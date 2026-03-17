"""
Agent Helper Controller Client
主控端客户端 - 用于控制其他 Agent Helper 设备
"""

import asyncio
import json
import os
import signal
import sys
import time
from pathlib import Path
from typing import Optional

import websockets
from websockets.exceptions import ConnectionClosed


# ============== 配置 ==============

DEFAULT_SERVER_URL = "ws://localhost:8080/ws/controller"


# ============== 日志工具 ==============

class Logger:
    def __init__(self):
        pass

    def _write(self, level: str, msg: str):
        timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
        line = f"[{timestamp}] [{level}] {msg}"
        print(line)

    def info(self, msg: str):
        self._write("INFO", msg)

    def error(self, msg: str):
        self._write("ERROR", msg)

    def warning(self, msg: str):
        self._write("WARN", msg)

    def success(self, msg: str):
        self._write("SUCCESS", msg)


logger = Logger()


# ============== 主控端客户端 ==============

class ControllerClient:
    def __init__(self, server_url: str, device_id: str, pairing_key: str):
        self.server_url = server_url
        self.device_id = device_id
        self.pairing_key = pairing_key
        self.ws: Optional[websockets.WebSocketClientProtocol] = None
        self.running = True
        self.controller_id: Optional[str] = None
        self.connected = False

    async def connect(self):
        """建立 WebSocket 连接并配对"""
        logger.info(f"连接到服务端: {self.server_url}")

        try:
            self.ws = await websockets.connect(
                self.server_url,
                ping_interval=None,
                close_timeout=10
            )

            # 发送配对消息
            await self.ws.send(json.dumps({
                "type": "pair",
                "device_id": self.device_id,
                "pairing_key": self.pairing_key,
                "controller_id": f"controller-{os.urandom(4).hex()}"
            }))

            # 等待配对响应
            response = await asyncio.wait_for(self.ws.recv(), timeout=10)
            resp_data = json.loads(response)

            if resp_data.get("type") == "paired":
                self.controller_id = resp_data.get("controller_id")
                self.connected = True
                logger.success(f"✅ 配对成功！")
                logger.info(f"   主控端ID: {self.controller_id}")
                logger.info(f"   被控设备: {resp_data.get('device_id')}")
                logger.info("")
                logger.info("可用命令:")
                logger.info("  shell <cmd>     - 执行 shell 命令")
                logger.info("  info            - 获取系统信息")
                logger.info("  files <path>    - 列出目录")
                logger.info("  read <path>     - 读取文件")
                logger.info("  write <path>    - 写入文件 (交互式)")
                logger.info("  processes       - 列出进程")
                logger.info("  quit            - 退出")
                logger.info("")
                return True
            else:
                logger.error(f"❌ 配对失败: {resp_data.get('msg', 'Unknown error')}")
                return False

        except Exception as e:
            logger.error(f"连接失败: {e}")
            return False

    async def send_command(self, action: str, params: dict) -> dict:
        """发送指令到被控设备"""
        req_id = f"req-{os.urandom(4).hex()}"

        await self.ws.send(json.dumps({
            "type": "exec",
            "req_id": req_id,
            "action": action,
            "params": params
        }))

        # 等待结果
        while True:
            msg = await self.ws.recv()
            data = json.loads(msg)

            if data.get("type") == "pong":
                continue

            if data.get("req_id") == req_id:
                return data

    async def handle_shell(self, cmd: str):
        """处理 shell 命令"""
        if not cmd:
            logger.warning("命令不能为空")
            return

        print(f"$ {cmd}")
        result = await self.send_command("shell.exec", {"cmd": cmd, "timeout": 60})

        if result.get("type") == "result":
            data = result.get("data", {})
            if data.get("success"):
                if data.get("stdout"):
                    print(data["stdout"], end="")
                if data.get("stderr"):
                    print(data["stderr"], end="", file=sys.stderr)
                print(f"\n[退出码: {data.get('returncode', 0)}]")
            else:
                print(f"错误: {data.get('error', 'Unknown error')}")
        else:
            print(f"错误: {result.get('msg', 'Unknown error')}")

    async def handle_info(self):
        """获取系统信息"""
        result = await self.send_command("system.info", {})

        if result.get("type") == "result":
            data = result.get("data", {})
            if data.get("success"):
                info = data.get("data", {})
                print(f"\n{'='*40}")
                print(f"主机名: {info.get('hostname', 'N/A')}")
                print(f"系统: {info.get('system', 'N/A')} {info.get('release', '')}")
                print(f"架构: {info.get('machine', 'N/A')}")
                print(f"处理器: {info.get('processor', 'N/A')}")
                print(f"Python: {info.get('python_version', 'N/A')}")
                print(f"运行时间: {info.get('uptime', 'N/A')}")
                if info.get('memory'):
                    print(f"内存: {info['memory'].get('available', 'N/A')} / {info['memory'].get('total', 'N/A')}")
                print(f"{'='*40}\n")
            else:
                print(f"错误: {data.get('error', 'Unknown error')}")
        else:
            print(f"错误: {result.get('msg', 'Unknown error')}")

    async def handle_files(self, path: str = "/"):
        """列出目录"""
        result = await self.send_command("file.list", {"path": path})

        if result.get("type") == "result":
            data = result.get("data", {})
            if data.get("success"):
                entries = data.get("data", {}).get("entries", [])
                print(f"\n目录: {path}")
                print(f"{'='*60}")
                for entry in entries:
                    name = entry.get("name", "")
                    type_str = "[DIR]" if entry.get("type") == "directory" else "[FILE]"
                    size = entry.get("size", 0)
                    mode = entry.get("mode", "---")
                    print(f"{type_str} {mode:>6} {size:>10} {name}")
                print(f"{'='*60}\n")
            else:
                print(f"错误: {data.get('error', 'Unknown error')}")
        else:
            print(f"错误: {result.get('msg', 'Unknown error')}")

    async def handle_read(self, path: str):
        """读取文件"""
        if not path:
            logger.warning("路径不能为空")
            return

        result = await self.send_command("file.read", {"path": path, "limit": 10000})

        if result.get("type") == "result":
            data = result.get("data", {})
            if data.get("success"):
                file_data = data.get("data", {})
                print(f"\n文件: {file_data.get('path', path)}")
                print(f"大小: {file_data.get('size', 0)} bytes")
                print(f"编码: {file_data.get('encoding', 'unknown')}")
                print(f"{'='*60}")
                content = file_data.get("content", "")
                if len(content) > 5000:
                    print(content[:5000])
                    print(f"\n... (已截断，共 {len(content)} 字符)")
                else:
                    print(content)
                print(f"{'='*60}\n")
            else:
                print(f"错误: {data.get('error', 'Unknown error')}")
        else:
            print(f"错误: {result.get('msg', 'Unknown error')}")

    async def handle_write(self, path: str):
        """写入文件"""
        if not path:
            logger.warning("路径不能为空")
            return

        print("请输入文件内容 (输入空行结束):")
        lines = []
        while True:
            try:
                line = input()
                if line == "":
                    break
                lines.append(line)
            except EOFError:
                break

        content = "\n".join(lines)
        result = await self.send_command("file.write", {"path": path, "content": content})

        if result.get("type") == "result":
            data = result.get("data", {})
            if data.get("success"):
                print(f"✅ 文件已写入: {path}")
            else:
                print(f"错误: {data.get('error', 'Unknown error')}")
        else:
            print(f"错误: {result.get('msg', 'Unknown error')}")

    async def handle_processes(self):
        """列出进程"""
        result = await self.send_command("process.list", {})

        if result.get("type") == "result":
            data = result.get("data", {})
            if data.get("success"):
                processes = data.get("data", {}).get("processes", [])
                print(f"\n{'PID':>8} {'CPU%':>6} {'MEM%':>6} {'COMMAND':<30}")
                print(f"{'='*60}")
                for proc in processes[:20]:  # 只显示前20个
                    pid = proc.get("pid", 0)
                    cpu = proc.get("cpu", 0)
                    mem = proc.get("mem", 0)
                    cmd = proc.get("command", "")[:30]
                    print(f"{pid:>8} {cpu:>6.1f} {mem:>6.1f} {cmd:<30}")
                if len(processes) > 20:
                    print(f"... (共 {len(processes)} 个进程)")
                print(f"{'='*60}\n")
            else:
                print(f"错误: {data.get('error', 'Unknown error')}")
        else:
            print(f"错误: {result.get('msg', 'Unknown error')}")

    async def interactive_shell(self):
        """交互式命令行"""
        while self.running and self.connected:
            try:
                # 使用 asyncio 来读取输入，避免阻塞
                loop = asyncio.get_event_loop()
                user_input = await loop.run_in_executor(None, lambda: input(f"[{self.device_id}]> "))

                parts = user_input.strip().split(None, 1)
                if not parts:
                    continue

                cmd = parts[0].lower()
                arg = parts[1] if len(parts) > 1 else ""

                if cmd == "quit" or cmd == "exit":
                    break
                elif cmd == "shell":
                    await self.handle_shell(arg)
                elif cmd == "info":
                    await self.handle_info()
                elif cmd == "files":
                    await self.handle_files(arg if arg else "/")
                elif cmd == "read":
                    await self.handle_read(arg)
                elif cmd == "write":
                    await self.handle_write(arg)
                elif cmd == "processes" or cmd == "ps":
                    await self.handle_processes()
                elif cmd == "help":
                    print("可用命令:")
                    print("  shell <cmd>     - 执行 shell 命令")
                    print("  info            - 获取系统信息")
                    print("  files [path]    - 列出目录 (默认 /)")
                    print("  read <path>     - 读取文件")
                    print("  write <path>    - 写入文件")
                    print("  processes       - 列出进程")
                    print("  quit            - 退出")
                else:
                    # 默认作为 shell 命令执行
                    await self.handle_shell(user_input)

            except asyncio.CancelledError:
                break
            except ConnectionClosed:
                logger.error("连接已关闭")
                break
            except Exception as e:
                logger.error(f"错误: {e}")

    async def run(self):
        """主循环"""
        if await self.connect():
            try:
                await self.interactive_shell()
            except Exception as e:
                logger.error(f"运行时错误: {e}")
            finally:
                if self.ws:
                    await self.ws.close()

    def stop(self):
        """停止客户端"""
        self.running = False


def show_usage():
    """显示使用方法"""
    print("Agent Helper Controller Client")
    print("主控端客户端 - 用于控制其他 Agent Helper 设备")
    print("")
    print("使用方法:")
    print(f"  python {sys.argv[0]} <device_id> <pairing_key> [server_url]")
    print("")
    print("参数:")
    print("  device_id      - 被控设备的设备ID")
    print("  pairing_key    - 配对密钥 (8位字母数字)")
    print("  server_url     - 服务端地址 (可选，默认 ws://localhost:8080/ws/controller)")
    print("")
    print("示例:")
    print(f"  python {sys.argv[0]} my-server-01 ABCD1234")
    print(f"  python {sys.argv[0]} my-server-01 ABCD1234 ws://192.168.1.100:8080/ws/controller")


def main():
    """主函数"""
    if len(sys.argv) < 3:
        show_usage()
        sys.exit(1)

    device_id = sys.argv[1]
    pairing_key = sys.argv[2]
    server_url = sys.argv[3] if len(sys.argv) > 3 else DEFAULT_SERVER_URL

    logger.info(f"Agent Helper Controller Client")
    logger.info(f"目标设备: {device_id}")
    logger.info(f"服务端: {server_url}")
    logger.info("")

    client = ControllerClient(server_url, device_id, pairing_key)

    # 信号处理
    def signal_handler(signum, frame):
        logger.info(f"收到信号 {signum}，正在退出...")
        client.stop()

    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)

    # 运行
    try:
        asyncio.run(client.run())
    except KeyboardInterrupt:
        logger.info("用户中断")
    except Exception as e:
        logger.error(f"运行时错误: {e}")

    logger.info("主控端已退出")


if __name__ == "__main__":
    main()
