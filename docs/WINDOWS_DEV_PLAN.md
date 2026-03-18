# AgentLinker Windows 端开发计划

🪟 **让 Windows 用户也能享受简单的远程控制**

---

## 🎯 目标

1. **一键安装** - 像安装普通软件一样简单
2. **图形界面** - 现代化的 Windows 应用
3. **系统托盘** - 后台运行，随时访问
4. **开机自启** - 可选的开机自动启动

---

## 📦 技术方案

### 方案一：PyInstaller + Tkinter（推荐）⭐
- **优点：**
  - 复用现有代码
  - 打包成独立 exe
  - 无需额外依赖
  - 开发速度快
- **缺点：**
  - 界面不如原生
  - exe 文件较大（~50MB）

### 方案二：PyQt5
- **优点：**
  - 现代化界面
  - 原生体验
  - 功能强大
- **缺点：**
  - 需要重写 UI
  - 学习曲线
  - 许可证问题（GPL）

### 方案三：Electron + Python Backend
- **优点：**
  - 最漂亮的界面
  - 跨平台一致
  - 易于定制
- **缺点：**
  - 资源占用大
  - 需要 Node.js
  - 开发复杂

**决定：使用方案一（PyInstaller + Tkinter）**

---

## 🗓️ 开发计划

### Phase 1: 基础适配（2-3 小时）
- [ ] Windows 平台兼容性修改
- [ ] PowerShell 命令支持
- [ ] Windows 路径处理
- [ ] 系统服务管理

### Phase 2: 打包配置（1-2 小时）
- [ ] PyInstaller 配置
- [ ] 图标和资源文件
- [ ] 版本信息
- [ ] 安装包制作

### Phase 3: 系统托盘（2-3 小时）
- [ ] 系统托盘图标
- [ ] 右键菜单
- [ ] 通知支持
- [ ] 开机自启

### Phase 4: 测试和优化（1-2 小时）
- [ ] Windows 10/11 测试
- [ ] 防病毒软件兼容
- [ ] 性能优化
- [ ] 文档更新

---

## 📁 文件结构

```
AgentLinker/
├── client/
│   ├── app.py              # 跨平台 GUI（已支持 Windows）
│   ├── core/
│   │   └── __init__.py     # 需要添加 Windows 支持
│   └── platform/
│       ├── windows.py      # ✨ 新增：Windows 特定实现
│       ├── macos.py        # 已有
│       └── linux.py        # 已有
├── packaging/
│   └── windows/
│       ├── build.py        # ✨ PyInstaller 配置
│       ├── installer.iss   # ✨ Inno Setup 脚本
│       └── icon.ico        # ✨ Windows 图标
├── scripts/
│   └── install.ps1         # ✨ PowerShell 安装脚本
└── docs/
    └── WINDOWS.md          # ✨ Windows 安装指南
```

---

## 🔧 Windows 特定功能

### 1. 系统服务
```python
# 使用 Windows Service 或 任务计划程序
- 开机自动启动
- 后台运行
- 自动重启
```

### 2. 系统托盘
```python
# 使用 pystray 库
- 托盘图标
- 右键菜单（启动/停止/复制密钥/退出）
- 通知弹窗
```

### 3. PowerShell 支持
```python
# 替代 shell 命令
- Get-Process (替代 ps aux)
- Get-Content (替代 tail)
- Stop-Process (替代 kill)
```

### 4. 文件路径
```python
# Windows 路径处理
- C:\\Users\\Username\\
- 使用 os.path.join()
- 支持 UNC 路径
```

---

## 📥 安装方式

### 方式一：一键安装脚本（推荐）
```powershell
# PowerShell 运行
iwr https://raw.githubusercontent.com/Royean/AgentLinker/master/scripts/install.ps1 -useb | iex
```

### 方式二：安装包
- 下载 `AgentLinker-Setup.exe`
- 双击运行
- 下一步 → 完成

### 方式三：便携版
- 下载 `AgentLinker-Portable.zip`
- 解压
- 运行 `AgentLinker.exe`

---

## 🎨 UI 设计

### 主界面（与 macOS 保持一致）
```
┌────────────────────────────────────┐
│  🤖 AgentLinker           v2.2.0  │
├────────────────────────────────────┤
│  状态：🟢 已连接                   │
├────────────────────────────────────┤
│  设备信息                          │
│  设备 ID: DESKTOP-ABC123-xxxx      │
│  名称：我的 Windows 电脑            │
│  配对密钥：ABCD1234                │
├────────────────────────────────────┤
│  [启动服务] [复制密钥] [⚙️ 设置]   │
├────────────────────────────────────┤
│  日志                              │
│  [12:30:45] 应用已启动             │
│  [12:30:46] 正在连接服务端...      │
│  [12:30:47] ✅ 连接成功！          │
└────────────────────────────────────┘
```

### 系统托盘菜单
```
🤖 AgentLinker
  ├─ 🟢 已连接
  ├─ 配对密钥：ABCD1234
  ├─ ────────────
  ├─ 📋 复制密钥
  ├─ 🪟 显示窗口
  ├─ ⚙️ 设置
  ├─ ────────────
  └─ ❌ 退出
```

---

## 🛠️ 依赖库

```txt
# 核心依赖
websockets>=12.0

# GUI
tkinter (内置)

# 系统托盘
pystray>=0.19.5
Pillow>=9.0.0

# Windows 特定
pywin32>=305  # Windows API
psutil>=5.9.0 # 系统信息

# 打包
pyinstaller>=6.0.0
```

---

## 📝 开发步骤

### 1. 创建 Windows 平台模块
```python
# client/platform/windows.py
def get_platform_info():
    return {
        "platform": "Windows",
        "version": platform.version(),
        "hostname": platform.node()
    }

def get_system_info_extended():
    # Windows 特定信息
    pass

def list_applications():
    # 列出已安装程序
    pass
```

### 2. 修改核心模块支持 Windows
```python
# client/core/__init__.py
if platform.system() == "Windows":
    # Windows 特定实现
    shell = False
    # 使用 PowerShell 命令
else:
    # Linux/macOS
    shell = True
```

### 3. 创建 PyInstaller 配置
```python
# packaging/windows/build.py
import PyInstaller.__main__

PyInstaller.__main__.run([
    'client/app.py',
    '--name=AgentLinker',
    '--onefile',
    '--windowed',
    '--icon=assets/icon.ico',
    '--add-data=client/core;core',
    '--hidden-import=tkinter',
])
```

### 4. 创建安装脚本
```powershell
# scripts/install.ps1
# 下载安装包
# 解压到程序目录
# 创建快捷方式
# 添加到开机启动
```

---

## ✅ 验收标准

### 功能测试
- [ ] 一键安装成功
- [ ] 图形界面正常显示
- [ ] 连接服务端成功
- [ ] 显示配对密钥
- [ ] 复制密钥功能正常
- [ ] 系统托盘工作正常
- [ ] 开机自启可选
- [ ] 命令执行正常
- [ ] 文件操作正常

### 兼容性测试
- [ ] Windows 10 (64 位)
- [ ] Windows 11
- [ ] Windows Server 2019/2022
- [ ] 常见防病毒软件（360、腾讯电脑管家等）

### 性能测试
- [ ] 启动时间 < 3 秒
- [ ] 内存占用 < 100MB
- [ ] CPU 占用 < 5%（空闲时）

---

## 📊 时间估算

| 任务 | 预计时间 |
|------|----------|
| Windows 平台适配 | 2-3 小时 |
| 系统托盘实现 | 2-3 小时 |
| PyInstaller 打包 | 1-2 小时 |
| 安装脚本制作 | 1-2 小时 |
| 测试和优化 | 2-3 小时 |
| 文档更新 | 1 小时 |
| **总计** | **9-14 小时** |

---

## 🚀 开始开发！

**当前状态：** 准备就绪  
**预计完成：** 今晚  
**目标版本：** v2.2.0 (包含 Windows 支持)

---

Let's build it! 💪
