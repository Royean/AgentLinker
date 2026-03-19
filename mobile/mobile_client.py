"""
AgentLinker Mobile Client
手机端 AgentLinker 客户端（iOS/Android）

使用方式:
- iOS: 使用 Pythonista 3 或 a-Shell
- Android: 使用 Pydroid 3 或 Termux
"""

import asyncio
import json
import time
import uuid
import platform
import socket
import os
from typing import Optional, Callable, Dict

try:
    import websockets
except ImportError:
    print("需要安装 websockets: pip install websockets")
    websockets = None


class MobileClient:
    """手机端 AgentLinker 客户端"""
    
    def __init__(self, server_url: str, device_id: str = None, device_name: str = None):
        self.server_url = server_url
        self.device_id = device_id or self._generate_device_id()
        self.device_name = device_name or self._get_device_name()
        self.ws: Optional[websockets.WebSocketClientProtocol] = None
        self.running = False
        self.token = "ah_device_token_change_in_production"
        
        # 设备信息
        self.device_info = self._get_device_info()
        
        # 回调函数
        self.on_connected: Optional[Callable] = None
        self.on_disconnected: Optional[Callable] = None
        self.on_command: Optional[Callable] = None
        
        # 配对信息
        self.pairing_key: Optional[str] = None
    
    def _generate_device_id(self) -> str:
        """生成设备 ID"""
        import uuid
        return f"{self._get_device_name().replace(' ', '-')}-{uuid.uuid4().hex[:8]}"
    
    def _get_device_name(self) -> str:
        """获取设备名称"""
        try:
            # iOS
            if platform.system() == "iOS":
                return "iPhone" if "iPhone" in platform.machine() else "iPad"
            # Android
            elif platform.system() == "Android":
                return f"Android-{platform.release()}"
            # 其他
            else:
                return f"Mobile-{platform.system()}"
        except:
            return "Unknown-Mobile"
    
    def _get_device_info(self) -> dict:
        """获取设备详细信息"""
        return {
            "device_id": self.device_id,
            "device_name": self.device_name,
            "platform": platform.system() or "Mobile",
            "platform_version": platform.release(),
            "machine": platform.machine(),
            "python_version": platform.python_version(),
            "hostname": socket.gethostname() if hasattr(socket, 'gethostname') else "mobile"
        }
    
    async def connect(self):
        """连接到服务端"""
        print(f"📱 AgentLinker Mobile 启动")
        print(f"   设备 ID: {self.device_id}")
        print(f"   设备名：{self.device_name}")
        print(f"   服务端：{self.server_url}")
        print()
        
        try:
            self.ws = await websockets.connect(
                self.server_url,
                ping_interval=30,
                ping_timeout=10
            )
            
            # 注册设备
            await self.ws.send(json.dumps({
                "type": "register",
                "device_id": self.device_id,
                "device_name": self.device_name,
                "token": self.token,
                "platform": self.device_info["platform"],
                "device_info": self.device_info
            }))
            
            # 等待注册响应
            response = await asyncio.wait_for(self.ws.recv(), timeout=30)
            data = json.loads(response)
            
            if data.get("type") == "registered":
                print(f"✅ 设备注册成功！")
                
                # 获取配对密钥
                if "pairing_key" in data:
                    self.pairing_key = data["pairing_key"]
                    print(f"🔑 配对密钥：{self.pairing_key}")
                    print(f"   使用主控端扫描此密钥进行配对")
                
                if self.on_connected:
                    self.on_connected(self.device_info)
                
                return True
            else:
                print(f"❌ 注册失败：{data}")
                return False
        
        except Exception as e:
            print(f"❌ 连接失败：{e}")
            return False
    
    async def run(self):
        """运行客户端主循环"""
        self.running = True
        
        print("🔄 开始监听服务端指令...")
        print("   按 Ctrl+C 停止")
        print()
        
        heartbeat_interval = 30
        
        while self.running:
            try:
                # 等待消息
                try:
                    message = await asyncio.wait_for(
                        self.ws.recv(),
                        timeout=heartbeat_interval
                    )
                    data = json.loads(message)
                    await self._handle_message(data)
                
                except asyncio.TimeoutError:
                    # 发送心跳
                    await self.ws.send(json.dumps({
                        "type": "pong",
                        "timestamp": time.time()
                    }))
            
            except websockets.exceptions.ConnectionClosed:
                print("❌ 连接已关闭")
                if self.on_disconnected:
                    self.on_disconnected()
                break
            
            except Exception as e:
                print(f"❌ 错误：{e}")
                await asyncio.sleep(5)
        
        # 清理
        if self.ws:
            await self.ws.close()
    
    async def _handle_message(self, data: dict):
        """处理服务端消息"""
        msg_type = data.get("type")
        
        if msg_type == "ping":
            await self.ws.send(json.dumps({
                "type": "pong",
                "timestamp": time.time()
            }))
        
        elif msg_type == "exec":
            # 执行命令
            req_id = data.get("req_id")
            action = data.get("action")
            params = data.get("params", {})
            
            print(f"📥 收到指令：{action}")
            
            # 执行并返回结果
            result = await self._execute_action(action, params)
            
            await self.ws.send(json.dumps({
                "type": "result",
                "req_id": req_id,
                "success": result.get("success", False),
                "data": result
            }))
            
            print(f"📤 指令执行完成：{result.get('success')}")
        
        elif msg_type == "file_incoming":
            # 接收文件
            file_id = data.get("file_id")
            filename = data.get("filename")
            
            print(f"📥 接收文件：{filename}")
            # 文件接收逻辑（简化版）
    
    async def _execute_action(self, action: str, params: dict) -> dict:
        """执行动作"""
        try:
            if action == "shell.exec":
                # 执行 Shell 命令
                cmd = params.get("cmd", "")
                return await self._execute_shell(cmd)
            
            elif action == "system.info":
                # 系统信息
                return {
                    "success": True,
                    "data": self.device_info
                }
            
            elif action == "file.read":
                # 读取文件
                path = params.get("path", "")
                return await self._read_file(path)
            
            elif action == "file.write":
                # 写入文件
                path = params.get("path", "")
                content = params.get("content", "")
                return await self._write_file(path, content)
            
            elif action == "app.list":
                # 列出应用（移动端特有）
                return await self._list_apps()
            
            elif action == "app.open":
                # 打开应用（移动端特有）
                app_url = params.get("url", "")
                return await self._open_app(app_url)
            
            else:
                return {
                    "success": False,
                    "error": f"未知动作：{action}"
                }
        
        except Exception as e:
            return {
                "success": False,
                "error": str(e)
            }
    
    async def _execute_shell(self, cmd: str) -> dict:
        """执行 Shell 命令"""
        try:
            proc = await asyncio.create_subprocess_shell(
                cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, stderr = await asyncio.wait_for(
                proc.communicate(),
                timeout=30
            )
            
            return {
                "success": proc.returncode == 0,
                "returncode": proc.returncode,
                "stdout": stdout.decode("utf-8", errors="ignore"),
                "stderr": stderr.decode("utf-8", errors="ignore")
            }
        
        except Exception as e:
            return {
                "success": False,
                "error": str(e)
            }
    
    async def _read_file(self, path: str) -> dict:
        """读取文件"""
        try:
            with open(path, "r", encoding="utf-8") as f:
                content = f.read()
            
            return {
                "success": True,
                "data": {
                    "path": path,
                    "content": content,
                    "size": len(content)
                }
            }
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    async def _write_file(self, path: str, content: str) -> dict:
        """写入文件"""
        try:
            # 确保目录存在
            os.makedirs(os.path.dirname(path), exist_ok=True)
            
            with open(path, "w", encoding="utf-8") as f:
                f.write(content)
            
            return {
                "success": True,
                "data": {
                    "path": path,
                    "size": len(content)
                }
            }
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    async def _list_apps(self) -> dict:
        """列出应用（简化版）"""
        # 移动端可以实现具体的应用列表
        return {
            "success": True,
            "data": {
                "apps": ["Safari", "Mail", "Photos", "Settings"]
            }
        }
    
    async def _open_app(self, url: str) -> dict:
        """打开应用（通过 URL Scheme）"""
        try:
            import webbrowser
            webbrowser.open(url)
            return {"success": True}
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    def stop(self):
        """停止客户端"""
        self.running = False
        print("🛑 正在停止...")


# 快速启动函数
async def quick_start(server_url: str = "ws://localhost:8080/ws/client"):
    """快速启动手机端客户端"""
    client = MobileClient(server_url)
    
    def on_connected(info):
        print(f"\n✅ 已连接！")
        print(f"   可以在主控端看到此设备")
    
    def on_disconnected():
        print(f"\n❌ 已断开连接")
    
    client.on_connected = on_connected
    client.on_disconnected = on_disconnected
    
    try:
        if await client.connect():
            await client.run()
    except KeyboardInterrupt:
        client.stop()


# 主函数
def main():
    import argparse
    
    parser = argparse.ArgumentParser(description="AgentLinker Mobile")
    parser.add_argument(
        "--server",
        default="ws://localhost:8080/ws/client",
        help="服务端 WebSocket 地址"
    )
    parser.add_argument(
        "--device-id",
        help="自定义设备 ID"
    )
    parser.add_argument(
        "--device-name",
        help="自定义设备名称"
    )
    
    args = parser.parse_args()
    
    # 运行
    asyncio.run(quick_start(args.server))


if __name__ == "__main__":
    main()
