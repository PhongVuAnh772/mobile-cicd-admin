#!/bin/bash
# ============================================================================
# 🔒 ENTERPRISE GITHUB GOVERNANCE AUTOMATOR - WITH STRICT AUTHENTICATION
# ============================================================================
# Script tự động cấu hình Rulesets, Environments, Team Permissions.
# BẢO MẬT: Bắt buộc đăng nhập GitHub CLI và YÊU CẦU QUYỀN ORG ADMIN (OWNER).
# Người dùng thông thường (Developers / Tech Leads) SẼ BỊ TỪ CHỐI TRUY CẬP.
# ============================================================================

set -e

# Màu sắc Terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

ORG_NAME="phong-mobile"
REPO_NAME=""

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  🔒 ENTERPRISE GITHUB GOVERNANCE AUTOMATOR - AUTH SECURED   ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ── 1. PHÂN TÍCH TARGET REPOSITORY ──────────────────────────────────────────
GIT_REPO_URL=$(git config --get remote.origin.url 2>/dev/null || echo "")
if [[ "$GIT_REPO_URL" =~ github.com[:/]([^/]+)/([^/.]+)(\.git)? ]]; then
  ORG_NAME="${BASH_REMATCH[1]}"
  REPO_NAME="${BASH_REMATCH[2]}"
fi

read -p "$(echo -e ${YELLOW}Nhập tên GitHub Organization [Mặc định: ${ORG_NAME}]: ${NC})" INPUT_ORG
ORG_NAME=${INPUT_ORG:-$ORG_NAME}

read -p "$(echo -e ${YELLOW}Nhập tên Repository [Mặc định: ${REPO_NAME:-your-rn-app}]: ${NC})" INPUT_REPO
REPO_NAME=${INPUT_REPO:-${REPO_NAME:-your-rn-app}}

FULL_REPO="${ORG_NAME}/${REPO_NAME}"

# ── 2. ĐÁNH GIÁ XÁC THỰC (AUTHENTICATION CHECK) ──────────────────────────────
echo ""
echo -e "${CYAN}🔑 [AUTH CHECK] Đang xác thực tài khoản GitHub CLI...${NC}"

if ! command -v gh &> /dev/null; then
  echo -e "${RED}❌ AUTH ERROR: Không tìm thấy GitHub CLI (gh). Vui lòng cài đặt: brew install gh${NC}"
  exit 1
fi

if ! gh auth status &> /dev/null; then
  echo -e "${RED}❌ AUTH ERROR: Chưa đăng nhập GitHub CLI. Vui lòng đăng nhập bằng tài khoản Admin: gh auth login${NC}"
  exit 1
fi

# Lấy Username đang đăng nhập
CURRENT_USER=$(gh api user --jq '.login' 2>/dev/null || echo "")
if [ -z "$CURRENT_USER" ]; then
  echo -e "${RED}❌ AUTH ERROR: Không thể lấy thông tin user từ GitHub API.${NC}"
  exit 1
fi

echo -e "  👤 Tài khoản hiện tại: ${GREEN}${CURRENT_USER}${NC}"

# ── 3. ĐÁNH GIÁ UỶ QUYỀN (AUTHORIZATION CHECK - ORG ADMIN ONLY) ─────────────
echo -e "${CYAN}🛡️ [AUTHORIZATION CHECK] Kiểm tra quyền hạn trên Organization '${ORG_NAME}'...${NC}"

# Lấy thông tin role trong Org
USER_ROLE=$(gh api "orgs/${ORG_NAME}/memberships/${CURRENT_USER}" --jq '.role' 2>/dev/null || echo "none")
USER_STATE=$(gh api "orgs/${ORG_NAME}/memberships/${CURRENT_USER}" --jq '.state' 2>/dev/null || echo "inactive")

if [ "$USER_ROLE" != "admin" ] || [ "$USER_STATE" != "active" ]; then
  echo ""
  echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${RED}║  ⛔ ACCESS DENIED - BỊ TỪ CHỐI TRUY CẬP!                    ║${NC}"
  echo -e "${RED}╠══════════════════════════════════════════════════════════════╣${NC}"
  echo -e "${RED}║ User '${CURRENT_USER}' không phải là ADMIN / OWNER của Org '${ORG_NAME}'. ║${NC}"
  echo -e "${RED}║ Vai trò hiện tại của bạn: [${USER_ROLE^^}]                            ║${NC}"
  echo -e "${RED}║ Chỉ tài khoản Organization Admin mới được phép thiết lập Rules. ║${NC}"
  echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  exit 1
fi

echo -e "${GREEN}  ✅ Xác thực thành công! User '${CURRENT_USER}' có vai trò [ORG ADMIN/OWNER].${NC}"
echo ""

# ── 4. XÁC NHẬN BẢO MẬT HAI LỚP (2FA CONFIRMATION PASSPHRASE) ────────────────
echo -e "${YELLOW}⚠️ CAUTION: Bạn chuẩn bị thay đổi toàn bộ Teams, Rulesets & Secrets Scope của ${FULL_REPO}.${NC}"
read -p "$(echo -e ${YELLOW}Gõ 'CONFIRM_ADMIN' để xác nhận thực thi: ${NC})" SECURITY_PIN

if [ "$SECURITY_PIN" != "CONFIRM_ADMIN" ]; then
  echo -e "${RED}❌ Mã xác nhận không chính xác. Đã hủy thao tác bảo mật.${NC}"
  exit 1
fi

# ── 5. GHI AUDIT LOG BẢO MẬT ────────────────────────────────────────────────
AUDIT_LOG_FILE="github-rules-audit.log"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
HOSTNAME=$(hostname)
echo "[AUDIT] $TIMESTAMP | User: $CURRENT_USER | Org: $ORG_NAME | Repo: $FULL_REPO | Host: $HOSTNAME | Action: SETUP_GOVERNANCE_RULES" >> "$AUDIT_LOG_FILE"
echo -e "${GREEN}📝 Đã ghi vết Audit Log tại: ${AUDIT_LOG_FILE}${NC}"

echo -e "\n${CYAN}🚀 Bắt đầu thiết lập Enterprise Governance Rulesets cho ${FULL_REPO}...${NC}"

# ============================================================================
# 1. KIỂM TRA & TẠO ORG TEAMS
# ============================================================================
echo -e "\n${BOLD}1️⃣  Cấu hình Teams trong Organization '${ORG_NAME}'...${NC}"

for TEAM in "mobile-developers" "mobile-tech-leads" "release-managers"; do
  if gh api "orgs/${ORG_NAME}/teams/${TEAM}" &>/dev/null; then
    echo -e "  ✅ Team '${TEAM}' đã tồn tại."
  else
    echo -e "  ➕ Tạo mới Team '${TEAM}'..."
    gh api -X POST "orgs/${ORG_NAME}/teams" -f name="${TEAM}" -f privacy="closed" &>/dev/null || true
  fi
done

# ============================================================================
# 2. PHÂN QUYỀN VÀO REPOSITORY
# ============================================================================
echo -e "\n${BOLD}2️⃣  Phân quyền Team vào Repo '${FULL_REPO}'...${NC}"

echo -e "  🔑 Gán quyền 'push' (Write) cho team 'mobile-developers'..."
gh api -X PUT "orgs/${ORG_NAME}/teams/mobile-developers/repos/${FULL_REPO}" -f permission="push"

echo -e "  🔑 Gán quyền 'maintain' cho team 'mobile-tech-leads'..."
gh api -X PUT "orgs/${ORG_NAME}/teams/mobile-tech-leads/repos/${FULL_REPO}" -f permission="maintain"

echo -e "  🔑 Gán quyền 'maintain' cho team 'release-managers'..."
gh api -X PUT "orgs/${ORG_NAME}/teams/release-managers/repos/${FULL_REPO}" -f permission="maintain"

# ============================================================================
# 3. TẠO ENVIRONMENTS & DUAL APPROVAL
# ============================================================================
echo -e "\n${BOLD}3️⃣  Cấu hình Environments (development, staging, production)...${NC}"

gh api -X PUT "repos/${FULL_REPO}/environments/development" \
  -H "Accept: application/vnd.github+json" \
  -f wait_timer=0 &>/dev/null

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

TECH_LEAD_TEAM_ID=$(gh api "orgs/${ORG_NAME}/teams/mobile-tech-leads" --jq '.id' 2>/dev/null || echo "")
RELEASE_MGR_TEAM_ID=$(gh api "orgs/${ORG_NAME}/teams/release-managers" --jq '.id' 2>/dev/null || echo "")

REVIEWERS_JSON="[]"
if [ -n "$TECH_LEAD_TEAM_ID" ] && [ -n "$RELEASE_MGR_TEAM_ID" ]; then
  REVIEWERS_JSON="[{\"type\":\"Team\",\"id\":${TECH_LEAD_TEAM_ID}},{\"type\":\"Team\",\"id\":${RELEASE_MGR_TEAM_ID}}]"
fi

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

# ============================================================================
# 4. TẠO BRANCH RULESET CHO MAIN
# ============================================================================
echo -e "\n${BOLD}4️⃣  Tạo Branch Ruleset bảo vệ nhánh 'main'...${NC}"

gh api -X POST "repos/${FULL_REPO}/rulesets" \
  -H "Accept: application/vnd.github+json" \
  --input - <<EOF &>/dev/null || echo -e "  ⚠️ Ruleset 'main' đã tồn tại hoặc cần tạo qua GUI."
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
          { "context": "🧪 ESLint & TypeScript Checks" },
          { "context": "Jest Unit Tests & Coverage (≥ 80%)" },
          { "context": "Gitleaks Secret Scanning" }
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

gh api -X POST "repos/${FULL_REPO}/rulesets" \
  -H "Accept: application/vnd.github+json" \
  --input - <<EOF &>/dev/null || echo -e "  ⚠️ Ruleset Tag 'v*' đã tồn tại hoặc cần tạo qua GUI."
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
  "bypass_actors": [
    {
      "actor_id": ${RELEASE_MGR_TEAM_ID:-0},
      "actor_type": "Team",
      "bypass_mode": "always"
    }
  ]
}
EOF

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ BẢO MẬT & CẤU HÌNH QUY TẮC HOÀN TẤT THÀNH CÔNG!          ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
