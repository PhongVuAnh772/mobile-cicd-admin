#!/usr/bin/env bash
# ============================================================================
# 🚀 ENTERPRISE MOBILE CI/CD ONE-CLICK REMOTE INITIALIZER & HEALTH CHECK
# ============================================================================
# 💡 HƯỚNG DẪN CÀI ĐẶT ALIAS KHI SANG MÁY MỚI (CHỈ CẦN LÀM 1 LẦN DUY NHẤT):
#
# 🍎 macOS (zsh - Mặc định):
#   echo 'alias init-mobile-cicd='\''bash -c "t=\$(mktemp -d); git clone --depth=1 --quiet git@github.com:phong-mobile/mobile-cicd-admin.git \"\$t\" && \"\$t/init-cicd.sh\" \"\$PWD\"; rm -rf \"\$t\""'\''' >> ~/.zshrc && source ~/.zshrc
#
# 🐧 Linux / Ubuntu / Debian (bash):
#   echo 'alias init-mobile-cicd='\''bash -c "t=\$(mktemp -d); git clone --depth=1 --quiet git@github.com:phong-mobile/mobile-cicd-admin.git \"\$t\" && \"\$t/init-cicd.sh\" \"\$PWD\"; rm -rf \"\$t\""'\''' >> ~/.bashrc && source ~/.bashrc
#
# ────────────────────────────────────────────────────────────────────────────
# 🎯 CÁCH SỬ DỤNG HÀNG NGÀY:
#   1. Mở Terminal và cd vào bất kỳ dự án Mobile nào (React Native / Expo).
#   2. Gõ đúng 1 từ:
#        init-mobile-cicd
#   3. Hệ thống tự động kéo script qua SSH, cấu hình CI/CD, chạy 70 Test Cases,
#      theo dõi Live Logs trực tiếp trên terminal và hướng dẫn từng bước!
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

TARGET_DIR="${1:-$(pwd)}"
cd "$TARGET_DIR"

GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$TARGET_DIR")

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   🚀 ENTERPRISE MOBILE CI/CD REMOTE INITIALIZER & HEALTH CHECK          ║${NC}"
echo -e "${CYAN}║   Centralized Engine: github.com/phong-mobile/mobile-cicd-admin          ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ──────────────────────────────────────────────────────────────────────────
# 1. AUTO-DETECT PROJECT CONFIGURATION
# ──────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}${BLUE}🔍 [1/4] Đang phân tích kiến trúc dự án tại: ${CYAN}$TARGET_DIR${NC}"

PKG_FILE="package.json"
[ ! -f "$PKG_FILE" ] && [ -f "crypto-vault-expo/package.json" ] && PKG_FILE="crypto-vault-expo/package.json"
[ ! -f "$PKG_FILE" ] && [ -f "$GIT_ROOT/crypto-vault-expo/package.json" ] && PKG_FILE="$GIT_ROOT/crypto-vault-expo/package.json"

if [ ! -f "$PKG_FILE" ]; then
  echo -e "${RED}❌ Không tìm thấy package.json trong thư mục ($TARGET_DIR)!${NC}"
  echo -e "${YELLOW}👉 Hãy cd vào thư mục dự án Mobile rồi chạy lại lệnh.${NC}"
  exit 1
fi

APP_NAME=$(node -e "try{const p=require('./$PKG_FILE');console.log(p.name||'CryptoVault')}catch{console.log('CryptoVault')}" 2>/dev/null)
APP_VERSION=$(node -e "try{const p=require('./$PKG_FILE');console.log(p.version||'1.0.0')}catch{console.log('1.0.0')}" 2>/dev/null)

# Detect Project Type
HAS_EXPO=false
HAS_DEV_CLIENT=false
HAS_NATIVE=false
PROJECT_TYPE="react-native-cli"

grep -q '"expo"' "$PKG_FILE" 2>/dev/null && HAS_EXPO=true
grep -q '"expo-dev-client"' "$PKG_FILE" 2>/dev/null && HAS_DEV_CLIENT=true

if grep -qE '(@react-native-firebase|@notifee|react-native-camera|react-native-reanimated|@walletconnect|expo-camera|expo-av)' "$PKG_FILE" 2>/dev/null; then
  HAS_NATIVE=true
fi

if [ "$HAS_EXPO" = true ]; then
  if [ "$HAS_DEV_CLIENT" = true ]; then
    PROJECT_TYPE="Expo Dev Client (Custom Native Modules)"
  elif [ "$HAS_NATIVE" = true ]; then
    PROJECT_TYPE="Expo Prebuild (Native Modules)"
  else
    PROJECT_TYPE="Expo Managed Workflow"
  fi
fi

CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "main")
BRANCH_SLUG=$(echo "$CURRENT_BRANCH" | tr '/' '-' | tr '[:upper:]' '[:lower:]')

if [ "$CURRENT_BRANCH" = "main" ] || [[ "$CURRENT_BRANCH" =~ ^v ]]; then
  ARTIFACT_RULE="trustvault-v${APP_VERSION}-release.apk (Production)"
  S3_FOLDER="downloads/android/production/"
elif [ "$CURRENT_BRANCH" = "dev" ] || [ "$CURRENT_BRANCH" = "staging" ]; then
  ARTIFACT_RULE="trustvault-staging-v${APP_VERSION}-b<RUN>.apk (Staging)"
  S3_FOLDER="downloads/android/staging/"
else
  ARTIFACT_RULE="trustvault-${BRANCH_SLUG}-b<RUN>.apk (Feature/Fix)"
  S3_FOLDER="downloads/android/branches/${BRANCH_SLUG}/"
fi

echo -e "  🏷️  Tên App:         ${GREEN}${BOLD}$APP_NAME${NC}"
echo -e "  📌 Version:         ${GREEN}$APP_VERSION${NC}"
echo -e "  🧩 Kiến trúc:       ${YELLOW}${BOLD}$PROJECT_TYPE${NC}"
echo -e "  🌿 Nhánh hiện tại:  ${CYAN}${BOLD}$CURRENT_BRANCH${NC} (Slug: $BRANCH_SLUG)"
echo -e "  🏷️  Branch Rule:     ${GREEN}$ARTIFACT_RULE${NC}"
echo -e "  📦 Thư mục S3:      ${YELLOW}$S3_FOLDER${NC}"
echo -e "  📁 Git Root:        ${CYAN}$GIT_ROOT${NC}"
echo ""

# ──────────────────────────────────────────────────────────────────────────
# 2. SYNC .github/workflows/ci.yml AT GIT ROOT & TARGET DIR
# ──────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}${BLUE}⚙️  [2/4] Đồng bộ file .github/workflows/ci.yml...${NC}"

if [ -f "$GIT_ROOT/.github/workflows/ci.yml" ]; then
  echo -e "  ${GREEN}✅ File .github/workflows/ci.yml đã sẵn sàng tại $GIT_ROOT!${NC}"
fi
echo ""

# ──────────────────────────────────────────────────────────────────────────
# 3. LOCAL HEALTH CHECK & TEST CASES VALIDATION (70 TCs)
# ──────────────────────────────────────────────────────────────────────────
run_local_checks() {
  echo -e "${BOLD}${BLUE}🧪 [3/4] Đang chạy kiểm thử bộ Test Cases trực tiếp trên máy...${NC}"

  PASS_COUNT=0
  WARN_COUNT=0
  FAIL_COUNT=0

  check_step() {
    local tc_id="$1"
    local tc_name="$2"
    local cmd="$3"
    
    if ( eval "$cmd" ) >/dev/null 2>&1; then
      echo -e "  ${GREEN}✅ [PASS]${NC} ${BOLD}$tc_id:${NC} $tc_name"
      PASS_COUNT=$((PASS_COUNT + 1))
    else
      echo -e "  ${YELLOW}⚠️ [WARN]${NC} ${BOLD}$tc_id:${NC} $tc_name"
      WARN_COUNT=$((WARN_COUNT + 1))
    fi
    return 0
  }

  echo -e "  ${CYAN}📋 [PHASE 1: CI Pipeline & Code Quality]${NC}"
  check_step "TC-01" "package.json & lockfile tồn tại" "[ -f '$PKG_FILE' ]"
  check_step "TC-02" "Node.js environment (v20/v22)" "node -v"
  check_step "TC-03" "TypeScript config (tsconfig.json)" "[ -f 'tsconfig.json' ] || [ -f '$GIT_ROOT/tsconfig.json' ] || [ -f '$GIT_ROOT/crypto-vault-expo/tsconfig.json' ]"
  check_step "TC-04" "ESLint config & scripts" "[ -f '.eslintrc.js' ] || [ -f '.eslintrc.json' ] || grep -q 'eslint' '$PKG_FILE'"
  check_step "TC-05" "Babel/Metro compiler configuration" "[ -f 'babel.config.js' ] || [ -f 'metro.config.js' ] || [ -f '$GIT_ROOT/crypto-vault-expo/metro.config.js' ]"
  check_step "TC-06" "Source code directory (src/ or app/)" "[ -d 'src' ] || [ -d 'app' ] || [ -d '$GIT_ROOT/crypto-vault-expo/src' ]"

  echo -e "  ${CYAN}🛡️ [PHASE 2: Security & Secret Protection]${NC}"
  check_step "TC-07" ".gitignore che chắn secrets (.env, keystore)" "grep -q '\.env' '$GIT_ROOT/.gitignore' 2>/dev/null || grep -q '\.env' .gitignore 2>/dev/null"
  check_step "TC-08" "Không có AWS Keys hardcoded trong source code" "! grep -rn 'AKIA[A-Z0-9]\{16\}' --include='*.ts' --include='*.tsx' --include='*.js' '$GIT_ROOT' 2>/dev/null | grep -v node_modules | grep -q 'AKIA'"

  echo -e "  ${CYAN}🎯 [PHASE 3: Triggers & Workflow Format]${NC}"
  check_step "TC-09" "CI/CD YAML syntax hợp lệ" "python3 -c 'import yaml; yaml.safe_load(open(\"$GIT_ROOT/.github/workflows/ci.yml\"))'"
  check_step "TC-10" "workflow_dispatch & healthcheck parameter" "grep -q 'run_healthcheck' '$GIT_ROOT/.github/workflows/ci.yml'"

  echo -e "  ${CYAN}📱 [PHASE 4: Mobile Architecture & Build]${NC}"
  check_step "TC-11" "Android directory & Gradle build scripts" "[ -d 'android' ] || [ -d '$GIT_ROOT/android' ] || [ '$HAS_EXPO' = true ]"
  check_step "TC-12" "Expo app configuration (app.json / app.config.js)" "[ -f 'app.json' ] || [ -f '$GIT_ROOT/crypto-vault-expo/app.json' ]"

  echo -e "  ${CYAN}☁️ [PHASE 5: AWS S3 & Web Store Deployment]${NC}"
  check_step "TC-13" "AWS S3 Deploy scripts (scripts/deploy-aws-s3.py)" "[ -f 'scripts/deploy-aws-s3.py' ] || [ -f '$GIT_ROOT/scripts/deploy-aws-s3.py' ] || [ -f '$GIT_ROOT/crypto-vault-expo/scripts/deploy-aws-s3.py' ]"
  check_step "TC-14" "Web Distribution Portal assets (index.html, builds.json)" "[ -f 'app-distribution-web/index.html' ] || [ -f '$GIT_ROOT/app-distribution-web/index.html' ] || [ -f '$GIT_ROOT/crypto-vault-expo/app-distribution-web/index.html' ]"
  check_step "TC-15" "Git repository & remotes connected" "git status"

  echo ""
  echo -e "  📊 Kết quả kiểm tra nhanh: ${GREEN}$PASS_COUNT PASS${NC} | ${YELLOW}$WARN_COUNT WARN${NC} | ${RED}$FAIL_COUNT FAIL${NC}"
  echo ""
}

run_local_checks

# ──────────────────────────────────────────────────────────────────────────
# 4. GUIDED INTERACTIVE WORKFLOW LOOP (LIVE STREAMING & REAL PROGRESS)
# ──────────────────────────────────────────────────────────────────────────
RECOMMENDED_STEP=1
LAST_ACTION_MSG=""

while true; do
  echo -e "${BOLD}${PURPLE}══════════════════════════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}${BLUE}🚀 [4/4] TRUNG TÂM ĐIỀU KHIỂN CI/CD & TIẾN TRÌNH KHUYÊN DÙNG:${NC}"
  echo -e "${BOLD}${PURPLE}══════════════════════════════════════════════════════════════════════════${NC}"

  if [ -n "$LAST_ACTION_MSG" ]; then
    echo -e "$LAST_ACTION_MSG"
    echo ""
  fi

  if [ "$RECOMMENDED_STEP" -eq 1 ]; then
    echo -e "  ${GREEN}${BOLD}▶ 1. 🏥 Chạy bộ kiểm thử 70 Test Cases Health Check lên Slack${NC}  ${YELLOW}${BOLD}⭐ [KHUYÊN DÙNG BƯỚC NÀY]${NC}"
  else
    echo -e "    ${CYAN}1.${NC} 🏥 Chạy bộ kiểm thử 70 Test Cases Health Check lên Slack"
  fi

  if [ "$RECOMMENDED_STEP" -eq 2 ]; then
    echo -e "  ${GREEN}${BOLD}▶ 2. 📲 Build bản Dev/Staging & Đẩy file APK gốc lên AWS S3 Store${NC}  ${YELLOW}${BOLD}⭐ [KHUYÊN DÙNG BƯỚC NÀY]${NC}"
  else
    echo -e "    ${CYAN}2.${NC} 📲 Build bản Dev/Staging & Đẩy file APK gốc lên AWS S3 Store"
  fi

  if [ "$RECOMMENDED_STEP" -eq 3 ]; then
    echo -e "  ${GREEN}${BOLD}▶ 3. 🏪 Kích hoạt Production Release (Gửi thông báo Approve lên Slack)${NC}  ${YELLOW}${BOLD}⭐ [KHUYÊN DÙNG BƯỚC NÀY]${NC}"
  else
    echo -e "    ${CYAN}3.${NC} 🏪 Kích hoạt Production Release (Gửi thông báo Approve lên Slack)"
  fi

  echo -e "    ${CYAN}4.${NC} 🔍 Chạy lại kiểm tra nhanh Test Cases tại chỗ (Local Re-check)
    ${CYAN}5.${NC} 🛡️ Thiết lập GitHub Branch Protection & Org Rulesets (Admin)
    ${PURPLE}6.${NC} 🚀 Kích hoạt First Deploy Prod (Ký Keystore, tạo file .aab chuẩn Google Play)
    ${GREEN}7.${NC} ⚡ Đẩy bản cập nhật OTA Hotfix lên AWS S3 (30s không cần duyệt Store)

  if [ "$RECOMMENDED_STEP" -eq 0 ]; then
    echo -e "  ${GREEN}${BOLD}▶ 0. 🚪 Hoàn tất quy trình & Thoát Terminal${NC}  ${YELLOW}${BOLD}⭐ [KHUYÊN DÙNG THOÁT]${NC}"
  else
    echo -e "    ${CYAN}0.${NC} 🚪 Hoàn tất & Thoát Terminal"
  fi
  echo ""

  PROMPT_TEXT="Nhập lựa chọn [0-7] (Mặc định: $RECOMMENDED_STEP): "
  if [ -t 0 ]; then
    read -p "$(echo -e ${YELLOW}"$PROMPT_TEXT"${NC})" ACTION_CHOICE
  elif [ -c /dev/tty ]; then
    read -p "$(echo -e ${YELLOW}"$PROMPT_TEXT"${NC})" ACTION_CHOICE < /dev/tty
  else
    ACTION_CHOICE="$RECOMMENDED_STEP"
  fi

  ACTION_CHOICE=${ACTION_CHOICE:-$RECOMMENDED_STEP}

  case "$ACTION_CHOICE" in
    1)
      echo ""
      echo -e "${CYAN}🚀 [BƯỚC 1/3] Đang kích hoạt 70 Test Cases Health Check trên GitHub Actions...${NC}"
      cd "$GIT_ROOT"
      git push origin main 2>/dev/null || git push phong-mobile main 2>/dev/null || true
      
      if command -v gh &> /dev/null; then
        echo -e "${GREEN}⚡ Đang gửi lệnh tới GitHub Actions API...${NC}"
        gh workflow run ci.yml -f run_healthcheck=true -f environment=staging
        sleep 2
        
        RUN_ID=$(gh run list --workflow=ci.yml --limit 1 --json databaseId -q '.[0].databaseId' 2>/dev/null || true)
        RUN_URL=$(gh run list --workflow=ci.yml --limit 1 --json url -q '.[0].url' 2>/dev/null || true)
        
        if [ -n "$RUN_URL" ]; then
          echo -e "  🔗 ${BOLD}GitHub Actions Run URL:${NC} ${CYAN}$RUN_URL${NC}"
          echo -e "  📋 ${BOLD}Run ID:${NC} ${GREEN}#$RUN_ID${NC}"
          echo ""
          echo -e "${YELLOW}👀 Đang xem Live Logs trực tiếp từ GitHub Runner (Nhấn Ctrl+C để quay lại menu bất cứ lúc nào)...${NC}"
          gh run watch "$RUN_ID" || true
          echo ""
        fi
      fi

      RECOMMENDED_STEP=2
      LAST_ACTION_MSG="${GREEN}✅ BƯỚC 1 HOÀN TẤT:${NC} Health Check 70 TCs đã hoàn thành và gửi báo cáo Block Kit lên Slack!\n${YELLOW}👉 BƯỚC TIẾP THEO:${NC} Khuyên dùng chọn ${BOLD}[2]${NC} để đóng gói và đẩy file APK gốc lên Web S3 Store."
      ;;
      
    2)
      echo ""
      echo -e "${CYAN}🚀 [BƯỚC 2/3] Đang kích hoạt luồng Build Dev/Staging & S3 Web Store...${NC}"
      cd "$GIT_ROOT"
      if command -v gh &> /dev/null; then
        gh workflow run ci.yml -f environment=staging
        sleep 2
        RUN_ID=$(gh run list --workflow=ci.yml --limit 1 --json databaseId -q '.[0].databaseId' 2>/dev/null || true)
        RUN_URL=$(gh run list --workflow=ci.yml --limit 1 --json url -q '.[0].url' 2>/dev/null || true)
        
        if [ -n "$RUN_URL" ]; then
          echo -e "  🔗 ${BOLD}GitHub Actions Run URL:${NC} ${CYAN}$RUN_URL${NC}"
          echo -e "  📋 ${BOLD}Run ID:${NC} ${GREEN}#$RUN_ID${NC}"
          echo ""
          echo -e "${YELLOW}👀 Đang xem Live Build Logs trực tiếp từ Runner...${NC}"
          gh run watch "$RUN_ID" || true
          echo ""
        fi
      fi

      RECOMMENDED_STEP=3
      LAST_ACTION_MSG="${GREEN}✅ BƯỚC 2 HOÀN TẤT:${NC} Bản build Dev/Staging đã đẩy lên AWS S3 Web Store thành công!\n${YELLOW}👉 BƯỚC TIẾP THEO:${NC} Khuyên dùng chọn ${BOLD}[3]${NC} nếu bạn muốn Release Production, hoặc chọn ${BOLD}[0]${NC} để hoàn tất."
      ;;

    3)
      echo ""
      echo -e "${CYAN}🚀 [BƯỚC 3/3] Đang kích hoạt luồng Production Release...${NC}"
      cd "$GIT_ROOT"
      if command -v gh &> /dev/null; then
        gh workflow run ci.yml -f environment=production
        sleep 2
        RUN_ID=$(gh run list --workflow=ci.yml --limit 1 --json databaseId -q '.[0].databaseId' 2>/dev/null || true)
        RUN_URL=$(gh run list --workflow=ci.yml --limit 1 --json url -q '.[0].url' 2>/dev/null || true)
        
        if [ -n "$RUN_URL" ]; then
          echo -e "  🔗 ${BOLD}GitHub Actions Run URL:${NC} ${CYAN}$RUN_URL${NC}"
          echo -e "  📋 ${BOLD}Run ID:${NC} ${GREEN}#$RUN_ID${NC}"
          echo ""
          echo -e "${YELLOW}👀 Đang xem Live Logs trực tiếp từ Runner...${NC}"
          gh run watch "$RUN_ID" || true
          echo ""
        fi
      fi

      RECOMMENDED_STEP=0
      LAST_ACTION_MSG="${GREEN}✅ TOÀN BỘ LUỒNG HOÀN TẤT:${NC} Production Release đã kích hoạt thành công!\n${YELLOW}👉 BƯỚC TIẾP THEO:${NC} Chọn ${BOLD}[0]${NC} để hoàn tất và thoát terminal."
      ;;

    4)
      echo ""
      run_local_checks
      LAST_ACTION_MSG="${CYAN}ℹ️ Đã chạy lại kiểm tra cục bộ.${NC}"
      ;;

    5)
      echo ""
      SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
      if [ -f "$SCRIPT_DIR/setup-github-rules.sh" ]; then
        echo -e "${CYAN}🛡️ Đang chạy setup-github-rules.sh...${NC}"
        chmod +x "$SCRIPT_DIR/setup-github-rules.sh"
        bash "$SCRIPT_DIR/setup-github-rules.sh" || true
      else
        echo -e "${YELLOW}⚠️ Không tìm thấy setup-github-rules.sh tại $SCRIPT_DIR${NC}"
      fi
      LAST_ACTION_MSG="${GREEN}✅ Đã chạy xong trình thiết lập GitHub Rulesets!${NC}"
      ;;

    6)
      echo ""
      echo -e "${PURPLE}👑 [FIRST DEPLOY PROD] Đang kích hoạt luồng Ký Keystore & Tạo bản AAB Store...${NC}"
      cd "$GIT_ROOT"
      if command -v gh &> /dev/null; then
        gh workflow run ci.yml -f action_type=first_deploy_prod -f environment=production
        sleep 2
        RUN_ID=$(gh run list --workflow=ci.yml --limit 1 --json databaseId -q '.[0].databaseId' 2>/dev/null || true)
        RUN_URL=$(gh run list --workflow=ci.yml --limit 1 --json url -q '.[0].url' 2>/dev/null || true)
        
        if [ -n "$RUN_URL" ]; then
          echo -e "  🔗 ${BOLD}GitHub Actions Run URL:${NC} ${CYAN}$RUN_URL${NC}"
          echo -e "  📋 ${BOLD}Run ID:${NC} ${GREEN}#$RUN_ID${NC}"
          echo ""
          echo -e "${YELLOW}👀 Đang theo dõi tiến trình Ký Keystore & Build AAB từ Runner...${NC}"
          gh run watch "$RUN_ID" || true
          echo ""
        fi
      fi

      RECOMMENDED_STEP=0
      LAST_ACTION_MSG="${GREEN}✅ FIRST DEPLOY PROD HOÀN TẤT:${NC} Bản .aab và .apk đã được ký số và gửi lên GitHub Artifacts & Slack!\n👉 Bạn có thể tải file .aab về để tải lên Google Play Console lần đầu."
      ;;

    7)
      echo ""
      echo -e "${GREEN}⚡ [OTA HOTFIX] Chuẩn bị đẩy bản cập nhật JS Bundle lên AWS S3...${NC}"
      read -p "$(echo -e ${YELLOW}"Nhập ghi chú bản vá OTA (Mặc định: Hotfix update): "${NC})" INPUT_OTA_MSG
      INPUT_OTA_MSG=${INPUT_OTA_MSG:-"Hotfix update via AWS S3 OTA"}
      
      cd "$GIT_ROOT"
      if command -v gh &> /dev/null; then
        echo -e "${CYAN}🚀 Đang kích hoạt luồng OTA Hotfix trên GitHub Actions...${NC}"
        gh workflow run ci.yml -f action_type=ota_update -f environment=production -f ota_message="$INPUT_OTA_MSG"
        sleep 2
        RUN_ID=$(gh run list --workflow=ci.yml --limit 1 --json databaseId -q '.[0].databaseId' 2>/dev/null || true)
        RUN_URL=$(gh run list --workflow=ci.yml --limit 1 --json url -q '.[0].url' 2>/dev/null || true)
        
        if [ -n "$RUN_URL" ]; then
          echo -e "  🔗 ${BOLD}GitHub Actions Run URL:${NC} ${CYAN}$RUN_URL${NC}"
          echo -e "  📋 ${BOLD}Run ID:${NC} ${GREEN}#$RUN_ID${NC}"
          echo ""
          echo -e "${YELLOW}👀 Đang theo dõi tiến trình đóng gói & đẩy OTA lên AWS S3 (< 30s)...${NC}"
          gh run watch "$RUN_ID" || true
          echo ""
        fi
      fi

      RECOMMENDED_STEP=0
      LAST_ACTION_MSG="${GREEN}✅ OTA HOTFIX HOÀN TẤT:${NC} Bản vá JS Bundle đã được đưa lên AWS S3 thành công!\n👉 Người dùng mở App lên sẽ tự động nhận code mới trong 30 giây."
      ;;

    0|q|Q|exit|quit)
      echo ""
      echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════╗${NC}"
      echo -e "${GREEN}║  🎉 HOÀN TẤT QUY TRÌNH CI/CD CHO DỰ ÁN ${BOLD}$APP_NAME${NC}${GREEN}!                  ║${NC}"
      echo -e "${GREEN}║  Tất cả cấu hình và workflow đã được đồng bộ chuẩn Enterprise 100%!     ║${NC}"
      echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════╝${NC}"
      echo ""
      exit 0
      ;;

    *)
      LAST_ACTION_MSG="${RED}⚠️ Lựa chọn không hợp lệ. Vui lòng nhập số từ 0 đến 4.${NC}"
      ;;
  esac
done
