unit nextpas.core.io.poller;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base
  {$IFDEF NEXTPAS_WINDOWS}
  , nextpas.core.io.reactor.iocp
  {$ENDIF}
  {$IFDEF NEXTPAS_LINUX}
  , nextpas.core.io.reactor
  , nextpas.core.io.reactor.epoll
  {$ENDIF}
  ;

type
  TIoCompletion = procedure(AUserData: UInt64; AResult: Int32; AContext: Pointer);

  TPollerBackend = (pbIoUring, pbEpoll, pbIocp, pbUnsupported);
  TPollerBackendModel = (pbmCompletionQueue, pbmReadiness, pbmUnsupported);

  TPoller = record
  private
    FBackend: TPollerBackend;
    {$IFDEF NEXTPAS_LINUX}
    FUring: TIoReactor;
    FEpoll: TEpollReactor;
    {$ENDIF}
    {$IFDEF NEXTPAS_WINDOWS}
    FIocp: TIocpReactor;
    {$ENDIF}
  public
    class function Create(AQueueDepth: UInt32 = 64): TPoller; static;
    procedure Close;
    function IsValid: Boolean; inline;
    function Backend: TPollerBackend; inline;

    function AsyncRead(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncWrite(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncAccept(AFd: PtrInt; AAddr: Pointer; AAddrLen: Pointer; AFlags: Int32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncConnect(AFd: PtrInt; AAddr: Pointer; AAddrLen: UInt32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncSend(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncRecv(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncClose(AFd: PtrInt;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;

    function Poll: Int32;
    function PollOne: Boolean;
    procedure Run;
    procedure Stop;
    function Flush: Int32;
    function HasPending: Boolean;
  end;

function PollerDetectBackend: TPollerBackend;
function PollerBackendModel(ABackend: TPollerBackend): TPollerBackendModel;
function PollerSupportsPositionedFileIO(ABackend: TPollerBackend): Boolean;

implementation

{$IFDEF NEXTPAS_LINUX}
uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.linux.modern,
  nextpas.core.platform.linux.ffi;

function TryIoUringProbe: Boolean;
var
  LParams: TIoUringParams;
  LFd: cint;
begin
  Result := False;
  FillChar(LParams, SizeOf(LParams), 0);
  LFd := cint(syscall(SYS_io_uring_setup, 1, PtrUInt(@LParams), 0, 0, 0, 0));
  if LFd >= 0 then
  begin
    nextpas.core.platform.posix.ffi.close(LFd);
    Result := True;
  end;
end;
{$ENDIF}

function PollerDetectBackend: TPollerBackend;
begin
  {$IFDEF NEXTPAS_WINDOWS}
  Result := pbIocp;
  {$ELSEIF defined(NEXTPAS_LINUX)}
  Result := pbEpoll;
  if TryIoUringProbe then
    Result := pbIoUring;
  {$ELSE}
  Result := pbUnsupported;
  {$ENDIF}
end;

function PollerBackendModel(ABackend: TPollerBackend): TPollerBackendModel;
begin
  case ABackend of
    pbIoUring: Result := pbmCompletionQueue;
    pbIocp: Result := pbmCompletionQueue;
    pbEpoll: Result := pbmReadiness;
  else
    Result := pbmUnsupported;
  end;
end;

function PollerSupportsPositionedFileIO(ABackend: TPollerBackend): Boolean;
begin
  case ABackend of
    pbIoUring: Result := True;
    pbIocp: Result := True;
    pbEpoll: Result := False;
  else
    Result := False;
  end;
end;

class function TPoller.Create(AQueueDepth: UInt32): TPoller;
begin
  Result := Default(TPoller);
  Result.FBackend := PollerDetectBackend;
  case Result.FBackend of
    {$IFDEF NEXTPAS_LINUX}
    pbIoUring:
      begin
        Result.FUring := TIoReactor.Create(AQueueDepth);
        if not Result.FUring.IsValid then
        begin
          Result.FBackend := pbEpoll;
          Result.FEpoll := TEpollReactor.Create(AQueueDepth);
          if not Result.FEpoll.IsValid then
            Result.FBackend := pbUnsupported;
        end;
      end;
    pbEpoll:
      begin
        Result.FEpoll := TEpollReactor.Create(AQueueDepth);
        if not Result.FEpoll.IsValid then
          Result.FBackend := pbUnsupported;
      end;
    {$ENDIF}
    {$IFDEF NEXTPAS_WINDOWS}
    pbIocp:
      begin
        Result.FIocp := TIocpReactor.Create(AQueueDepth);
        if not Result.FIocp.IsValid then
          Result.FBackend := pbUnsupported;
      end;
    {$ENDIF}
  else
    ;
  end;
end;

procedure TPoller.Close;
begin
  case FBackend of
    {$IFDEF NEXTPAS_LINUX}
    pbIoUring: FUring.Close;
    pbEpoll:   FEpoll.Close;
    {$ENDIF}
    {$IFDEF NEXTPAS_WINDOWS}
    pbIocp: FIocp.Close;
    {$ENDIF}
  else
    ;
  end;
end;

function TPoller.IsValid: Boolean;
begin
  case FBackend of
    {$IFDEF NEXTPAS_LINUX}
    pbIoUring: Result := FUring.IsValid;
    pbEpoll:   Result := FEpoll.IsValid;
    {$ENDIF}
    {$IFDEF NEXTPAS_WINDOWS}
    pbIocp: Result := FIocp.IsValid;
    {$ENDIF}
  else
    Result := False;
  end;
end;

function TPoller.Backend: TPollerBackend;
begin
  Result := FBackend;
end;

function TPoller.AsyncRead(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  case FBackend of
    {$IFDEF NEXTPAS_LINUX}
    pbIoUring: Result := FUring.AsyncRead(Int32(AFd), ABuf, ALen, AOffset,
                 nextpas.core.io.reactor.TIoCompletion(ACallback), AContext);
    pbEpoll:
      begin
        if AOffset >= 0 then
          Exit(False);
        Result := FEpoll.AsyncRead(Int32(AFd), ABuf, ALen, AOffset,
          nextpas.core.io.reactor.epoll.TIoCompletion(ACallback), AContext);
      end;
    {$ENDIF}
    {$IFDEF NEXTPAS_WINDOWS}
    pbIocp:    Result := FIocp.AsyncRead(AFd, ABuf, ALen, AOffset,
                 nextpas.core.io.reactor.iocp.TIoCompletion(ACallback), AContext);
    {$ENDIF}
  else
    Result := False;
  end;
end;

function TPoller.AsyncWrite(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  case FBackend of
    {$IFDEF NEXTPAS_LINUX}
    pbIoUring: Result := FUring.AsyncWrite(Int32(AFd), ABuf, ALen, AOffset,
                 nextpas.core.io.reactor.TIoCompletion(ACallback), AContext);
    pbEpoll:
      begin
        if AOffset >= 0 then
          Exit(False);
        Result := FEpoll.AsyncWrite(Int32(AFd), ABuf, ALen, AOffset,
          nextpas.core.io.reactor.epoll.TIoCompletion(ACallback), AContext);
      end;
    {$ENDIF}
    {$IFDEF NEXTPAS_WINDOWS}
    pbIocp:    Result := FIocp.AsyncWrite(AFd, ABuf, ALen, AOffset,
                 nextpas.core.io.reactor.iocp.TIoCompletion(ACallback), AContext);
    {$ENDIF}
  else
    Result := False;
  end;
end;

function TPoller.AsyncAccept(AFd: PtrInt; AAddr: Pointer; AAddrLen: Pointer; AFlags: Int32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  case FBackend of
    {$IFDEF NEXTPAS_LINUX}
    pbIoUring: Result := FUring.AsyncAccept(Int32(AFd), AAddr, AAddrLen, AFlags,
                 nextpas.core.io.reactor.TIoCompletion(ACallback), AContext);
    pbEpoll:   Result := FEpoll.AsyncAccept(Int32(AFd), AAddr, AAddrLen, AFlags,
                 nextpas.core.io.reactor.epoll.TIoCompletion(ACallback), AContext);
    {$ENDIF}
    {$IFDEF NEXTPAS_WINDOWS}
    pbIocp:    Result := FIocp.AsyncAccept(AFd, AAddr, AAddrLen, AFlags,
                 nextpas.core.io.reactor.iocp.TIoCompletion(ACallback), AContext);
    {$ENDIF}
  else
    Result := False;
  end;
end;

function TPoller.AsyncConnect(AFd: PtrInt; AAddr: Pointer; AAddrLen: UInt32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  case FBackend of
    {$IFDEF NEXTPAS_LINUX}
    pbIoUring: Result := FUring.AsyncConnect(Int32(AFd), AAddr, AAddrLen,
                 nextpas.core.io.reactor.TIoCompletion(ACallback), AContext);
    pbEpoll:   Result := FEpoll.AsyncConnect(Int32(AFd), AAddr, AAddrLen,
                 nextpas.core.io.reactor.epoll.TIoCompletion(ACallback), AContext);
    {$ENDIF}
    {$IFDEF NEXTPAS_WINDOWS}
    pbIocp:    Result := FIocp.AsyncConnect(AFd, AAddr, AAddrLen,
                 nextpas.core.io.reactor.iocp.TIoCompletion(ACallback), AContext);
    {$ENDIF}
  else
    Result := False;
  end;
end;

function TPoller.AsyncSend(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  case FBackend of
    {$IFDEF NEXTPAS_LINUX}
    pbIoUring: Result := FUring.AsyncSend(Int32(AFd), ABuf, ALen, AFlags,
                 nextpas.core.io.reactor.TIoCompletion(ACallback), AContext);
    pbEpoll:   Result := FEpoll.AsyncSend(Int32(AFd), ABuf, ALen, AFlags,
                 nextpas.core.io.reactor.epoll.TIoCompletion(ACallback), AContext);
    {$ENDIF}
    {$IFDEF NEXTPAS_WINDOWS}
    pbIocp:    Result := FIocp.AsyncSend(AFd, ABuf, ALen, AFlags,
                 nextpas.core.io.reactor.iocp.TIoCompletion(ACallback), AContext);
    {$ENDIF}
  else
    Result := False;
  end;
end;

function TPoller.AsyncRecv(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  case FBackend of
    {$IFDEF NEXTPAS_LINUX}
    pbIoUring: Result := FUring.AsyncRecv(Int32(AFd), ABuf, ALen, AFlags,
                 nextpas.core.io.reactor.TIoCompletion(ACallback), AContext);
    pbEpoll:   Result := FEpoll.AsyncRecv(Int32(AFd), ABuf, ALen, AFlags,
                 nextpas.core.io.reactor.epoll.TIoCompletion(ACallback), AContext);
    {$ENDIF}
    {$IFDEF NEXTPAS_WINDOWS}
    pbIocp:    Result := FIocp.AsyncRecv(AFd, ABuf, ALen, AFlags,
                 nextpas.core.io.reactor.iocp.TIoCompletion(ACallback), AContext);
    {$ENDIF}
  else
    Result := False;
  end;
end;

function TPoller.AsyncClose(AFd: PtrInt;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  case FBackend of
    {$IFDEF NEXTPAS_LINUX}
    pbIoUring: Result := FUring.AsyncClose(Int32(AFd),
                 nextpas.core.io.reactor.TIoCompletion(ACallback), AContext);
    pbEpoll:   Result := FEpoll.AsyncClose(Int32(AFd),
                 nextpas.core.io.reactor.epoll.TIoCompletion(ACallback), AContext);
    {$ENDIF}
    {$IFDEF NEXTPAS_WINDOWS}
    pbIocp:    Result := FIocp.AsyncClose(AFd,
                 nextpas.core.io.reactor.iocp.TIoCompletion(ACallback), AContext);
    {$ENDIF}
  else
    Result := False;
  end;
end;

function TPoller.Poll: Int32;
begin
  case FBackend of
    {$IFDEF NEXTPAS_LINUX}
    pbIoUring: Result := FUring.Poll;
    pbEpoll:   Result := FEpoll.Poll;
    {$ENDIF}
    {$IFDEF NEXTPAS_WINDOWS}
    pbIocp: Result := FIocp.Poll;
    {$ENDIF}
  else
    Result := 0;
  end;
end;

function TPoller.PollOne: Boolean;
begin
  case FBackend of
    {$IFDEF NEXTPAS_LINUX}
    pbIoUring: Result := FUring.PollOne;
    pbEpoll:   Result := FEpoll.PollOne;
    {$ENDIF}
    {$IFDEF NEXTPAS_WINDOWS}
    pbIocp: Result := FIocp.PollOne;
    {$ENDIF}
  else
    Result := False;
  end;
end;

procedure TPoller.Run;
begin
  case FBackend of
    {$IFDEF NEXTPAS_LINUX}
    pbIoUring: FUring.Run;
    pbEpoll:   FEpoll.Run;
    {$ENDIF}
    {$IFDEF NEXTPAS_WINDOWS}
    pbIocp: FIocp.Run;
    {$ENDIF}
  else
    ;
  end;
end;

procedure TPoller.Stop;
begin
  case FBackend of
    {$IFDEF NEXTPAS_LINUX}
    pbIoUring: FUring.Stop;
    pbEpoll:   FEpoll.Stop;
    {$ENDIF}
    {$IFDEF NEXTPAS_WINDOWS}
    pbIocp: FIocp.Stop;
    {$ENDIF}
  else
    ;
  end;
end;

function TPoller.Flush: Int32;
begin
  case FBackend of
    {$IFDEF NEXTPAS_LINUX}
    pbIoUring: Result := FUring.Flush;
    pbEpoll:   Result := FEpoll.Flush;
    {$ENDIF}
    {$IFDEF NEXTPAS_WINDOWS}
    pbIocp: Result := FIocp.Flush;
    {$ENDIF}
  else
    Result := 0;
  end;
end;

function TPoller.HasPending: Boolean;
begin
  case FBackend of
    {$IFDEF NEXTPAS_LINUX}
    pbIoUring: Result := FUring.HasPending;
    pbEpoll:   Result := FEpoll.HasPending;
    {$ENDIF}
    {$IFDEF NEXTPAS_WINDOWS}
    pbIocp: Result := FIocp.HasPending;
    {$ENDIF}
  else
    Result := False;
  end;
end;

end.
