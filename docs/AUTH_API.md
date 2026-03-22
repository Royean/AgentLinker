# AgentLinker 认证 API 文档

## 📋 概述

AgentLinker v3.0 新增了完整的用户认证系统，支持：
- ✅ 用户注册
- ✅ 用户登录（JWT Token）
- ✅ 设备与用户绑定
- ✅ 审计日志
- ✅ 权限控制

## 🔐 默认管理员账户

首次启动会自动创建默认管理员账户：
- **用户名**: `admin`
- **密码**: `admin123`

⚠️ **生产环境请立即修改密码！**

## 📡 API 端点

### 1. 用户注册

**POST** `/api/v1/auth/register`

**请求体**:
```json
{
  "username": "jiewei",
  "password": "jiewei123",
  "email": "jiewei@example.com"  // 可选
}
```

**响应**:
```json
{
  "id": 2,
  "username": "jiewei",
  "email": "jiewei@example.com",
  "created_at": "2026-03-22 04:50:18",
  "is_active": true
}
```

---

### 2. 用户登录

**POST** `/api/v1/auth/login`

**请求体**:
```json
{
  "username": "jiewei",
  "password": "jiewei123"
}
```

**响应**:
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "expires_in": 86400
}
```

---

### 3. 获取当前用户信息

**GET** `/api/v1/auth/me`

**请求头**:
```
Authorization: Bearer <access_token>
```

**响应**:
```json
{
  "id": 2,
  "username": "jiewei",
  "email": "jiewei@example.com",
  "created_at": "2026-03-22 04:50:18",
  "is_active": true
}
```

---

### 4. 获取用户设备列表

**GET** `/api/v1/devices`

**请求头**:
```
Authorization: Bearer <access_token>
```

**响应**:
```json
{
  "code": 0,
  "devices": [
    {
      "device_id": "device-001",
      "device_name": "My Server",
      "platform": "Linux",
      "connected_at": 1711080000,
      "last_ping": 1711080060,
      "online_duration": 60
    }
  ]
}
```

---

### 5. 获取用户的所有设备（包括离线）

**GET** `/api/v1/users/{user_id}/devices`

**请求头**:
```
Authorization: Bearer <access_token>
```

**响应**:
```json
{
  "code": 0,
  "devices": [
    {
      "id": 1,
      "device_id": "device-001",
      "user_id": 2,
      "device_name": "My Server",
      "platform": "Linux",
      "created_at": "2026-03-22 04:50:18",
      "last_seen": "2026-03-22 05:00:00"
    }
  ]
}
```

---

## 🚀 使用示例

### 使用 curl

```bash
# 1. 注册
curl -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"jiewei","password":"jiewei123"}'

# 2. 登录并获取 token
TOKEN=$(curl -s -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"jiewei","password":"jiewei123"}' | jq -r '.access_token')

# 3. 使用 token 访问受保护的 API
curl -s http://localhost:8080/api/v1/auth/me \
  -H "Authorization: Bearer $TOKEN"

# 4. 获取设备列表
curl -s http://localhost:8080/api/v1/devices \
  -H "Authorization: Bearer $TOKEN"
```

### 使用 Python

```python
import requests

BASE_URL = "http://localhost:8080"

# 注册
register_data = {
    "username": "jiewei",
    "password": "jiewei123"
}
resp = requests.post(f"{BASE_URL}/api/v1/auth/register", json=register_data)
print("注册结果:", resp.json())

# 登录
login_data = {
    "username": "jiewei",
    "password": "jiewei123"
}
resp = requests.post(f"{BASE_URL}/api/v1/auth/login", json=login_data)
token = resp.json()["access_token"]
print("Token:", token)

# 获取用户信息
headers = {"Authorization": f"Bearer {token}"}
resp = requests.get(f"{BASE_URL}/api/v1/auth/me", headers=headers)
print("用户信息:", resp.json())

# 获取设备列表
resp = requests.get(f"{BASE_URL}/api/v1/devices", headers=headers)
print("设备列表:", resp.json())
```

---

## 🔧 配置

### 环境变量

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `SERVER_AGENT_TOKEN` | 服务端 Agent Token | `ah_server_token_change_in_production` |
| `LINUX_DEVICE_TOKEN` | Linux 设备 Token | `ah_device_token_change_in_production` |
| `SECRET_KEY` | JWT 密钥 | `your-secret-key-change-in-production` |
| `DATABASE_PATH` | SQLite 数据库路径 | `./agentlinker.db` |

### 生产环境配置

```bash
export SERVER_AGENT_TOKEN="your-random-server-token"
export LINUX_DEVICE_TOKEN="your-random-device-token"
export SECRET_KEY="your-random-secret-key-at-least-32-chars"
export DATABASE_PATH="/var/lib/agentlinker/agentlinker.db"

python3 main.py
```

---

## 📊 数据库结构

### users 表
- `id` - 用户 ID
- `username` - 用户名（唯一）
- `email` - 邮箱（可选）
- `hashed_password` - 密码哈希
- `created_at` - 创建时间
- `is_active` - 是否激活
- `is_admin` - 是否管理员

### devices 表
- `id` - 记录 ID
- `device_id` - 设备 ID（唯一）
- `user_id` - 所属用户 ID
- `device_name` - 设备名称
- `platform` - 平台
- `paired_controllers` - 已配对的控制器（JSON）
- `created_at` - 创建时间
- `last_seen` - 最后在线时间

### audit_logs 表
- `id` - 日志 ID
- `user_id` - 用户 ID
- `action` - 操作类型
- `resource` - 资源
- `details` - 详情
- `ip_address` - IP 地址
- `created_at` - 创建时间

---

## 🔒 安全建议

1. **修改默认密码** - 首次启动后立即修改 admin 密码
2. **使用强密钥** - SECRET_KEY 至少 32 位随机字符
3. **启用 HTTPS** - 生产环境使用 Nginx 反向代理 + SSL
4. **定期备份数据库** - `agentlinker.db` 包含所有用户数据
5. **监控审计日志** - 定期检查异常登录和操作

---

## 🧪 测试

运行测试脚本：

```bash
cd server
chmod +x test_auth.sh
./test_auth.sh
```

---

## 📝 更新日志

### v3.0.0 (2026-03-22)
- ✅ 新增用户注册/登录功能
- ✅ JWT Token 认证
- ✅ SQLite 数据库支持
- ✅ 设备与用户绑定
- ✅ 审计日志记录
- ✅ 权限控制
