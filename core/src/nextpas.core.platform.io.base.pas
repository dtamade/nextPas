unit nextpas.core.platform.io.base;

{$I nextpas.core.settings.inc}

interface

type
  {** @desc I/O 多路复用事件类型枚举 *}
  TPlatformPollEvent = (
    peReadable,
    peWritable,
    peError,
    peHangup,
    peReadHangup
  );
  {** @desc I/O 多路复用事件集合 *}
  TPlatformPollEvents = set of TPlatformPollEvent;

  {** @desc I/O 多路复用条目 *}
  TPlatformPollEntry = record
    Fd: PtrUInt;
    Events: TPlatformPollEvents;
    REvents: TPlatformPollEvents;
    UserData: Pointer;
  end;
  PPlatformPollEntry = ^TPlatformPollEntry;

  {** @desc I/O 多路复用器（epoll/kqueue/IOCP 封装） *}
  TPlatformPoller = record
  {$IFDEF NEXTPAS_LINUX}
    EpollFd: Int32;
    WakeFd: Int32;
    Entries: Pointer;
    Count: Int32;
    Capacity: Int32;
  {$ELSEIF defined(NEXTPAS_MACOS) or defined(NEXTPAS_FREEBSD)}
    KqueueFd: Int32;
    WakeReadFd: Int32;
    WakeWriteFd: Int32;
  {$ELSEIF defined(NEXTPAS_WINDOWS)}
    Entries: Pointer;
    Count: Int32;
    Capacity: Int32;
    WakeReadSocket: PtrUInt;
    WakeWriteSocket: PtrUInt;
    WinsockStarted: Boolean;
  {$ELSE}
    Dummy: Int32;
  {$ENDIF}
  end;

implementation

end.
