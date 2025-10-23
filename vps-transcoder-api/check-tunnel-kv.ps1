$body = @{
    username = "admin"
    password = "admin123"
} | ConvertTo-Json

$login = Invoke-RestMethod -Uri "https://yoyoapi.5202021.xyz/api/login" -Method Post -Body $body -ContentType "application/json"
$headers = @{Authorization = "Bearer $($login.data.token)"}

Write-Host "=== 检查隧道配置 ===" -ForegroundColor Cyan

# 读取KV中的隧道状态
try {
    $tunnelStatus = Invoke-RestMethod -Uri "https://yoyoapi.5202021.xyz/api/admin/kv/RUNTIME_TUNNEL_ENABLED" -Headers $headers
    Write-Host "`nKV中的隧道状态:"
    Write-Host "  Key: RUNTIME_TUNNEL_ENABLED"
    Write-Host "  Value: $($tunnelStatus.data.value)" -ForegroundColor Yellow
    Write-Host "  启用: $($tunnelStatus.data.value -eq 'true')" -ForegroundColor $(if ($tunnelStatus.data.value -eq 'true') { 'Green' } else { 'Red' })
} catch {
    Write-Host "`n隧道配置不存在（默认关闭）" -ForegroundColor Yellow
}

Write-Host "`n=== 问题说明 ===" -ForegroundColor Cyan
Write-Host "即使隧道关闭（false），每次HLS请求仍然需要："
Write-Host "  1. 读取KV检查状态"
Write-Host "  2. 发现是false"
Write-Host "  3. 使用直连模式"
Write-Host "`n优化前: 每次HLS请求都读取KV (8400次/小时)"
Write-Host "优化后: 30秒内只读取1次KV (120次/小时)" -ForegroundColor Green
