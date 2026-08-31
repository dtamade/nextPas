{
  nextpas.core.async.combinators.pas — WhenAll/WhenAny 组合器

  功能：
  - WhenAll: 并行执行多个回调，全部完成时触发
  - WhenAny: 并行执行多个回调，第一个完成时触发

  设计原则：
  - 使用 Loop.Post 直接调度任务（避免 TaskGroup 的上下文限制）
  - 包装用户回调以追踪完成状态
  - 回调驱动，无阻塞
}
unit nextpas.core.async.combinators;

{$mode ObjFPC}{$H+}

interface

uses
  nextpas.core.async.base,
  nextpas.core.async.loop,
  nextpas.core.async.cancellation;

type
  { 组合器选项 }
  TCombinatorOptions = record
    TimeoutMs: UInt32;       // 0 = 无超时
    CancelOnError: Boolean;  // 任一失败则取消全部
    Token: IAsyncCancellationToken; { nil = 无；cancel ≈ 超时完成 }
  end;

const
  DefaultCombinatorOptions: TCombinatorOptions = (
    TimeoutMs: 0;
    CancelOnError: False;
    Token: nil
  );

{
  WhenAll — 并行执行多个回调，全部完成时触发 AOnComplete

  参数：
    ACallbacks  — 回调数组
    AContexts   — 上下文数组（与回调一一对应）
    ACount      — 回调数量
    AOnComplete — 全部完成时的回调
    AOnCompleteCtx — 全部完成回调的上下文
    AOptions    — 组合器选项
    ALoop       — 事件循环
}
procedure WhenAll(
  ACallbacks: array of TAsyncCallback;
  AContexts: array of Pointer;
  ACount: Integer;
  AOnComplete: TAsyncCallback;
  AOnCompleteCtx: Pointer;
  const AOptions: TCombinatorOptions;
  ALoop: TAsyncLoop
);

{
  WhenAny — 并行执行多个回调，第一个完成时触发 AOnComplete

  参数：
    ACallbacks  — 回调数组
    AContexts   — 上下文数组（与回调一一对应）
    ACount      — 回调数量
    AOnComplete — 第一个完成时的回调
    AOnCompleteCtx — 完成回调的上下文
    AOptions    — 组合器选项
    ALoop       — 事件循环
}
procedure WhenAny(
  ACallbacks: array of TAsyncCallback;
  AContexts: array of Pointer;
  ACount: Integer;
  AOnComplete: TAsyncCallback;
  AOnCompleteCtx: Pointer;
  const AOptions: TCombinatorOptions;
  ALoop: TAsyncLoop
);

{
  WhenAllRef — WhenAll 的匿名方法版本

  参数：
    ACallbacks  — 匿名方法回调数组
    ACount      — 回调数量
    AOnComplete — 全部完成时的匿名方法回调
    AOptions    — 组合器选项
    ALoop       — 事件循环
}
procedure WhenAllRef(
  ACallbacks: array of TAsyncCallbackRef;
  ACount: Integer;
  AOnComplete: TAsyncCallbackRef;
  const AOptions: TCombinatorOptions;
  ALoop: TAsyncLoop
);

{
  WhenAnyRef — WhenAny 的匿名方法版本

  参数：
    ACallbacks  — 匿名方法回调数组
    ACount      — 回调数量
    AOnComplete — 第一个完成时的匿名方法回调
    AOptions    — 组合器选项
    ALoop       — 事件循环
}
procedure WhenAnyRef(
  ACallbacks: array of TAsyncCallbackRef;
  ACount: Integer;
  AOnComplete: TAsyncCallbackRef;
  const AOptions: TCombinatorOptions;
  ALoop: TAsyncLoop
);

implementation

uses
  nextpas.core.atomic,
  nextpas.core.time.base;

type

  { 包装回调的上下文 }
  PWrappedContext = ^TWrappedContext;
  TWrappedContext = record
    UserCallback: TAsyncCallback;
    UserRef: TAsyncCallbackRef;
    UserCtx: Pointer;
    State: Pointer;  // 指向 WhenAllState 或 WhenAnyState
    IsWhenAll: Boolean;
  end;

  { WhenAll 状态 }
  PWhenAllState = ^TWhenAllState;
  TWhenAllState = record
    Remaining: Integer;
    RefCount: Integer;       // base + timer? + token?
    Finished: Int32;         // 0 pending; 1 completed
    TimedOut: Boolean;
    TokenOwner: Int32;       // 1 while token holds a RefCount
    OnComplete: TAsyncCallback;
    OnCompleteRef: TAsyncCallbackRef;
    OnCompleteCtx: Pointer;
    Loop: TAsyncLoop;
    TimeoutMs: UInt32;
    TimerHandle: TAsyncTimerHandle;
    Token: IAsyncCancellationToken;
  end;

  { WhenAny 状态 }
  PWhenAnyState = ^TWhenAnyState;
  TWhenAnyState = record
    Done: Boolean;
    Finished: Int32;
    TokenOwner: Int32;
    RefCount: Int32;  { base + optional post pin for token abort }
    OnComplete: TAsyncCallback;
    OnCompleteRef: TAsyncCallbackRef;
    OnCompleteCtx: Pointer;
    Loop: TAsyncLoop;
    Remaining: Integer;
    Token: IAsyncCancellationToken;
  end;

procedure WhenAllReleaseTokenOwner(var AState: PWhenAllState); forward;

procedure DiscardWrappedContext(AContext: Pointer);
var
  LWrapped: PWrappedContext;
  LAll: PWhenAllState;
  LAny: PWhenAnyState;
  LTmp: PWhenAllState;
begin
  LWrapped := PWrappedContext(AContext);
  if LWrapped = nil then
    Exit;
  if LWrapped^.IsWhenAll then
  begin
    LAll := PWhenAllState(LWrapped^.State);
    Dispose(LWrapped);
    if LAll = nil then
      Exit;
    Dec(LAll^.Remaining);
    if LAll^.Remaining <= 0 then
    begin
      { Close discard: release TokenOwner if held, then base ref.
        Timer ownership is dropped separately by DiscardWhenAllTimeoutState. }
      LTmp := LAll;
      WhenAllReleaseTokenOwner(LTmp);
      LAll := LTmp;
      if LAll = nil then
        Exit;
      if atomic_fetch_sub(LAll^.RefCount, 1, mo_acq_rel) = 1 then
        Dispose(LAll);
    end;
  end
  else
  begin
    LAny := PWhenAnyState(LWrapped^.State);
    Dispose(LWrapped);
    if LAny = nil then
      Exit;
    Dec(LAny^.Remaining);
    if LAny^.Remaining <= 0 then
      Dispose(LAny);
  end;
end;

procedure DiscardWhenAllTimeoutState(AContext: Pointer);
var
  LState: PWhenAllState;
begin
  LState := PWhenAllState(AContext);
  if LState = nil then
    Exit;
  { Timer was discarded without firing. Drop timer ownership only. }
  if atomic_fetch_sub(LState^.RefCount, 1, mo_acq_rel) = 1 then
    Dispose(LState);
end;

{ ==================== WhenAll ==================== }

function WhenAllClaimFinish(AState: PWhenAllState): Boolean;
var
  LExpected: Int32;
begin
  LExpected := 0;
  Result := atomic_compare_exchange_strong(AState^.Finished, LExpected, 1, mo_acq_rel, mo_acquire);
end;

procedure WhenAllFireComplete(AState: PWhenAllState);
begin
  if Assigned(AState^.OnComplete) then
    AState^.OnComplete(AState^.OnCompleteCtx)
  else if Assigned(AState^.OnCompleteRef) then
    AState^.OnCompleteRef(AState^.OnCompleteCtx);
end;

procedure WhenAllReleaseTokenOwner(var AState: PWhenAllState);
begin
  if AState = nil then
    Exit;
  if atomic_exchange(AState^.TokenOwner, 0, mo_acq_rel) = 1 then
  begin
    AState^.Token := nil;
    if atomic_fetch_sub(AState^.RefCount, 1, mo_acq_rel) = 1 then
    begin
      Dispose(AState);
      AState := nil;
    end;
  end
  else
    AState^.Token := nil;
end;

procedure WhenAllReleaseTimerOwner(var AState: PWhenAllState);
begin
  if AState = nil then
    Exit;
  if AState^.TimeoutMs = 0 then
    Exit;
  if not AState^.TimerHandle.IsValid then
    Exit;
  if AState^.Loop.CancelTimer(AState^.TimerHandle) then
  begin
    AState^.TimerHandle := TAsyncTimerHandle.None;
    if atomic_fetch_sub(AState^.RefCount, 1, mo_acq_rel) = 1 then
    begin
      Dispose(AState);
      AState := nil;
    end;
  end;
end;

procedure WhenAllReleaseOne(var AState: PWhenAllState);
begin
  if AState = nil then
    Exit;
  if atomic_fetch_sub(AState^.RefCount, 1, mo_acq_rel) = 1 then
  begin
    Dispose(AState);
    AState := nil;
  end;
end;

{ WhenAll 任务完成回调 }
procedure WhenAllTaskDone(AContext: Pointer);
var
  LWrapped: PWrappedContext;
  LState: PWhenAllState;
begin
  LWrapped := PWrappedContext(AContext);
  LState := PWhenAllState(LWrapped^.State);

  if not LState^.TimedOut then
  begin
    if Assigned(LWrapped^.UserCallback) then
      LWrapped^.UserCallback(LWrapped^.UserCtx)
    else if Assigned(LWrapped^.UserRef) then
      LWrapped^.UserRef(LWrapped^.UserCtx);
  end;

  Dispose(LWrapped);
  Dec(LState^.Remaining);

  if LState^.Remaining <= 0 then
  begin
    WhenAllReleaseTimerOwner(LState);
    if LState = nil then
      Exit;
    WhenAllReleaseTokenOwner(LState);
    if LState = nil then
      Exit;

    if WhenAllClaimFinish(LState) then
    begin
      if not LState^.TimedOut then
        WhenAllFireComplete(LState);
    end;

    WhenAllReleaseOne(LState);
  end;
end;

{ Timer path: releases the timer ownership ref }
procedure WhenAllTimerAbort(AContext: Pointer);
var
  LState: PWhenAllState;
begin
  LState := PWhenAllState(AContext);
  if LState = nil then
    Exit;

  LState^.TimedOut := True;
  LState^.TimerHandle := TAsyncTimerHandle.None;
  if WhenAllClaimFinish(LState) then
    WhenAllFireComplete(LState);

  WhenAllReleaseTokenOwner(LState);
  if LState = nil then
    Exit;
  WhenAllReleaseOne(LState);
end;

{ Token path: releases TokenOwner ref }
procedure WhenAllTokenAbort(AContext: Pointer);
var
  LState: PWhenAllState;
begin
  LState := PWhenAllState(AContext);
  if LState = nil then
    Exit;
  try
    LState^.TimedOut := True;
    if WhenAllClaimFinish(LState) then
    begin
      WhenAllReleaseTimerOwner(LState);
      if LState <> nil then
        WhenAllFireComplete(LState);
    end
    else
      WhenAllReleaseTimerOwner(LState);
    if LState <> nil then
      WhenAllReleaseTokenOwner(LState);
  finally
    if LState <> nil then
      WhenAllReleaseOne(LState); { drop Post pin from TokenNotify }
  end;
end;

procedure WhenAllTokenNotify(AContext: Pointer);
var
  LState: PWhenAllState;
begin
  LState := PWhenAllState(AContext);
  if (LState = nil) or (LState^.Loop = nil) then
    Exit;
  if atomic_load(LState^.TokenOwner, mo_acquire) = 0 then
    Exit;
  if atomic_load(LState^.Finished, mo_acquire) <> 0 then
    Exit;
  atomic_fetch_add(LState^.RefCount, 1, mo_acq_rel);
  LState^.Loop.Post(@WhenAllTokenAbort, LState);
end;

procedure WhenAllBindToken(AState: PWhenAllState; AToken: IAsyncCancellationToken);
begin
  if AToken = nil then
    Exit;
  AState^.Token := AToken;
  atomic_store(AState^.TokenOwner, 1, mo_release);
  atomic_fetch_add(AState^.RefCount, 1, mo_acq_rel);
  AToken.OnCancel(@WhenAllTokenNotify, AState);
end;

procedure WhenAll(
  ACallbacks: array of TAsyncCallback;
  AContexts: array of Pointer;
  ACount: Integer;
  AOnComplete: TAsyncCallback;
  AOnCompleteCtx: Pointer;
  const AOptions: TCombinatorOptions;
  ALoop: TAsyncLoop
);
var
  LState: PWhenAllState;
  LWrapped: PWrappedContext;
  LLoop: TAsyncLoop;
  I: Integer;
begin
  LLoop := ALoop;
  if ACount <= 0 then
  begin
    if Assigned(AOnComplete) then
      AOnComplete(AOnCompleteCtx);
    Exit;
  end;

  New(LState);
  FillChar(LState^, SizeOf(LState^), 0);
  LState^.Remaining := ACount;
  LState^.RefCount := 1;
  LState^.Finished := 0;
  LState^.TimedOut := False;
  LState^.TokenOwner := 0;
  LState^.OnComplete := AOnComplete;
  LState^.OnCompleteRef := nil;
  LState^.OnCompleteCtx := AOnCompleteCtx;
  LState^.Loop := LLoop;
  LState^.TimeoutMs := AOptions.TimeoutMs;

  if AOptions.TimeoutMs > 0 then
  begin
    Inc(LState^.RefCount);
    LState^.TimerHandle := LLoop.ScheduleEx(
      TDuration.FromMilliseconds(AOptions.TimeoutMs),
      @WhenAllTimerAbort,
      LState,
      @DiscardWhenAllTimeoutState
    );
  end;

  WhenAllBindToken(LState, AOptions.Token);

  for I := 0 to ACount - 1 do
  begin
    New(LWrapped);
    LWrapped^.UserCallback := ACallbacks[I];
    LWrapped^.UserRef := nil;
    LWrapped^.UserCtx := AContexts[I];
    LWrapped^.State := LState;
    LWrapped^.IsWhenAll := True;

    LLoop.PostEx(@WhenAllTaskDone, LWrapped, @DiscardWrappedContext);
  end;
end;

{ ==================== WhenAllRef ==================== }

procedure WhenAllRef(
  ACallbacks: array of TAsyncCallbackRef;
  ACount: Integer;
  AOnComplete: TAsyncCallbackRef;
  const AOptions: TCombinatorOptions;
  ALoop: TAsyncLoop
);
var
  LState: PWhenAllState;
  LWrapped: PWrappedContext;
  LLoop: TAsyncLoop;
  I: Integer;
begin
  LLoop := ALoop;
  if ACount <= 0 then
  begin
    if Assigned(AOnComplete) then
      AOnComplete(nil);
    Exit;
  end;

  New(LState);
  FillChar(LState^, SizeOf(LState^), 0);
  LState^.Remaining := ACount;
  LState^.RefCount := 1;
  LState^.Finished := 0;
  LState^.TimedOut := False;
  LState^.TokenOwner := 0;
  LState^.OnComplete := nil;
  LState^.OnCompleteRef := AOnComplete;
  LState^.OnCompleteCtx := nil;
  LState^.Loop := LLoop;
  LState^.TimeoutMs := AOptions.TimeoutMs;

  if AOptions.TimeoutMs > 0 then
  begin
    Inc(LState^.RefCount);
    LState^.TimerHandle := LLoop.ScheduleEx(
      TDuration.FromMilliseconds(AOptions.TimeoutMs),
      @WhenAllTimerAbort,
      LState,
      @DiscardWhenAllTimeoutState
    );
  end;

  WhenAllBindToken(LState, AOptions.Token);

  for I := 0 to ACount - 1 do
  begin
    New(LWrapped);
    LWrapped^.UserCallback := nil;
    LWrapped^.UserRef := ACallbacks[I];
    LWrapped^.UserCtx := nil;
    LWrapped^.State := LState;
    LWrapped^.IsWhenAll := True;

    LLoop.PostEx(@WhenAllTaskDone, LWrapped, @DiscardWrappedContext);
  end;
end;

{ ==================== WhenAny ==================== }

function WhenAnyClaimFinish(AState: PWhenAnyState): Boolean;
var
  LExpected: Int32;
begin
  LExpected := 0;
  Result := atomic_compare_exchange_strong(AState^.Finished, LExpected, 1, mo_acq_rel, mo_acquire);
end;

procedure WhenAnyFireComplete(AState: PWhenAnyState);
begin
  if Assigned(AState^.OnComplete) then
    AState^.OnComplete(AState^.OnCompleteCtx)
  else if Assigned(AState^.OnCompleteRef) then
    AState^.OnCompleteRef(AState^.OnCompleteCtx);
end;

procedure WhenAnyReleaseToken(AState: PWhenAnyState);
begin
  if AState = nil then
    Exit;
  if atomic_exchange(AState^.TokenOwner, 0, mo_acq_rel) = 1 then
    AState^.Token := nil
  else
    AState^.Token := nil;
end;

procedure WhenAnyTokenAbort(AContext: Pointer);
var
  LState: PWhenAnyState;
begin
  LState := PWhenAnyState(AContext);
  if LState = nil then
    Exit;
  try
    if WhenAnyClaimFinish(LState) then
    begin
      LState^.Done := True;
      WhenAnyFireComplete(LState);
    end;
    WhenAnyReleaseToken(LState);
  finally
    if atomic_fetch_sub(LState^.RefCount, 1, mo_acq_rel) = 1 then
      Dispose(LState);
  end;
end;

procedure WhenAnyTokenNotify(AContext: Pointer);
var
  LState: PWhenAnyState;
begin
  LState := PWhenAnyState(AContext);
  if (LState = nil) or (LState^.Loop = nil) then
    Exit;
  if atomic_load(LState^.TokenOwner, mo_acquire) = 0 then
    Exit;
  if atomic_load(LState^.Finished, mo_acquire) <> 0 then
    Exit;
  atomic_fetch_add(LState^.RefCount, 1, mo_acq_rel);
  LState^.Loop.Post(@WhenAnyTokenAbort, LState);
end;

procedure WhenAnyBindToken(AState: PWhenAnyState; AToken: IAsyncCancellationToken);
begin
  if AToken = nil then
    Exit;
  AState^.Token := AToken;
  atomic_store(AState^.TokenOwner, 1, mo_release);
  AToken.OnCancel(@WhenAnyTokenNotify, AState);
end;

procedure WhenAnyTaskDone(AContext: Pointer);
var
  LWrapped: PWrappedContext;
  LState: PWhenAnyState;
begin
  LWrapped := PWrappedContext(AContext);
  LState := PWhenAnyState(LWrapped^.State);

  if Assigned(LWrapped^.UserCallback) then
    LWrapped^.UserCallback(LWrapped^.UserCtx)
  else if Assigned(LWrapped^.UserRef) then
    LWrapped^.UserRef(LWrapped^.UserCtx);

  if WhenAnyClaimFinish(LState) then
  begin
    LState^.Done := True;
    WhenAnyReleaseToken(LState);
    WhenAnyFireComplete(LState);
  end;

  Dec(LState^.Remaining);
  if LState^.Remaining <= 0 then
  begin
    WhenAnyReleaseToken(LState);
    if atomic_fetch_sub(LState^.RefCount, 1, mo_acq_rel) = 1 then
      Dispose(LState);
  end;

  Dispose(LWrapped);
end;

procedure WhenAny(
  ACallbacks: array of TAsyncCallback;
  AContexts: array of Pointer;
  ACount: Integer;
  AOnComplete: TAsyncCallback;
  AOnCompleteCtx: Pointer;
  const AOptions: TCombinatorOptions;
  ALoop: TAsyncLoop
);
var
  LState: PWhenAnyState;
  LWrapped: PWrappedContext;
  LLoop: TAsyncLoop;
  I: Integer;
begin
  LLoop := ALoop;
  if ACount <= 0 then
  begin
    if Assigned(AOnComplete) then
      AOnComplete(AOnCompleteCtx);
    Exit;
  end;

  New(LState);
  FillChar(LState^, SizeOf(LState^), 0);
  LState^.Done := False;
  LState^.Finished := 0;
  LState^.TokenOwner := 0;
  LState^.RefCount := 1;
  LState^.OnComplete := AOnComplete;
  LState^.OnCompleteRef := nil;
  LState^.OnCompleteCtx := AOnCompleteCtx;
  LState^.Loop := LLoop;
  LState^.Remaining := ACount;
  WhenAnyBindToken(LState, AOptions.Token);

  for I := 0 to ACount - 1 do
  begin
    New(LWrapped);
    LWrapped^.UserCallback := ACallbacks[I];
    LWrapped^.UserRef := nil;
    LWrapped^.UserCtx := AContexts[I];
    LWrapped^.State := LState;
    LWrapped^.IsWhenAll := False;
    LLoop.PostEx(@WhenAnyTaskDone, LWrapped, @DiscardWrappedContext);
  end;
end;

{ ==================== WhenAnyRef ==================== }

procedure WhenAnyRef(
  ACallbacks: array of TAsyncCallbackRef;
  ACount: Integer;
  AOnComplete: TAsyncCallbackRef;
  const AOptions: TCombinatorOptions;
  ALoop: TAsyncLoop
);
var
  LState: PWhenAnyState;
  LWrapped: PWrappedContext;
  LLoop: TAsyncLoop;
  I: Integer;
begin
  LLoop := ALoop;
  if ACount <= 0 then
  begin
    if Assigned(AOnComplete) then
      AOnComplete(nil);
    Exit;
  end;

  New(LState);
  FillChar(LState^, SizeOf(LState^), 0);
  LState^.Done := False;
  LState^.Finished := 0;
  LState^.TokenOwner := 0;
  LState^.RefCount := 1;
  LState^.OnComplete := nil;
  LState^.OnCompleteRef := AOnComplete;
  LState^.OnCompleteCtx := nil;
  LState^.Loop := LLoop;
  LState^.Remaining := ACount;
  WhenAnyBindToken(LState, AOptions.Token);

  for I := 0 to ACount - 1 do
  begin
    New(LWrapped);
    LWrapped^.UserCallback := nil;
    LWrapped^.UserRef := ACallbacks[I];
    LWrapped^.UserCtx := nil;
    LWrapped^.State := LState;
    LWrapped^.IsWhenAll := False;
    LLoop.PostEx(@WhenAnyTaskDone, LWrapped, @DiscardWrappedContext);
  end;
end;

end.
