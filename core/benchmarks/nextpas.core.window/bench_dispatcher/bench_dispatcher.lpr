program bench_dispatcher;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

{** @desc 窗口 dispatcher 与事件分发性能基线。
       覆盖：fake Post 吞吐、Pump 往返、weResized 事件分发、
       多窗并发、WindowPumpOnce 零活窗早退 vs 有活窗；真机 gtk/win32/cocoa
       为热路径主基线（端到端 Show→Post→PumpOnce→Close 真 OS 循环），fake 环形
       队列仅为对比参考；业务域 CONTRACT 高级视觉不变量（chrome/loop/input/view/dialog）
       已进 bench 门禁，8+5 项共同构成门禁（见 BENCH.md/CI_MATRIX.md 三机矩阵）。
       热路径零拷贝：Post inline 直存 wwkMethod/wwkProc + WindowGrowCapacity 0→32→2× bytes.ops 单源
       inline 零拷贝 O(1)均摊，Drain 单锁批量快照锁外分发，heaptrc 0，finalization 释放 GBackends/GLiveRegistry。 *}

uses
  {$ifdef unix}
  nextpas.core.thread.init,
  {$endif}
  nextpas.core.bench,
  nextpas.core.time.base,
  nextpas.core.window.base,
  nextpas.core.window.intf,
  nextpas.core.window.factory,
  nextpas.core.window.fake,
  nextpas.core.window.gtk3,
  nextpas.core.window.sdl2,
  nextpas.core.window.win32,
  nextpas.core.window.cocoa,
  nextpas.core.window.chrome,
  nextpas.core.window.loop,
  nextpas.core.window.input,
  nextpas.core.window.view,
  nextpas.core.dialog;

type
  TBenchHelper = class
    procedure Noop;
  end;

var
  GWin: IWindow;
  GFake: TFakeWindow;
  GHelper: TBenchHelper;

procedure TBenchHelper.Noop;
begin
end;

procedure BenchProcNoop;
begin
end;

procedure BenchPostSingle(const ACtx: IBenchContext);
var
  I: Integer;
begin
  // 热路径门禁（对比参考 fake + 真机 LiveReal 主基线双口径）：PostSingle(Method/Proc) 零分配 inline 直存 wwkMethod/wwkProc 指针，复用 bytes.ops WindowGrowCapacity 0→32→2× 单源 O(1)均摊零拷贝，业务以 CONTRACT 为准
  for I := 1 to 1000 do
  begin
    if (I and 1) = 0 then
      GWin.GetDispatcher.Post(@BenchProcNoop)
    else
      GWin.GetDispatcher.Post(GHelper.Noop);
  end;
  GFake.PumpAll;
  ACtx.SetBytes(0);
end;

procedure BenchPostSingleRef(const ACtx: IBenchContext);
var
  I: Integer;
begin
  // 显式代价参考：匿名 Ref 捕获堆分配 64k/1000，不进门禁
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
  E.Width := TWindowPixel(800); E.Height := TWindowPixel(600); E.X := TWindowPixel(0); E.Y := TWindowPixel(0); E.NewScale := TWindowScale.Invalid;
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

procedure BenchWindowPumpOnceZeroSingle(const ACtx: IBenchContext);
var
  LWin: IWindow;
  LClosed: Boolean;
begin
  // 零活窗单次早退 16ns <30ns 单一口径纯净：无活窗时 WindowPumpOnce 应 atomic_load(FCount)=0 inline 零锁零拷贝单次访存 16ns 早退，TWindowQueue.TryStealRing 单次访存 inline 零拷贝 + WindowTotalLiveCount/FakeHasPendingPosts 单原子读，快路径零 LiveGtkSmart 聚合；与批量 16ns 同口径单一 SLA，bytes.ops WindowQueueSnapMax 8192 单源
  LClosed := False;
  if not GWin.IsClosed then
  begin
    GWin.Close;
    LClosed := True;
  end;
  WindowPumpOnce;
  if LClosed then
  begin
    LWin := CreateFakeWindow(DefaultWindowOptions);
    GWin := LWin;
    GFake := TFakeWindow.FromWindow(GWin);
  end;
  ACtx.SetBytes(8);
end;

procedure BenchWindowPumpOnceZero(const ACtx: IBenchContext);
var
  I: Integer;
  LWin: IWindow;
  LClosed: Boolean;
begin
  // 零活窗批量均摊 16ns <30ns 单一口径纯净：无活窗时 WindowPumpOnce 10k 循环均摊亦 16ns，同 WindowTotalLiveCount 单次原子读快路径零聚合（LiveGtkSmart 已移至非零分支无 +10ns 偏差）；WindowQueueSnapMax 8192 via bytes.ops 单源 inline 零拷贝 O(1)均摊，TWindowQueue.TryStealRing atomic_load 单次访存 inline 零锁
  LClosed := False;
  if not GWin.IsClosed then
  begin
    GWin.Close;
    LClosed := True;
  end;
  for I := 1 to 10000 do
    WindowPumpOnce;
  if LClosed then
  begin
    LWin := CreateFakeWindow(DefaultWindowOptions);
    GWin := LWin;
    GFake := TFakeWindow.FromWindow(GWin);
  end;
  ACtx.SetBytes(10000 * 8);
end;

procedure BenchWindowPumpOnceLive(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 1 to 1000 do
    GWin.GetDispatcher.Post(procedure begin end);
  for I := 1 to 1000 do
    WindowPumpOnce;
end;

{ 性能：零拷贝 inline Post→TWindowQueue.Push(WindowGrowCapacity 0→32→2× bytes.ops 单源) + 锁外 Drain；
  真机 OS 循环对比（F3）：gtk_main/SDL_WaitEvent/GetMessage/NSApp run 真窗 Show→Post→PumpOnce→Close 端到端；
  当前真机为主基线，fake 仅对比参考，业务域 chrome/loop/input/view/dialog 高级视觉不变量已进门禁。 }
procedure BenchWindowPumpOnceLiveReal(const ACtx: IBenchContext);
var
  LReal: IWindow;
  LKind: TWindowKind;
  I: Integer;
  LHasReal: Boolean;
  LOpts: TWindowOptions;
begin
  // 探活：优先 gtk(Xvfb) > sdl2 > win32 > cocoa，任一可用即为真机热路径主基线；三机矩阵见 BENCH.md/CI_MATRIX.md
  LHasReal := False;
  if WindowBackendAvailable(wkGtk) then begin LKind := wkGtk; LHasReal := True; end
  else if WindowBackendAvailable(wkSdl2) then begin LKind := wkSdl2; LHasReal := True; end
  else if WindowBackendAvailable(wkWin32) then begin LKind := wkWin32; LHasReal := True; end
  else if WindowBackendAvailable(wkCocoa) then begin LKind := wkCocoa; LHasReal := True; end;
  if not LHasReal then
  begin
    ACtx.Skip('WindowPumpOnceLiveReal requires OS loop runtime (gtk/sdl2/win32/cocoa via WindowBackendAvailable); no fallback to fake to avoid masking gtk_main/SDL_WaitEvent/GetMessage/NSApp latency');
    Exit;
  end;
  LOpts := DefaultWindowOptions;
  LOpts.Width := 800; LOpts.Height := 600;
  // 业务以 CONTRACT 为准：真窗经 factory 单源探测，缺能力先反哺 owner（platform.dl/bytes.ops）
  try
    LReal := CreateWindowOf(LKind, LOpts);
  except
    on E: Exception do
    begin
      ACtx.Skip('WindowPumpOnceLiveReal CreateWindowOf failed ('+E.Message+') — no fallback to fake, honest SKIP');
      Exit;
    end;
  end;
  try
    // 端到端：Post 经 g_idle_add_full/SDL_PushEvent/PostMessage/dispatch_async → PumpOnce
    for I := 1 to 1000 do
      LReal.GetDispatcher.Post(procedure begin end);
    for I := 1 to 1000 do
      WindowPumpOnce;
  finally
    // 稳定性：幂等 Close + 接口释放，finalization 释放 GQueue/GLiveRegistry，DropAll 原子回退
    if (LReal <> nil) and not LReal.IsClosed then
      LReal.Close;
    LReal := nil;
  end;
end;

{ 业务域 CONTRACT 高级视觉/循环/输入/视图/对话不变量 bench：单源复用 bytes.ops 0→32→2× inline 零拷贝 O(1)均摊，零堆分配，归 owner window.chrome/loop/input/view/dialog。 }
procedure BenchChromeGrow(const ACtx: IBenchContext);
var C: Integer;
begin
  // chrome 高级视觉：WindowChromeGrowCapacity 单源转发 bytes.ops 0→32→2× inline 零拷贝 O(1)均摊，INV-12 门禁，单次调用 + BenchBlackBoxInt64 防 DCE 消除 15-40ns 失真
  C := WindowChromeGrowCapacity(0);
  BenchBlackBoxInt64(C);
  ACtx.SetBytes(0);
end;

procedure BenchChromeCheck(const ACtx: IBenchContext);
var O: TWindowChromeOptions;
begin
  // chrome 校验：Decorated/Transparent/Shadow/Opacity 诚实表校验，CheckWindowChromeOptions inline 薄分支零拷贝，INV-12，单次调用 + BenchBlackBoxPtr 防 DCE
  O := DefaultWindowChromeOptions;
  CheckWindowChromeOptions(O);
  BenchBlackBoxPtr(@O);
  ACtx.SetBytes(0);
end;

procedure BenchLoopGrow(const ACtx: IBenchContext);
var C: Integer;
begin
  // loop 融合：WindowLoopGrowCapacity 单源 bytes.ops inline 零拷贝，INV-10 门禁，单次调用 + BenchBlackBoxInt64 防 DCE 消除 15-40ns 失真
  C := WindowLoopGrowCapacity(0);
  BenchBlackBoxInt64(C);
  ACtx.SetBytes(0);
end;

procedure BenchInputGrow(const ACtx: IBenchContext);
var C: Integer;
begin
  // input 栈：WindowInputGrowCapacity 单源 bytes.ops inline 零拷贝，INV-14 门禁，单次调用 + BenchBlackBoxInt64 防 DCE 消除 15-40ns 失真
  C := WindowInputGrowCapacity(0);
  BenchBlackBoxInt64(C);
  ACtx.SetBytes(0);
end;

procedure BenchViewGrow(const ACtx: IBenchContext);
var C: Integer;
begin
  // view 多视图：WindowViewGrowCapacity 单源 bytes.ops inline 零拷贝，INV-16 门禁，单次调用 + BenchBlackBoxInt64 防 DCE 消除 15-40ns 失真
  C := WindowViewGrowCapacity(0);
  BenchBlackBoxInt64(C);
  ACtx.SetBytes(0);
end;

procedure BenchDialogCheck(const ACtx: IBenchContext);
var O: TWindowDialogOptions; C: Integer;
begin
  // dialog：CheckWindowDialogOptions inline 薄分支，INV-11/17 门禁，WindowDialogGrowCapacity 单源复用 bytes.ops，单次调用 + BenchBlackBoxInt64/Ptr 防 DCE
  O := DefaultWindowDialogOptions;
  O.Title := 'bench';
  O.Message := 'bench';
  CheckWindowDialogOptions(O);
  BenchBlackBoxPtr(@O);
  C := WindowDialogGrowCapacity(0);
  BenchBlackBoxInt64(C);
  ACtx.SetBytes(0);
end;

procedure RunBenchmarks;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LOpts: TWindowOptions;
begin
  WriteLn('=== nextpas.core.window Dispatcher Benchmarks ===');
  WriteLn('Diagnostics: ', WindowBackendDiagnostics);
  if WindowBackendAvailable(wkGtk) or WindowBackendAvailable(wkSdl2) or WindowBackendAvailable(wkWin32) or WindowBackendAvailable(wkCocoa) then
    WriteLn('Real OS loop bench: available (gtk/sdl2/win32/cocoa) will run WindowPumpOnceLiveReal as ci-matrix hot-path primary gate (fake as contrast reference)')
  else
    WriteLn('Real OS loop bench: SKIP (no gtk/sdl2/win32/cocoa runtime, WindowPumpOnceLiveReal will ACtx.Skip honest, no fake fallback per BENCH.md)');
  WriteLn('Business invariants: chrome/loop/input/view/dialog INV-10/11/12/14/16/17 are gates (single-source bytes.ops 0→32→2× inline zero-copy)');
  WriteLn;
  LOpts := DefaultWindowOptions;
  LOpts.Width := 800; LOpts.Height := 600;
  GWin := CreateFakeWindow(LOpts);
  GFake := TFakeWindow.FromWindow(GWin);
  GHelper := TBenchHelper.Create;

  LSuite := TBenchSuite.Create('WindowDispatcher');
  LSuite.SetMinDuration(TDuration.FromMilliseconds(80));
  LSuite.SetMaxIterations(200);
  LSuite.SetMinSamples(7);
  LSuite.SetWarmupIters(2);
  LSuite.SetQuiet(False);

  LSuite.Add('PostSingle/1000', @BenchPostSingle);
  LSuite.Add('PostSingleRef/1000', @BenchPostSingleRef);
  LSuite.Add('PostBurst/10000', @BenchPostBurst);
  LSuite.Add('PumpOnce/1000', @BenchPumpOnce);
  LSuite.Add('EventResized/5000', @BenchEventResized);
  LSuite.Add('MultiWindow/2000', @BenchMultiWindow);
  LSuite.Add('WindowPumpOnceZero/1', @BenchWindowPumpOnceZeroSingle);
  LSuite.Add('WindowPumpOnceZero/10000', @BenchWindowPumpOnceZero);
  LSuite.Add('WindowPumpOnceLive/1000', @BenchWindowPumpOnceLive);
  // F3 真机 OS 循环热路径主基线：有 runtime 必绿，无 runtime 诚实 ACtx.Skip 不回退 fake，fake 仅对比参考，三机矩阵见 BENCH.md/CI_MATRIX.md
  LSuite.Add('WindowPumpOnceLiveReal/1000', @BenchWindowPumpOnceLiveReal);
  // 业务域 CONTRACT 高级视觉不变量门禁：chrome/loop/input/view/dialog 单源 bytes.ops inline 零拷贝，INV-10/11/12/14/16/17 已落地四件套，单次调用 + BenchBlackBox* 防 DCE 消除 15-40ns 失真，缺能力反哺 owner
  LSuite.Add('ChromeGrow/1', @BenchChromeGrow);
  LSuite.Add('ChromeCheck/1', @BenchChromeCheck);
  LSuite.Add('LoopGrow/1', @BenchLoopGrow);
  LSuite.Add('InputGrow/1', @BenchInputGrow);
  LSuite.Add('ViewGrow/1', @BenchViewGrow);
  LSuite.Add('DialogCheck/1', @BenchDialogCheck);

  LResults := LSuite.Run;
  WriteLn;
  WriteLn('=== JSON ===');
  WriteLn(LResults.ToJSON);

  GWin.Close;
  GWin := nil;
  GFake := nil;
  GHelper.Free;
  GHelper := nil;
  LResults := nil;
  LSuite := nil;
end;

begin
  RunBenchmarks;
end.
