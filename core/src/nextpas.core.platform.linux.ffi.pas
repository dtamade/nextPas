unit nextpas.core.platform.linux.ffi;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.linux.base,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi;

{ System calls }

{** @desc 系统调用入口
    @param ANumber 系统调用号
    @param A1-A6 系统调用参数
    @return 系统调用返回值 *}
function syscall(ANumber: PtrInt; A1: PtrUInt; A2: PtrUInt; A3: PtrUInt; A4: PtrUInt; A5: PtrUInt; A6: PtrUInt): PtrInt; cdecl; external 'c' name 'syscall';

{** @desc 获取当前线程 ID
    @return 线程 ID *}
function gettid: Int32; cdecl; external 'c' name 'gettid';

{** @desc 获取 errno 地址（线程安全）
    @return errno 指针 *}
function __errno_location: PInt32; cdecl; external 'c' name '__errno_location';

{ File stat (glibc versioned) }

{** @desc 获取文件状态（使用 glibc 版本化接口）
    @param AVersion stat 版本号
    @param AFileName 文件路径
    @param AStat 输出文件状态
    @return 0 成功，-1 失败 *}
function __xstat(
  const AVersion: Int32;
  const AFileName: PAnsiChar;
  var AStat: TPlatformLinuxStat): Int32; cdecl; external 'c' name '__xstat';

{** @desc 获取符号链接状态（不跟随符号链接）
    @param AVersion stat 版本号
    @param AFileName 文件路径
    @param AStat 输出文件状态
    @return 0 成功，-1 失败 *}
function __lxstat(
  const AVersion: Int32;
  const AFileName: PAnsiChar;
  var AStat: TPlatformLinuxStat): Int32; cdecl; external 'c' name '__lxstat';

{** @desc 获取文件描述符状态
    @param AVersion stat 版本号
    @param AFileDescriptor 文件描述符
    @param AStat 输出文件状态
    @return 0 成功，-1 失败 *}
function __fxstat(
  const AVersion: Int32;
  const AFileDescriptor: Int32;
  var AStat: TPlatformLinuxStat): Int32; cdecl; external 'c' name '__fxstat';

{** @desc 获取文件状态（AT_FDCWD 相对路径）
    @param dirfd 目录文件描述符
    @param pathname 文件路径
    @param buf 输出文件状态
    @param flags 标志（AT_SYMLINK_NOFOLLOW 等）
    @return 0 成功，-1 失败 *}
function fstatat(dirfd: cint; pathname: PAnsiChar; var buf: TPlatformLinuxStat; flags: cint): cint; cdecl; external 'c' name 'fstatat';

{ Pthread extensions }

{** @desc 设置条件变量时钟源
    @param attr 条件变量属性
    @param clk_id 时钟 ID（CLOCK_MONOTONIC 等）
    @return 0 成功 *}
function pthread_condattr_setclock(attr: Pointer; clk_id: Int32): Int32; cdecl; external 'pthread' name 'pthread_condattr_setclock';

{** @desc 带超时等待线程结束
    @param thread 线程 ID
    @param retval 输出线程返回值
    @param abstime 绝对超时时间
    @return 0 成功，ETIMEDOUT 超时 *}
function pthread_timedjoin_np(thread: PtrUInt; retval: PPointer; abstime: Pointer): Int32; cdecl; external 'c' name 'pthread_timedjoin_np';

{ Dynamic linking }

{** @desc 打开动态链接库
    @param Name 库文件路径（nil 表示加载自身）
    @param Flags 打开标志（RTLD_LAZY/RTLD_NOW/RTLD_GLOBAL）
    @return 库句柄，nil 失败 *}
function dlopen(Name: PAnsiChar; Flags: Int32): Pointer; cdecl; external 'dl' name 'dlopen';

{** @desc 查找动态库中的符号
    @param Lib 库句柄
    @param Name 符号名称
    @return 符号地址，nil 未找到 *}
function dlsym(Lib: Pointer; Name: PAnsiChar): Pointer; cdecl; external 'dl' name 'dlsym';

{** @desc 关闭动态库
    @param Lib 库句柄
    @return 0 成功 *}
function dlclose(Lib: Pointer): Int32; cdecl; external 'dl' name 'dlclose';

{** @desc 获取动态库操作的错误信息
    @return 错误信息字符串，nil 无错误 *}
function dlerror: PAnsiChar; cdecl; external 'dl' name 'dlerror';

{ Epoll }

{** @desc 创建 epoll 实例
    @param flags 标志（EPOLL_CLOEXEC 等）
    @return epoll 文件描述符，-1 失败 *}
function epoll_create1(flags: cint): cint; cdecl; external 'c' name 'epoll_create1';

{** @desc 控制 epoll 实例
    @param epfd epoll 文件描述符
    @param op 操作（EPOLL_CTL_ADD/MOD/DEL）
    @param fd 目标文件描述符
    @param event 事件配置
    @return 0 成功，-1 失败 *}
function epoll_ctl(epfd: cint; op: cint; fd: cint; event: pepoll_event): cint; cdecl; external 'c' name 'epoll_ctl';

{** @desc 等待 epoll 事件
    @param epfd epoll 文件描述符
    @param events 输出事件数组
    @param maxevents 最大事件数
    @param timeout 超时毫秒数（-1 无限等待）
    @return 就绪事件数，-1 失败 *}
function epoll_wait(epfd: cint; events: pepoll_event; maxevents: cint; timeout: cint): cint; cdecl; external 'c' name 'epoll_wait';

{** @desc 等待 epoll 事件（可屏蔽信号）
    @param epfd epoll 文件描述符
    @param events 输出事件数组
    @param maxevents 最大事件数
    @param timeout 超时毫秒数
    @param sigmask 信号掩码
    @return 就绪事件数，-1 失败 *}
function epoll_pwait(epfd: cint; events: pepoll_event; maxevents: cint; timeout: cint; sigmask: Pointer): cint; cdecl; external 'c' name 'epoll_pwait';

{ Event fd }

{** @desc 创建 eventfd
    @param initval 初始值
    @param flags 标志（EFD_SEMAPHORE/EFD_NONBLOCK/EFD_CLOEXEC）
    @return eventfd 文件描述符，-1 失败 *}
function eventfd(initval: cuint; flags: cint): cint; cdecl; external 'c' name 'eventfd';

{ Timer fd }

{** @desc 创建 timerfd
    @param clockid 时钟 ID
    @param flags 标志（TFD_NONBLOCK/TFD_CLOEXEC）
    @return timerfd 文件描述符，-1 失败 *}
function timerfd_create(clockid: cint; flags: cint): cint; cdecl; external 'c' name 'timerfd_create';

{** @desc 设置 timerfd 定时器
    @param fd timerfd 文件描述符
    @param flags 标志（TFD_TIMER_ABSTIME）
    @param new_value 新定时器值
    @param old_value 输出旧定时器值
    @return 0 成功，-1 失败 *}
function timerfd_settime(fd: cint; flags: cint; new_value: Pointer; old_value: Pointer): cint; cdecl; external 'c' name 'timerfd_settime';

{** @desc 获取 timerfd 当前定时器值
    @param fd timerfd 文件描述符
    @param curr_value 输出当前定时器值
    @return 0 成功，-1 失败 *}
function timerfd_gettime(fd: cint; curr_value: Pointer): cint; cdecl; external 'c' name 'timerfd_gettime';

{ Signal fd }

{** @desc 创建 signalfd
    @param fd 文件描述符（-1 创建新）
    @param mask 信号掩码
    @param flags 标志（SFD_NONBLOCK/SFD_CLOEXEC）
    @return signalfd 文件描述符，-1 失败 *}
function signalfd(fd: cint; mask: Pointer; flags: cint): cint; cdecl; external 'c' name 'signalfd';

{ Inotify }

{** @desc 创建 inotify 实例
    @param flags 标志（IN_NONBLOCK/IN_CLOEXEC）
    @return inotify 文件描述符，-1 失败 *}
function inotify_init1(flags: cint): cint; cdecl; external 'c' name 'inotify_init1';

{** @desc 添加 inotify 监视
    @param fd inotify 文件描述符
    @param pathname 监视路径
    @param mask 事件掩码
    @return 监视描述符，-1 失败 *}
function inotify_add_watch(fd: cint; pathname: PAnsiChar; mask: cuint32): cint; cdecl; external 'c' name 'inotify_add_watch';

{** @desc 移除 inotify 监视
    @param fd inotify 文件描述符
    @param wd 监视描述符
    @return 0 成功，-1 失败 *}
function inotify_rm_watch(fd: cint; wd: cint): cint; cdecl; external 'c' name 'inotify_rm_watch';

{ Pipe/dup }

{** @desc 创建管道（带标志）
    @param pipefd 输出管道文件描述符数组 [读, 写]
    @param flags 标志（O_CLOEXEC/O_NONBLOCK）
    @return 0 成功，-1 失败 *}
function pipe2(pipefd: PInt32; flags: cint): cint; cdecl; external 'c' name 'pipe2';

{** @desc 复制文件描述符（带标志）
    @param oldfd 源文件描述符
    @param newfd 目标文件描述符
    @param flags 标志（O_CLOEXEC）
    @return 新文件描述符，-1 失败 *}
function dup3(oldfd: cint; newfd: cint; flags: cint): cint; cdecl; external 'c' name 'dup3';

{ Socket }

{** @desc 接受连接（带标志）
    @param sockfd 监听套接字
    @param addr 输出对端地址
    @param addrlen 地址长度
    @param flags 标志（SOCK_NONBLOCK/SOCK_CLOEXEC）
    @return 新套接字文件描述符，-1 失败 *}
function accept4(sockfd: cint; addr: Pointer; addrlen: Pointer; flags: cint): cint; cdecl; external 'c' name 'accept4';

{ Directory }

{** @desc 读取目录项（64 位版本）
    @param fd 目录文件描述符
    @param dirp 输出缓冲区
    @param count 缓冲区大小
    @return 读取字节数，0 结束，-1 失败 *}
function getdents64(fd: cint; dirp: Pointer; count: size_t): ssize_t; cdecl; external 'c' name 'getdents64';

{ Filesystem }

{** @desc 获取文件系统状态
    @param path 路径
    @param buf 输出文件系统状态
    @return 0 成功，-1 失败 *}
function statfs(path: PAnsiChar; buf: PStatfs): cint; cdecl; external 'c' name 'statfs';

{** @desc 获取文件系统状态（通过文件描述符）
    @param fd 文件描述符
    @param buf 输出文件系统状态
    @return 0 成功，-1 失败 *}
function fstatfs(fd: cint; buf: PStatfs): cint; cdecl; external 'c' name 'fstatfs';

{ Resource limits }

{** @desc 获取/设置进程资源限制
    @param pid 进程 ID（0 表示当前进程）
    @param resource 资源类型
    @param new_limit 新限制（nil 不设置）
    @param old_limit 输出旧限制（nil 不获取）
    @return 0 成功，-1 失败 *}
function prlimit64(pid: pid_t; resource: cint; new_limit: PRLimit; old_limit: PRLimit): cint; cdecl; external 'c' name 'prlimit64';

{ Random }

{** @desc 获取随机数
    @param buf 输出缓冲区
    @param buflen 缓冲区长度
    @param flags 标志（GRND_NONBLOCK/GRND_RANDOM）
    @return 写入字节数，-1 失败 *}
function getrandom(buf: Pointer; buflen: size_t; flags: cuint): ssize_t; cdecl; external 'c' name 'getrandom';

{ System info }

{** @desc 获取系统信息
    @param info 输出系统信息
    @return 0 成功，-1 失败 *}
function sysinfo(info: PSysInfo): cint; cdecl; external 'c' name 'sysinfo';

{** @desc 获取系统标识
    @param buf 输出系统标识
    @return 0 成功，-1 失败 *}
function uname(buf: PUtsName): cint; cdecl; external 'c' name 'uname';

{ Signal }

{** @desc 设置信号处理
    @param sig 信号编号
    @param act 新信号处理（nil 使用默认）
    @param oact 输出旧信号处理
    @return 0 成功，-1 失败 *}
function sigaction(sig: cint; act: Pointer; oact: Pointer): cint; cdecl; external 'c' name 'sigaction';

{** @desc 设置信号掩码
    @param how 操作（SIG_BLOCK/SIG_UNBLOCK/SIG_SETMASK）
    @param nset 新信号掩码
    @param oset 输出旧信号掩码
    @return 0 成功，-1 失败 *}
function sigprocmask(how: cint; nset: Pointer; oset: Pointer): cint; cdecl; external 'c' name 'sigprocmask';

{** @desc 获取待处理信号
    @param sigset 输出待处理信号集
    @return 0 成功，-1 失败 *}
function sigpending(sigset: Pointer): cint; cdecl; external 'c' name 'sigpending';

{** @desc 等待信号
    @param sigset 等待的信号集
    @param sig 输出接收到的信号
    @return 0 成功，-1 失败 *}
function sigwait(sigset: Pointer; sig: pcint): cint; cdecl; external 'c' name 'sigwait';

{** @desc 向当前进程发送信号
    @param sig 信号编号
    @return 0 成功，-1 失败 *}
function raise_signal(sig: cint): cint; cdecl; external 'c' name 'raise';

{ File transfer }

{** @desc 零拷贝文件传输
    @param out_fd 输出文件描述符
    @param in_fd 输入文件描述符
    @param offset 偏移量（nil 从当前位置）
    @param count 传输字节数
    @return 传输字节数，-1 失败 *}
function sendfile(out_fd: cint; in_fd: cint; offset: Pointer; count: size_t): ssize_t; cdecl; external 'c' name 'sendfile';

{** @desc 管道 splice 操作
    @param fd_in 输入文件描述符
    @param off_in 输入偏移量
    @param fd_out 输出文件描述符
    @param off_out 输出偏移量
    @param len 传输长度
    @param flags 标志（SPLICE_F_MOVE 等）
    @return 传输字节数，-1 失败 *}
function splice(fd_in: cint; off_in: Pointer; fd_out: cint; off_out: Pointer; len: size_t; flags: cuint): ssize_t; cdecl; external 'c' name 'splice';

{** @desc 跨文件系统文件复制
    @param fd_in 输入文件描述符
    @param off_in 输入偏移量
    @param fd_out 输出文件描述符
    @param off_out 输出偏移量
    @param len 复制长度
    @param flags 标志
    @return 复制字节数，-1 失败 *}
function copy_file_range(fd_in: cint; off_in: Pointer; fd_out: cint; off_out: Pointer; len: size_t; flags: cuint): ssize_t; cdecl; external 'c' name 'copy_file_range';

{ Process }

{** @desc 进程控制
    @param option 选项（PR_SET_NAME/PR_GET_NAME 等）
    @param arg2 参数 2
    @param arg3 参数 3
    @param arg4 参数 4
    @param arg5 参数 5
    @return 0 成功，-1 失败 *}
function prctl(option: cint; arg2: culong; arg3: culong; arg4: culong; arg5: culong): cint; cdecl; external 'c' name 'prctl';

{ PTY — libutil }

{** @desc 创建伪终端对
    @param amaster 输出主端文件描述符
    @param aslave 输出从端文件描述符
    @param name 输出终端名称
    @param termp 终端属性
    @param winp 窗口大小
    @return 0 成功，-1 失败 *}
function openpty(amaster: pcint; aslave: pcint; name: PAnsiChar; termp: Pointer; winp: Pointer): cint; cdecl; external 'util' name 'openpty';

{** @desc 设置登录终端
    @param AFd 终端文件描述符
    @return 0 成功，-1 失败 *}
function login_tty(AFd: cint): cint; cdecl; external 'util' name 'login_tty';

{ CoW 克隆 — FICLONE ioctl（btrfs/xfs/...）
  FICLONE = _IOW(0x94, 9, int) = $80049409
  ioctl(dst_fd, FICLONE, src_fd) 让 dst 成为 src 的 reflink（共享数据块） }
const
  FICLONE = $80049409;

{** @desc I/O 控制
    @param AFd 文件描述符
    @param ARequest 设备/操作请求码
    @param AArgp 参数指针
    @return 0 成功，-1 失败 *}
function ioctl(AFd: cint; ARequest: culong; AArgp: Pointer): cint; cdecl; external 'c' name 'ioctl';

{ NUMA / CPU topology — host-owned raw truth for L2 numa }

{** @desc 获取当前 CPU 与节点（getcpu）
    @param cpu 输出 CPU
    @param node 输出节点
    @param tcache 缓存指针
    @return 0 成功 *}
function getcpu(cpu: pcint; node: pcint; tcache: Pointer): cint; cdecl; external 'c' name 'getcpu';

{** @desc 绑定内存到节点（mbind）
    @param addr 地址
    @param len 长度
    @param mode 策略（MPOL_*）
    @param nodemask 节点掩码
    @param maxnode 最大节点
    @param flags 标志（MPOL_MF_*）
    @return 0 成功 *}
function mbind(addr: Pointer; len: culong; mode: cint; nodemask: Pculong; maxnode: culong; flags: cuint): cint; cdecl; external 'c' name 'mbind';

{** @desc 设置 CPU 亲和性
    @param pid 进程/线程 ID
    @param cpusetsize 掩码大小
    @param mask CPU 掩码
    @return 0 成功 *}
function sched_setaffinity(pid: pid_t; cpusetsize: size_t; mask: Pointer): cint; cdecl; external 'c' name 'sched_setaffinity';

{** @desc 获取 CPU 亲和性
    @param pid 进程/线程 ID
    @param cpusetsize 掩码大小
    @param mask 输出掩码
    @return 0 成功 *}
function sched_getaffinity(pid: pid_t; cpusetsize: size_t; mask: Pointer): cint; cdecl; external 'c' name 'sched_getaffinity';

implementation

end.
