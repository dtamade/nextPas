unit nextpas.core.platform.android.ffi;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.android.base,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi;

{ System calls }
function syscall(ANumber: PtrInt; A1: PtrUInt; A2: PtrUInt; A3: PtrUInt; A4: PtrUInt; A5: PtrUInt; A6: PtrUInt): PtrInt; cdecl; external 'c' name 'syscall';

{ Errno — Android uses __errno instead of __errno_location }
function __errno: PInt32; cdecl; external 'c' name '__errno';

{ Thread ID — Android has gettid in libc }
function gettid: Int32; cdecl; external 'c' name 'gettid';

{ Condition variable clock }
function pthread_condattr_setclock(attr: Pointer; clk_id: Int32): Int32; cdecl; external 'pthread' name 'pthread_condattr_setclock';

{ Dynamic loading — Android uses libdl }
function dlopen(Name: PAnsiChar; Flags: Int32): Pointer; cdecl; external 'dl' name 'dlopen';
function dlsym(Lib: Pointer; Name: PAnsiChar): Pointer; cdecl; external 'dl' name 'dlsym';
function dlclose(Lib: Pointer): Int32; cdecl; external 'dl' name 'dlclose';
function dlerror: PAnsiChar; cdecl; external 'dl' name 'dlerror';

{ epoll — Android supports epoll like Linux }
function epoll_create1(flags: cint): cint; cdecl; external 'c' name 'epoll_create1';
function epoll_ctl(epfd: cint; op: cint; fd: cint; event: Pointer): cint; cdecl; external 'c' name 'epoll_ctl';
function epoll_wait(epfd: cint; events: Pointer; maxevents: cint; timeout: cint): cint; cdecl; external 'c' name 'epoll_wait';

{ eventfd }
function eventfd(initval: cuint; flags: cint): cint; cdecl; external 'c' name 'eventfd';

{ inotify — Android supports inotify }
function inotify_init1(flags: cint): cint; cdecl; external 'c' name 'inotify_init1';
function inotify_add_watch(fd: cint; pathname: PAnsiChar; mask: cuint32): cint; cdecl; external 'c' name 'inotify_add_watch';
function inotify_rm_watch(fd: cint; wd: cint): cint; cdecl; external 'c' name 'inotify_rm_watch';

{ accept4 — Android supports accept4 }
function accept4(sockfd: cint; addr: Pointer; addrlen: Pointer; flags: cint): cint; cdecl; external 'c' name 'accept4';

{ getdents64 }
function getdents64(fd: cint; dirp: Pointer; count: size_t): ssize_t; cdecl; external 'c' name 'getdents64';

{ Filesystem statistics }
function statfs(path: PAnsiChar; buf: Pointer): cint; cdecl; external 'c' name 'statfs';
function fstatfs(fd: cint; buf: Pointer): cint; cdecl; external 'c' name 'fstatfs';

{ Resource limits }
function prlimit64(pid: pid_t; resource: cint; new_limit: Pointer; old_limit: Pointer): cint; cdecl; external 'c' name 'prlimit64';

{ Random — Android has getrandom since API 28 }
function getrandom(buf: Pointer; buflen: size_t; flags: cuint): ssize_t; cdecl; external 'c' name 'getrandom';

{ System information }
function sysinfo(info: Pointer): cint; cdecl; external 'c' name 'sysinfo';
function uname(buf: Pointer): cint; cdecl; external 'c' name 'uname';

{ sendfile }
function sendfile(out_fd: cint; in_fd: cint; offset: Pointer; count: size_t): ssize_t; cdecl; external 'c' name 'sendfile';

{ splice — Android supports splice }
function splice(fd_in: cint; off_in: Pointer; fd_out: cint; off_out: Pointer; len: size_t; flags: cuint): ssize_t; cdecl; external 'c' name 'splice';

{ prctl — Android uses prctl for thread/process control }
function prctl(option: cint; arg2: culong; arg3: culong; arg4: culong; arg5: culong): cint; cdecl; external 'c' name 'prctl';

{ Signal handling — Android uses sigaction like Linux }
function sigaction(sig: cint; act: Pointer; oact: Pointer): cint; cdecl; external 'c' name 'sigaction';
function sigprocmask(how: cint; nset: Pointer; oset: Pointer): cint; cdecl; external 'c' name 'sigprocmask';
function sigpending(sigset: Pointer): cint; cdecl; external 'c' name 'sigpending';
function sigwait(sigset: Pointer; sig: pcint): cint; cdecl; external 'c' name 'sigwait';

{ raise signal }
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
