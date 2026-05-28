{ Linux sysinfo, clone, extended futex, splice, statx - ported from FPC rtl/linux/linux.pp }

type
  clockid_t = cint;

  TSysInfo = record
    uptime: clong;
    loads: array[0..2] of culong;
    totalram: culong;
    freeram: culong;
    sharedram: culong;
    bufferram: culong;
    totalswap: culong;
    freeswap: culong;
    procs: cushort;
    pad: cushort;
    totalhigh: culong;
    freehigh: culong;
    mem_unit: cuint;
{$IF not defined(NEXTPAS_X86_64) and not defined(NEXTPAS_AARCH64)}
    _f: array[0..19 - 2*SizeOf(clong) - SizeOf(cint)] of AnsiChar;
{$ENDIF}
  end;
  PSysInfo = ^TSysInfo;

const
  CLOCK_PROCESS_CPUTIME_ID = cint(2);
  CLOCK_THREAD_CPUTIME_ID  = cint(3);
  CLOCK_SGI_CYCLE          = cint(10);
  MAX_CLOCKS               = 16;

  CSIGNAL              = $000000ff;
  CLONE_VM             = $00000100;
  CLONE_FS             = $00000200;
  CLONE_FILES          = $00000400;
  CLONE_SIGHAND        = $00000800;
  CLONE_PID            = $00001000;
  CLONE_PTRACE         = $00002000;
  CLONE_VFORK          = $00004000;
  CLONE_PARENT         = $00008000;
  CLONE_THREAD         = $00010000;
  CLONE_NEWNS          = $00020000;
  CLONE_SYSVSEM        = $00040000;
  CLONE_SETTLS         = $00080000;
  CLONE_PARENT_SETTID  = $00100000;
  CLONE_CHILD_CLEARTID = $00200000;
  CLONE_DETACHED       = $00400000;
  CLONE_UNTRACED       = $00800000;
  CLONE_CHILD_SETTID   = $01000000;
  CLONE_STOPPED        = $02000000;
  CLONE_NEWCGROUP      = $02000000;
  CLONE_NEWUTS         = $04000000;
  CLONE_NEWIPC         = $08000000;
  CLONE_NEWUSER        = $10000000;
  CLONE_NEWPID         = $20000000;
  CLONE_NEWNET         = $40000000;
  CLONE_IO             = cuint32($80000000);

  FUTEX_OP_SET         = 0;
  FUTEX_OP_ADD         = 1;
  FUTEX_OP_OR          = 2;
  FUTEX_OP_ANDN        = 3;
  FUTEX_OP_XOR         = 4;
  FUTEX_OP_OPARG_SHIFT = 8;
  FUTEX_OP_CMP_EQ      = 0;
  FUTEX_OP_CMP_NE      = 1;
  FUTEX_OP_CMP_LT      = 2;
  FUTEX_OP_CMP_LE      = 3;
  FUTEX_OP_CMP_GT      = 4;
  FUTEX_OP_CMP_GE      = 5;

  SPLICE_F_MOVE     = 1;
  SPLICE_F_NONBLOCK = 2;
  SPLICE_F_MORE     = 4;
  SPLICE_F_GIFT     = 8;

  SYNC_FILE_RANGE_WAIT_BEFORE = 1;
  SYNC_FILE_RANGE_WRITE       = 2;
  SYNC_FILE_RANGE_WAIT_AFTER  = 4;

  STATX_TYPE          = $00000001;
  STATX_MODE          = $00000002;
  STATX_NLINK         = $00000004;
  STATX_UID           = $00000008;
  STATX_GID           = $00000010;
  STATX_ATIME         = $00000020;
  STATX_MTIME         = $00000040;
  STATX_CTIME         = $00000080;
  STATX_INO           = $00000100;
  STATX_SIZE          = $00000200;
  STATX_BLOCKS        = $00000400;
  STATX_BTIME         = $00000800;
  STATX_ALL           = $00000fff;
  STATX__RESERVED     = $80000000;

  STATX_ATTR_COMPRESSED = $00000004;
  STATX_ATTR_IMMUTABLE  = $00000010;
  STATX_ATTR_APPEND     = $00000020;
  STATX_ATTR_NODUMP     = $00000040;
  STATX_ATTR_ENCRYPTED  = $00000800;
  STATX_ATTR_AUTOMOUNT  = $00001000;
