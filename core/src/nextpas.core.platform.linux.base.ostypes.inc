{ Linux core OS types - ported from FPC rtl/linux/ostypes.inc + ptypes.inc }

const
  SYS_NMLN       = 65;
  PATH_MAX       = 4095;
  NAME_MAX       = 255;
  ARG_MAX        = 131072;

  FD_MAXFDSET    = 1024;
  BITSINWORD     = 8 * SizeOf(culong);
  wordsinfdset   = FD_MAXFDSET div BITSINWORD;

  POLLIN      = $0001;
  POLLPRI     = $0002;
  POLLOUT     = $0004;
  POLLERR     = $0008;
  POLLHUP     = $0010;
  POLLNVAL    = $0020;
  POLLRDNORM  = $0040;
  POLLRDBAND  = $0080;
  POLLWRNORM  = $0100;
  POLLWRBAND  = $0200;

  RLIMIT_CPU     = 0;
  RLIMIT_FSIZE   = 1;
  RLIMIT_DATA    = 2;
  RLIMIT_STACK   = 3;
  RLIMIT_CORE    = 4;
  RLIMIT_RSS     = 5;
  RLIMIT_NPROC   = 6;
  RLIMIT_NOFILE  = 7;
  RLIMIT_MEMLOCK = 8;
  RLIMIT_AS      = 9;
  RLIMIT_LOCKS   = 10;

  Prio_Process = 0;
  Prio_PGrp    = 1;
  Prio_User    = 2;

type
  pollfd = record
    fd: cint;
    events: cshort;
    revents: cshort;
  end;
  tpollfd = pollfd;
  ppollfd = ^pollfd;

  iovec = record
    iov_base: Pointer;
    iov_len: size_t;
  end;
  tiovec = iovec;
  piovec = ^tiovec;

  Dirent = record
    d_ino: ino64_t;
    d_off: off_t;
    d_reclen: cushort;
    d_type: cuchar;
    d_name: array[0..4095 - SizeOf(ino64_t) - SizeOf(off_t) - SizeOf(cushort) - SizeOf(cuchar)] of AnsiChar;
  end;
  TDirent = Dirent;
  pDirent = ^Dirent;

  UtsName = record
    Sysname: array[0..SYS_NMLN - 1] of AnsiChar;
    Nodename: array[0..SYS_NMLN - 1] of AnsiChar;
    Release: array[0..SYS_NMLN - 1] of AnsiChar;
    Version: array[0..SYS_NMLN - 1] of AnsiChar;
    Machine: array[0..SYS_NMLN - 1] of AnsiChar;
    Domain: array[0..SYS_NMLN - 1] of AnsiChar;
  end;
  TUtsName = UtsName;
  PUtsName = ^UtsName;

  timezone = record
    tz_minuteswest: cint;
    tz_dsttime: cint;
  end;
  ptimezone = ^timezone;
  TTimeZone = timezone;

  rlim_t = culonglong;
  PRLimit = ^TRLimit;
  TRLimit = record
    rlim_cur: rlim_t;
    rlim_max: rlim_t;
  end;

  TStatfs = record
    fstype: clong;
    bsize: clong;
    blocks: culong;
    bfree: culong;
    bavail: culong;
    files: culong;
    ffree: culong;
    fsid: array[0..1] of cint;
    namelen: clong;
    frsize: clong;
    flags: clong;
    spare: array[0..3] of clong;
  end;
  PStatfs = ^TStatfs;

  FLock = record
    l_type: cshort;
    l_whence: cshort;
    l_start: clong;
    l_len: clong;
    l_pid: pid_t;
  end;
  TFLock = FLock;
  PFLock = ^FLock;

  tms = record
    tms_utime: clock_t;
    tms_stime: clock_t;
    tms_cutime: clock_t;
    tms_cstime: clock_t;
  end;
  TTms = tms;
  PTms = ^tms;

  TFDSetEl = culong;
  TFDSet = array[0..wordsinfdset - 1] of TFDSetEl;
  pFDSet = ^TFDSet;

  cpu_set_t = record
{$IF defined(NEXTPAS_X86_64) or defined(NEXTPAS_AARCH64)}
    __bits: array[0..15] of culong;
{$ELSE}
    __bits: array[0..0] of culong;
{$ENDIF}
  end;
  tcpu_set_t = cpu_set_t;
  pcpu_set_t = ^tcpu_set_t;
