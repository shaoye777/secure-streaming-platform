# 代理模式调试测试脚本
$token = "5dab17ea-f455-4952-9e88-4ef398f87165"

Write-Host "=== 代理模式播放问题调试 ===" -ForegroundColor Cyan

# 1. 测试Workers健康状态
Write-Host "1. 检查Workers健康状态..." -ForegroundColor Yellow
try {
    $workersHealth = Invoke-RestMethod -Uri "https://yoyoapi.5202021.xyz/health" -Method GET -TimeoutSec 10
    Write-Host "✅ Workers正常: $($workersHealth.status)" -ForegroundColor Green
} catch {
    Write-Host "❌ Workers连接失败: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 2. 测试用户认证
Write-Host "2. 测试用户认证..." -ForegroundColor Yellow
try {
    $authTest = Invoke-RestMethod -Uri "https://yoyoapi.5202021.xyz/api/auth/verify" -Method POST -Headers @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "application/json"
    }
    Write-Host "✅ 认证成功: $($authTest.data.username)" -ForegroundColor Green
} catch {
    Write-Host "❌ 认证失败: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 3. 检查当前代理状态
Write-Host "3. 检查当前代理状态..." -ForegroundColor Yellow
try {
    $proxyStatus = Invoke-RestMethod -Uri "https://yoyoapi.5202021.xyz/api/admin/proxy/status" -Method GET -Headers @{
        "Authorization" = "Bearer $token"
    }
    Write-Host "✅ 代理状态: $($proxyStatus.data.isConnected)" -ForegroundColor Green
    Write-Host "   当前模式: $($proxyStatus.data.currentMode)" -ForegroundColor Cyan
    if ($proxyStatus.data.isConnected) {
        Write-Host "   代理配置: $($proxyStatus.data.activeProxy.name)" -ForegroundColor Cyan
    }
} catch {
    Write-Host "❌ 代理状态检查失败: $($_.Exception.Message)" -ForegroundColor Red
}

# 4. 测试频道配置获取
Write-Host "4. 测试频道配置获取..." -ForegroundColor Yellow
try {
    $streams = Invoke-RestMethod -Uri "https://yoyoapi.5202021.xyz/api/streams" -Method GET -Headers @{
        "Authorization" = "Bearer $token"
    }
    Write-Host "✅ 频道配置获取成功，共 $($streams.data.streams.Count) 个频道" -ForegroundColor Green
    $testChannel = $streams.data.streams[0]
    Write-Host "   测试频道: $($testChannel.name) ($($testChannel.id))" -ForegroundColor Cyan
} catch {
    Write-Host "❌ 频道配置获取失败: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 5. 测试start-watching API
Write-Host "5. 测试start-watching API..." -ForegroundColor Yellow
try {
    $startWatching = Invoke-RestMethod -Uri "https://yoyoapi.5202021.xyz/api/simple-stream/start-watching" -Method POST -Headers @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "application/json"
    } -Body (@{
        channelId = $testChannel.id
    } | ConvertTo-Json) -TimeoutSec 30
    
    Write-Host "✅ start-watching成功" -ForegroundColor Green
    Write-Host "   频道ID: $($startWatching.data.channelId)" -ForegroundColor Cyan
    Write-Host "   频道名: $($startWatching.data.channelName)" -ForegroundColor Cyan
    Write-Host "   HLS URL: $($startWatching.data.hlsUrl)" -ForegroundColor Cyan
    Write-Host "   路由模式: $($startWatching.data.routingMode)" -ForegroundColor Cyan
    
    # 6. 测试HLS文件访问
    Write-Host "6. 测试HLS文件访问..." -ForegroundColor Yellow
    try {
        $hlsResponse = Invoke-WebRequest -Uri $startWatching.data.hlsUrl -Method GET -TimeoutSec 10
        Write-Host "✅ HLS文件访问成功，状态码: $($hlsResponse.StatusCode)" -ForegroundColor Green
        Write-Host "   内容长度: $($hlsResponse.Content.Length) 字节" -ForegroundColor Cyan
        
        # 显示HLS文件前几行
        $hlsLines = $hlsResponse.Content -split "`n" | Select-Object -First 5
        Write-Host "   HLS内容预览:" -ForegroundColor Cyan
        foreach ($line in $hlsLines) {
            Write-Host "     $line" -ForegroundColor Gray
        }
    } catch {
        Write-Host "❌ HLS文件访问失败: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "   可能原因: 转码未完成或网络路由问题" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "❌ start-watching失败: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   错误详情: $($_.ErrorDetails.Message)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== 调试完成 ===" -ForegroundColor Cyan
