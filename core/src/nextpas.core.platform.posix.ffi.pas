unit nextpas.core.platform.posix.ffi;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.posix.base;

{$IF defined(NEXTPAS_LINUX) or defined(NEXTPAS_ANDROID) or defined(NEXTPAS_FREEBSD)}
{$ENDIF}

{ Time }

{** @desc 获取时钟时间
    @param clk_id 时钟 ID（CLOCK_REALTIME/CLOCK_MONOTONIC）
    @param tp 输出 timespec
    @return 0 成功 *}
function clock_gettime(const clk_id: Int32; tp: Pointer): Int32; cdecl; external 'c' name 'clock_gettime';

{** @desc 获取时钟分辨率
    @param clk_id 时钟 ID
    @param tp 输出 timespec
    @return 0 成功 *}
function clock_getres(const clk_id: Int32; tp: Pointer): Int32; cdecl; external 'c' name 'clock_getres';

{** @desc 时钟休眠
    @param clk_id 时钟 ID
    @param flags 标志（TIMER_ABSTIME）
    @param req 休眠时间
    @param rem 剩余时间
    @return 0 成功 *}
function clock_nanosleep(const clk_id: Int32; const flags: Int32; req: Pointer; rem: Pointer): Int32; cdecl; external 'c' name 'clock_nanosleep';

{** @desc 纳秒休眠
    @param req 休眠时间
    @param rem 剩余时间
    @return 0 成功 *}
function nanosleep(req: Pointer; rem: Pointer): Int32; cdecl; external 'c' name 'nanosleep';

{** @desc 获取当前时间
    @param tloc 输出时间
    @return 当前时间戳 *}
function c_time(tloc: Pointer): time_t; cdecl; external 'c' name 'time';

{** @desc 转换为本地时间
    @param timep 时间戳
    @param result_ 输出 tm 结构
    @return tm 指针 *}
function localtime_r(const timep: ptime_t; result_: ptm): ptm; cdecl; external 'c' name 'localtime_r';

{** @desc 转换为 UTC 时间
    @param timep 时间戳
    @param result_ 输出 tm 结构
    @return tm 指针 *}
function gmtime_r(const timep: ptime_t; result_: ptm): ptm; cdecl; external 'c' name 'gmtime_r';

{ Scheduler }

{** @desc 让出 CPU 时间片
    @return 0 成功 *}
function sched_yield: Int32; cdecl; external 'c' name 'sched_yield';

{ System }

{** @desc 获取系统配置值
    @param name 配置名称（_SC_*）
    @return 配置值 *}
function sysconf(name: Int32): PtrInt; cdecl; external 'c' name 'sysconf';

{ Process }

{** @desc 获取当前进程 ID
    @return 进程 ID *}
function getpid: pid_t; cdecl; external 'c' name 'getpid';

{** @desc 获取父进程 ID
    @return 父进程 ID *}
function getppid: pid_t; cdecl; external 'c' name 'getppid';

{ Memory mapping }

{** @desc 内存映射
    @param addr 期望地址（nil 由系统选择）
    @param len 映射长度
    @param prot 保护标志（PROT_READ/WRITE/EXEC）
    @param flags 映射标志（MAP_SHARED/PRIVATE/ANONYMOUS）
    @param fd 文件描述符
    @param ofs 文件偏移
    @return 映射地址，MAP_FAILED 失败 *}
function mmap(addr: Pointer; len: PtrUInt; prot: Int32; flags: Int32; fd: Int32; ofs: Int64): Pointer; cdecl; external 'c' name 'mmap';

{** @desc 取消内存映射
    @param addr 映射地址
    @param len 映射长度
    @return 0 成功 *}
function munmap(addr: Pointer; len: PtrUInt): Int32; cdecl; external 'c' name 'munmap';

{** @desc 设置内存保护
    @param addr 内存地址
    @param len 长度
    @param prot 保护标志
    @return 0 成功 *}
function mprotect(addr: Pointer; len: PtrUInt; prot: Int32): Int32; cdecl; external 'c' name 'mprotect';

{ Shared memory }

{** @desc 打开共享内存对象
    @param name 名称
    @param oflag 打开标志
    @param mode 权限模式
    @return 文件描述符，-1 失败 *}
function shm_open(name: PAnsiChar; oflag: cint; mode: mode_t): cint; cdecl; external {$IFDEF NEXTPAS_LINUX}'rt'{$ELSE}'c'{$ENDIF} name 'shm_open';

{** @desc 删除共享内存对象
    @param name 名称
    @return 0 成功 *}
function shm_unlink(name: PAnsiChar): cint; cdecl; external {$IFDEF NEXTPAS_LINUX}'rt'{$ELSE}'c'{$ENDIF} name 'shm_unlink';
{ File I/O }

{** @desc 打开文件
    @param path 文件路径
    @param flags 打开标志（O_RDONLY/WRITE/CREATE 等）
    @param mode 创建权限（O_CREAT 时作为 vararg 传入；Darwin aarch64 要求 mode 走 varargs ABI）
    @return 文件描述符，-1 失败 *}
function open(path: PAnsiChar; flags: Int32): TPlatformFileDescriptor; cdecl; varargs; external 'c' name 'open';

{** @desc 关闭文件描述符
    @param fd 文件描述符
    @return 0 成功 *}
function close(fd: TPlatformFileDescriptor): Int32; cdecl; external 'c' name 'close';

{** @desc 读取数据
    @param fd 文件描述符
    @param buf 输出缓冲区
    @param count 读取字节数
    @return 实际读取字节数，-1 失败 *}
function read(fd: TPlatformFileDescriptor; buf: Pointer; count: size_t): ssize_t; cdecl; external 'c' name 'read';

{** @desc 写入数据
    @param fd 文件描述符
    @param buf 数据缓冲区
    @param count 写入字节数
    @return 实际写入字节数，-1 失败 *}
function write(fd: TPlatformFileDescriptor; buf: Pointer; count: size_t): ssize_t; cdecl; external 'c' name 'write';

{** @desc 移动文件指针
    @param fd 文件描述符
    @param offset 偏移量
    @param whence 起点（SEEK_SET/CUR/END）
    @return 新偏移量，-1 失败 *}
function lseek(fd: TPlatformFileDescriptor; offset: off_t; whence: Int32): off_t; cdecl; external 'c' name 'lseek';

{** @desc 同步文件到磁盘
    @param fd 文件描述符
    @return 0 成功 *}
function fsync(fd: TPlatformFileDescriptor): Int32; cdecl; external 'c' name 'fsync';

{** @desc 截断文件
    @param fd 文件描述符
    @param length 新长度
    @return 0 成功 *}
function ftruncate(fd: TPlatformFileDescriptor; length: off_t): Int32; cdecl; external 'c' name 'ftruncate';

{** @desc 文件控制
    @param fd 文件描述符
    @param cmd 命令（F_GETFL/SETFL 等）
    @param arg 可选参数（F_SETFL/F_SETFD 等作为 vararg；Darwin aarch64 要求走 varargs ABI）
    @return 命令结果 *}
function fcntl(fd: TPlatformFileDescriptor; cmd: Int32): Int32; cdecl; varargs; external 'c' name 'fcntl';

{ Directory }

{** @desc 创建目录
    @param path 路径
    @param mode 权限模式
    @return 0 成功 *}
function mkdir(path: PAnsiChar; mode: TPlatformFileModeArg): Int32; cdecl; external 'c' name 'mkdir';

{** @desc 删除目录
    @param path 路径
    @return 0 成功 *}
function rmdir(path: PAnsiChar): Int32; cdecl; external 'c' name 'rmdir';

{ File }

{** @desc 删除文件
    @param path 路径
    @return 0 成功 *}
function unlink(path: PAnsiChar): Int32; cdecl; external 'c' name 'unlink';

{** @desc 重命名文件
    @param oldpath 旧路径
    @param newpath 新路径
    @return 0 成功 *}
function rename(oldpath: PAnsiChar; newpath: PAnsiChar): Int32; cdecl; external 'c' name 'rename';

{** @desc 检查文件访问权限
    @param path 路径
    @param mode 访问模式（R_OK/W_OK/X_OK/F_OK）
    @return 0 成功，-1 失败 *}
function access(path: PAnsiChar; mode: Int32): Int32; cdecl; external 'c' name 'access';

{ Working directory }

{** @desc 获取当前工作目录
    @param buf 输出缓冲区
    @param size 缓冲区大小
    @return 缓冲区指针，nil 失败 *}
function getcwd(buf: PAnsiChar; size: PtrUInt): PAnsiChar; cdecl; external 'c' name 'getcwd';

{** @desc 改变工作目录
    @param path 路径
    @return 0 成功 *}
function chdir(path: PAnsiChar): Int32; cdecl; external 'c' name 'chdir';

{ Environment }

{** @desc 获取环境变量
    @param name 变量名
    @return 变量值，nil 不存在 *}
function getenv(name: PAnsiChar): PAnsiChar; cdecl; external 'c' name 'getenv';

{** @desc 设置环境变量
    @param name 变量名
    @param value 变量值
    @param overwrite 是否覆盖
    @return 0 成功 *}
function setenv(name: PAnsiChar; value: PAnsiChar; overwrite: Int32): Int32; cdecl; external 'c' name 'setenv';

{** @desc 删除环境变量
    @param name 变量名
    @return 0 成功 *}
function unsetenv(name: PAnsiChar): Int32; cdecl; external 'c' name 'unsetenv';

{** @desc 设置环境变量（字符串格式）
    @param str "NAME=VALUE" 格式字符串
    @return 0 成功 *}
function putenv(str: PAnsiChar): Int32; cdecl; external 'c' name 'putenv';

{ User/Group }

{** @desc 设置有效用户 ID
    @param uid 用户 ID
    @return 0 成功 *}
function seteuid(uid: uid_t): Int32; cdecl; external 'c' name 'seteuid';

{** @desc 设置有效组 ID
    @param gid 组 ID
    @return 0 成功 *}
function setegid(gid: gid_t): Int32; cdecl; external 'c' name 'setegid';

{ Process control }

{** @desc 创建子进程
    @return 子进程 ID（父进程），0（子进程），-1 失败 *}
function fork: pid_t; cdecl; external 'c' name 'fork';

{** @desc 执行程序（带环境变量）
    @param path 程序路径
    @param argv 参数数组
    @param envp 环境变量数组
    @return 不返回（成功），-1 失败 *}
function execve(path: PAnsiChar; argv: Pointer; envp: Pointer): Int32; cdecl; external 'c' name 'execve';

{** @desc 执行程序（使用 PATH 搜索）
    @param filename 程序名或路径
    @param argv 参数数组
    @return 不返回（成功），-1 失败 *}
function execvp(filename: PAnsiChar; argv: Pointer): Int32; cdecl; external 'c' name 'execvp';

{** @desc 等待子进程
    @param pid 进程 ID（-1 任意子进程）
    @param stat_loc 输出状态
    @param options 选项（WNOHANG 等）
    @return 子进程 ID，0（WNOHANG），-1 失败 *}
function waitpid(pid: pid_t; stat_loc: PInt32; options: Int32): pid_t; cdecl; external 'c' name 'waitpid';

{** @desc 退出进程
    @param status 退出码 *}
procedure posix_exit(status: Int32); cdecl; external 'c' name '_exit';

{** @desc 向进程发送信号
    @param pid 进程 ID
    @param sig 信号编号
    @return 0 成功 *}
function kill(pid: pid_t; sig: Int32): Int32; cdecl; external 'c' name 'kill';

{ User info }

{** @desc 按用户名查找用户信息
    @param name 用户名
    @return passwd 结构指针，nil 未找到 *}
function getpwnam(name: PAnsiChar): Pointer; cdecl; external 'c' name 'getpwnam';

{** @desc 按用户 ID 查找用户信息
    @param uid 用户 ID
    @return passwd 结构指针，nil 未找到 *}
function getpwuid(uid: uid_t): Pointer; cdecl; external 'c' name 'getpwuid';

{ Pthread - Thread lifecycle }

{** @desc 创建线程
    @param thread 输出线程 ID
    @param attr 线程属性
    @param start_routine 线程入口函数
    @param arg 传递给线程的参数
    @return 0 成功 *}
function pthread_create(thread: Pointer; attr: Pointer; start_routine: TPThreadStartRoutine; arg: Pointer): Int32; cdecl; external 'pthread' name 'pthread_create';

{** @desc 等待线程结束
    @param thread 线程 ID
    @param retval 输出线程返回值
    @return 0 成功 *}
function pthread_join(thread: pthread_t; retval: Pointer): Int32; cdecl; external 'pthread' name 'pthread_join';

{** @desc 分离线程
    @param thread 线程 ID
    @return 0 成功 *}
function pthread_detach(thread: pthread_t): Int32; cdecl; external 'pthread' name 'pthread_detach';

{** @desc 获取当前线程 ID
    @return 线程 ID *}
function pthread_self: pthread_t; cdecl; external 'pthread' name 'pthread_self';

{ Pthread - TLS (Thread Local Storage) }

{** @desc 创建 TLS 键
    @param key 输出 TLS 键
    @param destructor_proc 析构函数
    @return 0 成功 *}
function pthread_key_create(key: Pointer; destructor_proc: Pointer): Int32; cdecl; external 'pthread' name 'pthread_key_create';

{** @desc 删除 TLS 键
    @param key TLS 键
    @return 0 成功 *}
function pthread_key_delete(key: pthread_key_t): Int32; cdecl; external 'pthread' name 'pthread_key_delete';

{** @desc 设置 TLS 值
    @param key TLS 键
    @param value 值
    @return 0 成功 *}
function pthread_setspecific(key: pthread_key_t; value: Pointer): Int32; cdecl; external 'pthread' name 'pthread_setspecific';

{** @desc 获取 TLS 值
    @param key TLS 键
    @return 值指针 *}
function pthread_getspecific(key: pthread_key_t): Pointer; cdecl; external 'pthread' name 'pthread_getspecific';

{ Pthread - Mutex }

{** @desc 初始化互斥锁属性
    @param attr 输出属性
    @return 0 成功 *}
function pthread_mutexattr_init(attr: Pointer): Int32; cdecl; external 'pthread' name 'pthread_mutexattr_init';

{** @desc 设置互斥锁类型
    @param attr 属性
    @param kind 互斥锁类型编号（由各 host base 定义）
    @return 0 成功 *}
function pthread_mutexattr_settype(attr: Pointer; kind: Int32): Int32; cdecl; external 'pthread' name 'pthread_mutexattr_settype';

{** @desc 销毁互斥锁属性
    @param attr 属性
    @return 0 成功 *}
function pthread_mutexattr_destroy(attr: Pointer): Int32; cdecl; external 'pthread' name 'pthread_mutexattr_destroy';

{** @desc 初始化互斥锁
    @param mutex 互斥锁
    @param attr 属性
    @return 0 成功 *}
function pthread_mutex_init(mutex: Pointer; attr: Pointer): Int32; cdecl; external 'pthread' name 'pthread_mutex_init';

{** @desc 销毁互斥锁
    @param mutex 互斥锁
    @return 0 成功 *}
function pthread_mutex_destroy(mutex: Pointer): Int32; cdecl; external 'pthread' name 'pthread_mutex_destroy';

{** @desc 加锁（阻塞）
    @param mutex 互斥锁
    @return 0 成功 *}
function pthread_mutex_lock(mutex: Pointer): Int32; cdecl; external 'pthread' name 'pthread_mutex_lock';

{** @desc 尝试加锁（非阻塞）
    @param mutex 互斥锁
    @return 0 成功，EBUSY 锁被占用 *}
function pthread_mutex_trylock(mutex: Pointer): Int32; cdecl; external 'pthread' name 'pthread_mutex_trylock';

{** @desc 带超时加锁
    @param mutex 互斥锁
    @param abstime 绝对超时时间
    @return 0 成功，ETIMEDOUT 超时 *}
function pthread_mutex_timedlock(mutex: Pointer; abstime: PTimeSpec): Int32; cdecl; external 'pthread' name 'pthread_mutex_timedlock';

{** @desc 解锁
    @param mutex 互斥锁
    @return 0 成功 *}
function pthread_mutex_unlock(mutex: Pointer): Int32; cdecl; external 'pthread' name 'pthread_mutex_unlock';

{ Pthread - RWLock }

{** @desc 初始化读写锁
    @param rwlock 读写锁
    @param attr 属性
    @return 0 成功 *}
function pthread_rwlock_init(rwlock: Pointer; attr: Pointer): Int32; cdecl; external 'pthread' name 'pthread_rwlock_init';

{** @desc 销毁读写锁
    @param rwlock 读写锁
    @return 0 成功 *}
function pthread_rwlock_destroy(rwlock: Pointer): Int32; cdecl; external 'pthread' name 'pthread_rwlock_destroy';

{** @desc 获取读锁（阻塞）
    @param rwlock 读写锁
    @return 0 成功 *}
function pthread_rwlock_rdlock(rwlock: Pointer): Int32; cdecl; external 'pthread' name 'pthread_rwlock_rdlock';

{** @desc 尝试获取读锁（非阻塞）
    @param rwlock 读写锁
    @return 0 成功，EBUSY 锁被占用 *}
function pthread_rwlock_tryrdlock(rwlock: Pointer): Int32; cdecl; external 'pthread' name 'pthread_rwlock_tryrdlock';

{** @desc 获取写锁（阻塞）
    @param rwlock 读写锁
    @return 0 成功 *}
function pthread_rwlock_wrlock(rwlock: Pointer): Int32; cdecl; external 'pthread' name 'pthread_rwlock_wrlock';

{** @desc 尝试获取写锁（非阻塞）
    @param rwlock 读写锁
    @return 0 成功，EBUSY 锁被占用 *}
function pthread_rwlock_trywrlock(rwlock: Pointer): Int32; cdecl; external 'pthread' name 'pthread_rwlock_trywrlock';

{** @desc 解锁读写锁
    @param rwlock 读写锁
    @return 0 成功 *}
function pthread_rwlock_unlock(rwlock: Pointer): Int32; cdecl; external 'pthread' name 'pthread_rwlock_unlock';

{ Pthread - CondVar }

{** @desc 初始化条件变量属性
    @param attr 输出属性
    @return 0 成功 *}
function pthread_condattr_init(attr: Pointer): Int32; cdecl; external 'pthread' name 'pthread_condattr_init';

{** @desc 销毁条件变量属性
    @param attr 属性
    @return 0 成功 *}
function pthread_condattr_destroy(attr: Pointer): Int32; cdecl; external 'pthread' name 'pthread_condattr_destroy';

{** @desc 初始化条件变量
    @param cond 条件变量
    @param attr 属性
    @return 0 成功 *}
function pthread_cond_init(cond: Pointer; attr: Pointer): Int32; cdecl; external 'pthread' name 'pthread_cond_init';

{** @desc 销毁条件变量
    @param cond 条件变量
    @return 0 成功 *}
function pthread_cond_destroy(cond: Pointer): Int32; cdecl; external 'pthread' name 'pthread_cond_destroy';

{** @desc 等待条件变量（阻塞）
    @param cond 条件变量
    @param mutex 互斥锁（原子释放并等待）
    @return 0 成功 *}
function pthread_cond_wait(cond: Pointer; mutex: Pointer): Int32; cdecl; external 'pthread' name 'pthread_cond_wait';

{** @desc 带超时等待条件变量
    @param cond 条件变量
    @param mutex 互斥锁
    @param abstime 绝对超时时间
    @return 0 成功，ETIMEDOUT 超时 *}
function pthread_cond_timedwait(cond: Pointer; mutex: Pointer; abstime: PTimeSpec): Int32; cdecl; external 'pthread' name 'pthread_cond_timedwait';

{** @desc 唤醒一个等待线程
    @param cond 条件变量
    @return 0 成功 *}
function pthread_cond_signal(cond: Pointer): Int32; cdecl; external 'pthread' name 'pthread_cond_signal';

{** @desc 唤醒所有等待线程
    @param cond 条件变量
    @return 0 成功 *}
function pthread_cond_broadcast(cond: Pointer): Int32; cdecl; external 'pthread' name 'pthread_cond_broadcast';

{ Pipe }

{** @desc 创建管道
    @param pipefd 输出管道文件描述符数组 [读, 写]
    @return 0 成功 *}
function pipe(pipefd: PInt32): cint; cdecl; external 'c' name 'pipe';

{$IFNDEF NEXTPAS_MACOS}
{** @desc 创建管道（带标志）
    @param pipefd 输出管道文件描述符数组 [读, 写]
    @param flags 标志（O_CLOEXEC/O_NONBLOCK）
    @return 0 成功 *}
function pipe2(pipefd: PInt32; flags: cint): cint; cdecl; external 'c' name 'pipe2';

var
  {** 环境变量数组 — shared POSIX raw inventory for Linux/Android/FreeBSD/generic Unix;
       Darwin uses NSGetEnviron in darwin.ffi (no linkable environ) *}
  environ: PPAnsiChar; external name 'environ';
{$ENDIF}

{ File descriptor }

{** @desc 复制文件描述符
    @param oldfd 源文件描述符
    @return 新文件描述符，-1 失败 *}
function dup(oldfd: cint): cint; cdecl; external 'c' name 'dup';

{** @desc 复制文件描述符到指定位置
    @param oldfd 源文件描述符
    @param newfd 目标文件描述符
    @return 新文件描述符，-1 失败 *}
function dup2(oldfd: cint; newfd: cint): cint; cdecl; external 'c' name 'dup2';

{ Symbolic link }

{** @desc 读取符号链接
    @param path 符号链接路径
    @param buf 输出缓冲区
    @param bufsiz 缓冲区大小
    @return 读取字节数，-1 失败 *}
function readlink(path: PAnsiChar; buf: PAnsiChar; bufsiz: size_t): ssize_t; cdecl; external 'c' name 'readlink';

{** @desc 创建符号链接
    @param target 目标路径
    @param linkpath 链接路径
    @return 0 成功 *}
function symlink(target: PAnsiChar; linkpath: PAnsiChar): cint; cdecl; external 'c' name 'symlink';

{** @desc 创建硬链接
    @param oldpath 现有文件路径
    @param newpath 新链接路径
    @return 0 成功 *}
function link(oldpath: PAnsiChar; newpath: PAnsiChar): cint; cdecl; external 'c' name 'link';

{** @desc 设置访问/修改时间（纳秒；dirfd 常用 AT_FDCWD=-100）
    @param dirfd 目录 fd 或 AT_FDCWD
    @param pathname 路径
    @param times 长度为 2 的 timespec 数组：atime, mtime
    @param flags 0 或 AT_SYMLINK_NOFOLLOW
    @return 0 成功 *}
function utimensat(dirfd: cint; pathname: PAnsiChar; times: PTimeSpec;
  flags: cint): cint; cdecl; external 'c' name 'utimensat';

{ Permission }

{** @desc 创建 FIFO 特殊文件
    @param path 路径
    @param mode 权限
    @return 0 成功 *}
function mkfifo(path: PAnsiChar; mode: mode_t): cint; cdecl; external 'c' name 'mkfifo';

{** @desc 创建设备节点（owner 反哺：tar device 往返完整，经平台单缝）
    @param path 路径
    @param mode 权限+类型（S_IFCHR/S_IFBLK）
    @param dev 设备号（makedev 编码）
    @return 0 成功 *}
function mknod(path: PAnsiChar; mode: mode_t; dev: dev_t): cint; cdecl; external 'c' name 'mknod';

{** @desc 设置文件权限
    @param path 文件路径
    @param mode 权限模式
    @return 0 成功 *}
function chmod(path: PAnsiChar; mode: mode_t): cint; cdecl; external 'c' name 'chmod';

{** @desc 设置文件权限（通过文件描述符）
    @param fd 文件描述符
    @param mode 权限模式
    @return 0 成功 *}
function fchmod(fd: cint; mode: mode_t): cint; cdecl; external 'c' name 'fchmod';

{** @desc 设置文件所有者
    @param path 文件路径
    @param owner 用户 ID
    @param group 组 ID
    @return 0 成功 *}
function chown(path: PAnsiChar; owner: uid_t; group: gid_t): cint; cdecl; external 'c' name 'chown';

{** @desc 设置文件所有者（通过文件描述符）
    @param fd 文件描述符
    @param owner 用户 ID
    @param group 组 ID
    @return 0 成功 *}
function fchown(fd: cint; owner: uid_t; group: gid_t): cint; cdecl; external 'c' name 'fchown';

{** @desc 设置文件所有者（不跟随符号链接）
    @param path 文件路径
    @param owner 用户 ID
    @param group 组 ID
    @return 0 成功 *}
function lchown(path: PAnsiChar; owner: uid_t; group: gid_t): cint; cdecl; external 'c' name 'lchown';

{ User/Group ID }

{** @desc 获取实际用户 ID
    @return 用户 ID *}
function getuid: uid_t; cdecl; external 'c' name 'getuid';

{** @desc 获取有效用户 ID
    @return 用户 ID *}
function geteuid: uid_t; cdecl; external 'c' name 'geteuid';

{** @desc 获取实际组 ID
    @return 组 ID *}
function getgid: gid_t; cdecl; external 'c' name 'getgid';

{** @desc 获取有效组 ID
    @return 组 ID *}
function getegid: gid_t; cdecl; external 'c' name 'getegid';

{** @desc 设置实际用户 ID
    @param uid 用户 ID
    @return 0 成功 *}
function setuid(uid: uid_t): cint; cdecl; external 'c' name 'setuid';

{** @desc 设置实际组 ID
    @param gid 组 ID
    @return 0 成功 *}
function setgid(gid: gid_t): cint; cdecl; external 'c' name 'setgid';

{** @desc 设置文件创建掩码
    @param mask 掩码
    @return 旧掩码 *}
function umask(mask: mode_t): mode_t; cdecl; external 'c' name 'umask';

{ I/O multiplexing }

{** @desc 轮询文件描述符
    @param fds pollfd 数组
    @param nfds 数组长度
    @param timeout 超时毫秒数（-1 无限等待）
    @return 就绪描述符数，-1 失败 *}
function poll(fds: Pointer; nfds: cuint; timeout: cint): cint; cdecl; external 'c' name 'poll';

{ Socket }

{** @desc 创建套接字
    @param domain 协议族（AF_INET/INET6/UNIX）
    @param xtype 类型（SOCK_STREAM/DGRAM/RAW）
    @param protocol 协议
    @return 套接字文件描述符，-1 失败 *}
function socket(domain: cint; xtype: cint; protocol: cint): cint; cdecl; external 'c' name 'socket';

{** @desc 绑定地址
    @param sockfd 套接字
    @param addr 地址
    @param addrlen 地址长度
    @return 0 成功 *}
function bind(sockfd: cint; addr: Pointer; addrlen: socklen_t): cint; cdecl; external 'c' name 'bind';

{** @desc 监听连接
    @param sockfd 套接字
    @param backlog 连接队列长度
    @return 0 成功 *}
function listen(sockfd: cint; backlog: cint): cint; cdecl; external 'c' name 'listen';

{** @desc 接受连接
    @param sockfd 监听套接字
    @param addr 输出对端地址
    @param addrlen 地址长度
    @return 新套接字文件描述符，-1 失败 *}
function accept(sockfd: cint; addr: Pointer; addrlen: Pointer): cint; cdecl; external 'c' name 'accept';

{** @desc 连接到对端
    @param sockfd 套接字
    @param addr 目标地址
    @param addrlen 地址长度
    @return 0 成功 *}
function connect(sockfd: cint; addr: Pointer; addrlen: socklen_t): cint; cdecl; external 'c' name 'connect';

{** @desc 发送数据
    @param sockfd 套接字
    @param buf 数据缓冲区
    @param len 数据长度
    @param flags 标志
    @return 发送字节数，-1 失败 *}
function send(sockfd: cint; buf: Pointer; len: size_t; flags: cint): ssize_t; cdecl; external 'c' name 'send';

{** @desc 接收数据
    @param sockfd 套接字
    @param buf 输出缓冲区
    @param len 缓冲区大小
    @param flags 标志
    @return 接收字节数，-1 失败 *}
function recv(sockfd: cint; buf: Pointer; len: size_t; flags: cint): ssize_t; cdecl; external 'c' name 'recv';
{** @desc 发送数据到指定地址
    @param sockfd 套接字
    @param buf 数据缓冲区
    @param len 数据长度
    @param flags 标志
    @param dest_addr 目标地址
    @param addrlen 地址长度
    @return 发送字节数，-1 失败 *}
function sendto(sockfd: cint; buf: Pointer; len: size_t; flags: cint; dest_addr: Pointer; addrlen: socklen_t): ssize_t; cdecl; external 'c' name 'sendto';

{** @desc 接收数据并获取发送方地址
    @param sockfd 套接字
    @param buf 输出缓冲区
    @param len 缓冲区大小
    @param flags 标志
    @param src_addr 输出发送方地址
    @param addrlen 地址长度
    @return 接收字节数，-1 失败 *}
function recvfrom(sockfd: cint; buf: Pointer; len: size_t; flags: cint; src_addr: Pointer; addrlen: Pointer): ssize_t; cdecl; external 'c' name 'recvfrom';

{** @desc 关闭套接字（部分或全部）
    @param sockfd 套接字
    @param how 关闭方式（SHUT_RD/WR/RDWR）
    @return 0 成功 *}
function shutdown(sockfd: cint; how: cint): cint; cdecl; external 'c' name 'shutdown';

{** @desc 获取套接字本地地址
    @param sockfd 套接字
    @param addr 输出地址
    @param addrlen 地址长度
    @return 0 成功 *}
function getsockname(sockfd: cint; addr: Pointer; addrlen: Pointer): cint; cdecl; external 'c' name 'getsockname';

{** @desc 获取套接字对端地址
    @param sockfd 套接字
    @param addr 输出地址
    @param addrlen 地址长度
    @return 0 成功 *}
function getpeername(sockfd: cint; addr: Pointer; addrlen: Pointer): cint; cdecl; external 'c' name 'getpeername';

{** @desc 获取套接字选项
    @param sockfd 套接字
    @param level 选项级别（SOL_SOCKET/IPPROTO_TCP 等）
    @param optname 选项名
    @param optval 输出选项值
    @param optlen 值长度
    @return 0 成功 *}
function getsockopt(sockfd: cint; level: cint; optname: cint; optval: Pointer; optlen: Pointer): cint; cdecl; external 'c' name 'getsockopt';

{** @desc 设置套接字选项
    @param sockfd 套接字
    @param level 选项级别
    @param optname 选项名
    @param optval 选项值
    @param optlen 值长度
    @return 0 成功 *}
function setsockopt(sockfd: cint; level: cint; optname: cint; optval: Pointer; optlen: socklen_t): cint; cdecl; external 'c' name 'setsockopt';

{** @desc 创建套接字对
    @param domain 协议族
    @param xtype 类型
    @param protocol 协议
    @param sv 输出套接字对 [0, 1]
    @return 0 成功 *}
function socketpair(domain: cint; xtype: cint; protocol: cint; sv: PInt32): cint; cdecl; external 'c' name 'socketpair';

{ DNS }

{** @desc 地址解析（DNS 查询）
    @param node 主机名
    @param service 服务名或端口
    @param hints 查询提示
    @param res 输出地址信息链表
    @return 0 成功 *}
function getaddrinfo(node: PAnsiChar; service: PAnsiChar; hints: PAddrInfo; res: PPAddrInfo): cint; cdecl; external 'c' name 'getaddrinfo';

{** @desc 释放地址信息
    @param res 地址信息链表 *}
procedure freeaddrinfo(res: PAddrInfo); cdecl; external 'c' name 'freeaddrinfo';

{** @desc 反向地址解析
    @param sa 地址
    @param salen 地址长度
    @param host 输出主机名
    @param hostlen 主机名缓冲区大小
    @param serv 输出服务名
    @param servlen 服务名缓冲区大小
    @param flags 标志
    @return 0 成功 *}
function getnameinfo(sa: Pointer; salen: socklen_t; host: PAnsiChar; hostlen: size_t; serv: PAnsiChar; servlen: size_t; flags: cint): cint; cdecl; external 'c' name 'getnameinfo';

{ Vectored I/O }

{** @desc 分散读取
    @param fd 文件描述符
    @param iov iovec 数组
    @param iovcnt 数组长度
    @return 读取字节数，-1 失败 *}
function readv(fd: cint; iov: piovec; iovcnt: cint): ssize_t; cdecl; external 'c' name 'readv';

{** @desc 聚集写入
    @param fd 文件描述符
    @param iov iovec 数组
    @param iovcnt 数组长度
    @return 写入字节数，-1 失败 *}
function writev(fd: cint; iov: piovec; iovcnt: cint): ssize_t; cdecl; external 'c' name 'writev';

{** @desc 发送消息（带辅助数据）
    @param sockfd 套接字
    @param msg 消息结构
    @param flags 标志
    @return 发送字节数，-1 失败 *}
function sendmsg(sockfd: cint; msg: Pointer; flags: cint): ssize_t; cdecl; external 'c' name 'sendmsg';

{** @desc 接收消息（带辅助数据）
    @param sockfd 套接字
    @param msg 消息结构
    @param flags 标志
    @return 接收字节数，-1 失败 *}
function recvmsg(sockfd: cint; msg: Pointer; flags: cint): ssize_t; cdecl; external 'c' name 'recvmsg';

{ Terminal I/O }

{** @desc 获取终端属性
    @param fd 文件描述符
    @param termios_p 输出终端属性
    @return 0 成功 *}
function tcgetattr(fd: cint; termios_p: Pointer): cint; cdecl; external 'c' name 'tcgetattr';

{** @desc 设置终端属性
    @param fd 文件描述符
    @param optional_actions 何时生效（TCSANOW/FLUSH/DRAIN）
    @param termios_p 终端属性
    @return 0 成功 *}
function tcsetattr(fd: cint; optional_actions: cint; termios_p: Pointer): cint; cdecl; external 'c' name 'tcsetattr';

{** @desc 获取输入波特率
    @param termios_p 终端属性
    @return 波特率 *}
function cfgetispeed(termios_p: Pointer): cuint32; cdecl; external 'c' name 'cfgetispeed';

{** @desc 获取输出波特率
    @param termios_p 终端属性
    @return 波特率 *}
function cfgetospeed(termios_p: Pointer): cuint32; cdecl; external 'c' name 'cfgetospeed';

{** @desc 设置输入波特率
    @param termios_p 终端属性
    @param speed 波特率
    @return 0 成功 *}
function cfsetispeed(termios_p: Pointer; speed: cuint32): cint; cdecl; external 'c' name 'cfsetispeed';

{** @desc 设置输出波特率
    @param termios_p 终端属性
    @param speed 波特率
    @return 0 成功 *}
function cfsetospeed(termios_p: Pointer; speed: cuint32): cint; cdecl; external 'c' name 'cfsetospeed';

{** @desc 等待输出 drain
    @param fd 文件描述符
    @return 0 成功 *}
function tcdrain(fd: cint): cint; cdecl; external 'c' name 'tcdrain';

{** @desc 刷新终端队列
    @param fd 文件描述符
    @param queue_selector 队列（TCIFLUSH/TCOFLUSH/TCIOFLUSH）
    @return 0 成功 *}
function tcflush(fd: cint; queue_selector: cint): cint; cdecl; external 'c' name 'tcflush';

{** @desc 挂起/恢复终端数据传输
    @param fd 文件描述符
    @param action 动作（TCOOFF/TCOON/TCIOFF/TCION）
    @return 0 成功 *}
function tcflow(fd: cint; action: cint): cint; cdecl; external 'c' name 'tcflow';

{** @desc 发送终端 break
    @param fd 文件描述符
    @param duration 持续时间
    @return 0 成功 *}
function tcsendbreak(fd: cint; duration: cint): cint; cdecl; external 'c' name 'tcsendbreak';

{** @desc 检查是否为终端
    @param fd 文件描述符
    @return 非 0 是终端 *}
function isatty(fd: cint): cint; cdecl; external 'c' name 'isatty';

{** @desc 设备控制
    @param fd 文件描述符
    @param request 请求码
    @param args 参数
    @return 0 成功 *}
function ioctl(fd: cint; request: culong; args: Pointer): cint; cdecl; varargs; external 'c' name 'ioctl';

{ String }

{** @desc 获取错误信息
    @param errnum 错误码
    @return 错误信息字符串 *}
function strerror(errnum: cint): PAnsiChar; cdecl; external 'c' name 'strerror';

{ Path }

{** @desc 解析绝对路径
    @param path 路径
    @param resolved_path 输出缓冲区
    @return 绝对路径指针，nil 失败 *}
function realpath(path: PAnsiChar; resolved_path: PAnsiChar): PAnsiChar; cdecl; external 'c' name 'realpath';

{ Positional I/O }

{** @desc 偏移读取
    @param fd 文件描述符
    @param buf 输出缓冲区
    @param count 读取字节数
    @param offset 文件偏移
    @return 读取字节数，-1 失败 *}
function pread(fd: cint; buf: Pointer; count: size_t; offset: off_t): ssize_t; cdecl; external 'c' name 'pread';

{** @desc 偏移写入
    @param fd 文件描述符
    @param buf 数据缓冲区
    @param count 写入字节数
    @param offset 文件偏移
    @return 写入字节数，-1 失败 *}
function pwrite(fd: cint; buf: Pointer; count: size_t; offset: off_t): ssize_t; cdecl; external 'c' name 'pwrite';

{** @desc 截断文件（通过路径）
    @param path 文件路径
    @param length 新长度
    @return 0 成功 *}
function truncate(path: PAnsiChar; length: off_t): cint; cdecl; external 'c' name 'truncate';

{ Temporary files }

{** @desc 创建临时文件
    @param template 模板（最后 6 个字符必须是 XXXXXX）
    @return 文件描述符，-1 失败 *}
function mkstemp(template: PAnsiChar): cint; cdecl; external 'c' name 'mkstemp';

{** @desc 创建临时目录
    @param template 模板（最后 6 个字符必须是 XXXXXX）
    @return 目录路径指针，nil 失败 *}
function mkdtemp(template: PAnsiChar): PAnsiChar; cdecl; external 'c' name 'mkdtemp';

{ File locking }

{** @desc 文件锁
    @param fd 文件描述符
    @param operation 操作（LOCK_SH/EX/UN/NB）
    @return 0 成功 *}
function flock(fd: cint; operation: cint): cint; cdecl; external 'c' name 'flock';

{ Memory advice }

{** @desc 内存使用建议
    @param addr 内存地址
    @param length 长度
    @param advice 建议（MADV_NORMAL/SEQUENTIAL/RANDOM/WILLNEED/DONTNEED）
    @return 0 成功 *}
function madvise(addr: Pointer; length: size_t; advice: cint): cint; cdecl; external 'c' name 'madvise';
{** @desc 内存同步
    @param addr 内存地址
    @param length 长度
    @param flags 标志（MS_SYNC/MS_ASYNC/MS_INVALIDATE）
    @return 0 成功 *}
function msync(addr: Pointer; length: size_t; flags: cint): cint; cdecl; external 'c' name 'msync';

{** @desc 锁定内存页
    @param addr 内存地址
    @param length 长度
    @return 0 成功 *}
function mlock(addr: Pointer; length: size_t): cint; cdecl; external 'c' name 'mlock';

{** @desc 解锁内存页
    @param addr 内存地址
    @param length 长度
    @return 0 成功 *}
function munlock(addr: Pointer; length: size_t): cint; cdecl; external 'c' name 'munlock';

{ Resource limits }

{** @desc 获取资源限制
    @param resource 资源类型（RLIMIT_*）
    @param rlim 输出限制
    @return 0 成功 *}
function getrlimit(resource: cint; rlim: Pointer): cint; cdecl; external 'c' name 'getrlimit';

{** @desc 设置资源限制
    @param resource 资源类型
    @param rlim 限制值
    @return 0 成功 *}
function setrlimit(resource: cint; rlim: Pointer): cint; cdecl; external 'c' name 'setrlimit';

{ Memory allocation }

{** @desc 对齐内存分配
    @param memptr 输出内存指针
    @param alignment 对齐要求
    @param size 分配大小
    @return 0 成功 *}
function posix_memalign(memptr: PPointer; alignment: size_t; size: size_t): cint; cdecl; external 'c' name 'posix_memalign';

{** @desc 安全清零内存
    @param s 内存地址
    @param n 长度 *}
procedure explicit_bzero(s: Pointer; n: size_t); cdecl; external 'c' name 'explicit_bzero';

{** @desc 释放内存
    @param ptr 内存指针 *}
procedure free(ptr: Pointer); cdecl; external 'c' name 'free';

{ Platform-specific stat (macOS/FreeBSD use native stat) }
{$IF defined(NEXTPAS_MACOS) or defined(NEXTPAS_FREEBSD)}
{** @desc 获取文件状态
    @param path 文件路径
    @param buf 输出文件状态
    @return 0 成功 *}
function fpstat(path: PAnsiChar; buf: Pointer): cint; cdecl; external 'c' name 'stat';

{** @desc 获取符号链接状态
    @param path 文件路径
    @param buf 输出文件状态
    @return 0 成功 *}
function fplstat(path: PAnsiChar; buf: Pointer): cint; cdecl; external 'c' name 'lstat';

{** @desc 获取文件描述符状态
    @param fd 文件描述符
    @param buf 输出文件状态
    @return 0 成功 *}
function fpfstat(fd: cint; buf: Pointer): cint; cdecl; external 'c' name 'fstat';
{$ENDIF}

{ Errno location }

{** @desc 获取 errno 地址（Linux）
    @return errno 指针 *}
{$IFDEF NEXTPAS_LINUX}
function __errno_location: PInt32; cdecl; external 'c' name '__errno_location';
{$ENDIF}

{** @desc 获取 errno 地址（macOS/FreeBSD）
    @return errno 指针 *}
{$IF defined(NEXTPAS_MACOS) or defined(NEXTPAS_FREEBSD)}
function __error: PInt32; cdecl; external 'c' name '__error';
{$ENDIF}

{ PTY / session }

{** @desc 创建新会话
    @return 会话 ID *}
function setsid: pid_t; cdecl; external 'c' name 'setsid';

{** @desc 打开伪终端主设备
    @param AFlags 标志（O_RDWR/O_NOCTTY）
    @return 文件描述符，-1 失败 *}
function posix_openpt(AFlags: cint): cint; cdecl; external 'c' name 'posix_openpt';

{** @desc 授权从端设备访问
    @param AFd 主端文件描述符
    @return 0 成功 *}
function grantpt(AFd: cint): cint; cdecl; external 'c' name 'grantpt';

{** @desc 解锁从端设备
    @param AFd 主端文件描述符
    @return 0 成功 *}
function unlockpt(AFd: cint): cint; cdecl; external 'c' name 'unlockpt';

{** @desc 获取从端设备路径
    @param AFd 主端文件描述符
    @return 从端设备路径 *}
function ptsname(AFd: cint): PAnsiChar; cdecl; external 'c' name 'ptsname';

{ File transfer }

{** @desc 零拷贝文件传输
    @param AOutFd 输出文件描述符
    @param AInFd 输入文件描述符
    @param AOffset 偏移量
    @param ACount 传输字节数
    @return 传输字节数，-1 失败 *}
function sendfile(AOutFd: cint; AInFd: cint; AOffset: Pointer;
  ACount: size_t): ssize_t; cdecl; external 'c' name 'sendfile';

{ System information }

{** @desc 获取系统标识
    @param buf 输出系统标识
    @return 0 成功 *}
function uname(buf: Pointer): cint; cdecl; external 'c' name 'uname';

{ File status }

{** @desc 获取文件状态（相对路径）
    @param dirfd 目录文件描述符
    @param pathname 文件路径
    @param buf 输出文件状态
    @param flags 标志（AT_SYMLINK_NOFOLLOW 等）
    @return 0 成功 *}
function fstatat(dirfd: cint; pathname: PAnsiChar; buf: Pointer; flags: cint): cint; cdecl; external 'c' name 'fstatat';

{ Filesystem statistics }

{** @desc 获取文件系统状态
    @param path 路径
    @param buf 输出文件系统状态
    @return 0 成功 *}
function statfs(path: PAnsiChar; buf: Pointer): cint; cdecl; external 'c' name 'statfs';

{** @desc 获取文件系统状态（通过文件描述符）
    @param fd 文件描述符
    @param buf 输出文件系统状态
    @return 0 成功 *}
function fstatfs(fd: cint; buf: Pointer): cint; cdecl; external 'c' name 'fstatfs';

{ Process groups }

{** @desc 获取进程组 ID
    @return 进程组 ID *}
function getpgrp: pid_t; cdecl; external 'c' name 'getpgrp';

{** @desc 设置进程组（pid/pgid 为 0 表示当前进程）
    @param pid 进程 ID
    @param pgid 进程组 ID
    @return 0 成功 *}
function setpgid(pid: pid_t; pgid: pid_t): Int32; cdecl; external 'c' name 'setpgid';

{** @desc 设置进程组 ID
    @return 进程组 ID *}
function setpgrp: pid_t; cdecl; external 'c' name 'setpgrp';

{** @desc 获取会话 ID
    @param pid 进程 ID
    @return 会话 ID *}
function getsid(pid: pid_t): pid_t; cdecl; external 'c' name 'getsid';

{ User/group info }

{** @desc 按组名查找组信息
    @param name 组名
    @return group 结构指针，nil 未找到 *}
function getgrnam(name: PAnsiChar): Pointer; cdecl; external 'c' name 'getgrnam';

{** @desc 按组 ID 查找组信息
    @param gid 组 ID
    @return group 结构指针，nil 未找到 *}
function getgrgid(gid: gid_t): Pointer; cdecl; external 'c' name 'getgrgid';

implementation

end.
