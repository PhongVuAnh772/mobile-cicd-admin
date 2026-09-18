#!/usr/bin/env python3
import os
import sys
import glob
import json
import re
import mimetypes
import boto3
from botocore.exceptions import ClientError

# Credentials and S3 Configuration
AWS_ACCESS_KEY_ID = os.getenv("AWS_ACCESS_KEY_ID", "")
AWS_SECRET_ACCESS_KEY = os.getenv("AWS_SECRET_ACCESS_KEY", "")
AWS_S3_BUCKET = os.getenv("AWS_S3_BUCKET", "amzn-s3-cryptovault")
AWS_REGION = os.getenv("AWS_REGION", "ap-southeast-2")

# Branch and Environment Context
REF_NAME = os.getenv("GITHUB_REF_NAME", os.getenv("GIT_BRANCH", "main"))
RUN_NUMBER = os.getenv("GITHUB_RUN_NUMBER", "1")
ENVIRONMENT = os.getenv("ENVIRONMENT", "staging")

# Sanitize Branch Name
CLEAN_BRANCH_SLUG = re.sub(r'[^a-zA-Z0-9_\-]', '-', REF_NAME).lower()

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
WEB_DIR = os.path.join(PROJECT_ROOT, "app-distribution-web")
BUILDS_JSON_PATH = os.path.join(WEB_DIR, "builds.json")
PKG_JSON_PATH = os.path.join(PROJECT_ROOT, "package.json")

# Read version from package.json
APP_VERSION = "1.0.0"
if os.path.exists(PKG_JSON_PATH):
    try:
        with open(PKG_JSON_PATH, "r", encoding="utf-8") as f:
            APP_VERSION = json.load(f).get("version", "1.0.0")
    except Exception:
        pass

print(f"==========================================================================")
print(f"🚀 AWS S3 BRANCH-RULE DEPLOYMENT ENGINE")
print(f"==========================================================================")
print(f"🌿 Git Branch:       {REF_NAME} (Slug: {CLEAN_BRANCH_SLUG})")
print(f"🌍 Environment:      {ENVIRONMENT}")
print(f"📌 Version:          v{APP_VERSION} (Build #{RUN_NUMBER})")
print(f"📦 Target Bucket:    s3://{AWS_S3_BUCKET}")
print(f"🌏 Region:           {AWS_REGION}")
print(f"==========================================================================")

session = boto3.Session(
    aws_access_key_id=AWS_ACCESS_KEY_ID,
    aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
    region_name=AWS_REGION
)
s3_client = session.client("s3")

# Ensure Bucket Exists
try:
    s3_client.head_bucket(Bucket=AWS_S3_BUCKET)
    print(f"✅ S3 Bucket '{AWS_S3_BUCKET}' verified.")
except ClientError as e:
    error_code = e.response['Error']['Code']
    if error_code in ['404', 'NoSuchBucket']:
        print(f"⚡ Creating S3 Bucket '{AWS_S3_BUCKET}' in {AWS_REGION}...")
        create_kwargs = {'Bucket': AWS_S3_BUCKET}
        if AWS_REGION != 'us-east-1':
            create_kwargs['CreateBucketConfiguration'] = {'LocationConstraint': AWS_REGION}
        s3_client.create_bucket(**create_kwargs)

# Locate APK Binary
apk_files = glob.glob(os.path.join(PROJECT_ROOT, "**/*.apk"), recursive=True)
if not apk_files and os.path.exists("/tmp/apk-artifacts"):
    apk_files = glob.glob("/tmp/apk-artifacts/**/*.apk", recursive=True)

if apk_files:
    raw_apk = apk_files[0]
    
    # ── BRANCH NAMING RULE LOGIC ──
    if REF_NAME == "main" or REF_NAME.startswith("v"):
        tagged_apk_name = f"trustvault-v{APP_VERSION}-release.apk"
        s3_apk_key = f"downloads/android/production/{tagged_apk_name}"
    elif REF_NAME in ["dev", "staging"]:
        tagged_apk_name = f"trustvault-staging-v{APP_VERSION}-b{RUN_NUMBER}.apk"
        s3_apk_key = f"downloads/android/staging/{tagged_apk_name}"
    else:
        # feature/* or bugfix/*
        tagged_apk_name = f"trustvault-{CLEAN_BRANCH_SLUG}-b{RUN_NUMBER}.apk"
        s3_apk_key = f"downloads/android/branches/{CLEAN_BRANCH_SLUG}/{tagged_apk_name}"

    direct_apk_url = f"https://{AWS_S3_BUCKET}.s3.{AWS_REGION}.amazonaws.com/{s3_apk_key}"
    
    print(f"📦 Source APK:       {raw_apk}")
    print(f"🏷️  Tagged Name:      {tagged_apk_name}")
    print(f"📤 S3 Key Path:      {s3_apk_key}")
    print(f"🔗 Direct URL:        {direct_apk_url}")
    
    s3_client.upload_file(
        raw_apk, 
        AWS_S3_BUCKET, 
        s3_apk_key, 
        ExtraArgs={'ContentType': 'application/vnd.android.package-archive'}
    )
    print(f"✅ Uploaded APK successfully to S3 under branch rule!")

    # Update builds.json with direct raw APK link & branch metadata
    if os.path.exists(BUILDS_JSON_PATH):
        try:
            with open(BUILDS_JSON_PATH, "r", encoding="utf-8") as f:
                data = json.load(f)
            
            for app in data.get("apps", []):
                if app.get("id") in ["cryptovault", "trustvault"]:
                    env_key = "production" if ENVIRONMENT == "production" else "staging"
                    builds = app["platforms"]["android"]["environments"].get(env_key, [])
                    if builds:
                        builds[0]["downloadUrl"] = direct_apk_url
                        builds[0]["fileName"] = tagged_apk_name
                        builds[0]["version"] = f"{APP_VERSION} ({REF_NAME})"
                        builds[0]["buildNumber"] = int(RUN_NUMBER) if RUN_NUMBER.isdigit() else 1

            with open(BUILDS_JSON_PATH, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
            print("✅ Updated app-distribution-web/builds.json with branch metadata!")
        except Exception as e:
            print(f"⚠️ builds.json update notice: {e}")

# Upload Web Portal Files (index.html, builds.json, app.js)
uploaded_files = 0
if os.path.exists(WEB_DIR):
    for root, dirs, files in os.walk(WEB_DIR):
        for file in files:
            file_path = os.path.join(root, file)
            rel_path = os.path.relpath(file_path, WEB_DIR)
            s3_key = rel_path.replace("\\", "/")

            content_type, _ = mimetypes.guess_type(file_path)
            if not content_type:
                if s3_key.endswith('.js'): content_type = 'application/javascript'
                elif s3_key.endswith('.css'): content_type = 'text/css'
                elif s3_key.endswith('.json'): content_type = 'application/json'
                else: content_type = 'binary/octet-stream'

            s3_client.upload_file(
                file_path,
                AWS_S3_BUCKET,
                s3_key,
                ExtraArgs={'ContentType': content_type}
            )
            uploaded_files += 1

print(f"✅ Web Distribution Store synced ({uploaded_files} assets uploaded)!")
print(f"🌐 Public Web Store URL: http://{AWS_S3_BUCKET}.s3-website-{AWS_REGION}.amazonaws.com")
print(f"==========================================================================")
