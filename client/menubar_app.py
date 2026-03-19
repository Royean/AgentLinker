#!/usr/bin/env python3
"""
AgentLinker 菜单栏应用 (macOS)
显示在系统菜单栏，快速访问状态和控制
"""

import sys
import os

# 检查是否 macOS
if sys.platform != 'darwin':
    print("⚠️  菜单栏应用仅支持 macOS")
    sys.exit(1)

try:
    import rumps
    HAS_RUMPS = True
except ImportError:
    print("安装 rumps: pip install rumps")
    print("或使用基础版本：python3 app.py")
    HAS_RUMPS = False

if not HAS_RUMPS:
    # 降级到普通 GUI
    from app import main
    main()
    sys.exit(0)

import json
import time
import asyncio
import threading
from pathlib import Path
from datetime import datetime

sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'core'))
from core import Config, AgentClient, generate_device_id

# 配置
CONFIG_DIR = Path.home() / ".agentlinker"
CONFIG_FILE = CONFIG_DIR / "config.json"
DEFAULT_SERVER = "ws://43.98.243.80:8080/ws/client"
VERSION = "2.1.0"


class AgentLinkerMenuBar(rumps.App):
    """AgentLinker 菜单栏应用"""
    
    def __init__(self):
        # 加载图标
        icon_path = os.path.join(os.path.dirname(__file__), '..', 'assets', 'icon.png')
        if not os.path.exists(icon_path):
            icon_path = None
        
        super(AgentLinkerMenuBar, self).__init__(
            "🤖",
            title="AgentLinker",
            quit_button="退出"
        )
        
        self.config = self._load_config()
        self.client = None
        self.pairing_key = None
        self.running = False
        
        # 菜单项
        self.status_item = rumps.MenuItem("⚪ 未连接")
        self.device_id_item = rumps.MenuItem("设备 ID: 加载中...")
        self.pairing_key_item = rumps.MenuItem("配对密钥：等待...")
        
        self.copy_key_item = rumps.MenuItem("📋 复制配对密钥", self.copy_pairing_key)
        self.start_stop_item = rumps.MenuItem("▶️ 启动服务", self.toggle_service)
        
        self.separator = rumps.MenuItem("-")
        self.show_window_item = rumps.MenuItem("🪟 显示窗口", self.show_window)
        self.preferences_item = rumps.MenuItem("⚙️ 偏好设置", self.show_preferences)
        
        # 添加菜单项
        self.menu = [
            self.status_item,
            rumps.MenuItem("-"),
            self.device_id_item,
            self.pairing_key_item,
            rumps.MenuItem("-"),
            self.copy_key_item,
            self.start_stop_item,
            rumps.MenuItem("-"),
            self.show_window_item,
            self.preferences_item,
        ]
        
        # 自动启动
        if self.config.get('auto_start', True):
            self.after(1000, self.start_client)
    
    def _load_config(self) -> dict:
        """加载配置"""
        if CONFIG_FILE.exists():
            try:
                with open(CONFIG_FILE, 'r') as f:
                    return json.load(f)
            except:
                pass
        
        return {
            "device_id": generate_device_id(),
            "device_name": f"{platform.node()} ({platform.system()})",
            "token": "ah_device_token_change_in_production",
            "server_url": DEFAULT_SERVER,
            "auto_start": True
        }
    
    def _save_config(self):
        """保存配置"""
        CONFIG_DIR.mkdir(parents=True, exist_ok=True)
        with open(CONFIG_FILE, 'w') as f:
            json.dump(self.config, f, indent=2, ensure_ascii=False)
    
    def toggle_service(self, sender):
        """切换服务状态"""
        if self.running:
            self.stop_client()
        else:
            self.start_client()
    
    def start_client(self):
        """启动客户端"""
        if self.running:
            return
        
        def run():
            try:
                config = Config(str(CONFIG_FILE))
                config.data = self.config
                
                self.client = AgentClient(config)
                
                loop = asyncio.new_event_loop()
                asyncio.set_event_loop(loop)
                
                connected = loop.run_until_complete(self.client.connect())
                
                if connected:
                    self.running = True
                    self._update_status("connected")
                    
                    # 等待配对密钥
                    for _ in range(30):
                        if self.client.pairing_key:
                            self.pairing_key = self.client.pairing_key
                            self._update_pairing_key(self.pairing_key)
                            
                            # 自动复制
                            if self.config.get('copy_on_start', True):
                                self.copy_pairing_key(None)
                            
                            break
                        time.sleep(1)
                    
                    loop.run_until_complete(self.client.handle_messages())
                else:
                    self._update_status("error")
                    
            except Exception as e:
                print(f"错误：{e}")
                self._update_status("error")
        
        self._update_status("connecting")
        thread = threading.Thread(target=run, daemon=True)
        thread.start()
    
    def stop_client(self):
        """停止客户端"""
        if self.client:
            self.client.stop()
        self.running = False
        self._update_status("disconnected")
    
    def _update_status(self, status: str):
        """更新状态"""
        status_map = {
            "disconnected": ("⚪ 未连接", "▶️ 启动服务"),
            "connecting": ("🟡 连接中...", "⏹️ 停止"),
            "connected": ("🟢 已连接", "⏹️ 停止"),
            "error": ("🔴 错误", "▶️ 重试")
        }
        
        status_text, button_text = status_map.get(status, status_map['disconnected'])
        self.status_item.title = status_text
        self.start_stop_item.title = button_text
    
    def _update_pairing_key(self, key: str):
        """更新配对密钥显示"""
        self.pairing_key_item.title = f"配对密钥：{key}"
    
    def copy_pairing_key(self, sender):
        """复制配对密钥"""
        if self.pairing_key:
            # macOS 剪贴板
            import subprocess
            subprocess.run(['pbcopy'], input=self.pairing_key.encode(), check=True)
            
            # 显示通知
            self.notification(
                "AgentLinker",
                f"配对密钥 {self.pairing_key} 已复制",
                "",
                3
            )
        else:
            self.notification(
                "AgentLinker",
                "无配对密钥",
                "请先启动服务",
                3
            )
    
    def show_window(self, sender):
        """显示主窗口（未来功能）"""
        self.notification(
            "AgentLinker",
            "窗口功能开发中",
            "请使用菜单栏控制",
            2
        )
    
    def show_preferences(self, sender):
        """显示偏好设置（未来功能）"""
        self.notification(
            "AgentLinker",
            "偏好设置开发中",
            "请编辑配置文件",
            2
        )


def main():
    """主函数"""
    import platform
    app = AgentLinkerMenuBar()
    app.run()


if __name__ == "__main__":
    main()
