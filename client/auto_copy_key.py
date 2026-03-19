#!/usr/bin/env python3
"""
AgentLinker 配对密钥自动复制工具
启动时自动复制配对密钥到剪贴板并显示通知
"""

import subprocess
import re
import time
from pathlib import Path

LOG_FILE = "/var/log/agentlinker/agentlinker.log"
CONFIG_FILE = "/etc/agentlinker/config.json"


def get_pairing_key():
    """从日志中获取最新的配对密钥"""
    try:
        if not Path(LOG_FILE).exists():
            return None
        
        # 读取日志最后 100 行
        result = subprocess.run(
            ["tail", "-100", LOG_FILE],
            capture_output=True,
            text=True,
            timeout=5
        )
        
        if result.stdout:
            # 查找配对密钥（8 位大写字母数字）
            matches = re.findall(r"配对密钥 [：:]\s*([A-Z0-9]{8})", result.stdout)
            if matches:
                return matches[-1]
    except Exception as e:
        print(f"获取配对密钥失败：{e}")
    
    return None


def get_device_id():
    """获取设备 ID"""
    try:
        import json
        if Path(CONFIG_FILE).exists():
            with open(CONFIG_FILE) as f:
                config = json.load(f)
                return config.get("device_id", "未知")
    except:
        pass
    return "未知"


def copy_to_clipboard(text):
    """复制文本到剪贴板 (macOS)"""
    try:
        process = subprocess.Popen(
            ["pbcopy"],
            stdin=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        process.communicate(text.encode("utf-8"))
        return process.returncode == 0
    except Exception as e:
        print(f"复制到剪贴板失败：{e}")
        return False


def show_notification(title, message):
    """显示 macOS 通知"""
    try:
        subprocess.run([
            "osascript",
            "-e",
            f'display notification "{message}" with title "{title}"'
        ], timeout=2)
    except:
        pass


def main():
    """主函数"""
    print("🔑 AgentLinker 配对密钥自动复制工具")
    print("-" * 50)
    
    # 等待服务启动
    print("等待服务启动...")
    time.sleep(3)
    
    # 获取配对密钥
    pairing_key = get_pairing_key()
    
    if pairing_key:
        device_id = get_device_id()
        
        print(f"设备 ID: {device_id}")
        print(f"配对密钥：{pairing_key}")
        print()
        
        # 复制到剪贴板
        if copy_to_clipboard(pairing_key):
            print("✅ 配对密钥已复制到剪贴板!")
            show_notification(
                "AgentLinker",
                f"配对密钥已复制：{pairing_key}\n设备：{device_id}"
            )
        else:
            print("❌ 复制失败")
    else:
        print("⚠️ 未找到配对密钥")
        print("   请检查服务是否已启动")
        print(f"   日志文件：{LOG_FILE}")
    
    print("-" * 50)


if __name__ == "__main__":
    main()
