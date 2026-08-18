#!/bin/bash
# ============================================================================
# 🚀 ENTERPRISE MOBILE CI/CD & RELEASE ENGINE - SETUP SCRIPT
# ============================================================================
# Script tự động cài đặt hệ thống CI/CD hoàn chỉnh cho mọi dự án Mobile.
# Hỗ trợ: React Native, Flutter, iOS Native, Android Native.
#
# Cách sử dụng:
#   chmod +x setup.sh
#   ./setup.sh
# ============================================================================

set -e

# ── Màu sắc Terminal ────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  🚀 ENTERPRISE MOBILE CI/CD & RELEASE ENGINE - SETUP       ║${NC}"
echo -e "${CYAN}║  Chuẩn Gold Standard cho Mobile App Production              ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ── Thu thập thông tin dự án ─────────────────────────────────────────────────
echo -e "${BOLD}📋 Nhập thông tin dự án:${NC}"
echo ""

read -p "$(echo -e ${YELLOW}Tên dự án \(VD: MyAwesomeApp\): ${NC})" PROJECT_NAME
if [ -z "$PROJECT_NAME" ]; then
  echo -e "${RED}❌ Tên dự án không được để trống!${NC}"
  exit 1
fi

read -p "$(echo -e ${YELLOW}Bundle ID iOS \(VD: com.company.myapp\): ${NC})" BUNDLE_ID_IOS
BUNDLE_ID_IOS=${BUNDLE_ID_IOS:-"com.company.${PROJECT_NAME,,}"}

read -p "$(echo -e ${YELLOW}Package Name Android \(VD: com.company.myapp\): ${NC})" PACKAGE_NAME_ANDROID
PACKAGE_NAME_ANDROID=${PACKAGE_NAME_ANDROID:-"$BUNDLE_ID_IOS"}

read -p "$(echo -e ${YELLOW}Tiền tố Jira Ticket \(VD: PAS, MOBILE, CRYPTO\): ${NC})" JIRA_PREFIX
JIRA_PREFIX=${JIRA_PREFIX:-"PAS"}

read -p "$(echo -e ${YELLOW}AWS S3 Region \(VD: ap-southeast-1\): ${NC})" AWS_REGION
AWS_REGION=${AWS_REGION:-"ap-southeast-1"}

read -p "$(echo -e ${YELLOW}AWS S3 Bucket Name \(VD: my-company-mobile-builds\): ${NC})" AWS_S3_BUCKET
AWS_S3_BUCKET=${AWS_S3_BUCKET:-"my-company-mobile-builds"}

read -p "$(echo -e ${YELLOW}Nhánh chính \(main / master\): ${NC})" MAIN_BRANCH
MAIN_BRANCH=${MAIN_BRANCH:-"main"}

read -p "$(echo -e ${YELLOW}Node.js version \(18 / 20\): ${NC})" NODE_VERSION
NODE_VERSION=${NODE_VERSION:-"20"}

read -p "$(echo -e ${YELLOW}Xcode version \(15.4 / 16.0\): ${NC})" XCODE_VERSION
XCODE_VERSION=${XCODE_VERSION:-"16.0"}

read -p "$(echo -e ${YELLOW}Đường dẫn thư mục đích cài đặt \(VD: /path/to/my-project hoặc . cho thư mục hiện tại\): ${NC})" TARGET_DIR
TARGET_DIR=${TARGET_DIR:-"."}

# Resolve relative path
TARGET_DIR=$(cd "$TARGET_DIR" 2>/dev/null && pwd || echo "$TARGET_DIR")

echo ""
echo -e "${BOLD}📌 Xác nhận cấu hình:${NC}"
echo -e "  Tên dự án:       ${GREEN}$PROJECT_NAME${NC}"
echo -e "  Bundle ID (iOS):  ${GREEN}$BUNDLE_ID_IOS${NC}"
echo -e "  Package (Android):${GREEN}$PACKAGE_NAME_ANDROID${NC}"
echo -e "  Jira Prefix:      ${GREEN}[$JIRA_PREFIX-XXXX]${NC}"
echo -e "  AWS Region:       ${GREEN}$AWS_REGION${NC}"
echo -e "  AWS S3 Bucket:    ${GREEN}$AWS_S3_BUCKET${NC}"
echo -e "  Nhánh chính:      ${GREEN}$MAIN_BRANCH${NC}"
echo -e "  Node.js:          ${GREEN}$NODE_VERSION${NC}"
echo -e "  Xcode:            ${GREEN}$XCODE_VERSION${NC}"
echo -e "  Thư mục đích:     ${GREEN}$TARGET_DIR${NC}"
echo ""

read -p "$(echo -e ${YELLOW}Xác nhận và tiến hành cài đặt? \(y/N\): ${NC})" CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo -e "${RED}❌ Đã hủy cài đặt.${NC}"
  exit 0
fi

# ── Xác định đường dẫn template ─────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/templates"

if [ ! -d "$TEMPLATE_DIR" ]; then
  echo -e "${RED}❌ Không tìm thấy thư mục templates/ tại: $TEMPLATE_DIR${NC}"
  exit 1
fi

# ── Xoá .github cũ (nếu có) ─────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}🗑️  Xóa thư mục .github cũ (nếu có)...${NC}"
rm -rf "$TARGET_DIR/.github"

# ── Copy toàn bộ templates ──────────────────────────────────────────────────
echo -e "${CYAN}📂 Sao chép template CI/CD vào dự án...${NC}"

# Copy .github/
cp -R "$SCRIPT_DIR/.github" "$TARGET_DIR/.github"

# Copy config files
cp "$TEMPLATE_DIR/.gitleaks.toml" "$TARGET_DIR/.gitleaks.toml" 2>/dev/null || true
cp "$TEMPLATE_DIR/Dangerfile.ts" "$TARGET_DIR/Dangerfile.ts" 2>/dev/null || true
cp "$TEMPLATE_DIR/release.config.js" "$TARGET_DIR/release.config.js" 2>/dev/null || true

# Copy Automated Rules Setup Script
if [ -f "$SCRIPT_DIR/setup-github-rules.sh" ]; then
  cp "$SCRIPT_DIR/setup-github-rules.sh" "$TARGET_DIR/setup-github-rules.sh"
  chmod +x "$TARGET_DIR/setup-github-rules.sh"
fi

# Copy Feature Flags Manager
mkdir -p "$TARGET_DIR/src/config" "$TARGET_DIR/src/__tests__"
cp "$TEMPLATE_DIR/src/config/featureFlags.json" "$TARGET_DIR/src/config/featureFlags.json" 2>/dev/null || true
cp "$TEMPLATE_DIR/src/featureFlags.js" "$TARGET_DIR/src/featureFlags.js" 2>/dev/null || true
cp "$TEMPLATE_DIR/src/__tests__/featureFlags.test.js" "$TARGET_DIR/src/__tests__/featureFlags.test.js" 2>/dev/null || true

# Copy iOS files
mkdir -p "$TARGET_DIR/ios/fastlane"
cp "$TEMPLATE_DIR/ios/PrivacyInfo.xcprivacy" "$TARGET_DIR/ios/PrivacyInfo.xcprivacy" 2>/dev/null || true
cp "$TEMPLATE_DIR/ios/fastlane/Fastfile" "$TARGET_DIR/ios/fastlane/Fastfile" 2>/dev/null || true

# Copy Android files
mkdir -p "$TARGET_DIR/android/fastlane"
cp "$TEMPLATE_DIR/android/fastlane/Fastfile" "$TARGET_DIR/android/fastlane/Fastfile" 2>/dev/null || true

# ── Thay thế placeholder bằng giá trị thực ──────────────────────────────────
echo -e "${CYAN}🔧 Thay thế placeholder bằng cấu hình dự án...${NC}"

replace_placeholders() {
  local file="$1"
  if [ -f "$file" ]; then
    sed -i '' \
      -e "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" \
      -e "s/{{BUNDLE_ID_IOS}}/$BUNDLE_ID_IOS/g" \
      -e "s/{{PACKAGE_NAME_ANDROID}}/$PACKAGE_NAME_ANDROID/g" \
      -e "s/{{JIRA_PREFIX}}/$JIRA_PREFIX/g" \
      -e "s/{{AWS_REGION}}/$AWS_REGION/g" \
      -e "s/{{AWS_S3_BUCKET}}/$AWS_S3_BUCKET/g" \
      -e "s/{{MAIN_BRANCH}}/$MAIN_BRANCH/g" \
      -e "s/{{NODE_VERSION}}/$NODE_VERSION/g" \
      -e "s/{{XCODE_VERSION}}/$XCODE_VERSION/g" \
      "$file" 2>/dev/null || true
  fi
}

find "$TARGET_DIR/.github" -type f | while read -r file; do
  replace_placeholders "$file"
done

replace_placeholders "$TARGET_DIR/.gitleaks.toml"
replace_placeholders "$TARGET_DIR/Dangerfile.ts"
replace_placeholders "$TARGET_DIR/release.config.js"
replace_placeholders "$TARGET_DIR/setup-github-rules.sh"
replace_placeholders "$TARGET_DIR/ios/fastlane/Fastfile"
replace_placeholders "$TARGET_DIR/android/fastlane/Fastfile"

# ── Hoàn tất ────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ CÀI ĐẶT HOÀN TẤT THÀNH CÔNG!                          ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}📂 Cấu trúc đã tạo tại: ${CYAN}$TARGET_DIR${NC}"
echo ""
echo -e "  .github/"
echo -e "  ├── CODEOWNERS"
echo -e "  ├── dependabot.yml"
echo -e "  ├── PULL_REQUEST_TEMPLATE.md"
echo -e "  ├── actions/notify/action.yml            📢 Slack/Teams Notification"
echo -e "  └── workflows/"
echo -e "      ├── 01-mr-governance.yml              🛡️ Quality Gates (Jest 80%, Gitleaks)"
echo -e "      ├── 02-e2e-preview-distribution.yml  📲 E2E & AWS S3 Ad-Hoc QR Code"
echo -e "      ├── 03a-first-release-build.yml        🆕 Lần đầu lên Store (Thủ công)"
echo -e "      ├── 03b-update-release-build.yml       🔄 Cập nhật định kỳ (Tag v*)"
echo -e "      ├── 04-store-deployment.yml           🏪 Fastlane Snapshot & Rollout 1%"
echo -e "      ├── 05-telemetry-auto-pause-hotfix.yml 🚨 Telemetry, OTA Hotfix, Rollback"
echo -e "      ├── 06-white-label-matrix.yml         🏭 White-Label Build Matrix"
echo -e "      └── 07-cert-expiration-monitor.yml     📅 Giám sát hạn chứng chỉ iOS/Android"
echo -e "  .gitleaks.toml"
echo -e "  Dangerfile.ts"
echo -e "  release.config.js"
echo -e "  setup-github-rules.sh                      🏛️ Automated Ruleset & Teams Setup"
echo -e "  src/featureFlags.js                        🚩 Feature Flag Manager (DJB2 Hash)"
echo -e "  src/config/featureFlags.json               🚩 Feature Flag Schema"
echo -e "  src/__tests__/featureFlags.test.js        🧪 Unit Tests (Coverage 100%)"
echo -e "  ios/PrivacyInfo.xcprivacy"
echo -e "  ios/fastlane/Fastfile                      (first_release + update_release + adhoc_aws)"
echo -e "  android/fastlane/Fastfile                  (first_release + update_release)"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}🎯 HƯỚNG DẪN SỬ DỤNG — CHỌN ĐÚNG LUỒNG:${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${RED}📌 APP CHƯA LÊN STORE LẦN NÀO?${NC}"
echo -e "  ──────────────────────────────"
echo -e "  1. Vào GitHub Actions ➔ Chạy thủ công: ${GREEN}03a-first-release-build.yml${NC}"
echo -e "  2. Workflow sẽ: Tạo Certificate mới → Build → Upload TOÀN BỘ"
echo -e "     (Binary + Metadata + Screenshots + dSYM/Mapping)"
echo -e "  3. ${YELLOW}⚠️ KHÔNG tự submit${NC} — Vào Store Console kiểm tra thủ công trước"
echo -e "  4. Điền Demo Account, Privacy Form, Data Safety ➔ Bấm Submit"
echo -e ""
echo -e "  ${GREEN}📌 APP ĐÃ CÓ TRÊN STORE? (Bản cập nhật)${NC}"
echo -e "  ──────────────────────────────"
echo -e "  1. Release Manager push Protected Tag: ${GREEN}git tag v1.0.0 && git push origin v1.0.0${NC}"
echo -e "  2. Workflow tự động kích hoạt: ${GREEN}03b-update-release-build.yml${NC}"
echo -e "  3. Yêu cầu ${YELLOW}Dual Approval${NC} từ Environment: production (Tech Lead + Release Mgr)"
echo -e "  4. Fastlane ký số → Upload Store → Phased Rollout 1% ➔ 100%"
echo -e "  5. Nếu Crash Rate tăng ➔ ${GREEN}05-telemetry-auto-pause-hotfix.yml${NC} tự động dừng rollout"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Hỏi người dùng có muốn tự động chạy setup-github-rules.sh ngay không
if command -v gh &> /dev/null; then
  read -p "$(echo -e ${YELLOW}Bạn có muốn chạy ./setup-github-rules.sh để tự tạo Teams & Rulesets trên GitHub Org ngay bây giờ? \(y/N\): ${NC})" RUN_RULES
  if [[ "$RUN_RULES" == "y" || "$RUN_RULES" == "Y" ]]; then
    cd "$TARGET_DIR" && ./setup-github-rules.sh
  fi
fi

echo -e "${GREEN}🎉 Chúc mừng! Dự án ${BOLD}$PROJECT_NAME${NC}${GREEN} đã sẵn sàng với hệ thống CI/CD chuẩn Enterprise!${NC}"
echo ""
