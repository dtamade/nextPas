# nextpas.core.process

L2 进程执行模块。提供类似 Go `os/exec` 和 Rust `std::process::Command` 的子进程管理能力。

## 快速开始

```pascal
uses nextpas.core.process;

// 一行执行，捕获输出
// 注意：Capture / Run 不检查退出码；exit≠0 时仍返回输出
var Out := Run('/bin/echo', ['hello', 'world']);
WriteLn(Out.StdOut);  // "hello world\n"

// 失败即错（类似 Go cmd.Output / 检查 ExitError）
var OutOk := RunChecked('/bin/true', []);
var TextOk := MustCapture('/bin/echo', ['ok']);

// 只要退出码
var Code := Command('/bin/true').Status;  // 0

// 只要 stdout 文本（不检查退出码）
var Text := Capture('/usr/bin/fpc', ['--version']);

// 超时后 TimedOut=True（Status 通常为 psSignaled）
var Timed := RunTimeout('/bin/sleep', ['10'], TDuration.FromMilliseconds(100));
if Timed.TimedOut then
  WriteLn('timed out');

// 查找 PATH 中的可执行文件（含目录部分时校验可执行性，对齐 Go LookPath）
var FpcPath := LookPath('fpc');  // '/usr/bin/fpc'
if not TryLookPath('/no/such/bin', FpcPath) then
  WriteLn('missing absolute path rejected');

// stdout + stderr 合并
var Combined := CaptureCombined('/bin/sh', ['-c', 'echo out; echo err >&2']);

// 在指定目录执行
var Out2 := RunIn('/bin/ls', ['-la'], '/tmp');
var Dir := CaptureIn('/bin/pwd', [], '/tmp');

// 在指定目录 + 超时执行
var Out3 := RunInTimeout('/bin/sleep', ['10'], '/tmp', TDuration.FromSeconds(1));
var Dir2 := CaptureInTimeout('/bin/pwd', [], '/tmp', TDuration.FromSeconds(5));

// 查找 PATH 中的可执行文件
var FpcPath := LookPath('fpc');  // '/usr/bin/fpc'

// 不抛异常版本
if TryLookPath('fpc', FpcPath) then
  WriteLn('fpc at: ', FpcPath);

// 带超时执行（超时后自动 Kill）
var Out := RunTimeout('/usr/bin/fpc', ['--version'], TDuration.FromSeconds(30));
var Text := CaptureTimeout('/usr/bin/fpc', ['--version'], TDuration.FromSeconds(30));

// 带超时 + stdout+stderr 合并
var Combined := CaptureTimeoutCombined('/bin/sh', ['-c', 'echo out; echo err >&2'], TDuration.FromSeconds(5));
var Combined2 := CaptureInTimeoutCombined('/bin/sh', ['-c', 'pwd; echo err >&2'], '/tmp', TDuration.FromSeconds(5));

// 通过 stdin 传入数据
var Input := TBytes.Create(Ord('h'), Ord('e'), Ord('l'), Ord('l'), Ord('o'));
var Out := RunWithInput('/bin/cat', [], Input);
var Text := CaptureWithInput('/bin/cat', [], Input);

// 通过 stdin 传入字符串
var Text := CaptureWithInputString('/bin/cat', [], 'hello world');

// 在指定目录 + stdin 传入数据
var Out4 := RunInWithInput('/bin/cat', [], '/tmp', Input);
var Text4 := CaptureInWithInput('/bin/cat', [], '/tmp', Input);
var Text5 := CaptureInWithInputString('/bin/cat', [], '/tmp', 'hello dir');

// 获取当前进程可执行文件路径
var ExePath := Executable;
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
| L2 `nextpas.core.process` | ✅ 一等支持 | ⚠️ 可用但未做完整 parity（管道/poll/信号语义差异） |
| L0 `platform.process` | ✅ | ✅ CreateProcess 基础；`platform_process_run` 捕获 stderr 有限 |

**建议**：生产路径以 Unix 为准；Windows 调用请走 `platform.process` 或先在 Wine/CI 补回归。完整 Windows L2 对等列为后续里程碑。

## 推荐 API 分层（避免便利函数爆炸）

| 场景 | 推荐 | 说明 |
|------|------|------|
| 完整控制 | `Command(...).Args.Dir.EnvAdd.Timeout.Spawn/Output` | 唯一完整入口 |
| 同步拿输出 | `Run` / `RunIn` | 检查 `ExitCode` / `TimedOut` |
| 失败即错 | `RunChecked` / `MustCapture` / `MustCaptureCombined` | 类似 Go `Output()` |
| 只要文本且可忽略 exit | `Capture*` | **不检查退出码** |
| 超时 | `.Timeout` 或 `RunTimeout` | 看 `TimedOut` |
| PATH 查找 | `LookPath` / `TryLookPath` | 含目录部分也校验可执行 |

其余 `RunInWithInputTimeout...` 组合函数保留兼容；新代码优先 builder。

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
- **Kill+Wait in Destroy**：IChild 释放时自动终止并 reap 子进程，防止僵尸

## 测试

```bash
make -C core/tests/nextpas.core.process/test_process clean test
make -C core/tests/nextpas.core.process/test_process_command clean test
make -C core/tests/nextpas.core.process/test_process_deep clean test
make -C core/tests/nextpas.core.process/test_process_pipe_contract clean test
```

覆盖公共 API，heaptrc 零泄漏。
