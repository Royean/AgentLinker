# AgentLinker Windows 安装指南

🪟 **在 Windows 上安装和使用 AgentLinker**

---

## 📋 系统要求

- **操作系统:** Windows 10/11 或 Windows Server 2019/2022
- **架构:** 64 位 (x64) 或 ARM64
- **.NET Framework:** 4.5+ (通常已预装)
- **内存:** 最少 100MB 可用内存
- **磁盘:** 最少 200MB 可用空间

---

## 🚀 安装方式

### 方式一：一键安装脚本（推荐）⭐

**最简单的方式！**

1. **打开 PowerShell（管理员）**
   - 按 `Win + X`
   - 选择 "Windows PowerShell (管理员)" 或 "终端 (管理员)"

2. **运行安装命令**
   ```powershell
   iwr https://raw.githubusercontent.com/Royean/AgentLinker/master/scripts/install.ps1 -useb | iex
   ```

3. **按照提示完成安装**
   - 选择是否开机自启
   - 选择是否立即运行

**就这么简单！**

---

### 方式二：手动安装

1. **下载安装包**
   - 访问 [GitHub Releases](https://github.com/Royean/AgentLinker/releases)
   - 下载 `AgentLinker-Windows.zip`

2. **解压文件**
   - 创建目录：`C:\Program Files\AgentLinker`
   - 解压到该目录

3. **创建快捷方式**
   - 右键 `AgentLinker.exe`
   - 发送到 → 桌面快捷方式

4. **运行程序**
   - 双击桌面上的 `AgentLinker` 图标

---

### 方式三：便携版

适合临时使用或 U 盘携带：

1. 下载 `AgentLinker-Portable.zip`
2. 解压到任意目录
3. 双击 `AgentLinker.exe`
4. 无需安装，即开即用

---

## 🎯 使用指南

### 首次启动

1. **双击桌面上的 AgentLinker 图标**
2. 应用会自动启动
3. 显示设备 ID 和配对密钥

### 查看配对密钥

- 主界面会显示 **配对密钥**（8 位字母数字）
- 点击 **"📋 复制密钥"** 按钮即可复制

### 配对设备

在控制器端（另一台电脑）：

```bash
# 启动控制器
agentlinker --mode controller --server ws://43.98.243.80:8080/ws/controller

# 配对你的 Windows 电脑
[controller]> pair DESKTOP-ABC123-xxxx ABCD1234
```

### 系统托盘

AgentLinker 会在系统托盘显示图标：

- **右键点击图标** 可以：
  - 复制配对密钥
  - 显示/隐藏窗口
  - 启动/停止服务
  - 退出程序

---

## ⚙️ 设置

### 修改设备 ID

1. 打开应用
2. 点击 **"⚙️ 设置"**
3. 修改设备 ID
4. 保存

### 修改服务器

默认服务器：`ws://43.98.243.80:8080/ws/client`

如果要使用自己的服务器：

1. 打开应用
2. 点击 **"⚙️ 设置"**
3. 修改服务器地址
4. 保存并重启

### 开机自启

**安装时设置：**
- 安装脚本会询问是否开机自启
- 选择 `Y` 即可

**安装后修改：**
1. 打开应用
2. 点击 **"⚙️ 设置"**
3. 勾选 **"开机自动启动"**
4. 保存

**手动设置：**
```powershell
# 添加到开机启动
$RegistryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
Set-ItemProperty -Path $RegistryPath -Name "AgentLinker" -Value "C:\Program Files\AgentLinker\AgentLinker.exe"
```

---

## 🔧 故障排除

### 问题 1: 应用无法启动

**可能原因：**
- .NET Framework 未安装
- 防病毒软件阻止

**解决方法：**
1. 安装 [.NET Framework 4.5+](https://dotnet.microsoft.com/download/dotnet-framework)
2. 将 AgentLinker 添加到防病毒软件白名单
3. 右键 `AgentLinker.exe` → 以管理员权限运行

---

### 问题 2: 连接失败

**可能原因：**
- 服务器地址错误
- 防火墙阻止
- 网络问题

**解决方法：**
1. 检查服务器地址是否正确
2. 关闭防火墙或添加例外规则
3. 测试网络连接：
   ```powershell
   Test-NetConnection 43.98.243.80 -Port 8080
   ```

---

### 问题 3: 配对密钥不显示

**可能原因：**
- 服务未启动
- 服务器未运行
- 网络不通

**解决方法：**
1. 点击 **"▶️ 启动服务"**
2. 查看日志是否有错误
3. 检查网络连接

---

### 问题 4: 开机不自启

**解决方法：**
1. 检查注册表：
   ```powershell
   Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "AgentLinker"
   ```
2. 如果不存在，手动添加（见上方"手动设置"）
3. 检查任务管理器 → 启动，确保已启用

---

## 📁 文件位置

### 安装目录
```
C:\Program Files\AgentLinker\
├── AgentLinker.exe      # 主程序
├── config.example.json  # 配置示例
└── README.txt           # 说明文件
```

### 配置文件
```
%USERPROFILE%\.agentlinker\config.json
```

### 日志文件
```
%USERPROFILE%\.agentlinker\agentlinker.log
```

---

## 🗑️ 卸载

### 方式一：使用卸载脚本

```powershell
iwr https://raw.githubusercontent.com/Royean/AgentLinker/master/scripts/install.ps1 -useb | iex -ArgumentList "-Uninstall"
```

### 方式二：手动卸载

1. **停止程序**
   - 右键系统托盘图标 → 退出

2. **删除安装目录**
   ```powershell
   Remove-Item "C:\Program Files\AgentLinker" -Recurse -Force
   ```

3. **删除快捷方式**
   - 删除桌面上的 `AgentLinker.lnk`
   - 删除开始菜单中的 `AgentLinker` 文件夹

4. **删除开机启动（如果存在）**
   ```powershell
   $RegistryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
   Remove-ItemProperty -Path $RegistryPath -Name "AgentLinker" -Force
   ```

5. **删除配置文件（可选）**
   ```powershell
   Remove-Item "$env:USERPROFILE\.agentlinker" -Recurse -Force
   ```

---

## 📞 需要帮助？

- 📖 [完整文档](https://github.com/Royean/AgentLinker#readme)
- 🐛 [提交 Issue](https://github.com/Royean/AgentLinker/issues)
- 💬 [讨论区](https://github.com/Royean/AgentLinker/discussions)

---

## 🎉 开始使用

**安装完成后：**

1. ✅ 打开 AgentLinker
2. ✅ 复制配对密钥
3. ✅ 在控制器端配对
4. ✅ 开始远程控制！

**就这么简单！**

---

**最后更新：** 2026-03-19  
**版本：** v2.2.0
