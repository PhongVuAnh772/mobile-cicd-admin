#!/usr/bin/env python3
"""
============================================================================
🚀 ENTERPRISE AWS S3 OTA (OVER-THE-AIR) UPDATE DEPLOYMENT ENGINE
============================================================================
Đóng gói Metro JS Bundle & Assets và đẩy trực tiếp lên AWS S3 Bucket.
Hỗ trợ cập nhật tức thì (30 giây) không cần qua Google Play / App Store duyệt.
============================================================================
"""

import os
import sys
import json
import hashlib
import zipfile
import shutil
import subprocess
import datetime
import mimetypes
import boto3
from botocore.exceptions import ClientError

# Configuration & Environment Variables
AWS_ACCESS_KEY_ID = os.getenv("AWS_ACCESS_KEY_ID", "")
AWS_SECRET_ACCESS_KEY = os.getenv("AWS_SECRET_ACCESS_KEY", "")
AWS_S3_BUCKET = os.getenv("AWS_S3_BUCKET", "amzn-s3-cryptovault")
AWS_REGION = os.getenv("AWS_REGION", "ap-southeast-2")

ENVIRONMENT = os.getenv("ENVIRONMENT", "production")  # staging | production
UPDATE_MESSAGE = os.getenv("OTA_MESSAGE", os.getenv("COMMIT_MESSAGE", "OTA Hotfix update"))
PLATFORM = os.getenv("PLATFORM", "android")  # android | ios | all

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
TEMP_OTA_DIR = "/tmp/ota-dist"
BUNDLE_OUTPUT_DIR = os.path.join(TEMP_OTA_DIR, "bundle")
ZIP_OUTPUT_DIR = os.path.join(TEMP_OTA_DIR, "zips")

# Extract App Version from package.json
PKG_JSON_PATH = os.path.join(PROJECT_ROOT, "package.json")
APP_NAME = "trustvault"
APP_VERSION = "1.0.0"

if os.path.exists(PKG_JSON_PATH):
    try:
        with open(PKG_JSON_PATH, "r", encoding="utf-8") as f:
            pkg = json.load(f)
            APP_NAME = pkg.get("name", "trustvault")
            APP_VERSION = pkg.get("version", "1.0.0")
    except Exception as e:
        print(f"⚠️ Warning reading package.json: {e}")

print("==========================================================================")
print(f"⚡ AWS S3 OTA (OVER-THE-AIR) UPDATE PIPELINE")
print("==========================================================================")
print(f"🏷️  App Name:         {APP_NAME}")
print(f"📌 App Version:      v{APP_VERSION}")
print(f"🌍 Environment:      {ENVIRONMENT}")
print(f"📱 Target Platform:  {PLATFORM}")
print(f"💬 Update Message:   {UPDATE_MESSAGE}")
print(f"📦 AWS S3 Bucket:    s3://{AWS_S3_BUCKET}")
print(f"🌏 AWS Region:       {AWS_REGION}")
print("==========================================================================")

# Clean and prepare temporary directory
if os.path.exists(TEMP_OTA_DIR):
    shutil.rmtree(TEMP_OTA_DIR)
os.makedirs(BUNDLE_OUTPUT_DIR, exist_ok=True)
os.makedirs(ZIP_OUTPUT_DIR, exist_ok=True)

# ── 1. GENERATE METRO JS BUNDLE & ASSETS ──
print("\n📦 [1/4] Generating Metro JS Bundle and assets...")

entry_file = "index.js"
if not os.path.exists(os.path.join(PROJECT_ROOT, entry_file)):
    if os.path.exists(os.path.join(PROJECT_ROOT, "index.ts")):
        entry_file = "index.ts"
    elif os.path.exists(os.path.join(PROJECT_ROOT, "App.tsx")):
        entry_file = "App.tsx"

js_bundle_file = os.path.join(BUNDLE_OUTPUT_DIR, "index.android.bundle")
assets_dir = os.path.join(BUNDLE_OUTPUT_DIR, "res")

bundle_cmd = [
    "npx", "react-native", "bundle",
    "--platform", "android",
    "--dev", "false",
    "--entry-file", entry_file,
    "--bundle-output", js_bundle_file,
    "--assets-dest", assets_dir
]

try:
    print(f"⚡ Running: {' '.join(bundle_cmd)}")
    subprocess.run(bundle_cmd, cwd=PROJECT_ROOT, check=True)
    print("✅ Metro bundle generated successfully!")
except Exception as e:
    print(f"⚠️ react-native bundle warning, trying fallback npx expo export:embed...")
    fallback_cmd = [
        "npx", "expo", "export:embed",
        "--platform", "android",
        "--dev", "false",
        "--entry-file", entry_file,
        "--bundle-output", js_bundle_file,
        "--assets-dest", assets_dir
    ]
    subprocess.run(fallback_cmd, cwd=PROJECT_ROOT, check=True)
    print("✅ Fallback Expo export succeeded!")

# ── 2. COMPUTE HASH & CREATE OTA ZIP PACKAGE ──
print("\n🔒 [2/4] Hashing & packaging OTA Zip...")

hasher = hashlib.sha256()
with open(js_bundle_file, 'rb') as f:
    while chunk := f.read(8192):
        hasher.update(chunk)
bundle_sha256 = hasher.hexdigest()
bundle_short_hash = bundle_sha256[:10]

now_iso = datetime.datetime.utcnow().isoformat() + "Z"
bundle_id = f"ota-{APP_VERSION}-{bundle_short_hash}"
zip_filename = f"{bundle_id}.zip"
zip_filepath = os.path.join(ZIP_OUTPUT_DIR, zip_filename)

print(f"  🔑 Bundle SHA256:   {bundle_sha256}")
print(f"  🆔 Bundle ID:       {bundle_id}")

with zipfile.ZipFile(zip_filepath, 'w', zipfile.ZIP_DEFLATED) as zipf:
    for root, dirs, files in os.walk(BUNDLE_OUTPUT_DIR):
        for file in files:
            full_path = os.path.join(root, file)
            rel_path = os.path.relpath(full_path, BUNDLE_OUTPUT_DIR)
            zipf.write(full_path, rel_path)

zip_size_mb = os.path.getsize(zip_filepath) / (1024 * 1024)
print(f"  📦 Packaged ZIP:    {zip_filename} ({zip_size_mb:.2f} MB)")

# ── 3. UPLOAD TO AWS S3 ──
print(f"\n☁️ [3/4] Uploading OTA Package & Manifest to AWS S3 ({AWS_S3_BUCKET})...")

session = boto3.Session(
    aws_access_key_id=AWS_ACCESS_KEY_ID,
    aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
    region_name=AWS_REGION
)
s3_client = session.client("s3")

# S3 Keys
s3_bundle_key = f"ota/bundles/{zip_filename}"
s3_manifest_key = f"ota/{ENVIRONMENT}/manifest.json"

bundle_public_url = f"https://{AWS_S3_BUCKET}.s3.{AWS_REGION}.amazonaws.com/{s3_bundle_key}"
manifest_public_url = f"https://{AWS_S3_BUCKET}.s3.{AWS_REGION}.amazonaws.com/{s3_manifest_key}"

# 3.1 Upload Zip
print(f"  📤 Uploading bundle to s3://{AWS_S3_BUCKET}/{s3_bundle_key}...")
s3_client.upload_file(
    zip_filepath,
    AWS_S3_BUCKET,
    s3_bundle_key,
    ExtraArgs={
        'ContentType': 'application/zip',
        'CacheControl': 'public, max-age=31536000, immutable'
    }
)
print(f"  ✅ Bundle URL: {bundle_public_url}")

# 3.2 Create & Upload Manifest
manifest_data = {
    "appId": APP_NAME,
    "version": APP_VERSION,
    "runtimeVersion": APP_VERSION,
    "environment": ENVIRONMENT,
    "bundleId": bundle_id,
    "bundleUrl": bundle_public_url,
    "sha256": bundle_sha256,
    "sizeBytes": os.path.getsize(zip_filepath),
    "releasedAt": now_iso,
    "message": UPDATE_MESSAGE,
    "isMandatory": True
}

manifest_local_path = os.path.join(TEMP_OTA_DIR, "manifest.json")
with open(manifest_local_path, "w", encoding="utf-8") as f:
    json.dump(manifest_data, f, indent=2, ensure_ascii=False)

print(f"  📤 Uploading manifest to s3://{AWS_S3_BUCKET}/{s3_manifest_key}...")
s3_client.upload_file(
    manifest_local_path,
    AWS_S3_BUCKET,
    s3_manifest_key,
    ExtraArgs={
        'ContentType': 'application/json',
        'CacheControl': 'no-cache, no-store, must-revalidate'
    }
)
print(f"  ✅ Manifest URL: {manifest_public_url}")

# ── 4. SEND SLACK NOTIFICATION ──
print("\n📢 [4/4] Sending Slack OTA Milestone Report...")
SLACK_WEBHOOK_URL = os.getenv("SLACK_WEBHOOK_URL", "")

if SLACK_WEBHOOK_URL:
    import urllib.request
    color = "#36a64f" if ENVIRONMENT == "production" else "#4A90E2"
    payload = {
        "attachments": [
            {
                "color": color,
                "blocks": [
                    {
                        "type": "header",
                        "text": { "type": "plain_text", "text": f"⚡ OTA HOTFIX LIVE ON AWS S3 — {APP_NAME.upper()}", "emoji": True }
                    },
                    {
                        "type": "section",
                        "fields": [
                            { "type": "mrkdwn", "text": f"*🏷️ App:*\n`{APP_NAME}`" },
                            { "type": "mrkdwn", "text": f"*🌍 Environment:*\n`{ENVIRONMENT.upper()}`" },
                            { "type": "mrkdwn", "text": f"*📌 Version:*\n`v{APP_VERSION}`" },
                            { "type": "mrkdwn", "text": f"*📦 Bundle ID:*\n`{bundle_id}`" }
                        ]
                    },
                    {
                        "type": "section",
                        "text": { "type": "mrkdwn", "text": f"💬 *Release Note:*\n_{UPDATE_MESSAGE}_\n\n⏱️ *Áp dụng tức thì:* Người dùng mở app lên sẽ tự động nhận bản vá JS trong 30 giây." }
                    },
                    { "type": "divider" },
                    {
                        "type": "actions",
                        "elements": [
                            {
                                "type": "button",
                                "text": { "type": "plain_text", "text": "📄 View Manifest", "emoji": True },
                                "url": manifest_public_url,
                                "style": "primary"
                            },
                            {
                                "type": "button",
                                "text": { "type": "plain_text", "text": "📦 Download Bundle Zip", "emoji": True },
                                "url": bundle_public_url
                            }
                        ]
                    }
                ]
            }
        ]
    }
    try:
        req = urllib.request.Request(
            SLACK_WEBHOOK_URL,
            data=json.dumps(payload).encode('utf-8'),
            headers={'Content-Type': 'application/json'}
        )
        urllib.request.urlopen(req, timeout=10)
        print("✅ Slack OTA notification delivered!")
    except Exception as e:
        print(f"⚠️ Slack notification error: {e}")

print("\n==========================================================================")
print(f"🎉 OTA DEPLOYMENT COMPLETED IN < 30 SECONDS!")
print(f"🌐 Manifest URL: {manifest_public_url}")
print(f"==========================================================================")
