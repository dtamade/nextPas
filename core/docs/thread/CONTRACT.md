# nextpas.core.thread 代码契约

**模块路径**：`core/src/nextpas.core.thread*.pas`（8 个源文件）
**层级**：L1（依赖 L0: base, sync）
**Owner**：Claude（AI 负责）
**最后更新**：2026-08-18
**版本**：1.1

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| thread.base | TThreadTask, TFutureState 基础类型 |
| thread.intf | IThreadPool, ICancellationToken, ICancellationSource 接口 |
| thread.pool | 线程池实现 |
| thread.future | TFuture 异步结果 |
| thread.cancel | 取消令牌实现 |
| thread.pas | 门面 |

### 1.2 核心接口

```pascal
IThreadPool = interface
  function Submit(ATask: TThreadTask): TFuture;
  procedure Shutdown;
  procedure ShutdownNow;
  function WorkerCount: Integer;
  function PendingCount: Integer;
end;

ICancellationSource = interface
  function Token: ICancellationToken;
  procedure Cancel;
end;

ICancellationToken = interface
  function IsCancellationRequested: Boolean;
  procedure Register(AProc: TProc);
end;
```

### 1.3 门面函数

```pascal
function ThreadPool(AWorkerCount: Integer = 0): IThreadPool;
// AWorkerCount=0 → CPU 核心数。使用建议（实测证据，2026-08-18）：
// 短请求/高频 handler 场景显式给小池（如 4-8）——44 逻辑核机上
// 0(=44) 池竞争劣化（只读 handler QPS 1508 vs 显式 4 的 2128，
// 2-16 区间持平，QPS 采样 100 并发/万请求）；重 IO/阻塞 handler
// 场景按需调大（池线程驻留阻塞 handler）。

function CancellationSource: ICancellationSource;
```

---

## 2. 不变量

- **[INV-1]** IThreadPool.Shutdown 等待所有已提交任务完成
- **[INV-2]** IThreadPool.ShutdownNow 中断正在等待的任务
- **[INV-3]** CancellationToken.Register 注册的回调在 Cancel 时被调用
- **[INV-4]** 线程池 Worker 数在创建时固定

---

## 3. 错误处理

| 场景 | 异常 |
|------|------|
| Shutdown 后 Submit | EInvalidState |
| 任务执行中抛异常 | 捕获并存储到 Future |
| Cancel 后等待 | ECancelledError |

---

## 4. 线程安全

| 类型 | 线程安全 | 说明 |
|------|----------|------|
| IThreadPool | ✅ | Submit/Shutdown 可并发 |
| ICancellationToken | ✅ | 原子读写 |
| ICancellationSource | ✅ | Cancel 可从任意线程 |
| TFuture | ✅ | Get 可从任意线程等待 |

---

## 5. 内存管理

- IThreadPool 拥有工作线程，Shutdown 释放
- TFuture 拥有结果槽位
- ICancellationSource 拥有回调列表

---

## 6. 测试覆盖

| 测试目录 | 说明 |
|----------|------|
| test_thread | 线程池基本功能 |
| test_thread_cancel | 取消令牌 |
| **合计** | **2 个测试目录** |

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | Claude |
| 2026-08-18 | 1.1 | 补充 ThreadPool(AWorkerCount) 使用建议（44 核实测：小池 4-8 优于 0(=44)） | Claude |
