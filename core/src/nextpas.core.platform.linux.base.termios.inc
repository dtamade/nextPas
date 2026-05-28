{ termios/ioctl constants and types for Linux
  Full port from FPC rtl/linux/termios.inc
  x86_64, aarch64, riscv64, arm share asm-generic values.
  powerpc, mips, sparc have different ioctl encodings — add when needed. }

const
  NCCS = 32;
  NCC  = 8;

{$IF defined(NEXTPAS_X86_64) or defined(NEXTPAS_AARCH64) or defined(NEXTPAS_RISCV64) or defined(NEXTPAS_ARM)}

  TCGETS          = $5401;
  TCSETS          = $5402;
  TCSETSW         = $5403;
  TCSETSF         = $5404;
  TCGETA          = $5405;
  TCSETA          = $5406;
  TCSETAW         = $5407;
  TCSETAF         = $5408;
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
  TIOCGSOFTCAR    = $5419;
  TIOCSSOFTCAR    = $541A;
  FIONREAD        = $541B;
  TIOCINQ         = FIONREAD;
  TIOCLINUX       = $541C;
  TIOCCONS        = $541D;
  TIOCGSERIAL     = $541E;
  TIOCSSERIAL     = $541F;
  TIOCPKT         = $5420;
  FIONBIO         = $5421;
  TIOCNOTTY       = $5422;
  TIOCSETD        = $5423;
  TIOCGETD        = $5424;
  TCSBRKP         = $5425;
  TIOCSBRK        = $5427;
  TIOCCBRK        = $5428;
  TIOCGSID        = $5429;
  TIOCGRS485      = $542E;
  TIOCSRS485      = $542F;
  TIOCVHANGUP     = $5437;
  FIONCLEX        = $5450;
  FIOCLEX         = $5451;
  FIOASYNC        = $5452;
  TIOCSERCONFIG   = $5453;
  TIOCSERGWILD    = $5454;
  TIOCSERSWILD    = $5455;
  TIOCGLCKTRMIOS  = $5456;
  TIOCSLCKTRMIOS  = $5457;
  TIOCSERGSTRUCT  = $5458;
  TIOCSERGETLSR   = $5459;
  TIOCSERGETMULTI = $545A;
  TIOCSERSETMULTI = $545B;
  TIOCMIWAIT      = $545C;
  TIOCGICOUNT     = $545D;
  FIOQSIZE        = $5460;

  TIOCPKT_DATA       = 0;
  TIOCPKT_FLUSHREAD  = 1;
  TIOCPKT_FLUSHWRITE = 2;
  TIOCPKT_STOP       = 4;
  TIOCPKT_START      = 8;
  TIOCPKT_NOSTOP     = 16;
  TIOCPKT_DOSTOP     = 32;
  TIOCPKT_IOCTL      = 64;
  TIOCSER_TEMT       = $01;

  { c_cc characters }
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

  { c_iflag bits }
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
  IUTF8   = $0004000;

  { c_oflag bits }
  OPOST  = $0000001;
  OLCUC  = $0000002;
  ONLCR  = $0000004;
  OCRNL  = $0000008;
  ONOCR  = $0000010;
  ONLRET = $0000020;
  OFILL  = $0000040;
  OFDEL  = $0000080;
  NLDLY  = $0000100;
  NL0    = $0000000;
  NL1    = $0000100;
  CRDLY  = $0000600;
  CR0    = $0000000;
  CR1    = $0000200;
  CR2    = $0000400;
  CR3    = $0000600;
  TABDLY = $0001800;
  TAB0   = $0000000;
  TAB1   = $0000800;
  TAB2   = $0001000;
  TAB3   = $0001800;
  XTABS  = $0001800;
  BSDLY  = $0002000;
  BS0    = $0000000;
  BS1    = $0002000;
  VTDLY  = $0004000;
  VT0    = $0000000;
  VT1    = $0004000;
  FFDLY  = $0008000;
  FF0    = $0000000;
  FF1    = $0008000;

  { c_cflag bits }
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
  EXTA    = B19200;
  EXTB    = B38400;
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
  __MAX_BAUD = B4000000;
  CIBAUD  = $100F0000;
  CMSPAR  = $40000000;
  CRTSCTS = $80000000;

  { c_lflag bits }
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

  { TCFlow }
  TCOOFF = 0;
  TCOON  = 1;
  TCIOFF = 2;
  TCION  = 3;

  { TCFlush }
  TCIFLUSH  = 0;
  TCOFLUSH  = 1;
  TCIOFLUSH = 2;

  { TCSetAttr }
  TCSANOW   = 0;
  TCSADRAIN = 1;
  TCSAFLUSH = 2;

  { modem lines }
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
  TIOCM_OUT1 = $2000;
  TIOCM_OUT2 = $4000;
  TIOCM_LOOP = $8000;

{$ELSE}
  {$ERROR 'termios: unsupported CPU — port values from FPC rtl/linux/termios.inc for this arch'}
{$ENDIF}

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
