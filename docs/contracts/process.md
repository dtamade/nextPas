# nextpas.core.process 代码契约

> 模块路径: `core/src/nextpas.core.process.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

进程管理门面。提供子进程启动、管道、超时、环境变量和链式命令构建。

---

## 关键接口

```pascal
type
  TStdio = (soInherit, soPipe, soNull);
  TProcessStatus = (psExited, psSignaled, psRunning);
  TProcessOutput = record
    Status: TProcessStatus;
    ExitCode: Int32;
    Stdout: TBytes;
    Stderr: TBytes;
  end;
  IChild = interface ... end;
  ICommand = interface ... end;

function Command(APath: string): ICommand;
function Run(APath: string; AArgs: array of string): TProcessOutput;
function RunIn(APath: string; AArgs: array of string; ADir: string): TProcessOutput;
function Capture(APath: string; AArgs: array of string): string;
```

---

## 错误语义

| 场景 | 行为 |
|------|------|
| 可执行文件不存在 | raise EProcessError |
| 超时 | TProcessStatus = psSignaled |
| 非零退出码 | TProcessOutput.ExitCode != 0 |

---

## 线程安全

- IChild 不线程安全（per-process）
- ICommand 为构建器，不线程安全
- 多进程可并发启动

---

## 依赖关系

- 依赖: base, text, platform.process, platform.pipe
- 被依赖: 工具链、测试运行器

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
