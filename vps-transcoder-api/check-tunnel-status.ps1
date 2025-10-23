$body = '{"username":"admin","password":"admin123"}'
$loginResp = Invoke-RestMethod -Uri "https://yoyoapi.5202021.xyz/api/login" -Method Post -Body $body -ContentType "application/json"
$token = $loginResp.data.token

Write-Host "=== 隧道配置检查 ===" -ForegroundColor Cyan

# 检查KV中的隧道配置
try {
    $kvTunnel = Invoke-RestMethod -Uri "https://yoyoapi.5202021.xyz/api/admin/kv/RUNTIME_TUNNEL_ENABLED" -Headers @{Authorization="Bearer $token"}
    Write-Host "`nKV中的隧道状态: $($kvTunnel.data.value)"
} catch {
    Write-Host "`n隧道配置不存在于KV中"
}

# 测试隧道端点
Write-Host "`n=== 测试端点连通性 ===" -ForegroundColor Yellow

Write-Host "`n1. 测试直连端点:"
try {
    $direct = Invoke-RestMethod -Uri "https://yoyo-vps.5202021.xyz/health" -TimeoutSec 5
    Write-Host "   直连端点: ✅ 正常 (yoyo-vps.5202021.xyz)"
} catch {
    Write-Host "   直连端点: ❌ 失败"
}

Write-Host "`n2. 测试隧道端点:"
try {
    $tunnel = Invoke-RestMethod -Uri "https://tunnel-api.yoyo-vps.5202021.xyz/health" -TimeoutSec 5
    Write-Host "   隧道端点: ✅ 正常 (tunnel-api.yoyo-vps.5202021.xyz)"
} catch {
    Write-Host "   隧道端点: ❌ 失败或未配置"
}
