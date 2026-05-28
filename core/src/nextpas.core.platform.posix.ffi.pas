unit nextpas.core.platform.posix.ffi;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.posix.base;

{$IF defined(NEXTPAS_LINUX) or defined(NEXTPAS_ANDROID) or defined(NEXTPAS_FREEBSD)}
{$ENDIF}

function clock_gettime(const clk_id: Int32; tp: Pointer): Int32; cdecl; external 'c' name 'clock_gettime';
function clock_getres(const clk_id: Int32; tp: Pointer): Int32; cdecl; external 'c' name 'clock_getres';
function nanosleep(req: Pointer; rem: Pointer): Int32; cdecl; external 'c' name 'nanosleep';
function sched_yield: Int32; cdecl; external 'c' name 'sched_yield';
function sysconf(name: Int32): PtrInt; cdecl; external 'c' name 'sysconf';
function getpid: pid_t; cdecl; external 'c' name 'getpid';
function getppid: pid_t; cdecl; external 'c' name 'getppid';
function mmap(addr: Pointer; len: PtrUInt; prot: Int32; flags: Int32; fd: Int32; ofs: Int64): Pointer; cdecl; external 'c' name 'mmap';
function munmap(addr: Pointer; len: PtrUInt): Int32; cdecl; external 'c' name 'munmap';
function mprotect(addr: Pointer; len: PtrUInt; prot: Int32): Int32; cdecl; external 'c' name 'mprotect';
function open(path: PAnsiChar; flags: Int32; mode: TPlatformFileModeArg): TPlatformFileDescriptor; cdecl; external 'c' name 'open';
function close(fd: TPlatformFileDescriptor): Int32; cdecl; external 'c' name 'close';
function read(fd: TPlatformFileDescriptor; buf: Pointer; count: size_t): ssize_t; cdecl; external 'c' name 'read';
function write(fd: TPlatformFileDescriptor; buf: Pointer; count: size_t): ssize_t; cdecl; external 'c' name 'write';
function lseek(fd: TPlatformFileDescriptor; offset: off_t; whence: Int32): off_t; cdecl; external 'c' name 'lseek';
function fsync(fd: TPlatformFileDescriptor): Int32; cdecl; external 'c' name 'fsync';
function ftruncate(fd: TPlatformFileDescriptor; length: off_t): Int32; cdecl; external 'c' name 'ftruncate';
function fcntl(fd: TPlatformFileDescriptor; cmd: Int32; arg: PtrInt): Int32; cdecl; external 'c' name 'fcntl';
function mkdir(path: PAnsiChar; mode: TPlatformFileModeArg): Int32; cdecl; external 'c' name 'mkdir';
function rmdir(path: PAnsiChar): Int32; cdecl; external 'c' name 'rmdir';
function unlink(path: PAnsiChar): Int32; cdecl; external 'c' name 'unlink';
function rename(oldpath: PAnsiChar; newpath: PAnsiChar): Int32; cdecl; external 'c' name 'rename';
function access(path: PAnsiChar; mode: Int32): Int32; cdecl; external 'c' name 'access';
function getcwd(buf: PAnsiChar; size: PtrUInt): PAnsiChar; cdecl; external 'c' name 'getcwd';
function chdir(path: PAnsiChar): Int32; cdecl; external 'c' name 'chdir';
function getenv(name: PAnsiChar): PAnsiChar; cdecl; external 'c' name 'getenv';
function setenv(name: PAnsiChar; value: PAnsiChar; overwrite: Int32): Int32; cdecl; external 'c' name 'setenv';
function unsetenv(name: PAnsiChar): Int32; cdecl; external 'c' name 'unsetenv';
function putenv(str: PAnsiChar): Int32; cdecl; external 'c' name 'putenv';
function fork: pid_t; cdecl; external 'c' name 'fork';
function execve(path: PAnsiChar; argv: Pointer; envp: Pointer): Int32; cdecl; external 'c' name 'execve';
function waitpid(pid: pid_t; stat_loc: PInt32; options: Int32): pid_t; cdecl; external 'c' name 'waitpid';
procedure posix_exit(status: Int32); cdecl; external 'c' name '_exit';
function kill(pid: pid_t; sig: Int32): Int32; cdecl; external 'c' name 'kill';

function pthread_create(thread: Pointer; attr: Pointer; start_routine: TPThreadStartRoutine; arg: Pointer): Int32; cdecl; external 'pthread' name 'pthread_create';
function pthread_join(thread: pthread_t; retval: Pointer): Int32; cdecl; external 'pthread' name 'pthread_join';
function pthread_detach(thread: pthread_t): Int32; cdecl; external 'pthread' name 'pthread_detach';
function pthread_self: pthread_t; cdecl; external 'pthread' name 'pthread_self';

function pthread_key_create(key: Pointer; destructor_proc: Pointer): Int32; cdecl; external 'pthread' name 'pthread_key_create';
function pthread_key_delete(key: pthread_key_t): Int32; cdecl; external 'pthread' name 'pthread_key_delete';
function pthread_setspecific(key: pthread_key_t; value: Pointer): Int32; cdecl; external 'pthread' name 'pthread_setspecific';
function pthread_getspecific(key: pthread_key_t): Pointer; cdecl; external 'pthread' name 'pthread_getspecific';

function pthread_mutexattr_init(attr: Pointer): Int32; cdecl; external 'pthread' name 'pthread_mutexattr_init';
function pthread_mutexattr_settype(attr: Pointer; kind: Int32): Int32; cdecl; external 'pthread' name 'pthread_mutexattr_settype';
function pthread_mutexattr_destroy(attr: Pointer): Int32; cdecl; external 'pthread' name 'pthread_mutexattr_destroy';
function pthread_mutex_init(mutex: Pointer; attr: Pointer): Int32; cdecl; external 'pthread' name 'pthread_mutex_init';
function pthread_mutex_destroy(mutex: Pointer): Int32; cdecl; external 'pthread' name 'pthread_mutex_destroy';
function pthread_mutex_lock(mutex: Pointer): Int32; cdecl; external 'pthread' name 'pthread_mutex_lock';
function pthread_mutex_trylock(mutex: Pointer): Int32; cdecl; external 'pthread' name 'pthread_mutex_trylock';
{$IF defined(NEXTPAS_LINUX) or defined(NEXTPAS_ANDROID) or defined(NEXTPAS_FREEBSD)}
function pthread_mutex_timedlock(mutex: Pointer; abstime: PTimeSpec): Int32; cdecl; external 'pthread' name 'pthread_mutex_timedlock';
{$ENDIF}
function pthread_mutex_unlock(mutex: Pointer): Int32; cdecl; external 'pthread' name 'pthread_mutex_unlock';

function pthread_rwlock_init(rwlock: Pointer; attr: Pointer): Int32; cdecl; external 'pthread' name 'pthread_rwlock_init';
function pthread_rwlock_destroy(rwlock: Pointer): Int32; cdecl; external 'pthread' name 'pthread_rwlock_destroy';
function pthread_rwlock_rdlock(rwlock: Pointer): Int32; cdecl; external 'pthread' name 'pthread_rwlock_rdlock';
function pthread_rwlock_tryrdlock(rwlock: Pointer): Int32; cdecl; external 'pthread' name 'pthread_rwlock_tryrdlock';
function pthread_rwlock_wrlock(rwlock: Pointer): Int32; cdecl; external 'pthread' name 'pthread_rwlock_wrlock';
function pthread_rwlock_trywrlock(rwlock: Pointer): Int32; cdecl; external 'pthread' name 'pthread_rwlock_trywrlock';
function pthread_rwlock_unlock(rwlock: Pointer): Int32; cdecl; external 'pthread' name 'pthread_rwlock_unlock';

function pthread_condattr_init(attr: Pointer): Int32; cdecl; external 'pthread' name 'pthread_condattr_init';
function pthread_condattr_destroy(attr: Pointer): Int32; cdecl; external 'pthread' name 'pthread_condattr_destroy';
function pthread_cond_init(cond: Pointer; attr: Pointer): Int32; cdecl; external 'pthread' name 'pthread_cond_init';
function pthread_cond_destroy(cond: Pointer): Int32; cdecl; external 'pthread' name 'pthread_cond_destroy';
function pthread_cond_wait(cond: Pointer; mutex: Pointer): Int32; cdecl; external 'pthread' name 'pthread_cond_wait';
function pthread_cond_timedwait(cond: Pointer; mutex: Pointer; abstime: PTimeSpec): Int32; cdecl; external 'pthread' name 'pthread_cond_timedwait';
function pthread_cond_signal(cond: Pointer): Int32; cdecl; external 'pthread' name 'pthread_cond_signal';
function pthread_cond_broadcast(cond: Pointer): Int32; cdecl; external 'pthread' name 'pthread_cond_broadcast';

function pipe(pipefd: PInt32): cint; cdecl; external 'c' name 'pipe';
function dup(oldfd: cint): cint; cdecl; external 'c' name 'dup';
function dup2(oldfd: cint; newfd: cint): cint; cdecl; external 'c' name 'dup2';
function readlink(path: PAnsiChar; buf: PAnsiChar; bufsiz: size_t): ssize_t; cdecl; external 'c' name 'readlink';
function symlink(target: PAnsiChar; linkpath: PAnsiChar): cint; cdecl; external 'c' name 'symlink';
function link(oldpath: PAnsiChar; newpath: PAnsiChar): cint; cdecl; external 'c' name 'link';
function chmod(path: PAnsiChar; mode: mode_t): cint; cdecl; external 'c' name 'chmod';
function fchmod(fd: cint; mode: mode_t): cint; cdecl; external 'c' name 'fchmod';
function chown(path: PAnsiChar; owner: uid_t; group: gid_t): cint; cdecl; external 'c' name 'chown';
function fchown(fd: cint; owner: uid_t; group: gid_t): cint; cdecl; external 'c' name 'fchown';
function lchown(path: PAnsiChar; owner: uid_t; group: gid_t): cint; cdecl; external 'c' name 'lchown';
function getuid: uid_t; cdecl; external 'c' name 'getuid';
function geteuid: uid_t; cdecl; external 'c' name 'geteuid';
function getgid: gid_t; cdecl; external 'c' name 'getgid';
function getegid: gid_t; cdecl; external 'c' name 'getegid';
function setuid(uid: uid_t): cint; cdecl; external 'c' name 'setuid';
function setgid(gid: gid_t): cint; cdecl; external 'c' name 'setgid';
function umask(mask: mode_t): mode_t; cdecl; external 'c' name 'umask';
function poll(fds: Pointer; nfds: cuint; timeout: cint): cint; cdecl; external 'c' name 'poll';
function socket(domain: cint; xtype: cint; protocol: cint): cint; cdecl; external 'c' name 'socket';
function bind(sockfd: cint; addr: Pointer; addrlen: socklen_t): cint; cdecl; external 'c' name 'bind';
function listen(sockfd: cint; backlog: cint): cint; cdecl; external 'c' name 'listen';
function accept(sockfd: cint; addr: Pointer; addrlen: Pointer): cint; cdecl; external 'c' name 'accept';
function connect(sockfd: cint; addr: Pointer; addrlen: socklen_t): cint; cdecl; external 'c' name 'connect';
function send(sockfd: cint; buf: Pointer; len: size_t; flags: cint): ssize_t; cdecl; external 'c' name 'send';
function recv(sockfd: cint; buf: Pointer; len: size_t; flags: cint): ssize_t; cdecl; external 'c' name 'recv';
function sendto(sockfd: cint; buf: Pointer; len: size_t; flags: cint; dest_addr: Pointer; addrlen: socklen_t): ssize_t; cdecl; external 'c' name 'sendto';
function recvfrom(sockfd: cint; buf: Pointer; len: size_t; flags: cint; src_addr: Pointer; addrlen: Pointer): ssize_t; cdecl; external 'c' name 'recvfrom';
function shutdown(sockfd: cint; how: cint): cint; cdecl; external 'c' name 'shutdown';
function getsockname(sockfd: cint; addr: Pointer; addrlen: Pointer): cint; cdecl; external 'c' name 'getsockname';
function getpeername(sockfd: cint; addr: Pointer; addrlen: Pointer): cint; cdecl; external 'c' name 'getpeername';
function getsockopt(sockfd: cint; level: cint; optname: cint; optval: Pointer; optlen: Pointer): cint; cdecl; external 'c' name 'getsockopt';
function setsockopt(sockfd: cint; level: cint; optname: cint; optval: Pointer; optlen: socklen_t): cint; cdecl; external 'c' name 'setsockopt';
function socketpair(domain: cint; xtype: cint; protocol: cint; sv: PInt32): cint; cdecl; external 'c' name 'socketpair';
function getaddrinfo(node: PAnsiChar; service: PAnsiChar; hints: PAddrInfo; res: PPAddrInfo): cint; cdecl; external 'c' name 'getaddrinfo';
procedure freeaddrinfo(res: PAddrInfo); cdecl; external 'c' name 'freeaddrinfo';
function getnameinfo(sa: Pointer; salen: socklen_t; host: PAnsiChar; hostlen: size_t; serv: PAnsiChar; servlen: size_t; flags: cint): cint; cdecl; external 'c' name 'getnameinfo';
function readv(fd: cint; iov: piovec; iovcnt: cint): ssize_t; cdecl; external 'c' name 'readv';
function writev(fd: cint; iov: piovec; iovcnt: cint): ssize_t; cdecl; external 'c' name 'writev';
function sendmsg(sockfd: cint; msg: Pointer; flags: cint): ssize_t; cdecl; external 'c' name 'sendmsg';
function recvmsg(sockfd: cint; msg: Pointer; flags: cint): ssize_t; cdecl; external 'c' name 'recvmsg';

implementation

end.
