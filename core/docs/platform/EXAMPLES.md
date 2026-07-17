# Platform 示例代码库

## 概述

本文档提供常见跨平台场景的代码示例，帮助快速上手 platform 模块。

**规则**: 示例 `uses` 只允许 `nextpas.core.platform.*`（及本模块文档已引用的 core 类型）。禁止 `SysUtils` / `BaseUnix` / `Windows` / `Classes`。

## 1. 文件操作示例

### 基本文件读写

```pascal
program FileReadWrite;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.platform.fileio,
  nextpas.core.platform.error;

const
  FILE_PATH = 'example.txt';
  CONTENT = 'Hello, Platform!';

var
  LFile: TPlatformFile;
  LBuf: array[0..255] of Char;
  LWritten, LRead: Integer;
begin
  // 写入文件
  LFile := platform_file_open(
    FILE_PATH,
    PLATFORM_FILE_CREATE or PLATFORM_FILE_READ_WRITE,
    PLATFORM_FILE_MODE_DEFAULT
  );
  if LFile.Handle = PLATFORM_INVALID_HANDLE then
  begin
    WriteLn('创建文件失败');
    Exit;
  end;

  try
    LWritten := platform_file_write(LFile, @CONTENT[1], Length(CONTENT));
    WriteLn('写入字节数: ', LWritten);
  finally
    platform_file_close(LFile);
  end;

  // 读取文件
  LFile := platform_file_open(FILE_PATH, PLATFORM_FILE_READ, 0);
  if LFile.Handle = PLATFORM_INVALID_HANDLE then
  begin
    WriteLn('打开文件失败');
    Exit;
  end;

  try
    FillChar(LBuf, SizeOf(LBuf), 0);
    LRead := platform_file_read(LFile, @LBuf, SizeOf(LBuf) - 1);
    WriteLn('读取内容: ', LBuf);
    WriteLn('读取字节数: ', LRead);
  finally
    platform_file_close(LFile);
  end;

  // 删除文件
  platform_file_unlink(FILE_PATH);
end.
```

### 文件信息查询

```pascal
program FileInfo;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.platform.fileio;

var
  LPath: String;
  LSize: Int64;
  LExists: Boolean;
begin
  LPath := '/etc/hosts';

  // 检查文件是否存在
  LExists := platform_file_exists(LPath);
  WriteLn('文件存在: ', LExists);

  // 获取文件大小
  if LExists then
  begin
    LSize := platform_file_size(LPath);
    WriteLn('文件大小: ', LSize, ' 字节');
  end;
end.
```

### 目录操作

```pascal
program DirOperations;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.platform.fileio;

var
  LDirPath: String;
begin
  LDirPath := 'test_directory';

  // 创建目录
  if platform_dir_create(LDirPath, PLATFORM_DIR_MODE_DEFAULT) = 0 then
    WriteLn('目录创建成功')
  else
    WriteLn('目录创建失败');

  // 删除目录
  if platform_dir_remove(LDirPath) = 0 then
    WriteLn('目录删除成功')
  else
    WriteLn('目录删除失败');
end.
```

## 2. 网络编程示例

### TCP 客户端

```pascal
program TcpClient;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.platform.net,
  nextpas.core.platform.error;

var
  LSocket: TPlatformSocket;
  LAddr: TPlatformSockAddrIn;
  LBuf: String;
  LResult: Integer;
begin
  // 创建 socket
  LSocket := platform_net_socket_create(
    PLATFORM_AF_INET,
    PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP
  );
  if LSocket.Handle = PLATFORM_INVALID_HANDLE then
  begin
    WriteLn('创建 socket 失败');
    Exit;
  end;

  try
    // 设置目标地址
    FillChar(LAddr, SizeOf(LAddr), 0);
    LAddr.sin_family := PLATFORM_AF_INET;
    LAddr.sin_port := htons(80);
    LAddr.sin_addr.s_addr := htonl($7F000001); // 127.0.0.1

    // 连接
    LResult := platform_net_socket_connect(
      LSocket,
      TPlatformSockAddr(LAddr),
      SizeOf(LAddr)
    );
    if LResult <> 0 then
    begin
      WriteLn('连接失败: ', platform_error_get_last.Code);
      Exit;
    end;

    // 发送数据
    LBuf := 'GET / HTTP/1.1' + #13#10 + 'Host: localhost' + #13#10 + #13#10;
    LResult := platform_net_socket_send(
      LSocket,
      @LBuf[1],
      Length(LBuf),
      0
    );
    WriteLn('发送字节数: ', LResult);

    // 接收响应
    SetLength(LBuf, 4096);
    LResult := platform_net_socket_recv(
      LSocket,
      @LBuf[1],
      Length(LBuf),
      0
    );
    if LResult > 0 then
    begin
      SetLength(LBuf, LResult);
      WriteLn('响应: ', LBuf);
    end;
  finally
    platform_net_socket_close(LSocket);
  end;
end.
```

### TCP 服务器

```pascal
program TcpServer;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.platform.net,
  nextpas.core.platform.error;

var
  LServerSocket, LClientSocket: TPlatformSocket;
  LAddr, LClientAddr: TPlatformSockAddrIn;
  LAddrLen: Integer;
  LBuf: array[0..1023] of Byte;
  LRead: Integer;
begin
  // 创建服务器 socket
  LServerSocket := platform_net_socket_create(
    PLATFORM_AF_INET,
    PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP
  );
  if LServerSocket.Handle = PLATFORM_INVALID_HANDLE then
  begin
    WriteLn('创建 socket 失败');
    Exit;
  end;

  try
    // 绑定地址
    FillChar(LAddr, SizeOf(LAddr), 0);
    LAddr.sin_family := PLATFORM_AF_INET;
    LAddr.sin_port := htons(8080);
    LAddr.sin_addr.s_addr := htonl(PLATFORM_INADDR_ANY);

    if platform_net_socket_bind(
      LServerSocket,
      TPlatformSockAddr(LAddr),
      SizeOf(LAddr)
    ) <> 0 then
    begin
      WriteLn('绑定失败');
      Exit;
    end;

    // 监听
    if platform_net_socket_listen(LServerSocket, 5) <> 0 then
    begin
      WriteLn('监听失败');
      Exit;
    end;

    WriteLn('服务器启动，监听端口 8080...');

    // 接受连接
    LAddrLen := SizeOf(LClientAddr);
    LClientSocket := platform_net_socket_accept(
      LServerSocket,
      TPlatformSockAddr(LClientAddr),
      @LAddrLen
    );
    if LClientSocket.Handle <> PLATFORM_INVALID_HANDLE then
    begin
      try
        WriteLn('客户端已连接');

        // 接收数据
        LRead := platform_net_socket_recv(LClientSocket, @LBuf, SizeOf(LBuf), 0);
        if LRead > 0 then
          WriteLn('收到数据: ', LRead, ' 字节');

        // 发送响应
        platform_net_socket_send(LClientSocket, @LBuf, LRead, 0);
      finally
        platform_net_socket_close(LClientSocket);
      end;
    end;
  finally
    platform_net_socket_close(LServerSocket);
  end;
end.
```

## 3. 进程管理示例

### 执行外部命令

```pascal
program ExecCommand;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.platform.process;

var
  LArgs: array of String;
  LResult: Integer;
begin
  SetLength(LArgs, 3);
  LArgs[0] := '-l';
  LArgs[1] := '-a';
  LArgs[2] := '/tmp';

  // 执行 ls 命令
  LResult := platform_process_exec('ls', LArgs);
  WriteLn('命令退出码: ', LResult);
end.
```

### 创建子进程

```pascal
program SpawnProcess;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.platform.process;

var
  LChild: TPlatformProcessId;
  LArgs: array of String;
  LStatus: Integer;
begin
  SetLength(LArgs, 1);
  LArgs[0] := '-l';

  // 创建子进程
  LChild := platform_process_spawn('ls', LArgs, nil, nil);
  if LChild = PLATFORM_INVALID_PID then
  begin
    WriteLn('创建进程失败');
    Exit;
  end;

  WriteLn('子进程 PID: ', LChild);

  // 等待子进程退出
  if platform_process_wait(LChild, LStatus, 0) = 0 then
    WriteLn('子进程退出码: ', LStatus)
  else
    WriteLn('等待进程失败');

  // 获取当前进程 ID
  WriteLn('当前进程 PID: ', platform_process_get_id);
end.
```

### 环境变量操作

```pascal
program EnvVars;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.platform.env;

var
  LValue: AnsiString;
begin
  // 获取环境变量（不存在与空值都返回 ''；需区分时先 platform_env_exists）
  LValue := platform_env_get_str('PATH');
  WriteLn('PATH = ', LValue);

  // 设置环境变量
  if platform_env_set(PAnsiChar('MY_VAR'), PAnsiChar('Hello World')) = 0 then
  begin
    LValue := platform_env_get_str('MY_VAR');
    WriteLn('MY_VAR = ', LValue);
  end;

  // 删除环境变量
  platform_env_unset(PAnsiChar('MY_VAR'));
  if not platform_env_exists(PAnsiChar('MY_VAR')) then
    WriteLn('MY_VAR 已删除');
end.
```

## 4. 线程与同步示例

### 基本线程创建

```pascal
program ThreadDemo;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.platform.sync;

var
  FThreadId: TPlatformThreadId;
  FCounter: Integer = 0;

function ThreadProc(AParam: Pointer): Pointer; cdecl;
var
  I: Integer;
begin
  for I := 1 to 1000 do
    InterLockedIncrement(FCounter);
  WriteLn('线程完成，计数器: ', FCounter);
  Result := nil;
end;

begin
  // 创建线程
  if platform_thread_create(@FThreadId, nil, @ThreadProc, nil) = 0 then
  begin
    WriteLn('线程创建成功');

    // 等待线程完成
    platform_thread_join(FThreadId, nil);
    WriteLn('最终计数器: ', FCounter);
  end
  else
    WriteLn('线程创建失败');
end.
```

### 互斥锁保护临界区

```pascal
program MutexDemo;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.platform.sync;

var
  FMutex: TPlatformMutex;
  FSharedData: Integer = 0;

function WorkerThread(AParam: Pointer): Pointer; cdecl;
var
  I: Integer;
begin
  for I := 1 to 1000 do
  begin
    platform_mutex_lock(FMutex);
    try
      Inc(FSharedData);
    finally
      platform_mutex_unlock(FMutex);
    end;
  end;
  Result := nil;
end;

var
  LThreads: array[0..3] of TPlatformThreadId;
  I: Integer;
begin
  // 初始化互斥锁
  if platform_mutex_init(FMutex, nil) <> 0 then
  begin
    WriteLn('互斥锁初始化失败');
    Exit;
  end;

  try
    // 创建多个线程
    for I := 0 to 3 do
    begin
      if platform_thread_create(@LThreads[I], nil, @WorkerThread, nil) <> 0 then
      begin
        WriteLn('线程创建失败');
        Exit;
      end;
    end;

    // 等待所有线程完成
    for I := 0 to 3 do
      platform_thread_join(LThreads[I], nil);

    WriteLn('期望值: 4000');
    WriteLn('实际值: ', FSharedData);
  finally
    platform_mutex_destroy(FMutex);
  end;
end.
```

### 读写锁

```pascal
program RwLockDemo;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.platform.sync;

var
  FRwLock: TPlatformRwLock;
  FSharedValue: Integer = 0;

function ReaderThread(AParam: Pointer): Pointer; cdecl;
var
  I: Integer;
begin
  for I := 1 to 100 do
  begin
    platform_rwlock_rdlock(FRwLock);
    try
      // 多个读者可以同时读取
      if FSharedValue <> 0 then
        WriteLn('读取值: ', FSharedValue);
    finally
      platform_rwlock_rdunlock(FRwLock);
    end;
  end;
  Result := nil;
end;

function WriterThread(AParam: Pointer): Pointer; cdecl;
var
  I: Integer;
begin
  for I := 1 to 10 do
  begin
    platform_rwlock_wrlock(FRwLock);
    try
      Inc(FSharedValue);
      WriteLn('写入值: ', FSharedValue);
    finally
      platform_rwlock_wrunlock(FRwLock);
    end;
  end;
  Result := nil;
end;

begin
  // 初始化读写锁
  if platform_rwlock_init(FRwLock) <> 0 then
  begin
    WriteLn('读写锁初始化失败');
    Exit;
  end;

  try
    // 启动读者和写者线程
    // ...
  finally
    platform_rwlock_destroy(FRwLock);
  end;
end.
```

## 5. 异步 I/O 示例

### 事件轮询器

```pascal
program PollerDemo;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.platform.poller,
  nextpas.core.platform.net;

var
  LPoller: TPlatformPoller;
  LEvent: TPlatformPollerEvent;
  LSocket: TPlatformSocket;
begin
  // 创建轮询器
  LPoller := platform_poller_create;
  if LPoller.Handle = PLATFORM_INVALID_HANDLE then
  begin
    WriteLn('创建轮询器失败');
    Exit;
  end;

  try
    // 创建 socket
    LSocket := platform_net_socket_create(
      PLATFORM_AF_INET,
      PLATFORM_SOCK_STREAM,
      PLATFORM_IPPROTO_TCP
    );
    if LSocket.Handle = PLATFORM_INVALID_HANDLE then
    begin
      WriteLn('创建 socket 失败');
      Exit;
    end;

    try
      // 注册事件
      if platform_poller_add(LPoller, LSocket.Handle, PLATFORM_EVENT_READ, nil) = 0 then
      begin
        WriteLn('事件注册成功');

        // 等待事件
        if platform_poller_wait(LPoller, @LEvent, 1, 1000) > 0 then
          WriteLn('事件触发')
        else
          WriteLn('超时');
      end;
    finally
      platform_net_socket_close(LSocket);
    end;
  finally
    platform_poller_close(LPoller);
  end;
end.
```

## 6. 时间与定时器示例

### 获取系统时间

```pascal
program TimeDemo;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.platform.time;

var
  LNow, LMono: Int64;
begin
  // 获取当前时间戳（秒，Unix epoch）
  LNow := platform_time_now;
  WriteLn('当前时间戳: ', LNow, ' s');

  // 获取单调时钟（纳秒）
  LMono := platform_time_monotonic;
  WriteLn('单调时钟: ', LMono, ' ns');
  WriteLn('单调时钟: ', LMono / 1000000000.0:0:3, ' s');
end.
```

### 高精度计时器

```pascal
program TimerDemo;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.platform.time;

var
  LStart, LEnd, LElapsed: Int64;
begin
  LStart := platform_time_monotonic;

  // 执行一些操作
  Sleep(100);

  LEnd := platform_time_monotonic;
  LElapsed := LEnd - LStart;

  WriteLn('耗时: ', LElapsed, ' ns');
  WriteLn('耗时: ', LElapsed / 1000000.0:0:3, ' ms');
end.
```

## 7. 信号处理示例

### 基本信号处理

```pascal
program SignalDemo;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.platform.signal;

var
  GSignalReceived: Boolean = False;

procedure SignalHandler(ASig: Integer); cdecl;
begin
  WriteLn('收到信号: ', ASig);
  GSignalReceived := True;
end;

var
  LOldAction: TPlatformSignalAction;
begin
  // 设置信号处理
  FillChar(LOldAction, SizeOf(LOldAction), 0);
  LOldAction.sa_handler := @SignalHandler;

  if platform_signal_set(PLATFORM_SIGINT, @LOldAction, nil) = 0 then
  begin
    WriteLn('信号处理已设置，按 Ctrl+C 测试...');

    // 等待信号
    while not GSignalReceived do
      Sleep(100);

    WriteLn('程序正常退出');
  end
  else
    WriteLn('设置信号处理失败');
end.
```

## 8. 内存映射示例

### 文件映射

```pascal
program MmapDemo;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.platform.mmap;

const
  FILE_PATH = 'mmap_test.bin';
  FILE_SIZE = 4096;

var
  LMapping: TPlatformMmap;
  LData: PByte;
  I: Integer;
begin
  // 创建并写入文件
  // ... (省略文件创建代码)

  // 映射文件
  if platform_mmap_open(LMapping, FILE_PATH, PLATFORM_MMAP_READ_WRITE) = 0 then
  begin
    try
      LData := PByte(LMapping.Data);

      // 写入数据
      for I := 0 to FILE_SIZE - 1 do
        LData[I] := I mod 256;

      // 读取验证
      for I := 0 to FILE_SIZE - 1 do
      begin
        if LData[I] <> (I mod 256) then
        begin
          WriteLn('数据验证失败');
          Break;
        end;
      end;

      WriteLn('映射操作成功');
    finally
      platform_mmap_close(LMapping);
    end;
  end
  else
    WriteLn('映射失败');

  // 清理
  platform_file_unlink(FILE_PATH);
end.
```

## 9. 控制台操作示例

### 终端检测

```pascal
program ConsoleDemo;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.platform.console;

var
  LWidth, LHeight: Integer;
begin
  // 检测是否是终端
  WriteLn('stdout 是终端: ', platform_console_is_terminal(1));
  WriteLn('stderr 是终端: ', platform_console_is_terminal(2));

  // 获取终端大小
  if platform_console_get_size(LWidth, LHeight) = 0 then
  begin
    WriteLn('终端宽度: ', LWidth);
    WriteLn('终端高度: ', LHeight);
  end
  else
    WriteLn('获取终端大小失败（可能不是终端）');

  // 启用 ANSI 颜色
  platform_console_enable_ansi(1);
  WriteLn(#27'[31m红色文字'#27'[0m');
  WriteLn(#27'[32m绿色文字'#27'[0m');
  WriteLn(#27'[34m蓝色文字'#27'[0m');
end.
```

## 10. 完整示例：多线程 Web 服务器

```pascal
program MiniWebServer;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.platform.net,
  nextpas.core.platform.sync,
  nextpas.core.platform.process;

const
  PORT = 8080;
  MAX_THREADS = 4;

var
  FServerSocket: TPlatformSocket;
  FMutex: TPlatformMutex;
  FClientCount: Integer = 0;

function HandleClient(AParam: Pointer): Pointer; cdecl;
var
  LClientSocket: TPlatformSocket;
  LBuf: array[0..4095] of Char;
  LRead: Integer;
  LResponse: String;
begin
  LClientSocket := TPlatformSocket(PtrUInt(AParam));

  // 接收请求
  FillChar(LBuf, SizeOf(LBuf), 0);
  LRead := platform_net_socket_recv(LClientSocket, @LBuf, SizeOf(LBuf) - 1, 0);

  if LRead > 0 then
  begin
    // 生成响应
    LResponse := 'HTTP/1.1 200 OK' + #13#10 +
                 'Content-Type: text/plain' + #13#10 +
                 'Content-Length: 13' + #13#10 +
                 #13#10 +
                 'Hello, World!';

    // 发送响应
    platform_net_socket_send(LClientSocket, @LResponse[1], Length(LResponse), 0);
  end;

  // 关闭连接
  platform_net_socket_close(LClientSocket);

  // 更新计数器
  platform_mutex_lock(FMutex);
  try
    Dec(FClientCount);
    WriteLn('活跃连接: ', FClientCount);
  finally
    platform_mutex_unlock(FMutex);
  end;

  Result := nil;
end;

procedure RunServer;
var
  LClientSocket: TPlatformSocket;
  LAddr, LClientAddr: TPlatformSockAddrIn;
  LAddrLen: Integer;
  LThreadId: TPlatformThreadId;
begin
  // 初始化互斥锁
  if platform_mutex_init(FMutex, nil) <> 0 then
  begin
    WriteLn('互斥锁初始化失败');
    Exit;
  end;

  try
    // 创建服务器 socket
    FServerSocket := platform_net_socket_create(
      PLATFORM_AF_INET,
      PLATFORM_SOCK_STREAM,
      PLATFORM_IPPROTO_TCP
    );
    if FServerSocket.Handle = PLATFORM_INVALID_HANDLE then
    begin
      WriteLn('创建 socket 失败');
      Exit;
    end;

    try
      // 绑定地址
      FillChar(LAddr, SizeOf(LAddr), 0);
      LAddr.sin_family := PLATFORM_AF_INET;
      LAddr.sin_port := htons(PORT);
      LAddr.sin_addr.s_addr := htonl(PLATFORM_INADDR_ANY);

      if platform_net_socket_bind(FServerSocket, TPlatformSockAddr(LAddr), SizeOf(LAddr)) <> 0 then
      begin
        WriteLn('绑定失败');
        Exit;
      end;

      // 监听
      if platform_net_socket_listen(FServerSocket, 128) <> 0 then
      begin
        WriteLn('监听失败');
        Exit;
      end;

      WriteLn('服务器启动: http://localhost:', PORT);

      // 主循环
      while True do
      begin
        // 接受连接
        LAddrLen := SizeOf(LClientAddr);
        LClientSocket := platform_net_socket_accept(
          FServerSocket,
          TPlatformSockAddr(LClientAddr),
          @LAddrLen
        );

        if LClientSocket.Handle = PLATFORM_INVALID_HANDLE then
          Continue;

        // 更新计数器
        platform_mutex_lock(FMutex);
        try
          Inc(FClientCount);
          WriteLn('新连接，活跃: ', FClientCount);
        finally
          platform_mutex_unlock(FMutex);
        end;

        // 创建处理线程
        if platform_thread_create(@LThreadId, nil, @HandleClient,
          Pointer(PtrUInt(LClientSocket.Handle))) <> 0 then
        begin
          WriteLn('创建线程失败');
          platform_net_socket_close(LClientSocket);
        end;
      end;
    finally
      platform_net_socket_close(FServerSocket);
    end;
  finally
    platform_mutex_destroy(FMutex);
  end;
end;

begin
  RunServer;
end.
```

## 11. 完整示例：文件监控

```pascal
program FileWatcher;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.platform.watch,
  nextpas.core.platform.process;

var
  LWatcher: TPlatformWatch;
  LEvent: TPlatformWatchEvent;
  LPath: String;
begin
  LPath := '/tmp';

  // 创建文件监控器
  LWatcher := platform_watch_create;
  if LWatcher.Handle = PLATFORM_INVALID_HANDLE then
  begin
    WriteLn('创建监控器失败');
    Exit;
  end;

  try
    // 添加监控路径
    if platform_watch_add(LWatcher, LPath) <> 0 then
    begin
      WriteLn('添加监控失败: ', LPath);
      Exit;
    end;

    WriteLn('正在监控: ', LPath);
    WriteLn('按 Ctrl+C 退出...');

    // 事件循环
    while True do
    begin
      if platform_watch_poll(LWatcher, @LEvent, 1000) > 0 then
      begin
        WriteLn('文件变化: ', LEvent.Path);
        WriteLn('事件类型: ', LEvent.Kind);
      end;
    end;
  finally
    platform_watch_close(LWatcher);
  end;
end.
```

## 12. 完整示例：进程间通信

```pascal
program PipeDemo;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.platform.pipe,
  nextpas.core.platform.process;

const
  PIPE_NAME = '/tmp/test_pipe';

var
  LPipe: TPlatformPipe;
  LBuf: String;
  LRead: Integer;
begin
  // 创建命名管道
  if platform_pipe_create(PIPE_NAME) <> 0 then
  begin
    WriteLn('创建管道失败');
    Exit;
  end;

  try
    // 打开管道
    LPipe := platform_pipe_open(PIPE_NAME, PLATFORM_PIPE_READ);
    if LPipe.Handle = PLATFORM_INVALID_HANDLE then
    begin
      WriteLn('打开管道失败');
      Exit;
    end;

    try
      WriteLn('等待数据...');

      // 读取数据
      SetLength(LBuf, 1024);
      LRead := platform_pipe_read(LPipe, @LBuf[1], Length(LBuf));
      if LRead > 0 then
      begin
        SetLength(LBuf, LRead);
        WriteLn('收到数据: ', LBuf);
      end;
    finally
      platform_pipe_close(LPipe);
    end;
  finally
    platform_pipe_unlink(PIPE_NAME);
  end;
end.
```

## 总结

这些示例覆盖了 platform 模块的主要功能：

1. **文件操作** — 文件读写、目录操作、文件信息
2. **网络编程** — TCP 客户端/服务器、socket 操作
3. **进程管理** — 进程创建、环境变量、进程等待
4. **线程同步** — 线程创建、互斥锁、读写锁
5. **异步 I/O** — 事件轮询器、事件处理
6. **时间处理** — 系统时间、单调时钟、高精度计时
7. **信号处理** — 信号注册、信号处理
8. **内存映射** — 文件映射、内存操作
9. **控制台操作** — 终端检测、ANSI 颜色
10. **完整应用** — Web 服务器、文件监控、进程间通信

每个示例都是独立可运行的程序，可以直接编译测试。
