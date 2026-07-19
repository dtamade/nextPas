# nextpas.core.process 代码契约

**模块路径**：`core/src/nextpas.core.process*.pas`（6 个源文件）
**层级**：L2（依赖 L0-L1: platform, text, io, time）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-19
**版本**：2.14

---

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
| `ProcessSucceeded(AOut): Boolean` | 非 TimedOut、非 OutputLimited 且 psExited 且 ExitCode=0 |
| `Run(APath, AArgs): TProcessOutput` | 同步执行，捕获输出（不检查 exit） |
| `RunChecked(APath, AArgs): TProcessOutput` | 同步执行，非成功退出抛 EProcessError |
| `Capture(APath, AArgs): string` | 同步执行，只返回 stdout（不检查 exit） |
| `MustCapture(APath, AArgs): string` | 同步执行返回 stdout；非成功退出抛 EProcessError |
| `LookPath(AName): string` | 在 PATH 中搜索可执行文件；含目录部分时校验可执行性 |
| `ICommand.Arg/Args/Dir/Env/EnvAdd` | 链式配置；EnvAdd 默认继承父环境（overlay） |
| `ICommand.Spawn: IChild` | 异步启动子进程 |
| `ICommand.Output: TProcessOutput` | 同步执行并捕获（含 TimedOut / OutputLimited） |
| `ICommand.Status: TProcessOutput` | 同步执行，**不捕获输出**；含 `TimedOut`/`ExitCode`/`Status`（对齐 Rust `status()`） |
| `ICommand.Timeout(ADuration)` | 设置超时；超时后 TimedOut=True 并 Kill |
| `ICommand.MaxOutput(ABytes)` | 限制 stdout+stderr 累计；<=0 不限制；超限 OutputLimited=True 并 Kill |
| `ICommand.MergeStderr` | stderr 与 stdout 共用写端；Output 的 StdOut 为交错流，StdErr 空 |
| `ICommand.ExtraFd` | 额外 fd 映射到子进程 3+（Go ExtraFiles；Unix） |
| `ICommand.Credential` | exec 前 setuid/setgid（Unix；Windows 不支持） |
| `ICommand.CancelToken` | 取消令牌；Wait/Output 路径 Kill 并置 `Cancelled` |
| `IChild.Wait: TProcessOutput` | 阻塞等待 |
| `IChild.TryWait: Boolean` | 非阻塞检查 |
| `IChild.Kill` | 终止子进程（SIGKILL） |
| `IChild.Signal(ASignal)` | 发送指定信号（如 SIGTERM=15） |
| `IChild.Detach` | 放弃生命周期管理 |
| `IChild.TakeStdin/Stdout/Stderr` | 取走管道（大输出流式路径） |
| `IChild.WaitWithOutput: TProcessOutput` | 并发读取 + 等待（全内存缓冲） |
| `IChild.WaitGraceful(AGrace)` | SIGTERM → grace 内 wait → 超时 Kill；TimedOut 表示走了 Kill |

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
- **[INV-10]** 未设置 `MaxOutput`（默认 0）时 `Run`/`Capture*`/`Output` 可耗尽内存；生产请显式 `.MaxOutput(N)`（非 bug）
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

**口径**：下表为 `make ... test` 的 suite 通过数（framework 报告的 tests / Check 聚合因 suite 而异）。**最后校准：2026-07-19**（以当次执行输出为准）。

| 测试目录 | 参考通过数 | 说明 |
|----------|-----------|------|
| test_process | 455 | R21 Cancel/ExtraFd/Credential + R19 表 |
| test_process_command | 48 | ICommand builder |
| test_process_deep | 20 | timeout/large output |
| test_process_pipe_contract | 17 | EINTR/EAGAIN/broken pipe |
| test_process_wine | wine-runtime-smoke **4 passed**（2026-07-19 本机） | Windows L2 under Wine；≠ 真 host |
| **合计** | **5 目录 / 532+ Unix** | 2026-07-19 R19 实测 Unix 全绿 + 0 leak |

---

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
