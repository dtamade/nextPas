unit nextpas.core.platform.darwin.ffi;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.darwin.base,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi;

function mach_absolute_time: UInt64; cdecl; external 'c' name 'mach_absolute_time';
function mach_timebase_info(out info: mach_timebase_info_data_t): Int32; cdecl; external 'c' name 'mach_timebase_info';
function pthread_threadid_np(thread: Pointer; thread_id: PUInt64): Int32; cdecl; external 'pthread' name 'pthread_threadid_np';
function __error: PInt32; cdecl; external 'c' name '__error';
function sigaction(
  const ASignal: Int32;
  ANewAction: PPlatformDarwinSigAction;
  AOldAction: PPlatformDarwinSigAction): Int32; cdecl; external 'c' name 'sigaction';
function sigprocmask(
  const AHow: Int32;
  ANewSet: PPlatformDarwinSignalSet;
  AOldSet: PPlatformDarwinSignalSet): Int32; cdecl; external 'c' name 'sigprocmask';
function pthread_sigmask(
  const AHow: Int32;
  ANewSet: PPlatformDarwinSignalSet;
  AOldSet: PPlatformDarwinSignalSet): Int32; cdecl; external 'c' name 'pthread_sigmask';
function stat(
  const APath: PAnsiChar;
  var AStat: TPlatformDarwinStat): Int32; cdecl; external 'c' name 'stat$INODE64';
function lstat(
  const APath: PAnsiChar;
  var AStat: TPlatformDarwinStat): Int32; cdecl; external 'c' name 'lstat$INODE64';
function fstat(
  const AFileDescriptor: Int32;
  var AStat: TPlatformDarwinStat): Int32; cdecl; external 'c' name 'fstat$INODE64';
function dlopen(Name: PAnsiChar; Flags: Int32): Pointer; cdecl; external 'c' name 'dlopen';
function dlsym(Lib: Pointer; Name: PAnsiChar): Pointer; cdecl; external 'c' name 'dlsym';
function dlclose(Lib: Pointer): Int32; cdecl; external 'c' name 'dlclose';
function dlerror: PAnsiChar; cdecl; external 'c' name 'dlerror';
function kqueue: Int32; cdecl; external 'c' name 'kqueue';
function kevent(kq: Int32; changelist: PKEvent; nchanges: Int32; eventlist: PKEvent; nevents: Int32; timeout: Pointer): Int32; cdecl; external 'c' name 'kevent';
function pipe(pipefd: Pointer): Int32; cdecl; external 'c' name 'pipe';
function dup2(oldfd: Int32; newfd: Int32): Int32; cdecl; external 'c' name 'dup2';
function readlink(path: PAnsiChar; buf: PAnsiChar; bufsiz: PtrUInt): PtrInt; cdecl; external 'c' name 'readlink';
function symlink(target: PAnsiChar; linkpath: PAnsiChar): Int32; cdecl; external 'c' name 'symlink';
function chmod(path: PAnsiChar; mode: UInt32): Int32; cdecl; external 'c' name 'chmod';
function chown(path: PAnsiChar; owner: UInt32; group: UInt32): Int32; cdecl; external 'c' name 'chown';
function getuid: UInt32; cdecl; external 'c' name 'getuid';
function geteuid: UInt32; cdecl; external 'c' name 'geteuid';
function getgid: UInt32; cdecl; external 'c' name 'getgid';
function getegid: UInt32; cdecl; external 'c' name 'getegid';
function poll(fds: Pointer; nfds: UInt32; timeout: Int32): Int32; cdecl; external 'c' name 'poll';
function socket(domain: Int32; xtype: Int32; protocol: Int32): Int32; cdecl; external 'c' name 'socket';
function bind(sockfd: Int32; addr: Pointer; addrlen: UInt32): Int32; cdecl; external 'c' name 'bind';
function listen(sockfd: Int32; backlog: Int32): Int32; cdecl; external 'c' name 'listen';
function accept(sockfd: Int32; addr: Pointer; addrlen: Pointer): Int32; cdecl; external 'c' name 'accept';
function connect(sockfd: Int32; addr: Pointer; addrlen: UInt32): Int32; cdecl; external 'c' name 'connect';
function send(sockfd: Int32; buf: Pointer; len: PtrUInt; flags: Int32): PtrInt; cdecl; external 'c' name 'send';
function recv(sockfd: Int32; buf: Pointer; len: PtrUInt; flags: Int32): PtrInt; cdecl; external 'c' name 'recv';
function shutdown(sockfd: Int32; how: Int32): Int32; cdecl; external 'c' name 'shutdown';
function getaddrinfo(node: PAnsiChar; service: PAnsiChar; hints: Pointer; res: Pointer): Int32; cdecl; external 'c' name 'getaddrinfo';
procedure freeaddrinfo(res: Pointer); cdecl; external 'c' name 'freeaddrinfo';
function getnameinfo(sa: Pointer; salen: UInt32; host: PAnsiChar; hostlen: PtrUInt; serv: PAnsiChar; servlen: PtrUInt; flags: Int32): Int32; cdecl; external 'c' name 'getnameinfo';

implementation

end.
