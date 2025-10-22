#!/bin/bash

# VPS Git问题一键修复脚本
# 专门解决 "unable to read sha1 file" 等Git损坏问题

echo "🔧 VPS Git问题修复脚本启动 - $(date)"

# 配置变量
REPO_URL="https://github.com/shao-ye/secure-streaming-platform.git"
GIT_BASE_DIR="/tmp/github"
GIT_DIR="$GIT_BASE_DIR/secure-streaming-platform"
SOURCE_DIR="$GIT_DIR/vps-transcoder-api/vps-transcoder-api/src"
TARGET_DIR="/opt/yoyo-transcoder/src"

# 函数：完全重建Git仓库
rebuild_git_repo() {
    echo "🚨 Git仓库损坏，执行完全重建..."
    
    # 1. 完全删除损坏的仓库
    echo "🗑️ 删除损坏的Git仓库..."
    if [ -d "$GIT_DIR" ]; then
        rm -rf "$GIT_DIR"
        echo "✅ 旧仓库已删除"
    fi
    
    # 2. 确保基础目录存在
    mkdir -p "$GIT_BASE_DIR"
    cd "$GIT_BASE_DIR"
    
    # 3. 重新克隆仓库
    echo "📥 重新克隆仓库..."
    if git clone "$REPO_URL" secure-streaming-platform; then
        echo "✅ 仓库重新克隆成功"
        
        # 4. 验证克隆结果
        cd "$GIT_DIR"
        if git status >/dev/null 2>&1; then
            echo "✅ 新仓库状态正常"
            echo "📊 当前版本: $(git rev-parse --short HEAD)"
            return 0
        else
            echo "❌ 新仓库状态异常"
            return 1
        fi
    else
        echo "❌ 仓库克隆失败，请检查网络连接"
        return 1
    fi
}

# 函数：同步代码到目标目录
sync_code() {
    echo "🔄 同步代码到目标目录..."
    
    # 检查源目录是否存在
    if [ ! -d "$SOURCE_DIR" ]; then
        echo "❌ 源代码目录不存在: $SOURCE_DIR"
        return 1
    fi
    
    # 备份当前代码
    if [ -d "$TARGET_DIR" ]; then
        backup_dir="/opt/yoyo-transcoder/backup-$(date +%Y%m%d_%H%M%S)"
        echo "💾 备份当前代码到 $backup_dir..."
        mkdir -p "$(dirname "$backup_dir")"
        cp -r "$TARGET_DIR" "$backup_dir"
        echo "✅ 备份完成"
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
configure_env() {
    echo "⚙️ 配置环境变量..."
    
    local env_file="$TARGET_DIR/../.env"
    
    # 创建或更新.env文件
    cat > "$env_file" << 'EOF'
# 服务器配置
PORT=3000
NODE_ENV=production

# API安全配置
API_SECRET_KEY=85da076ae24b028b3d1ea1884e6b13c5afe34b5b

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

# 函数：重启服务
restart_service() {
    echo "🔄 重启PM2服务..."
    
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

# 函数：验证修复结果
verify_fix() {
    echo "🔍 验证修复结果..."
    
    # 检查Git仓库
    if [ -d "$GIT_DIR" ] && cd "$GIT_DIR" && git status >/dev/null 2>&1; then
        echo "✅ Git仓库状态正常"
        echo "📊 当前版本: $(git rev-parse --short HEAD)"
    else
        echo "❌ Git仓库仍有问题"
        return 1
    fi
    
    # 检查关键文件
    local key_files=(
        "$TARGET_DIR/app.js"
        "$TARGET_DIR/routes/simple-stream.js"
        "$TARGET_DIR/middleware/auth.js"
    )
    
    for file in "${key_files[@]}"; do
        if [ -f "$file" ]; then
            echo "✅ $(basename "$file") 存在"
        else
            echo "❌ $(basename "$file") 缺失"
            return 1
        fi
    done
    
    # 检查服务健康
    if curl -s http://localhost:3000/health >/dev/null; then
        echo "✅ 服务健康检查通过"
    else
        echo "⚠️ 服务健康检查失败"
        return 1
    fi
    
    echo "✅ 所有验证通过"
    return 0
}

# 主执行流程
main() {
    echo "🎯 开始Git问题修复流程..."
    
    # 1. 重建Git仓库
    if ! rebuild_git_repo; then
        echo "❌ Git仓库重建失败"
        exit 1
    fi
    
    # 2. 同步代码
    if ! sync_code; then
        echo "❌ 代码同步失败"
        exit 1
    fi
    
    # 3. 配置环境
    configure_env
    
    # 4. 创建目录
    create_directories
    
    # 5. 重启服务
    if ! restart_service; then
        echo "❌ 服务重启失败"
        exit 1
    fi
    
    # 6. 验证修复
    if ! verify_fix; then
        echo "❌ 修复验证失败"
        exit 1
    fi
    
    echo ""
    echo "🎉 Git问题修复完成！"
    echo "时间: $(date)"
    echo ""
    echo "✅ 修复总结："
    echo "- Git仓库: 已重建并正常"
    echo "- 代码同步: 完成"
    echo "- 环境配置: 完成"
    echo "- 服务状态: 运行中"
    echo ""
    echo "🔗 测试命令："
    echo "curl -X POST http://localhost:3000/api/simple-stream/start-watching \\"
    echo "  -H 'Content-Type: application/json' \\"
    echo "  -H 'X-API-Key: 85da076ae24b028b3d1ea1884e6b13c5afe34b5b' \\"
    echo "  -d '{\"channelId\":\"test\",\"rtmpUrl\":\"rtmp://test.com/live/test\"}'"
}

# 执行主流程
main "$@"
