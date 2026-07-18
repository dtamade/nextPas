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
  nextpas.core.async.loop;

type
  { 组合器选项 }
  TCombinatorOptions = record
    TimeoutMs: UInt32;       // 0 = 无超时
    CancelOnError: Boolean;  // 任一失败则取消全部
  end;

const
  DefaultCombinatorOptions: TCombinatorOptions = (
    TimeoutMs: 0;
    CancelOnError: False;
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
    RefCount: Integer;       // 引用计数：每个任务 +1，定时器 +1
    TimedOut: Boolean;       // 超时后设置
    OnComplete: TAsyncCallback;
    OnCompleteRef: TAsyncCallbackRef;
    OnCompleteCtx: Pointer;
    Loop: TAsyncLoop;
    TimeoutMs: UInt32;
    TimerHandle: TAsyncTimerHandle;
  end;

  { WhenAny 状态 }
  PWhenAnyState = ^TWhenAnyState;
  TWhenAnyState = record
    Done: Boolean;
    OnComplete: TAsyncCallback;
    OnCompleteRef: TAsyncCallbackRef;
    OnCompleteCtx: Pointer;
    Loop: TAsyncLoop;
    Remaining: Integer;  // 跟踪剩余任务数
  end;

procedure DiscardWrappedContext(AContext: Pointer);
var
  LWrapped: PWrappedContext;
  LAll: PWhenAllState;
  LAny: PWhenAnyState;
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
      { Do not CancelTimer here: Close is already tearing down the loop.
        Timer OnDiscard drops the timer ownership ref safely. }
      if AtomicFetchSub32(LAll^.RefCount, 1, moAcqRel) = 1 then
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
  if AtomicFetchSub32(LState^.RefCount, 1, moAcqRel) = 1 then
    Dispose(LState);
end;

{ ==================== WhenAll ==================== }

{ WhenAll 任务完成回调 }
procedure WhenAllTaskDone(AContext: Pointer);
var
  LWrapped: PWrappedContext;
  LState: PWhenAllState;
begin
  LWrapped := PWrappedContext(AContext);
  LState := PWhenAllState(LWrapped^.State);

  { 超时后不执行用户回调 }
  if not LState^.TimedOut then
  begin
    if Assigned(LWrapped^.UserCallback) then
      LWrapped^.UserCallback(LWrapped^.UserCtx)
    else if Assigned(LWrapped^.UserRef) then
      LWrapped^.UserRef(LWrapped^.UserCtx);
  end;

  Dispose(LWrapped);

  { 减少剩余计数 }
  Dec(LState^.Remaining);

  { 检查是否全部完成 }
  if LState^.Remaining <= 0 then
  begin
    if (LState^.TimeoutMs > 0) and not LState^.TimedOut then
    begin
      { Cancel abandons timer without OnDiscard; drop timer ownership here. }
      LState^.Loop.CancelTimer(LState^.TimerHandle);
      if AtomicFetchSub32(LState^.RefCount, 1, moAcqRel) = 1 then
      begin
        Dispose(LState);
        Exit;
      end;
    end;

    if not LState^.TimedOut then
    begin
      if Assigned(LState^.OnComplete) then
        LState^.OnComplete(LState^.OnCompleteCtx)
      else if Assigned(LState^.OnCompleteRef) then
        LState^.OnCompleteRef(LState^.OnCompleteCtx);
    end;

    if AtomicFetchSub32(LState^.RefCount, 1, moAcqRel) = 1 then
      Dispose(LState);
  end;
end;

{ WhenAll 超时回调 }
procedure WhenAllTimeoutCallback(AContext: Pointer);
var
  LState: PWhenAllState;
begin
  LState := PWhenAllState(AContext);

  { 标记为已超时 }
  LState^.TimedOut := True;

  { 触发完成回调 }
  if Assigned(LState^.OnComplete) then
    LState^.OnComplete(LState^.OnCompleteCtx)
  else if Assigned(LState^.OnCompleteRef) then
    LState^.OnCompleteRef(LState^.OnCompleteCtx);

  { 释放引用 }
  if AtomicFetchSub32(LState^.RefCount, 1, moAcqRel) = 1 then
    Dispose(LState);
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
  // 空数组直接完成
  if ACount <= 0 then
  begin
    if Assigned(AOnComplete) then
      AOnComplete(AOnCompleteCtx);
    Exit;
  end;

  // 创建状态
  New(LState);
  LState^.Remaining := ACount;
  LState^.RefCount := 1;  // 基础引用
  LState^.TimedOut := False;
  LState^.OnComplete := AOnComplete;
  LState^.OnCompleteRef := nil;
  LState^.OnCompleteCtx := AOnCompleteCtx;
  LState^.Loop := LLoop;
  LState^.TimeoutMs := AOptions.TimeoutMs;

  // 设置超时定时器
  if AOptions.TimeoutMs > 0 then
  begin
    Inc(LState^.RefCount);  // 定时器持有引用
    LState^.TimerHandle := LLoop.ScheduleEx(
      TDuration.FromMilliseconds(AOptions.TimeoutMs),
      @WhenAllTimeoutCallback,
      LState,
      @DiscardWhenAllTimeoutState
    );
  end;

  // 添加所有任务（使用包装回调）
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
  LState^.Remaining := ACount;
  LState^.RefCount := 1;
  LState^.TimedOut := False;
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
      @WhenAllTimeoutCallback,
      LState,
      @DiscardWhenAllTimeoutState
    );
  end;

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

{ WhenAny 任务完成回调 }
procedure WhenAnyTaskDone(AContext: Pointer);
var
  LWrapped: PWrappedContext;
  LState: PWhenAnyState;
begin
  LWrapped := PWrappedContext(AContext);
  LState := PWhenAnyState(LWrapped^.State);

  { 执行用户回调 }
  if Assigned(LWrapped^.UserCallback) then
    LWrapped^.UserCallback(LWrapped^.UserCtx)
  else if Assigned(LWrapped^.UserRef) then
    LWrapped^.UserRef(LWrapped^.UserCtx);

  { 第一个完成的任务触发完成回调 }
  if not LState^.Done then
  begin
    LState^.Done := True;
    if Assigned(LState^.OnComplete) then
      LState^.OnComplete(LState^.OnCompleteCtx)
    else if Assigned(LState^.OnCompleteRef) then
      LState^.OnCompleteRef(LState^.OnCompleteCtx);
  end;

  { 减少剩余计数 }
  Dec(LState^.Remaining);

  { 最后一个任务清理状态 }
  if LState^.Remaining <= 0 then
    Dispose(LState);

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
  // 空数组直接完成
  if ACount <= 0 then
  begin
    if Assigned(AOnComplete) then
      AOnComplete(AOnCompleteCtx);
    Exit;
  end;

  // 创建状态
  New(LState);
  LState^.Done := False;
  LState^.OnComplete := AOnComplete;
  LState^.OnCompleteRef := nil;
  LState^.OnCompleteCtx := AOnCompleteCtx;
  LState^.Loop := LLoop;
  LState^.Remaining := ACount;

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
  LState^.Done := False;
  LState^.OnComplete := nil;
  LState^.OnCompleteRef := AOnComplete;
  LState^.OnCompleteCtx := nil;
  LState^.Loop := LLoop;
  LState^.Remaining := ACount;

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
