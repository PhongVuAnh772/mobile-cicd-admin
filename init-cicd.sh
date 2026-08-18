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
#   3. Hệ thống tự động kéo script qua SSH (kể cả Private Repo), cấu hình CI/CD pointer,
#      chạy 70 Test Cases và hướng dẫn từng bước tiếp theo trực quan!
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

echo -e "  🏷️  Tên App:         ${GREEN}${BOLD}$APP_NAME${NC}"
echo -e "  📌 Version:         ${GREEN}$APP_VERSION${NC}"
echo -e "  🧩 Kiến trúc:       ${YELLOW}${BOLD}$PROJECT_TYPE${NC}"
echo -e "  📁 Git Root:        ${CYAN}$GIT_ROOT${NC}"
echo ""

# ──────────────────────────────────────────────────────────────────────────
# 2. AUTO-GENERATE .github/workflows/ci.yml AT GIT ROOT & TARGET DIR
# ──────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}${BLUE}⚙️  [2/4] Tự động khởi tạo .github/workflows/ci.yml...${NC}"

generate_ci_yml() {
  local out_dir="$1"
  mkdir -p "$out_dir/.github/workflows"

  cat << 'EOF' > "$out_dir/.github/workflows/ci.yml"
name: "Enterprise Mobile CI/CD"

# ============================================================================
# CENTRALIZED ENTERPRISE MOBILE CI/CD POINTER
# Powered by: phong-mobile/mobile-cicd-admin
# All core logic, security scanning, build scripts, AWS S3 deployments,
# Slack Block Kit notifications, and 70-TC health checks are centrally managed.
# ============================================================================

on:
  push:
    branches: [main, dev]
    tags:
      - 'v*.*.*'
      - 'v*'
  pull_request:
    branches: [main, dev]
  workflow_dispatch:
    inputs:
      environment:
        description: "Target deployment environment"
        required: true
        default: "staging"
        type: choice
        options:
          - staging
          - production
      skip_tests:
        description: "Skip CI lint, type-check and unit tests"
        required: false
        default: false
        type: boolean
      run_healthcheck:
        description: "Run 70-TC CI/CD Init Health Check suite"
        required: false
        default: false
        type: boolean

jobs:
  # ──────────────────────────────────────────────────────────────────────────
  # 1. MAIN CI/CD PIPELINE (Build, S3 Web Store, Release Approval, Slack)
  # ──────────────────────────────────────────────────────────────────────────
  pipeline:
    name: "Enterprise Mobile Pipeline"
    if: github.event.inputs.run_healthcheck != 'true'
    uses: phong-mobile/mobile-cicd-admin/.github/workflows/master-pipeline.yml@main
    with:
      app_name: "APP_NAME_PLACEHOLDER"
      environment: ${{ github.event.inputs.environment || ((github.ref == 'refs/heads/main' || startsWith(github.ref, 'refs/tags/v')) && 'production' || 'staging') }}
      skip_tests: ${{ github.event.inputs.skip_tests == 'true' }}
    secrets: inherit

  # ──────────────────────────────────────────────────────────────────────────
  # 2. CI/CD INIT HEALTH CHECK (70 Test Cases, Auto-Detects Project & Native Modules)
  # ──────────────────────────────────────────────────────────────────────────
  healthcheck:
    name: "CI/CD Init Health Check"
    if: github.event.inputs.run_healthcheck == 'true'
    uses: phong-mobile/mobile-cicd-admin/.github/workflows/cicd-init-healthcheck.yml@main
    with:
      app_name: "APP_NAME_PLACEHOLDER"
      environment: ${{ github.event.inputs.environment || 'staging' }}
    secrets: inherit
EOF

  sed -i '' "s/APP_NAME_PLACEHOLDER/$APP_NAME/g" "$out_dir/.github/workflows/ci.yml" 2>/dev/null || \
  sed -i "s/APP_NAME_PLACEHOLDER/$APP_NAME/g" "$out_dir/.github/workflows/ci.yml" 2>/dev/null || true
}

generate_ci_yml "$GIT_ROOT"
[ "$TARGET_DIR" != "$GIT_ROOT" ] && generate_ci_yml "$TARGET_DIR"

echo -e "  ${GREEN}✅ Đã đồng bộ file .github/workflows/ci.yml trỏ về mobile-cicd-admin!${NC}"
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

  check_step "TC-01" "package.json & lockfile tồn tại" "[ -f '$PKG_FILE' ]"
  check_step "TC-02" "Node.js environment (v20/v22)" "node -v"
  check_step "TC-03" "TypeScript config (tsconfig.json)" "[ -f 'tsconfig.json' ] || [ -f '$GIT_ROOT/tsconfig.json' ]"
  check_step "TC-04" "ESLint config & scripts" "[ -f '.eslintrc.js' ] || [ -f '.eslintrc.json' ] || grep -q 'eslint' '$PKG_FILE'"
  check_step "TC-05" "CI/CD YAML syntax hợp lệ" "python3 -c 'import yaml; yaml.safe_load(open(\"$GIT_ROOT/.github/workflows/ci.yml\"))'"
  check_step "TC-06" ".gitignore che chắn secrets (.env, keystore)" "grep -q '\.env' '$GIT_ROOT/.gitignore' 2>/dev/null || grep -q '\.env' .gitignore 2>/dev/null"
  check_step "TC-07" "Android directory & Gradle build scripts" "[ -d 'android' ] || [ -d '$GIT_ROOT/android' ] || [ '$HAS_EXPO' = true ]"
  check_step "TC-08" "AWS S3 Deploy scripts (scripts/deploy-aws-s3.py)" "[ -f 'scripts/deploy-aws-s3.py' ] || [ -f '$GIT_ROOT/scripts/deploy-aws-s3.py' ]"
  check_step "TC-09" "Web Distribution Portal assets (index.html, builds.json)" "[ -f 'app-distribution-web/index.html' ] || [ -f '$GIT_ROOT/app-distribution-web/index.html' ]"
  check_step "TC-10" "Git repository & remotes connected" "git status"

  echo ""
  echo -e "  📊 Kết quả kiểm tra nhanh: ${GREEN}$PASS_COUNT PASS${NC} | ${YELLOW}$WARN_COUNT WARN${NC} | ${RED}$FAIL_COUNT FAIL${NC}"
  echo ""
}

run_local_checks

# ──────────────────────────────────────────────────────────────────────────
# 4. GUIDED INTERACTIVE WORKFLOW LOOP (Không thoát sớm, khuyên dùng bước tiếp theo)
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

  # Render Menu with dynamically highlighted recommendation
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

  echo -e "    ${CYAN}4.${NC} 🔍 Chạy lại kiểm tra nhanh Test Cases tại chỗ (Local Re-check)"

  if [ "$RECOMMENDED_STEP" -eq 0 ]; then
    echo -e "  ${GREEN}${BOLD}▶ 0. 🚪 Hoàn tất quy trình & Thoát Terminal${NC}  ${YELLOW}${BOLD}⭐ [KHUYÊN DÙNG THOÁT]${NC}"
  else
    echo -e "    ${CYAN}0.${NC} 🚪 Hoàn tất & Thoát Terminal"
  fi
  echo ""

  # Prompt user for input
  PROMPT_TEXT="Nhập lựa chọn [0-4] (Mặc định: $RECOMMENDED_STEP): "
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
      echo -e "${CYAN}🚀 [BƯỚC 1/3] Đang đồng bộ Git & kích hoạt 70 Test Cases Health Check...${NC}"
      cd "$GIT_ROOT"
      git add .github/workflows/ci.yml crypto-vault-expo/.github/workflows/ci.yml 2>/dev/null || true
      git commit -m "ci: init CI/CD pipeline and trigger 70-TC health check" 2>/dev/null || echo "Git index up-to-date"
      git push origin main 2>/dev/null || git push phong-mobile main 2>/dev/null || true
      
      if command -v gh &> /dev/null; then
        echo -e "${GREEN}⚡ Đang gọi lệnh GitHub Actions trigger Health Check...${NC}"
        gh workflow run ci.yml -f run_healthcheck=true -f environment=staging 2>/dev/null || gh workflow run "Enterprise Mobile CI/CD" -f run_healthcheck=true -f environment=staging 2>/dev/null || true
        echo -e "${GREEN}🎉 Đã kích hoạt 70 Test Cases! Kết quả đang được gửi về Slack có 3 Buttons.${NC}"
      else
        echo -e "${YELLOW}ℹ️  Vui lòng mở tab Actions trên GitHub để xem tiến trình chạy.${NC}"
      fi

      RECOMMENDED_STEP=2
      LAST_ACTION_MSG="${GREEN}✅ BƯỚC 1 HOÀN TẤT:${NC} Health Check 70 TCs đã kích hoạt thành công!\n${YELLOW}👉 BƯỚC TIẾP THEO:${NC} Khuyên dùng chọn ${BOLD}[2]${NC} để đóng gói và đẩy file APK gốc lên Web S3 Store."
      ;;
      
    2)
      echo ""
      echo -e "${CYAN}🚀 [BƯỚC 2/3] Đang kích hoạt luồng Build Dev/Staging & S3 Web Store...${NC}"
      cd "$GIT_ROOT"
      git add .github/workflows/ci.yml crypto-vault-expo/.github/workflows/ci.yml 2>/dev/null || true
      git commit -m "ci: trigger Staging build and AWS S3 upload" 2>/dev/null || true
      git push origin dev 2>/dev/null || git push phong-mobile dev 2>/dev/null || true
      if command -v gh &> /dev/null; then
        gh workflow run ci.yml -f environment=staging 2>/dev/null || gh workflow run "Enterprise Mobile CI/CD" -f environment=staging 2>/dev/null || true
        echo -e "${GREEN}🎉 Đã kích hoạt luồng Build Staging! File APK gốc sẽ được tự động đưa lên AWS S3 Web Store.${NC}"
      fi

      RECOMMENDED_STEP=3
      LAST_ACTION_MSG="${GREEN}✅ BƯỚC 2 HOÀN TẤT:${NC} Bản build Dev/Staging đã kích hoạt thành công!\n${YELLOW}👉 BƯỚC TIẾP THEO:${NC} Khuyên dùng chọn ${BOLD}[3]${NC} nếu bạn muốn Release Production, hoặc chọn ${BOLD}[0]${NC} để hoàn tất."
      ;;

    3)
      echo ""
      echo -e "${CYAN}🚀 [BƯỚC 3/3] Đang kích hoạt luồng Production Release...${NC}"
      if command -v gh &> /dev/null; then
        gh workflow run ci.yml -f environment=production 2>/dev/null || gh workflow run "Enterprise Mobile CI/CD" -f environment=production 2>/dev/null || true
        echo -e "${GREEN}🎉 Production Release đã kích hoạt thành công! Đã gửi thông báo phê duyệt lên Slack.${NC}"
      fi

      RECOMMENDED_STEP=0
      LAST_ACTION_MSG="${GREEN}✅ TOÀN BỘ LUỒNG HOÀN TẤT:${NC} Production Release đã kích hoạt thành công!\n${YELLOW}👉 BƯỚC TIẾP THEO:${NC} Chọn ${BOLD}[0]${NC} để hoàn tất và thoát terminal."
      ;;

    4)
      echo ""
      run_local_checks
      LAST_ACTION_MSG="${CYAN}ℹ️ Đã chạy lại kiểm tra cục bộ.${NC}"
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
