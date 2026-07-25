# Platform Module Quick Start Guide

> For new developers getting started with `nextpas.core.platform.*`

## Hard rules (do not skip)

1. **No FPC RTL** in production/tests/examples (`SysUtils` / `BaseUnix` / `Windows` / `Classes`). Only `nextpas.core.system` may uses FPC RTL.
2. **No new `platform_io_*` call sites** — dual-IO is permanent owner-only on `platform.process`. Prefer `platform.files` and `platform_process_*_ex`.
3. **console read/write**: success `>= 0` bytes, failure **`-1`** (value/sentinel). Do not treat positive `PLATFORM_ERR_*` as a length.
4. Prefer feature units (`platform.files`, `.process`, `.socket`, …); root `platform` is thin info/time only.
5. Host truth is evidence-tiered — see [host-capability-matrix.md](host-capability-matrix.md).

## Common Patterns

### 1. Open, Read, Close a File

```pascal
uses
  nextpas.core.platform.files,
  nextpas.core.platform.files.base,
  nextpas.core.platform.error;

var
  LHandle: TPlatformFileHandle;
  LBuf: array[0..1023] of Byte;
  LRead: PtrUInt;
  LR: Int32;
begin
  LR := platform_file_open('/path/to/file', fomReadOnly, fcmOpenExisting, LHandle);
  if LR <> 0 then
  begin
    { handle error: LR is PLATFORM_ERR_* code }
    Exit;
  end;

  LR := platform_file_read(LHandle, @LBuf[0], SizeOf(LBuf), LRead);
  if LR <> 0 then
  begin
    platform_file_close(LHandle);
    Exit;
  end;

  { process LBuf[0..LRead-1] }

  platform_file_close(LHandle);
end;
```

### 2. Create and Write a File

```pascal
var
  LHandle: TPlatformFileHandle;
  LWritten: PtrUInt;
begin
  if platform_file_open('/path/to/file', fomWriteOnly, fcmCreateAlways, LHandle) <> 0 then
    Exit;
  try
    if platform_file_write(LHandle, PAnsiChar('hello'), 5, LWritten) <> 0 then
      Exit;
  finally
    platform_file_close(LHandle);
  end;
end;
```

### 3. Check if File Exists

```pascal
uses
  nextpas.core.platform.fs;

begin
  if platform_fs_exists('/path/to/file') then
    { file exists };
end;
```

### 4. Create Directory Recursively

```pascal
uses
  nextpas.core.platform.fs;

begin
  if platform_fs_mkdir_p('/path/to/dir', 493{0755}) <> 0 then
    { handle error };
end;
```

### 5. Spawn a Process

```pascal
uses
  nextpas.core.platform.process;

var
  LProc: TPlatformProcess;
  LResult: TPlatformProcessResult;
begin
  if platform_process_spawn('/bin/ls', nil, nil, LProc) <> 0 then
    Exit;
  platform_process_wait(LProc, LResult, -1);
  { LResult.ExitCode contains exit status }
end;
```

### 6. Create a Socket

```pascal
uses
  nextpas.core.platform.socket;

var
  LSock: TPlatformSocket;
begin
  if platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM, 0, LSock) <> 0 then
    Exit;
  { use platform_socket_bind, listen, accept, connect, etc. }
  platform_socket_close(LSock);
end;
```

### 7. Synchronization

```pascal
uses
  nextpas.core.platform.sync;

var
  LMutex: TPlatformMutex;
begin
  platform_mutex_init(LMutex, 0);
  try
    platform_mutex_lock(LMutex);
    { critical section }
    platform_mutex_unlock(LMutex);
  finally
    platform_mutex_destroy(LMutex);
  end;
end;
```

### 8. Condition Variables

```pascal
uses
  nextpas.core.platform.sync;

var
  LMutex: TPlatformMutex;
  LCond: TPlatformCondVar;
  LReady: Boolean;
begin
  platform_mutex_init(LMutex, 0);
  platform_condvar_init(LCond);
  try
    platform_mutex_lock(LMutex);
    while not LReady do
      platform_condvar_wait(LCond, LMutex);
    { handle condition }
    platform_mutex_unlock(LMutex);
  finally
    platform_condvar_destroy(LCond);
    platform_mutex_destroy(LMutex);
  end;
end;
```

### 9. Dynamic Library Loading

```pascal
uses
  nextpas.core.platform.dl;

var
  Lib: TPlatformLibrary;
  Addr: Pointer;
begin
  if platform_dl_open('libfoo.so', PLATFORM_DL_NOW, Lib) <> 0 then
    Exit;
  try
    if platform_dl_sym(Lib, 'foo_function', Addr) = 0 then
      { call function via Addr }
  finally
    platform_dl_close(LLib);
  end;
end;
```

### 10. Memory-Mapped Files

```pascal
uses
  nextpas.core.platform.mmap;

var
  LMap: TPlatformMappedFile;
begin
  if platform_mmap_file('/path/to/file', LMap) <> 0 then
    Exit;
  try
    { access LMap.Data[0..LMap.Size-1] }
  finally
    platform_mmap_close(LMap);
  end;
end;
```

### 11. Environment Variables

```pascal
uses
  nextpas.core.platform.env;

var
  LBuf: array[0..255] of AnsiChar;
  LLen: Int32;
begin
  if platform_env_get('HOME', @LBuf[0], SizeOf(LBuf), LLen) = 0 then
    { LBuf contains home directory }

  if platform_env_set('MY_VAR', 'value') <> 0 then
    { handle error };

  platform_env_unset('MY_VAR');
end;
```

### 12. Path Operations

```pascal
uses
  nextpas.core.platform.path;

var
  LBuf: array[0..1023] of AnsiChar;
begin
  { Join paths }
  platform_path_join('/home/user', 'file.txt', @LBuf[0], SizeOf(LBuf));

  { Get directory }
  platform_path_dirname('/home/user/file.txt', @LBuf[0], SizeOf(LBuf));

  { Get filename }
  platform_path_basename('/home/user/file.txt', @LBuf[0], SizeOf(LBuf));

  { Check if absolute }
  if platform_path_is_absolute('/home/user') then
    { is absolute path };
end;
```

### 13. Filesystem Operations

```pascal
uses
  nextpas.core.platform.fs;

var
  LBuf: array[0..1023] of AnsiChar;
  LLen: Int32;
begin
  { Get current directory }
  if platform_fs_getcwd(@LBuf[0], SizeOf(LBuf), LLen) = 0 then
    { LBuf contains current directory }

  { Change directory }
  if platform_fs_chdir('/tmp') <> 0 then
    { handle error };

  { Remove file }
  if platform_fs_unlink('/tmp/file.txt') <> 0 then
    { handle error };

  { Rename file }
  if platform_fs_rename('/tmp/old.txt', '/tmp/new.txt') <> 0 then
    { handle error };
end;
```

### 14. Thread Creation

```pascal
uses
  nextpas.core.platform.thread;

function MyThreadFunc(AArg: Pointer): Int32;
begin
  { thread work }
  Result := 0;
end;

var
  LThread: TPlatformThread;
begin
  if platform_thread_create(@MyThreadFunc, nil, LThread) <> 0 then
    Exit;
  platform_thread_join(LThread, -1);
end;
```

### 15. Timer and Time

```pascal
uses
  nextpas.core.platform.time;

var
  LStart, LEnd: UInt64;
begin
  LStart := platform_time_monotonic_us;
  { do work }
  LEnd := platform_time_monotonic_us;
  { elapsed = LEnd - LStart microseconds }
end;
```

## Error Handling

All functions return `Int32` error codes:
- `0` = success
- `PLATFORM_ERR_*` = portable error code
- Positive values = system errno (POSIX) or GetLastError (Windows)

Use `platform_error_message()` to get human-readable error text.

### Error Handling Best Practices

```pascal
uses
  nextpas.core.platform.error;

var
  LBuf: array[0..255] of AnsiChar;
  LLen: Int32;
begin
  { Get error message }
  LLen := platform_error_message(LR, @LBuf[0], SizeOf(LBuf));
  if LLen > 0 then
    { LBuf contains error message }

  { Check error category }
  case platform_error_category(LR) of
    ecNotFound: { file not found };
    ecPermission: { permission denied };
    ecInvalidArgument: { invalid parameter };
    ecTimeout: { operation timed out };
  end;
end;
```

## Key Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `PLATFORM_ERR_INVALID` | 22 | Invalid argument |
| `PLATFORM_ERR_ENOENT` | 2 | No such file or directory |
| `PLATFORM_ERR_BADF` | 9 | Bad file descriptor |
| `PLATFORM_ERR_UNSUPPORTED` | 95 | Operation not supported |

## Platform Support

| Platform | Status |
|----------|--------|
| Linux x86_64 | Primary target |
| Windows x86_64 | Full support (Wine tested) |
| macOS | Source contract |
| FreeBSD | Source contract |
| Android | Cross-compile |
