#!/bin/bash
# ============================================================================
# 🚀 TRIGGER RENDER DEPLOY (VIA GITHUB & DEPLOY HOOK)
# ============================================================================

DEPLOY_HOOK_URL="${RENDER_DEPLOY_HOOK_URL:-$1}"

if [ -z "$DEPLOY_HOOK_URL" ]; then
    echo "ℹ️ Cách dùng: ./deploy.sh [DEPLOY_HOOK_URL]"
    echo "Hoặc gán biến môi trường: export RENDER_DEPLOY_HOOK_URL=\"https://api.render.com/deploy/...\""
    echo ""
    echo "👉 Để deploy tự động bằng GitHub:"
    echo "   Chỉ cần 'git push origin main', Render sẽ tự động kéo code và deploy Node.js!"
    exit 0
fi

echo "🌐 Đang kích hoạt Render Deploy Hook..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$DEPLOY_HOOK_URL")

if [ "$HTTP_STATUS" -eq 200 ] || [ "$HTTP_STATUS" -eq 201 ]; then
    echo "✅ Kích hoạt Render Deploy thành công (HTTP $HTTP_STATUS)!"
    echo "👉 Theo dõi tiến trình tại Render Dashboard."
else
    echo "❌ Lỗi: Render trả về mã HTTP $HTTP_STATUS"
fi
