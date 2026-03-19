#!/usr/bin/env python3
"""
AgentLinker CLI 工具（优化版）
改进的用户体验和输出格式
"""

import argparse
import json
import subprocess
import sys
from pathlib import Path

CONFIG_FILE = "/etc/agentlinker/config.json"
LOG_FILE = "/var/log/agentlinker/agentlinker.log"


def get_config():
    """获取配置"""
    try:
        if Path(CONFIG_FILE).exists():
            with open(CONFIG_FILE) as f:
                return json.load(f)
    except:
        pass
    return {}


def get_status():
    """获取服务状态"""
    try:
        result = subprocess.run(
            ["launchctl", "list", "com.agentlinker.client"],
            capture_output=True,
            text=True,
            timeout=5
        )
        return "🟢 运行中" if result.returncode == 0 else "🔴 已停止"
    except:
        return "⚪ 未知"


def cmd_status(args):
    """显示状态"""
    config = get_config()
    status = get_status()
    
    print("📊 AgentLinker 状态")
    print("=" * 50)
    print(f"服务状态：{status}")
    print(f"设备 ID:  {config.get('device_id', '未配置')}")
    print(f"设备名：  {config.get('device_name', '未配置')}")
    print(f"服务端：  {config.get('server_url', '未配置')}")
    print("=" * 50)


def cmd_copy(args):
    """复制配对密钥"""
    # 导入自动复制脚本
    sys.path.insert(0, str(Path(__file__).parent))
    from auto_copy_key import get_pairing_key, copy_to_clipboard, show_notification
    
    print("🔑 获取配对密钥...")
    key = get_pairing_key()
    
    if key:
        if copy_to_clipboard(key):
            print(f"✅ 配对密钥已复制：{key}")
            show_notification("AgentLinker", f"配对密钥：{key}")
        else:
            print(f"配对密钥：{key}")
    else:
        print("❌ 未找到配对密钥")
        print("   请确保服务已启动并生成了配对密钥")


def cmd_log(args):
    """查看日志"""
    if args.tail:
        subprocess.run(["tail", "-f", LOG_FILE])
    else:
        subprocess.run(["cat", LOG_FILE])


def cmd_qr(args):
    """显示二维码"""
    config = get_config()
    key = None
    
    # 尝试从日志获取密钥
    sys.path.insert(0, str(Path(__file__).parent))
    try:
        from auto_copy_key import get_pairing_key
        key = get_pairing_key()
    except:
        pass
    
    print("📱 AgentLinker 配对信息")
    print("=" * 50)
    print(f"设备 ID:  {config.get('device_id', '未知')}")
    print(f"设备名：  {config.get('device_name', '未知')}")
    print(f"服务端：  {config.get('server_url', '未知')}")
    if key:
        print(f"配对密钥：{key}")
    print("=" * 50)
    print()
    print("使用主控端扫描二维码，或手动输入配对密钥")


def main():
    parser = argparse.ArgumentParser(description="AgentLinker CLI 工具")
    subparsers = parser.add_subparsers(dest="command", help="命令")
    
    # status 命令
    status_parser = subparsers.add_parser("status", help="显示状态")
    status_parser.set_defaults(func=cmd_status)
    
    # copy 命令
    copy_parser = subparsers.add_parser("copy", help="复制配对密钥")
    copy_parser.set_defaults(func=cmd_copy)
    
    # log 命令
    log_parser = subparsers.add_parser("log", help="查看日志")
    log_parser.add_argument("-f", "--tail", action="store_true", help="跟踪日志")
    log_parser.set_defaults(func=cmd_log)
    
    # qr 命令
    qr_parser = subparsers.add_parser("qr", help="显示配对信息")
    qr_parser.set_defaults(func=cmd_qr)
    
    args = parser.parse_args()
    
    if args.command:
        args.func(args)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
