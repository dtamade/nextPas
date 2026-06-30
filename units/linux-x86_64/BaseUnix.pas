unit BaseUnix;

{$mode objfpc}{$H+}

interface

uses ctypes;

const
  F_OK = 0;
  R_OK = 4;
  W_OK = 2;
  X_OK = 1;
  O_RDONLY = 0;
  O_WRONLY = 1;
  O_RDWR = 2;
  O_CREAT = 64;
  O_TRUNC = 512;
  O_APPEND = 1024;
  O_NONBLOCK = 2048;
  O_CLOEXEC = 524288;
  SEEK_SET = 0;
  SEEK_CUR = 1;
  SEEK_END = 2;
  SIG_BLOCK = 0;
  SIG_UNBLOCK = 1;
  SIG_SETMASK = 2;
  EINTR = 4;
  EAGAIN = 11;
  EINPROGRESS = 115;
  POLLIN = 1;
  POLLOUT = 4;
  POLLERR = 8;
  POLLHUP = 16;
  POLLNVAL = 32;
  EPOLLIN = 1;
  EPOLLOUT = 4;
  EPOLLERR = 8;
  EPOLLHUP = 16;
  EPOLLET = Integer($80000000);
  EPOLL_CTL_ADD = 1;
  EPOLL_CTL_DEL = 2;
  EPOLL_CTL_MOD = 3;
  CLOCK_MONOTONIC = 1;
  CLOCK_REALTIME = 0;

type
  TPollFd = record
    fd: cint;
    events: cshort;
    revents: cshort;
  end;
  PPollFd = ^TPollFd;
  TEpollEvent = packed record
    events: LongWord;
    data: record
      case Integer of
        0: (ptr: Pointer);
        1: (fd: cint);
        2: (u32: LongWord);
        3: (u64: QWord);
    end;
  end;
  PEpollEvent = ^TEpollEvent;
  pid_t = cint;
  off_t = Int64;
  size_t = SizeUInt;
  ssize_t = SizeInt;
  TTimeSpec = record
    tv_sec: clong;
    tv_nsec: clong;
  end;
  PTimeSpec = ^TTimeSpec;

function fpOpen(const path: string; flags: cint): cint;
function fpOpen(const path: string; flags: cint; mode: cint): cint;
function fpClose(fd: cint): cint;
function fpRead(fd: cint; buf: Pointer; count: size_t): ssize_t;
function fpWrite(fd: cint; buf: Pointer; count: size_t): ssize_t;
function fpLseek(fd: cint; offset: off_t; whence: cint): off_t;
function fpPoll(fds: PPollFd; nfds: cuint; timeout: cint): cint;
function fpEpollCreate(size: cint): cint;
function fpEpollCreate1(flags: cint): cint;
function fpEpollCtl(epfd: cint; op: cint; fd: cint; event: PEpollEvent): cint;
function fpEpollWait(epfd: cint; events: PEpollEvent; maxevents: cint; timeout: cint): cint;
function fpSocket(domain: cint; xtype: cint; protocol: cint): cint;
function fpBind(fd: cint; addr: Pointer; addrlen: cuint): cint;
function fpListen(fd: cint; backlog: cint): cint;
function fpAccept(fd: cint; addr: Pointer; addrlen: pcuint): cint;
function fpConnect(fd: cint; addr: Pointer; addrlen: cuint): cint;
function fpShutdown(fd: cint; how: cint): cint;
function fpGetErrno: cint;
function fpKill(pid: pid_t; sig: cint): cint;
function fpSigProcMask(how: cint; nset: Pointer; oset: Pointer): cint;
function fpClockGettime(clk_id: cint; tp: PTimeSpec): cint;

implementation

function fpOpen(const path: string; flags: cint): cint;
begin Result := -1; end;

function fpOpen(const path: string; flags: cint; mode: cint): cint;
begin Result := -1; end;

function fpClose(fd: cint): cint;
begin Result := -1; end;

function fpRead(fd: cint; buf: Pointer; count: size_t): ssize_t;
begin Result := -1; end;

function fpWrite(fd: cint; buf: Pointer; count: size_t): ssize_t;
begin Result := -1; end;

function fpLseek(fd: cint; offset: off_t; whence: cint): off_t;
begin Result := -1; end;

function fpPoll(fds: PPollFd; nfds: cuint; timeout: cint): cint;
begin Result := -1; end;

function fpEpollCreate(size: cint): cint;
begin Result := -1; end;

function fpEpollCreate1(flags: cint): cint;
begin Result := -1; end;

function fpEpollCtl(epfd: cint; op: cint; fd: cint; event: PEpollEvent): cint;
begin Result := -1; end;

function fpEpollWait(epfd: cint; events: PEpollEvent; maxevents: cint; timeout: cint): cint;
begin Result := -1; end;

function fpSocket(domain: cint; xtype: cint; protocol: cint): cint;
begin Result := -1; end;

function fpBind(fd: cint; addr: Pointer; addrlen: cuint): cint;
begin Result := -1; end;

function fpListen(fd: cint; backlog: cint): cint;
begin Result := -1; end;

function fpAccept(fd: cint; addr: Pointer; addrlen: pcuint): cint;
begin Result := -1; end;

function fpConnect(fd: cint; addr: Pointer; addrlen: cuint): cint;
begin Result := -1; end;

function fpShutdown(fd: cint; how: cint): cint;
begin Result := -1; end;

function fpGetErrno: cint;
begin Result := 0; end;

function fpKill(pid: pid_t; sig: cint): cint;
begin Result := -1; end;

function fpSigProcMask(how: cint; nset: Pointer; oset: Pointer): cint;
begin Result := -1; end;

function fpClockGettime(clk_id: cint; tp: PTimeSpec): cint;
begin Result := -1; end;

end.
