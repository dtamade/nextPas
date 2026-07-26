# Platform 模块最佳实践

**权威示例**: 请优先阅读 [EXAMPLES.md](EXAMPLES.md)、[RETURN-SEMANTICS.md](RETURN-SEMANTICS.md)、[ERROR-HANDLING.md](ERROR-HANDLING.md)。
**API 目录**: [API-REFERENCE.md](API-REFERENCE.md)（唯一 API 参考权威）。
**约束**: 禁止 `uses SysUtils` / `BaseUnix` / `Windows` / `Classes`；仅 `nextpas.core.system` 可直接引用 FPC RTL。
**dual-IO**: 禁止新的 `platform_io_read/write/poll` 生产 call site（owner 仅 `platform.process`）。
**console**: `read`/`write` 失败返回 `-1`（value/sentinel），细节走 `platform_get_last_error`。

本文示例与 **live** `core/src/nextpas.core.platform*.pas` 对齐（2026-07-26 audit closeout）。

---

## 1. 文件句柄（error-code + out handle）

```pascal
uses
  nextpas.core.platform.files,
  nextpas.core.platform.files.base,
  nextpas.core.platform.error;

var
  LHandle: TPlatformFileHandle;
  LErr: Int32;
  LRead: PtrUInt;
  LBuf: array[0..255] of AnsiChar;
begin
  LErr := platform_file_open(PAnsiChar('/tmp/test.txt'), fomReadOnly, fcmOpenExisting, LHandle);
  if LErr <> 0 then
    Halt(1);
  try
    FillChar(LBuf, SizeOf(LBuf), 0);
    LErr := platform_file_read(LHandle, @LBuf[0], SizeOf(LBuf) - 1, LRead);
    if LErr <> 0 then
      Halt(1);
  finally
    platform_file_close(LHandle);
  end;
end;
```

## 2. 进程 spawn / wait（error-code）

```pascal
uses
  nextpas.core.platform.process,
  nextpas.core.platform.process.base;

var
  LProc: TPlatformProcess;
  LResult: TPlatformProcessResult;
  LArgv: array[0..1] of PAnsiChar;
  LErr: Int32;
begin
  LArgv[0] := PAnsiChar('/bin/true');
  LArgv[1] := nil;
  LErr := platform_process_spawn(LArgv[0], @LArgv[0], nil, LProc);
  if LErr <> 0 then
    Halt(1);
  LErr := platform_process_wait(LProc, LResult, -1);
  if LErr <> 0 then
    Halt(1);
end;
```

管道字节 I/O 使用 `platform_process_*_ex`（error-code + out 字节数）。
`platform_io_*` 为过渡 dual-API：生产调用仅允许 `platform.process` 定义侧；管道 I/O 走 `platform.files`（见 residual-roadmap F5）。

## 3. Socket（error-code + out socket）

```pascal
uses
  nextpas.core.platform.socket,
  nextpas.core.platform.socket.base,
  nextpas.core.platform.error;

var
  LSock: TPlatformSocket;
  LErr: Int32;
begin
  LErr := platform_socket_create_tcp(LSock);
  if LErr <> 0 then
    Halt(1);
  platform_socket_close(LSock);
end;
```

Socket 只用 `platform_socket_*`；不要使用已删除的历史 net 前缀 API 名。

## 4. 内存映射

```pascal
uses
  nextpas.core.platform.mmap;

var
  LMap: TPlatformMappedFile;
  LErr: Int32;
begin
  LErr := platform_mmap_file(PAnsiChar('/tmp/data.bin'), LMap);
  if LErr <> 0 then
    Halt(1);
  try
    { use LMap }
  finally
    platform_mmap_close(LMap);
  end;
end;
```

## 5. 错误消息（length API）

```pascal
uses
  nextpas.core.platform.error;

var
  LBuf: array[0..255] of AnsiChar;
  LLen: Int32;
begin
  LLen := platform_error_message(PLATFORM_ERR_NOENT, @LBuf[0], SizeOf(LBuf));
  if LLen < 0 then
    { LLen is PLATFORM_ERR_* }
  else
    { LBuf holds message of length LLen };
end;
```

## 6. 反模式

- 把 error-code API 的失败当成 bare `-1` 语义（应使用 `PLATFORM_ERR_*`）。
- 在 platform 生产/测试/示例中 `uses SysUtils` / `BaseUnix` / FPC `Windows`。
- 扩大 `platform_io_*` 使用面；新代码走 `platform.files` / `platform_process_*_ex`。
- 把 Windows 未映射的 raw `ERROR_*` 当作可移植错误码（应为 `PLATFORM_ERR_UNKNOWN`）。

## 7. 宿主诚实

Linux focused-runtime 不等于 Windows/macOS/Android runtime ready。见 [runtime-truth-matrix.md](runtime-truth-matrix.md) 与 [goal-tree.md](goal-tree.md)。
