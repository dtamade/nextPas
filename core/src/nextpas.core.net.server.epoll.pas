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
    FSession: ITcpServerSession;
  public
    constructor CreateForHandler(const AConn: ITcpStream;
      const AHandler: ITcpServerHandler;
      const ASessionContext: ITcpServerSessionContext);
    constructor CreateForSession(const AConn: ITcpStream;
      const ASession: ITcpServerSession);
    procedure Run;
  end;

  TTcpEpollPollSessionTarget = class
  private
    FConn: ITcpStream;
    FSocketRuntime: ITcpSocketRuntime;
    FSession: ITcpServerSession;
    FPollSession: ITcpServerPollDrivenSession;
    FEvents: TPlatformPollEvents;
  public
    constructor Create(const AConn: ITcpStream;
      const ASocketRuntime: ITcpSocketRuntime;
      const ASession: ITcpServerSession;
      const APollSession: ITcpServerPollDrivenSession);
    function SocketFd: Int32;
    function CurrentEvents: TPlatformPollEvents;
    procedure SetCurrentEvents(const AEvents: TPlatformPollEvents);
    function Connection: ITcpStream;
    function HandleEvents(const AEvents: TPlatformPollEvents;
      out ANextEvents: TPlatformPollEvents;
      out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
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
    procedure DispatchAcceptedSession(const AConn: ITcpStream;
      const ASession: ITcpServerSession);
    procedure DispatchAcceptedConn(const AHandler: ITcpServerHandler;
      const AConn: ITcpStream);
    function TryRegisterPollDrivenSession(const AConn: ITcpStream;
      const ASession: ITcpServerSession): Boolean;
    procedure HandlePollTarget(const ATarget: TTcpEpollPollSessionTarget;
      const AEvents: TPlatformPollEvents);
    procedure HandleListenerReady(const AHandler: ITcpServerHandler);
  public
    constructor Create(const AOptions: TTcpServerOptions);
    destructor Destroy; override;
    procedure ListenAndServe(const AAddr: string; const APort: UInt16;
      const AHandler: ITcpServerHandler);
    procedure Shutdown;
    function LocalAddr: TNetAddress;
    function IsRunning: Boolean;
  end;

constructor TTcpEpollConnTask.CreateForHandler(const AConn: ITcpStream;
  const AHandler: ITcpServerHandler;
  const ASessionContext: ITcpServerSessionContext);
begin
  inherited Create;
  FConn := AConn;
  FHandler := AHandler;
  FSessionContext := ASessionContext;
  FSession := nil;
end;

constructor TTcpEpollConnTask.CreateForSession(const AConn: ITcpStream;
  const ASession: ITcpServerSession);
begin
  inherited Create;
  FConn := AConn;
  FHandler := nil;
  FSessionContext := nil;
  FSession := ASession;
end;

procedure TTcpEpollConnTask.Run;
var
  LOwnership: TTcpServerConnOwnership;
begin
  if FSession <> nil then
    LOwnership := ExecuteTcpServerSession(FSession)
  else
    LOwnership := ExecuteTcpServerConnHandler(FHandler, FConn, FSessionContext);
  if LOwnership = tscoServer then
    CloseServerOwnedTcpConn(FConn);
  FConn := nil;
  FHandler := nil;
  FSessionContext := nil;
  FSession := nil;
end;

constructor TTcpEpollPollSessionTarget.Create(const AConn: ITcpStream;
  const ASocketRuntime: ITcpSocketRuntime; const ASession: ITcpServerSession;
  const APollSession: ITcpServerPollDrivenSession);
begin
  inherited Create;
  FConn := AConn;
  FSocketRuntime := ASocketRuntime;
  FSession := ASession;
  FPollSession := APollSession;
  FEvents := FPollSession.PollEvents;
  if FEvents = [] then
    raise EArgumentError.Create('poll-driven session must expose poll events');
end;

function TTcpEpollPollSessionTarget.SocketFd: Int32;
begin
  Result := Int32(FSocketRuntime.NativeSocketHandle);
end;

function TTcpEpollPollSessionTarget.CurrentEvents: TPlatformPollEvents;
begin
  Result := FEvents;
end;

procedure TTcpEpollPollSessionTarget.SetCurrentEvents(
  const AEvents: TPlatformPollEvents);
begin
  FEvents := AEvents;
end;

function TTcpEpollPollSessionTarget.Connection: ITcpStream;
begin
  Result := FConn;
end;

function TTcpEpollPollSessionTarget.HandleEvents(
  const AEvents: TPlatformPollEvents; out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
begin
  Result := FPollSession.Advance(AEvents, ANextEvents, AOwnership);
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

procedure TTcpEpollServer.DispatchAcceptedSession(const AConn: ITcpStream;
  const ASession: ITcpServerSession);
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

  LTask := TTcpEpollConnTask.CreateForSession(AConn, ASession);
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

procedure TTcpEpollServer.DispatchAcceptedConn(const AHandler: ITcpServerHandler;
  const AConn: ITcpStream);
var
  LTask: TTcpEpollConnTask;
  LSession: ITcpServerSession;
begin
  if AConn = nil then
    Exit;
  if not FRunning then
  begin
    CloseServerOwnedTcpConn(AConn);
    Exit;
  end;

  if TryCreateTcpServerSession(AHandler, AConn, FSessionContext, LSession) then
  begin
    if TryRegisterPollDrivenSession(AConn, LSession) then
      Exit;
    DispatchAcceptedSession(AConn, LSession);
    Exit;
  end;

  LTask := TTcpEpollConnTask.CreateForHandler(AConn, AHandler, FSessionContext);
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

function TTcpEpollServer.TryRegisterPollDrivenSession(const AConn: ITcpStream;
  const ASession: ITcpServerSession): Boolean;
var
  LPollSession: ITcpServerPollDrivenSession;
  LSocketRuntime: ITcpSocketRuntime;
  LTarget: TTcpEpollPollSessionTarget;
  LErr: Int32;
begin
  Result := False;
  if not Supports(ASession, ITcpServerPollDrivenSession, LPollSession) then
    Exit(False);
  if not Supports(AConn, ITcpSocketRuntime, LSocketRuntime) then
    Exit(False);

  LSocketRuntime.SetBlocking(False);
  LTarget := TTcpEpollPollSessionTarget.Create(AConn, LSocketRuntime,
    ASession, LPollSession);
  try
    LErr := platform_poller_add(FPoller, LTarget.SocketFd,
      LTarget.CurrentEvents, LTarget);
    if LErr <> 0 then
      raise ENetworkError.Create('tcp epoll poller add conn failed (' +
        IntToStr(LErr) + ')');
    Result := True;
  except
    LTarget.Free;
    raise;
  end;
end;

procedure TTcpEpollServer.HandlePollTarget(
  const ATarget: TTcpEpollPollSessionTarget; const AEvents: TPlatformPollEvents);
var
  LResult: TTcpServerPollResult;
  LNextEvents: TPlatformPollEvents;
  LOwnership: TTcpServerConnOwnership;
  LErr: Int32;
begin
  LOwnership := tscoServer;
  try
    LResult := ATarget.HandleEvents(AEvents, LNextEvents, LOwnership);
    if LResult = tsprDone then
    begin
      platform_poller_remove(FPoller, ATarget.SocketFd);
      if LOwnership = tscoServer then
        CloseServerOwnedTcpConn(ATarget.Connection);
      ATarget.Free;
      Exit;
    end;

    if LNextEvents = [] then
      raise EArgumentError.Create('poll-driven session returned empty wait events');

    if LNextEvents <> ATarget.CurrentEvents then
    begin
      ATarget.SetCurrentEvents(LNextEvents);
      LErr := platform_poller_modify(FPoller, ATarget.SocketFd,
        ATarget.CurrentEvents, ATarget);
      if LErr <> 0 then
        raise ENetworkError.Create('tcp epoll poller modify conn failed (' +
          IntToStr(LErr) + ')');
    end;
  except
    platform_poller_remove(FPoller, ATarget.SocketFd);
    CloseServerOwnedTcpConn(ATarget.Connection);
    ATarget.Free;
  end;
end;

procedure TTcpEpollServer.HandleListenerReady(const AHandler: ITcpServerHandler);
var
  LConn: ITcpStream;
  LAcceptResult: TTcpAcceptResult;
begin
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

procedure TTcpEpollServer.ListenAndServe(const AAddr: string;
  const APort: UInt16; const AHandler: ITcpServerHandler);
var
  LEntries: array[0..7] of TPlatformPollEntry;
  LCount: Int32;
  LErr: Int32;
  LI: Int32;
  LTarget: TTcpEpollPollSessionTarget;
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

        for LI := 0 to LCount - 1 do
        begin
          if LEntries[LI].UserData = nil then
          begin
            HandleListenerReady(AHandler);
            Continue;
          end;
          LTarget := TTcpEpollPollSessionTarget(LEntries[LI].UserData);
          HandlePollTarget(LTarget, LEntries[LI].REvents);
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
