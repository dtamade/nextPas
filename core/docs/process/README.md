# nextpas.core.process

L2 进程执行模块。提供类似 Go `os/exec` 和 Rust `std::process::Command` 的子进程管理能力。

**开发地图**：[`ROADMAP.md`](./ROADMAP.md) · **Windows**：[WIN.md](./WIN.md) · **对标**：[PARITY-go-rust.md](./PARITY-go-rust.md) · **证据**：[SCORECARD.md](./SCORECARD.md)

> Host Essential + M2/M3 + U1/U2 Done（Maintenance）。安全默认 MaxOutput（便利+builder）；Preferred API。新需求贴标签（ROADMAP §5）。

## 生产默认（Preferred）

```pascal
uses nextpas.core.process;

// 推荐：builder + 超时；未调用 MaxOutput 时缓冲路径默认 64 MiB（U2）
var Out := Command('/usr/bin/tool')
  .Args(['--flag'])
  .Timeout(TDuration.FromSeconds(30))
  .MaxOutput(1024 * 1024)  // 生产可再收紧；省略则仍 64MiB 默认
  .Output;
if not ProcessSucceeded(Out) then
  // Out.TimedOut / Out.OutputLimited / Out.Cancelled / Out.ExitCode
  ...

// 便利层与 builder 未配置时同为 64 MiB；无限必须显式 MaxOutput(0)
var Text := MustCapture('/bin/echo', ['ok']);
var St := RunChecked('/bin/true', []);
var Path := LookPath('fpc');
```

| Preferred | 用途 |
|-----------|------|
| `Command` / `ProcessSucceeded` | 配置与成功判定 |
| `LookPath` / `TryLookPath` / `Executable` | 解析可执行文件 |
| `RunChecked` / `MustCapture` / `RunTimeout` | 常用便利（带 64MiB 默认 cap） |
| `Spawn` + `Wait` / `WaitWithOutput` / `WaitGraceful` / `Detach` | 生命周期 |

其余 `RunIn*` / `Capture*Combined` / `*WithInput*` 为 **Compat**，保留不删；新代码优先上表 + builder。

## MaxOutput 策略（U1+U2）

| 入口 | 默认 |
|------|------|
| 未调用 `MaxOutput` 的 **ICommand** 缓冲路径（Output / 带管道 Spawn） | **`cProcessDefaultMaxOutput` = 64 MiB**（U2） |
| `MaxOutput(0)` | **显式不限制** |
| `MaxOutput(N>0)` | 上限 N |
| free `Run*` / `Capture*` | 同样 64 MiB（U1 显式挂载） |

```pascal
// 无限缓冲必须显式：
Command('/bin/tool').MaxOutput(0).Output;
```


## 生命周期

- Spawn 后须 **`Wait` / `WaitWithOutput` / `WaitGraceful` / `Detach` 之一**。
- `Destroy`：尽力 Kill+reap（约 5s），超时 abandon，**不保证零僵尸**（INV-1）。
- **非线程安全**：同一 `ICommand`/`IChild` 勿跨线程共享。

## Status vs Output

| | `Status` | `Output` |
|--|----------|----------|
| 管道 | 不强制 piped | 强制 stdout+stderr Piped（或 Merge） |
| `TimedOut` / `Cancelled` | ✓ | ✓ |
| `OutputLimited` | 恒 False | ✓（设了 MaxOutput） |
| `StdOut` / `StdErr` | **恒空**（勿当 Capture） | 有内容 |
| 用途 | 只要退出码/超时 | 捕获输出 |

```pascal
var St := Command('/bin/true').Status;  // StdOut 空
if ProcessSucceeded(St) then ...
```

## 快速开始（扩展）

```pascal
uses nextpas.core.process;

var Out := RunChecked('/bin/echo', ['hello']);
var Text := MustCapture('/usr/bin/fpc', ['--version']);
var Timed2 := RunTimeout('/bin/sleep', ['10'], TDuration.FromMilliseconds(100));
if Timed2.TimedOut then WriteLn('timed out');
```

### Compat 便利示例

```pascal
// 已带 64MiB 默认 cap（U1）；不检查 exit 用 Capture，失败即错用 MustCapture
var Text := Capture('/usr/bin/fpc', ['--version']);
var Combined := CaptureCombined('/bin/sh', ['-c', 'echo out; echo err >&2']);
var Out3 := RunWithInputString('/bin/cat', [], 'hello');
```

## Builder 模式

```pascal
var Out := Command('/usr/bin/fpc')
  .Args(['--version'])
  .Dir('/tmp')
  .Env(['PATH=/usr/bin', 'HOME=/tmp'])
  .Stdout(stPiped)
  .Stderr(stPiped)
  .Output;
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
- 验证：`bash core/tests/run_l2_wine_min_set.sh` 或 process wine **11**；host-windows 见 WIN.md / GHA

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
