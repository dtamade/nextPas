# nextpas.core.async 代码契约

**模块路径**：`core/src/nextpas.core.async*.pas`（5 个源文件）
**层级**：L1（依赖 L0: base, sync）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-01
**版本**：1.0

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| async.base | 基础类型 |
| async.future | TFuture\<T\> 异步结果 |
| async.promise | TPromise\<T\> 可写结果 |
| async.task | TTask 轻量工作单元 |
| async.pas | 门面 |

### 1.2 核心类型

```pascal
TFuture<T> = record
  function Get: T;           // 阻塞等待
  function TryGet(out AValue: T): Boolean;
  function Wait(ATimeoutMs: UInt32 = 0): Boolean;
  function IsDone: Boolean;
  function IsCancelled: Boolean;
  procedure Cancel;
end;

TPromise<T> = record
  class function Create: TPromise<T>; static;
  procedure SetValue(const AValue: T);
  procedure SetError(const AError: Exception);
  procedure SetCancelled;
  function Future: TFuture<T>;
end;

TTask = record
  class function Run(AProc: TProc): TTask; static;
  procedure Wait;
  function IsDone: Boolean;
end;
```

---

## 2. 不变量

- **[INV-1]** TPromise 只能 set 一次（重复 set 抛 EInvalidState）
- **[INV-2]** TFuture.Get 阻塞直到值可用或取消
- **[INV-3]** Cancel 后 Get 抛 ECancelledError
- **[INV-4]** TFuture 为值类型 record，可安全拷贝（内部引用计数）

---

## 3. 错误处理

| 场景 | 异常 |
|------|------|
| Get 已取消的 Future | ECancelledError |
| Promise 重复 set | EInvalidState |
| Promise set 的异常 | 从 Get 重新抛出 |
| Wait 超时 | 返回 False |

---

## 4. 线程安全

| 类型 | 线程安全 | 说明 |
|------|----------|------|
| TFuture | ✅ | 内部同步 |
| TPromise | ✅ | SetValue 原子 |
| TTask | ✅ | Wait 可从任意线程 |

---

## 5. 内存管理

- TFuture 内部引用计数，最后一个引用释放时清理
- TPromise 拥有结果槽位
- TTask 的 Proc 通过闭包捕获

---

## 6. 测试覆盖

| 测试目录 | 说明 |
|----------|------|
| test_async_future | Future/Promise 基本操作 |
| test_async_cancel | 取消流程 |
| test_async_error | 异常传播 |
| test_async_task | TTask 操作 |
| test_async_timeout | 超时等待 |
| **合计** | **5 个测试目录** |

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | Claude |
