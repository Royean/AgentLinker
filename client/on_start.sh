#!/bin/bash
# AgentLinker 启动后自动复制配对密钥

set -e

echo "🔑 AgentLinker 启动后脚本"

# 等待 3 秒让服务完全启动
sleep 3

# 运行自动复制脚本
if [ -f "/opt/agentlinker/client/auto_copy_key.py" ]; then
    python3 /opt/agentlinker/client/auto_copy_key.py
else
    echo "⚠️ 自动复制脚本不存在"
fi

echo "✅ 完成"
