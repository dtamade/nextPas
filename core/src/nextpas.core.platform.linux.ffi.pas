unit nextpas.core.platform.linux.ffi;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.linux.base,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi;

function syscall(ANumber: PtrInt; A1: PtrUInt; A2: PtrUInt; A3: PtrUInt; A4: PtrUInt; A5: PtrUInt; A6: PtrUInt): PtrInt; cdecl; external 'c' name 'syscall';
function gettid: Int32; cdecl; external 'c' name 'gettid';
function __errno_location: PInt32; cdecl; external 'c' name '__errno_location';
function __xstat(
  const AVersion: Int32;
  const AFileName: PAnsiChar;
  var AStat: TPlatformLinuxStat): Int32; cdecl; external 'c' name '__xstat';
function __lxstat(
  const AVersion: Int32;
  const AFileName: PAnsiChar;
  var AStat: TPlatformLinuxStat): Int32; cdecl; external 'c' name '__lxstat';
function __fxstat(
  const AVersion: Int32;
  const AFileDescriptor: Int32;
  var AStat: TPlatformLinuxStat): Int32; cdecl; external 'c' name '__fxstat';
function pthread_condattr_setclock(attr: Pointer; clk_id: Int32): Int32; cdecl; external 'pthread' name 'pthread_condattr_setclock';
function dlopen(Name: PAnsiChar; Flags: Int32): Pointer; cdecl; external 'dl' name 'dlopen';
function dlsym(Lib: Pointer; Name: PAnsiChar): Pointer; cdecl; external 'dl' name 'dlsym';
function dlclose(Lib: Pointer): Int32; cdecl; external 'dl' name 'dlclose';
function dlerror: PAnsiChar; cdecl; external 'dl' name 'dlerror';

function epoll_create1(flags: cint): cint; cdecl; external 'c' name 'epoll_create1';
function epoll_ctl(epfd: cint; op: cint; fd: cint; event: pepoll_event): cint; cdecl; external 'c' name 'epoll_ctl';
function epoll_wait(epfd: cint; events: pepoll_event; maxevents: cint; timeout: cint): cint; cdecl; external 'c' name 'epoll_wait';
function epoll_pwait(epfd: cint; events: pepoll_event; maxevents: cint; timeout: cint; sigmask: psigset_t): cint; cdecl; external 'c' name 'epoll_pwait';
function eventfd(initval: cuint; flags: cint): cint; cdecl; external 'c' name 'eventfd';
function timerfd_create(clockid: cint; flags: cint): cint; cdecl; external 'c' name 'timerfd_create';
function timerfd_settime(fd: cint; flags: cint; new_value: Pointer; old_value: Pointer): cint; cdecl; external 'c' name 'timerfd_settime';
function timerfd_gettime(fd: cint; curr_value: Pointer): cint; cdecl; external 'c' name 'timerfd_gettime';
function signalfd(fd: cint; mask: psigset_t; flags: cint): cint; cdecl; external 'c' name 'signalfd';
function inotify_init1(flags: cint): cint; cdecl; external 'c' name 'inotify_init1';
function inotify_add_watch(fd: cint; pathname: PAnsiChar; mask: cuint32): cint; cdecl; external 'c' name 'inotify_add_watch';
function inotify_rm_watch(fd: cint; wd: cint): cint; cdecl; external 'c' name 'inotify_rm_watch';
function pipe2(pipefd: PInt32; flags: cint): cint; cdecl; external 'c' name 'pipe2';
function dup3(oldfd: cint; newfd: cint; flags: cint): cint; cdecl; external 'c' name 'dup3';
function accept4(sockfd: cint; addr: Pointer; addrlen: Pointer; flags: cint): cint; cdecl; external 'c' name 'accept4';
function getdents64(fd: cint; dirp: Pointer; count: size_t): ssize_t; cdecl; external 'c' name 'getdents64';
function statfs(path: PAnsiChar; buf: PStatfs): cint; cdecl; external 'c' name 'statfs';
function fstatfs(fd: cint; buf: PStatfs): cint; cdecl; external 'c' name 'fstatfs';
function prlimit64(pid: pid_t; resource: cint; new_limit: PRLimit; old_limit: PRLimit): cint; cdecl; external 'c' name 'prlimit64';
function getrandom(buf: Pointer; buflen: size_t; flags: cuint): ssize_t; cdecl; external 'c' name 'getrandom';
function sysinfo(info: PSysInfo): cint; cdecl; external 'c' name 'sysinfo';
function uname(buf: PUtsName): cint; cdecl; external 'c' name 'uname';

implementation

end.
