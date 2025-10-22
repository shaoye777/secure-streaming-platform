#!/bin/bash

# VPS部署和配置脚本
# 用于完成VPS代码部署和环境配置

echo "🚀 VPS部署和配置脚本启动 - $(date)"

# 1. 进入项目目录
echo "📁 进入项目目录..."
cd /tmp/github/secure-streaming-platform/vps-transcoder-api

# 2. 执行现有的部署脚本
echo "🔄 执行VPS部署..."
chmod +x vps-simple-deploy.sh
./vps-simple-deploy.sh

# 3. 配置环境变量
echo "🔧 配置环境变量..."
cd vps-transcoder-api

# 检查.env文件是否存在
if [ ! -f .env ]; then
    echo "📝 创建.env文件..."
    cp .env.example .env
fi

# 设置正确的API密钥
echo "🔑 配置API密钥..."
sed -i 's/API_SECRET_KEY=.*/API_SECRET_KEY=85da076ae24b028b3d1ea1884e6b13c5afe34b5b/' .env

# 设置其他必要的环境变量
echo "⚙️ 配置其他环境变量..."
sed -i 's/NODE_ENV=.*/NODE_ENV=production/' .env
sed -i 's/ENABLE_IP_WHITELIST=.*/ENABLE_IP_WHITELIST=false/' .env
sed -i 's|HLS_OUTPUT_DIR=.*|HLS_OUTPUT_DIR=/var/www/hls|' .env
sed -i 's|LOG_DIR=.*|LOG_DIR=/var/log/transcoder|' .env

# 4. 创建必要的目录
echo "📁 创建必要目录..."
mkdir -p /var/www/hls
mkdir -p /var/log/transcoder
chown -R root:root /var/www/hls
chown -R root:root /var/log/transcoder

# 5. 重启服务以应用新配置
echo "🔄 重启服务应用新配置..."
pm2 restart vps-transcoder-api

# 6. 等待服务启动
echo "⏳ 等待服务启动..."
sleep 5

# 7. 验证配置
echo "🔍 验证服务配置..."
echo "检查PM2状态:"
pm2 status

echo ""
echo "检查服务健康:"
curl -s http://localhost:3000/health | jq '.'

echo ""
echo "检查SimpleStream健康:"
curl -s http://localhost:3000/api/simple-stream/health | jq '.'

# 8. 测试API认证
echo ""
echo "🧪 测试API认证..."
echo "测试无API Key (应该返回401):"
curl -s -w "HTTP Status: %{http_code}\n" \
  -X POST http://localhost:3000/api/simple-stream/start-watching \
  -H 'Content-Type: application/json' \
  -d '{"channelId":"test","rtmpUrl":"rtmp://test.com/live/test"}'

echo ""
echo "测试错误API Key (应该返回403):"
curl -s -w "HTTP Status: %{http_code}\n" \
  -X POST http://localhost:3000/api/simple-stream/start-watching \
  -H 'Content-Type: application/json' \
  -H 'X-API-Key: wrong-key' \
  -d '{"channelId":"test","rtmpUrl":"rtmp://test.com/live/test"}'

echo ""
echo "测试正确API Key (应该返回200或500):"
curl -s -w "HTTP Status: %{http_code}\n" \
  -X POST http://localhost:3000/api/simple-stream/start-watching \
  -H 'Content-Type: application/json' \
  -H 'X-API-Key: 85da076ae24b028b3d1ea1884e6b13c5afe34b5b' \
  -d '{"channelId":"test","rtmpUrl":"rtmp://test.com/live/test"}'

echo ""
echo "🎉 VPS部署和配置完成!"
echo "时间: $(date)"
echo ""
echo "✅ 配置总结:"
echo "- 代码已更新到最新版本"
echo "- API密钥已配置: 85da076ae24b028b3d1ea1884e6b13c5afe34b5b"
echo "- 环境变量已设置"
echo "- 必要目录已创建"
echo "- 服务已重启"
echo ""
echo "🔗 下一步:"
echo "请从Cloudflare Workers测试API调用"
