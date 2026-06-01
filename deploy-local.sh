#!/usr/bin/env bash
# ============================================
# 青龙面板 v2 一键部署脚本 (本地构建 + 推送服务器)
# 用法: bash deploy-local.sh [服务器IP] [服务器用户]
# 示例: bash deploy-local.sh 106.53.61.242 root
# ============================================
set -e

# ── 配置 ──────────────────────────────────
SERVER_IP="${1:-106.53.61.242}"
SERVER_USER="${2:-root}"
SERVER_PORT="${3:-5700}"
QL_DIR="${QL_DIR:-/ql}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
QL_BACKEND="${SCRIPT_DIR}/../qinglong"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

echo "============================================"
echo "  青龙面板 v2 一键部署"
echo "  目标服务器: ${SERVER_USER}@${SERVER_IP}"
echo "============================================"
echo ""

# ── 1. 构建前端 ───────────────────────────
log "1/4 构建前端..."
cd "$SCRIPT_DIR"
pnpm install --no-frozen-lockfile 2>/dev/null || pnpm install
pnpm exec vite build
log "前端构建完成 → dist/"

# ── 2. 构建后端 ───────────────────────────
log "2/4 构建后端..."
if [ -d "$QL_BACKEND" ]; then
  cd "$QL_BACKEND"
  pnpm install --no-frozen-lockfile 2>/dev/null || npm install
  pnpm run build:back 2>/dev/null || npm run build:back
  log "后端构建完成 → static/build/"
else
  warn "未找到 qinglong 后端源码 ($QL_BACKEND)，跳过后端构建"
  warn "后端将使用服务器上已有版本"
fi
cd "$SCRIPT_DIR"

# ── 3. 打包并上传 ─────────────────────────
log "3/4 打包部署文件..."
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/dist"

# 前端
cp -r dist/* "$TMPDIR/dist/"

# 后端 (如果有)
if [ -d "$QL_BACKEND/static/build" ]; then
  mkdir -p "$TMPDIR/static"
  cp -r "$QL_BACKEND/static/build" "$TMPDIR/static/"
fi

# 服务器端部署脚本
cat > "$TMPDIR/server-deploy.sh" << 'SERVERSCRIPT'
#!/usr/bin/env bash
set -e
QL_DIR="${QL_DIR:-/ql}"
BACKUP_DIR="${QL_DIR}/.backup_$(date +%Y%m%d_%H%M%S)"
DEPLOY_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "[INFO] 备份现有文件到 $BACKUP_DIR ..."
mkdir -p "$BACKUP_DIR"
cp -r "$QL_DIR/static/dist" "$BACKUP_DIR/dist" 2>/dev/null || true
cp -r "$QL_DIR/static/build" "$BACKUP_DIR/build" 2>/dev/null || true

echo "[INFO] 停止青龙面板..."
pm2 stop qinglong 2>/dev/null || true
sleep 2

echo "[INFO] 替换前端..."
rm -rf "$QL_DIR/static/dist"
cp -r "$DEPLOY_DIR/dist" "$QL_DIR/static/dist"

if [ -d "$DEPLOY_DIR/static/build" ]; then
  echo "[INFO] 替换后端..."
  rm -rf "$QL_DIR/static/build"
  cp -r "$DEPLOY_DIR/static/build" "$QL_DIR/static/build"
fi

echo "[INFO] 跳过数据库目录 ($QL_DIR/data) — 数据保留不动"

echo "[INFO] 重启青龙面板..."
pm2 restart qinglong 2>/dev/null || pm2 start "$QL_DIR/static/build/app.js" --name qinglong 2>/dev/null || true

echo ""
echo "============================================"
echo "  部署完成!"
echo "  访问地址: http://$(hostname -I | awk '{print $1}'):5700"
echo "  备份目录: $BACKUP_DIR"
echo "============================================"
SERVERSCRIPT
chmod +x "$TMPDIR/server-deploy.sh"

# 打包上传
ARCHIVE="/tmp/qinglong-deploy-$(date +%Y%m%d-%H%M%S).tar.gz"
cd "$TMPDIR"
tar czf "$ARCHIVE" .
log "上传到服务器 ${SERVER_USER}@${SERVER_IP}..."

scp "$ARCHIVE" "${SERVER_USER}@${SERVER_IP}:/tmp/"

# ── 4. 服务器端解压并执行 ─────────────────
log "4/4 服务器端部署..."
ssh "${SERVER_USER}@${SERVER_IP}" "
  cd /tmp
  DEPLOY_TMP=\$(mktemp -d)
  tar xzf '$ARCHIVE' -C \"\$DEPLOY_TMP\"
  cd \"\$DEPLOY_TMP\"
  bash server-deploy.sh
  rm -rf \"\$DEPLOY_TMP\" '$ARCHIVE'
"

# 清理本地临时文件
rm -rf "$TMPDIR" "$ARCHIVE"

echo ""
log "============================================"
log "  部署成功! 打开浏览器访问:"
log "  http://${SERVER_IP}:${SERVER_PORT}"
log "============================================"
