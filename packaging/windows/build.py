#!/usr/bin/env python3
"""
AgentLinker Windows 打包脚本
使用 PyInstaller 创建独立 exe 文件
"""

import os
import sys
import subprocess
from pathlib import Path

# 项目根目录
PROJECT_ROOT = Path(__file__).parent.parent
CLIENT_DIR = PROJECT_ROOT / "client"
ASSETS_DIR = PROJECT_ROOT / "assets"
DIST_DIR = PROJECT_ROOT / "dist" / "windows"

print("=" * 60)
print("AgentLinker Windows 打包工具")
print("=" * 60)

# 检查依赖
print("\n[1/5] 检查依赖...")
try:
    import PyInstaller
    print("✓ PyInstaller 已安装")
except ImportError:
    print("⚠  安装 PyInstaller...")
    subprocess.run([sys.executable, "-m", "pip", "install", "pyinstaller"], check=True)

try:
    import pystray
    print("✓ pystray 已安装")
except ImportError:
    print("⚠️  安装 pystray...")
    subprocess.run([sys.executable, "-m", "pip", "install", "pystray", "Pillow"], check=True)

try:
    import psutil
    print("✓ psutil 已安装")
except ImportError:
    print("⚠️  安装 psutil...")
    subprocess.run([sys.executable, "-m", "pip", "install", "psutil"], check=True)

# 创建输出目录
print("\n[2/5] 创建输出目录...")
DIST_DIR.mkdir(parents=True, exist_ok=True)
print(f"✓ 输出目录：{DIST_DIR}")

# PyInstaller 命令
print("\n[3/5] 运行 PyInstaller...")

pyinstaller_cmd = [
    sys.executable, "-m", "PyInstaller",
    str(CLIENT_DIR / "app.py"),
    "--name=AgentLinker",
    "--onefile",
    "--windowed",
    "--clean",
    "--noconfirm",
    f"--distpath={DIST_DIR}",
    f"--workpath={DIST_DIR / 'build'}",
    f"--specpath={DIST_DIR}",
]

# 添加图标（如果存在）
icon_file = ASSETS_DIR / "icon.ico"
if icon_file.exists():
    pyinstaller_cmd.append(f"--icon={icon_file}")
    print(f"✓ 使用图标：{icon_file}")
else:
    print("⚠️  未找到图标文件，跳过")

# 添加数据文件
pyinstaller_cmd.append(f"--add-data={CLIENT_DIR / 'core'}{os.pathsep}core")

# 隐藏导入
pyinstaller_cmd.extend([
    "--hidden-import=tkinter",
    "--hidden-import=tkinter.ttk",
    "--hidden-import=pystray",
    "--hidden-import=PIL",
])

print(f"命令：{' '.join(pyinstaller_cmd)}")

try:
    subprocess.run(pyinstaller_cmd, check=True)
    print("✓ PyInstaller 打包成功")
except subprocess.CalledProcessError as e:
    print(f"❌ PyInstaller 打包失败：{e}")
    sys.exit(1)

# 复制额外文件
print("\n[4/5] 复制额外文件...")

# 复制配置文件示例
config_example = DIST_DIR / "config.example.json"
config_example.write_text('''{
  "device_id": "my-windows-pc",
  "device_name": "我的 Windows 电脑",
  "token": "ah_device_token_change_in_production",
  "server_url": "ws://43.98.243.80:8080/ws/client",
  "auto_start": true,
  "copy_on_start": true
}
''')
print("✓ 配置文件示例已创建")

# 复制说明文件
readme_file = DIST_DIR / "README.txt"
readme_file.write_text(f'''AgentLinker for Windows
======================

安装说明:
1. 将 AgentLinker.exe 复制到你想安装的目录
2. 双击运行
3. 首次运行会自动创建配置文件

配置文件位置:
%USERPROFILE%\\.agentlinker\\config.json

使用说明:
1. 启动后会自动显示设备 ID 和配对密钥
2. 点击"复制密钥"按钮复制配对密钥
3. 在控制器端配对设备
4. 开始远程控制！

开机自启:
- 勾选"开机自动启动"选项
- 或手动添加快捷方式到启动文件夹

系统要求:
- Windows 10/11
- .NET Framework 4.5+ (通常已预装)
- 100MB 可用磁盘空间

默认服务器：ws://43.98.243.80:8080/ws/client

官网：https://github.com/Royean/AgentLinker
文档：https://github.com/Royean/AgentLinker#readme

许可证：MIT
''')
print("✓ 说明文件已创建")

# 创建快捷方式（可选）
print("\n[5/5] 创建快捷方式...")
try:
    import win32com.client
    shell = win32com.client.Dispatch("WScript.Shell")
    desktop = shell.SpecialFolders("Desktop")
    shortcut = shell.CreateShortcut(os.path.join(desktop, "AgentLinker.lnk"))
    shortcut.TargetPath = str(DIST_DIR / "AgentLinker.exe")
    shortcut.WorkingDirectory = str(DIST_DIR)
    shortcut.Description = "AgentLinker - AI Agent Remote Control"
    shortcut.save()
    print("✓ 桌面快捷方式已创建")
except:
    print("⚠️  无法创建桌面快捷方式（需要 pywin32）")

print("\n" + "=" * 60)
print("✅ 打包完成！")
print("=" * 60)
print(f"\n输出位置：{DIST_DIR}")
print(f"文件大小：{(DIST_DIR / 'AgentLinker.exe').stat().st_size / 1024 / 1024:.1f} MB")
print("\n下一步:")
print("1. 测试运行：双击 AgentLinker.exe")
print("2. 创建安装包（可选）：使用 Inno Setup")
print("3. 分发给用户")
print("")
