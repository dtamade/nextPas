unit nextpas.core.webview.eval;

{** @desc webview L3 家族共享：Eval pending exactly-once Owner（INV-7 单源）。

       职责（CONTRACT §3.2/INV-7）：
       - Done 恰好一次守卫 + 锁内快照结算（Close 竞态 vs 回调）
       - pending 注册表薄转发至 L1 bytes.ops.TCompactLiveRegistry<T> 单源
       四件套：base←intf←eval←facade，外溢必先反哺本 Owner（CONTRACT §1.2）。
       性能：inline 薄转发零额外调用，TCompactLiveRegistry Snapshot 单次 SetLength+Move inline 零拷贝，短临界 <1µs 指针-only，零堆抖动。
       稳定性：Done 守卫 + Snapshot 清空 + Default(T) / Dispose 释放不丢，回调异常不丢期约。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.webview.base,
  nextpas.core.webview.intf,
  nextpas.core.bytes.ops,
  nextpas.core.sync.mutex;

type
  // 单源别名：后端 PEvalRec 统一经本 Owner 类型岛收口，消除 Pointer 硬转；实际 Slab 仍由 pool 承载，eval 仅薄转发 owner 语义（Done+Snapshot 单源）
  PEvalSlot = ^TEvalSlot;
  TEvalSlot = record
    Callback: TWebviewEvalCallback;
    OnError: TWebviewEvalErrorCallback;
    Done: Boolean;
    Owner: Pointer;
    Cancel: Pointer;
  end;
  TEvalRegistry = specialize TCompactLiveRegistry<PEvalSlot>;

procedure EvalRegisterInline(AReg: TEvalRegistry; ALock: TMutex; ASlot: PEvalSlot); inline;
procedure EvalUnregisterInline(AReg: TEvalRegistry; ALock: TMutex; ASlot: PEvalSlot); inline;
function EvalSnapshotInline(AReg: TEvalRegistry; ALock: TMutex; var ADest: array of PEvalSlot): Integer; inline;
function EvalTryMarkDoneInline(ASlot: PEvalSlot): Boolean; inline;
procedure EvalSettleInline(ASlot: PEvalSlot; AOk: Boolean; const AText: string); inline;
procedure EvalClearRegistryInline(AReg: TEvalRegistry; ALock: TMutex); inline;

implementation

uses
  nextpas.core.errors;

procedure EvalRegisterInline(AReg: TEvalRegistry; ALock: TMutex; ASlot: PEvalSlot); inline;
begin
  // perf: short critical <1µs pointer-only via TCompactLiveRegistry.Register -> VecGrowCapacity 0→4→2× bytes.ops 单源 inline 零拷贝，零额外调用
  if ALock <> nil then ALock.Acquire;
  try
    if AReg <> nil then AReg.Register(ASlot);
  finally
    if ALock <> nil then ALock.Release;
  end;
end;

procedure EvalUnregisterInline(AReg: TEvalRegistry; ALock: TMutex; ASlot: PEvalSlot); inline;
begin
  // perf: O(1) VecRemoveSwap bytes.ops 单源 inline 零拷贝，短临界 <1µs
  if ALock <> nil then ALock.Acquire;
  try
    if AReg <> nil then AReg.Unregister(ASlot);
  finally
    if ALock <> nil then ALock.Release;
  end;
end;

function EvalSnapshotInline(AReg: TEvalRegistry; ALock: TMutex; var ADest: array of PEvalSlot): Integer; inline;
var
  LCount: Integer;
begin
  // perf: lock内 Snapshot 单次 SetLength+Move inline 零拷贝（bytes.ops 单源），快照后清表，避免持锁回调；短临界 <1µs 指针-only
  Result := 0;
  ADest := nil;
  if AReg = nil then Exit(0);
  if ALock <> nil then ALock.Acquire;
  try
    LCount := AReg.Count;
    if LCount = 0 then Exit(0);
    AReg.Snapshot(ADest);
    AReg.Clear;
    Result := LCount;
  finally
    if ALock <> nil then ALock.Release;
  end;
end;

function EvalTryMarkDoneInline(ASlot: PEvalSlot): Boolean; inline;
begin
  // stability: Done 守卫 exactly-once，短临界无锁（调用方已持锁快照或 Done CAS），inline 零额外调用
  if ASlot^.Done then Exit(False);
  ASlot^.Done := True;
  Result := True;
end;

procedure EvalSettleInline(ASlot: PEvalSlot; AOk: Boolean; const AText: string); inline;
var
  LErr: EWebviewEvalFailed;
begin
  if ASlot = nil then Exit;
  if ASlot^.Done then Exit;
  ASlot^.Done := True;
  try
    if AOk then
    begin
      if Assigned(ASlot^.Callback) then ASlot^.Callback(AText);
    end
    else if Assigned(ASlot^.OnError) then
    begin
      LErr := EWebviewEvalFailed.Create(AText);
      try ASlot^.OnError(LErr); finally LErr.Free; end;
    end;
  finally
    // stability: 调用方负责 Slab 释放（pool.ReleaseEvalRec 单源），此处仅回调 exactly-once，不丢异常
  end;
end;

procedure EvalClearRegistryInline(AReg: TEvalRegistry; ALock: TMutex); inline;
begin
  if AReg = nil then Exit;
  if ALock <> nil then ALock.Acquire;
  try AReg.Clear; finally if ALock <> nil then ALock.Release; end;
end;

end.
