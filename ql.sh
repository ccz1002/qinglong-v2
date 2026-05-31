#!/bin/bash
#==================================
# QingLong Panel - Install/Update/Uninstall
# Image: ncuon/qinglong-v2:latest
#==================================

IMAGE="ncuon/qinglong-v2:latest"
NAME="qinglong"
PORT="5700"
DIR="/opt/qinglong/data"

set -e

case "${1}" in
  install)
    echo "Installing QingLong..."
    if ! command -v docker &>/dev/null; then
      echo "Docker not found. Run: curl -fsSL https://get.docker.com | bash"
      exit 1
    fi
    if docker ps -a --format '{{.Names}}' | grep -q "^${NAME}$"; then
      echo "Container already exists. Use: ./ql.sh update"
      exit 0
    fi
    mkdir -p "$DIR"
    docker pull "$IMAGE"
    docker run -d --name "$NAME" -p "$PORT:5700" -v "$DIR:/ql/data" --restart unless-stopped "$IMAGE"
    echo "Done! Open http://YOUR_IP:$PORT"
    ;;

  update)
    echo "Updating QingLong..."
    docker pull "$IMAGE"
    docker stop "$NAME" 2>/dev/null || true
    docker rm "$NAME" 2>/dev/null || true
    docker run -d --name "$NAME" -p "$PORT:5700" -v "$DIR:/ql/data" --restart unless-stopped "$IMAGE"
    echo "Updated! Data preserved."
    ;;

  uninstall)
    echo "Stopping and removing container (data at $DIR is kept)..."
    docker stop "$NAME" 2>/dev/null || true
    docker rm "$NAME" 2>/dev/null || true
    echo "Done. To fully remove: rm -rf $DIR"
    ;;

  status)
    docker ps -a --filter "name=${NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    ;;

  *)
    echo "Usage: ./ql.sh {install|update|uninstall|status}"
    ;;
esac
