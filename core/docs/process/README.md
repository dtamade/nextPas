# nextpas.core.process

L2 进程执行模块。提供类似 Go `os/exec` 和 Rust `std::process::Command` 的子进程管理能力。

## 快速开始

```pascal
uses nextpas.core.process;

// 一行执行，捕获输出
var Out := Run('/bin/echo', ['hello', 'world']);
WriteLn(Out.StdOut);  // "hello world\n"

// 只要退出码
var Code := Command('/bin/true').Status;  // 0

// 只要 stdout 文本
var Text := Capture('/usr/bin/fpc', ['--version']);
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

// 终止
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

## 环境变量

```pascal
// 完全替换环境
Command('/bin/env').Env(['KEY=VALUE']).Output;

// 追加/覆盖单个变量（继承父进程其余环境）
Command('/bin/env').EnvAdd('MY_VAR', 'my_value').Output;
```

注意：不设置 Env 时，子进程自动继承父进程的完整环境（通过 execvp）。

## 模块结构

```
nextpas.core.process.pas          ← 门面（Run/RunIn/Capture/Command）
nextpas.core.process.base.pas     ← 类型（TStdio/TProcessOutput/EProcessError）
nextpas.core.process.command.pas  ← ICommand builder
nextpas.core.process.child.pas    ← IChild 接口（Wait/Kill/TakeStdin...）
nextpas.core.process.pipe.pas     ← TPipeReader/TPipeWriter（IReader/IWriter over fd）
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
cd tests/nextpas.core.process/test_process
make run
```

40 个测试，覆盖所有公共 API，heaptrc 零泄漏。
