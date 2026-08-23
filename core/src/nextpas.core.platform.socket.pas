unit nextpas.core.platform.socket;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.posix.errno,
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
  { Winsock 无 MSG_NOSIGNAL/MSG_DONTWAIT：占位 0（Windows 非阻塞发送
    需 ioctlsocket(FIONBIO) socket 模式，net.tcp poll 路径维持旧行为）。
    MSG_PEEK 为 Winsock 真值。 }
  PLATFORM_MSG_NOSIGNAL = 0;
  PLATFORM_MSG_DONTWAIT = 0;
  PLATFORM_MSG_PEEK = 2;
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
  PLATFORM_SO_RCVTIMEO = SO_RCVTIMEO;
  PLATFORM_SO_SNDTIMEO = SO_SNDTIMEO;
{$IF defined(NEXTPAS_MACOS) or defined(NEXTPAS_FREEBSD)}
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
{$IFDEF NEXTPAS_MACOS}
  PLATFORM_MSG_NOSIGNAL = $20000;
  PLATFORM_MSG_DONTWAIT = $80;
  PLATFORM_MSG_PEEK = 1;
{$ELSEIF defined(NEXTPAS_FREEBSD)}
  PLATFORM_MSG_NOSIGNAL = $20000;
  PLATFORM_MSG_DONTWAIT = $80;
  PLATFORM_MSG_PEEK = 2;
{$ELSE}
  PLATFORM_MSG_NOSIGNAL = $00004000;
  PLATFORM_MSG_DONTWAIT = $00000040;
  PLATFORM_MSG_PEEK = 2;
{$ENDIF}
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
    @param ASocket 要关闭的套接字（close 后执行 best-effort invalidate）
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

{** @desc 非破坏性对端存活探测（server 侧长前置工作的客户端断连识别）
    POSIX：一字节 recv(MSG_PEEK|MSG_DONTWAIT)——0 字节=对端 FIN→False，
    EAGAIN/EWOULDBLOCK=存活无数据→True，EINTR=无法判定（保守 True），
    其余错误（RESET/NOTCONN/BADF 等）=连接已坏→False。
    Windows：无 MSG_DONTWAIT 等价物，阻塞 socket 上窥探可能挂死
    worker 线程——恒返回 True（无法判定，保守）。永不消费数据。 }
function platform_socket_peer_alive(const ASocket: TPlatformSocket): Boolean;

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

const
  { Cap for platform_socket_resolve_stream multi-A collection }
  PLATFORM_RESOLVE_MAX = 16;

type
  { One resolved stream address (IPv4 or IPv6) from getaddrinfo walk }
  TPlatformResolvedAddr = record
    IsIPv6: Boolean;
    IPv4: UInt32; { network byte order when not IsIPv6 }
    IPv6: array[0..15] of Byte;
  end;
  PPlatformResolvedAddr = ^TPlatformResolvedAddr;

{** @desc 解析主机名为有序地址列表（multi-A / dual-stack，AF_UNSPEC + SOCK_STREAM）
    @param AHost 主机名
    @param AOut 输出缓冲区（至少 AMax 个 TPlatformResolvedAddr）
    @param AMax 最大条数（建议 ≤ PLATFORM_RESOLVE_MAX）
    @param ACount 实际写入条数
    @return 0 成功（ACount>0），否则错误码且 ACount=0 *}
function platform_socket_resolve_stream(const AHost: PAnsiChar;
  AOut: PPlatformResolvedAddr; AMax: Int32; out ACount: Int32): Int32;
{** @desc 按地址族解析 multi-A（AFamily = AF_INET / AF_INET6 / AF_UNSPEC） *}
function platform_socket_resolve_stream_family(const AHost: PAnsiChar;
  AFamily: Int32; AOut: PPlatformResolvedAddr; AMax: Int32;
  out ACount: Int32): Int32;

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

{** @desc 判断错误是否为 fd/资源表耗尽（EMFILE/ENFILE）
    @param AError 错误码
    @return True 表示资源限制 *}
function platform_socket_error_resource_limit(const AError: Int32): Boolean;

{** @desc 判断错误是否为超时
    @param AError 错误码
    @return True 表示超时 *}
function platform_socket_error_timed_out(const AError: Int32): Boolean;

{** @desc 判断错误是否为非阻塞 connect 进行中（EINPROGRESS / WSAEWOULDBLOCK）
    @param AError 错误码
    @return True 表示 connect 仍在进行 *}
function platform_socket_error_in_progress(const AError: Int32): Boolean;

const
  { poll event bits for platform_socket_poll }
{$IFDEF NEXTPAS_WINDOWS}
  PLATFORM_POLL_IN  = $0300; { POLLRDNORM | POLLRDBAND }
  PLATFORM_POLL_OUT = $0010; { POLLWRNORM }
  PLATFORM_POLL_ERR = $0001;
  PLATFORM_POLL_HUP = $0002;
{$ELSE}
  PLATFORM_POLL_IN  = $0001;
  PLATFORM_POLL_OUT = $0004;
  PLATFORM_POLL_ERR = $0008;
  PLATFORM_POLL_HUP = $0010;
{$ENDIF}

{** @desc 等待单个套接字就绪（poll / WSAPoll）
    @param ASocket 套接字句柄
    @param AEvents 关注事件（PLATFORM_POLL_IN / PLATFORM_POLL_OUT 等按位或）
    @param ATimeoutMs 超时毫秒；&lt;0 无限，0 非阻塞
    @param ARevents 输出就绪事件位
    @return 0 超时/无事件，1 就绪，&lt;0 错误码 *}
function platform_socket_poll(const ASocket: TPlatformSocket;
  const AEvents: Int32; const ATimeoutMs: Int32; out ARevents: Int32): Int32;

{** @desc 等待 ASocket 就绪或 AWake 可读（cancel wake）
    @param ASocket 业务套接字
    @param AEvents ASocket 关注事件
    @param AWake cancel wake 读端（必须有效）
    @param ATimeoutMs 超时毫秒；&lt;0 无限，0 非阻塞
    @param ARevents 当返回 1 时为 ASocket 的 revents
    @return 0 超时，1 ASocket 就绪，2 AWake 可读，&lt;0 错误码 *}
function platform_socket_poll_or_wake(const ASocket: TPlatformSocket;
  const AEvents: Int32; const AWake: TPlatformSocket;
  const ATimeoutMs: Int32; out ARevents: Int32): Int32;

{ Sockaddr helpers (from net layer merge) }

{** @desc 构造 IPv4 sockaddr_in 结构
    @param APort 端口号（主机字节序）
    @param AAddr IPv4 地址（主机字节序）
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
    @param ADomain 地址族（Unix: AF_UNIX；Windows: AF_UNIX/AF_INET/0 均可，内部用 TCP loopback）
    @param AType 套接字类型（STREAM）
    @param AProtocol 协议号
    @param ASocket1 输出读端（cancel wake 等用）
    @param ASocket2 输出写端
    @return 0 成功，否则返回错误码。Windows 无原生 socketpair，用 127.0.0.1 自连接模拟。 *}
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

{ Convenience: Create TCP/UDP sockets }

{** @desc 创建 TCP 套接字（IPv4）
    @param ASocket 输出套接字句柄
    @return 0 成功，否则返回错误码 *}
function platform_socket_create_tcp(out ASocket: TPlatformSocket): Int32;

{** @desc 创建 UDP 套接字（IPv4）
    @param ASocket 输出套接字句柄
    @return 0 成功，否则返回错误码 *}
function platform_socket_create_udp(out ASocket: TPlatformSocket): Int32;

{** @desc 创建 TCP 套接字并绑定到 IPv4 地址
    @param AAddr IPv4 地址（网络字节序）
    @param APort 端口号（主机字节序）
    @param ASocket 输出套接字句柄
    @return 0 成功，否则返回错误码 *}
function platform_socket_create_tcp_bind(AAddr: UInt32; APort: UInt16;
  out ASocket: TPlatformSocket): Int32;

{** @desc 创建 TCP 套接字并连接到 IPv4 地址
    @param AAddr IPv4 地址（网络字节序）
    @param APort 端口号（主机字节序）
    @param ASocket 输出套接字句柄
    @return 0 成功，否则返回错误码 *}
function platform_socket_create_tcp_connect(AAddr: UInt32; APort: UInt16;
  out ASocket: TPlatformSocket): Int32;

implementation

{$IFDEF NEXTPAS_UNIX}
uses
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.posix.helpers
  {$IFDEF NEXTPAS_LINUX}
  , nextpas.core.platform.linux.base
  {$ELSEIF defined(NEXTPAS_MACOS)}
  , nextpas.core.platform.darwin.base
  {$ELSEIF defined(NEXTPAS_FREEBSD)}
  , nextpas.core.platform.freebsd.base
  {$ELSEIF defined(NEXTPAS_ANDROID)}
  , nextpas.core.platform.android.base
  {$ELSE}
  , nextpas.core.platform.unix.base
  {$ENDIF}
  ;

const
  { Linux SOCK_CLOEXEC is octal 02000000 = 0x80000. Darwin has no SOCK_CLOEXEC. }
  SOCK_CLOEXEC_LOCAL = $00080000;

{ 套接字描述符转换辅助函数 }
function FdToSocket(AFd: cint; out ASocket: TPlatformSocket): Int32; inline;
begin
  Result := PosixFdToHandle(AFd, ASocket.Value);
end;

function platform_socket_create(const ADomain, AType, AProtocol: Int32;
  out ASocket: TPlatformSocket): Int32;
var
  LFd: cint;
begin
{$IF defined(NEXTPAS_MACOS) or defined(NEXTPAS_FREEBSD)}
  { BSD: no SOCK_CLOEXEC type flag; set FD_CLOEXEC after create. }
  LFd := socket(ADomain, AType, AProtocol);
  if LFd >= 0 then
    fcntl(LFd, F_SETFD, FD_CLOEXEC);
{$ELSE}
  LFd := socket(ADomain, AType or SOCK_CLOEXEC_LOCAL, AProtocol);
  if (LFd < 0) and (platform_get_errno = ESysEINVAL) then
  begin
    LFd := socket(ADomain, AType, AProtocol);
    if LFd >= 0 then
      fcntl(LFd, F_SETFD, FD_CLOEXEC);
  end;
{$ENDIF}
  Result := FdToSocket(LFd, ASocket);
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

function platform_socket_peer_alive(const ASocket: TPlatformSocket): Boolean;
var
  LBuf: Byte;
  LN: Int32;
  LRc: Int32;
begin
  { 一字节窥探：不消费数据、不阻塞（MSG_DONTWAIT）。 }
  LRc := platform_socket_recv(ASocket, @LBuf, 1,
    PLATFORM_MSG_PEEK or PLATFORM_MSG_DONTWAIT, LN);
  if LRc = 0 then
    Exit(LN > 0);            { 0 字节 = 对端已 FIN → False；有数据 → True }
  if platform_socket_error_would_block(LRc) or
     platform_socket_error_timed_out(LRc) or (LRc = ESysEINTR) then
    Exit(True);              { 无数据 / 被中断：存活或无法判定，保守 True }
  Exit(False);               { RESET/NOTCONN/BADF 等：连接已坏 }
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

function platform_socket_resolve_stream_family(const AHost: PAnsiChar;
  AFamily: Int32; AOut: PPlatformResolvedAddr; AMax: Int32;
  out ACount: Int32): Int32;
var
  LHints: addrinfo;
  LRes, LCur: PAddrInfo;
  LSa4: ^sockaddr_in;
  LSa6: ^sockaddr_in6;
  LMax: Int32;
  LDst: PPlatformResolvedAddr;
begin
  ACount := 0;
  if (AHost = nil) or (AOut = nil) or (AMax <= 0) then
    Exit(PLATFORM_ERR_INVALID);
  LMax := AMax;
  if LMax > PLATFORM_RESOLVE_MAX then
    LMax := PLATFORM_RESOLVE_MAX;

  FillChar(LHints, SizeOf(LHints), 0);
  LHints.ai_family := AFamily;
  LHints.ai_socktype := SOCK_STREAM;
  LRes := nil;
  Result := getaddrinfo(AHost, nil, @LHints, @LRes);
  if (Result <> 0) or (LRes = nil) then
  begin
    if Result = 0 then
      Result := PLATFORM_ERR_INVALID;
    Exit;
  end;

  LCur := LRes;
  while (LCur <> nil) and (ACount < LMax) do
  begin
    if (LCur^.ai_socktype = SOCK_STREAM) or (LCur^.ai_socktype = 0) then
    begin
      if (LCur^.ai_family = AF_INET) and (LCur^.ai_addr <> nil) and
         ((AFamily = AF_UNSPEC) or (AFamily = AF_INET)) then
      begin
        LSa4 := Pointer(LCur^.ai_addr);
        LDst := AOut;
        Inc(LDst, ACount);
        LDst^.IsIPv6 := False;
        LDst^.IPv4 := LSa4^.sin_addr.s_addr;
        FillChar(LDst^.IPv6, SizeOf(LDst^.IPv6), 0);
        Inc(ACount);
      end
      else if (LCur^.ai_family = AF_INET6) and (LCur^.ai_addr <> nil) and
              ((AFamily = AF_UNSPEC) or (AFamily = AF_INET6)) then
      begin
        LSa6 := Pointer(LCur^.ai_addr);
        LDst := AOut;
        Inc(LDst, ACount);
        LDst^.IsIPv6 := True;
        LDst^.IPv4 := 0;
        Move(LSa6^.sin6_addr, LDst^.IPv6, 16);
        Inc(ACount);
      end;
    end;
    LCur := LCur^.ai_next;
  end;
  freeaddrinfo(LRes);
  if ACount = 0 then
    Exit(PLATFORM_ERR_INVALID);
  Result := 0;
end;

function platform_socket_resolve_stream(const AHost: PAnsiChar;
  AOut: PPlatformResolvedAddr; AMax: Int32; out ACount: Int32): Int32;
begin
  Result := platform_socket_resolve_stream_family(AHost, AF_UNSPEC, AOut, AMax, ACount);
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

function platform_socket_error_resource_limit(const AError: Int32): Boolean;
begin
  Result := (AError = ESysEMFILE) or (AError = ESysENFILE);
end;

function platform_socket_error_timed_out(const AError: Int32): Boolean;
begin
  Result := AError = ESysETIMEDOUT;
end;

function platform_socket_error_in_progress(const AError: Int32): Boolean;
begin
  { Nonblocking connect reports EINPROGRESS; some stacks also use EWOULDBLOCK. }
  Result := (AError = ESysEINPROGRESS) or
    platform_socket_error_would_block(AError);
end;

function platform_socket_poll(const ASocket: TPlatformSocket;
  const AEvents: Int32; const ATimeoutMs: Int32; out ARevents: Int32): Int32;
var
  LPfd: TPollFd;
  LNready: Int32;
begin
  ARevents := 0;
  FillChar(LPfd, SizeOf(LPfd), 0);
  LPfd.fd := Int32(ASocket.Value);
  LPfd.events := Int16(AEvents);
  repeat
    LNready := poll(@LPfd, 1, ATimeoutMs);
    if LNready >= 0 then
    begin
      if LNready = 0 then
        Exit(0);
      ARevents := Int32(LPfd.revents);
      Exit(1);
    end;
    if platform_get_errno = ESysEINTR then
      Continue;
    Exit(-platform_get_errno);
  until False;
end;

function platform_socket_poll_or_wake(const ASocket: TPlatformSocket;
  const AEvents: Int32; const AWake: TPlatformSocket;
  const ATimeoutMs: Int32; out ARevents: Int32): Int32;
var
  LPfds: array[0..1] of TPollFd;
  LNready: Int32;
begin
  ARevents := 0;
  FillChar(LPfds[0], SizeOf(LPfds), 0);
  LPfds[0].fd := Int32(ASocket.Value);
  LPfds[0].events := Int16(AEvents);
  LPfds[1].fd := Int32(AWake.Value);
  LPfds[1].events := Int16(PLATFORM_POLL_IN);
  repeat
    LNready := poll(@LPfds[0], 2, ATimeoutMs);
    if LNready >= 0 then
    begin
      if LNready = 0 then
        Exit(0);
      { Prefer wake so cancel wins races with concurrent peer data. }
      if (LPfds[1].revents and Int16(PLATFORM_POLL_IN or PLATFORM_POLL_HUP or
        PLATFORM_POLL_ERR)) <> 0 then
        Exit(2);
      if (LPfds[0].revents and Int16(AEvents or PLATFORM_POLL_HUP or
        PLATFORM_POLL_ERR)) <> 0 then
      begin
        ARevents := Int32(LPfds[0].revents);
        Exit(1);
      end;
      Exit(0);
    end;
    if platform_get_errno = ESysEINTR then
      Continue;
    Exit(-platform_get_errno);
  until False;
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
{$IF defined(NEXTPAS_MACOS) or defined(NEXTPAS_FREEBSD)}
  ASockAddr.sin_len := SizeOf(sockaddr_in);
{$ENDIF}
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
{$IF defined(NEXTPAS_MACOS) or defined(NEXTPAS_FREEBSD)}
  LAddr^.sin_len := SizeOf(sockaddr_in);
{$ENDIF}
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
{$IF defined(NEXTPAS_MACOS) or defined(NEXTPAS_FREEBSD)}
  LAddr^.sin6_len := SizeOf(sockaddr_in6);
{$ENDIF}
  LAddr^.sin6_family := AF_INET6;
  LAddr^.sin6_port := platform_htons(APort);
  LAddr^.sin6_flowinfo := 0;
  if AAddr <> nil then
    Move(AAddr^, LAddr^.sin6_addr, 16)
  else
    FillChar(LAddr^.sin6_addr, 16, 0);
  { sin6_scope_id is host byte order. }
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
{$IF defined(NEXTPAS_MACOS) or defined(NEXTPAS_FREEBSD)}
  if socketpair(ADomain, AType, AProtocol, @LSv[0]) <> 0 then
  begin
    ASocket1.Value := -1;
    ASocket2.Value := -1;
    Exit(platform_get_errno);
  end;
  fcntl(LSv[0], F_SETFD, FD_CLOEXEC);
  fcntl(LSv[1], F_SETFD, FD_CLOEXEC);
{$ELSE}
  if socketpair(ADomain, AType or SOCK_CLOEXEC_LOCAL, AProtocol, @LSv[0]) <> 0 then
  begin
    if platform_get_errno = ESysEINVAL then
    begin
      if socketpair(ADomain, AType, AProtocol, @LSv[0]) = 0 then
      begin
        fcntl(LSv[0], F_SETFD, FD_CLOEXEC);
        fcntl(LSv[1], F_SETFD, FD_CLOEXEC);
      end
      else
      begin
        ASocket1.Value := -1;
        ASocket2.Value := -1;
        Exit(platform_get_errno);
      end;
    end
    else
    begin
      ASocket1.Value := -1;
      ASocket2.Value := -1;
      Exit(platform_get_errno);
    end;
  end;
{$ENDIF}
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

function platform_socket_create_tcp(out ASocket: TPlatformSocket): Int32;
begin
  Result := platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, ASocket);
end;

function platform_socket_create_udp(out ASocket: TPlatformSocket): Int32;
begin
  Result := platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_DGRAM,
    PLATFORM_IPPROTO_UDP, ASocket);
end;

function platform_socket_create_tcp_bind(AAddr: UInt32; APort: UInt16;
  out ASocket: TPlatformSocket): Int32;
var
  LSockAddr: TPlatformSockAddr;
begin
  Result := platform_socket_create_tcp(ASocket);
  if Result <> 0 then
    Exit;
  Result := platform_sockaddr_ipv4(APort, AAddr, LSockAddr);
  if Result <> 0 then
  begin
    platform_socket_close(ASocket);
    Exit;
  end;
  Result := platform_socket_bind(ASocket, @LSockAddr.Storage, Int32(LSockAddr.Len));
  if Result <> 0 then
  begin
    platform_socket_close(ASocket);
    Exit;
  end;
end;

function platform_socket_create_tcp_connect(AAddr: UInt32; APort: UInt16;
  out ASocket: TPlatformSocket): Int32;
var
  LSockAddr: TPlatformSockAddr;
begin
  Result := platform_socket_create_tcp(ASocket);
  if Result <> 0 then
    Exit;
  Result := platform_sockaddr_ipv4(APort, AAddr, LSockAddr);
  if Result <> 0 then
  begin
    platform_socket_close(ASocket);
    Exit;
  end;
  Result := platform_socket_connect(ASocket, @LSockAddr.Storage, Int32(LSockAddr.Len));
  if Result <> 0 then
  begin
    platform_socket_close(ASocket);
    Exit;
  end;
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
    Result := platform_get_last_error
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
    Result := platform_get_last_error;
  ASocket.Value := PtrUInt(-1);
end;

function platform_socket_bind(const ASocket: TPlatformSocket;
  AAddr: Pointer; AAddrLen: Int32): Int32;
begin
  if winsock_bind(TSocket(ASocket.Value), AAddr, AAddrLen) = 0 then
    Result := 0
  else
    Result := platform_get_last_error;
end;

function platform_socket_listen(const ASocket: TPlatformSocket;
  ABacklog: Int32): Int32;
begin
  if winsock_listen(TSocket(ASocket.Value), ABacklog) = 0 then
    Result := 0
  else
    Result := platform_get_last_error;
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
    Result := platform_get_last_error;
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
    Result := platform_get_last_error;
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
    Result := platform_get_last_error
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
    Result := platform_get_last_error
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
    Result := platform_get_last_error;
end;

function platform_socket_setsockopt(const ASocket: TPlatformSocket;
  ALevel, AOptName: Int32; AOptVal: Pointer; AOptLen: Int32): Int32;
begin
  if winsock_setsockopt(TSocket(ASocket.Value), ALevel, AOptName, AOptVal, AOptLen) = 0 then
    Result := 0
  else
    Result := platform_get_last_error;
end;

function platform_socket_getsockname(const ASocket: TPlatformSocket;
  AAddr: Pointer; AAddrLen: Pointer): Int32;
begin
  if winsock_getsockname(TSocket(ASocket.Value), AAddr, AAddrLen) = 0 then
    Result := 0
  else
    Result := platform_get_last_error;
end;

function platform_socket_getpeername(const ASocket: TPlatformSocket;
  AAddr: Pointer; AAddrLen: Pointer): Int32;
begin
  if winsock_getpeername(TSocket(ASocket.Value), AAddr, AAddrLen) = 0 then
    Result := 0
  else
    Result := platform_get_last_error;
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
    Result := platform_get_last_error;
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
  if AAddrLen = nil then
    Exit(PLATFORM_ERR_INVALID);
  if ALen <= 0 then
    Exit(0);
  LResult := winsock_recvfrom(TSocket(ASocket.Value), ABuf, ALen, AFlags, AAddr, AAddrLen);
  if LResult < 0 then
  begin
    ARecvd := 0;
    Result := platform_get_last_error;
  end
  else
  begin
    ARecvd := LResult;
    Result := 0;
  end;
end;

function platform_socket_peer_alive(const ASocket: TPlatformSocket): Boolean;
begin
  { 无 MSG_DONTWAIT 等价物：阻塞 socket 上窥探可能挂死 worker——保守 True。 }
  Result := True;
end;

function platform_socket_resolve_ipv4(const AHost: PAnsiChar; out AAddr: UInt32): Int32;
type
  { FPC's winsock bindings in this toolchain do not expose addrinfo/getaddrinfo.
    Local TWinAddrInfo definition is used to call the raw WinSock getaddrinfo
    without relying on FPC RTL's ws2_32 header. This avoids potential ABI
    mismatches between FPC's bundled addrinfo layout and the system ws2_32. }
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

function platform_socket_resolve_stream_family(const AHost: PAnsiChar;
  AFamily: Int32; AOut: PPlatformResolvedAddr; AMax: Int32;
  out ACount: Int32): Int32;
type
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
  TWinSockAddrIn6 = packed record
    sin6_family: Word;
    sin6_port: Word;
    sin6_flowinfo: UInt32;
    sin6_addr: array[0..15] of Byte;
    sin6_scope_id: UInt32;
  end;
  PWinSockAddrIn6 = ^TWinSockAddrIn6;
var
  LHints: TWinAddrInfo;
  LRes, LCur: PWinAddrInfo;
  LMax: Int32;
  LDst: PPlatformResolvedAddr;
begin
  ACount := 0;
  if (AHost = nil) or (AOut = nil) or (AMax <= 0) then
    Exit(PLATFORM_ERR_INVALID);
  LMax := AMax;
  if LMax > PLATFORM_RESOLVE_MAX then
    LMax := PLATFORM_RESOLVE_MAX;
  FillChar(LHints, SizeOf(LHints), 0);
  LHints.ai_family := AFamily; { 0=AF_UNSPEC, 2=AF_INET, 23=AF_INET6 }
  LHints.ai_socktype := 1; { SOCK_STREAM }
  LRes := nil;
  Result := winsock_getaddrinfo(AHost, nil, @LHints, @LRes);
  if (Result <> 0) or (LRes = nil) then
  begin
    if Result = 0 then
      Result := PLATFORM_ERR_INVALID;
    Exit;
  end;
  LCur := LRes;
  while (LCur <> nil) and (ACount < LMax) do
  begin
    if (LCur^.ai_socktype = 1) or (LCur^.ai_socktype = 0) then
    begin
      if (LCur^.ai_family = 2) and (LCur^.ai_addr <> nil) and
         ((AFamily = 0) or (AFamily = 2)) then
      begin
        LDst := AOut;
        Inc(LDst, ACount);
        LDst^.IsIPv6 := False;
        LDst^.IPv4 := PWinSockAddrIn(LCur^.ai_addr)^.sin_addr;
        FillChar(LDst^.IPv6, SizeOf(LDst^.IPv6), 0);
        Inc(ACount);
      end
      else if (LCur^.ai_family = 23) and (LCur^.ai_addr <> nil) and
              ((AFamily = 0) or (AFamily = 23)) then
      begin
        LDst := AOut;
        Inc(LDst, ACount);
        LDst^.IsIPv6 := True;
        LDst^.IPv4 := 0;
        Move(PWinSockAddrIn6(LCur^.ai_addr)^.sin6_addr, LDst^.IPv6, 16);
        Inc(ACount);
      end;
    end;
    LCur := PWinAddrInfo(LCur^.ai_next);
  end;
  winsock_freeaddrinfo(LRes);
  if ACount = 0 then
    Exit(PLATFORM_ERR_INVALID);
  Result := 0;
end;

function platform_socket_resolve_stream(const AHost: PAnsiChar;
  AOut: PPlatformResolvedAddr; AMax: Int32; out ACount: Int32): Int32;
begin
  Result := platform_socket_resolve_stream_family(AHost, 0 { AF_UNSPEC },
    AOut, AMax, ACount);
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
    Result := platform_get_last_error;
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
  { Accept portable PLATFORM_ERR_AGAIN and raw Winsock codes. }
  Result := (AError = PLATFORM_ERR_AGAIN) or (AError = WSAEWOULDBLOCK);
end;

function platform_socket_error_resource_limit(const AError: Int32): Boolean;
begin
  { WSAEMFILE = too many open sockets. }
  Result := AError = WSAEMFILE;
end;

function platform_socket_error_timed_out(const AError: Int32): Boolean;
begin
  Result := (AError = PLATFORM_ERR_TIMEDOUT) or (AError = WSAETIMEDOUT);
end;

function platform_socket_error_in_progress(const AError: Int32): Boolean;
begin
  { Winsock nonblocking connect typically returns WSAEWOULDBLOCK → AGAIN. }
  Result := (AError = PLATFORM_ERR_AGAIN) or
    (AError = WSAEINPROGRESS) or (AError = WSAEWOULDBLOCK);
end;

function platform_socket_poll(const ASocket: TPlatformSocket;
  const AEvents: Int32; const ATimeoutMs: Int32; out ARevents: Int32): Int32;
var
  LPfd: TWSAPollFd;
  LNready: LongInt;
begin
  ARevents := 0;
  FillChar(LPfd, SizeOf(LPfd), 0);
  LPfd.fd := TSocket(ASocket.Value);
  LPfd.events := SmallInt(AEvents);
  LNready := WSAPoll(@LPfd, 1, ATimeoutMs);
  if LNready < 0 then
    Exit(-platform_get_last_error);
  if LNready = 0 then
    Exit(0);
  ARevents := Int32(LPfd.revents);
  Result := 1;
end;

function platform_socket_poll_or_wake(const ASocket: TPlatformSocket;
  const AEvents: Int32; const AWake: TPlatformSocket;
  const ATimeoutMs: Int32; out ARevents: Int32): Int32;
var
  LPfds: array[0..1] of TWSAPollFd;
  LNready: LongInt;
begin
  ARevents := 0;
  FillChar(LPfds[0], SizeOf(LPfds), 0);
  LPfds[0].fd := TSocket(ASocket.Value);
  LPfds[0].events := SmallInt(AEvents);
  LPfds[1].fd := TSocket(AWake.Value);
  LPfds[1].events := SmallInt(PLATFORM_POLL_IN);
  LNready := WSAPoll(@LPfds[0], 2, ATimeoutMs);
  if LNready < 0 then
    Exit(-platform_get_last_error);
  if LNready = 0 then
    Exit(0);
  if (LPfds[1].revents and SmallInt(PLATFORM_POLL_IN or PLATFORM_POLL_HUP or
    PLATFORM_POLL_ERR)) <> 0 then
    Exit(2);
  if (LPfds[0].revents and SmallInt(AEvents or PLATFORM_POLL_HUP or
    PLATFORM_POLL_ERR)) <> 0 then
  begin
    ARevents := Int32(LPfds[0].revents);
    Exit(1);
  end;
  Result := 0;
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
  { sin6_scope_id is host byte order. }
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
var
  LListener: TPlatformSocket;
  LRead: TPlatformSocket;
  LWrite: TPlatformSocket;
  LAddr: TPlatformSockAddr;
  LNameLen: Int32;
begin
  { No native socketpair on Windows. Emulate full-duplex STREAM pair via
    TCP loopback (same pattern as WindowsCreateWakePair in platform.io).
    net.cancel passes domain=1 (AF_UNIX on Unix); accept that, AF_INET, or 0. }
  ASocket1.Value := PtrUInt(-1);
  ASocket2.Value := PtrUInt(-1);
  LListener.Value := PtrUInt(-1);
  LRead.Value := PtrUInt(-1);
  LWrite.Value := PtrUInt(-1);

  if AType <> PLATFORM_SOCK_STREAM then
    Exit(PLATFORM_ERR_UNSUPPORTED);
  if (ADomain <> 0) and (ADomain <> 1) and (ADomain <> PLATFORM_AF_INET) then
    Exit(PLATFORM_ERR_UNSUPPORTED);
  if (AProtocol <> 0) and (AProtocol <> PLATFORM_IPPROTO_TCP) then
    Exit(PLATFORM_ERR_UNSUPPORTED);

  Result := platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LListener);
  if Result <> 0 then
    Exit;

  Result := platform_socket_set_reuseaddr(LListener, True);
  if Result <> 0 then
  begin
    platform_socket_close(LListener);
    Exit;
  end;

  Result := platform_sockaddr_loopback4(0, LAddr);
  if Result <> 0 then
  begin
    platform_socket_close(LListener);
    Exit;
  end;

  Result := platform_socket_bind(LListener, @LAddr.Storage, Int32(LAddr.Len));
  if Result <> 0 then
  begin
    platform_socket_close(LListener);
    Exit;
  end;

  Result := platform_socket_listen(LListener, 1);
  if Result <> 0 then
  begin
    platform_socket_close(LListener);
    Exit;
  end;

  LNameLen := Int32(SizeOf(LAddr.Storage));
  Result := platform_socket_getsockname(LListener, @LAddr.Storage, @LNameLen);
  if Result <> 0 then
  begin
    platform_socket_close(LListener);
    Exit;
  end;
  LAddr.Len := LNameLen;

  Result := platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, LWrite);
  if Result <> 0 then
  begin
    platform_socket_close(LListener);
    Exit;
  end;

  Result := platform_socket_connect(LWrite, @LAddr.Storage, Int32(LAddr.Len));
  if Result <> 0 then
  begin
    platform_socket_close(LWrite);
    platform_socket_close(LListener);
    Exit;
  end;

  Result := platform_socket_accept(LListener, nil, nil, LRead);
  platform_socket_close(LListener);
  if Result <> 0 then
  begin
    platform_socket_close(LWrite);
    Exit;
  end;

  ASocket1 := LRead;
  ASocket2 := LWrite;
  Result := 0;
end;

function platform_socket_getsockopt(const ASocket: TPlatformSocket;
  ALevel, AOptName: Int32; AOptVal: Pointer; AOptLen: Pointer): Int32;
begin
  if winsock_getsockopt(TSocket(ASocket.Value), ALevel, AOptName,
    PAnsiChar(AOptVal), AOptLen) = 0 then
    Result := 0
  else
    Result := platform_get_last_error;
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

function platform_socket_create_tcp(out ASocket: TPlatformSocket): Int32;
begin
  Result := platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, ASocket);
end;

function platform_socket_create_udp(out ASocket: TPlatformSocket): Int32;
begin
  Result := platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_DGRAM,
    PLATFORM_IPPROTO_UDP, ASocket);
end;

function platform_socket_create_tcp_bind(AAddr: UInt32; APort: UInt16;
  out ASocket: TPlatformSocket): Int32;
var
  LSockAddr: TPlatformSockAddr;
begin
  Result := platform_socket_create_tcp(ASocket);
  if Result <> 0 then
    Exit;
  Result := platform_sockaddr_ipv4(APort, AAddr, LSockAddr);
  if Result <> 0 then
  begin
    platform_socket_close(ASocket);
    Exit;
  end;
  Result := platform_socket_bind(ASocket, @LSockAddr.Storage, Int32(LSockAddr.Len));
  if Result <> 0 then
  begin
    platform_socket_close(ASocket);
    Exit;
  end;
end;

function platform_socket_create_tcp_connect(AAddr: UInt32; APort: UInt16;
  out ASocket: TPlatformSocket): Int32;
var
  LSockAddr: TPlatformSockAddr;
begin
  Result := platform_socket_create_tcp(ASocket);
  if Result <> 0 then
    Exit;
  Result := platform_sockaddr_ipv4(APort, AAddr, LSockAddr);
  if Result <> 0 then
  begin
    platform_socket_close(ASocket);
    Exit;
  end;
  Result := platform_socket_connect(ASocket, @LSockAddr.Storage, Int32(LSockAddr.Len));
  if Result <> 0 then
  begin
    platform_socket_close(ASocket);
    Exit;
  end;
end;

var
  GWsaData: array[0..511] of Byte;

initialization
  WSAStartup($0202, @GWsaData);

finalization
  WSACleanup;

{$ENDIF}

{$IF not defined(NEXTPAS_UNIX) and not defined(NEXTPAS_WINDOWS)}
function platform_socket_create(const ADomain, AType, AProtocol: Int32; out ASocket: TPlatformSocket): Int32; begin ASocket.Value := -1; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_close(var ASocket: TPlatformSocket): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_bind(const ASocket: TPlatformSocket; AAddr: Pointer; AAddrLen: Int32): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_listen(const ASocket: TPlatformSocket; ABacklog: Int32): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_accept(const ASocket: TPlatformSocket; AAddr: Pointer; AAddrLen: Pointer; out AClient: TPlatformSocket): Int32; begin AClient.Value := -1; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_connect(const ASocket: TPlatformSocket; AAddr: Pointer; AAddrLen: Int32): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_send(const ASocket: TPlatformSocket; ABuf: Pointer; ALen: Int32; AFlags: Int32; out ASent: Int32): Int32; begin ASent := 0; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_recv(const ASocket: TPlatformSocket; ABuf: Pointer; ALen: Int32; AFlags: Int32; out ARecvd: Int32): Int32; begin ARecvd := 0; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_peer_alive(const ASocket: TPlatformSocket): Boolean; begin Result := True; end;
function platform_socket_shutdown(const ASocket: TPlatformSocket; AHow: Int32): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_setsockopt(const ASocket: TPlatformSocket; ALevel, AOptName: Int32; AOptVal: Pointer; AOptLen: Int32): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_getsockname(const ASocket: TPlatformSocket; AAddr: Pointer; AAddrLen: Pointer): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_getpeername(const ASocket: TPlatformSocket; AAddr: Pointer; AAddrLen: Pointer): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_resolve_ipv4(const AHost: PAnsiChar; out AAddr: UInt32): Int32; begin AAddr := 0; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_resolve_stream_family(const AHost: PAnsiChar; AFamily: Int32; AOut: PPlatformResolvedAddr; AMax: Int32; out ACount: Int32): Int32; begin ACount := 0; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_resolve_stream(const AHost: PAnsiChar; AOut: PPlatformResolvedAddr; AMax: Int32; out ACount: Int32): Int32; begin ACount := 0; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_set_nonblocking(const ASocket: TPlatformSocket; const ANonBlock: Boolean): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_set_timeout(const ASocket: TPlatformSocket; const AOptName: Int32; const ATimeoutMs: Int64): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_error_would_block(const AError: Int32): Boolean; begin Result := False; end;
function platform_socket_error_resource_limit(const AError: Int32): Boolean; begin Result := False; end;
function platform_socket_error_timed_out(const AError: Int32): Boolean; begin Result := False; end;
function platform_socket_error_in_progress(const AError: Int32): Boolean; begin Result := False; end;
function platform_socket_poll(const ASocket: TPlatformSocket; const AEvents: Int32; const ATimeoutMs: Int32; out ARevents: Int32): Int32; begin ARevents := 0; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_poll_or_wake(const ASocket: TPlatformSocket; const AEvents: Int32; const AWake: TPlatformSocket; const ATimeoutMs: Int32; out ARevents: Int32): Int32; begin ARevents := 0; Result := PLATFORM_ERR_UNSUPPORTED; end;
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
function platform_socket_create_tcp(out ASocket: TPlatformSocket): Int32; begin ASocket.Value := -1; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_create_udp(out ASocket: TPlatformSocket): Int32; begin ASocket.Value := -1; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_create_tcp_bind(AAddr: UInt32; APort: UInt16; out ASocket: TPlatformSocket): Int32; begin ASocket.Value := -1; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_socket_create_tcp_connect(AAddr: UInt32; APort: UInt16; out ASocket: TPlatformSocket): Int32; begin ASocket.Value := -1; Result := PLATFORM_ERR_UNSUPPORTED; end;
{$ENDIF}

end.
