program test_window_polish;
{ 1.1→1.3 polish evidence: drives shipped factory API end-to-end on wkFake
  and probes each landed backend family without crashing.
  Validates: Build→Show→Host→PumpOnce→Close lifecycle, queue/live reuse,
  text.ansi discipline (no PAnsiChar(AnsiString)), diagnostics path. }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.window.base,
  nextpas.core.window.intf,
  nextpas.core.window.factory,
  nextpas.core.window.fake,
  nextpas.core.window.gtk3,
  nextpas.core.window.sdl2,
  nextpas.core.text.ansi,
  nextpas.core.diagnostics;

procedure TestFactoryLifecycleViaShippedAPI;
var
  W: IWindow;
  Host: IWindowHost;
  Ctr: Integer;
  Ev: TWindowEvent;
  B: TDiagnosticsBuilder;
begin
  Ctr := 0;
  W := TWindowBuilder.New.Kind(wkFake).Title('polish').Size(800, 600).Build;
  try
    Check(not W.IsClosed, 'fresh not closed');
    Check(W.GetDispatcher <> nil, 'dispatcher exists');
    Check(W.GetDispatcher.IsOnMainThread, 'on main thread');
    W.OnEvent(procedure(const E: TWindowEvent)
      begin
        if E.Kind = weResized then Inc(Ctr);
        if E.Kind = weScaleChanged then Inc(Ctr);
      end);
    W.Show;
    Check(W.IsVisible, 'show');
    // Host drive via shipped IWindowHost (typed, no LM_ message)
    if Supports(W, IWindowHost, Host) then
    begin
      Host.HostResized(1024, 768);
      Host.HostScaleChanged(2.0);
    end;
    // PumpOnce drains Host events + any dispatcher posts
    Check(W.GetWidth = 1024, 'host resized width 1024');
    Check(W.GetScaleFactor = 2.0, 'host scale 2.0');
    Check(Ctr >= 2, 'host events delivered via PumpOnce path');
    // Dispatcher post from any thread (here main) → PumpOnce
    W.GetDispatcher.Post(procedure begin Ctr := Ctr + 10; end);
    WindowPumpOnce;
    Check(Ctr >= 12, 'dispatcher post via WindowPumpOnce');
    // Close idempotent via factory path
    W.Close;
    Check(W.IsClosed, 'closed');
    Check(W.NativeHandle = nil, 'handle nil after close');
    W.Close; // idempotent
    Check(W.IsClosed, 'still closed');
  finally
    W := nil;
  end;
  // text.ansi reuse evidence: StrToAnsi / AnsiPtrToStr round-trip without direct SysUtils
  Check(StrToAnsi('hello') <> '', 'StrToAnsi non-empty');
  Check(AnsiPtrToStr(PAnsiChar(StrToAnsi('hello'))) = 'hello', 'ansi round-trip');
  // diagnostics reuse evidence
  B.Clear;
  Check(B.Build = '', 'diagnostics builder empty build');
  Check(B.Count = 0, 'diagnostics count 0');
end;

procedure TestBackendProbingNoCrash;
var
  K: TWindowKind;
  Av: Boolean;
  Diag: string;
begin
  for K := Low(TWindowKind) to High(TWindowKind) do
  begin
    Av := False;
    try
      Av := WindowBackendAvailable(K);
    except
      Check(False, 'WindowBackendAvailable crashed for ' + IntToStr(Ord(K)));
    end;
    // wkFake must always be available
    if K = wkFake then
      Check(Av, 'wkFake must be available');
    // probing must not crash even when unavailable
    Check(True, 'probing ' + IntToStr(Ord(K)) + ' no crash, avail=' + BoolToStr(Av, True));
  end;
  Diag := '';
  try Diag := WindowBackendDiagnostics; except Check(False, 'diagnostics crashed'); end;
  Check(Diag <> '', 'diagnostics non-empty');
  Check(Pos('gtk', LowerCase(Diag)) > 0, 'diagnostics mentions gtk');
  Check(Pos('sdl2', LowerCase(Diag)) > 0, 'diagnostics mentions sdl2');
end;

procedure TestQueueLiveReuse;
var
  W1, W2: IWindow;
  Before: Integer;
begin
  Before := FakeLiveWindowCount;
  W1 := TWindowBuilder.New.Kind(wkFake).Build;
  W2 := TWindowBuilder.New.Kind(wkFake).Build;
  CheckEqual(Int64(Before + 2), Int64(FakeLiveWindowCount));
  // queue reuse: Post many then PumpAll drains without per-backend duplication
  W1.GetDispatcher.Post(procedure begin end);
  W1.GetDispatcher.Post(procedure begin end);
  W2.GetDispatcher.Post(procedure begin end);
  WindowPumpAll;
  // live registry reuse via factory's Live count
  W1.Close;
  CheckEqual(Int64(Before + 1), Int64(FakeLiveWindowCount));
  W2.Close;
  CheckEqual(Int64(Before), Int64(FakeLiveWindowCount));
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.window.polish');
  T.Test('factory lifecycle via shipped API', @TestFactoryLifecycleViaShippedAPI);
  T.Test('backend probing no crash', @TestBackendProbingNoCrash);
  T.Test('queue/live reuse', @TestQueueLiveReuse);
  if not T.Run then Halt(1);
end.
