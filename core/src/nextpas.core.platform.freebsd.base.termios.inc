{ FreeBSD termios ioctl constants and winsize structure }

const
  TIOCGWINSZ = $40087468;
  TIOCSWINSZ = $80087467;
  TIOCSCTTY  = $20007461;
  TIOCNOTTY  = $20007471;

type
  winsize = record
    ws_row: UInt16;
    ws_col: UInt16;
    ws_xpixel: UInt16;
    ws_ypixel: UInt16;
  end;
  TWinSize = winsize;
  PWinSize = ^winsize;
