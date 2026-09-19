#!/usr/bin/env bash
# ============================================================================
# 📢 TELEGRAM NOTIFICATION SCRIPT (MATCHING VUIHOC MOBILE BUILDER CARD STYLE)
# ============================================================================
# Định dạng chuẩn theo phong cách Mobile Builder:
#   [Banner Image: Android hoặc iOS Logo + Brand]
#   # {APP_NAME} {PLATFORM} {ENV}
#   🚦 Version: {VERSION}+{BUILD_NUMBER}
#   🌿 Branch: {BRANCH}
#   👨‍💻 By: @{AUTHOR} <{EMAIL}>
#   📝 Note: {NOTE}
#   [ 🔗 Install App ]
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

BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT_ID="${TELEGRAM_CHAT_ID:-}"
THREAD_ID="${TELEGRAM_THREAD_ID:-}"

# Tham số mặc định
APP_NAME=""
PLATFORM=""
BUILD_ENV="DEV"
VERSION=""
BUILD_NUM=""
BRANCH=""
AUTHOR=""
MESSAGE=""
INSTALL_URL=""
BANNER_PATH=""
STATUS="success"
TITLE=""
DRY_RUN=false
TEST_MODE=false

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --token) BOT_TOKEN="$2"; shift ;;
    --chat-id) CHAT_ID="$2"; shift ;;
    --thread-id) THREAD_ID="$2"; shift ;;
    --app-name) APP_NAME="$2"; shift ;;
    --platform) PLATFORM="$2"; shift ;;
    --env|-e) BUILD_ENV="$2"; shift ;;
    --version|-v) VERSION="$2"; shift ;;
    --build-num) BUILD_NUM="$2"; shift ;;
    --branch|-b) BRANCH="$2"; shift ;;
    --author|-a) AUTHOR="$2"; shift ;;
    --message|--note|-m) MESSAGE="$2"; shift ;;
    --install-url|--url) INSTALL_URL="$2"; shift ;;
    --photo|--banner) BANNER_PATH="$2"; shift ;;
    --status) STATUS="$2"; shift ;;
    --title) TITLE="$2"; shift ;;
    --dry-run) DRY_RUN=true ;;
    --test) TEST_MODE=true ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
  shift
done

# Kiểm tra chế độ test kết nối
if [ "$TEST_MODE" = true ]; then
  echo "🔍 [Telegram Test] Đang kiểm tra cấu hình..."
  if [ -z "$BOT_TOKEN" ]; then
    echo "❌ Lỗi: Chưa cung cấp TELEGRAM_BOT_TOKEN (qua biến môi trường, .env hoặc cờ --token)"
    exit 1
  fi

  echo "⚡ Kiểm tra Bot Profile qua getMe..."
  BOT_INFO=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getMe")
  IS_OK=$(echo "$BOT_INFO" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('ok', False))" 2>/dev/null || echo "False")

  if [ "$IS_OK" = "True" ]; then
    BOT_USER=$(echo "$BOT_INFO" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('result', {}).get('username', 'N/A'))" 2>/dev/null)
    echo "✅ Bot kết nối thành công: @${BOT_USER}"
  else
    echo "❌ Token không hợp lệ hoặc không thể kết nối tới Telegram API!"
    echo "Response: $BOT_INFO"
    exit 1
  fi

  if [ -n "$CHAT_ID" ]; then
    echo "📤 Đang gửi tin nhắn thử nghiệm tới Chat ID: $CHAT_ID..."
    MESSAGE="🔔 <b>Test Notification</b>\nBot @${BOT_USER} đã kết nối thành công với dự án <b>${APP_NAME:-MobileApp}</b>!"
    STATUS="success"
  else
    echo "ℹ️ Chưa có TELEGRAM_CHAT_ID. Chỉ kiểm tra token thành công."
    exit 0
  fi
fi

# Tự động suy luận thông tin còn thiếu nếu chưa truyền
[ -z "$BRANCH" ] && BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

if [ -z "$AUTHOR" ]; then
  GIT_NAME=$(git log -1 --pretty=format:'%an' 2>/dev/null || echo "$USER")
  GIT_EMAIL=$(git log -1 --pretty=format:'%ae' 2>/dev/null || echo "")
  if [ -n "$GIT_EMAIL" ]; then
    AUTHOR="@@TE_PhongVA <${GIT_EMAIL}>"
  else
    AUTHOR="@@TE_PhongVA"
  fi
fi

if [ -z "$VERSION" ] && [ -f "package.json" ]; then
  VERSION=$(python3 -c "import json; print(json.load(open('package.json')).get('version', '1.0.0'))" 2>/dev/null || echo "1.0.0")
fi
[ -z "$VERSION" ] && VERSION="1.0.0"

if [ -z "$BUILD_NUM" ]; then
  BUILD_NUM="${GITHUB_RUN_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo '1')}"
fi

if [ -z "$APP_NAME" ]; then
  if [ -f "package.json" ]; then
    APP_NAME=$(python3 -c "import json; print(json.load(open('package.json')).get('name', 'RetroBox'))" 2>/dev/null || echo "RetroBox")
  else
    APP_NAME="RetroBox"
  fi
fi

# Tự động chuẩn hóa Platform (android / ios)
PLATFORM_LOWER=$(echo "$PLATFORM" | tr '[:upper:]' '[:lower:]')
PLATFORM_DISPLAY="Android"
[ "$PLATFORM_LOWER" = "ios" ] && PLATFORM_DISPLAY="iOS"

ENV_DISPLAY=$(echo "$BUILD_ENV" | tr '[:lower:]' '[:upper:]')

# Tự động chọn Banner Card nếu chưa chỉ định
if [ -z "$BANNER_PATH" ]; then
  if [ "$PLATFORM_LOWER" = "ios" ]; then
    POSSIBLE_BANNERS=("${PROJECT_ROOT}/assets/banners/ios_banner.png" "assets/banners/ios_banner.png" "../assets/banners/ios_banner.png")
  else
    POSSIBLE_BANNERS=("${PROJECT_ROOT}/assets/banners/android_banner.png" "assets/banners/android_banner.png" "../assets/banners/android_banner.png")
  fi

  for b in "${POSSIBLE_BANNERS[@]}"; do
    if [ -f "$b" ]; then
      BANNER_PATH="$b"
      break
    fi
  done
fi

# Chuẩn bị Caption theo đúng format Mobile Builder
CAPTION_HEADER="# ${APP_NAME} ${PLATFORM_DISPLAY} ${ENV_DISPLAY}"
[ -n "$TITLE" ] && CAPTION_HEADER="$TITLE"

CLEAN_AUTHOR=$(echo "$AUTHOR" | sed 's/</\&lt;/g' | sed 's/>/\&gt;/g')

CAPTION="<b>${CAPTION_HEADER}</b>
🚦 <b>Version:</b> ${VERSION}+${BUILD_NUM}
🌿 <b>Branch:</b> ${BRANCH}
👨‍💻 <b>By:</b> ${CLEAN_AUTHOR}"

if [ -n "$MESSAGE" ]; then
  CLEAN_MSG=$(echo "$MESSAGE" | sed 's/</\&lt;/g' | sed 's/>/\&gt;/g')
  CAPTION="${CAPTION}
📝 <b>Note:</b> ${CLEAN_MSG}"
fi

# Chuẩn bị Inline Keyboard Button "Install App"
REPLY_MARKUP=""
if [ -n "$INSTALL_URL" ]; then
  REPLY_MARKUP=$(python3 -c "
import json
print(json.dumps({
  'inline_keyboard': [[
    {'text': '🔗 Install App', 'url': '$INSTALL_URL'}
  ]]
}))
")
fi

# Dry Run Output
if [ "$DRY_RUN" = true ]; then
  echo "══════════════════════════════════════════════════════════════════════════"
  echo "🔍 [DRY-RUN] MOBILE BUILDER TELEGRAM CARD PREVIEW:"
  echo "══════════════════════════════════════════════════════════════════════════"
  echo "🖼️  Banner Image:  ${BANNER_PATH:-[Không có banner -> Dùng text]}"
  echo "💬 Caption:"
  echo "$CAPTION"
  if [ -n "$INSTALL_URL" ]; then
    echo "🔘 Button:        [ 🔗 Install App ] ➔ $INSTALL_URL"
  fi
  echo "══════════════════════════════════════════════════════════════════════════"
  exit 0
fi

# Kiểm tra Token & Chat ID
if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
  echo "⚠️ TELEGRAM_BOT_TOKEN hoặc TELEGRAM_CHAT_ID chưa được thiết lập."
  echo "👉 Hãy cấu hình trong .env hoặc truyền qua cờ --token và --chat-id"
  exit 0
fi

# Gửi ảnh banner kèm caption và button (sendPhoto API)
if [ -n "$BANNER_PATH" ] && [ -f "$BANNER_PATH" ]; then
  echo "📤 Đang gửi Mobile Builder Photo Card tới Telegram..."
  CURL_ARGS=(
    -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendPhoto"
    --form-string "chat_id=${CHAT_ID}"
    -F "photo=@${BANNER_PATH}"
    --form-string "caption=${CAPTION}"
    --form-string "parse_mode=HTML"
  )
  [ -n "$THREAD_ID" ] && CURL_ARGS+=(--form-string "message_thread_id=${THREAD_ID}")
  [ -n "$REPLY_MARKUP" ] && CURL_ARGS+=(--form-string "reply_markup=${REPLY_MARKUP}")

  RESP=$(curl "${CURL_ARGS[@]}")
  IS_SUCCESS=$(echo "$RESP" | python3 -c "import sys, json; print(json.load(sys.stdin).get('ok', False))" 2>/dev/null || echo "False")

  if [ "$IS_SUCCESS" = "True" ]; then
    echo "✅ Đã gửi Mobile Builder Card lên Telegram thành công!"
    exit 0
  else
    echo "⚠️ Gửi ảnh thất bại, chuyển sang fallback gửi tin nhắn văn bản. Lỗi: $RESP"
  fi
fi

# Fallback gửi tin nhắn văn bản (sendMessage API)
echo "📤 Đang gửi tin nhắn văn bản tới Telegram..."
CURL_ARGS=(
  -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage"
  --form-string "chat_id=${CHAT_ID}"
  --form-string "text=${CAPTION}"
  --form-string "parse_mode=HTML"
  --form-string "disable_web_page_preview=true"
)
[ -n "$THREAD_ID" ] && CURL_ARGS+=(--form-string "message_thread_id=${THREAD_ID}")
[ -n "$REPLY_MARKUP" ] && CURL_ARGS+=(--form-string "reply_markup=${REPLY_MARKUP}")

RESP=$(curl "${CURL_ARGS[@]}")
IS_SUCCESS=$(echo "$RESP" | python3 -c "import sys, json; print(json.load(sys.stdin).get('ok', False))" 2>/dev/null || echo "False")

if [ "$IS_SUCCESS" = "True" ]; then
  echo "✅ Đã gửi thông báo Telegram thành công!"
else
  echo "❌ Gửi thông báo Telegram thất bại: $RESP"
fi

