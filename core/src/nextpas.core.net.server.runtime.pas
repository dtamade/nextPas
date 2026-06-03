unit nextpas.core.net.server.runtime;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.net.intf,
  nextpas.core.net.server.base,
  nextpas.core.net.server.intf;

procedure CreateTcpServerRuntimeContext(
  out AWorkerHandoff: ITcpServerWorkerHandoff;
  out ASessionContext: ITcpServerSessionContext);
function TryCreateTcpServerSession(const AHandler: ITcpServerHandler;
  const AConn: ITcpStream; const AContext: ITcpServerSessionContext;
  out ASession: ITcpServerSession): Boolean;
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
