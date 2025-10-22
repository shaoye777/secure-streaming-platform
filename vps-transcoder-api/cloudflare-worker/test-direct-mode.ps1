# 测试直连模式
$token = "5dab17ea-f455-4952-9e88-4ef398f87165"

Write-Host "=== 测试直连模式 ===" -ForegroundColor Cyan

# 1. 先断开代理
Write-Host "1. 断开代理连接..." -ForegroundColor Yellow
try {
    $disconnectResponse = Invoke-RestMethod -Uri "https://yoyoapi.5202021.xyz/api/admin/proxy/disconnect" -Method POST -Headers @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "application/json"
    }
    Write-Host "✅ 代理已断开" -ForegroundColor Green
} catch {
    Write-Host "⚠️ 代理断开失败或已断开: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 2. 等待一下让状态同步
Start-Sleep -Seconds 2

# 3. 测试start-watching API
Write-Host "2. 测试start-watching API (直连模式)..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "https://yoyoapi.5202021.xyz/api/simple-stream/start-watching" -Method POST -Headers @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "application/json"
    } -Body (@{
        channelId = "stream_cpa2czoo"
    } | ConvertTo-Json)
    
    Write-Host "✅ 直连模式成功响应:" -ForegroundColor Green
    Write-Host ($response | ConvertTo-Json -Depth 3)
    
    # 检查路由模式
    if ($response.data.routingMode -eq "direct") {
        Write-Host "✅ 确认使用直连模式" -ForegroundColor Green
    } else {
        Write-Host "⚠️ 路由模式: $($response.data.routingMode)" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "❌ 直连模式请求失败:" -ForegroundColor Red
    Write-Host $_.Exception.Message
}

Write-Host "=== 直连模式测试完成 ===" -ForegroundColor Cyan
