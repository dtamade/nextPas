# Platform 错误处理最佳实践

**日期**: 2026-07-06
**版本**: v1.0
**状态**: 活跃

---

## 1. 错误码体系

### 1.1 PLATFORM_ERR_* 常量

platform 模块使用统一的错误码常量，定义在 `nextpas.core.platform.error`：

| 常量 | 值 | 含义 |
|------|-----|------|
| `PLATFORM_ERR_OK` | 0 | 成功 |
| `PLATFORM_ERR_INVALID` | -1 | 无效参数 |
| `PLATFORM_ERR_NOT_FOUND` | -2 | 文件/资源不存在 |
| `PLATFORM_ERR_EXISTS` | -3 | 文件/资源已存在 |
| `PLATFORM_ERR_ACCESS` | -4 | 权限不足 |
| `PLATFORM_ERR_BUSY` | -5 | 资源忙 |
| `PLATFORM_ERR_FULL` | -6 | 磁盘/空间满 |
| `PLATFORM_ERR_TIMEOUT` | -7 | 操作超时 |
| `PLATFORM_ERR_ABORTED` | -8 | 操作被中止 |
| `PLATFORM_ERR_IO` | -9 | I/O 错误 |
| `PLATFORM_ERR_NETWORK` | -10 | 网络错误 |
| `PLATFORM_ERR_UNSUPPORTED` | -11 | 不支持的操作 |

### 1.2 平台错误码转换

```pascal
uses
  nextpas.core.platform.error;

// 获取平台错误码
var
  LPlatformErr: Int32;
begin
  LPlatformErr := platform_error_get_last();
  
  // 转换为 PLATFORM_ERR_*
  var LErr: Int32;
  LErr := platform_error_to_platform(LPlatformErr);
  
  // 获取错误消息
  var LBuf: array[0..255] of AnsiChar;
  platform_error_message(LErr, @LBuf[0], Length(LBuf));
end;
```

---

## 2. 函数返回值约定

### 2.1 成功/失败模式

```pascal
// 模式 A: 返回 PLATFORM_ERR_* 错误码
function platform_do_something(): Int32;
begin
  if not_valid then
    Exit(PLATFORM_ERR_INVALID);
  // ...
  Result := PLATFORM_ERR_OK;
end;

// 调用方
var LErr: Int32;
LErr := platform_do_something();
if LErr <> PLATFORM_ERR_OK then
  HandleError(LErr);
```

### 2.2 长度/大小模式

```pascal
// 模式 B: 返回长度/大小，负数表示错误
function platform_get_name(ABuf: PAnsiChar; ABufSize: Int32): Int32;
begin
  if (ABuf = nil) or (ABufSize <= 0) then
    Exit(PLATFORM_ERR_INVALID);
  // ...
  Result := Length(Name);  // 成功返回长度
end;

// 调用方
var LLen: Int32;
LLen := platform_get_name(@LBuf[0], Length(LBuf));
if LLen < 0 then
  HandleError(LLen)
else
  ProcessName(@LBuf[0], LLen);
```

### 2.3 布尔模式

```pascal
// 模式 C: 返回 Boolean
function platform_file_exists(APath: PAnsiChar): Boolean;
begin
  if APath = nil then
    Exit(False);
  // ...
  Result := Found;
end;

// 调用方
if platform_file_exists('/tmp/test') then
  DoSomething();
```

---

## 3. nil Guard 规范

### 3.1 必须检查的参数

所有指针参数必须在使用前检查：

```pascal
function platform_do_something(APath: PAnsiChar; AOut: PInt32): Int32;
begin
  // ✅ 正确：检查所有指针参数
  if APath = nil then
    Exit(PLATFORM_ERR_INVALID);
  if AOut = nil then
    Exit(PLATFORM_ERR_INVALID);
  // ...
end;
```

### 3.2 可选参数处理

```pascal
function platform_get_info(ABuf: PAnsiChar; ABufSize: Int32): Int32;
begin
  // ABuf = nil 表示"查询所需大小"
  if ABuf = nil then
    Exit(RequiredSize);
  
  // ABufSize <= 0 表示缓冲区太小
  if ABufSize < RequiredSize then
    Exit(PLATFORM_ERR_INVALID);
  // ...
end;
```

### 3.3 输出参数初始化

```pascal
function platform_query(out AResult: TSomeRecord): Int32;
begin
  // ✅ 正确：始终初始化输出参数
  FillChar(AResult, SizeOf(AResult), 0);
  // ...
end;
```

---

## 4. 错误传播策略

### 4.1 直接传播

```pascal
function platform_high_level(): Int32;
var
  LErr: Int32;
begin
  LErr := platform_low_level();
  if LErr <> PLATFORM_ERR_OK then
    Exit(LErr);  // 直接传播底层错误
  // ...
  Result := PLATFORM_ERR_OK;
end;
```

### 4.2 错误转换

```pascal
function platform_convert_error(APlatformErr: Int32): Int32;
begin
  case APlatformErr of
    0: Result := PLATFORM_ERR_OK;
    ENOENT: Result := PLATFORM_ERR_NOT_FOUND;
    EEXIST: Result := PLATFORM_ERR_EXISTS;
    EACCES: Result := PLATFORM_ERR_ACCESS;
    EBUSY: Result := PLATFORM_ERR_BUSY;
    ENOSPC: Result := PLATFORM_ERR_FULL;
    ETIMEDOUT: Result := PLATFORM_ERR_TIMEOUT;
  else
    Result := PLATFORM_ERR_IO;
  end;
end;
```

### 4.3 错误日志

```pascal
uses
  nextpas.core.log;

function platform_do_something(): Int32;
begin
  // ...
  if LErr <> PLATFORM_ERR_OK then
  begin
    np_log_error('platform_do_something failed: %d', [LErr]);
    Exit(LErr);
  end;
  // ...
end;
```

---

## 5. 资源清理模式

### 5.1 try/finally 模式

```pascal
function platform_copy_file(ASrc, ADst: PAnsiChar): Int32;
var
  LSrcHandle, LDstHandle: HANDLE;
begin
  LSrcHandle := INVALID_HANDLE_VALUE;
  LDstHandle := INVALID_HANDLE_VALUE;
  try
    LSrcHandle := CreateFileA(ASrc, ...);
    if LSrcHandle = INVALID_HANDLE_VALUE then
      Exit(PLATFORM_ERR_IO);
    
    LDstHandle := CreateFileA(ADst, ...);
    if LDstHandle = INVALID_HANDLE_VALUE then
      Exit(PLATFORM_ERR_IO);
    
    // ... 复制操作 ...
    Result := PLATFORM_ERR_OK;
  finally
    if LSrcHandle <> INVALID_HANDLE_VALUE then
      CloseHandle(LSrcHandle);
    if LDstHandle <> INVALID_HANDLE_VALUE then
      CloseHandle(LDstHandle);
  end;
end;
```

### 5.2 错误时清理

```pascal
function platform_create_and_init(): Int32;
var
  LHandle: HANDLE;
begin
  LHandle := CreateFileA(...);
  if LHandle = INVALID_HANDLE_VALUE then
    Exit(PLATFORM_ERR_IO);
  
  if not InitializeSomething(LHandle) then
  begin
    CloseHandle(LHandle);  // 失败时清理
    Exit(PLATFORM_ERR_IO);
  end;
  
  // 成功，返回句柄
  Result := LHandle;
end;
```

---

## 6. 跨平台错误处理

### 6.1 平台差异处理

```pascal
function platform_delete_file(APath: PAnsiChar): Int32;
begin
{$IFDEF NEXTPAS_WINDOWS}
  if not DeleteFileA(APath) then
    Exit(platform_error_to_platform(GetLastError));
{$ELSE}
  if unlink(APath) <> 0 then
    Exit(platform_error_to_platform(errno));
{$ENDIF}
  Result := PLATFORM_ERR_OK;
end;
```

### 6.2 统一错误码映射

```pascal
// Windows 错误码映射
function windows_error_to_platform(AWinErr: DWORD): Int32;
begin
  case AWinErr of
    ERROR_SUCCESS: Result := PLATFORM_ERR_OK;
    ERROR_FILE_NOT_FOUND: Result := PLATFORM_ERR_NOT_FOUND;
    ERROR_PATH_NOT_FOUND: Result := PLATFORM_ERR_NOT_FOUND;
    ERROR_ACCESS_DENIED: Result := PLATFORM_ERR_ACCESS;
    ERROR_ALREADY_EXISTS: Result := PLATFORM_ERR_EXISTS;
    ERROR_BUSY: Result := PLATFORM_ERR_BUSY;
    ERROR_DISK_FULL: Result := PLATFORM_ERR_FULL;
    ERROR_TIMEOUT: Result := PLATFORM_ERR_TIMEOUT;
    ERROR_OPERATION_ABORTED: Result := PLATFORM_ERR_ABORTED;
  else
    Result := PLATFORM_ERR_IO;
  end;
end;

// POSIX 错误码映射
function posix_error_to_platform(APosixErr: Int32): Int32;
begin
  case APosixErr of
    0: Result := PLATFORM_ERR_OK;
    ENOENT: Result := PLATFORM_ERR_NOT_FOUND;
    EEXIST: Result := PLATFORM_ERR_EXISTS;
    EACCES: Result := PLATFORM_ERR_ACCESS;
    EBUSY: Result := PLATFORM_ERR_BUSY;
    ENOSPC: Result := PLATFORM_ERR_FULL;
    ETIMEDOUT: Result := PLATFORM_ERR_TIMEOUT;
    EINTR: Result := PLATFORM_ERR_ABORTED;
  else
    Result := PLATFORM_ERR_IO;
  end;
end;
```

---

## 7. 常见错误场景

### 7.1 文件操作

```pascal
function platform_safe_open(APath: PAnsiChar; AMode: Int32): Int32;
var
  LHandle: HANDLE;
begin
  if APath = nil then
    Exit(PLATFORM_ERR_INVALID);
  
{$IFDEF NEXTPAS_WINDOWS}
  LHandle := CreateFileA(APath, GENERIC_READ, FILE_SHARE_READ, nil, 
    OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  if LHandle = INVALID_HANDLE_VALUE then
    Exit(windows_error_to_platform(GetLastError));
{$ELSE}
  LHandle := open(APath, O_RDONLY);
  if LHandle < 0 then
    Exit(posix_error_to_platform(errno));
{$ENDIF}
  
  Result := LHandle;
end;
```

### 7.2 内存分配

```pascal
function platform_safe_alloc(ASize: SizeUInt): Pointer;
begin
  if ASize = 0 then
    Exit(nil);
  
  Result := platform_memory_alloc(ASize);
  if Result = nil then
    Exit(nil);  // 分配失败
end;
```

### 7.3 网络操作

```pascal
function platform_safe_connect(ASocket: Int32; 
  const AAddr: TPlatformSockAddr): Int32;
var
  LRet: Int32;
begin
  LRet := platform_socket_connect(ASocket, AAddr);
  if LRet <> 0 then
  begin
    // 网络错误使用 PLATFORM_ERR_NETWORK
    Exit(PLATFORM_ERR_NETWORK);
  end;
  Result := PLATFORM_ERR_OK;
end;
```

---

## 8. 错误处理检查清单

### 8.1 代码审查要点

- [ ] 所有指针参数都有 nil guard
- [ ] 输出参数在错误路径前初始化
- [ ] 资源在错误路径中正确释放
- [ ] 错误码正确传播，不丢失信息
- [ ] 平台特定错误正确转换
- [ ] 错误日志记录足够信息用于调试

### 8.2 测试要点

- [ ] nil 参数测试
- [ ] 无效参数测试
- [ ] 资源不足测试
- [ ] 权限不足测试
- [ ] 并发访问测试
- [ ] 超时测试

---

## 9. 最佳实践总结

1. **始终使用 PLATFORM_ERR_* 常量**，不要使用魔术数字
2. **nil guard 所有指针参数**，返回 PLATFORM_ERR_INVALID
3. **初始化输出参数**，即使函数失败
4. **使用 try/finally** 确保资源释放
5. **传播底层错误**，不要吞掉错误信息
6. **记录错误日志**，便于调试
7. **统一错误码映射**，保持跨平台一致性
8. **测试错误路径**，确保健壮性

---

**文档维护**: 随 platform 模块演进更新
**最后更新**: 2026-07-06
