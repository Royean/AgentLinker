#!/bin/bash
# AgentLinker macOS 打包脚本（通用版）
# 生成 .app 和 .tar.gz 包

set -e

# 配置
APP_NAME="AgentLinker"
APP_DIR="/tmp/AgentLinker-App"
OUTPUT_DIR="/tmp/AgentLinker-Releases"
VERSION="2.0.0"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "🍎 AgentLinker macOS 打包脚本"
echo "版本：$VERSION"
echo ""

# 清理旧文件
rm -rf "$APP_DIR" "$OUTPUT_DIR"
mkdir -p "$APP_DIR/$APP_NAME.app/Contents/MacOS"
mkdir -p "$APP_DIR/$APP_NAME.app/Contents/Resources"
mkdir -p "$OUTPUT_DIR"

# 创建 Info.plist
echo "📦 创建 Info.plist..."
cat > "$APP_DIR/$APP_NAME.app/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>agentlinker</string>
    <key>CFBundleIdentifier</key>
    <string>com.agentlinker.client</string>
    <key>CFBundleName</key>
    <string>AgentLinker</string>
    <key>CFBundleDisplayName</key>
    <string>AgentLinker</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>CFBundleLicense</key>
    <string>MIT</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 AgentLinker. All rights reserved.</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

# 创建启动脚本
echo "📝 创建启动脚本..."
cat > "$APP_DIR/$APP_NAME.app/Contents/MacOS/agentlinker" << 'EOF'
#!/bin/bash
# AgentLinker macOS App 启动脚本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
INSTALL_DIR="$APP_DIR/Contents/Resources"

# 检查配置
CONFIG_FILE="/etc/agentlinker/config.json"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "错误：配置文件不存在，请先运行安装脚本"
    echo "运行：sudo bash installer/macos/install.sh"
    exit 1
fi

# 激活虚拟环境
source "$INSTALL_DIR/venv/bin/activate"

# 启动客户端
cd "$INSTALL_DIR"
exec python3 "$INSTALL_DIR/client/cli.py" --mode client --config "$CONFIG_FILE"
EOF

chmod +x "$APP_DIR/$APP_NAME.app/Contents/MacOS/agentlinker"

# 复制资源文件
echo "📁 复制资源文件..."
cp -r /tmp/AgentLinker/* "$APP_DIR/$APP_NAME.app/Contents/Resources/"

# 创建虚拟环境
echo "🐍 创建虚拟环境..."
cd "$APP_DIR/$APP_NAME.app/Contents/Resources"
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip -q
pip install -r client/requirements.txt -q

# 创建 PkgInfo
echo "APPL????" > "$APP_DIR/$APP_NAME.app/Contents/PkgInfo"

# 创建安装说明
echo "📄 创建安装说明..."
cat > "$APP_DIR/README.txt" << EOF
AgentLinker $VERSION for macOS

========================================
安装步骤:
========================================

方式一：使用安装脚本（推荐）
----------------------------------------
1. 打开终端
2. 运行：
   sudo bash installer/macos/install.sh

方式二：手动安装
----------------------------------------
1. 将 AgentLinker.app 拖到 /Applications
2. 运行安装脚本配置服务：
   sudo /Applications/AgentLinker.app/Contents/Resources/installer/macos/install.sh

========================================
配置:
========================================
1. 编辑配置文件：
   sudo nano /etc/agentlinker/config.json

2. 设置 token 和 server_url

========================================
启动:
========================================
# 启动服务
sudo launchctl start com.agentlinker.client

# 查看日志
tail -f /var/log/agentlinker/agentlinker.log

# 显示配对二维码
agentlinker-show-qr

========================================
更多信息:
========================================
GitHub: https://github.com/Royean/AgentLinker
文档：https://github.com/Royean/AgentLinker/tree/master/docs

EOF

# 创建 tar.gz 包
echo "📦 打包..."
cd "$APP_DIR"
tar -czf "$OUTPUT_DIR/${APP_NAME}_${VERSION}_macOS_${TIMESTAMP}.tar.gz" "$APP_NAME.app" README.txt

# 计算文件大小
PACKAGE_SIZE=$(du -h "$OUTPUT_DIR/${APP_NAME}_${VERSION}_macOS_${TIMESTAMP}.tar.gz" | cut -f1)

echo ""
echo "✅ 打包完成!"
echo ""
echo "输出文件:"
echo "  📦 TAR.GZ: $OUTPUT_DIR/${APP_NAME}_${VERSION}_macOS_${TIMESTAMP}.tar.gz ($PACKAGE_SIZE)"
echo "  📱 APP: $APP_DIR/$APP_NAME.app"
echo ""
echo "SHA256 校验:"
sha256sum "$OUTPUT_DIR/${APP_NAME}_${VERSION}_macOS_${TIMESTAMP}.tar.gz" || shasum -a 256 "$OUTPUT_DIR/${APP_NAME}_${VERSION}_macOS_${TIMESTAMP}.tar.gz"
echo ""
echo "下一步:"
echo "  1. 测试安装：将 .app 拖到 /Applications"
echo "  2. 运行安装脚本：sudo bash installer/macos/install.sh"
echo "  3. 创建 GitHub Release 并上传"
echo ""
