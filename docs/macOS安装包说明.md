# macOS 安装包说明

## 📦 当前 DMG 的问题

你下载的 `AgentLinker_2.0.0_macOS.dmg` 打开后看到的是文件夹结构，这是因为：

**原因：**
- 这个 DMG 是直接从 `/opt/agentlinker` 目录创建的
- 它只是一个简单的压缩包，不是专业的安装包
- 没有图形化安装界面

**打开后你会看到：**
```
AgentLinker_2.0.0_macOS/
├── client/
├── server/
├── installer/
├── docs/
└── ... (源代码和脚本)
```

---

## ✅ 解决方案：创建专业安装包 (.pkg)

在你的 Mac 上运行以下命令创建专业的安装包：

### 方法一：使用 pkgbuild（推荐）

```bash
# 打开终端，运行：

mkdir -p /tmp/pkg-root/opt/agentlinker
cp -r /opt/agentlinker/* /tmp/pkg-root/opt/agentlinker/

pkgbuild --root /tmp/pkg-root \
    --identifier com.agentlinker.client \
    --version 2.0.0 \
    --install-location / \
    ~/Desktop/AgentLinker_2.0.0.pkg

echo "✅ 安装包创建完成：~/Desktop/AgentLinker_2.0.0.pkg"
```

### 方法二：使用脚本自动创建

```bash
# 创建脚本
cat > ~/Desktop/create-installer.sh << 'EOF'
#!/bin/bash
set -e

echo "🍎 正在创建专业安装包..."

# 准备包内容
PKG_ROOT="/tmp/AgentLinker-Pkg"
mkdir -p "$PKG_ROOT/opt/agentlinker"
cp -r /opt/agentlinker/* "$PKG_ROOT/opt/agentlinker/"

# 创建 pkg
pkgbuild --root "$PKG_ROOT" \
    --identifier com.agentlinker.client \
    --version 2.0.0 \
    --install-location / \
    ~/Desktop/AgentLinker_2.0.0.pkg

# 清理
rm -rf "$PKG_ROOT"

echo ""
echo "✅ 专业安装包创建完成！"
echo "位置：~/Desktop/AgentLinker_2.0.0.pkg"
ls -lh ~/Desktop/AgentLinker_2.0.0.pkg
EOF

chmod +x ~/Desktop/create-installer.sh

# 运行脚本
~/Desktop/create-installer.sh
```

---

## 🎯 专业安装包的特点

创建后的 `.pkg` 文件会有：

### ✅ 图形化安装界面
```
┌─────────────────────────────┐
│  欢迎使用 AgentLinker       │
│                             │
│  本程序将安装到您的电脑     │
│                             │
│  [ 继续 ]  [ 取消 ]         │
└─────────────────────────────┘
```

### ✅ 许可协议
- MIT License 展示
- 用户需要同意

### ✅ 安装位置选择
- 默认安装到 `/opt/agentlinker`
- 可以更改位置

### ✅ 进度条
```
安装中...
[████████████░░░░] 60%
```

### ✅ 安装完成
```
安装成功！
AgentLinker 已安装完成。

[ 关闭 ]
```

---

## 📋 安装后的使用

安装 `.pkg` 后：

```bash
# 1. 配置文件
sudo nano /etc/agentlinker/config.json

# 2. 启动服务
sudo launchctl start com.agentlinker.client

# 3. 查看状态
launchctl list | grep agentlinker

# 4. 查看日志
tail -f /var/log/agentlinker/agentlinker.log
```

---

## 🔍 对比

| 特性 | DMG (当前) | PKG (专业) |
|------|-----------|-----------|
| 安装界面 | ❌ 文件夹 | ✅ 图形化向导 |
| 安装方式 | 手动复制 | ✅ 自动安装 |
| 系统服务 | ❌ 需手动配置 | ✅ 自动配置 |
| 卸载 | ❌ 手动删除 | ✅ 可卸载 |
| 用户体验 | ⭐⭐ | ⭐⭐⭐⭐⭐ |

---

## 💡 建议

**现在：**
1. 在 Mac 上运行上面的脚本创建 `.pkg` 安装包
2. 双击 `.pkg` 文件进行专业安装

**未来发布：**
- 使用 `productbuild` 创建带签名的安装包
- 提交到 App Store 或 Homebrew

---

**创建时间**: 2026-03-19  
**版本**: v2.0.0
