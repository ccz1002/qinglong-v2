#!/usr/bin/env bash
# ============================================
# 青龙面板 v2 服务器端部署脚本
# 在服务器上直接运行
#
# 用法:
#   bash deploy.sh install       # 全量安装
#   bash deploy.sh update        # 全量更新（保留数据库）
#   bash deploy.sh uninstall     # 全量卸载
# ============================================
set -e

MODE="${1:-update}"
DEPLOY_DIR="$(cd "$(dirname "$0")" && pwd)"
QL_DIR="${QL_DIR:-/ql}"
BACKUP_DIR="${QL_DIR}/.backup_$(date +%Y%m%d_%H%M%S)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

if [ "$MODE" != "install" ] && [ "$MODE" != "update" ] && [ "$MODE" != "uninstall" ]; then
  echo "用法: bash deploy.sh {install|update|uninstall}"
  exit 1
fi

# ════════════════════════════════════════════
# 卸载
# ════════════════════════════════════════════
if [ "$MODE" = "uninstall" ]; then
  echo ""
  echo -e "${RED}⚠  即将全量卸载青龙面板！${NC}"
  echo -e "${RED}   所有数据将被永久删除（包括数据库、脚本、配置、日志）${NC}"
  echo ""
  read -p "确认卸载？输入 yes 继续: " CONFIRM
  [ "$CONFIRM" != "yes" ] && err "已取消卸载"

  log "停止并删除 pm2 进程..."
  pm2 delete qinglong 2>/dev/null || true
  pm2 save 2>/dev/null || true

  log "停止并删除 Docker 容器..."
  docker stop qinglong 2>/dev/null || true
  docker rm qinglong 2>/dev/null || true

  log "删除所有文件: $QL_DIR"
  rm -rf "$QL_DIR"

  log "青龙面板已完全卸载"
  exit 0
fi

# ════════════════════════════════════════════
# 安装 / 更新
# ════════════════════════════════════════════

if [ "$MODE" = "install" ]; then
  log "============================================"
  log "  青龙面板 — 全量安装"
  log "============================================"

  log "创建目录结构..."
  mkdir -p "$QL_DIR"/{static,data,log,repo,raw,scripts,config,deps}

  log "安装前端..."
  [ -d "$DEPLOY_DIR/dist" ] && cp -r "$DEPLOY_DIR/dist" "$QL_DIR/static/" || err "未找到 dist/ 目录"

  log "安装后端..."
  [ -d "$DEPLOY_DIR/static/build" ] && cp -r "$DEPLOY_DIR/static/build" "$QL_DIR/static/" || err "未找到 static/build/ 目录"

  log "安装运行时依赖..."
  cd "$QL_DIR"
  cp "$DEPLOY_DIR/static/build/package.json" "$QL_DIR/" 2>/dev/null || true
  npm install --production 2>/dev/null || warn "npm install 失败，可稍后手动安装"

  log "数据库将在首次启动时自动初始化"

elif [ "$MODE" = "update" ]; then
  log "============================================"
  log "  青龙面板 — 全量更新"
  log "============================================"

  log "备份现有文件 → $BACKUP_DIR"
  mkdir -p "$BACKUP_DIR"
  cp -r "$QL_DIR/static/dist" "$BACKUP_DIR/dist" 2>/dev/null || true
  cp -r "$QL_DIR/static/build" "$BACKUP_DIR/build" 2>/dev/null || true

  log "停止服务..."
  pm2 stop qinglong 2>/dev/null || true
  sleep 2

  log "替换前端..."
  rm -rf "$QL_DIR/static/dist"
  cp -r "$DEPLOY_DIR/dist" "$QL_DIR/static/dist"

  log "替换后端..."
  rm -rf "$QL_DIR/static/build"
  cp -r "$DEPLOY_DIR/static/build" "$QL_DIR/static/build"

  echo ""
  log "以下目录保留不动:"
  log "  ✓ $QL_DIR/data      — 数据库"
  log "  ✓ $QL_DIR/config    — 配置文件"
  log "  ✓ $QL_DIR/scripts   — 脚本仓库"
  log "  ✓ $QL_DIR/log       — 日志文件"
  log "  ✓ $QL_DIR/repo      — 仓库缓存"
fi

# ════════════════════════════════════════════
# 启动
# ════════════════════════════════════════════
log "启动青龙面板..."
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
log "  ${MODE} 完成!"
log "  访问地址: http://${IP}:5700"
if [ "$MODE" = "update" ]; then
  log "  备份目录: $BACKUP_DIR"
  log "  回滚命令: cp -r $BACKUP_DIR/dist/* $QL_DIR/static/dist/ && cp -r $BACKUP_DIR/build/* $QL_DIR/static/build/ && pm2 restart qinglong"
fi
echo "============================================"
