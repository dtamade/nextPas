{** @desc webview fake 实现拆分：主单元实现体（手写 .inc）。

       治理：原 1583 行单文件超 800 软指引，按 design-conventions
       四件套与 L0-L3 单向依赖拆为 dispatcher/support/store 等子模块；
       本 .inc 承载 TFakeWebview/TFakeCompletion/活窗登记等主体实现，
       复用 L1 bytes.ops VecGrow/Capacity/VecCopy/VecRingCopy 单源 inline
       零拷贝，短临界 <1µs，资源 Finalize 释放不丢。

       性能修复：RecordOutcome 竞争路径 O(n) 持锁搬移消除（同 dispatcher）。
       原二次持锁内再次 VecCopy O(n) 搬移放大尾延迟；现改为乐观重试：
       分配 + VecCopy 仅锁外，二次持锁仅 O(1) 指针检查与写入，stale 重试零 O(n) 持锁。 *}

{ handler 异常 → 协议错误码映射：唯一实现移至 bridge（NormalizeInvokeCode），
  fake 与未来真实后端共用同一映射，避免双处定义漂移。 }
function MapInvokeCode(const ACode: string): string;
begin
  Result := NormalizeInvokeCode(ACode);
end;

{ ---- 回调归一化（method/proc → reference）----
  统一存储范式（design-conventions §8）：内部只存 reference 形态。
  单源：nextpas.core.webview.callbacks inline 薄转发，零拷贝闭包，消除四后端重复。 }

function NotifyMethodToRef(AHandler: TWebviewNotifyMethod): TWebviewNotifyHandler; inline;
begin
  Result := WebviewNotifyMethodToRef(AHandler);
end;

function NotifyProcToRef(AHandler: TWebviewNotifyProc): TWebviewNotifyHandler; inline;
begin
  Result := WebviewNotifyProcToRef(AHandler);
end;

function NavMethodToRef(AHandler: TWebviewNavEventMethod): TWebviewNavEventHandler; inline;
begin
  Result := WebviewNavMethodToRef(AHandler);
end;

function NavProcToRef(AHandler: TWebviewNavEventProc): TWebviewNavEventHandler; inline;
begin
  Result := WebviewNavProcToRef(AHandler);
end;

function NavFailedMethodToRef(AHandler: TWebviewNavFailedMethod): TWebviewNavFailedHandler; inline;
begin
  Result := WebviewNavFailedMethodToRef(AHandler);
end;

function NavFailedProcToRef(AHandler: TWebviewNavFailedProc): TWebviewNavFailedHandler; inline;
begin
  Result := WebviewNavFailedProcToRef(AHandler);
end;

function ScaleMethodToRef(AHandler: TWebviewScaleMethod): TWebviewScaleHandler; inline;
begin
  Result := WebviewScaleMethodToRef(AHandler);
end;

function ScaleProcToRef(AHandler: TWebviewScaleProc): TWebviewScaleHandler; inline;
begin
  Result := WebviewScaleProcToRef(AHandler);
end;

{ ---- invoke 注册表：唯一实现收敛到 bridge（TWebviewInvokeRegistry）----
  fake 仅保留别名；gtk 后端复用同一实现，杜绝双处漂移。 }

type
  TFakeInvokeRegistry = nextpas.core.webview.bridge.TWebviewInvokeRegistry;

{ ---- 资产存储：唯一实现收敛到 bridge（TWebviewAssetsImpl）---- }

type
  TFakeAssets = nextpas.core.webview.bridge.TWebviewAssetsImpl;

{ ---- TFakeCompletion：at-most-once + 主线程 marshal ---- }

type
  TFakeCompletion = class(TInterfacedObject, IWebviewInvokeCompletion)
  private
    FWin: TObject;
    FCmd: string;
    { 来源帧 id；<0 表示 driver 直呼（DeliverInvoke），不产生回执脚本 }
    FFrameId: Int64;
    FDone: Boolean;
    procedure RecordViaDispatcher(AIsError: Boolean;
      const AResultJson, ACode, AMessage: string);
  public
    constructor Create(AWin: TObject; const ACmd: string; AFrameId: Int64);
    procedure Ok(const AResultJson: string);
    procedure Fail(const ACode, AMessage: string);
  end;

constructor TFakeCompletion.Create(AWin: TObject; const ACmd: string;
  AFrameId: Int64);
begin
  inherited Create;
  FWin := AWin;
  FCmd := ACmd;
  FFrameId := AFrameId;
end;

procedure TFakeCompletion.RecordViaDispatcher(AIsError: Boolean;
  const AResultJson, ACode, AMessage: string);
var
  LWin: TFakeWebview;
  LCmd: string;
  LFrameId: Int64;
begin
  LCmd := FCmd;
  LFrameId := FFrameId;
  LWin := FWin as TFakeWebview;
  LWin.GetWindow.Dispatcher.Post(
    procedure
    begin
      LWin.RecordOutcome(LCmd, AIsError, AResultJson, ACode, AMessage);
      if LFrameId >= 0 then
        LWin.EnqueueReceipt(LFrameId, AIsError, AResultJson,
          NormalizeInvokeCode(ACode), AMessage);
    end);
end;

procedure TFakeCompletion.Ok(const AResultJson: string);
begin
  if FDone then
    raise EWebviewInvalidState.Create('invoke completion already settled');
  FDone := True;
  RecordViaDispatcher(False, AResultJson, '', '');
end;

procedure TFakeCompletion.Fail(const ACode, AMessage: string);
begin
  if FDone then
    raise EWebviewInvalidState.Create('invoke completion already settled');
  FDone := True;
  RecordViaDispatcher(True, '',
    ACode, AMessage);
end;

{ 活跃窗口登记（factory RunLoop 的退出事实源）。
  计数口径 = 未 Close 的窗口（持有引用但已 Close 不计入）。 }

var
  GLiveWindows: specialize TWebviewLiveRegistry<TFakeWebview> = nil;
  GLiveCount: Integer = 0;
  GLiveLck: ILock;

{ GLiveWindows 操作单源收敛到 nextpas.core.webview.live TWebviewLiveRegistry 单封装：
  统一消除数组+Count 双变量手写样板，Register/Unregister/Snapshot 薄转发
  bytes.ops Vec 单源 inline 零额外调用，零额外堆分配 }
procedure RegisterLive(AWin: TFakeWebview); inline;
begin
  // perf: single source TWebviewLiveRegistry.Register -> WebviewLiveAdd -> VecGrow inline (0→4→2×) zero extra alloc; cross-thread safety via GLiveLck
  GLiveLck.Acquire;
  try
    GLiveWindows.Register(AWin);
    Inc(GLiveCount);
  finally
    GLiveLck.Release;
  end;
end;

procedure UnregisterLive(AWin: TFakeWebview); inline;
var
  LShouldDec: Boolean;
begin
  // stability: if never Close'd, live count was still 1 — decrement here; already Closed windows decremented at Close time; read FClosed under instance lock, registry under GLiveLck (GLive->FLck order)
  GLiveLck.Acquire;
  try
    AWin.FLck.Acquire;
    try
      LShouldDec := not AWin.FClosed;
    finally
      AWin.FLck.Release;
    end;
    if LShouldDec then
      Dec(GLiveCount);
    // perf: O(1) swap-remove inline via TWebviewLiveRegistry.Unregister single source VecRemoveSwap, nil trailing to release ref
    GLiveWindows.Unregister(AWin);
  finally
    GLiveLck.Release;
  end;
end;

function FakeLiveWindowCount: Integer; inline;
begin
  // perf: O(1) cached count inline, zero scan, close 密集零遍历; Dispatcher cross-thread Post safety via GLiveLck
  GLiveLck.Acquire;
  try
    Result := GLiveCount;
  finally
    GLiveLck.Release;
  end;
end;

procedure FakePumpAll;
var
  I: Integer;
  LSnapshot: array of TFakeWebview;
begin
  // Dispatcher cross-thread Post safety: snapshot under GLiveLck, then pump without holding global lock to avoid dispatch deadlock
  GLiveLck.Acquire;
  try
    GLiveWindows.Snapshot(LSnapshot);
  finally
    GLiveLck.Release;
  end;
  for I := 0 to High(LSnapshot) do
    if not LSnapshot[I].FClosed then
      LSnapshot[I].PumpOnce;
end;

{ ---- TFakeWebview ---- }

class function TFakeWebview.FromWindow(
  const AW: IWebviewWindow): TFakeWebview;
var
  LAcc: IFakeSelfAccess;
begin
  if (AW <> nil) and (AW.QueryInterface(IFakeSelfAccess, LAcc) = 0) then
    Result := LAcc.FakeSelf as TFakeWebview
  else
    raise EWebviewInvalidState.Create(
      'window is not a nextpas.core.webview.fake instance');
end;

function TFakeWebview.FakeSelf: TObject;
begin
  Result := Self;
end;

function WindowOptionsOf(const AOptions: TWebviewOptions): TWindowOptions;
begin
  Result := DefaultWindowOptions;
  Result.Title := AOptions.Title;
  Result.Width := AOptions.Width;
  Result.Height := AOptions.Height;
  Result.MinWidth := AOptions.MinWidth;
  Result.MinHeight := AOptions.MinHeight;
  Result.MaxWidth := AOptions.MaxWidth;
  Result.MaxHeight := AOptions.MaxHeight;
  Result.Resizable := AOptions.Resizable;
  Result.Maximized := AOptions.Maximized;
  Result.ParentHandle := nil;
end;

constructor TFakeWebview.Create(const AOptions: TWebviewOptions);
var
  LReg: TFakeInvokeRegistry;
  LAssets: TFakeAssets;
  LWinOpts: TWindowOptions;
begin
  inherited Create;
  FLck := TMutex.Create as ILock;
  FClosed := False;
  FZoom := 1.0;
  FUserAgent := '';
  FBridgeReady := False;
  FDebugTools := AOptions.DebugTools;
  LWinOpts := WindowOptionsOf(AOptions);
  FWindow := TFakeWindow.Create(LWinOpts);
  FOwnsWindow := True;
  LReg := TFakeInvokeRegistry.Create;
  LAssets := TFakeAssets.Create(AOptions.DevServerUrl <> '');
  FInvokesIntf := LReg;    { 拥有（引用计数） }
  FAssetsIntf := LAssets;
  FInvokes := LReg;        { 非拥有别名（同类私有访问） }
  FAssets := LAssets;
  FDroppedEmits := 0;
  FNavigateCount := 0;
  FHistoryCount := 0;
  FHistIdx := -1;
  RegisterLive(Self);

  { Initial* 启动加载：构造即导航。优先级 InitialUrl > InitialHtml
    （CONTRACT §2.2），资产/桥请求都在主循环泵里才发生，Build 返回后的
    挂载先于任何请求，无时序竞态（§3.4） }
  if AOptions.InitialUrl <> '' then
    Navigate(AOptions.InitialUrl)
  else if AOptions.InitialHtml <> '' then
    NavigateToString(AOptions.InitialHtml);
end;

constructor TFakeWebview.CreateOn(const AParent: IWindow; const AOptions: TWebviewOptions);
var
  LReg: TFakeInvokeRegistry;
  LAssets: TFakeAssets;
begin
  inherited Create;
  if AParent = nil then
    raise EWebviewInvalidState.Create('Parent window must not be nil for CreateOn');
  FLck := TMutex.Create as ILock;
  FClosed := False;
  FZoom := 1.0;
  FUserAgent := '';
  FBridgeReady := False;
  FDebugTools := AOptions.DebugTools;
  FWindow := AParent;
  FOwnsWindow := False;
  LReg := TFakeInvokeRegistry.Create;
  LAssets := TFakeAssets.Create(AOptions.DevServerUrl <> '');
  FInvokesIntf := LReg;
  FAssetsIntf := LAssets;
  FInvokes := LReg;
  FAssets := LAssets;
  FDroppedEmits := 0;
  FNavigateCount := 0;
  FHistoryCount := 0;
  FHistIdx := -1;
  RegisterLive(Self);
  if AOptions.InitialUrl <> '' then
    Navigate(AOptions.InitialUrl)
  else if AOptions.InitialHtml <> '' then
    NavigateToString(AOptions.InitialHtml);
end;

destructor TFakeWebview.Destroy;
begin
  UnregisterLive(Self);
  inherited Destroy;
end;

procedure TFakeWebview.RequireOpen;
begin
  if FClosed then
    raise EWebviewClosed.Create('webview window is closed');
end;

procedure TFakeWebview.GrowQueue; inline;
begin
  if FEvalQueueCount = Length(FEvalQueue) then
  begin
    specialize VecGrow<Boolean>(FEvalQueue, FEvalQueueCount);
    specialize VecGrow<string>(FEvalResults, FEvalQueueCount);
  end;
end;

procedure TFakeWebview.RecordOutcome(const ACmd: string; AIsError: Boolean;
  const AResultJson, ACode, AMessage: string);
var
  LNew, LOld: TFakeInvokeOutcomes;
  LCap, LCount, LOldLen, LIdx: Integer;
begin
  // stability: managed assignments keep AddRef/Release balanced, heaptrc0 safe, no PPointer steal; perf via bytes.ops VecCopy/VecGrowCapacity single source inline, zero mod, zero leak
  // perf fix: optimistic retry — allocation + VecCopy outside lock, install under lock only O(1) check+swap, stale => retry, zero O(n) hold, mirrors dispatcher fix
  while True do
  begin
    FLck.Acquire;
    try
      if FOutcomesCount < Length(FOutcomes) then
      begin
        LIdx := FOutcomesCount;
        Inc(FOutcomesCount);
        FOutcomes[LIdx].Cmd := ACmd;
        FOutcomes[LIdx].IsError := AIsError;
        FOutcomes[LIdx].ResultJson := AResultJson;
        FOutcomes[LIdx].Code := ACode;
        FOutcomes[LIdx].Message := AMessage;
        Exit;
      end;
      LCap := VecGrowCapacity(Length(FOutcomes));
      LOld := FOutcomes;
      LCount := FOutcomesCount;
      LOldLen := Length(FOutcomes);
    finally
      FLck.Release;
    end;
    // perf: heap allocation outside lock, single source VecGrowCapacity inline zero extra call
    SetLength(LNew, LCap);
    // perf: O(n) VecCopy single source outside lock, zero lock hold, managed ref preserved, inline zero-copy
    if LCount > 0 then
      specialize VecCopy<TFakeInvokeOutcome>(LOld, LNew, LCount);
    FLck.Acquire;
    try
      if FOutcomesCount < Length(FOutcomes) then
      begin
        LIdx := FOutcomesCount;
        Inc(FOutcomesCount);
        FOutcomes[LIdx].Cmd := ACmd;
        FOutcomes[LIdx].IsError := AIsError;
        FOutcomes[LIdx].ResultJson := AResultJson;
        FOutcomes[LIdx].Code := ACode;
        FOutcomes[LIdx].Message := AMessage;
        Exit;
      end;
      if (Length(FOutcomes) = LOldLen) and (FOutcomesCount = LCount) then
      begin
        // stability: FOutcomes:=LNew releases old refs via finalization, retains new, zero leak
        FOutcomes := LNew;
        LIdx := FOutcomesCount;
        Inc(FOutcomesCount);
        FOutcomes[LIdx].Cmd := ACmd;
        FOutcomes[LIdx].IsError := AIsError;
        FOutcomes[LIdx].ResultJson := AResultJson;
        FOutcomes[LIdx].Code := ACode;
        FOutcomes[LIdx].Message := AMessage;
        Exit;
      end;
      // contention: stale snapshot — discard LNew and retry, zero O(n) under lock, rare path
    finally
      FLck.Release;
    end;
  end;
end;

procedure TFakeWebview.PushHistory(const AUrl: string);
var
  I: Integer;
begin
  if FHistIdx + 1 < FHistoryCount then
  begin
    for I := FHistIdx + 2 to FHistoryCount - 1 do
      FHistory[I] := '';
    FHistoryCount := FHistIdx + 1;
  end;
  // perf: single source bytes.ops VecGrow inline (0→4→2×) zero extra call, live registry single source
  specialize VecGrow<string>(FHistory, FHistoryCount);
  FHistory[FHistoryCount] := AUrl;
  Inc(FHistoryCount);
  FHistIdx := FHistoryCount - 1;
end;

procedure TFakeWebview.FireReadyHandlers;
var
  I: Integer;
begin
  for I := 0 to FOnReadyCount - 1 do
    FOnReady[I]();
end;

procedure TFakeWebview.AppendEvalScript(const AScript: string);
begin
  // perf: single source bytes.ops VecGrow inline (0→4→2×) zero extra call, live registry single source
  specialize VecGrow<TFakeEvalRecord>(FEvalScripts, FEvalScriptsCount);
  FEvalScripts[FEvalScriptsCount].Script := AScript;
  FEvalScripts[FEvalScriptsCount].Answered := False;
  Inc(FEvalScriptsCount);
end;

function TFakeWebview.GetWindow: IWindow;
begin
  Result := FWindow;
end;

procedure TFakeWebview.Close;
var
  I, LPendingCount: Integer;
  LPending: array of TFakePendingEval;
  LErr: EWebviewEvalFailed;
  LOnError: TWebviewEvalErrorCallback;
  LNeedDec: Boolean;
begin
  LNeedDec := False;
  FLck.Acquire;
  try
    if FClosed then
      Exit;
    FClosed := True;
    LNeedDec := True;
    // perf: zero-alloc snapshot via pointer swap (no SetLength(LErrors,N)), inline O(1) move; bytes.ops single source unchanged
    LPending := FPendingEvals;
    LPendingCount := FPendingCount;
    FPendingEvals := nil;
    FPendingCount := 0;
    // stability: mark Answered under lock to preserve exactly-once invariant
    for I := 0 to LPendingCount - 1 do
    begin
      FEvalScripts[LPending[I].ScriptIdx].Answered := True;
      FEvalScripts[LPending[I].ScriptIdx].ErrorMessage := 'window closed';
    end;
  finally
    FLck.Release;
  end;
  if LNeedDec then
  begin
    GLiveLck.Acquire;
    try
      Dec(GLiveCount);
    finally
      GLiveLck.Release;
    end;
  end;
  // perf: single exception instance reused for N callbacks, inline alloc once, zero per-pending heap churn
  if LPendingCount > 0 then
  begin
    LErr := EWebviewEvalFailed.Create('window closed');
    try
      for I := 0 to LPendingCount - 1 do
      begin
        LOnError := LPending[I].OnError;
        if Assigned(LOnError) then
          LOnError(LErr);
        // release callback refs promptly to avoid retention, zero-copy nil
        LPending[I].Callback := nil;
        LPending[I].OnError := nil;
      end;
    finally
      LErr.Free;
    end;
    // stability: clear snapshot storage, release refs, nil trailing (managed)
    for I := 0 to LPendingCount - 1 do
      LPending[I] := Default(TFakePendingEval);
    LPending := nil;
  end;
  if FOwnsWindow and (FWindow <> nil) and not FWindow.IsClosed then
    FWindow.Close;
end;

function TFakeWebview.IsClosed: Boolean; inline;
begin
  Result := FClosed;
end;

procedure TFakeWebview.SetZoom(AFactor: Double);
begin
  RequireOpen;
  if AFactor <= 0 then
    raise EWebviewInvalidState.Create('zoom factor must be > 0');
  FZoom := AFactor;
end;

function TFakeWebview.GetZoom: Double;
begin
  RequireOpen;
  Result := FZoom;
end;

procedure TFakeWebview.SetUserAgent(const AUserAgent: string);
begin
  RequireOpen;
  FUserAgent := AUserAgent;
end;

function TFakeWebview.GetUserAgent: string;
begin
  RequireOpen;
  Result := FUserAgent;
end;

procedure TFakeWebview.Navigate(const AUrl: string);
var
  LEvent: TWebviewNavigationEvent;
  I: Integer;
begin
  RequireOpen;
  FNavigateCount := FNavigateCount + 1;
  PushHistory(AUrl);
  FBridgeReady := True;
  LEvent.Url := AUrl;
  LEvent.IsError := False;
  LEvent.ErrorCode := 0;
  LEvent.ErrorMessage := '';
  for I := 0 to FOnNavStartedCount - 1 do
    FOnNavStarted[I](LEvent);
  FireReadyHandlers;
end;

procedure TFakeWebview.NavigateToString(const AHtml: string);
begin
  RequireOpen;
  FNavigateCount := FNavigateCount + 1;
  PushHistory('data:text/html;base64,fake');
  FBridgeReady := True;
  FireReadyHandlers;
end;

procedure TFakeWebview.Reload;
begin
  RequireOpen;
  FReloadCount := FReloadCount + 1;
end;

procedure TFakeWebview.Stop;
begin
  RequireOpen;
  FStopCount := FStopCount + 1;
end;

function TFakeWebview.CanGoBack: Boolean;
begin
  RequireOpen;
  Result := FHistIdx > 0;
end;

function TFakeWebview.GoBack: Boolean;
begin
  RequireOpen;
  if FHistIdx <= 0 then
    Exit(False);
  FHistIdx := FHistIdx - 1;
  Result := True;
end;

function TFakeWebview.CanGoForward: Boolean;
begin
  RequireOpen;
  Result := FHistIdx + 1 < FHistoryCount;
end;

function TFakeWebview.GoForward: Boolean;
begin
  RequireOpen;
  if FHistIdx + 1 >= FHistoryCount then
    Exit(False);
  FHistIdx := FHistIdx + 1;
  Result := True;
end;

procedure TFakeWebview.Eval(const AJavascript: string;
  ACallback: TWebviewEvalCallback;
  AOnError: TWebviewEvalErrorCallback);
var
  LHasQueued: Boolean;
  LIsError: Boolean;
  LValue: string;
  LIdx: Integer;
begin
  RequireOpen;
  AppendEvalScript(AJavascript);
  LIdx := FEvalScriptsCount - 1;
  LHasQueued := False;
  LIsError := False;
  LValue := '';
  FLck.Acquire;
  try
    if FEvalQueueCount > 0 then
    begin
      LIsError := FEvalQueue[0];
      LValue := FEvalResults[0];
      ShiftEvalQueue;
      LHasQueued := True;
    end
    else
    begin
      // perf: single source bytes.ops VecGrow inline (0→4→2×) zero extra call, live registry single source
      specialize VecGrow<TFakePendingEval>(FPendingEvals, FPendingCount);
      FPendingEvals[FPendingCount].ScriptIdx := LIdx;
      FPendingEvals[FPendingCount].Callback := ACallback;
      FPendingEvals[FPendingCount].OnError := AOnError;
      Inc(FPendingCount);
    end;
  finally
    FLck.Release;
  end;
  if LHasQueued then
    SettleEval(LIdx, LIsError, LValue, ACallback, AOnError);
end;

procedure TFakeWebview.ShiftEvalQueue;
var
  I: Integer;
begin
  for I := 0 to FEvalQueueCount - 2 do
  begin
    FEvalQueue[I] := FEvalQueue[I + 1];
    FEvalResults[I] := FEvalResults[I + 1];
  end;
  Dec(FEvalQueueCount);
  if FEvalQueueCount < Length(FEvalQueue) then
  begin
    FEvalQueue[FEvalQueueCount] := False;
    FEvalResults[FEvalQueueCount] := '';
  end;
end;

{ 恰好一次兑现：先落记录再触发回调（回调内再入本对象是安全的） }
procedure TFakeWebview.SettleEval(AIdx: Integer; AIsError: Boolean;
  const AValue: string;
  ACallback: TWebviewEvalCallback;
  AOnError: TWebviewEvalErrorCallback);
var
  LErr: EWebviewEvalFailed;
begin
  if FEvalScripts[AIdx].Answered then
    raise EWebviewInvalidState.Create('eval already settled');
  FEvalScripts[AIdx].Answered := True;
  if AIsError then
  begin
    FEvalScripts[AIdx].ErrorMessage := AValue;
    { 异常实例所有权：框架创建、回调期内有效、回调返回后框架释放。
      回调只读信息，不得持有引用（CONTRACT §3.2）。 }
    LErr := EWebviewEvalFailed.Create(AValue);
    try
      AOnError(LErr);
    finally
      LErr.Free;
    end;
  end
  else
  begin
    FEvalScripts[AIdx].ResultJson := AValue;
    ACallback(AValue);
  end;
end;

procedure TFakeWebview.Emit(const AEvent, APayloadJson: string);
begin
  CheckWebviewEventName(AEvent);
  RequireOpen;
  if not FBridgeReady then
  begin
    FDroppedEmits := FDroppedEmits + 1;
    Exit;
  end;
  // perf: single source bytes.ops VecGrow inline (0→4→2×) zero extra call, live registry single source
  specialize VecGrow<TFakeEmit>(FEmits, FEmitsCount);
  FEmits[FEmitsCount].Event := AEvent;
  FEmits[FEmitsCount].PayloadJson := APayloadJson;
  Inc(FEmitsCount);
end;

procedure TFakeWebview.OnNavigationStarted(AHandler: TWebviewNavEventHandler);
begin
  RequireOpen;
  // perf: single source bytes.ops VecGrow inline (0→4→2×) zero extra call, live registry single source
  specialize VecGrow<TWebviewNavEventHandler>(FOnNavStarted, FOnNavStartedCount);
  FOnNavStarted[FOnNavStartedCount] := AHandler;
  Inc(FOnNavStartedCount);
end;

procedure TFakeWebview.OnNavigationStarted(AHandler: TWebviewNavEventMethod);
begin
  OnNavigationStarted(NavMethodToRef(AHandler));
end;

procedure TFakeWebview.OnNavigationStarted(AHandler: TWebviewNavEventProc);
begin
  OnNavigationStarted(NavProcToRef(AHandler));
end;

procedure TFakeWebview.OnNavigationFinished(AHandler: TWebviewNavEventHandler);
begin
  RequireOpen;
  // perf: single source bytes.ops VecGrow inline (0→4→2×) zero extra call, live registry single source
  specialize VecGrow<TWebviewNavEventHandler>(FOnNavFinished, FOnNavFinishedCount);
  FOnNavFinished[FOnNavFinishedCount] := AHandler;
  Inc(FOnNavFinishedCount);
end;

procedure TFakeWebview.OnNavigationFinished(AHandler: TWebviewNavEventMethod);
begin
  OnNavigationFinished(NavMethodToRef(AHandler));
end;

procedure TFakeWebview.OnNavigationFinished(AHandler: TWebviewNavEventProc);
begin
  OnNavigationFinished(NavProcToRef(AHandler));
end;

procedure TFakeWebview.OnNavigationFailed(AHandler: TWebviewNavFailedHandler);
begin
  RequireOpen;
  // perf: single source bytes.ops VecGrow inline (0→4→2×) zero extra call, live registry single source
  specialize VecGrow<TWebviewNavFailedHandler>(FOnNavFailed, FOnNavFailedCount);
  FOnNavFailed[FOnNavFailedCount] := AHandler;
  Inc(FOnNavFailedCount);
end;

procedure TFakeWebview.OnNavigationFailed(AHandler: TWebviewNavFailedMethod);
begin
  OnNavigationFailed(NavFailedMethodToRef(AHandler));
end;

procedure TFakeWebview.OnNavigationFailed(AHandler: TWebviewNavFailedProc);
begin
  OnNavigationFailed(NavFailedProcToRef(AHandler));
end;

procedure TFakeWebview.OnReady(AHandler: TWebviewNotifyHandler);
begin
  RequireOpen;
  // perf: single source bytes.ops VecGrow inline (0→4→2×) zero extra call, live registry single source
  specialize VecGrow<TWebviewNotifyHandler>(FOnReady, FOnReadyCount);
  FOnReady[FOnReadyCount] := AHandler;
  Inc(FOnReadyCount);
end;

procedure TFakeWebview.OnReady(AHandler: TWebviewNotifyMethod);
begin
  OnReady(NotifyMethodToRef(AHandler));
end;

procedure TFakeWebview.OnReady(AHandler: TWebviewNotifyProc);
begin
  OnReady(NotifyProcToRef(AHandler));
end;

function TFakeWebview.GetInvokes: IWebviewInvokeRegistry;
begin
  Result := TFakeInvokeRegistry(FInvokes);
end;

function TFakeWebview.GetAssets: IWebviewAssets;
begin
  Result := TFakeAssets(FAssets);
end;

{ ---- 驱动面 ---- }

function TFakeWebview.PumpOnce: Boolean;
begin
  if FWindow = nil then Exit(False);
  // Delegate to underlying fake window's dispatcher pump
  try
    Result := TFakeWindow.FromWindow(FWindow).PumpOnce;
  except
    Result := False;
  end;
end;

procedure TFakeWebview.PumpAll;
begin
  if FWindow = nil then Exit;
  try
    TFakeWindow.FromWindow(FWindow).PumpAll;
  except
  end;
end;

function TFakeWebview.PendingPosts: Integer;
begin
  if FWindow = nil then Exit(0);
  try
    Result := TFakeWindow.FromWindow(FWindow).PendingPosts;
  except
    Result := 0;
  end;
end;

procedure TFakeWebview.QueueEvalResult(const AResultJson: string);
var
  LPending: TFakePendingEval;
  LHadPending: Boolean;
begin
  LHadPending := False;
  FLck.Acquire;
  try
    if FPendingCount > 0 then
    begin
      LPending := FPendingEvals[0];
      ShiftEvalList;
      LHadPending := True;
    end
    else
    begin
      GrowQueue;
      FEvalQueue[FEvalQueueCount] := False;
      FEvalResults[FEvalQueueCount] := AResultJson;
      Inc(FEvalQueueCount);
    end;
  finally
    FLck.Release;
  end;
  if LHadPending then
    SettleEval(LPending.ScriptIdx, False, AResultJson,
      LPending.Callback, LPending.OnError);
end;

procedure TFakeWebview.QueueEvalError(const AMessage: string);
var
  LPending: TFakePendingEval;
  LHadPending: Boolean;
begin
  LHadPending := False;
  FLck.Acquire;
  try
    if FPendingCount > 0 then
    begin
      LPending := FPendingEvals[0];
      ShiftEvalList;
      LHadPending := True;
    end
    else
    begin
      GrowQueue;
      FEvalQueue[FEvalQueueCount] := True;
      FEvalResults[FEvalQueueCount] := AMessage;
      Inc(FEvalQueueCount);
    end;
  finally
    FLck.Release;
  end;
  if LHadPending then
    SettleEval(LPending.ScriptIdx, True, AMessage,
      LPending.Callback, LPending.OnError);
end;

procedure TFakeWebview.ShiftEvalList;
var
  I: Integer;
begin
  for I := 0 to FPendingCount - 2 do
    FPendingEvals[I] := FPendingEvals[I + 1];
  Dec(FPendingCount);
  if FPendingCount < Length(FPendingEvals) then
    FPendingEvals[FPendingCount] := Default(TFakePendingEval);
end;

procedure TFakeWebview.FireNavigationStarted(const AUrl: string);
var
  LEvent: TWebviewNavigationEvent;
  I: Integer;
begin
  RequireOpen;
  LEvent.Url := AUrl;
  for I := 0 to FOnNavStartedCount - 1 do
    FOnNavStarted[I](LEvent);
end;

procedure TFakeWebview.FireNavigationFinished(const AUrl: string);
var
  LEvent: TWebviewNavigationEvent;
  I: Integer;
begin
  RequireOpen;
  LEvent.Url := AUrl;
  for I := 0 to FOnNavFinishedCount - 1 do
    FOnNavFinished[I](LEvent);
end;

procedure TFakeWebview.FireNavigationFailed(const AUrl: string;
  ACode: Integer; const AMessage: string);
var
  LEvent: TWebviewNavigationEvent;
  I: Integer;
begin
  RequireOpen;
  LEvent.Url := AUrl;
  LEvent.IsError := True;
  LEvent.ErrorCode := ACode;
  LEvent.ErrorMessage := AMessage;
  for I := 0 to FOnNavFailedCount - 1 do
    FOnNavFailed[I](LEvent);
end;

procedure TFakeWebview.FireReady;
begin
  RequireOpen;
  FBridgeReady := True;
  FireReadyHandlers;
end;

procedure TFakeWebview.SimulateBridgeReady;
begin
  RequireOpen;
  FBridgeReady := True;
end;

procedure TFakeWebview.EnqueueReceipt(AFrameId: Int64; AIsError: Boolean;
  const AResultJson, ACode, AMessage: string);
begin
  // perf: single source bytes.ops VecGrow inline (0→4→2×) zero extra call, live registry single source
  specialize VecGrow<string>(FCapturedEvals, FCapturedCount);
  if AIsError then
    FCapturedEvals[FCapturedCount] :=
      BuildRejectScript(AFrameId, ACode, AMessage)
  else
    FCapturedEvals[FCapturedCount] :=
      BuildResolveScript(AFrameId, AResultJson);
  Inc(FCapturedCount);
end;

function TFakeWebview.CaptureEvalCount: Integer;
begin
  Result := FCapturedCount;
end;

function TFakeWebview.CaptureEvalAt(AIndex: Integer): string;
begin
  Result := FCapturedEvals[AIndex];
end;

procedure TFakeWebview.DispatchInvoke(AFrameId: Int64; const ACmd,
  APayloadJson: string);
var
  LReg: TFakeInvokeRegistry;
  LIsAsync: Boolean;
  LSync: TWebviewInvokeSyncHandler;
  LAsync: TWebviewInvokeAsyncHandler;
  LResultJson: string;
  LCompletion: IWebviewInvokeCompletion;
begin
  LReg := TFakeInvokeRegistry(FInvokes);
  if not LReg.Find(ACmd, LIsAsync, LSync, LAsync) then
  begin
    RecordOutcome(ACmd, True, '', NPW_CODE_HANDLER_MISSING,
      'no handler registered for cmd');
    if AFrameId >= 0 then
      EnqueueReceipt(AFrameId, True, '', NPW_CODE_HANDLER_MISSING,
        'no handler registered for cmd');
    Exit;
  end;
  if LIsAsync then
  begin
    LCompletion := TFakeCompletion.Create(Self, ACmd, AFrameId);
    try
      LAsync(APayloadJson, LCompletion);
    except
      on E: Exception do
      begin
        if E is EWebviewInvokeError then
        begin
          RecordOutcome(ACmd, True, '',
            MapInvokeCode(EWebviewInvokeError(E).Code), E.Message);
          if AFrameId >= 0 then
            EnqueueReceipt(AFrameId, True, '',
              MapInvokeCode(EWebviewInvokeError(E).Code), E.Message);
        end
        else
        begin
          RecordOutcome(ACmd, True, '', NPW_CODE_HANDLER_ERROR, E.Message);
          if AFrameId >= 0 then
            EnqueueReceipt(AFrameId, True, '', NPW_CODE_HANDLER_ERROR,
              E.Message);
        end;
      end;
    end;
  end
  else
  begin
    try
      LResultJson := LSync(APayloadJson);
      RecordOutcome(ACmd, False, LResultJson, '', '');
      if AFrameId >= 0 then
        EnqueueReceipt(AFrameId, False, LResultJson, '', '');
    except
      on E: Exception do
      begin
        if E is EWebviewInvokeError then
        begin
          RecordOutcome(ACmd, True, '',
            MapInvokeCode(EWebviewInvokeError(E).Code), E.Message);
          if AFrameId >= 0 then
            EnqueueReceipt(AFrameId, True, '',
              MapInvokeCode(EWebviewInvokeError(E).Code), E.Message);
        end
        else
        begin
          RecordOutcome(ACmd, True, '', NPW_CODE_HANDLER_ERROR, E.Message);
          if AFrameId >= 0 then
            EnqueueReceipt(AFrameId, True, '', NPW_CODE_HANDLER_ERROR,
              E.Message);
        end;
      end;
    end;
  end;
end;

procedure TFakeWebview.DeliverInvoke(const ACmd, APayloadJson: string);
begin
  RequireOpen;
  { driver 直呼：无帧 id，不产生回执脚本 }
  DispatchInvoke(-1, ACmd, APayloadJson);
end;

procedure TFakeWebview.DeliverFrame(const AFrameJson: string);
var
  LFrame: TWebviewFrame;
begin
  RequireOpen;
  if not TryDecodeFrame(AFrameJson, LFrame) then
    raise EWebviewBadFrame.Create('malformed invoke frame');
  DispatchInvoke(LFrame.Id, LFrame.Cmd, LFrame.PayloadJson);
end;

function TFakeWebview.OutcomeCount: Integer;
begin
  Result := FOutcomesCount;
end;

function TFakeWebview.OutcomeAt(AIndex: Integer): TFakeInvokeOutcome;
begin
  Result := FOutcomes[AIndex];
end;

function TFakeWebview.LastOutcome: TFakeInvokeOutcome;
begin
  if FOutcomesCount = 0 then
    raise EWebviewInvalidState.Create('no invoke outcomes recorded');
  Result := FOutcomes[FOutcomesCount - 1];
end;

function TFakeWebview.EmitCount: Integer;
begin
  Result := FEmitsCount;
end;

function TFakeWebview.DroppedEmitCount: Integer;
begin
  Result := FDroppedEmits;
end;

function TFakeWebview.LastEmitEvent: string;
begin
  if FEmitsCount = 0 then
    raise EWebviewInvalidState.Create('no emits recorded');
  Result := FEmits[FEmitsCount - 1].Event;
end;

function TFakeWebview.LastEmitPayloadJson: string;
begin
  if FEmitsCount = 0 then
    raise EWebviewInvalidState.Create('no emits recorded');
  Result := FEmits[FEmitsCount - 1].PayloadJson;
end;

function TFakeWebview.NavigateCount: Integer;
begin
  Result := FNavigateCount;
end;

function TFakeWebview.EvalRecordCount: Integer;
begin
  Result := FEvalScriptsCount;
end;

function TFakeWebview.EvalRecordAt(AIndex: Integer): TFakeEvalRecord;
begin
  Result := FEvalScripts[AIndex];
end;
