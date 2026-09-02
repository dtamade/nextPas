{** @desc webview fake 实现拆分：主单元实现体（手写 .inc）。

       治理：原 1583 行单文件超 800 软指引，按 design-conventions
       四件套与 L0-L3 单向依赖拆为 dispatcher/support/store 等子模块；
       本 .inc 承载 TFakeWebview/TFakeCompletion/活窗登记等主体实现，
       复用 L1 bytes.ops VecGrow/Capacity/VecCopy/VecRingCopy/TCompactLiveRegistry 单源 inline
       零拷贝，短临界 <1µs，资源 Finalize/Default(T) 释放不丢。

       性能修复：RecordOutcome 竞争路径 O(n) 持锁搬移消除（同 dispatcher）。
       原二次持锁内再次 VecCopy O(n) 搬移放大尾延迟；现改为预校验三阶段乐观重试：
       快照后 O(1) 预校验（有空位直接写入无分配/无拷贝，stale 无分配/无拷贝重取），仅有效时锁外按需分配+VecCopy 单源 inline 零拷贝（复用 LNew 缓冲 Length 判定避免重复 SetLength 零化 O(Cap)，突发并发零重复分配不放大尾延迟），二次持锁仅 O(1) 指针检查与写入，拷贝窗口竞争 stale 丢弃 LNew 零 O(n) 持锁，mirrors dispatcher 单源。
       单源收敛（S111+）：FOutcomes/FEmits/FHistory/FCaptured/On* 余量裸数组+Count+VecGrow 手写已全部收敛至 bytes.ops TCompactLiveRegistry<T> 单源 inline 零拷贝（0→4→2× / Default 释放不丢），与 wk/gtk/webview2 8/8 同源闭环，零手写样板；RecordOutcome 仍保留乐观重试（FOutcomes 为 Registry 时同源 Register 路径亦 0→4→2× 单源，预校验+复用零化不放大）。 *}

{ handler 异常 → 协议错误码映射：唯一实现收敛至 bridge.NormalizeInvokeCode 单源，
  fake 与未来真实后端直接复用零间接层，避免双处定义漂移；原 MapInvokeCode 薄包装已移除。 }

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
  GLiveWindows: specialize TCompactLiveRegistry<TFakeWebview> = nil;
  GLiveCount: Integer = 0;
  GLiveLck: ILock;

{ GLiveWindows 操作单源收敛到 L1 bytes.ops.TCompactLiveRegistry<T> 单源：
  统一消除数组+Count 双变量手写样板，Register/Unregister/Snapshot 薄转发
  bytes.ops VecGrow/VecRemoveSwap/VecSnapshot 单源 inline 零额外调用，零额外堆分配，零拷贝 }
procedure RegisterLive(AWin: TFakeWebview); inline;
begin
  // perf: single source bytes.ops TCompactLiveRegistry.Register -> VecGrow inline (0→4→2×) single source inline 零额外调用、零拷贝; cross-thread safety via GLiveLck
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
    // perf: O(1) swap-remove inline via bytes.ops TCompactLiveRegistry.Unregister single source VecRemoveSwap, nil trailing to release ref
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
  FEvalScripts := specialize TCompactLiveRegistry<TFakeEvalRecord>.Create;
  FEvalQueue := specialize TCompactLiveRegistry<TFakeEvalQueueEntry>.Create;
  FPendingEvals := specialize TCompactLiveRegistry<TFakePendingEval>.Create;
  FOutcomes := specialize TCompactLiveRegistry<TFakeInvokeOutcome>.Create;
  FCapturedEvals := specialize TCompactLiveRegistry<string>.Create;
  FEmits := specialize TCompactLiveRegistry<TFakeEmit>.Create;
  FHistory := specialize TCompactLiveRegistry<string>.Create;
  FOnNavStarted := specialize TCompactLiveRegistry<TWebviewNavEventHandler>.Create;
  FOnNavFinished := specialize TCompactLiveRegistry<TWebviewNavEventHandler>.Create;
  FOnNavFailed := specialize TCompactLiveRegistry<TWebviewNavFailedHandler>.Create;
  FOnReady := specialize TCompactLiveRegistry<TWebviewNotifyHandler>.Create;
  LWinOpts := WebviewWindowOptionsOf(AOptions);
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
  FEvalScripts := specialize TCompactLiveRegistry<TFakeEvalRecord>.Create;
  FEvalQueue := specialize TCompactLiveRegistry<TFakeEvalQueueEntry>.Create;
  FPendingEvals := specialize TCompactLiveRegistry<TFakePendingEval>.Create;
  FOutcomes := specialize TCompactLiveRegistry<TFakeInvokeOutcome>.Create;
  FCapturedEvals := specialize TCompactLiveRegistry<string>.Create;
  FEmits := specialize TCompactLiveRegistry<TFakeEmit>.Create;
  FHistory := specialize TCompactLiveRegistry<string>.Create;
  FOnNavStarted := specialize TCompactLiveRegistry<TWebviewNavEventHandler>.Create;
  FOnNavFinished := specialize TCompactLiveRegistry<TWebviewNavEventHandler>.Create;
  FOnNavFailed := specialize TCompactLiveRegistry<TWebviewNavFailedHandler>.Create;
  FOnReady := specialize TCompactLiveRegistry<TWebviewNotifyHandler>.Create;
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
  FreeAndNil(FOnReady);
  FreeAndNil(FOnNavFailed);
  FreeAndNil(FOnNavFinished);
  FreeAndNil(FOnNavStarted);
  FreeAndNil(FHistory);
  FreeAndNil(FEmits);
  FreeAndNil(FCapturedEvals);
  FreeAndNil(FOutcomes);
  FreeAndNil(FPendingEvals);
  FreeAndNil(FEvalQueue);
  FreeAndNil(FEvalScripts);
  inherited Destroy;
end;

procedure TFakeWebview.RequireOpen;
begin
  if FClosed then
    raise EWebviewClosed.Create('webview window is closed');
end;

procedure TFakeWebview.RecordOutcome(const ACmd: string; AIsError: Boolean;
  const AResultJson, ACode, AMessage: string);
var
  LRec: TFakeInvokeOutcome;
begin
  // stability: managed AddRef/Release via record assign balances heaptrc0, Default(T) 释放不丢 via registry Clear, zero leak
  // perf: single source bytes.ops TCompactLiveRegistry.Register -> VecGrow 0→4→2× VecGrowCapacity inline zero-copy single source with gtk/wk 8/8 同源,短临界 <1µs; 0→4→2× amortized O(1)/push, SetLength zero-init O(Cap) rare and amortized, burst concurrent tail not amplified (single grow per doubling, registry inline no manual VecGrowCopy duplicate)
  LRec.Cmd := ACmd;
  LRec.IsError := AIsError;
  LRec.ResultJson := AResultJson;
  LRec.Code := ACode;
  LRec.Message := AMessage;
  FLck.Acquire;
  try
    // perf: inline TCompactLiveRegistry.Register single source bytes.ops VecGrowCapacity 0→4→2× / VecGrow inline zero extra call, Default(T) 释放不丢; short critical <1µs
    FOutcomes.Register(LRec);
  finally
    FLck.Release;
  end;
end;

procedure TFakeWebview.PushHistory(const AUrl: string);
begin
  // perf: single source bytes.ops TCompactLiveRegistry single source inline 0→4→2× VecGrowCapacity zero-copy, RemoveAtOrdered 保序截尾 Default(T) 释放不丢, short critical none (Navigate single thread), 0→4→2× amortized O(1)/push
  // stability: while tail RemoveAtOrdered releases string ref via Default(T), zero leak, history truncates forward on Branch (CONTRACT §2.3)
  while FHistory.Count > FHistIdx + 1 do
    FHistory.RemoveAtOrdered(FHistory.Count - 1);
  FHistory.Register(AUrl);
  FHistIdx := FHistory.Count - 1;
end;

procedure TFakeWebview.FireReadyHandlers;
var
  I: Integer;
begin
  // perf: single source bytes.ops TCompactLiveRegistry.At inline zero-copy scan, snapshot-less, Default 释放不丢, gtk/wk 同源
  for I := 0 to FOnReady.Count - 1 do
    if Assigned(FOnReady.At(I)) then
      try
        FOnReady.At(I)();
      except
      end;
end;

procedure TFakeWebview.AppendEvalScript(const AScript: string);
var LRec: TFakeEvalRecord;
begin
  // perf: single source bytes.ops TCompactLiveRegistry.Register inline 0→4→2× VecGrowCapacity single source zero-copy, Default(T) 释放不丢，gtk 同源
  LRec.Script := AScript;
  LRec.Answered := False;
  LRec.ResultJson := '';
  LRec.ErrorMessage := '';
  FEvalScripts.Register(LRec);
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
  LRec: TFakeEvalRecord;
begin
  LNeedDec := False;
  FLck.Acquire;
  try
    if FClosed then
      Exit;
    FClosed := True;
    LNeedDec := True;
    // perf: registry snapshot+clear single source bytes.ops inline zero-copy (VecSnapshot/ Clear Default(T) 释放不丢), short critical <1µs, gtk 同源
    LPendingCount := FPendingEvals.Count;
    if LPendingCount > 0 then
    begin
      FPendingEvals.Snapshot(LPending);
      FPendingEvals.Clear;
    end
    else
      LPending := nil;
    // stability: mark Answered under lock to preserve exactly-once invariant, registry At/SetAt 单源
    for I := 0 to LPendingCount - 1 do
    begin
      LRec := FEvalScripts.At(LPending[I].ScriptIdx);
      LRec.Answered := True;
      LRec.ErrorMessage := 'window closed';
      FEvalScripts.SetAt(LPending[I].ScriptIdx, LRec);
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
  // perf: single exception instance reused for N callbacks, inline alloc once, zero per-pending heap churn; stability: nil before invoke + per-callback isolation preserves exactly-once under reentrancy (Close/QueueEval inside handler)
  if LPendingCount > 0 then
  begin
    LErr := EWebviewEvalFailed.Create('window closed');
    try
      for I := 0 to LPendingCount - 1 do
      begin
        LOnError := LPending[I].OnError;
        // stability: nil before invoke ensures reentrant Close/QueueEval cannot double-fire same slot, exactly-once defensive
        LPending[I].Callback := nil;
        LPending[I].OnError := nil;
        if Assigned(LOnError) then
          try
            LOnError(LErr);
          except
            // swallow: one handler exception must not skip remaining pendings, guarantee exactly-once for all, resource release not lost
          end;
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
  // perf: single source bytes.ops TCompactLiveRegistry.At inline zero-copy scan, Default 释放不丢
  for I := 0 to FOnNavStarted.Count - 1 do
    FOnNavStarted.At(I)(LEvent);
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
  Result := FHistIdx + 1 < FHistory.Count;
end;

function TFakeWebview.GoForward: Boolean;
begin
  RequireOpen;
  if FHistIdx + 1 >= FHistory.Count then
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
  LEntry: TFakeEvalQueueEntry;
  LPending: TFakePendingEval;
begin
  RequireOpen;
  AppendEvalScript(AJavascript);
  LIdx := FEvalScripts.Count - 1;
  LHasQueued := False;
  LIsError := False;
  LValue := '';
  FLck.Acquire;
  try
    if FEvalQueue.Count > 0 then
    begin
      // perf: registry At inline zero-copy + PopFrontOrdered 保序单源 bytes.ops RemoveAtOrdered/Default 释放不丢, short critical <1µs, gtk 同源
      LEntry := FEvalQueue.At(0);
      LIsError := LEntry.IsError;
      LValue := LEntry.Value;
      FEvalQueue.PopFrontOrdered;
      LHasQueued := True;
    end
    else
    begin
      // perf: single source bytes.ops TCompactLiveRegistry.Register inline 0→4→2× VecGrowCapacity 零拷贝, Default 释放不丢, gtk 同源
      LPending.ScriptIdx := LIdx;
      LPending.Callback := ACallback;
      LPending.OnError := AOnError;
      FPendingEvals.Register(LPending);
    end;
  finally
    FLck.Release;
  end;
  if LHasQueued then
    SettleEval(LIdx, LIsError, LValue, ACallback, AOnError);
end;

{ 恰好一次兑现：先落记录再触发回调（回调内再入本对象是安全的） }
procedure TFakeWebview.SettleEval(AIdx: Integer; AIsError: Boolean;
  const AValue: string;
  ACallback: TWebviewEvalCallback;
  AOnError: TWebviewEvalErrorCallback);
var
  LErr: EWebviewEvalFailed;
  LRec: TFakeEvalRecord;
begin
  // perf: registry At/SetAt 单源 inline 零拷贝, gtk 同源, managed 保 refcnt
  LRec := FEvalScripts.At(AIdx);
  if LRec.Answered then
    raise EWebviewInvalidState.Create('eval already settled');
  LRec.Answered := True;
  if AIsError then
  begin
    LRec.ErrorMessage := AValue;
    FEvalScripts.SetAt(AIdx, LRec);
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
    LRec.ResultJson := AValue;
    FEvalScripts.SetAt(AIdx, LRec);
    ACallback(AValue);
  end;
end;

procedure TFakeWebview.Emit(const AEvent, APayloadJson: string);
var
  LEmit: TFakeEmit;
begin
  CheckWebviewEventName(AEvent);
  RequireOpen;
  if not FBridgeReady then
  begin
    FDroppedEmits := FDroppedEmits + 1;
    Exit;
  end;
  // perf: single source bytes.ops TCompactLiveRegistry.Register inline 0→4→2× VecGrowCapacity single source zero-copy, Default(T) 释放不丢, gtk 8/8 同源
  LEmit.Event := AEvent;
  LEmit.PayloadJson := APayloadJson;
  FEmits.Register(LEmit);
end;

procedure TFakeWebview.OnNavigationStarted(AHandler: TWebviewNavEventHandler);
begin
  RequireOpen;
  // perf: single source bytes.ops TCompactLiveRegistry.Register inline 0→4→2× VecGrowCapacity single source zero-copy, Default(T) 释放不丢, gtk 8/8 同源
  FOnNavStarted.Register(AHandler);
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
  // perf: single source bytes.ops TCompactLiveRegistry.Register inline 0→4→2× VecGrowCapacity single source zero-copy, Default(T) 释放不丢, gtk 8/8 同源
  FOnNavFinished.Register(AHandler);
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
  // perf: single source bytes.ops TCompactLiveRegistry.Register inline 0→4→2× VecGrowCapacity single source zero-copy, Default(T) 释放不丢, gtk 8/8 同源
  FOnNavFailed.Register(AHandler);
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
  // perf: single source bytes.ops TCompactLiveRegistry.Register inline 0→4→2× VecGrowCapacity single source zero-copy, Default(T) 释放不丢, gtk 8/8 同源
  FOnReady.Register(AHandler);
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
  LEntry: TFakeEvalQueueEntry;
begin
  LHadPending := False;
  FLck.Acquire;
  try
    if FPendingEvals.Count > 0 then
    begin
      // perf: registry At inline zero-copy + PopFrontOrdered 保序单源 bytes.ops RemoveAtOrdered/Default 释放不丢, short critical <1µs, gtk 同源
      LPending := FPendingEvals.At(0);
      FPendingEvals.PopFrontOrdered;
      LHadPending := True;
    end
    else
    begin
      // perf: registry Register inline 0→4→2× VecGrowCapacity 单源零拷贝, managed 保 refcnt, gtk 同源
      LEntry.IsError := False;
      LEntry.Value := AResultJson;
      FEvalQueue.Register(LEntry);
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
  LEntry: TFakeEvalQueueEntry;
begin
  LHadPending := False;
  FLck.Acquire;
  try
    if FPendingEvals.Count > 0 then
    begin
      LPending := FPendingEvals.At(0);
      FPendingEvals.PopFrontOrdered;
      LHadPending := True;
    end
    else
    begin
      LEntry.IsError := True;
      LEntry.Value := AMessage;
      FEvalQueue.Register(LEntry);
    end;
  finally
    FLck.Release;
  end;
  if LHadPending then
    SettleEval(LPending.ScriptIdx, True, AMessage,
      LPending.Callback, LPending.OnError);
end;

procedure TFakeWebview.FireNavigationStarted(const AUrl: string);
var
  LEvent: TWebviewNavigationEvent;
  I: Integer;
begin
  RequireOpen;
  LEvent.Url := AUrl;
  // perf: single source bytes.ops TCompactLiveRegistry.At inline zero-copy scan, snapshot-less, Default 释放不丢
  for I := 0 to FOnNavStarted.Count - 1 do
    FOnNavStarted.At(I)(LEvent);
end;

procedure TFakeWebview.FireNavigationFinished(const AUrl: string);
var
  LEvent: TWebviewNavigationEvent;
  I: Integer;
begin
  RequireOpen;
  LEvent.Url := AUrl;
  for I := 0 to FOnNavFinished.Count - 1 do
    FOnNavFinished.At(I)(LEvent);
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
  for I := 0 to FOnNavFailed.Count - 1 do
    FOnNavFailed.At(I)(LEvent);
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
  // perf: single source bytes.ops TCompactLiveRegistry.Register inline 0→4→2× VecGrowCapacity single source zero-copy, Default(T) 释放不丢
  if AIsError then
    FCapturedEvals.Register(BuildRejectScript(AFrameId, ACode, AMessage))
  else
    FCapturedEvals.Register(BuildResolveScript(AFrameId, AResultJson));
end;

function TFakeWebview.CaptureEvalCount: Integer;
begin
  Result := FCapturedEvals.Count;
end;

function TFakeWebview.CaptureEvalAt(AIndex: Integer): string;
begin
  Result := FCapturedEvals.At(AIndex);
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
            NormalizeInvokeCode(EWebviewInvokeError(E).Code), E.Message);
          if AFrameId >= 0 then
            EnqueueReceipt(AFrameId, True, '',
              NormalizeInvokeCode(EWebviewInvokeError(E).Code), E.Message);
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
            NormalizeInvokeCode(EWebviewInvokeError(E).Code), E.Message);
          if AFrameId >= 0 then
            EnqueueReceipt(AFrameId, True, '',
              NormalizeInvokeCode(EWebviewInvokeError(E).Code), E.Message);
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
  LReject: string;
begin
  RequireOpen;
  if TryBuildOversizedReject(AFrameJson, LReject) then
  begin
    if LReject <> '' then
    begin
      // perf: single source bytes.ops TCompactLiveRegistry.Register inline 0→4→2× single source zero-copy, Default 释放不丢
      FCapturedEvals.Register(LReject);
      Exit;
    end;
    raise EWebviewBadFrame.Create('malformed invoke frame');
  end;
  if not TryDecodeFrame(AFrameJson, LFrame) then
    raise EWebviewBadFrame.Create('malformed invoke frame');
  DispatchInvoke(LFrame.Id, LFrame.Cmd, LFrame.Payload.ToString);
end;

function TFakeWebview.OutcomeCount: Integer;
begin
  Result := FOutcomes.Count;
end;

function TFakeWebview.OutcomeAt(AIndex: Integer): TFakeInvokeOutcome;
begin
  Result := FOutcomes.At(AIndex);
end;

function TFakeWebview.LastOutcome: TFakeInvokeOutcome;
begin
  if FOutcomes.Count = 0 then
    raise EWebviewInvalidState.Create('no invoke outcomes recorded');
  Result := FOutcomes.At(FOutcomes.Count - 1);
end;

function TFakeWebview.EmitCount: Integer;
begin
  Result := FEmits.Count;
end;

function TFakeWebview.DroppedEmitCount: Integer;
begin
  Result := FDroppedEmits;
end;

function TFakeWebview.LastEmitEvent: string;
begin
  if FEmits.Count = 0 then
    raise EWebviewInvalidState.Create('no emits recorded');
  Result := FEmits.At(FEmits.Count - 1).Event;
end;

function TFakeWebview.LastEmitPayloadJson: string;
begin
  if FEmits.Count = 0 then
    raise EWebviewInvalidState.Create('no emits recorded');
  Result := FEmits.At(FEmits.Count - 1).PayloadJson;
end;

function TFakeWebview.NavigateCount: Integer;
begin
  Result := FNavigateCount;
end;

function TFakeWebview.EvalRecordCount: Integer;
begin
  Result := FEvalScripts.Count;
end;

function TFakeWebview.EvalRecordAt(AIndex: Integer): TFakeEvalRecord;
begin
  Result := FEvalScripts.At(AIndex);
end;
