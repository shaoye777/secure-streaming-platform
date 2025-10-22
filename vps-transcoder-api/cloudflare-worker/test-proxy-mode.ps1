# 测试代理模式下的API调用
Write-Host "=== 测试代理模式API调用 ==="

# 1. 先登录获取token
Write-Host "`n1. 登录获取token..."
try {
    $loginResponse = Invoke-RestMethod -Uri "https://yoyoapi.5202021.xyz/api/login" -Method POST -Headers @{"Content-Type"="application/json"} -Body '{"username":"admin","password":"admin123"}'
    $token = $loginResponse.data.token
    Write-Host "✅ 登录成功，token: $token"
} catch {
    Write-Host "❌ 登录失败: $($_.Exception.Message)"
    exit 1
}

# 2. 获取频道列表
Write-Host "`n2. 获取频道列表..."
try {
    $streams = Invoke-RestMethod -Uri "https://yoyoapi.5202021.xyz/api/streams" -Method GET -Headers @{"Authorization"="Bearer $token"}
    $firstChannel = $streams.data.streams[0]
    Write-Host "✅ 获取频道成功，第一个频道: $($firstChannel.id) - $($firstChannel.name)"
} catch {
    Write-Host "❌ 获取频道失败: $($_.Exception.Message)"
    exit 1
}

# 3. 检查代理配置状态
Write-Host "`n3. 检查代理配置状态..."
try {
    $proxyStatus = Invoke-RestMethod -Uri "https://yoyoapi.5202021.xyz/api/admin/proxy/status" -Method GET -Headers @{"Authorization"="Bearer $token"}
    Write-Host "✅ 代理状态: $($proxyStatus.data | ConvertTo-Json -Depth 3)"
} catch {
    Write-Host "❌ 获取代理状态失败: $($_.Exception.Message)"
}

# 4. 测试start-watching API
Write-Host "`n4. 测试start-watching API..."
try {
    $startResponse = Invoke-RestMethod -Uri "https://yoyoapi.5202021.xyz/api/simple-stream/start-watching" -Method POST -Headers @{
        "Content-Type" = "application/json"
        "Authorization" = "Bearer $token"
    } -Body "{`"channelId`":`"$($firstChannel.id)`"}"
    
    Write-Host "✅ start-watching成功: $($startResponse | ConvertTo-Json -Depth 3)"
} catch {
    Write-Host "❌ start-watching失败: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        Write-Host "错误响应体: $responseBody"
    }
}

Write-Host "`n=== 测试完成 ==="
