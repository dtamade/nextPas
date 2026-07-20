# nextpas.core.process

L2 进程执行模块。提供类似 Go `os/exec` 和 Rust `std::process::Command` 的子进程管理能力。

**开发地图（Host 完成 / Win 里程碑 / 禁止无限 Rxx）**：[`ROADMAP.md`](./ROADMAP.md)  
**Go/Rust 对标矩阵**：见 [`PARITY-go-rust.md`](./PARITY-go-rust.md)（含 fs/path/env）。  
**证据 / scorecard**：见 [`SCORECARD.md`](./SCORECARD.md)。

> **Host Linux Essential 已完成（Maintenance）**。新需求须贴标签，见 ROADMAP §5。

## 快速开始

```pascal
uses nextpas.core.process;

// 推荐默认路径（新代码）
var Out := RunChecked('/bin/echo', ['hello']);  // 失败抛 EProcessError
if ProcessSucceeded(Out) then WriteLn(Out.StdOut);

var Text := MustCapture('/usr/bin/fpc', ['--version']);

var Builder := Command('/usr/bin/fpc')
  .Args(['--version'])
  .Timeout(TDuration.FromSeconds(30))
  .MaxOutput(1024 * 1024);  // 生产推荐：限制 stdout+stderr 累计字节
var Timed := Builder.Output;
if Timed.TimedOut then ...
if Timed.OutputLimited then ...

// Status 返回完整 TProcessOutput（不捕获 stdout/stderr，含 TimedOut）
var St := Command('/bin/true').Status;
if ProcessSucceeded(St) then ...

// 超时便利函数
var Timed2 := RunTimeout('/bin/sleep', ['10'], TDuration.FromMilliseconds(100));
if Timed2.TimedOut then
  WriteLn('timed out');

// PATH 查找
var FpcPath := LookPath('fpc');
if not TryLookPath('/no/such/bin', FpcPath) then
  WriteLn('missing absolute path rejected');
```

### 便利函数示例（兼容保留，新代码优先 builder）

```pascal
// Capture 不检查退出码；需要失败即错用 MustCapture
// 注意：Run/Capture* 默认无 MaxOutput 上限，海量子进程输出可导致 OOM（INV-10）
var Text := Capture('/usr/bin/fpc', ['--version']);
var Combined := CaptureCombined('/bin/sh', ['-c', 'echo out; echo err >&2']);
// Combined：stderr 重定向到 stdout 管道，按写入时间交错（对齐 Go CombinedOutput）
var Out2 := RunIn('/bin/ls', ['-la'], '/tmp');
var Out3 := RunWithInputString('/bin/cat', [], 'hello');
var ExePath := Executable;
```

## Status vs Output

| | `Status` | `Output` |
|--|----------|----------|
| 管道 | 不强制 piped | 强制 stdout+stderr Piped（或 Merge 单管道） |
| `TimedOut` | ✓ | ✓ |
| `OutputLimited` | 恒 False（不读输出） | ✓（若设了 MaxOutput） |
| `StdOut` / `StdErr` | 空 | 有内容 |
| 用途 | 只要退出/超时 | 捕获输出 |
| 成功判定 | `ProcessSucceeded(cmd.Status)` | `ProcessSucceeded(cmd.Output)` |

```pascal
// 合并流（builder）
var Merged := Command('/bin/sh')
  .Args(['-c', 'printf A; printf B >&2; printf C'])
  .MergeStderr
  .Output;
// Merged.StdOut = 'ABC'; Merged.StdErr = ''
```

## Builder 模式

```pascal
uses nextpas.core.process, nextpas.core.process.command;

var Out := Command('/usr/bin/fpc')
  .Args(['--version'])
  .Dir('/tmp')
  .Env(['PATH=/usr/bin', 'HOME=/tmp'])
  .Stdout(stPiped)
  .Stderr(stPiped)
  .Output;

WriteLn('exit: ', Out.ExitCode);
WriteLn('stdout: ', Out.StdOut);
WriteLn('stderr: ', Out.StdErr);
```

## 异步执行（Spawn + Wait）

```pascal
uses nextpas.core.process, nextpas.core.process.child;

var Child := Command('/bin/sleep').Arg('5').Spawn;
WriteLn('pid: ', Child.Pid);

// 非阻塞检查
var Done: TProcessOutput;
if not Child.TryWait(Done) then
  WriteLn('still running...');

// 发送信号（SIGTERM=15 优雅终止）
Child.Signal(15);

// 或强制终止（SIGKILL）
Child.Kill;
var Result := Child.Wait;
```

## 流式 I/O（管道）

```pascal
uses nextpas.core.process, nextpas.core.process.child, nextpas.core.process.pipe;

var Child := Command('/bin/cat')
  .Stdin(stPiped)
  .Stdout(stPiped)
  .Spawn;

// 写入子进程 stdin
var Stdin := Child.TakeStdin;
Stdin.Write(PAnsiChar('hello')^, 5);
(Stdin as TPipeWriter).Close;
Stdin := nil;

// 读取子进程 stdout
var Result := Child.WaitWithOutput;
WriteLn(Result.StdOut);  // "hello"
```

## Stdio 模式

| 模式 | 行为 |
|------|------|
| `stInherit` | 子进程继承父进程的 fd（默认） |
| `stPiped` | 创建管道，可通过 IReader/IWriter 访问 |
| `stNull` | 重定向到 /dev/null |

每个流（stdin/stdout/stderr）可独立配置。

## 平台支持

| 层 | Unix (Linux/macOS) | Windows |
|----|--------------------|---------|
| L2 `nextpas.core.process` | ✅ 一等支持 | ✅ L2 路径可用；证据 `truth=wine-runtime-smoke`（≠ 真 Windows host） |
| L0 `platform.process` | ✅ | ✅ CreateProcess / 管道 / Kill |

**Windows 精确限制**

- 无 POSIX 信号语义：`Signal` 仅 `SIGKILL(9)` → `TerminateProcess`；其它信号返回 unsupported
- 管道：父端句柄清 inherit + `PeekNamedPipe` 并发 drain（避免双流死锁）
- PATHEXT / LookPath 已支持
- 验证：`make -C core/tests/nextpas.core.process/test_process_wine wine-runtime-smoke`（2026-07-20 R26 本机 **7 passed**；truth=wine-runtime-smoke）

## 推荐 API 分层（避免便利函数爆炸）

| 场景 | 推荐 | 说明 |
|------|------|------|
| 完整控制 | `Command(...).Args.Dir.EnvAdd.Timeout.MaxOutput.Spawn/Output` | 唯一完整入口 |
| 同步拿输出 | `Run` / `RunIn` | 检查 `ExitCode` / `TimedOut` / `OutputLimited` 或 `ProcessSucceeded` |
| 成功判定 | `ProcessSucceeded(Out)` | 非超时、非超限且 exit=0 |
| 失败即错 | `RunChecked` / `MustCapture` / `MustCaptureCombined` | 类似 Go `Output()`；`EProcessError.TimedOut/OutputLimited` |
| 只要文本且可忽略 exit | `Capture*` | **不检查退出码** |
| 超时 | `.Timeout` 或 `RunTimeout` | 看 `TimedOut`；`Status` 返回 `TProcessOutput`（不捕获输出） |
| 有界输出 | `.MaxOutput(N)` | stdout+stderr 累计；**默认无界（INV-10）**；超限 `OutputLimited` |
| 合并 stderr | `.MergeStderr` / `Capture*Combined` | 真时间交错；**要求** stdout piped（`.Output` 强制）；`StdErr` 空、`StdOut` 为合并流；覆盖 Stderr(stPiped/stInherit)；与 `Stderr(stNull)` 或非 piped stdout 冲突抛错 |
| PATH 查找 | `LookPath` / `TryLookPath` | 含目录部分也校验可执行 |

### 便利函数冻结策略

- **新能力只加在 `ICommand` builder**（Timeout、MaxOutput、MergeStderr…）。
- **不再按 In×Timeout×Input×Combined 笛卡尔积扩展** 门面便利函数。
- 现有 `Run*`/`Capture*` 组合 **保留兼容**，不删除；新代码优先上表推荐入口。

### 大输出 / 流式

- `Run` / `Capture` / `IChild.WaitWithOutput`：默认 **全内存**缓冲；可用 `.MaxOutput(N)` 有界。
- 大输出推荐：`Command(...).Stdout(stPiped).Spawn` → `TakeStdout` 流式读，再 `Wait`。
- 超限时不伪装为 `TimedOut`，单独看 `OutputLimited`。

## 环境变量

```pascal
// 完全替换环境
Command('/bin/env').Env(['KEY=VALUE']).Output;

// 追加/覆盖单个变量（继承父进程其余环境）
Command('/bin/env').EnvAdd('MY_VAR', 'my_value').Output;
```

注意：
- 不设置 Env/EnvAdd 时，子进程自动继承父进程的完整环境（通过 execvp）
- 调用 Env 时，子进程环境被完全替换为指定的变量列表（不继承父进程）
- 调用 EnvAdd 时，继承父进程环境并追加/覆盖指定变量
- 混合使用 Env + EnvAdd 时，Env 优先（完全替换模式）

## 模块结构

```
nextpas.core.process.pas          ← 门面（Run/RunIn/Capture/Command/LookPath）
nextpas.core.process.base.pas     ← 类型（TStdio/TProcessOutput/EProcessError）
nextpas.core.process.command.pas  ← ICommand builder
nextpas.core.process.child.pas    ← IChild 接口（Wait/Kill/TakeStdin...）
nextpas.core.process.pipe.pas     ← TPipeReader/TPipeWriter（IReader/IWriter over fd）
nextpas.core.process.pathresolve.pas ← PATH 搜索逻辑（ResolveExecutablePath）
```

## 设计决策

- **接口优先**：ICommand 和 IChild 都是 interface，引用计数自动管理生命周期
- **Builder 模式**：ICommand 链式调用，每个方法返回 Self
- **poll 并发读**：WaitWithOutput 用 poll(2) 同时读 stdout+stderr，避免死锁
- **execvp**：默认继承父进程环境 + 搜索 PATH
- **close(3..1023)**：子进程 exec 前关闭所有继承的 fd，防止管道泄漏
- **Kill+reap in Destroy**：尽力终止并 reap 子进程（约 5s）；超时 abandon 再 detach，极端负载下不保证零僵尸
- **Wait 与管道（INV-13）**：仍持管道时 `Wait`→`WaitWithOutput`；`TryWait` 在进程已退出后**仅 drain**（不二次 wait，避免 ECHILD）。`TakeStdout`/`TakeStderr` 后**必须由调用方读完**再 `Wait`/`TryWait`，否则大输出仍可能死锁

## 测试

```bash
make -C core/tests/nextpas.core.process/test_process clean test
make -C core/tests/nextpas.core.process/test_process_command clean test
make -C core/tests/nextpas.core.process/test_process_deep clean test
make -C core/tests/nextpas.core.process/test_process_pipe_contract clean test
```

suite 通过数与覆盖细节见 `CONTRACT.md`（以 `make test` 输出为准）。
