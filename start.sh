#!/bin/bash
# AgentLinker 启动脚本（优化版）
# 自动复制配对密钥 + 状态检查

set -e

INSTALL_DIR="/opt/agentlinker"
CONFIG_FILE="/etc/agentlinker/config.json"
LOG_DIR="/var/log/agentlinker"

echo "🚀 AgentLinker 启动脚本"
echo "============================"

# 检查配置
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ 配置文件不存在：$CONFIG_FILE"
    echo "请先运行：sudo bash install.sh"
    exit 1
fi

# 读取配置
DEVICE_ID=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('device_id', 'Unknown'))" 2>/dev/null || echo "Unknown")
echo "设备 ID: $DEVICE_ID"

# 启动服务
echo "启动 AgentLinker 服务..."
sudo launchctl start com.agentlinker.client 2>/dev/null || true

# 等待服务启动
echo "等待服务启动..."
sleep 3

# 自动复制配对密钥
echo ""
echo "🔑 自动复制配对密钥..."
if [ -f "$INSTALL_DIR/client/auto_copy_key.py" ]; then
    python3 "$INSTALL_DIR/client/auto_copy_key.py"
else
    echo "⚠️ 自动复制脚本不存在，跳过"
fi

# 显示状态
echo ""
echo "📊 服务状态:"
launchctl list | grep agentlinker || echo "服务未运行"

echo ""
echo "============================"
echo "✅ 启动完成!"
echo ""
echo "常用命令:"
echo "  查看日志：tail -f $LOG_DIR/agentlinker.log"
echo "  重启服务：sudo launchctl kickstart -k system/com.agentlinker.client"
echo "  显示二维码：agentlinker-show-qr"
echo ""
