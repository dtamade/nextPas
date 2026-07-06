# nextpas.core.async — 跨平台异步运行时

> **层级:** L1
> **目标:** 跨平台单线程异步事件循环，支持 I/O + Timer
> **回退策略:** io_uring → epoll → kqueue → IOCP

## 跨平台后端架构

```
nextpas.core.async.pas                    ← facade
nextpas.core.async.base.pas               ← TAsyncContext, TAsyncTaskState, callback types
nextpas.core.async.intf.pas               ← IAsyncTask<T>, IAsyncPromise<T>
nextpas.core.async.timer.pas              ← min-heap timer
nextpas.core.async.task.pas               ← task/promise 实现
nextpas.core.async.loop.pas               ← TAsyncLoop (统一 API)

nextpas.core.io.reactor.pas               ← reactor facade (选择后端)
nextpas.core.io.reactor.epoll.pas         ← epoll 后端 (Linux 2.6+, 通用)
nextpas.core.io.reactor.uring.pas         ← io_uring 后端 (Linux 5.1+, 已有)
nextpas.core.io.reactor.kqueue.pas        ← kqueue 后端 (macOS/BSD, Phase 4)
nextpas.core.io.reactor.iocp.pas          ← IOCP 后端 (Windows, Phase 5)
```

## 后端选择策略

```pascal
{$IFDEF LINUX}
// 运行时检测: 尝试 io_uring_setup, 失败则用 epoll
function SelectReactorBackend: TReactorBackend;
begin
  if TryIoUringSetup then
    Result := rbIoUring
  else
    Result := rbEpoll;
end;
{$ENDIF}
{$IFDEF DARWIN}
  Result := rbKqueue;
{$ENDIF}
{$IFDEF WINDOWS}
  Result := rbIocp;
{$ENDIF}
```

## 实施顺序

### Phase 1: epoll reactor (Linux 通用回退)
- 实现 TEpollReactor (与现有 TIoReactor 相同 API)
- AsyncRead/Write/Accept/Connect/Send/Recv/Close
- Poll/PollOne/Run/Stop
- 测试: 与 io_uring reactor 相同的 7 个测试
- 这确保所有 Linux 系统都能运行

### Phase 2: 统一 reactor 接口
- 重构 io.reactor.pas 为 facade
- 运行时检测 io_uring 可用性
- 回退到 epoll
- 现有测试不变

### Phase 3: async 核心 (timer + task + loop)
- async.base/intf/timer/task/loop
- TAsyncLoop 建立在统一 reactor 之上
- Schedule/Sleep/Spawn/Await
- I/O with deadline

### Phase 4: kqueue (macOS)
- 实现 TKqueueReactor
- 编译时 {$IFDEF DARWIN} 选择

### Phase 5: IOCP (Windows)
- 补充 Windows FFI (CreateIoCompletionPort 等)
- 实现 TIocpReactor
- 编译时 {$IFDEF WINDOWS} 选择

## 质量门禁
- 每个后端独立测试 (7+ tests)
- heaptrc 零泄漏
- 基准对照 (Go net, Rust tokio)
- epoll 后端性能不低于 Go net
