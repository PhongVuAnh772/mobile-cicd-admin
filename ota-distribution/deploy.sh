#!/bin/bash

# 1. Build & Push Docker image (Force platform to linux/amd64 for Render)
echo "🚀 Building and Pushing Docker Image (AMD64)..."
docker build --platform linux/amd64 -t phongva/ota-distribution:latest .
docker tag phongva/ota-distribution:latest phongva/ota-distribution:v1
docker push phongva/ota-distribution:v1

# 2. Trigger Render Deploy (Dán đường dẫn Deploy Hook của bạn vào đây)
# Bạn hãy thay URL dưới đây bằng URL bạn lấy từ Render Settings
DEPLOY_HOOK_URL="BẠN_DÁN_DE_PLOY_HOOK_VÀO_ĐÂY"

if [ "$DEPLOY_HOOK_URL" != "BẠN_DÁN_DE_PLOY_HOOK_VÀO_ĐÂY" ]; then
    echo "🌐 Triggering Render Deploy..."
    curl -X POST "$DEPLOY_HOOK_URL"
    echo -e "\n✅ Done! Check your Render Dashboard for progress."
else
    echo "⚠️  Cảnh báo: Bạn chưa dán Deploy Hook URL vào file deploy.sh"
    echo "Vui lòng dán link lấy từ Render Settings vào biến DEPLOY_HOOK_URL."
fi
