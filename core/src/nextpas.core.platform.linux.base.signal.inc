{ Linux signal constants and types - ported from FPC rtl/linux/signal.inc + linux.pp }

const
  SIGHUP    = 1;
  SIGINT    = 2;
  SIGQUIT   = 3;
  SIGILL    = 4;
  SIGTRAP   = 5;
  SIGABRT   = 6;
  SIGIOT    = 6;
  SIGBUS    = 7;
  SIGFPE    = 8;
  SIGKILL   = 9;
  SIGUSR1   = 10;
  SIGSEGV   = 11;
  SIGUSR2   = 12;
  SIGPIPE   = 13;
  SIGALRM   = 14;
  SIGTERM   = 15;
  SIGSTKFLT = 16;
  SIGCHLD   = 17;
  SIGCONT   = 18;
  SIGSTOP   = 19;
  SIGTSTP   = 20;
  SIGTTIN   = 21;
  SIGTTOU   = 22;
  SIGURG    = 23;
  SIGXCPU   = 24;
  SIGXFSZ   = 25;
  SIGVTALRM = 26;
  SIGPROF   = 27;
  SIGWINCH  = 28;
  SIGIO     = 29;
  SIGPOLL   = SIGIO;
  SIGPWR    = 30;
  SIGUNUSED = 31;
  SIGRTMIN  = 32;

  SIG_BLOCK   = 0;
  SIG_UNBLOCK = 1;
  SIG_SETMASK = 2;

  SIG_DFL = 0;
  SIG_IGN = 1;
  SIG_ERR = -1;

  SA_NOCLDSTOP = $00000001;
  SA_NOCLDWAIT = $00000002;
  SA_SIGINFO   = $00000004;
  SA_RESTORER  = $04000000;
  SA_ONSTACK   = $08000000;
  SA_RESTART   = $10000000;
  SA_INTERRUPT = $20000000;
  SA_NODEFER   = $40000000;
  SA_RESETHAND = cuint32($80000000);
  SA_NOMASK    = SA_NODEFER;
  SA_ONESHOT   = SA_RESETHAND;

{$IF defined(NEXTPAS_X86_64) or defined(NEXTPAS_AARCH64)}
const
  SIG_MAXSIG     = 128;
  wordsinsigset  = SIG_MAXSIG div (8 * SizeOf(culong));
{$ENDIF}

type
  sigset_t = array[0..wordsinsigset - 1] of culong;
  psigset_t = ^sigset_t;
  TSigSet = sigset_t;
  PSigSet = psigset_t;

  signalhandler_t = procedure(sig: cint); cdecl;
  sigactionhandler_t = procedure(sig: cint; info: Pointer; context: Pointer); cdecl;
  sigrestorerhandler_t = procedure; cdecl;

  sigactionrec = record
    case Boolean of
      False: (sa_handler: signalhandler_t);
      True: (sa_sigaction: sigactionhandler_t);
  end;

  TSigAction = record
    sa_handler: sigactionrec;
    sa_flags: culong;
    sa_restorer: sigrestorerhandler_t;
    sa_mask: sigset_t;
  end;
  PSigAction = ^TSigAction;

  tsiginfo = record
    si_signo: cint;
    si_errno: cint;
    si_code: cint;
    _pad: array[0..28] of cint;
  end;
  psiginfo = ^tsiginfo;
  TSigInfo_t = tsiginfo;
