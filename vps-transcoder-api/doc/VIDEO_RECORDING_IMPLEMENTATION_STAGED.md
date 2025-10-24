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
- **格式**: `YYYY-MM-DD_HH-MM-SS.mp4`
- **示例**: `2025-10-24_14-03-25.mp4`
- **说明**: 录制开始时间（年-月-日_时-分-秒）
- **结束时间**: 通过ffprobe读取视频时长或查询D1数据库的end_time字段

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
Copy-Item "vps-transcoder-api\vps-simple-deploy.sh" "backups\$timestamp\"
Copy-Item "vps-transcoder-api\package.json" "backups\$timestamp\"
Copy-Item "cloudflare-worker\src\index.js" "backups\$timestamp\"
Copy-Item "cloudflare-worker\wrangler.toml" "backups\$timestamp\"
```

### 准备4：检查VPS部署脚本 ⭐重要

⚠️ **确保部署脚本包含依赖安装步骤，否则后续阶段会失败！**

**检查文件**: `vps-transcoder-api/vps-simple-deploy.sh`

**必须包含的关键步骤**（推荐的优化版本）：
```bash
# 1. 同步package.json（确保依赖定义最新）
cp /tmp/github/secure-streaming-platform/vps-transcoder-api/package.json /opt/yoyo-transcoder/

# 2. 智能安装依赖（检查是否有变化，避免不必要的安装）
cd /opt/yoyo-transcoder

# 方式1: 检查package.json是否变化（推荐）
if ! cmp -s package.json package.json.old 2>/dev/null || [ ! -d node_modules ]; then
  echo "📦 Dependencies changed or missing, installing..."
  npm ci --production  # 使用npm ci更快更可靠
  cp package.json package.json.old
else
  echo "✅ Dependencies up to date, skipping install"
fi

# 方式2: 简单版本（总是安装，npm会自动跳过已安装的）
npm install --production  # npm install是幂等的，不会报错

# 3. 重启服务
pm2 reload vps-transcoder-api
```

**npm install vs npm ci**：
- `npm install`：幂等操作，可重复执行，不会报错
- `npm ci`：更快更可靠，适合生产环境，会删除node_modules重新安装

**如果脚本中缺少这些步骤**，需要先完善部署脚本，再继续后续阶段。

**验证方法**：
```bash
# 查看当前部署脚本内容
cat vps-transcoder-api/vps-simple-deploy.sh

# 确认包含 npm install 步骤
grep "npm install\|npm ci" vps-transcoder-api/vps-simple-deploy.sh
```

### 准备5：创建VPS录制目录

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

### 准备6：验证清单

- [ ] D1数据库已创建
- [ ] wrangler.toml已更新绑定
- [ ] Workers环境变量已配置
- [ ] VPS环境变量已配置
- [ ] 关键文件已备份（包括vps-simple-deploy.sh和package.json）
- [ ] **VPS部署脚本包含npm install步骤** ⭐关键
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
      '-segment_filename', `/var/recordings/${channelId}/%Y-%m-%d_%H-%M-%S.mp4`
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

## 🎯 阶段3：分段录制管理器

**目标**：实现录制分段监听和处理，自动重命名临时文件  
**影响范围**：VPS端新增1个服务类  
**风险等级**：🟡 中  
**预计时间**：60分钟

### 3.1 创建SegmentedRecordingManager

**创建文件**: `vps-transcoder-api/src/services/SegmentedRecordingManager.js`

核心功能：
- 监听录制目录的文件变化
- 检测新分段文件生成
- 自动重命名临时文件为标准格式
- 通过Workers API更新D1数据库

**关键方法**：
```javascript
class SegmentedRecordingManager {
  constructor() {
    this.recordingsDir = process.env.RECORDINGS_BASE_DIR || '/var/recordings';
    this.activeWatchers = new Map();
  }
  
  // 开始监听频道录制目录
  startWatching(channelId) { /* ... */ }
  
  // 停止监听
  stopWatching(channelId) { /* ... */ }
  
  // 处理新文件创建事件
  async handleNewFile(channelId, filename) { /* ... */ }
  
  // 重命名临时文件并更新数据库
  async processCompletedSegment(channelId, filePath) { /* ... */ }
}
```

### 3.2 集成到SimpleStreamManager

**修改文件**: `vps-transcoder-api/src/services/SimpleStreamManager.js`

```javascript
const SegmentedRecordingManager = require('./SegmentedRecordingManager');

class SimpleStreamManager {
  constructor() {
    // ... 现有代码
    this.recordingManager = new SegmentedRecordingManager();
  }
  
  async startNewStream(channelId, rtmpUrl, options = {}) {
    // ... 现有代码
    
    if (options.recordingConfig?.enabled) {
      // 启动录制目录监听
      this.recordingManager.startWatching(channelId);
    }
  }
  
  async stopChannel(channelId) {
    // ... 现有代码
    
    // 停止录制监听
    this.recordingManager.stopWatching(channelId);
  }
}
```

### 3.3 部署和验证

```bash
# 提交代码
git add vps-transcoder-api/src/services/SegmentedRecordingManager.js
git add vps-transcoder-api/src/services/SimpleStreamManager.js
git commit -m "feat: 添加分段录制管理器"
git push

# 部署到VPS
ssh root@142.171.75.220 "cd /tmp/github/secure-streaming-platform/vps-transcoder-api && ./vps-simple-deploy.sh"

# 验证文件监听
# 启动录制后，等待1小时检查文件是否正确重命名
ssh root@142.171.75.220 "ls -la /var/recordings/stream_xxx/"
```

**验证清单**:
- [ ] 新分段文件自动生成
- [ ] 文件名格式正确（YYYY-MM-DD_HH-MM-SS.mp4）
- [ ] D1数据库记录已创建
- [ ] 文件大小和时长正常

✅ 完成后更新进度表

---

## 🎯 阶段4：自动修复机制

**目标**：实现服务启动时自动检测和修复损坏文件  
**影响范围**：VPS端新增1个服务类 + app.js启动逻辑  
**风险等级**：🟡 中  
**预计时间**：90分钟

### 4.1 创建RecordingRecoveryManager

**创建文件**: `vps-transcoder-api/src/services/RecordingRecoveryManager.js`

核心功能：
- 服务启动时自动执行恢复流程
- 处理临时文件重命名
- 检测损坏文件并尝试修复
- 三级修复策略：标准修复 → 强制重建 → 提取数据

**关键方法**：
```javascript
class RecordingRecoveryManager {
  // 启动时执行恢复
  async recoverOnStartup() { /* ... */ }
  
  // 处理临时文件
  async processTempFiles() { /* ... */ }
  
  // 获取中断的录制
  async getInterruptedRecordings() { /* ... */ }
  
  // 验证MP4文件
  async validateMP4File(filePath) { /* ... */ }
  
  // 修复文件（三级策略 + 文件保护机制）
  async repairMP4WithRecovery(filePath) {
    const backupPath = `${filePath}.backup`;
    const tempPath = `${filePath}.repairing`;
    
    try {
      // 🔐 关键：先备份原文件
      await fs.copyFile(filePath, backupPath);
      
      // 在临时文件上尝试修复（保护原文件）
      let success = await this.tryStandardRepair(filePath, tempPath);
      if (!success) success = await this.tryForceRebuild(filePath, tempPath);
      if (!success) success = await this.tryDataExtraction(filePath, tempPath);
      
      if (success && await this.validateMP4File(tempPath)) {
        // ✅ 修复成功：替换原文件，删除备份
        await fs.rename(tempPath, filePath);
        await fs.unlink(backupPath);
        return true;
      }
      
      // ❌ 修复失败：清理临时文件，保留原文件
      if (fs.existsSync(tempPath)) await fs.unlink(tempPath);
      return false;
      
    } catch (error) {
      // 清理临时文件，保护原文件不被破坏
      if (fs.existsSync(tempPath)) await fs.unlink(tempPath);
      return false;
    }
  }
  
  // 方法1: 标准修复（快速，适合轻微损坏）
  async tryStandardRepair(inputPath, outputPath) {
    return execAsync(
      `ffmpeg -err_detect ignore_err -i "${inputPath}" -c copy -movflags +faststart "${outputPath}"`
    ).then(() => true).catch(() => false);
  }
  
  // 方法2: 强制重建（中等，适合索引损坏）
  async tryForceRebuild(inputPath, outputPath) {
    return execAsync(
      `ffmpeg -fflags +genpts -i "${inputPath}" -c:v libx264 -preset fast -movflags +faststart "${outputPath}"`
    ).then(() => true).catch(() => false);
  }
  
  // 方法3: 提取数据（保守，确保有输出）
  async tryDataExtraction(inputPath, outputPath) {
    return execAsync(
      `ffmpeg -err_detect ignore_err -fflags +genpts -i "${inputPath}" -c:v libx264 -preset ultrafast "${outputPath}"`
    ).then(() => true).catch(() => false);
  }
}
```

**🔐 文件保护机制**：
1. **修复前备份** - 创建 `.backup` 文件保护原始数据
2. **临时文件修复** - 在 `.repairing` 文件上操作，不直接修改原文件
3. **验证后替换** - 修复成功且验证通过才替换原文件
4. **失败保护** - 修复失败时清理临时文件，保留原文件不受损
5. **异常安全** - catch块确保即使程序崩溃也不破坏原文件

**为什么这样设计**：
- ⚠️ **防止二次损伤** - 如果修复过程中程序崩溃，原文件仍然完好
- ⚠️ **可回退** - 备份文件允许在修复失败后恢复原始状态
- ⚠️ **原子操作** - 文件替换是原子操作，不会出现半损坏状态

### 4.2 集成到app.js启动流程

**修改文件**: `vps-transcoder-api/src/app.js`

```javascript
const RecordingRecoveryManager = require('./services/RecordingRecoveryManager');

async function startServer() {
  // 1. 初始化恢复管理器
  const recoveryManager = new RecordingRecoveryManager();
  
  // 2. 执行启动恢复（在后台进行，不阻塞服务启动）
  recoveryManager.recoverOnStartup().catch(err => {
    logger.error('Recovery process failed:', err);
  });
  
  // 3. 启动Express服务器
  app.listen(PORT, () => {
    logger.info(`Server started on port ${PORT}`);
  });
}

startServer();
```

### 4.3 部署和验证

```bash
# 提交代码
git add vps-transcoder-api/src/services/RecordingRecoveryManager.js
git add vps-transcoder-api/src/app.js
git commit -m "feat: 添加录制文件自动修复机制"
git push

# 部署到VPS
ssh root@142.171.75.220 "cd /tmp/github/secure-streaming-platform/vps-transcoder-api && ./vps-simple-deploy.sh"

# 重启服务观察修复日志
ssh root@142.171.75.220 "pm2 restart vps-transcoder-api && pm2 logs --lines 50"
```

**验证清单**:
- [ ] 服务启动时执行恢复流程
- [ ] 损坏文件被检测到
- [ ] 修复流程正常执行
- [ ] 修复日志完整

✅ 完成后更新进度表

---

## 🎯 阶段5：前端管理界面

**目标**：在频道管理页面添加录制控制功能  
**影响范围**：frontend/src/views/admin/ChannelManagement.vue  
**风险等级**：🟢 低  
**预计时间**：45分钟

### 5.1 添加录制配置API

**创建文件**: `frontend/src/services/recordingApi.js`

```javascript
import axios from 'axios';

const API_BASE = process.env.VUE_APP_API_URL;

export default {
  // 获取录制配置
  async getRecordingConfig(channelId) {
    return axios.get(`${API_BASE}/api/recording/config/${channelId}`);
  },
  
  // 更新录制配置
  async updateRecordingConfig(channelId, config) {
    return axios.put(`${API_BASE}/api/recording/config/${channelId}`, config);
  },
  
  // 获取录制文件列表
  async getRecordingFiles(channelId, params) {
    return axios.get(`${API_BASE}/api/recording/files`, {
      params: { channel_id: channelId, ...params }
    });
  }
};
```

### 5.2 修改频道管理界面

**修改文件**: `frontend/src/views/admin/ChannelManagement.vue`

在频道列表中添加录制开关：

```vue
<template>
  <el-table :data="channels">
    <!-- 现有列 -->
    
    <!-- 新增：录制列 -->
    <el-table-column label="录制" width="100">
      <template #default="{ row }">
        <el-switch
          v-model="row.recordingEnabled"
          @change="handleRecordingToggle(row)"
          :loading="row.recordingLoading"
        />
      </template>
    </el-table-column>
    
    <!-- 新增：录制配置按钮 -->
    <el-table-column label="操作" width="200">
      <template #default="{ row }">
        <el-button @click="openRecordingConfig(row)">
          录制配置
        </el-button>
      </template>
    </el-table-column>
  </el-table>
  
  <!-- 录制配置对话框 -->
  <el-dialog v-model="recordingDialogVisible" title="录制配置">
    <el-form :model="recordingForm">
      <el-form-item label="开始时间">
        <el-time-picker v-model="recordingForm.startTime" format="HH:mm" />
      </el-form-item>
      <el-form-item label="结束时间">
        <el-time-picker v-model="recordingForm.endTime" format="HH:mm" />
      </el-form-item>
      <el-form-item label="保留天数">
        <el-input-number v-model="recordingForm.retentionDays" :min="1" :max="7" />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="recordingDialogVisible = false">取消</el-button>
      <el-button type="primary" @click="saveRecordingConfig">保存</el-button>
    </template>
  </el-dialog>
</template>

<script setup>
import recordingApi from '@/services/recordingApi';

// 切换录制开关
async function handleRecordingToggle(channel) {
  channel.recordingLoading = true;
  try {
    await recordingApi.updateRecordingConfig(channel.id, {
      enabled: channel.recordingEnabled
    });
    ElMessage.success('录制设置已更新');
  } catch (error) {
    channel.recordingEnabled = !channel.recordingEnabled;
    ElMessage.error('更新失败：' + error.message);
  } finally {
    channel.recordingLoading = false;
  }
}
</script>
```

### 5.3 部署前端

```bash
cd frontend
npm run build

# 自动部署到Cloudflare Pages（通过GitHub推送）
git add frontend/
git commit -m "feat: 添加频道录制管理界面"
git push
```

### 5.4 验证测试

**测试步骤**：
1. 打开频道管理页面
2. 找到任意频道，开启录制开关
3. 点击"录制配置"，修改时间设置
4. 验证VPS上FFmpeg进程启动
5. 检查录制文件是否生成

**验证清单**:
- [ ] 录制开关显示正常
- [ ] 开关状态与数据库同步
- [ ] 录制配置对话框正常打开
- [ ] 配置保存成功
- [ ] FFmpeg进程已启动录制

✅ 完成后更新进度表

---

## 🎯 阶段6：定时任务和自动清理

**目标**：实现定时录制和自动清理过期文件  
**影响范围**：VPS端新增定时任务模块  
**风险等级**：🟡 中  
**预计时间**：60分钟

### 6.1 创建定时任务管理器

**创建文件**: `vps-transcoder-api/src/services/ScheduledTaskManager.js`

```javascript
const cron = require('node-cron');

class ScheduledTaskManager {
  constructor(simpleStreamManager) {
    this.streamManager = simpleStreamManager;
    this.tasks = new Map();
    this.cleanupHour = process.env.RECORDINGS_CLEANUP_HOUR || 3;
    this.retentionDays = process.env.RECORDINGS_RETENTION_DAYS || 2;
  }
  
  // 启动所有定时任务
  startAllTasks() {
    this.startRecordingSchedule();
    this.startCleanupSchedule();
  }
  
  // 定时录制任务（每天7:50启动，17:20停止）
  startRecordingSchedule() {
    // 每天7:50启动录制
    cron.schedule('50 7 * * *', async () => {
      await this.startDailyRecording();
    });
    
    // 每天17:20停止录制
    cron.schedule('20 17 * * *', async () => {
      await this.stopDailyRecording();
    });
  }
  
  // 定时清理任务（凌晨3点）
  startCleanupSchedule() {
    const hour = this.cleanupHour;
    cron.schedule(`0 ${hour} * * *`, async () => {
      await this.cleanupOldRecordings();
    });
  }
  
  // 清理过期文件
  async cleanupOldRecordings() {
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - this.retentionDays);
    
    // 遍历所有频道目录
    const channels = await fs.readdir(this.recordingsDir);
    for (const channelDir of channels) {
      const files = await fs.readdir(path.join(this.recordingsDir, channelDir));
      
      for (const file of files) {
        const filePath = path.join(this.recordingsDir, channelDir, file);
        const stats = await fs.stat(filePath);
        
        if (stats.mtime < cutoffDate) {
          await fs.unlink(filePath);
          logger.info('Deleted old recording', { file, age: stats.mtime });
        }
      }
    }
  }
}

module.exports = ScheduledTaskManager;
```

### 6.2 集成到app.js

**修改文件**: `vps-transcoder-api/src/app.js`

```javascript
const ScheduledTaskManager = require('./services/ScheduledTaskManager');

async function startServer() {
  // ... 现有代码
  
  // 启动定时任务
  const taskManager = new ScheduledTaskManager(simpleStreamManager);
  taskManager.startAllTasks();
  
  logger.info('Scheduled tasks started');
}
```

### 6.3 安装依赖

**本地安装**：
```bash
cd vps-transcoder-api
npm install node-cron --save
```

这会更新 `package.json` 和 `package-lock.json` 文件。

### 6.4 更新VPS部署脚本 ⭐重要

⚠️ **必须同步修改部署脚本，确保VPS部署时自动安装新依赖！**

**修改文件**: `vps-transcoder-api/vps-simple-deploy.sh`

在部署脚本中添加依赖安装步骤（提供两种方案）：

**方案1: 智能安装（推荐，更快）**
```bash
# 在重启服务前添加：
echo "📦 Checking dependencies..."
cd /opt/yoyo-transcoder

# 只在package.json变化或node_modules缺失时安装
if ! cmp -s package.json package.json.old 2>/dev/null || [ ! -d node_modules ]; then
  echo "📦 Dependencies changed or missing, installing..."
  npm ci --production
  cp package.json package.json.old
else
  echo "✅ Dependencies up to date, skipping install"
fi
```

**方案2: 简单版本（总是安装，但npm会自动优化）**
```bash
echo "📦 Installing dependencies..."
cd /opt/yoyo-transcoder
npm install --production  # 幂等操作，不会报错
```

**完整建议的部署流程**：
```bash
#!/bin/bash
# vps-simple-deploy.sh 完整示例

echo "🚀 Starting deployment..."

# 1. 同步代码
echo "📁 Syncing source code..."
cp -r /tmp/github/secure-streaming-platform/vps-transcoder-api/src/* /opt/yoyo-transcoder/src/

# 2. 同步package.json（确保依赖定义最新）
echo "📦 Syncing package.json..."
cp /tmp/github/secure-streaming-platform/vps-transcoder-api/package.json /opt/yoyo-transcoder/

# 3. 智能安装依赖
cd /opt/yoyo-transcoder
if ! cmp -s package.json package.json.old 2>/dev/null || [ ! -d node_modules ]; then
  echo "📦 Installing dependencies..."
  npm ci --production
  cp package.json package.json.old
else
  echo "✅ Dependencies up to date"
fi

# 4. 重启服务
echo "🔄 Reloading service..."
pm2 reload vps-transcoder-api

echo "✅ Deployment completed!"
```

**为什么重要**：
- ❌ 不更新部署脚本 → VPS缺少node-cron → 定时任务功能无法启动 → 阶段6失败
- ✅ 更新部署脚本 → 自动安装依赖 → 所有功能正常工作

**npm install vs npm ci**：
| 命令 | 特点 | 适用场景 |
|------|------|---------|
| `npm install` | 幂等操作，可重复执行 | 开发环境 |
| `npm ci` | 删除node_modules重新安装，更快更可靠 | 生产环境部署 ⭐推荐 |

### 6.5 部署和验证

```bash
# 1. 提交代码（包括package.json和部署脚本）
git add vps-transcoder-api/package.json
git add vps-transcoder-api/package-lock.json
git add vps-transcoder-api/vps-simple-deploy.sh
git add vps-transcoder-api/src/services/ScheduledTaskManager.js
git add vps-transcoder-api/src/app.js
git commit -m "feat: 添加定时录制和自动清理功能

- 新增ScheduledTaskManager定时任务管理器
- 集成node-cron实现定时录制和清理
- 更新部署脚本支持依赖自动安装
"
git push

# 2. 同步到VPS Git目录
ssh root@142.171.75.220 "cd /tmp/github/secure-streaming-platform && git pull"

# 3. 执行部署脚本（会自动安装依赖）
ssh root@142.171.75.220 "/tmp/github/secure-streaming-platform/vps-transcoder-api/vps-simple-deploy.sh"

# 4. 验证依赖安装
ssh root@142.171.75.220 "cd /opt/yoyo-transcoder && npm list node-cron"
```

**验证清单**:
- [ ] node-cron已安装
- [ ] 定时任务已启动
- [ ] 7:50自动开始录制
- [ ] 17:20自动停止录制
- [ ] 凌晨3点清理过期文件

✅ 完成后更新进度表

---

## 🎯 阶段7：完整集成测试

**目标**：验证所有功能正常工作，压力测试  
**影响范围**：全系统  
**风险等级**：🟢 低（仅测试）  
**预计时间**：120分钟

### 7.1 功能测试清单

**基础功能**:
- [ ] 手动启动/停止录制
- [ ] 定时自动录制（7:50-17:20）
- [ ] 分段录制（每1小时切换文件）
- [ ] 文件命名格式正确
- [ ] D1数据库记录同步

**高级功能**:
- [ ] 配置变更自动重启FFmpeg
- [ ] 进程崩溃后自动修复文件
- [ ] 服务重启后恢复录制状态
- [ ] 过期文件自动清理
- [ ] 录制不影响HLS播放

### 7.2 压力测试

**测试场景**：
```bash
# 同时录制8个频道
for i in {1..8}; do
  curl -X POST https://yoyo-vps.5202021.xyz/api/simple-stream/start-watching \
    -H "X-API-Key: YOUR_KEY" \
    -d "{
      \"channelId\": \"stream_$i\",
      \"rtmpUrl\": \"rtmp://source$i/live\",
      \"options\": {\"recordingConfig\": {\"enabled\": true}}
    }"
done

# 监控系统资源
ssh root@142.171.75.220 "top -b -n 1 | head -20"
```

**性能指标**:
- [ ] CPU使用率 < 80%
- [ ] 内存使用 < 4GB
- [ ] 磁盘I/O正常
- [ ] 所有频道录制正常

### 7.3 异常测试

**测试1：进程崩溃恢复**
```bash
# 强制终止FFmpeg进程
ssh root@142.171.75.220 "pkill -9 ffmpeg"

# 重启服务
ssh root@142.171.75.220 "pm2 restart vps-transcoder-api"

# 验证文件修复
ssh root@142.171.75.220 "ls -la /var/recordings/*/
```

**测试2：磁盘空间不足**
```bash
# 模拟磁盘满（谨慎使用）
# 验证错误处理和告警
```

**测试3：网络中断**
```bash
# 断开RTMP源
# 验证录制停止和错误记录
```

### 7.4 验证报告

完成所有测试后，填写验证报告：

**功能验证**: ✅/❌  
**性能验证**: ✅/❌  
**异常处理**: ✅/❌  
**文档完整性**: ✅/❌

**发现的问题**：
1. 问题描述
2. 影响范围
3. 解决方案
4. 是否阻塞上线

✅ 完成后更新进度表，标记项目完成

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