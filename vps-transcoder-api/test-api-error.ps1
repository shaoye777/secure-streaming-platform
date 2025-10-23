# 测试API端点
Write-Host "=== 测试Workers API ===" -ForegroundColor Cyan

# 1. Health check
Write-Host "`n1. Health Check:"
try {
    $health = Invoke-RestMethod -Uri "https://yoyoapi.5202021.xyz/health"
    Write-Host "   Status: $($health.status)" -ForegroundColor Green
    Write-Host "   Service: $($health.service)"
    Write-Host "   Version: $($health.version)"
} catch {
    Write-Host "   ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   Status Code: $($_.Exception.Response.StatusCode.value__)"
}

# 2. Login
Write-Host "`n2. Login Test:"
try {
    $body = @{
        username = "admin"
        password = "admin123"
    } | ConvertTo-Json
    
    $login = Invoke-RestMethod -Uri "https://yoyoapi.5202021.xyz/api/login" -Method Post -Body $body -ContentType "application/json"
    Write-Host "   Success: $($login.success)" -ForegroundColor Green
    $token = $login.data.token
    Write-Host "   Token: $($token.Substring(0, 20))..."
    
    # 3. Test start-watching
    Write-Host "`n3. Start Watching Test:"
    try {
        $headers = @{Authorization = "Bearer $token"}
        $watchBody = @{
            channelId = "stream_1734327677088_bvlxvhtxf"
        } | ConvertTo-Json
        
        $watch = Invoke-RestMethod -Uri "https://yoyoapi.5202021.xyz/api/simple-stream/start-watching" -Method Post -Body $watchBody -ContentType "application/json" -Headers $headers
        Write-Host "   Success: $($watch.success)" -ForegroundColor Green
        Write-Host "   HLS URL: $($watch.data.hlsUrl)"
    } catch {
        Write-Host "   ERROR: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.ErrorDetails.Message) {
            Write-Host "   Details: $($_.ErrorDetails.Message)" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "   ERROR: $($_.Exception.Message)" -ForegroundColor Red
}
