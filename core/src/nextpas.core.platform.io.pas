unit nextpas.core.platform.io;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.io.base;

function platform_poller_create(out APoller: TPlatformPoller): Int32;
function platform_poller_close(var APoller: TPlatformPoller): Int32;
function platform_poller_add(var APoller: TPlatformPoller; AFd: PtrUInt;
  AEvents: TPlatformPollEvents; AUserData: Pointer): Int32;
function platform_poller_modify(var APoller: TPlatformPoller; AFd: PtrUInt;
  AEvents: TPlatformPollEvents; AUserData: Pointer): Int32;
function platform_poller_remove(var APoller: TPlatformPoller; AFd: PtrUInt): Int32;
function platform_poller_enable_wake(var APoller: TPlatformPoller;
  AUserData: Pointer): Int32;
function platform_poller_wake(var APoller: TPlatformPoller): Int32;
function platform_poller_drain_wake(var APoller: TPlatformPoller): Int32;
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

type
  PPlatformPollRegistration = ^TPlatformPollRegistration;
  TPlatformPollRegistration = record
    Entry: TPlatformPollEntry;
  end;

  PPlatformPollRegistrationArray = ^TPlatformPollRegistrationArray;
  TPlatformPollRegistrationArray =
    array[0..MaxInt div SizeOf(PPlatformPollRegistration) - 1] of PPlatformPollRegistration;

function LinuxPollEntries(var APoller: TPlatformPoller): PPlatformPollRegistrationArray;
begin
  Result := PPlatformPollRegistrationArray(APoller.Entries);
end;

function LinuxFindPollEntry(var APoller: TPlatformPoller; AFd: PtrUInt): Int32;
var
  LEntries: PPlatformPollRegistrationArray;
  LI: Int32;
begin
  LEntries := LinuxPollEntries(APoller);
  for LI := 0 to APoller.Count - 1 do
    if (LEntries^[LI] <> nil) and (LEntries^[LI]^.Entry.Fd = AFd) then
      Exit(LI);
  Result := -1;
end;

function LinuxEnsurePollCapacity(var APoller: TPlatformPoller;
  ACapacity: Int32): Int32;
var
  LNewCapacity: Int32;
  LNewEntries: Pointer;
  LBytes: SizeUInt;
begin
  if ACapacity <= APoller.Capacity then
    Exit(0);
  LNewCapacity := APoller.Capacity;
  if LNewCapacity < 8 then
    LNewCapacity := 8;
  while LNewCapacity < ACapacity do
    LNewCapacity := LNewCapacity * 2;
  LBytes := SizeUInt(LNewCapacity) * SizeOf(PPlatformPollRegistration);
  GetMem(LNewEntries, LBytes);
  if LNewEntries = nil then
    Exit(ESysENOMEM);
  FillChar(LNewEntries^, LBytes, 0);
  if (APoller.Entries <> nil) and (APoller.Count > 0) then
    Move(APoller.Entries^, LNewEntries^,
      SizeUInt(APoller.Count) * SizeOf(PPlatformPollRegistration));
  if APoller.Entries <> nil then
    FreeMem(APoller.Entries);
  APoller.Entries := LNewEntries;
  APoller.Capacity := LNewCapacity;
  Result := 0;
end;

function platform_poller_create(out APoller: TPlatformPoller): Int32;
begin
  FillChar(APoller, SizeOf(APoller), 0);
  APoller.EpollFd := -1;
  APoller.WakeFd := -1;
  APoller.EpollFd := epoll_create1(EPOLL_CLOEXEC);
  if APoller.EpollFd < 0 then
    Result := platform_get_errno
  else
    Result := 0;
end;

function platform_poller_close(var APoller: TPlatformPoller): Int32;
var
  LEntries: PPlatformPollRegistrationArray;
  LI: Int32;
begin
  if APoller.Entries <> nil then
  begin
    LEntries := LinuxPollEntries(APoller);
    for LI := 0 to APoller.Count - 1 do
      if LEntries^[LI] <> nil then
        FreeMem(LEntries^[LI]);
    FreeMem(APoller.Entries);
    APoller.Entries := nil;
  end;
  APoller.Count := 0;
  APoller.Capacity := 0;
  if APoller.WakeFd >= 0 then
  begin
    close(APoller.WakeFd);
    APoller.WakeFd := -1;
  end;
  if APoller.EpollFd >= 0 then
  begin
    close(APoller.EpollFd);
    APoller.EpollFd := -1;
    Result := 0;
  end
  else
    Result := 9; { EBADF }
end;

function platform_poller_add(var APoller: TPlatformPoller; AFd: PtrUInt;
  AEvents: TPlatformPollEvents; AUserData: Pointer): Int32;
var
  LEv: epoll_event;
  LEntries: PPlatformPollRegistrationArray;
  LRegistration: PPlatformPollRegistration;
begin
  if LinuxFindPollEntry(APoller, AFd) >= 0 then
    Exit(ESysEEXIST);
  Result := LinuxEnsurePollCapacity(APoller, APoller.Count + 1);
  if Result <> 0 then
    Exit(Result);
  LEntries := LinuxPollEntries(APoller);
  GetMem(LRegistration, SizeOf(TPlatformPollRegistration));
  if LRegistration = nil then
    Exit(ESysENOMEM);
  LRegistration^.Entry.Fd := AFd;
  LRegistration^.Entry.Events := AEvents;
  LRegistration^.Entry.REvents := [];
  LRegistration^.Entry.UserData := AUserData;
  FillChar(LEv, SizeOf(LEv), 0);
  LEv.events := EventsToEpoll(AEvents);
  LEv.data.ptr := LRegistration;
  if epoll_ctl(APoller.EpollFd, EPOLL_CTL_ADD, Int32(AFd), @LEv) = 0 then
  begin
    LEntries^[APoller.Count] := LRegistration;
    Inc(APoller.Count);
    Exit(0);
  end;
  Result := platform_get_errno;
  FreeMem(LRegistration);
end;

function platform_poller_modify(var APoller: TPlatformPoller; AFd: PtrUInt;
  AEvents: TPlatformPollEvents; AUserData: Pointer): Int32;
var
  LEv: epoll_event;
  LEntries: PPlatformPollRegistrationArray;
  LOldEntry: TPlatformPollEntry;
  LIndex: Int32;
begin
  LIndex := LinuxFindPollEntry(APoller, AFd);
  if LIndex < 0 then
    Exit(ESysENOENT);
  LEntries := LinuxPollEntries(APoller);
  LOldEntry := LEntries^[LIndex]^.Entry;
  LEntries^[LIndex]^.Entry.Events := AEvents;
  LEntries^[LIndex]^.Entry.REvents := [];
  LEntries^[LIndex]^.Entry.UserData := AUserData;
  FillChar(LEv, SizeOf(LEv), 0);
  LEv.events := EventsToEpoll(AEvents);
  LEv.data.ptr := LEntries^[LIndex];
  if epoll_ctl(APoller.EpollFd, EPOLL_CTL_MOD, Int32(AFd), @LEv) = 0 then
    Result := 0
  else
  begin
    Result := platform_get_errno;
    LEntries^[LIndex]^.Entry := LOldEntry;
  end;
end;

function platform_poller_remove(var APoller: TPlatformPoller; AFd: PtrUInt): Int32;
var
  LIndex: Int32;
  LEntries: PPlatformPollRegistrationArray;
  LMoveCount: Int32;
begin
  LIndex := LinuxFindPollEntry(APoller, AFd);
  if LIndex < 0 then
    Exit(ESysENOENT);
  if epoll_ctl(APoller.EpollFd, EPOLL_CTL_DEL, Int32(AFd), nil) <> 0 then
    Exit(platform_get_errno);
  LEntries := LinuxPollEntries(APoller);
  FreeMem(LEntries^[LIndex]);
  LMoveCount := APoller.Count - LIndex - 1;
  if LMoveCount > 0 then
    Move(LEntries^[LIndex + 1], LEntries^[LIndex],
      SizeUInt(LMoveCount) * SizeOf(PPlatformPollRegistration));
  Dec(APoller.Count);
  LEntries^[APoller.Count] := nil;
  Result := 0;
end;

function platform_poller_enable_wake(var APoller: TPlatformPoller;
  AUserData: Pointer): Int32;
begin
  if APoller.WakeFd >= 0 then
    Exit(0);
  APoller.WakeFd := eventfd(0, EFD_NONBLOCK or EFD_CLOEXEC);
  if APoller.WakeFd < 0 then
    Exit(platform_get_errno);

  Result := platform_poller_add(APoller, PtrUInt(APoller.WakeFd),
    [peReadable], AUserData);
  if Result = 0 then
    Exit(0);

  close(APoller.WakeFd);
  APoller.WakeFd := -1;
end;

function platform_poller_wake(var APoller: TPlatformPoller): Int32;
var
  LValue: UInt64;
begin
  if APoller.WakeFd < 0 then
    Exit(ESysEOPNOTSUPP);
  LValue := 1;
  if write(APoller.WakeFd, @LValue, SizeOf(LValue)) = SizeOf(LValue) then
    Result := 0
  else
    Result := platform_get_errno;
end;

function platform_poller_drain_wake(var APoller: TPlatformPoller): Int32;
var
  LValue: UInt64;
  LRead: ssize_t;
begin
  if APoller.WakeFd < 0 then
    Exit(ESysEOPNOTSUPP);
  LRead := read(APoller.WakeFd, @LValue, SizeOf(LValue));
  if LRead = SizeOf(LValue) then
    Exit(0);
  if (LRead < 0) and (platform_get_errno = ESysEAGAIN) then
    Exit(0);
  Result := platform_get_errno;
end;

function platform_poller_wait(var APoller: TPlatformPoller;
  AEntries: PPlatformPollEntry; AMaxEntries: Int32; ATimeoutMs: Int32;
  out ACount: Int32): Int32;
const
  MAX_STACK_EVENTS = 256;
var
  LStackEvents: array[0..MAX_STACK_EVENTS - 1] of epoll_event;
  LHeapEvents: pepoll_event;
  LEvents: pepoll_event;
  LRegistration: PPlatformPollRegistration;
  LN, LI: Int32;
  LNeedFree: Boolean;
begin
  ACount := 0;
  if (AEntries = nil) or (AMaxEntries <= 0) then
    Exit(ESysEINVAL);
  if AMaxEntries <= MAX_STACK_EVENTS then
  begin
    LEvents := @LStackEvents[0];
    LNeedFree := False;
  end
  else
  begin
    LHeapEvents := nil;
    GetMem(LHeapEvents, SizeUInt(AMaxEntries) * SizeOf(epoll_event));
    LEvents := LHeapEvents;
    LNeedFree := True;
  end;
  try
    LN := epoll_wait(APoller.EpollFd, LEvents, AMaxEntries, ATimeoutMs);
    if LN < 0 then
      Exit(platform_get_errno);
    for LI := 0 to LN - 1 do
    begin
      LRegistration := PPlatformPollRegistration(LEvents[LI].data.ptr);
      if LRegistration = nil then
        Exit(ESysEINVAL);
      AEntries[LI].Fd := LRegistration^.Entry.Fd;
      AEntries[LI].Events := LRegistration^.Entry.Events;
      AEntries[LI].REvents := EpollToEvents(LEvents[LI].events);
      AEntries[LI].UserData := LRegistration^.Entry.UserData;
    end;
    ACount := LN;
    Result := 0;
  finally
    if LNeedFree then
      FreeMem(LEvents);
  end;
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

function SetFdNonBlocking(AFd: Int32): Int32;
var
  LFlags: PtrInt;
begin
  LFlags := fcntl(AFd, F_GETFL, 0);
  if LFlags < 0 then
    Exit(platform_get_errno);
  if (LFlags and O_NONBLOCK) <> 0 then
    Exit(0);
  if fcntl(AFd, F_SETFL, LFlags or O_NONBLOCK) < 0 then
    Exit(platform_get_errno);
  Result := 0;
end;

function SetFdCloseOnExec(AFd: Int32): Int32;
var
  LFlags: PtrInt;
begin
  LFlags := fcntl(AFd, F_GETFD, 0);
  if LFlags < 0 then
    Exit(platform_get_errno);
  if (LFlags and FD_CLOEXEC) <> 0 then
    Exit(0);
  if fcntl(AFd, F_SETFD, LFlags or FD_CLOEXEC) < 0 then
    Exit(platform_get_errno);
  Result := 0;
end;

function platform_poller_create(out APoller: TPlatformPoller): Int32;
begin
  FillChar(APoller, SizeOf(APoller), 0);
  APoller.KqueueFd := -1;
  APoller.WakeReadFd := -1;
  APoller.WakeWriteFd := -1;
  APoller.KqueueFd := kqueue;
  if APoller.KqueueFd < 0 then
    Result := platform_get_errno
  else
    Result := 0;
end;

function platform_poller_close(var APoller: TPlatformPoller): Int32;
begin
  if APoller.WakeReadFd >= 0 then
  begin
    close(APoller.WakeReadFd);
    APoller.WakeReadFd := -1;
  end;
  if APoller.WakeWriteFd >= 0 then
  begin
    close(APoller.WakeWriteFd);
    APoller.WakeWriteFd := -1;
  end;
  if APoller.KqueueFd >= 0 then
  begin
    close(APoller.KqueueFd);
    APoller.KqueueFd := -1;
    Result := 0;
  end
  else
    Result := platform_get_errno;
end;

function platform_poller_add(var APoller: TPlatformPoller; AFd: PtrUInt;
  AEvents: TPlatformPollEvents; AUserData: Pointer): Int32;
var
  LChanges: array[0..1] of TKEvent;
  LCount: Int32;
begin
  LCount := 0;
  if peReadable in AEvents then
  begin
    FillChar(LChanges[LCount], SizeOf(TKEvent), 0);
    LChanges[LCount].Ident := AFd;
    LChanges[LCount].Filter := EVFILT_READ;
    LChanges[LCount].Flags := EV_ADD or EV_CLEAR;
    LChanges[LCount].uData := AUserData;
    Inc(LCount);
  end;
  if peWritable in AEvents then
  begin
    FillChar(LChanges[LCount], SizeOf(TKEvent), 0);
    LChanges[LCount].Ident := AFd;
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

function platform_poller_modify(var APoller: TPlatformPoller; AFd: PtrUInt;
  AEvents: TPlatformPollEvents; AUserData: Pointer): Int32;
begin
  platform_poller_remove(APoller, AFd);
  Result := platform_poller_add(APoller, AFd, AEvents, AUserData);
end;

function platform_poller_remove(var APoller: TPlatformPoller; AFd: PtrUInt): Int32;
var
  LChanges: array[0..1] of TKEvent;
begin
  FillChar(LChanges, SizeOf(LChanges), 0);
  LChanges[0].Ident := AFd;
  LChanges[0].Filter := EVFILT_READ;
  LChanges[0].Flags := EV_DELETE;
  LChanges[1].Ident := AFd;
  LChanges[1].Filter := EVFILT_WRITE;
  LChanges[1].Flags := EV_DELETE;
  kevent(APoller.KqueueFd, @LChanges[0], 2, nil, 0, nil);
  Result := 0;
end;

function platform_poller_wait(var APoller: TPlatformPoller;
  AEntries: PPlatformPollEntry; AMaxEntries: Int32; ATimeoutMs: Int32;
  out ACount: Int32): Int32;
var
  LEvents: PKEvent;
  LN, LI: Int32;
  LTimeout: timespec;
  LTimeoutPtr: Pointer;
begin
  ACount := 0;
  if (AEntries = nil) or (AMaxEntries <= 0) then
    Exit(ESysEINVAL);
  if ATimeoutMs < 0 then
    LTimeoutPtr := nil
  else
  begin
    LTimeout.tv_sec := ATimeoutMs div 1000;
    LTimeout.tv_nsec := (ATimeoutMs mod 1000) * 1000000;
    LTimeoutPtr := @LTimeout;
  end;
  LEvents := nil;
  GetMem(LEvents, SizeUInt(AMaxEntries) * SizeOf(TKEvent));
  try
    LN := kevent(APoller.KqueueFd, nil, 0, LEvents, AMaxEntries, LTimeoutPtr);
    if LN < 0 then
      Exit(platform_get_errno);
    for LI := 0 to LN - 1 do
    begin
      AEntries[LI].Fd := LEvents[LI].Ident;
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
  finally
    FreeMem(LEvents);
  end;
end;

function platform_poller_enable_wake(var APoller: TPlatformPoller;
  AUserData: Pointer): Int32;
var
  LFds: array[0..1] of Int32;
  LErrno: Int32;
begin
  if (APoller.WakeReadFd >= 0) and (APoller.WakeWriteFd >= 0) then
    Exit(0);

  if APoller.WakeReadFd >= 0 then
  begin
    close(APoller.WakeReadFd);
    APoller.WakeReadFd := -1;
  end;
  if APoller.WakeWriteFd >= 0 then
  begin
    close(APoller.WakeWriteFd);
    APoller.WakeWriteFd := -1;
  end;

  LFds[0] := -1;
  LFds[1] := -1;
  if pipe(@LFds[0]) <> 0 then
    Exit(platform_get_errno);
  LErrno := SetFdNonBlocking(LFds[0]);
  if LErrno <> 0 then
  begin
    Result := LErrno;
    close(LFds[0]);
    close(LFds[1]);
    Exit(Result);
  end;
  LErrno := SetFdNonBlocking(LFds[1]);
  if LErrno <> 0 then
  begin
    Result := LErrno;
    close(LFds[0]);
    close(LFds[1]);
    Exit(Result);
  end;
  LErrno := SetFdCloseOnExec(LFds[0]);
  if LErrno <> 0 then
  begin
    Result := LErrno;
    close(LFds[0]);
    close(LFds[1]);
    Exit(Result);
  end;
  LErrno := SetFdCloseOnExec(LFds[1]);
  if LErrno <> 0 then
  begin
    Result := LErrno;
    close(LFds[0]);
    close(LFds[1]);
    Exit(Result);
  end;

  APoller.WakeReadFd := LFds[0];
  APoller.WakeWriteFd := LFds[1];
  Result := platform_poller_add(APoller, APoller.WakeReadFd, [peReadable],
    AUserData);
  if Result <> 0 then
  begin
    close(APoller.WakeReadFd);
    close(APoller.WakeWriteFd);
    APoller.WakeReadFd := -1;
    APoller.WakeWriteFd := -1;
  end;
end;

function platform_poller_wake(var APoller: TPlatformPoller): Int32;
var
  LByte: Byte;
  LWritten: ssize_t;
  LErrno: Int32;
begin
  if APoller.WakeWriteFd < 0 then
    Exit(ESysEOPNOTSUPP);
  LByte := 1;
  repeat
    LWritten := write(APoller.WakeWriteFd, @LByte, 1);
    if LWritten = 1 then
      Exit(0);
    if LWritten >= 0 then
      Exit(ESysEIO);
    LErrno := platform_get_errno;
    if (LErrno = ESysEAGAIN) or (LErrno = ESysEWOULDBLOCK) then
      Exit(0);
    if LErrno <> ESysEINTR then
      Exit(LErrno);
  until False;
end;

function platform_poller_drain_wake(var APoller: TPlatformPoller): Int32;
var
  LBuffer: array[0..63] of Byte;
  LRead: ssize_t;
  LErrno: Int32;
begin
  if APoller.WakeReadFd < 0 then
    Exit(ESysEOPNOTSUPP);
  repeat
    LRead := read(APoller.WakeReadFd, @LBuffer[0], SizeOf(LBuffer));
    if LRead > 0 then
      Continue;
    if LRead = 0 then
      Exit(0);
    LErrno := platform_get_errno;
    if (LErrno = ESysEAGAIN) or (LErrno = ESysEWOULDBLOCK) then
      Exit(0);
    if LErrno <> ESysEINTR then
      Exit(LErrno);
  until False;
end;
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.windows.base,
  nextpas.core.platform.windows.ffi;

const
  WINDOWS_INVALID_POLL_SOCKET = PtrUInt(not PtrUInt(0));

type
  PPlatformPollEntryArray = ^TPlatformPollEntryArray;
  TPlatformPollEntryArray = array[0..MaxInt div SizeOf(TPlatformPollEntry) - 1] of TPlatformPollEntry;

  PWSAPollFdArray = ^TWSAPollFdArray;
  TWSAPollFdArray = array[0..MaxInt div SizeOf(TWSAPollFd) - 1] of TWSAPollFd;

function WindowsSocketError: Int32; inline;
begin
  Result := Int32(WSAGetLastError);
end;

function EnsureWinsockReady: Int32;
var
  LData: TWSAData;
begin
  if WSAStartup($0202, @LData) = 0 then
    Result := 0
  else
    Result := WindowsSocketError;
end;

function WindowsEventsToPoll(AEvents: TPlatformPollEvents): Int16;
begin
  Result := 0;
  if peReadable in AEvents then
    Result := Result or POLLIN;
  if peWritable in AEvents then
    Result := Result or POLLOUT;
end;

function WindowsPollToEvents(AEvents: Int16): TPlatformPollEvents;
begin
  Result := [];
  if (AEvents and (POLLIN or POLLRDNORM or POLLRDBAND)) <> 0 then
    Include(Result, peReadable);
  if (AEvents and (POLLOUT or POLLWRNORM or POLLWRBAND)) <> 0 then
    Include(Result, peWritable);
  if (AEvents and (POLLERR or POLLNVAL)) <> 0 then
    Include(Result, peError);
  if (AEvents and POLLHUP) <> 0 then
    Include(Result, peHangup);
end;

function WindowsPollEntries(var APoller: TPlatformPoller): PPlatformPollEntryArray;
begin
  Result := PPlatformPollEntryArray(APoller.Entries);
end;

function WindowsFindPollEntry(var APoller: TPlatformPoller; AFd: PtrUInt): Int32;
var
  LEntries: PPlatformPollEntryArray;
  LI: Int32;
begin
  LEntries := WindowsPollEntries(APoller);
  for LI := 0 to APoller.Count - 1 do
    if LEntries^[LI].Fd = AFd then
      Exit(LI);
  Result := -1;
end;

function WindowsEnsurePollCapacity(var APoller: TPlatformPoller;
  ACapacity: Int32): Int32;
var
  LNewCapacity: Int32;
  LNewEntries: Pointer;
  LBytes: SizeUInt;
begin
  if ACapacity <= APoller.Capacity then
    Exit(0);
  LNewCapacity := APoller.Capacity;
  if LNewCapacity < 8 then
    LNewCapacity := 8;
  while LNewCapacity < ACapacity do
    LNewCapacity := LNewCapacity * 2;
  LBytes := SizeUInt(LNewCapacity) * SizeOf(TPlatformPollEntry);
  GetMem(LNewEntries, LBytes);
  if LNewEntries = nil then
    Exit(Int32(ERROR_NOT_ENOUGH_MEMORY));
  FillChar(LNewEntries^, LBytes, 0);
  if (APoller.Entries <> nil) and (APoller.Count > 0) then
    Move(APoller.Entries^, LNewEntries^,
      SizeUInt(APoller.Count) * SizeOf(TPlatformPollEntry));
  if APoller.Entries <> nil then
    FreeMem(APoller.Entries);
  APoller.Entries := LNewEntries;
  APoller.Capacity := LNewCapacity;
  Result := 0;
end;

procedure WindowsCloseSocketValue(var ASocket: PtrUInt);
begin
  if ASocket <> WINDOWS_INVALID_POLL_SOCKET then
  begin
    closesocket(TSocket(ASocket));
    ASocket := WINDOWS_INVALID_POLL_SOCKET;
  end;
end;

function WindowsSetSocketNonBlocking(ASocket: PtrUInt): Int32;
var
  LNonBlock: DWORD;
begin
  LNonBlock := 1;
  if ioctlsocket(TSocket(ASocket), FIONBIO, @LNonBlock) = 0 then
    Result := 0
  else
    Result := WindowsSocketError;
end;

function WindowsCreateWakePair(out AReadSocket, AWriteSocket: PtrUInt): Int32;
var
  LListener: TSocket;
  LRead: TSocket;
  LWrite: TSocket;
  LAddr: sockaddr_in;
  LLen: Int32;
begin
  AReadSocket := WINDOWS_INVALID_POLL_SOCKET;
  AWriteSocket := WINDOWS_INVALID_POLL_SOCKET;
  LListener := TSocket(WINDOWS_INVALID_POLL_SOCKET);
  LRead := TSocket(WINDOWS_INVALID_POLL_SOCKET);
  LWrite := TSocket(WINDOWS_INVALID_POLL_SOCKET);

  LListener := winsock_socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if LListener = TSocket(WINDOWS_INVALID_POLL_SOCKET) then
    Exit(WindowsSocketError);
  try
    FillChar(LAddr, SizeOf(LAddr), 0);
    LAddr.sin_family := AF_INET;
    LAddr.sin_port := 0;
    LAddr.sin_addr.s_addr := htonl($7F000001);
    if winsock_bind(LListener, @LAddr, SizeOf(LAddr)) <> 0 then
      Exit(WindowsSocketError);
    if winsock_listen(LListener, 1) <> 0 then
      Exit(WindowsSocketError);

    LLen := SizeOf(LAddr);
    if winsock_getsockname(LListener, @LAddr, @LLen) <> 0 then
      Exit(WindowsSocketError);

    LWrite := winsock_socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if LWrite = TSocket(WINDOWS_INVALID_POLL_SOCKET) then
      Exit(WindowsSocketError);
    if winsock_connect(LWrite, @LAddr, SizeOf(LAddr)) <> 0 then
      Exit(WindowsSocketError);

    LRead := winsock_accept(LListener, nil, nil);
    if LRead = TSocket(WINDOWS_INVALID_POLL_SOCKET) then
      Exit(WindowsSocketError);

    AReadSocket := PtrUInt(LRead);
    AWriteSocket := PtrUInt(LWrite);
    LRead := TSocket(WINDOWS_INVALID_POLL_SOCKET);
    LWrite := TSocket(WINDOWS_INVALID_POLL_SOCKET);

    Result := WindowsSetSocketNonBlocking(AReadSocket);
    if Result <> 0 then
      Exit(Result);
    Result := WindowsSetSocketNonBlocking(AWriteSocket);
    if Result <> 0 then
      Exit(Result);
  finally
    if LRead <> TSocket(WINDOWS_INVALID_POLL_SOCKET) then
      closesocket(LRead);
    if LWrite <> TSocket(WINDOWS_INVALID_POLL_SOCKET) then
      closesocket(LWrite);
    closesocket(LListener);
    if Result <> 0 then
    begin
      WindowsCloseSocketValue(AReadSocket);
      WindowsCloseSocketValue(AWriteSocket);
    end;
  end;
end;

function platform_poller_create(out APoller: TPlatformPoller): Int32;
begin
  FillChar(APoller, SizeOf(APoller), 0);
  APoller.WakeReadSocket := WINDOWS_INVALID_POLL_SOCKET;
  APoller.WakeWriteSocket := WINDOWS_INVALID_POLL_SOCKET;
  Result := EnsureWinsockReady;
  APoller.WinsockStarted := Result = 0;
end;

function platform_poller_close(var APoller: TPlatformPoller): Int32;
begin
  WindowsCloseSocketValue(APoller.WakeReadSocket);
  WindowsCloseSocketValue(APoller.WakeWriteSocket);
  if APoller.Entries <> nil then
  begin
    FreeMem(APoller.Entries);
    APoller.Entries := nil;
  end;
  APoller.Count := 0;
  APoller.Capacity := 0;
  if APoller.WinsockStarted then
  begin
    WSACleanup;
    APoller.WinsockStarted := False;
  end;
  Result := 0;
end;

function platform_poller_add(var APoller: TPlatformPoller; AFd: PtrUInt;
  AEvents: TPlatformPollEvents; AUserData: Pointer): Int32;
var
  LEntries: PPlatformPollEntryArray;
begin
  if AFd = WINDOWS_INVALID_POLL_SOCKET then
    Exit(Int32(ERROR_INVALID_HANDLE));
  if WindowsFindPollEntry(APoller, AFd) >= 0 then
    Exit(Int32(ERROR_ALREADY_EXISTS));
  Result := WindowsEnsurePollCapacity(APoller, APoller.Count + 1);
  if Result <> 0 then
    Exit(Result);
  LEntries := WindowsPollEntries(APoller);
  LEntries^[APoller.Count].Fd := AFd;
  LEntries^[APoller.Count].Events := AEvents;
  LEntries^[APoller.Count].REvents := [];
  LEntries^[APoller.Count].UserData := AUserData;
  Inc(APoller.Count);
  Result := 0;
end;

function platform_poller_modify(var APoller: TPlatformPoller; AFd: PtrUInt;
  AEvents: TPlatformPollEvents; AUserData: Pointer): Int32;
var
  LIndex: Int32;
  LEntries: PPlatformPollEntryArray;
begin
  LIndex := WindowsFindPollEntry(APoller, AFd);
  if LIndex < 0 then
    Exit(Int32(ERROR_NOT_FOUND));
  LEntries := WindowsPollEntries(APoller);
  LEntries^[LIndex].Events := AEvents;
  LEntries^[LIndex].UserData := AUserData;
  LEntries^[LIndex].REvents := [];
  Result := 0;
end;

function platform_poller_remove(var APoller: TPlatformPoller; AFd: PtrUInt): Int32;
var
  LIndex: Int32;
  LEntries: PPlatformPollEntryArray;
  LMoveCount: Int32;
begin
  LIndex := WindowsFindPollEntry(APoller, AFd);
  if LIndex < 0 then
    Exit(Int32(ERROR_NOT_FOUND));
  LEntries := WindowsPollEntries(APoller);
  LMoveCount := APoller.Count - LIndex - 1;
  if LMoveCount > 0 then
    Move(LEntries^[LIndex + 1], LEntries^[LIndex],
      SizeUInt(LMoveCount) * SizeOf(TPlatformPollEntry));
  Dec(APoller.Count);
  FillChar(LEntries^[APoller.Count], SizeOf(TPlatformPollEntry), 0);
  Result := 0;
end;

function platform_poller_enable_wake(var APoller: TPlatformPoller;
  AUserData: Pointer): Int32;
var
  LReadSocket: PtrUInt;
  LWriteSocket: PtrUInt;
begin
  if (APoller.WakeReadSocket <> WINDOWS_INVALID_POLL_SOCKET) and
     (APoller.WakeWriteSocket <> WINDOWS_INVALID_POLL_SOCKET) then
    Exit(0);

  Result := WindowsCreateWakePair(LReadSocket, LWriteSocket);
  if Result <> 0 then
    Exit(Result);
  APoller.WakeReadSocket := LReadSocket;
  APoller.WakeWriteSocket := LWriteSocket;
  Result := platform_poller_add(APoller, APoller.WakeReadSocket,
    [peReadable], AUserData);
  if Result <> 0 then
  begin
    WindowsCloseSocketValue(APoller.WakeReadSocket);
    WindowsCloseSocketValue(APoller.WakeWriteSocket);
  end;
end;

function platform_poller_wake(var APoller: TPlatformPoller): Int32;
var
  LByte: Byte;
  LSent: LongInt;
  LErr: Int32;
begin
  if APoller.WakeWriteSocket = WINDOWS_INVALID_POLL_SOCKET then
    Exit(Int32(ERROR_NOT_SUPPORTED));
  LByte := 1;
  LSent := winsock_send(TSocket(APoller.WakeWriteSocket), @LByte, 1, 0);
  if LSent = 1 then
    Exit(0);
  LErr := WindowsSocketError;
  if LErr = WSAEWOULDBLOCK then
    Exit(0);
  Result := LErr;
end;

function platform_poller_drain_wake(var APoller: TPlatformPoller): Int32;
var
  LBuffer: array[0..63] of Byte;
  LRead: LongInt;
  LErr: Int32;
begin
  if APoller.WakeReadSocket = WINDOWS_INVALID_POLL_SOCKET then
    Exit(Int32(ERROR_NOT_SUPPORTED));
  repeat
    LRead := winsock_recv(TSocket(APoller.WakeReadSocket), @LBuffer[0],
      SizeOf(LBuffer), 0);
    if LRead > 0 then
      Continue;
    if LRead = 0 then
      Exit(0);
    LErr := WindowsSocketError;
    if LErr = WSAEWOULDBLOCK then
      Exit(0);
    Result := LErr;
    Exit;
  until False;
end;

function platform_poller_wait(var APoller: TPlatformPoller;
  AEntries: PPlatformPollEntry; AMaxEntries: Int32; ATimeoutMs: Int32;
  out ACount: Int32): Int32;
var
  LPollFds: PWSAPollFdArray;
  LEntries: PPlatformPollEntryArray;
  LReady: LongInt;
  LI: Int32;
begin
  ACount := 0;
  if (AEntries = nil) or (AMaxEntries <= 0) then
    Exit(Int32(ERROR_INVALID_PARAMETER));
  if APoller.Count <= 0 then
    Exit(0);

  LPollFds := nil;
  GetMem(LPollFds, SizeUInt(APoller.Count) * SizeOf(TWSAPollFd));
  try
    LEntries := WindowsPollEntries(APoller);
    for LI := 0 to APoller.Count - 1 do
    begin
      LPollFds^[LI].fd := TSocket(LEntries^[LI].Fd);
      LPollFds^[LI].events := WindowsEventsToPoll(LEntries^[LI].Events);
      LPollFds^[LI].revents := 0;
    end;

    LReady := WSAPoll(PWSAPollFd(LPollFds), ULONG(APoller.Count), ATimeoutMs);
    if LReady < 0 then
      Exit(WindowsSocketError);
    if LReady = 0 then
      Exit(0);

    for LI := 0 to APoller.Count - 1 do
    begin
      if LPollFds^[LI].revents = 0 then
        Continue;
      if ACount >= AMaxEntries then
        Break;
      AEntries[ACount].Fd := LEntries^[LI].Fd;
      AEntries[ACount].Events := LEntries^[LI].Events;
      AEntries[ACount].REvents := WindowsPollToEvents(LPollFds^[LI].revents);
      AEntries[ACount].UserData := LEntries^[LI].UserData;
      Inc(ACount);
    end;
    Result := 0;
  finally
    FreeMem(LPollFds);
  end;
end;
{$ENDIF}

{$IF not defined(NEXTPAS_LINUX) and not defined(NEXTPAS_MACOS) and not defined(NEXTPAS_FREEBSD) and not defined(NEXTPAS_WINDOWS)}
function platform_poller_create(out APoller: TPlatformPoller): Int32; begin FillChar(APoller, SizeOf(APoller), 0); Result := -1; end;
function platform_poller_close(var APoller: TPlatformPoller): Int32; begin Result := -1; end;
function platform_poller_add(var APoller: TPlatformPoller; AFd: PtrUInt; AEvents: TPlatformPollEvents; AUserData: Pointer): Int32; begin Result := -1; end;
function platform_poller_modify(var APoller: TPlatformPoller; AFd: PtrUInt; AEvents: TPlatformPollEvents; AUserData: Pointer): Int32; begin Result := -1; end;
function platform_poller_remove(var APoller: TPlatformPoller; AFd: PtrUInt): Int32; begin Result := -1; end;
function platform_poller_enable_wake(var APoller: TPlatformPoller; AUserData: Pointer): Int32; begin Result := -1; end;
function platform_poller_wake(var APoller: TPlatformPoller): Int32; begin Result := -1; end;
function platform_poller_drain_wake(var APoller: TPlatformPoller): Int32; begin Result := -1; end;
function platform_poller_wait(var APoller: TPlatformPoller; AEntries: PPlatformPollEntry; AMaxEntries: Int32; ATimeoutMs: Int32; out ACount: Int32): Int32; begin ACount := 0; Result := -1; end;
{$ENDIF}

end.
