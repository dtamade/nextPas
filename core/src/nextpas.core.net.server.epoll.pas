unit nextpas.core.net.server.epoll;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.net.server.base,
  nextpas.core.net.server.intf;

function NewTcpEpollServer(
  const AOptions: TTcpServerOptions): ITcpServer;

implementation

uses
  SysUtils,
  nextpas.core.errors,
  nextpas.core.thread,
  nextpas.core.platform.io.base,
  nextpas.core.platform.io,
  nextpas.core.net.tcp,
  nextpas.core.net.server.runtime;

type
  TTcpEpollConnTask = class(TInterfacedObject)
  private
    FConn: ITcpStream;
    FHandler: ITcpServerHandler;
    FSessionContext: ITcpServerSessionContext;
  public
    constructor Create(const AConn: ITcpStream;
      const AHandler: ITcpServerHandler;
      const ASessionContext: ITcpServerSessionContext);
    procedure Run;
  end;

  TTcpEpollServer = class(TInterfacedObject, ITcpServer)
  private
    FOptions: TTcpServerOptions;
    FRunning: Boolean;
    FListener: ITcpListener;
    FListenerRuntime: ITcpListenerRuntime;
    FListenerSocketRuntime: ITcpSocketRuntime;
    FConnWorkers: IThreadPool;
    FWorkerHandoff: ITcpServerWorkerHandoff;
    FSessionContext: ITcpServerSessionContext;
    FPoller: TPlatformPoller;
    FPollerReady: Boolean;
    procedure EnsureRuntimeContext;
    procedure DispatchAcceptedConn(const AHandler: ITcpServerHandler;
      const AConn: ITcpStream);
  public
    constructor Create(const AOptions: TTcpServerOptions);
    destructor Destroy; override;
    procedure ListenAndServe(const AAddr: string; const APort: UInt16;
      const AHandler: ITcpServerHandler);
    procedure Shutdown;
    function LocalAddr: TNetAddress;
    function IsRunning: Boolean;
  end;

constructor TTcpEpollConnTask.Create(const AConn: ITcpStream;
  const AHandler: ITcpServerHandler;
  const ASessionContext: ITcpServerSessionContext);
begin
  inherited Create;
  FConn := AConn;
  FHandler := AHandler;
  FSessionContext := ASessionContext;
end;

procedure TTcpEpollConnTask.Run;
var
  LOwnership: TTcpServerConnOwnership;
begin
  LOwnership := ExecuteTcpServerConnHandler(FHandler, FConn, FSessionContext);
  if LOwnership = tscoServer then
    CloseServerOwnedTcpConn(FConn);
  FConn := nil;
  FHandler := nil;
  FSessionContext := nil;
end;

constructor TTcpEpollServer.Create(const AOptions: TTcpServerOptions);
begin
  inherited Create;
  FOptions := AOptions;
  FRunning := False;
  FListener := nil;
  FListenerRuntime := nil;
  FListenerSocketRuntime := nil;
  FConnWorkers := nil;
  FWorkerHandoff := nil;
  FSessionContext := nil;
  FPollerReady := False;
end;

destructor TTcpEpollServer.Destroy;
begin
  if FRunning then
    Shutdown;
  FSessionContext := nil;
  FWorkerHandoff := nil;
  FConnWorkers := nil;
  FListenerSocketRuntime := nil;
  FListenerRuntime := nil;
  FListener := nil;
  inherited;
end;

procedure TTcpEpollServer.EnsureRuntimeContext;
begin
  if FWorkerHandoff = nil then
  begin
    CreateTcpServerRuntimeContext(FWorkerHandoff, FSessionContext);
    FConnWorkers := ThreadPool(0);
  end;
end;

procedure TTcpEpollServer.DispatchAcceptedConn(const AHandler: ITcpServerHandler;
  const AConn: ITcpStream);
var
  LTask: TTcpEpollConnTask;
begin
  if AConn = nil then
    Exit;
  if not FRunning then
  begin
    CloseServerOwnedTcpConn(AConn);
    Exit;
  end;

  LTask := TTcpEpollConnTask.Create(AConn, AHandler, FSessionContext);
  try
    FConnWorkers.Submit(procedure
    begin
      try
        LTask.Run;
      finally
        LTask.Free;
      end;
    end);
  except
    LTask.Free;
    CloseServerOwnedTcpConn(AConn);
    raise;
  end;
end;

procedure TTcpEpollServer.ListenAndServe(const AAddr: string;
  const APort: UInt16; const AHandler: ITcpServerHandler);
var
  LEntries: array[0..7] of TPlatformPollEntry;
  LCount: Int32;
  LErr: Int32;
  LConn: ITcpStream;
  LAcceptResult: TTcpAcceptResult;
begin
  if AHandler = nil then
    raise EArgumentError.Create('tcp server handler must not be nil');

  EnsureRuntimeContext;
  try
    FListener := NetTcpListen(AAddr, APort);
    if not Supports(FListener, ITcpListenerRuntime, FListenerRuntime) then
      raise ENotSupportedError.Create('tcp listener runtime seam not available');
    if not Supports(FListener, ITcpSocketRuntime, FListenerSocketRuntime) then
      raise ENotSupportedError.Create('tcp listener socket runtime seam not available');

    FListenerSocketRuntime.SetBlocking(False);
    LErr := platform_poller_create(FPoller);
    if LErr <> 0 then
      raise ENetworkError.Create('tcp epoll poller create failed (' + IntToStr(LErr) + ')');
    FPollerReady := True;

    LErr := platform_poller_add(FPoller,
      Int32(FListenerSocketRuntime.NativeSocketHandle),
      [peReadable], nil);
    if LErr <> 0 then
      raise ENetworkError.Create('tcp epoll poller add failed (' + IntToStr(LErr) + ')');

    FRunning := True;
    try
      while FRunning do
      begin
        LErr := platform_poller_wait(FPoller, @LEntries[0], SizeOf(LEntries), -1,
          LCount);
        if LErr <> 0 then
        begin
          if not FRunning then
            Break;
          raise ENetworkError.Create('tcp epoll poller wait failed (' + IntToStr(LErr) + ')');
        end;
        if LCount <= 0 then
          Continue;

        while FRunning do
        begin
          LConn := nil;
          LAcceptResult := FListenerRuntime.TryAccept(LConn);
          if LAcceptResult = tarAccepted then
          begin
            DispatchAcceptedConn(AHandler, LConn);
            Continue;
          end;
          Break;
        end;
      end;
    finally
      FRunning := False;
      if FPollerReady then
      begin
        platform_poller_close(FPoller);
        FPollerReady := False;
      end;
      if FConnWorkers <> nil then
        FConnWorkers.Shutdown;
      if FWorkerHandoff <> nil then
        FWorkerHandoff.Shutdown;
    end;
  finally
    FSessionContext := nil;
    FWorkerHandoff := nil;
    FConnWorkers := nil;
    FListenerSocketRuntime := nil;
    FListenerRuntime := nil;
    FListener := nil;
  end;
end;

procedure TTcpEpollServer.Shutdown;
var
  LAddr: TNetAddress;
  LWake: ITcpStream;
begin
  FRunning := False;
  if FListener <> nil then
  begin
    LAddr := FListener.LocalAddr;
    try
      LWake := NetTcpConnect(LAddr.IP, LAddr.Port);
      LWake.Close;
    except
    end;
    FListener.Close;
  end;
end;

function TTcpEpollServer.LocalAddr: TNetAddress;
begin
  if FListener <> nil then
    Result := FListener.LocalAddr
  else
    Result := TNetAddress.Any(0);
end;

function TTcpEpollServer.IsRunning: Boolean;
begin
  Result := FRunning;
end;

function NewTcpEpollServer(
  const AOptions: TTcpServerOptions): ITcpServer;
begin
  Result := TTcpEpollServer.Create(AOptions);
end;

end.
