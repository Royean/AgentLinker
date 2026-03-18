#!/bin/bash
# AgentLinker 服务端一键部署脚本
# 在阿里云主机上执行

set -e

echo "============================================"
echo "   AgentLinker 服务端部署"
echo "============================================"

# 克隆仓库
echo "正在下载代码..."
cd /tmp
rm -rf AgentLinker
git clone https://github.com/Royean/AgentLinker.git
cd AgentLinker/server

# 安装依赖
echo "正在安装依赖..."
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# 启动服务端
echo "正在启动服务端..."
nohup python main.py > /var/log/agentlinker_server.log 2>&1 &

# 等待启动
sleep 3

# 检查状态
echo ""
echo "============================================"
echo "   部署完成！"
echo "============================================"
echo ""
echo "服务端日志:"
tail -20 /var/log/agentlinker_server.log
echo ""
echo "测试连接:"
curl http://localhost:8080/health
echo ""
echo ""
echo "⚠️  重要：请在阿里云控制台开放 8080 端口！"
echo "   安全组 → 入站规则 → TCP:8080 → 来源 0.0.0.0/0"
echo ""
