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
    {** @desc 检查是否可读
        @return True 如果有可读事件 *}
    function IsReadable: Boolean; inline;
    {** @desc 检查是否可写
        @return True 如果有可写事件 *}
    function IsWritable: Boolean; inline;
    {** @desc 检查是否有错误
        @return True 如果有错误事件 *}
    function HasError: Boolean; inline;
    {** @desc 检查是否挂起
        @return True 如果有挂起事件 *}
    function IsHangup: Boolean; inline;
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

function TPlatformPollEntry.IsReadable: Boolean;
begin
  Result := peReadable in REvents;
end;

function TPlatformPollEntry.IsWritable: Boolean;
begin
  Result := peWritable in REvents;
end;

function TPlatformPollEntry.HasError: Boolean;
begin
  Result := peError in REvents;
end;

function TPlatformPollEntry.IsHangup: Boolean;
begin
  Result := (peHangup in REvents) or (peReadHangup in REvents);
end;

end.
