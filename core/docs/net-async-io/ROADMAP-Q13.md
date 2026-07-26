# ROADMAP Q13+（Go/Rust 质量波次）

**基线**: Q1–Q12 Landed；调研见 [GO-RUST-PARITY.md](GO-RUST-PARITY.md)

## 波次

| 波次 | 主题 | 退出标准 | 状态 |
|------|------|----------|------|
| **R** | 对标文档 + 记分卡 | GO-RUST-PARITY + 本文件 + SCORECARD 更新 | **本轮** |
| **Q13** | ClassifyNetError + Dial 推荐路径文档 | 单测 0 leak；CONTRACT 表 | **done** |
| **Q14** | 统一 IAsyncCancellationToken / INetCancelToken | `NetCancelFromAsync` + soak | **done** |
| **Q15** | Async UDP 最小面 | Bind/RecvFrom/SendTo + Timeout | **done** |
| **Q16** | Pool.AcquireAsync → AsyncTcpDial | Token + idle 校验 | **done** |
| **Q17** | 平台证据加深 | kqueue accept/connect；Windows native 评估 | **done** |
| **Q18** | 同机 Go/Rust bench 脚本 | SCORECARD 表；CI 不强制对照 | **done** |
| **Q19** | localhost dial 吞吐对照 | dial_ops_per_s + go peer | **done** |
| **Q20** | 并发 multi-dial 吞吐 | dial_concurrent_ops_per_s + go concurrent peer；Windows assessment 轻量 | **done** |
| **Q21** | 公网 DNS HE 统计样本 | opt-in `NEXTPAS_PUBLIC_DNS_HE=1`；metrics；非 CI 门 | **done** |
| **Q22** | Windows native async smoke 挂钩 | `async-windows-native-smoke.sh` + CI continue-on-error | **done** |
| **Q23** | 多 host 公网 HE 矩阵 | 3 host + v4/v6 attempt 分计；可选 PreferIPv6First 遍 | **done** |
| **Q24** | Windows fail-closed 就绪 | streak 观测 + **fail-closed 升格** | **done (A+B)** |
| **Q25** | Dial LocalAddr bind-before-connect | Go Dialer.LocalAddr subset；family match；0 leak | **done** |
| **Q26** | Dial NoDelay/KeepAlive 选项 | 成功 stream 回调前 best-effort 应用 | **done** |
| **Q27** | Dial OnControl | Go Control 子集；attempt 级 fail | **done** |
| **Q28** | Dial OnResolve | 自定义 Resolver via DnsFeed 契约 | **done** |
| **Q29** | Pool AcquireAsyncEx | 贯通 TAsyncTcpDialOptions | **done** |
| **Q30** | Dial AddressFamily 过滤 | dafAny/v4/v6 | **done** |
| **Q31** | Dial OnAttemptResult | attempt 结果可观测 | **done** |
| **Q32** | 门面 DnsFeed + 对标重估 | AsyncTcpDialWithDnsFeed re-export；D 轴 ~8.3 | **done** |
| **Q33** | Windows candidate 套件扩容 | dial/resolve/udp/pool/error/cancel 入 smoke | **done** |
| **Q34** | smoke 与 platform matrix 解耦 | FPC 安装成功即跑 async smoke | **done** |
| **Q35** | Windows 测试 cthreads 条件化 | `{$IFDEF UNIX}cthreads{$ENDIF}` 修编译 | **done** |
| **Q36** | net.tcp/udp 去 POSIX sockaddr 耦合 | TPlatformSockAddr only — win64 可编 dial/udp | **done** |
| **Q37** | async.tcp/udp Windows/macOS 可移植 | 去 accept4；async.udp TPlatformSockAddr | **done** |
| **Q38** | Windows smoke 诚实化 | STRICT 收窄 + suite timeout；dial/udp/pool soft | **done** |
| **Q39** | IOCP ConnectEx pre-bind | ConnectEx 前 wildcard bind + WSAGetLastError | **done** |
| **Q40** | IOCP datagram | AsyncSendTo/AsyncRecvFrom via WSASendTo/WSARecvFrom | **done** |
| **Q41** | Wake coalescing + bench 旗标诚实化 | post/channel 与 Go 同数量级；stress 3 新测试 0 leak | **done** |
| **—** | MPTCP | 见下文：不做的原因 | **deferred permanently (for now)** |
| **—** | full native-windows claim | 等 STRICT multi-week 绿 + soft 升 STRICT | **deferred** |

### 为何 MPTCP 不做

1. **无跨平台内核契约**：Linux 用 `IPPROTO_MPTCP`/`mptcp` socket；macOS/Windows 无对等稳定公开 ABI。
2. **非 Dial 默认路径**：Go 也只是 opt-in；强行默认会改变路径选择与失败语义。
3. **可观测/测试成本高**：需要多路径网卡/内核配置，CI 无法诚实 fail-closed。
4. **当前质量北极星**是 HE + cancel + Windows candidate 证据，不是 MPTCP 功能点。

若未来做：仅 Linux opt-in `DialOptions.Multipath`，默认 false，独立 lab 套件，永不进默认 CI 门。

### 为何 full native-windows 尚未宣称

1. claim 名 **native-windows** = 满血 host 对等；当前只能诚实标 **candidate**。
2. Q33 扩容后曾 **编不过**（cthreads + sockaddr POSIX 耦合）→ Q35/Q36 修编译；
   Q36 后 GHA 仍红：`accept4`（async.tcp）+ posix `sockaddr_in`（async.udp）→ **Q37** 修。
3. 升满血条件（assessment）：扩容 smoke **多周** step=success streak + 无 flaky + 文档矩阵对齐。
4. platform.watch 等 **非 async 套件** 仍可能让 job overall 红；Q34 已解耦 smoke 证据。

### Q37 细节

- `async.tcp`：同步试 accept 改为 `platform_socket_accept`（全平台），去掉 Linux-only `accept4`。
- `async.udp`：op 缓冲用 `TPlatformSockAddr` + `platform_sockaddr_ipv4` / `_extract`，去 `posix.base`。
- 验证：Linux dial/udp/pool/cancel/accept_connect 0 leak；Windows **编译** 通过。

### Q38 细节（GHA 证据驱动）

Q37 run `29755003106`：

| 套件 | 结果 |
|------|------|
| compile_gate / contract / poller / iocp / accept_connect / resolve / error_classify | PASS |
| dial | 3/19；成功路径 error≈−111 / stream nil |
| udp | Bind ok；Recv arm / timeout arm fail |
| pool | 挂死 >1h（无 suite timeout）→ cancel |
| cancel_bridge | 未跑到 |

动作：`async-windows-native-smoke.sh` STRICT 只含已绿项；dial/udp/pool/cancel 进 soft + 默认 120s `timeout`；文档 honesty。

### Q39 细节

MSDN：`ConnectEx` 要求 socket **已 bind**。Dial 无 LocalAddr 时 Linux `connect` 可隐式 bind，IOCP 路径却直接 `ConnectEx` → 失败映射为 dial −111 / stream nil。

修复：`TIocpReactor.AsyncConnect` 在 ConnectEx 前按目标族 bind `0.0.0.0:0` / `::`；已 bind（LocalAddr）时忽略 `WSAEINVAL`；错误码改用 `WSAGetLastError`。

UDP soft 仍待 IOCP `AsyncSendTo`/`AsyncRecvFrom`（poller 明确未实现）。

### Q40 细节

- `WSASendTo` / `WSARecvFrom` FFI
- `TIocpReactor.AsyncSendTo` / `AsyncRecvFrom` + poller `pbIocp` 接线
- 与 epoll 路径同样的回调契约（`AAddrLen` 指针 out for recvfrom）
- soft 套件仍报告；GHA 绿后再升 STRICT

### Q41 细节（wake coalescing）

痛点：post ~3.2e5 vs Go ~1.2e7（37×）。归因（strace 不可用，改代码路径推演 + 旗标 A/B 实验证实）：

1. **每 Post 一次 eventfd write**：`PostEx` = MPSC Enqueue + 无条件 `Wake`。
2. **每 Poll 两次 syscall**：无条件 `DrainWake`（eventfd read）+ 无条件 `FPoller.Poll`（epoll_wait(0)）。
3. **bench 旗标不对等**：`common.mk` 默认 `-gh` heaptrc 全量堆跟踪，Go/Rust peer 是 release。

修复（Go netpollBreak 协议）：

- `FWakeSignaled: Int32` 合并标志；`Wake` = `atomic_exchange(flag,1,seq_cst)=0` 才付 `platform_poller_wake`。
- 消费者睡前序（顺序强制）：DrainWake(fd) → `atomic_exchange(flag,0,seq_cst)` → DrainPending 重查 → 才 WaitForWake。两侧必须 RMW（防 StoreLoad 重排 lost wakeup；全交错已推演）。
- `Poll`/`Run` 热路径去 DrainWake（MPSC 队列是 truth；fd 只服务 WaitForWake 返回）。
- `FPoller.HasPending=false` 时跳过 Flush+Poll（4 后端 HasPending 均 O(1) 注册计数）。
- `async-bench-parity.sh` 改 release 旗标（`NEXTPAS_BENCH_FPC_FLAGS`，可覆写）；泄漏纪律仍归默认 `make test`。

归因表（post / channel，ops/s）：

| 配置 | post | channel |
|------|------|---------|
| 旧代码 + heaptrc（旧记分卡） | 2.9e5 | 4.1e5 |
| 旧代码 + release | 4.8e5 | 7.9e6 |
| 新代码 + heaptrc | 7.0e5 | 4.6e5 |
| **新代码 + release** | **~4–5.4e6** | **~7.7e6** |

结论：post 瓶颈 = syscall（合并贡献 ~11×）；channel 瓶颈 = heaptrc（旗标贡献 ~19×）。

新回归测试（test_async_stress 10–12）：PingPongWakeLatency（lost-wakeup 探测器，200 轮对睡眠 loop 单发 Post）、PollOnlyCrossThreadDrain（Poll 去 DrainWake 后队列即 truth）、StopDuringDeepSleep（跨线程 Stop 不被合并吞掉）。

已知次级成本（不动）：MPSC per-node New/Dispose——lockfree F-044 已证明池化为否定结果（FPC per-thread 堆即 TLS 池）。

### 待升 STRICT 条件

| soft 套件 | 阻塞 | 修复 |
|-----------|------|------|
| dial / pool | ConnectEx unbound | **Q39** |
| udp | 无 IOCP datagram | **Q40** |
| cancel_bridge | 依赖 stream bind + dial | Q39 后应连带改善 |

## Q13 细节

### ClassifyNetError

- 单元: `nextpas.core.net.errors`
- API: `ClassifyNetError(ACode)` → `TNetErrorClass`（Kind, Timeout, Temporary, Canceled, Code）
- 接受负码（dial 回调惯例）与正码（PLATFORM_ERR_*）
- 测试: `test_net_error_classify`

### Dial 产品默认

- 源码头注释 + CONTRACT：推荐 `AsyncTcpDial`，`AsyncTcpConnect` = HE-lite legacy
- LocalAddr：~~本轮跳过~~ → **Q25** bind-before-connect 已接线

### 不做

- 改回调签名为 INetError 对象（保留 Int32 + Classify）
- MPTCP / 完整 Dialer Control

## 依赖

```
R ──► Q13 ──► Q14 ──► Q15
              └─────► Q16
R ──► Q17 (证据，可并行)
R ──► Q18 (性能，可并行)
```

## 验证命令

```bash
make -C core/tests/nextpas.core.net/test_net_error_classify clean test
make -C core/tests/nextpas.core.net/test_net_async_dial clean test
bash core/scripts/async-host-matrix.sh
```
