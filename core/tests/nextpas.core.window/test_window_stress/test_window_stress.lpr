program test_window_stress;
{ 并发投递与生命周期压力测试：4 线程各 2000 Post，主线程 PumpAll，
  验证 FIFO 完整性、Close 后投递丢弃、事件不重排。 heaptrc 0。 }

{$I nextpas.core.settings.inc}

uses
  {$ifdef unix}
  nextpas.core.thread.init,
  {$endif}
  SysUtils,
  nextpas.core.test,
  nextpas.core.window.base,
  nextpas.core.window.intf,
  nextpas.core.window.fake,
  nextpas.core.window.factory,
  nextpas.core.platform.thread;

var
  GCounter: Integer = 0;
  GStressWindow: IWindow = nil;

procedure IncCounter;
begin
  InterlockedIncrement(GCounter);
end;

function WorkerProc(AArg: Pointer): Pointer; cdecl;
var
  I: Integer;
  LDisp: IWindowDispatcher;
begin
  // Use global window ref — avoids raw interface pointer arg lifetime races.
  // Each worker captures the dispatcher once to reduce GetDispatcher overhead.
  LDisp := GStressWindow.GetDispatcher;
  for I := 1 to 2000 do
    LDisp.Post(@IncCounter);
  Result := nil;
end;

procedure TestConcurrentPost;
var
  W: IWindow;
  F: TFakeWindow;
  Handles: array[0..3] of TPlatformThreadHandle;
  I: Integer;
  LPtr: Pointer;
begin
  GCounter := 0;
  W := CreateFakeWindow(DefaultWindowOptions);
  F := TFakeWindow.FromWindow(W);
  GStressWindow := W;
  for I := 0 to 3 do
    platform_thread_create(Handles[I], @WorkerProc, nil);
  for I := 0 to 3 do
    platform_thread_join(Handles[I], LPtr);
  // pump all
  F.PumpAll;
  CheckEqual(Int64(8000), Int64(GCounter), 'concurrent 4*2000 posts all delivered');
  CheckEqual(Int64(0), Int64(F.PendingPosts), 'no pending after pump');
  GStressWindow := nil;
  W.Close;
end;

procedure TestCloseDropsPending;
var
  W: IWindow;
  F: TFakeWindow;
begin
  GCounter := 0;
  W := CreateFakeWindow(DefaultWindowOptions);
  F := TFakeWindow.FromWindow(W);
  W.GetDispatcher.Post(@IncCounter);
  W.GetDispatcher.Post(@IncCounter);
  W.Close;
  // Close should drop pending
  F.PumpAll;
  CheckEqual(Int64(0), Int64(GCounter), 'pending dropped after close');
  Check(W.IsClosed, 'closed');
end;

procedure TestEventOrderFIFO;
var
  W: IWindow;
  F: TFakeWindow;
  Seq: array of Integer;
  E: TWindowEvent;
  I: Integer;
begin
  W := CreateFakeWindow(DefaultWindowOptions);
  F := TFakeWindow.FromWindow(W);
  SetLength(Seq, 0);
  W.OnEvent(procedure(const AEvent: TWindowEvent)
    begin
      SetLength(Seq, Length(Seq)+1);
      Seq[High(Seq)] := AEvent.Width;
    end);
  for I := 1 to 100 do
  begin
    E.Kind := weResized;
    E.Width := TWindowPixel(I); E.Height := TWindowPixel(I);
    E.X := TWindowPixel(0); E.Y := TWindowPixel(0); E.NewScale := TWindowScale.Invalid;
    F.InjectEvent(E);
  end;
  CheckEqual(Int64(100), Int64(Length(Seq)), '100 events delivered');
  for I := 0 to 99 do
    CheckEqual(Int64(I+1), Int64(Seq[I]), 'FIFO order');
  W.Close;
end;

procedure TestMultiWindowIsolation;
var
  W1, W2: IWindow;
  F1, F2: TFakeWindow;
  C1, C2: Integer;
begin
  W1 := CreateFakeWindow(DefaultWindowOptions);
  W2 := CreateFakeWindow(DefaultWindowOptions);
  F1 := TFakeWindow.FromWindow(W1);
  F2 := TFakeWindow.FromWindow(W2);
  C1 := 0; C2 := 0;
  W1.OnEvent(procedure(const AEvent: TWindowEvent) begin Inc(C1); end);
  W2.OnEvent(procedure(const AEvent: TWindowEvent) begin Inc(C2); end);
  F1.InjectEvent(Default(TWindowEvent));
  F2.InjectEvent(Default(TWindowEvent));
  F1.InjectEvent(Default(TWindowEvent));
  CheckEqual(Int64(2), Int64(C1), 'W1 2 events');
  CheckEqual(Int64(1), Int64(C2), 'W2 1 event isolated');
  W1.Close; W2.Close;
end;

var
  GEventCounter: Integer = 0;
  GStressWindow2: IWindow = nil;

function Worker6Proc(AArg: Pointer): Pointer; cdecl;
var
  I: Integer;
  E: TWindowEvent;
  F: TFakeWindow;
begin
  F := TFakeWindow.FromWindow(GStressWindow2);
  for I := 1 to 500 do
  begin
    E := Default(TWindowEvent);
    E.Kind := TWindowEventKind(I mod 6);
    if E.Kind = weResized then begin E.Width:=TWindowPixel(I); E.Height:=TWindowPixel(I); end;
    if E.Kind = weMoved then begin E.X:=TWindowPixel(I); E.Y:=TWindowPixel(I); end;
    if E.Kind = weScaleChanged then E.NewScale:=TWindowScale.FromFactor(1.0);
    F.InjectEvent(E);
  end;
  Result := nil;
end;

procedure TestConcurrent6EventsMixed;
var
  W: IWindow;
  F: TFakeWindow;
  Handles: array[0..3] of TPlatformThreadHandle;
  I: Integer;
  LPtr: Pointer;
begin
  GEventCounter := 0;
  W := CreateFakeWindow(DefaultWindowOptions);
  F := TFakeWindow.FromWindow(W);
  GStressWindow2 := W;
  W.OnEvent(procedure(const AEvent: TWindowEvent) begin InterlockedIncrement(GEventCounter); end);
  for I := 0 to 3 do
    platform_thread_create(Handles[I], @Worker6Proc, nil);
  for I := 0 to 3 do
    platform_thread_join(Handles[I], LPtr);
  while F.PendingPosts > 0 do F.PumpAll;
  CheckEqual(Int64(2000), Int64(GEventCounter), 'concurrent 6-event 4*500 mixed delivered');
  GStressWindow2 := nil;
  W.Close;
end;

procedure Test6EventMatrix;
var
  W: IWindow;
  F: TFakeWindow;
  K: TWindowEventKind;
  E: TWindowEvent;
  Got: array[TWindowEventKind] of Integer;
  KK: TWindowEventKind;
begin
  for KK := Low(TWindowEventKind) to High(TWindowEventKind) do Got[KK] := 0;
  W := CreateFakeWindow(DefaultWindowOptions);
  F := TFakeWindow.FromWindow(W);
  W.OnEvent(procedure(const AEvent: TWindowEvent) begin Inc(Got[AEvent.Kind]); Inc(GEventCounter); end);
  GEventCounter := 0;
  for K := Low(TWindowEventKind) to High(TWindowEventKind) do
  begin
    E := Default(TWindowEvent);
    E.Kind := K;
    case K of
      weResized: begin E.Width:=10; E.Height:=10; end;
      weMoved: begin E.X:=5; E.Y:=5; end;
      weScaleChanged: E.NewScale:=TWindowScale.FromFactor(1.5);
    end;
    F.InjectEvent(E);
  end;
  CheckEqual(Int64(6), Int64(GEventCounter), '6-event matrix all delivered');
  for K := Low(TWindowEventKind) to High(TWindowEventKind) do
    CheckEqual(Int64(1), Int64(Got[K]), 'kind '+IntToStr(Ord(K))+' once');
  W.Close;
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.window.stress');
  T.Test('concurrent post', @TestConcurrentPost);
  T.Test('close drops pending', @TestCloseDropsPending);
  T.Test('event order fifo', @TestEventOrderFIFO);
  T.Test('multi window isolation', @TestMultiWindowIsolation);
  T.Test('concurrent 6-event mixed', @TestConcurrent6EventsMixed);
  T.Test('6-event matrix', @Test6EventMatrix);
  if not T.Run then Halt(1);
end.
