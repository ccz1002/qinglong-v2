@echo off
echo ============================================
echo  QingLong Panel - Build & Push to Docker Hub
echo ============================================
echo.

set DOCKER_USER=ncuon

echo [1/3] Building image...
docker build -t qinglong-v2 .

echo.
echo [2/3] Login to Docker Hub...
docker login

echo.
echo [3/3] Pushing to %DOCKER_USER%/qinglong-v2...
docker tag qinglong-v2 %DOCKER_USER%/qinglong-v2:latest
docker push %DOCKER_USER%/qinglong-v2:latest

echo.
echo ============================================
echo  Done! Run on server:
echo  docker run -d --name qinglong -p 5700:5700 -v /opt/qinglong/data:/ql/data %DOCKER_USER%/qinglong-v2:latest
echo ============================================
pause
