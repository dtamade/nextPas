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
    {** @desc 检查 poller 是否已初始化
        @return True 如果 poller 有效 *}
    function IsValid: Boolean; inline;
  end;

implementation

function TPlatformPoller.IsValid: Boolean;
begin
{$IFDEF NEXTPAS_LINUX}
  Result := EpollFd >= 0;
{$ELSEIF defined(NEXTPAS_MACOS) or defined(NEXTPAS_FREEBSD)}
  Result := KqueueFd >= 0;
{$ELSEIF defined(NEXTPAS_WINDOWS)}
  Result := WinsockStarted;
{$ELSE}
  Result := False;
{$ENDIF}
end;

end.
