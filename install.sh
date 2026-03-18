#!/bin/bash
# AgentLinker 一键安装脚本 (macOS)
# 最简单的方式安装 AgentLinker

set -e

echo "🤖 ============================================"
echo "   AgentLinker 一键安装"
echo "============================================"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检查系统
if [ "$(uname)" != "Darwin" ]; then
    echo -e "${RED}❌ 错误：此脚本仅支持 macOS${NC}"
    exit 1
fi

echo -e "${BLUE}✓ 检测到 macOS${NC}"

# 检查 Python
if ! command -v python3 &> /dev/null; then
    echo -e "${YELLOW}⚠️  未找到 Python 3，正在安装...${NC}"
    if command -v brew &> /dev/null; then
        brew install python3
    else
        echo -e "${RED}请先安装 Homebrew 或 Python 3${NC}"
        echo "访问：https://www.python.org/downloads/macos/"
        exit 1
    fi
fi

PYTHON_VERSION=$(python3 --version)
echo -e "${GREEN}✓ Python: $PYTHON_VERSION${NC}"

# 选择安装方式
echo ""
echo "选择安装方式:"
echo "  1) 应用程序包 (.app) - 推荐，有图形界面"
echo "  2) 命令行工具 (Homebrew)"
echo "  3) 仅下载代码"
echo ""
read -p "请选择 [1-3]: " choice

case $choice in
    1)
        echo ""
        echo -e "${BLUE}正在创建应用程序包...${NC}"
        
        # 下载最新代码
        curl -L "https://github.com/Royean/AgentLinker/archive/refs/heads/master.tar.gz" -o /tmp/agentlinker.tar.gz
        tar -xzf /tmp/agentlinker.tar.gz -C /tmp
        rm /tmp/agentlinker.tar.gz
        
        # 创建应用包
        APP_NAME="AgentLinker"
        APP_DIR="$HOME/Applications/$APP_NAME.app"
        
        mkdir -p "$HOME/Applications"
        rm -rf "$APP_DIR"
        mkdir -p "$APP_DIR/Contents/MacOS"
        mkdir -p "$APP_DIR/Contents/Resources"
        
        # 复制代码
        cp -r /tmp/AgentLinker-master/client "$APP_DIR/Contents/Resources/"
        cp -r /tmp/AgentLinker-master/server "$APP_DIR/Contents/Resources/"
        
        # 创建启动脚本
        cat > "$APP_DIR/Contents/MacOS/agentlinker" << 'STARTSCRIPT'
#!/bin/bash
RESOURCES_DIR="$(dirname "$0")/../Resources"
PYTHON="/usr/bin/python3"
mkdir -p "$HOME/.agentlinker"
cd "$RESOURCES_DIR/client"
exec "$PYTHON" app.py
STARTSCRIPT
        
        chmod +x "$APP_DIR/Contents/MacOS/agentlinker"
        
        # 创建 Info.plist
        cat > "$APP_DIR/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>AgentLinker</string>
    <key>CFBundleExecutable</key>
    <string>agentlinker</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
</dict>
</plist>
EOF
        
        echo -e "${GREEN}✓ 应用程序已安装到：$APP_DIR${NC}"
        echo ""
        echo -e "${BLUE}正在启动应用...${NC}"
        open "$APP_DIR"
        
        ;;
    
    2)
        echo ""
        echo -e "${BLUE}通过 Homebrew 安装...${NC}"
        
        # 检查 Homebrew
        if ! command -v brew &> /dev/null; then
            echo -e "${YELLOW}正在安装 Homebrew...${NC}"
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        
        # 添加自定义 tap
        TAP_DIR="$(brew --repo)/custom-taps"
        mkdir -p "$TAP_DIR"
        
        # 复制 formula
        curl -L "https://raw.githubusercontent.com/Royean/AgentLinker/master/packaging/homebrew/agentlinker.rb" \
            -o "$TAP_DIR/agentlinker.rb"
        
        # 安装
        brew install "$TAP_DIR/agentlinker.rb"
        
        echo -e "${GREEN}✓ 安装完成${NC}"
        ;;
    
    3)
        echo ""
        echo -e "${BLUE}下载代码...${NC}"
        
        curl -L "https://github.com/Royean/AgentLinker/archive/refs/heads/master.tar.gz" -o /tmp/agentlinker.tar.gz
        tar -xzf /tmp/agentlinker.tar.gz -C "$HOME"
        rm /tmp/agentlinker.tar.gz
        
        echo -e "${GREEN}✓ 代码已下载到：$HOME/AgentLinker-master${NC}"
        ;;
    
    *)
        echo -e "${RED}无效选择${NC}"
        exit 1
        ;;
esac

echo ""
echo "============================================"
echo -e "${GREEN}   ✅ 安装完成！${NC}"
echo "============================================"
echo ""
echo "下一步:"
echo "  1. 打开 AgentLinker 应用"
echo "  2. 查看设备 ID 和配对密钥"
echo "  3. 在控制器端配对设备"
echo ""
echo "默认服务器：ws://43.98.243.80:8080/ws/client"
echo ""
echo -e "${BLUE}需要帮助？访问：https://github.com/Royean/AgentLinker${NC}"
echo ""
