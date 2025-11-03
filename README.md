# YOYO流媒体平台 - 项目结构说明

## 📁 目录结构

\\\
secure-streaming-platform/
│
├── cloudflare-worker/          # Cloudflare Workers（后端API）
│   ├── src/                    # Workers源代码
│   │   ├── index.js            # 主入口文件（单文件架构）
│   │   └── handlers/           # 功能模块
│   ├── wrangler.toml           # Workers配置
│   └── package.json
│
├── frontend/                   # 前端（Vue.js）
│   ├── src/                    # 前端源代码
│   ├── public/                 # 静态资源
│   └── package.json
│
├── vps-server/                 # VPS服务端（Node.js）
│   ├── src/                    # 服务端源代码
│   │   ├── routes/             # API路由
│   │   ├── services/           # 业务服务
│   │   └── middleware/         # 中间件
│   ├── ecosystem.config.js     # PM2配置
│   └── package.json
│
├── docs/                       # 文档
│   ├── project/                # 项目文档
│   ├── root-legacy/            # 遗留文档
│   └── *.md                    # 项目级文档
│
├── scripts/                    # 脚本工具
│   ├── deploy/                 # 部署脚本
│   ├── test/                   # 测试脚本
│   ├── fix/                    # 修复脚本
│   └── utils/                  # 工具脚本
│
├── config/                     # 配置文件
├── src/                        # 共享源代码
└── archive/                    # 归档文件
\\\

## 🚀 部署流程

### 1. Cloudflare Workers
\\\ash
cd cloudflare-worker
wrangler deploy --env production
\\\

### 2. Cloudflare Pages（前端）
\\\ash
# 自动部署：提交代码到GitHub
git push origin master

# 构建配置：
# - Root directory: frontend
# - Build command: npm run build
# - Output directory: dist
\\\

### 3. VPS服务端
\\\ash
cd vps-server
pm2 restart ecosystem.config.js
\\\

## 📝 重构说明

**重构日期**: 2025-11-03

**重构原因**:
- 消除两套Workers代码并存的混乱
- 提升核心目录到根级别
- 统一脚本和文档管理

**主要变更**:
- 删除 \ps-transcoder-api/cloudflare-worker/\（不用的版本）
- 提升 \rontend/\、\ps-server/\ 到根目录
- 整理所有脚本到 \scripts/\
- 合并文档到 \docs/\

**备份标签**: \ackup-before-restructure-20251103\

## ⚠️ 注意事项

1. **Cloudflare Pages需要更新构建路径**：
   - 旧路径: \ps-transcoder-api/frontend\
   - 新路径: \rontend\

2. **部署脚本路径已更改**：
   - 所有脚本移至 \scripts/\ 目录

3. **VPS服务端重命名**：
   - 旧名称: \ps-transcoder-api/vps-transcoder-api\
   - 新名称: \ps-server\

## 📞 联系方式

如有问题，请查看 \docs/\ 目录中的详细文档。
