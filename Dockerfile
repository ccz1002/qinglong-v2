# ============================================
# 青龙面板 + Art Design Pro 新前端 (一体化)
# 用法: docker run -p 5700:5700 qinglong-v2
# ============================================

# 第一阶段: 构建新前端
FROM node:22-alpine AS frontend-builder
WORKDIR /app
COPY package.json pnpm-lock.yaml .npmrc ./
RUN npm install -g pnpm && pnpm install --frozen-lockfile
COPY . .
RUN pnpm build

# 第二阶段: 替换青龙原版前端
FROM whyour/qinglong:latest
COPY --from=frontend-builder /app/dist /ql/static/dist
