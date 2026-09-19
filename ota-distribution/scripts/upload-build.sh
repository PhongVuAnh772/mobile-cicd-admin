#!/usr/bin/env bash
# ============================================================================
# 🚀 CLI SCRIPT: UPLOAD BUILD TO OTA DISTRIBUTION PORTAL
# ============================================================================
# Tự động đẩy file build (.ipa, .apk, .aab) lên server OTA kèm đầy đủ metadata
# Hỗ trợ flags: -m, --file, --env, --flavor, --author, --branch, --server
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Đọc .env nếu có
if [ -f "${PROJECT_ROOT}/.env" ]; then
  set -a
  source "${PROJECT_ROOT}/.env"
  set +a
elif [ -f ".env" ]; then
  set -a
  source ".env"
  set +a
fi

# Mặc định
SERVER_URL="${OTA_SERVER_URL:-${BASE_URL:-https://mobile-cicd-admin.onrender.com}}"
BUILD_ENV="${BUILD_ENV:-dev}"
FLAVOR="${FLAVOR:-dev}"
MESSAGE="${MESSAGE:-${M:-Bản build nội bộ mới}}"
AUTHOR="${AUTHOR:-$(git log -1 --pretty=format:'%an' 2>/dev/null || echo 'Developer')}"
BRANCH="${REF_NAME:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'main')}"
FILE_PATH=""
APP_NAME=""
VERSION=""
BUILD_NUM=""

# Parse arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    -f|--file) FILE_PATH="$2"; shift ;;
    -f=*|--file=*) FILE_PATH="${1#*=}" ;;
    -e|--env) BUILD_ENV="$2"; shift ;;
    -e=*|--env=*) BUILD_ENV="${1#*=}" ;;
    --flavor) FLAVOR="$2"; shift ;;
    --flavor=*) FLAVOR="${1#*=}" ;;
    -m|--message) MESSAGE="$2"; shift ;;
    -m=*|--message=*) MESSAGE="${1#*=}" ;;
    -a|--author) AUTHOR="$2"; shift ;;
    -a=*|--author=*) AUTHOR="${1#*=}" ;;
    -b|--branch) BRANCH="$2"; shift ;;
    -b=*|--branch=*) BRANCH="${1#*=}" ;;
    -s|--server) SERVER_URL="$2"; shift ;;
    -s=*|--server=*) SERVER_URL="${1#*=}" ;;
    --name) APP_NAME="$2"; shift ;;
    --name=*) APP_NAME="${1#*=}" ;;
    --version) VERSION="$2"; shift ;;
    --version=*) VERSION="${1#*=}" ;;
    --build-num) BUILD_NUM="$2"; shift ;;
    --build-num=*) BUILD_NUM="${1#*=}" ;;
    -h|--help)
      echo "📱 OTA Build Upload CLI Tool"
      echo "Cách dùng: $0 [options]"
      echo "  -f, --file FILE       Đường dẫn file .ipa, .apk, hoặc .aab"
      echo "  -e, --env ENV         Môi trường: dev | beta | prod (mặc định: dev)"
      echo "  --flavor FLAVOR       Flavor ứng dụng: dev | beta | pro (mặc định: theo env)"
      echo "  -m, --message MSG     Ghi chú bản build (VD: -m=\"Gửi bản dev cho @TE_HauTV\")"
      echo "  -a, --author AUTHOR   Người build / author tag (VD: @TE_HauTV)"
      echo "  -b, --branch BRANCH   Tên nhánh Git (mặc định: nhánh hiện tại)"
      echo "  -s, --server URL      Địa chỉ OTA Server (mặc định: https://mobile-cicd-admin.onrender.com)"
      exit 0
      ;;
    *) echo "⚠️ Tham số không xác định: $1" ;;
  esac
  shift
done

# Tự động tìm file build nếu chưa truyền
if [ -z "$FILE_PATH" ]; then
  echo "🔍 Đang tự động quét tìm file build gần nhất..."
  FILE_PATH=$(find build ../build -type f \( -name "*.apk" -o -name "*.ipa" -o -name "*.aab" \) 2>/dev/null | head -n 1 || true)
fi

if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
  echo "❌ Lỗi: Không tìm thấy file build hợp lệ (.ipa, .apk, .aab)."
  echo "👉 Cách dùng: $0 --file path/to/app.apk -m \"Gửi bản dev cho @TE_HauTV\" --env dev"
  exit 1
fi

FILE_NAME=$(basename "$FILE_PATH")
echo "=========================================================================="
echo "🚀 ĐẨY BẢN BUILD LÊN OTA DISTRIBUTION PORTAL"
echo "=========================================================================="
echo "📦 File:         $FILE_NAME ($FILE_PATH)"
echo "🌍 Môi trường:   $BUILD_ENV (Flavor: $FLAVOR)"
echo "💬 Ghi chú (-m): $MESSAGE"
echo "👤 Tác giả:      $AUTHOR"
echo "🌿 Nhánh Git:    $BRANCH"
echo "🌐 Server OTA:   $SERVER_URL"
echo "=========================================================================="

CURL_ARGS=(
  -s -w "\n%{http_code}" -X POST "${SERVER_URL}/api/ota/upload"
  -F "file=@${FILE_PATH}"
  --form-string "environment=${BUILD_ENV}"
  --form-string "flavor=${FLAVOR}"
  --form-string "message=${MESSAGE}"
  --form-string "author=${AUTHOR}"
  --form-string "branch=${BRANCH}"
)

[ -n "$APP_NAME" ] && CURL_ARGS+=(--form-string "appName=${APP_NAME}")
[ -n "$VERSION" ] && CURL_ARGS+=(--form-string "version=${VERSION}")
[ -n "$BUILD_NUM" ] && CURL_ARGS+=(--form-string "buildNumber=${BUILD_NUM}")

HTTP_RESPONSE=$(curl "${CURL_ARGS[@]}")

HTTP_BODY=$(echo "$HTTP_RESPONSE" | sed '$d')
HTTP_STATUS=$(echo "$HTTP_RESPONSE" | tail -n 1)

if [ "$HTTP_STATUS" -eq 200 ]; then
  echo "✅ ĐẨY BẢN BUILD THÀNH CÔNG!"
  INSTALL_URL=$(echo "$HTTP_BODY" | grep -o '"installUrl":"[^"]*' | cut -d'"' -f4 || true)
  WEB_URL=$(echo "$HTTP_BODY" | grep -o '"webInstallUrl":"[^"]*' | cut -d'"' -f4 || true)
  FILE_URL=$(echo "$HTTP_BODY" | grep -o '"fileUrl":"[^"]*' | cut -d'"' -f4 || true)
  S3_URL="${FILE_URL:-$INSTALL_URL}"

  # Tự động đồng bộ lên AWS S3 nếu có S3 credentials và server chưa đẩy S3
  if [[ "$FILE_URL" != *"amazonaws.com"* ]] && [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_S3_BUCKET" ]; then
    echo "☁️ Đang đồng bộ bản build lên AWS S3 ($AWS_S3_BUCKET)..."
    S3_KEY="ota/$(date +%s)-${FILE_NAME}"
    python3 -c "
import os, sys, boto3
file_path, key = sys.argv[1], sys.argv[2]
s3 = boto3.client('s3',
    aws_access_key_id=os.environ['AWS_ACCESS_KEY_ID'],
    aws_secret_access_key=os.environ['AWS_SECRET_ACCESS_KEY'],
    region_name=os.environ.get('AWS_REGION', 'ap-southeast-2')
)
s3.upload_file(file_path, os.environ['AWS_S3_BUCKET'], key)
" "$FILE_PATH" "$S3_KEY" 2>/dev/null && S3_URL="https://${AWS_S3_BUCKET}.s3.${AWS_REGION:-ap-southeast-2}.amazonaws.com/${S3_KEY}" || true
  fi

  echo "👉 Link Portal:   ${SERVER_URL}"
  [ -n "$WEB_URL" ] && echo "👉 Link Web:      ${WEB_URL}"
  [ -n "$S3_URL" ] && echo "👉 Link S3:       ${S3_URL}"
  echo "=========================================================================="

  # Tự động gửi Mobile Builder Card lên Telegram với 1 Link Web và 1 Link S3
  PLATFORM_DETECT="android"
  [[ "$FILE_NAME" =~ \.ipa$ ]] && PLATFORM_DETECT="ios"
  
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [ -f "${SCRIPT_DIR}/notify-telegram.sh" ]; then
    bash "${SCRIPT_DIR}/notify-telegram.sh" \
      --app-name "${APP_NAME:-RetroBox}" \
      --platform "$PLATFORM_DETECT" \
      --env "$BUILD_ENV" \
      --version "$VERSION" \
      --build-num "$BUILD_NUM" \
      --branch "$BRANCH" \
      --author "$AUTHOR" \
      --note "$MESSAGE" \
      --web-url "$WEB_URL" \
      --s3-url "$S3_URL" || true
  fi
else
  echo "❌ Lỗi khi upload (HTTP Status $HTTP_STATUS):"
  echo "$HTTP_BODY"
  exit 1
fi
