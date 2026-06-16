unit nextpas.core.io.reactor.epoll;

{$I nextpas.core.settings.inc}

interface

uses nextpas.core.atomic, nextpas.core.errors, nextpas.core.platform.posix.base, nextpas.core.platform.posix.ffi, nextpas.core.platform.linux.base, nextpas.core.platform.linux.ffi;

type
  TIoCompletion = procedure(AUserData: UInt64; AResult: Int32; AContext: Pointer);

  TEpollOpKind = (
    opRead,
    opWrite,
    opAccept,
    opConnect,
    opSend,
    opRecv,
    opClose
  );

  TEpollPendingOp = record
    Kind: TEpollOpKind;
    Fd: Int32;
    Buf: Pointer;
    Len: UInt32;
    Offset: Int64;
    Flags: Int32;
    Addr: Pointer;
    AddrLen: Pointer;
    AddrLenVal: UInt32;
    Callback: TIoCompletion;
    Context: Pointer;
    NextFree: Int32;
    Active: Boolean;
  end;

  TEpollReactor = record
  private
    FEpfd: Int32;
    FMaxEvents: UInt32;
    FEvents: array of epoll_event;
    FOps: array of TEpollPendingOp;
    FOpCount: UInt32;
    FOpCap: UInt32;
    FPendingCount: UInt32;
    FFreeHead: Int32;
    FRunning: Int32;
    function AllocOp(AKind: TEpollOpKind; AFd: Int32; ABuf: Pointer;
      ALen: UInt32; AOffset: Int64; AFlags: Int32; AAddr: Pointer;
      AAddrLen: Pointer; AAddrLenVal: UInt32;
      ACallback: TIoCompletion; AContext: Pointer): Int32;
    procedure FreeOp(AIdx: Int32);
    function SetNonBlocking(AFd: Int32): Boolean;
    function RegisterFd(AFd: Int32; AEvents: UInt32; AData: UInt64): Boolean;
    function ModifyFd(AFd: Int32; AEvents: UInt32; AData: UInt64): Boolean;
    procedure RemoveFd(AFd: Int32);
    procedure ReleasePendingOps(AResult: Int32);
    procedure DispatchEvent(const AEv: epoll_event);
    procedure ExecuteOp(AIdx: Int32);
  public
    class function Create(AMaxEvents: UInt32 = 64): TEpollReactor; static;
    procedure Close;
    function IsValid: Boolean; inline;

    function AsyncRead(AFd: Int32; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncWrite(AFd: Int32; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncAccept(AFd: Int32; AAddr: Pointer; AAddrLen: Pointer; AFlags: Int32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncConnect(AFd: Int32; AAddr: Pointer; AAddrLen: UInt32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncSend(AFd: Int32; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncRecv(AFd: Int32; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncClose(AFd: Int32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;

    function Poll: Int32;
    function PollOne: Boolean;
    procedure Run;
    procedure Stop;
    function Flush: Int32;
    function HasPending: Boolean;
  end;

implementation


const
  INITIAL_OPS = 256;
  EAGAIN      = 11;
  EINTR       = 4;
  EINPROGRESS = 115;

type
  TEpollPendingRelease = record
    Callback: TIoCompletion;
    Context: Pointer;
    UserData: UInt64;
  end;

function EpollResultFromSyscall(AResult: SizeInt): Int32; inline;
begin
  if AResult >= 0 then
    Exit(Int32(AResult));
  Result := -platform_get_errno;
end;

class function TEpollReactor.Create(AMaxEvents: UInt32): TEpollReactor;
begin
  Result := Default(TEpollReactor);
  Result.FEpfd := epoll_create1(EPOLL_CLOEXEC);
  if Result.FEpfd < 0 then Exit;
  Result.FMaxEvents := AMaxEvents;
  SetLength(Result.FEvents, AMaxEvents);
  Result.FOpCap := INITIAL_OPS;
  SetLength(Result.FOps, INITIAL_OPS);
  Result.FOpCount := 0;
  Result.FPendingCount := 0;
  Result.FFreeHead := -1;
  AtomicStore32(Result.FRunning, 0, moRelease);
end;

procedure TEpollReactor.Close;
begin
  AtomicStore32(FRunning, 0, moRelease);
  try
    ReleasePendingOps(-ESysECANCELED);
  finally
    if FEpfd >= 0 then
    begin
      nextpas.core.platform.posix.ffi.close(FEpfd);
      FEpfd := -1;
    end;
    SetLength(FEvents, 0);
    SetLength(FOps, 0);
    FOpCount := 0;
    FOpCap := 0;
    FPendingCount := 0;
    FFreeHead := -1;
  end;
end;

function TEpollReactor.IsValid: Boolean;
begin
  Result := FEpfd >= 0;
end;

function TEpollReactor.AllocOp(AKind: TEpollOpKind; AFd: Int32; ABuf: Pointer;
  ALen: UInt32; AOffset: Int64; AFlags: Int32; AAddr: Pointer;
  AAddrLen: Pointer; AAddrLenVal: UInt32;
  ACallback: TIoCompletion; AContext: Pointer): Int32;
var
  LIdx: UInt32;
begin
  if FFreeHead >= 0 then
  begin
    LIdx := UInt32(FFreeHead);
    FFreeHead := FOps[LIdx].NextFree;
  end
  else
  begin
    if FOpCount >= FOpCap then
    begin
      FOpCap := FOpCap * 2;
      SetLength(FOps, FOpCap);
    end;
    LIdx := FOpCount;
    Inc(FOpCount);
  end;
  FOps[LIdx].Kind := AKind;
  FOps[LIdx].Fd := AFd;
  FOps[LIdx].Buf := ABuf;
  FOps[LIdx].Len := ALen;
  FOps[LIdx].Offset := AOffset;
  FOps[LIdx].Flags := AFlags;
  FOps[LIdx].Addr := AAddr;
  FOps[LIdx].AddrLen := AAddrLen;
  FOps[LIdx].AddrLenVal := AAddrLenVal;
  FOps[LIdx].Callback := ACallback;
  FOps[LIdx].Context := AContext;
  FOps[LIdx].NextFree := -1;
  FOps[LIdx].Active := True;
  Inc(FPendingCount);
  Result := Int32(LIdx);
end;

procedure TEpollReactor.FreeOp(AIdx: Int32);
begin
  if (AIdx < 0) or (UInt32(AIdx) >= FOpCount) then Exit;
  if not FOps[AIdx].Active then
    Exit;
  if FPendingCount > 0 then
    Dec(FPendingCount);
  FOps[AIdx].Callback := nil;
  FOps[AIdx].Context := nil;
  FOps[AIdx].Active := False;
  FOps[AIdx].NextFree := FFreeHead;
  FFreeHead := AIdx;
end;

function TEpollReactor.SetNonBlocking(AFd: Int32): Boolean;
var
  LFlags: Int32;
begin
  LFlags := fcntl(AFd, F_GETFL, 0);
  if LFlags < 0 then begin Result := False; Exit; end;
  if (LFlags and O_NONBLOCK) <> 0 then begin Result := True; Exit; end;
  Result := fcntl(AFd, F_SETFL, LFlags or O_NONBLOCK) >= 0;
end;

function TEpollReactor.RegisterFd(AFd: Int32; AEvents: UInt32; AData: UInt64): Boolean;
var
  LEv: epoll_event;
begin
  LEv.events := AEvents;
  LEv.data.u64 := AData;
  Result := epoll_ctl(FEpfd, EPOLL_CTL_ADD, AFd, @LEv) = 0;
end;

function TEpollReactor.ModifyFd(AFd: Int32; AEvents: UInt32; AData: UInt64): Boolean;
var
  LEv: epoll_event;
begin
  LEv.events := AEvents;
  LEv.data.u64 := AData;
  Result := epoll_ctl(FEpfd, EPOLL_CTL_MOD, AFd, @LEv) = 0;
end;

procedure TEpollReactor.RemoveFd(AFd: Int32);
var
  LEv: epoll_event;
begin
  if FEpfd < 0 then
    Exit;
  FillChar(LEv, SizeOf(LEv), 0);
  epoll_ctl(FEpfd, EPOLL_CTL_DEL, AFd, @LEv);
end;

procedure TEpollReactor.ReleasePendingOps(AResult: Int32);
var
  LI: UInt32;
  LReleaseCount: UInt32;
  LReleases: array of TEpollPendingRelease;
  LHasException: Boolean;
  LExceptionMessage: string;
begin
  if FPendingCount = 0 then
    Exit;
  SetLength(LReleases, FOpCount);
  LReleaseCount := 0;
  for LI := 0 to FOpCount - 1 do
  begin
    if not FOps[LI].Active then
      Continue;
    RemoveFd(FOps[LI].Fd);
    if Assigned(FOps[LI].Callback) then
    begin
      LReleases[LReleaseCount].Callback := FOps[LI].Callback;
      LReleases[LReleaseCount].Context := FOps[LI].Context;
      LReleases[LReleaseCount].UserData := UInt64(LI);
      Inc(LReleaseCount);
    end;
    FOps[LI].Callback := nil;
    FOps[LI].Context := nil;
    FOps[LI].Active := False;
    FOps[LI].NextFree := -1;
  end;
  FOpCount := 0;
  FPendingCount := 0;
  FFreeHead := -1;
  if LReleaseCount = 0 then
    Exit;
  LHasException := False;
  LExceptionMessage := '';
  if FEpfd >= 0 then
  begin
    nextpas.core.platform.posix.ffi.close(FEpfd);
    FEpfd := -1;
  end;
  for LI := 0 to LReleaseCount - 1 do
  begin
    try
      LReleases[LI].Callback(LReleases[LI].UserData, AResult,
        LReleases[LI].Context);
    except
      on E: Exception do
      begin
        if not LHasException then
        begin
          LHasException := True;
          LExceptionMessage := E.Message;
        end;
      end;
    end;
  end;
  if LHasException then
    raise Exception.Create(LExceptionMessage);
end;

procedure TEpollReactor.ExecuteOp(AIdx: Int32);
var
  LRes: SizeInt;
  LRes32: Int32;
  LOptVal: Int32;
  LOptLen: UInt32;
  LCallback: TIoCompletion;
  LContext: Pointer;
begin
  LCallback := FOps[AIdx].Callback;
  LContext := FOps[AIdx].Context;
  case FOps[AIdx].Kind of
    opRead:
    begin
      if FOps[AIdx].Offset >= 0 then
        LRes := pread(FOps[AIdx].Fd, FOps[AIdx].Buf, FOps[AIdx].Len, FOps[AIdx].Offset)
      else
        LRes := read(FOps[AIdx].Fd, FOps[AIdx].Buf, FOps[AIdx].Len);
      LRes32 := EpollResultFromSyscall(LRes);
      RemoveFd(FOps[AIdx].Fd);
      FreeOp(AIdx);
      if Assigned(LCallback) then
        LCallback(UInt64(AIdx), LRes32, LContext);
    end;

    opWrite:
    begin
      if FOps[AIdx].Offset >= 0 then
        LRes := pwrite(FOps[AIdx].Fd, FOps[AIdx].Buf, FOps[AIdx].Len, FOps[AIdx].Offset)
      else
        LRes := write(FOps[AIdx].Fd, FOps[AIdx].Buf, FOps[AIdx].Len);
      LRes32 := EpollResultFromSyscall(LRes);
      RemoveFd(FOps[AIdx].Fd);
      FreeOp(AIdx);
      if Assigned(LCallback) then
        LCallback(UInt64(AIdx), LRes32, LContext);
    end;

    opAccept:
    begin
      LRes := accept4(FOps[AIdx].Fd, FOps[AIdx].Addr,
        FOps[AIdx].AddrLen, FOps[AIdx].Flags);
      LRes32 := EpollResultFromSyscall(LRes);
      RemoveFd(FOps[AIdx].Fd);
      FreeOp(AIdx);
      if Assigned(LCallback) then
        LCallback(UInt64(AIdx), LRes32, LContext);
    end;

    opConnect:
    begin
      LOptVal := 0;
      LOptLen := SizeOf(LOptVal);
      LRes := getsockopt(FOps[AIdx].Fd, SOL_SOCKET, SO_ERROR, @LOptVal, @LOptLen);
      if LRes < 0 then
        LRes32 := EpollResultFromSyscall(LRes)
      else
      begin
        if LOptVal = 0 then
          LRes32 := 0
        else
          LRes32 := -LOptVal;
      end;
      RemoveFd(FOps[AIdx].Fd);
      FreeOp(AIdx);
      if Assigned(LCallback) then
        LCallback(UInt64(AIdx), LRes32, LContext);
    end;

    opSend:
    begin
      LRes := send(FOps[AIdx].Fd, FOps[AIdx].Buf, FOps[AIdx].Len, FOps[AIdx].Flags);
      LRes32 := EpollResultFromSyscall(LRes);
      RemoveFd(FOps[AIdx].Fd);
      FreeOp(AIdx);
      if Assigned(LCallback) then
        LCallback(UInt64(AIdx), LRes32, LContext);
    end;

    opRecv:
    begin
      LRes := recv(FOps[AIdx].Fd, FOps[AIdx].Buf, FOps[AIdx].Len, FOps[AIdx].Flags);
      LRes32 := EpollResultFromSyscall(LRes);
      RemoveFd(FOps[AIdx].Fd);
      FreeOp(AIdx);
      if Assigned(LCallback) then
        LCallback(UInt64(AIdx), LRes32, LContext);
    end;

    opClose:
    begin
      LRes := nextpas.core.platform.posix.ffi.close(FOps[AIdx].Fd);
      LRes32 := EpollResultFromSyscall(LRes);
      FreeOp(AIdx);
      if Assigned(LCallback) then
        LCallback(UInt64(AIdx), LRes32, LContext);
    end;
  end;
end;

procedure TEpollReactor.DispatchEvent(const AEv: epoll_event);
var
  LIdx: Int32;
begin
  LIdx := Int32(AEv.data.u64);
  if (LIdx < 0) or (UInt32(LIdx) >= FOpCount) then Exit;
  if not FOps[LIdx].Active then Exit;
  ExecuteOp(LIdx);
end;

function TEpollReactor.AsyncRead(AFd: Int32; ABuf: Pointer; ALen: UInt32;
  AOffset: Int64; ACallback: TIoCompletion; AContext: Pointer): Boolean;
var
  LIdx: Int32;
begin
  if not IsValid then begin Result := False; Exit; end;
  if AOffset >= 0 then begin Result := False; Exit; end;
  if not SetNonBlocking(AFd) then begin Result := False; Exit; end;
  LIdx := AllocOp(opRead, AFd, ABuf, ALen, AOffset, 0, nil, nil, 0,
    ACallback, AContext);
  Result := RegisterFd(AFd, EPOLLIN or EPOLLET or EPOLLONESHOT, UInt64(LIdx));
  if not Result then FreeOp(LIdx);
end;

function TEpollReactor.AsyncWrite(AFd: Int32; ABuf: Pointer; ALen: UInt32;
  AOffset: Int64; ACallback: TIoCompletion; AContext: Pointer): Boolean;
var
  LIdx: Int32;
begin
  if not IsValid then begin Result := False; Exit; end;
  if AOffset >= 0 then begin Result := False; Exit; end;
  if not SetNonBlocking(AFd) then begin Result := False; Exit; end;
  LIdx := AllocOp(opWrite, AFd, ABuf, ALen, AOffset, 0, nil, nil, 0,
    ACallback, AContext);
  Result := RegisterFd(AFd, EPOLLOUT or EPOLLET or EPOLLONESHOT, UInt64(LIdx));
  if not Result then FreeOp(LIdx);
end;

function TEpollReactor.AsyncAccept(AFd: Int32; AAddr: Pointer;
  AAddrLen: Pointer; AFlags: Int32; ACallback: TIoCompletion;
  AContext: Pointer): Boolean;
var
  LIdx: Int32;
begin
  if not IsValid then begin Result := False; Exit; end;
  if not SetNonBlocking(AFd) then begin Result := False; Exit; end;
  LIdx := AllocOp(opAccept, AFd, nil, 0, -1, AFlags, AAddr, AAddrLen, 0,
    ACallback, AContext);
  Result := RegisterFd(AFd, EPOLLIN or EPOLLET or EPOLLONESHOT, UInt64(LIdx));
  if not Result then FreeOp(LIdx);
end;

function TEpollReactor.AsyncConnect(AFd: Int32; AAddr: Pointer;
  AAddrLen: UInt32; ACallback: TIoCompletion; AContext: Pointer): Boolean;
var
  LIdx: Int32;
  LRet: Int32;
  LErrno: Int32;
begin
  if not IsValid then begin Result := False; Exit; end;
  if not SetNonBlocking(AFd) then begin Result := False; Exit; end;
  LRet := connect(AFd, AAddr, AAddrLen);
  if LRet = 0 then
  begin
    if Assigned(ACallback) then
      ACallback(0, 0, AContext);
    Result := True;
    Exit;
  end;
  LErrno := __errno_location()^;
  if LErrno <> EINPROGRESS then
  begin
    if Assigned(ACallback) then
      ACallback(0, -LErrno, AContext);
    Result := True;
    Exit;
  end;
  LIdx := AllocOp(opConnect, AFd, nil, 0, -1, 0, AAddr, nil, AAddrLen,
    ACallback, AContext);
  Result := RegisterFd(AFd, EPOLLOUT or EPOLLET or EPOLLONESHOT, UInt64(LIdx));
  if not Result then FreeOp(LIdx);
end;

function TEpollReactor.AsyncSend(AFd: Int32; ABuf: Pointer; ALen: UInt32;
  AFlags: Int32; ACallback: TIoCompletion; AContext: Pointer): Boolean;
var
  LIdx: Int32;
begin
  if not IsValid then begin Result := False; Exit; end;
  if not SetNonBlocking(AFd) then begin Result := False; Exit; end;
  LIdx := AllocOp(opSend, AFd, ABuf, ALen, -1, AFlags, nil, nil, 0,
    ACallback, AContext);
  Result := RegisterFd(AFd, EPOLLOUT or EPOLLET or EPOLLONESHOT, UInt64(LIdx));
  if not Result then FreeOp(LIdx);
end;

function TEpollReactor.AsyncRecv(AFd: Int32; ABuf: Pointer; ALen: UInt32;
  AFlags: Int32; ACallback: TIoCompletion; AContext: Pointer): Boolean;
var
  LIdx: Int32;
begin
  if not IsValid then begin Result := False; Exit; end;
  if not SetNonBlocking(AFd) then begin Result := False; Exit; end;
  LIdx := AllocOp(opRecv, AFd, nil, 0, -1, AFlags, ABuf, nil, ALen,
    ACallback, AContext);
  { Store buf in the Buf field for recv }
  FOps[LIdx].Buf := ABuf;
  FOps[LIdx].Len := ALen;
  Result := RegisterFd(AFd, EPOLLIN or EPOLLET or EPOLLONESHOT, UInt64(LIdx));
  if not Result then FreeOp(LIdx);
end;

function TEpollReactor.AsyncClose(AFd: Int32; ACallback: TIoCompletion;
  AContext: Pointer): Boolean;
var
  LI: UInt32;
  LReleaseCount: UInt32;
  LReleases: array of TEpollPendingRelease;
  LRes: Int32;
  LHasException: Boolean;
  LExceptionMessage: string;
begin
  if not IsValid then begin Result := False; Exit; end;
  { Close is synchronous - epoll cannot watch for close readiness }
  RemoveFd(AFd);
  SetLength(LReleases, FOpCount);
  LReleaseCount := 0;
  if FOpCount > 0 then
  begin
    for LI := 0 to FOpCount - 1 do
    begin
      if (not FOps[LI].Active) or (FOps[LI].Fd <> AFd) then
        Continue;
      if Assigned(FOps[LI].Callback) then
      begin
        LReleases[LReleaseCount].Callback := FOps[LI].Callback;
        LReleases[LReleaseCount].Context := FOps[LI].Context;
        LReleases[LReleaseCount].UserData := UInt64(LI);
        Inc(LReleaseCount);
      end;
      FreeOp(Int32(LI));
    end;
  end;
  LRes := EpollResultFromSyscall(nextpas.core.platform.posix.ffi.close(AFd));
  LHasException := False;
  LExceptionMessage := '';
  if LReleaseCount > 0 then
  begin
    for LI := 0 to LReleaseCount - 1 do
    begin
      try
        LReleases[LI].Callback(LReleases[LI].UserData, -ESysECANCELED,
          LReleases[LI].Context);
      except
        on E: Exception do
        begin
          if not LHasException then
          begin
            LHasException := True;
            LExceptionMessage := E.Message;
          end;
        end;
      end;
    end;
  end;
  if Assigned(ACallback) then
  begin
    try
      ACallback(0, LRes, AContext);
    except
      on E: Exception do
      begin
        if not LHasException then
        begin
          LHasException := True;
          LExceptionMessage := E.Message;
        end;
      end;
    end;
  end;
  if LHasException then
    raise Exception.Create(LExceptionMessage);
  Result := True;
end;

function TEpollReactor.Flush: Int32;
begin
  { epoll operations are registered immediately, no batching needed }
  Result := 0;
end;

function TEpollReactor.HasPending: Boolean;
begin
  Result := FPendingCount > 0;
end;

function TEpollReactor.PollOne: Boolean;
var
  LN: Int32;
begin
  if not IsValid then begin Result := False; Exit; end;
  LN := epoll_wait(FEpfd, @FEvents[0], 1, 0);
  if LN <= 0 then begin Result := False; Exit; end;
  DispatchEvent(FEvents[0]);
  Result := True;
end;

function TEpollReactor.Poll: Int32;
var
  LN, LI: Int32;
begin
  Result := 0;
  if not IsValid then Exit;
  LN := epoll_wait(FEpfd, @FEvents[0], cint(FMaxEvents), 0);
  if LN <= 0 then Exit;
  for LI := 0 to LN - 1 do
    DispatchEvent(FEvents[LI]);
  Result := LN;
end;

procedure TEpollReactor.Run;
var
  LN, LI: Int32;
begin
  if not IsValid then
    Exit;
  AtomicStore32(FRunning, 1, moRelease);
  while AtomicLoad32(FRunning, moAcquire) <> 0 do
  begin
    LN := epoll_wait(FEpfd, @FEvents[0], cint(FMaxEvents), 100);
    if LN < 0 then
    begin
      { libc sets errno; EINTR is normal for signals }
      if __errno_location()^ = EINTR then Continue;
      Break;
    end;
    for LI := 0 to LN - 1 do
    begin
      if AtomicLoad32(FRunning, moAcquire) = 0 then Break;
      DispatchEvent(FEvents[LI]);
    end;
  end;
end;

procedure TEpollReactor.Stop;
begin
  AtomicStore32(FRunning, 0, moRelease);
end;

end.
