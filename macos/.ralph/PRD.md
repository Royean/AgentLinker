# AgentLinker macOS - 迭代开发 PRD

## 当前状态
- 已有基础框架：App 入口、ContentView、MenuBarView、SettingsView
- 已有服务：WebSocketManager、DeviceManager
- 已有模型：Device、Messages

## 本次迭代任务 (Must Have)

### 1. 完善用户认证
- [ ] 添加登录/注册界面
- [ ] 集成 Keychain 存储凭证
- [ ] 会话管理和自动登录

### 2. 完善设备管理
- [ ] 设备列表展示
- [ ] 设备详情和状态
- [ ] 添加/删除设备
- [ ] 设备配对流程

### 3. 完善 UI/UX
- [ ] 优化 ContentView 布局
- [ ] 添加加载状态和错误处理
- [ ] 完善设置页面选项

### 4. WebSocket 连接
- [ ] 完善连接状态管理
- [ ] 添加重连机制
- [ ] 消息处理和完善

## 验证条件
- `swift build` 编译成功
- 应用可以启动运行
- UI 组件完整可用

## 下一步 (Should Have)
- 单元测试
- UI 测试
- 打包成 DMG
- Sparkle 自动更新
