"""
AgentLinker Windows 平台特定实现
"""

import platform
import subprocess
import os
import sys
from pathlib import Path


def get_platform_info() -> dict:
    """获取 Windows 平台信息"""
    try:
        # 获取 Windows 版本
        win_version = platform.version()
        
        # 获取版本号（如 10.0.22621）
        version_parts = platform.version().split('.')
        major = int(version_parts[0]) if len(version_parts) > 0 else 0
        build = int(version_parts[2]) if len(version_parts) > 2 else 0
        
        # 判断 Windows 版本
        if major == 10 and build >= 22000:
            version_name = "Windows 11"
        elif major == 10:
            version_name = "Windows 10"
        elif major == 6 and int(version_parts[1]) >= 3:
            version_name = "Windows 8.1"
        elif major == 6 and int(version_parts[1]) >= 2:
            version_name = "Windows 8"
        elif major == 6 and int(version_parts[1]) >= 1:
            version_name = "Windows 7"
        else:
            version_name = "Windows"
        
    except:
        version_name = "Windows"
        win_version = "Unknown"
    
    try:
        # 获取架构
        arch = platform.machine()
        if arch == "AMD64":
            arch_name = "64-bit"
        elif arch == "x86":
            arch_name = "32-bit"
        elif arch == "ARM64":
            arch_name = "ARM64"
        else:
            arch_name = arch
    except:
        arch_name = "Unknown"
    
    return {
        "platform": "Windows",
        "version_name": version_name,
        "version": win_version,
        "architecture": arch_name,
        "hostname": platform.node()
    }


def get_system_info_extended() -> dict:
    """获取扩展系统信息（Windows 特定）"""
    info = {}
    
    # 获取电池状态（如果是笔记本）
    try:
        import subprocess
        result = subprocess.run(
            ["powercfg", "/batteryreport"],
            capture_output=True,
            text=True,
            timeout=10,
            cwd=os.environ.get('TEMP', 'C:\\Windows\\Temp')
        )
        # 简单判断是否使用电池
        import psutil
        battery = psutil.sensors_battery()
        if battery:
            info["battery_percent"] = battery.percent
            info["battery_plugged"] = battery.power_plugged
            info["battery_status"] = "Charging" if battery.power_plugged else "On Battery"
    except:
        pass
    
    # 获取电源模式
    try:
        import psutil
        info["power_status"] = "AC Power" if psutil.sensors_battery() and psutil.sensors_battery().power_plugged else "Battery"
    except:
        pass
    
    return info


def list_applications() -> list:
    """列出已安装的应用程序"""
    apps = []
    
    try:
        import winreg
        
        # 从注册表读取已安装程序
        registry_paths = [
            r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
            r"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
        ]
        
        for reg_path in registry_paths:
            try:
                key = winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, reg_path)
                i = 0
                while True:
                    try:
                        subkey_name = winreg.EnumKey(key, i)
                        subkey = winreg.OpenKey(key, subkey_name)
                        
                        try:
                            display_name = winreg.QueryValueEx(subkey, "DisplayName")[0]
                            display_version = winreg.QueryValueEx(subkey, "DisplayVersion")[0]
                            publisher = winreg.QueryValueEx(subkey, "Publisher")[0]
                            install_location = winreg.QueryValueEx(subkey, "InstallLocation")[0]
                            
                            apps.append({
                                "name": display_name,
                                "version": display_version,
                                "publisher": publisher,
                                "path": install_location
                            })
                        except:
                            pass
                        
                        winreg.CloseKey(subkey)
                        i += 1
                    except OSError:
                        break
                
                winreg.CloseKey(key)
            except:
                pass
    except:
        pass
    
    return apps


def get_process_list_enhanced() -> list:
    """获取增强的进程列表（Windows 特定）"""
    processes = []
    
    try:
        import psutil
        for proc in psutil.process_iter(['pid', 'name', 'username', 'cpu_percent', 'memory_percent']):
            try:
                processes.append({
                    "pid": proc.info['pid'],
                    "name": proc.info['name'],
                    "username": proc.info['username'],
                    "cpu_percent": proc.info['cpu_percent'],
                    "memory_percent": proc.info['memory_percent']
                })
            except:
                pass
    except:
        # 降级到 tasklist
        try:
            result = subprocess.run(
                ["tasklist", "/FO", "CSV"],
                capture_output=True,
                text=True,
                timeout=10
            )
            lines = result.stdout.strip().split("\n")
            for line in lines[1:]:  # 跳过标题
                parts = line.split(",")
                if len(parts) >= 2:
                    processes.append({
                        "pid": parts[1].strip('"'),
                        "name": parts[0].strip('"')
                    })
        except:
            pass
    
    return processes


def get_windows_services() -> list:
    """获取 Windows 服务列表"""
    services = []
    
    try:
        result = subprocess.run(
            ["sc", "query", "type=", "service"],
            capture_output=True,
            text=True,
            timeout=30,
            creationflags=subprocess.CREATE_NO_WINDOW
        )
        
        current_service = {}
        for line in result.stdout.split("\n"):
            line = line.strip()
            if line.startswith("SERVICE_NAME:"):
                if current_service:
                    services.append(current_service)
                current_service = {"name": line.split(":")[1].strip()}
            elif line.startswith("DISPLAY_NAME:"):
                current_service["display_name"] = line.split(":")[1].strip()
            elif line.startswith("STATE"):
                state = line.split(":")[-1].strip()
                current_service["state"] = state
        
        if current_service:
            services.append(current_service)
            
    except:
        pass
    
    return services


def manage_windows_service(service_name: str, operation: str) -> dict:
    """管理 Windows 服务"""
    valid_ops = ["start", "stop", "restart", "status", "enable", "disable"]
    
    if operation not in valid_ops:
        return {"success": False, "error": f"Invalid operation. Valid: {valid_ops}"}
    
    try:
        if operation == "status":
            result = subprocess.run(
                ["sc", "query", service_name],
                capture_output=True,
                text=True,
                timeout=10,
                creationflags=subprocess.CREATE_NO_WINDOW
            )
            return {
                "success": result.returncode == 0,
                "stdout": result.stdout,
                "stderr": result.stderr
            }
        
        elif operation == "start":
            result = subprocess.run(
                ["sc", "start", service_name],
                capture_output=True,
                text=True,
                timeout=30,
                creationflags=subprocess.CREATE_NO_WINDOW
            )
            return {
                "success": result.returncode == 0,
                "stdout": result.stdout,
                "stderr": result.stderr
            }
        
        elif operation == "stop":
            result = subprocess.run(
                ["sc", "stop", service_name],
                capture_output=True,
                text=True,
                timeout=30,
                creationflags=subprocess.CREATE_NO_WINDOW
            )
            return {
                "success": result.returncode == 0,
                "stdout": result.stdout,
                "stderr": result.stderr
            }
        
        elif operation in ["enable", "disable"]:
            config = "auto" if operation == "enable" else "disabled"
            result = subprocess.run(
                ["sc", "config", service_name, f"start= {config}"],
                capture_output=True,
                text=True,
                timeout=10,
                creationflags=subprocess.CREATE_NO_WINDOW
            )
            return {
                "success": result.returncode == 0,
                "stdout": result.stdout,
                "stderr": result.stderr
            }
        
        elif operation == "restart":
            # 先停止再启动
            stop_result = manage_windows_service(service_name, "stop")
            if stop_result.get("success"):
                import time
                time.sleep(2)
                return manage_windows_service(service_name, "start")
            else:
                return stop_result
        
    except Exception as e:
        return {"success": False, "error": str(e)}


def get_registry_value(key_path: str, value_name: str) -> dict:
    """读取注册表值"""
    try:
        import winreg
        
        # 解析根键
        root_keys = {
            "HKLM": winreg.HKEY_LOCAL_MACHINE,
            "HKCU": winreg.HKEY_CURRENT_USER,
            "HKCR": winreg.HKEY_CLASSES_ROOT,
            "HKU": winreg.HKEY_USERS,
            "HKCC": winreg.HKEY_CURRENT_CONFIG
        }
        
        parts = key_path.split("\\", 1)
        if parts[0] not in root_keys:
            return {"success": False, "error": "Invalid root key"}
        
        root_key = root_keys[parts[0]]
        sub_key = parts[1] if len(parts) > 1 else ""
        
        key = winreg.OpenKey(root_key, sub_key)
        value, value_type = winreg.QueryValueEx(key, value_name)
        winreg.CloseKey(key)
        
        return {
            "success": True,
            "value": value,
            "type": value_type
        }
    except Exception as e:
        return {"success": False, "error": str(e)}


def set_registry_value(key_path: str, value_name: str, value, value_type=winreg.REG_SZ) -> dict:
    """设置注册表值"""
    try:
        import winreg
        
        # 解析根键
        root_keys = {
            "HKLM": winreg.HKEY_LOCAL_MACHINE,
            "HKCU": winreg.HKEY_CURRENT_USER,
            "HKCR": winreg.HKEY_CLASSES_ROOT,
            "HKU": winreg.HKEY_USERS,
            "HKCC": winreg.HKEY_CURRENT_CONFIG
        }
        
        parts = key_path.split("\\", 1)
        if parts[0] not in root_keys:
            return {"success": False, "error": "Invalid root key"}
        
        root_key = root_keys[parts[0]]
        sub_key = parts[1] if len(parts) > 1 else ""
        
        key = winreg.CreateKey(root_key, sub_key)
        winreg.SetValueEx(key, value_name, 0, value_type, value)
        winreg.CloseKey(key)
        
        return {"success": True}
    except Exception as e:
        return {"success": False, "error": str(e)}


def add_to_startup(app_name: str, app_path: str) -> dict:
    """添加到开机启动"""
    try:
        import winreg
        
        startup_key = r"Software\Microsoft\Windows\CurrentVersion\Run"
        key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, startup_key, 0, winreg.KEY_SET_VALUE)
        winreg.SetValueEx(key, app_name, 0, winreg.REG_SZ, app_path)
        winreg.CloseKey(key)
        
        return {"success": True}
    except Exception as e:
        return {"success": False, "error": str(e)}


def remove_from_startup(app_name: str) -> dict:
    """从开机启动移除"""
    try:
        import winreg
        
        startup_key = r"Software\Microsoft\Windows\CurrentVersion\Run"
        key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, startup_key, 0, winreg.KEY_SET_VALUE)
        winreg.DeleteValue(key, app_name)
        winreg.CloseKey(key)
        
        return {"success": True}
    except:
        return {"success": False, "error": "Not found"}
