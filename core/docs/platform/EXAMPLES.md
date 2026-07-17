# Platform 示例代码库

## 概述

常见跨平台场景的**可对齐 live API** 示例。

**规则**:

- 示例 `uses` 只允许 `nextpas.core.platform.*`（及文档已引用的 core 类型）。
- **禁止** `SysUtils` / `BaseUnix` / `Windows` / `Classes`。
- 权威签名以 `core/src/nextpas.core.platform*.pas` 与 [CONTRACT.md](CONTRACT.md) 为准。
- 返回语义见 [RETURN-SEMANTICS.md](RETURN-SEMANTICS.md)：error-code / length / value-sentinel 三档。

## 1. 文件读写（`platform.files`）

```pascal
program FileReadWrite;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.platform.files,
  nextpas.core.platform.files.base,
  nextpas.core.platform.error;

const
  FILE_PATH = 'example.txt';
  CONTENT = 'Hello, Platform!';

var
  LHandle: TPlatformFileHandle;
  LBuf: array[0..255] of AnsiChar;
  LErr: Int32;
  LWritten, LRead: PtrUInt;
begin
  LErr := platform_file_open(PAnsiChar(FILE_PATH), fomReadWrite, fcmCreateAlways, LHandle);
  if LErr <> 0 then
  begin
    WriteLn('create/open failed: ', LErr);
    Halt(1);
  end;

  LErr := platform_file_write(LHandle, @CONTENT[1], Length(CONTENT), LWritten);
  if LErr <> 0 then
    WriteLn('write failed: ', LErr)
  else
    WriteLn('wrote: ', LWritten);

  platform_file_close(LHandle);

  LErr := platform_file_open(PAnsiChar(FILE_PATH), fomReadOnly, fcmOpenExisting, LHandle);
  if LErr <> 0 then
    Halt(1);

  FillChar(LBuf, SizeOf(LBuf), 0);
  LErr := platform_file_read(LHandle, @LBuf[0], SizeOf(LBuf) - 1, LRead);
  if LErr = 0 then
    WriteLn('read: ', LBuf, ' (', LRead, ' bytes)');

  platform_file_close(LHandle);
  platform_file_unlink(PAnsiChar(FILE_PATH));
end.
```

## 2. 路径存在与大小（`platform.fs`）

```pascal
program FileInfo;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.platform.fs,
  nextpas.core.platform.error;

var
  LSize: Int64;
  LErr: Int32;
begin
  if platform_fs_exists(PAnsiChar('/etc/hosts')) then
  begin
    LErr := platform_fs_file_size(PAnsiChar('/etc/hosts'), LSize);
    if LErr = 0 then
      WriteLn('size: ', LSize)
    else
      WriteLn('size failed: ', LErr);
  end
  else
    WriteLn('not found');
end.
```

## 3. 目录创建（`platform.files`）

```pascal
program DirOperations;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.platform.files,
  nextpas.core.platform.error;

const
  DIR_PATH = 'test_directory';
  DIR_MODE = $1FF; { 0777 }

begin
  if platform_file_mkdir(PAnsiChar(DIR_PATH), DIR_MODE) = 0 then
    WriteLn('mkdir ok')
  else
    WriteLn('mkdir failed');

  if platform_file_rmdir(PAnsiChar(DIR_PATH)) = 0 then
    WriteLn('rmdir ok');
end.
```

## 4. 环境变量（`platform.env`）

```pascal
program EnvVars;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.platform.env;

var
  LValue: AnsiString;
begin
  LValue := platform_env_get_str('PATH');
  WriteLn('PATH = ', LValue);

  if platform_env_set(PAnsiChar('MY_VAR'), PAnsiChar('Hello')) = 0 then
    WriteLn('MY_VAR = ', platform_env_get_str('MY_VAR'));

  platform_env_unset(PAnsiChar('MY_VAR'));
  if not platform_env_exists(PAnsiChar('MY_VAR')) then
    WriteLn('MY_VAR unset');
end.
```

## 5. 时间（`platform.time`）

```pascal
program TimeDemo;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.platform.time;

var
  LNow, LMono: Int64;
begin
  LNow := platform_time_now;
  WriteLn('wall seconds: ', LNow);

  LMono := platform_time_monotonic;
  WriteLn('monotonic ns: ', LMono);
end.
```

## 6. TCP 连接（`platform.socket`）

```pascal
program TcpConnect;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.platform.socket,
  nextpas.core.platform.error;

var
  LSock: TPlatformSocket;
  LErr: Int32;
  LSent, LRecvd: Int32;
  LReq: AnsiString;
  LBuf: array[0..1023] of AnsiChar;
begin
  { 127.0.0.1:80 — address is host-order UInt32 per live API }
  LErr := platform_socket_create_tcp_connect($7F000001, 80, LSock);
  if LErr <> 0 then
  begin
    WriteLn('connect failed: ', LErr);
    Halt(1);
  end;

  LReq := 'GET / HTTP/1.0' + #13#10 + #13#10;
  LErr := platform_socket_send(LSock, @LReq[1], Length(LReq), 0, LSent);
  if LErr = 0 then
    WriteLn('sent: ', LSent);

  FillChar(LBuf, SizeOf(LBuf), 0);
  LErr := platform_socket_recv(LSock, @LBuf[0], SizeOf(LBuf) - 1, 0, LRecvd);
  if LErr = 0 then
    WriteLn('recv: ', LRecvd, ' bytes');

  platform_socket_close(LSock);
end.
```

## 7. 错误消息（`platform.error`）

```pascal
program ErrorDemo;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.platform.error,
  nextpas.core.exception;

var
  LBuf: array[0..127] of AnsiChar;
  LLen: Int32;
begin
  LLen := platform_error_message(PLATFORM_ERR_NOENT, @LBuf[0], SizeOf(LBuf));
  if LLen > 0 then
    WriteLn(LBuf);

  WriteLn('category NOENT ordinal: ', Ord(platform_error_category(PLATFORM_ERR_NOENT)));
  WriteLn('UNKNOWN = ', PLATFORM_ERR_UNKNOWN);
end.
```

## 8. 解析（`platform.fmt`）

```pascal
program ParseDemo;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.platform.fmt,
  nextpas.core.platform.error;

var
  LVal: Int64;
  LErr: Int32;
begin
  LErr := platform_parse_int(PAnsiChar('42'), 2, LVal);
  if LErr = 0 then
    WriteLn('value: ', LVal);

  LErr := platform_parse_int(PAnsiChar('x'), 1, LVal);
  if LErr = PLATFORM_ERR_INVALID then
    WriteLn('invalid input (not bare -1)');
end.
```

## 9. 进程管道 IO 偏好（`platform.process`）

新代码使用 `platform_process_*_ex`（error-code + out 字节数）。
`platform_io_*` 为过渡 dual-API：生产调用仅允许 `platform.process` 定义侧；管道 I/O 走 `platform.files` / 本地 poll，勿新增 consumer。
见 [RETURN-SEMANTICS.md](RETURN-SEMANTICS.md) Dual API 表。

## 10. 反模式

```pascal
// 禁止：uses SysUtils / BaseUnix / Windows / Classes
// 禁止：error-code API 把 -1 当可移植错误码（用 PLATFORM_ERR_*）
// 禁止：假设 Windows raw ERROR_* 会出现在 platform_get_last_error 结果中
//       （未映射码为 PLATFORM_ERR_UNKNOWN）
```
