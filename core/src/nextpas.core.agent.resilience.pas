unit nextpas.core.agent.resilience;
{**
 * LLM 流式韧性原语（刀 82 自 code888 韧弧 K69-K75 提炼反哺——
 * 断流指纹判定 / 取消感知毫秒等待 / 重试提示钳帽）。
 *
 * 三家锚：「等待或取消」在 grok-build(tokio::select! 惯式)/
 * codex(run_until_cancelled)/opencode(Effect.sleep+interrupt) 均为
 * 一等原语；ObjFPC 无框架供给，以库函数承担并内建 ms→ns 溢出守卫与
 * nil 吸收——比手写样板更安全。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.thread,
  nextpas.core.async.cancellation,
  nextpas.core.agent.base;

{ 流中断指纹判定：deltas 中任一 sdkError 帧携带指定错误码 → True。
  典型消费=传输中断识别（aecTransport）：半截流绝不静默定稿，
  由调用方决定整轮重启或失败出口 }
function StreamHasError(const ADeltas: TStreamDeltaArray;
  ACode: TAgentErrorCode): Boolean;

{ 取消感知毫秒退避等待：先查已取消态，再等至多 ADelayMs。
  True=已取消（含进入前已取消）；False=完整等待或无需等待
  （nil 源、非正延迟、ms→ns 超界守卫跳过等待——永不因极端延迟挂死）
  F-H12 归一：首选 IAsyncCancellationToken 重载（SELECTION C10）；
  ICancellationSource 重载为历史兼容保留，后续 deprecate }
function WaitCancelMs(const AToken: IAsyncCancellationToken;
  ADelayMs: Int64): Boolean; overload;
function WaitCancelMs(const ASource: ICancellationSource;
  ADelayMs: Int64): Boolean; overload; deprecated 'use IAsyncCancellationToken overload (C10)';

{ 零 SleepMs 切片等待：以 WaitForCancel 按 CArbitrationSlice 驱动，避免 SleepMs 放大取消延迟（F-H08/F-M05）
  True=已取消，False=超时未取消；切片内部零额外 Sleep }
function WaitCancelSlice(const AToken: IAsyncCancellationToken;
  ASliceMs: Int64): Boolean;

{ 重试提示钳帽：服务端指示（Retry-After 类）与本地退避同帽收敛，
  防长窗静默冻结重试循环。负数=无提示哨兵原样透传（调用方回退
  计算退避）；正数超帽钳到 ACapMs }
function ClampHintMs(AHintMs, ACapMs: Int64): Int64;

implementation

function StreamHasError(const ADeltas: TStreamDeltaArray;
  ACode: TAgentErrorCode): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(ADeltas) do
    if (ADeltas[I].Kind = sdkError) and (ADeltas[I].Error.Code = ACode) then
      Exit(True);
end;

function WaitCancelMs(const AToken: IAsyncCancellationToken;
  ADelayMs: Int64): Boolean;
var
  LRem, LChunk: Int64;
begin
  if AToken = nil then
    Exit(False);
  if AToken.IsCancelled then
    Exit(True);
  if ADelayMs <= 0 then
    Exit(False);
  // 分片等待以保持取消响应性，单次上限 High(UInt32) ms
  LRem := ADelayMs;
  while LRem > 0 do
  begin
    if LRem > High(UInt32) then
      LChunk := High(UInt32)
    else
      LChunk := LRem;
    if AToken.WaitForCancel(UInt32(LChunk)) then
      Exit(True);
    Dec(LRem, LChunk);
    if AToken.IsCancelled then
      Exit(True);
  end;
  Result := False;
end;

function WaitCancelMs(const ASource: ICancellationSource;
  ADelayMs: Int64): Boolean;
var
  Tok: ICancellationToken;
begin
  if ASource = nil then
    Exit(False);
  Tok := ASource.Token;
  if Tok = nil then
    Exit(False);
  if Tok.IsCancelled then
    Exit(True);
  if ADelayMs <= 0 then
    Exit(False);
  { ms→ns 超界守卫：High(Int64) div 1000000 以上视为不可等待 }
  if ADelayMs > High(Int64) div 1000000 then
    Exit(False);
  Result := Tok.WaitCancellation(ADelayMs * 1000000);
end;

function WaitCancelSlice(const AToken: IAsyncCancellationToken;
  ASliceMs: Int64): Boolean;
begin
  // 零 SleepMs 切片：直接以 WaitForCancel 驱动，到点或取消即返回
  Result := WaitCancelMs(AToken, ASliceMs);
end;

function ClampHintMs(AHintMs, ACapMs: Int64): Int64;
begin
  if AHintMs < 0 then
    Exit(AHintMs);
  if AHintMs > ACapMs then
    Exit(ACapMs);
  Result := AHintMs;
end;

end.
