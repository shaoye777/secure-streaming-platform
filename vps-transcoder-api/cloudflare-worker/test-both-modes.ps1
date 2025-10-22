# 测试两种模式
$token = "5dab17ea-f455-4952-9e88-4ef398f87165"

Write-Host "=== 测试两种路由模式 ===" -ForegroundColor Cyan

# 测试当前模式
Write-Host "1. 测试当前模式..." -ForegroundColor Yellow
try {
    $response1 = Invoke-RestMethod -Uri "https://yoyoapi.5202021.xyz/api/simple-stream/start-watching" -Method POST -Headers @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "application/json"
    } -Body (@{
        channelId = "stream_cpa2czoo"
    } | ConvertTo-Json)
    
    Write-Host "✅ 当前模式响应成功:" -ForegroundColor Green
    Write-Host "路由模式: $($response1.data.routingMode)"
    Write-Host "HLS URL: $($response1.data.hlsUrl)"
} catch {
    Write-Host "❌ 当前模式失败: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "2. 切换代理状态..." -ForegroundColor Yellow

# 如果当前是proxy，切换到direct；如果是direct，切换到proxy
if ($response1.data.routingMode -eq "proxy") {
    Write-Host "当前是代理模式，切换到直连模式..."
    try {
        Invoke-RestMethod -Uri "https://yoyoapi.5202021.xyz/api/admin/proxy/disconnect" -Method POST -Headers @{
            "Authorization" = "Bearer $token"
            "Content-Type" = "application/json"
        } | Out-Null
        Write-Host "✅ 已切换到直连模式" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ 切换失败: $($_.Exception.Message)" -ForegroundColor Yellow
    }
} else {
    Write-Host "当前是直连模式，切换到代理模式..."
    try {
        Invoke-RestMethod -Uri "https://yoyoapi.5202021.xyz/api/admin/proxy/connect" -Method POST -Headers @{
            "Authorization" = "Bearer $token"
            "Content-Type" = "application/json"
        } -Body (@{
            proxyId = "proxy_1760948716295_gzz9denbf"
        } | ConvertTo-Json) | Out-Null
        Write-Host "✅ 已切换到代理模式" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ 切换失败: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# 等待状态同步
Start-Sleep -Seconds 3

Write-Host ""
Write-Host "3. 测试切换后的模式..." -ForegroundColor Yellow
try {
    $response2 = Invoke-RestMethod -Uri "https://yoyoapi.5202021.xyz/api/simple-stream/start-watching" -Method POST -Headers @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "application/json"
    } -Body (@{
        channelId = "stream_cpa2czoo"
    } | ConvertTo-Json)
    
    Write-Host "✅ 切换后模式响应成功:" -ForegroundColor Green
    Write-Host "路由模式: $($response2.data.routingMode)"
    Write-Host "HLS URL: $($response2.data.hlsUrl)"
} catch {
    Write-Host "❌ 切换后模式失败: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== 测试结果总结 ===" -ForegroundColor Cyan
Write-Host "模式1: $($response1.data.routingMode) - $(if($response1) {'成功'} else {'失败'})"
Write-Host "模式2: $($response2.data.routingMode) - $(if($response2) {'成功'} else {'失败'})"

if ($response1 -and $response2) {
    Write-Host "🎉 两种模式都工作正常！" -ForegroundColor Green
} else {
    Write-Host "⚠️ 部分模式存在问题" -ForegroundColor Yellow
}
