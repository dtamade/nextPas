# Platform 模块最佳实践

## 概述

本文档提供各平台的开发最佳实践，帮助开发者编写高效、可移植的代码。

## Linux 最佳实践

### 文件描述符管理

```pascal
//✅ 正确：及时关闭文件描述符
var
  LFile: TPlatformFile;
begin
  LFile := platform_file_open('/tmp/test.txt', PLATFORM_FILE_READ, 0);
  if LFile.Handle <> PLATFORM_INVALID_HANDLE then
  begin
    try
      // 使用文件
      platform_file_read(LFile, @LBuf, SizeOf(LBuf));
    finally
      platform_file_close(LFile);
    end;
  end;
end;
```

### 进程管理

```pascal
//✅ 正确：等待子进程退出，避免僵尸进程
var
  LChild: TPlatformProcessId;
  LStatus: Integer;
begin
  LChild := platform_process_spawn('/bin/ls', nil, nil, nil);
  if LChild > 0 then
    platform_process_wait(LChild, LStatus, 0);
end;
```

### 信号处理

```pascal
//✅ 正确：保存和恢复信号处理
var
  LOldAction: TPlatformSignalAction;
begin
  if platform_signal_set(PLATFORM_SIGINT, @LAction, @LOldAction) = 0 then
  begin
    try
      // 业务逻辑
    finally
      platform_signal_set(PLATFORM_SIGINT, @LOldAction, nil);
    end;
  end;
end;
```

### 线程同步

```pascal
//✅ 正确：使用 RAII 模式管理锁
var
  LGuard: ILockGuard;
begin
  LGuard := TLockGuard.Create(FMutex);
  // 临界区代码
  // 离开作用域自动解锁
end;
```

### 内存映射

```pascal
//✅ 正确：映射后及时解除映射
var
  LMapping: TPlatformMmap;
begin
  if platform_mmap_open(LMapping, '/tmp/data.bin', PLATFORM_MMAP_READ) = 0 then
  begin
    try
      // 使用映射内存
    finally
      platform_mmap_close(LMapping);
    end;
  end;
end;
```

## Windows 最佳实践

### 句柄管理

```pascal
//✅ 正确：Windows 句柄使用 0 初始化，用 INVALID_HANDLE_VALUE 检查
var
  LHandle: HANDLE = 0;
begin
  LHandle := CreateFileW(...);
  if LHandle <> INVALID_HANDLE_VALUE then
  begin
    try
      // 使用句柄
    finally
      CloseHandle(LHandle);
    end;
  end;
end;
```

### Unicode 处理

```pascal
//✅ 正确：统一使用 UTF-16 宽字符 API
var
  LPath: UnicodeString;
  LHandle: HANDLE;
begin
  LPath := 'C:\Users\test\file.txt';
  LHandle := CreateFileW(
    PWideChar(LPath),
    GENERIC_READ,
    FILE_SHARE_READ,
    nil,
    OPEN_EXISTING,
    FILE_ATTRIBUTE_NORMAL,
    0
  );
end;

//❌错误：使用 ANSI API 导致中文路径失败
LHandle := CreateFileA(PAnsiChar(LPath), ...);
```

### 错误处理

```pascal
//✅ 正确：获取详细错误信息
var
  LResult: DWORD;
  LErrMsg: array[0..255] of WideChar;
begin
  LResult := GetLastError;
  if LResult <> ERROR_SUCCESS then
  begin
    FormatMessageW(
      FORMAT_MESSAGE_FROM_SYSTEM,
      nil,
      LResult,
      0,
      @LErrMsg,
      SizeOf(LErrMsg),
      nil
    );
    // 记录错误
  end;
end;
```

### 临界区使用

```pascal
//✅ 正确：初始化和销毁临界区
var
  FSection: TRTLCriticalSection;
begin
  InitializeCriticalSection(FSection);
  try
    EnterCriticalSection(FSection);
    try
      // 临界区代码
    finally
      LeaveCriticalSection(FSection);
    end;
  finally
    DeleteCriticalSection(FSection);
  end;
end;
```

### 进程创建

```pascal
//✅ 正确：使用 Unicode 版本的进程创建
var
  LSi: TStartupInfoW;
  LPi: TProcessInformation;
  LCmd: UnicodeString;
begin
  FillChar(LSi, SizeOf(LSi), 0);
  LSi.cb := SizeOf(LSi);
  LCmd := 'notepad.exe C:\test.txt';

  if CreateProcessW(
    nil,
    PWideChar(LCmd),
    nil,
    nil,
    False,
    CREATE_NEW_CONSOLE,
    nil,
    nil,
    LSi,
    LPi
  ) then
  begin
    CloseHandle(LPi.hProcess);
    CloseHandle(LPi.hThread);
  end;
end;
```

## macOS 最佳实践

### 文件系统

```pascal
//✅ 正确：使用 NSFileManager 处理文件属性
// macOS 文件系统大小写不敏感但保留大小写
// 路径中避免使用 :（HFS+ 保留字符）
var
  LPath: String;
begin
  LPath := '/Users/test/Documents/file.txt';
  // 使用 platform_file_open 而非直接 POSIX
end;
```

### 网络编程

```pascal
//✅ 正确：处理 kqueue 的 EVFILT_READ/EVFILT_WRITE
var
  LKq: TPlatformPoller;
  LEvent: TPlatformPollerEvent;
begin
  LKq := platform_poller_create;
  if LKq.Handle <> PLATFORM_INVALID_HANDLE then
  begin
    try
      // 添加事件监听
      platform_poller_add(LKq, LSocket, PLATFORM_EVENT_READ, nil);
      // 事件循环
      platform_poller_wait(LKq, @LEvent, 1, 1000);
    finally
      platform_poller_close(LKq);
    end;
  end;
end;
```

### 信号处理

```pascal
//✅ 正确：macOS 使用 kqueue 处理信号
var
  LKq: TPlatformPoller;
  LSigSet: TPlatformSignalSet;
begin
  LKq := platform_poller_create;
  platform_signal_empty(LSigSet);
  platform_signal_add(LSigSet, PLATFORM_SIGINT);
  // 注册信号到 kqueue
end;
```

## FreeBSD 最佳实践

### 进程管理

```pascal
//✅ 正确：FreeBSD 使用 kqueue 进行进程监控
var
  LKq: TPlatformPoller;
  LChild: TPlatformProcessId;
begin
  LKq := platform_poller_create;
  LChild := platform_process_spawn('/bin/ls', nil, nil, nil);
  // 使用 kqueue 监控子进程退出
end;
```

### 网络编程

```pascal
//✅ 正确：FreeBSD 支持 accept4 系统调用
var
  LSocket: TPlatformSocket;
  LAddr: TPlatformSocketAddress;
  LAddrLen: Integer;
begin
  LSocket := platform_net_socket_create(
    PLATFORM_AF_INET,
    PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP
  );
  // accept4 可以设置 SOCK_NONBLOCK 和 SOCK_CLOEXEC
end;
```

## Android 最佳实践

### JNI 交互

```pascal
//✅ 正确：通过 JNI 调用 Android API
// Android 上 platform 模块通过 JNI 桥接 Java API
// 文件访问需要权限检查
var
  LPath: String;
begin
  // 使用 ContentResolver 而非直接文件路径
  LPath := '/storage/emulated/0/Documents/file.txt';
  // 注意：Android 10+ 限制直接文件访问
end;
```

### 权限管理

```pascal
//✅ 正确：运行时权限检查
// Android 6.0+ 需要运行时权限
// platform 模块提供权限检查接口
begin
  // 检查存储权限
  // 检查网络权限
  // 检查相机权限
end;
```

## 跨平台通用最佳实践

### 1. 资源管理

```pascal
//✅ 正确：使用 try-finally 确保资源释放
var
  LResource: TPlatformResource;
begin
  LResource := platform_resource_create;
  try
    // 使用资源
  finally
    platform_resource_destroy(LResource);
  end;
end;

//❌错误：忘记释放资源
var
  LResource: TPlatformResource;
begin
  LResource := platform_resource_create;
  // 使用资源
  // 忘记释放 - 资源泄漏
end;
```

### 2. 错误处理

```pascal
//✅ 正确：检查所有返回值
var
  LResult: Integer;
begin
  LResult := platform_file_read(LFile, @LBuf, LSize);
  if LResult < 0 then
  begin
    // 处理错误
    LError := platform_error_get_last;
    // 记录或返回错误
  end;
end;

//❌错误：忽略返回值
begin
  platform_file_read(LFile, @LBuf, LSize);
  // 不检查返回值 - 可能失败
end;
```

### 3. 字符串处理

```pascal
//✅ 正确：统一使用 UTF-8 编码
var
  LStr: String;
begin
  LStr := '中文测试';
  // 内部存储为 UTF-8
  // 传递给平台 API 时自动转换
end;

//❌错误：使用 ANSI 编码
var
  LStr: AnsiString;
begin
  LStr := '中文测试';
  // 可能导致编码错误
end;
```

### 4. 字节序处理

```pascal
//✅ 正确：网络字节序转换
var
  LPort: Word;
  LNetPort: Word;
begin
  LPort := 8080;
  LNetPort := htons(LPort); // 主机序→网络序
  LPort := ntohs(LNetPort); // 网络序→主机序
end;

//✅ 正确：处理 IP 地址字节序
var
  LAddr: TPlatformInAddr;
begin
  // sin_addr.s_addr 是网络字节序
  LAddr.s_addr := htonl($7F000001); // 127.0.0.1
end;
```

### 5. 线程安全

```pascal
//✅ 正确：使用原子操作进行无锁编程
var
  FCounter: Integer;
begin
  InterLockedIncrement(FCounter);
  InterLockedDecrement(FCounter);
  InterLockedExchange(FCounter, 0);
end;

//✅ 正确：使用线程局部存储
threadvar
  GThreadBuffer: array[0..1023] of Byte;
begin
  // 每个线程独立的缓冲区
  FillChar(GThreadBuffer, SizeOf(GThreadBuffer), 0);
end;
```

### 6. 内存管理

```pascal
//✅ 正确：使用 IAllocator 接口
var
  LAlloc: IAllocator;
  LMem: Pointer;
begin
  LAlloc := TSystemAllocator.Create;
  LMem := LAlloc.Alloc(1024);
  try
    // 使用内存
  finally
    LAlloc.Free(LMem);
  end;
end;

//✅ 正确：检查分配结果
var
  LMem: Pointer;
begin
  LMem := platform_memory_alloc(1024);
  if LMem = nil then
    raise EOutOfMemory.Create('分配失败');
end;
```

### 7. 异步编程

```pascal
//✅ 正确：使用事件循环进行异步操作
var
  LLoop: TPlatformEventLoop;
begin
  LLoop := TPlatformEventLoop.Create;
  try
    LLoop.AddEvent(LSocket, PLATFORM_EVENT_READ, @OnRead);
    LLoop.AddEvent(LTimer, PLATFORM_EVENT_TIMEOUT, @OnTimeout);
    LLoop.Run;
  finally
    LLoop.Free;
  end;
end;
```

### 8. 测试策略

```pascal
//✅ 正确：编写跨平台测试
procedure TestFileReadWrite;
var
  LFile: TPlatformFile;
  LBuf: array[0..255] of Byte;
  LWritten: Integer;
begin
  // 创建临时文件
  LFile := platform_file_open(
    'test_file.tmp',
    PLATFORM_FILE_CREATE or PLATFORM_FILE_READ_WRITE,
    PLATFORM_FILE_MODE_DEFAULT
  );
  try
    // 写入数据
    LWritten := platform_file_write(LFile, @LTestData, SizeOf(LTestData));
    Check(LWritten = SizeOf(LTestData));

    // 读取数据
    platform_file_seek(LFile, 0, PLATFORM_SEEK_SET);
    platform_file_read(LFile, @LBuf, SizeOf(LBuf));
    Check(CompareMem(@LBuf, @LTestData, SizeOf(LTestData)));
  finally
    platform_file_close(LFile);
    platform_file_unlink('test_file.tmp');
  end;
end;
```

## 常见错误模式

### 1. 资源泄漏

```pascal
//❌错误：异常导致资源泄漏
begin
  LFile := platform_file_open(...);
  // 如果这里抛出异常
  platform_file_close(LFile); // 不会执行
end;

//✅ 正确：使用 try-finally
begin
  LFile := platform_file_open(...);
  try
    // 业务逻辑
  finally
    platform_file_close(LFile);
  end;
end;
```

### 2. 未检查返回值

```pascal
//❌错误：忽略错误
begin
  platform_file_write(LFile, @LData, LSize);
  // 可能写入失败
end;

//✅ 正确：检查返回值
begin
  LWritten := platform_file_write(LFile, @LData, LSize);
  if LWritten < 0 then
    raise EWriteError.Create('写入失败');
end;
```

### 3. 字节序错误

```pascal
//❌错误：直接使用主机序
var
  LAddr: TPlatformSocketAddress;
begin
  LAddr.sin_port := 8080; // 错误：应该是网络序
end;

//✅ 正确：使用 htons 转换
begin
  LAddr.sin_port := htons(8080);
end;
```

### 4. 线程安全问题

```pascal
//❌错误：多线程访问共享变量
var
  FCounter: Integer;
begin
  FCounter := FCounter + 1; // 非原子操作
end;

//✅ 正确：使用原子操作
begin
  InterLockedIncrement(FCounter);
end;
```

## 性能优化建议

### 1. 批量操作

```pascal
//✅ 正确：批量读写减少系统调用
var
  LChunks: array[0..9] of TPlatformIoBuffer;
begin
  // 一次系统调用读取多个块
  platform_file_readv(LFile, @LChunks, 10);
end;

//❌错误：多次小块读写
begin
  for I := 0 to 9 do
    platform_file_read(LFile, @LBuf[I * 1024], 1024);
end;
```

### 2. 缓冲区复用

```pascal
//✅ 正确：复用缓冲区避免频繁分配
var
  LBuf: array[0..65535] of Byte;
begin
  // 重复使用同一缓冲区
  while MoreData do
  begin
    LRead := platform_file_read(LFile, @LBuf, SizeOf(LBuf));
    ProcessData(@LBuf, LRead);
  end;
end;
```

### 3. 异步操作

```pascal
//✅ 正确：使用异步 I/O 提高并发性能
var
  LLoop: TPlatformEventLoop;
begin
  LLoop := TPlatformEventLoop.Create;
  // 注册多个异步操作
  LLoop.AddEvent(LSocket1, PLATFORM_EVENT_READ, @OnRead1);
  LLoop.AddEvent(LSocket2, PLATFORM_EVENT_READ, @OnRead2);
  LLoop.Run; // 事件驱动，高效并发
end;
```

## 调试技巧

### 1. 错误追踪

```pascal
//✅ 正确：记录详细的错误信息
procedure LogError(const AOperation: String);
var
  LError: TPlatformError;
begin
  LError := platform_error_get_last;
  WriteLn(Format('错误: %s 失败, 错误码: %d, 消息: %s',
    [AOperation, LError.Code, LError.Message]));
end;
```

### 2. 资源追踪

```pascal
//✅ 正确：追踪资源分配和释放
{$IFDEF DEBUG}
var
  GAllocCount: Integer = 0;
  GFreeCount: Integer = 0;
{$ENDIF}

procedure TrackAlloc;
begin
  {$IFDEF DEBUG}
  InterLockedIncrement(GAllocCount);
  {$ENDIF}
end;

procedure TrackFree;
begin
  {$IFDEF DEBUG}
  InterLockedIncrement(GFreeCount);
  {$ENDIF}
end;

// 程序结束时检查
finalization
  {$IFDEF DEBUG}
  if GAllocCount <> GFreeCount then
    WriteLn(Format('资源泄漏: 分配 %d, 释放 %d', [GAllocCount, GFreeCount]));
  {$ENDIF}
```

### 3. 性能测量

```pascal
//✅ 正确：使用高精度计时器
var
  LStart, LEnd, LFreq: Int64;
begin
  QueryPerformanceFrequency(LFreq);
  QueryPerformanceCounter(LStart);

  // 业务逻辑

  QueryPerformanceCounter(LEnd);
  WriteLn(Format('耗时: %.3f ms', [(LEnd - LStart) / LFreq * 1000]));
end;
```

## 安全建议

### 1. 输入验证

```pascal
//✅ 正确：验证所有外部输入
function SafePath(const APath: String): String;
begin
  // 检查路径遍历攻击
  if Pos('..', APath) > 0 then
    raise ESecurityError.Create('路径遍历攻击');
  // 检查空字节
  if Pos(#0, APath) > 0 then
    raise ESecurityError.Create('空字节注入');
  Result := APath;
end;
```

### 2. 权限检查

```pascal
//✅ 正确：检查文件权限
var
  LMode: Integer;
begin
  if platform_file_chmod(LPath, PLATFORM_FILE_MODE_DEFAULT) <> 0 then
    raise EPermissionError.Create('权限设置失败');
end;
```

### 3. 安全删除

```pascal
//✅ 正确：安全删除敏感数据
procedure SecureDelete(var AData: array of Byte);
begin
  FillChar(AData, SizeOf(AData), 0); // 覆盖内存
  // 多次覆盖确保无法恢复
  FillChar(AData, SizeOf(AData), $FF);
  FillChar(AData, SizeOf(AData), 0);
end;
```

## 总结

1. **资源管理**：始终使用 try-finally 确保资源释放
2. **错误处理**：检查所有返回值，记录详细错误信息
3. **字符串编码**：统一使用 UTF-8，避免 ANSI 编码
4. **字节序**：网络编程时正确处理字节序转换
5. **线程安全**：使用原子操作和临界区保护共享数据
6. **性能优化**：批量操作、缓冲区复用、异步编程
7. **安全防护**：输入验证、权限检查、安全删除
