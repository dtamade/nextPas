unit nextpas.core.net.server.runtime;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.net.intf,
  nextpas.core.net.server.base,
  nextpas.core.net.server.intf,
  nextpas.core.platform.io.base,
  nextpas.core.time.deadline;

type
  TTcpServerPollSessionTarget = class;

  TTcpServerPollCompletionEnqueueProc = procedure(
    const ATarget: TTcpServerPollSessionTarget;
    const ACompletion: ITcpServerWorkCompletion;
    const AOutcome: TTcpServerWorkOutcome;
    const AOwnership: TTcpServerConnOwnership) of object;
  TTcpServerPollWakeProc = procedure of object;

  TTcpServerPollSessionTarget = class
  private
    FConn: ITcpStream;
    FSocketRuntime: ITcpSocketRuntime;
    FSession: ITcpServerSession;
    FPollSession: ITcpServerPollDrivenSession;
    FDeadlineSession: ITcpServerPollDrivenSessionWithDeadline;
    FEvents: TPlatformPollEvents;
    FWakeDeadline: TDeadline;
    procedure RefreshWakeDeadline;
  public
    constructor Create(const AConn: ITcpStream;
      const ASocketRuntime: ITcpSocketRuntime;
      const ASession: ITcpServerSession;
      const APollSession: ITcpServerPollDrivenSession);
    function SocketHandle: Int32;
    function CurrentEvents: TPlatformPollEvents;
    procedure SetCurrentEvents(const AEvents: TPlatformPollEvents);
    function WakeDeadline: TDeadline;
    function Connection: ITcpStream;
    function HandleEvents(const AEvents: TPlatformPollEvents;
      out ANextEvents: TPlatformPollEvents;
      out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
  end;

  TTcpServerPollWorkerHandoff = class(TInterfacedObject,
    ITcpServerWorkerHandoff)
  private
    FBaseHandoff: ITcpServerWorkerHandoff;
    FTarget: TTcpServerPollSessionTarget;
    FEnqueueCompletion: TTcpServerPollCompletionEnqueueProc;
    FWake: TTcpServerPollWakeProc;
  public
    constructor Create(const ABaseHandoff: ITcpServerWorkerHandoff;
      const AEnqueueCompletion: TTcpServerPollCompletionEnqueueProc;
      const AWake: TTcpServerPollWakeProc);
    procedure BindTarget(const ATarget: TTcpServerPollSessionTarget);
    function Submit(const AWork: ITcpServerWork;
      const ACompletion: ITcpServerWorkCompletion): TTcpServerHandoffResult;
    procedure Shutdown;
  end;

  TTcpServerPollSessionContext = class(TInterfacedObject,
    ITcpServerSessionContext)
  private
    FWorkerHandoffRef: ITcpServerWorkerHandoff;
    FWorkerHandoff: TTcpServerPollWorkerHandoff;
  public
    constructor Create(const ABaseHandoff: ITcpServerWorkerHandoff;
      const AEnqueueCompletion: TTcpServerPollCompletionEnqueueProc;
      const AWake: TTcpServerPollWakeProc);
    procedure BindTarget(const ATarget: TTcpServerPollSessionTarget);
    function WorkerHandoff: ITcpServerWorkerHandoff;
  end;

procedure CreateTcpServerRuntimeContext(
  out AWorkerHandoff: ITcpServerWorkerHandoff;
  out ASessionContext: ITcpServerSessionContext);
function TryCreateTcpServerSession(const AHandler: ITcpServerHandler;
  const AConn: ITcpStream; const AContext: ITcpServerSessionContext;
  out ASession: ITcpServerSession): Boolean;
function TryCreateTcpServerPollSessionTarget(const AConn: ITcpStream;
  const ASession: ITcpServerSession;
  out ATarget: TTcpServerPollSessionTarget): Boolean;
function ExecuteTcpServerSession(
  const ASession: ITcpServerSession): TTcpServerConnOwnership;
function ExecuteTcpServerConnHandler(const AHandler: ITcpServerHandler;
  const AConn: ITcpStream; const AContext: ITcpServerSessionContext): TTcpServerConnOwnership;
procedure CloseServerOwnedTcpConn(const AConn: ITcpStream);

implementation

uses
  SysUtils,
  nextpas.core.errors,
  nextpas.core.sync.intf,
  nextpas.core.sync.mutex,
  nextpas.core.thread;

type
  TTcpServerWorkTask = class(TInterfacedObject)
  private
    FWork: ITcpServerWork;
    FCompletion: ITcpServerWorkCompletion;
  public
    constructor Create(const AWork: ITcpServerWork;
      const ACompletion: ITcpServerWorkCompletion);
    procedure Run;
  end;

  TTcpServerDefaultWorkerHandoff = class(TInterfacedObject,
    ITcpServerWorkerHandoff)
  private
    FPool: IThreadPool;
    FMutex: IMutex;
    FShuttingDown: Boolean;
  public
    constructor Create;
    procedure Shutdown;
    function Submit(const AWork: ITcpServerWork;
      const ACompletion: ITcpServerWorkCompletion): TTcpServerHandoffResult;
  end;

  TTcpServerDefaultSessionContext = class(TInterfacedObject,
    ITcpServerSessionContext)
  private
    FWorkerHandoff: ITcpServerWorkerHandoff;
  public
    constructor Create(const AWorkerHandoff: ITcpServerWorkerHandoff);
    function WorkerHandoff: ITcpServerWorkerHandoff;
  end;

  TTcpServerPollQueuedCompletion = class(TInterfacedObject,
    ITcpServerWorkCompletion)
  private
    FTarget: TTcpServerPollSessionTarget;
    FInner: ITcpServerWorkCompletion;
    FEnqueueCompletion: TTcpServerPollCompletionEnqueueProc;
    FWake: TTcpServerPollWakeProc;
  public
    constructor Create(const ATarget: TTcpServerPollSessionTarget;
      const AInner: ITcpServerWorkCompletion;
      const AEnqueueCompletion: TTcpServerPollCompletionEnqueueProc;
      const AWake: TTcpServerPollWakeProc);
    procedure Complete(const AOutcome: TTcpServerWorkOutcome;
      const AOwnership: TTcpServerConnOwnership);
  end;

constructor TTcpServerPollSessionTarget.Create(const AConn: ITcpStream;
  const ASocketRuntime: ITcpSocketRuntime; const ASession: ITcpServerSession;
  const APollSession: ITcpServerPollDrivenSession);
begin
  inherited Create;
  FConn := AConn;
  FSocketRuntime := ASocketRuntime;
  FSession := ASession;
  FPollSession := APollSession;
  FEvents := FPollSession.PollEvents;
  if Supports(ASession, ITcpServerPollDrivenSessionWithDeadline,
    FDeadlineSession) then
    RefreshWakeDeadline
  else
    FWakeDeadline := TDeadline.Infinite;
  if (FEvents = []) and FWakeDeadline.IsInfinite then
    raise EArgumentError.Create('poll-driven session must expose poll events');
end;

function TTcpServerPollSessionTarget.SocketHandle: Int32;
begin
  Result := Int32(FSocketRuntime.NativeSocketHandle);
end;

function TTcpServerPollSessionTarget.CurrentEvents: TPlatformPollEvents;
begin
  Result := FEvents;
end;

procedure TTcpServerPollSessionTarget.SetCurrentEvents(
  const AEvents: TPlatformPollEvents);
begin
  FEvents := AEvents;
end;

procedure TTcpServerPollSessionTarget.RefreshWakeDeadline;
begin
  if FDeadlineSession <> nil then
    FWakeDeadline := FDeadlineSession.WakeDeadline
  else
    FWakeDeadline := TDeadline.Infinite;
end;

function TTcpServerPollSessionTarget.WakeDeadline: TDeadline;
begin
  Result := FWakeDeadline;
end;

function TTcpServerPollSessionTarget.Connection: ITcpStream;
begin
  Result := FConn;
end;

function TTcpServerPollSessionTarget.HandleEvents(
  const AEvents: TPlatformPollEvents; out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
begin
  Result := FPollSession.Advance(AEvents, ANextEvents, AOwnership);
  RefreshWakeDeadline;
end;

constructor TTcpServerPollQueuedCompletion.Create(
  const ATarget: TTcpServerPollSessionTarget;
  const AInner: ITcpServerWorkCompletion;
  const AEnqueueCompletion: TTcpServerPollCompletionEnqueueProc;
  const AWake: TTcpServerPollWakeProc);
begin
  inherited Create;
  FTarget := ATarget;
  FInner := AInner;
  FEnqueueCompletion := AEnqueueCompletion;
  FWake := AWake;
end;

procedure TTcpServerPollQueuedCompletion.Complete(
  const AOutcome: TTcpServerWorkOutcome;
  const AOwnership: TTcpServerConnOwnership);
begin
  if Assigned(FEnqueueCompletion) then
  begin
    FEnqueueCompletion(FTarget, FInner, AOutcome, AOwnership);
    if Assigned(FWake) then
      FWake();
  end
  else if FInner <> nil then
    FInner.Complete(AOutcome, AOwnership);
  FInner := nil;
  FTarget := nil;
end;

constructor TTcpServerPollWorkerHandoff.Create(
  const ABaseHandoff: ITcpServerWorkerHandoff;
  const AEnqueueCompletion: TTcpServerPollCompletionEnqueueProc;
  const AWake: TTcpServerPollWakeProc);
begin
  inherited Create;
  FBaseHandoff := ABaseHandoff;
  FTarget := nil;
  FEnqueueCompletion := AEnqueueCompletion;
  FWake := AWake;
end;

procedure TTcpServerPollWorkerHandoff.BindTarget(
  const ATarget: TTcpServerPollSessionTarget);
begin
  FTarget := ATarget;
end;

function TTcpServerPollWorkerHandoff.Submit(const AWork: ITcpServerWork;
  const ACompletion: ITcpServerWorkCompletion): TTcpServerHandoffResult;
var
  LCompletion: ITcpServerWorkCompletion;
begin
  if (FTarget <> nil) and Assigned(FEnqueueCompletion) then
    LCompletion := TTcpServerPollQueuedCompletion.Create(FTarget, ACompletion,
      FEnqueueCompletion, FWake)
  else
    LCompletion := ACompletion;
  Result := FBaseHandoff.Submit(AWork, LCompletion);
end;

procedure TTcpServerPollWorkerHandoff.Shutdown;
begin
  FBaseHandoff.Shutdown;
end;

constructor TTcpServerPollSessionContext.Create(
  const ABaseHandoff: ITcpServerWorkerHandoff;
  const AEnqueueCompletion: TTcpServerPollCompletionEnqueueProc;
  const AWake: TTcpServerPollWakeProc);
begin
  inherited Create;
  FWorkerHandoff := TTcpServerPollWorkerHandoff.Create(ABaseHandoff,
    AEnqueueCompletion, AWake);
  FWorkerHandoffRef := FWorkerHandoff;
end;

procedure TTcpServerPollSessionContext.BindTarget(
  const ATarget: TTcpServerPollSessionTarget);
begin
  FWorkerHandoff.BindTarget(ATarget);
end;

function TTcpServerPollSessionContext.WorkerHandoff: ITcpServerWorkerHandoff;
begin
  Result := FWorkerHandoffRef;
end;

constructor TTcpServerWorkTask.Create(const AWork: ITcpServerWork;
  const ACompletion: ITcpServerWorkCompletion);
begin
  inherited Create;
  FWork := AWork;
  FCompletion := ACompletion;
end;

procedure TTcpServerWorkTask.Run;
var
  LOutcome: TTcpServerWorkOutcome;
  LOwnership: TTcpServerConnOwnership;
begin
  LOutcome := tswoCompleted;
  LOwnership := tscoServer;
  try
    LOwnership := FWork.Execute;
  except
    LOutcome := tswoFailed;
    LOwnership := tscoServer;
  end;
  try
    FCompletion.Complete(LOutcome, LOwnership);
  except
  end;
  FCompletion := nil;
  FWork := nil;
end;

constructor TTcpServerDefaultWorkerHandoff.Create;
begin
  inherited Create;
  FPool := ThreadPool(0);
  FMutex := nextpas.core.sync.mutex.TMutex.Create;
  FShuttingDown := False;
end;

procedure TTcpServerDefaultWorkerHandoff.Shutdown;
var
  LPool: IThreadPool;
begin
  FMutex.Acquire;
  try
    if FShuttingDown then
      Exit;
    FShuttingDown := True;
    LPool := FPool;
    FPool := nil;
  finally
    FMutex.Release;
  end;
  if LPool <> nil then
    LPool.Shutdown;
end;

function TTcpServerDefaultWorkerHandoff.Submit(const AWork: ITcpServerWork;
  const ACompletion: ITcpServerWorkCompletion): TTcpServerHandoffResult;
var
  LTask: TTcpServerWorkTask;
begin
  if AWork = nil then
    raise EArgumentError.Create('tcp server handoff work must not be nil');
  if ACompletion = nil then
    raise EArgumentError.Create('tcp server handoff completion must not be nil');

  FMutex.Acquire;
  try
    if FShuttingDown or (FPool = nil) then
      Exit(tshrShuttingDown);
    LTask := TTcpServerWorkTask.Create(AWork, ACompletion);
    try
      FPool.Submit(procedure
      begin
        try
          LTask.Run;
        finally
          LTask.Free;
        end;
      end);
    except
      LTask.Free;
      raise;
    end;
    Result := tshrAccepted;
  finally
    FMutex.Release;
  end;
end;

constructor TTcpServerDefaultSessionContext.Create(
  const AWorkerHandoff: ITcpServerWorkerHandoff);
begin
  inherited Create;
  FWorkerHandoff := AWorkerHandoff;
end;

function TTcpServerDefaultSessionContext.WorkerHandoff: ITcpServerWorkerHandoff;
begin
  Result := FWorkerHandoff;
end;

procedure CreateTcpServerRuntimeContext(
  out AWorkerHandoff: ITcpServerWorkerHandoff;
  out ASessionContext: ITcpServerSessionContext);
begin
  AWorkerHandoff := TTcpServerDefaultWorkerHandoff.Create;
  ASessionContext := TTcpServerDefaultSessionContext.Create(AWorkerHandoff);
end;

function TryCreateTcpServerSession(const AHandler: ITcpServerHandler;
  const AConn: ITcpStream; const AContext: ITcpServerSessionContext;
  out ASession: ITcpServerSession): Boolean;
var
  LContextFactory: ITcpServerSessionFactoryWithContext;
  LSessionFactory: ITcpServerSessionFactory;
begin
  ASession := nil;
  if Supports(AHandler, ITcpServerSessionFactoryWithContext, LContextFactory) then
  begin
    ASession := LContextFactory.NewSession(AConn, AContext);
    if ASession = nil then
      raise EArgumentError.Create('tcp server session factory returned nil');
    Exit(True);
  end;
  if Supports(AHandler, ITcpServerSessionFactory, LSessionFactory) then
  begin
    ASession := LSessionFactory.NewSession(AConn);
    if ASession = nil then
      raise EArgumentError.Create('tcp server session factory returned nil');
    Exit(True);
  end;
  Result := False;
end;

function TryCreateTcpServerPollSessionTarget(const AConn: ITcpStream;
  const ASession: ITcpServerSession;
  out ATarget: TTcpServerPollSessionTarget): Boolean;
var
  LPollSession: ITcpServerPollDrivenSession;
  LSocketRuntime: ITcpSocketRuntime;
begin
  ATarget := nil;
  if not Supports(ASession, ITcpServerPollDrivenSession, LPollSession) then
    Exit(False);
  if not Supports(AConn, ITcpSocketRuntime, LSocketRuntime) then
    Exit(False);

  LSocketRuntime.SetBlocking(False);
  ATarget := TTcpServerPollSessionTarget.Create(AConn, LSocketRuntime,
    ASession, LPollSession);
  Result := True;
end;

function ExecuteTcpServerSession(
  const ASession: ITcpServerSession): TTcpServerConnOwnership;
begin
  if ASession = nil then
    raise EArgumentError.Create('tcp server session must not be nil');
  Result := ASession.Run;
end;

function ExecuteTcpServerConnHandler(const AHandler: ITcpServerHandler;
  const AConn: ITcpStream; const AContext: ITcpServerSessionContext): TTcpServerConnOwnership;
var
  LSession: ITcpServerSession;
begin
  Result := tscoServer;
  try
    if TryCreateTcpServerSession(AHandler, AConn, AContext, LSession) then
      Result := ExecuteTcpServerSession(LSession)
    else
      Result := AHandler.ServeConn(AConn);
  except
    Result := tscoServer;
  end;
end;

procedure CloseServerOwnedTcpConn(const AConn: ITcpStream);
begin
  if AConn = nil then
    Exit;
  try
    AConn.Shutdown;
  except
  end;
  try
    AConn.Close;
  except
  end;
end;

end.
