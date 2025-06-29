# Nakama 断线重连功能优化说明

## 功能概述

本次优化实现了完整的断线重连机制，包括：
- 自动检测网络断开
- 智能重连策略
- 请求队列缓存
- 重连成功后自动恢复失败的请求

## 主要特性

### 1. 自动断线检测
- 心跳检测机制（每15秒发送ping）
- 心跳超时自动触发重连
- Socket连接状态实时监控

### 2. 智能重连策略
- 指数退避重试算法
- 最大重试次数限制（5次）
- Session失效时自动重新登录

### 3. 请求队列管理
- 断线期间自动缓存失败的请求
- 重连成功后自动重试所有待处理请求
- 避免重复请求
- 单个请求最大重试次数限制（3次）

### 4. 网络错误分类
- 网络相关错误：自动重试
- 业务逻辑错误：直接显示错误信息

## 使用方法

### 发送RPC请求
```gdscript
# 使用优化后的sendDataRPC函数
var result = await Online.sendDataRPC("function_name", payload)
```

### 检查连接状态
```gdscript
# 获取连接状态信息
var status = Online.get_connection_status()
print("连接状态:", status)

# 获取待处理请求数量
var pending_count = Online.get_pending_requests_count()
print("待处理请求:", pending_count)
```

### 手动触发重连
```gdscript
# 手动触发重连
Online.manual_reconnect()
```

## 配置参数

```gdscript
const RECONNECT_INTERVAL := 15        # 重连检查间隔（秒）
const BASE_RETRY_DELAY := 3.0         # 基础重试延迟（秒）
const MAX_RETRY_DELAY := 15.0         # 最大重试延迟（秒）
const MAX_RETRY_COUNT := 5            # 最大重试次数
const PING_TIMEOUT := 10.0            # 心跳超时时间（秒）
const REQUEST_RETRY_LIMIT := 3        # 单个请求最大重试次数
```

## 工作流程

1. **正常连接状态**
   - 定期发送心跳包
   - 处理RPC请求
   - 监控连接状态

2. **检测到断线**
   - 将失败的请求加入队列
   - 触发重连机制
   - 显示断线提示

3. **重连过程**
   - 尝试恢复Session
   - 重新连接Socket
   - 重试次数限制

4. **重连成功**
   - 自动重试所有待处理请求
   - 恢复心跳检测
   - 显示连接成功提示

## 错误处理

### 网络错误（自动重试）
- "网络断开"
- "连接失败"
- "连接超时"
- "HTTPRequest failed!"
- "Invalid session."
- "Session expired."

### 业务错误（直接显示）
- 其他所有非网络相关错误

## 注意事项

1. 所有RPC请求都应该使用 `sendDataRPC` 函数
2. 重连过程中会显示相应的状态提示
3. 应用恢复焦点时会自动检查连接状态
4. 请求队列会在重连成功后自动清空

## 兼容性

- 保持与现有代码的兼容性
- 自动处理旧版本的错误处理方式
- 支持渐进式升级 