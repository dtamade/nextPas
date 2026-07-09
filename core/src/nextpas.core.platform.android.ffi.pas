unit nextpas.core.platform.android.ffi;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.android.base,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi;

{ 系统调用 }

{** @desc 系统调用入口
    @param ANumber 系统调用号
    @param A1-A6 系统调用参数
    @return 系统调用返回值 *}
function syscall(ANumber: PtrInt; A1: PtrUInt; A2: PtrUInt; A3: PtrUInt; A4: PtrUInt; A5: PtrUInt; A6: PtrUInt): PtrInt; cdecl; external 'c' name 'syscall';

{ Errno — Android uses __errno instead of __errno_location }

{** @desc 获取 errno 指针（Android 版本） *}
function __errno: PInt32; cdecl; external 'c' name '__errno';

{ 线程 ID — Android has gettid in libc }

{** @desc 获取当前线程 ID *}
function gettid: Int32; cdecl; external 'c' name 'gettid';

{ 条件变量时钟 }

{** @desc 设置条件变量时钟属性
    @param attr 条件变量属性
    @param clk_id 时钟 ID
    @return 0 成功 *}
function pthread_condattr_setclock(attr: Pointer; clk_id: Int32): Int32; cdecl; external 'pthread' name 'pthread_condattr_setclock';

{ 动态加载 — Android uses libdl }

{** @desc 打开动态链接库
    @param Name 库名称
    @param Flags 打开标志
    @return 库句柄，nil 失败 *}
function dlopen(Name: PAnsiChar; Flags: Int32): Pointer; cdecl; external 'dl' name 'dlopen';
{** @desc 获取动态链接库符号
    @param Lib 库句柄
    @param Name 符号名称
    @return 符号地址，nil 失败 *}
function dlsym(Lib: Pointer; Name: PAnsiChar): Pointer; cdecl; external 'dl' name 'dlsym';
{** @desc 关闭动态链接库
    @param Lib 库句柄
    @return 0 成功 *}
function dlclose(Lib: Pointer): Int32; cdecl; external 'dl' name 'dlclose';
{** @desc 获取动态链接错误消息
    @return 错误消息字符串 *}
function dlerror: PAnsiChar; cdecl; external 'dl' name 'dlerror';

{ epoll — Android supports epoll like Linux }

{** @desc 创建 epoll 实例
    @param flags 创建标志
    @return epoll 文件描述符，-1 失败 *}
function epoll_create1(flags: cint): cint; cdecl; external 'c' name 'epoll_create1';
{** @desc 控制 epoll 事件
    @param epfd epoll 文件描述符
    @param op 操作类型
    @param fd 目标文件描述符
    @param event 事件结构
    @return 0 成功，-1 失败 *}
function epoll_ctl(epfd: cint; op: cint; fd: cint; event: Pointer): cint; cdecl; external 'c' name 'epoll_ctl';
{** @desc 等待 epoll 事件
    @param epfd epoll 文件描述符
    @param events 事件数组
    @param maxevents 最大事件数
    @param timeout 超时时间（毫秒）
    @return 就绪事件数，-1 失败 *}
function epoll_wait(epfd: cint; events: Pointer; maxevents: cint; timeout: cint): cint; cdecl; external 'c' name 'epoll_wait';

{ eventfd }

{** @desc 创建 eventfd
    @param initval 初始值
    @param flags 创建标志
    @return eventfd 文件描述符，-1 失败 *}
function eventfd(initval: cuint; flags: cint): cint; cdecl; external 'c' name 'eventfd';

{ inotify — Android supports inotify }

{** @desc 创建 inotify 实例
    @param flags 创建标志
    @return inotify 文件描述符，-1 失败 *}
function inotify_init1(flags: cint): cint; cdecl; external 'c' name 'inotify_init1';
{** @desc 添加 inotify 监视
    @param fd inotify 文件描述符
    @param pathname 路径
    @param mask 监视掩码
    @return 监视描述符，-1 失败 *}
function inotify_add_watch(fd: cint; pathname: PAnsiChar; mask: cuint32): cint; cdecl; external 'c' name 'inotify_add_watch';
{** @desc 移除 inotify 监视
    @param fd inotify 文件描述符
    @param wd 监视描述符
    @return 0 成功，-1 失败 *}
function inotify_rm_watch(fd: cint; wd: cint): cint; cdecl; external 'c' name 'inotify_rm_watch';

{ accept4 — Android supports accept4 }

{** @desc 接受套接字连接（带标志）
    @param sockfd 监听套接字
    @param addr 输出地址
    @param addrlen 地址长度
    @param flags 标志
    @return 新套接字描述符，-1 失败 *}
function accept4(sockfd: cint; addr: Pointer; addrlen: Pointer; flags: cint): cint; cdecl; external 'c' name 'accept4';

{ getdents64 }

{** @desc 读取目录条目（64 位版本）
    @param fd 目录文件描述符
    @param dirp 输出缓冲区
    @param count 缓冲区大小
    @return 读取字节数，0 结束，-1 失败 *}
function getdents64(fd: cint; dirp: Pointer; count: size_t): ssize_t; cdecl; external 'c' name 'getdents64';

{ 文件系统统计 }

{** @desc 获取文件系统统计信息（通过路径）
    @param path 路径
    @param buf 输出缓冲区
    @return 0 成功，-1 失败 *}
function statfs(path: PAnsiChar; buf: Pointer): cint; cdecl; external 'c' name 'statfs';
{** @desc 获取文件系统统计信息（通过文件描述符）
    @param fd 文件描述符
    @param buf 输出缓冲区
    @return 0 成功，-1 失败 *}
function fstatfs(fd: cint; buf: Pointer): cint; cdecl; external 'c' name 'fstatfs';

{ 资源限制 }

{** @desc 获取/设置进程资源限制
    @param pid 进程 ID
    @param resource 资源类型
    @param new_limit 新限制（nil 不设置）
    @param old_limit 输出旧限制（nil 不获取）
    @return 0 成功，-1 失败 *}
function prlimit64(pid: pid_t; resource: cint; new_limit: Pointer; old_limit: Pointer): cint; cdecl; external 'c' name 'prlimit64';

{ 随机数 — Android has getrandom since API 28 }

{** @desc 获取随机字节
    @param buf 输出缓冲区
    @param buflen 请求字节数
    @param flags 标志
    @return 实际读取字节数，-1 失败 *}
function getrandom(buf: Pointer; buflen: size_t; flags: cuint): ssize_t; cdecl; external 'c' name 'getrandom';

{ 系统信息 }

{** @desc 获取系统信息
    @param info 输出缓冲区
    @return 0 成功，-1 失败 *}
function sysinfo(info: Pointer): cint; cdecl; external 'c' name 'sysinfo';
{** @desc 获取系统标识信息
    @param buf 输出缓冲区
    @return 0 成功，-1 失败 *}
function uname(buf: Pointer): cint; cdecl; external 'c' name 'uname';

{ 文件传输 }

{** @desc 发送文件到套接字
    @param out_fd 输出文件描述符
    @param in_fd 输入文件描述符
    @param offset 偏移量
    @param count 字节数
    @return 发送字节数，-1 失败 *}
function sendfile(out_fd: cint; in_fd: cint; offset: Pointer; count: size_t): ssize_t; cdecl; external 'c' name 'sendfile';

{ splice — Android supports splice }

{** @desc 管道 splice 操作
    @param fd_in 输入文件描述符
    @param off_in 输入偏移
    @param fd_out 输出文件描述符
    @param off_out 输出偏移
    @param len 字节数
    @param flags 标志
    @return splice 字节数，-1 失败 *}
function splice(fd_in: cint; off_in: Pointer; fd_out: cint; off_out: Pointer; len: size_t; flags: cuint): ssize_t; cdecl; external 'c' name 'splice';

{ prctl — Android uses prctl for thread/process control }

{** @desc 进程/线程控制
    @param option 控制选项
    @param arg2-arg5 选项参数
    @return 0 成功，-1 失败 *}
function prctl(option: cint; arg2: culong; arg3: culong; arg4: culong; arg5: culong): cint; cdecl; external 'c' name 'prctl';

{ 信号处理 — Android uses sigaction like Linux }

{** @desc 设置信号处理动作
    @param sig 信号编号
    @param act 新动作
    @param oact 输出旧动作
    @return 0 成功，-1 失败 *}
function sigaction(sig: cint; act: Pointer; oact: Pointer): cint; cdecl; external 'c' name 'sigaction';
{** @desc 设置信号掩码
    @param how 操作类型
    @param nset 新掩码
    @param oset 输出旧掩码
    @return 0 成功，-1 失败 *}
function sigprocmask(how: cint; nset: Pointer; oset: Pointer): cint; cdecl; external 'c' name 'sigprocmask';
{** @desc 获取待处理信号集
    @param sigset 输出信号集
    @return 0 成功，-1 失败 *}
function sigpending(sigset: Pointer): cint; cdecl; external 'c' name 'sigpending';
{** @desc 等待信号
    @param sigset 等待的信号集
    @param sig 输出接收的信号
    @return 0 成功，-1 失败 *}
function sigwait(sigset: Pointer; sig: pcint): cint; cdecl; external 'c' name 'sigwait';

{ raise signal }

{** @desc 向当前进程发送信号
    @param sig 信号编号
    @return 0 成功，-1 失败 *}
function raise_signal(sig: cint): cint; cdecl; external 'c' name 'raise';

{ Network interface enumeration }
function if_nametoindex(ifname: PAnsiChar): cuint; cdecl; external 'c' name 'if_nametoindex';
function if_indextoname(ifindex: cuint; ifname: PAnsiChar): PAnsiChar; cdecl; external 'c' name 'if_indextoname';

{ Misc POSIX }
function ftruncate(fd: cint; length: off_t): cint; cdecl; external 'c' name 'ftruncate';
function fsync(fd: cint): cint; cdecl; external 'c' name 'fsync';
function fdatasync(fd: cint): cint; cdecl; external 'c' name 'fdatasync';
function flock(fd: cint; operation: cint): cint; cdecl; external 'c' name 'flock';
function fstatat(dirfd: cint; pathname: PAnsiChar; buf: Pointer; flags: cint): cint; cdecl; external 'c' name 'fstatat';

{ Android-specific: property system }
function __system_property_find(name: PAnsiChar): Pointer; cdecl; external 'c' name '__system_property_find';
function __system_property_get(name: PAnsiChar; value: PAnsiChar): cint; cdecl; external 'c' name '__system_property_get';
function __system_property_read_callback(pi: Pointer; callback: Pointer; cookie: Pointer): cint; cdecl; external 'c' name '__system_property_read_callback';

implementation

end.
