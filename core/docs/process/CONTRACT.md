# nextpas.core.process 代码契约

**模块路径**：`core/src/nextpas.core.process*.pas`（5 个源文件）
**层级**：L2（依赖 L0-L1: platform, text, io, time）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-11
**版本**：2.0

---

## 1. 接口契约

### 1.1 子模块

```
process.base        ← TStdio/TProcessStatus/TProcessOutput/EProcessError
process.command     ← ICommand builder（链式 API）
process.child       ← IChild 接口（Wait/Kill/TakeStdin...）
process.pipe        ← TPipeReader/TPipeWriter（IReader/IWriter over fd）
process.pathresolve ← PATH 搜索逻辑（ResolveExecutablePath）
process.pas         ← 门面（Run/RunIn/Capture/Command/LookPath）
```

### 1.2 核心函数

| 函数 | 说明 |
|------|------|
| `Command(APath): ICommand` | 创建命令构建器 |
| `Run(APath, AArgs): TProcessOutput` | 同步执行，捕获输出 |
| `RunIn(APath, AArgs, ADir): TProcessOutput` | 同步执行，指定工作目录 |
| `Capture(APath, AArgs): string` | 同步执行，只返回 stdout |
| `LookPath(AName): string` | 在 PATH 中搜索可执行文件 |
| `ICommand.Arg/Args/Dir/Env/EnvAdd` | 链式配置 |
| `ICommand.Spawn: IChild` | 异步启动子进程 |
| `ICommand.Output: TProcessOutput` | 同步执行并捕获 |
| `ICommand.Status: Integer` | 同步执行，只返回退出码 |
| `ICommand.Timeout(ADuration)` | 设置超时 |
| `IChild.Wait: TProcessOutput` | 阻塞等待 |
| `IChild.TryWait: Boolean` | 非阻塞检查 |
| `IChild.Kill` | 终止子进程 |
| `IChild.Detach` | 放弃生命周期管理 |
| `IChild.TakeStdin/Stdout/Stderr` | 取走管道 |
| `IChild.WaitWithOutput: TProcessOutput` | 并发读取 + 等待 |

---

## 2. 不变量

- **[INV-1]** IChild 释放时自动 Kill + Wait（防止僵尸进程）
- **[INV-2]** WaitWithOutput 用 poll(2) 同时读 stdout+stderr，避免死锁
- **[INV-3]** 子进程 exec 前关闭所有继承的 fd（close(3..1023)）
- **[INV-4]** EnvAdd 继承父进程环境并追加/覆盖；Env 完全替换
- **[INV-5]** Timeout 超时后自动 Kill + Wait

---

## 3. 错误处理

| 场景 | 异常 |
|------|------|
| 命令不存在 | EProcessError |
| exec 失败 | EProcessError |
| chdir 失败 | EProcessError |
| 参数含 NUL | EProcessError |
| 空命令路径 | EProcessError |

---

## 4. 线程安全

❌ 非线程安全。ICommand 和 IChild 的所有方法必须在同一线程调用。

---

## 5. 内存管理

- ICommand 和 IChild 都是 interface，引用计数自动管理
- TProcessOutput 的 StdOut/StdErr 为 string，调用方负责释放
- 管道 fd 在 IChild 释放时自动关闭

---

## 6. 测试覆盖

| 测试文件 | 测试数 | 说明 |
|----------|--------|------|
| test_process | 177 | 全面 API 测试（spawn/wait/env/timeout/pipe/lookpath） |
| test_process_command | 47 | ICommand builder 测试 |
| test_process_deep | 20 | 深度测试（timeout/large output/multiple） |
| test_process_pipe_contract | 17 | 管道契约测试（EINTR/EAGAIN/broken pipe） |
| **合计** | **4 个测试目录** | **261** |

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | Claude |
| 2026-07-11 | 2.0 | 更新为实际 API 和测试数据 | Claude |
