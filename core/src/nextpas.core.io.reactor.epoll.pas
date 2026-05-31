unit nextpas.core.io.reactor.epoll;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.atomic,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.linux.base,
  nextpas.core.platform.linux.ffi;

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
  end;

  TEpollReactor = record
  private
    FEpfd: Int32;
    FMaxEvents: UInt32;
    FEvents: array of epoll_event;
    FOps: array of TEpollPendingOp;
    FOpCount: UInt32;
    FOpCap: UInt32;
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
  end;

implementation

const
  INITIAL_OPS = 256;
  EAGAIN      = 11;
  EINTR       = 4;
  EINPROGRESS = 115;

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
  Result.FFreeHead := -1;
  AtomicStore32(Result.FRunning, 0, moRelease);
end;

procedure TEpollReactor.Close;
begin
  if FEpfd >= 0 then
  begin
    nextpas.core.platform.posix.ffi.close(FEpfd);
    FEpfd := -1;
  end;
  SetLength(FEvents, 0);
  SetLength(FOps, 0);
  FOpCount := 0;
  FOpCap := 0;
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
  Result := Int32(LIdx);
end;

procedure TEpollReactor.FreeOp(AIdx: Int32);
begin
  if (AIdx < 0) or (UInt32(AIdx) >= FOpCount) then Exit;
  FOps[AIdx].Callback := nil;
  FOps[AIdx].Context := nil;
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
  FillChar(LEv, SizeOf(LEv), 0);
  epoll_ctl(FEpfd, EPOLL_CTL_DEL, AFd, @LEv);
end;

procedure TEpollReactor.ExecuteOp(AIdx: Int32);
var
  LRes: SizeInt;
  LRes32: Int32;
  LOptVal: Int32;
  LOptLen: UInt32;
begin
  case FOps[AIdx].Kind of
    opRead:
    begin
      if FOps[AIdx].Offset >= 0 then
        LRes := pread(FOps[AIdx].Fd, FOps[AIdx].Buf, FOps[AIdx].Len, FOps[AIdx].Offset)
      else
        LRes := read(FOps[AIdx].Fd, FOps[AIdx].Buf, FOps[AIdx].Len);
      RemoveFd(FOps[AIdx].Fd);
      if Assigned(FOps[AIdx].Callback) then
        FOps[AIdx].Callback(UInt64(AIdx), Int32(LRes), FOps[AIdx].Context);
      FreeOp(AIdx);
    end;

    opWrite:
    begin
      if FOps[AIdx].Offset >= 0 then
        LRes := pwrite(FOps[AIdx].Fd, FOps[AIdx].Buf, FOps[AIdx].Len, FOps[AIdx].Offset)
      else
        LRes := write(FOps[AIdx].Fd, FOps[AIdx].Buf, FOps[AIdx].Len);
      RemoveFd(FOps[AIdx].Fd);
      if Assigned(FOps[AIdx].Callback) then
        FOps[AIdx].Callback(UInt64(AIdx), Int32(LRes), FOps[AIdx].Context);
      FreeOp(AIdx);
    end;

    opAccept:
    begin
      LRes32 := accept4(FOps[AIdx].Fd, FOps[AIdx].Addr,
        FOps[AIdx].AddrLen, FOps[AIdx].Flags);
      RemoveFd(FOps[AIdx].Fd);
      if Assigned(FOps[AIdx].Callback) then
        FOps[AIdx].Callback(UInt64(AIdx), LRes32, FOps[AIdx].Context);
      FreeOp(AIdx);
    end;

    opConnect:
    begin
      LOptVal := 0;
      LOptLen := SizeOf(LOptVal);
      getsockopt(FOps[AIdx].Fd, SOL_SOCKET, SO_ERROR, @LOptVal, @LOptLen);
      RemoveFd(FOps[AIdx].Fd);
      if LOptVal = 0 then
        LRes32 := 0
      else
        LRes32 := -LOptVal;
      if Assigned(FOps[AIdx].Callback) then
        FOps[AIdx].Callback(UInt64(AIdx), LRes32, FOps[AIdx].Context);
      FreeOp(AIdx);
    end;

    opSend:
    begin
      LRes := send(FOps[AIdx].Fd, FOps[AIdx].Buf, FOps[AIdx].Len, FOps[AIdx].Flags);
      RemoveFd(FOps[AIdx].Fd);
      if Assigned(FOps[AIdx].Callback) then
        FOps[AIdx].Callback(UInt64(AIdx), Int32(LRes), FOps[AIdx].Context);
      FreeOp(AIdx);
    end;

    opRecv:
    begin
      LRes := recv(FOps[AIdx].Fd, FOps[AIdx].Buf, FOps[AIdx].Len, FOps[AIdx].Flags);
      RemoveFd(FOps[AIdx].Fd);
      if Assigned(FOps[AIdx].Callback) then
        FOps[AIdx].Callback(UInt64(AIdx), Int32(LRes), FOps[AIdx].Context);
      FreeOp(AIdx);
    end;

    opClose:
    begin
      LRes32 := nextpas.core.platform.posix.ffi.close(FOps[AIdx].Fd);
      if Assigned(FOps[AIdx].Callback) then
        FOps[AIdx].Callback(UInt64(AIdx), LRes32, FOps[AIdx].Context);
      FreeOp(AIdx);
    end;
  end;
end;

procedure TEpollReactor.DispatchEvent(const AEv: epoll_event);
var
  LIdx: Int32;
begin
  LIdx := Int32(AEv.data.u64);
  if (LIdx < 0) or (UInt32(LIdx) >= FOpCount) then Exit;
  if not Assigned(FOps[LIdx].Callback) then Exit;
  ExecuteOp(LIdx);
end;

function TEpollReactor.AsyncRead(AFd: Int32; ABuf: Pointer; ALen: UInt32;
  AOffset: Int64; ACallback: TIoCompletion; AContext: Pointer): Boolean;
var
  LIdx: Int32;
begin
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
begin
  if not SetNonBlocking(AFd) then begin Result := False; Exit; end;
  LRet := connect(AFd, AAddr, AAddrLen);
  if LRet = 0 then
  begin
    { Connected immediately }
    if Assigned(ACallback) then
      ACallback(0, 0, AContext);
    Result := True;
    Exit;
  end;
  { Check if in progress }
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
  LRes: Int32;
begin
  { Close is synchronous - epoll cannot watch for close readiness }
  RemoveFd(AFd);
  LRes := nextpas.core.platform.posix.ffi.close(AFd);
  if Assigned(ACallback) then
    ACallback(0, LRes, AContext);
  Result := True;
end;

function TEpollReactor.Flush: Int32;
begin
  { epoll operations are registered immediately, no batching needed }
  Result := 0;
end;

function TEpollReactor.PollOne: Boolean;
var
  LN: Int32;
begin
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
