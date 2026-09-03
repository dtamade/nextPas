program test_event;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.event.base,
  nextpas.core.event.intf,
  nextpas.core.event,
  nextpas.core.test;

var
  GHitCount: Integer = 0;
  GLastInt: Int64 = 0;
  GLastFloat: Double = 0;
  GPriOrder: string = '';

type
  TTestReceiver = class
    procedure OnEvent(const AName: string; const AData: TEventData);
    procedure OnPriHigh(const AName: string; const AData: TEventData);
    procedure OnPriLow(const AName: string; const AData: TEventData);
  end;

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

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('event');

  LSuite.Test('subscribe and emit', procedure
  var LBus: IEventBus; LRcv: TTestReceiver;
  begin
    LBus := CreateEventBus; LRcv := TTestReceiver.Create;
    try
      GHitCount := 0;
      LBus.Subscribe('hit', @LRcv.OnEvent);
      LBus.Emit('hit');
      CheckEqual(1, GHitCount);
      CheckEqual(1, LBus.GetSubscriptionCount);
    finally LRcv.Free; end;
  end);

  LSuite.Test('emit with data', procedure
  var LBus: IEventBus; LRcv: TTestReceiver;
  begin
    LBus := CreateEventBus; LRcv := TTestReceiver.Create;
    try
      GLastInt := 0; GLastFloat := 0;
      LBus.Subscribe('damage', @LRcv.OnEvent);
      LBus.EmitInt('damage', 42);
      CheckEqual(Int64(42), GLastInt);
      LBus.EmitFloat('damage', 3.14);
      CheckTrue(Abs(GLastFloat - 3.14) < 0.01);
    finally LRcv.Free; end;
  end);

  LSuite.Test('unsubscribe', procedure
  var LBus: IEventBus; LRcv: TTestReceiver; LID: TSubscriptionID;
  begin
    LBus := CreateEventBus; LRcv := TTestReceiver.Create;
    try
      GHitCount := 0;
      LID := LBus.Subscribe('tick', @LRcv.OnEvent);
      LBus.Emit('tick');
      CheckEqual(1, GHitCount);
      LBus.Unsubscribe(LID);
      LBus.Emit('tick');
      CheckEqual(1, GHitCount);
      CheckEqual(0, LBus.GetSubscriptionCount);
    finally LRcv.Free; end;
  end);

  LSuite.Test('unsubscribe all', procedure
  var LBus: IEventBus; LRcv: TTestReceiver;
  begin
    LBus := CreateEventBus; LRcv := TTestReceiver.Create;
    try
      GHitCount := 0;
      LBus.Subscribe('x', @LRcv.OnEvent);
      LBus.Subscribe('x', @LRcv.OnEvent);
      LBus.Subscribe('y', @LRcv.OnEvent);
      LBus.UnsubscribeAll('x');
      LBus.Emit('x');
      CheckEqual(0, GHitCount);
      LBus.Emit('y');
      CheckEqual(1, GHitCount);
    finally LRcv.Free; end;
  end);

  LSuite.Test('priority ordering', procedure
  var LBus: IEventBus; LRcv: TTestReceiver;
  begin
    LBus := CreateEventBus; LRcv := TTestReceiver.Create;
    try
      GPriOrder := '';
      LBus.Subscribe('order', @LRcv.OnPriLow, 1);
      LBus.Subscribe('order', @LRcv.OnPriHigh, 10);
      LBus.Emit('order');
      CheckEqual('HL', GPriOrder);
    finally LRcv.Free; end;
  end);

  LSuite.Test('proc handler', procedure
  var LBus: IEventBus;
  begin
    LBus := CreateEventBus;
    GHitCount := 0;
    LBus.SubscribeProc('proc_event', @ProcHandler);
    LBus.Emit('proc_event');
    CheckEqual(1, GHitCount);
  end);

  LSuite.Test('post and flush', procedure
  var LBus: IEventBus; LRcv: TTestReceiver;
  begin
    LBus := CreateEventBus; LRcv := TTestReceiver.Create;
    try
      GHitCount := 0;
      LBus.Subscribe('deferred', @LRcv.OnEvent);
      LBus.Post('deferred');
      LBus.Post('deferred');
      CheckEqual(0, GHitCount);
      CheckEqual(2, LBus.GetQueuedCount);
      LBus.Flush;
      CheckEqual(2, GHitCount);
      CheckEqual(0, LBus.GetQueuedCount);
    finally LRcv.Free; end;
  end);

  LSuite.Test('post with data', procedure
  var LBus: IEventBus; LRcv: TTestReceiver;
  begin
    LBus := CreateEventBus; LRcv := TTestReceiver.Create;
    try
      GLastInt := 0;
      LBus.Subscribe('score', @LRcv.OnEvent);
      LBus.PostInt('score', 99);
      LBus.Flush;
      CheckEqual(Int64(99), GLastInt);
    finally LRcv.Free; end;
  end);

  LSuite.Test('clear queue', procedure
  var LBus: IEventBus; LRcv: TTestReceiver;
  begin
    LBus := CreateEventBus; LRcv := TTestReceiver.Create;
    try
      GHitCount := 0;
      LBus.Subscribe('x', @LRcv.OnEvent);
      LBus.Post('x');
      LBus.ClearQueue;
      LBus.Flush;
      CheckEqual(0, GHitCount);
    finally LRcv.Free; end;
  end);

  LSuite.Test('multiple events', procedure
  var LBus: IEventBus; LRcv: TTestReceiver;
  begin
    LBus := CreateEventBus; LRcv := TTestReceiver.Create;
    try
      GHitCount := 0;
      LBus.Subscribe('a', @LRcv.OnEvent);
      LBus.Subscribe('b', @LRcv.OnEvent);
      LBus.Emit('a');
      LBus.Emit('b');
      LBus.Emit('c');
      CheckEqual(2, GHitCount);
    finally LRcv.Free; end;
  end);

  LSuite.Test('no subscribers', procedure
  var LBus: IEventBus;
  begin
    LBus := CreateEventBus;
    LBus.Emit('nobody');
    CheckTrue(True, 'no crash');
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.event');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then
    Halt(1);
end.
