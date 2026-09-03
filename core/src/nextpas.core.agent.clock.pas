{**
 * nextpas.core.agent.clock - IAgentClock 实现：真实时钟与测试时钟。
 *
 * 契约权威：core/docs/agent/API.md §3 构造入口。选型见 SELECTION C8。
 *}

unit nextpas.core.agent.clock;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.stopwatch,
  nextpas.core.time.sleep,
  nextpas.core.async.cancellation,
  nextpas.core.agent.intf;

{ 真实时钟；SleepMs 底层 WaitForCancel（可被令牌打断）}
function NewSystemClock: IAgentClock; inline;

type
  { 测试时钟：SleepMs 记录请睡时长并立即返回（令牌已取消则返回 False）；
    虚拟时间只经 Advance 推进，配合 WithRetry 实现零睡眠退避断言。
    非线程安全——单线程测试场景专用 }
  TFakeClock = class(TInterfacedObject, IAgentClock)
  private
    FVirtualNowMs: Int64;
    FLastSleepRequestMs: Int64;
    FRandState: UInt64;
  public
    constructor Create;
    procedure Advance(AMs: Int64);        { 推进虚拟时钟 }
    function VirtualNowMs: Int64;
    function LastSleepRequestMs: Int64;   { 最近一次被请求的睡眠时长 }
    function NowMs: Int64;
    function SleepMs(AMs: Int64;
      const AToken: IAsyncCancellationToken): Boolean;
    function RandomU64: UInt64;
  end;

implementation

uses
  nextpas.core.time.base,
  nextpas.core.platform.random;

type
  TSystemClock = class(TInterfacedObject, IAgentClock)
  private
    FStopwatch: TStopwatch;              { 单调源；构造时启动 }
  public
    constructor Create; reintroduce;
    function NowMs: Int64;
    function SleepMs(AMs: Int64;
      const AToken: IAsyncCancellationToken): Boolean;
    function RandomU64: UInt64;
  end;

function NewSystemClock: IAgentClock;
begin
  Result := TSystemClock.Create;
end;

constructor TSystemClock.Create;
begin
  inherited Create;
  FStopwatch := TStopwatch.StartNew;
end;

function TSystemClock.NowMs: Int64;
begin
  Result := FStopwatch.ElapsedMs;
end;

function TSystemClock.SleepMs(AMs: Int64;
  const AToken: IAsyncCancellationToken): Boolean;
var
  LRemaining: Int64;
  LChunk: Int64;
begin
  if AToken = nil then
  begin
    TSleep.ForDuration(TDuration.FromMilliseconds(AMs));
    Exit(True);
  end;
  if AMs <= 0 then
    Exit(not AToken.IsCancelled);      { 零睡：仅报告取消状态 }
  { WaitForCancel 返回 True=期间被取消；UInt32 域上限分片等待，
    长睡保持取消响应性 }
  LRemaining := AMs;
  repeat
    if LRemaining > High(UInt32) then
      LChunk := High(UInt32)
    else
      LChunk := LRemaining;
    if AToken.WaitForCancel(UInt32(LChunk)) then
      Exit(False);
    Dec(LRemaining, LChunk);
  until LRemaining <= 0;
  Result := True;
end;

function TSystemClock.RandomU64: UInt64;
begin
  Result := platform_random_u64;
end;

procedure TFakeClock.Advance(AMs: Int64);
begin
  Inc(FVirtualNowMs, AMs);
end;

function TFakeClock.VirtualNowMs: Int64;
begin
  Result := FVirtualNowMs;
end;

function TFakeClock.LastSleepRequestMs: Int64;
begin
  Result := FLastSleepRequestMs;
end;

constructor TFakeClock.Create;
begin
  inherited Create;
  FRandState := UInt64(14695981039346656037);
end;

function TFakeClock.NowMs: Int64;
begin
  Result := FVirtualNowMs;
end;

function TFakeClock.SleepMs(AMs: Int64;
  const AToken: IAsyncCancellationToken): Boolean;
begin
  FLastSleepRequestMs := AMs;
  if (AToken <> nil) and AToken.IsCancelled then
    Exit(False);
  Result := True;
end;

function TFakeClock.RandomU64: UInt64;
begin
  { 确定性 LCG：FNV 基 + 乘，测试可复现，覆盖 jitter 全带 }
  FRandState := FRandState * UInt64(6364136223846793005) + 1;
  Result := FRandState;
end;

end.
