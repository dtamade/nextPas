unit nextpas.core.platform.socket;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.socket.base,
{$IFDEF NEXTPAS_UNIX}
  nextpas.core.platform.posix.base,
  nextpas.core.platform.error;
{$ENDIF}
{$IFDEF NEXTPAS_WINDOWS}
  nextpas.core.platform.windows.base;
{$ENDIF}

{ Re-export byte-order helpers from socket.base }

{** @desc 主机字节序转网络字节序（16 位）
    @param AHost 主机字节序值
    @return 网络字节序值 *}
function platform_htons(AHost: UInt16): UInt16; inline;

{** @desc 主机字节序转网络字节序（32 位）
    @param AHost 主机字节序值
    @return 网络字节序值 *}
function platform_htonl(AHost: UInt32): UInt32; inline;

{** @desc 网络字节序转主机字节序（16 位）
    @param ANet 网络字节序值
    @return 主机字节序值 *}
function platform_ntohs(ANet: UInt16): UInt16; inline;

{** @desc 网络字节序转主机字节序（32 位）
    @param ANet 网络字节序值
    @return 主机字节序值 *}
function platform_ntohl(ANet: UInt32): UInt32; inline;

{ Re-export IPv4 helpers from socket.base }

{** @desc 解析 IPv4 地址字符串为 32 位整数
    @param AAddr 点分十进制地址（如 "192.168.1.1"）
    @return 网络字节序 IPv4 地址，解析失败返回 0 *}
function platform_ipv4_parse(const AAddr: string): UInt32;

{** @desc 将 32 位 IPv4 地址转为点分十进制字符串
    @param AIP 网络字节序 IPv4 地址
    @return 点分十进制字符串 *}
function platform_ipv4_to_string(AIP: UInt32): string;

const
{$IFDEF NEXTPAS_WINDOWS}
  PLATFORM_AF_INET     = 2;
  PLATFORM_AF_INET6    = 23;
  PLATFORM_SOCK_STREAM = 1;
  PLATFORM_SOCK_DGRAM  = 2;
  PLATFORM_IPPROTO_TCP = 6;
  PLATFORM_IPPROTO_UDP = 17;
  PLATFORM_SOL_SOCKET  = $FFFF;
  PLATFORM_SO_REUSEADDR = $0004;
  PLATFORM_SO_REUSEPORT = $0004;
  PLATFORM_SO_KEEPALIVE = $0008;
  PLATFORM_SO_LINGER   = $0080;
  PLATFORM_SO_RCVTIMEO = $1006;
  PLATFORM_SO_SNDTIMEO = $1005;
  PLATFORM_SO_RCVBUF   = $1002;
  PLATFORM_SO_SNDBUF   = $1001;
  PLATFORM_SO_ERROR    = $1007;
  PLATFORM_TCP_NODELAY  = $0001;
  PLATFORM_SHUT_RD     = 0;
  PLATFORM_SHUT_WR     = 1;
  PLATFORM_SHUT_RDWR   = 2;
{$ELSE}
  PLATFORM_AF_INET     = AF_INET;
  PLATFORM_AF_INET6    = AF_INET6;
  PLATFORM_SOCK_STREAM = SOCK_STREAM;
  PLATFORM_SOCK_DGRAM  = SOCK_DGRAM;
  PLATFORM_IPPROTO_TCP = IPPROTO_TCP;
  PLATFORM_IPPROTO_UDP = IPPROTO_UDP;
  PLATFORM_SOL_SOCKET  = SOL_SOCKET;
  PLATFORM_SO_REUSEADDR = SO_REUSEADDR;
{$IFDEF NEXTPAS_MACOS}
  PLATFORM_SO_REUSEPORT = $0200;
  PLATFORM_SO_LINGER   = $0080;
{$ELSEIF defined(NEXTPAS_FREEBSD)}
  PLATFORM_SO_REUSEPORT = $0004;
  PLATFORM_SO_LINGER   = $0080;
{$ELSE}
  PLATFORM_SO_REUSEPORT = 15;
  PLATFORM_SO_LINGER   = 13;
{$ENDIF}
  PLATFORM_SO_KEEPALIVE = SO_KEEPALIVE;
  PLATFORM_SO_RCVTIMEO = 20;
  PLATFORM_SO_SNDTIMEO = 21;
{$IFDEF NEXTPAS_MACOS}
  PLATFORM_SO_RCVBUF   = $1002;
  PLATFORM_SO_SNDBUF   = $1001;
  PLATFORM_SO_ERROR    = $1007;
{$ELSEIF defined(NEXTPAS_FREEBSD)}
  PLATFORM_SO_RCVBUF   = $1002;
  PLATFORM_SO_SNDBUF   = $1001;
  PLATFORM_SO_ERROR    = $1007;
{$ELSE}
  PLATFORM_SO_RCVBUF   = 8;
  PLATFORM_SO_SNDBUF   = 7;
  PLATFORM_SO_ERROR    = 4;
{$ENDIF}
  PLATFORM_TCP_NODELAY  = TCP_NODELAY;
  PLATFORM_SHUT_RD     = SHUT_RD;
  PLATFORM_SHUT_WR     = SHUT_WR;
  PLATFORM_SHUT_RDWR   = SHUT_RDWR;
{$ENDIF}

{ Re-export types from socket.base for backward compatibility }
type
  TPlatformSocket = nextpas.core.platform.socket.base.TPlatformSocket;
  TPlatformSockAddr = nextpas.core.platform.socket.base.TPlatformSockAddr;

const
{$IFDEF NEXTPAS_WINDOWS}
  PLATFORM_INVALID_SOCKET: TPlatformSocket = (Value: PtrUInt(-1));
{$ELSE}
  PLATFORM_INVALID_SOCKET: TPlatformSocket = (Value: -1);
{$ENDIF}

{** @desc 创建套接字
    @param ADomain 地址族（PLATFORM_AF_INET 等）
    @param AType 套接字类型（PLATFORM_SOCK_STREAM 等）
    @param AProtocol 协议号（0 表示自动选择）
    @param ASocket 输出套接字句柄
    @return 0 成功，否则返回错误码 *}
function platform_socket_create(const ADomain, AType, AProtocol: Int32;
  out ASocket: TPlatformSocket): Int32;

{** @desc 关闭套接字
    @param ASocket 要关闭的套接字（置为无效）
    @return 0 成功，否则返回错误码 *}
function platform_socket_close(var ASocket: TPlatformSocket): Int32;

{** @desc 绑定套接字到地址
    @param ASocket 套接字句柄
    @param AAddr 地址结构指针
    @param AAddrLen 地址结构长度
    @return 0 成功，否则返回错误码 *}
function platform_socket_bind(const ASocket: TPlatformSocket;
  AAddr: Pointer; AAddrLen: Int32): Int32;

{** @desc 开始监听连接
    @param ASocket 套接字句柄
    @param ABacklog 等待队列最大长度
    @return 0 成功，否则返回错误码 *}
function platform_socket_listen(const ASocket: TPlatformSocket;
  ABacklog: Int32): Int32;

{** @desc 接受传入连接
    @param ASocket 监听套接字
    @param AAddr 输出客户端地址（可为 nil）
    @param AAddrLen 地址长度指针（可为 nil）
    @param AClient 输出客户端套接字
    @return 0 成功，否则返回错误码 *}
function platform_socket_accept(const ASocket: TPlatformSocket;
  AAddr: Pointer; AAddrLen: Pointer; out AClient: TPlatformSocket): Int32;

{** @desc 连接到远程地址
    @param ASocket 套接字句柄
    @param AAddr 目标地址结构指针
    @param AAddrLen 地址结构长度
    @return 0 成功，否则返回错误码 *}
function platform_socket_connect(const ASocket: TPlatformSocket;
  AAddr: Pointer; AAddrLen: Int32): Int32;

{** @desc 发送数据
    @param ASocket 套接字句柄
    @param ABuf 数据缓冲区
    @param ALen 数据长度
    @param AFlags 发送标志
    @param ASent 输出实际发送字节数
    @return 0 成功，否则返回错误码 *}
function platform_socket_send(const ASocket: TPlatformSocket;
  ABuf: Pointer; ALen: Int32; AFlags: Int32; out ASent: Int32): Int32;

{** @desc 接收数据
    @param ASocket 套接字句柄
    @param ABuf 接收缓冲区
    @param ALen 缓冲区长度
    @param AFlags 接收标志
    @param ARecvd 输出实际接收字节数
    @return 0 成功，否则返回错误码 *}
function platform_socket_recv(const ASocket: TPlatformSocket;
  ABuf: Pointer; ALen: Int32; AFlags: Int32; out ARecvd: Int32): Int32;

{** @desc 关闭套接字的读/写/读写端
    @param ASocket 套接字句柄
    @param AHow 关闭方向（PLATFORM_SHUT_RD/WR/RDWR）
    @return 0 成功，否则返回错误码 *}
function platform_socket_shutdown(const ASocket: TPlatformSocket;
  AHow: Int32): Int32;

{** @desc 设置套接字选项
    @param ASocket 套接字句柄
    @param ALevel 选项级别
    @param AOptName 选项名称
    @param AOptVal 选项值指针
    @param AOptLen 选项值长度
    @return 0 成功，否则返回错误码 *}
function platform_socket_setsockopt(const ASocket: TPlatformSocket;
  ALevel, AOptName: Int32; AOptVal: Pointer; AOptLen: Int32): Int32;

{** @desc 发送数据到指定地址（UDP）
    @param ASocket 套接字句柄
    @param ABuf 数据缓冲区
    @param ALen 数据长度
    @param AFlags 发送标志
    @param AAddr 目标地址指针
    @param AAddrLen 地址结构长度
    @param ASent 输出实际发送字节数
    @return 0 成功，否则返回错误码 *}
function platform_socket_sendto(const ASocket: TPlatformSocket;
  ABuf: Pointer; ALen: Int32; AFlags: Int32;
  AAddr: Pointer; AAddrLen: Int32; out ASent: Int32): Int32;

{** @desc 从指定地址接收数据（UDP）
    @param ASocket 套接字句柄
    @param ABuf 接收缓冲区
    @param ALen 缓冲区长度
    @param AFlags 接收标志
    @param AAddr 输出来源地址指针
    @param AAddrLen 地址长度指针
    @param ARecvd 输出实际接收字节数
    @return 0 成功，否则返回错误码 *}
function platform_socket_recvfrom(const ASocket: TPlatformSocket;
  ABuf: Pointer; ALen: Int32; AFlags: Int32;
  AAddr: Pointer; AAddrLen: Pointer; out ARecvd: Int32): Int32;

{** @desc 获取套接字本地地址
    @param ASocket 套接字句柄
    @param AAddr 输出地址缓冲区
    @param AAddrLen 地址长度指针
    @return 0 成功，否则返回错误码 *}
function platform_socket_getsockname(const ASocket: TPlatformSocket;
  AAddr: Pointer; AAddrLen: Pointer): Int32;

{** @desc 获取套接字对端地址
    @param ASocket 套接字句柄
    @param AAddr 输出地址缓冲区
    @param AAddrLen 地址长度指针
    @return 0 成功，否则返回错误码 *}
function platform_socket_getpeername(const ASocket: TPlatformSocket;
  AAddr: Pointer; AAddrLen: Pointer): Int32;

{** @desc 解析主机名为 IPv4 地址
    @param AHost 主机名字符串
    @param AAddr 输出网络字节序 IPv4 地址
    @return 0 成功，否则返回错误码 *}
function platform_socket_resolve_ipv4(const AHost: PAnsiChar; out AAddr: UInt32): Int32;

{** @desc 设置套接字为非阻塞模式
    @param ASocket 套接字句柄
    @param ANonBlock True 设为非阻塞，False 设为阻塞
    @return 0 成功，否则返回错误码 *}
function platform_socket_set_nonblocking(const ASocket: TPlatformSocket;
  const ANonBlock: Boolean): Int32;

{** @desc 设置套接字超时
    @param ASocket 套接字句柄
    @param AOptName 选项名（PLATFORM_SO_RCVTIMEO 或 PLATFORM_SO_SNDTIMEO）
    @param ATimeoutMs 超时时间（毫秒）
    @return 0 成功，否则返回错误码 *}
function platform_socket_set_timeout(const ASocket: TPlatformSocket;
  const AOptName: Int32; const ATimeoutMs: Int64): Int32;

{** @desc 判断错误是否为"would block"（非阻塞 I/O 无数据）
    @param AError 错误码
    @return True 表示 would block *}
function platform_socket_error_would_block(const AError: Int32): Boolean;

{** @desc 判断错误是否为超时
    @param AError 错误码
    @return True 表示超时 *}
function platform_socket_error_timed_out(const AError: Int32): Boolean;

{ Sockaddr helpers (from net layer merge) }

{** @desc 构造 IPv4 sockaddr_in 结构
    @param APort 端口号（主机字节序）
    @param AAddr IPv4 地址（网络字节序）
    @param AResult 输出 sockaddr 结构
    @return 0 成功 *}
function platform_sockaddr_ipv4(APort: UInt16; AAddr: UInt32;
  out AResult: TPlatformSockAddr): Int32;

{** @desc 构造 IPv4 回环地址 sockaddr 结构
    @param APort 端口号（主机字节序）
    @param AResult 输出 sockaddr 结构
    @return 0 成功 *}
function platform_sockaddr_loopback4(APort: UInt16;
  out AResult: TPlatformSockAddr): Int32;

{** @desc 构造 IPv6 sockaddr_in6 结构
    @param APort 端口号（主机字节序）
    @param AAddr IPv6 地址字节指针（16 字节）
    @param AScopeId 作用域 ID
    @param AResult 输出 sockaddr 结构
    @return 0 成功 *}
function platform_sockaddr_ipv6(APort: UInt16; AAddr: PByte;
  AScopeId: UInt32; out AResult: TPlatformSockAddr): Int32;

{** @desc 构造 IPv6 回环地址 sockaddr 结构
    @param APort 端口号（主机字节序）
    @param AResult 输出 sockaddr 结构
    @return 0 成功 *}
function platform_sockaddr_loopback6(APort: UInt16;
  out AResult: TPlatformSockAddr): Int32;

{** @desc 解析主机名为 IPv6 地址
    @param AHost 主机名字符串
    @param AAddr 输出 IPv6 地址缓冲区（16 字节）
    @return 0 成功，否则返回错误码 *}
function platform_socket_resolve_ipv6(const AHost: PAnsiChar;
  AAddr: PByte): Int32;

{** @desc 创建已连接的套接字对
    @param ADomain 地址族
    @param AType 套接字类型
    @param AProtocol 协议号
    @param ASocket1 输出第一个套接字
    @param ASocket2 输出第二个套接字
    @return 0 成功，否则返回错误码；Windows 当前返回 PLATFORM_ERR_UNSUPPORTED *}
function platform_socket_pair(ADomain, AType, AProtocol: Int32;
  out ASocket1, ASocket2: TPlatformSocket): Int32;

{** @desc 获取套接字选项
    @param ASocket 套接字句柄
    @param ALevel 选项级别
    @param AOptName 选项名称
    @param AOptVal 输出选项值缓冲区
    @param AOptLen 输入缓冲区长度，输出实际长度
    @return 0 成功，否则返回错误码 *}
function platform_socket_getsockopt(const ASocket: TPlatformSocket;
  ALevel, AOptName: Int32; AOptVal: Pointer; AOptLen: Pointer): Int32;

{ Convenience: TCP_NODELAY }

{** @desc 设置 TCP_NODELAY 选项（禁用 Nagle 算法）
    @param ASocket 套接字句柄
    @param AEnable True 启用，False 禁用
    @return 0 成功，否则返回错误码 *}
function platform_socket_set_tcp_nodelay(const ASocket: TPlatformSocket;
  const AEnable: Boolean): Int32;

{ Convenience: SO_REUSEADDR }

{** @desc 设置 SO_REUSEADDR 选项（允许地址重用）
    @param ASocket 套接字句柄
    @param AEnable True 启用，False 禁用
    @return 0 成功，否则返回错误码 *}
function platform_socket_set_reuseaddr(const ASocket: TPlatformSocket;
  const AEnable: Boolean): Int32;

{ Convenience: SO_KEEPALIVE }

{** @desc 设置 SO_KEEPALIVE 选项（TCP 保活）
    @param ASocket 套接字句柄
    @param AEnable True 启用，False 禁用
    @return 0 成功，否则返回错误码 *}
function platform_socket_set_keepalive(const ASocket: TPlatformSocket;
  const AEnable: Boolean): Int32;

{ Convenience: SO_LINGER }

{** @desc 设置 SO_LINGER 选项（关闭时等待数据发送）
    @param ASocket 套接字句柄
    @param AEnable True 启用，False 禁用
    @param ALingerSec 等待秒数
    @return 0 成功，否则返回错误码 *}
function platform_socket_set_linger(const ASocket: TPlatformSocket;
  const AEnable: Boolean; const ALingerSec: Int32): Int32;

{ Convenience: SO_RCVBUF }

{** @desc 设置接收缓冲区大小
    @param ASocket 套接字句柄
    @param ASize 缓冲区大小（字节）
    @return 0 成功，否则返回错误码 *}
function platform_socket_set_recvbuf(const ASocket: TPlatformSocket;
  ASize: Int32): Int32;

{ Convenience: SO_SNDBUF }

{** @desc 设置发送缓冲区大小
    @param ASocket 套接字句柄
    @param ASize 缓冲区大小（字节）
    @return 0 成功，否则返回错误码 *}
function platform_socket_set_sendbuf(const ASocket: TPlatformSocket;
  ASize: Int32): Int32;

{ Convenience: SO_ERROR (get pending error) }

{** @desc 获取套接字待处理错误
    @param ASocket 套接字句柄
    @param AError 输出错误码
    @return 0 成功，否则返回错误码 *}
function platform_socket_get_error(const ASocket: TPlatformSocket;
  out AError: Int32): Int32;

{ IPv4 helpers for net layer }

{** @desc 从 IPv4 地址和端口构造 sockaddr_in
    @param AIP IPv4 地址（网络字节序）
    @param APort 端口号（主机字节序）
    @param ASockAddr 输出 sockaddr_in 结构
    @param ALen 输出地址结构长度
    @return 0 成功 *}
function platform_sockaddr_from_ipv4(AIP: UInt32; APort: UInt16;
  out ASockAddr: sockaddr_in; out ALen: Int32): Int32;

{** @desc 从 sockaddr_in 提取 IPv4 地址和端口
    @param ASockAddr sockaddr_in 结构
    @param AIP 输出 IPv4 地址（网络字节序）
    @param APort 输出端口号（主机字节序） *}
procedure platform_sockaddr_to_ipv4(const ASockAddr: sockaddr_in;
  out AIP: UInt32; out APort: UInt16);

implementation

{$IFDEF NEXTPAS_UNIX}
uses
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.posix.helpers,
  {$IFDEF NEXTPAS_LINUX}nextpas.core.platform.linux.base{$ENDIF}
  {$IFDEF NEXTPAS_MACOS}nextpas.core.platform.darwin.base{$ENDIF}
  {$IFDEF NEXTPAS_FREEBSD}nextpas.core.platform.freebsd.base{$ENDIF}
  ;

{ 套接字描述符转换辅助函数 }
function FdToSocket(AFd: cint; out ASocket: TPlatformSocket): Int32; inline;
begin
  Result := PosixFdToHandle(AFd, ASocket.Value);
end;

function platform_socket_create(const ADomain, AType, AProtocol: Int32;
  out ASocket: TPlatformSocket): Int32;
begin
  Result := FdToSocket(socket(ADomain, AType, AProtocol), ASocket);
end;

function platform_socket_close(var ASocket: TPlatformSocket): Int32;
begin
  if ASocket.Value < 0 then
    Exit(PLATFORM_ERR_INVALID_HANDLE);
  Result := PosixCheck(close(ASocket.Value));
  ASocket.Value := -1;
end;

function platform_socket_bind(const ASocket: TPlatformSocket;
  AAddr: Pointer; AAddrLen: Int32): Int32;
begin
  Result := PosixCheck(bind(ASocket.Value, AAddr, socklen_t(AAddrLen)));
end;

function platform_socket_listen(const ASocket: TPlatformSocket;
  ABacklog: Int32): Int32;
begin
  Result := PosixCheck(listen(ASocket.Value, ABacklog));
end;

function platform_socket_accept(const ASocket: TPlatformSocket;
  AAddr: Pointer; AAddrLen: Pointer; out AClient: TPlatformSocket): Int32;
begin
  Result := FdToSocket(accept(ASocket.Value, AAddr, AAddrLen), AClient);
end;

function platform_socket_connect(const ASocket: TPlatformSocket;
  AAddr: Pointer; AAddrLen: Int32): Int32;
begin
  Result := PosixCheck(connect(ASocket.Value, AAddr, socklen_t(AAddrLen)));
end;

function platform_socket_send(const ASocket: TPlatformSocket;
  ABuf: Pointer; ALen: Int32; AFlags: Int32; out ASent: Int32): Int32;
var
  LSent: PtrUInt;
begin
  ASent := 0;
  if ABuf = nil then
    Exit(PLATFORM_ERR_INVALID);
  if ALen <= 0 then
    Exit(0);
  Result := PosixSsizeToResult(send(ASocket.Value, ABuf, size_t(ALen), AFlags), LSent);
  if Result = 0 then
    ASent := Int32(LSent);
end;

function platform_socket_recv(const ASocket: TPlatformSocket;
  ABuf: Pointer; ALen: Int32; AFlags: Int32; out ARecvd: Int32): Int32;
var
  LRecvd: PtrUInt;
begin
  ARecvd := 0;
  if ABuf = nil then
    Exit(PLATFORM_ERR_INVALID);
  if ALen <= 0 then
    Exit(0);
  Result := PosixSsizeToResult(recv(ASocket.Value, ABuf, size_t(ALen), AFlags), LRecvd);
  if Result = 0 then
    ARecvd := Int32(LRecvd);
end;

function platform_socket_shutdown(const ASocket: TPlatformSocket;
  AHow: Int32): Int32;
begin
  Result := PosixCheck(nextpas.core.platform.posix.ffi.shutdown(ASocket.Value, AHow));
end;

function platform_socket_setsockopt(const ASocket: TPlatformSocket;
  ALevel, AOptName: Int32; AOptVal: Pointer; AOptLen: Int32): Int32;
begin
  Result := PosixCheck(setsockopt(ASocket.Value, ALevel, AOptName, AOptVal, socklen_t(AOptLen)));
end;

function platform_socket_sendto(const ASocket: TPlatformSocket;
  ABuf: Pointer; ALen: Int32; AFlags: Int32;
  AAddr: Pointer; AAddrLen: Int32; out ASent: Int32): Int32;
var
  LSent: PtrUInt;
begin
  ASent := 0;
  if ABuf = nil then
    Exit(PLATFORM_ERR_INVALID);
  if ALen <= 0 then
    Exit(0);
  Result := PosixSsizeToResult(sendto(ASocket.Value, ABuf, size_t(ALen), AFlags, AAddr, socklen_t(AAddrLen)), LSent);
  if Result = 0 then
    ASent := Int32(LSent);
end;

function platform_socket_recvfrom(const ASocket: TPlatformSocket;
  ABuf: Pointer; ALen: Int32; AFlags: Int32;
  AAddr: Pointer; AAddrLen: Pointer; out ARecvd: Int32): Int32;
var
  LRecvd: PtrUInt;
begin
  ARecvd := 0;
  if ABuf = nil then
    Exit(PLATFORM_ERR_INVALID);
  if ALen <= 0 then
    Exit(0);
  Result := PosixSsizeToResult(recvfrom(ASocket.Value, ABuf, size_t(ALen), AFlags, AAddr, AAddrLen), LRecvd);
  if Result = 0 then
    ARecvd := Int32(LRecvd);
end;

function platform_socket_getsockname(const ASocket: TPlatformSocket;
  AAddr: Pointer; AAddrLen: Pointer): Int32;
begin
  Result := PosixCheck(getsockname(ASocket.Value, AAddr, AAddrLen));
end;

function platform_socket_getpeername(const ASocket: TPlatformSocket;
  AAddr: Pointer; AAddrLen: Pointer): Int32;
begin
  Result := PosixCheck(getpeername(ASocket.Value, AAddr, AAddrLen));
end;

function platform_socket_resolve_ipv4(const AHost: PAnsiChar; out AAddr: UInt32): Int32;
var
  LHints: addrinfo;
  LRes: PAddrInfo;
  LSa: ^sockaddr_in;
begin
  AAddr := 0;
  if AHost = nil then
    Exit(PLATFORM_ERR_INVALID);
  FillChar(LHints, SizeOf(LHints), 0);
  LHints.ai_family := AF_INET;
  LHints.ai_socktype := SOCK_STREAM;
  LRes := nil;
  Result := getaddrinfo(AHost, nil, @LHints, @LRes);
  if (Result <> 0) or (LRes = nil) then
  begin
    if Result = 0 then Result := PLATFORM_ERR_INVALID;
    Exit;
  end;
  LSa := Pointer(LRes^.ai_addr);
  AAddr := LSa^.sin_addr.s_addr;
  freeaddrinfo(LRes);
  Result := 0;
end;

function platform_socket_set_nonblocking(const ASocket: TPlatformSocket;
  const ANonBlock: Boolean): Int32;
var
  LFlags: PtrInt;
begin
  LFlags := fcntl(TPlatformFileDescriptor(ASocket.Value), F_GETFL, 0);
  if LFlags < 0 then Exit(platform_get_errno);
  if ANonBlock then
    LFlags := LFlags or O_NONBLOCK
  else
    LFlags := LFlags and (not O_NONBLOCK);
  if fcntl(TPlatformFileDescriptor(ASocket.Value), F_SETFL, LFlags) < 0 then
    Exit(platform_get_errno);
  Result := 0;
end;

function platform_socket_set_timeout(const ASocket: TPlatformSocket;
  const AOptName: Int32; const ATimeoutMs: Int64): Int32;
var
  LTv: timeval;
begin
  LTv.tv_sec := ATimeoutMs div 1000;
  LTv.tv_usec := (ATimeoutMs mod 1000) * 1000;
  Result := platform_socket_setsockopt(ASocket, PLATFORM_SOL_SOCKET, AOptName,
    @LTv, SizeOf(LTv));
end;

function platform_socket_error_would_block(const AError: Int32): Boolean;
begin
  Result := (AError = ESysEAGAIN) or (AError = ESysEWOULDBLOCK);
end;

function platform_socket_error_timed_out(const AError: Int32): Boolean;
begin
  Result := AError = ESysETIMEDOUT;
end;

{ --- sockaddr helpers (byte-order + ipv4 forwarding from socket.base) --- }

function platform_htons(AHost: UInt16): UInt16; inline;
begin
  Result := nextpas.core.platform.socket.base.platform_htons(AHost);
end;

function platform_htonl(AHost: UInt32): UInt32; inline;
begin
  Result := nextpas.core.platform.socket.base.platform_htonl(AHost);
end;

function platform_ntohs(ANet: UInt16): UInt16; inline;
begin
  Result := nextpas.core.platform.socket.base.platform_ntohs(ANet);
end;

function platform_ntohl(ANet: UInt32): UInt32; inline;
begin
  Result := nextpas.core.platform.socket.base.platform_ntohl(ANet);
end;

function platform_ipv4_parse(const AAddr: string): UInt32;
begin
  Result := nextpas.core.platform.socket.base.platform_ipv4_parse(AAddr);
end;

function platform_ipv4_to_string(AIP: UInt32): string;
begin
  Result := nextpas.core.platform.socket.base.platform_ipv4_to_string(AIP);
end;

function platform_sockaddr_from_ipv4(AIP: UInt32; APort: UInt16;
  out ASockAddr: sockaddr_in; out ALen: Int32): Int32;
begin
  FillChar(ASockAddr, SizeOf(ASockAddr), 0);
  ASockAddr.sin_family := AF_INET;
  ASockAddr.sin_port := platform_htons(APort);
  ASockAddr.sin_addr.s_addr := platform_htonl(AIP);
  ALen := SizeOf(sockaddr_in);
  Result := 0;
end;

procedure platform_sockaddr_to_ipv4(const ASockAddr: sockaddr_in;
  out AIP: UInt32; out APort: UInt16);
begin
  AIP := platform_ntohl(ASockAddr.sin_addr.s_addr);
  APort := platform_ntohs(ASockAddr.sin_port);
end;

function platform_sockaddr_ipv4(APort: UInt16; AAddr: UInt32;
  out AResult: TPlatformSockAddr): Int32;
var
  LAddr: ^sockaddr_in;
begin
  FillChar(AResult, SizeOf(AResult), 0);
  LAddr := @AResult.Storage;
  LAddr^.sin_family := AF_INET;
  LAddr^.sin_port := platform_htons(APort);
  LAddr^.sin_addr.s_addr := platform_htonl(AAddr);
  AResult.Len := SizeOf(sockaddr_in);
  Result := 0;
end;

function platform_sockaddr_loopback4(APort: UInt16;
  out AResult: TPlatformSockAddr): Int32;
begin
  Result := platform_sockaddr_ipv4(APort, $7F000001, AResult);
end;

function platform_sockaddr_ipv6(APort: UInt16; AAddr: PByte;
  AScopeId: UInt32; out AResult: TPlatformSockAddr): Int32;
var
  LAddr: ^sockaddr_in6;
begin
  FillChar(AResult, SizeOf(AResult), 0);
  LAddr := @AResult.Storage;
  LAddr^.sin6_family := AF_INET6;
  LAddr^.sin6_port := platform_htons(APort);
  LAddr^.sin6_flowinfo := 0;
  if AAddr <> nil then
    Move(AAddr^, LAddr^.sin6_addr, 16)
  else
    FillChar(LAddr^.sin6_addr, 16, 0);
  LAddr^.sin6_scope_id := AScopeId;
  AResult.Len := SizeOf(sockaddr_in6);
  Result := 0;
end;

function platform_sockaddr_loopback6(APort: UInt16;
  out AResult: TPlatformSockAddr): Int32;
var
  LAddr: array[0..15] of Byte;
begin
  FillChar(LAddr, 16, 0);
  LAddr[15] := 1; { ::1 }
  Result := platform_sockaddr_ipv6(APort, @LAddr[0], 0, AResult);
end;

function platform_socket_resolve_ipv6(const AHost: PAnsiChar;
  AAddr: PByte): Int32;
var
  LHints: addrinfo;
  LRes: PAddrInfo;
  LSa: ^sockaddr_in6;
begin
  if (AHost = nil) or (AAddr = nil) then
    Exit(PLATFORM_ERR_INVALID);
  FillChar(AAddr^, 16, 0);
  FillChar(LHints, SizeOf(LHints), 0);
  LHints.ai_family := AF_INET6;
  LHints.ai_socktype := SOCK_STREAM;
  LRes := nil;
  Result := getaddrinfo(AHost, nil, @LHints, @LRes);
  if (Result <> 0) or (LRes = nil) then
  begin
    if Result = 0 then Result := PLATFORM_ERR_INVALID;
    Exit;
  end;
  LSa := Pointer(LRes^.ai_addr);
  Move(LSa^.sin6_addr, AAddr^, 16);
  freeaddrinfo(LRes);
  Result := 0;
end;

function platform_socket_pair(ADomain, AType, AProtocol: Int32;
  out ASocket1, ASocket2: TPlatformSocket): Int32;
var
  LSv: array[0..1] of cint;
begin
  if socketpair(ADomain, AType, AProtocol, @LSv[0]) <> 0 then
  begin
    ASocket1.Value := -1;
    ASocket2.Value := -1;
    Exit(platform_get_errno);
  end;
  ASocket1.Value := LSv[0];
  ASocket2.Value := LSv[1];
  Result := 0;
end;

function platform_socket_getsockopt(const ASocket: TPlatformSocket;
  ALevel, AOptName: Int32; AOptVal: Pointer; AOptLen: Pointer): Int32;
begin
  if getsockopt(ASocket.Value, ALevel, AOptName, AOptVal, AOptLen) = 0 then
    Result := 0
  else
    Result := platform_get_errno;
end;

function platform_socket_set_tcp_nodelay(const ASocket: TPlatformSocket;
  const AEnable: Boolean): Int32;
var
  LVal: cint;
begin
  if AEnable then LVal := 1 else LVal := 0;
  Result := platform_socket_setsockopt(ASocket, PLATFORM_IPPROTO_TCP,
    PLATFORM_TCP_NODELAY, @LVal, SizeOf(LVal));
end;

function platform_socket_set_reuseaddr(const ASocket: TPlatformSocket;
  const AEnable: Boolean): Int32;
var
  LVal: cint;
begin
  if AEnable then LVal := 1 else LVal := 0;
  Result := platform_socket_setsockopt(ASocket, PLATFORM_SOL_SOCKET,
    PLATFORM_SO_REUSEADDR, @LVal, SizeOf(LVal));
end;

function platform_socket_set_keepalive(const ASocket: TPlatformSocket;
  const AEnable: Boolean): Int32;
var
  LVal: cint;
begin
  if AEnable then LVal := 1 else LVal := 0;
  Result := platform_socket_setsockopt(ASocket, PLATFORM_SOL_SOCKET,
    PLATFORM_SO_KEEPALIVE, @LVal, SizeOf(LVal));
end;

function platform_socket_set_linger(const ASocket: TPlatformSocket;
  const AEnable: Boolean; const ALingerSec: Int32): Int32;
var
  LLinger: TLinger;
begin
  if AEnable then LLinger.l_onoff := 1 else LLinger.l_onoff := 0;
  LLinger.l_linger := ALingerSec;
  Result := platform_socket_setsockopt(ASocket, PLATFORM_SOL_SOCKET,
    PLATFORM_SO_LINGER, @LLinger, SizeOf(LLinger));
end;

function platform_socket_set_recvbuf(const ASocket: TPlatformSocket;
  ASize: Int32): Int32;
begin
  Result := platform_socket_setsockopt(ASocket, PLATFORM_SOL_SOCKET,
    PLATFORM_SO_RCVBUF, @ASize, SizeOf(ASize));
end;

function platform_socket_set_sendbuf(const ASocket: TPlatformSocket;
  ASize: Int32): Int32;
begin
  Result := platform_socket_setsockopt(ASocket, PLATFORM_SOL_SOCKET,
    PLATFORM_SO_SNDBUF, @ASize, SizeOf(ASize));
end;

function platform_socket_get_error(const ASocket: TPlatformSocket;
  out AError: Int32): Int32;
var
  LLen: cint;
begin
  LLen := SizeOf(AError);
  Result := platform_socket_getsockopt(ASocket, PLATFORM_SOL_SOCKET,
    PLATFORM_SO_ERROR, @AError, @LLen);
end;

{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.windows.ffi,
  nextpas.core.platform.error;

function platform_socket_create(const ADomain, AType, AProtocol: Int32;
  out ASocket: TPlatformSocket): Int32;
begin
  ASocket.Value := PtrUInt(winsock_socket(ADomain, AType, AProtocol));
  if ASocket.Value = PtrUInt(-1) then
    Result := WSAGetLastError
  else
    Result := 0;
end;

function platform_socket_close(var ASocket: TPlatformSocket): Int32;
begin
  if ASocket.Value = PtrUInt(-1) then
    Exit(PLATFORM_ERR_INVALID_HANDLE);
  if closesocket(TSocket(ASocket.Value)) = 0 then
    Result := 0
  else
    Result := WSAGetLastError;
  ASocket.Value := PtrUInt(-1);
end;

function platform_socket_bind(const ASocket: TPlatformSocket;
  AAddr: Pointer; AAddrLen: Int32): Int32;
begin
  if winsock_bind(TSocket(ASocket.Value), AAddr, AAddrLen) = 0 then
    Result := 0
  else
    Result := WSAGetLastError;
end;

function platform_socket_listen(const ASocket: TPlatformSocket;
  ABacklog: Int32): Int32;
begin
  if winsock_listen(TSocket(ASocket.Value), ABacklog) = 0 then
    Result := 0
  else
    Result := WSAGetLastError;
end;

function platform_socket_accept(const ASocket: TPlatformSocket;
  AAddr: Pointer; AAddrLen: Pointer; out AClient: TPlatformSocket): Int32;
var
  LS: TSocket;
begin
  LS := winsock_accept(TSocket(ASocket.Value), AAddr, AAddrLen);
  if LS = TSocket(-1) then
  begin
    AClient.Value := PtrUInt(-1);
    Result := WSAGetLastError;
  end
  else
  begin
    AClient.Value := PtrUInt(LS);
    Result := 0;
  end;
end;

function platform_socket_connect(const ASocket: TPlatformSocket;
  AAddr: Pointer; AAddrLen: Int32): Int32;
begin
  if winsock_connect(TSocket(ASocket.Value), AAddr, AAddrLen) = 0 then
    Result := 0
  else
    Result := WSAGetLastError;
end;

function platform_socket_send(const ASocket: TPlatformSocket;
  ABuf: Pointer; ALen: Int32; AFlags: Int32; out ASent: Int32): Int32;
var
  LResult: LongInt;
begin
  ASent := 0;
  if ABuf = nil then
    Exit(PLATFORM_ERR_INVALID);
  if ALen <= 0 then
    Exit(0);
  LResult := winsock_send(TSocket(ASocket.Value), ABuf, ALen, AFlags);
  if LResult < 0 then
    Result := WSAGetLastError
  else
  begin
    ASent := LResult;
    Result := 0;
  end;
end;

function platform_socket_recv(const ASocket: TPlatformSocket;
  ABuf: Pointer; ALen: Int32; AFlags: Int32; out ARecvd: Int32): Int32;
var
  LResult: LongInt;
begin
  ARecvd := 0;
  if ABuf = nil then
    Exit(PLATFORM_ERR_INVALID);
  if ALen <= 0 then
    Exit(0);
  LResult := winsock_recv(TSocket(ASocket.Value), ABuf, ALen, AFlags);
  if LResult < 0 then
    Result := WSAGetLastError
  else
  begin
    ARecvd := LResult;
    Result := 0;
  end;
end;

function platform_socket_shutdown(const ASocket: TPlatformSocket;
  AHow: Int32): Int32;
begin
  if winsock_shutdown(TSocket(ASocket.Value), AHow) = 0 then
    Result := 0
  else
    Result := WSAGetLastError;
end;

function platform_socket_setsockopt(const ASocket: TPlatformSocket;
  ALevel, AOptName: Int32; AOptVal: Pointer; AOptLen: Int32): Int32;
begin
  if winsock_setsockopt(TSocket(ASocket.Value), ALevel, AOptName, AOptVal, AOptLen) = 0 then
    Result := 0
  else
    Result := WSAGetLastError;
end;

function platform_socket_getsockname(const ASocket: TPlatformSocket;
  AAddr: Pointer; AAddrLen: Pointer): Int32;
begin
  if winsock_getsockname(TSocket(ASocket.Value), AAddr, AAddrLen) = 0 then
    Result := 0
  else
    Result := WSAGetLastError;
end;

function platform_socket_getpeername(const ASocket: TPlatformSocket;
  AAddr: Pointer; AAddrLen: Pointer): Int32;
begin
  if winsock_getpeername(TSocket(ASocket.Value), AAddr, AAddrLen) = 0 then
    Result := 0
  else
    Result := WSAGetLastError;
end;

function platform_socket_sendto(const ASocket: TPlatformSocket;
  ABuf: Pointer; ALen: Int32; AFlags: Int32;
  AAddr: Pointer; AAddrLen: Int32; out ASent: Int32): Int32;
var
  LResult: LongInt;
begin
  ASent := 0;
  if ABuf = nil then
    Exit(PLATFORM_ERR_INVALID);
  if ALen <= 0 then
    Exit(0);
  LResult := winsock_sendto(TSocket(ASocket.Value), ABuf, ALen, AFlags, AAddr, AAddrLen);
  if LResult < 0 then
  begin
    ASent := 0;
    Result := WSAGetLastError;
  end
  else
  begin
    ASent := LResult;
    Result := 0;
  end;
end;

function platform_socket_recvfrom(const ASocket: TPlatformSocket;
  ABuf: Pointer; ALen: Int32; AFlags: Int32;
  AAddr: Pointer; AAddrLen: Pointer; out ARecvd: Int32): Int32;
var
  LResult: LongInt;
begin
  ARecvd := 0;
  if ABuf = nil then
    Exit(PLATFORM_ERR_INVALID);
  if ALen <= 0 then
    Exit(0);
  LResult := winsock_recvfrom(TSocket(ASocket.Value), ABuf, ALen, AFlags, AAddr, AAddrLen);
  if LResult < 0 then
  begin
    ARecvd := 0;
    Result := WSAGetLastError;
  end
  else
  begin
    ARecvd := LResult;
    Result := 0;
  end;
end;

function platform_socket_resolve_ipv4(const AHost: PAnsiChar; out AAddr: UInt32): Int32;
type
  { FPC's winsock bindings in this toolchain do not expose addrinfo/getaddrinfo. }
  TWinAddrInfo = record
    ai_flags: Int32;
    ai_family: Int32;
    ai_socktype: Int32;
    ai_protocol: Int32;
    ai_addrlen: PtrUInt;
    ai_canonname: PAnsiChar;
    ai_addr: Pointer;
    ai_next: Pointer;
  end;
  PWinAddrInfo = ^TWinAddrInfo;
  TWinSockAddrIn = packed record
    sin_family: Word;
    sin_port: Word;
    sin_addr: UInt32;
    sin_zero: array[0..7] of Byte;
  end;
  PWinSockAddrIn = ^TWinSockAddrIn;
var
  LHints: TWinAddrInfo;
  LRes: PWinAddrInfo;
begin
  AAddr := 0;
  if AHost = nil then
    Exit(PLATFORM_ERR_INVALID);
  FillChar(LHints, SizeOf(LHints), 0);
  LHints.ai_family := 2; { AF_INET }
  LHints.ai_socktype := 1; { SOCK_STREAM }
  LRes := nil;
  Result := winsock_getaddrinfo(AHost, nil, @LHints, @LRes);
  if (Result <> 0) or (LRes = nil) then
  begin
    if Result = 0 then Result := PLATFORM_ERR_INVALID;
    Exit;
  end;
  if LRes^.ai_addr <> nil then
    AAddr := PWinSockAddrIn(LRes^.ai_addr)^.sin_addr;
  winsock_freeaddrinfo(LRes);
  Result := 0;
end;

function platform_socket_set_nonblocking(const ASocket: TPlatformSocket;
  const ANonBlock: Boolean): Int32;
var
  LMode: DWORD;
begin
  if ANonBlock then
    LMode := 1
  else
    LMode := 0;
  if ioctlsocket(TSocket(ASocket.Value), FIONBIO, @LMode) = 0 then
    Result := 0
  else
    Result := WSAGetLastError;
end;

function platform_socket_set_timeout(const ASocket: TPlatformSocket;
  const AOptName: Int32; const ATimeoutMs: Int64): Int32;
var
  LMs: Int32;
begin
  LMs := Int32(ATimeoutMs);
  Result := platform_socket_setsockopt(ASocket, PLATFORM_SOL_SOCKET, AOptName,
    @LMs, SizeOf(LMs));
end;

function platform_socket_error_would_block(const AError: Int32): Boolean;
begin
  Result := AError = WSAEWOULDBLOCK;
end;

function platform_socket_error_timed_out(const AError: Int32): Boolean;
begin
  Result := AError = WSAETIMEDOUT;
end;

{ --- sockaddr helpers (byte-order + ipv4 forwarding from socket.base) --- }

function platform_htons(AHost: UInt16): UInt16; inline;
begin
  Result := nextpas.core.platform.socket.base.platform_htons(AHost);
end;

function platform_htonl(AHost: UInt32): UInt32; inline;
begin
  Result := nextpas.core.platform.socket.base.platform_htonl(AHost);
end;

function platform_ntohs(ANet: UInt16): UInt16; inline;
begin
  Result := nextpas.core.platform.socket.base.platform_ntohs(ANet);
end;

function platform_ntohl(ANet: UInt32): UInt32; inline;
begin
  Result := nextpas.core.platform.socket.base.platform_ntohl(ANet);
end;

function platform_ipv4_parse(const AAddr: string): UInt32;
begin
  Result := nextpas.core.platform.socket.base.platform_ipv4_parse(AAddr);
end;

function platform_ipv4_to_string(AIP: UInt32): string;
begin
  Result := nextpas.core.platform.socket.base.platform_ipv4_to_string(AIP);
end;

function platform_sockaddr_from_ipv4(AIP: UInt32; APort: UInt16;
  out ASockAddr: sockaddr_in; out ALen: Int32): Int32;
begin
  FillChar(ASockAddr, SizeOf(ASockAddr), 0);
  ASockAddr.sin_family := AF_INET;
  ASockAddr.sin_port := platform_htons(APort);
  ASockAddr.sin_addr.s_addr := platform_htonl(AIP);
  ALen := SizeOf(sockaddr_in);
  Result := 0;
end;

procedure platform_sockaddr_to_ipv4(const ASockAddr: sockaddr_in;
  out AIP: UInt32; out APort: UInt16);
begin
  AIP := platform_ntohl(ASockAddr.sin_addr.s_addr);
  APort := platform_ntohs(ASockAddr.sin_port);
end;

function platform_sockaddr_ipv4(APort: UInt16; AAddr: UInt32;
  out AResult: TPlatformSockAddr): Int32;
var
  LAddr: ^sockaddr_in;
begin
  FillChar(AResult, SizeOf(AResult), 0);
  LAddr := @AResult.Storage;
  LAddr^.sin_family := AF_INET;
  LAddr^.sin_port := htons(APort);
  LAddr^.sin_addr.s_addr := platform_htonl(AAddr);
  AResult.Len := SizeOf(sockaddr_in);
  Result := 0;
end;

function platform_sockaddr_loopback4(APort: UInt16;
  out AResult: TPlatformSockAddr): Int32;
begin
  Result := platform_sockaddr_ipv4(APort, $7F000001, AResult);
end;

function platform_sockaddr_ipv6(APort: UInt16; AAddr: PByte;
  AScopeId: UInt32; out AResult: TPlatformSockAddr): Int32;
var
  LAddr: ^sockaddr_in6;
begin
  FillChar(AResult, SizeOf(AResult), 0);
  LAddr := @AResult.Storage;
  LAddr^.sin6_family := AF_INET6;
  LAddr^.sin6_port := htons(APort);
  LAddr^.sin6_flowinfo := 0;
  if AAddr <> nil then
    Move(AAddr^, LAddr^.sin6_addr, 16)
  else
    FillChar(LAddr^.sin6_addr, 16, 0);
  LAddr^.sin6_scope_id := AScopeId;
  AResult.Len := SizeOf(sockaddr_in6);
  Result := 0;
end;

function platform_sockaddr_loopback6(APort: UInt16;
  out AResult: TPlatformSockAddr): Int32;
var
  LAddr: array[0..15] of Byte;
begin
  FillChar(LAddr, 16, 0);
  LAddr[15] := 1; { ::1 }
  Result := platform_sockaddr_ipv6(APort, @LAddr[0], 0, AResult);
end;

function platform_socket_resolve_ipv6(const AHost: PAnsiChar;
  AAddr: PByte): Int32;
var
  LHints: addrinfo;
  LRes: PAddrInfo;
  LSa: ^sockaddr_in6;
begin
  if (AHost = nil) or (AAddr = nil) then
    Exit(PLATFORM_ERR_INVALID);
  FillChar(AAddr^, 16, 0);
  FillChar(LHints, SizeOf(LHints), 0);
  LHints.ai_family := AF_INET6;
  LHints.ai_socktype := SOCK_STREAM;
  LRes := nil;
  Result := winsock_getaddrinfo(AHost, nil, @LHints, @LRes);
  if (Result <> 0) or (LRes = nil) then
  begin
    if Result = 0 then Result := PLATFORM_ERR_INVALID;
    Exit;
  end;
  LSa := Pointer(LRes^.ai_addr);
  Move(LSa^.sin6_addr, AAddr^, 16);
  winsock_freeaddrinfo(LRes);
  Result := 0;
end;

function platform_socket_pair(ADomain, AType, AProtocol: Int32;
  out ASocket1, ASocket2: TPlatformSocket): Int32;
begin
  { Windows doesn't have socketpair, use loopback connect }
  Result := PLATFORM_ERR_UNSUPPORTED;
end;

function platform_socket_getsockopt(const ASocket: TPlatformSocket;
  ALevel, AOptName: Int32; AOptVal: Pointer; AOptLen: Pointer): Int32;
begin
  if winsock_getsockopt(TSocket(ASocket.Value), ALevel, AOptName,
    PAnsiChar(AOptVal), AOptLen) = 0 then
    Result := 0
  else
    Result := WSAGetLastError;
end;

function platform_socket_set_tcp_nodelay(const ASocket: TPlatformSocket;
  const AEnable: Boolean): Int32;
var
  LVal: Int32;
begin
  if AEnable then LVal := 1 else LVal := 0;
  Result := platform_socket_setsockopt(ASocket, PLATFORM_IPPROTO_TCP,
    PLATFORM_TCP_NODELAY, @LVal, SizeOf(LVal));
end;

function platform_socket_set_reuseaddr(const ASocket: TPlatformSocket;
  const AEnable: Boolean): Int32;
var
  LVal: Int32;
begin
  if AEnable then LVal := 1 else LVal := 0;
  Result := platform_socket_setsockopt(ASocket, PLATFORM_SOL_SOCKET,
    PLATFORM_SO_REUSEADDR, @LVal, SizeOf(LVal));
end;

function platform_socket_set_keepalive(const ASocket: TPlatformSocket;
  const AEnable: Boolean): Int32;
var
  LVal: Int32;
begin
  if AEnable then LVal := 1 else LVal := 0;
  Result := platform_socket_setsockopt(ASocket, PLATFORM_SOL_SOCKET,
    PLATFORM_SO_KEEPALIVE, @LVal, SizeOf(LVal));
end;

function platform_socket_set_linger(const ASocket: TPlatformSocket;
  const AEnable: Boolean; const ALingerSec: Int32): Int32;
var
  LLinger: TLinger;
begin
  if AEnable then LLinger.l_onoff := 1 else LLinger.l_onoff := 0;
  LLinger.l_linger := ALingerSec;
  Result := platform_socket_setsockopt(ASocket, PLATFORM_SOL_SOCKET,
    PLATFORM_SO_LINGER, @LLinger, SizeOf(LLinger));
end;

function platform_socket_set_recvbuf(const ASocket: TPlatformSocket;
  ASize: Int32): Int32;
begin
  Result := platform_socket_setsockopt(ASocket, PLATFORM_SOL_SOCKET,
    PLATFORM_SO_RCVBUF, @ASize, SizeOf(ASize));
end;

function platform_socket_set_sendbuf(const ASocket: TPlatformSocket;
  ASize: Int32): Int32;
begin
  Result := platform_socket_setsockopt(ASocket, PLATFORM_SOL_SOCKET,
    PLATFORM_SO_SNDBUF, @ASize, SizeOf(ASize));
end;

function platform_socket_get_error(const ASocket: TPlatformSocket;
  out AError: Int32): Int32;
var
  LLen: Int32;
begin
  LLen := SizeOf(AError);
  Result := platform_socket_getsockopt(ASocket, PLATFORM_SOL_SOCKET,
    PLATFORM_SO_ERROR, @AError, @LLen);
end;

var
  GWsaData: array[0..511] of Byte;

initialization
  WSAStartup($0202, @GWsaData);

finalization
  WSACleanup;

{$ENDIF}

{$IF not defined(NEXTPAS_UNIX) and not defined(NEXTPAS_WINDOWS)}
function platform_socket_create(const ADomain, AType, AProtocol: Int32; out ASocket: TPlatformSocket): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_close(var ASocket: TPlatformSocket): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_bind(const ASocket: TPlatformSocket; AAddr: Pointer; AAddrLen: Int32): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_listen(const ASocket: TPlatformSocket; ABacklog: Int32): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_accept(const ASocket: TPlatformSocket; AAddr: Pointer; AAddrLen: Pointer; out AClient: TPlatformSocket): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_connect(const ASocket: TPlatformSocket; AAddr: Pointer; AAddrLen: Int32): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_send(const ASocket: TPlatformSocket; ABuf: Pointer; ALen: Int32; AFlags: Int32; out ASent: Int32): Int32; begin ASent := 0; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_recv(const ASocket: TPlatformSocket; ABuf: Pointer; ALen: Int32; AFlags: Int32; out ARecvd: Int32): Int32; begin ARecvd := 0; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_shutdown(const ASocket: TPlatformSocket; AHow: Int32): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_setsockopt(const ASocket: TPlatformSocket; ALevel, AOptName: Int32; AOptVal: Pointer; AOptLen: Int32): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_getsockname(const ASocket: TPlatformSocket; AAddr: Pointer; AAddrLen: Pointer): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_getpeername(const ASocket: TPlatformSocket; AAddr: Pointer; AAddrLen: Pointer): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_resolve_ipv4(const AHost: PAnsiChar; out AAddr: UInt32): Int32; begin AAddr := 0; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_set_nonblocking(const ASocket: TPlatformSocket; const ANonBlock: Boolean): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_set_timeout(const ASocket: TPlatformSocket; const AOptName: Int32; const ATimeoutMs: Int64): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_error_would_block(const AError: Int32): Boolean; begin Result := False; end;
function platform_socket_error_timed_out(const AError: Int32): Boolean; begin Result := False; end;
function platform_socket_pair(ADomain, AType, AProtocol: Int32; out ASocket1, ASocket2: TPlatformSocket): Int32; begin ASocket1.Value := -1; ASocket2.Value := -1; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_getsockopt(const ASocket: TPlatformSocket; ALevel, AOptName: Int32; AOptVal: Pointer; AOptLen: Pointer): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_set_tcp_nodelay(const ASocket: TPlatformSocket; const AEnable: Boolean): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_set_reuseaddr(const ASocket: TPlatformSocket; const AEnable: Boolean): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_set_keepalive(const ASocket: TPlatformSocket; const AEnable: Boolean): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_set_linger(const ASocket: TPlatformSocket; const AEnable: Boolean; const ALingerSec: Int32): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_set_recvbuf(const ASocket: TPlatformSocket; ASize: Int32): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_set_sendbuf(const ASocket: TPlatformSocket; ASize: Int32): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_get_error(const ASocket: TPlatformSocket; out AError: Int32): Int32; begin AError := 0; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_htons(AHost: UInt16): UInt16; begin Result := nextpas.core.platform.socket.base.platform_htons(AHost); end;
function platform_htonl(AHost: UInt32): UInt32; begin Result := nextpas.core.platform.socket.base.platform_htonl(AHost); end;
function platform_ntohs(ANet: UInt16): UInt16; begin Result := nextpas.core.platform.socket.base.platform_ntohs(ANet); end;
function platform_ntohl(ANet: UInt32): UInt32; begin Result := nextpas.core.platform.socket.base.platform_ntohl(ANet); end;
function platform_ipv4_parse(const AAddr: string): UInt32; begin Result := nextpas.core.platform.socket.base.platform_ipv4_parse(AAddr); end;
function platform_ipv4_to_string(AIP: UInt32): string; begin Result := nextpas.core.platform.socket.base.platform_ipv4_to_string(AIP); end;
function platform_sockaddr_ipv4(APort: UInt16; AAddr: UInt32; out AResult: TPlatformSockAddr): Int32; begin FillChar(AResult, SizeOf(AResult), 0); Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_sockaddr_loopback4(APort: UInt16; out AResult: TPlatformSockAddr): Int32; begin FillChar(AResult, SizeOf(AResult), 0); Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_sockaddr_ipv6(APort: UInt16; AAddr: PByte; AScopeId: UInt32; out AResult: TPlatformSockAddr): Int32; begin FillChar(AResult, SizeOf(AResult), 0); Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_sockaddr_loopback6(APort: UInt16; out AResult: TPlatformSockAddr): Int32; begin FillChar(AResult, SizeOf(AResult), 0); Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_resolve_ipv6(const AHost: PAnsiChar; AAddr: PByte): Int32; begin FillChar(AAddr^, 16, 0); Result := PLATFORM_ERR_UNSUPPORTED; end;
{$ENDIF}

end.
