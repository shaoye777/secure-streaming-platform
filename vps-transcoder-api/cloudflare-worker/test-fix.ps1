# 测试修复后的API
$token = "5dab17ea-f455-4952-9e88-4ef398f87165"
$uri = "https://yoyoapi.5202021.xyz/api/simple-stream/start-watching"

$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}

$body = @{
    channelId = "stream_cpa2czoo"
} | ConvertTo-Json

Write-Host "=== 测试修复后的start-watching API ==="
Write-Host "URL: $uri"
Write-Host "Body: $body"

try {
    $response = Invoke-RestMethod -Uri $uri -Method POST -Headers $headers -Body $body
    Write-Host "✅ 成功响应:" -ForegroundColor Green
    Write-Host ($response | ConvertTo-Json -Depth 3)
} catch {
    Write-Host "❌ 请求失败:" -ForegroundColor Red
    Write-Host $_.Exception.Message
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        Write-Host "响应内容: $responseBody"
    }
}
