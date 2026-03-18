# AgentLinker 开发路线图

## 🎯 目标
打造跨平台、易用、安全的 AI Agent 远程控制系统

## 📦 核心功能

### 1. 跨平台支持
- [ ] Linux (systemd)
- [ ] macOS (launchd)
- [ ] Windows (Service + 系统托盘)

### 2. 安装包形式
- [ ] Linux: `.deb` / `.rpm` / 安装脚本
- [ ] macOS: `.dmg` / Homebrew
- [ ] Windows: `.msi` / `.exe` 安装程序

### 3. 一对多控制
- [ ] 主控端支持多设备连接
- [ ] 设备分组管理
- [ ] 批量指令下发

### 4. 配对优化
- [ ] 二维码配对
- [ ] 局域网自动发现
- [ ] 持久化配对（无需每次重新配对）

### 5. 安全增强
- [ ] TLS/SSL 加密
- [ ] 设备证书
- [ ] 操作审计日志

---

## 🏗️ 技术架构

### 服务端
```
FastAPI + WebSocket
├── 设备管理（在线/离线状态）
├── 配对管理（设备 - 控制器绑定）
├── 消息路由（控制器 ↔ 设备）
└── API 网关（Agent HTTP 调用）
```

### 客户端
```
Python 跨平台客户端
├── Linux: systemd 服务
├── macOS: launchd 服务
├── Windows: Windows Service + 系统托盘
└── 统一核心逻辑
```

---

## 📁 新的目录结构

```
AgentLinker/
├── server/                 # 服务端
│   ├── main.py
│   ├── requirements.txt
│   └── config.py
├── client/                 # 客户端核心
│   ├── core/              # 跨平台核心逻辑
│   │   ├── __init__.py
│   │   ├── client.py      # WebSocket 客户端
│   │   ├── executor.py    # 指令执行器
│   │   └── config.py      # 配置管理
│   ├── platform/          # 平台特定实现
│   │   ├── linux.py
│   │   ├── macos.py
│   │   └── windows.py
│   ├── cli.py             # 命令行界面
│   └── tray.py            # Windows 系统托盘
├── installer/              # 安装包
│   ├── linux/
│   │   ├── install.sh
│   │   ├── uninstall.sh
│   │   └── agentlinker.service
│   ├── macos/
│   │   ├── install.sh
│   │   └── com.agentlinker.client.plist
│   └── windows/
│       ├── installer.iss   # Inno Setup 脚本
│       └── service.py
├── examples/               # 使用示例
├── docs/                   # 文档
└── tests/                  # 测试
```

---

## 🚀 开发计划

### Phase 1: 核心功能完善 (1-2 天)
1. 重构客户端为跨平台架构
2. 实现一对多控制
3. 持久化配对

### Phase 2: 安装包制作 (1 天)
1. Linux 安装脚本
2. macOS 安装脚本
3. Windows 安装程序

### Phase 3: 测试迭代 (持续)
1. 阿里云 ↔ 腾讯云 互测
2. 修复 bug
3. 优化体验

---

## 🧪 测试环境

| 角色 | 平台 | IP | 用途 |
|------|------|-----|------|
| 服务端 | 腾讯云 | 43.159.61.30 | 中转服务器 |
| 被控端 A | 阿里云 | 43.98.243.80 | Linux 被控 |
| 被控端 B | 腾讯云 | 43.159.61.30 | 本地测试 |

---

## 📝 待办事项

1. [ ] 重构客户端代码
2. [ ] 实现一对多控制
3. [ ] 添加 Windows 支持
4. [ ] 添加 macOS 支持
5. [ ] 制作安装包
6. [ ] 编写文档
7. [ ] 持续测试
