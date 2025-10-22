#!/bin/bash

# VPS Git修复脚本 - 专门处理Git仓库损坏问题
# 当出现 "unable to read sha1 file" 错误时使用

echo "🔧 VPS Git修复脚本启动 - $(date)"

# 配置变量
REPO_URL="https://github.com/shao-ye/secure-streaming-platform.git"
GIT_BASE_DIR="/tmp/github"
GIT_DIR="$GIT_BASE_DIR/secure-streaming-platform"

# 函数：完全重建Git仓库
rebuild_git_repo() {
    echo "🚨 检测到Git仓库严重损坏，执行完全重建..."
    
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
            echo "📊 分支信息: $(git branch -a)"
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

# 函数：尝试轻量级修复
try_light_repair() {
    echo "🔧 尝试轻量级Git修复..."
    
    cd "$GIT_DIR" || return 1
    
    # 1. 清理工作目录
    echo "🧹 清理工作目录..."
    git clean -fd
    
    # 2. 重置索引
    echo "🔄 重置Git索引..."
    rm -f .git/index
    git reset
    
    # 3. 垃圾回收
    echo "🗑️ 执行垃圾回收..."
    git gc --aggressive --prune=now
    
    # 4. 验证修复结果
    if git status >/dev/null 2>&1 && git fsck --no-progress >/dev/null 2>&1; then
        echo "✅ 轻量级修复成功"
        return 0
    else
        echo "❌ 轻量级修复失败"
        return 1
    fi
}

# 函数：检查Git仓库状态
check_git_status() {
    echo "🔍 检查Git仓库状态..."
    
    # 检查目录是否存在
    if [ ! -d "$GIT_DIR" ]; then
        echo "❌ Git目录不存在: $GIT_DIR"
        return 1
    fi
    
    cd "$GIT_DIR" || return 1
    
    # 检查是否是Git仓库
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo "❌ 不是有效的Git仓库"
        return 1
    fi
    
    # 检查仓库完整性
    echo "🔍 检查仓库完整性..."
    if git fsck --no-progress >/dev/null 2>&1; then
        echo "✅ 仓库完整性检查通过"
    else
        echo "❌ 仓库存在损坏的对象"
        return 1
    fi
    
    # 检查状态命令
    if git status >/dev/null 2>&1; then
        echo "✅ Git状态命令正常"
        echo "📊 当前状态:"
        git status --porcelain
        echo "📊 当前分支: $(git branch --show-current)"
        echo "📊 当前提交: $(git rev-parse --short HEAD)"
        return 0
    else
        echo "❌ Git状态命令失败"
        return 1
    fi
}

# 函数：显示修复选项
show_repair_options() {
    echo ""
    echo "🛠️ Git修复选项："
    echo "1. 轻量级修复 (推荐先尝试)"
    echo "2. 完全重建仓库 (彻底解决)"
    echo "3. 仅检查状态"
    echo "4. 退出"
    echo ""
}

# 函数：交互式修复
interactive_repair() {
    while true; do
        show_repair_options
        read -p "请选择修复选项 (1-4): " choice
        
        case $choice in
            1)
                echo "🔧 执行轻量级修复..."
                if try_light_repair; then
                    echo "✅ 轻量级修复完成"
                    check_git_status
                    break
                else
                    echo "❌ 轻量级修复失败，建议选择选项2"
                fi
                ;;
            2)
                echo "🚨 执行完全重建..."
                if rebuild_git_repo; then
                    echo "✅ 完全重建完成"
                    break
                else
                    echo "❌ 完全重建失败"
                fi
                ;;
            3)
                check_git_status
                ;;
            4)
                echo "👋 退出修复脚本"
                exit 0
                ;;
            *)
                echo "❌ 无效选项，请选择1-4"
                ;;
        esac
        echo ""
    done
}

# 函数：自动修复
auto_repair() {
    echo "🤖 自动修复模式..."
    
    # 首先检查当前状态
    if check_git_status; then
        echo "✅ Git仓库状态正常，无需修复"
        return 0
    fi
    
    # 尝试轻量级修复
    echo "🔧 尝试轻量级修复..."
    if try_light_repair && check_git_status; then
        echo "✅ 轻量级修复成功"
        return 0
    fi
    
    # 轻量级修复失败，执行完全重建
    echo "🚨 轻量级修复失败，执行完全重建..."
    if rebuild_git_repo; then
        echo "✅ 完全重建成功"
        return 0
    else
        echo "❌ 所有修复尝试都失败了"
        return 1
    fi
}

# 主函数
main() {
    echo "🎯 Git修复脚本参数: $*"
    
    # 检查参数
    if [ "$1" = "--auto" ] || [ "$1" = "-a" ]; then
        auto_repair
    elif [ "$1" = "--rebuild" ] || [ "$1" = "-r" ]; then
        rebuild_git_repo
    elif [ "$1" = "--check" ] || [ "$1" = "-c" ]; then
        check_git_status
    else
        echo "🔍 首先检查当前Git状态..."
        if check_git_status; then
            echo "✅ Git仓库状态正常"
            echo ""
            echo "💡 如果仍有问题，可以使用以下参数："
            echo "  --auto   : 自动修复"
            echo "  --rebuild: 完全重建"
            echo "  --check  : 仅检查状态"
        else
            echo ""
            echo "❌ 检测到Git问题，启动交互式修复..."
            interactive_repair
        fi
    fi
    
    echo ""
    echo "🎉 Git修复脚本完成 - $(date)"
}

# 执行主函数
main "$@"
