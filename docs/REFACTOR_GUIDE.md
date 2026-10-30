# 代码重构规范（上一轮，已完成）

> 历史文档：记录上一轮重构的约束与验证方式，保留作参考。
> 新增子游戏请看 [GAME_DEVELOPMENT.md](GAME_DEVELOPMENT.md)，整体分层见 [ARCHITECTURE.md](ARCHITECTURE.md)。

> 目标：在**不丢失主体功能**的前提下，让代码更简洁、易读、层次清晰，并补齐中文注释。
> 本文件只用于本轮重构，完成后可删除。

## 一、硬性约束

1. **只改分配给你的文件**。不要改 `addons/`、`gdprotobuf/`、`project.godot`、`.tscn`、`assets/`。
2. **保持对外契约不变**：
   - 公开方法名、参数顺序、返回值语义；
   - `signal` 名称与参数；
   - `@export` / `@onready` 变量名；
   - `@onready` 里的节点路径（`$A/B/C`）一律不改；
   - 脚本 `extends` 的基类不改（除非文件本身就是基类）。
   > 场景文件里通过 `signal`/方法名绑定，改名会直接断掉功能。
3. **不引入新依赖**：继续使用现有的 `Global.X` 服务、`Util`、`SignalMgr`。
4. **不新增自动加载（autoload）**，不改 `project.godot`。
5. **保留业务行为**：可以合并重复逻辑、删掉死代码/注释掉的旧实现，但不能改变“用户能看到/能操作”的流程。
6. 如果发现接口本身有 Bug（例如调用了不存在的方法），可以修，但要在汇报里写明。

## 二、风格要求

### 文件头（每个 `.gd` 必加，放在 `extends` 之后）

```gdscript
## 模块：聊天消息列表
## 职责：维护当前频道的消息缓存、时间分隔线、消息控件复用。
## 依赖：Global.DataMgr / Global.OnlineChat / Util。
## 对外：add_message()、refresh_current_channel_display()、clear_messages_item()。
```

### 方法注释

- 对外/复杂方法用 `##` 写 1~3 行说明“做什么、参数含义、返回值/副作用”。
- 简单 getter/setter 不必逐行注释。
- 易错逻辑（异步、索引、缓存、协议字段）用普通 `#` 就近说明。

### 代码

- 优先早返回（guard clause），减少 `if` 嵌套。
- 合并重复分支；用 `match` 替代长 `if/elif`。
- 删除：整段注释掉的旧代码、`print("进入函数")` 之类无信息日志、未使用的变量/常量。
- 保留：`push_error` / `push_warning` 和真正有用的错误日志。
- 变量尽量加类型；不确定类型时不要强行标注，避免 `Variant` 推断报错。
- 不写超长函数：超过约 80 行时，拆出语义明确的私有方法（`_xxx`）。
- 注释用中文；专有名词（Nakama、RPC、Socket）保留英文。

## 三、验证方式

每改完一个文件，至少做一次语法检查：

```powershell
& 'C:\Users\po265\Desktop\Godot_v4.7.2-stable_win64.exe' --headless --path . --check-only --script res://相对/路径.gd
```

- 退出码可能因 GDExtension 缺失而为 0/1，**重点看输出里有没有 `SCRIPT ERROR` / `Parse Error`**。
- 最后再跑全项目导入检查（由主代理统一执行）：

```powershell
& 'C:\Users\po265\Desktop\Godot_v4.7.2-stable_win64.exe' --headless --path . --editor --quit
```

## 四、Godot 4.7 异步注意事项

- 4.7 中**异步函数必须用 `await` 调用**；不能先拿到返回值再 `await result.completed`。
- 动态调用异步方法要写成：`var r = await obj.callv("method", args)`。
- `NakamaAsyncResult` 用 `r.is_exception()` / `r.get_exception().message` 判断错误。
- 不要对可能为 `null` 的对象直接取成员。

## 五、汇报格式

完成后回复：

1. 改了哪些文件（路径列表）；
2. 每个文件做了什么（1 行）；
3. 修掉的 Bug（如有）；
4. 未能完成/有风险的点。
