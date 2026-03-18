#!/bin/bash
# AgentLinker macOS DMG 打包脚本
# 创建独立应用程序包

set -e

echo "============================================"
echo "   AgentLinker macOS DMG 打包工具"
echo "============================================"

# 配置
APP_NAME="AgentLinker"
APP_DIR="/tmp/AgentLinker.app"
DMG_DIR="/tmp/agentlinker_dmg"
DMG_FILE="/tmp/AgentLinker.dmg"
VERSION="2.0.0"

# 清理
rm -rf "$APP_DIR" "$DMG_DIR" "$DMG_FILE"

echo ""
echo "[1/6] 创建应用程序包结构..."

# 创建 .app 包结构
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

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
    <key>CFBundleIdentifier</key>
    <string>com.agentlinker.client</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>CFBundleExecutable</key>
    <string>agentlinker</string>
    <key>CFBundleIconFile</key>
    <string>icon.icns</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>LSUIElement</key>
    <false/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo "[2/6] 下载 Python 运行时..."

# 下载嵌入式 Python（或使用系统 Python）
PYTHON_URL="https://www.python.org/ftp/python/3.12.0/python-3.12.0-macos11.pkg"
PYTHON_PKG="/tmp/python.pkg"

if [ ! -f "$PYTHON_PKG" ]; then
    echo "下载 Python 运行时..."
    curl -L "$PYTHON_URL" -o "$PYTHON_PKG" || {
        echo "⚠️  无法下载 Python，使用系统 Python"
        USE_SYSTEM_PYTHON=true
    }
fi

echo "[3/6] 复制客户端代码..."

# 复制客户端代码
cp -r /tmp/AgentLinker/client "$APP_DIR/Contents/Resources/"
cp -r /tmp/AgentLinker/server "$APP_DIR/Contents/Resources/"

# 创建启动脚本
cat > "$APP_DIR/Contents/MacOS/agentlinker" << 'STARTSCRIPT'
#!/bin/bash

# 获取应用资源目录
RESOURCES_DIR="$(dirname "$0")/../Resources"

# 设置 Python 路径
if [ -d "$RESOURCES_DIR/Python3.framework" ]; then
    # 使用打包的 Python
    PYTHON="$RESOURCES_DIR/Python3.framework/Versions/Current/bin/python3"
else
    # 使用系统 Python
    PYTHON="/usr/bin/python3"
fi

# 检查 Python
if [ ! -x "$PYTHON" ]; then
    osascript -e "display dialog \"错误：未找到 Python 3。\n\n请安装 Python 3 或从 python.org 下载。\" buttons {\"OK\"} default button 1 with icon stop"
    exit 1
fi

# 创建配置目录
mkdir -p "$HOME/.agentlinker"

# 运行应用
cd "$RESOURCES_DIR/client"
exec "$PYTHON" app.py
STARTSCRIPT

chmod +x "$APP_DIR/Contents/MacOS/agentlinker"

echo "[4/6] 创建图标..."

# 创建简单图标（红色圆角矩形）
cat > /tmp/create_icon.py << 'ICONSCRIPT'
import tkinter as tk
from PIL import Image, ImageDraw

# 创建 512x512 图像
img = Image.new('RGB', (512, 512), color='white')
draw = ImageDraw.Draw(img)

# 绘制圆角矩形背景
draw.rounded_rectangle([(10, 10), (502, 502)], radius=100, fill='#FF6B6B')

# 绘制机器人图标
draw.ellipse([(156, 156), (356, 356)], fill='white')
draw.ellipse([(206, 206), (306, 306)], fill='#4ECDC4')

# 保存
img.save('/tmp/icon.png')
img.save('/tmp/icon.icns', format='ICNS')
ICONSCRIPT

python3 /tmp/create_icon.py 2>/dev/null || {
    echo "⚠️  无法创建图标，使用默认图标"
    # 创建占位文件
    touch "$APP_DIR/Contents/Resources/icon.icns"
}

if [ -f /tmp/icon.icns ]; then
    cp /tmp/icon.icns "$APP_DIR/Contents/Resources/"
fi

echo "[5/6] 创建 DMG..."

# 创建 DMG 目录结构
mkdir -p "$DMG_DIR"
cp -r "$APP_DIR" "$DMG_DIR/"

# 创建 Applications 链接
ln -s /Applications "$DMG_DIR/Applications"

# 创建 README
cat > "$DMG_DIR/README.txt" << EOF
AgentLinker $VERSION

安装说明:
1. 将 AgentLinker.app 拖拽到 Applications 文件夹
2. 打开 AgentLinker.app
3. 应用会自动启动并显示设备 ID 和配对密钥

使用说明:
- 启动后会自动连接到默认服务器
- 配对密钥会显示在主界面
- 点击"复制配对密钥"按钮复制密钥
- 在"文件"菜单可以修改设备 ID 和服务器地址

默认服务器：ws://43.98.243.80:8080/ws/client

官网：https://github.com/Royean/AgentLinker
EOF

# 创建 DMG
hdiutil create -volname "AgentLinker" -srcfolder "$DMG_DIR" -ov -format UDZO "$DMG_FILE"

echo "[6/6] 清理..."

rm -rf "$APP_DIR" "$DMG_DIR"

echo ""
echo "============================================"
echo "   ✅ DMG 创建完成！"
echo "============================================"
echo ""
echo "DMG 文件：$DMG_FILE"
echo "文件大小：$(du -h "$DMG_FILE" | cut -f1)"
echo ""
echo "下一步:"
echo "1. 测试安装：双击 $DMG_FILE"
echo "2. 拖拽 AgentLinker.app 到 Applications"
echo "3. 打开应用测试"
echo ""
