unit nextpas.core.platform.linux.modern;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.posix.base;

{ Modern Linux syscalls (kernel 5.x+) }

const
  // io_uring setup flags
  IORING_SETUP_IOPOLL     = 1 shl 0;
  IORING_SETUP_SQPOLL     = 1 shl 1;
  IORING_SETUP_SQ_AFF     = 1 shl 2;
  IORING_SETUP_CQSIZE     = 1 shl 3;
  IORING_SETUP_CLAMP      = 1 shl 4;
  IORING_SETUP_ATTACH_WQ  = 1 shl 5;
  IORING_SETUP_R_DISABLED = 1 shl 6;
  IORING_SETUP_SUBMIT_ALL = 1 shl 7;
  IORING_SETUP_COOP_TASKRUN = 1 shl 8;
  IORING_SETUP_TASKRUN_FLAG = 1 shl 9;
  IORING_SETUP_SQE128     = 1 shl 10;
  IORING_SETUP_CQE32      = 1 shl 11;
  IORING_SETUP_SINGLE_ISSUER = 1 shl 12;
  IORING_SETUP_DEFER_TASKRUN = 1 shl 13;

  // io_uring enter flags
  IORING_ENTER_GETEVENTS  = 1 shl 0;
  IORING_ENTER_SQ_WAKEUP  = 1 shl 1;
  IORING_ENTER_SQ_WAIT    = 1 shl 2;
  IORING_ENTER_EXT_ARG    = 1 shl 3;

  // io_uring register opcodes
  IORING_REGISTER_BUFFERS = 0;
  IORING_UNREGISTER_BUFFERS = 1;
  IORING_REGISTER_FILES   = 2;
  IORING_UNREGISTER_FILES = 3;
  IORING_REGISTER_EVENTFD = 4;
  IORING_UNREGISTER_EVENTFD = 5;
  IORING_REGISTER_FILES_UPDATE = 6;
  IORING_REGISTER_EVENTFD_ASYNC = 7;
  IORING_REGISTER_PROBE   = 8;

  // io_uring SQE opcodes
  IORING_OP_NOP       = 0;
  IORING_OP_READV     = 1;
  IORING_OP_WRITEV    = 2;
  IORING_OP_FSYNC     = 3;
  IORING_OP_READ_FIXED = 4;
  IORING_OP_WRITE_FIXED = 5;
  IORING_OP_POLL_ADD  = 6;
  IORING_OP_POLL_REMOVE = 7;
  IORING_OP_SYNC_FILE_RANGE = 8;
  IORING_OP_SENDMSG   = 9;
  IORING_OP_RECVMSG   = 10;
  IORING_OP_TIMEOUT   = 11;
  IORING_OP_TIMEOUT_REMOVE = 12;
  IORING_OP_ACCEPT    = 13;
  IORING_OP_ASYNC_CANCEL = 14;
  IORING_OP_LINK_TIMEOUT = 15;
  IORING_OP_CONNECT   = 16;
  IORING_OP_OPENAT    = 18;
  IORING_OP_CLOSE     = 19;
  IORING_OP_READ      = 22;
  IORING_OP_WRITE     = 23;
  IORING_OP_SEND      = 26;
  IORING_OP_RECV      = 27;
  IORING_OP_OPENAT2   = 28;
  IORING_OP_SPLICE    = 30;
  IORING_OP_SHUTDOWN  = 34;
  IORING_OP_RENAMEAT  = 35;
  IORING_OP_UNLINKAT  = 36;
  IORING_OP_MKDIRAT   = 37;
  IORING_OP_SYMLINKAT = 38;
  IORING_OP_LINKAT    = 39;

  // memfd_create flags
  MFD_CLOEXEC       = 1;
  MFD_ALLOW_SEALING = 2;
  MFD_HUGETLB       = 4;

  // pidfd_open flags
  PIDFD_NONBLOCK = $800;

  // close_range flags
  CLOSE_RANGE_UNSHARE = 1 shl 1;
  CLOSE_RANGE_CLOEXEC = 1 shl 2;

  // Linux syscall numbers (x86_64)
  {$IFDEF CPUX86_64}
  SYS_io_uring_setup    = 425;
  SYS_io_uring_enter    = 426;
  SYS_io_uring_register = 427;
  SYS_memfd_create      = 319;
  SYS_pidfd_open        = 434;
  SYS_clone3            = 435;
  SYS_close_range       = 436;
  SYS_openat2           = 437;
  SYS_pidfd_getfd       = 438;
  SYS_fanotify_init     = 300;
  SYS_fanotify_mark     = 301;
  {$ENDIF}
  {$IFDEF CPUAARCH64}
  SYS_io_uring_setup    = 425;
  SYS_io_uring_enter    = 426;
  SYS_io_uring_register = 427;
  SYS_memfd_create      = 279;
  SYS_pidfd_open        = 434;
  SYS_clone3            = 435;
  SYS_close_range       = 436;
  SYS_openat2           = 437;
  SYS_pidfd_getfd       = 438;
  SYS_fanotify_init     = 262;
  SYS_fanotify_mark     = 263;
  {$ENDIF}

type
  TIoUringSqe = record
    opcode: Byte;
    flags: Byte;
    ioprio: UInt16;
    fd: Int32;
    off: UInt64;
    addr: UInt64;
    len: UInt32;
    case Byte of
      0: (rw_flags: Int32);
      1: (fsync_flags: UInt32);
      2: (poll_events: UInt16);
      3: (sync_range_flags: UInt32);
      4: (msg_flags: UInt32);
      5: (timeout_flags: UInt32);
      6: (accept_flags: UInt32);
      7: (cancel_flags: UInt32);
      8: (open_flags: UInt32);
      9: (statx_flags: UInt32);
      10: (splice_flags: UInt32);
  end;
  PIoUringSqe = ^TIoUringSqe;

  TIoUringCqe = record
    user_data: UInt64;
    res: Int32;
    flags: UInt32;
  end;
  PIoUringCqe = ^TIoUringCqe;

  TIoSqringOffsets = record
    head: UInt32;
    tail: UInt32;
    ring_mask: UInt32;
    ring_entries: UInt32;
    flags: UInt32;
    dropped: UInt32;
    array_off: UInt32;
    resv1: UInt32;
    user_addr: UInt64;
  end;

  TIoCqringOffsets = record
    head: UInt32;
    tail: UInt32;
    ring_mask: UInt32;
    ring_entries: UInt32;
    overflow: UInt32;
    cqes: UInt32;
    flags: UInt32;
    resv1: UInt32;
    user_addr: UInt64;
  end;

  TIoUringParams = record
    sq_entries: UInt32;
    cq_entries: UInt32;
    flags: UInt32;
    sq_thread_cpu: UInt32;
    sq_thread_idle: UInt32;
    features: UInt32;
    wq_fd: UInt32;
    resv: array[0..2] of UInt32;
    sq_off: TIoSqringOffsets;
    cq_off: TIoCqringOffsets;
  end;
  PIoUringParams = ^TIoUringParams;

  TOpenHow = record
    flags: UInt64;
    mode: UInt64;
    resolve: UInt64;
  end;
  POpenHow = ^TOpenHow;

// io_uring syscalls (via libc syscall wrapper)
function io_uring_setup(entries: cuint; params: PIoUringParams): cint;
function io_uring_enter(fd: cint; to_submit: cuint; min_complete: cuint;
  flags: cuint; sig: Pointer): cint;
function io_uring_register(fd: cint; opcode: cuint; arg: Pointer;
  nr_args: cuint): cint;

// Memory
function memfd_create(name: PAnsiChar; flags: cuint): cint;

// Process
function pidfd_open(pid: pid_t; flags: cuint): cint;
function close_range(first: cuint; last: cuint; flags: cuint): cint;

// File
function openat2(dirfd: cint; pathname: PAnsiChar; how: POpenHow;
  size: size_t): cint;

implementation

function syscall_raw(nr: PtrInt; a1, a2, a3, a4, a5, a6: PtrUInt): PtrInt;
  cdecl; external 'c' name 'syscall';

function io_uring_setup(entries: cuint; params: PIoUringParams): cint;
begin
  Result := cint(syscall_raw(SYS_io_uring_setup, PtrUInt(entries),
    PtrUInt(params), 0, 0, 0, 0));
end;

function io_uring_enter(fd: cint; to_submit: cuint; min_complete: cuint;
  flags: cuint; sig: Pointer): cint;
begin
  Result := cint(syscall_raw(SYS_io_uring_enter, PtrUInt(fd),
    PtrUInt(to_submit), PtrUInt(min_complete), PtrUInt(flags),
    PtrUInt(sig), 0));
end;

function io_uring_register(fd: cint; opcode: cuint; arg: Pointer;
  nr_args: cuint): cint;
begin
  Result := cint(syscall_raw(SYS_io_uring_register, PtrUInt(fd),
    PtrUInt(opcode), PtrUInt(arg), PtrUInt(nr_args), 0, 0));
end;

function memfd_create(name: PAnsiChar; flags: cuint): cint;
begin
  Result := cint(syscall_raw(SYS_memfd_create, PtrUInt(name),
    PtrUInt(flags), 0, 0, 0, 0));
end;

function pidfd_open(pid: pid_t; flags: cuint): cint;
begin
  Result := cint(syscall_raw(SYS_pidfd_open, PtrUInt(pid),
    PtrUInt(flags), 0, 0, 0, 0));
end;

function close_range(first: cuint; last: cuint; flags: cuint): cint;
begin
  Result := cint(syscall_raw(SYS_close_range, PtrUInt(first),
    PtrUInt(last), PtrUInt(flags), 0, 0, 0));
end;

function openat2(dirfd: cint; pathname: PAnsiChar; how: POpenHow;
  size: size_t): cint;
begin
  Result := cint(syscall_raw(SYS_openat2, PtrUInt(dirfd),
    PtrUInt(pathname), PtrUInt(how), PtrUInt(size), 0, 0));
end;

end.
