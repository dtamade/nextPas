# Go / Rust 生产级质量对标（net · async · io）

**日期**: 2026-07-20
**锚点**: main Q1–Q31（HE、DNS race、cancel、UDP、pool、benches、Windows candidate、Dial Control/Resolve/Family/AttemptResult）
**方法**: 质量属性对标（非 API 个数对齐）；代码 `rg` 交叉核对

## 1. 质量维度 D1–D8（Q31 后重估）

| ID | 维度 | Go / Tokio 标准 | nextpas 现状 | 分 (0–10) | 目标 |
|----|------|-----------------|--------------|-----------|------|
| D1 | 取消正确性 | Dial/IO 可取消、单完成 | Dial Token + **NetCancelFromAsync** | **8.5** | 9.0 |
| D2 | 超时竞态 | deadline 无双 fire | CAS TimeoutCtx；dial OverallDeadline | **8.5** | 9.0 |
| D3 | 双栈拨号 | Dialer DualStack HE | 严格 CAD + DNS race + AddressFamily 过滤 | **8.7** | 9.0 |
| D4 | 错误可判定 | net.Error Timeout/Temporary | **ClassifyNetError**（非 OpError 对象） | **8.0** | 8.5 |
| D5 | 平台证据 | CI 真 OS | Linux runtime；macOS kqueue fail-closed；Windows **candidate fail-closed** | **8.0** | 8.5 |
| D6 | 性能诚实 | 社区/自有 bench | async-bench-parity + dial sequential/concurrent metrics | **7.8** | 8.5 |
| D7 | API 可用性 | Dialer 一站式 | 选项面已扩（LocalAddr/Control/Resolve/Family/hooks/pool Ex） | **8.2** | 8.7 |
| D8 | 生命周期 | Close 清晰 | class loop + OnDiscard；0 leak 聚焦套件 | **9.0** | 9.0 |
| | **综合** | | | **~8.3** | **~8.7** |

## 2. 刻意不对齐

- Go `context.Value` 键值袋
- Tokio work-stealing 多线程 runtime / tower 生态
- 在 epoll/kqueue 上假实现 completion 文件 I/O
- Go 全量 `syscall.RawConn` Control（仅 fd 钩子子集）
- MPTCP

**契约**: 单线程 `TAsyncLoop` + `Post` 跨线程。

## 3. 能力差距摘要

### 拨号 / DNS（vs `net.Dialer`）

| 项 | 状态 |
|----|------|
| Token / OverallDeadline / HE CAD / DNS race / lab feed | 有 |
| LocalAddr | **Q25** |
| NoDelay / KeepAlive | **Q26** |
| Control (fd hook) | **Q27** subset |
| Custom Resolver | **Q28** OnResolve |
| AddressFamily filter | **Q30** |
| OnAttemptStart / OnAttemptResult | **Q31** |
| MPTCP | **deferred** |
| ClassifyNetError | **Q13** |

### 取消

| 项 | 状态 |
|----|------|
| IAsyncCancellationToken 树 | 有 |
| INetCancelToken 桥 | **Q14** NetCancelFromAsync |

### I/O 后端

| 后端 | 证据 |
|------|------|
| io_uring / epoll | linux-runtime |
| kqueue | macOS fail-closed + compile gate |
| IOCP | wine-runtime-smoke + **native-windows-candidate** (Q24B) |

### 产品面

| 项 | 状态 |
|----|------|
| Async UDP | **Q15** |
| Pool AcquireAsync / **AcquireAsyncEx** | **Q16 / Q29** |
| host benches / public HE opt-in | **Q18–Q23** |

## 4. 推荐路径

```
推荐: AsyncTcpDial / AsyncTcpDialAddrs
高级: OnResolve / AsyncTcpDialWithDnsFeed / AcquireAsyncEx
保留: AsyncTcpConnect          (HE-lite legacy)
错误: ClassifyNetError(code)
```

## 5. 证据分层

| 层 | 含义 |
|----|------|
| linux-runtime | 默认质量门 |
| macos-host-smoke | kqueue + dial/resolve fail-closed |
| wine-runtime-smoke | IOCP under Wine |
| native-windows-candidate | Q24B fail-closed async smoke（套件限定） |
| native-windows | **未宣称** 满血 |

## 6. 路线图

见 [ROADMAP-Q13.md](ROADMAP-Q13.md)。
