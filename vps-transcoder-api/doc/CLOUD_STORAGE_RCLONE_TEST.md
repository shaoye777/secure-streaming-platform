# ☁️ rclone云存储方案测试 - 阶段化执行文档

**版本**: v1.0 | **创建时间**: 2025-10-31 13:05  
**目标**: 验证rclone上传视频到中国移动云盘家庭云的可行性

---

## 📖 文档使用说明

⚠️ **本文档采用阶段化执行策略** - 每个阶段完成后必须验证通过才能继续

**🚨 执行纪律**：
1. ✅ 绝对禁止跳步
2. ✅ 验证是强制性的
3. ✅ 验证失败必须停止
4. ✅ 每步更新进度表

---

## 📊 执行进度追踪

| 阶段 | 名称 | 状态 | 完成时间 | 验证结果 |
|------|------|------|----------|----------|
| **准备** | 安装rclone | ⏳ 待执行 | - | - |
| **阶段1** | 抓包获取参数 | ⏳ 待执行 | - | - |
| **阶段2** | 配置rclone | ⏳ 待执行 | - | - |
| **阶段3** | 测试小文件 | ⏳ 待执行 | - | - |
| **阶段4** | 上传视频 | ⏳ 待执行 | - | - |
| **阶段5** | 验证完整性 | ⏳ 待执行 | - | - |

---

## 🎯 准备阶段：安装rclone

### 操作步骤

```bash
# 1. SSH连接VPS
ssh root@142.171.75.220

# 2. 查看录制目录
ls -lh /srv/filebrowser/yoyo-k/
find /srv/filebrowser/yoyo-k/ -name "*.mp4" -type f -mtime -1 | head -5

# 3. 安装rclone
curl https://rclone.org/install.sh | sudo bash

# 4. 验证安装
rclone version

# 5. 创建测试文件
mkdir -p /tmp/rclone-test
echo "rclone test - $(date)" > /tmp/rclone-test/test.txt
```

### 验证清单
- [ ] rclone安装成功
- [ ] 找到录制视频文件
- [ ] 测试文件创建成功

---

## 🎯 阶段1：抓包获取139云盘参数

### 需要获取的参数
1. **Authorization** - 认证令牌
2. **cloudID** - 家庭云ID
3. **catalogID** - 文件夹ID（可选）

### 操作步骤

**步骤1：打开139云盘**
1. 访问 https://yun.139.com/
2. 登录账号
3. 进入"家庭云"

**步骤2：开发者工具**
1. 按F12
2. 切换到Network标签
3. 输入过滤：queryContentList

**步骤3：触发请求**
1. 点击任意文件夹
2. 找到queryContentList请求

**步骤4：复制参数**
```
Headers标签 → Request Headers → Authorization
⚠️ 只复制"Basic "后面的内容！

Payload标签 → cloudID
Payload标签 → catalogID（可选）
```

### 参数记录
```
Authorization: _______________
cloudID: _______________
catalogID: _______________ (可选)
```

---

## 🎯 阶段2：配置rclone

### 操作步骤

```bash
# 1. 创建配置目录
mkdir -p ~/.config/rclone

# 2. 创建配置文件
nano ~/.config/rclone/rclone.conf

# 3. 填写配置（替换YOUR_XXX为实际参数）
```

**配置内容：**
```ini
[china139]
type = webdav
url = https://yun.139.com/orchestration/familyCloud/
vendor = other
headers = Authorization,Basic YOUR_AUTHORIZATION,cloudID,YOUR_CLOUD_ID
user = dummy
pass = dummy
```

```bash
# 4. 保存并验证
cat ~/.config/rclone/rclone.conf
rclone listremotes

# 5. 测试连接
rclone lsd china139:/
```

### 验证清单
- [ ] 配置文件创建成功
- [ ] rclone listremotes显示china139
- [ ] rclone lsd能列出目录

---

## 🎯 阶段3：测试上传小文件

### 操作步骤

```bash
# 1. 上传测试文件
rclone copy /tmp/rclone-test/test.txt china139:/录制视频测试/

# 2. 验证
rclone ls china139:/录制视频测试/

# 3. 在网页端查看
# 打开 https://yun.139.com/ → 家庭云 → 录制视频测试
# 应该能看到test.txt
```

### 验证清单
- [ ] 上传无报错
- [ ] rclone ls能看到文件
- [ ] 网页端能看到文件

---

## 🎯 阶段4：上传真实录制视频

### 操作步骤

```bash
# 1. 选择测试视频（建议<50MB）
find /srv/filebrowser/yoyo-k/ -name "*.mp4" -type f -size -50M -mtime -1

# 2. 设置文件路径
VIDEO_FILE="/srv/filebrowser/yoyo-k/stream_gkg5hknc/20251031/xxx.mp4"

# 3. 上传（带进度）
rclone copy "$VIDEO_FILE" china139:/录制视频测试/ \
  --progress \
  --stats 5s \
  --stats-one-line

# 4. 验证文件大小
rclone ls china139:/录制视频测试/ | grep mp4
```

### 记录信息
```
文件名：_______________
文件大小：_______________
上传耗时：_______________
上传速度：_______________
```

### 验证清单
- [ ] 上传100%完成
- [ ] 远程文件大小一致
- [ ] 无报错信息

---

## 🎯 阶段5：验证文件完整性

### 网页端验证

1. 打开 https://yun.139.com/
2. 进入家庭云 → 录制视频测试
3. 找到上传的视频文件
4. 点击在线播放

### 验证项
- [ ] 文件名正确
- [ ] 文件大小正确
- [ ] 能在线播放
- [ ] 画面和声音正常
- [ ] 可拖动进度条

### 下载验证（可选）

```bash
# 1. 下载文件
rclone copy "china139:/录制视频测试/$VIDEO_NAME" /tmp/verify/ --progress

# 2. 对比MD5
md5sum "$VIDEO_FILE"
md5sum "/tmp/verify/$VIDEO_NAME"

# 应该完全一致
```

---

## 📊 测试结果总结

### 环境信息
```
VPS系统：_______________
rclone版本：_______________
139云盘账号：_______________
```

### 测试结果
```
小文件测试：
- 状态：✅ 成功 / ❌ 失败
- 耗时：___ 秒

视频文件测试：
- 文件大小：___ MB
- 上传耗时：___ 秒
- 平均速度：___ KB/s
- 状态：✅ 成功 / ❌ 失败

在线播放：
- 状态：✅ 正常 / ❌ 异常
```

### 结论
- [ ] ✅ rclone方案可行，可以继续开发集成
- [ ] ❌ rclone方案不可行，需要考虑其他方案

### 遇到的问题
```
问题1：_______________
解决：_______________

问题2：_______________
解决：_______________
```

---

## 🔧 常见问题排查

### 问题1：rclone lsd报401错误
```bash
# 原因：Authorization错误
# 解决：重新抓包，确保没有"Basic "前缀
nano ~/.config/rclone/rclone.conf
```

### 问题2：上传中断
```bash
# rclone支持断点续传，重新执行上传命令即可
rclone copy "$VIDEO_FILE" china139:/录制视频测试/ --progress
```

### 问题3：网页端看不到文件
```
1. 刷新网页
2. 检查文件夹路径是否正确
3. 重新登录139云盘
```

---

## 📝 下一步计划

如果测试成功：
1. ✅ 设计Web界面配置rclone
2. ✅ 实现自动上传服务
3. ✅ 集成到录制完成事件
4. ✅ 添加上传进度监控

---

**文档完成时间**：_______________  
**测试执行人**：_______________  
**测试结果**：✅ 通过 / ❌ 失败
