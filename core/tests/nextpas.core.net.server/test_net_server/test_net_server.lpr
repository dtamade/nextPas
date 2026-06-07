program test_net_server;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Classes,
  SysUtils,
  StrUtils,
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.net,
  nextpas.core.net.intf,
  nextpas.core.net.server,
  nextpas.core.net.server.readiness,
  nextpas.core.platform.io.base,
  nextpas.core.platform.thread,
  nextpas.core.time.base,
  nextpas.core.time.deadline;

type
  PServerCtx = ^TServerCtx;
  TServerCtx = record
    Server: ITcpServer;
    Handler: ITcpServerHandler;
    Addr: string;
    Port: UInt16;
  end;

  TEchoHandler = class(TInterfacedObject, ITcpServerHandler)
  private
    FCalled: Boolean;
    FSeenRemoteAddr: string;
  public
    function ServeConn(const AConn: ITcpStream): TTcpServerConnOwnership;
    property Called: Boolean read FCalled;
    property SeenRemoteAddr: string read FSeenRemoteAddr;
  end;

  TDetachHandler = class(TInterfacedObject, ITcpServerHandler)
  private
    FConn: ITcpStream;
  public
    function ServeConn(const AConn: ITcpStream): TTcpServerConnOwnership;
    property Conn: ITcpStream read FConn;
  end;

  TFailOnceHandler = class(TInterfacedObject, ITcpServerHandler)
  private
    FCalls: Int32;
  public
    function ServeConn(const AConn: ITcpStream): TTcpServerConnOwnership;
    property Calls: Int32 read FCalls;
  end;

  TCountingSession = class(TInterfacedObject, ITcpServerSession)
  private
    FConn: ITcpStream;
    FRunCount: PInt32;
  public
    constructor Create(const AConn: ITcpStream; const ARunCount: PInt32);
    function Run: TTcpServerConnOwnership;
  end;

  TSessionFactoryHandler = class(TInterfacedObject, ITcpServerHandler,
    ITcpServerSessionFactory)
  private
    FCreateCount: Int32;
    FRunCount: Int32;
  public
    function ServeConn(const AConn: ITcpStream): TTcpServerConnOwnership;
    function NewSession(const AConn: ITcpStream): ITcpServerSession;
    property CreateCount: Int32 read FCreateCount;
    property RunCount: Int32 read FRunCount;
  end;

  TContextSessionMode = (
    csmClose,
    csmSubmitCompleted,
    csmSubmitFailing
  );

  TContextAwareHandler = class;

  TClosingSession = class(TInterfacedObject, ITcpServerSession)
  public
    function Run: TTcpServerConnOwnership;
  end;

  THandoffWork = class(TInterfacedObject, ITcpServerWork)
  private
    FOwner: TContextAwareHandler;
    FFailWork: Boolean;
  public
    constructor Create(const AOwner: TContextAwareHandler;
      const AFailWork: Boolean);
    function Execute: TTcpServerConnOwnership;
  end;

  THandoffCompletion = class(TInterfacedObject, ITcpServerWorkCompletion)
  private
    FOwner: TContextAwareHandler;
    FConn: ITcpStream;
  public
    constructor Create(const AOwner: TContextAwareHandler;
      const AConn: ITcpStream);
    procedure Complete(const AOutcome: TTcpServerWorkOutcome;
      const AOwnership: TTcpServerConnOwnership);
  end;

  TContextAwareSession = class(TInterfacedObject, ITcpServerSession)
  private
    FOwner: TContextAwareHandler;
    FConn: ITcpStream;
    FHandoff: ITcpServerWorkerHandoff;
    FMode: TContextSessionMode;
  public
    constructor Create(const AOwner: TContextAwareHandler;
      const AConn: ITcpStream; const AHandoff: ITcpServerWorkerHandoff;
      const AMode: TContextSessionMode);
    function Run: TTcpServerConnOwnership;
  end;

  TContextAwareHandler = class(TInterfacedObject, ITcpServerHandler,
    ITcpServerSessionFactory, ITcpServerSessionFactoryWithContext)
  private
    FMode: TContextSessionMode;
    FServeConnCalled: Boolean;
    FLegacyFactoryCalled: Boolean;
    FContextFactoryCalled: Boolean;
    FContextSeen: Boolean;
    FWorkerHandoffSeen: Boolean;
    FCapturedHandoff: ITcpServerWorkerHandoff;
    FSubmitResult: TTcpServerHandoffResult;
    FWorkExecuteCount: Int32;
    FCompletionCount: Int32;
    FRunThreadId: UInt64;
    FWorkThreadId: UInt64;
    FCompletionThreadId: UInt64;
    FLastWorkOutcome: TTcpServerWorkOutcome;
    FLastOwnership: TTcpServerConnOwnership;
  public
    constructor Create(const AMode: TContextSessionMode);
    function ServeConn(const AConn: ITcpStream): TTcpServerConnOwnership;
    function NewSession(const AConn: ITcpStream): ITcpServerSession; overload;
    function NewSession(const AConn: ITcpStream;
      const AContext: ITcpServerSessionContext): ITcpServerSession; overload;
    property ServeConnCalled: Boolean read FServeConnCalled;
    property LegacyFactoryCalled: Boolean read FLegacyFactoryCalled;
    property ContextFactoryCalled: Boolean read FContextFactoryCalled;
    property ContextSeen: Boolean read FContextSeen;
    property WorkerHandoffSeen: Boolean read FWorkerHandoffSeen;
    property CapturedHandoff: ITcpServerWorkerHandoff read FCapturedHandoff;
    property SubmitResult: TTcpServerHandoffResult read FSubmitResult;
    property WorkExecuteCount: Int32 read FWorkExecuteCount;
    property CompletionCount: Int32 read FCompletionCount;
    property RunThreadId: UInt64 read FRunThreadId;
    property WorkThreadId: UInt64 read FWorkThreadId;
    property CompletionThreadId: UInt64 read FCompletionThreadId;
    property LastWorkOutcome: TTcpServerWorkOutcome read FLastWorkOutcome;
    property LastOwnership: TTcpServerConnOwnership read FLastOwnership;
  end;

  TPollDrivenHandler = class;

  TPollDrivenEchoSession = class(TInterfacedObject, ITcpServerSession,
    ITcpServerPollDrivenSession)
  private
    FOwner: TPollDrivenHandler;
    FConn: ITcpStream;
    FConnRuntime: ITcpStreamRuntime;
    FBuf: array[0..31] of Byte;
    FReadCount: SizeUInt;
    FWritePos: SizeUInt;
  public
    constructor Create(const AOwner: TPollDrivenHandler; const AConn: ITcpStream);
    function Run: TTcpServerConnOwnership;
    function PollEvents: TPlatformPollEvents;
    function Advance(const AEvents: TPlatformPollEvents;
      out ANextEvents: TPlatformPollEvents;
      out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
  end;

  TPollDrivenHandler = class(TInterfacedObject, ITcpServerHandler,
    ITcpServerSessionFactoryWithContext)
  private
    FServeConnCalled: Boolean;
    FContextFactoryCalled: Boolean;
    FRunCount: Int32;
    FAdvanceCount: Int32;
  public
    function ServeConn(const AConn: ITcpStream): TTcpServerConnOwnership;
    function NewSession(const AConn: ITcpStream;
      const AContext: ITcpServerSessionContext): ITcpServerSession;
    property ServeConnCalled: Boolean read FServeConnCalled;
    property ContextFactoryCalled: Boolean read FContextFactoryCalled;
    property RunCount: Int32 read FRunCount;
    property AdvanceCount: Int32 read FAdvanceCount;
  end;

  TWakeupPollDrivenHandler = class;

  TWakeupWork = class(TInterfacedObject, ITcpServerWork)
  private
    FOwner: TWakeupPollDrivenHandler;
  public
    constructor Create(const AOwner: TWakeupPollDrivenHandler);
    function Execute: TTcpServerConnOwnership;
  end;

  TWakeupCompletion = class(TInterfacedObject, ITcpServerWorkCompletion)
  private
    FOwner: TWakeupPollDrivenHandler;
  public
    constructor Create(const AOwner: TWakeupPollDrivenHandler);
    procedure Complete(const AOutcome: TTcpServerWorkOutcome;
      const AOwnership: TTcpServerConnOwnership);
  end;

  TWakeupPollDrivenSession = class(TInterfacedObject, ITcpServerSession,
    ITcpServerPollDrivenSession)
  private
    FOwner: TWakeupPollDrivenHandler;
    FConn: ITcpStream;
    FConnRuntime: ITcpStreamRuntime;
    FHandoff: ITcpServerWorkerHandoff;
    FSubmitted: Boolean;
    FWritePos: SizeUInt;
  public
    constructor Create(const AOwner: TWakeupPollDrivenHandler;
      const AConn: ITcpStream; const AHandoff: ITcpServerWorkerHandoff);
    function Run: TTcpServerConnOwnership;
    function PollEvents: TPlatformPollEvents;
    function Advance(const AEvents: TPlatformPollEvents;
      out ANextEvents: TPlatformPollEvents;
      out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
  end;

  TWakeupPollDrivenHandler = class(TInterfacedObject, ITcpServerHandler,
    ITcpServerSessionFactoryWithContext)
  private
    FServeConnCalled: Boolean;
    FContextFactoryCalled: Boolean;
    FSubmitResult: TTcpServerHandoffResult;
    FAdvanceCount: Int32;
    FWorkExecuteCount: Int32;
    FCompletionCount: Int32;
    FReactorThreadId: UInt64;
    FWorkThreadId: UInt64;
    FCompletionThreadId: UInt64;
    FCompletionReady: Boolean;
    FObservedEmptyAdvance: Boolean;
  public
    function ServeConn(const AConn: ITcpStream): TTcpServerConnOwnership;
    function NewSession(const AConn: ITcpStream;
      const AContext: ITcpServerSessionContext): ITcpServerSession;
    property ServeConnCalled: Boolean read FServeConnCalled;
    property ContextFactoryCalled: Boolean read FContextFactoryCalled;
    property SubmitResult: TTcpServerHandoffResult read FSubmitResult;
    property AdvanceCount: Int32 read FAdvanceCount;
    property WorkExecuteCount: Int32 read FWorkExecuteCount;
    property CompletionCount: Int32 read FCompletionCount;
    property ReactorThreadId: UInt64 read FReactorThreadId;
    property WorkThreadId: UInt64 read FWorkThreadId;
    property CompletionThreadId: UInt64 read FCompletionThreadId;
    property ObservedEmptyAdvance: Boolean read FObservedEmptyAdvance;
  end;

  TDeadlinePollDrivenHandler = class;

  TDeadlinePollDrivenSession = class(TInterfacedObject, ITcpServerSession,
    ITcpServerPollDrivenSession, ITcpServerPollDrivenSessionWithDeadline)
  private
    FOwner: TDeadlinePollDrivenHandler;
    FConn: ITcpStream;
    FConnRuntime: ITcpStreamRuntime;
    FDeadline: TDeadline;
    FTimerArmed: Boolean;
    FWritePos: SizeUInt;
  public
    constructor Create(const AOwner: TDeadlinePollDrivenHandler;
      const AConn: ITcpStream);
    function Run: TTcpServerConnOwnership;
    function PollEvents: TPlatformPollEvents;
    function Advance(const AEvents: TPlatformPollEvents;
      out ANextEvents: TPlatformPollEvents;
      out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
    function WakeDeadline: TDeadline;
  end;

  TDeadlinePollDrivenHandler = class(TInterfacedObject, ITcpServerHandler,
    ITcpServerSessionFactoryWithContext)
  private
    FServeConnCalled: Boolean;
    FContextFactoryCalled: Boolean;
    FAdvanceCount: Int32;
    FObservedDeadlineWake: Boolean;
  public
    function ServeConn(const AConn: ITcpStream): TTcpServerConnOwnership;
    function NewSession(const AConn: ITcpStream;
      const AContext: ITcpServerSessionContext): ITcpServerSession;
    property ServeConnCalled: Boolean read FServeConnCalled;
    property ContextFactoryCalled: Boolean read FContextFactoryCalled;
    property AdvanceCount: Int32 read FAdvanceCount;
    property ObservedDeadlineWake: Boolean read FObservedDeadlineWake;
  end;

  TMockServerProvider = class(TInterfacedObject, ITcpServer)
  private
    FListenCalled: Boolean;
    FShutdownCalled: Boolean;
    FOptionsBackend: TTcpServerBackend;
  public
    constructor Create(const AOptions: TTcpServerOptions);
    procedure ListenAndServe(const AAddr: string; const APort: UInt16;
      const AHandler: ITcpServerHandler);
    procedure Shutdown;
    function LocalAddr: TNetAddress;
    function IsRunning: Boolean;
    property ListenCalled: Boolean read FListenCalled;
    property ShutdownCalled: Boolean read FShutdownCalled;
    property OptionsBackend: TTcpServerBackend read FOptionsBackend;
  end;

function ExpandRepoPath(const ARelativePath: string): string;
begin
  Result := ExpandFileName('../../../' + ARelativePath);
end;

function LoadSourceText(const ARelativePath: string): string;
var
  LSourcePath: string;
  LLines: TStringList;
begin
  LSourcePath := ExpandRepoPath(ARelativePath);
  Check(FileExists(LSourcePath), 'source file should exist: ' + LSourcePath);
  LLines := TStringList.Create;
  try
    LLines.LoadFromFile(LSourcePath);
    Result := LowerCase(LLines.Text);
  finally
    LLines.Free;
  end;
end;

procedure CheckSourceContains(const ASource, ANeedle, AMessage: string);
begin
  Check(Pos(ANeedle, ASource) > 0, AMessage);
end;

procedure CheckSourceNotContains(const ASource, ANeedle, AMessage: string);
begin
  Check(Pos(ANeedle, ASource) = 0, AMessage);
end;

procedure CheckSourceOrder(const ASource, AFirstNeedle, ASecondNeedle,
  AMessage: string);
var
  LFirst: SizeInt;
  LSecond: SizeInt;
begin
  LFirst := Pos(AFirstNeedle, ASource);
  LSecond := PosEx(ASecondNeedle, ASource, LFirst + Length(AFirstNeedle));
  Check((LFirst > 0) and (LSecond > LFirst), AMessage);
end;

function ExtractSourceRange(const ASource, AStartNeedle, AEndNeedle,
  AMessage: string): string;
var
  LStart: SizeInt;
  LEnd: SizeInt;
begin
  LStart := Pos(AStartNeedle, ASource);
  Check(LStart > 0, AMessage + ' start marker');
  LEnd := PosEx(AEndNeedle, ASource, LStart + Length(AStartNeedle));
  Check(LEnd > LStart, AMessage + ' end marker');
  Result := Copy(ASource, LStart, LEnd - LStart);
end;

var
  T: TTestRunner;
  GProviderFactoryCalls: Int32;
  GLastMockProvider: TMockServerProvider;

function CreateMockServerProvider(
  const AOptions: TTcpServerOptions): ITcpServer;
var
  LProvider: TMockServerProvider;
begin
  Inc(GProviderFactoryCalls);
  LProvider := TMockServerProvider.Create(AOptions);
  GLastMockProvider := LProvider;
  Result := LProvider;
end;

function ServerThreadFunc(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PServerCtx;
begin
  Result := nil;
  LCtx := PServerCtx(AArg);
  try
    LCtx^.Server.ListenAndServe(LCtx^.Addr, LCtx^.Port, LCtx^.Handler);
  finally
    LCtx^.Server := nil;
    LCtx^.Handler := nil;
    Dispose(LCtx);
  end;
end;

function TEchoHandler.ServeConn(const AConn: ITcpStream): TTcpServerConnOwnership;
var
  LBuf: array[0..255] of Byte;
  LN: SizeUInt;
begin
  FCalled := True;
  FSeenRemoteAddr := AConn.RemoteAddr.ToString;
  LN := AConn.Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
  if LN > 0 then
    AConn.Write(LBuf[0], LN);
  Result := TCP_SERVER_CONN_OWNERSHIP_SERVER;
end;

function TDetachHandler.ServeConn(const AConn: ITcpStream): TTcpServerConnOwnership;
begin
  FConn := AConn;
  Result := TCP_SERVER_CONN_OWNERSHIP_HANDLER;
end;

function TFailOnceHandler.ServeConn(const AConn: ITcpStream): TTcpServerConnOwnership;
var
  LBuf: array[0..255] of Byte;
  LN: SizeUInt;
begin
  Inc(FCalls);
  if FCalls = 1 then
    raise Exception.Create('fail once');
  LN := AConn.Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
  if LN > 0 then
    AConn.Write(LBuf[0], LN);
  Result := TCP_SERVER_CONN_OWNERSHIP_SERVER;
end;

constructor TCountingSession.Create(const AConn: ITcpStream; const ARunCount: PInt32);
begin
  inherited Create;
  FConn := AConn;
  FRunCount := ARunCount;
end;

function TCountingSession.Run: TTcpServerConnOwnership;
var
  LBuf: array[0..255] of Byte;
  LN: SizeUInt;
begin
  Inc(FRunCount^);
  LN := FConn.Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
  if LN > 0 then
    FConn.Write(LBuf[0], LN);
  Result := TCP_SERVER_CONN_OWNERSHIP_SERVER;
end;

function TSessionFactoryHandler.ServeConn(
  const AConn: ITcpStream): TTcpServerConnOwnership;
begin
  Result := TCP_SERVER_CONN_OWNERSHIP_SERVER;
  Fail('session factory path should bypass legacy ServeConn');
end;

function TSessionFactoryHandler.NewSession(
  const AConn: ITcpStream): ITcpServerSession;
begin
  Inc(FCreateCount);
  Result := TCountingSession.Create(AConn, @FRunCount);
end;

function TClosingSession.Run: TTcpServerConnOwnership;
begin
  Result := TCP_SERVER_CONN_OWNERSHIP_SERVER;
end;

constructor THandoffWork.Create(const AOwner: TContextAwareHandler;
  const AFailWork: Boolean);
begin
  inherited Create;
  FOwner := AOwner;
  FFailWork := AFailWork;
end;

function THandoffWork.Execute: TTcpServerConnOwnership;
begin
  InterlockedIncrement(FOwner.FWorkExecuteCount);
  FOwner.FWorkThreadId := platform_thread_id;
  if FFailWork then
    raise Exception.Create('handoff work failed');
  Result := TCP_SERVER_CONN_OWNERSHIP_SERVER;
end;

constructor THandoffCompletion.Create(const AOwner: TContextAwareHandler;
  const AConn: ITcpStream);
begin
  inherited Create;
  FOwner := AOwner;
  FConn := AConn;
end;

procedure THandoffCompletion.Complete(const AOutcome: TTcpServerWorkOutcome;
  const AOwnership: TTcpServerConnOwnership);
begin
  InterlockedIncrement(FOwner.FCompletionCount);
  FOwner.FCompletionThreadId := platform_thread_id;
  FOwner.FLastWorkOutcome := AOutcome;
  FOwner.FLastOwnership := AOwnership;
  if (AOwnership = TCP_SERVER_CONN_OWNERSHIP_SERVER) and (FConn <> nil) then
  begin
    try
      FConn.Shutdown;
      FConn.Close;
    except
    end;
    FConn := nil;
  end;
end;

constructor TContextAwareSession.Create(const AOwner: TContextAwareHandler;
  const AConn: ITcpStream; const AHandoff: ITcpServerWorkerHandoff;
  const AMode: TContextSessionMode);
begin
  inherited Create;
  FOwner := AOwner;
  FConn := AConn;
  FHandoff := AHandoff;
  FMode := AMode;
end;

function TContextAwareSession.Run: TTcpServerConnOwnership;
var
  LWork: ITcpServerWork;
  LCompletion: ITcpServerWorkCompletion;
begin
  FOwner.FRunThreadId := platform_thread_id;
  case FMode of
    csmClose:
      Result := TCP_SERVER_CONN_OWNERSHIP_SERVER;
    csmSubmitCompleted, csmSubmitFailing:
      begin
        LWork := THandoffWork.Create(FOwner, FMode = csmSubmitFailing);
        LCompletion := THandoffCompletion.Create(FOwner, FConn);
        FOwner.FSubmitResult := FHandoff.Submit(LWork, LCompletion);
        if FOwner.FSubmitResult = TCP_SERVER_HANDOFF_ACCEPTED then
          Result := TCP_SERVER_CONN_OWNERSHIP_HANDLER
        else
          Result := TCP_SERVER_CONN_OWNERSHIP_SERVER;
      end;
  end;
end;

constructor TContextAwareHandler.Create(const AMode: TContextSessionMode);
begin
  inherited Create;
  FMode := AMode;
end;

function TContextAwareHandler.ServeConn(
  const AConn: ITcpStream): TTcpServerConnOwnership;
begin
  FServeConnCalled := True;
  Result := TCP_SERVER_CONN_OWNERSHIP_SERVER;
  Fail('context-aware session factory path should bypass ServeConn');
end;

function TContextAwareHandler.NewSession(
  const AConn: ITcpStream): ITcpServerSession;
begin
  FLegacyFactoryCalled := True;
  Result := TClosingSession.Create;
end;

function TContextAwareHandler.NewSession(const AConn: ITcpStream;
  const AContext: ITcpServerSessionContext): ITcpServerSession;
begin
  FContextFactoryCalled := True;
  FContextSeen := AContext <> nil;
  FWorkerHandoffSeen := (AContext <> nil) and (AContext.WorkerHandoff <> nil);
  if AContext <> nil then
    FCapturedHandoff := AContext.WorkerHandoff
  else
    FCapturedHandoff := nil;
  Result := TContextAwareSession.Create(Self, AConn, FCapturedHandoff, FMode);
end;

constructor TPollDrivenEchoSession.Create(const AOwner: TPollDrivenHandler;
  const AConn: ITcpStream);
begin
  inherited Create;
  FOwner := AOwner;
  FConn := AConn;
  if not Supports(AConn, ITcpStreamRuntime, FConnRuntime) then
    raise Exception.Create('poll-driven session requires stream runtime seam');
  FReadCount := 0;
  FWritePos := 0;
end;

function TPollDrivenEchoSession.Run: TTcpServerConnOwnership;
var
  LN: SizeUInt;
begin
  InterlockedIncrement(FOwner.FRunCount);
  LN := FConn.Read(FBuf[0], SizeUInt(SizeOf(FBuf)));
  if LN > 0 then
    FConn.Write(FBuf[0], LN);
  Result := TCP_SERVER_CONN_OWNERSHIP_SERVER;
end;

function TPollDrivenEchoSession.PollEvents: TPlatformPollEvents;
begin
  if FWritePos < FReadCount then
    Result := [peWritable]
  else
    Result := [peReadable];
end;

function TPollDrivenEchoSession.Advance(const AEvents: TPlatformPollEvents;
  out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
var
  LN: SizeUInt;
  LResult: TTcpStreamIOResult;
begin
  InterlockedIncrement(FOwner.FAdvanceCount);
  AOwnership := TCP_SERVER_CONN_OWNERSHIP_SERVER;

  if FWritePos < FReadCount then
  begin
    LResult := FConnRuntime.TryWrite(FBuf[FWritePos], FReadCount - FWritePos, LN);
    case LResult of
      tsiorOk:
        begin
          Inc(FWritePos, LN);
          if FWritePos >= FReadCount then
          begin
            ANextEvents := [];
            Exit(TCP_SERVER_POLL_DONE);
          end;
          ANextEvents := [peWritable];
          Exit(TCP_SERVER_POLL_WAIT);
        end;
      tsiorWouldBlock:
        begin
          ANextEvents := [peWritable];
          Exit(TCP_SERVER_POLL_WAIT);
        end;
    else
      ANextEvents := [];
      Exit(TCP_SERVER_POLL_DONE);
    end;
  end;

  if not (peReadable in AEvents) then
  begin
    ANextEvents := [peReadable];
    Exit(TCP_SERVER_POLL_WAIT);
  end;

  LResult := FConnRuntime.TryRead(FBuf[0], SizeUInt(SizeOf(FBuf)), LN);
  case LResult of
    tsiorOk:
      begin
        if LN = 0 then
        begin
          ANextEvents := [];
          Exit(TCP_SERVER_POLL_DONE);
        end;
        FReadCount := LN;
        FWritePos := 0;
        ANextEvents := [peWritable];
        Exit(TCP_SERVER_POLL_WAIT);
      end;
    tsiorWouldBlock:
      begin
        ANextEvents := [peReadable];
        Exit(TCP_SERVER_POLL_WAIT);
      end;
  else
    ANextEvents := [];
    Exit(TCP_SERVER_POLL_DONE);
  end;
end;

function TPollDrivenHandler.ServeConn(
  const AConn: ITcpStream): TTcpServerConnOwnership;
begin
  FServeConnCalled := True;
  Result := TCP_SERVER_CONN_OWNERSHIP_SERVER;
  Fail('poll-driven handler should bypass legacy ServeConn');
end;

function TPollDrivenHandler.NewSession(const AConn: ITcpStream;
  const AContext: ITcpServerSessionContext): ITcpServerSession;
begin
  FContextFactoryCalled := True;
  Result := TPollDrivenEchoSession.Create(Self, AConn);
end;

constructor TWakeupWork.Create(const AOwner: TWakeupPollDrivenHandler);
begin
  inherited Create;
  FOwner := AOwner;
end;

function TWakeupWork.Execute: TTcpServerConnOwnership;
begin
  InterlockedIncrement(FOwner.FWorkExecuteCount);
  FOwner.FWorkThreadId := platform_thread_id;
  platform_thread_sleep_ns(50000000);
  Result := TCP_SERVER_CONN_OWNERSHIP_SERVER;
end;

constructor TWakeupCompletion.Create(const AOwner: TWakeupPollDrivenHandler);
begin
  inherited Create;
  FOwner := AOwner;
end;

procedure TWakeupCompletion.Complete(const AOutcome: TTcpServerWorkOutcome;
  const AOwnership: TTcpServerConnOwnership);
begin
  InterlockedIncrement(FOwner.FCompletionCount);
  FOwner.FCompletionThreadId := platform_thread_id;
  FOwner.FCompletionReady := (AOutcome = TCP_SERVER_WORK_COMPLETED) and
    (AOwnership = TCP_SERVER_CONN_OWNERSHIP_SERVER);
end;

constructor TWakeupPollDrivenSession.Create(
  const AOwner: TWakeupPollDrivenHandler; const AConn: ITcpStream;
  const AHandoff: ITcpServerWorkerHandoff);
begin
  inherited Create;
  FOwner := AOwner;
  FConn := AConn;
  FHandoff := AHandoff;
  if not Supports(AConn, ITcpStreamRuntime, FConnRuntime) then
    raise Exception.Create('wakeup poll-driven session requires stream runtime seam');
  if FHandoff = nil then
    raise Exception.Create('wakeup poll-driven session requires worker handoff');
  FSubmitted := False;
  FWritePos := 0;
end;

function TWakeupPollDrivenSession.Run: TTcpServerConnOwnership;
begin
  Fail('epoll wakeup poll-driven session should not fall back to Run');
  Result := TCP_SERVER_CONN_OWNERSHIP_SERVER;
end;

function TWakeupPollDrivenSession.PollEvents: TPlatformPollEvents;
begin
  Result := [peReadable];
end;

function TWakeupPollDrivenSession.Advance(const AEvents: TPlatformPollEvents;
  out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
const
  RESPONSE_BYTES: array[0..1] of Byte = (111, 107); { 'o', 'k' }
var
  LByte: Byte;
  LN: SizeUInt;
  LResult: TTcpStreamIOResult;
  LWork: ITcpServerWork;
  LCompletion: ITcpServerWorkCompletion;
begin
  InterlockedIncrement(FOwner.FAdvanceCount);
  FOwner.FReactorThreadId := platform_thread_id;
  AOwnership := TCP_SERVER_CONN_OWNERSHIP_SERVER;

  if not FSubmitted then
  begin
    if not (peReadable in AEvents) then
    begin
      ANextEvents := [peReadable];
      Exit(TCP_SERVER_POLL_WAIT);
    end;

    LResult := FConnRuntime.TryRead(LByte, 1, LN);
    case LResult of
      tsiorOk:
        begin
          if LN = 0 then
          begin
            ANextEvents := [];
            Exit(TCP_SERVER_POLL_DONE);
          end;
          LWork := TWakeupWork.Create(FOwner);
          LCompletion := TWakeupCompletion.Create(FOwner);
          FOwner.FSubmitResult := FHandoff.Submit(LWork, LCompletion);
          if FOwner.FSubmitResult <> TCP_SERVER_HANDOFF_ACCEPTED then
          begin
            ANextEvents := [];
            Exit(TCP_SERVER_POLL_DONE);
          end;
          FSubmitted := True;
          ANextEvents := [];
          Exit(TCP_SERVER_POLL_WAIT);
        end;
      tsiorWouldBlock:
        begin
          ANextEvents := [peReadable];
          Exit(TCP_SERVER_POLL_WAIT);
        end;
    else
      ANextEvents := [];
      Exit(TCP_SERVER_POLL_DONE);
    end;
  end;

  if AEvents = [] then
    FOwner.FObservedEmptyAdvance := True;

  if not FOwner.FCompletionReady then
  begin
    ANextEvents := [];
    Exit(TCP_SERVER_POLL_WAIT);
  end;

  LResult := FConnRuntime.TryWrite(RESPONSE_BYTES[FWritePos],
    SizeUInt(Length(RESPONSE_BYTES)) - FWritePos, LN);
  case LResult of
    tsiorOk:
      begin
        Inc(FWritePos, LN);
        if FWritePos >= SizeUInt(Length(RESPONSE_BYTES)) then
        begin
          ANextEvents := [];
          Exit(TCP_SERVER_POLL_DONE);
        end;
        ANextEvents := [peWritable];
        Exit(TCP_SERVER_POLL_WAIT);
      end;
    tsiorWouldBlock:
      begin
        ANextEvents := [peWritable];
        Exit(TCP_SERVER_POLL_WAIT);
      end;
  else
    ANextEvents := [];
    Exit(TCP_SERVER_POLL_DONE);
  end;
end;

function TWakeupPollDrivenHandler.ServeConn(
  const AConn: ITcpStream): TTcpServerConnOwnership;
begin
  FServeConnCalled := True;
  Result := TCP_SERVER_CONN_OWNERSHIP_SERVER;
  Fail('wakeup poll-driven handler should bypass ServeConn');
end;

function TWakeupPollDrivenHandler.NewSession(const AConn: ITcpStream;
  const AContext: ITcpServerSessionContext): ITcpServerSession;
begin
  FContextFactoryCalled := True;
  if AContext = nil then
    raise Exception.Create('wakeup poll-driven handler requires session context');
  Result := TWakeupPollDrivenSession.Create(Self, AConn, AContext.WorkerHandoff);
end;

constructor TDeadlinePollDrivenSession.Create(
  const AOwner: TDeadlinePollDrivenHandler; const AConn: ITcpStream);
begin
  inherited Create;
  FOwner := AOwner;
  FConn := AConn;
  if not Supports(AConn, ITcpStreamRuntime, FConnRuntime) then
    raise Exception.Create('deadline poll-driven session requires stream runtime seam');
  FDeadline := TDeadline.Infinite;
  FTimerArmed := False;
  FWritePos := 0;
end;

function TDeadlinePollDrivenSession.Run: TTcpServerConnOwnership;
begin
  Fail('deadline poll-driven session should not fall back to Run');
  Result := TCP_SERVER_CONN_OWNERSHIP_SERVER;
end;

function TDeadlinePollDrivenSession.PollEvents: TPlatformPollEvents;
begin
  Result := [peReadable];
end;

function TDeadlinePollDrivenSession.Advance(const AEvents: TPlatformPollEvents;
  out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
const
  RESPONSE_BYTES: array[0..1] of Byte = (111, 107); { 'o', 'k' }
var
  LByte: Byte;
  LN: SizeUInt;
  LResult: TTcpStreamIOResult;
begin
  InterlockedIncrement(FOwner.FAdvanceCount);
  AOwnership := TCP_SERVER_CONN_OWNERSHIP_SERVER;

  if not FTimerArmed then
  begin
    if not (peReadable in AEvents) then
    begin
      ANextEvents := [peReadable];
      Exit(TCP_SERVER_POLL_WAIT);
    end;

    LResult := FConnRuntime.TryRead(LByte, 1, LN);
    case LResult of
      tsiorOk:
        begin
          if LN = 0 then
          begin
            ANextEvents := [];
            Exit(TCP_SERVER_POLL_DONE);
          end;
          FTimerArmed := True;
          FDeadline := TDeadline.After(TDuration.FromMilliseconds(50));
          ANextEvents := [];
          Exit(TCP_SERVER_POLL_WAIT);
        end;
      tsiorWouldBlock:
        begin
          ANextEvents := [peReadable];
          Exit(TCP_SERVER_POLL_WAIT);
        end;
    else
      ANextEvents := [];
      Exit(TCP_SERVER_POLL_DONE);
    end;
  end;

  if AEvents = [] then
    FOwner.FObservedDeadlineWake := True;

  LResult := FConnRuntime.TryWrite(RESPONSE_BYTES[FWritePos],
    SizeUInt(Length(RESPONSE_BYTES)) - FWritePos, LN);
  case LResult of
    tsiorOk:
      begin
        Inc(FWritePos, LN);
        if FWritePos >= SizeUInt(Length(RESPONSE_BYTES)) then
        begin
          FDeadline := TDeadline.Infinite;
          ANextEvents := [];
          Exit(TCP_SERVER_POLL_DONE);
        end;
        ANextEvents := [peWritable];
        Exit(TCP_SERVER_POLL_WAIT);
      end;
    tsiorWouldBlock:
      begin
        ANextEvents := [peWritable];
        Exit(TCP_SERVER_POLL_WAIT);
      end;
  else
    ANextEvents := [];
    Exit(TCP_SERVER_POLL_DONE);
  end;
end;

function TDeadlinePollDrivenSession.WakeDeadline: TDeadline;
begin
  Result := FDeadline;
end;

function TDeadlinePollDrivenHandler.ServeConn(
  const AConn: ITcpStream): TTcpServerConnOwnership;
begin
  FServeConnCalled := True;
  Result := TCP_SERVER_CONN_OWNERSHIP_SERVER;
  Fail('deadline poll-driven handler should bypass ServeConn');
end;

function TDeadlinePollDrivenHandler.NewSession(const AConn: ITcpStream;
  const AContext: ITcpServerSessionContext): ITcpServerSession;
begin
  FContextFactoryCalled := True;
  if AContext = nil then
    raise Exception.Create('deadline poll-driven handler requires session context');
  Result := TDeadlinePollDrivenSession.Create(Self, AConn);
end;

constructor TMockServerProvider.Create(const AOptions: TTcpServerOptions);
begin
  inherited Create;
  FOptionsBackend := AOptions.Backend;
end;

procedure TMockServerProvider.ListenAndServe(const AAddr: string; const APort: UInt16;
  const AHandler: ITcpServerHandler);
begin
  FListenCalled := True;
end;

procedure TMockServerProvider.Shutdown;
begin
  FShutdownCalled := True;
end;

function TMockServerProvider.LocalAddr: TNetAddress;
begin
  Result := TNetAddress.Any(0);
end;

function TMockServerProvider.IsRunning: Boolean;
begin
  Result := False;
end;

procedure TestDefaultOptions;
var
  LOptions: TTcpServerOptions;
begin
  LOptions := TTcpServerOptions.Default;
  Check(LOptions.Backend = TCP_SERVER_BACKEND_THREADED,
    'default backend is threaded');
end;

procedure TestThreadedServerEcho;
var
  LHandler: TEchoHandler;
  LServer: ITcpServer;
  LCtx: PServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
  LPort: UInt16;
  LClient: ITcpStream;
  LBuf: array[0..31] of Byte;
  LN: SizeUInt;
  LRet: Pointer;
begin
  LHandler := TEchoHandler.Create;
  LServer := NewTcpServer;
  New(LCtx);
  LCtx^.Server := LServer;
  LCtx^.Handler := LHandler;
  LCtx^.Addr := '127.0.0.1';
  LCtx^.Port := 0;
  platform_thread_create(LHandle, @ServerThreadFunc, LCtx);

  LWait := 0;
  while (not LServer.IsRunning) and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;

  LPort := LServer.LocalAddr.Port;
  Check(LPort > 0, 'server exposes bound port');

  LClient := TcpConnect('127.0.0.1', LPort);
  LClient.Write(PAnsiChar('ping')^, 4);
  LClient.Shutdown;
  LN := LClient.Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
  CheckEqual(SizeUInt(4), LN, 'echo size');
  CheckEqual(Byte(Ord('p')), LBuf[0], 'echo first byte');
  Check(LHandler.Called, 'handler called');
  Check(Pos('127.0.0.1', LHandler.SeenRemoteAddr) > 0, 'handler sees remote addr');
  LClient.Close;

  LServer.Shutdown;
  platform_thread_join(LHandle, LRet);
end;

procedure TestThreadedServerShutdownWithoutClients;
var
  LServer: ITcpServer;
  LCtx: PServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
  LRet: Pointer;
begin
  LServer := NewTcpServer(TTcpServerOptions.Default);
  New(LCtx);
  LCtx^.Server := LServer;
  LCtx^.Handler := TEchoHandler.Create;
  LCtx^.Addr := '127.0.0.1';
  LCtx^.Port := 0;
  platform_thread_create(LHandle, @ServerThreadFunc, LCtx);

  LWait := 0;
  while (not LServer.IsRunning) and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;

  Check(LServer.IsRunning, 'server started');
  LServer.Shutdown;
  platform_thread_join(LHandle, LRet);
  Check(not LServer.IsRunning, 'server stopped after shutdown');
end;

procedure TestThreadedServerDetachKeepsConnectionOpen;
var
  LHandler: TDetachHandler;
  LServer: ITcpServer;
  LCtx: PServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
  LPort: UInt16;
  LClient: ITcpStream;
  LBuf: array[0..31] of Byte;
  LN: SizeUInt;
  LRet: Pointer;
  LProbe: string;
begin
  LHandler := TDetachHandler.Create;
  LServer := NewTcpServer;
  New(LCtx);
  LCtx^.Server := LServer;
  LCtx^.Handler := LHandler;
  LCtx^.Addr := '127.0.0.1';
  LCtx^.Port := 0;
  platform_thread_create(LHandle, @ServerThreadFunc, LCtx);

  LWait := 0;
  while (not LServer.IsRunning) and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;

  LPort := LServer.LocalAddr.Port;
  Check(LPort > 0, 'server exposes bound port');

  LClient := TcpConnect('127.0.0.1', LPort);
  try
    LWait := 0;
    while (LHandler.Conn = nil) and (LWait < 200) do
    begin
      platform_thread_sleep_ns(5000000);
      Inc(LWait);
    end;

    Check(LHandler.Conn <> nil, 'handler captured detached connection');
    platform_thread_sleep_ns(100000000);

    LProbe := 'probe';
    LHandler.Conn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(1)));
    LClient.Write(LProbe[1], SizeUInt(Length(LProbe)));
    LN := LHandler.Conn.Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
    CheckEqual(Int64(Length(LProbe)), Int64(LN),
      'detached connection stays readable after handler returns');
    CheckEqual(Byte(Ord('p')), LBuf[0], 'detached connection received probe');

    LHandler.Conn.Shutdown;
    LHandler.Conn.Close;
  finally
    LClient.Close;
  end;

  LServer.Shutdown;
  platform_thread_join(LHandle, LRet);
end;

procedure TestThreadedServerHandlerExceptionDoesNotStopAcceptLoop;
var
  LHandler: TFailOnceHandler;
  LServer: ITcpServer;
  LCtx: PServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
  LPort: UInt16;
  LClient: ITcpStream;
  LBuf: array[0..31] of Byte;
  LN: SizeUInt;
  LRet: Pointer;
begin
  LHandler := TFailOnceHandler.Create;
  LServer := NewTcpServer;
  New(LCtx);
  LCtx^.Server := LServer;
  LCtx^.Handler := LHandler;
  LCtx^.Addr := '127.0.0.1';
  LCtx^.Port := 0;
  platform_thread_create(LHandle, @ServerThreadFunc, LCtx);

  LWait := 0;
  while (not LServer.IsRunning) and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;

  LPort := LServer.LocalAddr.Port;
  Check(LPort > 0, 'server exposes bound port');

  LClient := TcpConnect('127.0.0.1', LPort);
  try
    LClient.Write(PAnsiChar('boom')^, 4);
    LClient.Shutdown;
  finally
    LClient.Close;
  end;

  platform_thread_sleep_ns(100000000);
  Check(LServer.IsRunning, 'server keeps running after handler exception');

  LClient := TcpConnect('127.0.0.1', LPort);
  try
    LClient.Write(PAnsiChar('pong')^, 4);
    LClient.Shutdown;
    LN := LClient.Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
    CheckEqual(SizeUInt(4), LN, 'second connection still echoes');
    CheckEqual(Byte(Ord('p')), LBuf[0], 'second connection first byte');
  finally
    LClient.Close;
  end;

  CheckEqual(Int64(2), Int64(LHandler.Calls), 'handler saw both connections');

  LServer.Shutdown;
  platform_thread_join(LHandle, LRet);
end;

procedure TestThreadedServerShutdownWithWildcardListen;
var
  LServer: ITcpServer;
  LCtx: PServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
  LRet: Pointer;
begin
  LServer := NewTcpServer(TTcpServerOptions.Default);
  New(LCtx);
  LCtx^.Server := LServer;
  LCtx^.Handler := TEchoHandler.Create;
  LCtx^.Addr := '0.0.0.0';
  LCtx^.Port := 0;
  platform_thread_create(LHandle, @ServerThreadFunc, LCtx);

  LWait := 0;
  while (not LServer.IsRunning) and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;

  Check(LServer.IsRunning, 'wildcard listener started');
  Check(LServer.LocalAddr.Port > 0, 'wildcard listener exposes bound port');
  LServer.Shutdown;
  platform_thread_join(LHandle, LRet);
  Check(not LServer.IsRunning, 'wildcard listener stopped after shutdown');
end;

procedure TestThreadedServerShutdownWithEmptyListenAddr;
var
  LServer: ITcpServer;
  LCtx: PServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
  LRet: Pointer;
begin
  LServer := NewTcpServer(TTcpServerOptions.Default);
  New(LCtx);
  LCtx^.Server := LServer;
  LCtx^.Handler := TEchoHandler.Create;
  LCtx^.Addr := '';
  LCtx^.Port := 0;
  platform_thread_create(LHandle, @ServerThreadFunc, LCtx);

  LWait := 0;
  while (not LServer.IsRunning) and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;

  Check(LServer.IsRunning, 'empty-addr listener started');
  Check(LServer.LocalAddr.Port > 0, 'empty-addr listener exposes bound port');
  LServer.Shutdown;
  platform_thread_join(LHandle, LRet);
  Check(not LServer.IsRunning, 'empty-addr listener stopped after shutdown');
end;

procedure TestThreadedServerPrefersSessionFactoryWhenAvailable;
var
  LHandler: TSessionFactoryHandler;
  LServer: ITcpServer;
  LCtx: PServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
  LPort: UInt16;
  LClient: ITcpStream;
  LBuf: array[0..31] of Byte;
  LN: SizeUInt;
  LRet: Pointer;
begin
  LHandler := TSessionFactoryHandler.Create;
  LServer := NewTcpServer;
  New(LCtx);
  LCtx^.Server := LServer;
  LCtx^.Handler := LHandler;
  LCtx^.Addr := '127.0.0.1';
  LCtx^.Port := 0;
  platform_thread_create(LHandle, @ServerThreadFunc, LCtx);

  LWait := 0;
  while (not LServer.IsRunning) and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;

  LPort := LServer.LocalAddr.Port;
  Check(LPort > 0, 'session-factory server exposes bound port');

  LClient := TcpConnect('127.0.0.1', LPort);
  try
    LClient.Write(PAnsiChar('ping')^, 4);
    LClient.Shutdown;
    LN := LClient.Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
    CheckEqual(SizeUInt(4), LN, 'session path echo size');
    CheckEqual(Byte(Ord('p')), LBuf[0], 'session path first byte');
  finally
    LClient.Close;
  end;

  CheckEqual(Int64(1), Int64(LHandler.CreateCount),
    'threaded runtime created one session');
  CheckEqual(Int64(1), Int64(LHandler.RunCount),
    'threaded runtime ran session once');

  LServer.Shutdown;
  platform_thread_join(LHandle, LRet);
end;

procedure TestThreadedServerPrefersContextSessionFactoryWhenAvailable;
var
  LHandler: TContextAwareHandler;
  LServer: ITcpServer;
  LCtx: PServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
  LPort: UInt16;
  LClient: ITcpStream;
  LRet: Pointer;
begin
  LHandler := TContextAwareHandler.Create(csmClose);
  LServer := NewTcpServer;
  New(LCtx);
  LCtx^.Server := LServer;
  LCtx^.Handler := LHandler;
  LCtx^.Addr := '127.0.0.1';
  LCtx^.Port := 0;
  platform_thread_create(LHandle, @ServerThreadFunc, LCtx);

  LWait := 0;
  while (not LServer.IsRunning) and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;

  LPort := LServer.LocalAddr.Port;
  Check(LPort > 0, 'context-factory server exposes bound port');

  LClient := TcpConnect('127.0.0.1', LPort);
  try
    LClient.Close;
  except
    LClient.Close;
    raise;
  end;

  LWait := 0;
  while (not LHandler.ContextFactoryCalled) and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;

  Check(LHandler.ContextFactoryCalled,
    'context-aware session factory was called');
  Check(not LHandler.LegacyFactoryCalled,
    'legacy session factory was bypassed');
  Check(not LHandler.ServeConnCalled, 'ServeConn was bypassed');
  Check(LHandler.ContextSeen, 'context-aware factory received context');
  Check(LHandler.WorkerHandoffSeen,
    'context-aware factory received worker handoff');
  Check(LHandler.CapturedHandoff <> nil, 'worker handoff captured');

  LServer.Shutdown;
  platform_thread_join(LHandle, LRet);
end;

procedure TestThreadedServerAcceptedHandoffCompletesExactlyOnce;
var
  LHandler: TContextAwareHandler;
  LServer: ITcpServer;
  LCtx: PServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
  LPort: UInt16;
  LClient: ITcpStream;
  LRet: Pointer;
begin
  LHandler := TContextAwareHandler.Create(csmSubmitCompleted);
  LServer := NewTcpServer;
  New(LCtx);
  LCtx^.Server := LServer;
  LCtx^.Handler := LHandler;
  LCtx^.Addr := '127.0.0.1';
  LCtx^.Port := 0;
  platform_thread_create(LHandle, @ServerThreadFunc, LCtx);

  LWait := 0;
  while (not LServer.IsRunning) and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;

  LPort := LServer.LocalAddr.Port;
  Check(LPort > 0, 'accepted-handoff server exposes bound port');

  LClient := TcpConnect('127.0.0.1', LPort);
  try
    LClient.Close;
  except
    LClient.Close;
    raise;
  end;

  LWait := 0;
  while (LHandler.CompletionCount = 0) and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;

  CheckEqual(Int64(Ord(TCP_SERVER_HANDOFF_ACCEPTED)),
    Int64(Ord(LHandler.SubmitResult)), 'handoff was accepted');
  CheckEqual(Int64(1), Int64(LHandler.WorkExecuteCount),
    'accepted handoff executed exactly once');
  CheckEqual(Int64(1), Int64(LHandler.CompletionCount),
    'accepted handoff completed exactly once');
  CheckEqual(Int64(Ord(TCP_SERVER_WORK_COMPLETED)),
    Int64(Ord(LHandler.LastWorkOutcome)),
    'accepted handoff reports completed outcome');
  CheckEqual(Int64(Ord(TCP_SERVER_CONN_OWNERSHIP_SERVER)),
    Int64(Ord(LHandler.LastOwnership)),
    'accepted handoff reports server ownership');
  Check(LHandler.RunThreadId <> 0, 'session run captured thread id');
  Check(LHandler.WorkThreadId <> 0, 'handoff work captured thread id');
  Check(LHandler.WorkThreadId <> LHandler.RunThreadId,
    'handoff work ran off the session thread');

  LServer.Shutdown;
  platform_thread_join(LHandle, LRet);
end;

procedure TestThreadedServerFailingHandoffReportsFailedOutcome;
var
  LHandler: TContextAwareHandler;
  LServer: ITcpServer;
  LCtx: PServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
  LPort: UInt16;
  LClient: ITcpStream;
  LRet: Pointer;
begin
  LHandler := TContextAwareHandler.Create(csmSubmitFailing);
  LServer := NewTcpServer;
  New(LCtx);
  LCtx^.Server := LServer;
  LCtx^.Handler := LHandler;
  LCtx^.Addr := '127.0.0.1';
  LCtx^.Port := 0;
  platform_thread_create(LHandle, @ServerThreadFunc, LCtx);

  LWait := 0;
  while (not LServer.IsRunning) and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;

  LPort := LServer.LocalAddr.Port;
  Check(LPort > 0, 'failing-handoff server exposes bound port');

  LClient := TcpConnect('127.0.0.1', LPort);
  try
    LClient.Close;
  except
    LClient.Close;
    raise;
  end;

  LWait := 0;
  while (LHandler.CompletionCount = 0) and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;

  CheckEqual(Int64(Ord(TCP_SERVER_HANDOFF_ACCEPTED)),
    Int64(Ord(LHandler.SubmitResult)), 'failing handoff was accepted');
  CheckEqual(Int64(1), Int64(LHandler.WorkExecuteCount),
    'failing handoff executed exactly once');
  CheckEqual(Int64(1), Int64(LHandler.CompletionCount),
    'failing handoff completed exactly once');
  CheckEqual(Int64(Ord(TCP_SERVER_WORK_FAILED)),
    Int64(Ord(LHandler.LastWorkOutcome)),
    'failing handoff reports failed outcome');
  CheckEqual(Int64(Ord(TCP_SERVER_CONN_OWNERSHIP_SERVER)),
    Int64(Ord(LHandler.LastOwnership)),
    'failing handoff falls back to server ownership');

  LServer.Shutdown;
  platform_thread_join(LHandle, LRet);
end;

procedure TestThreadedServerRejectsHandoffAfterShutdown;
var
  LHandler: TContextAwareHandler;
  LHandlerRef: ITcpServerHandler;
  LServer: ITcpServer;
  LCtx: PServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
  LPort: UInt16;
  LClient: ITcpStream;
  LRet: Pointer;
  LHandoff: ITcpServerWorkerHandoff;
  LWork: ITcpServerWork;
  LCompletion: ITcpServerWorkCompletion;
  LResult: TTcpServerHandoffResult;
begin
  LHandler := TContextAwareHandler.Create(csmClose);
  LHandlerRef := LHandler;
  Check(LHandlerRef <> nil, 'handler keepalive installed');
  LServer := NewTcpServer;
  New(LCtx);
  LCtx^.Server := LServer;
  LCtx^.Handler := LHandler;
  LCtx^.Addr := '127.0.0.1';
  LCtx^.Port := 0;
  platform_thread_create(LHandle, @ServerThreadFunc, LCtx);

  LWait := 0;
  while (not LServer.IsRunning) and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;

  LPort := LServer.LocalAddr.Port;
  Check(LPort > 0, 'shutdown-handoff server exposes bound port');

  LClient := TcpConnect('127.0.0.1', LPort);
  try
    LClient.Close;
  except
    LClient.Close;
    raise;
  end;

  LWait := 0;
  while ((not LHandler.ContextFactoryCalled) or (LHandler.CapturedHandoff = nil))
    and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;

  Check(LHandler.CapturedHandoff <> nil,
    'captured handoff before shutdown');
  LHandoff := LHandler.CapturedHandoff;

  LServer.Shutdown;
  platform_thread_join(LHandle, LRet);

  LWork := THandoffWork.Create(LHandler, False);
  LCompletion := THandoffCompletion.Create(LHandler, nil);
  LResult := LHandoff.Submit(LWork, LCompletion);
  platform_thread_sleep_ns(100000000);

  CheckEqual(Int64(Ord(TCP_SERVER_HANDOFF_SHUTTING_DOWN)),
    Int64(Ord(LResult)), 'handoff rejects new work after shutdown');
  CheckEqual(Int64(0), Int64(LHandler.WorkExecuteCount),
    'shutdown handoff does not execute work');
  CheckEqual(Int64(0), Int64(LHandler.CompletionCount),
    'shutdown handoff does not call completion');
end;

procedure TestThreadedServerPollDrivenSessionFallsBackToRun;
var
  LHandler: TPollDrivenHandler;
  LHandlerRef: ITcpServerHandler;
  LServer: ITcpServer;
  LCtx: PServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
  LPort: UInt16;
  LClient: ITcpStream;
  LBuf: array[0..31] of Byte;
  LN: SizeUInt;
  LRet: Pointer;
begin
  LHandler := TPollDrivenHandler.Create;
  LHandlerRef := LHandler;
  Check(LHandlerRef <> nil, 'poll-driven threaded handler keepalive installed');
  LServer := NewTcpServer;
  New(LCtx);
  LCtx^.Server := LServer;
  LCtx^.Handler := LHandler;
  LCtx^.Addr := '127.0.0.1';
  LCtx^.Port := 0;
  platform_thread_create(LHandle, @ServerThreadFunc, LCtx);

  LWait := 0;
  while (not LServer.IsRunning) and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;

  LPort := LServer.LocalAddr.Port;
  Check(LPort > 0, 'poll-driven threaded server exposes bound port');

  LClient := TcpConnect('127.0.0.1', LPort);
  try
    LClient.Write(PAnsiChar('ping')^, 4);
    LClient.Shutdown;
    LN := LClient.Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
    CheckEqual(SizeUInt(4), LN, 'poll-driven threaded echo size');
    CheckEqual(Byte(Ord('p')), LBuf[0], 'poll-driven threaded first byte');
  finally
    LClient.Close;
  end;

  Check(LHandler.ContextFactoryCalled,
    'threaded runtime still uses context-aware session factory');
  Check(not LHandler.ServeConnCalled,
    'threaded poll-driven handler bypasses ServeConn');
  CheckEqual(Int64(1), Int64(LHandler.RunCount),
    'threaded backend falls back to blocking Run');
  CheckEqual(Int64(0), Int64(LHandler.AdvanceCount),
    'threaded backend does not drive poll session');

  LServer.Shutdown;
  platform_thread_join(LHandle, LRet);
end;

procedure TestBuiltInThreadedBackendFactoryExists;
var
  LFactory: TTcpServerFactory;
begin
  Check(TryGetTcpServerFactory(TCP_SERVER_BACKEND_THREADED, LFactory),
    'threaded backend factory is registered');
  Check(Assigned(LFactory), 'threaded backend factory is assigned');
end;

procedure TestKqueueBackendSourceContract;
var
  LKqueueSource: string;
  LFacadeSource: string;
begin
  LKqueueSource := LoadSourceText('src/nextpas.core.net.server.kqueue.pas');
  Check(Pos('function newtcpkqueueserver', LKqueueSource) > 0,
    'kqueue unit should expose a named backend constructor');
  Check(Pos('nextpas.core.net.server.readiness', LKqueueSource) > 0,
    'kqueue unit should depend on shared readiness owner');
  Check(Pos('result := newtcpreadinessserver(aoptions);', LKqueueSource) > 0,
    'kqueue unit should forward directly to shared readiness owner');

  LFacadeSource := LoadSourceText('src/nextpas.core.net.server.pas');
  Check(Pos('nextpas.core.net.server.kqueue', LFacadeSource) > 0,
    'facade should include the kqueue backend unit');
  Check(Pos('@nextpas.core.net.server.kqueue.newtcpkqueueserver', LFacadeSource) > 0,
    'facade should register the kqueue backend factory');
  {$IFDEF NEXTPAS_LINUX}
  Check(not HasTcpServerFactory(TCP_SERVER_BACKEND_KQUEUE),
    'linux should not expose built-in kqueue backend registration');
  {$ENDIF}
end;

procedure TestReadinessConsumerUsesPlatformPollerSourceContract;
var
  LSource: string;
begin
  LSource := LoadSourceText('src/nextpas.core.net.server.readiness.pas');

  CheckSourceContains(LSource, 'nextpas.core.platform.io.base',
    'readiness consumer should use platform io base contract');
  CheckSourceContains(LSource, 'nextpas.core.platform.io',
    'readiness consumer should use platform poller facade');
  CheckSourceNotContains(LSource, 'nextpas.core.io.poller',
    'readiness consumer must not depend on completion poller');
  CheckSourceNotContains(LSource, 'nextpas.core.io.reactor',
    'readiness consumer must not depend on completion reactor');
  CheckSourceNotContains(LSource, 'iocp',
    'readiness consumer must not mention IOCP/proactor implementation');

  CheckSourceContains(LSource, 'platform_poller_create',
    'readiness consumer should create readiness poller through platform facade');
  CheckSourceContains(LSource, 'platform_poller_enable_wake',
    'readiness consumer should enable wake through platform facade');
  CheckSourceContains(LSource, 'platform_poller_add',
    'readiness consumer should add readiness interests through platform facade');
  CheckSourceContains(LSource, 'platform_poller_modify',
    'readiness consumer should modify readiness interests through platform facade');
  CheckSourceContains(LSource, 'platform_poller_remove',
    'readiness consumer should remove readiness interests through platform facade');
  CheckSourceContains(LSource, 'platform_poller_wait',
    'readiness consumer should wait through platform facade');
  CheckSourceContains(LSource, 'platform_poller_wake',
    'readiness consumer should wake through platform facade');
  CheckSourceContains(LSource, 'platform_poller_drain_wake',
    'readiness consumer should drain wake through platform facade');
end;

procedure TestReadinessUserDataPreservationSourceContract;
var
  LSource: string;
  LWaitLoop: string;
begin
  LSource := LoadSourceText('src/nextpas.core.net.server.readiness.pas');

  CheckSourceContains(LSource, 'const wake_userdata = pointer(ptruint(1));',
    'wake userdata should be a stable non-nil sentinel');
  CheckSourceContains(LSource, 'platform_poller_enable_wake(fpoller, wake_userdata)',
    'wake registration should preserve the wake sentinel');
  CheckSourceContains(LSource, '[pereadable], nil);',
    'listener registration should preserve nil userdata');
  CheckSourceContains(LSource,
    'platform_poller_add(fpoller, ltarget.sockethandle,',
    'session registration should preserve target pointer userdata');

  LWaitLoop := ExtractSourceRange(LSource,
    'for li := 0 to lcount - 1 do',
    'handleexpiredpolltargets;',
    'readiness wait loop');
  CheckSourceOrder(LWaitLoop, 'lentries[li].userdata = wake_userdata',
    'platform_poller_drain_wake(fpoller);',
    'wake userdata should be drained before completion dispatch');
  CheckSourceOrder(LWaitLoop, 'lentries[li].userdata = wake_userdata',
    'drainpendingcompletions;',
    'wake userdata should dispatch queued completions');
  CheckSourceOrder(LWaitLoop, 'lentries[li].userdata = nil',
    'handlelistenerready(ahandler);',
    'nil userdata should be treated as listener readiness');
  CheckSourceOrder(LWaitLoop, 'ltarget := ttcpserverpollsessiontarget(lentries[li].userdata);',
    'handlepolltarget(ltarget, lentries[li].revents);',
    'non-sentinel non-nil userdata should be treated as session target pointer');
end;

procedure TestReadinessEmptyInterestSourceContract;
var
  LSource: string;
  LRegister: string;
  LHandle: string;
begin
  LSource := LoadSourceText('src/nextpas.core.net.server.readiness.pas');

  CheckSourceContains(LSource, 'handlepolltarget(litems[li].target, []);',
    'completion wake should re-enter session with empty readiness events');
  CheckSourceContains(LSource, 'handlepolltarget(lexpired[li], []);',
    'deadline wake should re-enter session with empty readiness events');

  LRegister := ExtractSourceRange(LSource,
    'function ttcpreadinessserver.tryregisterpolldrivensession',
    'procedure ttcpreadinessserver.enqueuecompletion',
    'poll target registration');
  CheckSourceOrder(LRegister, 'if ltarget.currentevents <> [] then',
    'acontext.bindtarget(ltarget);',
    'empty-interest targets should bind even when no socket interest is registered');
  CheckSourceOrder(LRegister, 'acontext.bindtarget(ltarget);',
    'registerpolltarget(ltarget);',
    'empty-interest targets should remain owned by registry after context binding');

  LHandle := ExtractSourceRange(LSource,
    'procedure ttcpreadinessserver.handlepolltarget',
    'procedure ttcpreadinessserver.handlelistenerready',
    'poll target handler');
  CheckSourceContains(LHandle, 'if lnextevents = [] then',
    'empty next events should be handled as a legal wait state');
  CheckSourceOrder(LHandle, 'platform_poller_remove(fpoller, atarget.sockethandle);',
    'atarget.setcurrentevents(lnextevents);',
    'empty-interest transition should remove readiness interest before recording empty state');
end;

procedure TestReadinessWakeFallbackSourceContract;
var
  LSource: string;
  LShutdown: string;
begin
  LSource := LoadSourceText('src/nextpas.core.net.server.readiness.pas');
  LShutdown := ExtractSourceRange(LSource,
    'procedure ttcpreadinessserver.shutdown',
    'function ttcpreadinessserver.localaddr',
    'readiness shutdown');

  CheckSourceOrder(LShutdown, 'frunning := false;',
    'lwoken := platform_poller_wake(fpoller) = 0;',
    'shutdown should first request the regular readiness wake contract');
  CheckSourceOrder(LShutdown, 'if not lwoken then',
    'lwake := nettcpconnect(laddr.ip, laddr.port);',
    'listener-connect wake should remain a fallback path only');
  CheckSourceOrder(LShutdown, 'lwake.close;',
    'flistener.close;',
    'fallback connection should be closed before listener shutdown continues');
end;

procedure TestReadinessPollTargetLifecycleSourceContract;
var
  LSource: string;
  LRegister: string;
  LHandle: string;
  LDoneBlock: string;
  LExceptBlock: string;
begin
  LSource := LoadSourceText('src/nextpas.core.net.server.readiness.pas');

  LRegister := ExtractSourceRange(LSource,
    'function ttcpreadinessserver.tryregisterpolldrivensession',
    'procedure ttcpreadinessserver.enqueuecompletion',
    'poll target registration lifecycle');
  CheckSourceContains(LRegister, 'closeserverownedtcpconn(aconn);',
    'registration failure should close the server-owned connection before propagating');

  LHandle := ExtractSourceRange(LSource,
    'procedure ttcpreadinessserver.handlepolltarget',
    'procedure ttcpreadinessserver.handlelistenerready',
    'poll target lifecycle handler');
  LDoneBlock := ExtractSourceRange(LHandle,
    'if lresult = tsprdone then',
    'if lnextevents <> atarget.currentevents then',
    'done lifecycle branch');
  CheckSourceOrder(LDoneBlock, 'platform_poller_remove(fpoller, atarget.sockethandle);',
    'unregisterpolltarget(atarget);',
    'done branch should remove readiness interest before unregistering target');
  CheckSourceOrder(LDoneBlock, 'unregisterpolltarget(atarget);',
    'closeserverownedtcpconn(atarget.connection);',
    'done branch should unregister before closing server-owned connection');
  CheckSourceOrder(LDoneBlock, 'closeserverownedtcpconn(atarget.connection);',
    'atarget.free;',
    'done branch should close connection before releasing target owner');

  LExceptBlock := Copy(LHandle, Pos('except', LHandle), MaxInt);
  CheckSourceOrder(LExceptBlock, 'platform_poller_remove(fpoller, atarget.sockethandle);',
    'unregisterpolltarget(atarget);',
    'exception branch should remove readiness interest before unregistering target');
  CheckSourceOrder(LExceptBlock, 'unregisterpolltarget(atarget);',
    'closeserverownedtcpconn(atarget.connection);',
    'exception branch should unregister before closing server-owned connection');
  CheckSourceOrder(LExceptBlock, 'closeserverownedtcpconn(atarget.connection);',
    'atarget.free;',
    'exception branch should close connection before releasing target owner');
end;

procedure TestCustomBackendFactoryOverridesSelection;
var
  LOldFactory: TTcpServerFactory;
  LHadFactory: Boolean;
  LOptions: TTcpServerOptions;
  LServer: ITcpServer;
begin
  LHadFactory := TryGetTcpServerFactory(TCP_SERVER_BACKEND_KQUEUE, LOldFactory);
  RegisterTcpServerFactory(TCP_SERVER_BACKEND_KQUEUE, @CreateMockServerProvider);
  GProviderFactoryCalls := 0;
  GLastMockProvider := nil;
  try
    LOptions := TTcpServerOptions.Default;
    LOptions.Backend := TCP_SERVER_BACKEND_KQUEUE;
    LServer := NewTcpServer(LOptions);
    Check(LServer <> nil, 'custom backend factory returns server');
    Check(GLastMockProvider <> nil, 'custom backend factory is used');
    CheckEqual(Int64(1), Int64(GProviderFactoryCalls),
      'custom backend factory called exactly once');
    CheckEqual(Int64(Ord(TCP_SERVER_BACKEND_KQUEUE)),
      Int64(Ord(GLastMockProvider.OptionsBackend)),
      'custom backend factory sees requested backend');
  finally
    if LHadFactory then
      RegisterTcpServerFactory(TCP_SERVER_BACKEND_KQUEUE, LOldFactory)
    else
      UnregisterTcpServerFactory(TCP_SERVER_BACKEND_KQUEUE);
    GLastMockProvider := nil;
  end;
end;

procedure TestMissingBackendFactoryRaisesNotSupported;
var
  LOldFactory: TTcpServerFactory;
  LHadFactory: Boolean;
  LOptions: TTcpServerOptions;
  LRaised: Boolean;
begin
  LHadFactory := TryGetTcpServerFactory(TCP_SERVER_BACKEND_IOCP, LOldFactory);
  UnregisterTcpServerFactory(TCP_SERVER_BACKEND_IOCP);
  LRaised := False;
  try
    LOptions := TTcpServerOptions.Default;
    LOptions.Backend := TCP_SERVER_BACKEND_IOCP;
    NewTcpServer(LOptions);
  except
    on E: ENotSupportedError do
      LRaised := True;
  end;
  if LHadFactory then
    RegisterTcpServerFactory(TCP_SERVER_BACKEND_IOCP, LOldFactory);
  Check(LRaised, 'missing backend factory raises ENotSupportedError');
end;

{$IFDEF NEXTPAS_LINUX}
procedure TestReadinessServerWakesPollDrivenSessionAfterWorkerCompletion;
var
  LHandler: TWakeupPollDrivenHandler;
  LHandlerRef: ITcpServerHandler;
  LServer: ITcpServer;
  LCtx: PServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
  LPort: UInt16;
  LClient: ITcpStream;
  LBuf: array[0..7] of Byte;
  LN: SizeUInt;
  LRet: Pointer;
begin
  LHandler := TWakeupPollDrivenHandler.Create;
  LHandlerRef := LHandler;
  Check(LHandlerRef <> nil, 'readiness handler keepalive installed');
  LServer := NewTcpReadinessServer(TTcpServerOptions.Default);
  New(LCtx);
  LCtx^.Server := LServer;
  LCtx^.Handler := LHandler;
  LCtx^.Addr := '127.0.0.1';
  LCtx^.Port := 0;
  platform_thread_create(LHandle, @ServerThreadFunc, LCtx);

  LWait := 0;
  while (not LServer.IsRunning) and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;

  LPort := LServer.LocalAddr.Port;
  Check(LPort > 0, 'readiness server exposes bound port');

  LClient := TcpConnect('127.0.0.1', LPort);
  try
    LClient.Write(PAnsiChar('x')^, 1);
    LN := LClient.Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
    CheckEqual(SizeUInt(2), LN, 'readiness response size');
    CheckEqual(Byte(Ord('o')), LBuf[0], 'readiness first byte');
    CheckEqual(Byte(Ord('k')), LBuf[1], 'readiness second byte');
  finally
    LClient.Close;
  end;

  LWait := 0;
  while (LHandler.CompletionCount = 0) and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;

  Check(LHandler.ContextFactoryCalled,
    'readiness path uses context-aware session factory');
  Check(not LHandler.ServeConnCalled,
    'readiness path bypasses ServeConn');
  CheckEqual(Int64(Ord(TCP_SERVER_HANDOFF_ACCEPTED)),
    Int64(Ord(LHandler.SubmitResult)), 'readiness handoff accepted');
  CheckEqual(Int64(1), Int64(LHandler.WorkExecuteCount),
    'readiness work executed once');
  CheckEqual(Int64(1), Int64(LHandler.CompletionCount),
    'readiness completion executed once');
  Check(LHandler.AdvanceCount > 1,
    'readiness path re-enters poll-driven session after completion');
  Check(LHandler.ObservedEmptyAdvance,
    'readiness path re-enters session without socket readiness');
  Check(LHandler.ReactorThreadId <> 0, 'readiness path captured reactor thread');
  Check(LHandler.WorkThreadId <> 0, 'readiness path captured worker thread');
  Check(LHandler.CompletionThreadId <> 0,
    'readiness path captured completion thread');
  Check(LHandler.WorkThreadId <> LHandler.ReactorThreadId,
    'readiness worker runs off reactor thread');
  CheckEqual(Int64(LHandler.ReactorThreadId), Int64(LHandler.CompletionThreadId),
    'readiness completion returns to reactor thread');

  LServer.Shutdown;
  platform_thread_join(LHandle, LRet);
end;

procedure TestEpollServerEcho;
var
  LHandler: TEchoHandler;
  LHandlerRef: ITcpServerHandler;
  LServer: ITcpServer;
  LCtx: PServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
  LPort: UInt16;
  LClient: ITcpStream;
  LBuf: array[0..31] of Byte;
  LN: SizeUInt;
  LRet: Pointer;
  LOptions: TTcpServerOptions;
begin
  LHandler := TEchoHandler.Create;
  LHandlerRef := LHandler;
  Check(LHandlerRef <> nil, 'epoll echo handler keepalive installed');
  LOptions := TTcpServerOptions.Default;
  LOptions.Backend := TCP_SERVER_BACKEND_EPOLL;
  LServer := NewTcpServer(LOptions);
  New(LCtx);
  LCtx^.Server := LServer;
  LCtx^.Handler := LHandler;
  LCtx^.Addr := '127.0.0.1';
  LCtx^.Port := 0;
  platform_thread_create(LHandle, @ServerThreadFunc, LCtx);

  LWait := 0;
  while (not LServer.IsRunning) and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;

  LPort := LServer.LocalAddr.Port;
  Check(LPort > 0, 'epoll server exposes bound port');

  LClient := TcpConnect('127.0.0.1', LPort);
  try
    LClient.Write(PAnsiChar('ping')^, 4);
    LClient.Shutdown;
    LN := LClient.Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
    CheckEqual(SizeUInt(4), LN, 'epoll echo size');
    CheckEqual(Byte(Ord('p')), LBuf[0], 'epoll echo first byte');
  finally
    LClient.Close;
  end;

  Check(LHandler.Called, 'epoll handler called');
  Check(Pos('127.0.0.1', LHandler.SeenRemoteAddr) > 0,
    'epoll handler sees remote addr');

  LServer.Shutdown;
  platform_thread_join(LHandle, LRet);
end;

procedure TestEpollServerShutdownWithoutClients;
var
  LServer: ITcpServer;
  LCtx: PServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
  LRet: Pointer;
  LOptions: TTcpServerOptions;
begin
  LOptions := TTcpServerOptions.Default;
  LOptions.Backend := TCP_SERVER_BACKEND_EPOLL;
  LServer := NewTcpServer(LOptions);
  New(LCtx);
  LCtx^.Server := LServer;
  LCtx^.Handler := TEchoHandler.Create;
  LCtx^.Addr := '127.0.0.1';
  LCtx^.Port := 0;
  platform_thread_create(LHandle, @ServerThreadFunc, LCtx);

  LWait := 0;
  while (not LServer.IsRunning) and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;

  Check(LServer.IsRunning, 'epoll server started');
  LServer.Shutdown;
  platform_thread_join(LHandle, LRet);
  Check(not LServer.IsRunning, 'epoll server stopped after shutdown');
end;

procedure TestEpollServerPrefersContextSessionFactoryWhenAvailable;
var
  LHandler: TContextAwareHandler;
  LHandlerRef: ITcpServerHandler;
  LServer: ITcpServer;
  LCtx: PServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
  LPort: UInt16;
  LClient: ITcpStream;
  LRet: Pointer;
  LOptions: TTcpServerOptions;
begin
  LHandler := TContextAwareHandler.Create(csmClose);
  LHandlerRef := LHandler;
  Check(LHandlerRef <> nil, 'epoll context handler keepalive installed');
  LOptions := TTcpServerOptions.Default;
  LOptions.Backend := TCP_SERVER_BACKEND_EPOLL;
  LServer := NewTcpServer(LOptions);
  New(LCtx);
  LCtx^.Server := LServer;
  LCtx^.Handler := LHandler;
  LCtx^.Addr := '127.0.0.1';
  LCtx^.Port := 0;
  platform_thread_create(LHandle, @ServerThreadFunc, LCtx);

  LWait := 0;
  while (not LServer.IsRunning) and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;

  LPort := LServer.LocalAddr.Port;
  Check(LPort > 0, 'epoll context server exposes bound port');

  LClient := TcpConnect('127.0.0.1', LPort);
  try
    LClient.Close;
  except
    LClient.Close;
    raise;
  end;

  LWait := 0;
  while (not LHandler.ContextFactoryCalled) and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;

  Check(LHandler.ContextFactoryCalled,
    'epoll context-aware session factory was called');
  Check(not LHandler.LegacyFactoryCalled,
    'epoll legacy session factory was bypassed');
  Check(not LHandler.ServeConnCalled, 'epoll ServeConn was bypassed');
  Check(LHandler.ContextSeen, 'epoll context-aware factory received context');
  Check(LHandler.WorkerHandoffSeen,
    'epoll context-aware factory received worker handoff');
  Check(LHandler.CapturedHandoff <> nil, 'epoll worker handoff captured');

  LServer.Shutdown;
  platform_thread_join(LHandle, LRet);
end;

procedure TestEpollServerUsesPollDrivenSessionWhenAvailable;
var
  LHandler: TPollDrivenHandler;
  LHandlerRef: ITcpServerHandler;
  LServer: ITcpServer;
  LCtx: PServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
  LPort: UInt16;
  LClient: ITcpStream;
  LBuf: array[0..31] of Byte;
  LN: SizeUInt;
  LRet: Pointer;
  LOptions: TTcpServerOptions;
begin
  LHandler := TPollDrivenHandler.Create;
  LHandlerRef := LHandler;
  Check(LHandlerRef <> nil, 'poll-driven epoll handler keepalive installed');
  LOptions := TTcpServerOptions.Default;
  LOptions.Backend := TCP_SERVER_BACKEND_EPOLL;
  LServer := NewTcpServer(LOptions);
  New(LCtx);
  LCtx^.Server := LServer;
  LCtx^.Handler := LHandler;
  LCtx^.Addr := '127.0.0.1';
  LCtx^.Port := 0;
  platform_thread_create(LHandle, @ServerThreadFunc, LCtx);

  LWait := 0;
  while (not LServer.IsRunning) and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;

  LPort := LServer.LocalAddr.Port;
  Check(LPort > 0, 'poll-driven epoll server exposes bound port');

  LClient := TcpConnect('127.0.0.1', LPort);
  try
    LClient.Write(PAnsiChar('ping')^, 4);
    LClient.Shutdown;
    LN := LClient.Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
    CheckEqual(SizeUInt(4), LN, 'poll-driven epoll echo size');
    CheckEqual(Byte(Ord('p')), LBuf[0], 'poll-driven epoll first byte');
  finally
    LClient.Close;
  end;

  LWait := 0;
  while (LHandler.AdvanceCount = 0) and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;

  Check(LHandler.ContextFactoryCalled,
    'epoll runtime uses context-aware session factory for poll-driven session');
  Check(not LHandler.ServeConnCalled,
    'epoll poll-driven handler bypasses ServeConn');
  CheckEqual(Int64(0), Int64(LHandler.RunCount),
    'epoll backend does not fall back to blocking Run');
  Check(LHandler.AdvanceCount > 0,
    'epoll backend drives poll session via Advance');

  LServer.Shutdown;
  platform_thread_join(LHandle, LRet);
end;

procedure TestEpollServerWakesPollDrivenSessionAfterWorkerCompletion;
var
  LHandler: TWakeupPollDrivenHandler;
  LHandlerRef: ITcpServerHandler;
  LServer: ITcpServer;
  LCtx: PServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
  LPort: UInt16;
  LClient: ITcpStream;
  LBuf: array[0..7] of Byte;
  LN: SizeUInt;
  LRet: Pointer;
  LOptions: TTcpServerOptions;
begin
  LHandler := TWakeupPollDrivenHandler.Create;
  LHandlerRef := LHandler;
  Check(LHandlerRef <> nil, 'wakeup epoll handler keepalive installed');
  LOptions := TTcpServerOptions.Default;
  LOptions.Backend := TCP_SERVER_BACKEND_EPOLL;
  LServer := NewTcpServer(LOptions);
  New(LCtx);
  LCtx^.Server := LServer;
  LCtx^.Handler := LHandler;
  LCtx^.Addr := '127.0.0.1';
  LCtx^.Port := 0;
  platform_thread_create(LHandle, @ServerThreadFunc, LCtx);

  LWait := 0;
  while (not LServer.IsRunning) and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;

  LPort := LServer.LocalAddr.Port;
  Check(LPort > 0, 'wakeup epoll server exposes bound port');

  LClient := TcpConnect('127.0.0.1', LPort);
  try
    LClient.Write(PAnsiChar('x')^, 1);
    LN := LClient.Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
    CheckEqual(SizeUInt(2), LN, 'wakeup epoll response size');
    CheckEqual(Byte(Ord('o')), LBuf[0], 'wakeup epoll first byte');
    CheckEqual(Byte(Ord('k')), LBuf[1], 'wakeup epoll second byte');
  finally
    LClient.Close;
  end;

  LWait := 0;
  while (LHandler.CompletionCount = 0) and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;

  Check(LHandler.ContextFactoryCalled,
    'epoll wakeup path uses context-aware session factory');
  Check(not LHandler.ServeConnCalled,
    'epoll wakeup path bypasses ServeConn');
  CheckEqual(Int64(Ord(TCP_SERVER_HANDOFF_ACCEPTED)),
    Int64(Ord(LHandler.SubmitResult)), 'epoll wakeup handoff accepted');
  CheckEqual(Int64(1), Int64(LHandler.WorkExecuteCount),
    'epoll wakeup work executed once');
  CheckEqual(Int64(1), Int64(LHandler.CompletionCount),
    'epoll wakeup completion executed once');
  Check(LHandler.AdvanceCount > 1,
    'epoll wakeup path re-enters poll-driven session after completion');
  Check(LHandler.ObservedEmptyAdvance,
    'epoll wakeup path re-enters session without socket readiness');
  Check(LHandler.ReactorThreadId <> 0, 'epoll wakeup captured reactor thread');
  Check(LHandler.WorkThreadId <> 0, 'epoll wakeup captured worker thread');
  Check(LHandler.CompletionThreadId <> 0,
    'epoll wakeup captured completion thread');
  Check(LHandler.WorkThreadId <> LHandler.ReactorThreadId,
    'epoll wakeup worker runs off reactor thread');
  CheckEqual(Int64(LHandler.ReactorThreadId), Int64(LHandler.CompletionThreadId),
    'epoll wakeup completion returns to reactor thread');

  LServer.Shutdown;
  platform_thread_join(LHandle, LRet);
end;

procedure TestEpollServerWakesPollDrivenSessionOnDeadline;
var
  LHandler: TDeadlinePollDrivenHandler;
  LHandlerRef: ITcpServerHandler;
  LServer: ITcpServer;
  LCtx: PServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
  LPort: UInt16;
  LClient: ITcpStream;
  LBuf: array[0..7] of Byte;
  LN: SizeUInt;
  LRet: Pointer;
  LOptions: TTcpServerOptions;
begin
  LHandler := TDeadlinePollDrivenHandler.Create;
  LHandlerRef := LHandler;
  Check(LHandlerRef <> nil, 'deadline epoll handler keepalive installed');
  LOptions := TTcpServerOptions.Default;
  LOptions.Backend := TCP_SERVER_BACKEND_EPOLL;
  LServer := NewTcpServer(LOptions);
  New(LCtx);
  LCtx^.Server := LServer;
  LCtx^.Handler := LHandler;
  LCtx^.Addr := '127.0.0.1';
  LCtx^.Port := 0;
  platform_thread_create(LHandle, @ServerThreadFunc, LCtx);

  LWait := 0;
  while (not LServer.IsRunning) and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;

  LPort := LServer.LocalAddr.Port;
  Check(LPort > 0, 'deadline epoll server exposes bound port');

  LClient := TcpConnect('127.0.0.1', LPort);
  try
    LClient.Write(PAnsiChar('d')^, 1);
    LN := LClient.Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
    CheckEqual(SizeUInt(2), LN, 'deadline epoll response size');
    CheckEqual(Byte(Ord('o')), LBuf[0], 'deadline epoll first byte');
    CheckEqual(Byte(Ord('k')), LBuf[1], 'deadline epoll second byte');
  finally
    LClient.Close;
  end;

  LWait := 0;
  while (LHandler.AdvanceCount < 2) and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;

  Check(LHandler.ContextFactoryCalled,
    'epoll deadline path uses context-aware session factory');
  Check(not LHandler.ServeConnCalled,
    'epoll deadline path bypasses ServeConn');
  Check(LHandler.AdvanceCount > 1,
    'epoll deadline path re-enters poll-driven session');
  Check(LHandler.ObservedDeadlineWake,
    'epoll deadline path re-enters session without socket readiness');

  LServer.Shutdown;
  platform_thread_join(LHandle, LRet);
end;
{$ENDIF}

begin
  T := TTestRunner.Create('nextpas.core.net.server');
  T.Run('Default options', @TestDefaultOptions);
  T.Run('Threaded server echo', @TestThreadedServerEcho);
  T.Run('Threaded server shutdown without clients', @TestThreadedServerShutdownWithoutClients);
  T.Run('Threaded server detach keeps connection open', @TestThreadedServerDetachKeepsConnectionOpen);
  T.Run('Threaded server handler exception does not stop accept loop',
    @TestThreadedServerHandlerExceptionDoesNotStopAcceptLoop);
  T.Run('Threaded server shutdown with wildcard listen',
    @TestThreadedServerShutdownWithWildcardListen);
  T.Run('Threaded server shutdown with empty listen addr',
    @TestThreadedServerShutdownWithEmptyListenAddr);
  T.Run('Threaded server prefers session factory when available',
    @TestThreadedServerPrefersSessionFactoryWhenAvailable);
  T.Run('Threaded server prefers context session factory when available',
    @TestThreadedServerPrefersContextSessionFactoryWhenAvailable);
  T.Run('Threaded server accepted handoff completes exactly once',
    @TestThreadedServerAcceptedHandoffCompletesExactlyOnce);
  T.Run('Threaded server failing handoff reports failed outcome',
    @TestThreadedServerFailingHandoffReportsFailedOutcome);
  T.Run('Threaded server rejects handoff after shutdown',
    @TestThreadedServerRejectsHandoffAfterShutdown);
  T.Run('Threaded server poll-driven session falls back to Run',
    @TestThreadedServerPollDrivenSessionFallsBackToRun);
  T.Run('Built-in threaded backend factory exists',
    @TestBuiltInThreadedBackendFactoryExists);
  T.Run('Kqueue backend source contract',
    @TestKqueueBackendSourceContract);
  T.Run('Readiness consumer uses platform poller source contract',
    @TestReadinessConsumerUsesPlatformPollerSourceContract);
  T.Run('Readiness userdata preservation source contract',
    @TestReadinessUserDataPreservationSourceContract);
  T.Run('Readiness empty-interest source contract',
    @TestReadinessEmptyInterestSourceContract);
  T.Run('Readiness wake fallback source contract',
    @TestReadinessWakeFallbackSourceContract);
  T.Run('Readiness poll target lifecycle source contract',
    @TestReadinessPollTargetLifecycleSourceContract);
  T.Run('Custom backend factory overrides selection',
    @TestCustomBackendFactoryOverridesSelection);
  T.Run('Missing backend factory raises not supported',
    @TestMissingBackendFactoryRaisesNotSupported);
  {$IFDEF NEXTPAS_LINUX}
  T.Run('Readiness server wakes poll-driven session after worker completion',
    @TestReadinessServerWakesPollDrivenSessionAfterWorkerCompletion);
  T.Run('Epoll server echo', @TestEpollServerEcho);
  T.Run('Epoll server shutdown without clients',
    @TestEpollServerShutdownWithoutClients);
  T.Run('Epoll server prefers context session factory when available',
    @TestEpollServerPrefersContextSessionFactoryWhenAvailable);
  T.Run('Epoll server uses poll-driven session when available',
    @TestEpollServerUsesPollDrivenSessionWhenAvailable);
  T.Run('Epoll server wakes poll-driven session after worker completion',
    @TestEpollServerWakesPollDrivenSessionAfterWorkerCompletion);
  T.Run('Epoll server wakes poll-driven session on deadline',
    @TestEpollServerWakesPollDrivenSessionOnDeadline);
  {$ENDIF}
  T.Summary;
end.
