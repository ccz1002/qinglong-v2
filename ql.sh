#!/bin/bash
# ============================================
# 青龙面板 v2 — Docker 一键管理脚本
# 用法: bash <(curl -fsSL https://gitee.com/ncuon/qinglong-v2/raw/main/ql.sh)
# ============================================

IMG="ncuon/qinglong-v2:latest"
NAME="qinglong"
PORT="5700"
DIR="/opt/qinglong/data"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'

clear
echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN}  青龙面板 v2 — Docker 管理脚本${NC}"
echo -e "${CYAN}  镜像: ${IMG}${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""
echo "  1. 安装 (首次部署)"
echo "  2. 更新 (保留数据库)"
echo "  3. 卸载 (全部清除)"
echo "  4. 查看状态"
echo "  0. 退出"
echo ""

# ── 检查 Docker ──
if ! command -v docker &>/dev/null; then
  echo -e "${RED}请先安装 Docker: curl -fsSL https://get.docker.com | bash${NC}"
  exit 1
fi

read -p "请选择 [0-4]: " opt

case "$opt" in
  1)
    echo ""
    echo -e "${GREEN}>>> 全量安装中...${NC}"
    mkdir -p "$DIR"
    docker pull "$IMG"
    docker rm -f "$NAME" 2>/dev/null || true
    docker run -d \
      --name "$NAME" \
      -p "$PORT:5700" \
      -v "$DIR:/ql/data" \
      --restart unless-stopped \
      "$IMG"
    IP=$(curl -s ip.sb 2>/dev/null || curl -s ifconfig.me 2>/dev/null || echo "你的服务器IP")
    echo ""
    echo -e "${GREEN}>>> 安装完成！${NC}"
    echo -e "${GREEN}>>> 访问地址: http://${IP}:${PORT}${NC}"
    echo -e "${GREEN}>>> 默认账号: admin / admin${NC}"
    ;;

  2)
    echo ""
    echo -e "${GREEN}>>> 全量更新（保留数据库 /opt/qinglong/data）...${NC}"
    docker pull "$IMG"
    docker rm -f "$NAME" 2>/dev/null || true
    docker run -d \
      --name "$NAME" \
      -p "$PORT:5700" \
      -v "$DIR:/ql/data" \
      --restart unless-stopped \
      "$IMG"
    echo -e "${GREEN}>>> 更新完成! 访问 http://$(curl -s ip.sb 2>/dev/null || echo '你的IP'):${PORT}${NC}"
    ;;

  3)
    echo ""
    echo -e "${RED}⚠  将删除容器、镜像、所有数据!${NC}"
    read -p "确认卸载？输入 yes 继续: " cf
    if [ "$cf" = "yes" ]; then
      docker rm -f "$NAME" 2>/dev/null || true
      docker rmi "$IMG" 2>/dev/null || true
      rm -rf "$DIR"
      echo -e "${GREEN}>>> 已完全卸载${NC}"
    else
      echo ">>> 已取消"
    fi
    ;;

  4)
    echo ""
    docker ps -a --filter "name=$NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Image}}"
    echo ""
    if docker ps --filter "name=$NAME" --format "{{.Names}}" | grep -q "$NAME"; then
      echo -e "${GREEN}容器运行中 ✓${NC}"
    elif docker ps -a --filter "name=$NAME" --format "{{.Names}}" | grep -q "$NAME"; then
      echo -e "${YELLOW}容器已停止，查看日志: docker logs $NAME${NC}"
    else
      echo -e "${RED}容器不存在${NC}"
    fi
    ;;

  0)
    echo ">>> 退出"
    ;;

  *)
    echo ">>> 无效选项"
    ;;
esac
