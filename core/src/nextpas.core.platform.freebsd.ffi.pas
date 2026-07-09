unit nextpas.core.platform.freebsd.ffi;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.freebsd.base,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi;

{ Errno }

{** @desc 获取 errno 指针（FreeBSD 版本） *}
function __error: PInt32; cdecl; external 'c' name '__error';

{ 线程 ID }

{** @desc 获取当前线程 ID（FreeBSD 版本） *}
function pthread_getthreadid_np: Int32; cdecl; external 'pthread' name 'pthread_getthreadid_np';

{ 信号处理 }

{** @desc 设置信号处理动作（FreeBSD 版本）
    @param ASignal 信号编号
    @param ANewAction 新动作
    @param AOldAction 输出旧动作
    @return 0 成功 *}
function sigaction(
  const ASignal: Int32;
  ANewAction: PPlatformFreeBSDSigAction;
  AOldAction: PPlatformFreeBSDSigAction): Int32; cdecl; external 'c' name 'sigaction';
{** @desc 设置信号掩码（FreeBSD 版本）
    @param AHow 操作类型
    @param ANewSet 新掩码
    @param AOldSet 输出旧掩码
    @return 0 成功 *}
function sigprocmask(
  const AHow: Int32;
  ANewSet: PPlatformFreeBSDSignalSet;
  AOldSet: PPlatformFreeBSDSignalSet): Int32; cdecl; external 'c' name 'sigprocmask';
{** @desc 获取待处理信号集（FreeBSD 版本）
    @param ASet 输出信号集
    @return 0 成功 *}
function sigpending(
  ASet: PPlatformFreeBSDSignalSet): Int32; cdecl; external 'c' name 'sigpending';
{** @desc 等待信号（FreeBSD 版本）
    @param ASet 等待的信号集
    @param ASig 输出接收的信号
    @return 0 成功 *}
function sigwait(
  ASet: PPlatformFreeBSDSignalSet;
  ASig: PInt32): Int32; cdecl; external 'c' name 'sigwait';
{** @desc 设置线程信号掩码（FreeBSD 版本）
    @param AHow 操作类型
    @param ANewSet 新掩码
    @param AOldSet 输出旧掩码
    @return 0 成功 *}
function pthread_sigmask(
  const AHow: Int32;
  ANewSet: PPlatformFreeBSDSignalSet;
  AOldSet: PPlatformFreeBSDSignalSet): Int32; cdecl; external 'pthread' name 'pthread_sigmask';

{ 文件状态 }

{** @desc 获取文件状态（通过路径，跟随符号链接）
    @param APath 文件路径
    @param AStat 输出文件状态
    @return 0 成功，-1 失败 *}
function stat(
  const APath: PAnsiChar;
  var AStat: TPlatformFreeBSDStat): Int32; cdecl; external 'c' name 'stat';
{** @desc 获取文件状态（通过路径，不跟随符号链接）
    @param APath 文件路径
    @param AStat 输出文件状态
    @return 0 成功，-1 失败 *}
function lstat(
  const APath: PAnsiChar;
  var AStat: TPlatformFreeBSDStat): Int32; cdecl; external 'c' name 'lstat';
{** @desc 获取文件状态（通过文件描述符）
    @param AFileDescriptor 文件描述符
    @param AStat 输出文件状态
    @return 0 成功，-1 失败 *}
function fstat(
  const AFileDescriptor: Int32;
  var AStat: TPlatformFreeBSDStat): Int32; cdecl; external 'c' name 'fstat';

{ 条件变量时钟 }

{** @desc 设置条件变量时钟属性
    @param attr 条件变量属性
    @param clk_id 时钟 ID
    @return 0 成功 *}
function pthread_condattr_setclock(attr: Pointer; clk_id: Int32): Int32; cdecl; external 'pthread' name 'pthread_condattr_setclock';

{ 动态加载 }

{** @desc 打开动态链接库
    @param Name 库名称
    @param Flags 打开标志
    @return 库句柄，nil 失败 *}
function dlopen(Name: PAnsiChar; Flags: Int32): Pointer; cdecl; external 'c' name 'dlopen';
{** @desc 获取动态链接库符号
    @param Lib 库句柄
    @param Name 符号名称
    @return 符号地址，nil 失败 *}
function dlsym(Lib: Pointer; Name: PAnsiChar): Pointer; cdecl; external 'c' name 'dlsym';
{** @desc 关闭动态链接库
    @param Lib 库句柄
    @return 0 成功 *}
function dlclose(Lib: Pointer): Int32; cdecl; external 'c' name 'dlclose';
{** @desc 获取动态链接错误消息
    @return 错误消息字符串 *}
function dlerror: PAnsiChar; cdecl; external 'c' name 'dlerror';

{ kqueue 事件通知 }

{** @desc 创建 kqueue 实例
    @return kqueue 文件描述符，-1 失败 *}
function kqueue: Int32; cdecl; external 'c' name 'kqueue';
{** @desc 操作 kqueue 事件
    @param kq kqueue 文件描述符
    @param changelist 变更列表
    @param nchanges 变更数量
    @param eventlist 输出事件列表
    @param nevents 最大事件数
    @param timeout 超时时间
    @return 就绪事件数，-1 失败 *}
function kevent(kq: Int32; changelist: PKEvent; nchanges: Int32; eventlist: PKEvent; nevents: Int32; timeout: Pointer): Int32; cdecl; external 'c' name 'kevent';

{ 文件描述符 }

{** @desc 创建管道
    @param pipefd 输出文件描述符数组
    @return 0 成功，-1 失败 *}
function pipe(pipefd: Pointer): Int32; cdecl; external 'c' name 'pipe';
{** @desc 复制文件描述符
    @param oldfd 原文件描述符
    @param newfd 目标文件描述符
    @return 0 成功，-1 失败 *}
function dup2(oldfd: Int32; newfd: Int32): Int32; cdecl; external 'c' name 'dup2';

{ 链接和权限 }

{** @desc 读取符号链接目标
    @param path 符号链接路径
    @param buf 输出缓冲区
    @param bufsiz 缓冲区大小
    @return 读取字节数，-1 失败 *}
function readlink(path: PAnsiChar; buf: PAnsiChar; bufsiz: PtrUInt): PtrInt; cdecl; external 'c' name 'readlink';
{** @desc 创建符号链接
    @param target 目标路径
    @param linkpath 链接路径
    @return 0 成功，-1 失败 *}
function symlink(target: PAnsiChar; linkpath: PAnsiChar): Int32; cdecl; external 'c' name 'symlink';
{** @desc 修改文件权限
    @param path 文件路径
    @param mode 权限模式
    @return 0 成功，-1 失败 *}
function chmod(path: PAnsiChar; mode: UInt32): Int32; cdecl; external 'c' name 'chmod';
{** @desc 修改文件所有者
    @param path 文件路径
    @param owner 用户 ID
    @param group 组 ID
    @return 0 成功，-1 失败 *}
function chown(path: PAnsiChar; owner: UInt32; group: UInt32): Int32; cdecl; external 'c' name 'chown';

{ 用户/组 }

{** @desc 获取用户 ID *}
function getuid: UInt32; cdecl; external 'c' name 'getuid';
{** @desc 获取有效用户 ID *}
function geteuid: UInt32; cdecl; external 'c' name 'geteuid';
{** @desc 获取组 ID *}
function getgid: UInt32; cdecl; external 'c' name 'getgid';
{** @desc 获取有效组 ID *}
function getegid: UInt32; cdecl; external 'c' name 'getegid';

{ 轮询 }

{** @desc 轮询文件描述符事件
    @param fds 文件描述符数组
    @param nfds 文件描述符数量
    @param timeout 超时时间（毫秒，-1 无限等待）
    @return 就绪文件描述符数，-1 失败 *}
function poll(fds: Pointer; nfds: UInt32; timeout: Int32): Int32; cdecl; external 'c' name 'poll';

{ 套接字操作 }
function socket(domain: Int32; xtype: Int32; protocol: Int32): Int32; cdecl; external 'c' name 'socket';
function bind(sockfd: Int32; addr: Pointer; addrlen: UInt32): Int32; cdecl; external 'c' name 'bind';
function listen(sockfd: Int32; backlog: Int32): Int32; cdecl; external 'c' name 'listen';
function accept(sockfd: Int32; addr: Pointer; addrlen: Pointer): Int32; cdecl; external 'c' name 'accept';
function connect(sockfd: Int32; addr: Pointer; addrlen: UInt32): Int32; cdecl; external 'c' name 'connect';
function send(sockfd: Int32; buf: Pointer; len: PtrUInt; flags: Int32): PtrInt; cdecl; external 'c' name 'send';
function recv(sockfd: Int32; buf: Pointer; len: PtrUInt; flags: Int32): PtrInt; cdecl; external 'c' name 'recv';
function sendto(sockfd: Int32; buf: Pointer; len: PtrUInt; flags: Int32; dest_addr: Pointer; addrlen: UInt32): PtrInt; cdecl; external 'c' name 'sendto';
function recvfrom(sockfd: Int32; buf: Pointer; len: PtrUInt; flags: Int32; src_addr: Pointer; addrlen: Pointer): PtrInt; cdecl; external 'c' name 'recvfrom';
function shutdown(sockfd: Int32; how: Int32): Int32; cdecl; external 'c' name 'shutdown';
function getsockname(sockfd: Int32; addr: Pointer; addrlen: Pointer): Int32; cdecl; external 'c' name 'getsockname';
function getpeername(sockfd: Int32; addr: Pointer; addrlen: Pointer): Int32; cdecl; external 'c' name 'getpeername';
function getsockopt(sockfd: Int32; level: Int32; optname: Int32; optval: Pointer; optlen: Pointer): Int32; cdecl; external 'c' name 'getsockopt';
function setsockopt(sockfd: Int32; level: Int32; optname: Int32; optval: Pointer; optlen: UInt32): Int32; cdecl; external 'c' name 'setsockopt';
function socketpair(domain: Int32; xtype: Int32; protocol: Int32; sv: PInt32): Int32; cdecl; external 'c' name 'socketpair';

{ accept4 — FreeBSD supports this for atomic SOCK_NONBLOCK/SOCK_CLOEXEC }
function accept4(sockfd: Int32; addr: Pointer; addrlen: Pointer; flags: Int32): Int32; cdecl; external 'c' name 'accept4';

{ DNS resolution }
function getaddrinfo(node: PAnsiChar; service: PAnsiChar; hints: Pointer; res: Pointer): Int32; cdecl; external 'c' name 'getaddrinfo';
procedure freeaddrinfo(res: Pointer); cdecl; external 'c' name 'freeaddrinfo';
function getnameinfo(sa: Pointer; salen: UInt32; host: PAnsiChar; hostlen: PtrUInt; serv: PAnsiChar; servlen: PtrUInt; flags: Int32): Int32; cdecl; external 'c' name 'getnameinfo';

{ Random }
procedure arc4random_buf(buf: Pointer; nbytes: PtrUInt); cdecl; external 'c' name 'arc4random_buf';

{ Directory reading }
function getdents(fd: Int32; buf: PAnsiChar; nbytes: PtrUInt): PtrInt; cdecl; external 'c' name 'getdents';

{ PTY — in libc on FreeBSD }
function openpty(amaster: pcint; aslave: pcint; name: PAnsiChar; termp: Pointer; winp: Pointer): cint; cdecl; external 'c' name 'openpty';
function login_tty(AFd: cint): cint; cdecl; external 'c' name 'login_tty';

{ sendfile — FreeBSD version }
function sendfile(fd: Int32; s: Int32; offset: Int64; nbytes: PtrUInt; hdtr: Pointer; flags: Int32): Int32; cdecl; external 'c' name 'sendfile';

{ Network interface enumeration }
function if_nametoindex(ifname: PAnsiChar): cuint; cdecl; external 'c' name 'if_nametoindex';
function if_indextoname(ifindex: cuint; ifname: PAnsiChar): PAnsiChar; cdecl; external 'c' name 'if_indextoname';

{ Filesystem }
function statfs(path: PAnsiChar; buf: Pointer): cint; cdecl; external 'c' name 'statfs';
function fstatfs(fd: cint; buf: Pointer): cint; cdecl; external 'c' name 'fstatfs';

{ Resource limits — FreeBSD has prlimit }
function prlimit(pid: pid_t; resource: cint; new_limit: Pointer; old_limit: Pointer): cint; cdecl; external 'c' name 'prlimit';

{ getrandom — FreeBSD 12+ }
function getrandom(buf: Pointer; buflen: size_t; flags: cuint): ssize_t; cdecl; external 'c' name 'getrandom';

{ System information }
function sysctlbyname(name: PAnsiChar; oldp: Pointer; oldlenp: Pointer; newp: Pointer; newlen: PtrUInt): Int32; cdecl; external 'c' name 'sysctlbyname';

{ Misc POSIX }
function ftruncate(fd: Int32; length: Int64): Int32; cdecl; external 'c' name 'ftruncate';
function fsync(fd: Int32): Int32; cdecl; external 'c' name 'fsync';
function fdatasync(fd: Int32): Int32; cdecl; external 'c' name 'fdatasync';
function flock(fd: Int32; operation: Int32): Int32; cdecl; external 'c' name 'flock';

{ copy_file_range — FreeBSD 13+ }
function copy_file_range(fd_in: cint; off_in: Pointer; fd_out: cint; off_out: Pointer; len: size_t; flags: cuint): ssize_t; cdecl; external 'c' name 'copy_file_range';

implementation

end.
