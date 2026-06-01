#!/usr/bin/env bash
# ============================================
# 本地构建 Docker 镜像并推送到 Docker Hub
# 用法: bash build-docker.sh
# ============================================

IMG="ncuon/qinglong-v2:latest"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "============================================"
echo "  青龙面板 v2 Docker 镜像构建 & 推送"
echo "  镜像: $IMG"
echo "============================================"

# 1. 构建前端
echo "[1/3] 构建前端..."
cd "$SCRIPT_DIR"
pnpm install --no-frozen-lockfile 2>/dev/null || true
npx vite build

# 2. 准备 Docker 上下文
echo "[2/3] 准备 Docker 上下文..."
rm -rf docker-context
mkdir -p docker-context/dist
cp -r dist/* docker-context/dist/
cp -r backend-build docker-context/

# 3. 构建并推送
echo "[3/3] 构建并推送 Docker 镜像..."
cd docker-context
docker build -f "$SCRIPT_DIR/Dockerfile.full" -t "$IMG" .
docker push "$IMG"

cd "$SCRIPT_DIR"
rm -rf docker-context

echo ""
echo "============================================"
echo "  完成! 镜像已推送: $IMG"
echo "  服务器更新命令: bash <(curl -fsSL https://gitee.com/ncuon/qinglong-v2/raw/main/ql.sh)"
echo "============================================"
