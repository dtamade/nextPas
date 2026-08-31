{
  nextpas.core.async.retry.pas — 异步重试机制

  功能：
  - RetryWithBackoff: 指数退避重试
  - RetryWithFixedDelay: 固定延迟重试
  - 支持最大重试次数、最大延迟、退避因子

  设计原则：
  - 回调驱动，无阻塞
  - 使用定时器实现延迟
  - 状态封装在堆分配记录中
}
unit nextpas.core.async.retry;

{$mode ObjFPC}{$H+}

interface

uses
  nextpas.core.async.base,
  nextpas.core.async.loop;

type
  { 重试结果 }
  TAsyncRetryResult = (
    arrSuccess,      // 成功
    arrMaxRetries,   // 达到最大重试次数
    arrCancelled     // 被取消
  );

  { 重试选项 }
  TAsyncRetryOptions = record
    MaxRetries: Integer;       // 最大重试次数 (0 = 无限)
    BaseDelayMs: UInt32;       // 基础延迟 (毫秒)
    MaxDelayMs: UInt32;        // 最大延迟 (毫秒)
    BackoffFactor: UInt32;     // 退避因子 (默认 2)
  end;

const
  DefaultRetryOptions: TAsyncRetryOptions = (
    MaxRetries: 3;
    BaseDelayMs: 100;
    MaxDelayMs: 5000;
    BackoffFactor: 2;
  );

{
  RetryWithBackoff — 指数退避重试

  如果回调执行失败（通过 AOnError 判断），则延迟后重试。
  直到成功或达到最大重试次数。

  参数：
    ACallback    — 要重试的回调
    AContext     — 回调上下文
    AOnError     — 判断是否失败的回调（返回 True 表示失败）
    AOnErrorCtx  — 错误判断回调的上下文
    AOnComplete  — 成功或最终失败时的回调
    AOnCompleteCtx — 完成回调的上下文
    AOptions     — 重试选项
    ALoop        — 事件循环

  用法：
    procedure MyOperation(AContext: Pointer);
    begin
      // 执行可能失败的操作
    end;

    procedure CheckError(AContext: Pointer);
    begin
      // 检查是否失败
      // 如果失败，设置标志位
    end;

    procedure OnRetryComplete(AContext: Pointer);
    begin
      // 重试完成（成功或达到最大次数）
    end;

    RetryWithBackoff(
      @MyOperation, MyData,
      @CheckError, ErrorData,
      @OnRetryComplete, nil,
      DefaultRetryOptions, @Loop
    );
}
procedure RetryWithBackoff(
  ACallback: TAsyncCallback;
  AContext: Pointer;
  AOnError: TAsyncCallback;
  AOnErrorCtx: Pointer;
  AOnComplete: TAsyncCallback;
  AOnCompleteCtx: Pointer;
  const AOptions: TAsyncRetryOptions;
  ALoop: TAsyncLoop
);

{
  RetryWithFixedDelay — 固定延迟重试

  如果回调执行失败，则固定延迟后重试。

  参数：
    ACallback    — 要重试的回调
    AContext     — 回调上下文
    AOnError     — 判断是否失败的回调
    AOnErrorCtx  — 错误判断回调的上下文
    AOnComplete  — 成功或最终失败时的回调
    AOnCompleteCtx — 完成回调的上下文
    AMaxRetries  — 最大重试次数
    ADelayMs     — 固定延迟 (毫秒)
    ALoop        — 事件循环
}
procedure RetryWithFixedDelay(
  ACallback: TAsyncCallback;
  AContext: Pointer;
  AOnError: TAsyncCallback;
  AOnErrorCtx: Pointer;
  AOnComplete: TAsyncCallback;
  AOnCompleteCtx: Pointer;
  AMaxRetries: Integer;
  ADelayMs: UInt32;
  ALoop: TAsyncLoop
);

implementation

uses
  nextpas.core.atomic,
  nextpas.core.time.base;

type

  { 重试状态 }
  PRetryState = ^TRetryState;
  TRetryState = record
    Callback: TAsyncCallback;
    Context: Pointer;
    OnError: TAsyncCallback;
    OnErrorCtx: Pointer;
    OnComplete: TAsyncCallback;
    OnCompleteCtx: Pointer;
    Options: TAsyncRetryOptions;
    Loop: TAsyncLoop;
    CurrentRetry: Integer;
    CurrentDelayMs: UInt32;
    Failed: Boolean;
    Done: Int32;
  end;

{ ==================== 重试逻辑 ==================== }

procedure DiscardRetryState(AContext: Pointer);
var
  LState: PRetryState;
  LExpected: Int32;
begin
  if AContext = nil then
    Exit;
  LState := PRetryState(AContext);
  LExpected := 0;
  if not atomic_compare_exchange_strong(LState^.Done, LExpected, 1, mo_acq_rel, mo_acquire) then
    Exit;
  Dispose(LState);
end;

function RetryStateClaimDone(AState: PRetryState): Boolean;
var
  LExpected: Int32;
begin
  LExpected := 0;
  Result := atomic_compare_exchange_strong(AState^.Done, LExpected, 1, mo_acq_rel, mo_acquire);
end;

{ 统一的重试执行步骤（首次和后续重试共用） }
procedure RetryExecuteStep(AContext: Pointer);
var
  LState: PRetryState;
begin
  LState := PRetryState(AContext);
  if LState = nil then
    Exit;
  if LState^.Done <> 0 then
    Exit;
  { 执行回调 }
  LState^.Callback(LState^.Context);
  { 检查是否失败 }
  if Assigned(LState^.OnError) then
  begin
    LState^.Failed := False;
    LState^.OnError(LState^.OnErrorCtx);
    if LState^.Failed then
    begin
      { 失败，检查是否需要重试 }
      if (LState^.Options.MaxRetries > 0) and
         (LState^.CurrentRetry >= LState^.Options.MaxRetries) then
      begin
        if RetryStateClaimDone(LState) then
        begin
          if Assigned(LState^.OnComplete) then
            LState^.OnComplete(LState^.OnCompleteCtx);
          Dispose(LState);
        end;
        Exit;
      end;
      { 用当前延迟调度下一次重试 }
      Inc(LState^.CurrentRetry);
      try
        LState^.Loop.ScheduleEx(
          TDuration.FromMilliseconds(LState^.CurrentDelayMs),
          @RetryExecuteStep,
          LState,
          @DiscardRetryState
        );
      except
        if RetryStateClaimDone(LState) then
          Dispose(LState);
        Exit;
      end;
      { 更新延迟供下次使用（在 schedule 之后，不影响本次调度） }
      LState^.CurrentDelayMs := LState^.CurrentDelayMs * LState^.Options.BackoffFactor;
      if LState^.CurrentDelayMs > LState^.Options.MaxDelayMs then
        LState^.CurrentDelayMs := LState^.Options.MaxDelayMs;
    end
    else
    begin
      if RetryStateClaimDone(LState) then
      begin
        if Assigned(LState^.OnComplete) then
          LState^.OnComplete(LState^.OnCompleteCtx);
        Dispose(LState);
      end;
    end;
  end
  else
  begin
    if RetryStateClaimDone(LState) then
    begin
      if Assigned(LState^.OnComplete) then
        LState^.OnComplete(LState^.OnCompleteCtx);
      Dispose(LState);
    end;
  end;
end;

{ ==================== 公共 API ==================== }

procedure RetryWithBackoff(
  ACallback: TAsyncCallback;
  AContext: Pointer;
  AOnError: TAsyncCallback;
  AOnErrorCtx: Pointer;
  AOnComplete: TAsyncCallback;
  AOnCompleteCtx: Pointer;
  const AOptions: TAsyncRetryOptions;
  ALoop: TAsyncLoop
);
var
  LState: PRetryState;
  LLoop: TAsyncLoop;
begin
  LLoop := ALoop;
  // 创建状态
  New(LState);
  LState^.Callback := ACallback;
  LState^.Context := AContext;
  LState^.OnError := AOnError;
  LState^.OnErrorCtx := AOnErrorCtx;
  LState^.OnComplete := AOnComplete;
  LState^.OnCompleteCtx := AOnCompleteCtx;
  LState^.Options := AOptions;
  LState^.Loop := LLoop;
  LState^.CurrentRetry := 0;
  LState^.CurrentDelayMs := AOptions.BaseDelayMs;
  LState^.Failed := False;
  LState^.Done := 0;

  // 立即执行第一次尝试
  LLoop.PostEx(@RetryExecuteStep, LState, @DiscardRetryState);
end;

procedure RetryWithFixedDelay(
  ACallback: TAsyncCallback;
  AContext: Pointer;
  AOnError: TAsyncCallback;
  AOnErrorCtx: Pointer;
  AOnComplete: TAsyncCallback;
  AOnCompleteCtx: Pointer;
  AMaxRetries: Integer;
  ADelayMs: UInt32;
  ALoop: TAsyncLoop
);
var
  LOptions: TAsyncRetryOptions;
begin
  LOptions.MaxRetries := AMaxRetries;
  LOptions.BaseDelayMs := ADelayMs;
  LOptions.MaxDelayMs := ADelayMs;
  LOptions.BackoffFactor := 1;
  RetryWithBackoff(
    ACallback, AContext,
    AOnError, AOnErrorCtx,
    AOnComplete, AOnCompleteCtx,
    LOptions, ALoop
  );
end;

end.
