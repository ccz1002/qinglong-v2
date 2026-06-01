@echo off
chcp 65001 >nul
echo ============================================
echo  青龙面板新前端 - 构建 & 推送到 Docker Hub
echo ============================================
echo.

REM 设置你的 Docker Hub 用户名（登录 https://hub.docker.com 右上角查看）
set DOCKER_USER=ncuon

REM 1. 构建
echo [1/3] 构建镜像...
docker build -t qinglong-v2 .

REM 2. 登录
echo [2/3] 登录 Docker Hub...
docker login

REM 3. 打标签 + 推送
echo [3/3] 推送镜像...
docker tag qinglong-v2 %DOCKER_USER%/qinglong-v2:latest
docker push %DOCKER_USER%/qinglong-v2:latest

echo.
echo ============================================
echo  完成！服务器安装命令：
echo  docker run -d --name qinglong -p 5700:5700 -v /opt/qinglong/data:/ql/data %DOCKER_USER%/qinglong-v2:latest
echo ============================================
pause
