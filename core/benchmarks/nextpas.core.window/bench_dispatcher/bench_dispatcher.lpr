program bench_dispatcher;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

{** @desc 窗口 dispatcher 与事件分发性能基线。
       覆盖：fake Post 吞吐、Pump 往返、weResized 事件分发、
       多窗并发。供 directui/game 评估主线程投递成本。 *}

uses
  {$ifdef unix}
  nextpas.core.thread.init,
  {$endif}
  nextpas.core.bench,
  nextpas.core.time.base,
  nextpas.core.window.base,
  nextpas.core.window.intf,
  nextpas.core.window.factory,
  nextpas.core.window.fake;

var
  GWin: IWindow;
  GFake: TFakeWindow;

procedure BenchPostSingle(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 1 to 1000 do
    GWin.GetDispatcher.Post(procedure begin end);
  GFake.PumpAll;
  ACtx.SetBytes(1000 * 64);
end;

procedure BenchPostBurst(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 1 to 10000 do
    GWin.GetDispatcher.Post(procedure begin end);
  GFake.PumpAll;
  ACtx.SetBytes(10000 * 64);
end;

procedure BenchPumpOnce(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 1 to 1000 do
    GWin.GetDispatcher.Post(procedure begin end);
  for I := 1 to 1000 do
    GFake.PumpOnce;
end;

procedure BenchEventResized(const ACtx: IBenchContext);
var
  E: TWindowEvent;
  I: Integer;
  Cnt: Integer = 0;
begin
  GWin.OnEvent(procedure(const AEvent: TWindowEvent)
    begin
      if AEvent.Kind = weResized then Inc(Cnt);
    end);
  E.Kind := weResized;
  E.Width := 800; E.Height := 600; E.X := 0; E.Y := 0; E.NewScale := 0;
  for I := 1 to 5000 do
    GFake.InjectEvent(E);
  GWin.OnEvent(TWindowEventHandler(nil));
end;

procedure BenchMultiWindow(const ACtx: IBenchContext);
var
  W2: IWindow;
  F2: TFakeWindow;
  I: Integer;
begin
  W2 := CreateFakeWindow(DefaultWindowOptions);
  F2 := TFakeWindow.FromWindow(W2);
  for I := 1 to 1000 do
  begin
    GWin.GetDispatcher.Post(procedure begin end);
    W2.GetDispatcher.Post(procedure begin end);
  end;
  GFake.PumpAll;
  F2.PumpAll;
  W2.Close;
end;

procedure RunBenchmarks;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LOpts: TWindowOptions;
begin
  WriteLn('=== nextpas.core.window Dispatcher Benchmarks ===');
  WriteLn;
  LOpts := DefaultWindowOptions;
  LOpts.Width := 800; LOpts.Height := 600;
  GWin := CreateFakeWindow(LOpts);
  GFake := TFakeWindow.FromWindow(GWin);

  LSuite := TBenchSuite.Create('WindowDispatcher');
  LSuite.SetMinDuration(TDuration.FromMilliseconds(80));
  LSuite.SetMaxIterations(200);
  LSuite.SetMinSamples(7);
  LSuite.SetWarmupIters(2);
  LSuite.SetQuiet(False);

  LSuite.Add('PostSingle/1000', @BenchPostSingle);
  LSuite.Add('PostBurst/10000', @BenchPostBurst);
  LSuite.Add('PumpOnce/1000', @BenchPumpOnce);
  LSuite.Add('EventResized/5000', @BenchEventResized);
  LSuite.Add('MultiWindow/2000', @BenchMultiWindow);

  LResults := LSuite.Run;
  WriteLn;
  WriteLn('=== JSON ===');
  WriteLn(LResults.ToJSON);

  GWin.Close;
  GWin := nil;
  GFake := nil;
  LResults := nil;
  LSuite := nil;
end;

begin
  RunBenchmarks;
end.
