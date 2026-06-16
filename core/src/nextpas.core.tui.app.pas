unit nextpas.core.tui.app;

{$I nextpas.core.settings.inc}

interface

uses nextpas.core.tui.base, nextpas.core.tui.event, nextpas.core.tui.terminal, nextpas.core.tui.app.screen, nextpas.core.tui.focus, nextpas.core.tui.frame_budget, nextpas.core.tui.task;

type
  TApp = class;

  TAppRenderProc = procedure(App: TApp; var Frame: TFrame) of object;
  TAppEventProc  = procedure(App: TApp; const Ev: TEvent) of object;
  TAppTickProc   = procedure(App: TApp; TickCount: Integer) of object;
  TAppTaskCompletionProc = procedure(App: TApp;
    const Slots: array of TCompletionSlot; SlotCount: Integer) of object;

  TApp = class
  private
    FTerminal: TTerminal;
    FScreens: TScreenStack;
    FSharedStateObject: TObject;
    FFocus: TFocusManager;
    FBudget: TFrameBudget;
    FUseFocus: Boolean;
    FUseBudget: Boolean;
    FTickInterval: Integer;
    FTickCount: Integer;
    FShouldQuit: Boolean;
    FOnRender: TAppRenderProc;
    FOnEvent: TAppEventProc;
    FOnTick: TAppTickProc;
    FOnTaskCompletion: TAppTaskCompletionProc;
    FAnimTickInterval: Integer;
    FIdleTickInterval: Integer;
    FAnimationRequested: Boolean;
    FStartTime: QWord;
    FTasks: TTaskManager;
    function GetTerminalOptions: TTerminalOptions;
    function GetSharedStateObject: TObject;
    procedure SetTerminalOptions(const AOptions: TTerminalOptions);
    procedure SetSharedStateObject(AValue: TObject);
    procedure CleanupAfterRun(SuppressErrors: Boolean);
    procedure DispatchTick;
    procedure ConsumeScreenQuitRequest;
  protected
    procedure Render(var Frame: TFrame); virtual;
    procedure HandleEvent(const Ev: TEvent); virtual;
    procedure HandleTaskCompletions(const Slots: array of TCompletionSlot;
      SlotCount: Integer); virtual;
    procedure OnTick; virtual;
    procedure OnInit; virtual;
    procedure OnDestroy; virtual;
    function IsQuitEvent(const Ev: TEvent): Boolean; virtual;
    function DoEnterTui: Boolean; virtual;
    procedure DoLeaveTui; virtual;
    function NextPollTimeout: Integer;
    function DoPollEvent: TEvent; virtual;
    function DoBeginFrame: TFrame; virtual;
    procedure DoEndFrame(const F: TFrame); virtual;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Run;
    procedure Quit;
    procedure EnableFocus;
    procedure EnableBudget(BudgetMs: Double);
    procedure RequestAnimationFrame;
    function ElapsedMs: QWord;
    property Terminal: TTerminal read FTerminal;
    property Screens: TScreenStack read FScreens;
    property Focus: TFocusManager read FFocus;
    property Budget: TFrameBudget read FBudget;
    property TickInterval: Integer read FTickInterval write FTickInterval;
    property TickCount: Integer read FTickCount;
    property AnimTickInterval: Integer read FAnimTickInterval write FAnimTickInterval;
    property IdleTickInterval: Integer read FIdleTickInterval write FIdleTickInterval;
    property Tasks: TTaskManager read FTasks;
    property SharedStateObject: TObject read GetSharedStateObject write SetSharedStateObject;
    property TerminalOptions: TTerminalOptions read GetTerminalOptions write SetTerminalOptions;
    property OnRenderCb: TAppRenderProc read FOnRender write FOnRender;
    property OnEventCb: TAppEventProc read FOnEvent write FOnEvent;
    property OnTickCb: TAppTickProc read FOnTick write FOnTick;
    property OnTaskCompletionCb: TAppTaskCompletionProc
      read FOnTaskCompletion write FOnTaskCompletion;
  end;

implementation

uses nextpas.core.platform.console, nextpas.core.platform.signal, nextpas.core.platform.time, nextpas.core.tui.error;

constructor TApp.Create;
begin
  inherited Create;
  FTerminal := TTerminal.Create;
  FScreens := TScreenStack.Create;
  FSharedStateObject := nil;
  FTasks := TTaskManager.Create;
  FFocus := nil;
  FUseFocus := False;
  FUseBudget := False;
  FTickInterval := -1;
  FTickCount := 0;
  FShouldQuit := False;
  FOnRender := nil;
  FOnEvent := nil;
  FOnTick := nil;
  FOnTaskCompletion := nil;
  FAnimTickInterval := 33;
  FIdleTickInterval := 200;
  FAnimationRequested := False;
  FStartTime := 0;
end;

destructor TApp.Destroy;
begin
  FScreens.Free;
  FTasks.Free;
  FFocus.Free;
  FTerminal.Free;
  inherited;
end;

procedure TApp.EnableFocus;
begin
  if FFocus = nil then
    FFocus := TFocusManager.Create;
  FUseFocus := True;
end;

function TApp.GetTerminalOptions: TTerminalOptions;
begin
  Result := FTerminal.Options;
end;

function TApp.GetSharedStateObject: TObject;
begin
  Result := FSharedStateObject;
end;

procedure TApp.SetTerminalOptions(const AOptions: TTerminalOptions);
begin
  FTerminal.Options := AOptions;
end;

procedure TApp.SetSharedStateObject(AValue: TObject);
begin
  FSharedStateObject := AValue;
  if FScreens <> nil then
    FScreens.SharedStateObject := AValue;
end;

procedure TApp.EnableBudget(BudgetMs: Double);
begin
  FBudget := TFrameBudget.Create(BudgetMs);
  FUseBudget := True;
end;

procedure TApp.Quit;
begin
  FShouldQuit := True;
  FTerminal.RequestQuit;
end;

procedure TApp.RequestAnimationFrame;
begin
  FAnimationRequested := True;
end;

procedure TApp.DispatchTick;
begin
  Inc(FTickCount);
  if Assigned(FOnTick) then
    FOnTick(Self, FTickCount)
  else
    OnTick;
end;

procedure TApp.ConsumeScreenQuitRequest;
begin
  if (FScreens <> nil) and FScreens.ConsumeQuitRequested then
    Quit;
end;

function TApp.ElapsedMs: QWord;
begin
  Result := (platform_monotonic_ns div 1000000) - FStartTime;
end;

function TApp.DoEnterTui: Boolean;
begin
  Result := FTerminal.EnterTui;
end;

procedure TApp.DoLeaveTui;
begin
  FTerminal.LeaveTui;
end;

function TApp.DoPollEvent: TEvent;
begin
  Result := FTerminal.PollEvent(NextPollTimeout);
end;

function TApp.NextPollTimeout: Integer;
begin
  if FTickInterval >= 0 then
    Result := FTickInterval
  else if FAnimationRequested or (FTasks.ActiveCount > 0) or
          (FTasks.CompletionCount > 0) then
    Result := FAnimTickInterval
  else
    Result := FIdleTickInterval;
  FAnimationRequested := False;
end;

function TApp.DoBeginFrame: TFrame;
begin
  Result := FTerminal.BeginFrame;
end;

procedure TApp.DoEndFrame(const F: TFrame);
begin
  FTerminal.EndFrame(F);
end;

procedure TApp.CleanupAfterRun(SuppressErrors: Boolean);
begin
  try
    OnDestroy;
  except
    if not SuppressErrors then
    begin
      try
        DoLeaveTui;
      except
      end;
      raise;
    end;
  end;

  try
    DoLeaveTui;
  except
    if not SuppressErrors then
      raise;
  end;
end;

procedure TApp.Run;
var
  Frame: TFrame;
  Ev: TEvent;
  LCompletionCount: Integer;
  LCompletions: array[0..TASK_QUEUE_CAPACITY - 1] of TCompletionSlot;
begin
  if not DoEnterTui then
    raise ETuiBackend.Create('TApp.Run: failed to enter TUI terminal mode');
  try
    FShouldQuit := False;
    FTickCount := 0;
    FAnimationRequested := False;
    if FUseFocus and Assigned(FFocus) then
      FFocus.ResetSession;
    if FUseBudget then
      FBudget.Reset;
    FStartTime := (platform_monotonic_ns div 1000000);
    OnInit;
    ConsumeScreenQuitRequest;
    while not FShouldQuit do
    begin
      if FTasks.CompletionCount > 0 then
      begin
        LCompletionCount := FTasks.DrainCompleted(LCompletions,
          Length(LCompletions));
        HandleTaskCompletions(LCompletions, LCompletionCount);
        ConsumeScreenQuitRequest;
        if FTerminal.ShouldQuit then
          FShouldQuit := True;
        if FShouldQuit then
          Continue;
      end;
      if FUseBudget then FBudget.BeginFrame;
      if FUseFocus then FFocus.BeginFrame;
      Frame := DoBeginFrame;
      try
        if Assigned(FOnRender) then
          FOnRender(Self, Frame)
        else
          Render(Frame);
        ConsumeScreenQuitRequest;
      finally
        DoEndFrame(Frame);
        if FUseBudget then FBudget.EndFrame;
      end;
      if FShouldQuit then
        Continue;
      Ev := DoPollEvent;
      if FTerminal.ShouldQuit then
      begin
        FShouldQuit := True;
        Continue;
      end;
      if Ev.Kind = evNone then
      begin
        DispatchTick;
        ConsumeScreenQuitRequest;
      end
      else
      begin
        if IsQuitEvent(Ev) then
          FShouldQuit := True
        else if Assigned(FOnEvent) then
          FOnEvent(Self, Ev)
        else
          HandleEvent(Ev);
        ConsumeScreenQuitRequest;
      end;
    end;
  except
    CleanupAfterRun(True);
    raise;
  end;
  CleanupAfterRun(False);
end;

function TApp.IsQuitEvent(const Ev: TEvent): Boolean;
begin
  Result := False;
  if Ev.Kind <> evKey then Exit;
  if not (kmCtrl in Ev.Key.Modifiers) then Exit;
  if Ev.Key.Code <> kcChar then Exit;
  Result := (Ev.Key.Ch = Ord('c')) or (Ev.Key.Ch = Ord('C'))
         or (Ev.Key.Ch = Ord('q')) or (Ev.Key.Ch = Ord('Q'));
end;

procedure TApp.Render(var Frame: TFrame);
begin
  if FScreens <> nil then
    FScreens.Render(Frame.Area, Frame.Buffer);
end;

procedure TApp.HandleEvent(const Ev: TEvent);
begin
  if FScreens <> nil then
    FScreens.HandleEvent(Ev);
end;

procedure TApp.HandleTaskCompletions(const Slots: array of TCompletionSlot;
  SlotCount: Integer);
var
  LTop: TScreen;
begin
  if SlotCount <= 0 then
    Exit;

  if Assigned(FOnTaskCompletion) then
  begin
    FOnTaskCompletion(Self, Slots, SlotCount);
    Exit;
  end;

  if FScreens = nil then
    Exit;

  LTop := FScreens.Top;
  if LTop <> nil then
    LTop.HandleTaskCompletions(Slots, SlotCount);
end;

procedure TApp.OnTick; begin end;
procedure TApp.OnInit; begin end;
procedure TApp.OnDestroy; begin end;

end.
