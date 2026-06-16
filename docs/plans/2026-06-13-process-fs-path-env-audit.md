# 2026-06-13 process/fs/path/env 深度审查

## 范围

本次审查覆盖：

- `core/src/nextpas.core.fs.pas`
- `core/src/nextpas.core.fs.dir.pas`
- `core/src/nextpas.core.fs.util.pas`
- `core/src/nextpas.core.fs.path.pas`
- `core/src/nextpas.core.process.child.pas`
- `core/src/nextpas.core.process.command.pas`
- `core/src/nextpas.core.process.pathresolve.pas`
- 相关 owner / platform 实现与 focused tests

## 验证快照

已实际阅读上述源码与相关测试，并补读：

- `core/src/nextpas.core.process.pipe.pas`
- `core/src/nextpas.core.platform.process.pas`
- `core/src/nextpas.core.platform.files.pas`
- `core/src/nextpas.core.platform.fs.pas`
- `core/src/nextpas.core.platform.path.pas`
- `core/docs/process/README.md`
- `core/docs/design-conventions.md`

当前 focused gate 现状：

- `make focused FOCUS=core/tests/nextpas.core.fs/test_fs`
  - 编译失败：`core/src/nextpas.core.fs.util.pas:164` 引用未定义符号 `platform_fs_mktemp_handle`
- `make focused FOCUS=core/tests/nextpas.core.fs/test_fs_text`
  - 同上，失败点一致
- `make focused FOCUS=core/tests/nextpas.core.process/test_process`
  - 编译失败：`core/src/nextpas.core.process.pathresolve.pas:58` 引用未定义符号 `platform_fs_is_executable`
- `make focused FOCUS=core/tests/nextpas.core.process/test_process_pipe_contract`
  - 编译失败：`core/src/nextpas.core.platform.error.pas:18` uses 缺失单元 `nextpas.core.platform.error.base`

这 3 个编译阻塞比用户列出的部分代码味道问题更优先，因为它们已经阻断本 lane 的 focused verification。

## 结论总览

| # | 结论 | 严重性 | 备注 |
| --- | --- | --- | --- |
| 1 | 原始 bug 描述不成立；实现可改进 | P3低 | 当前 `string` 是 UTF-8 `AnsiString`，`Length` 返回字节数 |
| 2 | 真实存在 | P2中 | 绕过 path owner，Windows 特殊路径语义不安全 |
| 3 | 真实存在 | P2中 | `Walk` 错误回调契约不完整 |
| 4 | 真实存在 | P2中 | 读取文本无 BOM 剥离，也无 UTF-8 合法性检查 |
| 5 | 部分成立，优先级低 | P3低 | 更像 owner boundary / 优化项，不是当前主红点 |
| 6 | 原始“私有字段”说法不成立；真实问题存在 | P1高 | concrete downcast + raw POSIX I/O，封装和跨平台都被破坏 |
| 7 | 真实存在 | P1高 | L2 builder 绕过 `platform.process`，Windows 路径被卡住 |
| 8 | 原始 bug 描述不成立；实现脆弱 | P3低 | 偏移正确，但可维护性差 |

## 逐项核查

### 问题 1: `WriteFileText` / `AppendFileText` 编码假设

- 结论：**原始 bug 描述不成立**
- 严重性：`P3低`
- 影响范围：
  - `nextpas.core.fs.WriteFileText`
  - `nextpas.core.fs.AppendFileText`
  - 间接影响 `AppendFileLine`
- 证据：
  - `core/src/nextpas.core.fs.pas:171-175`
  - `core/src/nextpas.core.fs.pas:220-224`
  - `core/src/nextpas.core.settings.inc:7` 启用 `{$H+}`
  - `core/docs/design-conventions.md:1168-1170` 明确规定 `string` 为 UTF-8 `AnsiString`
- 分析：
  - 在当前工程约定下，`string` 是 UTF-8 字节串。
  - `Length(AText)` 返回的是 **字节数**，不是 Unicode code point 数。
  - 所以 `Move(PAnsiChar(AText)^, ..., Length(AText))` 不会把 UTF-8 多字节字符截断。
  - 这段代码的问题不是 correctness，而是重复、隐含契约太强、可读性差。
- 修复方案：
  - 抽出统一的 UTF-8 text-to-bytes helper，避免相同逻辑在 `WriteFileText` / `AppendFileText` / `WriteFileLines` 各自散落。

```pascal
function Utf8TextToBytes(const AText: string): TBytes;
var
  LLen: SizeInt;
begin
  LLen := Length(AText);
  SetLength(Result, LLen);
  if LLen > 0 then
    Move(AText[1], Result[0], LLen);
end;

procedure WriteFileText(const APath: string; const AText: string;
  const APerm: TFilePermission);
begin
  nextpas.core.fs.util.FsWriteFile(APath, Utf8TextToBytes(AText), APerm);
end;
```

### 问题 2: `FsRemoveAll` / `FsWalk` 硬编码 `'/'`

- 结论：**真实存在**
- 严重性：`P2中`
- 影响范围：
  - `nextpas.core.fs.dir.FsRemoveAll`
  - `nextpas.core.fs.dir.FsWalk`
  - 所有递归删除 / 遍历调用者
- 证据：
  - `core/src/nextpas.core.fs.dir.pas:237`
  - `core/src/nextpas.core.fs.dir.pas:303`
  - `core/src/nextpas.core.platform.path.pas:7-44` 已经定义平台分隔符和 join 逻辑
- 分析：
  - 这不是单纯“Windows 一定立即出错”的问题。
  - 普通 `C:/tmp` 路径在 Win32 API 上经常还能工作，但这里绕过了 `platform.path` 的 root 分类、UNC share、`\??\` / `\\?\` 扩展路径语义。
  - 对 L2 facade 来说，这已经是 owner boundary 泄漏。
- 修复方案：
  - 在 `fs.dir` 内部统一走 `FsPathJoin` 或一个局部 helper。

```pascal
uses
  nextpas.core.fs.path;

function JoinChildPath(const ADir, AName: string): string;
begin
  Result := FsPathJoin([ADir, AName]);
end;

...
LChild := JoinChildPath(APath, LEntry.Name);
```

### 问题 3: `FsWalk` 缺少目录打开/读取错误处理

- 结论：**真实存在**
- 严重性：`P2中`
- 影响范围：
  - `nextpas.core.fs.dir.FsWalk`
  - 所有依赖 `AErr` 回调处理错误的调用方
- 证据：
  - `core/src/nextpas.core.fs.dir.pas:279-289` 只包裹了 `FsLstat`
  - `core/src/nextpas.core.fs.dir.pas:297-306` 的 `FsOpenDir` / `LIter.Next` 完全裸奔
- 分析：
  - `TWalkFunc` 明确带 `AErr: Exception`，说明 API 设计就是要把遍历错误交回 callback。
  - 当前实现只在 `lstat` 失败时走 callback。
  - `opendir`、`readdir`、`closedir` 失败会直接异常终止，契约不完整。
- 修复方案：
  - 把目录打开和目录迭代也纳入同一错误分发路径。

```pascal
procedure ReportWalkError(const APath: string; const AErr: Exception);
var
  LInfo: TFileInfo;
begin
  LInfo := Default(TFileInfo);
  LInfo.Name := APath;
  AFunc(APath, LInfo, AErr);
end;

...
try
  LIter := FsOpenDir(APath);
except
  on E: Exception do
  begin
    ReportWalkError(APath, E);
    Exit;
  end;
end;

try
  while LIter.Next do
    ...
except
  on E: Exception do
    ReportWalkError(APath, E);
finally
  if LIter <> nil then
    LIter.Close;
end;
```

### 问题 4: `FsReadFileText` 无 UTF-8 BOM 处理

- 结论：**真实存在**
- 严重性：`P2中`
- 影响范围：
  - `nextpas.core.fs.util.FsReadFileText`
  - 所有走 `ReadFileText` / `ReadFileLines` 的配置、文本解析器
- 证据：
  - `core/src/nextpas.core.fs.util.pas:330-339`
  - `core/src/nextpas.core.fs.util.pas:341-378`
- 分析：
  - 当前实现只是 `SetString(Result, PAnsiChar(@Bytes[0]), Length(Bytes))`。
  - UTF-8 BOM (`EF BB BF`) 会原样进入返回字符串首字符。
  - 更关键的是，这个函数也没有验证文本是否为合法 UTF-8，而仓库规范要求 `string` 始终存储 UTF-8。
- 修复方案：
  - 读取文本时同时做：
    1. UTF-8 BOM 剥离
    2. UTF-8 合法性校验

```pascal
uses
  nextpas.core.text.utf8,
  nextpas.core.errors;

function FsReadFileText(const APath: string): string;
var
  LBytes: TBytes;
  LOffset, LLen: SizeInt;
begin
  LBytes := FsReadFile(APath);
  LOffset := 0;
  if (Length(LBytes) >= 3) and
     (LBytes[0] = $EF) and (LBytes[1] = $BB) and (LBytes[2] = $BF) then
    LOffset := 3;

  LLen := Length(LBytes) - LOffset;
  if (LLen > 0) and (not UTF8IsValid(@LBytes[LOffset], LLen)) then
    raise EConvertError.Create('read file: invalid UTF-8: ' + APath);

  if LLen > 0 then
    SetString(Result, PAnsiChar(@LBytes[LOffset]), LLen)
  else
    Result := '';
end;
```

### 问题 5: `FsCopyFile` 32KB 固定缓冲区性能

- 结论：**部分成立，但优先级低**
- 严重性：`P3低`
- 影响范围：
  - 大文件 copy 吞吐
  - `nextpas.core.fs.util.FsCopyFile`
- 证据：
  - `core/src/nextpas.core.fs.util.pas:125-145`
  - `core/src/nextpas.core.platform.fs.pas:229-255` 已存在下层 copy helper
- 分析：
  - 32KB 固定缓冲区确实不是最佳吞吐策略，但这还不是当前最大问题。
  - 当前更明显的问题是 L2 自己手写 copy，而不是复用 owner 层能力。
  - 现有 `platform_fs_copy_file` 目前也只是循环 copy，不是系统快路径，因此“只改成调用 platform helper”不一定马上提升性能。
- 修复方案：
  - 优先做 owner 收敛：把 copy 策略放回 platform 层唯一维护。
  - 如果后续 benchmark 证明确实是热点，再在 platform 层做系统快路径优化。

```pascal
function FsCopyFile(const ASrc, ADst: string): Int64;
var
  LStat: TFileInfo;
  LErr: Int32;
begin
  LStat := FsStat(ASrc);
  LErr := platform_fs_copy_file(PAnsiChar(ASrc), PAnsiChar(ADst));
  if LErr <> 0 then
    RaiseFsError(LErr, 'copy', ASrc);
  if LStat.Permission <> PermDefault then
    FsChmod(ADst, LStat.Permission);
  Result := LStat.Size;
end;
```

### 问题 6: `TChild.WaitWithOutput` 封装破坏

- 结论：**原始“访问 private 字段”说法不成立，但真实问题存在**
- 严重性：`P1高`
- 影响范围：
  - `nextpas.core.process.child.TChild.WaitWithOutput`
  - `nextpas.core.process.pipe`
  - Windows 适配和替换式 `IReader` 实现
- 证据：
  - `core/src/nextpas.core.process.child.pas:283-288`
  - `core/src/nextpas.core.process.child.pas:329-389`
  - `core/src/nextpas.core.process.pipe.pas:12-22`
- 分析：
  - `Fd` 不是 private field，它是 `TPipeReader` 暴露的 public property。
  - 真正的问题是：
    1. `TChild` downcast 到 concrete `TPipeReader`
    2. `TChild` 自己直接做 `poll/read`
    3. `TChild` 因此必须无条件依赖 POSIX units
  - 这已经让 `WaitWithOutput` 既不抽象，也不跨平台。
- 修复方案：
  - 把并发 drain 逻辑下沉到 `nextpas.core.process.pipe` 或 `platform.process`。
  - `TChild` 只依赖一个显式契约，不再认识 `TPipeReader` 具体类型。

```pascal
type
  IPipeDrainReader = interface(IReader)
    ['{6C658D19-5222-4C25-ACF7-716F6D840001}']
    function NativeHandle: PtrInt;
  end;

function DrainPipePair(const AStdout, AStderr: IReader;
  const ATimeout: TDuration; const AProc: TPlatformProcess;
  out AStdoutText, AStderrText: string;
  out AWaitResult: TPlatformProcessResult): Boolean;
```

建议实现方向：

- `IPipeDrainReader` 的 owner 是 `process.pipe`
- POSIX `poll/read` 或 Windows `WaitForMultipleObjects` 也都留在 `process.pipe` / `platform.process`
- `TChild.WaitWithOutput` 只调用 `DrainPipePair`

### 问题 7: `TCommand.Spawn` 直接使用 POSIX API

- 结论：**真实存在**
- 严重性：`P1高`
- 影响范围：
  - `nextpas.core.process.command.TCommand.Spawn`
  - 混合 stdio 模式
  - Windows L2 builder 路径
- 证据：
  - `core/src/nextpas.core.process.command.pas:365-405`
  - `core/src/nextpas.core.process.command.pas:423-452`
  - `core/src/nextpas.core.platform.process.pas:523-760` 已有 Windows process owner 实现
- 分析：
  - 这里的问题比“跨平台性差”更具体：
    - L2 直接 `pipe()`
    - 直接 `open('/dev/null')`
    - 直接 `close()`
    - 无条件依赖 POSIX units
  - 结果是 `platform.process` 明明已经具备 Windows 进程能力，L2 builder 仍然把自己锁在 Unix 语义上。
- 修复方案：
  - 把 pipe/null/close 准备逻辑全部下沉到 platform owner。

```pascal
type
  TPlatformSpawnPipe = record
    ParentEnd: PtrInt;
    ChildEnd: PtrInt;
  end;

function platform_process_create_pipe(out APipe: TPlatformSpawnPipe): Int32;
function platform_process_open_null(AForRead: Boolean; out AHandle: PtrInt): Int32;
procedure platform_process_close_handle(var AHandle: PtrInt);
```

`TCommand.Spawn` 收敛后应类似：

```pascal
if FStdinMode = stPiped then
begin
  LErr := platform_process_create_pipe(LStdinPipe);
  if LErr <> 0 then
    raise EProcessError.Create('Failed to create stdin pipe', LErr);
  LChildStdin := LStdinPipe.ChildEnd;
end;
```

这样 `TCommand` 只负责 builder 语义，不再拥有 POSIX 细节。

### 问题 8: `PATH` 提取硬编码偏移

- 结论：**原始 bug 描述不成立，但实现脆弱**
- 严重性：`P3低`
- 影响范围：
  - `nextpas.core.process.pathresolve.ExtractPathFromEnv`
  - `nextpas.core.process.pathresolve.ExtractPathExtFromEnv`
- 证据：
  - `core/src/nextpas.core.process.pathresolve.pas:111-123`
- 分析：
  - `Copy(AEnv[I], 6, Length(AEnv[I]) - 5)` 对 `PATH=` 来说是正确的。
  - `Copy(AEnv[I], 9, Length(AEnv[I]) - 8)` 对 `PATHEXT=` 也正确。
  - 所以这不是 off-by-one bug。
  - 但硬编码数字不利于维护，也不利于代码阅读。
- 修复方案：
  - 改成 prefix 常量或直接按 `=` 位置切。

```pascal
const
  PATH_ENV_PREFIX = 'PATH=';
  PATHEXT_ENV_PREFIX = 'PATHEXT=';

...
Result := Copy(AEnv[I], Length(PATH_ENV_PREFIX) + 1, MaxInt);
...
Result := Copy(AEnv[I], Length(PATHEXT_ENV_PREFIX) + 1, MaxInt);
```

## 补充发现

### A1. focused gates 当前存在 3 个编译阻塞

- 严重性：`P0阻塞`
- 影响范围：
  - `nextpas.core.fs` focused gate
  - `nextpas.core.process` focused gate
  - `nextpas.core.process.pipe` contract gate

#### A1.1 `platform_fs_mktemp_handle` 未定义

- 证据：
  - `core/src/nextpas.core.fs.util.pas:164`
  - `core/src/nextpas.core.platform.fs.pas:331-409` 真实存在的是 `platform_fs_mktemp`
- 修复方案：
  - 直接改回现有 owner API，不要调用不存在的 wrapper。

```pascal
var
  LFd: Int32;
begin
  LResult := platform_fs_mktemp(PAnsiChar(APattern), PAnsiChar(''),
    @LPathBuf[0], SizeOf(LPathBuf), LFd);
  if LResult <> 0 then
    raise EIOError.Create('mktemp failed (' + IntToStr(LResult) + ')');
  LPath := StrPas(@LPathBuf[0]);
  Result := FsFromHandle(LFd, LPath);
end;
```

#### A1.2 `platform_fs_is_executable` 未定义

- 证据：
  - `core/src/nextpas.core.process.pathresolve.pas:58`
  - `core/src/nextpas.core.platform.fs.pas` interface 当前没有该函数
- 修复方案：
  - 在 `platform.fs` 增加统一可执行判定 helper。

```pascal
function platform_fs_is_executable(const APath: PAnsiChar): Boolean;
var
  LStat: TPlatformFileStat;
begin
  if platform_file_stat(APath, LStat) <> 0 then
    Exit(False);
  if LStat.FileType <> ftRegular then
    Exit(False);
{$IFDEF NEXTPAS_WINDOWS}
  Result := True;
{$ELSE}
  Result := (LStat.Mode and $49) <> 0;
{$ENDIF}
end;
```

#### A1.3 `nextpas.core.platform.error.base` 缺失

- 证据：
  - `core/src/nextpas.core.platform.error.pas:17-18`
  - 仓库内没有 `core/src/nextpas.core.platform.error.base.pas`
- 修复方案：
  - 二选一：
    1. 新增 `platform.error.base` re-export shim
    2. 直接让 `platform.error` uses 现有 `nextpas.core.platform.sync.base`

```pascal
unit nextpas.core.platform.error.base;

interface

uses
  nextpas.core.platform.sync.base;

const
  PLATFORM_ERR_INVALID     = nextpas.core.platform.sync.base.PLATFORM_ERR_INVALID;
  PLATFORM_ERR_UNSUPPORTED = nextpas.core.platform.sync.base.PLATFORM_ERR_UNSUPPORTED;
  PLATFORM_ERR_TIMEOUT     = nextpas.core.platform.sync.base.PLATFORM_ERR_TIMEOUT;
  PLATFORM_ERR_AGAIN       = nextpas.core.platform.sync.base.PLATFORM_ERR_AGAIN;
  PLATFORM_ERR_BUSY        = nextpas.core.platform.sync.base.PLATFORM_ERR_BUSY;
```

### A2. `FsRemoveAll` 的危险根路径保护不完整

- 严重性：`P1高`
- 影响范围：
  - Windows volume root / UNC share root
  - 所有 `RemoveAll` 调用者
- 证据：
  - `core/src/nextpas.core.fs.dir.pas:221-222`
  - `core/src/nextpas.core.platform.path.pas:59-76`
  - `core/src/nextpas.core.platform.path.pas:159-216`
- 分析：
  - 当前只拒绝 `''`、`/`、`\`。
  - 没有拒绝 `C:\`、`C:/`、`\\server\share`、`\\?\C:\` 这类真正的 Windows 根。
- 修复方案：
  - 在 `platform.path` 暴露 `platform_path_is_root` 或 root-length helper，`FsRemoveAll` 用它做统一判断。

```pascal
function platform_path_is_root(const APath: PAnsiChar): Boolean;
```

```pascal
if (APath = '') or platform_path_is_root(PAnsiChar(FsPathClean(APath))) then
  raise EInvalidOperationError.Create('removeall refused unsafe root: ' + APath);
```

### A3. `TChild.Wait` / `TryWait` / `Kill` 静默忽略平台返回码

- 严重性：`P1高`
- 影响范围：
  - 所有进程等待 / kill 路径
- 证据：
  - `core/src/nextpas.core.process.child.pas:165-183`
  - `core/src/nextpas.core.process.child.pas:201-205`
  - `core/src/nextpas.core.process.child.pas:219-224`
- 分析：
  - `platform_process_wait`
  - `platform_process_try_wait`
  - `platform_process_kill`
  的返回值都被忽略了。
  - 如果底层返回 `EINTR` / `ECHILD` / `ESRCH`，上层会把零值结构体当作成功结果继续用。
- 修复方案：
  - 统一封装错误传播 helper。

```pascal
procedure RaiseProcessPlatformError(const AOp: string; const ACode: Int32);
begin
  if ACode <> 0 then
    raise EProcessError.Create(AOp + ' failed', ACode);
end;

...
RaiseProcessPlatformError('wait', platform_process_wait(FProc, LResult));
...
RaiseProcessPlatformError('try_wait', platform_process_try_wait(FProc, LResult));
...
RaiseProcessPlatformError('kill', platform_process_kill(FProc));
```

### A4. `WaitWithOutput` 对 `poll/read` 错误处理不正确

- 严重性：`P1高`
- 影响范围：
  - 大输出、信号打断、边界场景下的 `WaitWithOutput`
- 证据：
  - `core/src/nextpas.core.process.child.pas:329-335`
  - `core/src/nextpas.core.process.child.pas:340-352`
  - `core/src/nextpas.core.process.child.pas:359-387`
- 分析：
  - `poll(...) < 0` 直接 `Break`，没有区分 `EINTR` 和真正错误。
  - `read(...) < 0` 也直接把 fd 标成 `-1`，把错误当成 EOF。
  - 这会导致输出丢失和错误静默。
- 修复方案：
  - 对 `EINTR` 重试；对 `EAGAIN` 继续 poll；对其他 errno 抛 `EProcessError`。

```pascal
if LPollResult < 0 then
begin
  if platform_get_errno = ESysEINTR then
    Continue;
  raise EProcessError.Create('poll failed', platform_get_errno);
end;

if LRead < 0 then
begin
  if platform_get_errno = ESysEINTR then
    Continue;
  if platform_get_errno = ESysEAGAIN then
    Continue;
  raise EProcessError.Create('pipe read failed', platform_get_errno);
end;
```

## 修复优先级

1. `P0阻塞`
   - 修 `platform_fs_mktemp_handle` 调用断裂
   - 补 `platform_fs_is_executable`
   - 解决 `platform.error.base` 缺失
   - 先把 focused gates 恢复到可编译
2. `P1高`
   - `TChild.Wait/TryWait/Kill/WaitWithOutput` 错误传播
   - `WaitWithOutput` 从 concrete `TPipeReader` + raw POSIX I/O 抽离
   - `TCommand.Spawn` 平台化，不再自己手写 POSIX pipe/null
   - `FsRemoveAll` 的 Windows 根保护
3. `P2中`
   - `FsWalk` 错误回调契约补全
   - `FsRemoveAll` / `FsWalk` 统一走 path join owner
   - `FsReadFileText` BOM 剥离 + UTF-8 校验
4. `P3低`
   - `WriteFileText` / `AppendFileText` 抽 helper 去重
   - `PATH=` / `PATHEXT=` 偏移常量化
   - `FsCopyFile` owner 收敛和性能优化

## 测试补充建议

### fs

- `test_fs_text`
  - 新增 UTF-8 BOM 文件读取回归
  - 新增 invalid UTF-8 输入拒绝回归
  - 新增 `AppendFileText` / `WriteFileText` helper 回归
- `test_fs`
  - 新增 `RemoveAll` 拒绝根路径回归
  - 新增 `Walk` 权限拒绝回调回归
  - 新增 `Walk` 目录中途消失/读取失败回归

### process

- `test_process`
  - 新增 `Kill` 失败错误传播
  - 新增 `Wait/TryWait` 底层错误传播
- `test_process_pipe_contract`
  - 新增 `EINTR` / `EAGAIN` 回归
  - 新增 `WaitWithOutput` 在信号打断下不丢输出回归
- `test_process_deep`
  - 新增 mixed stdio 模式在 Windows/Unix 两侧一致性回归

推荐 focused gate 顺序：

```bash
make focused FOCUS=core/tests/nextpas.core.fs/test_fs
make focused FOCUS=core/tests/nextpas.core.fs/test_fs_text
make focused FOCUS=core/tests/nextpas.core.process/test_process
make focused FOCUS=core/tests/nextpas.core.process/test_process_pipe_contract
make focused FOCUS=core/tests/nextpas.core.process/test_process_deep
```

## 功能补全建议

- 在 `platform.path` 暴露 root 判断 helper，避免每个模块自己猜根路径语义
- 在 `platform.fs` 补齐 `is_executable` / `mktemp` 对应 facade，消除上层凭空引用不存在 API 的问题
- 在 `process.pipe` 或 `platform.process` 收口“并发 drain pipe”能力，让 `TChild` 恢复为 orchestration 层
- 统一 text I/O 契约：`ReadFileText` / `WriteFileText` 明确就是 UTF-8 text API；非 UTF-8 数据一律走 `ReadFile` / `WriteFile`

## Codex 终审裁决

### 独立验证结论

我已在当前 worktree 直接复现 3 个编译阻塞：

- `make focused FOCUS=core/tests/nextpas.core.fs/test_fs_text`
  - 失败于 `core/src/nextpas.core.fs.util.pas:164`，`platform_fs_mktemp_handle` 未定义
- `make focused FOCUS=core/tests/nextpas.core.process/test_process`
  - 失败于 `core/src/nextpas.core.process.pathresolve.pas:58`，`platform_fs_is_executable` 未定义
- `make focused FOCUS=core/tests/nextpas.core.process/test_process_pipe_contract`
  - 失败于 `core/src/nextpas.core.platform.error.pas:18`，`nextpas.core.platform.error.base` 缺失

Claude 列出的 8 个原始问题和 4 个补充发现，总体判断大体准确，但有 4 个需要明确修正：

| 项目 | Codex 判断 | 最终级别 | 裁决 |
| --- | --- | --- | --- |
| 1 `WriteFileText`/`AppendFileText` UTF-8 假设 | 原始 bug 不成立 | P3 | 保留为去重/可读性优化，不是 correctness bug |
| 2 `FsRemoveAll`/`FsWalk` 硬编码 `'/'` | 成立 | P2 | 同意 |
| 3 `FsWalk` 错误回调契约不完整 | 成立 | P2 | 同意 |
| 4 `FsReadFileText` BOM / UTF-8 校验缺失 | 成立 | P2 | 同意 |
| 5 `FsCopyFile` 32KB/owner 问题 | 部分成立 | P3 | 应按 owner 收敛表述，不当成当前主红点 |
| 6 `WaitWithOutput` concrete downcast + raw POSIX I/O | 成立 | P1 | 同意；原始“private 字段”说法不重要，核心问题属实 |
| 7 `TCommand.Spawn` 直接 POSIX pipe/null/close | 成立 | P1 | 同意 |
| 8 `PATH`/`PATHEXT` 偏移 off-by-one | 原始 bug 不成立 | P3 | 保留为常量化/可维护性优化 |
| A1.1 `platform_fs_mktemp_handle` 缺失 | 成立 | P0 | 同意，但修法必须改 |
| A1.2 `platform_fs_is_executable` 缺失 | 成立 | P0 | 同意，但 Windows 骨架必须改 |
| A1.3 `platform.error.base` 缺失 | 成立 | P0 | 同意，但优先修 phantom dependency，而不是先造新壳 |
| A2 `FsRemoveAll` 根路径保护不完整 | 成立 | P1 | 同意 |
| A3 `Wait`/`TryWait`/`Kill` 静默忽略返回码 | 成立 | P1 | 同意 |
| A4 `WaitWithOutput` poll/read 错误处理不正确 | 成立 | P1 | 同意；执行上应与问题 6 合并成同一 slice |

### 对修复骨架的裁决

1. `A1.1` 当前文档里的修法不接受。  
   不能把 `FsTempFile` 改回 `platform_fs_mktemp` + `FsFromHandle`。现有 `test_fs` 已有 source-contract，明确要求：
   - `FsTempFile` 继续调用 `platform_fs_mktemp_handle`
   - `FsTempFile` 继续走 `FsFromPlatformHandle`
   - 不允许回退到 legacy `Int32 fd` seam

   更关键的是，当前 `platform_fs_mktemp` 在 Windows 分支会把 `TPlatformFileHandle` 窄化成 `Int32`
   (`core/src/nextpas.core.platform.fs.pas:397-404`)；这正是 typed seam 必须存在的原因。  
   正确修法：在 `platform.fs` 补回 `platform_fs_mktemp_handle`，而不是降级 caller。

2. `A1.2` 当前文档里的 Windows 骨架不接受。  
   `platform_fs_is_executable` 不能简单写成“regular file 就是 executable”。  
   否则 Windows 下带显式扩展名的普通文本文件也会被 `ResolveExecutablePath` 误判为可执行。  
   正确要求：Unix 看执行位；Windows 侧至少要与当前 spawn/pathresolve 合同保持一致，不能 blanket `True`。

3. `A1.3` 我不同意把“新建 `platform.error.base` shim”当作默认首选。  
   当前仓库里真正拥有 `PLATFORM_ERR_*` public carrier 的是 `nextpas.core.platform.sync.base`。  
   就当前证据看，`platform.error.pas` 直接依赖 `platform.sync.base` 更小、更真实。  
   只有在明确要给 `platform.error` 建立长期 `base` carrier 时，才值得新增 shim。

4. `2.1` 当前计划漏掉了析构路径。  
   一旦 `TChild.Kill` 改成抛错，`TChild.Destroy` 不能继续直接调公有 `Kill`；否则析构会开始抛异常。  
   需要一个内部 best-effort cleanup 路径，或在析构里吞掉 cleanup error。

### Claude 漏掉的点

我确认至少还有 2 个应写进裁决，但不一定都进首批执行：

1. `platform_fs_mktemp` 的 Windows handle narrowing 风险  
   - 位置：`core/src/nextpas.core.platform.fs.pas:397-404`
   - 性质：不是新 P0，但它解释了为什么 `A1.1` 不能用 legacy fd seam 修过去
   - 处理：作为 `A1.1` 的 acceptance rule 一并修正

2. pipe close 合同仍然 concrete-cast `TPipeWriter`
   - 位置：`core/src/nextpas.core.process.child.pas:142-143, 163, 211, 270`
   - 现象：`TakeStdin`/示例/测试都靠 `TPipeWriter` concrete cast 来 `Close`
   - 建议：在做 `2.2` 时，至少把内部 close 改成接口契约；是否升级 public return type 另行评估
   - 级别：P2 跟随项，不阻塞首批

### 最终优先级排序

1. `P0`
   - 补回 `platform_fs_mktemp_handle` typed seam，保留 `FsTempFile` source-contract
   - 补 `platform_fs_is_executable`
   - 修 `platform.error` 对不存在单元的依赖

2. `P1`
   - `TChild.Wait/TryWait/Kill` 返回码传播
   - `WaitWithOutput` 的 `poll/read` 错误处理 + 抽离 raw POSIX I/O
   - `TCommand.Spawn` 平台化 pipe/null/close 准备逻辑
   - `FsRemoveAll` 根路径保护

3. `P2`
   - `FsWalk` 错误回调补全
   - `FsReadFileText` BOM 剥离 + UTF-8 校验
   - `FsRemoveAll`/`FsWalk` child path join 收口到 path owner
   - pipe close 接口化收尾

4. `P3`
   - text write helper 去重
   - `PATH=` / `PATHEXT=` prefix 常量化
   - `FsCopyFile` owner 收敛

### 首批执行任务列表

我同意的首批执行顺序是：

1. `P0 compile-unblock`
   - `platform_fs_mktemp_handle`
   - `platform_fs_is_executable`
   - `platform.error` dependency fix
   - 目标：`test_fs` / `test_fs_text` / `test_process` / `test_process_pipe_contract` 进入可编译状态

2. `P1 process reliability`
   - `Wait/TryWait/Kill` 错误传播
   - `WaitWithOutput` drain seam + `EINTR` / `EAGAIN` 修正
   - `TCommand.Spawn` 平台化

3. `P1 fs safety`
   - `FsRemoveAll` 根路径保护
   - 若 diff 仍然紧凑，同一批顺手把 child path join 收口到 `FsPathJoin`

4. `P2 text/walk correctness`
   - `FsWalk` 错误回调
   - `FsReadFileText` UTF-8 契约
