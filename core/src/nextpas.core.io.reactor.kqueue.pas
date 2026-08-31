unit nextpas.core.io.reactor.kqueue;

{** @desc kqueue 反应器。写路径不拷贝：ABuf 须保持有效直到回调。
       短写回调 AResult=本次实际送达，不自动续发；一 op 一回调。 *}

{$I nextpas.core.settings.inc}

{$IF defined(NEXTPAS_MACOS) or defined(NEXTPAS_FREEBSD)}
interface

uses
  nextpas.core.io.base,
  nextpas.core.atomic,
  nextpas.core.errors,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.posix.errno
  {$IFDEF NEXTPAS_MACOS}
  , nextpas.core.platform.darwin.base
  , nextpas.core.platform.darwin.ffi
  {$ELSE}
  , nextpas.core.platform.freebsd.base
  , nextpas.core.platform.freebsd.ffi
  {$ENDIF}
  ;

type
  TIoCompletion = nextpas.core.io.base.TIoCompletion;

  TKqueueOpKind = (
    opRead,
    opWrite,
    opAccept,
    opConnect,
    opSend,
    opRecv,
    opSendTo,
    opRecvFrom,
    opClose
  );

  TKqueuePendingOp = record
    Kind: TKqueueOpKind;
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

  { Readiness reactor for macOS/FreeBSD — mirrors TEpollReactor semantics. }
  TKqueueReactor = record
  private
    FKqFd: Int32;
    FMaxEvents: UInt32;
    FEvents: array of TKEvent;
    FOps: array of TKqueuePendingOp;
    FOpCount: UInt32;
    FOpCap: UInt32;
    FPendingCount: UInt32;
    FFreeHead: Int32;
    FRunning: Int32;
    function AllocOp(AKind: TKqueueOpKind; AFd: Int32; ABuf: Pointer;
      ALen: UInt32; AOffset: Int64; AFlags: Int32; AAddr: Pointer;
      AAddrLen: Pointer; AAddrLenVal: UInt32;
      ACallback: TIoCompletion; AContext: Pointer): Int32;
    procedure FreeOp(AIdx: Int32);
    function SetNonBlocking(AFd: Int32): Boolean;
    function RegisterFilter(AFd: Int32; AFilter: Int16; AData: UInt64): Boolean;
    procedure RemoveFilter(AFd: Int32; AFilter: Int16);
    procedure RemoveFd(AFd: Int32);
    procedure ReleasePendingOps(AResult: Int32);
    procedure DispatchEvent(const AEv: TKEvent);
    procedure ExecuteOp(AIdx: Int32);
  public
    class function Create(AMaxEvents: UInt32 = 64): TKqueueReactor; static;
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
    function AsyncSendTo(AFd: Int32; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
      AAddr: Pointer; AAddrLen: UInt32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncRecvFrom(AFd: Int32; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
      AAddr: Pointer; AAddrLen: Pointer;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncClose(AFd: Int32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;

    function Poll: Int32;
    { 阻塞等待至多 ATimeoutMs（-1 = 无限），然后分发就绪事件。
      kqueue server 事件循环用：无事件且无超时目标时挂起省 CPU。 }
    function PollWait(const ATimeoutMs: Int64): Int32;
    function PollOne: Boolean;
    procedure Run;
    procedure Stop;
    function Flush: Int32;
    function HasPending: Boolean;
    { Drop one pending op with matching Context and deliver -ECANCELED. }
    function TryCancelByContext(AContext: Pointer): Boolean;
    function CancelByFd(AFd: Int32): Boolean;
  end;

implementation


const
  INITIAL_OPS = 256;
  EINTR_LOCAL = 4;

type
  TKqueuePendingRelease = record
    Callback: TIoCompletion;
    Context: Pointer;
    UserData: UInt64;
  end;

function KqueueResultFromSyscall(AResult: SizeInt): Int32; inline;
begin
  if AResult >= 0 then
    Exit(Int32(AResult));
  Result := -platform_get_errno;
end;

class function TKqueueReactor.Create(AMaxEvents: UInt32): TKqueueReactor;
begin
  Result := Default(TKqueueReactor);
  Result.FKqFd := kqueue;
  if Result.FKqFd < 0 then
    Exit;
  Result.FMaxEvents := AMaxEvents;
  if Result.FMaxEvents = 0 then
    Result.FMaxEvents := 64;
  SetLength(Result.FEvents, Result.FMaxEvents);
  Result.FOpCap := INITIAL_OPS;
  SetLength(Result.FOps, INITIAL_OPS);
  Result.FOpCount := 0;
  Result.FPendingCount := 0;
  Result.FFreeHead := -1;
  atomic_store(Result.FRunning, 0, mo_release);
end;

procedure TKqueueReactor.Close;
begin
  atomic_store(FRunning, 0, mo_release);
  try
    ReleasePendingOps(-ESysECANCELED);
  finally
    if FKqFd >= 0 then
    begin
      nextpas.core.platform.posix.ffi.close(FKqFd);
      FKqFd := -1;
    end;
    SetLength(FEvents, 0);
    SetLength(FOps, 0);
    FOpCount := 0;
    FOpCap := 0;
    FPendingCount := 0;
    FFreeHead := -1;
  end;
end;

function TKqueueReactor.IsValid: Boolean;
begin
  Result := FKqFd >= 0;
end;

function TKqueueReactor.AllocOp(AKind: TKqueueOpKind; AFd: Int32; ABuf: Pointer;
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

procedure TKqueueReactor.FreeOp(AIdx: Int32);
begin
  if (AIdx < 0) or (UInt32(AIdx) >= FOpCount) then
    Exit;
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

function TKqueueReactor.SetNonBlocking(AFd: Int32): Boolean;
var
  LFlags: Int32;
begin
  LFlags := fcntl(AFd, F_GETFL, 0);
  if LFlags < 0 then
  begin
    Result := False;
    Exit;
  end;
  if (LFlags and O_NONBLOCK) <> 0 then
  begin
    Result := True;
    Exit;
  end;
  Result := fcntl(AFd, F_SETFL, LFlags or O_NONBLOCK) >= 0;
end;

function TKqueueReactor.RegisterFilter(AFd: Int32; AFilter: Int16;
  AData: UInt64): Boolean;
var
  LChange: TKEvent;
begin
  FillChar(LChange, SizeOf(LChange), 0);
  LChange.Ident := PtrUInt(AFd);
  LChange.Filter := AFilter;
  LChange.Flags := EV_ADD or EV_ONESHOT;
  LChange.uData := Pointer(PtrUInt(AData));
  Result := kevent(FKqFd, @LChange, 1, nil, 0, nil) >= 0;
end;

procedure TKqueueReactor.RemoveFilter(AFd: Int32; AFilter: Int16);
var
  LChange: TKEvent;
begin
  if FKqFd < 0 then
    Exit;
  FillChar(LChange, SizeOf(LChange), 0);
  LChange.Ident := PtrUInt(AFd);
  LChange.Filter := AFilter;
  LChange.Flags := EV_DELETE;
  kevent(FKqFd, @LChange, 1, nil, 0, nil);
end;

procedure TKqueueReactor.RemoveFd(AFd: Int32);
var
  LChanges: array[0..1] of TKEvent;
begin
  if FKqFd < 0 then
    Exit;
  FillChar(LChanges, SizeOf(LChanges), 0);
  LChanges[0].Ident := PtrUInt(AFd);
  LChanges[0].Filter := EVFILT_READ;
  LChanges[0].Flags := EV_DELETE;
  LChanges[1].Ident := PtrUInt(AFd);
  LChanges[1].Filter := EVFILT_WRITE;
  LChanges[1].Flags := EV_DELETE;
  kevent(FKqFd, @LChanges[0], 2, nil, 0, nil);
end;

procedure TKqueueReactor.ReleasePendingOps(AResult: Int32);
var
  LI: UInt32;
  LReleaseCount: UInt32;
  LReleases: array of TKqueuePendingRelease;
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
  if FKqFd >= 0 then
  begin
    nextpas.core.platform.posix.ffi.close(FKqFd);
    FKqFd := -1;
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

procedure TKqueueReactor.ExecuteOp(AIdx: Int32);
var
  LRes: SizeInt;
  LRes32: Int32;
  LOptVal: Int32;
  LOptLen: UInt32;
  LCallback: TIoCompletion;
  LContext: Pointer;
  LAccepted: Int32;
begin
  LCallback := FOps[AIdx].Callback;
  LContext := FOps[AIdx].Context;
  case FOps[AIdx].Kind of
    opRead:
    begin
      LRes := read(FOps[AIdx].Fd, FOps[AIdx].Buf, FOps[AIdx].Len);
      LRes32 := KqueueResultFromSyscall(LRes);
      RemoveFilter(FOps[AIdx].Fd, EVFILT_READ);
      FreeOp(AIdx);
      if Assigned(LCallback) then
        LCallback(UInt64(AIdx), LRes32, LContext);
    end;

    opWrite:
    begin
      LRes := write(FOps[AIdx].Fd, FOps[AIdx].Buf, FOps[AIdx].Len);
      LRes32 := KqueueResultFromSyscall(LRes);
      RemoveFilter(FOps[AIdx].Fd, EVFILT_WRITE);
      FreeOp(AIdx);
      if Assigned(LCallback) then
        LCallback(UInt64(AIdx), LRes32, LContext);
    end;

    opAccept:
    begin
      LAccepted := accept(FOps[AIdx].Fd, FOps[AIdx].Addr, FOps[AIdx].AddrLen);
      if LAccepted >= 0 then
      begin
        SetNonBlocking(LAccepted);
        LRes32 := LAccepted;
      end
      else
        LRes32 := KqueueResultFromSyscall(-1);
      RemoveFilter(FOps[AIdx].Fd, EVFILT_READ);
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
        LRes32 := KqueueResultFromSyscall(LRes)
      else if LOptVal = 0 then
        LRes32 := 0
      else
        LRes32 := -LOptVal;
      RemoveFilter(FOps[AIdx].Fd, EVFILT_WRITE);
      FreeOp(AIdx);
      if Assigned(LCallback) then
        LCallback(UInt64(AIdx), LRes32, LContext);
    end;

    opSend:
    begin
      LRes := send(FOps[AIdx].Fd, FOps[AIdx].Buf, FOps[AIdx].Len, FOps[AIdx].Flags);
      LRes32 := KqueueResultFromSyscall(LRes);
      RemoveFilter(FOps[AIdx].Fd, EVFILT_WRITE);
      FreeOp(AIdx);
      if Assigned(LCallback) then
        LCallback(UInt64(AIdx), LRes32, LContext);
    end;

    opRecv:
    begin
      LRes := recv(FOps[AIdx].Fd, FOps[AIdx].Buf, FOps[AIdx].Len, FOps[AIdx].Flags);
      LRes32 := KqueueResultFromSyscall(LRes);
      RemoveFilter(FOps[AIdx].Fd, EVFILT_READ);
      FreeOp(AIdx);
      if Assigned(LCallback) then
        LCallback(UInt64(AIdx), LRes32, LContext);
    end;

    opSendTo:
    begin
      LRes := sendto(FOps[AIdx].Fd, FOps[AIdx].Buf, FOps[AIdx].Len,
        FOps[AIdx].Flags, FOps[AIdx].Addr, socklen_t(FOps[AIdx].AddrLenVal));
      LRes32 := KqueueResultFromSyscall(LRes);
      { 只摘 WRITE：同一 UDP fd 上 EVFILT_READ 的 RecvFrom 必须留下 }
      RemoveFilter(FOps[AIdx].Fd, EVFILT_WRITE);
      FreeOp(AIdx);
      if Assigned(LCallback) then
        LCallback(UInt64(AIdx), LRes32, LContext);
    end;

    opRecvFrom:
    begin
      LRes := recvfrom(FOps[AIdx].Fd, FOps[AIdx].Buf, FOps[AIdx].Len,
        FOps[AIdx].Flags, FOps[AIdx].Addr, FOps[AIdx].AddrLen);
      LRes32 := KqueueResultFromSyscall(LRes);
      RemoveFilter(FOps[AIdx].Fd, EVFILT_READ);
      FreeOp(AIdx);
      if Assigned(LCallback) then
        LCallback(UInt64(AIdx), LRes32, LContext);
    end;

    opClose:
    begin
      LRes := nextpas.core.platform.posix.ffi.close(FOps[AIdx].Fd);
      LRes32 := KqueueResultFromSyscall(LRes);
      FreeOp(AIdx);
      if Assigned(LCallback) then
        LCallback(UInt64(AIdx), LRes32, LContext);
    end;
  end;
end;

procedure TKqueueReactor.DispatchEvent(const AEv: TKEvent);
var
  LIdx: Int32;
begin
  if (AEv.Flags and EV_ERROR) <> 0 then
  begin
    { Registration/error on filter — still try dispatch by uData if present. }
  end;
  LIdx := Int32(PtrUInt(AEv.uData));
  if (LIdx < 0) or (UInt32(LIdx) >= FOpCount) then
    Exit;
  if not FOps[LIdx].Active then
    Exit;
  ExecuteOp(LIdx);
end;

function TKqueueReactor.AsyncRead(AFd: Int32; ABuf: Pointer; ALen: UInt32;
  AOffset: Int64; ACallback: TIoCompletion; AContext: Pointer): Boolean;
var
  LIdx: Int32;
begin
  if not IsValid then
  begin
    Result := False;
    Exit;
  end;
  if AOffset >= 0 then
  begin
    Result := False;
    Exit;
  end;
  if not SetNonBlocking(AFd) then
  begin
    Result := False;
    Exit;
  end;
  LIdx := AllocOp(opRead, AFd, ABuf, ALen, AOffset, 0, nil, nil, 0,
    ACallback, AContext);
  Result := RegisterFilter(AFd, EVFILT_READ, UInt64(LIdx));
  if not Result then
    FreeOp(LIdx);
end;

function TKqueueReactor.AsyncWrite(AFd: Int32; ABuf: Pointer; ALen: UInt32;
  AOffset: Int64; ACallback: TIoCompletion; AContext: Pointer): Boolean;
var
  LIdx: Int32;
  LRes: SizeInt;
  LRes32: Int32;
begin
  if not IsValid then
  begin
    Result := False;
    Exit;
  end;
  if AOffset >= 0 then
  begin
    Result := False;
    Exit;
  end;
  if not SetNonBlocking(AFd) then
  begin
    Result := False;
    Exit;
  end;
  LRes := write(AFd, ABuf, ALen);
  LRes32 := KqueueResultFromSyscall(LRes);
  if (LRes32 <> -ESysEAGAIN) and (LRes32 <> -EINTR_LOCAL) then
  begin
    if Assigned(ACallback) then
      ACallback(0, LRes32, AContext);
    Result := True;
    Exit;
  end;
  LIdx := AllocOp(opWrite, AFd, ABuf, ALen, AOffset, 0, nil, nil, 0,
    ACallback, AContext);
  Result := RegisterFilter(AFd, EVFILT_WRITE, UInt64(LIdx));
  if not Result then
    FreeOp(LIdx);
end;

function TKqueueReactor.AsyncAccept(AFd: Int32; AAddr: Pointer;
  AAddrLen: Pointer; AFlags: Int32; ACallback: TIoCompletion;
  AContext: Pointer): Boolean;
var
  LIdx: Int32;
begin
  if not IsValid then
  begin
    Result := False;
    Exit;
  end;
  if not SetNonBlocking(AFd) then
  begin
    Result := False;
    Exit;
  end;
  LIdx := AllocOp(opAccept, AFd, nil, 0, -1, AFlags, AAddr, AAddrLen, 0,
    ACallback, AContext);
  Result := RegisterFilter(AFd, EVFILT_READ, UInt64(LIdx));
  if not Result then
    FreeOp(LIdx);
end;

function TKqueueReactor.AsyncConnect(AFd: Int32; AAddr: Pointer;
  AAddrLen: UInt32; ACallback: TIoCompletion; AContext: Pointer): Boolean;
var
  LIdx: Int32;
  LRet: Int32;
  LErrno: Int32;
begin
  if not IsValid then
  begin
    Result := False;
    Exit;
  end;
  if not SetNonBlocking(AFd) then
  begin
    Result := False;
    Exit;
  end;
  LRet := connect(AFd, AAddr, AAddrLen);
  if LRet = 0 then
  begin
    if Assigned(ACallback) then
      ACallback(0, 0, AContext);
    Result := True;
    Exit;
  end;
  LErrno := platform_get_errno;
  if LErrno <> ESysEINPROGRESS then
  begin
    if Assigned(ACallback) then
      ACallback(0, -LErrno, AContext);
    Result := True;
    Exit;
  end;
  LIdx := AllocOp(opConnect, AFd, nil, 0, -1, 0, AAddr, nil, AAddrLen,
    ACallback, AContext);
  Result := RegisterFilter(AFd, EVFILT_WRITE, UInt64(LIdx));
  if not Result then
    FreeOp(LIdx);
end;

function TKqueueReactor.AsyncSend(AFd: Int32; ABuf: Pointer; ALen: UInt32;
  AFlags: Int32; ACallback: TIoCompletion; AContext: Pointer): Boolean;
var
  LIdx: Int32;
  LRes: SizeInt;
  LRes32: Int32;
begin
  if not IsValid then
  begin
    Result := False;
    Exit;
  end;
  if not SetNonBlocking(AFd) then
  begin
    Result := False;
    Exit;
  end;
  LRes := send(AFd, ABuf, ALen, AFlags);
  LRes32 := KqueueResultFromSyscall(LRes);
  if (LRes32 <> -ESysEAGAIN) and (LRes32 <> -EINTR_LOCAL) then
  begin
    if Assigned(ACallback) then
      ACallback(0, LRes32, AContext);
    Result := True;
    Exit;
  end;
  LIdx := AllocOp(opSend, AFd, ABuf, ALen, -1, AFlags, nil, nil, 0,
    ACallback, AContext);
  Result := RegisterFilter(AFd, EVFILT_WRITE, UInt64(LIdx));
  if not Result then
    FreeOp(LIdx);
end;

function TKqueueReactor.AsyncRecv(AFd: Int32; ABuf: Pointer; ALen: UInt32;
  AFlags: Int32; ACallback: TIoCompletion; AContext: Pointer): Boolean;
var
  LIdx: Int32;
begin
  if not IsValid then
  begin
    Result := False;
    Exit;
  end;
  if not SetNonBlocking(AFd) then
  begin
    Result := False;
    Exit;
  end;
  LIdx := AllocOp(opRecv, AFd, ABuf, ALen, -1, AFlags, nil, nil, 0,
    ACallback, AContext);
  Result := RegisterFilter(AFd, EVFILT_READ, UInt64(LIdx));
  if not Result then
    FreeOp(LIdx);
end;

function TKqueueReactor.AsyncSendTo(AFd: Int32; ABuf: Pointer; ALen: UInt32;
  AFlags: Int32; AAddr: Pointer; AAddrLen: UInt32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
var
  LIdx: Int32;
  LRes: SizeInt;
  LRes32: Int32;
begin
  if not IsValid then
  begin
    Result := False;
    Exit;
  end;
  if (AAddr = nil) or (AAddrLen = 0) then
  begin
    Result := False;
    Exit;
  end;
  if not SetNonBlocking(AFd) then
  begin
    Result := False;
    Exit;
  end;
  { 与 epoll 同：先 sendto，成功不动 kqueue，避免 EVFILT_WRITE 完成时
    RemoveFd 把 EVFILT_READ 一并删掉。 }
  LRes := sendto(AFd, ABuf, ALen, AFlags, AAddr, socklen_t(AAddrLen));
  LRes32 := KqueueResultFromSyscall(LRes);
  if (LRes32 <> -ESysEAGAIN) and (LRes32 <> -EINTR_LOCAL) then
  begin
    if Assigned(ACallback) then
      ACallback(0, LRes32, AContext);
    Result := True;
    Exit;
  end;
  LIdx := AllocOp(opSendTo, AFd, ABuf, ALen, -1, AFlags, AAddr, nil, AAddrLen,
    ACallback, AContext);
  Result := RegisterFilter(AFd, EVFILT_WRITE, UInt64(LIdx));
  if not Result then
    FreeOp(LIdx);
end;

function TKqueueReactor.AsyncRecvFrom(AFd: Int32; ABuf: Pointer; ALen: UInt32;
  AFlags: Int32; AAddr: Pointer; AAddrLen: Pointer;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
var
  LIdx: Int32;
begin
  if not IsValid then
  begin
    Result := False;
    Exit;
  end;
  if (AAddr = nil) or (AAddrLen = nil) then
  begin
    Result := False;
    Exit;
  end;
  if not SetNonBlocking(AFd) then
  begin
    Result := False;
    Exit;
  end;
  LIdx := AllocOp(opRecvFrom, AFd, ABuf, ALen, -1, AFlags, AAddr, AAddrLen, 0,
    ACallback, AContext);
  Result := RegisterFilter(AFd, EVFILT_READ, UInt64(LIdx));
  if not Result then
    FreeOp(LIdx);
end;

function TKqueueReactor.AsyncClose(AFd: Int32; ACallback: TIoCompletion;
  AContext: Pointer): Boolean;
var
  LI: UInt32;
  LReleaseCount: UInt32;
  LReleases: array of TKqueuePendingRelease;
  LRes: Int32;
  LHasException: Boolean;
  LExceptionMessage: string;
begin
  if not IsValid then
  begin
    Result := False;
    Exit;
  end;
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
  LRes := KqueueResultFromSyscall(nextpas.core.platform.posix.ffi.close(AFd));
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

function TKqueueReactor.Flush: Int32;
begin
  Result := 0;
end;

function TKqueueReactor.HasPending: Boolean;
begin
  Result := FPendingCount > 0;
end;

function TKqueueReactor.TryCancelByContext(AContext: Pointer): Boolean;
var
  LI: UInt32;
  LIdx: Int32;
  LCallback: TIoCompletion;
  LContext: Pointer;
  LFd: Int32;
  LUserData: UInt64;
begin
  Result := False;
  if (AContext = nil) or (not IsValid) then
    Exit;
  LIdx := -1;
  if FOpCount > 0 then
  begin
    for LI := 0 to FOpCount - 1 do
    begin
      if FOps[LI].Active and (FOps[LI].Context = AContext) then
      begin
        LIdx := Int32(LI);
        Break;
      end;
    end;
  end;
  if LIdx < 0 then
    Exit;
  LCallback := FOps[LIdx].Callback;
  LContext := FOps[LIdx].Context;
  LFd := FOps[LIdx].Fd;
  LUserData := UInt64(LIdx);
  FreeOp(LIdx);
  RemoveFd(LFd);
  if Assigned(LCallback) then
    LCallback(LUserData, -ESysECANCELED, LContext);
  Result := True;
end;

function TKqueueReactor.CancelByFd(AFd: Int32): Boolean;
var
  LI: UInt32;
  LContexts: array of Pointer;
  LCount, LJ: UInt32;
begin
  Result := False;
  if (AFd < 0) or (not IsValid) then
    Exit;
  if FOpCount = 0 then
    Exit;
  SetLength(LContexts, FOpCount);
  LCount := 0;
  for LI := 0 to FOpCount - 1 do
    if FOps[LI].Active and (FOps[LI].Fd = AFd) then
    begin
      LContexts[LCount] := FOps[LI].Context;
      Inc(LCount);
    end;
  for LJ := 0 to LCount - 1 do
    if TryCancelByContext(LContexts[LJ]) then
      Result := True;
end;

function TKqueueReactor.PollWait(const ATimeoutMs: Int64): Int32;
var
  LTimeout: timespec;
  LTimeoutPtr: Pointer;
  LN, LI: Int32;
begin
  Result := 0;
  if not IsValid then
    Exit;
  if ATimeoutMs < 0 then
    LTimeoutPtr := nil
  else
  begin
    LTimeout.tv_sec := ATimeoutMs div 1000;
    LTimeout.tv_nsec := (ATimeoutMs mod 1000) * 1000000;
    LTimeoutPtr := @LTimeout;
  end;
  LN := kevent(FKqFd, nil, 0, @FEvents[0], Int32(FMaxEvents), LTimeoutPtr);
  if LN <= 0 then
    Exit;
  for LI := 0 to LN - 1 do
    DispatchEvent(FEvents[LI]);
  Result := LN;
end;

function TKqueueReactor.PollOne: Boolean;
var
  LTimeout: timespec;
  LN: Int32;
begin
  if not IsValid then
  begin
    Result := False;
    Exit;
  end;
  LTimeout.tv_sec := 0;
  LTimeout.tv_nsec := 0;
  LN := kevent(FKqFd, nil, 0, @FEvents[0], 1, @LTimeout);
  if LN <= 0 then
  begin
    Result := False;
    Exit;
  end;
  DispatchEvent(FEvents[0]);
  Result := True;
end;

function TKqueueReactor.Poll: Int32;
var
  LTimeout: timespec;
  LN, LI: Int32;
begin
  Result := 0;
  if not IsValid then
    Exit;
  LTimeout.tv_sec := 0;
  LTimeout.tv_nsec := 0;
  LN := kevent(FKqFd, nil, 0, @FEvents[0], Int32(FMaxEvents), @LTimeout);
  if LN <= 0 then
    Exit;
  for LI := 0 to LN - 1 do
    DispatchEvent(FEvents[LI]);
  Result := LN;
end;

procedure TKqueueReactor.Run;
var
  LTimeout: timespec;
  LN, LI: Int32;
begin
  if not IsValid then
    Exit;
  atomic_store(FRunning, 1, mo_release);
  while atomic_load(FRunning, mo_acquire) <> 0 do
  begin
    LTimeout.tv_sec := 0;
    LTimeout.tv_nsec := 100 * 1000000; { 100ms }
    LN := kevent(FKqFd, nil, 0, @FEvents[0], Int32(FMaxEvents), @LTimeout);
    if LN < 0 then
    begin
      if platform_get_errno = EINTR_LOCAL then
        Continue;
      Break;
    end;
    for LI := 0 to LN - 1 do
    begin
      if atomic_load(FRunning, mo_acquire) = 0 then
        Break;
      DispatchEvent(FEvents[LI]);
    end;
  end;
end;

procedure TKqueueReactor.Stop;
begin
  atomic_store(FRunning, 0, mo_release);
end;

end.
{$ELSE}
interface
implementation
end.
{$ENDIF}
