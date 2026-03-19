"""
AgentLinker 文件传输模块
支持上传/下载文件，断点续传，进度显示
"""

import asyncio
import base64
import hashlib
import json
import os
import time
from pathlib import Path
from typing import Optional, Callable, Dict


class FileTransfer:
    """文件传输类"""
    
    # 分块大小（1MB）
    CHUNK_SIZE = 1024 * 1024
    
    def __init__(self):
        self.upload_progress: Dict[str, dict] = {}
        self.download_progress: Dict[str, dict] = {}
    
    async def upload_file(
        self,
        file_path: str,
        send_callback: Callable,
        progress_callback: Optional[Callable] = None
    ) -> dict:
        """
        上传文件到远程设备
        
        Args:
            file_path: 本地文件路径
            send_callback: 发送数据的回调函数
            progress_callback: 进度回调函数
        
        Returns:
            传输结果
        """
        file_path = Path(file_path)
        
        if not file_path.exists():
            return {"success": False, "error": f"文件不存在：{file_path}"}
        
        # 生成文件 ID
        file_id = f"{file_path.name}_{int(time.time())}"
        
        # 计算文件哈希
        file_hash = self._calculate_hash(file_path)
        file_size = file_path.stat().st_size
        
        # 初始化进度
        self.upload_progress[file_id] = {
            "filename": file_path.name,
            "total_size": file_size,
            "transferred": 0,
            "start_time": time.time(),
            "status": "uploading"
        }
        
        try:
            # 发送文件信息
            await send_callback({
                "type": "file_transfer_start",
                "file_id": file_id,
                "filename": file_path.name,
                "file_size": file_size,
                "file_hash": file_hash,
                "chunk_size": self.CHUNK_SIZE
            })
            
            # 分块读取并发送
            chunk_index = 0
            with open(file_path, "rb") as f:
                while True:
                    chunk_data = f.read(self.CHUNK_SIZE)
                    if not chunk_data:
                        break
                    
                    # Base64 编码
                    chunk_b64 = base64.b64encode(chunk_data).decode("utf-8")
                    
                    # 发送分块
                    await send_callback({
                        "type": "file_transfer_chunk",
                        "file_id": file_id,
                        "chunk_index": chunk_index,
                        "chunk_size": len(chunk_data),
                        "data": chunk_b64
                    })
                    
                    # 更新进度
                    self.upload_progress[file_id]["transferred"] += len(chunk_data)
                    self.upload_progress[file_id]["chunk_index"] = chunk_index
                    
                    if progress_callback:
                        progress_callback(
                            self.upload_progress[file_id]["transferred"],
                            file_size
                        )
                    
                    chunk_index += 1
                    
                    # 小延迟避免阻塞
                    await asyncio.sleep(0.01)
            
            # 发送完成信号
            await send_callback({
                "type": "file_transfer_complete",
                "file_id": file_id,
                "file_hash": file_hash
            })
            
            # 更新状态
            self.upload_progress[file_id]["status"] = "completed"
            self.upload_progress[file_id]["end_time"] = time.time()
            
            # 计算传输速度
            duration = self.upload_progress[file_id]["end_time"] - self.upload_progress[file_id]["start_time"]
            speed = file_size / duration if duration > 0 else 0
            
            return {
                "success": True,
                "file_id": file_id,
                "filename": file_path.name,
                "file_size": file_size,
                "duration": duration,
                "speed": speed
            }
        
        except Exception as e:
            self.upload_progress[file_id]["status"] = "failed"
            self.upload_progress[file_id]["error"] = str(e)
            
            return {"success": False, "error": str(e)}
    
    async def download_file(
        self,
        file_id: str,
        save_path: str,
        send_callback: Callable,
        progress_callback: Optional[Callable] = None
    ) -> dict:
        """
        从远程设备下载文件
        
        Args:
            file_id: 文件 ID
            save_path: 保存路径
            send_callback: 发送请求的回调函数
            progress_callback: 进度回调函数
        
        Returns:
            传输结果
        """
        try:
            # 初始化进度
            self.download_progress[file_id] = {
                "filename": Path(save_path).name,
                "total_size": 0,
                "transferred": 0,
                "start_time": time.time(),
                "status": "downloading",
                "chunks": []
            }
            
            # 请求文件
            await send_callback({
                "type": "file_download_request",
                "file_id": file_id
            })
            
            # 等待接收文件数据（由消息处理器处理）
            # 这里简化处理，实际需要在消息处理中接收分块
            
            # 重组文件
            save_path = Path(save_path)
            save_path.parent.mkdir(parents=True, exist_ok=True)
            
            with open(save_path, "wb") as f:
                for chunk_b64 in self.download_progress[file_id]["chunks"]:
                    chunk_data = base64.b64decode(chunk_b64)
                    f.write(chunk_data)
            
            # 验证哈希
            downloaded_hash = self._calculate_hash(save_path)
            expected_hash = self.download_progress[file_id].get("file_hash")
            
            if expected_hash and downloaded_hash != expected_hash:
                return {
                    "success": False,
                    "error": "文件哈希不匹配，传输可能损坏"
                }
            
            self.download_progress[file_id]["status"] = "completed"
            self.download_progress[file_id]["end_time"] = time.time()
            
            file_size = save_path.stat().st_size
            duration = self.download_progress[file_id]["end_time"] - self.download_progress[file_id]["start_time"]
            speed = file_size / duration if duration > 0 else 0
            
            return {
                "success": True,
                "file_id": file_id,
                "filename": save_path.name,
                "file_size": file_size,
                "duration": duration,
                "speed": speed
            }
        
        except Exception as e:
            self.download_progress[file_id]["status"] = "failed"
            self.download_progress[file_id]["error"] = str(e)
            
            return {"success": False, "error": str(e)}
    
    def _calculate_hash(self, file_path: Path) -> str:
        """计算文件 SHA256 哈希"""
        sha256 = hashlib.sha256()
        with open(file_path, "rb") as f:
            while True:
                data = f.read(65536)  # 64KB chunks
                if not data:
                    break
                sha256.update(data)
        return sha256.hexdigest()
    
    def get_progress(self, file_id: str) -> Optional[dict]:
        """获取传输进度"""
        if file_id in self.upload_progress:
            progress = self.upload_progress[file_id]
            return {
                "filename": progress["filename"],
                "total_size": progress["total_size"],
                "transferred": progress["transferred"],
                "percent": (progress["transferred"] / progress["total_size"] * 100) if progress["total_size"] > 0 else 0,
                "status": progress["status"],
                "speed": self._calculate_speed(progress)
            }
        
        if file_id in self.download_progress:
            progress = self.download_progress[file_id]
            return {
                "filename": progress["filename"],
                "total_size": progress["total_size"],
                "transferred": progress["transferred"],
                "percent": (progress["transferred"] / progress["total_size"] * 100) if progress["total_size"] > 0 else 0,
                "status": progress["status"],
                "speed": self._calculate_speed(progress)
            }
        
        return None
    
    def _calculate_speed(self, progress: dict) -> float:
        """计算传输速度 (bytes/s)"""
        elapsed = time.time() - progress["start_time"]
        if elapsed > 0:
            return progress["transferred"] / elapsed
        return 0.0
    
    def format_speed(self, speed: float) -> str:
        """格式化速度显示"""
        if speed < 1024:
            return f"{speed:.1f} B/s"
        elif speed < 1024 * 1024:
            return f"{speed/1024:.1f} KB/s"
        else:
            return f"{speed/(1024*1024):.1f} MB/s"


# 服务端文件传输处理
class ServerFileTransfer:
    """服务端文件传输处理器"""
    
    def __init__(self):
        self.temp_files: Dict[str, dict] = {}
        self.CHUNK_SIZE = 1024 * 1024  # 1MB
    
    async def handle_transfer_start(self, device_id: str, data: dict):
        """处理文件传输开始"""
        file_id = data.get("file_id")
        
        self.temp_files[file_id] = {
            "device_id": device_id,
            "filename": data.get("filename"),
            "file_size": data.get("file_size"),
            "file_hash": data.get("file_hash"),
            "chunks_received": 0,
            "chunks": {},
            "start_time": time.time()
        }
        
        print(f"📥 开始接收文件：{data.get('filename')} ({data.get('file_size')} bytes)")
    
    async def handle_transfer_chunk(self, device_id: str, data: dict):
        """处理文件分块"""
        file_id = data.get("file_id")
        chunk_index = data.get("chunk_index")
        chunk_data = data.get("data")
        
        if file_id not in self.temp_files:
            print(f"❌ 未知的文件 ID: {file_id}")
            return
        
        self.temp_files[file_id]["chunks"][chunk_index] = chunk_data
        self.temp_files[file_id]["chunks_received"] += 1
        
        # 更新进度
        progress = self.get_transfer_progress(file_id)
        print(f"📊 进度：{progress['percent']:.1f}% ({progress['speed']})")
    
    async def handle_transfer_complete(self, device_id: str, data: dict):
        """处理文件传输完成"""
        file_id = data.get("file_id")
        file_hash = data.get("file_hash")
        
        if file_id not in self.temp_files:
            return {"success": False, "error": "未知的文件 ID"}
        
        file_info = self.temp_files[file_id]
        
        # 重组文件
        save_dir = Path(f"/tmp/agentlinker_uploads/{device_id}")
        save_dir.mkdir(parents=True, exist_ok=True)
        
        save_path = save_dir / file_info["filename"]
        
        try:
            with open(save_path, "wb") as f:
                # 按顺序写入分块
                for i in range(len(file_info["chunks"])):
                    chunk_b64 = file_info["chunks"][i]
                    chunk_data = base64.b64decode(chunk_b64)
                    f.write(chunk_data)
            
            # 验证哈希
            received_hash = self._calculate_hash(save_path)
            if received_hash != file_hash:
                return {
                    "success": False,
                    "error": "文件哈希不匹配"
                }
            
            # 清理临时数据
            del self.temp_files[file_id]
            
            duration = time.time() - file_info["start_time"]
            speed = file_info["file_size"] / duration if duration > 0 else 0
            
            print(f"✅ 文件接收完成：{save_path}")
            print(f"   大小：{file_info['file_size']} bytes")
            print(f"   耗时：{duration:.2f}s")
            print(f"   速度：{speed/1024:.1f} KB/s")
            
            return {
                "success": True,
                "file_path": str(save_path),
                "file_size": file_info["file_size"]
            }
        
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    def get_transfer_progress(self, file_id: str) -> dict:
        """获取传输进度"""
        if file_id not in self.temp_files:
            return {"percent": 0, "speed": "0 KB/s"}
        
        file_info = self.temp_files[file_id]
        total_chunks = (file_info["file_size"] + self.CHUNK_SIZE - 1) // self.CHUNK_SIZE
        received_chunks = file_info["chunks_received"]
        
        percent = (received_chunks / total_chunks * 100) if total_chunks > 0 else 0
        
        elapsed = time.time() - file_info["start_time"]
        transferred = received_chunks * self.CHUNK_SIZE
        speed = transferred / elapsed if elapsed > 0 else 0
        
        def format_speed(s):
            if s < 1024:
                return f"{s:.1f} B/s"
            elif s < 1024 * 1024:
                return f"{s/1024:.1f} KB/s"
            else:
                return f"{s/(1024*1024):.1f} MB/s"
        
        return {
            "percent": percent,
            "received": received_chunks,
            "total": total_chunks,
            "speed": format_speed(speed)
        }
    
    def _calculate_hash(self, file_path: Path) -> str:
        """计算文件 SHA256 哈希"""
        sha256 = hashlib.sha256()
        with open(file_path, "rb") as f:
            while True:
                data = f.read(65536)
                if not data:
                    break
                sha256.update(data)
        return sha256.hexdigest()
