program test_event;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.event.base,
  nextpas.core.event.intf,
  nextpas.core.event;

var
  GTestPassed: Integer = 0;
  GTestFailed: Integer = 0;
  GHitCount: Integer = 0;
  GLastInt: Int64 = 0;
  GLastFloat: Double = 0;

procedure Check(const AName: string; ACondition: Boolean);
begin
  if ACondition then begin Inc(GTestPassed); WriteLn('  PASS: ', AName); end
  else begin Inc(GTestFailed); WriteLn('  FAIL: ', AName); end;
end;

{ Test handlers }
type
  TTestReceiver = class
    procedure OnEvent(const AName: string; const AData: TEventData);
    procedure OnPriHigh(const AName: string; const AData: TEventData);
    procedure OnPriLow(const AName: string; const AData: TEventData);
  end;

var
  GPriOrder: string = '';

procedure TTestReceiver.OnEvent(const AName: string; const AData: TEventData);
begin
  Inc(GHitCount);
  if AData.Kind = edInt then GLastInt := AData.IntVal;
  if AData.Kind = edFloat then GLastFloat := AData.FloatVal;
end;

procedure TTestReceiver.OnPriHigh(const AName: string; const AData: TEventData);
begin
  GPriOrder := GPriOrder + 'H';
end;

procedure TTestReceiver.OnPriLow(const AName: string; const AData: TEventData);
begin
  GPriOrder := GPriOrder + 'L';
end;

procedure ProcHandler(const AName: string; const AData: TEventData);
begin
  Inc(GHitCount);
end;

{ Tests }

procedure TestSubscribeAndEmit;
var
  LBus: IEventBus;
  LRcv: TTestReceiver;
begin
  WriteLn('--- TestSubscribeAndEmit ---');
  LBus := CreateEventBus;
  LRcv := TTestReceiver.Create;
  try
    GHitCount := 0;
    LBus.Subscribe('hit', @LRcv.OnEvent);
    LBus.Emit('hit');
    Check('Handler called', GHitCount = 1);
    Check('SubCount=1', LBus.GetSubscriptionCount = 1);
  finally
    LRcv.Free;
  end;
end;

procedure TestEmitWithData;
var
  LBus: IEventBus;
  LRcv: TTestReceiver;
begin
  WriteLn('--- TestEmitWithData ---');
  LBus := CreateEventBus;
  LRcv := TTestReceiver.Create;
  try
    GLastInt := 0;
    GLastFloat := 0;
    LBus.Subscribe('damage', @LRcv.OnEvent);
    LBus.EmitInt('damage', 42);
    Check('Int data', GLastInt = 42);
    LBus.EmitFloat('damage', 3.14);
    Check('Float data', Abs(GLastFloat - 3.14) < 0.01);
  finally
    LRcv.Free;
  end;
end;

procedure TestUnsubscribe;
var
  LBus: IEventBus;
  LRcv: TTestReceiver;
  LID: TSubscriptionID;
begin
  WriteLn('--- TestUnsubscribe ---');
  LBus := CreateEventBus;
  LRcv := TTestReceiver.Create;
  try
    GHitCount := 0;
    LID := LBus.Subscribe('tick', @LRcv.OnEvent);
    LBus.Emit('tick');
    Check('Before unsub', GHitCount = 1);
    LBus.Unsubscribe(LID);
    LBus.Emit('tick');
    Check('After unsub', GHitCount = 1);
    Check('SubCount=0', LBus.GetSubscriptionCount = 0);
  finally
    LRcv.Free;
  end;
end;

procedure TestUnsubscribeAll;
var
  LBus: IEventBus;
  LRcv: TTestReceiver;
begin
  WriteLn('--- TestUnsubscribeAll ---');
  LBus := CreateEventBus;
  LRcv := TTestReceiver.Create;
  try
    GHitCount := 0;
    LBus.Subscribe('x', @LRcv.OnEvent);
    LBus.Subscribe('x', @LRcv.OnEvent);
    LBus.Subscribe('y', @LRcv.OnEvent);
    LBus.UnsubscribeAll('x');
    LBus.Emit('x');
    Check('x unsubscribed', GHitCount = 0);
    LBus.Emit('y');
    Check('y still works', GHitCount = 1);
  finally
    LRcv.Free;
  end;
end;

procedure TestPriority;
var
  LBus: IEventBus;
  LRcv: TTestReceiver;
begin
  WriteLn('--- TestPriority ---');
  LBus := CreateEventBus;
  LRcv := TTestReceiver.Create;
  try
    GPriOrder := '';
    LBus.Subscribe('order', @LRcv.OnPriLow, 1);
    LBus.Subscribe('order', @LRcv.OnPriHigh, 10);
    LBus.Emit('order');
    Check('High before Low', GPriOrder = 'HL');
  finally
    LRcv.Free;
  end;
end;

procedure TestProcHandler;
var
  LBus: IEventBus;
begin
  WriteLn('--- TestProcHandler ---');
  LBus := CreateEventBus;
  GHitCount := 0;
  LBus.SubscribeProc('proc_event', @ProcHandler);
  LBus.Emit('proc_event');
  Check('Proc called', GHitCount = 1);
end;

procedure TestPostAndFlush;
var
  LBus: IEventBus;
  LRcv: TTestReceiver;
begin
  WriteLn('--- TestPostAndFlush ---');
  LBus := CreateEventBus;
  LRcv := TTestReceiver.Create;
  try
    GHitCount := 0;
    LBus.Subscribe('deferred', @LRcv.OnEvent);
    LBus.Post('deferred');
    LBus.Post('deferred');
    Check('Not yet', GHitCount = 0);
    Check('Queued=2', LBus.GetQueuedCount = 2);
    LBus.Flush;
    Check('After flush', GHitCount = 2);
    Check('Queue empty', LBus.GetQueuedCount = 0);
  finally
    LRcv.Free;
  end;
end;

procedure TestPostWithData;
var
  LBus: IEventBus;
  LRcv: TTestReceiver;
begin
  WriteLn('--- TestPostWithData ---');
  LBus := CreateEventBus;
  LRcv := TTestReceiver.Create;
  try
    GLastInt := 0;
    LBus.Subscribe('score', @LRcv.OnEvent);
    LBus.PostInt('score', 99);
    LBus.Flush;
    Check('Posted int', GLastInt = 99);
  finally
    LRcv.Free;
  end;
end;

procedure TestClearQueue;
var
  LBus: IEventBus;
  LRcv: TTestReceiver;
begin
  WriteLn('--- TestClearQueue ---');
  LBus := CreateEventBus;
  LRcv := TTestReceiver.Create;
  try
    GHitCount := 0;
    LBus.Subscribe('x', @LRcv.OnEvent);
    LBus.Post('x');
    LBus.ClearQueue;
    LBus.Flush;
    Check('Cleared', GHitCount = 0);
  finally
    LRcv.Free;
  end;
end;

procedure TestMultipleEvents;
var
  LBus: IEventBus;
  LRcv: TTestReceiver;
begin
  WriteLn('--- TestMultipleEvents ---');
  LBus := CreateEventBus;
  LRcv := TTestReceiver.Create;
  try
    GHitCount := 0;
    LBus.Subscribe('a', @LRcv.OnEvent);
    LBus.Subscribe('b', @LRcv.OnEvent);
    LBus.Emit('a');
    LBus.Emit('b');
    LBus.Emit('c');
    Check('Only a+b fire', GHitCount = 2);
  finally
    LRcv.Free;
  end;
end;

procedure TestNoSubscribers;
var
  LBus: IEventBus;
begin
  WriteLn('--- TestNoSubscribers ---');
  LBus := CreateEventBus;
  LBus.Emit('nobody');
  Check('No crash', True);
end;

begin
  WriteLn('=== nextpas.core.event tests ===');
  WriteLn;
  TestSubscribeAndEmit;
  TestEmitWithData;
  TestUnsubscribe;
  TestUnsubscribeAll;
  TestPriority;
  TestProcHandler;
  TestPostAndFlush;
  TestPostWithData;
  TestClearQueue;
  TestMultipleEvents;
  TestNoSubscribers;
  WriteLn;
  WriteLn('=== Results: ', GTestPassed, ' passed, ', GTestFailed, ' failed ===');
  if GTestFailed > 0 then Halt(1);
end.
