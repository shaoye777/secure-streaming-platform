#!/bin/bash

echo "测试VPS start-watching API..."

curl -X POST http://localhost:52535/api/simple-stream/start-watching \
  -H 'Content-Type: application/json' \
  -H 'X-API-Key: 85da076ae24b028b3d1ea1884e6b13c5afe34b5b' \
  -d '{"channelId":"stream_cpa2czoo","rtmpUrl":"rtmp://test.com/live/test"}' \
  -v
