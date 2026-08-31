# nextpas.core.process 代码契约

**模块路径**：`core/src/nextpas.core.process*.pas`（6 个源文件）
**层级**：L2（依赖 L0-L1: platform, text, io, time）
**Owner**：Claude（AI 负责）
**最后更新**：2026-08-31
**版本**：2.23

---

## 概要

进程生命周期管理:创建、等待与终止子进程,退出码与环境,信号处理;门面 `nextpas.core.process`(6 个源文件),依赖 L0–L1(platform/text/io/time)。

## 1. 接口契约

### 1.1 子模块

```
process.base        ← TStdio/TProcessStatus/TProcessOutput/EProcessError
process.command     ← ICommand builder（链式 API）
process.child       ← IChild 接口（Wait/Kill/TakeStdin...）
process.pipe        ← TPipeReader/TPipeWriter（IReader/IWriter over fd）
process.pathresolve ← PATH 搜索逻辑（ResolveExecutablePath）
process.pas         ← 门面（Run/RunIn/Capture/Command/LookPath/ProcessSucceeded）
```

### 1.2 核心函数

| 函数 | 说明 |
|------|------|
| `Command(APath): ICommand` | 创建命令构建器 |
| `ProcessSucceeded(AOut): Boolean` | 非 TimedOut/OutputLimited/Cancelled 且 psExited 且 ExitCode=0 |
| `cProcessDefaultMaxOutput` | **64 MiB**；缓冲型 free `Run*`/`Capture*` 默认 cap（U1） |
| `Run` / `RunChecked` / `Capture*` / `MustCapture*` | 缓冲路径默认套 64MiB；不检查 exit 的见 Capture 系列 |
| `LookPath` / `TryLookPath` / `Executable` | PATH / 本进程路径 |
| `ICommand.Arg/Args/Dir/Env/EnvAdd` | 链式配置；EnvAdd 默认继承父环境（overlay） |
| `ICommand.Spawn: IChild` | 异步启动子进程 |
| `ICommand.Output: TProcessOutput` | 同步捕获；含 TimedOut / OutputLimited / Cancelled |
| `ICommand.Status: TProcessOutput` | **不捕获**；StdOut/StdErr **恒空**；含 TimedOut/Cancelled |
| `ICommand.Timeout` / `MaxOutput` | MaxOutput：builder 默认 **0=无限**；<=0 不限制 |
| `ICommand.MergeStderr` | stderr 与 stdout 共用写端；合并流在 StdOut |
| `ICommand.ExtraFd` / `Credential` | Unix；Win fail-closed |
| `ICommand.CancelToken` / `NewProcessGroup` | 取消；进程组 / Job |
| `EProcessError` | ExitCode / TimedOut / OutputLimited / **Cancelled** |
| `IChild.Wait` / `TryWait` / `WaitWithOutput` / `WaitGraceful` | 等待与排水 |
| `IChild.Kill` / `Signal` / `KillTree` / `SignalTree` | 终止；Win Signal 有限 |
| `IChild.Detach` / `TakeStdin/Stdout/Stderr` | 生命周期 / 流式管道 |
| `IChild.ProcessGroupId` | 建组时 = Pid；否则 0 |

---

## 2. 不变量

- **[INV-1]** 未 Wait/Detach 的 `Destroy`：**尽力** try_wait → 仍 running 则 Kill + 有限 reap（约 5s）→ 超时 abandon 再 detach；**不保证**零僵尸。已 Waited/Detached 不 Kill。
- **[INV-2]** WaitWithOutput 用 poll(2) 同时读 stdout+stderr，避免死锁
- **[INV-3]** 子进程 exec 前关闭所有继承的 fd（close(3..1023)）
- **[INV-4]** EnvAdd 继承父进程环境并追加/覆盖；Env 完全替换
- **[INV-5]** Timeout 超时后自动 Kill + Wait，且 TProcessOutput.TimedOut=True
- **[INV-6]** LookPath/ResolveExecutablePath 对含目录部分的路径校验可执行性；未找到返回空/抛错
- **[INV-7]** ProcessSucceeded ⇔ (not TimedOut) and (not OutputLimited) and (not Cancelled) and (Status=psExited) and (ExitCode=0)
- **[INV-8]** MaxOutput 超限：停缓冲、Kill、OutputLimited=True（不伪装 TimedOut）
- **[INV-9]** 父保留管道端不可继承；Windows 用 PeekNamedPipe 并发 drain
- **[INV-10]** **MaxOutput（U1+U2）**：未调用 `MaxOutput` 时，缓冲路径（`Output` / 带管道的 `Spawn`→WaitWithOutput）默认 **`cProcessDefaultMaxOutput`（64 MiB）**。`MaxOutput(0)`=显式不限制；`MaxOutput(N>0)`=上限。门面 free `Run*`/`Capture*` 同默认。
- **[INV-11]** `MergeStderr` / `Capture*Combined`：子进程 stderr→stdout 同管道；合并流在 `StdOut`，`StdErr` 为空（时间交错，对齐 Go CombinedOutput）。**要求** `Stdout(stPiped)`（`.Output` / `Capture*Combined` 会强制）；非 piped 时 `Spawn` 抛 `EProcessError`。stdout piped 时 Merge 覆盖 `Stderr(stPiped/stInherit)`；与 `Stderr(stNull)` 冲突时 `Spawn` 抛 `EProcessError`。
- **[INV-12]** **FPC RTL 隔离 / 编译器无关**：`nextpas.core.process*` 源码与 process 测试套件不得 `uses` 裸 FPC RTL 单元（SysUtils/Classes/BaseUnix/Unix/Windows/…）；OS 能力仅经 `nextpas.core.platform.*` / 其他 core 模块。仅 `nextpas.core.system` 允许直接引用 FPC RTL。门禁：真实 uses 子句扫描（多行/末位单元），见 `core/tests/fpc_rtl_uses_scan.inc`。
- **[INV-13]** **管道与 Wait/TryWait**：`IChild` 仍持有 stdout/stderr 时：
  - `Wait` → **`WaitWithOutput`**（边 drain 边 reap），避免写满死锁与输出丢失；
  - `TryWait`：`platform_process_try_wait` **已 reap** 后若仍持管道 → **仅 `DrainPipePair`**，用已有结果 `FinishWaitResult`；**禁止**再 `WaitWithOutput`/二次 wait（否则 ECHILD）。
  - `TakeStdout`/`TakeStderr` 后由调用方排水，再 `Wait`/`TryWait`。
  - `Destroy`：尽力 Kill+reap（约 5s 上限），超时 abandon 再 detach，**不保证**零僵尸。

---

## 3. 错误处理

| 场景 | 异常 |
|------|------|
| 命令不存在 | EProcessError |
| exec 失败 | EProcessError |
| chdir 失败 | EProcessError |
| 参数含 NUL | EProcessError |
| 空命令路径 | EProcessError |
| RunChecked/MustCapture 非成功 | EProcessError |

---

## 4. 线程安全

❌ 非线程安全。ICommand 和 IChild 的所有方法必须在同一线程调用。

---

## 5. 内存管理

- ICommand 和 IChild 都是 interface，引用计数自动管理
- TProcessOutput 的 StdOut/StdErr 为 string，调用方负责释放
- 管道 fd 在 IChild 释放时自动关闭
- WaitWithOutput/Capture 全内存缓冲；大输出请用 TakeStdout 流式读

---

## 6. 测试覆盖

**口径**：下表为 `make ... test` 的 suite 通过数（framework `T.Test` cases）。**最后校准：2026-07-20 R28**。

| 测试目录 | 参考通过数 | 说明 |
|----------|-----------|------|
| test_process | **133** | U2 builder MaxOutput 三态 + Status 空输出 |
| test_process_command | **21** | R28 迁 nextpas.core.test（原 48 Check） |
| test_process_deep | **27** | timeout/large + R22 Cancel + R24 KillTree + R26 group |
| test_process_pipe_contract | **17** | EINTR/EAGAIN/broken pipe |
| test_process_wine | wine-runtime-smoke **11 passed**（M2-W3/W4） | 见 [WIN.md](./WIN.md)；≠ 真 host |
| **合计** | **5 目录 / 193+ Unix cases** | R28 framework cases + deep/pipe；0 leak |

---

## Windows / Unix 支持矩阵（M2）

完整一眼表：[WIN.md](./WIN.md)。摘要：

| 能力 | Linux/Unix | Windows | 失败形态 |
|------|------------|---------|----------|
| Spawn / Wait / Capture / Status | Done | Done（wine 最小生产集） | raise |
| Timeout / MaxOutput / CancelToken | Done | Done | 语义同 Host |
| NewProcessGroup / KillTree | setpgid + kill(-pg) | **Job Object**（M2-W2） | raise |
| ExtraFd（fd≥3） | Done | **UNSUPPORTED** | Spawn 前 **EProcessError** 明文 |
| Credential（uid/gid） | Done | **UNSUPPORTED** | Spawn 前 **EProcessError** 明文 |
| Signal（非 Kill） | Partial | Partial（Kill=Terminate） | 文档 |

**原则**：不 silent fail；矩阵与代码一致。

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | Claude |
| 2026-07-11 | 2.0 | 更新为实际 API 和测试数据 | Claude |
| 2026-07-19 | 2.1 | ProcessSucceeded 公开 + 测试数口径 + Status/大输出说明 | Claude |
| 2026-07-19 | 2.2 | MaxOutput/OutputLimited；Windows inherit+drain；Mkdir procedure 见 fs | Claude |
| 2026-07-19 | 2.3 | Status→TProcessOutput；INV-10 无界输出；L0 Win dual capture | Claude |
| 2026-07-19 | 2.4 | MergeStderr 真 Combined；Status/Output 文档；测试数校准 | Claude |
| 2026-07-19 | 2.5 | INV-12 FPC RTL 隔离；测试去 SysUtils/Classes；EINTR 测改 ThreadPool | Claude |
| 2026-07-19 | 2.6 | 真 uses 门禁 + MergeStderr/stNull 冲突；共享 fpc_rtl_uses_scan.inc | Claude |
| 2026-07-19 | 2.7 | INV-13 Wait 自动排水；MergeStderr 强制 piped；Destroy 5s 写实；测试数口径 | Claude |
| 2026-07-19 | 2.8 | INV-13 TryWait 持管道排水；Take* 责任钉死 | Claude |
| 2026-07-19 | 2.9 | INV-13 钉死 TryWait=drain-only（非 WaitWithOutput） | Claude |
| 2026-07-19 | 2.10 | INV-1 对齐 Destroy 5s abandon（非无限 Kill+Wait） | Claude |
| 2026-07-19 | 2.11 | WaitGraceful；测试 292 | Claude |
| 2026-07-19 | 2.12 | R17 质量表；测试 340 | Claude |
| 2026-07-19 | 2.13 | wine-runtime-smoke 实况 4/4 绿 | Claude |
| 2026-07-19 | 2.14 | R19 质量表；测试 447 | Claude |
| 2026-07-20 | 2.15 | R22 CancelToken 贯通 Wait/Status；WaitWithOutput 忙等修复；deep 24 | Claude |
| 2026-07-20 | 2.16 | R24 NewProcessGroup/KillTree；deep 26 | Claude |
| 2026-07-20 | 2.17 | R26 WaitGraceful×ProcessGroup；deep 27 | Claude |
| 2026-07-20 | 2.18 | R27 Capture stdout-only + WaitWithOutput drain 加速 | Claude |
| 2026-07-20 | 2.19 | M2-W2 Win Job Object NewProcessGroup/KillTree | Claude |
| 2026-07-20 | 2.20 | M2-W3 ExtraFd/Cred fail-closed；wine 11 | Claude |
| 2026-07-20 | 2.21 | M2-W4 WIN.md 交叉引用；wine 最小生产集口径 | Claude |
| 2026-07-20 | 2.22 | U1：cProcessDefaultMaxOutput 64MiB 便利层；EProcessError.Cancelled；test 130 | Claude |
| 2026-07-20 | 2.23 | U2：builder 未配置 MaxOutput→64MiB；MaxOutput(0) 无限；test 133 | Claude |
| 2026-08-31 | 2.23 | 时效刷新：批量校正至 2026-08-31，统一 AL1 口径 | core-docs |
