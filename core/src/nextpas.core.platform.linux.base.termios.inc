{ termios constants and types for Linux
  x86_64, aarch64, riscv64, arm share the same ioctl values.
  Ported from FPC rtl/linux/termios.inc }

const
  NCCS = 32;

  TCGETS          = $5401;
  TCSETS          = $5402;
  TCSETSW         = $5403;
  TCSETSF         = $5404;
  TCSBRK          = $5409;
  TCXONC          = $540A;
  TCFLSH          = $540B;
  TIOCEXCL        = $540C;
  TIOCNXCL        = $540D;
  TIOCSCTTY       = $540E;
  TIOCGPGRP       = $540F;
  TIOCSPGRP       = $5410;
  TIOCOUTQ        = $5411;
  TIOCSTI         = $5412;
  TIOCGWINSZ      = $5413;
  TIOCSWINSZ      = $5414;
  TIOCMGET        = $5415;
  TIOCMBIS        = $5416;
  TIOCMBIC        = $5417;
  TIOCMSET        = $5418;
  FIONREAD        = $541B;
  TIOCINQ         = FIONREAD;
  FIONBIO         = $5421;
  TIOCNOTTY       = $5422;
  TIOCSETD        = $5423;
  TIOCGETD        = $5424;
  TIOCGSID        = $5429;

  VINTR    = 0;
  VQUIT    = 1;
  VERASE   = 2;
  VKILL    = 3;
  VEOF     = 4;
  VTIME    = 5;
  VMIN     = 6;
  VSWTC    = 7;
  VSTART   = 8;
  VSTOP    = 9;
  VSUSP    = 10;
  VEOL     = 11;
  VREPRINT = 12;
  VDISCARD = 13;
  VWERASE  = 14;
  VLNEXT   = 15;
  VEOL2    = 16;

  IGNBRK  = $0000001;
  BRKINT  = $0000002;
  IGNPAR  = $0000004;
  PARMRK  = $0000008;
  INPCK   = $0000010;
  ISTRIP  = $0000020;
  INLCR   = $0000040;
  IGNCR   = $0000080;
  ICRNL   = $0000100;
  IUCLC   = $0000200;
  IXON    = $0000400;
  IXANY   = $0000800;
  IXOFF   = $0001000;
  IMAXBEL = $0002000;

  OPOST  = $0000001;
  OLCUC  = $0000002;
  ONLCR  = $0000004;
  OCRNL  = $0000008;
  ONOCR  = $0000010;
  ONLRET = $0000020;

  CBAUD   = $000100F;
  B0      = $0000000;
  B50     = $0000001;
  B75     = $0000002;
  B110    = $0000003;
  B134    = $0000004;
  B150    = $0000005;
  B200    = $0000006;
  B300    = $0000007;
  B600    = $0000008;
  B1200   = $0000009;
  B1800   = $000000A;
  B2400   = $000000B;
  B4800   = $000000C;
  B9600   = $000000D;
  B19200  = $000000E;
  B38400  = $000000F;
  CSIZE   = $0000030;
  CS5     = $0000000;
  CS6     = $0000010;
  CS7     = $0000020;
  CS8     = $0000030;
  CSTOPB  = $0000040;
  CREAD   = $0000080;
  PARENB  = $0000100;
  PARODD  = $0000200;
  HUPCL   = $0000400;
  CLOCAL  = $0000800;
  CBAUDEX = $0001000;
  B57600  = $0001001;
  B115200 = $0001002;
  B230400 = $0001003;
  B460800 = $0001004;
  B500000 = $0001005;
  B576000 = $0001006;
  B921600 = $0001007;
  B1000000= $0001008;
  B1152000= $0001009;
  B1500000= $000100A;
  B2000000= $000100B;
  B2500000= $000100C;
  B3000000= $000100D;
  B3500000= $000100E;
  B4000000= $000100F;
  CRTSCTS = $80000000;

  ISIG    = $0000001;
  ICANON  = $0000002;
  XCASE   = $0000004;
  ECHO_   = $0000008;
  ECHOE   = $0000010;
  ECHOK   = $0000020;
  ECHONL  = $0000040;
  NOFLSH  = $0000080;
  TOSTOP  = $0000100;
  ECHOCTL = $0000200;
  ECHOPRT = $0000400;
  ECHOKE  = $0000800;
  FLUSHO  = $0001000;
  PENDIN  = $0004000;
  IEXTEN  = $0008000;

  TCOOFF = 0;
  TCOON  = 1;
  TCIOFF = 2;
  TCION  = 3;

  TCIFLUSH  = 0;
  TCOFLUSH  = 1;
  TCIOFLUSH = 2;

  TCSANOW   = 0;
  TCSADRAIN = 1;
  TCSAFLUSH = 2;

  TIOCM_LE   = $001;
  TIOCM_DTR  = $002;
  TIOCM_RTS  = $004;
  TIOCM_ST   = $008;
  TIOCM_SR   = $010;
  TIOCM_CTS  = $020;
  TIOCM_CAR  = $040;
  TIOCM_RNG  = $080;
  TIOCM_DSR  = $100;
  TIOCM_CD   = TIOCM_CAR;
  TIOCM_RI   = TIOCM_RNG;

type
  winsize = record
    ws_row: UInt16;
    ws_col: UInt16;
    ws_xpixel: UInt16;
    ws_ypixel: UInt16;
  end;
  TWinSize = winsize;
  PWinSize = ^winsize;

{$packrecords c}
  termios = record
    c_iflag: UInt32;
    c_oflag: UInt32;
    c_cflag: UInt32;
    c_lflag: UInt32;
    c_line: Byte;
    c_cc: array[0..NCCS-1] of Byte;
    c_ispeed: UInt32;
    c_ospeed: UInt32;
  end;
  TTermios = termios;
  PTermios = ^termios;
{$packrecords default}
