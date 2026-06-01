#!/bin/bash
# ============================================
# 青龙面板 v2 — 一键管理脚本
# 用法: bash <(curl -fsSL https://gitee.com/ncuon/qinglong-v2/raw/main/ql.sh)
# ============================================

IMG="ncuon/qinglong-v2:latest"
NAME="qinglong"
PORT="5700"
DIR="/opt/qinglong/data"
QL_DIR="/ql"
RELEASE_URL="https://gitee.com/ncuon/qinglong-v2/raw/main/qinglong-v2-release.tar.gz"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'

clear
echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN}  青龙面板 v2 — 一键管理脚本${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""
echo "  ── Docker 模式 ──"
echo "  1. Docker 安装"
echo "  2. Docker 更新"
echo "  3. Docker 卸载"
echo ""
echo "  ── 直接部署模式 (无需Docker) ──"
echo "  5. 直接安装"
echo "  6. 直接更新 (保留数据库)"
echo "  7. 直接卸载"
echo ""
echo "  4. 查看状态"
echo "  0. 退出"
echo ""

read -p "请选择 [0-7]: " opt

# ════════════════════════════════════════════
# 直接部署函数
# ════════════════════════════════════════════
direct_deploy() {
  local MODE="$1"
  local TMPDIR=$(mktemp -d)
  local BACKUP="${QL_DIR}/.backup_$(date +%Y%m%d_%H%M%S)"

  echo -e "${GREEN}>>> 下载最新发布包...${NC}"
  if command -v wget &>/dev/null; then
    wget -q --no-check-certificate -O "$TMPDIR/release.tar.gz" "$RELEASE_URL"
  else
    curl -fsSL -o "$TMPDIR/release.tar.gz" "$RELEASE_URL"
  fi

  if [ ! -s "$TMPDIR/release.tar.gz" ]; then
    echo -e "${RED}下载失败，请检查网络${NC}"
    rm -rf "$TMPDIR"
    exit 1
  fi

  echo -e "${GREEN}>>> 解压中...${NC}"
  tar xzf "$TMPDIR/release.tar.gz" -C "$TMPDIR"

  if [ ! -d "$TMPDIR/dist" ] || [ ! -d "$TMPDIR/static/build" ]; then
    echo -e "${RED}发布包不完整${NC}"
    rm -rf "$TMPDIR"
    exit 1
  fi

  if [ "$MODE" = "update" ]; then
    echo -e "${GREEN}>>> 备份现有文件 → ${BACKUP}${NC}"
    mkdir -p "$BACKUP"
    cp -r "$QL_DIR/static/dist" "$BACKUP/dist" 2>/dev/null || true
    cp -r "$QL_DIR/static/build" "$BACKUP/build" 2>/dev/null || true

    echo -e "${GREEN}>>> 停止服务...${NC}"
    pm2 stop qinglong 2>/dev/null || true
    sleep 2
  else
    echo -e "${GREEN}>>> 创建目录结构...${NC}"
    mkdir -p "$QL_DIR"/{static,data,log,repo,raw,scripts,config,deps}
  fi

  echo -e "${GREEN}>>> 替换前端...${NC}"
  rm -rf "$QL_DIR/static/dist"
  cp -r "$TMPDIR/dist" "$QL_DIR/static/dist"

  echo -e "${GREEN}>>> 替换后端（含菜单API）...${NC}"
  rm -rf "$QL_DIR/static/build"
  cp -r "$TMPDIR/static/build" "$QL_DIR/static/build"

  echo ""
  echo -e "${GREEN}  保留不动:${NC}"
  echo -e "${GREEN}  ✓ ${QL_DIR}/data      — 数据库${NC}"
  echo -e "${GREEN}  ✓ ${QL_DIR}/config    — 配置文件${NC}"
  echo -e "${GREEN}  ✓ ${QL_DIR}/scripts   — 脚本仓库${NC}"
  echo -e "${GREEN}  ✓ ${QL_DIR}/log       — 日志文件${NC}"

  echo -e "${GREEN}>>> 启动服务...${NC}"
  cd "$QL_DIR"
  if pm2 list 2>/dev/null | grep -q qinglong; then
    pm2 restart qinglong
  else
    pm2 start static/build/app.js --name qinglong
  fi
  pm2 save 2>/dev/null || true

  rm -rf "$TMPDIR"
  IP=$(curl -s ip.sb 2>/dev/null || curl -s ifconfig.me 2>/dev/null || echo "你的IP")
  echo ""
  echo "============================================"
  echo -e "${GREEN}  部署完成!${NC}"
  echo -e "${GREEN}  访问: http://${IP}:${PORT}${NC}"
  echo -e "${GREEN}  默认账号: admin / admin${NC}"
  [ "$MODE" = "update" ] && echo -e "${GREEN}  回滚: cp -r ${BACKUP}/* ${QL_DIR}/static/${NC}"
  echo "============================================"
}

# ════════════════════════════════════════════
direct_uninstall() {
  echo ""
  echo -e "${RED}⚠  将删除所有文件和数据!${NC}"
  read -p "确认卸载？输入 yes 继续: " cf
  if [ "$cf" = "yes" ]; then
    pm2 delete qinglong 2>/dev/null || true
    pm2 save 2>/dev/null || true
    rm -rf "$QL_DIR"
    echo -e "${GREEN}>>> 已完全卸载${NC}"
  else
    echo ">>> 已取消"
  fi
}

# ════════════════════════════════════════════
case "$opt" in
  1)
    if ! command -v docker &>/dev/null; then
      echo -e "${RED}请先安装 Docker: curl -fsSL https://get.docker.com | bash${NC}"
      exit 1
    fi
    echo -e "${GREEN}>>> Docker 安装中...${NC}"
    mkdir -p "$DIR"
    docker pull "$IMG"
    docker rm -f "$NAME" 2>/dev/null || true
    docker run -d --name "$NAME" -p "$PORT:5700" -v "$DIR:/ql/data" --restart unless-stopped "$IMG"
    IP=$(curl -s ip.sb 2>/dev/null || curl -s ifconfig.me 2>/dev/null || echo "你的IP")
    echo -e "${GREEN}>>> 安装完成！http://${IP}:${PORT}  默认: admin/admin${NC}"
    ;;

  2)
    if ! command -v docker &>/dev/null; then
      echo -e "${RED}请先安装 Docker${NC}"
      exit 1
    fi
    echo -e "${GREEN}>>> Docker 更新（保留数据库）...${NC}"
    docker pull "$IMG"
    docker rm -f "$NAME" 2>/dev/null || true
    docker run -d --name "$NAME" -p "$PORT:5700" -v "$DIR:/ql/data" --restart unless-stopped "$IMG"
    echo -e "${GREEN}>>> 更新完成!${NC}"
    ;;

  3)
    if ! command -v docker &>/dev/null; then exit 0; fi
    echo -e "${RED}⚠  删除容器+镜像+数据!${NC}"
    read -p "输入 yes 继续: " cf
    [ "$cf" = "yes" ] && docker rm -f "$NAME" 2>/dev/null && docker rmi "$IMG" 2>/dev/null && rm -rf "$DIR" && echo -e "${GREEN}已卸载${NC}" || echo "取消"
    ;;

  5)
    direct_deploy "install"
    ;;

  6)
    direct_deploy "update"
    ;;

  7)
    direct_uninstall
    ;;

  4)
    echo ""
    if command -v docker &>/dev/null; then
      docker ps -a --filter "name=$NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null
    fi
    pm2 list 2>/dev/null | grep -q qinglong && echo -e "${GREEN}PM2 进程运行中 ✓${NC}" || echo -e "${YELLOW}PM2 未运行${NC}"
    ;;

  0) echo "退出";;

  *) echo "无效选项";;
esac
