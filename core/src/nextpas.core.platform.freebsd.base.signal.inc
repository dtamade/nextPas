{ FreeBSD signal constants - ported from FPC rtl/darwin/signal.inc }

const
  SIGHUP    = 1;
  SIGINT    = 2;
  SIGQUIT   = 3;
  SIGILL    = 4;
  SIGTRAP   = 5;
  SIGABRT   = 6;
  SIGIOT    = SIGABRT;
  SIGEMT    = 7;
  SIGFPE    = 8;
  SIGKILL   = 9;
  SIGBUS    = 10;
  SIGSEGV   = 11;
  SIGSYS    = 12;
  SIGPIPE   = 13;
  SIGALRM   = 14;
  SIGTERM   = 15;
  SIGURG    = 16;
  SIGSTOP   = 17;
  SIGTSTP   = 18;
  SIGCONT   = 19;
  SIGCHLD   = 20;
  SIGTTIN   = 21;
  SIGTTOU   = 22;
  SIGIO     = 23;
  SIGXCPU   = 24;
  SIGXFSZ   = 25;
  SIGVTALRM = 26;
  SIGPROF   = 27;
  SIGWINCH  = 28;
  SIGINFO   = 29;
  SIGUSR1   = 30;
  SIGUSR2   = 31;

  SIG_DFL = 0;
  SIG_IGN = 1;
  SIG_ERR = -1;

  SIG_BLOCK   = 1;
  SIG_UNBLOCK = 2;
  SIG_SETMASK = 3;

  SA_NOCLDSTOP = 8;
  SA_ONSTACK   = $001;
  SA_RESTART   = $002;
  SA_DISABLE   = $004;
  SA_RESETHAND = $004;
  SA_NODEFER   = $010;
  SA_NOCLDWAIT = $020;
  SA_SIGINFO   = $040;
  SA_USERTRAMP = $100;
