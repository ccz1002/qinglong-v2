#!/bin/bash
IMG="ncuon/qinglong-v2:latest"
NAME="qinglong"
PORT="5700"
DIR="/opt/qinglong/data"

case "$1" in
  install)
    echo ">>> Installing QingLong..."
    mkdir -p "$DIR"
    docker pull "$IMG"
    docker rm -f "$NAME" 2>/dev/null
    docker run -d --name "$NAME" -p "$PORT:5700" -v "$DIR:/ql/data" --restart unless-stopped "$IMG"
    echo ">>> Done: http://YOUR_IP:$PORT"
    ;;
  update)
    echo ">>> Updating QingLong..."
    docker pull "$IMG"
    docker rm -f "$NAME" 2>/dev/null
    docker run -d --name "$NAME" -p "$PORT:5700" -v "$DIR:/ql/data" --restart unless-stopped "$IMG"
    echo ">>> Updated"
    ;;
  uninstall)
    echo ">>> Removing QingLong (data kept at $DIR)..."
    docker rm -f "$NAME" 2>/dev/null
    echo ">>> Done"
    ;;
  status)
    docker ps -a --filter "name=$NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    ;;
  *)
    echo "Usage: ./ql.sh install | update | uninstall | status"
    ;;
esac
