#!/usr/bin/env python3
"""
AgentLinker 配对工具
支持二维码生成/扫描、局域网发现
"""

import argparse
import asyncio
import json
import sys
import time
from pathlib import Path

# 添加模块路径
sys.path.insert(0, str(Path(__file__).parent.parent))

from client.utils.discovery import LANDiscovery, QRCodePairing, DiscoveredDevice


class PairingCLI:
    """配对命令行工具"""
    
    def __init__(self):
        self.qr = QRCodePairing()
        self.discovery = None
    
    def generate_qr(self, device_id: str, pairing_key: str, 
                   device_name: str = None, server_url: str = None,
                   output: str = None):
        """生成配对二维码"""
        print("🔐 生成配对二维码...\n")
        
        qr_content = self.qr.generate_pairing_qr(
            device_id=device_id,
            pairing_key=pairing_key,
            device_name=device_name,
            server_url=server_url
        )
        
        if output:
            # 保存为图片
            self.qr.generate_qr_image(qr_content, output)
            print(f"✅ 二维码已保存：{output}")
        else:
            # 终端显示
            self.qr.print_qr_terminal(qr_content)
        
        # 打印配对信息
        print("\n📋 配对信息:")
        print(f"   设备 ID: {device_id}")
        print(f"   设备名：{device_name or device_id}")
        print(f"   配对密钥：{pairing_key}")
        if server_url:
            print(f"   服务端：{server_url}")
        print()
    
    def scan_qr(self, qr_content: str):
        """解析二维码内容"""
        print("📷 解析二维码...\n")
        
        result = self.qr.parse_pairing_qr(qr_content)
        
        if result:
            print("✅ 配对信息解析成功!")
            print("\n📋 设备信息:")
            print(f"   设备 ID: {result['device_id']}")
            print(f"   设备名：{result.get('device_name', 'N/A')}")
            print(f"   配对密钥：{result['pairing_key']}")
            if result.get('server_url'):
                print(f"   服务端：{result['server_url']}")
            
            return result
        else:
            print("❌ 无法解析二维码")
            return None
    
    def discover_devices(self, timeout: int = 10, interactive: bool = False):
        """发现局域网设备"""
        print("📡 正在搜索局域网设备...\n")
        
        discovered = []
        
        def on_found(device: DiscoveredDevice):
            discovered.append(device)
            print(f"\n📱 发现设备:")
            print(f"   设备名：{device.device_name}")
            print(f"   设备 ID: {device.device_id}")
            print(f"   IP 地址：{device.ip_address}:{device.port}")
            print(f"   平台：{device.platform}")
            if device.pairing_key:
                print(f"   配对密钥：{device.pairing_key}")
            print()
        
        self.discovery = LANDiscovery()
        self.discovery.on_device_found = on_found
        
        # 启动监听
        self.discovery.start_listener(timeout=float(timeout))
        
        try:
            time.sleep(timeout)
        except KeyboardInterrupt:
            pass
        finally:
            self.discovery.stop()
        
        # 显示结果
        print("\n" + "=" * 50)
        print(f"搜索完成，共发现 {len(discovered)} 个设备")
        print("=" * 50)
        
        if discovered and interactive:
            # 交互式选择
            print("\n选择设备进行配对:")
            for i, dev in enumerate(discovered, 1):
                print(f"  {i}. {dev.device_name} ({dev.device_id})")
            
            try:
                choice = input("\n输入设备编号 (或 q 退出): ")
                if choice.lower() != 'q' and choice.isdigit():
                    idx = int(choice) - 1
                    if 0 <= idx < len(discovered):
                        selected = discovered[idx]
                        print(f"\n已选择：{selected.device_name}")
                        
                        if selected.pairing_key:
                            print(f"配对密钥：{selected.pairing_key}")
                            print(f"\n使用以下命令配对:")
                            print(f"  agentlinker pair {selected.device_id} {selected.pairing_key}")
                        else:
                            print("⚠️ 此设备未广播配对密钥")
                            print("请在设备日志中查看配对密钥")
                        
                        return selected
            except (EOFError, ValueError):
                pass
        
        return None
    
    def broadcast_self(self, device_id: str, device_name: str = None, 
                      port: int = 8080, pairing_key: str = None):
        """广播自己的设备信息"""
        print("📡 开始广播设备信息...")
        print(f"   设备 ID: {device_id}")
        print(f"   设备名：{device_name or device_id}")
        print(f"   端口：{port}")
        if pairing_key:
            print(f"   配对密钥：{pairing_key}")
        print("\n按 Ctrl+C 停止广播\n")
        
        extra = {}
        if pairing_key:
            extra["pairing_key"] = pairing_key
        
        self.discovery = LANDiscovery(
            device_id=device_id,
            device_name=device_name or device_id
        )
        
        self.discovery.start_broadcast(port=port, extra_info=extra)
        
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            print("\n\n停止广播")
            self.discovery.stop()


def main():
    parser = argparse.ArgumentParser(
        description='AgentLinker 配对工具',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  # 生成二维码
  %(prog)s qr-gen --device-id my-device --pairing-key XK9M2P7Q
  
  # 解析二维码
  %(prog)s qr-scan '{"type":"agentlinker_pair","device_id":"..."}'
  
  # 发现设备
  %(prog)s discover --timeout 10
  
  # 广播自己
  %(prog)s broadcast --device-id my-device --pairing-key XK9M2P7Q
        """
    )
    
    subparsers = parser.add_subparsers(dest='command', help='命令')
    
    # 生成二维码
    qr_gen = subparsers.add_parser('qr-gen', help='生成配对二维码')
    qr_gen.add_argument('--device-id', required=True, help='设备 ID')
    qr_gen.add_argument('--pairing-key', required=True, help='配对密钥')
    qr_gen.add_argument('--device-name', help='设备名称')
    qr_gen.add_argument('--server-url', help='服务端 URL')
    qr_gen.add_argument('-o', '--output', help='输出图片路径')
    
    # 解析二维码
    qr_scan = subparsers.add_parser('qr-scan', help='解析二维码内容')
    qr_scan.add_argument('qr_content', help='二维码内容 (JSON 字符串)')
    
    # 发现设备
    discover = subparsers.add_parser('discover', help='发现局域网设备')
    discover.add_argument('--timeout', type=int, default=10, help='搜索超时 (秒)')
    discover.add_argument('-i', '--interactive', action='store_true', help='交互式选择')
    
    # 广播自己
    broadcast = subparsers.add_parser('broadcast', help='广播设备信息')
    broadcast.add_argument('--device-id', required=True, help='设备 ID')
    broadcast.add_argument('--device-name', help='设备名称')
    broadcast.add_argument('--port', type=int, default=8080, help='服务端口')
    broadcast.add_argument('--pairing-key', help='配对密钥')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        sys.exit(1)
    
    cli = PairingCLI()
    
    if args.command == 'qr-gen':
        cli.generate_qr(
            device_id=args.device_id,
            pairing_key=args.pairing_key,
            device_name=args.device_name,
            server_url=args.server_url,
            output=args.output
        )
    
    elif args.command == 'qr-scan':
        cli.scan_qr(args.qr_content)
    
    elif args.command == 'discover':
        cli.discover_devices(timeout=args.timeout, interactive=args.interactive)
    
    elif args.command == 'broadcast':
        cli.broadcast_self(
            device_id=args.device_id,
            device_name=args.device_name,
            port=args.port,
            pairing_key=args.pairing_key
        )


if __name__ == "__main__":
    main()
