# nextpas.core.net.maintenance

通用连接维护策略与调度（L1 策略 + L2 调度）。

**层级**：L2（`net.maintenance` 门面；策略子单元 L1 能力仅依赖 `time` 单调时钟）
**Owner**：`net` / `ssh` 协同（S15 P2-2）
**最后更新**：2026-09-02

## 职责

从 `nextpas.core.ssh.rekey / keepalive(.scheduler)` 抽离的通用记录：

* **Rekey 策略** `TRekeyPolicy`（`nextpas.core.net.maintenance.rekey`，L1）：按字节数 / 时间双阈值触发重协商/密钥轮换，`TInstant` 单调时钟，`0` 禁用该维度，`Account` 累计载荷，`ShouldRekey(AEncrypted)` 单点判断，消 sync/async 双实现漂移。
* **KeepAlive 策略** `TKeepAlivePolicy`（`nextpas.core.net.maintenance.keepalive`，L1）：周期心跳 `ShouldSend` 基于 `Elapsed >= IntervalMs`，`IntervalMs<=0` 禁用。
* **KeepAlive 调度器** `TKeepAliveScheduler`（`nextpas.core.net.maintenance.scheduler`，L2）：`record + TAsyncLoop` 缝隙，委托 `TKeepAlivePolicy` 单源，`Schedule/Cancel` 仅单次 `ScheduleMethod/CancelTimer` 注册，零轮询、零堆分配，`FActive+IsValid` 幂等，适配 `TAsyncLoop.Close` 竞态。

**四件套**：`base ← rekey/keepalive ← scheduler ← 门面`；`base` 仅常量；无 `intf/ffi`（record 值语义，无接口/FFI）。

**门面**：`nextpas.core.net.maintenance` 纯 re-export，开箱 `uses nextpas.core.net.maintenance`。

## 分层与依赖

* `base`：无依赖，常量 `NET_REKEY_* / NET_KEEPALIVE_*`
* `rekey/keepalive`：`time.base.TInstant/TDuration`（L1），不依赖 `SysUtils/GetTickCount64`
* `scheduler`：`keepalive` + `async.base/loop`（L1），L2 调度
* 上层仅依赖 L0-L1；禁止向上/同层循环。

## 复用点

* `ssh.transport.core / transport.async` 复用 `TRekeyPolicy`
* `ssh.session.async` 复用 `TKeepAliveScheduler`（`ScheduleKeepAlive/Cancel` 委托）
* 预留：`tls/quic` key phase 轮换、`http` PING 心跳

## 性能

* `record` 零堆，`Init/Reset/Account/ShouldRekey/ShouldSend/Schedule/Cancel` 全 `inline` 薄转发；真实调度回调外联，防 I-Cache 膨胀。
* `bytes.ops` 单源由调用方零拷贝 `Move` 保证，本模块不自实现拷贝。

## 不变量

* `ShouldRekey` 仅当 `AEncrypted=True` 评估；任一维度达阈值即 `True`。
* `ShouldSend` 以 `TInstant.Elapsed.AsMilliseconds` 单调时钟度量，不受系统时钟跳变影响。
* `Scheduler.Cancel` 幂等，`FHandle.IsValid` 守卫 + `try/except` 吞 `CancelTimer` 关闭竞态。

## 兼容

* `nextpas.core.ssh.rekey / keepalive / keepalive.scheduler` 已转为薄门面 `type ... = net.maintenance.*` alias，历史 `TSshRekeyPolicy/TKeepAlivePolicy/TKeepAliveScheduler` 零改动可用，新代码请 `uses nextpas.core.net.maintenance`。
