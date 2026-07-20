# Go / Rust 生产级质量对标（net · async · io）

**日期**: 2026-07-20  
**锚点**: main 起 Q1–Q12（HE CAD、DNS race、lab feed、macOS fail-closed）  
**方法**: 质量属性对标（非 API 个数对齐）；代码 `rg` 交叉核对

## 1. 质量维度 D1–D8

| ID | 维度 | Go / Tokio 标准 | nextpas 现状 | 分 (0–10) | 目标 |
|----|------|-----------------|--------------|-----------|------|
| D1 | 取消正确性 | Dial/IO 可取消、单完成 | Dial Token；**Q14 NetCancelFromAsync** 贯通阻塞 IO | **8.5** | 9.0 |
| D2 | 超时竞态 | deadline 无双 fire | CAS TimeoutCtx 成熟；dial OverallDeadline | 8.5 | 9.0 |
| D3 | 双栈拨号 | Dialer DualStack 默认 HE | AsyncTcpDial 严格 CAD + Stream race；Connect HE-lite | 8.5 | 9.0 |
| D4 | 错误可判定 | net.Error Timeout/Temporary | **ClassifyNetError**（Q13）；非 OpError 对象 | 7.5 | 8.5 |
| D5 | 平台证据 | CI 真 OS | Linux runtime；macOS kqueue+dial fail-closed；Windows wine | 7.5 | 8.5 |
| D6 | 性能诚实 | 社区/自有 bench | metric 行；无同 harness A/B | 7.0 | 8.0 |
| D7 | API 可用性 | Dialer 一站式 | Dial 推荐路径文档化；选项面仍窄 | 7.5 | 8.5 |
| D8 | 生命周期 | Close 清晰 | class loop + OnDiscard；0 leak 聚焦套件 | 9.0 | 9.0 |
| | **综合** | | | **~8.0** | **~8.7** |

## 2. 刻意不对齐

- Go `context.Value` 键值袋  
- Tokio work-stealing 多线程 runtime / tower 生态  
- 在 epoll/kqueue 上假实现 completion 文件 I/O  

**契约**: 单线程 `TAsyncLoop` + `Post` 跨线程。

## 3. 能力差距摘要

### 拨号 / DNS（vs `net.Dialer`）

| 项 | 状态 |
|----|------|
| Token / OverallDeadline / HE CAD / DNS race / lab feed | 有 |
| LocalAddr (bind-before-connect) | **Q25** family-matched subset |
| NoDelay / KeepAlive on win stream | **Q26** |
| Control / 自定义 Resolver / MPTCP | 无或未接线 |
| ClassifyNetError | **Q13** |
| AsyncTcpDial 为推荐默认（文档） | **Q13** |

### 取消（vs context / CancellationToken）

| 项 | 状态 |
|----|------|
| IAsyncCancellationToken 树 | 有 |
| INetCancelToken（阻塞 IO wake） | **Q14** NetCancelFromAsync 桥 |

### I/O 后端

| 后端 | 证据 |
|------|------|
| io_uring / epoll | linux-runtime |
| kqueue | macOS L0 fail-closed + compile gate |
| IOCP | wine-runtime-smoke；**非 native Windows** |

### 产品面

| 项 | 状态 |
|----|------|
| Async UDP | **Q15** |
| Pool × AsyncTcpDial | **Q16** AcquireAsync |
| kqueue accept/connect smoke | **Q17** |

## 4. 推荐路径（用户心智模型）

```
推荐: AsyncTcpDial / AsyncTcpDialAddrs
保留: AsyncTcpConnect          (HE-lite legacy)
高级: AsyncTcpDialWithDnsFeed  (lab / inject DNS)
错误: ClassifyNetError(code)   (Timeout/Canceled/Refused/…)
```

## 5. 证据分层

| 层 | 含义 |
|----|------|
| linux-runtime | 默认质量门 |
| macos-host-smoke | kqueue + dial/resolve fail-closed |
| wine-runtime-smoke | IOCP |
| native-windows | 未宣称 |

## 6. 路线图索引

见 [ROADMAP-Q13.md](ROADMAP-Q13.md)。旧 F 类正确性债见 `../async/RESEARCH-REPORT-2026-07-11.md`。
