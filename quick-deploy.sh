#!/usr/bin/env bash
# ============================================
# 快速部署脚本（仅前端，30秒内完成）
# 用法: bash quick-deploy.sh [服务器IP]
# 示例: bash quick-deploy.sh 106.53.61.242
# ============================================
set -e

SERVER="${1:-106.53.61.242}"
USER="${2:-root}"

echo "🚀 快速部署到 ${USER}@${SERVER} ..."

# 1. 构建
echo "📦 构建前端..."
pnpm exec vite build

# 2. 上传 + 重启
echo "📤 上传并重启..."
scp -r dist/* ${USER}@${SERVER}:/ql/static/dist/ \
  && ssh ${USER}@${SERVER} "pm2 restart qinglong 2>/dev/null || pm2 start /ql/static/build/app.js --name qinglong" \
  && echo "✅ 完成! http://${SERVER}:5700"
