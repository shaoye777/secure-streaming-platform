$body = @{
    username = "admin"
    password = "admin123"
} | ConvertTo-Json

$login = Invoke-RestMethod -Uri "https://yoyoapi.5202021.xyz/api/login" -Method Post -Body $body -ContentType "application/json"
$headers = @{Authorization = "Bearer $($login.data.token)"}

Write-Host "=== 获取频道列表 ===" -ForegroundColor Cyan
$streams = Invoke-RestMethod -Uri "https://yoyoapi.5202021.xyz/api/admin/streams" -Headers $headers

Write-Host "`n频道数量: $($streams.data.streams.Count)"
Write-Host "`n频道列表:"
foreach ($stream in $streams.data.streams) {
    Write-Host "  - ID: $($stream.id)" -ForegroundColor Yellow
    Write-Host "    Name: $($stream.name)"
    Write-Host "    RTMP: $($stream.rtmpUrl)"
}

if ($streams.data.streams.Count -gt 0) {
    $firstChannel = $streams.data.streams[0].id
    Write-Host "`n=== 测试第一个频道播放 ===" -ForegroundColor Cyan
    Write-Host "Channel ID: $firstChannel"
    
    try {
        $watchBody = @{
            channelId = $firstChannel
        } | ConvertTo-Json
        
        $watch = Invoke-RestMethod -Uri "https://yoyoapi.5202021.xyz/api/simple-stream/start-watching" -Method Post -Body $watchBody -ContentType "application/json" -Headers $headers
        Write-Host "`nSuccess: $($watch.success)" -ForegroundColor Green
        Write-Host "HLS URL: $($watch.data.hlsUrl)"
    } catch {
        Write-Host "`nERROR: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.ErrorDetails.Message) {
            $errorObj = $_.ErrorDetails.Message | ConvertFrom-Json
            Write-Host "Error Code: $($errorObj.code)" -ForegroundColor Red
            Write-Host "Message: $($errorObj.message)" -ForegroundColor Red
            if ($errorObj.details) {
                Write-Host "Details: $($errorObj.details | ConvertTo-Json)" -ForegroundColor Red
            }
        }
    }
}
