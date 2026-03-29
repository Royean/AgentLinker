#!/usr/bin/env python3
"""
AgentLinker Client Daemon
运行在本地，连接到云端服务端
"""

import asyncio
import json
import os
import sys
import signal
import platform
import subprocess
from datetime import datetime

try:
    import websockets
except ImportError:
    print("Installing websockets...")
    subprocess.run([sys.executable, "-m", "pip", "install", "websockets", "-q"])
    import websockets

# 配置
SERVER_URL = os.getenv("AGENTLINKER_SERVER", "ws://43.98.243.80:8080/ws/client")
DEVICE_TOKEN = os.getenv("AGENTLINKER_TOKEN", "ah_device_token_change_in_production")
DEVICE_ID = os.getenv("AGENTLINKER_DEVICE_ID", f"mac_{platform.node().replace('-', '_')[:16]}")
DEVICE_NAME = os.getenv("AGENTLINKER_DEVICE_NAME", platform.node())

HEARTBEAT_INTERVAL = 30


class AgentLinkerClient:
    def __init__(self):
        self.ws = None
        self.running = True
        self.connected = False

    async def connect(self):
        """连接服务端"""
        print(f"[{datetime.now()}] 连接服务端: {SERVER_URL}")
        print(f"[{datetime.now()}] 设备 ID: {DEVICE_ID}")
        print(f"[{datetime.now()}] 设备名称: {DEVICE_NAME}")

        try:
            self.ws = await websockets.connect(SERVER_URL, ping_interval=None)

            # 发送注册消息
            register_msg = {
                "type": "register",
                "device_id": DEVICE_ID,
                "device_name": DEVICE_NAME,
                "platform": f"macOS {platform.mac_ver()[0]}",
                "token": DEVICE_TOKEN
            }
            await self.ws.send(json.dumps(register_msg))
            print(f"[{datetime.now()}] 发送注册消息")

            # 等待响应
            response = await self.ws.recv()
            data = json.loads(response)

            if data.get("type") == "registered":
                self.connected = True
                print(f"[{datetime.now()}] ✅ 注册成功!")

                # 获取配对密钥
                pairing_msg = await self.ws.recv()
                pairing_data = json.loads(pairing_msg)
                print(f"[{datetime.now()}] 🔑 配对密钥: {pairing_data.get('pairing_key')}")

                return True
            else:
                print(f"[{datetime.now()}] ❌ 注册失败: {data}")
                return False

        except Exception as e:
            print(f"[{datetime.now()}] ❌ 连接失败: {e}")
            return False

    async def heartbeat(self):
        """发送心跳"""
        while self.running and self.connected:
            try:
                await asyncio.sleep(HEARTBEAT_INTERVAL)
                if self.ws and self.connected:
                    ping_msg = {
                        "type": "ping",
                        "time": asyncio.get_event_loop().time(),
                        "device_id": DEVICE_ID
                    }
                    await self.ws.send(json.dumps(ping_msg))
                    print(f"[{datetime.now()}] 💓 心跳发送")
            except Exception as e:
                print(f"[{datetime.now()}] 心跳错误: {e}")
                self.connected = False

    async def receive_messages(self):
        """接收消息"""
        while self.running and self.connected:
            try:
                message = await self.ws.recv()
                data = json.loads(message)
                msg_type = data.get("type")

                if msg_type == "pong":
                    print(f"[{datetime.now()}] 💓 心跳响应")
                elif msg_type == "exec":
                    await self.handle_exec(data)
                elif msg_type == "ping":
                    await self.ws.send(json.dumps({"type": "pong", "time": asyncio.get_event_loop().time()}))
                else:
                    print(f"[{datetime.now()}] 收到消息: {msg_type}")

            except websockets.exceptions.ConnectionClosed:
                print(f"[{datetime.now()}] 连接关闭")
                self.connected = False
                break
            except Exception as e:
                print(f"[{datetime.now()}] 接收错误: {e}")

    async def handle_exec(self, data):
        """处理执行命令"""
        req_id = data.get("req_id", "")
        action = data.get("action", "")
        params = data.get("params", {})

        print(f"[{datetime.now()}] ⚙️ 执行命令: {action}")

        result = {
            "type": "result",
            "req_id": req_id
        }

        if action == "shell":
            command = params.get("command", "")
            try:
                proc = await asyncio.create_subprocess_shell(
                    command,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE
                )
                stdout, stderr = await proc.communicate()
                output = stdout.decode() + stderr.decode()
                result["data"] = {"success": True, "output": output}
                print(f"[{datetime.now()}] ✅ 命令执行成功")
            except Exception as e:
                result["data"] = {"success": False, "error": str(e)}
                print(f"[{datetime.now()}] ❌ 命令执行失败: {e}")
        else:
            result["data"] = {"success": False, "error": f"Unknown action: {action}"}

        await self.ws.send(json.dumps(result))

    async def run(self):
        """主循环"""
        while self.running:
            if await self.connect():
                # 启动心跳和接收任务
                heartbeat_task = asyncio.create_task(self.heartbeat())
                receive_task = asyncio.create_task(self.receive_messages())

                # 等待连接断开
                while self.running and self.connected:
                    await asyncio.sleep(1)

                # 取消任务
                heartbeat_task.cancel()
                receive_task.cancel()

            if self.running:
                print(f"[{datetime.now()}] 5秒后重连...")
                await asyncio.sleep(5)

    def stop(self):
        self.running = False
        self.connected = False


async def main():
    client = AgentLinkerClient()

    def signal_handler(sig, frame):
        print(f"\n[{datetime.now()}] 停止客户端...")
        client.stop()

    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    await client.run()


if __name__ == "__main__":
    asyncio.run(main())