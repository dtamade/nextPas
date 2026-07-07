unit nextpas.core.platform.freebsd.ffi;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.freebsd.base,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi;

{ Errno }
function __error: PInt32; cdecl; external 'c' name '__error';

{ Thread ID }
function pthread_getthreadid_np: Int32; cdecl; external 'pthread' name 'pthread_getthreadid_np';

{ Signal handling }
function sigaction(
  const ASignal: Int32;
  ANewAction: PPlatformFreeBSDSigAction;
  AOldAction: PPlatformFreeBSDSigAction): Int32; cdecl; external 'c' name 'sigaction';
function sigprocmask(
  const AHow: Int32;
  ANewSet: PPlatformFreeBSDSignalSet;
  AOldSet: PPlatformFreeBSDSignalSet): Int32; cdecl; external 'c' name 'sigprocmask';
function sigpending(
  ASet: PPlatformFreeBSDSignalSet): Int32; cdecl; external 'c' name 'sigpending';
function sigwait(
  ASet: PPlatformFreeBSDSignalSet;
  ASig: PInt32): Int32; cdecl; external 'c' name 'sigwait';
function pthread_sigmask(
  const AHow: Int32;
  ANewSet: PPlatformFreeBSDSignalSet;
  AOldSet: PPlatformFreeBSDSignalSet): Int32; cdecl; external 'pthread' name 'pthread_sigmask';

{ File status }
function stat(
  const APath: PAnsiChar;
  var AStat: TPlatformFreeBSDStat): Int32; cdecl; external 'c' name 'stat';
function lstat(
  const APath: PAnsiChar;
  var AStat: TPlatformFreeBSDStat): Int32; cdecl; external 'c' name 'lstat';
function fstat(
  const AFileDescriptor: Int32;
  var AStat: TPlatformFreeBSDStat): Int32; cdecl; external 'c' name 'fstat';

{ Condition variable clock }
function pthread_condattr_setclock(attr: Pointer; clk_id: Int32): Int32; cdecl; external 'pthread' name 'pthread_condattr_setclock';

{ Dynamic loading }
function dlopen(Name: PAnsiChar; Flags: Int32): Pointer; cdecl; external 'c' name 'dlopen';
function dlsym(Lib: Pointer; Name: PAnsiChar): Pointer; cdecl; external 'c' name 'dlsym';
function dlclose(Lib: Pointer): Int32; cdecl; external 'c' name 'dlclose';
function dlerror: PAnsiChar; cdecl; external 'c' name 'dlerror';

{ kqueue event notification }
function kqueue: Int32; cdecl; external 'c' name 'kqueue';
function kevent(kq: Int32; changelist: PKEvent; nchanges: Int32; eventlist: PKEvent; nevents: Int32; timeout: Pointer): Int32; cdecl; external 'c' name 'kevent';

{ File descriptors }
function pipe(pipefd: Pointer): Int32; cdecl; external 'c' name 'pipe';
function dup2(oldfd: Int32; newfd: Int32): Int32; cdecl; external 'c' name 'dup2';

{ Links and permissions }
function readlink(path: PAnsiChar; buf: PAnsiChar; bufsiz: PtrUInt): PtrInt; cdecl; external 'c' name 'readlink';
function symlink(target: PAnsiChar; linkpath: PAnsiChar): Int32; cdecl; external 'c' name 'symlink';
function chmod(path: PAnsiChar; mode: UInt32): Int32; cdecl; external 'c' name 'chmod';
function chown(path: PAnsiChar; owner: UInt32; group: UInt32): Int32; cdecl; external 'c' name 'chown';

{ User/group }
function getuid: UInt32; cdecl; external 'c' name 'getuid';
function geteuid: UInt32; cdecl; external 'c' name 'geteuid';
function getgid: UInt32; cdecl; external 'c' name 'getgid';
function getegid: UInt32; cdecl; external 'c' name 'getegid';

{ Polling }
function poll(fds: Pointer; nfds: UInt32; timeout: Int32): Int32; cdecl; external 'c' name 'poll';

{ Socket operations }
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
