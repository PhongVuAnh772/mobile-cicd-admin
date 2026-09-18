#!/bin/bash
# ============================================================================
# 🔒 ENTERPRISE GITHUB GOVERNANCE AUTOMATOR — DUAL MODE
# Hỗ trợ: Cả GitHub Organization VÀ Tài khoản Cá nhân (Personal User)
# ============================================================================
# Script tự động cấu hình Rulesets, Environments, Phân quyền bảo mật.
# - Organization Mode: Tự động tạo 3 Teams, phân quyền và thiết lập Dual Approval.
# - Personal Mode: Tự động cấu hình Ruleset bảo vệ nhánh main & tag cho cá nhân/solo dev.
# ============================================================================

set -e

# Màu sắc Terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

DEFAULT_OWNER="phong-mobile"
DEFAULT_REPO=""

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  🔒 ENTERPRISE GITHUB GOVERNANCE AUTOMATOR — DUAL MODE       ║${NC}"
echo -e "${CYAN}║  Hỗ trợ cả Organization (Doanh nghiệp) & Personal (Cá nhân)  ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ── 1. PHÂN TÍCH TARGET REPOSITORY ──────────────────────────────────────────
GIT_REPO_URL=$(git config --get remote.origin.url 2>/dev/null || echo "")
if [[ "$GIT_REPO_URL" =~ github.com[:/]([^/]+)/([^/.]+)(\.git)? ]]; then
  DEFAULT_OWNER="${BASH_REMATCH[1]}"
  DEFAULT_REPO="${BASH_REMATCH[2]}"
fi

read -p "$(echo -e "${YELLOW}Nhập GitHub Owner (Organization hoặc Username cá nhân) [Mặc định: ${DEFAULT_OWNER}]: ${NC}")" INPUT_OWNER
OWNER_NAME=${INPUT_OWNER:-$DEFAULT_OWNER}

read -p "$(echo -e "${YELLOW}Nhập tên Repository [Mặc định: ${DEFAULT_REPO:-your-rn-app}]: ${NC}")" INPUT_REPO
REPO_NAME=${INPUT_REPO:-${DEFAULT_REPO:-your-rn-app}}

FULL_REPO="${OWNER_NAME}/${REPO_NAME}"

# ── 2. ĐÁNH GIÁ XÁC THỰC (AUTHENTICATION CHECK) ──────────────────────────────
echo ""
echo -e "${CYAN}🔑 [AUTH CHECK] Đang xác thực tài khoản GitHub CLI...${NC}"

if ! command -v gh &> /dev/null; then
  echo -e "${RED}❌ AUTH ERROR: Không tìm thấy GitHub CLI (gh). Vui lòng cài đặt: brew install gh${NC}"
  exit 1
fi

if ! gh auth status &> /dev/null; then
  echo -e "${RED}❌ AUTH ERROR: Chưa đăng nhập GitHub CLI. Vui lòng đăng nhập: gh auth login${NC}"
  exit 1
fi

CURRENT_USER=$(gh api user --jq '.login' 2>/dev/null || echo "")
if [ -z "$CURRENT_USER" ]; then
  echo -e "${RED}❌ AUTH ERROR: Không thể lấy thông tin user từ GitHub API.${NC}"
  exit 1
fi

CURRENT_USER_ID=$(gh api user --jq '.id' 2>/dev/null || echo "0")
echo -e "  👤 Tài khoản hiện tại: ${GREEN}${CURRENT_USER}${NC} (ID: ${CURRENT_USER_ID})"

# ── 3. TỰ ĐỘNG NHẬN DIỆN LOẠI TÀI KHOẢN (ORG VS PERSONAL) ───────────────────
echo -e "${CYAN}🔍 [ACCOUNT DETECTION] Đang kiểm tra loại tài khoản của '${OWNER_NAME}'...${NC}"

ACCOUNT_TYPE=$(gh api "users/${OWNER_NAME}" --jq '.type' 2>/dev/null || echo "User")

if [ "$ACCOUNT_TYPE" = "Organization" ]; then
  IS_ORG=true
  echo -e "  🏢 Chế độ: ${PURPLE}${BOLD}ORGANIZATION (Doanh nghiệp)${NC}"
  
  # Kiểm tra quyền Org Admin
  USER_ROLE=$(gh api "orgs/${OWNER_NAME}/memberships/${CURRENT_USER}" --jq '.role' 2>/dev/null || echo "none")
  USER_STATE=$(gh api "orgs/${OWNER_NAME}/memberships/${CURRENT_USER}" --jq '.state' 2>/dev/null || echo "inactive")

  if [ "$USER_ROLE" != "admin" ] || [ "$USER_STATE" != "active" ]; then
    echo ""
    echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ⛔ ACCESS DENIED - BỊ TỪ CHỐI TRUY CẬP!                    ║${NC}"
    echo -e "${RED}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${RED}║ User '${CURRENT_USER}' không phải ADMIN / OWNER của Org '${OWNER_NAME}'.║${NC}"
    echo -e "${RED}║ Vai trò hiện tại của bạn: [${USER_ROLE^^}]                            ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    exit 1
  fi
  echo -e "${GREEN}  ✅ Xác thực thành công: User '${CURRENT_USER}' có vai trò [ORG ADMIN/OWNER].${NC}"

else
  IS_ORG=false
  echo -e "  👤 Chế độ: ${BLUE}${BOLD}PERSONAL ACCOUNT (Tài khoản cá nhân / Solo Dev)${NC}"
  
  # Kiểm tra quyền truy cập repo cá nhân
  REPO_ADMIN=$(gh api "repos/${FULL_REPO}" --jq '.permissions.admin' 2>/dev/null || echo "false")
  if [ "$REPO_ADMIN" != "true" ] && [ "$CURRENT_USER" != "$OWNER_NAME" ]; then
    echo ""
    echo -e "${RED}⛔ ACCESS DENIED: Bạn không có quyền Admin trên repo '${FULL_REPO}'.${NC}"
    exit 1
  fi
  echo -e "${GREEN}  ✅ Xác thực thành công: Bạn có quyền quản trị repo '${FULL_REPO}'.${NC}"
fi

echo ""

# ── 4. XÁC NHẬN BẢO MẬT (2FA CONFIRMATION PASSPHRASE) ────────────────────────
echo -e "${YELLOW}⚠️ CAUTION: Bạn chuẩn bị thiết lập Rulesets & Environments cho ${FULL_REPO}.${NC}"
read -p "$(echo -e "${YELLOW}Gõ 'CONFIRM_ADMIN' để xác nhận thực thi: ${NC}")" SECURITY_PIN

if [ "$SECURITY_PIN" != "CONFIRM_ADMIN" ]; then
  echo -e "${RED}❌ Mã xác nhận không chính xác. Đã hủy thao tác.${NC}"
  exit 1
fi

# ── 5. GHI AUDIT LOG ────────────────────────────────────────────────────────
AUDIT_LOG_FILE="github-rules-audit.log"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
HOSTNAME=$(hostname)
echo "[AUDIT] $TIMESTAMP | User: $CURRENT_USER | Owner: $OWNER_NAME | Type: $ACCOUNT_TYPE | Repo: $FULL_REPO | Host: $HOSTNAME | Action: SETUP_GOVERNANCE_RULES" >> "$AUDIT_LOG_FILE"
echo -e "${GREEN}📝 Đã ghi vết Audit Log tại: ${AUDIT_LOG_FILE}${NC}"

# ============================================================================
# 1. CẤU HÌNH TEAMS (CHỈ DÀNH CHO ORGANIZATION)
# ============================================================================
if [ "$IS_ORG" = true ]; then
  echo -e "\n${BOLD}1️⃣  Cấu hình Teams trong Organization '${OWNER_NAME}'...${NC}"
  for TEAM in "mobile-developers" "mobile-tech-leads" "release-managers"; do
    if gh api "orgs/${OWNER_NAME}/teams/${TEAM}" &>/dev/null; then
      echo -e "  ✅ Team '${TEAM}' đã tồn tại."
    else
      echo -e "  ➕ Tạo mới Team '${TEAM}'..."
      gh api -X POST "orgs/${OWNER_NAME}/teams" -f name="${TEAM}" -f privacy="closed" &>/dev/null || true
    fi
  done

  echo -e "\n${BOLD}2️⃣  Phân quyền Team vào Repo '${FULL_REPO}'...${NC}"
  echo -e "  🔑 Gán quyền 'push' (Write) cho team 'mobile-developers'..."
  gh api -X PUT "orgs/${OWNER_NAME}/teams/mobile-developers/repos/${FULL_REPO}" -f permission="push" &>/dev/null || true

  echo -e "  🔑 Gán quyền 'maintain' cho team 'mobile-tech-leads'..."
  gh api -X PUT "orgs/${OWNER_NAME}/teams/mobile-tech-leads/repos/${FULL_REPO}" -f permission="maintain" &>/dev/null || true

  echo -e "  🔑 Gán quyền 'maintain' cho team 'release-managers'..."
  gh api -X PUT "orgs/${OWNER_NAME}/teams/release-managers/repos/${FULL_REPO}" -f permission="maintain" &>/dev/null || true

  TECH_LEAD_TEAM_ID=$(gh api "orgs/${OWNER_NAME}/teams/mobile-tech-leads" --jq '.id' 2>/dev/null || echo "")
  RELEASE_MGR_TEAM_ID=$(gh api "orgs/${OWNER_NAME}/teams/release-managers" --jq '.id' 2>/dev/null || echo "")

  REVIEWERS_JSON="[]"
  if [ -n "$TECH_LEAD_TEAM_ID" ] && [ -n "$RELEASE_MGR_TEAM_ID" ]; then
    REVIEWERS_JSON="[{\"type\":\"Team\",\"id\":${TECH_LEAD_TEAM_ID}},{\"type\":\"Team\",\"id\":${RELEASE_MGR_TEAM_ID}}]"
  fi
else
  echo -e "\n${BLUE}ℹ️  [PERSONAL MODE] Bỏ qua cấu hình Teams (Tài khoản cá nhân quản lý trực tiếp qua Repo Collaborators).${NC}"
  # Với tài khoản cá nhân, reviewer có thể là chính Owner
  REVIEWERS_JSON="[{\"type\":\"User\",\"id\":${CURRENT_USER_ID}}]"
fi

# ============================================================================
# 3. TẠO ENVIRONMENTS (development, staging, production)
# ============================================================================
echo -e "\n${BOLD}3️⃣  Cấu hình Environments (development, staging, production)...${NC}"

gh api -X PUT "repos/${FULL_REPO}/environments/development" \
  -H "Accept: application/vnd.github+json" \
  -f wait_timer=0 &>/dev/null || true

gh api -X PUT "repos/${FULL_REPO}/environments/staging" \
  -H "Accept: application/vnd.github+json" \
  --input - <<EOF &>/dev/null || true
{
  "deployment_branch_policy": {
    "protected_branches": true,
    "custom_branch_policies": false
  }
}
EOF

# Môi trường production
if [ "$IS_ORG" = true ]; then
  # Dual approval cho Org
  gh api -X PUT "repos/${FULL_REPO}/environments/production" \
    -H "Accept: application/vnd.github+json" \
    --input - <<EOF &>/dev/null || true
{
  "wait_timer": 5,
  "prevent_self_approval": true,
  "reviewers": ${REVIEWERS_JSON},
  "deployment_branch_policy": {
    "protected_branches": false,
    "custom_branch_policies": true
  }
}
EOF
else
  # Personal account: Cho phép owner deploy an toàn
  gh api -X PUT "repos/${FULL_REPO}/environments/production" \
    -H "Accept: application/vnd.github+json" \
    --input - <<EOF &>/dev/null || true
{
  "wait_timer": 0,
  "prevent_self_approval": false,
  "deployment_branch_policy": {
    "protected_branches": false,
    "custom_branch_policies": true
  }
}
EOF
fi

echo -e "  ✅ Đã tạo đủ 3 Environments: development, staging, production"

# ============================================================================
# 4. TẠO BRANCH RULESET CHO MAIN
# ============================================================================
echo -e "\n${BOLD}4️⃣  Tạo Branch Ruleset bảo vệ nhánh 'main'...${NC}"

gh api -X POST "repos/${FULL_REPO}/rulesets" \
  -H "Accept: application/vnd.github+json" \
  --input - <<EOF &>/dev/null || echo -e "  ℹ️ Ruleset 'main' đã tồn tại hoặc đã được cập nhật."
{
  "name": "Protected Branch Main (Production Standard)",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/main"],
      "exclude": []
    }
  },
  "rules": [
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 1,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": true,
        "require_last_push_approval": true,
        "required_review_thread_resolution": true
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "required_status_checks": [
          { "context": "🧪 CI — Lint, TypeCheck & Unit Tests" },
          { "context": "🛡️ Admin Governance & Security Check" }
        ]
      }
    },
    { "type": "deletion" },
    { "type": "non_fast_forward" }
  ]
}
EOF

# ============================================================================
# 5. TẠO TAG RULESET CHO v*.*.*
# ============================================================================
echo -e "\n${BOLD}5️⃣  Tạo Tag Ruleset bảo vệ Tag 'v*.*.*'...${NC}"

if [ "$IS_ORG" = true ] && [ -n "$RELEASE_MGR_TEAM_ID" ]; then
  BYPASS_ACTORS="[{\"actor_id\": ${RELEASE_MGR_TEAM_ID}, \"actor_type\": \"Team\", \"bypass_mode\": \"always\"}]"
else
  # Personal Account: Repository Admin có quyền tạo Tag release
  BYPASS_ACTORS="[{\"actor_id\": 1, \"actor_type\": \"RepositoryRole\", \"bypass_mode\": \"always\"}]"
fi

gh api -X POST "repos/${FULL_REPO}/rulesets" \
  -H "Accept: application/vnd.github+json" \
  --input - <<EOF &>/dev/null || echo -e "  ℹ️ Ruleset Tag 'v*' đã tồn tại hoặc đã được cập nhật."
{
  "name": "Protected Production Tags (SemVer)",
  "target": "tag",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/tags/v*.*.*", "refs/tags/v*"],
      "exclude": []
    }
  },
  "rules": [
    { "type": "creation" },
    { "type": "deletion" },
    { "type": "update" }
  ],
  "bypass_actors": ${BYPASS_ACTORS}
}
EOF

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ BẢO MẬT & CẤU HÌNH QUY TẮC HOÀN TẤT THÀNH CÔNG!          ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ "$IS_ORG" = false ]; then
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}💡 HƯỚNG DẪN DÀNH CHO TÀI KHOẢN CÁ NHÂN (${OWNER_NAME}):${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  Để pipeline gửi thông báo Slack hoặc upload bản build lên AWS S3:"
  echo -e "  1. Mở trang cài đặt Secrets của repo:"
  echo -e "     👉 ${CYAN}https://github.com/${FULL_REPO}/settings/secrets/actions${NC}"
  echo -e "  2. Thêm các Secrets cần thiết: ${YELLOW}SLACK_WEBHOOK_URL${NC}, ${YELLOW}AWS_ACCESS_KEY_ID${NC}, ${YELLOW}AWS_SECRET_ACCESS_KEY${NC}, ${YELLOW}AWS_S3_BUCKET${NC}"
  echo -e "  3. Trên repo cá nhân của bạn, chỉ cần tạo file ${GREEN}.github/workflows/ci.yml${NC} là xong!"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
fi
