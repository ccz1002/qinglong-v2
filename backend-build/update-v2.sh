#!/bin/bash
# 青龙v2 在线更新脚本 — 后端API调用
set -e
QL_DIR="${QL_DIR:-/ql}"
RELEASE_URL="https://gitee.com/ncuon/qinglong-v2/raw/main/qinglong-v2-release.tar.gz"
LOG="/tmp/ql-update.log"
echo "=== 青龙v2 在线更新 $(date) ===" > "$LOG"

log() { echo "$1" | tee -a "$LOG"; }

log "[1/5] 下载发布包..."
TMPDIR=$(mktemp -d)
curl -fsSL -o "$TMPDIR/release.tar.gz" "$RELEASE_URL" 2>> "$LOG" || { log "ERROR: 下载失败"; exit 1; }

log "[2/5] 解压..."
tar xzf "$TMPDIR/release.tar.gz" -C "$TMPDIR" 2>> "$LOG" || { log "ERROR: 解压失败"; exit 1; }

log "[3/5] 停止服务..."
pm2 stop qinglong 2>/dev/null || true
sleep 2

log "[4/5] 替换代码..."
mkdir -p "$QL_DIR/static"
rm -rf "$QL_DIR/static/dist" "$QL_DIR/static/build"
cp -r "$TMPDIR/dist" "$QL_DIR/static/dist"
cp -r "$TMPDIR/static/build" "$QL_DIR/static/build"
rm -rf "$TMPDIR"

log "[5/5] 重启服务..."
cd "$QL_DIR"
pm2 restart qinglong 2>/dev/null || pm2 start static/build/app.js --name qinglong
pm2 save 2>/dev/null

log "✅ 更新完成 $(date)"
echo "DONE" >> "$LOG"
