unit nextpas.core.platform.io.base;

{$I nextpas.core.settings.inc}

interface

type
  TPlatformPollEvent = (
    peReadable,
    peWritable,
    peError,
    peHangup,
    peReadHangup
  );
  TPlatformPollEvents = set of TPlatformPollEvent;

  TPlatformPollEntry = record
    Fd: PtrUInt;
    Events: TPlatformPollEvents;
    REvents: TPlatformPollEvents;
    UserData: Pointer;
  end;
  PPlatformPollEntry = ^TPlatformPollEntry;

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
