# AgentLinker Windows 一键安装脚本
# PowerShell 运行

param(
    [switch]$Uninstall,
    [switch]$Silent
)

$ErrorActionPreference = "Stop"

# 颜色函数
function Write-Color {
    param($Text, $Color)
    Write-Host $Text -ForegroundColor $Color
}

# 标题
Write-Color "============================================" "Cyan"
Write-Color "   AgentLinker Windows 安装程序" "Cyan"
Write-Color "============================================" "Cyan"
Write-Host ""

# 检查管理员权限
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin -and -not $Silent) {
    Write-Color "⚠️  建议以管理员权限运行" "Yellow"
    Write-Host "按任意键继续，或 Ctrl+C 取消..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# 安装目录
$InstallDir = "$env:ProgramFiles\AgentLinker"
if ($Silent) {
    $InstallDir = "$env:LOCALAPPDATA\AgentLinker"
}

# 卸载模式
if ($Uninstall) {
    Write-Color "正在卸载 AgentLinker..." "Yellow"
    
    # 停止服务
    Get-Process "AgentLinker" -ErrorAction SilentlyContinue | Stop-Process -Force
    
    # 删除安装目录
    if (Test-Path $InstallDir) {
        Remove-Item $InstallDir -Recurse -Force
        Write-Color "✓ 已删除安装目录" "Green"
    }
    
    # 删除快捷方式
    $DesktopPath = [System.IO.Path]::Combine([System.Environment]::GetFolderPath('Desktop'), 'AgentLinker.lnk')
    if (Test-Path $DesktopPath) {
        Remove-Item $DesktopPath -Force
        Write-Color "✓ 已删除桌面快捷方式" "Green"
    }
    
    # 删除开始菜单
    $StartMenuPath = [System.IO.Path]::Combine([System.Environment]::GetFolderPath('StartMenu'), 'Programs', 'AgentLinker')
    if (Test-Path $StartMenuPath) {
        Remove-Item $StartMenuPath -Recurse -Force
        Write-Color "✓ 已删除开始菜单快捷方式" "Green"
    }
    
    # 删除开机启动（如果存在）
    $RegistryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    if (Get-ItemProperty -Path $RegistryPath -Name "AgentLinker" -ErrorAction SilentlyContinue) {
        Remove-ItemProperty -Path $RegistryPath -Name "AgentLinker" -Force
        Write-Color "✓ 已删除开机启动项" "Green"
    }
    
    Write-Color "============================================" "Green"
    Write-Color "   ✅ 卸载完成！" "Green"
    Write-Color "============================================" "Green"
    return
}

# 检查 .NET Framework
Write-Color "[1/6] 检查系统要求..." "Cyan"
try {
    $netVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -ErrorAction SilentlyContinue).Version
    if ($netVersion -lt [Version]"4.5.0") {
        Write-Color "⚠️  需要 .NET Framework 4.5 或更高版本" "Yellow"
        Write-Host "请访问：https://dotnet.microsoft.com/download/dotnet-framework"
        if (-not $Silent) {
            Write-Host "按任意键继续..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
    } else {
        Write-Color "✓ .NET Framework: $netVersion" "Green"
    }
} catch {
    Write-Color "⚠️  无法检测 .NET Framework 版本" "Yellow"
}

# 下载最新版本
Write-Color "[2/6] 下载 AgentLinker..." "Cyan"
$DownloadUrl = "https://github.com/Royean/AgentLinker/releases/latest/download/AgentLinker-Windows.zip"
$TempFile = "$env:TEMP\AgentLinker-Setup.zip"

try {
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $TempFile -UseBasicParsing
    Write-Color "✓ 下载完成" "Green"
} catch {
    Write-Color "❌ 下载失败：$_" "Red"
    Write-Host "请检查网络连接，或手动下载：$DownloadUrl"
    if (-not $Silent) {
        Write-Host "按任意键退出..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    exit 1
}

# 创建安装目录
Write-Color "[3/6] 创建安装目录..." "Cyan"
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    Write-Color "✓ 目录已创建：$InstallDir" "Green"
}

# 解压文件
Write-Color "[4/6] 解压文件..." "Cyan"
try {
    Expand-Archive -Path $TempFile -DestinationPath $InstallDir -Force
    Remove-Item $TempFile -Force
    Write-Color "✓ 文件已解压" "Green"
} catch {
    Write-Color "❌ 解压失败：$_" "Red"
    exit 1
}

# 创建快捷方式
Write-Color "[5/6] 创建快捷方式..." "Cyan"

# 桌面快捷方式
$DesktopPath = [System.IO.Path]::Combine([System.Environment]::GetFolderPath('Desktop'), 'AgentLinker.lnk')
$WScript = New-Object -ComObject WScript.Shell
$Shortcut = $WScript.CreateShortcut($DesktopPath)
$Shortcut.TargetPath = "$InstallDir\AgentLinker.exe"
$Shortcut.WorkingDirectory = $InstallDir
$Shortcut.Description = "AgentLinker - AI Agent Remote Control"
$Shortcut.Save()
Write-Color "✓ 桌面快捷方式已创建" "Green"

# 开始菜单快捷方式
$StartMenuPath = [System.IO.Path]::Combine([System.Environment]::GetFolderPath('StartMenu'), 'Programs', 'AgentLinker')
if (-not (Test-Path $StartMenuPath)) {
    New-Item -ItemType Directory -Path $StartMenuPath -Force | Out-Null
}
$Shortcut = $WScript.CreateShortcut("$StartMenuPath\AgentLinker.lnk")
$Shortcut.TargetPath = "$InstallDir\AgentLinker.exe"
$Shortcut.WorkingDirectory = $InstallDir
$Shortcut.Description = "AgentLinker - AI Agent Remote Control"
$Shortcut.Save()
Write-Color "✓ 开始菜单快捷方式已创建" "Green"

# 询问是否开机自启
$AutoStart = $false
if (-not $Silent) {
    $Response = Read-Host "是否开机自动启动？(Y/N)"
    if ($Response -eq "Y" -or $Response -eq "y") {
        $AutoStart = $true
    }
}

if ($AutoStart) {
    $RegistryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    Set-ItemProperty -Path $RegistryPath -Name "AgentLinker" -Value "$InstallDir\AgentLinker.exe"
    Write-Color "✓ 已添加到开机启动" "Green"
}

# 完成
Write-Color "[6/6] 完成！" "Green"
Write-Host ""
Write-Color "============================================" "Cyan"
Write-Color "   ✅ 安装完成！" "Cyan"
Write-Color "============================================" "Cyan"
Write-Host ""
Write-Host "安装位置：$InstallDir"
Write-Host ""
Write-Host "下一步:"
Write-Host "  1. 双击桌面上的 AgentLinker 图标"
Write-Host "  2. 查看设备 ID 和配对密钥"
Write-Host "  3. 在控制器端配对设备"
Write-Host ""
Write-Host "默认服务器：ws://43.98.243.80:8080/ws/client"
Write-Host ""
Write-Host "需要帮助？访问：https://github.com/Royean/AgentLinker"
Write-Host ""

if (-not $Silent) {
    $RunNow = Read-Host "是否立即运行 AgentLinker？(Y/N)"
    if ($RunNow -eq "Y" -or $RunNow -eq "y") {
        Start-Process "$InstallDir\AgentLinker.exe"
    }
}
