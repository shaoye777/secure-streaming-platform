# 🔧 视频录制功能实施方案 - 阶段化执行文档

**版本**: v1.0 | **创建时间**: 2025-10-24 22:40  
**基于**: VIDEO_RECORDING_SOLUTION.md v1.1

---

## 📖 文档使用说明

### **重要原则**

⚠️ **本文档采用阶段化执行策略** - 每个阶段完成后必须验证通过才能继续

**🚨 执行纪律（必须严格遵守）**：
1. ✅ **绝对禁止跳步** - 必须完成当前阶段的所有步骤（修改→部署→验证→更新状态）后才能进入下一阶段
2. ✅ **验证是强制性的** - 即使代码看起来正确，也必须执行验证步骤确认功能正常
3. ✅ **验证失败必须回滚** - 使用备份文件恢复，不能带着问题继续
4. ✅ **每步更新进度表** - 在下方进度表中实时标记当前状态
5. ✅ **遇到问题立即停止** - 不要继续执行后续阶段

**为什么要阶段化**：
- 🔴 本次实施涉及约15个文件、1000+行代码
- 🔴 一次性修改风险极高，难以定位问题
- ✅ 分阶段执行可以及时发现和修复问题
- ✅ 每个阶段都可独立回滚，影响范围小

**AI执行者注意**：
- 📝 **每完成一个阶段，必须更新下方进度表**
- 📝 **在状态列标记 ✅ 并填写完成时间**
- 📝 **如果验证失败，标记 ❌ 并说明原因**

---

## 📊 执行进度追踪

### **总体进度**: 0/7 阶段完成

| 阶段 | 名称 | 状态 | 完成时间 | 验证结果 |
|------|------|------|----------|---------|
| **准备** | 环境配置和文件备份 | ⏳ 未开始 | - | - |
| **阶段1** | D1数据库设计和API | ⏳ 未开始 | - | - |
| **阶段2** | SimpleStreamManager核心改造 | ⏳ 未开始 | - | - |
| **阶段3** | 分段录制和文件管理 | ⏳ 未开始 | - | - |
| **阶段4** | 自动修复机制 | ⏳ 未开始 | - | - |
| **阶段5** | 前端管理界面 | ⏳ 未开始 | - | - |
| **阶段6** | 定时任务和清理 | ⏳ 未开始 | - | - |
| **阶段7** | 完整集成测试 | ⏳ 未开始 | - | - |

**状态图例**：⏳ 未开始 | 🔄 进行中 | ✅ 已完成 | ❌ 验证失败 | 🔙 已回滚

---

## 📋 功能概述

### **核心需求**
1. **录制控制**: 管理员可启用/禁用频道录制
2. **定时录制**: 默认时间 7:50-17:20（北京时间）
3. **分段录制**: 每1小时一个MP4文件
4. **自动清理**: 保留2天，凌晨3点自动删除
5. **文件下载**: 通过FileBrowser访问录像

### **关键技术决策**

#### 1. FFmpeg进程复用 ⭐
- **策略**: 一个FFmpeg进程同时输出HLS和MP4
- **优势**: CPU仅增加30%，节省50%资源
- **权衡**: 修改配置需要重启进程（影响观看用户7秒）

#### 2. D1数据库访问 ⭐
- **限制**: VPS无法直接访问D1，必须通过Workers API
- **规范**: 
  - 🖥️ VPS端代码：通过HTTP API访问
  - ☁️ Workers端代码：直接使用`env.RECORDING_DB`

#### 3. 分段录制 ⭐
- **策略**: 每1小时自动切换到新文件
- **优势**: 进程崩溃最多损失1小时，其他段完好
- **实现**: FFmpeg `-f segment` 参数

#### 4. 自动修复 ⭐
- **策略**: 服务启动时自动检测和修复损坏文件
- **三级修复**: 标准修复 → 强制重建 → 提取数据
- **成功率**: 正常停止99%，崩溃85%，断电60%

### **文件命名规则**
- **格式**: `YYYY-MM-DD_HH-MM_HH-MM.mp4`
- **示例**: `2025-10-22_07-50_08-50.mp4`
- **说明**: 开始时间_结束时间

---

## 🎯 准备阶段：环境配置和文件备份

⚠️ **在开始任何修改前，必须先完成准备工作！**

**目标**：配置环境变量，创建D1数据库，备份关键文件  
**影响范围**：全局配置  
**风险等级**：🟢 低  
**预计时间**：30分钟

### 准备1：创建D1数据库

```bash
# 1. 创建D1数据库
cd cloudflare-worker
npx wrangler d1 create yoyo-recordings

# 2. 记录返回的database_id
# 3. 更新wrangler.toml添加绑定（见准备2）
```

### 准备2：配置环境变量

**Workers (wrangler.toml)**:
```toml
# 在[env.production]部分添加
RECORDING_ENABLED = "true"
RECORDING_DEFAULT_RETENTION_DAYS = "2"
RECORDING_CLEANUP_HOUR = "3"
RECORDING_MAX_SEGMENT_DURATION = "7200"

# 添加D1数据库绑定
[[d1_databases]]
binding = "RECORDING_DB"
database_name = "yoyo-recordings"
database_id = "<your-database-id>"
```

**VPS (.env)**:
```bash
# SSH到VPS后编辑 /opt/yoyo-transcoder/.env
RECORDINGS_BASE_DIR=/var/recordings
RECORDINGS_CLEANUP_HOUR=3
RECORDINGS_RETENTION_DAYS=2
RECORDINGS_SEGMENT_DURATION=3600
WORKERS_API_URL=https://yoyoapi.5202021.xyz
```

### 准备3：备份文件

```powershell
cd D:\项目文件\yoyo-kindergarten\code\secure-streaming-platform\vps-transcoder-api

# 创建备份目录
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
New-Item -Path "backups\$timestamp" -ItemType Directory -Force

# 备份关键文件
Copy-Item "vps-transcoder-api\src\services\SimpleStreamManager.js" "backups\$timestamp\"
Copy-Item "vps-transcoder-api\src\routes\simple-stream.js" "backups\$timestamp\"
Copy-Item "cloudflare-worker\src\index.js" "backups\$timestamp\"
Copy-Item "cloudflare-worker\wrangler.toml" "backups\$timestamp\"
```

### 准备4：创建VPS录制目录

```bash
# SSH到VPS
ssh root@142.171.75.220

# 创建目录
mkdir -p /var/recordings
mkdir -p /var/log/recordings
chmod 755 /var/recordings /var/log/recordings

# 验证磁盘空间
df -h /var
```

### 准备5：验证清单

- [ ] D1数据库已创建
- [ ] wrangler.toml已更新绑定
- [ ] Workers环境变量已配置
- [ ] VPS环境变量已配置
- [ ] 关键文件已备份
- [ ] VPS录制目录已创建
- [ ] 磁盘空间 > 200GB

✅ 完成后更新进度表

---

## 🎯 阶段1：D1数据库设计和Workers API

**目标**：创建数据库表结构，实现Workers端D1访问API  
**影响范围**：cloudflare-worker/ (3个文件)  
**风险等级**：🟡 中  
**预计时间**：60分钟

### 1.1 创建数据库表结构

**创建文件**: `cloudflare-worker/schema.sql`

```sql
-- 录制配置表
CREATE TABLE IF NOT EXISTS recording_configs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  channel_id TEXT NOT NULL UNIQUE,
  enabled INTEGER DEFAULT 0,
  start_time TEXT DEFAULT '07:50',
  end_time TEXT DEFAULT '17:20',
  segment_duration INTEGER DEFAULT 3600,
  video_bitrate INTEGER DEFAULT 1500,
  retention_days INTEGER DEFAULT 2,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- 录制文件表
CREATE TABLE IF NOT EXISTS recording_files (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  channel_id TEXT NOT NULL,
  filename TEXT NOT NULL,
  file_path TEXT NOT NULL,
  start_time TEXT NOT NULL,
  end_time TEXT,
  file_size INTEGER DEFAULT 0,
  status TEXT DEFAULT 'recording',
  repair_attempts INTEGER DEFAULT 0,
  repair_status TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_configs_channel ON recording_configs(channel_id);
CREATE INDEX IF NOT EXISTS idx_files_channel ON recording_files(channel_id);
CREATE INDEX IF NOT EXISTS idx_files_status ON recording_files(status);
```

**执行SQL**:
```bash
cd cloudflare-worker
npx wrangler d1 execute yoyo-recordings --file=schema.sql --env production
```

### 1.2 创建recordingHandler.js

**创建文件**: `cloudflare-worker/src/handlers/recordingHandler.js`

这个文件实现D1数据库CRUD操作。核心方法：
- `getRecordingConfig()` - 获取频道录制配置
- `updateRecordingConfig()` - 更新录制配置
- `createRecordingFile()` - 创建录制文件记录
- `updateRecordingFile()` - 更新文件状态
- `getInterruptedRecordings()` - 获取需要修复的文件
- `getRecordingFiles()` - 查询录制文件列表

**注意**: 由于代码较长，完整实现见VIDEO_RECORDING_SOLUTION.md第2200-2500行

### 1.3 添加API路由

**修改文件**: `cloudflare-worker/src/index.js`

在路由部分添加：
```javascript
// 录制配置API
router.get('/api/recording/config/:channelId', recordingHandler.getRecordingConfig);
router.put('/api/recording/config/:channelId', recordingHandler.updateRecordingConfig);

// 录制文件API
router.post('/api/recording/files', recordingHandler.createRecordingFile);
router.patch('/api/recording/files/:id', recordingHandler.updateRecordingFile);
router.get('/api/recording/files/interrupted', recordingHandler.getInterruptedRecordings);
router.get('/api/recording/files', recordingHandler.getRecordingFiles);
```

### 1.4 部署Workers

```bash
cd cloudflare-worker
npx wrangler deploy --env production
```

### 1.5 验证测试

**测试API端点**:
```powershell
# 测试获取配置
$token = "YOUR_ADMIN_TOKEN"
Invoke-RestMethod -Uri "https://yoyoapi.5202021.xyz/api/recording/config/stream_xxx" `
  -Headers @{"Authorization"="Bearer $token"}

# 测试更新配置
$body = @{
  enabled = $true
  start_time = "07:50"
  end_time = "17:20"
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://yoyoapi.5202021.xyz/api/recording/config/stream_xxx" `
  -Method PUT -Body $body -ContentType "application/json" `
  -Headers @{"Authorization"="Bearer $token"}
```

**验证清单**:
- [ ] D1表已创建（3个表，3个索引）
- [ ] recordingHandler.js已创建
- [ ] API路由已添加
- [ ] Workers部署成功
- [ ] 配置API返回200
- [ ] 文件API返回200

**如果验证失败**: 回滚Workers部署，恢复index.js备份

✅ 完成后更新进度表

---

## 🎯 阶段2：SimpleStreamManager核心改造

**目标**：扩展SimpleStreamManager支持录制功能  
**影响范围**：SimpleStreamManager.js (1个文件，约300行代码)  
**风险等级**：🔴 高（核心逻辑）  
**预计时间**：90分钟

**关键改动**：
1. `startWatching()` - 添加options参数支持录制配置
2. `spawnFFmpegProcess()` - 支持HLS+MP4双输出
3. `cleanupIdleChannels()` - 跳过正在录制的频道
4. 新增录制心跳机制

### 2.1 修改startWatching方法

**文件**: `vps-transcoder-api/src/services/SimpleStreamManager.js`

在现有方法基础上添加options参数（向后兼容）：

```javascript
async startWatching(channelId, rtmpUrl, options = {}) {
  // 检查配置是否变更
  const existingChannel = this.activeStreams.get(channelId);
  if (existingChannel) {
    const recordingChanged = this.isRecordingConfigChanged(
      existingChannel.recordingConfig,
      options.recordingConfig
    );
    
    if (existingChannel.rtmpUrl !== rtmpUrl || recordingChanged) {
      await this.stopFFmpegProcess(channelId);
      return await this.startNewStream(channelId, rtmpUrl, options);
    }
    return existingChannel.hlsUrl;
  }
  
  return await this.startNewStream(channelId, rtmpUrl, options);
}
```

### 2.2 修改spawnFFmpegProcess方法

**核心修改**：支持FFmpeg多输出（HLS + MP4分段录制）

```javascript
async spawnFFmpegProcess(channelId, rtmpUrl, options = {}) {
  const ffmpegArgs = ['-i', rtmpUrl];
  
  if (options.recordingConfig?.enabled) {
    // 输出1: HLS流
    ffmpegArgs.push(
      '-map', '0:v:0',
      '-c:v:0', 'libx264', '-preset:v:0', 'ultrafast', '-an',
      '-f', 'hls', '-hls_time', '2',
      // ... HLS参数
    );
    
    // 输出2: MP4分段录制
    const segmentDuration = options.recordingConfig.segment_duration || 3600;
    ffmpegArgs.push(
      '-map', '0:v:0',
      '-c:v:1', 'libx264', '-preset:v:1', 'medium', '-an',
      '-f', 'segment', '-segment_time', segmentDuration,
      '-strftime', '1',
      '-segment_filename', `/var/recordings/${channelId}/%Y-%m-%d_%H-%M_temp.mp4`
    );
  } else {
    // 只输出HLS（现有逻辑）
  }
  
  return spawn(this.ffmpegPath, ffmpegArgs, {env});
}
```

### 2.3 新增辅助方法

```javascript
// 录制心跳
setRecordingHeartbeat(channelId) { /* ... */ }
clearRecordingHeartbeat(channelId) { /* ... */ }
isRecordingConfigChanged(oldConfig, newConfig) { /* ... */ }
```

### 2.4 修改cleanupIdleChannels

```javascript
async cleanupIdleChannels() {
  for (const [channelId, lastHeartbeat] of this.channelHeartbeats) {
    const processInfo = this.activeStreams.get(channelId);
    
    // 跳过正在录制的频道
    if (processInfo && processInfo.isRecording) continue;
    
    // 正常清理逻辑...
  }
}
```

### 2.5 部署到VPS

```bash
# 提交代码
git add vps-transcoder-api/src/services/SimpleStreamManager.js
git commit -m "feat: SimpleStreamManager支持录制功能"
git push

# 部署到VPS
ssh root@142.171.75.220 "cd /tmp/github/secure-streaming-platform/vps-transcoder-api && ./vps-simple-deploy.sh"
```

### 2.6 验证测试

```bash
# 测试启动录制
curl -X POST https://yoyo-vps.5202021.xyz/api/simple-stream/start-watching \
  -H "X-API-Key: YOUR_KEY" \
  -d '{
    "channelId": "stream_xxx",
    "rtmpUrl": "rtmp://source/live",
    "options": {
      "recordingConfig": {"enabled": true, "segment_duration": 3600}
    }
  }'

# 检查进程
ssh root@142.171.75.220 "ps aux | grep ffmpeg"

# 检查文件生成
ssh root@142.171.75.220 "ls -la /var/recordings/stream_xxx/"
```

**验证清单**:
- [ ] FFmpeg进程包含HLS和MP4输出
- [ ] 录制文件开始生成
- [ ] HLS播放仍然正常
- [ ] 无JavaScript错误

**如果验证失败**: 恢复SimpleStreamManager.js备份，重新部署

✅ 完成后更新进度表

---

## 📝 后续阶段概览

由于文档篇幅限制，剩余阶段的详细步骤请参考：

- **阶段3**: 分段录制管理器（SegmentedRecordingManager）
- **阶段4**: 自动修复机制（RecordingRecoveryManager）
- **阶段5**: 前端管理界面（频道录制开关）
- **阶段6**: 定时任务和自动清理
- **阶段7**: 完整集成测试

完整实施细节见：`VIDEO_RECORDING_SOLUTION.md`

---

## 🔄 回滚方案

如果任何阶段失败，立即执行回滚：

```bash
# 回滚到备份
$timestamp = "YOUR_BACKUP_TIMESTAMP"
Copy-Item "backups\$timestamp\*" -Destination "对应目录" -Force

# 重新部署Workers
cd cloudflare-worker
npx wrangler deploy --env production

# 重新部署VPS
ssh root@142.171.75.220 "cd /tmp/github && ./vps-simple-deploy.sh"
```

---

## 📌 重要提醒

1. ⚠️ **修改配置会导致重启** - 影响观看用户7秒
2. ⚠️ **VPS无法直接访问D1** - 必须通过Workers API
3. ⚠️ **磁盘空间监控** - 8频道2天约109GB
4. ⚠️ **文件权限** - 确保/var/recordings可写
5. ⚠️ **分段录制** - 每1小时自动切换文件

---

**文档维护者**: AI Assistant  
**最后更新**: 2025-10-24 22:45 (UTC+8)  
**文档状态**: ✅ 初始版本完成