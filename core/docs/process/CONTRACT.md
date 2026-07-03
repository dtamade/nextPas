# nextpas.core.process 代码契约

**模块路径**：`core/src/nextpas.core.process*.pas`（6 个源文件）
**层级**：L3（依赖 L0-L2: fs, platform）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-01
**版本**：1.0

---

## 1. 接口契约

### 1.1 子模块

```
process.base       ← TProcessOptions, TProcessExitCode
process.exec       ← Exec/ExecCapture/ExecBackground
process.pipe       ← 管道通信 (stdin/stdout/stderr)
process.env        ← 环境变量管理
process.pas        ← 门面
```

### 1.2 核心函数

| 函数 | 说明 |
|------|------|
| `Exec(ACommand, AArgs)` | 同步执行，等待退出 |
| `ExecCapture(ACommand, AArgs): TProcessResult` | 执行并捕获 stdout+stderr |
| `ExecBackground(ACommand, AArgs): TProcessHandle` | 后台执行 |
| `WaitFor(AHandle): TProcessExitCode` | 等待后台进程 |
| `Kill(AHandle, ASignal)` | 发送信号 |
| `GetEnv(AName): string` | 获取环境变量 |
| `SetEnv(AName, AValue)` | 设置环境变量 |

---

## 2. 不变量

- **[INV-1]** Exec 等待子进程退出后返回
- **[INV-2]** ExecCapture 的 stdout/stderr 缓冲区无死锁（双线程读取）
- **[INV-3]** ExecBackground 返回句柄，调用方负责 WaitFor
- **[INV-4]** Kill 发送 SIGTERM (UNIX) 或 TerminateProcess (Windows)

---

## 3-6. 概要

- **错误**: 命令不存在抛 ENotFoundError; 信号失败抛 EIOError
- **线程安全**: ❌ 每个 TProcessHandle 独立操作; GetEnv/SetEnv ❌
- **内存**: ExecCapture 的 stdout/stderr 为 string, 调用方管理
- **测试**: 4 个测试目录

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | Claude |
