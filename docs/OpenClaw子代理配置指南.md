# OpenClaw 子代理配置指南

🤖 **多 Agent 协作系统配置和使用**

---

## 🎯 什么是子代理？

子代理（Sub-Agent）是 OpenClaw 的**多 Agent 协作系统**，允许：

- ✅ **并行处理** - 同时执行多个任务
- ✅ **分工合作** - 不同 Agent 负责不同领域
- ✅ **任务委派** - 主 Agent 分配任务给子 Agent
- ✅ **结果汇总** - 收集所有子 Agent 的结果

---

## 📋 配置子代理

### 方式一：使用 OpenClaw 配置（推荐）

编辑配置文件 `~/.openclaw/config.json`：

```json
{
  "agents": {
    "main": {
      "model": "qwencode/qwen3.5-plus",
      "enabled": true
    },
    "coder": {
      "model": "qwencode/qwen3.5-plus",
      "enabled": true,
      "specialty": "coding",
      "description": "负责代码编写和审查"
    },
    "researcher": {
      "model": "qwencode/qwen3.5-plus",
      "enabled": true,
      "specialty": "research",
      "description": "负责资料搜索和整理"
    },
    "tester": {
      "model": "qwencode/qwen3.5-plus",
      "enabled": true,
      "specialty": "testing",
      "description": "负责测试和验证"
    }
  },
  "subagents": {
    "enabled": true,
    "maxConcurrent": 3,
    "timeout": 300
  }
}
```

### 方式二：使用命令行

```bash
# 查看可用代理
openclaw agents list

# 添加子代理
openclaw agents add coder --model qwencode/qwen3.5-plus --specialty coding

# 启用子代理
openclaw agents enable coder

# 查看配置
openclaw agents status
```

---

## 🚀 使用子代理

### 方式一：在对话中委派

```
你：@coder 请帮我写一个 Python 文件传输模块
你：@researcher 请搜索最新的文件传输协议
你：@tester 请为这个模块编写测试用例
```

### 方式二：编程方式委派

```python
from openclaw import sessions_spawn

#  spawns 一个子代理处理编码任务
result = sessions_spawn(
    task="写一个 Python 文件传输模块，支持分块传输和哈希验证",
    agentId="coder",
    runtime="subagent",
    mode="run"
)

# 等待结果
await result
```

### 方式三：并行处理多个任务

```python
# 同时 spawns 多个子代理
tasks = [
    sessions_spawn(task="搜索文件传输协议", agentId="researcher"),
    sessions_spawn(task="设计 API 接口", agentId="coder"),
    sessions_spawn(task="编写测试计划", agentId="tester")
]

# 等待所有完成
results = await asyncio.gather(*tasks)
```

---

## 📊 子代理配置示例

### 完整配置文件

```json
{
  "agents": {
    "main": {
      "model": "qwencode/qwen3.5-plus",
      "enabled": true,
      "role": "coordinator"
    },
    "coder": {
      "model": "qwencode/qwen3.5-plus",
      "enabled": true,
      "role": "developer",
      "specialty": ["python", "javascript", "rust"],
      "maxTokens": 8192
    },
    "researcher": {
      "model": "qwencode/qwen3.5-plus",
      "enabled": true,
      "role": "analyst",
      "specialty": ["web_search", "data_analysis"],
      "tools": ["web_search", "web_fetch"]
    },
    "tester": {
      "model": "qwencode/qwen3.5-plus",
      "enabled": true,
      "role": "qa",
      "specialty": ["testing", "debugging"],
      "tools": ["exec", "read"]
    }
  },
  "subagents": {
    "enabled": true,
    "maxConcurrent": 5,
    "timeout": 600,
    "retryAttempts": 3,
    "streamTo": "parent"
  },
  "routing": {
    "coding": "coder",
    "research": "researcher",
    "testing": "tester",
    "default": "main"
  }
}
```

---

## 🎯 实际使用案例

### 案例 1：开发新功能

```
你：我要开发一个文件传输功能

@main 请协调以下任务：
1. @researcher 搜索现有的文件传输协议和最佳实践
2. @coder 基于调研结果设计并实现代码
3. @tester 编写单元测试和集成测试

请在 30 分钟内完成并汇总报告。
```

### 案例 2：代码审查

```
你：@coder 请审查这个 PR 的代码质量
你：@tester 请检查测试覆盖率
你：@main 请汇总审查报告并给出改进建议
```

### 案例 3：故障排查

```
你：系统出现性能问题

@researcher 搜索类似问题的解决方案
@coder 分析代码中的性能瓶颈
@tester 重现问题并定位根因

请协作找出问题并提供修复方案。
```

---

## 🔧 高级配置

### 自定义 Agent 角色

```json
{
  "agents": {
    "security_expert": {
      "model": "qwencode/qwen3.5-plus",
      "enabled": true,
      "role": "security_analyst",
      "specialty": ["security_audit", "vulnerability_assessment"],
      "system_prompt": "你是一个网络安全专家，负责审查代码安全性和系统漏洞。"
    },
    "devops": {
      "model": "qwencode/qwen3.5-plus",
      "enabled": true,
      "role": "devops_engineer",
      "specialty": ["deployment", "monitoring", "ci_cd"],
      "tools": ["exec", "docker", "kubernetes"]
    }
  }
}
```

### 任务路由规则

```json
{
  "routing": {
    "rules": [
      {
        "pattern": ".*(写代码 | 实现 | 开发|program|code).*",
        "agent": "coder"
      },
      {
        "pattern": ".*(搜索 | 查找 | 调研|research|search).*",
        "agent": "researcher"
      },
      {
        "pattern": ".*(测试 | 验证 | 检查|test|verify).*",
        "agent": "tester"
      },
      {
        "pattern": ".*(安全 | 漏洞 | 审计|security|audit).*",
        "agent": "security_expert"
      }
    ],
    "default": "main"
  }
}
```

---

## 📈 性能优化

### 并发控制

```json
{
  "subagents": {
    "maxConcurrent": 3,  // 最多同时运行 3 个代理
    "queueSize": 10,     // 任务队列大小
    "timeout": 300,      // 单个任务超时（秒）
    "retryAttempts": 2   // 失败重试次数
  }
}
```

### 资源限制

```json
{
  "agents": {
    "coder": {
      "maxTokens": 8192,    // 最大 token 数
      "timeout": 600,       // 超时时间
      "memoryLimit": "2GB"  // 内存限制（如果支持）
    }
  }
}
```

---

## 🐛 故障排查

### 查看子代理状态

```bash
# 列出所有子代理
openclaw subagents list

# 查看运行状态
openclaw subagents status

# 查看日志
openclaw logs --agent coder
```

### 常见问题

#### 1. 子代理无法启动

**原因**: 配置错误或资源不足

**解决**:
```bash
# 检查配置
openclaw config validate

# 查看可用资源
openclaw resources status
```

#### 2. 任务超时

**原因**: 任务太复杂或网络问题

**解决**:
```json
{
  "subagents": {
    "timeout": 600  // 增加超时时间
  }
}
```

#### 3. 结果丢失

**原因**: 子代理崩溃或通信失败

**解决**:
```json
{
  "subagents": {
    "retryAttempts": 3,
    "streamTo": "parent"  // 实时流式传输结果
  }
}
```

---

## 📚 API 参考

### sessions_spawn

```python
sessions_spawn(
    task: str,              # 任务描述
    agentId: str,           # 代理 ID
    runtime: str = "subagent",  # 运行时
    mode: str = "run",      # run 或 session
    timeout: int = 300,     # 超时时间（秒）
    streamTo: str = "parent" # 结果传输方式
)
```

### subagents 管理

```python
# 列出子代理
subagents(action="list")

# 终止子代理
subagents(action="kill", target="coder")

# 指导子代理
subagents(action="steer", target="coder", message="请优化代码性能")
```

---

## 🎓 最佳实践

1. **明确分工** - 每个子代理负责特定领域
2. **合理并发** - 不要同时运行太多子代理
3. **设置超时** - 避免任务无限期运行
4. **错误处理** - 设置重试机制
5. **结果汇总** - 主代理负责整合结果

---

**版本**: 1.0.0  
**更新日期**: 2026-03-19  
**维护者**: OpenClaw Team
