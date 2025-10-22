#!/bin/bash

# VPS强力部署脚本 - 处理Git损坏和各种异常情况
# 支持完全重新克隆、环境配置、服务重启等

echo "🚀 VPS强力部署脚本启动 - $(date)"

# 配置变量
REPO_URL="https://github.com/shao-ye/secure-streaming-platform.git"
GIT_BASE_DIR="/tmp/github"
GIT_DIR="$GIT_BASE_DIR/secure-streaming-platform"
SOURCE_DIR="$GIT_DIR/vps-transcoder-api/vps-transcoder-api/src"
TARGET_DIR="/opt/yoyo-transcoder/src"
BACKUP_DIR="/opt/yoyo-transcoder/backup-$(date +%Y%m%d_%H%M%S)"

# API配置
API_SECRET_KEY="85da076ae24b028b3d1ea1884e6b13c5afe34b5b"

# 函数：检查Git仓库健康状态
check_git_health() {
    echo "🔍 检查Git仓库健康状态..."
    cd "$GIT_DIR" 2>/dev/null || return 1
    
    # 检查是否是有效的Git仓库
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo "❌ 不是有效的Git仓库"
        return 1
    fi
    
    # 检查是否有损坏的对象
    if ! git fsck --no-progress >/dev/null 2>&1; then
        echo "❌ Git仓库存在损坏的对象"
        return 1
    fi
    
    # 检查是否能正常获取状态
    if ! git status >/dev/null 2>&1; then
        echo "❌ Git状态检查失败"
        return 1
    fi
    
    echo "✅ Git仓库健康状态良好"
    return 0
}

# 函数：完全重新克隆仓库
fresh_clone() {
    echo "🔄 执行完全重新克隆..."
    
    # 删除旧的Git目录
    if [ -d "$GIT_DIR" ]; then
        echo "🗑️ 删除损坏的Git仓库..."
        rm -rf "$GIT_DIR"
    fi
    
    # 确保基础目录存在
    mkdir -p "$GIT_BASE_DIR"
    cd "$GIT_BASE_DIR"
    
    # 克隆仓库
    echo "📥 重新克隆仓库..."
    if git clone "$REPO_URL" secure-streaming-platform; then
        echo "✅ 仓库克隆成功"
        return 0
    else
        echo "❌ 仓库克隆失败"
        return 1
    fi
}

# 函数：尝试修复Git仓库
repair_git() {
    echo "🔧 尝试修复Git仓库..."
    cd "$GIT_DIR" || return 1
    
    # 清理和重置
    git clean -fd
    git reset --hard HEAD
    
    # 重建索引
    rm -f .git/index
    git reset
    
    # 垃圾回收
    git gc --aggressive --prune=now
    
    # 再次检查健康状态
    if check_git_health; then
        echo "✅ Git仓库修复成功"
        return 0
    else
        echo "❌ Git仓库修复失败"
        return 1
    fi
}

# 函数：更新代码
update_code() {
    echo "📥 更新代码..."
    
    # 首先检查Git仓库是否存在
    if [ ! -d "$GIT_DIR" ]; then
        echo "⚠️ Git目录不存在，执行首次克隆..."
        fresh_clone || return 1
    fi
    
    # 检查Git仓库健康状态
    if ! check_git_health; then
        echo "⚠️ Git仓库损坏，尝试修复..."
        if ! repair_git; then
            echo "⚠️ 修复失败，执行完全重新克隆..."
            fresh_clone || return 1
        fi
    fi
    
    # 进入Git目录
    cd "$GIT_DIR" || return 1
    
    # 强制拉取最新代码
    echo "🔄 拉取最新代码..."
    git fetch origin master || {
        echo "⚠️ 拉取失败，尝试重新克隆..."
        fresh_clone || return 1
        cd "$GIT_DIR" || return 1
    }
    
    # 强制重置到最新版本
    git reset --hard origin/master
    
    echo "✅ 代码更新完成: $(git rev-parse --short HEAD)"
    return 0
}

# 函数：备份当前代码
backup_current() {
    if [ -d "$TARGET_DIR" ]; then
        echo "💾 备份当前代码到 $BACKUP_DIR..."
        mkdir -p "$(dirname "$BACKUP_DIR")"
        cp -r "$TARGET_DIR" "$BACKUP_DIR"
        echo "✅ 备份完成"
    fi
}

# 函数：同步代码
sync_code() {
    echo "🔄 同步代码到目标目录..."
    
    # 检查源目录是否存在
    if [ ! -d "$SOURCE_DIR" ]; then
        echo "❌ 源代码目录不存在: $SOURCE_DIR"
        return 1
    fi
    
    # 创建目标目录
    mkdir -p "$TARGET_DIR"
    
    # 同步代码
    if command -v rsync >/dev/null 2>&1; then
        rsync -av --delete "$SOURCE_DIR/" "$TARGET_DIR/"
        echo "✅ rsync同步完成"
    else
        rm -rf "$TARGET_DIR"/*
        cp -r "$SOURCE_DIR"/* "$TARGET_DIR/"
        echo "✅ cp同步完成"
    fi
    
    return 0
}

# 函数：配置环境
configure_environment() {
    echo "⚙️ 配置环境变量..."
    
    local env_file="$TARGET_DIR/../.env"
    
    # 创建.env文件
    if [ ! -f "$env_file" ]; then
        echo "📝 创建.env文件..."
        cat > "$env_file" << EOF
# 服务器配置
PORT=3000
NODE_ENV=production

# API安全配置
API_SECRET_KEY=$API_SECRET_KEY

# FFmpeg配置
FFMPEG_PATH=/usr/bin/ffmpeg
HLS_OUTPUT_DIR=/var/www/hls
HLS_SEGMENT_TIME=2
HLS_LIST_SIZE=6

# 日志配置
LOG_LEVEL=info
LOG_DIR=/var/log/transcoder

# Cloudflare IP范围验证 (可选)
ENABLE_IP_WHITELIST=false
EOF
    else
        echo "🔧 更新现有.env文件..."
        # 更新API密钥
        if grep -q "API_SECRET_KEY=" "$env_file"; then
            sed -i "s/API_SECRET_KEY=.*/API_SECRET_KEY=$API_SECRET_KEY/" "$env_file"
        else
            echo "API_SECRET_KEY=$API_SECRET_KEY" >> "$env_file"
        fi
        
        # 确保生产环境
        if grep -q "NODE_ENV=" "$env_file"; then
            sed -i "s/NODE_ENV=.*/NODE_ENV=production/" "$env_file"
        else
            echo "NODE_ENV=production" >> "$env_file"
        fi
        
        # 禁用IP白名单（开发阶段）
        if grep -q "ENABLE_IP_WHITELIST=" "$env_file"; then
            sed -i "s/ENABLE_IP_WHITELIST=.*/ENABLE_IP_WHITELIST=false/" "$env_file"
        else
            echo "ENABLE_IP_WHITELIST=false" >> "$env_file"
        fi
    fi
    
    echo "✅ 环境配置完成"
}

# 函数：创建必要目录
create_directories() {
    echo "📁 创建必要目录..."
    
    local dirs=(
        "/var/www/hls"
        "/var/log/transcoder"
        "/opt/yoyo-transcoder"
    )
    
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            echo "✅ 创建目录: $dir"
        fi
    done
    
    # 设置权限
    chown -R root:root /var/www/hls /var/log/transcoder /opt/yoyo-transcoder
    chmod -R 755 /var/www/hls /var/log/transcoder /opt/yoyo-transcoder
    
    echo "✅ 目录创建完成"
}

# 函数：验证关键文件
verify_files() {
    echo "🔍 验证关键文件..."
    
    local key_files=(
        "$TARGET_DIR/app.js"
        "$TARGET_DIR/routes/simple-stream.js"
        "$TARGET_DIR/services/SimpleStreamManager.js"
        "$TARGET_DIR/middleware/auth.js"
    )
    
    local missing_files=()
    
    for file in "${key_files[@]}"; do
        if [ -f "$file" ]; then
            echo "✅ $(basename "$file")"
        else
            echo "❌ $(basename "$file") - 缺失"
            missing_files+=("$file")
        fi
    done
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        echo "❌ 发现缺失文件，部署可能不完整"
        return 1
    fi
    
    echo "✅ 所有关键文件验证通过"
    return 0
}

# 函数：重启服务
restart_service() {
    echo "🔄 重启PM2服务..."
    
    # 检查PM2是否安装
    if ! command -v pm2 >/dev/null 2>&1; then
        echo "❌ PM2未安装，请先安装PM2"
        return 1
    fi
    
    # 进入目标目录
    cd "$TARGET_DIR/.." || return 1
    
    # 重启服务
    if pm2 restart vps-transcoder-api 2>/dev/null; then
        echo "✅ PM2重启成功"
    elif pm2 reload vps-transcoder-api 2>/dev/null; then
        echo "✅ PM2重载成功"
    else
        echo "⚠️ PM2重启失败，尝试启动新实例..."
        pm2 start src/app.js --name vps-transcoder-api
    fi
    
    # 等待服务启动
    sleep 5
    
    # 检查服务状态
    if pm2 list | grep -q "vps-transcoder-api.*online"; then
        echo "✅ 服务运行正常"
        return 0
    else
        echo "❌ 服务启动失败"
        pm2 logs vps-transcoder-api --lines 10 --nostream
        return 1
    fi
}

# 函数：健康检查
health_check() {
    echo "🏥 执行健康检查..."
    
    local max_attempts=5
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "🔍 健康检查尝试 $attempt/$max_attempts..."
        
        if curl -s http://localhost:3000/health >/dev/null; then
            echo "✅ 基础健康检查通过"
            
            # 检查SimpleStream API
            if curl -s http://localhost:3000/api/simple-stream/health >/dev/null; then
                echo "✅ SimpleStream API健康检查通过"
                return 0
            else
                echo "⚠️ SimpleStream API不可用"
            fi
        else
            echo "⚠️ 基础健康检查失败"
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            echo "⏳ 等待5秒后重试..."
            sleep 5
        fi
        
        ((attempt++))
    done
    
    echo "❌ 健康检查失败，查看服务日志："
    pm2 logs vps-transcoder-api --lines 10 --nostream
    return 1
}

# 函数：测试API认证
test_api_auth() {
    echo "🧪 测试API认证..."
    
    local test_url="http://localhost:3000/api/simple-stream/start-watching"
    
    # 测试无API Key (应该返回401)
    echo "📝 测试无API Key..."
    local status1=$(curl -s -w "%{http_code}" -o /dev/null \
        -X POST "$test_url" \
        -H 'Content-Type: application/json' \
        -d '{"channelId":"test","rtmpUrl":"rtmp://test.com/live/test"}')
    
    if [ "$status1" = "401" ]; then
        echo "✅ 无API Key正确返回401"
    else
        echo "⚠️ 无API Key返回状态码: $status1 (期望401)"
    fi
    
    # 测试错误API Key (应该返回403)
    echo "📝 测试错误API Key..."
    local status2=$(curl -s -w "%{http_code}" -o /dev/null \
        -X POST "$test_url" \
        -H 'Content-Type: application/json' \
        -H 'X-API-Key: wrong-key' \
        -d '{"channelId":"test","rtmpUrl":"rtmp://test.com/live/test"}')
    
    if [ "$status2" = "403" ]; then
        echo "✅ 错误API Key正确返回403"
    else
        echo "⚠️ 错误API Key返回状态码: $status2 (期望403)"
    fi
    
    # 测试正确API Key (应该返回200或500)
    echo "📝 测试正确API Key..."
    local status3=$(curl -s -w "%{http_code}" -o /dev/null \
        -X POST "$test_url" \
        -H 'Content-Type: application/json' \
        -H "X-API-Key: $API_SECRET_KEY" \
        -d '{"channelId":"test","rtmpUrl":"rtmp://test.com/live/test"}')
    
    if [ "$status3" = "200" ] || [ "$status3" = "500" ]; then
        echo "✅ 正确API Key认证通过 (状态码: $status3)"
    else
        echo "⚠️ 正确API Key返回状态码: $status3 (期望200或500)"
    fi
    
    echo "✅ API认证测试完成"
}

# 主执行流程
main() {
    echo "🎯 开始VPS强力部署流程..."
    
    # 1. 更新代码
    if ! update_code; then
        echo "❌ 代码更新失败"
        exit 1
    fi
    
    # 2. 备份当前代码
    backup_current
    
    # 3. 同步代码
    if ! sync_code; then
        echo "❌ 代码同步失败"
        exit 1
    fi
    
    # 4. 配置环境
    configure_environment
    
    # 5. 创建必要目录
    create_directories
    
    # 6. 验证关键文件
    if ! verify_files; then
        echo "❌ 文件验证失败"
        exit 1
    fi
    
    # 7. 重启服务
    if ! restart_service; then
        echo "❌ 服务重启失败"
        exit 1
    fi
    
    # 8. 健康检查
    if ! health_check; then
        echo "❌ 健康检查失败"
        exit 1
    fi
    
    # 9. 测试API认证
    test_api_auth
    
    echo ""
    echo "🎉 VPS强力部署完成！"
    echo "时间: $(date)"
    echo ""
    echo "✅ 部署总结："
    echo "- Git仓库: 健康"
    echo "- 代码同步: 完成"
    echo "- 环境配置: 完成"
    echo "- 服务状态: 运行中"
    echo "- 健康检查: 通过"
    echo "- API认证: 配置完成"
    echo ""
    echo "🔗 测试命令："
    echo "curl -X POST http://localhost:3000/api/simple-stream/start-watching \\"
    echo "  -H 'Content-Type: application/json' \\"
    echo "  -H 'X-API-Key: $API_SECRET_KEY' \\"
    echo "  -d '{\"channelId\":\"test\",\"rtmpUrl\":\"rtmp://test.com/live/test\"}'"
    echo ""
    echo "📊 查看服务状态: pm2 status"
    echo "📋 查看服务日志: pm2 logs vps-transcoder-api"
}

# 执行主流程
main "$@"
