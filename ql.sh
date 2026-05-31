#!/bin/bash
#==================================
# 青龙面板 (Art Design Pro 新版) 管理脚本
# 镜像: ncuon/qinglong-v2:latest
#==================================

IMAGE="ncuon/qinglong-v2:latest"
CONTAINER="qinglong"
PORT="5700"
DATA_DIR="/opt/qinglong/data"

set -e

# 颜色
RED='\033[31m'; GREEN='\033[32m'; YELLOW='\033[33m'; NC='\033[0m'

usage() {
  echo "用法: ./ql.sh {install|update|uninstall|status}"
  echo ""
  echo "  install   首次安装"
  echo "  update    更新到最新版本（数据不丢失）"
  echo "  uninstall 卸载（保留数据目录）"
  echo "  status    查看运行状态"
  exit 0
}

log()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

check_docker() {
  if ! command -v docker &>/dev/null; then
    err "请先安装 Docker: curl -fsSL https://get.docker.com | bash"
  fi
}

install() {
  log "安装青龙面板..."
  check_docker

  mkdir -p "$DATA_DIR"

  if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    warn "容器已存在，请使用 update 更新"
    exit 0
  fi

  docker pull "$IMAGE"
  docker run -d \
    --name "$CONTAINER" \
    -p "$PORT:5700" \
    -v "$DATA_DIR:/ql/data" \
    --restart unless-stopped \
    "$IMAGE"

  log "安装完成！访问 http://$(curl -s ip.sb 2>/dev/null || echo '服务器IP'):$PORT"
}

update() {
  log "更新青龙面板..."
  check_docker

  if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    warn "容器不存在，将执行首次安装"
    install
    return
  fi

  docker pull "$IMAGE"
  docker stop "$CONTAINER"
  docker rm "$CONTAINER"
  docker run -d \
    --name "$CONTAINER" \
    -p "$PORT:5700" \
    -v "$DATA_DIR:/ql/data" \
    --restart unless-stopped \
    "$IMAGE"

  log "更新完成！数据已保留"
}

uninstall() {
  warn "即将卸载青龙面板（数据目录 $DATA_DIR 将保留）"
  read -p "确认卸载？[y/N] " confirm
  if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    log "已取消"
    exit 0
  fi

  docker stop "$CONTAINER" 2>/dev/null || true
  docker rm "$CONTAINER" 2>/dev/null || true

  log "已卸载。数据保留在 $DATA_DIR"
  log "如需完全删除数据，请手动执行: rm -rf $DATA_DIR"
}

status() {
  if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    log "状态: 运行中"
    docker ps --filter "name=${CONTAINER}" --format "  ID: {{.ID}}  Port: {{.Ports}}  Status: {{.Status}}"
  elif docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    warn "状态: 已停止"
  else
    warn "状态: 未安装"
  fi
}

# 主入口
case "${1:-}" in
  install)   install ;;
  update)    update ;;
  uninstall) uninstall ;;
  status)    status ;;
  *)         usage ;;
esac
