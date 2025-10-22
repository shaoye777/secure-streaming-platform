# Proxy Mode Debug Script
$token = "5dab17ea-f455-4952-9e88-4ef398f87165"

Write-Host "=== Proxy Mode Debug ===" -ForegroundColor Cyan

# 1. Test Workers Health
Write-Host "1. Testing Workers Health..." -ForegroundColor Yellow
try {
    $workersHealth = Invoke-RestMethod -Uri "https://yoyoapi.5202021.xyz/health" -Method GET -TimeoutSec 10
    Write-Host "OK Workers: $($workersHealth.status)" -ForegroundColor Green
} catch {
    Write-Host "FAIL Workers: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 2. Test Auth
Write-Host "2. Testing Auth..." -ForegroundColor Yellow
try {
    $authTest = Invoke-RestMethod -Uri "https://yoyoapi.5202021.xyz/api/me" -Method GET -Headers @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "application/json"
    }
    Write-Host "OK Auth: $($authTest.data.username)" -ForegroundColor Green
} catch {
    Write-Host "FAIL Auth: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 3. Check Proxy Status
Write-Host "3. Checking Proxy Status..." -ForegroundColor Yellow
try {
    $proxyStatus = Invoke-RestMethod -Uri "https://yoyoapi.5202021.xyz/api/admin/proxy/status" -Method GET -Headers @{
        "Authorization" = "Bearer $token"
    }
    Write-Host "OK Proxy Connected: $($proxyStatus.data.isConnected)" -ForegroundColor Green
    Write-Host "   Mode: $($proxyStatus.data.currentMode)" -ForegroundColor Cyan
} catch {
    Write-Host "FAIL Proxy Status: $($_.Exception.Message)" -ForegroundColor Red
}

# 4. Get Streams
Write-Host "4. Getting Streams..." -ForegroundColor Yellow
try {
    $streams = Invoke-RestMethod -Uri "https://yoyoapi.5202021.xyz/api/streams" -Method GET -Headers @{
        "Authorization" = "Bearer $token"
    }
    Write-Host "OK Streams: $($streams.data.streams.Count) channels" -ForegroundColor Green
    $testChannel = $streams.data.streams[0]
    Write-Host "   Test Channel: $($testChannel.name) ($($testChannel.id))" -ForegroundColor Cyan
} catch {
    Write-Host "FAIL Streams: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 5. Test Start Watching
Write-Host "5. Testing Start Watching..." -ForegroundColor Yellow
try {
    $startWatching = Invoke-RestMethod -Uri "https://yoyoapi.5202021.xyz/api/simple-stream/start-watching" -Method POST -Headers @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "application/json"
    } -Body (@{
        channelId = $testChannel.id
    } | ConvertTo-Json) -TimeoutSec 30
    
    Write-Host "OK Start Watching Success" -ForegroundColor Green
    Write-Host "   Channel: $($startWatching.data.channelName)" -ForegroundColor Cyan
    Write-Host "   HLS URL: $($startWatching.data.hlsUrl)" -ForegroundColor Cyan
    Write-Host "   Routing: $($startWatching.data.routingMode)" -ForegroundColor Cyan
    
    # 6. Test HLS Access
    Write-Host "6. Testing HLS Access..." -ForegroundColor Yellow
    try {
        $hlsResponse = Invoke-WebRequest -Uri $startWatching.data.hlsUrl -Method GET -TimeoutSec 10
        Write-Host "OK HLS Access: Status $($hlsResponse.StatusCode)" -ForegroundColor Green
        Write-Host "   Content Length: $($hlsResponse.Content.Length) bytes" -ForegroundColor Cyan
    } catch {
        Write-Host "FAIL HLS Access: $($_.Exception.Message)" -ForegroundColor Red
    }
    
} catch {
    Write-Host "FAIL Start Watching: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ErrorDetails.Message) {
        Write-Host "   Details: $($_.ErrorDetails.Message)" -ForegroundColor Yellow
    }
}

Write-Host "=== Debug Complete ===" -ForegroundColor Cyan
