# Platform Module Quick Start Guide

> For new developers getting started with `nextpas.core.platform.*`

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
