#!/bin/bash
# AgentLinker Server 启动脚本（带认证功能）

cd "$(dirname "$0")"

echo "🚀 启动 AgentLinker Server v3.0..."
echo ""

# 检查依赖
echo "📦 检查依赖..."
python3 -c "import fastapi, uvicorn, jwt, bcrypt, aiosqlite" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "⚠️  安装依赖..."
    pip3 install -r requirements.txt -q
fi

# 清理旧进程
echo "🧹 清理旧进程..."
pkill -9 -f "python3.*main.py" 2>/dev/null
sleep 1

# 启动服务
echo "🔌 启动服务..."
nohup python3 main.py > server.log 2>&1 &
PID=$!

sleep 3

# 检查服务状态
if ps -p $PID > /dev/null; then
    echo "✅ 服务启动成功！"
    echo ""
    echo "📊 服务信息:"
    echo "   - 地址：http://localhost:8080"
    echo "   - PID: $PID"
    echo "   - 日志：server.log"
    echo ""
    echo "🔐 默认管理员账户:"
    echo "   - 用户名：admin"
    echo "   - 密码：admin123"
    echo ""
    echo "📖 API 文档：http://localhost:8080/docs"
    echo ""
    echo "🛑 停止服务：pkill -f 'python3.*main.py'"
else
    echo "❌ 服务启动失败！"
    echo "查看日志：cat server.log"
fi
