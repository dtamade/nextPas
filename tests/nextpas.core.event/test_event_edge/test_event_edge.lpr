program test_event_edge;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.event.base,
  nextpas.core.event.intf,
  nextpas.core.event;

var
  GPass: Integer = 0;
  GFail: Integer = 0;
  GHits: Integer = 0;

procedure Check(const AName: string; ACond: Boolean);
begin
  if ACond then begin Inc(GPass); WriteLn('  PASS: ', AName); end
  else begin Inc(GFail); WriteLn('  FAIL: ', AName); end;
end;

type
  TRcv = class
    procedure OnHit(const AName: string; const AData: TEventData);
  end;

procedure TRcv.OnHit(const AName: string; const AData: TEventData);
begin
  Inc(GHits);
end;

procedure TestUnsubscribeInvalidID;
var LBus: IEventBus;
begin
  WriteLn('--- TestUnsubscribeInvalidID ---');
  LBus := CreateEventBus;
  LBus.Unsubscribe(SUBSCRIPTION_INVALID);
  LBus.Unsubscribe(99999);
  Check('No crash', True);
end;

procedure TestEmitEmptyName;
var LBus: IEventBus; LRcv: TRcv;
begin
  WriteLn('--- TestEmitEmptyName ---');
  LBus := CreateEventBus;
  LRcv := TRcv.Create;
  try
    GHits := 0;
    LBus.Subscribe('', @LRcv.OnHit);
    LBus.Emit('');
    Check('Empty name works', GHits = 1);
  finally
    LRcv.Free;
  end;
end;

procedure TestDoubleUnsubscribe;
var LBus: IEventBus; LRcv: TRcv; LID: TSubscriptionID;
begin
  WriteLn('--- TestDoubleUnsubscribe ---');
  LBus := CreateEventBus;
  LRcv := TRcv.Create;
  try
    LID := LBus.Subscribe('x', @LRcv.OnHit);
    LBus.Unsubscribe(LID);
    LBus.Unsubscribe(LID);
    Check('Double unsub no crash', True);
    Check('Count=0', LBus.GetSubscriptionCount = 0);
  finally
    LRcv.Free;
  end;
end;

procedure TestFlushEmpty;
var LBus: IEventBus;
begin
  WriteLn('--- TestFlushEmpty ---');
  LBus := CreateEventBus;
  LBus.Flush;
  Check('Flush empty no crash', True);
end;

procedure TestQueueOverflow;
var LBus: IEventBus; LIdx: Integer;
begin
  WriteLn('--- TestQueueOverflow ---');
  LBus := CreateEventBus;
  for LIdx := 0 to EVENT_MAX_QUEUED + 10 do
    LBus.Post('overflow');
  Check('Queue capped', LBus.GetQueuedCount = EVENT_MAX_QUEUED);
end;

procedure TestSubscriptionOverflow;
var LBus: IEventBus; LRcv: TRcv; LIdx: Integer; LID: TSubscriptionID;
begin
  WriteLn('--- TestSubscriptionOverflow ---');
  LBus := CreateEventBus;
  LRcv := TRcv.Create;
  try
    for LIdx := 0 to EVENT_MAX_SUBSCRIPTIONS - 1 do
      LBus.Subscribe('x', @LRcv.OnHit);
    LID := LBus.Subscribe('x', @LRcv.OnHit);
    Check('Overflow returns invalid', LID = SUBSCRIPTION_INVALID);
  finally
    LRcv.Free;
  end;
end;

procedure TestEmitDuringEmit;
var LBus: IEventBus; LRcv: TRcv;
begin
  WriteLn('--- TestEmitDuringEmit ---');
  LBus := CreateEventBus;
  LRcv := TRcv.Create;
  try
    GHits := 0;
    LBus.Subscribe('chain', @LRcv.OnHit);
    LBus.Emit('chain');
    Check('Single emit', GHits = 1);
  finally
    LRcv.Free;
  end;
end;

begin
  WriteLn('=== nextpas.core.event edge tests ===');
  WriteLn;
  TestUnsubscribeInvalidID;
  TestEmitEmptyName;
  TestDoubleUnsubscribe;
  TestFlushEmpty;
  TestQueueOverflow;
  TestSubscriptionOverflow;
  TestEmitDuringEmit;
  WriteLn;
  WriteLn('=== Results: ', GPass, ' passed, ', GFail, ' failed ===');
  if GFail > 0 then Halt(1);
end.
