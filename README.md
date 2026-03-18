# AgentLinker

🤖 **跨平台 AI Agent 远程控制系统**

一套轻量、高权限、内网穿透、跨平台的远程接入系统，让任何 AI Agent 可以跨网、安全、高权限控制 Linux、macOS、Windows 主机。

## ✨ 特性

- 🖥️ **跨平台支持** - Linux、macOS、Windows 全支持
- 📦 **一键安装** - 安装包形式，快速部署
- 🎮 **一对多控制** - 一台主机可控制多台远程设备
- 🔐 **安全配对** - 动态配对密钥，持久化绑定
- 🌐 **内网穿透** - 无需公网 IP，主动连接服务端
- 🔒 **TLS 加密** - 全程加密传输
- 📊 **实时状态** - 设备在线/离线状态实时同步

## 🏗️ 架构

```
┌─────────────┐      HTTP/WebSocket      ┌──────────────────┐
│  AI Agent   │ ◄──────────────────────► │   云端服务端     │
│  (主控端)   │                          │  (中转 + 鉴权)   │
└─────────────┘                          └──────────────────┘
                                                ▲
                                                │ WebSocket
                                                ▼
                                         ┌──────────────┐
                                         │  Linux 客户端 │
                                         │  macOS 客户端 │
                                         │  Windows 客户端│
                                         └──────────────┘
                                                │
                                                ▼
                                         ┌──────────────┐
                                         │   目标主机    │
                                         └──────────────┘
```

## 🚀 快速开始

### 1. 部署服务端

```bash
cd server

# 创建虚拟环境
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# 启动服务端
python main.py
```

服务端默认监听 `0.0.0.0:8080`

### 2. 安装被控端客户端

#### Linux/macOS

```bash
# 一键安装
curl -fsSL https://your-server.com/install.sh | sudo bash
```

#### Windows

下载安装程序运行（开发中）

### 3. 配置客户端

编辑配置文件 `/etc/agentlinker/config.json`:

```json
{
  "device_id": "my-server-01",
  "device_name": "阿里云主机",
  "token": "YOUR_DEVICE_TOKEN",
  "server_url": "wss://your-server.com/ws/client"
}
```

### 4. 启动客户端

```bash
# Linux (systemd)
sudo systemctl start agentlinker
sudo systemctl enable agentlinker

# 查看日志
sudo journalctl -u agentlinker -f
```

启动后，日志中会显示配对密钥：

```
==================================================
🔐 配对密钥已生成！
   设备 ID: my-server-01
   配对密钥：XK9M2P7Q
   将此密钥提供给主控端进行配对
==================================================
```

### 5. 主控端连接

```bash
# 启动主控端
agentlinker --mode controller --server ws://your-server.com/ws/controller
```

进入交互式命令行：

```
[controller]> pair my-server-01 XK9M2P7Q
[controller]> list
[controller]> exec my-server-01 df -h
[controller]> info my-server-01
```

## 📋 支持的指令

| Action | 描述 | 参数 |
|--------|------|------|
| `system.info` | 获取系统信息 | - |
| `shell.exec` | 执行 shell 命令 | `cmd`, `timeout`, `cwd` |
| `file.list` | 列目录 | `path` |
| `file.read` | 读文件 | `path`, `offset`, `limit` |
| `file.write` | 写文件 | `path`, `content`, `encoding` |
| `file.delete` | 删除文件/目录 | `path`, `recursive` |
| `process.list` | 进程列表 | - |
| `process.kill` | 杀死进程 | `pid`, `signal` |
| `service.operate` | 系统服务操作 | `service`, `operation` |

## 🎮 主控端命令

| 命令 | 描述 | 示例 |
|------|------|------|
| `pair` | 配对设备 | `pair device-id XK9M2P7Q` |
| `unpair` | 解除配对 | `unpair device-id` |
| `list` | 列出已配对设备 | `list` |
| `scan` | 扫描在线设备 | `scan` |
| `exec` | 执行命令 | `exec device-id ls -l` |
| `info` | 获取设备信息 | `info device-id` |

## 🔐 安全配置

### Token 配置

服务端使用环境变量配置 Token：

```bash
export SERVER_AGENT_TOKEN="your_secure_token"
export LINUX_DEVICE_TOKEN="device_token"
```

### 配对机制

1. 设备启动后生成动态配对密钥（8 位，1 小时过期）
2. 主控端使用配对密钥连接设备
3. 配对成功后持久化绑定
4. 支持一对多配对（一个控制器可配对多个设备）

### 生产环境建议

- 使用随机生成的长 Token（32 位以上）
- 使用 HTTPS/WSS 加密传输
- 配置防火墙限制服务端访问 IP
- 定期更换 Token

## 📁 目录结构

```
AgentLinker/
├── server/               # 服务端
│   ├── main.py          # FastAPI 主程序
│   └── requirements.txt
├── client/               # 客户端
│   ├── core/            # 跨平台核心逻辑
│   ├── controller.py    # 主控端客户端
│   ├── cli.py           # 命令行工具
│   └── requirements.txt
├── installer/            # 安装包
│   ├── linux/
│   │   └── install.sh   # Linux 安装脚本
│   ├── macos/
│   └── windows/
├── examples/             # 调用示例
├── docs/                 # 文档
└── tests/                # 测试
```

## 🧪 测试

使用两台机器进行测试：

```bash
# 机器 A (服务端 + 被控端)
# 1. 启动服务端
cd server && python main.py

# 2. 安装被控端
sudo bash installer/linux/install.sh

# 机器 B (主控端)
# 启动主控端
agentlinker --mode controller --server ws://机器 A-IP:8080/ws/controller
```

## 🛣️ 开发路线图

- [x] 跨平台核心架构
- [x] 一对多控制
- [x] Linux 安装脚本
- [ ] macOS 安装包
- [ ] Windows 安装包
- [ ] Web 控制台
- [ ] 设备分组管理
- [ ] 批量指令下发
- [ ] 操作审计日志
- [ ] TLS/SSL 证书

## 📝 许可证

MIT
