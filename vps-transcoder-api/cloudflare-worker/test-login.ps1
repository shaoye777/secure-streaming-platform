# 测试登录并获取token
$loginResponse = Invoke-RestMethod -Uri "https://yoyoapi.5202021.xyz/api/login" -Method POST -Headers @{"Content-Type"="application/json"} -Body '{"username":"admin","password":"admin123"}'

Write-Host "登录响应:"
$loginResponse | ConvertTo-Json -Depth 10

if ($loginResponse.status -eq "success") {
    $token = $loginResponse.data.token
    Write-Host "获得token: $token"
    
    # 使用token测试start-watching API
    Write-Host "`n测试带认证的start-watching API:"
    try {
        $apiResponse = Invoke-RestMethod -Uri "https://yoyoapi.5202021.xyz/api/simple-stream/start-watching" -Method POST -Headers @{
            "Content-Type" = "application/json"
            "Authorization" = "Bearer $token"
        } -Body '{"channelId":"test"}'
        
        Write-Host "API响应:"
        $apiResponse | ConvertTo-Json -Depth 10
    } catch {
        Write-Host "API调用失败: $($_.Exception.Message)"
        if ($_.Exception.Response) {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $responseBody = $reader.ReadToEnd()
            Write-Host "错误响应体: $responseBody"
        }
    }
} else {
    Write-Host "登录失败"
}
