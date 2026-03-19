"""
AgentLinker 局域网发现模块
使用 UDP 广播/组播实现设备自动发现
"""

import asyncio
import json
import socket
import threading
import time
from typing import Callable, Dict, List, Optional
from dataclasses import dataclass


@dataclass
class DiscoveredDevice:
    """发现的设备信息"""
    device_id: str
    device_name: str
    ip_address: str
    port: int
    platform: str
    last_seen: float
    pairing_key: Optional[str] = None


class LANDiscovery:
    """局域网设备发现"""
    
    # 默认配置
    BROADCAST_PORT = 53535
    BROADCAST_ADDRESS = "255.255.255.255"
    MULTICAST_GROUP = "224.0.0.251"
    DISCOVERY_INTERVAL = 2.0  # 广播间隔（秒）
    DISCOVERY_TIMEOUT = 10.0  # 设备超时（秒）
    
    def __init__(self, device_id: str = None, device_name: str = None):
        self.device_id = device_id
        self.device_name = device_name or device_id
        self.discovered_devices: Dict[str, DiscoveredDevice] = {}
        self.running = False
        self.socket = None
        self._lock = threading.Lock()
        
        # 回调函数
        self.on_device_found: Optional[Callable[[DiscoveredDevice], None]] = None
        self.on_device_lost: Optional[Callable[[str], None]] = None
    
    def start_broadcast(self, port: int = 8080, extra_info: dict = None):
        """启动广播（作为被控端）"""
        self.running = True
        
        def broadcast_loop():
            # 创建 UDP 广播 socket
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
            
            # 绑定到所有接口
            self.socket.bind(('', 0))  # 随机可用端口
            
            print(f"📡 开始广播设备信息：{self.device_id}")
            
            while self.running:
                try:
                    # 构建广播消息
                    message = {
                        "type": "announcement",
                        "device_id": self.device_id,
                        "device_name": self.device_name,
                        "port": port,
                        "platform": self._get_platform(),
                        "timestamp": time.time(),
                        **(extra_info or {})
                    }
                    
                    # 发送广播
                    data = json.dumps(message).encode('utf-8')
                    self.socket.sendto(data, (self.BROADCAST_ADDRESS, self.BROADCAST_PORT))
                    
                    # 也发送到组播地址（某些网络环境广播可能被阻止）
                    try:
                        self.socket.sendto(data, (self.MULTICAST_GROUP, self.BROADCAST_PORT))
                    except:
                        pass
                    
                    time.sleep(self.DISCOVERY_INTERVAL)
                    
                except Exception as e:
                    print(f"广播错误：{e}")
                    time.sleep(5)
        
        thread = threading.Thread(target=broadcast_loop, daemon=True)
        thread.start()
        return thread
    
    def start_listener(self, timeout: float = None):
        """启动监听（作为主控端）"""
        self.running = True
        
        def listen_loop():
            # 创建 UDP 监听 socket
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            
            # 允许端口复用
            self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            
            # 绑定到广播端口
            self.socket.bind(('', self.BROADCAST_PORT))
            
            # 加入组播组
            self.socket.setsockopt(
                socket.IPPROTO_IP,
                socket.IP_ADD_MEMBERSHIP,
                socket.inet_aton(self.MULTICAST_GROUP) + socket.inet_aton("0.0.0.0")
            )
            
            # 设置超时
            self.socket.settimeout(1.0)
            
            print(f"👂 开始监听局域网设备...")
            
            start_time = time.time()
            
            while self.running:
                if timeout and (time.time() - start_time) > timeout:
                    break
                
                try:
                    data, addr = self.socket.recvfrom(4096)
                    message = json.loads(data.decode('utf-8'))
                    
                    if message.get("type") == "announcement":
                        device_id = message.get("device_id")
                        if not device_id:
                            continue
                        
                        device = DiscoveredDevice(
                            device_id=device_id,
                            device_name=message.get("device_name", device_id),
                            ip_address=addr[0],
                            port=message.get("port", 8080),
                            platform=message.get("platform", "Unknown"),
                            last_seen=time.time(),
                            pairing_key=message.get("pairing_key")
                        )
                        
                        is_new = device_id not in self.discovered_devices
                        
                        with self._lock:
                            self.discovered_devices[device_id] = device
                        
                        if is_new and self.on_device_found:
                            self.on_device_found(device)
                        
                        print(f"📱 发现设备：{device.device_name} @ {addr[0]}:{device.port}")
                    
                except socket.timeout:
                    # 检查超时设备
                    self._cleanup_stale_devices()
                except Exception as e:
                    print(f"监听错误：{e}")
                    time.sleep(1)
        
        thread = threading.Thread(target=listen_loop, daemon=True)
        thread.start()
        return thread
    
    def _cleanup_stale_devices(self):
        """清理超时设备"""
        now = time.time()
        stale = []
        
        with self._lock:
            for device_id, device in self.discovered_devices.items():
                if (now - device.last_seen) > self.DISCOVERY_TIMEOUT:
                    stale.append(device_id)
            
            for device_id in stale:
                del self.discovered_devices[device_id]
                if self.on_device_lost:
                    self.on_device_lost(device_id)
                print(f"📴 设备离线：{device_id}")
    
    def stop(self):
        """停止发现服务"""
        self.running = False
        if self.socket:
            try:
                self.socket.close()
            except:
                pass
    
    def get_devices(self) -> List[DiscoveredDevice]:
        """获取已发现的设备列表"""
        with self._lock:
            return list(self.discovered_devices.values())
    
    def _get_platform(self) -> str:
        """获取平台信息"""
        import platform
        return f"{platform.system()} {platform.release()}"


class QRCodePairing:
    """二维码配对"""
    
    def __init__(self):
        self.qr_data = None
    
    def generate_pairing_qr(self, device_id: str, pairing_key: str, 
                           server_url: str = None, device_name: str = None) -> str:
        """
        生成配对二维码数据
        
        返回二维码内容（URL 格式），可用于生成二维码图片
        """
        import json
        import base64
        
        pairing_data = {
            "v": 1,  # 版本
            "type": "agentlinker_pair",
            "device_id": device_id,
            "pairing_key": pairing_key,
            "device_name": device_name or device_id,
        }
        
        if server_url:
            pairing_data["server_url"] = server_url
        
        # 编码为 JSON
        json_str = json.dumps(pairing_data, ensure_ascii=False)
        
        # 压缩并 base64 编码（可选，数据太长时）
        # import zlib
        # compressed = zlib.compress(json_str.encode('utf-8'))
        # encoded = base64.b64encode(compressed).decode('ascii')
        
        # 返回 JSON 格式（直接可用）
        self.qr_data = pairing_data
        return json_str
    
    def parse_pairing_qr(self, qr_content: str) -> Optional[dict]:
        """
        解析二维码内容
        
        返回配对信息字典
        """
        try:
            import json
            
            # 尝试直接解析 JSON
            data = json.loads(qr_content)
            
            if data.get("type") != "agentlinker_pair":
                print("⚠️ 不是 AgentLinker 配对二维码")
                return None
            
            if data.get("v") != 1:
                print(f"⚠️ 不支持的二维码版本：{data.get('v')}")
                return None
            
            return {
                "device_id": data.get("device_id"),
                "pairing_key": data.get("pairing_key"),
                "device_name": data.get("device_name"),
                "server_url": data.get("server_url")
            }
        
        except json.JSONDecodeError:
            # 尝试 base64 解码（压缩格式）
            try:
                import base64
                import zlib
                
                decoded = base64.b64decode(qr_content)
                decompressed = zlib.decompress(decoded)
                data = json.loads(decompressed)
                
                return {
                    "device_id": data.get("device_id"),
                    "pairing_key": data.get("pairing_key"),
                    "device_name": data.get("device_name"),
                    "server_url": data.get("server_url")
                }
            
            except Exception:
                print("⚠️ 无法解析二维码内容")
                return None
    
    def generate_qr_image(self, qr_content: str, output_path: str = None):
        """
        生成二维码图片
        
        需要安装 qrcode 库：pip install qrcode[pil]
        """
        try:
            import qrcode
            
            qr = qrcode.QRCode(
                version=1,
                error_correction=qrcode.constants.ERROR_CORRECT_L,
                box_size=10,
                border=4,
            )
            qr.add_data(qr_content)
            qr.make(fit=True)
            
            img = qr.make_image(fill_color="black", back_color="white")
            
            if output_path:
                img.save(output_path)
                print(f"✅ 二维码已保存到：{output_path}")
            
            return img
        
        except ImportError:
            print("⚠️ 需要安装 qrcode 库：pip install qrcode[pil]")
            return None
    
    def print_qr_terminal(self, qr_content: str):
        """
        在终端打印二维码（ASCII 艺术）
        
        使用 qrterminal 库或简单的字符表示
        """
        try:
            import qrterminal
            
            print("\n" + "=" * 50)
            print("📱 扫描此二维码进行配对")
            print("=" * 50 + "\n")
            
            qrterminal.generate(
                qr_content,
                level=qrterminal.L,
                write=lambda x: print(x, end='')
            )
            
            print("\n" + "=" * 50 + "\n")
        
        except ImportError:
            # 简单的文本表示
            print("\n" + "=" * 50)
            print("📱 配对二维码内容:")
            print("=" * 50)
            print(qr_content)
            print("=" * 50)
            print("\n提示：安装 qrterminal 可显示图形二维码")
            print("      pip install qrterminal\n")


async def demo_discovery():
    """演示局域网发现功能"""
    print("=" * 50)
    print("AgentLinker 局域网发现演示")
    print("=" * 50)
    
    # 模拟设备广播
    device = LANDiscovery(
        device_id="demo-device-001",
        device_name="演示设备"
    )
    
    def on_found(d: DiscoveredDevice):
        print(f"\n🎉 新设备上线：{d.device_name}")
        print(f"   IP: {d.ip_address}:{d.port}")
        print(f"   平台：{d.platform}")
    
    device.on_device_found = on_found
    
    # 启动广播
    device.start_broadcast(port=8080, extra_info={"pairing_key": "XK9M2P7Q"})
    
    print("\n设备正在广播中...")
    print("按 Ctrl+C 停止\n")
    
    try:
        await asyncio.sleep(30)
    except KeyboardInterrupt:
        pass
    finally:
        device.stop()
        print("\n发现服务已停止")


if __name__ == "__main__":
    asyncio.run(demo_discovery())
