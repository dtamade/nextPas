unit nextpas.core.net.server.runtime;

{$I nextpas.core.settings.inc}

interface

uses nextpas.core.net.intf, nextpas.core.net.server.base, nextpas.core.net.server.intf, nextpas.core.sync.intf, nextpas.core.platform.io.base, nextpas.core.time.deadline;

type
  TTcpServerPollSessionTarget = class;
  ITcpServerPollTargetTicket = interface;
  TTcpServerPollSessionTargetArray = array of TTcpServerPollSessionTarget;

  TTcpServerPollCompletionEnqueueProc = procedure(
    const ATicket: ITcpServerPollTargetTicket;
    const ACompletion: ITcpServerWorkCompletion;
    const AOutcome: TTcpServerWorkOutcome;
    const AOwnership: TTcpServerConnOwnership) of object;
  TTcpServerPollWakeProc = procedure of object;

  TTcpServerPollPendingCompletion = record
    TargetTicket: ITcpServerPollTargetTicket;
    Completion: ITcpServerWorkCompletion;
    Outcome: TTcpServerWorkOutcome;
    Ownership: TTcpServerConnOwnership;
  end;
  TTcpServerPollPendingCompletionArray = array of TTcpServerPollPendingCompletion;

  ITcpServerPollTargetTicket = interface
    ['{6F1D6F1D-4D7C-4E31-9100-410000000012}']
    function ResolveTarget(out ATarget: TTcpServerPollSessionTarget): Boolean;
    procedure DetachTarget;
  end;

  TTcpServerPollSessionTarget = class
  private
    FConn: ITcpStream;
    FSocketRuntime: ITcpSocketRuntime;
    FSession: ITcpServerSession;
    FPollSession: ITcpServerPollDrivenSession;
    FDeadlineSession: ITcpServerPollDrivenSessionWithDeadline;
    FEvents: TPlatformPollEvents;
    FWakeDeadline: TDeadline;
    FTicket: ITcpServerPollTargetTicket;
    procedure RefreshWakeDeadline;
  public
    constructor Create(const AConn: ITcpStream;
      const ASocketRuntime: ITcpSocketRuntime;
      const ASession: ITcpServerSession;
      const APollSession: ITcpServerPollDrivenSession;
      const AInitialEvents: TPlatformPollEvents;
      const AInitialWakeDeadline: TDeadline);
    destructor Destroy; override;
    function SocketHandle: PtrUInt;
    function CurrentEvents: TPlatformPollEvents;
    procedure SetCurrentEvents(const AEvents: TPlatformPollEvents);
    function WakeDeadline: TDeadline;
    function Connection: ITcpStream;
    function TargetTicket: ITcpServerPollTargetTicket;
    procedure DetachTicket;
    procedure RestoreBlocking;
    function HandleEvents(const AEvents: TPlatformPollEvents;
      out ANextEvents: TPlatformPollEvents;
      out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
  end;

  TTcpServerPollWorkerHandoff = class(TInterfacedObject,
    ITcpServerWorkerHandoff)
  private
    FBaseHandoff: ITcpServerWorkerHandoff;
    FTargetTicket: ITcpServerPollTargetTicket;
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

  TTcpServerPollCompletionQueue = class
  private
    FLock: IMutex;
    FItems: TTcpServerPollPendingCompletionArray;
    FCount: SizeUInt;
  public
    constructor Create;
    procedure Enqueue(const ATicket: ITcpServerPollTargetTicket;
      const ACompletion: ITcpServerWorkCompletion;
      const AOutcome: TTcpServerWorkOutcome;
      const AOwnership: TTcpServerConnOwnership);
    function Drain: TTcpServerPollPendingCompletionArray;
    procedure Clear;
  end;

  TTcpServerPollTargetRegistry = class
  private
    FItems: TTcpServerPollSessionTargetArray;
    FCount: SizeUInt;
  public
    procedure RegisterTarget(const ATarget: TTcpServerPollSessionTarget);
    procedure UnregisterTarget(const ATarget: TTcpServerPollSessionTarget);
    function ContainsTarget(const ATarget: TTcpServerPollSessionTarget): Boolean;
    function ComputePollTimeoutMs: Int32;
    function CollectExpiredTargets: TTcpServerPollSessionTargetArray;
    function Drain: TTcpServerPollSessionTargetArray;
    procedure Clear;
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

uses nextpas.core.errors, nextpas.core.sync.mutex, nextpas.core.thread, nextpas.core.time.base;

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
    FTargetTicket: ITcpServerPollTargetTicket;
    FInner: ITcpServerWorkCompletion;
    FEnqueueCompletion: TTcpServerPollCompletionEnqueueProc;
    FWake: TTcpServerPollWakeProc;
  public
    constructor Create(const ATicket: ITcpServerPollTargetTicket;
      const AInner: ITcpServerWorkCompletion;
      const AEnqueueCompletion: TTcpServerPollCompletionEnqueueProc;
      const AWake: TTcpServerPollWakeProc);
    procedure Complete(const AOutcome: TTcpServerWorkOutcome;
      const AOwnership: TTcpServerConnOwnership);
  end;

  TTcpServerPollTargetTicket = class(TInterfacedObject,
    ITcpServerPollTargetTicket)
  private
    FLock: IMutex;
    FTarget: TTcpServerPollSessionTarget;
  public
    constructor Create(const ATarget: TTcpServerPollSessionTarget);
    function ResolveTarget(out ATarget: TTcpServerPollSessionTarget): Boolean;
    procedure DetachTarget;
  end;

constructor TTcpServerPollTargetTicket.Create(
  const ATarget: TTcpServerPollSessionTarget);
begin
  inherited Create;
  FLock := nextpas.core.sync.mutex.TMutex.Create;
  FTarget := ATarget;
end;

function TTcpServerPollTargetTicket.ResolveTarget(
  out ATarget: TTcpServerPollSessionTarget): Boolean;
begin
  FLock.Acquire;
  try
    ATarget := FTarget;
    Result := ATarget <> nil;
  finally
    FLock.Release;
  end;
end;

procedure TTcpServerPollTargetTicket.DetachTarget;
begin
  FLock.Acquire;
  try
    FTarget := nil;
  finally
    FLock.Release;
  end;
end;

constructor TTcpServerPollSessionTarget.Create(const AConn: ITcpStream;
  const ASocketRuntime: ITcpSocketRuntime; const ASession: ITcpServerSession;
  const APollSession: ITcpServerPollDrivenSession;
  const AInitialEvents: TPlatformPollEvents;
  const AInitialWakeDeadline: TDeadline);
begin
  inherited Create;
  FConn := AConn;
  FSocketRuntime := ASocketRuntime;
  FSession := ASession;
  FPollSession := APollSession;
  FEvents := AInitialEvents;
  if Supports(ASession, ITcpServerPollDrivenSessionWithDeadline,
    FDeadlineSession) then
    FWakeDeadline := AInitialWakeDeadline
  else
    FWakeDeadline := TDeadline.Infinite;
  FTicket := TTcpServerPollTargetTicket.Create(Self);
end;

destructor TTcpServerPollSessionTarget.Destroy;
begin
  DetachTicket;
  FDeadlineSession := nil;
  FPollSession := nil;
  FSession := nil;
  FSocketRuntime := nil;
  FConn := nil;
  inherited;
end;

function TTcpServerPollSessionTarget.SocketHandle: PtrUInt;
begin
  Result := FSocketRuntime.NativeSocketHandle;
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

function TTcpServerPollSessionTarget.TargetTicket: ITcpServerPollTargetTicket;
begin
  Result := FTicket;
end;

procedure TTcpServerPollSessionTarget.DetachTicket;
begin
  if FTicket <> nil then
    FTicket.DetachTarget;
end;

procedure TTcpServerPollSessionTarget.RestoreBlocking;
begin
  FSocketRuntime.SetBlocking(True);
end;

function TTcpServerPollSessionTarget.HandleEvents(
  const AEvents: TPlatformPollEvents; out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
begin
  Result := FPollSession.Advance(AEvents, ANextEvents, AOwnership);
  RefreshWakeDeadline;
end;

constructor TTcpServerPollQueuedCompletion.Create(
  const ATicket: ITcpServerPollTargetTicket;
  const AInner: ITcpServerWorkCompletion;
  const AEnqueueCompletion: TTcpServerPollCompletionEnqueueProc;
  const AWake: TTcpServerPollWakeProc);
begin
  inherited Create;
  FTargetTicket := ATicket;
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
    FEnqueueCompletion(FTargetTicket, FInner, AOutcome, AOwnership);
    if Assigned(FWake) then
      FWake();
  end
  else if FInner <> nil then
    FInner.Complete(AOutcome, AOwnership);
  FInner := nil;
  FTargetTicket := nil;
end;

constructor TTcpServerPollWorkerHandoff.Create(
  const ABaseHandoff: ITcpServerWorkerHandoff;
  const AEnqueueCompletion: TTcpServerPollCompletionEnqueueProc;
  const AWake: TTcpServerPollWakeProc);
begin
  inherited Create;
  FBaseHandoff := ABaseHandoff;
  FTargetTicket := nil;
  FEnqueueCompletion := AEnqueueCompletion;
  FWake := AWake;
end;

procedure TTcpServerPollWorkerHandoff.BindTarget(
  const ATarget: TTcpServerPollSessionTarget);
begin
  if ATarget <> nil then
    FTargetTicket := ATarget.TargetTicket
  else
    FTargetTicket := nil;
end;

function TTcpServerPollWorkerHandoff.Submit(const AWork: ITcpServerWork;
  const ACompletion: ITcpServerWorkCompletion): TTcpServerHandoffResult;
var
  LCompletion: ITcpServerWorkCompletion;
begin
  if (FTargetTicket <> nil) and Assigned(FEnqueueCompletion) then
    LCompletion := TTcpServerPollQueuedCompletion.Create(FTargetTicket,
      ACompletion, FEnqueueCompletion, FWake)
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

constructor TTcpServerPollCompletionQueue.Create;
begin
  inherited Create;
  FLock := nextpas.core.sync.mutex.TMutex.Create;
  FCount := 0;
end;

procedure TTcpServerPollCompletionQueue.Enqueue(
  const ATicket: ITcpServerPollTargetTicket;
  const ACompletion: ITcpServerWorkCompletion;
  const AOutcome: TTcpServerWorkOutcome;
  const AOwnership: TTcpServerConnOwnership);
var
  LCapacity: SizeUInt;
begin
  if ACompletion = nil then
    Exit;

  FLock.Acquire;
  try
    LCapacity := SizeUInt(Length(FItems));
    if FCount >= LCapacity then
    begin
      if LCapacity = 0 then
        LCapacity := 4
      else
        LCapacity := LCapacity * 2;
      SetLength(FItems, LCapacity);
    end;
    FItems[FCount].TargetTicket := ATicket;
    FItems[FCount].Completion := ACompletion;
    FItems[FCount].Outcome := AOutcome;
    FItems[FCount].Ownership := AOwnership;
    Inc(FCount);
  finally
    FLock.Release;
  end;
end;

function TTcpServerPollCompletionQueue.Drain: TTcpServerPollPendingCompletionArray;
var
  LI: SizeUInt;
begin
  Result := nil;
  FLock.Acquire;
  try
    if FCount = 0 then
      Exit;
    SetLength(Result, FCount);
    for LI := 0 to FCount - 1 do
    begin
      Result[LI] := FItems[LI];
      FItems[LI].TargetTicket := nil;
      FItems[LI].Completion := nil;
    end;
    FCount := 0;
  finally
    FLock.Release;
  end;
end;

procedure TTcpServerPollCompletionQueue.Clear;
begin
  Drain;
end;

procedure TTcpServerPollTargetRegistry.RegisterTarget(
  const ATarget: TTcpServerPollSessionTarget);
begin
  if FCount >= SizeUInt(Length(FItems)) then
    SetLength(FItems, FCount + 8);
  FItems[FCount] := ATarget;
  Inc(FCount);
end;

procedure TTcpServerPollTargetRegistry.UnregisterTarget(
  const ATarget: TTcpServerPollSessionTarget);
var
  LI: SizeUInt;
begin
  if FCount = 0 then
    Exit;
  for LI := 0 to FCount - 1 do
    if FItems[LI] = ATarget then
    begin
      Dec(FCount);
      FItems[LI] := FItems[FCount];
      FItems[FCount] := nil;
      ATarget.DetachTicket;
      Exit;
    end;
end;

function TTcpServerPollTargetRegistry.ContainsTarget(
  const ATarget: TTcpServerPollSessionTarget): Boolean;
var
  LI: SizeUInt;
begin
  Result := False;
  if (ATarget = nil) or (FCount = 0) then
    Exit;
  for LI := 0 to FCount - 1 do
    if FItems[LI] = ATarget then
      Exit(True);
end;

function TTcpServerPollTargetRegistry.ComputePollTimeoutMs: Int32;
var
  LI: SizeUInt;
  LDeadline: TDeadline;
  LRemaining: TDuration;
  LMs: Int64;
begin
  Result := -1;
  if FCount = 0 then
    Exit;
  for LI := 0 to FCount - 1 do
  begin
    LDeadline := FItems[LI].WakeDeadline;
    if LDeadline.IsInfinite then
      Continue;
    if LDeadline.IsExpired then
      Exit(0);
    LRemaining := LDeadline.Remaining;
    LMs := LRemaining.AsMilliseconds;
    if (LMs <= 0) and (LRemaining.AsNanoseconds > 0) then
      LMs := 1;
    if LMs > High(Int32) then
      LMs := High(Int32);
    if (Result < 0) or (LMs < Result) then
      Result := Int32(LMs);
  end;
end;

function TTcpServerPollTargetRegistry.CollectExpiredTargets: TTcpServerPollSessionTargetArray;
var
  LI: SizeUInt;
  LCount: SizeUInt;
begin
  Result := nil;
  LCount := 0;
  if FCount = 0 then
    Exit;
  for LI := 0 to FCount - 1 do
    if FItems[LI].WakeDeadline.IsExpired then
    begin
      if LCount >= SizeUInt(Length(Result)) then
        SetLength(Result, LCount + 4);
      Result[LCount] := FItems[LI];
      Inc(LCount);
    end;
  SetLength(Result, LCount);
end;

function TTcpServerPollTargetRegistry.Drain: TTcpServerPollSessionTargetArray;
var
  LI: SizeUInt;
begin
  Result := nil;
  if FCount = 0 then
    Exit;
  SetLength(Result, FCount);
  for LI := 0 to FCount - 1 do
  begin
    Result[LI] := FItems[LI];
    if FItems[LI] <> nil then
      FItems[LI].DetachTicket;
    FItems[LI] := nil;
  end;
  FCount := 0;
end;

procedure TTcpServerPollTargetRegistry.Clear;
var
  LI: SizeUInt;
begin
  if FCount = 0 then
    Exit;
  for LI := 0 to FCount - 1 do
    FItems[LI] := nil;
  FCount := 0;
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
  LDeadlineSession: ITcpServerPollDrivenSessionWithDeadline;
  LSocketRuntime: ITcpSocketRuntime;
  LEvents: TPlatformPollEvents;
  LWakeDeadline: TDeadline;
begin
  ATarget := nil;
  if not Supports(ASession, ITcpServerPollDrivenSession, LPollSession) then
    Exit(False);
  if not Supports(AConn, ITcpSocketRuntime, LSocketRuntime) then
    Exit(False);

  LEvents := LPollSession.PollEvents;
  if Supports(ASession, ITcpServerPollDrivenSessionWithDeadline,
    LDeadlineSession) then
    LWakeDeadline := LDeadlineSession.WakeDeadline
  else
    LWakeDeadline := TDeadline.Infinite;
  if (LEvents = []) and LWakeDeadline.IsInfinite then
    Exit(False);

  LSocketRuntime.SetBlocking(False);
  ATarget := TTcpServerPollSessionTarget.Create(AConn, LSocketRuntime,
    ASession, LPollSession, LEvents, LWakeDeadline);
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
