"""
AgentLinker Server with Authentication
云端中转服务端 - FastAPI + WebSocket + 用户认证
支持一对多控制，账号密码注册登录
"""

import asyncio
import json
import time
import uuid
import os
from datetime import datetime, timedelta
from typing import Dict, Optional, Set
from contextlib import asynccontextmanager

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials, OAuth2PasswordBearer
from pydantic import BaseModel, Field, EmailStr
from starlette.middleware.cors import CORSMiddleware
from passlib.context import CryptContext
from jose import JWTError, jwt
import aiosqlite
import uvicorn

# ============== 配置 ==============
SERVER_AGENT_TOKEN = os.getenv("SERVER_AGENT_TOKEN", "ah_server_token_change_in_production")
LINUX_DEVICE_TOKEN = os.getenv("LINUX_DEVICE_TOKEN", "ah_device_token_change_in_production")
SECRET_KEY = os.getenv("SECRET_KEY", "your-secret-key-change-in-production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24  # 24 小时

DATABASE_PATH = os.getenv("DATABASE_PATH", "./agentlinker.db")

# ============== 密码加密 ==============
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# ============== JWT 工具 ==============
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """验证密码"""
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    """密码哈希"""
    return pwd_context.hash(password)


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """创建 JWT token"""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt


def decode_access_token(token: str) -> Optional[dict]:
    """解码 JWT token"""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except JWTError:
        return None


# ============== 数据库模型 ==============

class DatabaseManager:
    """SQLite 数据库管理器"""
    
    def __init__(self, db_path: str):
        self.db_path = db_path
        self.db: Optional[aiosqlite.Connection] = None
    
    async def connect(self):
        """连接数据库"""
        self.db = await aiosqlite.connect(self.db_path)
        self.db.row_factory = aiosqlite.Row
        await self.init_db()
    
    async def close(self):
        """关闭数据库"""
        if self.db:
            await self.db.close()
    
    async def init_db(self):
        """初始化数据库表"""
        await self.db.execute("""
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT UNIQUE NOT NULL,
                email TEXT UNIQUE,
                hashed_password TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                is_active BOOLEAN DEFAULT TRUE,
                is_admin BOOLEAN DEFAULT FALSE
            )
        """)
        
        await self.db.execute("""
            CREATE TABLE IF NOT EXISTS devices (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                device_id TEXT UNIQUE NOT NULL,
                user_id INTEGER NOT NULL,
                device_name TEXT,
                platform TEXT,
                paired_controllers TEXT DEFAULT '[]',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                last_seen TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users (id)
            )
        """)
        
        await self.db.execute("""
            CREATE TABLE IF NOT EXISTS controllers (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                controller_id TEXT UNIQUE NOT NULL,
                user_id INTEGER NOT NULL,
                platform TEXT,
                paired_devices TEXT DEFAULT '[]',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                last_seen TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users (id)
            )
        """)
        
        await self.db.execute("""
            CREATE TABLE IF NOT EXISTS audit_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER,
                action TEXT NOT NULL,
                resource TEXT,
                details TEXT,
                ip_address TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users (id)
            )
        """)
        
        await self.db.commit()
        
        # 创建默认管理员账户（如果不存在）
        await self.create_default_admin()
    
    async def create_default_admin(self):
        """创建默认管理员账户"""
        cursor = await self.db.execute("SELECT * FROM users WHERE username = ?", ("admin",))
        if not await cursor.fetchone():
            hashed_pw = get_password_hash("admin123")
            await self.db.execute(
                "INSERT INTO users (username, email, hashed_password, is_admin) VALUES (?, ?, ?, ?)",
                ("admin", "admin@agentlinker.local", hashed_pw, True)
            )
            await self.db.commit()
            print("✅ 创建默认管理员账户：admin / admin123")
    
    async def get_user_by_username(self, username: str) -> Optional[dict]:
        """根据用户名获取用户"""
        cursor = await self.db.execute("SELECT * FROM users WHERE username = ?", (username,))
        row = await cursor.fetchone()
        return dict(row) if row else None
    
    async def get_user_by_id(self, user_id: int) -> Optional[dict]:
        """根据 ID 获取用户"""
        cursor = await self.db.execute("SELECT * FROM users WHERE id = ?", (user_id,))
        row = await cursor.fetchone()
        return dict(row) if row else None
    
    async def create_user(self, username: str, password: str, email: Optional[str] = None) -> dict:
        """创建新用户"""
        hashed_pw = get_password_hash(password)
        cursor = await self.db.execute(
            "INSERT INTO users (username, email, hashed_password) VALUES (?, ?, ?)",
            (username, email, hashed_pw)
        )
        await self.db.commit()
        user_id = cursor.lastrowid
        return await self.get_user_by_id(user_id)
    
    async def authenticate_user(self, username: str, password: str) -> Optional[dict]:
        """认证用户"""
        user = await self.get_user_by_username(username)
        if not user:
            return None
        if not verify_password(password, user["hashed_password"]):
            return None
        return user
    
    async def register_device(self, user_id: int, device_id: str, device_name: str, platform: str) -> dict:
        """注册设备"""
        cursor = await self.db.execute(
            "INSERT OR REPLACE INTO devices (user_id, device_id, device_name, platform, last_seen) VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)",
            (user_id, device_id, device_name, platform)
        )
        await self.db.commit()
        return {
            "user_id": user_id,
            "device_id": device_id,
            "device_name": device_name,
            "platform": platform
        }
    
    async def get_device_by_id(self, device_id: str) -> Optional[dict]:
        """获取设备信息"""
        cursor = await self.db.execute("SELECT * FROM devices WHERE device_id = ?", (device_id,))
        row = await cursor.fetchone()
        return dict(row) if row else None
    
    async def update_device_last_seen(self, device_id: str):
        """更新设备最后在线时间"""
        await self.db.execute(
            "UPDATE devices SET last_seen = CURRENT_TIMESTAMP WHERE device_id = ?",
            (device_id,)
        )
        await self.db.commit()
    
    async def log_action(self, user_id: Optional[int], action: str, resource: Optional[str] = None, details: Optional[str] = None, ip_address: Optional[str] = None):
        """记录审计日志"""
        await self.db.execute(
            "INSERT INTO audit_logs (user_id, action, resource, details, ip_address) VALUES (?, ?, ?, ?, ?)",
            (user_id, action, resource, details, ip_address)
        )
        await self.db.commit()


# ============== 数据模型 ==============

class AgentRequest(BaseModel):
    device_id: str = Field(..., description="目标设备 ID")
    req_id: Optional[str] = Field(default_factory=lambda: str(uuid.uuid4()), description="请求 ID")
    action: str = Field(..., description="执行动作")
    params: dict = Field(default_factory=dict, description="动作参数")


class AgentResponse(BaseModel):
    code: int = 0
    msg: str = "ok"
    req_id: str
    data: Optional[dict] = None


# 认证相关模型
class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int


class TokenData(BaseModel):
    username: Optional[str] = None
    user_id: Optional[int] = None


class UserCreate(BaseModel):
    username: str = Field(..., min_length=3, max_length=50)
    password: str = Field(..., min_length=6)
    email: Optional[str] = None


class UserLogin(BaseModel):
    username: str
    password: str


class UserResponse(BaseModel):
    id: int
    username: str
    email: Optional[str]
    created_at: str
    is_active: bool


class DeviceRegister(BaseModel):
    device_id: str
    device_name: str
    platform: str
    token: str


class MessageResponse(BaseModel):
    code: int
    msg: str
    data: Optional[dict] = None


class DeviceInfo(BaseModel):
    model_config = {"arbitrary_types_allowed": True}
    
    device_id: str
    device_name: str
    platform: str
    connected_at: float
    last_ping: float
    websocket: Optional[WebSocket] = None
    pending_requests: Dict[str, asyncio.Future] = {}
    paired_controllers: Set[str] = set()
    user_id: Optional[int] = None


class ControllerInfo(BaseModel):
    model_config = {"arbitrary_types_allowed": True}
    
    controller_id: str
    platform: str
    connected_at: float
    last_ping: float
    websocket: Optional[WebSocket] = None
    paired_devices: Set[str] = set()
    user_id: Optional[int] = None


# ============== 全局状态 ==============

db_manager = DatabaseManager(DATABASE_PATH)
connected_devices: Dict[str, DeviceInfo] = {}
connected_controllers: Dict[str, ControllerInfo] = {}
security = HTTPBearer()

# 配对密钥存储
pairing_keys: Dict[str, dict] = {}


# ============== 工具函数 ==============

def verify_agent_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """验证 Agent 调用 Token"""
    if credentials.credentials != SERVER_AGENT_TOKEN:
        raise HTTPException(status_code=401, detail="Invalid token")
    return credentials.credentials


async def get_current_user(token: str = Depends(oauth2_scheme)) -> dict:
    """获取当前用户"""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    payload = decode_access_token(token)
    if payload is None:
        raise credentials_exception
    
    username: str = payload.get("sub")
    user_id: int = payload.get("user_id")
    
    if username is None or user_id is None:
        raise credentials_exception
    
    user = await db_manager.get_user_by_username(username)
    if user is None:
        raise credentials_exception
    
    if not user.get("is_active", True):
        raise HTTPException(status_code=403, detail="User account is disabled")
    
    return user


def generate_pairing_key() -> str:
    """生成配对密钥（8 位字母数字）"""
    import secrets
    import string
    return ''.join(secrets.choice(string.ascii_uppercase + string.digits) for _ in range(8))


def cleanup_expired_pairing_keys():
    """清理过期的配对密钥"""
    now = time.time()
    expired = [k for k, v in pairing_keys.items() if v.get('expires_at', 0) < now]
    for k in expired:
        del pairing_keys[k]


# ============== FastAPI 应用 ==============

@asynccontextmanager
async def lifespan(app: FastAPI):
    """应用生命周期管理"""
    await db_manager.connect()
    print("🚀 AgentLinker Server 启动")
    print(f"   数据库：{DATABASE_PATH}")
    print(f"   服务端 Token: {SERVER_AGENT_TOKEN[:8]}...")
    yield
    # 清理所有连接
    for device in connected_devices.values():
        if device.websocket:
            await device.websocket.close()
    for controller in connected_controllers.values():
        if controller.websocket:
            await controller.websocket.close()
    await db_manager.close()
    print("🛑 AgentLinker Server 关闭")


app = FastAPI(
    title="AgentLinker Server",
    description="AI Agent 远程控制系统服务端 - 支持用户认证",
    version="3.0.0",
    lifespan=lifespan
)

# CORS 配置
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============== 认证 API ==============

@app.post("/api/v1/auth/register", response_model=UserResponse)
async def register(user_data: UserCreate):
    """用户注册"""
    # 检查用户名是否已存在
    existing_user = await db_manager.get_user_by_username(user_data.username)
    if existing_user:
        raise HTTPException(status_code=400, detail="Username already registered")
    
    # 创建用户
    user = await db_manager.create_user(
        username=user_data.username,
        password=user_data.password,
        email=user_data.email
    )
    
    await db_manager.log_action(
        user_id=user["id"],
        action="USER_REGISTER",
        details=f"Username: {user_data.username}"
    )
    
    print(f"👤 新用户注册：{user_data.username}")
    
    return UserResponse(
        id=user["id"],
        username=user["username"],
        email=user.get("email"),
        created_at=str(user["created_at"]),
        is_active=user["is_active"]
    )


@app.post("/api/v1/auth/login", response_model=Token)
async def login(user_data: UserLogin):
    """用户登录"""
    user = await db_manager.authenticate_user(user_data.username, user_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    if not user.get("is_active", True):
        raise HTTPException(status_code=403, detail="User account is disabled")
    
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user["username"], "user_id": user["id"]},
        expires_delta=access_token_expires
    )
    
    await db_manager.log_action(
        user_id=user["id"],
        action="USER_LOGIN",
        details=f"Username: {user_data.username}"
    )
    
    print(f"🔐 用户登录：{user_data.username}")
    
    return Token(
        access_token=access_token,
        token_type="bearer",
        expires_in=ACCESS_TOKEN_EXPIRE_MINUTES * 60
    )


@app.get("/api/v1/auth/me", response_model=UserResponse)
async def get_current_user_info(current_user: dict = Depends(get_current_user)):
    """获取当前用户信息"""
    return UserResponse(
        id=current_user["id"],
        username=current_user["username"],
        email=current_user.get("email"),
        created_at=str(current_user["created_at"]),
        is_active=current_user["is_active"]
    )


# ============== WebSocket 路由 (设备端连接) ==============

@app.websocket("/ws/client")
async def client_websocket(websocket: WebSocket):
    """设备端 WebSocket 连接入口"""
    await websocket.accept()
    device_id: Optional[str] = None
    
    try:
        # 第一步：接收注册消息
        raw_msg = await websocket.receive_text()
        msg = json.loads(raw_msg)
        
        if msg.get("type") != "register":
            await websocket.send_json({"type": "error", "msg": "First message must be register"})
            await websocket.close()
            return
        
        device_id = msg.get("device_id")
        device_name = msg.get("device_name", device_id)
        platform = msg.get("platform", "Unknown")
        token = msg.get("token")
        user_token = msg.get("user_token")  # 用户 JWT token
        
        if not device_id or not token:
            await websocket.send_json({"type": "error", "msg": "Missing device_id or token"})
            await websocket.close()
            return
        
        if not verify_device_token(token):
            await websocket.send_json({"type": "error", "msg": "Invalid token"})
            await websocket.close()
            return
        
        # 验证用户 token（可选）
        user_id = None
        if user_token:
            payload = decode_access_token(user_token)
            if payload:
                user_id = payload.get("user_id")
                # 注册设备到用户
                await db_manager.register_device(user_id, device_id, device_name, platform)
                await db_manager.log_action(
                    user_id=user_id,
                    action="DEVICE_CONNECT",
                    resource=device_id,
                    details=f"Device: {device_name} ({platform})"
                )
        
        # 注册成功
        now = time.time()
        device_info = DeviceInfo(
            device_id=device_id,
            device_name=device_name,
            platform=platform,
            connected_at=now,
            last_ping=now,
            websocket=websocket,
            pending_requests={},
            paired_controllers=set(),
            user_id=user_id
        )
        
        # 如果设备已存在，关闭旧连接
        if device_id in connected_devices:
            old_device = connected_devices[device_id]
            if old_device.websocket:
                try:
                    await old_device.websocket.close()
                except:
                    pass
            for future in old_device.pending_requests.values():
                if not future.done():
                    future.set_exception(Exception("Device reconnected"))
        
        connected_devices[device_id] = device_info
        
        await websocket.send_json({
            "type": "registered",
            "device_id": device_id,
            "device_name": device_name,
            "msg": "Connected successfully"
        })
        
        print(f"📱 设备上线：{device_id} ({platform})")
        
        # 生成配对密钥
        pairing_key = generate_pairing_key()
        pairing_keys[device_id] = {
            "key": pairing_key,
            "expires_at": now + 3600,
            "created_at": now
        }
        
        await websocket.send_json({
            "type": "pairing_key",
            "device_id": device_id,
            "pairing_key": pairing_key,
            "msg": f"Your pairing key: {pairing_key}"
        })
        print(f"🔑 设备 {device_id} 配对密钥：{pairing_key}")
        
        # 保持连接，处理心跳和结果返回
        while True:
            try:
                raw_msg = await asyncio.wait_for(websocket.receive_text(), timeout=60.0)
                msg = json.loads(raw_msg)
                
                msg_type = msg.get("type")
                
                if msg_type == "ping":
                    device_info.last_ping = time.time()
                    await db_manager.update_device_last_seen(device_id)
                    await websocket.send_json({"type": "pong", "time": time.time()})
                
                elif msg_type == "result":
                    req_id = msg.get("req_id")
                    if req_id and req_id in device_info.pending_requests:
                        future = device_info.pending_requests.pop(req_id)
                        if not future.done():
                            future.set_result(msg)
                
                elif msg_type == "error":
                    req_id = msg.get("req_id")
                    if req_id and req_id in device_info.pending_requests:
                        future = device_info.pending_requests.pop(req_id)
                        if not future.done():
                            future.set_result(msg)
                
            except asyncio.TimeoutError:
                if time.time() - device_info.last_ping > 120:
                    print(f"⏱️ 设备心跳超时：{device_id}")
                    break
                try:
                    await websocket.send_json({"type": "ping"})
                except:
                    break
    
    except WebSocketDisconnect:
        print(f"📴 设备断开：{device_id}")
    except Exception as e:
        print(f"❌ 设备 {device_id} 异常：{e}")
    finally:
        if device_id and device_id in connected_devices:
            device = connected_devices[device_id]
            for future in device.pending_requests.values():
                if not future.done():
                    future.set_exception(Exception("Device disconnected"))
            
            del connected_devices[device_id]
            if device_id in pairing_keys:
                del pairing_keys[device_id]
            print(f"🗑️ 设备注销：{device_id}")


# ============== WebSocket 路由 (控制器端连接) ==============

@app.websocket("/ws/controller")
async def controller_websocket(websocket: WebSocket):
    """控制器 WebSocket 连接入口"""
    await websocket.accept()
    controller_id: Optional[str] = None
    
    try:
        raw_msg = await websocket.receive_text()
        msg = json.loads(raw_msg)
        
        if msg.get("type") != "controller_handshake":
            await websocket.send_json({"type": "error", "msg": "First message must be controller_handshake"})
            await websocket.close()
            return
        
        controller_id = msg.get("controller_id")
        platform = msg.get("platform", "Unknown")
        
        if not controller_id:
            await websocket.send_json({"type": "error", "msg": "Missing controller_id"})
            await websocket.close()
            return
        
        now = time.time()
        controller_info = ControllerInfo(
            controller_id=controller_id,
            platform=platform,
            connected_at=now,
            last_ping=now,
            websocket=websocket,
            paired_devices=set()
        )
        
        if controller_id in connected_controllers:
            old_controller = connected_controllers[controller_id]
            if old_controller.websocket:
                try:
                    await old_controller.websocket.close()
                except:
                    pass
        
        connected_controllers[controller_id] = controller_info
        
        await websocket.send_json({
            "type": "controller_ready",
            "controller_id": controller_id,
            "msg": "Controller ready"
        })
        
        print(f"🎮 控制器上线：{controller_id} ({platform})")
        
        while True:
            try:
                raw_msg = await asyncio.wait_for(websocket.receive_text(), timeout=60.0)
                msg = json.loads(raw_msg)
                
                msg_type = msg.get("type")
                
                if msg_type == "ping":
                    controller_info.last_ping = time.time()
                    await websocket.send_json({"type": "pong", "time": time.time()})
                
                elif msg_type == "pair":
                    device_id = msg.get("device_id")
                    pairing_key = msg.get("pairing_key")
                    
                    cleanup_expired_pairing_keys()
                    
                    if device_id not in pairing_keys:
                        await websocket.send_json({
                            "type": "error",
                            "msg": f"Device {device_id} not found or pairing key expired"
                        })
                        continue
                    
                    if pairing_keys[device_id]["key"] != pairing_key:
                        await websocket.send_json({
                            "type": "error",
                            "msg": "Invalid pairing key"
                        })
                        continue
                    
                    if device_id not in connected_devices:
                        await websocket.send_json({
                            "type": "error",
                            "msg": f"Device {device_id} is offline"
                        })
                        continue
                    
                    device = connected_devices[device_id]
                    device.paired_controllers.add(controller_id)
                    controller_info.paired_devices.add(device_id)
                    
                    await websocket.send_json({
                        "type": "paired",
                        "controller_id": controller_id,
                        "device_id": device_id,
                        "msg": f"Successfully paired with {device_id}"
                    })
                    
                    if device.websocket:
                        await device.websocket.send_json({
                            "type": "controller_connected",
                            "controller_id": controller_id
                        })
                    
                    print(f"🔗 控制器 {controller_id} 配对设备 {device_id}")
                
                elif msg_type == "unpair":
                    device_id = msg.get("device_id")
                    
                    if device_id in connected_devices:
                        device = connected_devices[device_id]
                        device.paired_controllers.discard(controller_id)
                        if device.websocket:
                            await device.websocket.send_json({
                                "type": "controller_disconnected",
                                "controller_id": controller_id
                            })
                    
                    controller_info.paired_devices.discard(device_id)
                    print(f"🔓 控制器 {controller_id} 解除配对 {device_id}")
                
                elif msg_type == "exec":
                    req_id = msg.get("req_id", str(uuid.uuid4()))
                    device_id = msg.get("device_id")
                    action = msg.get("action")
                    params = msg.get("params", {})
                    
                    if device_id not in controller_info.paired_devices:
                        await websocket.send_json({
                            "type": "error",
                            "req_id": req_id,
                            "msg": f"Device {device_id} not paired"
                        })
                        continue
                    
                    if device_id not in connected_devices:
                        await websocket.send_json({
                            "type": "error",
                            "req_id": req_id,
                            "msg": f"Device {device_id} is offline"
                        })
                        continue
                    
                    target_device = connected_devices[device_id]
                    future = asyncio.get_event_loop().create_future()
                    target_device.pending_requests[req_id] = future
                    
                    await target_device.websocket.send_json({
                        "type": "exec",
                        "req_id": req_id,
                        "action": action,
                        "params": params
                    })
                    
                    try:
                        result = await asyncio.wait_for(future, timeout=30.0)
                        await websocket.send_json({
                            "type": "result",
                            "req_id": req_id,
                            "data": result.get("data") or result
                        })
                    except asyncio.TimeoutError:
                        await websocket.send_json({
                            "type": "error",
                            "req_id": req_id,
                            "msg": "Request timeout"
                        })
                    finally:
                        if req_id in target_device.pending_requests:
                            del target_device.pending_requests[req_id]
                
                elif msg_type == "list_devices":
                    req_id = msg.get("req_id")
                    devices = []
                    for dev_id, dev in connected_devices.items():
                        devices.append({
                            "device_id": dev_id,
                            "device_name": dev.device_name,
                            "platform": dev.platform,
                            "online_duration": time.time() - dev.connected_at
                        })
                    
                    await websocket.send_json({
                        "type": "result",
                        "req_id": req_id,
                        "devices": devices
                    })
                
            except asyncio.TimeoutError:
                try:
                    await websocket.send_json({"type": "ping"})
                except:
                    break
    
    except WebSocketDisconnect:
        print(f"🎮 控制器断开：{controller_id}")
    except Exception as e:
        print(f"❌ 控制器 {controller_id} 异常：{e}")
    finally:
        if controller_id and controller_id in connected_controllers:
            controller = connected_controllers[controller_id]
            for device_id in controller.paired_devices:
                if device_id in connected_devices:
                    device = connected_devices[device_id]
                    device.paired_controllers.discard(controller_id)
            
            del connected_controllers[controller_id]
            print(f"🗑️ 控制器注销：{controller_id}")


# ============== HTTP API 路由 ==============

@app.post("/api/v1/agent/send", response_model=AgentResponse)
async def agent_send(
    request: AgentRequest,
    token: str = Depends(verify_agent_token)
):
    """Agent 发送指令到设备"""
    device_id = request.device_id
    
    if device_id not in connected_devices:
        raise HTTPException(status_code=404, detail=f"Device {device_id} not connected")
    
    device = connected_devices[device_id]
    future = asyncio.get_event_loop().create_future()
    device.pending_requests[request.req_id] = future
    
    try:
        await device.websocket.send_json({
            "type": "exec",
            "req_id": request.req_id,
            "action": request.action,
            "params": request.params
        })
        
        result = await asyncio.wait_for(future, timeout=60.0)
        
        return AgentResponse(
            code=0,
            msg="ok",
            req_id=request.req_id,
            data=result.get("data") or {"success": result.get("success", False)}
        )
    except asyncio.TimeoutError:
        return AgentResponse(
            code=408,
            msg="Request timeout",
            req_id=request.req_id,
            data={"success": False, "error": "Request timeout"}
        )
    except Exception as e:
        return AgentResponse(
            code=500,
            msg=str(e),
            req_id=request.req_id,
            data={"success": False, "error": str(e)}
        )
    finally:
        if request.req_id in device.pending_requests:
            del device.pending_requests[request.req_id]


@app.get("/api/v1/devices")
async def list_devices(current_user: dict = Depends(get_current_user)):
    """获取当前用户的在线设备列表"""
    now = time.time()
    devices = []
    for device_id, info in connected_devices.items():
        # 只返回当前用户的设备
        if info.user_id == current_user["id"]:
            devices.append({
                "device_id": device_id,
                "device_name": info.device_name,
                "platform": info.platform,
                "connected_at": info.connected_at,
                "last_ping": info.last_ping,
                "online_duration": now - info.connected_at
            })
    return {"code": 0, "devices": devices}


@app.get("/api/v1/users/{user_id}/devices")
async def get_user_devices(user_id: int, current_user: dict = Depends(get_current_user)):
    """获取用户的所有设备（包括离线）"""
    # 只允许查看自己的设备
    if current_user["id"] != user_id and not current_user.get("is_admin", False):
        raise HTTPException(status_code=403, detail="Not authorized")
    
    cursor = await db_manager.db.execute(
        "SELECT * FROM devices WHERE user_id = ?",
        (user_id,)
    )
    rows = await cursor.fetchall()
    devices = [dict(row) for row in rows]
    return {"code": 0, "devices": devices}


@app.get("/health")
async def health_check():
    """健康检查"""
    return {
        "status": "ok",
        "connected_devices": len(connected_devices),
        "connected_controllers": len(connected_controllers),
        "database": DATABASE_PATH,
        "version": "3.0.0"
    }


# ============== 主入口 ==============

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8080,
        reload=False,
        log_level="info"
    )
