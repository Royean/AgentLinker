#!/bin/bash
# AgentLinker 认证 API 测试脚本

BASE_URL="http://localhost:8080"

echo "======================================"
echo "AgentLinker 认证 API 测试"
echo "======================================"
echo ""

# 1. 健康检查
echo "1️⃣  健康检查..."
curl -s $BASE_URL/health | jq .
echo ""

# 2. 用户注册
echo "2️⃣  用户注册..."
REGISTER_RESULT=$(curl -s -X POST $BASE_URL/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"test123","email":"test@example.com"}')
echo $REGISTER_RESULT | jq .
echo ""

# 3. 用户登录
echo "3️⃣  用户登录..."
LOGIN_RESULT=$(curl -s -X POST $BASE_URL/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"test123"}')
echo $LOGIN_RESULT | jq .
echo ""

# 提取 token
TOKEN=$(echo $LOGIN_RESULT | jq -r '.access_token')
echo "🔑 Token: ${TOKEN:0:50}..."
echo ""

# 4. 获取当前用户信息
echo "4️⃣  获取当前用户信息..."
curl -s $BASE_URL/api/v1/auth/me \
  -H "Authorization: Bearer $TOKEN" | jq .
echo ""

# 5. 获取用户设备列表
echo "5️⃣  获取用户设备列表..."
curl -s $BASE_URL/api/v1/devices \
  -H "Authorization: Bearer $TOKEN" | jq .
echo ""

echo "======================================"
echo "✅ 测试完成！"
echo "======================================"
