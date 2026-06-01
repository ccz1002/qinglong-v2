#!/usr/bin/env bash
# ============================================
# 青龙面板 v2 一键部署脚本
#
# 用法:
#   bash deploy.sh install   [服务器IP]    # 全量安装（首次部署）
#   bash deploy.sh update    [服务器IP]    # 全量更新（保留数据库）
#   bash deploy.sh uninstall [服务器IP]    # 全量卸载
#
# 示例:
#   bash deploy.sh install 106.53.61.242
#   bash deploy.sh update  106.53.61.242
#   bash deploy.sh uninstall 106.53.61.242
# ============================================
set -e

# ── 参数 ──────────────────────────────────
MODE="${1:-update}"
SERVER_IP="${2:-106.53.61.242}"
SERVER_USER="${3:-root}"
SERVER_PORT="5700"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
QL_BACKEND="$(dirname "$SCRIPT_DIR")/qinglong"
QL_DIR="/ql"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ── 校验 ──────────────────────────────────
if [ "$MODE" != "install" ] && [ "$MODE" != "update" ] && [ "$MODE" != "uninstall" ]; then
  echo "用法: bash deploy.sh {install|update|uninstall} [服务器IP]"
  echo "  install   — 全量安装（首次部署）"
  echo "  update    — 全量更新（保留数据库）"
  echo "  uninstall — 全量卸载"
  exit 1
fi

# ── 卸载 ──────────────────────────────────
if [ "$MODE" = "uninstall" ]; then
  echo "⚠  即将全量卸载青龙面板，所有数据将被删除！"
  read -p "确认卸载？输入 yes 继续: " CONFIRM
  [ "$CONFIRM" != "yes" ] && err "已取消"

  ssh "${SERVER_USER}@${SERVER_IP}" "
    echo '[INFO] 停止服务...'
    pm2 delete qinglong 2>/dev/null || true
    docker stop qinglong 2>/dev/null || true
    docker rm qinglong 2>/dev/null || true
    echo '[INFO] 删除所有文件...'
    rm -rf $QL_DIR
    echo '[INFO] 卸载完成'
  "
  log "青龙面板已从 ${SERVER_IP} 完全卸载"
  exit 0
fi

# ── 本地构建 ──────────────────────────────
log "============================================"
log "  青龙面板 v2 — 全量${MODE}"
log "  目标: ${SERVER_USER}@${SERVER_IP}"
log "============================================"

log "1/4 构建前端..."
cd "$SCRIPT_DIR"
pnpm install --no-frozen-lockfile 2>/dev/null || pnpm install
pnpm exec vite build
log "前端构建完成"

log "2/4 使用预编译后端 (backend-build/)..."
if [ ! -d "$SCRIPT_DIR/backend-build" ]; then
  warn "未找到 backend-build/ 目录，请在 ../qinglong 中执行 pnpm run build:back 然后复制到 backend-build/"
  warn "现在自动构建..."
  cd "$QL_BACKEND"
  pnpm install --no-frozen-lockfile 2>/dev/null || npm install
  pnpm run build:back 2>/dev/null || npm run build:back
  cd "$SCRIPT_DIR"
  cp -r "$QL_BACKEND/static/build" backend-build
  cp backend/api/*.js backend-build/api/ 2>/dev/null || true
  cp backend/services/*.js backend-build/services/ 2>/dev/null || true
  cp backend/data/*.js backend-build/data/ 2>/dev/null || true
  cp backend/loaders/*.js backend-build/loaders/ 2>/dev/null || true
fi
log "后端就绪"

# ── 打包 ──────────────────────────────────
log "3/4 打包部署文件..."
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/dist" "$TMPDIR/static"
cp -r dist/* "$TMPDIR/dist/"
cp -r "$SCRIPT_DIR/backend-build" "$TMPDIR/static/build"

# 生成服务器端部署脚本
cat > "$TMPDIR/server-deploy.sh" << 'SERVERSCRIPT'
#!/usr/bin/env bash
set -e
QL_DIR="/ql"
MODE="$1"
DEPLOY_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="${QL_DIR}/.backup_$(date +%Y%m%d_%H%M%S)"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $1"; }

if [ "$MODE" = "install" ]; then
  # ========== 全量安装 ==========
  log "全量安装青龙面板..."

  # 创建目录结构
  mkdir -p "$QL_DIR"/{static,data,log,repo,raw,scripts,config,deps}

  # 复制所有代码
  log "安装前端..."
  cp -r "$DEPLOY_DIR/dist" "$QL_DIR/static/dist"

  log "安装后端..."
  cp -r "$DEPLOY_DIR/static/build" "$QL_DIR/static/build"

  # 安装依赖
  if [ -f "$QL_DIR/static/build/package.json" ]; then
    cd "$QL_DIR"
    log "安装运行时依赖..."
    npm install --production 2>/dev/null || true
  fi

  # 初始化数据库
  log "初始化数据库..."
  cd "$QL_DIR"
  node -e "
    const { sequelize } = require('./static/build/data/index.js');
    sequelize.sync().then(() => console.log('DB synced'));
  " 2>/dev/null || log "数据库将在首次启动时自动初始化"

  log "青龙面板安装完成!"

elif [ "$MODE" = "update" ]; then
  # ========== 全量更新 ==========
  log "全量更新青龙面板（保留数据库）..."

  # 备份
  log "备份现有文件 → $BACKUP_DIR"
  mkdir -p "$BACKUP_DIR"
  cp -r "$QL_DIR/static/dist" "$BACKUP_DIR/dist" 2>/dev/null || true
  cp -r "$QL_DIR/static/build" "$BACKUP_DIR/build" 2>/dev/null || true

  # 停服
  log "停止服务..."
  pm2 stop qinglong 2>/dev/null || true
  sleep 2

  # 替换
  log "替换前端..."
  rm -rf "$QL_DIR/static/dist"
  cp -r "$DEPLOY_DIR/dist" "$QL_DIR/static/dist"

  log "替换后端..."
  rm -rf "$QL_DIR/static/build"
  cp -r "$DEPLOY_DIR/static/build" "$QL_DIR/static/build"

  log "数据库 ($QL_DIR/data) — 保留不动 ✓"
  log "配置文件 ($QL_DIR/config) — 保留不动 ✓"
  log "脚本仓库 ($QL_DIR/scripts) — 保留不动 ✓"
  log "日志目录 ($QL_DIR/log) — 保留不动 ✓"

else
  echo "Unknown mode: $MODE"; exit 1
fi

# 重启
log "启动服务..."
cd "$QL_DIR"
if pm2 list 2>/dev/null | grep -q qinglong; then
  pm2 restart qinglong
else
  pm2 start static/build/app.js --name qinglong
fi
pm2 save 2>/dev/null || true

IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")
echo ""
echo "============================================"
log "  部署完成!"
log "  访问: http://${IP}:5700"
[ "$MODE" = "update" ] && log "  回滚: cp -r $BACKUP_DIR/* $QL_DIR/static/"
echo "============================================"
SERVERSCRIPT
chmod +x "$TMPDIR/server-deploy.sh"

ARCHIVE="/tmp/qinglong-deploy-$(date +%Y%m%d-%H%M%S).tar.gz"
cd "$TMPDIR"
tar czf "$ARCHIVE" .
log "打包完成: $ARCHIVE ($(du -h "$ARCHIVE" | cut -f1))"

# ── 上传并执行 ─────────────────────────────
log "4/4 上传到服务器并执行..."
scp "$ARCHIVE" "${SERVER_USER}@${SERVER_IP}:/tmp/"

ssh "${SERVER_USER}@${SERVER_IP}" "
  DEPLOY_TMP=\$(mktemp -d)
  tar xzf '$ARCHIVE' -C \"\$DEPLOY_TMP\"
  cd \"\$DEPLOY_TMP\"
  bash server-deploy.sh '$MODE'
  rm -rf \"\$DEPLOY_TMP\" '$ARCHIVE'
"

# 清理本地
rm -rf "$TMPDIR" "$ARCHIVE"

log "============================================"
log "  全部完成! 打开浏览器访问:"
log "  http://${SERVER_IP}:${SERVER_PORT}"
log "============================================"
