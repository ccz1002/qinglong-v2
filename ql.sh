#!/bin/bash
IMG="ncuon/qinglong-v2:latest"
NAME="qinglong"
PORT="5700"
DIR="/opt/qinglong/data"

clear
echo "========================================="
echo "  青龙面板 (Art Design Pro 新版) 管理脚本"
echo "========================================="
echo "  1. 安装"
echo "  2. 更新"
echo "  3. 卸载"
echo "  4. 查看状态"
echo "  0. 退出"
echo "========================================="
read -p "请选择 [1-4]: " opt

case "$opt" in
  1)
    echo ">>> 安装中..."
    mkdir -p "$DIR"
    docker pull "$IMG"
    docker rm -f "$NAME" 2>/dev/null
    docker run -d --name "$NAME" -p "$PORT:5700" -v "$DIR:/ql/data" --restart unless-stopped "$IMG"
    echo ">>> 安装完成！访问 http://$(curl -s ip.sb):$PORT"
    ;;
  2)
    echo ">>> 更新中..."
    docker pull "$IMG"
    docker rm -f "$NAME" 2>/dev/null
    docker run -d --name "$NAME" -p "$PORT:5700" -v "$DIR:/ql/data" --restart unless-stopped "$IMG"
    echo ">>> 更新完成"
    ;;
  3)
    read -p "确认卸载？将删除容器、镜像和数据！[y/N]: " cf
    if [ "$cf" = "y" ] || [ "$cf" = "Y" ]; then
      docker rm -f "$NAME" 2>/dev/null
      docker rmi "$IMG" 2>/dev/null
      rm -rf "$DIR"
      echo ">>> 已卸载，全部清除"
    else
      echo ">>> 已取消"
    fi
    ;;
  4)
    docker ps -a --filter "name=$NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    ;;
  0) echo ">>> 退出";;
  *) echo ">>> 无效选项";;
esac
