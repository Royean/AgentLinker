# AgentLinker - Product Requirements Document

## 项目概述
AgentLinker 是一个 macOS 应用，用于管理和连接 OpenClaw Agent 设备。

## Must Have (P0)

### 1. 用户认证系统
- [ ] 用户登录界面（已有 LoginView，需要完善）
- [ ] 用户注册功能（已有 register 方法，需要完善）
- [ ] 密码重置功能
- [ ] Keychain 安全存储凭证（替换 UserDefaults mock）
- [ ] 会话管理和自动登录

### 2. 设备管理
- [ ] 设备列表展示（已有 DeviceRowView）
- [ ] 设备详情页面（已有 DeviceDetailView）
- [ ] 添加新设备（已有 AddDeviceView）
- [ ] 设备连接状态管理
- [ ] 设备删除功能

### 3. 主界面
- [ ] 内容视图（已有 ContentView 框架）
- [ ] 侧边栏导航
- [ ] 设备状态实时更新

### 4. 设置页面
- [ ] 设置视图（已有 SettingsView 框架）
- [ ] 用户账户设置
- [ ] 应用偏好设置
- [ ] 关于页面

## Should Have (P1)

### 5. 网络层
- [ ] API 客户端封装
- [ ] 错误处理
- [ ] 请求重试机制
- [ ] 离线模式支持

### 6. 数据持久化
- [ ] Core Data 或 SQLite
- [ ] 本地缓存
- [ ] 数据同步

## 技术栈
- SwiftUI
- Combine
- Keychain (Security framework)
- URLSession

## 验证条件
- [ ] `swift build` 编译成功
- [ ] `swift test` 测试通过
- [ ] 应用可以启动并运行
