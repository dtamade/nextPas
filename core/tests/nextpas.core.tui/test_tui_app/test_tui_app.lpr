program test_tui_app;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils,
  nextpas.core.tui.base,
  nextpas.core.tui.event,
  nextpas.core.tui.buffer,
  nextpas.core.tui.style,
  nextpas.core.tui.app,
  nextpas.core.tui.terminal,
  nextpas.core.tui.task,
  nextpas.core.tui.app.screen,
  nextpas.core.testing;

type
  TSharedStateBox = class
  public
    Value: AnsiString;
    Revision: Integer;
    CommitLog: AnsiString;
    procedure Commit(const AValue: AnsiString);
  end;

  TRecordingScreen = class(TScreen)
  public
    Name: AnsiString;
    RenderCount: Integer;
    EventCount: Integer;
    TaskCompletionCount: Integer;
    LastTaskSlotCount: Integer;
    LastTaskId: TTaskId;
    LastTaskStatus: TTaskStatus;
    TaskCompletionIdLog: AnsiString;
    TaskCompletionStatusLog: AnsiString;
    EnterCount: Integer;
    LeaveCount: Integer;
    LastArea: TRect;
    LastEvent: TEvent;
    RequestQuitOnEvent: Boolean;
    RequestQuitOnTaskCompletion: Boolean;
    RaiseOnEnter: Boolean;
    PushScreenOnTaskCompletion: TScreen;
    FollowUpTasks: TTaskManager;
    FollowUpTaskId: TTaskId;
    FollowUpTaskStatus: TTaskStatus;
    FollowUpCancelledTasks: TTaskManager;
    FollowUpCancelledTaskId: TTaskId;
    FollowUpScheduled: Boolean;
    RenderedSharedStateLog: AnsiString;
    DestroyedCountTarget: PInteger;
    LifecycleLog: PAnsiString;
    destructor Destroy; override;
    procedure Render(const Area: TRect; Buf: TBuffer); override;
    procedure HandleEvent(const Ev: TEvent); override;
    procedure HandleTaskCompletions(const Slots: array of TCompletionSlot;
      SlotCount: Integer); override;
    procedure OnEnter; override;
    procedure OnLeave; override;
  end;

  TFakeApp = class(TApp)
  private
    FEvents: array of TEvent;
    FPollIndex: Integer;
    FFrameBuffer: TBuffer;
    FBeginFrameCount: Integer;
    FEndFrameCount: Integer;
    FLeaveCount: Integer;
  protected
    function DoEnterTui: Boolean; override;
    procedure DoLeaveTui; override;
    function DoPollEvent: TEvent; override;
    function DoBeginFrame: TFrame; override;
    procedure DoEndFrame(const F: TFrame); override;
  public
    constructor Create(const AEvents: array of TEvent); reintroduce;
    destructor Destroy; override;
    property FrameBuffer: TBuffer read FFrameBuffer;
    property PollCount: Integer read FPollIndex;
    property BeginFrameCount: Integer read FBeginFrameCount;
    property EndFrameCount: Integer read FEndFrameCount;
    property LeaveCount: Integer read FLeaveCount;
  end;

  TTaskCallbackHost = class
  public
    Count: Integer;
    LastSlotCount: Integer;
    LastTaskId: TTaskId;
    LastTaskStatus: TTaskStatus;
    TaskCompletionIdLog: AnsiString;
    TaskCompletionStatusLog: AnsiString;
    BatchSizeLog: AnsiString;
    RequestQuitAfterHandling: Boolean;
    RequestQuitOnCount: Integer;
    ReleaseOwnershipAfterHandling: Boolean;
    PushScreenOnTaskCompletion: TScreen;
    FollowUpTasks: TTaskManager;
    FollowUpTaskId: TTaskId;
    FollowUpTaskStatus: TTaskStatus;
    FollowUpCancelledTasks: TTaskManager;
    FollowUpCancelledTaskId: TTaskId;
    SharedState: TSharedStateBox;
    SharedStateValueOnFirstCompletion: AnsiString;
    SharedStateValueOnFollowUpCompletion: AnsiString;
    FollowUpScheduled: Boolean;
    procedure HandleTasks(App: TApp; const Slots: array of TCompletionSlot;
      SlotCount: Integer);
  end;

var
  T: TTestRunner;

procedure SeedPendingCancelledTask(ATasks: TTaskManager; out CancelledTaskId: TTaskId); forward;

procedure TSharedStateBox.Commit(const AValue: AnsiString);
begin
  Value := AValue;
  Inc(Revision);
  if CommitLog <> '' then
    CommitLog := CommitLog + '>';
  CommitLog := CommitLog + AValue;
end;

procedure AppendLifecycle(ALog: PAnsiString; const AEntry: AnsiString);
begin
  if ALog = nil then
    Exit;
  if ALog^ <> '' then
    ALog^ := ALog^ + '>';
  ALog^ := ALog^ + AEntry;
end;

procedure AppendTaskCompletionIds(var ALog: AnsiString;
  const Slots: array of TCompletionSlot; SlotCount: Integer);
var
  LIndex: Integer;
begin
  for LIndex := 0 to SlotCount - 1 do
  begin
    if ALog <> '' then
      ALog := ALog + '>';
    ALog := ALog + IntToStr(Slots[LIndex].Id);
  end;
end;

procedure AppendTaskCompletionStatuses(var ALog: AnsiString;
  const Slots: array of TCompletionSlot; SlotCount: Integer);
var
  LIndex: Integer;
begin
  for LIndex := 0 to SlotCount - 1 do
  begin
    if ALog <> '' then
      ALog := ALog + '>';
    ALog := ALog + IntToStr(Ord(Slots[LIndex].Result.Status));
  end;
end;

procedure AppendLogEntry(var ALog: AnsiString; const AEntry: AnsiString);
begin
  if ALog <> '' then
    ALog := ALog + '>';
  ALog := ALog + AEntry;
end;

destructor TRecordingScreen.Destroy;
begin
  if DestroyedCountTarget <> nil then
    Inc(DestroyedCountTarget^);
  AppendLifecycle(LifecycleLog, Name + '.destroy');
  inherited;
end;

procedure TRecordingScreen.Render(const Area: TRect; Buf: TBuffer);
begin
  Inc(RenderCount);
  LastArea := Area;
  if SharedStateObject <> nil then
    AppendLogEntry(RenderedSharedStateLog,
      TSharedStateBox(SharedStateObject).Value);
  Buf.SetString(0, 0, 'screen', StyleDefault);
end;

procedure TRecordingScreen.HandleEvent(const Ev: TEvent);
begin
  Inc(EventCount);
  LastEvent := Ev;
  if RequestQuitOnEvent then
    Stack.RequestQuit;
end;

procedure TRecordingScreen.HandleTaskCompletions(
  const Slots: array of TCompletionSlot; SlotCount: Integer);
var
  LRes: TTaskResult;
begin
  Inc(TaskCompletionCount);
  LastTaskSlotCount := SlotCount;
  AppendTaskCompletionIds(TaskCompletionIdLog, Slots, SlotCount);
  AppendTaskCompletionStatuses(TaskCompletionStatusLog, Slots, SlotCount);
  if SlotCount > 0 then
  begin
    LastTaskId := Slots[0].Id;
    LastTaskStatus := Slots[0].Result.Status;
  end;
  if (not FollowUpScheduled) and (PushScreenOnTaskCompletion <> nil) then
  begin
    FollowUpScheduled := True;
    Stack.Push(PushScreenOnTaskCompletion);
    if FollowUpTasks <> nil then
    begin
      LRes.Data := nil;
      LRes.DataSize := 0;
      LRes.Error := '';
      LRes.Status := FollowUpTaskStatus;
      FollowUpTasks.OnThreadComplete(FollowUpTaskId, LRes);
    end;
    if FollowUpCancelledTasks <> nil then
      SeedPendingCancelledTask(FollowUpCancelledTasks, FollowUpCancelledTaskId);
  end;
  if RequestQuitOnTaskCompletion then
    Stack.RequestQuit;
end;

procedure TRecordingScreen.OnEnter;
begin
  Inc(EnterCount);
  AppendLifecycle(LifecycleLog, Name + '.enter');
  if RaiseOnEnter then
    raise Exception.Create(String(Name) + ' enter failed');
end;

procedure TRecordingScreen.OnLeave;
begin
  Inc(LeaveCount);
  AppendLifecycle(LifecycleLog, Name + '.leave');
end;

procedure TTaskCallbackHost.HandleTasks(App: TApp;
  const Slots: array of TCompletionSlot; SlotCount: Integer);
var
  LRes: TTaskResult;
  LCommitValue: AnsiString;
begin
  Inc(Count);
  LastSlotCount := SlotCount;
  if BatchSizeLog <> '' then
    BatchSizeLog := BatchSizeLog + '>';
  BatchSizeLog := BatchSizeLog + IntToStr(SlotCount);
  AppendTaskCompletionIds(TaskCompletionIdLog, Slots, SlotCount);
  AppendTaskCompletionStatuses(TaskCompletionStatusLog, Slots, SlotCount);
  if SlotCount > 0 then
  begin
    LastTaskId := Slots[0].Id;
    LastTaskStatus := Slots[0].Result.Status;
  end;
  if SharedState <> nil then
  begin
    if Count = 1 then
      LCommitValue := SharedStateValueOnFirstCompletion
    else
      LCommitValue := SharedStateValueOnFollowUpCompletion;
    if LCommitValue <> '' then
      SharedState.Commit(LCommitValue);
  end;
  if (not FollowUpScheduled) and (PushScreenOnTaskCompletion <> nil) then
  begin
    FollowUpScheduled := True;
    App.Screens.Push(PushScreenOnTaskCompletion);
    if FollowUpTasks <> nil then
    begin
      LRes.Data := nil;
      LRes.DataSize := 0;
      LRes.Error := '';
      LRes.Status := FollowUpTaskStatus;
      FollowUpTasks.OnThreadComplete(FollowUpTaskId, LRes);
    end;
    if FollowUpCancelledTasks <> nil then
      SeedPendingCancelledTask(FollowUpCancelledTasks, FollowUpCancelledTaskId);
  end;
  if ReleaseOwnershipAfterHandling then
    App.OnTaskCompletionCb := nil;
  if RequestQuitAfterHandling or
     ((RequestQuitOnCount > 0) and (Count >= RequestQuitOnCount)) then
    App.Quit;
end;

constructor TFakeApp.Create(const AEvents: array of TEvent);
var
  LIndex: Integer;
begin
  inherited Create;
  SetLength(FEvents, Length(AEvents));
  for LIndex := 0 to High(AEvents) do
    FEvents[LIndex] := AEvents[LIndex];
  FPollIndex := 0;
  FFrameBuffer := TBuffer.CreateEmpty(TRect.Make(0, 0, 12, 3));
end;

destructor TFakeApp.Destroy;
begin
  FFrameBuffer.Free;
  inherited;
end;

function TFakeApp.DoEnterTui: Boolean;
begin
  Result := True;
end;

procedure TFakeApp.DoLeaveTui;
begin
  Inc(FLeaveCount);
end;

function TFakeApp.DoPollEvent: TEvent;
begin
  if FPollIndex < Length(FEvents) then
  begin
    Result := FEvents[FPollIndex];
    Inc(FPollIndex);
    Exit;
  end;

  Inc(FPollIndex);
  Result := KeyCharEvent(Ord('q'), [kmCtrl]);
end;

function TFakeApp.DoBeginFrame: TFrame;
begin
  Inc(FBeginFrameCount);
  FFrameBuffer.Reset;
  Result.Buffer := FFrameBuffer;
  Result.Overlay := nil;
  Result.Area := FFrameBuffer.Area;
  Result.HasCursor := False;
  Result.CursorPos := PositionMake(0, 0);
  Result.FrameId := Cardinal(FBeginFrameCount);
end;

procedure TFakeApp.DoEndFrame(const F: TFrame);
begin
  Inc(FEndFrameCount);
end;

procedure EnqueueCompletion(ATasks: TTaskManager; AId: TTaskId;
  AStatus: TTaskStatus; const AError: ShortString = '');
var
  LRes: TTaskResult;
begin
  LRes.Data := nil;
  LRes.DataSize := 0;
  LRes.Error := AError;
  LRes.Status := AStatus;
  ATasks.OnThreadComplete(AId, LRes);
end;

function WaitUntilCancelledTask(const Ctx: TTaskContext): TTaskResult;
begin
  Result.Data := nil;
  Result.DataSize := 0;
  Result.Error := '';
  while not IsCancelled(Ctx) do
    Sleep(1);
  Result.Status := tsCompleted;
end;

procedure SeedPendingCancelledTask(ATasks: TTaskManager; out CancelledTaskId: TTaskId);
var
  LIndex: Integer;
  LSpec: TTaskSpec;
begin
  LSpec := MakeSpec(@WaitUntilCancelledTask, nil, 0, 'wait-until-cancelled');
  for LIndex := 1 to MAX_CONCURRENT_TASKS do
    ATasks.Spawn(LSpec);
  CancelledTaskId := ATasks.Spawn(LSpec);
  ATasks.Cancel(CancelledTaskId);
end;

procedure TestAppRendersTopScreenByDefault;
var
  LApp: TFakeApp;
  LScreen: TRecordingScreen;
  LLines: TBufferLines;
begin
  LApp := TFakeApp.Create([
    KeyCharEvent(Ord('q'), [kmCtrl])
  ]);
  try
    LScreen := TRecordingScreen.Create;
    LApp.Screens.Push(LScreen);

    LApp.Run;

    CheckEqual(Int64(1), Int64(LScreen.EnterCount), 'screen entered once');
    CheckEqual(Int64(1), Int64(LScreen.RenderCount), 'default app render uses top screen');
    Check(RectEquals(LScreen.LastArea, LApp.FrameBuffer.Area), 'screen rendered with frame area');
    CheckEqual(Int64(1), Int64(LApp.BeginFrameCount), 'one frame rendered');
    CheckEqual(Int64(1), Int64(LApp.EndFrameCount), 'one frame ended');

    LLines := LApp.FrameBuffer.AsLines;
    CheckEqual('screen', Copy(LLines[0], 1, 6), 'screen wrote into frame buffer');
  finally
    LApp.Free;
  end;
end;

procedure TestAppRoutesEventsToTopScreenByDefault;
var
  LApp: TFakeApp;
  LScreen: TRecordingScreen;
begin
  LApp := TFakeApp.Create([
    KeyCodeEvent(kcTab, []),
    KeyCharEvent(Ord('q'), [kmCtrl])
  ]);
  try
    LScreen := TRecordingScreen.Create;
    LApp.Screens.Push(LScreen);

    LApp.Run;

    CheckEqual(Int64(1), Int64(LScreen.EventCount), 'default app event path uses top screen');
    Check(LScreen.LastEvent.Kind = evKey, 'screen received key event');
    Check(LScreen.LastEvent.Key.Code = kcTab, 'screen received original event');
  finally
    LApp.Free;
  end;
end;

procedure TestAppStopsWhenScreenRequestsQuit;
var
  LApp: TFakeApp;
  LScreen: TRecordingScreen;
begin
  LApp := TFakeApp.Create([
    KeyCodeEvent(kcEnter, []),
    NoneEvent,
    KeyCharEvent(Ord('q'), [kmCtrl])
  ]);
  try
    LScreen := TRecordingScreen.Create;
    LScreen.RequestQuitOnEvent := True;
    LApp.Screens.Push(LScreen);

    LApp.Run;

    CheckEqual(Int64(1), Int64(LScreen.EventCount), 'screen handled one event before quitting');
    CheckEqual(Int64(1), Int64(LApp.PollCount), 'screen quit request stops app immediately');
    CheckEqual(Int64(1), Int64(LApp.BeginFrameCount), 'screen quit request avoids extra frames');
  finally
    LApp.Free;
  end;
end;

procedure TestScreenStackPushLeavesOldTopAndEntersNewTop;
var
  LStack: TScreenStack;
  LFirst: TRecordingScreen;
  LSecond: TRecordingScreen;
  LLog: AnsiString;
begin
  LStack := TScreenStack.Create;
  try
    LLog := '';
    LFirst := TRecordingScreen.Create;
    LFirst.Name := 'first';
    LFirst.LifecycleLog := @LLog;
    LStack.Push(LFirst);

    LSecond := TRecordingScreen.Create;
    LSecond.Name := 'second';
    LSecond.LifecycleLog := @LLog;
    LStack.Push(LSecond);

    CheckEqual(Int64(2), Int64(LStack.Count), 'push keeps both screens on stack');
    Check(LStack.Top = LSecond, 'second screen becomes top after push');
    Check(LFirst.Stack = LStack, 'first screen stays owned by stack');
    Check(LSecond.Stack = LStack, 'second screen is owned by stack');
    CheckEqual(Int64(1), Int64(LFirst.EnterCount), 'first screen entered once');
    CheckEqual(Int64(1), Int64(LFirst.LeaveCount), 'first screen leaves when second is pushed');
    CheckEqual(Int64(1), Int64(LSecond.EnterCount), 'second screen entered once');
    CheckEqual('first.enter>first.leave>second.enter', String(LLog), 'push order is stable');
  finally
    LStack.Free;
  end;
end;

procedure TestScreenStackPopResumesPreviousTop;
var
  LStack: TScreenStack;
  LFirst: TRecordingScreen;
  LSecond: TRecordingScreen;
  LPopped: TScreen;
  LLog: AnsiString;
begin
  LStack := TScreenStack.Create;
  try
    LLog := '';
    LFirst := TRecordingScreen.Create;
    LFirst.Name := 'first';
    LFirst.LifecycleLog := @LLog;
    LStack.Push(LFirst);

    LSecond := TRecordingScreen.Create;
    LSecond.Name := 'second';
    LSecond.LifecycleLog := @LLog;
    LStack.Push(LSecond);

    LPopped := LStack.Pop;
    Check(LPopped = LSecond, 'pop returns previous top screen');
    Check(LStack.Top = LFirst, 'pop resumes previous screen');
    CheckEqual(Int64(1), Int64(LStack.Count), 'pop reduces stack count');
    Check(LSecond.Stack = nil, 'popped screen is detached from stack');
    CheckEqual(Int64(2), Int64(LFirst.EnterCount), 'previous screen re-enters after pop');
    CheckEqual(Int64(1), Int64(LSecond.LeaveCount), 'popped top leaves once');
    CheckEqual('first.enter>first.leave>second.enter>second.leave>first.enter',
      String(LLog), 'pop resume order is stable');
    LPopped.Free;
  finally
    LStack.Free;
  end;
end;

procedure TestScreenStackOwnsScreenStackReference;
var
  LStack: TScreenStack;
  LScreen: TRecordingScreen;
  LPopped: TScreen;
begin
  LStack := TScreenStack.Create;
  try
    LScreen := TRecordingScreen.Create;
    Check(LScreen.Stack = nil, 'new screen starts without stack owner');

    LStack.Push(LScreen);
    Check(LScreen.Stack = LStack, 'push assigns stack owner');

    LPopped := LStack.Pop;
    Check(LPopped = LScreen, 'pop returns pushed screen');
    Check(LScreen.Stack = nil, 'pop clears stack owner');
    LPopped.Free;
  finally
    LStack.Free;
  end;
end;

procedure TestScreenStackReplaceFreesOldTop;
var
  LStack: TScreenStack;
  LOldScreen: TRecordingScreen;
  LNewScreen: TRecordingScreen;
  LDestroyedCount: Integer;
  LLog: AnsiString;
begin
  LStack := TScreenStack.Create;
  try
    LDestroyedCount := 0;
    LLog := '';
    LOldScreen := TRecordingScreen.Create;
    LOldScreen.Name := 'old';
    LOldScreen.LifecycleLog := @LLog;
    LOldScreen.DestroyedCountTarget := @LDestroyedCount;
    LStack.Push(LOldScreen);

    LNewScreen := TRecordingScreen.Create;
    LNewScreen.Name := 'new';
    LNewScreen.LifecycleLog := @LLog;
    LStack.Replace(LNewScreen);

    CheckEqual(Int64(1), Int64(LStack.Count), 'replace keeps stack size stable');
    Check(LStack.Top = LNewScreen, 'replace swaps top screen');
    CheckEqual(Int64(1), Int64(LDestroyedCount), 'replace frees old top after new enters');
    CheckEqual(Int64(1), Int64(LNewScreen.EnterCount), 'new screen enters once');
    CheckEqual('old.enter>old.leave>new.enter>old.destroy', String(LLog),
      'replace order is stable');
  finally
    LStack.Free;
  end;
end;

procedure TestScreenStackPushRollbackRestoresPreviousTop;
var
  LStack: TScreenStack;
  LFirst: TRecordingScreen;
  LFailing: TRecordingScreen;
  LLog: AnsiString;
begin
  LStack := TScreenStack.Create;
  try
    LLog := '';
    LFirst := TRecordingScreen.Create;
    LFirst.Name := 'first';
    LFirst.LifecycleLog := @LLog;
    LStack.Push(LFirst);

    LFailing := TRecordingScreen.Create;
    LFailing.Name := 'failing';
    LFailing.LifecycleLog := @LLog;
    LFailing.RaiseOnEnter := True;

    try
      LStack.Push(LFailing);
      Fail('push should propagate enter failure');
    except
      on E: Exception do
        Check(Pos('enter failed', E.Message) > 0, 'push surfaces enter failure');
    end;

    CheckEqual(Int64(1), Int64(LStack.Count), 'failed push keeps original stack size');
    Check(LStack.Top = LFirst, 'failed push restores previous top');
    Check(LFailing.Stack = nil, 'failed push detaches incoming screen');
    CheckEqual(Int64(2), Int64(LFirst.EnterCount), 'previous screen re-enters after rollback');
    CheckEqual(Int64(1), Int64(LFirst.LeaveCount), 'previous screen leaves once during failed push');
    CheckEqual('first.enter>first.leave>failing.enter>first.enter', String(LLog),
      'failed push rollback order is stable');
    LFailing.Free;
  finally
    LStack.Free;
  end;
end;

procedure TestScreenStackRejectsNilAndOwnedScreens;
var
  LOwnedStack: TScreenStack;
  LOtherStack: TScreenStack;
  LScreen: TRecordingScreen;
begin
  LOwnedStack := TScreenStack.Create;
  LOtherStack := TScreenStack.Create;
  try
    try
      LOwnedStack.Push(nil);
      Fail('push nil should fail');
    except
      on E: EFtuiScreenError do
        Check(Pos('requires a screen', E.Message) > 0, 'push nil reports screen requirement');
    end;

    LScreen := TRecordingScreen.Create;
    LOwnedStack.Push(LScreen);

    try
      LOtherStack.Push(LScreen);
      Fail('push owned screen should fail');
    except
      on E: EFtuiScreenError do
        Check(Pos('already owned by a stack', E.Message) > 0, 'owned screen is rejected');
    end;
  finally
    LOtherStack.Free;
    LOwnedStack.Free;
  end;
end;

procedure TestAppRoutesTaskCompletionsToTopScreenByDefault;
var
  LApp: TFakeApp;
  LScreen: TRecordingScreen;
begin
  LApp := TFakeApp.Create([]);
  try
    LScreen := TRecordingScreen.Create;
    LScreen.RequestQuitOnTaskCompletion := True;
    LApp.Screens.Push(LScreen);
    EnqueueCompletion(LApp.Tasks, 77, tsCompleted);

    LApp.Run;

    CheckEqual(Int64(1), Int64(LScreen.TaskCompletionCount),
      'default app task path uses top screen');
    CheckEqual(Int64(1), Int64(LScreen.LastTaskSlotCount),
      'screen receives one completion slot');
    CheckEqual(Int64(77), Int64(LScreen.LastTaskId),
      'screen receives original completion id');
    CheckEqual(Int64(Ord(tsCompleted)), Int64(Ord(LScreen.LastTaskStatus)),
      'screen receives completion status');
    CheckEqual(Int64(0), Int64(LApp.BeginFrameCount),
      'task completion quit stops app before rendering');
    CheckEqual(Int64(0), Int64(LApp.PollCount),
      'task completion can stop app before polling');
  finally
    LApp.Free;
  end;
end;

procedure TestAppRoutesTaskCompletionsToCallbackPath;
var
  LApp: TFakeApp;
  LScreen: TRecordingScreen;
  LHost: TTaskCallbackHost;
begin
  LApp := TFakeApp.Create([]);
  LHost := TTaskCallbackHost.Create;
  try
    LScreen := TRecordingScreen.Create;
    LApp.Screens.Push(LScreen);
    LHost.RequestQuitAfterHandling := True;
    LApp.OnTaskCompletionCb := @LHost.HandleTasks;
    EnqueueCompletion(LApp.Tasks, 88, tsFailed, 'boom');

    LApp.Run;

    CheckEqual(Int64(1), Int64(LHost.Count),
      'callback app task path handles completions');
    CheckEqual(Int64(1), Int64(LHost.LastSlotCount),
      'callback receives one completion slot');
    CheckEqual(Int64(88), Int64(LHost.LastTaskId),
      'callback receives completion id');
    CheckEqual(Int64(Ord(tsFailed)), Int64(Ord(LHost.LastTaskStatus)),
      'callback receives completion status');
    CheckEqual(Int64(0), Int64(LScreen.TaskCompletionCount),
      'callback path takes precedence over screen task path');
    CheckEqual(Int64(0), Int64(LApp.BeginFrameCount),
      'callback quit stops app before rendering');
    CheckEqual(Int64(0), Int64(LApp.PollCount),
      'callback quit stops app before polling');
  finally
    LHost.Free;
    LApp.Free;
  end;
end;

procedure TestAppRoutesCancelledTaskCompletionToTopScreenByDefault;
var
  LApp: TFakeApp;
  LScreen: TRecordingScreen;
  LCancelledTaskId: TTaskId;
begin
  LApp := TFakeApp.Create([]);
  try
    LScreen := TRecordingScreen.Create;
    LScreen.RequestQuitOnTaskCompletion := True;
    LApp.Screens.Push(LScreen);
    SeedPendingCancelledTask(LApp.Tasks, LCancelledTaskId);

    LApp.Run;

    CheckEqual(Int64(1), Int64(LScreen.TaskCompletionCount),
      'default app task path handles cancelled task completions');
    CheckEqual(Int64(1), Int64(LScreen.LastTaskSlotCount),
      'screen receives one cancelled completion slot');
    CheckEqual(Int64(LCancelledTaskId), Int64(LScreen.LastTaskId),
      'screen receives cancelled task id');
    CheckEqual(Int64(Ord(tsCancelled)), Int64(Ord(LScreen.LastTaskStatus)),
      'screen receives cancelled task status from real Cancel path');
    CheckEqual(Int64(0), Int64(LApp.BeginFrameCount),
      'cancelled completion quit still stops app before rendering');
    CheckEqual(Int64(0), Int64(LApp.PollCount),
      'cancelled completion quit still stops app before polling');
  finally
    LApp.Free;
  end;
end;

procedure TestAppRoutesCancelledTaskCompletionToCallbackPath;
var
  LApp: TFakeApp;
  LScreen: TRecordingScreen;
  LHost: TTaskCallbackHost;
  LCancelledTaskId: TTaskId;
begin
  LApp := TFakeApp.Create([]);
  LHost := TTaskCallbackHost.Create;
  try
    LScreen := TRecordingScreen.Create;
    LApp.Screens.Push(LScreen);
    LHost.RequestQuitAfterHandling := True;
    LApp.OnTaskCompletionCb := @LHost.HandleTasks;
    SeedPendingCancelledTask(LApp.Tasks, LCancelledTaskId);

    LApp.Run;

    CheckEqual(Int64(1), Int64(LHost.Count),
      'callback app task path handles cancelled task completions');
    CheckEqual(Int64(1), Int64(LHost.LastSlotCount),
      'callback receives one cancelled completion slot');
    CheckEqual(Int64(LCancelledTaskId), Int64(LHost.LastTaskId),
      'callback receives cancelled task id');
    CheckEqual(Int64(Ord(tsCancelled)), Int64(Ord(LHost.LastTaskStatus)),
      'callback receives cancelled task status from real Cancel path');
    CheckEqual(Int64(0), Int64(LScreen.TaskCompletionCount),
      'callback path still takes precedence over screen for cancelled completions');
    CheckEqual(Int64(0), Int64(LApp.BeginFrameCount),
      'cancelled callback quit still stops app before rendering');
    CheckEqual(Int64(0), Int64(LApp.PollCount),
      'cancelled callback quit still stops app before polling');
  finally
    LHost.Free;
    LApp.Free;
  end;
end;

procedure TestAppRoutesMultipleTaskCompletionsToTopScreenInOrder;
var
  LApp: TFakeApp;
  LScreen: TRecordingScreen;
begin
  LApp := TFakeApp.Create([]);
  try
    LScreen := TRecordingScreen.Create;
    LScreen.RequestQuitOnTaskCompletion := True;
    LApp.Screens.Push(LScreen);
    EnqueueCompletion(LApp.Tasks, 10, tsCompleted);
    EnqueueCompletion(LApp.Tasks, 20, tsFailed, 'boom');

    LApp.Run;

    CheckEqual(Int64(1), Int64(LScreen.TaskCompletionCount),
      'top screen receives one drained completion batch');
    CheckEqual(Int64(2), Int64(LScreen.LastTaskSlotCount),
      'top screen receives both completion slots');
    CheckEqual('10>20', String(LScreen.TaskCompletionIdLog),
      'top screen sees completion ids in drain order');
    CheckEqual(Int64(0), Int64(LApp.PollCount),
      'screen batch quit still stops app before polling');
  finally
    LApp.Free;
  end;
end;

procedure TestAppPreservesMixedTaskCompletionStatusesOnTopScreen;
var
  LApp: TFakeApp;
  LScreen: TRecordingScreen;
begin
  LApp := TFakeApp.Create([]);
  try
    LScreen := TRecordingScreen.Create;
    LScreen.RequestQuitOnTaskCompletion := True;
    LApp.Screens.Push(LScreen);
    EnqueueCompletion(LApp.Tasks, 81, tsCompleted);
    EnqueueCompletion(LApp.Tasks, 82, tsFailed, 'boom');
    EnqueueCompletion(LApp.Tasks, 83, tsCancelled);

    LApp.Run;

    CheckEqual(Int64(1), Int64(LScreen.TaskCompletionCount),
      'top screen receives one mixed-status completion batch');
    CheckEqual(Int64(3), Int64(LScreen.LastTaskSlotCount),
      'top screen receives all mixed-status completion slots');
    CheckEqual('81>82>83', String(LScreen.TaskCompletionIdLog),
      'top screen preserves mixed-status completion ordering');
    CheckEqual(IntToStr(Ord(tsCompleted)) + '>' + IntToStr(Ord(tsFailed)) + '>' +
      IntToStr(Ord(tsCancelled)), String(LScreen.TaskCompletionStatusLog),
      'top screen preserves per-slot mixed completion statuses');
  finally
    LApp.Free;
  end;
end;

procedure TestAppRoutesTaskCompletionsToCallbackWithoutTopScreen;
var
  LApp: TFakeApp;
  LHost: TTaskCallbackHost;
begin
  LApp := TFakeApp.Create([]);
  LHost := TTaskCallbackHost.Create;
  try
    LHost.RequestQuitAfterHandling := True;
    LApp.OnTaskCompletionCb := @LHost.HandleTasks;
    EnqueueCompletion(LApp.Tasks, 30, tsCompleted);
    EnqueueCompletion(LApp.Tasks, 40, tsCancelled);

    LApp.Run;

    CheckEqual(Int64(1), Int64(LHost.Count),
      'callback receives completion batch without top screen');
    CheckEqual(Int64(2), Int64(LHost.LastSlotCount),
      'callback receives both slots without top screen');
    CheckEqual('30>40', String(LHost.TaskCompletionIdLog),
      'callback sees completion ids in drain order');
    CheckEqual(Int64(0), Int64(LApp.BeginFrameCount),
      'callback quit still stops render without top screen');
    CheckEqual(Int64(0), Int64(LApp.PollCount),
      'callback quit still stops poll without top screen');
  finally
    LHost.Free;
    LApp.Free;
  end;
end;

procedure TestAppPreservesMixedTaskCompletionStatusesOnCallbackPath;
var
  LApp: TFakeApp;
  LScreen: TRecordingScreen;
  LHost: TTaskCallbackHost;
begin
  LApp := TFakeApp.Create([]);
  LHost := TTaskCallbackHost.Create;
  try
    LScreen := TRecordingScreen.Create;
    LApp.Screens.Push(LScreen);
    LHost.RequestQuitAfterHandling := True;
    LApp.OnTaskCompletionCb := @LHost.HandleTasks;
    EnqueueCompletion(LApp.Tasks, 91, tsCompleted);
    EnqueueCompletion(LApp.Tasks, 92, tsFailed, 'boom');
    EnqueueCompletion(LApp.Tasks, 93, tsCancelled);

    LApp.Run;

    CheckEqual(Int64(1), Int64(LHost.Count),
      'callback receives one mixed-status completion batch');
    CheckEqual(Int64(3), Int64(LHost.LastSlotCount),
      'callback receives all mixed-status completion slots');
    CheckEqual('91>92>93', String(LHost.TaskCompletionIdLog),
      'callback preserves mixed-status completion ordering');
    CheckEqual(IntToStr(Ord(tsCompleted)) + '>' + IntToStr(Ord(tsFailed)) + '>' +
      IntToStr(Ord(tsCancelled)), String(LHost.TaskCompletionStatusLog),
      'callback preserves per-slot mixed completion statuses');
    CheckEqual(Int64(0), Int64(LScreen.TaskCompletionCount),
      'screen still does not receive callback-owned mixed-status completion batch');
  finally
    LHost.Free;
    LApp.Free;
  end;
end;

procedure TestAppRoutesCallbackCompletionOverflowAcrossLoopIterations;
var
  LApp: TFakeApp;
  LHost: TTaskCallbackHost;
  LId: Integer;
  LExpectedLog: AnsiString;
begin
  LApp := TFakeApp.Create([NoneEvent]);
  LHost := TTaskCallbackHost.Create;
  try
    LHost.RequestQuitOnCount := 2;
    LApp.OnTaskCompletionCb := @LHost.HandleTasks;
    LExpectedLog := '';
    for LId := 1 to TASK_QUEUE_CAPACITY + 3 do
    begin
      EnqueueCompletion(LApp.Tasks, LId, tsCompleted);
      if LExpectedLog <> '' then
        LExpectedLog := LExpectedLog + '>';
      LExpectedLog := LExpectedLog + IntToStr(LId);
    end;

    LApp.Run;

    CheckEqual(Int64(2), Int64(LHost.Count),
      'callback drains overflowed completion queue across two loop iterations');
    CheckEqual('32>3', String(LHost.BatchSizeLog),
      'callback sees TASK_QUEUE_CAPACITY-sized batch followed by overflow remainder');
    CheckEqual(LExpectedLog, String(LHost.TaskCompletionIdLog),
      'callback preserves completion ordering across overflow batches');
    CheckEqual(Int64(TASK_QUEUE_CAPACITY + 1), Int64(LHost.LastTaskId),
      'callback second batch starts at the first overflow completion id');
    CheckEqual(Int64(Ord(tsCompleted)), Int64(Ord(LHost.LastTaskStatus)),
      'callback receives the final overflow completion status');
    CheckEqual(Int64(1), Int64(LApp.BeginFrameCount),
      'overflow remainder quit still avoids a second render');
    CheckEqual(Int64(1), Int64(LApp.PollCount),
      'overflow remainder is dispatched on the next loop before a second poll');
  finally
    LHost.Free;
    LApp.Free;
  end;
end;

procedure TestAppBootstrapsFirstScreenFromCallbackWithoutTopScreen;
var
  LApp: TFakeApp;
  LScreen: TRecordingScreen;
  LHost: TTaskCallbackHost;
begin
  LApp := TFakeApp.Create([
    KeyCodeEvent(kcTab, [])
  ]);
  LHost := TTaskCallbackHost.Create;
  try
    LScreen := TRecordingScreen.Create;
    LScreen.Name := 'bootstrap';
    LScreen.RequestQuitOnEvent := True;

    LHost.PushScreenOnTaskCompletion := LScreen;
    LApp.OnTaskCompletionCb := @LHost.HandleTasks;
    EnqueueCompletion(LApp.Tasks, 350, tsCompleted);

    LApp.Run;

    CheckEqual(Int64(1), Int64(LHost.Count),
      'callback receives bootstrap completion without top screen');
    CheckEqual(Int64(1), Int64(LHost.LastSlotCount),
      'callback receives one bootstrap completion slot');
    CheckEqual(Int64(350), Int64(LHost.LastTaskId),
      'callback receives bootstrap completion id');
    CheckEqual(Int64(Ord(tsCompleted)), Int64(Ord(LHost.LastTaskStatus)),
      'callback receives bootstrap completion status');
    CheckEqual(Int64(1), Int64(LScreen.EnterCount),
      'callback can bootstrap the first screen from an empty app');
    CheckEqual(Int64(1), Int64(LScreen.RenderCount),
      'bootstrapped screen renders in the same loop iteration');
    CheckEqual(Int64(1), Int64(LScreen.EventCount),
      'bootstrapped screen receives the first polled event');
    Check(LScreen.LastEvent.Kind = evKey,
      'bootstrapped screen receives key event after callback bootstrap');
    Check(LScreen.LastEvent.Key.Code = kcTab,
      'bootstrapped screen receives original post-bootstrap event');
    CheckEqual(Int64(0), Int64(LScreen.TaskCompletionCount),
      'bootstrapped screen does not receive callback-owned completion batch');
    CheckEqual(Int64(1), Int64(LApp.BeginFrameCount),
      'callback bootstrap renders exactly one frame before event quit');
    CheckEqual(Int64(1), Int64(LApp.PollCount),
      'callback bootstrap reaches the first poll on the same loop iteration');
  finally
    LHost.Free;
    LApp.Free;
  end;
end;

procedure TestAppDrainsTaskCompletionsWithoutHandler;
var
  LApp: TFakeApp;
begin
  LApp := TFakeApp.Create([]);
  try
    EnqueueCompletion(LApp.Tasks, 50, tsCompleted);
    EnqueueCompletion(LApp.Tasks, 60, tsFailed, 'ignored');

    LApp.Run;

    CheckEqual(Int64(0), Int64(LApp.Tasks.CompletionCount),
      'completion queue is drained even without screen or callback');
    CheckEqual(Int64(1), Int64(LApp.BeginFrameCount),
      'app continues into render when completion batch is ignored');
    CheckEqual(Int64(1), Int64(LApp.PollCount),
      'app continues into poll when completion batch is ignored');
  finally
    LApp.Free;
  end;
end;

procedure TestAppRoutesFollowUpCompletionToNewTopScreen;
var
  LApp: TFakeApp;
  LFirst: TRecordingScreen;
  LSecond: TRecordingScreen;
begin
  LApp := TFakeApp.Create([NoneEvent]);
  try
    LFirst := TRecordingScreen.Create;
    LFirst.Name := 'first';
    LSecond := TRecordingScreen.Create;
    LSecond.Name := 'second';
    LSecond.RequestQuitOnTaskCompletion := True;

    LFirst.PushScreenOnTaskCompletion := LSecond;
    LFirst.FollowUpTasks := LApp.Tasks;
    LFirst.FollowUpTaskId := 200;
    LFirst.FollowUpTaskStatus := tsCompleted;

    LApp.Screens.Push(LFirst);
    EnqueueCompletion(LApp.Tasks, 100, tsCompleted);

    LApp.Run;

    CheckEqual(Int64(1), Int64(LFirst.TaskCompletionCount),
      'first screen handles initial completion batch');
    CheckEqual('100', String(LFirst.TaskCompletionIdLog),
      'first screen receives only the initial completion id');
    CheckEqual(Int64(1), Int64(LFirst.LeaveCount),
      'first screen leaves when it pushes a new top screen');
    CheckEqual(Int64(1), Int64(LSecond.TaskCompletionCount),
      'new top screen handles follow-up completion batch');
    CheckEqual('200', String(LSecond.TaskCompletionIdLog),
      'new top screen receives only the follow-up completion id');
    CheckEqual(Int64(1), Int64(LSecond.EnterCount),
      'new top screen enters once during completion transition');
    CheckEqual(Int64(1), Int64(LApp.BeginFrameCount),
      'follow-up completion quit avoids a second render');
    CheckEqual(Int64(1), Int64(LApp.PollCount),
      'follow-up completion ownership migrates on the next loop iteration');
  finally
    LApp.Free;
  end;
end;

procedure TestAppRendersAndPollsNewTopScreenAfterCompletionTransition;
var
  LApp: TFakeApp;
  LFirst: TRecordingScreen;
  LSecond: TRecordingScreen;
begin
  LApp := TFakeApp.Create([
    KeyCodeEvent(kcTab, [])
  ]);
  try
    LFirst := TRecordingScreen.Create;
    LFirst.Name := 'first';
    LSecond := TRecordingScreen.Create;
    LSecond.Name := 'second';
    LSecond.RequestQuitOnEvent := True;

    LFirst.PushScreenOnTaskCompletion := LSecond;

    LApp.Screens.Push(LFirst);
    EnqueueCompletion(LApp.Tasks, 300, tsCompleted);

    LApp.Run;

    CheckEqual(Int64(1), Int64(LFirst.TaskCompletionCount),
      'first screen handles the completion batch that triggers the transition');
    CheckEqual(Int64(0), Int64(LFirst.RenderCount),
      'old top screen does not render after completion-driven transition');
    CheckEqual(Int64(0), Int64(LFirst.EventCount),
      'old top screen does not receive post-transition event ownership');
    CheckEqual(Int64(1), Int64(LSecond.EnterCount),
      'new top screen enters during completion transition');
    CheckEqual(Int64(1), Int64(LSecond.RenderCount),
      'new top screen renders in the same loop iteration after transition');
    CheckEqual(Int64(1), Int64(LSecond.EventCount),
      'new top screen receives the first polled event after transition');
    Check(LSecond.LastEvent.Kind = evKey, 'new top screen receives key event after transition');
    Check(LSecond.LastEvent.Key.Code = kcTab,
      'new top screen receives the original post-transition event');
    CheckEqual(Int64(1), Int64(LApp.BeginFrameCount),
      'transition renders exactly one frame before event-driven quit');
    CheckEqual(Int64(1), Int64(LApp.PollCount),
      'transition reaches the first poll on the same loop iteration');
  finally
    LApp.Free;
  end;
end;

procedure TestAppRendersAndPollsNewTopScreenAfterCallbackTransition;
var
  LApp: TFakeApp;
  LFirst: TRecordingScreen;
  LSecond: TRecordingScreen;
  LHost: TTaskCallbackHost;
begin
  LApp := TFakeApp.Create([
    KeyCodeEvent(kcTab, [])
  ]);
  LHost := TTaskCallbackHost.Create;
  try
    LFirst := TRecordingScreen.Create;
    LFirst.Name := 'first';
    LSecond := TRecordingScreen.Create;
    LSecond.Name := 'second';
    LSecond.RequestQuitOnEvent := True;

    LHost.PushScreenOnTaskCompletion := LSecond;
    LApp.Screens.Push(LFirst);
    LApp.OnTaskCompletionCb := @LHost.HandleTasks;
    EnqueueCompletion(LApp.Tasks, 400, tsCompleted);

    LApp.Run;

    CheckEqual(Int64(1), Int64(LHost.Count),
      'callback handles the completion batch that triggers the transition');
    CheckEqual(Int64(1), Int64(LHost.LastSlotCount),
      'callback receives the single completion slot');
    CheckEqual(Int64(400), Int64(LHost.LastTaskId),
      'callback receives the original completion id');
    CheckEqual(Int64(Ord(tsCompleted)), Int64(Ord(LHost.LastTaskStatus)),
      'callback receives completion status before transition');
    CheckEqual(Int64(0), Int64(LFirst.TaskCompletionCount),
      'old top screen still does not receive callback-owned completion batch');
    CheckEqual(Int64(0), Int64(LFirst.RenderCount),
      'old top screen does not render after callback-driven transition');
    CheckEqual(Int64(0), Int64(LFirst.EventCount),
      'old top screen does not receive post-transition event ownership');
    CheckEqual(Int64(1), Int64(LFirst.LeaveCount),
      'old top screen leaves when callback pushes a new top screen');
    CheckEqual(Int64(1), Int64(LSecond.EnterCount),
      'new top screen enters during callback-driven transition');
    CheckEqual(Int64(1), Int64(LSecond.RenderCount),
      'new top screen renders in the same loop iteration after callback transition');
    CheckEqual(Int64(1), Int64(LSecond.EventCount),
      'new top screen receives the first polled event after callback transition');
    Check(LSecond.LastEvent.Kind = evKey,
      'new top screen receives a key event after callback transition');
    Check(LSecond.LastEvent.Key.Code = kcTab,
      'new top screen receives the original post-transition event');
    CheckEqual(Int64(1), Int64(LApp.BeginFrameCount),
      'callback-driven transition renders exactly one frame before event quit');
    CheckEqual(Int64(1), Int64(LApp.PollCount),
      'callback-driven transition reaches the first poll on the same loop iteration');
  finally
    LHost.Free;
    LApp.Free;
  end;
end;

procedure TestAppRoutesFollowUpCompletionToCallbackAfterCallbackTransition;
var
  LApp: TFakeApp;
  LFirst: TRecordingScreen;
  LSecond: TRecordingScreen;
  LHost: TTaskCallbackHost;
begin
  LApp := TFakeApp.Create([NoneEvent]);
  LHost := TTaskCallbackHost.Create;
  try
    LFirst := TRecordingScreen.Create;
    LFirst.Name := 'first';
    LSecond := TRecordingScreen.Create;
    LSecond.Name := 'second';

    LHost.PushScreenOnTaskCompletion := LSecond;
    LHost.FollowUpTasks := LApp.Tasks;
    LHost.FollowUpTaskId := 500;
    LHost.FollowUpTaskStatus := tsCancelled;
    LHost.RequestQuitOnCount := 2;

    LApp.Screens.Push(LFirst);
    LApp.OnTaskCompletionCb := @LHost.HandleTasks;
    EnqueueCompletion(LApp.Tasks, 400, tsCompleted);

    LApp.Run;

    CheckEqual(Int64(2), Int64(LHost.Count),
      'callback handles both the initial and follow-up completion batches');
    CheckEqual('400>500', String(LHost.TaskCompletionIdLog),
      'callback retains ownership of follow-up completion across the screen transition');
    CheckEqual(Int64(500), Int64(LHost.LastTaskId),
      'callback receives the follow-up completion id after transition');
    CheckEqual(Int64(Ord(tsCancelled)), Int64(Ord(LHost.LastTaskStatus)),
      'callback receives the follow-up completion status after transition');
    CheckEqual(Int64(0), Int64(LFirst.TaskCompletionCount),
      'old top screen never receives callback-owned completion batches');
    CheckEqual(Int64(0), Int64(LSecond.TaskCompletionCount),
      'new top screen does not steal follow-up completion ownership from callback');
    CheckEqual(Int64(1), Int64(LSecond.EnterCount),
      'new top screen still enters during callback-driven transition');
    CheckEqual(Int64(1), Int64(LSecond.RenderCount),
      'new top screen still renders once before follow-up callback quit');
    CheckEqual(Int64(1), Int64(LApp.BeginFrameCount),
      'follow-up callback quit still avoids a second render');
    CheckEqual(Int64(1), Int64(LApp.PollCount),
      'follow-up callback ownership is resolved on the next loop before a second poll');
  finally
    LHost.Free;
    LApp.Free;
  end;
end;

procedure TestAppRoutesCancelledFollowUpCompletionToNewTopScreen;
var
  LApp: TFakeApp;
  LFirst: TRecordingScreen;
  LSecond: TRecordingScreen;
begin
  LApp := TFakeApp.Create([NoneEvent]);
  try
    LFirst := TRecordingScreen.Create;
    LFirst.Name := 'first';
    LSecond := TRecordingScreen.Create;
    LSecond.Name := 'second';
    LSecond.RequestQuitOnTaskCompletion := True;

    LFirst.PushScreenOnTaskCompletion := LSecond;
    LFirst.FollowUpCancelledTasks := LApp.Tasks;

    LApp.Screens.Push(LFirst);
    EnqueueCompletion(LApp.Tasks, 650, tsCompleted);

    LApp.Run;

    CheckEqual(Int64(1), Int64(LFirst.TaskCompletionCount),
      'first screen handles the transition-triggering completion before cancelled follow-up');
    CheckEqual(Int64(1), Int64(LSecond.TaskCompletionCount),
      'new top screen handles the cancelled follow-up completion after transition');
    CheckEqual(Int64(LFirst.FollowUpCancelledTaskId), Int64(LSecond.LastTaskId),
      'new top screen receives the real cancelled follow-up task id');
    CheckEqual(Int64(Ord(tsCancelled)), Int64(Ord(LSecond.LastTaskStatus)),
      'new top screen receives cancelled follow-up status after transition');
    CheckEqual(Int64(1), Int64(LApp.BeginFrameCount),
      'cancelled follow-up quit still avoids a second render after transition');
    CheckEqual(Int64(1), Int64(LApp.PollCount),
      'cancelled follow-up is resolved on the next loop before a second poll');
  finally
    LApp.Free;
  end;
end;

procedure TestAppRoutesCancelledFollowUpCompletionToCallbackAfterTransition;
var
  LApp: TFakeApp;
  LFirst: TRecordingScreen;
  LSecond: TRecordingScreen;
  LHost: TTaskCallbackHost;
begin
  LApp := TFakeApp.Create([NoneEvent]);
  LHost := TTaskCallbackHost.Create;
  try
    LFirst := TRecordingScreen.Create;
    LFirst.Name := 'first';
    LSecond := TRecordingScreen.Create;
    LSecond.Name := 'second';

    LHost.PushScreenOnTaskCompletion := LSecond;
    LHost.FollowUpCancelledTasks := LApp.Tasks;
    LHost.RequestQuitOnCount := 2;

    LApp.Screens.Push(LFirst);
    LApp.OnTaskCompletionCb := @LHost.HandleTasks;
    EnqueueCompletion(LApp.Tasks, 700, tsCompleted);

    LApp.Run;

    CheckEqual(Int64(2), Int64(LHost.Count),
      'callback handles both the transition-triggering completion and cancelled follow-up');
    CheckEqual('700>' + IntToStr(LHost.FollowUpCancelledTaskId),
      String(LHost.TaskCompletionIdLog),
      'callback receives the real cancelled follow-up task id after transition');
    CheckEqual(Int64(Ord(tsCancelled)), Int64(Ord(LHost.LastTaskStatus)),
      'callback receives cancelled follow-up status after transition');
    CheckEqual(Int64(0), Int64(LSecond.TaskCompletionCount),
      'new top screen still does not steal callback-owned cancelled follow-up');
    CheckEqual(Int64(1), Int64(LApp.BeginFrameCount),
      'cancelled callback follow-up quit still avoids a second render after transition');
    CheckEqual(Int64(1), Int64(LApp.PollCount),
      'cancelled callback follow-up is resolved on the next loop before a second poll');
  finally
    LHost.Free;
    LApp.Free;
  end;
end;

procedure TestAppFallsBackToScreenAfterCallbackBootstrapReleasesOwnership;
var
  LApp: TFakeApp;
  LScreen: TRecordingScreen;
  LHost: TTaskCallbackHost;
begin
  LApp := TFakeApp.Create([NoneEvent]);
  LHost := TTaskCallbackHost.Create;
  try
    LScreen := TRecordingScreen.Create;
    LScreen.Name := 'bootstrap';
    LScreen.RequestQuitOnTaskCompletion := True;

    LHost.PushScreenOnTaskCompletion := LScreen;
    LHost.FollowUpTasks := LApp.Tasks;
    LHost.FollowUpTaskId := 600;
    LHost.FollowUpTaskStatus := tsFailed;
    LHost.ReleaseOwnershipAfterHandling := True;

    LApp.OnTaskCompletionCb := @LHost.HandleTasks;
    EnqueueCompletion(LApp.Tasks, 550, tsCompleted);

    LApp.Run;

    CheckEqual(Int64(1), Int64(LHost.Count),
      'callback handles only the bootstrap completion batch');
    CheckEqual('550', String(LHost.TaskCompletionIdLog),
      'callback only records the bootstrap completion id');
    CheckEqual(Int64(1), Int64(LScreen.EnterCount),
      'callback bootstrap still creates the first screen');
    CheckEqual(Int64(1), Int64(LScreen.RenderCount),
      'bootstrapped screen still renders before follow-up fallback');
    CheckEqual(Int64(1), Int64(LScreen.TaskCompletionCount),
      'follow-up completion falls back to the new top screen after callback release');
    CheckEqual('600', String(LScreen.TaskCompletionIdLog),
      'new top screen receives only the follow-up completion id');
    CheckEqual(Int64(Ord(tsFailed)), Int64(Ord(LScreen.LastTaskStatus)),
      'new top screen receives the follow-up completion status after callback release');
    CheckEqual(Int64(1), Int64(LApp.BeginFrameCount),
      'screen-owned follow-up quit avoids a second render');
    CheckEqual(Int64(1), Int64(LApp.PollCount),
      'screen-owned follow-up is resolved on the next loop before a second poll');
  finally
    LHost.Free;
    LApp.Free;
  end;
end;

procedure TestAppCallbackCommitsSharedStateBeforeFirstRender;
var
  LApp: TFakeApp;
  LScreen: TRecordingScreen;
  LHost: TTaskCallbackHost;
  LSharedState: TSharedStateBox;
begin
  LApp := TFakeApp.Create([KeyCharEvent(Ord('x'), [])]);
  LHost := TTaskCallbackHost.Create;
  LSharedState := TSharedStateBox.Create;
  try
    LScreen := TRecordingScreen.Create;
    LScreen.Name := 'shared';
    LScreen.RequestQuitOnEvent := True;

    LHost.SharedState := LSharedState;
    LHost.SharedStateValueOnFirstCompletion := 'loaded';

    LApp.SharedStateObject := LSharedState;
    LApp.Screens.Push(LScreen);
    LApp.OnTaskCompletionCb := @LHost.HandleTasks;
    EnqueueCompletion(LApp.Tasks, 800, tsCompleted);

    LApp.Run;

    CheckEqual(Int64(1), Int64(LHost.Count),
      'app callback handles the completion batch that commits shared state');
    CheckEqual(Int64(0), Int64(LScreen.TaskCompletionCount),
      'screen does not receive the same completion batch when app callback owns shared state');
    CheckEqual('loaded', String(LSharedState.CommitLog),
      'app callback commits shared state from completion handling');
    CheckEqual('loaded', String(LScreen.RenderedSharedStateLog),
      'screen render sees shared state already committed before first render');
    CheckEqual(Int64(1), Int64(LSharedState.Revision),
      'shared state is committed exactly once before first render');
    CheckEqual(Int64(1), Int64(LApp.BeginFrameCount),
      'shared-state commit path still renders exactly one frame');
    CheckEqual(Int64(1), Int64(LApp.PollCount),
      'shared-state commit path still reaches one poll before screen quit');
  finally
    LSharedState.Free;
    LHost.Free;
    LApp.Free;
  end;
end;

procedure TestAppCallbackRetainsSharedStateOwnershipAcrossScreenTransition;
var
  LApp: TFakeApp;
  LFirst: TRecordingScreen;
  LSecond: TRecordingScreen;
  LHost: TTaskCallbackHost;
  LSharedState: TSharedStateBox;
begin
  LApp := TFakeApp.Create([NoneEvent, KeyCharEvent(Ord('x'), [])]);
  LHost := TTaskCallbackHost.Create;
  LSharedState := TSharedStateBox.Create;
  try
    LFirst := TRecordingScreen.Create;
    LFirst.Name := 'first';
    LSecond := TRecordingScreen.Create;
    LSecond.Name := 'second';
    LSecond.RequestQuitOnEvent := True;

    LHost.SharedState := LSharedState;
    LHost.SharedStateValueOnFirstCompletion := 'bootstrap';
    LHost.SharedStateValueOnFollowUpCompletion := 'refreshed';
    LHost.PushScreenOnTaskCompletion := LSecond;
    LHost.FollowUpTasks := LApp.Tasks;
    LHost.FollowUpTaskId := 850;
    LHost.FollowUpTaskStatus := tsCompleted;

    LApp.SharedStateObject := LSharedState;
    LApp.Screens.Push(LFirst);
    LApp.OnTaskCompletionCb := @LHost.HandleTasks;
    EnqueueCompletion(LApp.Tasks, 840, tsCompleted);

    LApp.Run;

    CheckEqual(Int64(2), Int64(LHost.Count),
      'app callback keeps ownership of both transition completion and follow-up shared-state update');
    CheckEqual(Int64(0), Int64(LSecond.TaskCompletionCount),
      'new top screen never steals callback-owned shared-state completions');
    CheckEqual('bootstrap>refreshed', String(LSharedState.CommitLog),
      'same shared-state object is committed twice by app callback across transition');
    CheckEqual('bootstrap>refreshed', String(LSecond.RenderedSharedStateLog),
      'new top screen renders the same app-owned shared state before and after follow-up');
    CheckEqual(Int64(2), Int64(LSecond.RenderCount),
      'new top screen renders once per shared-state revision');
    CheckEqual(Int64(2), Int64(LApp.BeginFrameCount),
      'shared-state transition path renders two frames');
    CheckEqual(Int64(2), Int64(LApp.PollCount),
      'shared-state transition path reaches two polls before screen quit');
  finally
    LSharedState.Free;
    LHost.Free;
    LApp.Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.tui.app');
  T.Run('app renders top screen by default', @TestAppRendersTopScreenByDefault);
  T.Run('app routes events to top screen by default', @TestAppRoutesEventsToTopScreenByDefault);
  T.Run('app stops when screen requests quit', @TestAppStopsWhenScreenRequestsQuit);
  T.Run('screen stack push leaves old top and enters new top', @TestScreenStackPushLeavesOldTopAndEntersNewTop);
  T.Run('screen stack pop resumes previous top', @TestScreenStackPopResumesPreviousTop);
  T.Run('screen stack owns screen stack reference', @TestScreenStackOwnsScreenStackReference);
  T.Run('screen stack replace frees old top', @TestScreenStackReplaceFreesOldTop);
  T.Run('screen stack push rollback restores previous top', @TestScreenStackPushRollbackRestoresPreviousTop);
  T.Run('screen stack rejects nil and owned screens', @TestScreenStackRejectsNilAndOwnedScreens);
  T.Run('app routes task completions to top screen by default', @TestAppRoutesTaskCompletionsToTopScreenByDefault);
  T.Run('app routes task completions to callback path', @TestAppRoutesTaskCompletionsToCallbackPath);
  T.Run('app routes cancelled task completion to top screen by default', @TestAppRoutesCancelledTaskCompletionToTopScreenByDefault);
  T.Run('app routes cancelled task completion to callback path', @TestAppRoutesCancelledTaskCompletionToCallbackPath);
  T.Run('app routes multiple task completions to top screen in order', @TestAppRoutesMultipleTaskCompletionsToTopScreenInOrder);
  T.Run('app preserves mixed task completion statuses on top screen', @TestAppPreservesMixedTaskCompletionStatusesOnTopScreen);
  T.Run('app routes task completions to callback without top screen', @TestAppRoutesTaskCompletionsToCallbackWithoutTopScreen);
  T.Run('app preserves mixed task completion statuses on callback path', @TestAppPreservesMixedTaskCompletionStatusesOnCallbackPath);
  T.Run('app routes callback completion overflow across loop iterations', @TestAppRoutesCallbackCompletionOverflowAcrossLoopIterations);
  T.Run('app bootstraps first screen from callback without top screen', @TestAppBootstrapsFirstScreenFromCallbackWithoutTopScreen);
  T.Run('app drains task completions without handler', @TestAppDrainsTaskCompletionsWithoutHandler);
  T.Run('app routes follow-up completion to new top screen', @TestAppRoutesFollowUpCompletionToNewTopScreen);
  T.Run('app renders and polls new top screen after completion transition', @TestAppRendersAndPollsNewTopScreenAfterCompletionTransition);
  T.Run('app renders and polls new top screen after callback transition', @TestAppRendersAndPollsNewTopScreenAfterCallbackTransition);
  T.Run('app routes follow-up completion to callback after callback transition', @TestAppRoutesFollowUpCompletionToCallbackAfterCallbackTransition);
  T.Run('app routes cancelled follow-up completion to new top screen', @TestAppRoutesCancelledFollowUpCompletionToNewTopScreen);
  T.Run('app routes cancelled follow-up completion to callback after transition', @TestAppRoutesCancelledFollowUpCompletionToCallbackAfterTransition);
  T.Run('app falls back to screen after callback bootstrap releases ownership', @TestAppFallsBackToScreenAfterCallbackBootstrapReleasesOwnership);
  T.Run('app callback commits shared state before first render', @TestAppCallbackCommitsSharedStateBeforeFirstRender);
  T.Run('app callback retains shared-state ownership across screen transition', @TestAppCallbackRetainsSharedStateOwnershipAcrossScreenTransition);
  T.Summary;
  if not T.AllPassed then
    Halt(1);
end.
