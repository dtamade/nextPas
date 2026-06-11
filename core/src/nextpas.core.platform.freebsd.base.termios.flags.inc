{ FreeBSD termios flag constants and record layout.
  Constants and layout follow the FreeBSD <sys/termios.h> ABI. }

const
  NCCS = 20;

  { c_cc indices }
  VEOF = 0;
  VEOL = 1;
  VEOL2 = 2;
  VERASE = 3;
  VWERASE = 4;
  VKILL = 5;
  VREPRINT = 6;
  VINTR = 8;
  VQUIT = 9;
  VSUSP = 10;
  VDSUSP = 11;
  VSTART = 12;
  VSTOP = 13;
  VLNEXT = 14;
  VDISCARD = 15;
  VMIN = 16;
  VTIME = 17;
  VSTATUS = 18;

  { c_iflag }
  IGNBRK = $0001;
  BRKINT = $0002;
  IGNPAR = $0004;
  PARMRK = $0008;
  INPCK = $0010;
  ISTRIP = $0020;
  INLCR = $0040;
  IGNCR = $0080;
  ICRNL = $0100;
  IXON = $0200;
  IXOFF = $0400;
  IXANY = $0800;

  { c_oflag }
  OPOST = $0001;
  ONLCR = $0002;

  { c_cflag }
  CSIZE = $0030;
  CS5 = $0000;
  CS6 = $0010;
  CS7 = $0020;
  CS8 = $0030;
  CSTOPB = $0040;
  CREAD = $0080;
  PARENB = $0100;
  PARODD = $0200;
  HUPCL = $0400;
  CLOCAL = $0800;
  CRTSCTS = $00030000;

  { c_lflag }
  ECHO_ = $0008;
  ECHOE = $0010;
  ECHOK = $0020;
  ECHONL = $0040;
  ECHOPRT = $0020;
  ECHOKE = $0040;
  ISIG = $0080;
  ICANON = $0100;
  IEXTEN = $0000400;
  NOFLSH = $8000;
  TOSTOP = $00400000;
  FLUSHO = $00800000;
  PENDIN = $20000000;

  { tcsetattr actions }
  TCSANOW = 0;
  TCSADRAIN = 1;
  TCSAFLUSH = 2;

type
{$packrecords c}
  termios = record
    c_iflag: cuint;
    c_oflag: cuint;
    c_cflag: cuint;
    c_lflag: cuint;
    c_cc: array[0..NCCS - 1] of Byte;
    c_ispeed: cuint;
    c_ospeed: cuint;
  end;
  TPlatformFreeBSDTermios = termios;
  PPlatformFreeBSDTermios = ^termios;
  TTermios = termios;
  PTermios = ^termios;
{$packrecords default}
