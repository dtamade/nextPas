unit nextpas.core.window.factory;

{** @desc window 后端工厂、fluent Builder 与主循环入口。

       S1 后端可用性事实源：仅 fake 编译内建；gtk/sdl2 随波次
       接入时把 ResolveDefaultKind 切到平台优先并接入探测。
       默认 kind 的选择是本单元唯一职责，禁止散落到后端单元。

       Builder 形态决策（docs/window/CONTRACT.md §4.3）：
       - Build 可多次调用创建多窗（多窗口路径）。
       - RunLoop 阻塞直到末窗关闭或 WindowExitLoop。
       - 工厂持 loader 真相；base 不知道这些函数的存在。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.base,
  nextpas.core.window.intf;

type
  {** fluent 构建器。COM 引用计数生命周期，消费方不手写释放。 *}
  IWindowBuilder = interface
    ['{8F1A2B3C-4D5E-4F60-9A8B-C0D1E2F3A004}']
    function Kind(AKind: TWindowKind): IWindowBuilder;
    function Title(const ATitle: string): IWindowBuilder;
    function Size(AWidth, AHeight: Integer): IWindowBuilder;
    function MinSize(AWidth, AHeight: Integer): IWindowBuilder;
    function MaxSize(AWidth, AHeight: Integer): IWindowBuilder;
    function Resizable(AResizable: Boolean): IWindowBuilder;
    function StartMaximized(AMaximized: Boolean): IWindowBuilder;
    function Parent(AHandle: TWindowNativeHandle): IWindowBuilder;
    function Options(const AOptions: TWindowOptions): IWindowBuilder;
    function Build: IWindow;
  end;

  {** 入口形态：`TWindowBuilder.New.Title(..)...Build`。 *}
  TWindowBuilder = record
    class function New: IWindowBuilder; static;
  end;

{ 能力探测（factory 持 loader 真相；base 不知道这些函数的存在） }
function WindowBackendAvailable(AKind: TWindowKind): Boolean;
function DefaultWindowKind: TWindowKind;
function WindowBackendDiagnostics: string;

{ 按 kind 创建；不可用抛 EWindowBackendUnavailable }
function CreateWindowOf(AKind: TWindowKind;
  const AOptions: TWindowOptions): IWindow;
function CreateFakeWindow(const AOptions: TWindowOptions): IWindow;

{ 主循环所有权：阻塞直到最后一个未 Close 的窗口关闭，或 ExitLoop 被调 }
procedure WindowRunLoop;
procedure WindowExitLoop;

{ 非阻塞泵：为 game/directui 的 tick 循环提供不阻塞的单步迭代。
  返回 True 表示做了工作（处理了事件或投递），False 表示空转。
  拒绝 LCL 式消息伪装：调用方只关心"是否该重绘"，不解析 WPARAM。 }
function WindowPumpOnce: Boolean;
procedure WindowPumpAll;

implementation

uses
  nextpas.core.system.sysutils,
  nextpas.core.system.typinfo,
  nextpas.core.diagnostics,
  nextpas.core.platform.thread,
  nextpas.core.window.fake,
  nextpas.core.window.gtk3,
  nextpas.core.window.gtk4,
  nextpas.core.window.gtk2,
  nextpas.core.gtk3.loader,
  nextpas.core.gtk4.loader,
  nextpas.core.gtk2.loader,
  nextpas.core.qt5pas.loader,
  nextpas.core.qt.loader,
  nextpas.core.window.sdl2,
  nextpas.core.window.sdl2.loader,
  nextpas.core.window.win32,
  nextpas.core.window.win32.loader,
  nextpas.core.window.cocoa,
  nextpas.core.window.cocoa.loader,
  nextpas.core.window.wasm,
  nextpas.core.window.wasm.loader,
  nextpas.core.window.android,
  nextpas.core.window.android.loader,
  nextpas.core.window.uikit,
  nextpas.core.window.uikit.loader;

var
  GExitRequested: Boolean = False;

{ ---- 后端注册表：优雅扩展的唯一真相收敛点 ---- }
type
  TBackendProbe = function: Boolean;
  TBackendCreate = function(const AOptions: TWindowOptions): IWindow;
  TBackendLive = function: Integer;
  TBackendRun = procedure;
  TBackendQuit = procedure;

  TBackendDesc = record
    Kind: TWindowKind;
    Probe: TBackendProbe;
    Create: TBackendCreate;
    Live: TBackendLive;
    Run: TBackendRun;
    Quit: TBackendQuit;
  end;
  PBackendDesc = ^TBackendDesc;

function ProbeFake: Boolean; begin Result := True; end;
function LiveFake: Integer; begin Result := FakeLiveWindowCount; end;
procedure RunFake;
begin
  while not GExitRequested do
  begin
    if FakeLiveWindowCount > 0 then FakePumpAll else Break;
    if FakeLiveWindowCount = 0 then Break;
    platform_thread_yield;
    if GExitRequested then Break;
  end;
end;
procedure QuitFake; begin end;

// 独立家族探测（供 diagnostics 与回退）
function ProbeGtk3: Boolean;
var L: TGtk3LoadInfo; begin Result := TryLoadGtk3(L) and L.Loaded; end;
function ProbeGtk4: Boolean;
var L: TGtk4LoadInfo; begin Result := TryLoadGtk4(L) and L.Loaded; end;
function ProbeGtk2: Boolean;
var L: TGtk2LoadInfo; begin Result := TryLoadGtk2(L) and L.Loaded; end;

function ProbeGtk: Boolean;
begin
  // gtk 聚合探测：gtk4 > gtk3 > gtk2 任一可用即视为 wkGtk 可用（智能回退）
  Result := ProbeGtk4 or ProbeGtk3 or ProbeGtk2;
end;

function CreateGtkSmart(const AOptions: TWindowOptions): IWindow;
begin
  if ProbeGtk4 then
    Exit(nextpas.core.window.gtk4.CreateWindowGtk4(AOptions));
  if ProbeGtk3 then
    Exit(nextpas.core.window.gtk3.CreateWindowGtk(AOptions));
  if ProbeGtk2 then
    Exit(nextpas.core.window.gtk2.CreateWindowGtk2(AOptions));
  raise EWindowBackendUnavailable.Create('GTK backend not available (all families failed)');
end;

function LiveGtkSmart: Integer; inline;
begin
  Result := nextpas.core.window.gtk3.GtkLiveWindowCount
          + nextpas.core.window.gtk4.Gtk4LiveWindowCount
          + nextpas.core.window.gtk2.Gtk2LiveWindowCount;
end;

procedure RunGtkSmart;
begin
  if ProbeGtk4 and (nextpas.core.window.gtk4.Gtk4LiveWindowCount > 0) then
  begin
    nextpas.core.window.gtk4.WindowGtk4RunMainLoop;
    Exit;
  end;
  if ProbeGtk3 and (nextpas.core.window.gtk3.GtkLiveWindowCount > 0) then
  begin
    nextpas.core.window.gtk3.WindowGtkRunMainLoop;
    Exit;
  end;
  if ProbeGtk2 and (nextpas.core.window.gtk2.Gtk2LiveWindowCount > 0) then
  begin
    nextpas.core.window.gtk2.WindowGtk2RunMainLoop;
    Exit;
  end;
  if ProbeGtk4 then nextpas.core.window.gtk4.WindowGtk4RunMainLoop
  else if ProbeGtk3 then nextpas.core.window.gtk3.WindowGtkRunMainLoop
  else nextpas.core.window.gtk2.WindowGtk2RunMainLoop;
end;

procedure QuitGtkSmart;
begin
  if ProbeGtk4 then try nextpas.core.window.gtk4.WindowGtk4QuitMainLoop; except end;
  if ProbeGtk3 then try nextpas.core.window.gtk3.WindowGtkQuitMainLoop; except end;
  if ProbeGtk2 then try nextpas.core.window.gtk2.WindowGtk2QuitMainLoop; except end;
end;
function ProbeQt5Pas: Boolean;
var L: TQt5PasLoadInfo; begin Result := TryLoadQt5Pas(L) and L.Loaded; end;
function ProbeQt: Boolean;
var L: TQtLoadInfo; begin Result := TryLoadQt(L) and L.Loaded; end;

function ProbeSdl2: Boolean;
var L: TWindowSdl2LoadInfo; begin Result := TryLoadWindowSdl2(L) and L.Loaded; end;

function ProbeWin32: Boolean;
var L: TWindowWin32LoadInfo; begin Result := TryLoadWindowWin32(L) and L.Loaded; end;

function ProbeCocoa: Boolean;
var L: TWindowCocoaLoadInfo; begin Result := TryLoadWindowCocoa(L) and L.Loaded; end;

function ProbeWasm: Boolean;
var L: TWindowWasmLoadInfo; begin Result := TryLoadWindowWasm(L) and L.Loaded; end;

function ProbeAndroid: Boolean;
var L: TWindowAndroidLoadInfo; begin Result := TryLoadWindowAndroid(L) and L.Loaded; end;

function ProbeUIKit: Boolean;
var L: TWindowUIKitLoadInfo; begin Result := TryLoadWindowUIKit(L) and L.Loaded; end;

var
  BACKENDS: array[0..7] of TBackendDesc;
  BACKENDS_INITED: Boolean = False;

procedure InitBackends;
begin
  if BACKENDS_INITED then Exit;
  BACKENDS[0].Kind := wkWin32; BACKENDS[0].Probe := @ProbeWin32; BACKENDS[0].Create := @CreateWindowWin32; BACKENDS[0].Live := @Win32LiveWindowCount; BACKENDS[0].Run := @WindowWin32RunLoop; BACKENDS[0].Quit := @WindowWin32QuitLoop;
  BACKENDS[1].Kind := wkCocoa; BACKENDS[1].Probe := @ProbeCocoa; BACKENDS[1].Create := @CreateWindowCocoa; BACKENDS[1].Live := @CocoaLiveWindowCount; BACKENDS[1].Run := @WindowCocoaRunLoop; BACKENDS[1].Quit := @WindowCocoaQuitLoop;
  BACKENDS[2].Kind := wkAndroid; BACKENDS[2].Probe := @ProbeAndroid; BACKENDS[2].Create := @CreateWindowAndroid; BACKENDS[2].Live := @AndroidLiveWindowCount; BACKENDS[2].Run := @WindowAndroidRunLoop; BACKENDS[2].Quit := @WindowAndroidQuitLoop;
  BACKENDS[3].Kind := wkUIKit; BACKENDS[3].Probe := @ProbeUIKit; BACKENDS[3].Create := @CreateWindowUIKit; BACKENDS[3].Live := @UIKitLiveWindowCount; BACKENDS[3].Run := @WindowUIKitRunLoop; BACKENDS[3].Quit := @WindowUIKitQuitLoop;
  BACKENDS[4].Kind := wkWasm; BACKENDS[4].Probe := @ProbeWasm; BACKENDS[4].Create := @CreateWindowWasm; BACKENDS[4].Live := @WasmLiveWindowCount; BACKENDS[4].Run := @WindowWasmRunLoop; BACKENDS[4].Quit := @WindowWasmQuitLoop;
  BACKENDS[5].Kind := wkGtk; BACKENDS[5].Probe := @ProbeGtk; BACKENDS[5].Create := @CreateGtkSmart; BACKENDS[5].Live := @LiveGtkSmart; BACKENDS[5].Run := @RunGtkSmart; BACKENDS[5].Quit := @QuitGtkSmart;
  BACKENDS[6].Kind := wkSdl2; BACKENDS[6].Probe := @ProbeSdl2; BACKENDS[6].Create := @CreateWindowSdl2; BACKENDS[6].Live := @SdlLiveWindowCount; BACKENDS[6].Run := @WindowSdl2RunLoop; BACKENDS[6].Quit := @WindowSdl2QuitLoop;
  BACKENDS[7].Kind := wkFake; BACKENDS[7].Probe := @ProbeFake; BACKENDS[7].Create := @CreateFakeWindow; BACKENDS[7].Live := @LiveFake; BACKENDS[7].Run := @RunFake; BACKENDS[7].Quit := @QuitFake;
  BACKENDS_INITED := True;
end;

function FindBackend(AKind: TWindowKind): PBackendDesc;
var
  I: Integer;
begin
  InitBackends;
  for I := Low(BACKENDS) to High(BACKENDS) do
    if BACKENDS[I].Kind = AKind then
      Exit(@BACKENDS[I]);
  Result := nil;
end;

function WindowBackendAvailable(AKind: TWindowKind): Boolean;
var
  B: PBackendDesc;
begin
  InitBackends;
  B := FindBackend(AKind);
  if B = nil then Exit(False);
  if not Assigned(B^.Probe) then Exit(False);
  Result := B^.Probe();
end;

function DefaultWindowKind: TWindowKind;
var
  I: Integer;
begin
  InitBackends;
  for I := Low(BACKENDS) to High(BACKENDS) do
    if BACKENDS[I].Probe() then
      Exit(BACKENDS[I].Kind);
  Result := wkFake;
end;

function WindowBackendDiagnostics: string;
var
  I: Integer;
  LAvail: Boolean;
  LDetail: string;
  B: TDiagnosticsBuilder;
begin
  InitBackends;
  B.Clear;
  for I := Low(BACKENDS) to High(BACKENDS) do
  begin
    LAvail := False;
    if Assigned(BACKENDS[I].Probe) then
      try
        LAvail := BACKENDS[I].Probe();
      except
        LAvail := False;
      end;
    case BACKENDS[I].Kind of
      wkGtk: LDetail := 'sonames: libgtk-4.so.1|libgtk-3.so.0|libgtk-x11-2.0.so.0, libgobject-2.0.so.0, libglib-2.0.so.0; smart fallback gtk4>gtk3>gtk2';
      wkSdl2: LDetail := 'soname: libSDL2.so';
      wkWin32: LDetail := 'sonames: user32.dll / libuser32';
      wkCocoa: LDetail := 'sonames: libobjc, libdispatch, AppKit';
      wkWasm: LDetail := 'sonames: env:emscripten_*';
      wkAndroid: LDetail := 'soname: libandroid.so / ANativeWindow';
      wkUIKit: LDetail := 'soname: UIKit / libobjc';
      wkFake: LDetail := 'builtin';
    end;
    B.Add(GetEnumName(TypeInfo(TWindowKind), Ord(BACKENDS[I].Kind)), LAvail, LDetail);
  end;
  try B.Add('gtk4', ProbeGtk4, 'sonames: libgtk-4.so.1, libgobject-2.0.so.0, libglib-2.0.so.0'); except end;
  try B.Add('gtk2', ProbeGtk2, 'sonames: libgtk-x11-2.0.so.0, libgobject-2.0.so.0, libglib-2.0.so.0'); except end;
  try B.Add('qt5pas', ProbeQt5Pas, 'sonames: libQt5Pas.so.1'); except end;
  try B.Add('qt', ProbeQt, 'sonames: libnextpas-qt.so'); except end;
  Result := B.Build;
end;

function CreateFakeWindow(const AOptions: TWindowOptions): IWindow;
begin
  CheckWindowOptions(AOptions);
  Result := TFakeWindow.Create(AOptions);
end;

function CreateWindowOf(AKind: TWindowKind;
  const AOptions: TWindowOptions): IWindow;
var
  B: PBackendDesc;
begin
  CheckWindowOptions(AOptions);
  if not WindowBackendAvailable(AKind) then
    raise EWindowBackendUnavailable.CreateFmt(
      'window backend "%s" is not available in this build — call WindowBackendDiagnostics for sonames/probe details', [
      GetEnumName(TypeInfo(TWindowKind), Ord(AKind))]);

  if (AOptions.ParentHandle <> nil) and (AKind in [wkGtk, wkSdl2, wkWin32, wkCocoa]) then
    raise EWindowUnsupported.Create(
      'ParentHandle is not supported for desktop window backends');

  B := FindBackend(AKind);
  if (B <> nil) and Assigned(B^.Create) then
    Exit(B^.Create(AOptions));

  raise EWindowBackendUnavailable.CreateFmt(
    'window backend "%s" is registered but has no factory yet', [
    GetEnumName(TypeInfo(TWindowKind), Ord(AKind))]);
end;

procedure WindowRunLoop;
var
  I: Integer;
  B: PBackendDesc;
begin
  InitBackends;
  GExitRequested := False;
  // 优先让有存活窗的原生后端的阻塞式 RunLoop 接管
  for I := Low(BACKENDS) to High(BACKENDS) do
  begin
    B := @BACKENDS[I];
    if Assigned(B^.Live) and Assigned(B^.Run) and (B^.Live() > 0) and B^.Probe() then
    begin
      B^.Run();
      Exit;
    end;
  end;
  // 无原生阻塞循环时的混合 pump（fake 为主，兼顾原生 LIVE 兜底）
  while not GExitRequested do
  begin
    for I := Low(BACKENDS) to High(BACKENDS) do
    begin
      B := PBackendDesc(@BACKENDS[I]);
      if Assigned(B^.Live) and Assigned(B^.Run) and (B^.Live() > 0) and B^.Probe() then
      begin
        B^.Run();
        Exit;
      end;
    end;
    if FakeLiveWindowCount > 0 then
      FakePumpAll
    else
      Break;
    if (FakeLiveWindowCount = 0) and (LiveGtkSmart = 0) and (SdlLiveWindowCount = 0)
       and (Win32LiveWindowCount = 0) and (CocoaLiveWindowCount = 0)
       and (WasmLiveWindowCount = 0) and (AndroidLiveWindowCount = 0) and (UIKitLiveWindowCount = 0) then
      Break;
    platform_thread_yield;
    if GExitRequested then Break;
  end;
end;

procedure WindowExitLoop;
var
  I: Integer;
begin
  InitBackends;
  GExitRequested := True;
  for I := Low(BACKENDS) to High(BACKENDS) do
    if Assigned(BACKENDS[I].Quit) and BACKENDS[I].Probe() then
      BACKENDS[I].Quit();
end;

function WindowPumpOnce: Boolean;
var
  LDid: Boolean;
begin
  { 零活窗快速路径：避免多后端 Live 计数与潜在锁竞争（gtk 聚合 LiveGtkSmart） }
  if (FakeLiveWindowCount = 0) and (SdlLiveWindowCount = 0)
     and (WasmLiveWindowCount = 0) and (AndroidLiveWindowCount = 0)
     and (UIKitLiveWindowCount = 0) and (LiveGtkSmart = 0)
     and (Win32LiveWindowCount = 0) and (CocoaLiveWindowCount = 0) then
    Exit(False);
  Result := False;
  if FakeHasPendingPosts then
  begin
    FakePumpAll;
    Result := True;
  end;
  if SdlLiveWindowCount > 0 then
  begin
    LDid := SdlPollAndDispatchOnce;
    if LDid then Result := True;
  end;
  if WasmLiveWindowCount > 0 then
    if WasmPumpOnce then Result := True;
  if AndroidLiveWindowCount > 0 then
    if AndroidPumpOnce then Result := True;
  if UIKitLiveWindowCount > 0 then
    if UIKitPumpOnce then Result := True;
end;

procedure WindowPumpAll;
begin
  while WindowPumpOnce do ;
end;

{ ---- Builder ---- }

type
  TBuilderImpl = class(TInterfacedObject, IWindowBuilder)
  private
    FOptions: TWindowOptions;
    FKind: TWindowKind;
    FKindSet: Boolean;
  public
    constructor Create;
    function Kind(AKind: TWindowKind): IWindowBuilder;
    function Title(const ATitle: string): IWindowBuilder;
    function Size(AWidth, AHeight: Integer): IWindowBuilder;
    function MinSize(AWidth, AHeight: Integer): IWindowBuilder;
    function MaxSize(AWidth, AHeight: Integer): IWindowBuilder;
    function Resizable(AResizable: Boolean): IWindowBuilder;
    function StartMaximized(AMaximized: Boolean): IWindowBuilder;
    function Parent(AHandle: TWindowNativeHandle): IWindowBuilder;
    function Options(const AOptions: TWindowOptions): IWindowBuilder;
    function Build: IWindow;
  end;

constructor TBuilderImpl.Create;
begin
  inherited Create;
  FOptions := DefaultWindowOptions;
  FKind := wkFake;
  FKindSet := False;
end;

function TBuilderImpl.Kind(AKind: TWindowKind): IWindowBuilder;
begin
  FKind := AKind;
  FKindSet := True;
  Result := Self;
end;

function TBuilderImpl.Title(const ATitle: string): IWindowBuilder;
begin
  FOptions.Title := ATitle;
  Result := Self;
end;

function TBuilderImpl.Size(AWidth, AHeight: Integer): IWindowBuilder;
begin
  FOptions.Width := AWidth;
  FOptions.Height := AHeight;
  Result := Self;
end;

function TBuilderImpl.MinSize(AWidth, AHeight: Integer): IWindowBuilder;
begin
  FOptions.MinWidth := AWidth;
  FOptions.MinHeight := AHeight;
  Result := Self;
end;

function TBuilderImpl.MaxSize(AWidth, AHeight: Integer): IWindowBuilder;
begin
  FOptions.MaxWidth := AWidth;
  FOptions.MaxHeight := AHeight;
  Result := Self;
end;

function TBuilderImpl.Resizable(AResizable: Boolean): IWindowBuilder;
begin
  FOptions.Resizable := AResizable;
  Result := Self;
end;

function TBuilderImpl.StartMaximized(AMaximized: Boolean): IWindowBuilder;
begin
  FOptions.Maximized := AMaximized;
  Result := Self;
end;

function TBuilderImpl.Parent(AHandle: TWindowNativeHandle): IWindowBuilder;
begin
  FOptions.ParentHandle := AHandle;
  Result := Self;
end;

function TBuilderImpl.Options(const AOptions: TWindowOptions): IWindowBuilder;
begin
  FOptions := AOptions;
  Result := Self;
end;

function TBuilderImpl.Build: IWindow;
var
  LKind: TWindowKind;
begin
  if FKindSet then
    LKind := FKind
  else
    LKind := DefaultWindowKind;
  Result := CreateWindowOf(LKind, FOptions);
end;

class function TWindowBuilder.New: IWindowBuilder;
begin
  Result := TBuilderImpl.Create;
end;

end.
