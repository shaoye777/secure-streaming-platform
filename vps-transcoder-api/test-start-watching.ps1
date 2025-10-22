# 测试start-watching API
# 首先登录获取token
$loginBody = @{
    username = "admin"
    password = "admin123"
} | ConvertTo-Json

$loginResponse = Invoke-RestMethod -Uri "https://yoyoapi.5202021.xyz/api/login" -Method Post -Body $loginBody -ContentType "application/json" -SessionVariable session

Write-Host "登录成功！Token: $($loginResponse.data.token.substring(0,20))..."

# 测试start-watching
$headers = @{
    "Authorization" = "Bearer $($loginResponse.data.token)"
    "Content-Type" = "application/json"
}

$watchBody = @{
    channelId = "stream_cpa2czoo"
} | ConvertTo-Json

Write-Host "`n测试start-watching API..."
try {
    $watchResponse = Invoke-RestMethod -Uri "https://yoyoapi.5202021.xyz/api/simple-stream/start-watching" -Method Post -Headers $headers -Body $watchBody
    Write-Host "Success!" -ForegroundColor Green
    $watchResponse | ConvertTo-Json -Depth 5
} catch {
    Write-Host "Failed!" -ForegroundColor Red
    Write-Host $_.Exception.Message
    if ($_.ErrorDetails.Message) {
        Write-Host ($_.ErrorDetails.Message | ConvertFrom-Json | ConvertTo-Json -Depth 5)
    }
}
