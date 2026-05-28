{ FreeBSD/BSD kqueue types and constants - ported from FPC rtl/bsd/bsd.pas }

const
  EVFILT_READ    = -1;
  EVFILT_WRITE   = -2;
  EVFILT_AIO     = -3;
  EVFILT_VNODE   = -4;
  EVFILT_PROC    = -5;
  EVFILT_SIGNAL  = -6;
  EVFILT_TIMER   = -7;
  EVFILT_NETDEV  = -8;
  EVFILT_FS      = -9;
  EVFILT_SYSCOUNT = 9;

  EV_ADD      = $0001;
  EV_DELETE   = $0002;
  EV_ENABLE   = $0004;
  EV_DISABLE  = $0008;
  EV_ONESHOT  = $0010;
  EV_CLEAR    = $0020;
  EV_SYSFLAGS = $F000;
  EV_FLAG1    = $2000;
  EV_EOF      = $8000;
  EV_ERROR    = $4000;

  NOTE_LOWAT     = $0001;
  NOTE_DELETE    = $0001;
  NOTE_WRITE     = $0002;
  NOTE_EXTEND    = $0004;
  NOTE_ATTRIB    = $0008;
  NOTE_LINK      = $0010;
  NOTE_RENAME    = $0020;
  NOTE_REVOKE    = $0040;

  NOTE_EXIT      = $80000000;
  NOTE_FORK      = $40000000;
  NOTE_EXEC      = $20000000;
  NOTE_PCTRLMASK = $f0000000;
  NOTE_PDATAMASK = $000fffff;
  NOTE_TRACK     = $00000001;
  NOTE_TRACKERR  = $00000002;
  NOTE_CHILD     = $00000004;

type
  PKEvent = ^TKEvent;
  TKEvent = record
    Ident: PtrUInt;
    Filter: Int16;
    Flags: UInt16;
    FFlags: UInt32;
    Data: PtrInt;
    uData: Pointer;
  end;
