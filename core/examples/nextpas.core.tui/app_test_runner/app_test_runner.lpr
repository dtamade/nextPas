program app_test_runner;

{**
 * @desc nextPas 测试套件 TUI 运行器（dogfood 应用）。
 *
 * 扫描给定根目录（默认 core/tests/nextpas.core.tui）下含 Makefile 的
 * 套件目录，交互式选择并在后台任务线程执行 `make clean test`，
 * 实时显示状态与输出尾部。
 *
 * 键位：↑/↓ 选择  Enter 运行  a 运行全部可见  / 过滤  r 重扫  q 退出
 *
 * 用法：app_test_runner [suites-root]
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,  { 必须第一：TTaskManager 线程依赖 FPC 线程管理器初始化 }
  nextpas.core.mem,
  nextpas.core.text.conv,
  nextpas.core.time,
  nextpas.core.fs,
  nextpas.core.process,
  nextpas.core.tui,
  nextpas.core.tui.event,
  nextpas.core.tui.ext;

const
  MAX_PARALLEL_RUNS = 2;      { 并发 make 上限：编译型套件吃满核，别灌满线程池 }
  LOG_TAIL_BYTES = 16384;
  RUN_TIMEOUT_MINUTES = 15;

type
  TSuiteStatus = (ssIdle, ssQueued, ssRunning, ssPassed, ssFailed);

  TSuiteInfo = record
    Name: AnsiString;
    Dir: AnsiString;
    Status: TSuiteStatus;
    DurationMs: Int64;
    LogTail: AnsiString;
    ErrMsg: AnsiString;
    TaskId: TTaskId;
    StartMs: QWord;
  end;

  TRunParam = record
    Dir: ShortString;
  end;
  PRunParam = ^TRunParam;

{ 任务线程内执行：跑 make 并把输出尾部通过 Result.Data 移交 UI 线程。
  Data 用 nextpas.core.mem GetMem 分配，接收方按 (Data, DataSize) 释放。 }
function RunSuiteTask(const Ctx: TTaskContext): TTaskResult;
var
  LParam: PRunParam;
  LOut: TProcessOutput;
  LText: AnsiString;
  LLen: SizeUInt;
begin
  Result.Data := nil;
  Result.DataSize := 0;
  Result.Error := '';
  Result.Status := tsFailed;
  LParam := PRunParam(Ctx.Param);
  if LParam = nil then
  begin
    Result.Error := 'missing param';
    Exit;
  end;
  if IsCancelled(Ctx) then
  begin
    Result.Status := tsCancelled;
    Exit;
  end;
  try
    LOut := RunInTimeout('make', ['clean', 'test'], AnsiString(LParam^.Dir),
      TDuration.FromMinutes(RUN_TIMEOUT_MINUTES));
    LText := LOut.StdOut;
    if LOut.StdErr <> '' then
      LText := LText + LineEnding + '--- stderr ---' + LineEnding + LOut.StdErr;
    if Length(LText) > LOG_TAIL_BYTES then
      Delete(LText, 1, Length(LText) - LOG_TAIL_BYTES);
    if LOut.TimedOut then
      Result.Error := 'timeout after ' + IntToStr(RUN_TIMEOUT_MINUTES) + 'min'
    else if LOut.ExitCode <> 0 then
      Result.Error := 'exit code ' + IntToStr(LOut.ExitCode);
    if (LOut.ExitCode = 0) and not LOut.TimedOut then
      Result.Status := tsCompleted;
    LLen := SizeUInt(Length(LText));
    if LLen > 0 then
    begin
      Result.Data := GetMem(LLen);
      Move(LText[1], Result.Data^, LLen);
      Result.DataSize := UInt32(LLen);
    end;
  except
    on E: TObject do
    begin
      Result.Status := tsFailed;
      Result.Error := 'spawn failed: ' + ShortString(E.ClassName);
    end;
  end;
end;

type
  TRunnerScreen = class(TScreen)
  private
    FApp: TApp;                      { 构造注入，不拥有 }
    FSuites: array of TSuiteInfo;
    FVisible: array of Integer;
    FList: TListState;
    FFilter: TInputState;
    FFilterActive: Boolean;
    FPending: array of Integer;      { 应用级 FIFO：索引指向 FSuites }
    FPendHead: Integer;
    FPendCount: Integer;
    FSpinner: Integer;
    FRoot: AnsiString;
    procedure Discover;
    procedure ApplyFilter;
    procedure QueueRun(ASuite: Integer);
    procedure QueueAllVisible;
    procedure Pump;
    function SelectedSuite: Integer;
    function StatusGlyph(const S: TSuiteInfo): AnsiString;
    function StatusStyle(AStatus: TSuiteStatus): TStyle;
    function StatusText(const S: TSuiteInfo): AnsiString;
    procedure RenderHeader(const AArea: TRect; ABuffer: TBuffer);
    procedure RenderSuites(const ACell: TRect; ABuffer: TBuffer);
    procedure RenderLog(const ACell: TRect; ABuffer: TBuffer);
    procedure RenderStatusBar(const AArea: TRect; ABuffer: TBuffer);
  public
    constructor Create(AApp: TApp; const ARoot: AnsiString);
    procedure Render(const Area: TRect; Buf: TBuffer); override;
    procedure HandleEvent(const Ev: TEvent); override;
    procedure HandleTaskCompletions(const Slots: array of TCompletionSlot;
      SlotCount: Integer); override;
  end;

function LowerAscii(const S: AnsiString): AnsiString;
var
  I: Integer;
begin
  Result := S;
  for I := 1 to Length(Result) do
    if Result[I] in ['A'..'Z'] then
      Result[I] := Chr(Ord(Result[I]) + 32);
end;

{ 取字符串最后 N 个物理行（按 #10 切），供日志窗格贴底显示 }
function TailLines(const S: AnsiString; AMaxLines: Integer): AnsiString;
var
  I, LCount: Integer;
begin
  Result := S;
  if AMaxLines <= 0 then
  begin
    Result := '';
    Exit;
  end;
  LCount := 0;
  I := Length(S);
  while I > 0 do
  begin
    if S[I] = #10 then
    begin
      Inc(LCount);
      if LCount >= AMaxLines then
      begin
        Delete(Result, 1, I);
        Exit;
      end;
    end;
    Dec(I);
  end;
end;

constructor TRunnerScreen.Create(AApp: TApp; const ARoot: AnsiString);
begin
  inherited Create;
  FApp := AApp;
  FRoot := ARoot;
  FList := TListState.Empty;
  FFilter := TInputState.Empty;
  FFilterActive := False;
  SetLength(FPending, 0);
  FPendHead := 0;
  FPendCount := 0;
  FSpinner := 0;
  Discover;
end;

procedure TRunnerScreen.Discover;
var
  LEntries: TDirEntryArray;
  LDir: AnsiString;
  LTmp: TSuiteInfo;
  I, J: Integer;
begin
  SetLength(FSuites, 0);
  LEntries := ReadDir(FRoot);
  for I := 0 to High(LEntries) do
  begin
    if not LEntries[I].IsDir then Continue;
    LDir := FRoot + '/' + LEntries[I].Name;
    if not FileExists(LDir + '/Makefile') then Continue;
    SetLength(FSuites, Length(FSuites) + 1);
    FSuites[High(FSuites)].Name := LEntries[I].Name;
    FSuites[High(FSuites)].Dir := LDir;
    FSuites[High(FSuites)].Status := ssIdle;
    FSuites[High(FSuites)].DurationMs := 0;
    FSuites[High(FSuites)].LogTail := '';
    FSuites[High(FSuites)].ErrMsg := '';
    FSuites[High(FSuites)].TaskId := 0;
    FSuites[High(FSuites)].StartMs := 0;
  end;
  { ReadDir 顺序不保证；按名字插入排序 }
  for I := 1 to High(FSuites) do
  begin
    LTmp := FSuites[I];
    J := I - 1;
    while (J >= 0) and (FSuites[J].Name > LTmp.Name) do
    begin
      FSuites[J + 1] := FSuites[J];
      Dec(J);
    end;
    FSuites[J + 1] := LTmp;
  end;
  FPendHead := 0;
  FPendCount := 0;
  SetLength(FPending, 0);
  ApplyFilter;
end;

procedure TRunnerScreen.ApplyFilter;
var
  LNeedle: AnsiString;
  I: Integer;
begin
  LNeedle := LowerAscii(FFilter.Text);
  SetLength(FVisible, 0);
  for I := 0 to High(FSuites) do
    if (LNeedle = '') or (Pos(LNeedle, LowerAscii(FSuites[I].Name)) > 0) then
    begin
      SetLength(FVisible, Length(FVisible) + 1);
      FVisible[High(FVisible)] := I;
    end;
  if Length(FVisible) = 0 then
    FList.ClearSelection
  else if (not FList.HasSelection) or (FList.Selected >= Length(FVisible)) then
    FList.Select(0);
end;

function TRunnerScreen.SelectedSuite: Integer;
begin
  Result := -1;
  if FList.HasSelection and (FList.Selected >= 0) and
     (FList.Selected < Length(FVisible)) then
    Result := FVisible[FList.Selected];
end;

procedure TRunnerScreen.QueueRun(ASuite: Integer);
begin
  if (ASuite < 0) or (ASuite > High(FSuites)) then Exit;
  if FSuites[ASuite].Status in [ssQueued, ssRunning] then Exit;
  FSuites[ASuite].Status := ssQueued;
  FSuites[ASuite].ErrMsg := '';
  if FPendHead + FPendCount >= Length(FPending) then
    SetLength(FPending, FPendHead + FPendCount + 8);
  FPending[FPendHead + FPendCount] := ASuite;
  Inc(FPendCount);
  Pump;
end;

procedure TRunnerScreen.QueueAllVisible;
var
  I: Integer;
begin
  for I := 0 to High(FVisible) do
    QueueRun(FVisible[I]);
end;

procedure TRunnerScreen.Pump;
var
  LIdx: Integer;
  LParam: TRunParam;
  LId: TTaskId;
begin
  if (FApp = nil) or (FApp.Tasks = nil) then Exit;
  while (FPendCount > 0) and
        (FApp.Tasks.ActiveCount + FApp.Tasks.PendingCount < MAX_PARALLEL_RUNS) do
  begin
    LIdx := FPending[FPendHead];
    Inc(FPendHead);
    Dec(FPendCount);
    if FPendCount = 0 then
      FPendHead := 0;
    LParam.Dir := ShortString(FSuites[LIdx].Dir);
    LId := FApp.Tasks.Spawn(MakeSpec(@RunSuiteTask, @LParam, SizeOf(LParam),
      ShortString(FSuites[LIdx].Name)));
    if LId = 0 then
    begin
      FSuites[LIdx].Status := ssFailed;
      FSuites[LIdx].ErrMsg := 'task spawn refused';
      Continue;
    end;
    FSuites[LIdx].Status := ssRunning;
    FSuites[LIdx].TaskId := LId;
    FSuites[LIdx].StartMs := FApp.ElapsedMs;
  end;
end;

procedure TRunnerScreen.HandleTaskCompletions(
  const Slots: array of TCompletionSlot; SlotCount: Integer);
var
  I, J: Integer;
begin
  for I := 0 to SlotCount - 1 do
  begin
    for J := 0 to High(FSuites) do
      if (FSuites[J].Status = ssRunning) and (FSuites[J].TaskId = Slots[I].Id) then
      begin
        if Slots[I].Result.Data <> nil then
          SetString(FSuites[J].LogTail, PAnsiChar(Slots[I].Result.Data),
            Slots[I].Result.DataSize)
        else
          FSuites[J].LogTail := '';
        FSuites[J].ErrMsg := AnsiString(Slots[I].Result.Error);
        if Slots[I].Result.Status = tsCompleted then
          FSuites[J].Status := ssPassed
        else
          FSuites[J].Status := ssFailed;
        FSuites[J].DurationMs := Int64(FApp.ElapsedMs - FSuites[J].StartMs);
        FSuites[J].TaskId := 0;
        Break;
      end;
    if Slots[I].Result.Data <> nil then
      FreeMem(Slots[I].Result.Data, Slots[I].Result.DataSize);
  end;
  Pump;
end;

procedure TRunnerScreen.HandleEvent(const Ev: TEvent);
begin
  if FFilterActive then
  begin
    if IsKeyCode(Ev, kcEsc) or IsKeyCode(Ev, kcEnter) then
      FFilterActive := False
    else if Ev.Kind = evKey then
      if FFilter.HandleKey(Ev.Key) then
        ApplyFilter;
    Exit;
  end;
  if IsKeyChar(Ev, Ord('q')) then
    Stack.RequestQuit
  else if IsKeyCode(Ev, kcEsc) then
  begin
    { Esc 只清过滤，不退出——终端 ESC 粘连/误触不应丢掉整个会话 }
    if FFilter.Text <> '' then
    begin
      FFilter := TInputState.Empty;
      ApplyFilter;
    end;
  end
  else if IsKeyCode(Ev, kcUp) then
    FList.Previous
  else if IsKeyCode(Ev, kcDown) then
    FList.Next(Length(FVisible))
  else if IsKeyCode(Ev, kcHome) then
    FList.First
  else if IsKeyCode(Ev, kcEnd) then
    FList.Last(Length(FVisible))
  else if IsKeyCode(Ev, kcEnter) then
    QueueRun(SelectedSuite)
  else if IsKeyChar(Ev, Ord('a')) then
    QueueAllVisible
  else if IsKeyChar(Ev, Ord('/')) then
    FFilterActive := True
  else if IsKeyChar(Ev, Ord('r')) then
    Discover;
end;

function TRunnerScreen.StatusGlyph(const S: TSuiteInfo): AnsiString;
const
  SPIN: array[0..3] of AnsiString = ('|', '/', '-', '\');
begin
  Result := ' ';
  case S.Status of
    ssQueued:  Result := '…';
    ssRunning: Result := SPIN[FSpinner mod 4];
    ssPassed:  Result := '✓';
    ssFailed:  Result := '✗';
  else
  end;
end;

function TRunnerScreen.StatusStyle(AStatus: TSuiteStatus): TStyle;
begin
  case AStatus of
    ssPassed:  Result := StyleFg(TUI_GREEN);
    ssFailed:  Result := StyleFg(TUI_RED);
    ssRunning: Result := StyleFg(TUI_YELLOW);
    ssQueued:  Result := StyleFg(TUI_CYAN);
  else
    Result := StyleDefault;
  end;
end;

function TRunnerScreen.StatusText(const S: TSuiteInfo): AnsiString;
begin
  Result := '';
  case S.Status of
    ssIdle:    Result := 'idle';
    ssQueued:  Result := 'queued';
    ssRunning: Result := 'running ' +
      IntToStr(Int64((FApp.ElapsedMs - S.StartMs) div 1000)) + 's';
    ssPassed:  Result := 'PASS ' + IntToStr(S.DurationMs div 1000) + 's';
    ssFailed:  Result := 'FAIL ' + IntToStr(S.DurationMs div 1000) + 's';
  end;
  if (S.Status = ssFailed) and (S.ErrMsg <> '') then
    Result := Result + ' (' + S.ErrMsg + ')';
end;

procedure TRunnerScreen.RenderHeader(const AArea: TRect; ABuffer: TBuffer);
var
  LInput: IInput;
  LTitle: AnsiString;
begin
  LTitle := ' nextPas suite runner — ' + FRoot + ' ';
  ABuffer.SetString(AArea.X, AArea.Y, LTitle, StyleBold);
  if FFilterActive or (FFilter.Text <> '') then
  begin
    LInput := TInput.New.WithPlaceholder('type to filter…');
    ABuffer.SetString(AArea.X + Integer(AArea.Width) - 30, AArea.Y, '/', StyleFg(TUI_CYAN));
    LInput.RenderInline(ABuffer, AArea.X + Integer(AArea.Width) - 28, AArea.Y, 26, FFilter);
  end;
end;

procedure TRunnerScreen.RenderSuites(const ACell: TRect; ABuffer: TBuffer);
var
  LItems: TListItems;
  I: Integer;
  LSuite: TSuiteInfo;
begin
  SetLength(LItems, Length(FVisible));
  for I := 0 to High(FVisible) do
  begin
    LSuite := FSuites[FVisible[I]];
    LItems[I] := TListItem.FromString(StatusGlyph(LSuite) + ' ' + LSuite.Name)
      .WithStyle(StatusStyle(LSuite.Status));
  end;
  { 标题显示可见/总数（完成统计在状态栏，不重复） }
  TListWidget.New(LItems)
    .WithBlock(TBlock.Rounded(' Suites ' + IntToStr(Length(FVisible)) + '/' +
      IntToStr(Length(FSuites)) + ' '))
    .WithHighlightStyle(StyleFgBg(TUI_BLACK, TUI_CYAN))
    .WithHighlightSymbol('')
    .RenderStateful(ACell, ABuffer, FList);
end;

procedure TRunnerScreen.RenderLog(const ACell: TRect; ABuffer: TBuffer);
var
  LIdx: Integer;
  LTitle, LBody: AnsiString;
  LInnerH: Integer;
begin
  LIdx := SelectedSuite;
  if LIdx < 0 then
  begin
    TParagraph.FromString('没有匹配的套件。按 r 重扫，按 / 修改过滤。')
      .WithBlock(TBlock.Rounded(' log '))
      .Render(ACell, ABuffer);
    Exit;
  end;
  LTitle := ' ' + FSuites[LIdx].Name + ' — ' + StatusText(FSuites[LIdx]) + ' ';
  LInnerH := Integer(ACell.Height) - 2;
  case FSuites[LIdx].Status of
    ssIdle:   LBody := '按 Enter 运行该套件。';
    ssQueued: LBody := '排队等待空闲任务槽…';
    ssRunning: LBody := '执行中：make clean test @ ' + FSuites[LIdx].Dir;
  else
    LBody := TailLines(FSuites[LIdx].LogTail, LInnerH);
    if LBody = '' then
      LBody := '（无输出）';
  end;
  TParagraph.FromString(LBody)
    .WithBlock(TBlock.Rounded(LTitle)
      .WithTitleStyle(StatusStyle(FSuites[LIdx].Status)))
    .Render(ACell, ABuffer);
end;

procedure TRunnerScreen.RenderStatusBar(const AArea: TRect; ABuffer: TBuffer);
var
  LRunning, LQueuedN, LPassed, LFailed, I: Integer;
  LLine: AnsiString;
begin
  LRunning := 0; LQueuedN := 0; LPassed := 0; LFailed := 0;
  for I := 0 to High(FSuites) do
    case FSuites[I].Status of
      ssRunning: Inc(LRunning);
      ssQueued:  Inc(LQueuedN);
      ssPassed:  Inc(LPassed);
      ssFailed:  Inc(LFailed);
    else
    end;
  LLine := ' ✓ ' + IntToStr(LPassed) + '  ✗ ' + IntToStr(LFailed) +
    '  运行 ' + IntToStr(LRunning) + '  队列 ' + IntToStr(LQueuedN) +
    '  │  Enter 运行  a 全部  / 过滤  r 重扫  q 退出';
  ABuffer.SetString(AArea.X, AArea.Y + Integer(AArea.Height) - 1, LLine,
    StyleFg(TUI_CYAN));
end;

procedure TRunnerScreen.Render(const Area: TRect; Buf: TBuffer);
var
  LListW: Integer;
  LBodyH: Integer;
  LRunningAny: Boolean;
  I: Integer;
begin
  LRunningAny := False;
  for I := 0 to High(FSuites) do
    if FSuites[I].Status = ssRunning then
    begin
      LRunningAny := True;
      Break;
    end;
  if LRunningAny then
    FSpinner := (FSpinner + 1) mod 4;

  if (Area.Width < 40) or (Area.Height < 8) then
  begin
    Buf.SetString(Area.X, Area.Y, '终端太小（需要 ≥ 40x8）', StyleDefault);
    Exit;
  end;
  RenderHeader(TRect.Make(Area.X, Area.Y, Area.Width, 1), Buf);
  LListW := Integer(Area.Width) div 3;
  if LListW < 28 then LListW := 28;
  if LListW > 46 then LListW := 46;
  LBodyH := Integer(Area.Height) - 2;
  RenderSuites(TRect.Make(Area.X, Area.Y + 1, Word(LListW), Word(LBodyH)), Buf);
  RenderLog(TRect.Make(Area.X + Word(LListW), Area.Y + 1,
    Area.Width - Word(LListW), Word(LBodyH)), Buf);
  RenderStatusBar(Area, Buf);
end;

var
  App: TApp;
  LRoot: AnsiString;
begin
  LRoot := 'core/tests/nextpas.core.tui';
  if ParamCount >= 1 then
    LRoot := ParamStr(1);
  if not DirectoryExists(LRoot) then
  begin
    Writeln('套件根目录不存在: ', LRoot);
    Writeln('用法: app_test_runner [suites-root]');
    Halt(2);
  end;
  App := TApp.Create;
  try
    try
      App.Screens.Push(TRunnerScreen.Create(App, LRoot));
      App.Run;
    except
      on E: ETuiBackend do
      begin
        Writeln('无法进入 TUI 模式（需要真实终端）: ', E.Message);
        Halt(1);
      end;
    end;
  finally
    App.Free;
  end;
end.
