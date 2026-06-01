#!/usr/bin/env bash
# ============================================
# 青龙面板 v2 全量部署脚本
# 替换前端 + 后端所有代码，保留数据库（/ql/data）
# ============================================
set -e

QL_DIR="${QL_DIR:-/ql}"
BACKUP_DIR="${QL_DIR}/.backup_$(date +%Y%m%d_%H%M%S)"
DIST_SRC="./dist"
BUILD_SRC="./static/build"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; }

# ── 权限检查 ──────────────────────────────────
if [ ! -w "$QL_DIR" ]; then
  err "没有 $QL_DIR 写入权限，请用 root 或 qinglong 用户执行"
  exit 1
fi

# ── 备份现有代码（不含 data） ────────────────
log "备份现有代码到 $BACKUP_DIR ..."
mkdir -p "$BACKUP_DIR"
if [ -d "$QL_DIR/static/dist" ]; then
  cp -r "$QL_DIR/static/dist" "$BACKUP_DIR/dist" 2>/dev/null || true
fi
if [ -d "$QL_DIR/static/build" ]; then
  cp -r "$QL_DIR/static/build" "$BACKUP_DIR/build" 2>/dev/null || true
fi

# ── 停止服务 ──────────────────────────────────
log "停止青龙面板服务..."
cd "$QL_DIR"
if command -v pm2 &>/dev/null && pm2 list 2>/dev/null | grep -q "qinglong"; then
  pm2 stop qinglong 2>/dev/null || true
  sleep 2
fi

# ── 全量替换后端代码 ──────────────────────────
if [ -d "$BUILD_SRC" ]; then
  log "替换后端编译代码..."
  rm -rf "$QL_DIR/static/build"
  cp -r "$BUILD_SRC" "$QL_DIR/static/build"
else
  warn "未找到 $BUILD_SRC，跳过后端替换"
fi

# ── 替换前端静态资源 ──────────────────────────
if [ -d "$DIST_SRC" ]; then
  log "替换前端静态资源..."
  rm -rf "$QL_DIR/static/dist"
  cp -r "$DIST_SRC" "$QL_DIR/static/dist"
else
  warn "未找到 $DIST_SRC，跳过前端替换"
fi

# ── 数据库保持不变 ────────────────────────────
log "跳过数据库目录 ($QL_DIR/data) — 数据保留不动"
log "跳过配置文件目录 — 配置保留不动"

# ── 重启服务 ──────────────────────────────────
log "重启青龙面板服务..."
cd "$QL_DIR"
if command -v pm2 &>/dev/null; then
  pm2 restart qinglong 2>/dev/null || pm2 start static/build/app.js --name qinglong 2>/dev/null || true
fi

log "============================================"
log "  全量部署完成!"
log "  备份位置: $BACKUP_DIR"
log "  如需回滚: cp -r $BACKUP_DIR/dist/* $QL_DIR/static/dist/"
log "            cp -r $BACKUP_DIR/build/* $QL_DIR/static/build/"
log "============================================"
