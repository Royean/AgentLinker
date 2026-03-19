# AgentLinker Mobile 使用指南

📱 **在手机上运行 AgentLinker**

---

## 🎯 支持的 platform

| 平台 | 推荐应用 | 支持程度 |
|------|----------|----------|
| **iOS** | Pythonista 3 | ⭐⭐⭐⭐⭐ |
| **iOS** | a-Shell | ⭐⭐⭐⭐ |
| **Android** | Pydroid 3 | ⭐⭐⭐⭐⭐ |
| **Android** | Termux | ⭐⭐⭐⭐⭐ |

---

## 📲 iOS 安装和使用

### 方式一：Pythonista 3（推荐）

**步骤：**

1. **安装 Pythonista 3**
   - App Store 下载：$9.99
   - 支持完整的 Python 3.10

2. **安装依赖**
   ```bash
   # 在 Pythonista 中运行
   pip install websockets
   ```

3. **运行 AgentLinker**
   ```python
   # 打开 mobile_client.py
   # 修改服务端地址
   # 运行！
   ```

### 方式二：a-Shell（免费）

**步骤：**

1. **安装 a-Shell**
   - App Store 免费下载

2. **安装依赖**
   ```bash
   pip install websockets
   ```

3. **运行**
   ```bash
   python mobile_client.py --server ws://your-server.com:8080/ws/client
   ```

---

## 🤖 Android 安装和使用

### 方式一：Pydroid 3（推荐）

**步骤：**

1. **安装 Pydroid 3**
   - Google Play 免费下载

2. **安装依赖**
   ```bash
   # 打开 Pydroid
   # 进入 Pip 菜单
   # 安装 websockets
   ```

3. **运行**
   ```python
   # 打开 mobile_client.py
   # 点击运行按钮
   ```

### 方式二：Termux（高级用户）

**步骤：**

1. **安装 Termux**
   - F-Droid 下载（推荐）
   - 或 Google Play

2. **安装 Python 和依赖**
   ```bash
   pkg update
   pkg install python
   pip install websockets
   ```

3. **运行**
   ```bash
   python mobile_client.py --server ws://your-server.com:8080/ws/client
   ```

---

## 🔧 配置

### 修改服务端地址

编辑 `mobile_client.py`：

```python
# 默认配置
server_url = "ws://localhost:8080/ws/client"

# 修改为你的服务端地址
server_url = "ws://43.98.243.80:8080/ws/client"
```

### 自定义设备名称

```python
# 命令行方式
python mobile_client.py \
    --server ws://43.98.243.80:8080/ws/client \
    --device-name "我的 iPhone" \
    --device-id "iphone-001"
```

---

## 📋 使用示例

### 1. 启动客户端

```bash
# iOS (Pythonista)
python mobile_client.py

# Android (Termux)
python mobile_client.py --server ws://43.98.243.80:8080/ws/client
```

**输出：**
```
📱 AgentLinker Mobile 启动
   设备 ID: iPhone-abc12345
   设备名：iPhone
   服务端：ws://43.98.243.80:8080/ws/client

✅ 设备注册成功！
🔑 配对密钥：XK9M2P7Q
   使用主控端扫描此密钥进行配对
```

### 2. 配对设备

在主控端运行：

```bash
agentlinker --mode controller
[controller]> pair iPhone-abc12345 XK9M2P7Q
```

### 3. 执行命令

在主控端：

```bash
# 查看手机信息
[controller]> exec iPhone-abc12345 system.info

# 执行 Shell 命令
[controller]> exec iPhone-abc12345 shell.exec "uname -a"

# 读取文件
[controller]> exec iPhone-abc12345 file.read "/path/to/file.txt"

# 写入文件
[controller]> exec iPhone-abc12345 file.write "/path/to/file.txt" "Hello from AgentLinker!"
```

---

## 🎯 手机端特有功能

### 打开应用（iOS URL Scheme）

```python
# 打开 Safari
await client._open_app("https://example.com")

# 打开邮件
await client._open_app("mailto:test@example.com")

# 打开电话
await client._open_app("tel:1234567890")

# 打开短信
await client._open_app("sms:1234567890")
```

### 常用 iOS URL Scheme

```
Safari: https://example.com
邮件：mailto:email@example.com
电话：tel:1234567890
短信：sms:1234567890
相机：photos-redirect://
设置：App-Prefs:root=
```

---

## 📊 手机端功能列表

| 功能 | iOS | Android | 说明 |
|------|-----|---------|------|
| Shell 命令 | ✅ | ✅ | 执行系统命令 |
| 文件读写 | ✅ | ✅ | 读取/写入文件 |
| 系统信息 | ✅ | ✅ | 获取设备信息 |
| 打开应用 | ✅ | ✅ | 通过 URL Scheme |
| 文件传输 | ✅ | ✅ | 上传/下载文件 |
| 应用列表 | ⚠️ | ⚠️ | 受限（沙盒） |
| 相机访问 | ❌ | ❌ | 需要额外权限 |
| 位置信息 | ❌ | ❌ | 需要额外权限 |

---

## 🔐 安全考虑

### 1. 网络访问

- 使用 WSS 加密连接（生产环境）
- 不要使用公共 WiFi

### 2. 权限限制

- iOS/Android 沙盒限制
- 无法访问系统关键文件
- 需要用户授权的操作

### 3. 电池优化

- 后台运行可能被系统杀死
- 建议在前台运行

---

## 🐛 故障排查

### 问题 1: 无法连接

**原因**: 网络问题或服务端地址错误

**解决**:
```bash
# 检查网络连接
ping your-server.com

# 检查服务端地址
# 确保 WebSocket 地址正确
```

### 问题 2: 依赖安装失败

**原因**: 网络问题或 pip 源问题

**解决**:
```bash
# 使用国内源
pip install websockets -i https://pypi.tuna.tsinghua.edu.cn/simple
```

### 问题 3: 应用被杀死

**原因**: 系统后台限制

**解决**:
- 保持应用在前台
- 关闭电池优化
- 使用前台服务（Android）

---

## 📱 快速启动脚本

### iOS (Pythonista)

```python
# startup.py
import mobile_client
import asyncio

asyncio.run(mobile_client.quick_start(
    "ws://43.98.243.80:8080/ws/client"
))
```

### Android (Termux)

```bash
#!/data/data/com.termux/files/usr/bin/bash
# run.sh
cd /storage/emulated/0/AgentLinker
python mobile_client.py --server ws://43.98.243.80:8080/ws/client
```

---

## 🎓 最佳实践

1. **保持连接** - 尽量让应用在前台运行
2. **合理命名** - 使用有意义的设备名称
3. **安全配对** - 不要在公共场合展示配对密钥
4. **定期更新** - 保持代码最新

---

## 🔗 相关资源

- [Pythonista 官网](https://www.pythonista.io)
- [a-Shell GitHub](https://github.com/holzschu/a-shell)
- [Pydroid 3 Google Play](https://play.google.com/store/apps/details?id=ru.iiec.pydroid3)
- [Termux 官网](https://termux.org)

---

**版本**: 1.0.0  
**更新日期**: 2026-03-20  
**维护者**: AgentLinker Team
