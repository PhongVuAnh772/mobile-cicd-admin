#!/usr/bin/env bash
# ==============================================================================
# AWS S3 Store Deploy Script for Internal App Distribution Web Portal
# ==============================================================================

set -e

S3_BUCKET="${AWS_S3_BUCKET:-cryptovault-app-distribution-store}"
AWS_REGION="${AWS_REGION:-ap-southeast-1}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🚀 Deploying App Distribution Store to AWS S3..."
echo "📦 Target Bucket: s3://$S3_BUCKET"
echo "🌏 AWS Region: $AWS_REGION"
echo "📁 Project Root: $PROJECT_ROOT"

# Check AWS CLI installation
if ! command -v aws &> /dev/null; then
    echo "❌ Error: AWS CLI is not installed or not in PATH."
    echo "Please install awscli: brew install awscli or pip install awscli"
    exit 1
fi

# Ensure S3 Bucket exists or create it
echo "🔍 Checking S3 Bucket status..."
if ! aws s3api head-bucket --bucket "$S3_BUCKET" 2>/dev/null; then
    echo "⚡ Creating S3 Bucket: $S3_BUCKET in $AWS_REGION..."
    aws s3api create-bucket \
        --bucket "$S3_BUCKET" \
        --region "$AWS_REGION" \
        --create-bucket-configuration LocationConstraint="$AWS_REGION"
    
    # Enable Static Website Hosting
    aws s3 website "s3://$S3_BUCKET/" \
        --index-document index.html \
        --error-document index.html
fi

# Upload Static Web Portal Files
WEB_DIR="$PROJECT_ROOT/app-distribution-web"
echo "📤 Uploading Web Portal static files from $WEB_DIR..."

aws s3 sync "$WEB_DIR" "s3://$S3_BUCKET/" \
    --delete \
    --cache-control "max-age=300"

# Copy App Icon asset if exists
if [ -f "$PROJECT_ROOT/assets/images/icon_app.png" ]; then
    mkdir -p "$WEB_DIR/assets/images"
    cp "$PROJECT_ROOT/assets/images/icon_app.png" "$WEB_DIR/assets/images/icon_app.png"
    aws s3 cp "$PROJECT_ROOT/assets/images/icon_app.png" "s3://$S3_BUCKET/assets/images/icon_app.png"
fi

# Upload Release Binaries (APK / IPA)
APK_PATH="$(find "$PROJECT_ROOT" -type f -name "*.apk" | head -n 1)"
if [ -n "$APK_PATH" ]; then
    echo "📦 Found Android Release APK: $APK_PATH"
    APK_NAME="$(basename "$APK_PATH")"
    aws s3 cp "$APK_PATH" "s3://$S3_BUCKET/downloads/android/$APK_NAME" --acl public-read
    echo "✅ Uploaded APK to s3://$S3_BUCKET/downloads/android/$APK_NAME"
fi

# Summary
WEBSITE_URL="http://$S3_BUCKET.s3-website-$AWS_REGION.amazonaws.com"
echo "=========================================================================="
echo "🎉 AWS S3 APP DISTRIBUTION STORE DEPLOYED SUCCESSFULLY!"
echo "🌐 Live Portal URL: $WEBSITE_URL"
echo "=========================================================================="
