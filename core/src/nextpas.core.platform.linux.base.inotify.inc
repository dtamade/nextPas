{ Linux inotify types and constants - ported from FPC rtl/linux/linux.pp }

const
  IN_ACCESS        = $00000001;
  IN_MODIFY        = $00000002;
  IN_ATTRIB        = $00000004;
  IN_CLOSE_WRITE   = $00000008;
  IN_CLOSE_NOWRITE = $00000010;
  IN_CLOSE         = IN_CLOSE_WRITE or IN_CLOSE_NOWRITE;
  IN_OPEN          = $00000020;
  IN_MOVED_FROM    = $00000040;
  IN_MOVED_TO      = $00000080;
  IN_MOVE          = IN_MOVED_FROM or IN_MOVED_TO;
  IN_CREATE        = $00000100;
  IN_DELETE         = $00000200;
  IN_DELETE_SELF    = $00000400;
  IN_MOVE_SELF     = $00000800;
  IN_ALL_EVENTS    = IN_ACCESS or IN_MODIFY or IN_ATTRIB or IN_CLOSE_WRITE or
                     IN_CLOSE_NOWRITE or IN_OPEN or IN_MOVED_FROM or
                     IN_MOVED_TO or IN_CREATE or IN_DELETE or IN_DELETE_SELF or
                     IN_MOVE_SELF;
  IN_UNMOUNT       = $00002000;
  IN_Q_OVERFLOW    = $00004000;
  IN_IGNORED       = $00008000;
  IN_ONLYDIR       = $01000000;
  IN_DONT_FOLLOW   = $02000000;
  IN_EXCL_UNLINK   = $04000000;
  IN_MASK_CREATE   = $10000000;
  IN_MASK_ADD      = $20000000;
  IN_ISDIR         = $40000000;
  IN_ONESHOT       = cuint32($80000000);
  IN_CLOEXEC       = $80000;
  IN_NONBLOCK      = $800;

type
  inotify_event = record
    wd: cint;
    mask: cuint32;
    cookie: cuint32;
    len: cuint32;
  end;
  Pinotify_event = ^inotify_event;
