program test_lockfree_delayed_retry_queue;

{$mode objfpc}{$H+}

uses
  nextpas.core.thread.init,
  nextpas.core.lockfree.delayed_retry_queue,
  nextpas.core.errors,
  nextpas.core.test;

var
  GNow: UInt64 = 0;
  { handler 共享上下文（匿名过程捕获外层局部变量在本 FPC/选项组合下
    解析不稳，统一走命名 handler + 全局上下文）。 }
  GCalls: Integer = 0;
  GTags: string = '';
  GFirstTag: string = '';
  GKeep: Boolean = False;
  T: TTestSuite;

function FakeNowNs: UInt64;
begin
  Result := GNow;
end;

type
  TPayload = class(TInterfacedObject)
    Tag: string;
    constructor Create(const ATag: string);
  end;

constructor TPayload.Create(const ATag: string);
begin
  inherited Create;
  Tag := ATag;
end;

{ 类 → 接口须经局部接口变量中转（FPC 引用计数语义）。 }
procedure Enq(const AQ: TDelayedRetryQueue; const AKey, ATag: string);
var
  LP: IInterface;
begin
  LP := TPayload.Create(ATag);
  AQ.Enqueue(AKey, LP);
end;

{ 收集 payload 标签并 handled（handled 与否由 GKeep 控制）。 }
procedure HndCollect(const AItem: TDelayedRetryItem; var AHandled: Boolean);
begin
  Inc(GCalls);
  GTags := GTags + (AItem.Payload as TPayload).Tag;
  if GFirstTag = '' then
    GFirstTag := (AItem.Payload as TPayload).Tag;
  AHandled := not GKeep;
end;

{ 全局上限/每 key 上限：满丢最旧。 }
procedure TestGlobalLimitDropsOldest;
var
  LQ: TDelayedRetryQueue;
begin
  GNow := 0;
  LQ := TDelayedRetryQueue.Create(2, 4, 5000000000, 300000000000, @FakeNowNs);
  try
    Enq(LQ, 'a@x', 'm1');
    Enq(LQ, 'b@x', 'm2');
    Enq(LQ, 'c@x', 'm3');   { 满 → 丢 m1 }
    CheckEqual(Int64(2), LQ.Count, 'bounded at max items');
    CheckEqual(Int64(1), LQ.Dropped, 'one dropped');
    GNow := 10000000000;             { 到期：base=5s 已过 }
    GCalls := 0; GTags := ''; GFirstTag := ''; GKeep := False;
    LQ.DrainDue(@HndCollect);
    CheckEqual('m2m3', GTags, 'oldest (m1) dropped, order kept');
    CheckEqual(Int64(0), LQ.Count, 'all drained');
  finally
    LQ.Free;
  end;
end;

{ 每 key 上限：同 key 超限丢该 key 最旧，其他 key 不受影响。 }
procedure TestPerKeyLimitDropsOldest;
var
  LQ: TDelayedRetryQueue;
begin
  GNow := 0;
  LQ := TDelayedRetryQueue.Create(16, 2, 5000000000, 300000000000, @FakeNowNs);
  try
    Enq(LQ, 'a@x', 'a1');
    Enq(LQ, 'a@x', 'a2');
    Enq(LQ, 'a@x', 'a3');   { a 超限 → 丢 a1 }
    Enq(LQ, 'b@x', 'b1');
    CheckEqual(Int64(3), LQ.Count, 'a bounded at 2, b unaffected');
    CheckEqual(Int64(1), LQ.Dropped, 'one per-key drop');
    GNow := 10000000000;             { 到期：全部已过 base 窗口 }
    GCalls := 0; GTags := ''; GKeep := False;
    LQ.DrainDue(@HndCollect);
    CheckEqual('a2a3b1', GTags, 'per-key oldest dropped, order kept');
  finally
    LQ.Free;
  end;
end;

{ 未到期不回调；到期 handled 移除。 }
procedure TestDrainDueWindow;
var
  LQ: TDelayedRetryQueue;
begin
  GNow := 0;
  LQ := TDelayedRetryQueue.Create(16, 4, 5000000000, 300000000000, @FakeNowNs);
  try
    Enq(LQ, 'a@x', 'm1');
    GCalls := 0; GKeep := False;
    LQ.DrainDue(@HndCollect);
    CheckEqual(0, GCalls, 'not due yet: no callback');
    CheckEqual(Int64(1), LQ.Count, 'not due yet: stays queued');
    GNow := 5000000000;
    GCalls := 0; GTags := '';
    LQ.DrainDue(@HndCollect);
    CheckEqual(1, GCalls, 'due: callback fired once');
    CheckEqual('m1', GTags, 'payload delivered to handler');
    CheckEqual(Int64(0), LQ.Count, 'handled item removed');
  finally
    LQ.Free;
  end;
end;

{ 未 handled → 指数退避推进，窗口内不重试。 }
procedure TestUnhandledBackoff;
var
  LQ: TDelayedRetryQueue;
begin
  GNow := 0;
  LQ := TDelayedRetryQueue.Create(16, 4, 5000000000, 300000000000, @FakeNowNs);
  try
    Enq(LQ, 'a@x', 'm1');
    GNow := 5000000000;              { 首个到期点 }
    GCalls := 0; GKeep := True;      { 保留 → attempts=2, delay=10s }
    LQ.DrainDue(@HndCollect);
    CheckEqual(1, GCalls, 'first attempt');
    CheckEqual(Int64(1), LQ.Count, 'unhandled stays queued');
    GNow := 6000000000;              { +1s：第二次退避(10s)未到期 }
    GCalls := 0; GKeep := True;
    LQ.DrainDue(@HndCollect);
    CheckEqual(0, GCalls, 'backoff window respected (no early callback)');
    GNow := 15000000000;             { 10s 到期点 }
    GCalls := 0; GKeep := False;
    LQ.DrainDue(@HndCollect);
    CheckEqual(1, GCalls, 'second attempt after backoff');
    CheckEqual(Int64(0), LQ.Count, 'handled after backoff removed');
  finally
    LQ.Free;
  end;
end;

{ 指数退避从 attempts=0 起：delay(n)=base×2^(n-1) 钳 max。
  序列（base=5s, max=30s）：5/10/20/30/30... }
procedure TestBackoffClampMax;
var
  LQ: TDelayedRetryQueue;
begin
  GNow := 0;
  LQ := TDelayedRetryQueue.Create(16, 4, 5000000000, 30000000000, @FakeNowNs);
  try
    Enq(LQ, 'a@x', 'm1');
    GCalls := 0; GKeep := True;
    GNow := 5000000000;              { 初值到期：0 + base }
    LQ.DrainDue(@HndCollect);
    CheckEqual(1, GCalls, 'initial window 5s');
    GNow := 9999999999;              { 第 2 轮到期点 5+5=10s 前 1ns }
    LQ.DrainDue(@HndCollect);
    CheckEqual(1, GCalls, 'attempt2 = +5s: not before');
    GNow := 10000000000;
    LQ.DrainDue(@HndCollect);
    CheckEqual(2, GCalls, 'attempt2 fires at 10s');
    GNow := 19999999999;             { 第 3 轮到期点 10+10=20s 前 1ns }
    LQ.DrainDue(@HndCollect);
    CheckEqual(2, GCalls, 'attempt3 = +10s: not before');
    GNow := 20000000000;
    LQ.DrainDue(@HndCollect);
    CheckEqual(3, GCalls, 'attempt3 fires at 20s');
    GNow := 39999999999;             { 第 4 轮到期点 20+20=40s 前 1ns }
    LQ.DrainDue(@HndCollect);
    CheckEqual(3, GCalls, 'attempt4 = +20s: not before');
    GNow := 40000000000;
    LQ.DrainDue(@HndCollect);
    CheckEqual(4, GCalls, 'attempt4 fires at 40s');
    GNow := 69999999999;             { 第 5 轮钳位到期点 40+30=70s 前 1ns }
    LQ.DrainDue(@HndCollect);
    CheckEqual(4, GCalls, 'clamp 30s: not before 70s');
    GNow := 70000000000;
    LQ.DrainDue(@HndCollect);
    CheckEqual(5, GCalls, 'clamp 30s fires at 70s');
    GNow := 99999999999;             { 第 6 轮仍 30s：70+30=100s 前 1ns }
    LQ.DrainDue(@HndCollect);
    CheckEqual(5, GCalls, 'stays clamped: not before 100s');
    GNow := 100000000000;
    GKeep := False;                      { 最后一轮：handled 移除 }
    LQ.DrainDue(@HndCollect);
    CheckEqual(6, GCalls, 'stays clamped: fires at 100s');
    CheckEqual(Int64(0), LQ.Count, 'finally handled and removed');
  finally
    LQ.Free;
  end;
end;

{ Reset：清空条目与 Dropped 计数。 }
procedure TestReset;
var
  LQ: TDelayedRetryQueue;
begin
  GNow := 0;
  LQ := TDelayedRetryQueue.Create(16, 4, 5000000000, 300000000000, @FakeNowNs);
  try
    Enq(LQ, 'a@x', 'm1');
    Enq(LQ, 'b@x', 'm2');
    LQ.Reset;
    CheckEqual(Int64(0), LQ.Count, 'reset empties queue');
    CheckEqual(Int64(0), LQ.Dropped, 'reset clears dropped counter');
  finally
    LQ.Free;
  end;
end;

{ 构造校验：上限/退避窗口非法抛 EArgumentError。 }
procedure TestConstructorValidation;
var
  LQ: TDelayedRetryQueue;
begin
  LQ := nil;
  try
    try
      LQ := TDelayedRetryQueue.Create(0, 4);
      Check(False, 'maxItems=0 must raise');
    except
      on E: EArgumentError do ;
    end;
    try
      LQ := TDelayedRetryQueue.Create(16, 0);
      Check(False, 'maxPerKey=0 must raise');
    except
      on E: EArgumentError do ;
    end;
    try
      LQ := TDelayedRetryQueue.Create(16, 4, 0, 100);
      Check(False, 'base=0 must raise');
    except
      on E: EArgumentError do ;
    end;
    try
      LQ := TDelayedRetryQueue.Create(16, 4, 100, 50);
      Check(False, 'max<base must raise');
    except
      on E: EArgumentError do ;
    end;
  finally
    LQ.Free;
  end;
end;

begin
  GNow := 0;
  T := TTestSuite.Create('delayed retry queue');
  T.Test('enqueue/drain/handled', @TestDrainDueWindow);
  T.Test('unhandled exponential backoff', @TestUnhandledBackoff);
  T.Test('backoff clamps to max', @TestBackoffClampMax);
  T.Test('global limit drops oldest', @TestGlobalLimitDropsOldest);
  T.Test('per-key limit drops oldest', @TestPerKeyLimitDropsOldest);
  T.Test('reset empties queue', @TestReset);
  T.Test('constructor validation', @TestConstructorValidation);
  if not T.Run then Halt(1);
end.