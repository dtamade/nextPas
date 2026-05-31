unit nextpas.core.io.poller;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.linux.modern,
  nextpas.core.platform.linux.ffi,
  nextpas.core.io.reactor,
  nextpas.core.io.reactor.epoll;

type
  TIoCompletion = nextpas.core.io.reactor.TIoCompletion;

  TPollerBackend = (pbIoUring, pbEpoll);

  TPoller = record
  private
    FBackend: TPollerBackend;
    FUring: TIoReactor;
    FEpoll: TEpollReactor;
  public
    class function Create(AQueueDepth: UInt32 = 64): TPoller; static;
    procedure Close;
    function IsValid: Boolean; inline;
    function Backend: TPollerBackend; inline;

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

function PollerDetectBackend: TPollerBackend;

implementation

uses
  nextpas.core.platform.posix.ffi;

const
  ENOSYS = 38;

function TryIoUringProbe: Boolean;
var
  LParams: TIoUringParams;
  LFd: cint;
begin
  FillChar(LParams, SizeOf(LParams), 0);
  LFd := cint(syscall(SYS_io_uring_setup, 1, PtrUInt(@LParams), 0, 0, 0, 0));
  if LFd >= 0 then
  begin
    nextpas.core.platform.posix.ffi.close(LFd);
    Result := True;
  end
  else
  begin
    { LFd is negative errno on failure }
    if LFd = -ENOSYS then
      Result := False
    else
      Result := True; { io_uring exists but params were invalid }
  end;
end;

function PollerDetectBackend: TPollerBackend;
begin
  Result := pbEpoll;
  {$IFDEF NEXTPAS_LINUX}
  if TryIoUringProbe then
    Result := pbIoUring;
  {$ENDIF}
end;

class function TPoller.Create(AQueueDepth: UInt32): TPoller;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.FBackend := PollerDetectBackend;
  case Result.FBackend of
    pbIoUring: Result.FUring := TIoReactor.Create(AQueueDepth);
    pbEpoll:   Result.FEpoll := TEpollReactor.Create(AQueueDepth);
  end;
end;

procedure TPoller.Close;
begin
  case FBackend of
    pbIoUring: FUring.Close;
    pbEpoll:   FEpoll.Close;
  end;
end;

function TPoller.IsValid: Boolean;
begin
  case FBackend of
    pbIoUring: Result := FUring.IsValid;
    pbEpoll:   Result := FEpoll.IsValid;
  else
    Result := False;
  end;
end;

function TPoller.Backend: TPollerBackend;
begin
  Result := FBackend;
end;

function TPoller.AsyncRead(AFd: Int32; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  case FBackend of
    pbIoUring: Result := FUring.AsyncRead(AFd, ABuf, ALen, AOffset, ACallback, AContext);
    pbEpoll:   Result := FEpoll.AsyncRead(AFd, ABuf, ALen, AOffset,
                 nextpas.core.io.reactor.epoll.TIoCompletion(ACallback), AContext);
  else
    Result := False;
  end;
end;

function TPoller.AsyncWrite(AFd: Int32; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  case FBackend of
    pbIoUring: Result := FUring.AsyncWrite(AFd, ABuf, ALen, AOffset, ACallback, AContext);
    pbEpoll:   Result := FEpoll.AsyncWrite(AFd, ABuf, ALen, AOffset,
                 nextpas.core.io.reactor.epoll.TIoCompletion(ACallback), AContext);
  else
    Result := False;
  end;
end;

function TPoller.AsyncAccept(AFd: Int32; AAddr: Pointer; AAddrLen: Pointer; AFlags: Int32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  case FBackend of
    pbIoUring: Result := FUring.AsyncAccept(AFd, AAddr, AAddrLen, AFlags, ACallback, AContext);
    pbEpoll:   Result := FEpoll.AsyncAccept(AFd, AAddr, AAddrLen, AFlags,
                 nextpas.core.io.reactor.epoll.TIoCompletion(ACallback), AContext);
  else
    Result := False;
  end;
end;

function TPoller.AsyncConnect(AFd: Int32; AAddr: Pointer; AAddrLen: UInt32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  case FBackend of
    pbIoUring: Result := FUring.AsyncConnect(AFd, AAddr, AAddrLen, ACallback, AContext);
    pbEpoll:   Result := FEpoll.AsyncConnect(AFd, AAddr, AAddrLen,
                 nextpas.core.io.reactor.epoll.TIoCompletion(ACallback), AContext);
  else
    Result := False;
  end;
end;

function TPoller.AsyncSend(AFd: Int32; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  case FBackend of
    pbIoUring: Result := FUring.AsyncSend(AFd, ABuf, ALen, AFlags, ACallback, AContext);
    pbEpoll:   Result := FEpoll.AsyncSend(AFd, ABuf, ALen, AFlags,
                 nextpas.core.io.reactor.epoll.TIoCompletion(ACallback), AContext);
  else
    Result := False;
  end;
end;

function TPoller.AsyncRecv(AFd: Int32; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  case FBackend of
    pbIoUring: Result := FUring.AsyncRecv(AFd, ABuf, ALen, AFlags, ACallback, AContext);
    pbEpoll:   Result := FEpoll.AsyncRecv(AFd, ABuf, ALen, AFlags,
                 nextpas.core.io.reactor.epoll.TIoCompletion(ACallback), AContext);
  else
    Result := False;
  end;
end;

function TPoller.AsyncClose(AFd: Int32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  case FBackend of
    pbIoUring: Result := FUring.AsyncClose(AFd, ACallback, AContext);
    pbEpoll:   Result := FEpoll.AsyncClose(AFd,
                 nextpas.core.io.reactor.epoll.TIoCompletion(ACallback), AContext);
  else
    Result := False;
  end;
end;

function TPoller.Poll: Int32;
begin
  case FBackend of
    pbIoUring: Result := FUring.Poll;
    pbEpoll:   Result := FEpoll.Poll;
  else
    Result := 0;
  end;
end;

function TPoller.PollOne: Boolean;
begin
  case FBackend of
    pbIoUring: Result := FUring.PollOne;
    pbEpoll:   Result := FEpoll.PollOne;
  else
    Result := False;
  end;
end;

procedure TPoller.Run;
begin
  case FBackend of
    pbIoUring: FUring.Run;
    pbEpoll:   FEpoll.Run;
  end;
end;

procedure TPoller.Stop;
begin
  case FBackend of
    pbIoUring: FUring.Stop;
    pbEpoll:   FEpoll.Stop;
  end;
end;

function TPoller.Flush: Int32;
begin
  case FBackend of
    pbIoUring: Result := FUring.Flush;
    pbEpoll:   Result := FEpoll.Flush;
  else
    Result := 0;
  end;
end;

end.
