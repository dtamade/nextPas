unit nextpas.core.platform.io;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.io.base;

function platform_poller_create(out APoller: TPlatformPoller): Int32;
function platform_poller_close(var APoller: TPlatformPoller): Int32;
function platform_poller_add(var APoller: TPlatformPoller; AFd: Int32;
  AEvents: TPlatformPollEvents; AUserData: Pointer): Int32;
function platform_poller_modify(var APoller: TPlatformPoller; AFd: Int32;
  AEvents: TPlatformPollEvents; AUserData: Pointer): Int32;
function platform_poller_remove(var APoller: TPlatformPoller; AFd: Int32): Int32;
function platform_poller_wait(var APoller: TPlatformPoller;
  AEntries: PPlatformPollEntry; AMaxEntries: Int32; ATimeoutMs: Int32;
  out ACount: Int32): Int32;

implementation

{$IFDEF NEXTPAS_LINUX}
uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.linux.base,
  nextpas.core.platform.linux.ffi;

function EventsToEpoll(AEvents: TPlatformPollEvents): UInt32;
begin
  Result := 0;
  if peReadable in AEvents then Result := Result or EPOLLIN;
  if peWritable in AEvents then Result := Result or EPOLLOUT;
  if peReadHangup in AEvents then Result := Result or EPOLLRDHUP;
end;

function EpollToEvents(AEpoll: UInt32): TPlatformPollEvents;
begin
  Result := [];
  if (AEpoll and EPOLLIN) <> 0 then Include(Result, peReadable);
  if (AEpoll and EPOLLOUT) <> 0 then Include(Result, peWritable);
  if (AEpoll and EPOLLERR) <> 0 then Include(Result, peError);
  if (AEpoll and EPOLLHUP) <> 0 then Include(Result, peHangup);
  if (AEpoll and EPOLLRDHUP) <> 0 then Include(Result, peReadHangup);
end;

function platform_poller_create(out APoller: TPlatformPoller): Int32;
begin
  FillChar(APoller, SizeOf(APoller), 0);
  APoller.EpollFd := epoll_create1(EPOLL_CLOEXEC);
  if APoller.EpollFd < 0 then
    Result := platform_get_errno
  else
    Result := 0;
end;

function platform_poller_close(var APoller: TPlatformPoller): Int32;
begin
  if APoller.EpollFd >= 0 then
  begin
    close(APoller.EpollFd);
    APoller.EpollFd := -1;
    Result := 0;
  end
  else
    Result := 9; { EBADF }
end;

function platform_poller_add(var APoller: TPlatformPoller; AFd: Int32;
  AEvents: TPlatformPollEvents; AUserData: Pointer): Int32;
var
  LEv: epoll_event;
begin
  FillChar(LEv, SizeOf(LEv), 0);
  LEv.events := EventsToEpoll(AEvents);
  LEv.data.ptr := AUserData;
  if epoll_ctl(APoller.EpollFd, EPOLL_CTL_ADD, AFd, @LEv) = 0 then
    Result := 0
  else
    Result := platform_get_errno;
end;

function platform_poller_modify(var APoller: TPlatformPoller; AFd: Int32;
  AEvents: TPlatformPollEvents; AUserData: Pointer): Int32;
var
  LEv: epoll_event;
begin
  FillChar(LEv, SizeOf(LEv), 0);
  LEv.events := EventsToEpoll(AEvents);
  LEv.data.ptr := AUserData;
  if epoll_ctl(APoller.EpollFd, EPOLL_CTL_MOD, AFd, @LEv) = 0 then
    Result := 0
  else
    Result := platform_get_errno;
end;

function platform_poller_remove(var APoller: TPlatformPoller; AFd: Int32): Int32;
begin
  if epoll_ctl(APoller.EpollFd, EPOLL_CTL_DEL, AFd, nil) = 0 then
    Result := 0
  else
    Result := platform_get_errno;
end;

function platform_poller_wait(var APoller: TPlatformPoller;
  AEntries: PPlatformPollEntry; AMaxEntries: Int32; ATimeoutMs: Int32;
  out ACount: Int32): Int32;
var
  LEvents: array[0..63] of epoll_event;
  LMax, LN, LI: Int32;
begin
  ACount := 0;
  LMax := AMaxEntries;
  if LMax > 64 then LMax := 64;
  LN := epoll_wait(APoller.EpollFd, @LEvents[0], LMax, ATimeoutMs);
  if LN < 0 then
    Exit(platform_get_errno);
  for LI := 0 to LN - 1 do
  begin
    AEntries[LI].Fd := 0;
    AEntries[LI].REvents := EpollToEvents(LEvents[LI].events);
    AEntries[LI].UserData := LEvents[LI].data.ptr;
  end;
  ACount := LN;
  Result := 0;
end;
{$ENDIF}

{$IF defined(NEXTPAS_MACOS) or defined(NEXTPAS_FREEBSD)}
uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  {$IFDEF NEXTPAS_MACOS}
  nextpas.core.platform.darwin.base,
  nextpas.core.platform.darwin.ffi;
  {$ELSE}
  nextpas.core.platform.freebsd.base,
  nextpas.core.platform.freebsd.ffi;
  {$ENDIF}

function platform_poller_create(out APoller: TPlatformPoller): Int32;
begin
  FillChar(APoller, SizeOf(APoller), 0);
  APoller.KqueueFd := kqueue;
  if APoller.KqueueFd < 0 then
    Result := platform_get_errno
  else
    Result := 0;
end;

function platform_poller_close(var APoller: TPlatformPoller): Int32;
begin
  if APoller.KqueueFd >= 0 then
  begin
    close(APoller.KqueueFd);
    APoller.KqueueFd := -1;
    Result := 0;
  end
  else
    Result := platform_get_errno;
end;

function platform_poller_add(var APoller: TPlatformPoller; AFd: Int32;
  AEvents: TPlatformPollEvents; AUserData: Pointer): Int32;
var
  LChanges: array[0..1] of TKEvent;
  LCount: Int32;
begin
  LCount := 0;
  if peReadable in AEvents then
  begin
    FillChar(LChanges[LCount], SizeOf(TKEvent), 0);
    LChanges[LCount].Ident := PtrUInt(AFd);
    LChanges[LCount].Filter := EVFILT_READ;
    LChanges[LCount].Flags := EV_ADD or EV_CLEAR;
    LChanges[LCount].uData := AUserData;
    Inc(LCount);
  end;
  if peWritable in AEvents then
  begin
    FillChar(LChanges[LCount], SizeOf(TKEvent), 0);
    LChanges[LCount].Ident := PtrUInt(AFd);
    LChanges[LCount].Filter := EVFILT_WRITE;
    LChanges[LCount].Flags := EV_ADD or EV_CLEAR;
    LChanges[LCount].uData := AUserData;
    Inc(LCount);
  end;
  if LCount = 0 then Exit(0);
  if kevent(APoller.KqueueFd, @LChanges[0], LCount, nil, 0, nil) < 0 then
    Result := platform_get_errno
  else
    Result := 0;
end;

function platform_poller_modify(var APoller: TPlatformPoller; AFd: Int32;
  AEvents: TPlatformPollEvents; AUserData: Pointer): Int32;
begin
  platform_poller_remove(APoller, AFd);
  Result := platform_poller_add(APoller, AFd, AEvents, AUserData);
end;

function platform_poller_remove(var APoller: TPlatformPoller; AFd: Int32): Int32;
var
  LChanges: array[0..1] of TKEvent;
begin
  FillChar(LChanges, SizeOf(LChanges), 0);
  LChanges[0].Ident := PtrUInt(AFd);
  LChanges[0].Filter := EVFILT_READ;
  LChanges[0].Flags := EV_DELETE;
  LChanges[1].Ident := PtrUInt(AFd);
  LChanges[1].Filter := EVFILT_WRITE;
  LChanges[1].Flags := EV_DELETE;
  kevent(APoller.KqueueFd, @LChanges[0], 2, nil, 0, nil);
  Result := 0;
end;

function platform_poller_wait(var APoller: TPlatformPoller;
  AEntries: PPlatformPollEntry; AMaxEntries: Int32; ATimeoutMs: Int32;
  out ACount: Int32): Int32;
var
  LEvents: array[0..63] of TKEvent;
  LMax, LN, LI: Int32;
  LTimeout: timespec;
  LTimeoutPtr: Pointer;
begin
  ACount := 0;
  LMax := AMaxEntries;
  if LMax > 64 then LMax := 64;
  if ATimeoutMs < 0 then
    LTimeoutPtr := nil
  else
  begin
    LTimeout.tv_sec := ATimeoutMs div 1000;
    LTimeout.tv_nsec := (ATimeoutMs mod 1000) * 1000000;
    LTimeoutPtr := @LTimeout;
  end;
  LN := kevent(APoller.KqueueFd, nil, 0, @LEvents[0], LMax, LTimeoutPtr);
  if LN < 0 then
    Exit(platform_get_errno);
  for LI := 0 to LN - 1 do
  begin
    AEntries[LI].Fd := Int32(LEvents[LI].Ident);
    AEntries[LI].REvents := [];
    AEntries[LI].UserData := LEvents[LI].uData;
    if LEvents[LI].Filter = EVFILT_READ then
      Include(AEntries[LI].REvents, peReadable);
    if LEvents[LI].Filter = EVFILT_WRITE then
      Include(AEntries[LI].REvents, peWritable);
    if (LEvents[LI].Flags and EV_EOF) <> 0 then
      Include(AEntries[LI].REvents, peHangup);
    if (LEvents[LI].Flags and EV_ERROR) <> 0 then
      Include(AEntries[LI].REvents, peError);
  end;
  ACount := LN;
  Result := 0;
end;
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
function platform_poller_create(out APoller: TPlatformPoller): Int32;
begin
  FillChar(APoller, SizeOf(APoller), 0);
  Result := 0;
end;

function platform_poller_close(var APoller: TPlatformPoller): Int32;
begin
  if APoller.Entries <> nil then
  begin
    FreeMem(APoller.Entries);
    APoller.Entries := nil;
  end;
  APoller.Count := 0;
  APoller.Capacity := 0;
  Result := 0;
end;

function platform_poller_add(var APoller: TPlatformPoller; AFd: Int32;
  AEvents: TPlatformPollEvents; AUserData: Pointer): Int32;
begin
  Result := Int32(WSAGetLastError);
end;

function platform_poller_modify(var APoller: TPlatformPoller; AFd: Int32;
  AEvents: TPlatformPollEvents; AUserData: Pointer): Int32;
begin
  Result := Int32(WSAGetLastError);
end;

function platform_poller_remove(var APoller: TPlatformPoller; AFd: Int32): Int32;
begin
  Result := Int32(WSAGetLastError);
end;

function platform_poller_wait(var APoller: TPlatformPoller;
  AEntries: PPlatformPollEntry; AMaxEntries: Int32; ATimeoutMs: Int32;
  out ACount: Int32): Int32;
begin
  ACount := 0;
  Result := Int32(WSAGetLastError);
end;
{$ENDIF}

{$IF not defined(NEXTPAS_LINUX) and not defined(NEXTPAS_MACOS) and not defined(NEXTPAS_FREEBSD) and not defined(NEXTPAS_WINDOWS)}
function platform_poller_create(out APoller: TPlatformPoller): Int32; begin FillChar(APoller, SizeOf(APoller), 0); Result := -1; end;
function platform_poller_close(var APoller: TPlatformPoller): Int32; begin Result := -1; end;
function platform_poller_add(var APoller: TPlatformPoller; AFd: Int32; AEvents: TPlatformPollEvents; AUserData: Pointer): Int32; begin Result := -1; end;
function platform_poller_modify(var APoller: TPlatformPoller; AFd: Int32; AEvents: TPlatformPollEvents; AUserData: Pointer): Int32; begin Result := -1; end;
function platform_poller_remove(var APoller: TPlatformPoller; AFd: Int32): Int32; begin Result := -1; end;
function platform_poller_wait(var APoller: TPlatformPoller; AEntries: PPlatformPollEntry; AMaxEntries: Int32; ATimeoutMs: Int32; out ACount: Int32): Int32; begin ACount := 0; Result := -1; end;
{$ENDIF}

end.
