#!/bin/bash
# AgentLinker Linux 安装脚本
# 支持 Debian/Ubuntu/CentOS/Fedora

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 配置
INSTALL_DIR="/opt/agentlinker"
CONFIG_DIR="/etc/agentlinker"
LOG_DIR="/var/log/agentlinker"
SERVICE_NAME="agentlinker"

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}   AgentLinker 安装脚本${NC}"
echo -e "${GREEN}============================================${NC}"

# 检查 root 权限
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}错误：请使用 sudo 运行此脚本${NC}"
    echo "用法：sudo bash install.sh"
    exit 1
fi

# 检测操作系统
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        OS=$(uname -s)
        VER=""
    fi
    
    echo "检测到操作系统：$OS $VER"
}

# 安装依赖
install_dependencies() {
    echo -e "${YELLOW}正在安装依赖...${NC}"
    
    case "$OS" in
        *"Ubuntu"* | *"Debian"*)
            apt-get update
            apt-get install -y python3 python3-pip python3-venv curl
            ;;
        *"CentOS"* | *"Fedora"* | *"Red Hat"*)
            yum install -y python3 python3-pip curl
            ;;
        *)
            echo -e "${YELLOW}警告：未知操作系统，尝试使用系统包管理器安装 python3${NC}"
            ;;
    esac
    
    echo -e "${GREEN}✓ 依赖安装完成${NC}"
}

# 创建目录
create_directories() {
    echo -e "${YELLOW}正在创建目录...${NC}"
    
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$LOG_DIR"
    
    echo -e "${GREEN}✓ 目录创建完成${NC}"
}

# 下载客户端
download_client() {
    echo -e "${YELLOW}正在下载 AgentLinker 客户端...${NC}"
    
    # 从 GitHub 下载最新版本
    LATEST_VERSION=$(curl -s https://api.github.com/repos/Royean/AgentLinker/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
    
    if [ -z "$LATEST_VERSION" ]; then
        LATEST_VERSION="main"
    fi
    
    DOWNLOAD_URL="https://github.com/Royean/AgentLinker/archive/refs/heads/${LATEST_VERSION}.tar.gz"
    
    # 下载并解压
    curl -L "$DOWNLOAD_URL" -o /tmp/agentlinker.tar.gz
    tar -xzf /tmp/agentlinker.tar.gz -C "$INSTALL_DIR" --strip-components=1
    
    rm -f /tmp/agentlinker.tar.gz
    
    echo -e "${GREEN}✓ 客户端下载完成${NC}"
}

# 创建虚拟环境
create_venv() {
    echo -e "${YELLOW}正在创建 Python 虚拟环境...${NC}"
    
    cd "$INSTALL_DIR"
    python3 -m venv venv
    source venv/bin/activate
    
    # 安装依赖
    if [ -f "client/requirements.txt" ]; then
        pip install -r client/requirements.txt
    else
        pip install websockets
    fi
    
    echo -e "${GREEN}✓ 虚拟环境创建完成${NC}"
}

# 创建配置文件
create_config() {
    echo -e "${YELLOW}正在创建配置文件...${NC}"
    
    cat > "$CONFIG_DIR/config.json" << 'EOF'
{
  "device_id": "",
  "device_name": "",
  "token": "YOUR_DEVICE_TOKEN",
  "server_url": "wss://your-server.com/ws/client",
  "reconnect_interval": 5,
  "heartbeat_interval": 30
}
EOF
    
    echo -e "${YELLOW}配置文件已创建：$CONFIG_DIR/config.json${NC}"
    echo -e "${YELLOW}请编辑配置文件，设置 token 和 server_url${NC}"
    
    echo -e "${GREEN}✓ 配置文件创建完成${NC}"
}

# 创建 systemd 服务
create_service() {
    echo -e "${YELLOW}正在创建 systemd 服务...${NC}"
    
    cat > "/etc/systemd/system/$SERVICE_NAME.service" << EOF
[Unit]
Description=AgentLinker Client
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
Environment="PATH=$INSTALL_DIR/venv/bin"
ExecStart=$INSTALL_DIR/venv/bin/python3 $INSTALL_DIR/client/cli.py --mode client
Restart=always
RestartSec=10
StandardOutput=append:$LOG_DIR/agentlinker.log
StandardError=append:$LOG_DIR/agentlinker.error.log

[Install]
WantedBy=multi-user.target
EOF
    
    # 重载 systemd
    systemctl daemon-reload
    
    echo -e "${GREEN}✓ systemd 服务创建完成${NC}"
}

# 创建快捷脚本
create_cli() {
    echo -e "${YELLOW}正在创建 CLI 工具...${NC}"
    
    cat > "$INSTALL_DIR/client/cli.py" << 'EOF'
#!/usr/bin/env python3
"""AgentLinker CLI"""

import sys
import os

# 添加核心模块路径
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'core'))

from core import Config, AgentClient, generate_device_id

def main():
    import argparse
    
    parser = argparse.ArgumentParser(description='AgentLinker Client')
    parser.add_argument('--mode', choices=['client', 'controller'], default='client',
                       help='运行模式：client(被控端) 或 controller(主控端)')
    parser.add_argument('--config', default='/etc/agentlinker/config.json',
                       help='配置文件路径')
    parser.add_argument('--server', default='ws://localhost:8080/ws/controller',
                       help='服务端 URL (controller 模式)')
    
    args = parser.parse_args()
    
    if args.mode == 'client':
        config = Config(args.config)
        
        # 如果设备 ID 为空，自动生成
        if not config.device_id:
            config.device_id = generate_device_id()
            print(f"已生成设备 ID: {config.device_id}")
        
        if not config.token or not config.server_url:
            print("错误：配置不完整，请编辑配置文件:")
            print(f"  {args.config}")
            sys.exit(1)
        
        print(f"启动 AgentLinker Client")
        print(f"设备 ID: {config.device_id}")
        print(f"服务端：{config.server_url}")
        
        client = AgentClient(config)
        
        import signal
        def signal_handler(signum, frame):
            print("\n收到退出信号，正在停止...")
            client.stop()
            sys.exit(0)
        
        signal.signal(signal.SIGTERM, signal_handler)
        signal.signal(signal.SIGINT, signal_handler)
        
        import asyncio
        asyncio.run(client.run())
    
    elif args.mode == 'controller':
        from controller import ControllerClient
        import asyncio
        
        controller = ControllerClient(args.server)
        
        import signal
        def signal_handler(signum, frame):
            print("\n收到退出信号，正在停止...")
            controller.stop()
            sys.exit(0)
        
        signal.signal(signal.SIGTERM, signal_handler)
        signal.signal(signal.SIGINT, signal_handler)
        
        asyncio.run(controller.run())

if __name__ == "__main__":
    main()
EOF
    
    chmod +x "$INSTALL_DIR/client/cli.py"
    
    # 创建系统链接
    ln -sf "$INSTALL_DIR/client/cli.py" /usr/local/bin/agentlinker
    
    echo -e "${GREEN}✓ CLI 工具创建完成${NC}"
    echo -e "${GREEN}  可以使用 'agentlinker' 命令启动${NC}"
}

# 主函数
main() {
    detect_os
    install_dependencies
    create_directories
    download_client
    create_venv
    create_config
    create_service
    create_cli
    
    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}   安装完成！${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""
    echo "下一步:"
    echo "  1. 编辑配置文件：$CONFIG_DIR/config.json"
    echo "  2. 设置 token 和 server_url"
    echo "  3. 启动服务：systemctl start $SERVICE_NAME"
    echo "  4. 开机自启：systemctl enable $SERVICE_NAME"
    echo "  5. 查看日志：journalctl -u $SERVICE_NAME -f"
    echo ""
    echo "配对密钥将在启动后显示在日志中"
    echo ""
}

# 运行
main
