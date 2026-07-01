# nextpas.core.async 代码契约

**模块路径**：`core/src/nextpas.core.async*.pas`（5 个源文件）
**层级**：L1（依赖 L0: base, sync）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-01
**版本**：1.0

---

## 1. 接口契约

### 1.1 核心类型

| 类型 | 文件 | 说明 |
|------|------|------|
| TFuture\<T\> | future.pas | 异步结果句柄 (Get/Wait/Cancel) |
| TPromise\<T\> | promise.pas | 可写异步结果 (SetValue/SetError) |
| TTask | task.pas | 可调度工作单元 |
| TExecutor | executor.pas | 线程池执行器 |

### 1.2 核心 API

```pascal
TTask = record
  class function Run(AProc: TProc): TTask; static;
  procedure Wait;
  function IsDone: Boolean;
end;

TExecutor = class
  constructor Create(AWorkers: SizeInt = 0);
  function Submit(AProc: TProc): TFuture<T>;
  procedure Shutdown;
end;
```

---

## 2. 不变量

- **[INV-1]** Future.Get 阻塞直到值可用或取消
- **[INV-2]** Promise 只能 set 一次（重复 set 抛 EInvalidState）
- **[INV-3]** Executor.Shutdown 等待所有已提交任务完成

---

## 3-6. 概要

- **错误**: 取消时 Future.Get 抛 ECancelledError; 超时抛 ETimeoutError
- **线程安全**: Future/Promise ✅; Executor ✅
- **内存**: 任务队列 + 工作线程; Shutdown 释放所有资源
- **测试**: 5 个测试目录

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | Claude |
