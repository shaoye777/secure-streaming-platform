# Cloudflare Workers 部署配置说明

## 📋 快速开始

### **情况1：团队内部部署（共用同一个Cloudflare账号）**

✅ **无需修改配置，直接部署即可**

```bash
cd cloudflare-worker
wrangler login  # 使用团队Cloudflare账号登录
wrangler deploy --env production
```

**前提条件**：
- 使用相同的Cloudflare账号
- 共用相同的域名和资源
- 在Dashboard配置相同的Secrets

---

### **情况2：个人部署（使用自己的Cloudflare账号和域名）**

⚠️ **需要修改配置文件**

#### **步骤1：复制配置模板**

```bash
cd cloudflare-worker
cp wrangler.toml.example wrangler.toml
```

或者直接修改现有的 `wrangler.toml`

#### **步骤2：修改配置文件**

打开 `wrangler.toml`，修改以下配置：

| 配置项 | 说明 | 示例 |
|-------|------|------|
| `name` | Worker名称 | `your-worker-name` |
| `route.pattern` | API域名路由 | `your-api.com/*` |
| `route.zone_name` | Cloudflare Zone | `your-domain.com` |
| `FRONTEND_DOMAIN` | 前端域名 | `https://your-app.com` |
| `PAGES_DOMAIN` | Cloudflare Pages域名 | `https://your-app.pages.dev` |
| `WORKER_DOMAIN` | Worker API域名 | `https://your-api.com` |
| `VPS_API_URL` | VPS服务器地址 | `https://your-vps.com` |
| `TUNNEL_*_DOMAIN` | Cloudflare Tunnel域名 | `tunnel-*.your-vps.com` |
| `kv_namespaces.id` | KV Namespace ID | 从Dashboard获取 |
| `r2_buckets.bucket_name` | R2存储桶名称 | `your-bucket-name` |

#### **步骤3：创建Cloudflare资源**

1. **创建KV Namespace**
   ```bash
   wrangler kv:namespace create "YOYO_USER_DB" --env production
   ```
   将返回的ID填入 `wrangler.toml` 的 `kv_namespaces.id`

2. **创建R2 Buckets**
   ```bash
   wrangler r2 bucket create proxy-test-history
   wrangler r2 bucket create login-logs
   ```

3. **配置域名路由**
   - 在Cloudflare Dashboard中添加域名
   - 确保 `route.zone_name` 对应的Zone已添加

#### **步骤4：配置Secrets（Dashboard）**

登录 Cloudflare Dashboard → Workers → 选择你的Worker → Settings → Variables

添加以下Secrets：

| 名称 | 类型 | 说明 |
|------|------|------|
| `VPS_API_KEY` | Secret | VPS API密钥 |
| `EMERGENCY_ADMIN_PASSWORD` | Secret | 应急admin密码 |

#### **步骤5：部署**

```bash
wrangler login
wrangler deploy --env production
```

---

## 🔧 配置管理策略

### **方案A：共用配置（当前方式）**

**适用场景**：
- ✅ 团队内部协作
- ✅ 共用Cloudflare账号
- ✅ 共用域名和资源

**优点**：
- 简单，无需修改配置
- 配置统一，减少错误
- Git同步配置

**缺点**：
- 无法适应多账号部署

---

### **方案B：独立配置（推荐给外部开发者）**

**适用场景**：
- ✅ 开源项目
- ✅ 多个独立部署
- ✅ 不同的Cloudflare账号

**实施方式**：

1. 将 `wrangler.toml` 加入 `.gitignore`
   ```bash
   echo "cloudflare-worker/wrangler.toml" >> .gitignore
   ```

2. 每个开发者根据 `wrangler.toml.example` 创建自己的配置

**优点**：
- 配置独立，互不影响
- 适合多人协作

**缺点**：
- 需要手动同步配置更新

---

## 📝 配置文件说明

### **必须修改的配置**

这些配置包含个人/团队特定的信息，其他人部署时**必须修改**：

```toml
# 1. Worker名称（可能冲突）
name = "yoyo-streaming-simple"

# 2. 域名路由（个人域名）
route = { pattern = "yoyoapi.your-domain.com/*", zone_name = "your-domain.com" }

# 3. 环境变量中的域名
FRONTEND_DOMAIN = "https://yoyo.your-domain.com"
WORKER_DOMAIN = "https://yoyoapi.your-domain.com"
VPS_API_URL = "https://yoyo-vps.your-domain.com"

# 4. KV和R2的ID
id = "<KV_Namespace_ID>"
bucket_name = "proxy-test-history"
```

### **无需修改的配置**

这些配置是通用的，所有人都相同：

```toml
# 入口文件
main = "src/index.js"

# 兼容性配置
compatibility_date = "2024-01-01"
compatibility_flags = ["nodejs_compat"]

# 通用环境变量
ENVIRONMENT = "production"
VERSION = "2.0.0"
EMERGENCY_ADMIN_USERNAME = "admin"
```

---

## ⚠️ 重要提醒

### **Secrets必须在Dashboard配置**

以下敏感信息**不能**写在 `wrangler.toml` 中，必须在Dashboard配置：

- `VPS_API_KEY` - VPS API密钥
- `EMERGENCY_ADMIN_PASSWORD` - 应急admin密码

### **部署后验证**

部署成功后，访问以下端点验证：

```bash
# 健康检查
curl https://your-api-domain.com/health

# Worker信息
curl https://your-api-domain.com/api/system/info
```

---

## 🆘 常见问题

### Q1: 部署时提示 "Route already exists"

**原因**：域名路由已被其他Worker占用

**解决**：修改 `wrangler.toml` 中的 `name` 和 `route.pattern`

### Q2: 部署后环境变量都是undefined

**原因**：Secrets未在Dashboard配置

**解决**：在Dashboard → Settings → Variables 中添加Secrets

### Q3: KV/R2绑定失败

**原因**：KV Namespace或R2 Bucket不存在，或ID错误

**解决**：
1. 使用 `wrangler kv:namespace list` 查看KV列表
2. 使用 `wrangler r2 bucket list` 查看R2列表
3. 确认 `wrangler.toml` 中的ID正确

---

## 📚 相关文档

- [Cloudflare Workers 官方文档](https://developers.cloudflare.com/workers/)
- [Wrangler CLI 文档](https://developers.cloudflare.com/workers/wrangler/)
- [环境变量配置](https://developers.cloudflare.com/workers/configuration/environment-variables/)
- [Secrets 管理](https://developers.cloudflare.com/workers/configuration/secrets/)
