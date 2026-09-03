unit nextpas.core.window.probe;

{** @desc window 后端探测聚合（工厂持 loader 真相；base 不知）。

       职责：单一 dlopen 探测事实源，8 后端 + gtk 家族 3 + qt 2，
       进程级幂等（loader 内已缓存 GLoaded），零堆分配，冷路径
       非 inline（dlopen 路由体禁 inline，守 I-Cache）。 *}

{$I nextpas.core.settings.inc}

interface

function ProbeFake: Boolean;
function ProbeGtk3: Boolean;
function ProbeGtk4: Boolean;
function ProbeGtk2: Boolean;
function ProbeGtk: Boolean;
function ProbeQt5Pas: Boolean;
function ProbeQt: Boolean;
function ProbeSdl2: Boolean;
function ProbeWin32: Boolean;
function ProbeCocoa: Boolean;
function ProbeWasm: Boolean;
function ProbeAndroid: Boolean;
function ProbeUIKit: Boolean;

implementation

uses
  nextpas.core.gtk3.loader,
  nextpas.core.gtk4.loader,
  nextpas.core.gtk2.loader,
  nextpas.core.qt5pas.loader,
  nextpas.core.qt.loader,
  nextpas.core.window.sdl2.loader,
  nextpas.core.window.win32.loader,
  nextpas.core.window.cocoa.loader,
  nextpas.core.window.wasm.loader,
  nextpas.core.window.android.loader,
  nextpas.core.window.uikit.loader;

function ProbeFake: Boolean;
begin
  Result := True;
end;

function ProbeGtk3: Boolean;
var L: TGtk3LoadInfo;
begin
  Result := TryLoadGtk3(L) and L.Loaded;
end;

function ProbeGtk4: Boolean;
var L: TGtk4LoadInfo;
begin
  Result := TryLoadGtk4(L) and L.Loaded;
end;

function ProbeGtk2: Boolean;
var L: TGtk2LoadInfo;
begin
  Result := TryLoadGtk2(L) and L.Loaded;
end;

function ProbeGtk: Boolean;
begin
  // gtk 聚合探测：gtk4 > gtk3 > gtk2 任一可用即视为 wkGtk 可用（智能回退，与 registry CreateGtkSmart 同源）
  Result := ProbeGtk4 or ProbeGtk3 or ProbeGtk2;
end;

function ProbeQt5Pas: Boolean;
var L: TQt5PasLoadInfo;
begin
  Result := TryLoadQt5Pas(L) and L.Loaded;
end;

function ProbeQt: Boolean;
var L: TQtLoadInfo;
begin
  Result := TryLoadQt(L) and L.Loaded;
end;

function ProbeSdl2: Boolean;
var L: TWindowSdl2LoadInfo;
begin
  Result := TryLoadWindowSdl2(L) and L.Loaded;
end;

function ProbeWin32: Boolean;
var L: TWindowWin32LoadInfo;
begin
  Result := TryLoadWindowWin32(L) and L.Loaded;
end;

function ProbeCocoa: Boolean;
var L: TWindowCocoaLoadInfo;
begin
  Result := TryLoadWindowCocoa(L) and L.Loaded;
end;

function ProbeWasm: Boolean;
var L: TWindowWasmLoadInfo;
begin
  Result := TryLoadWindowWasm(L) and L.Loaded;
end;

function ProbeAndroid: Boolean;
var L: TWindowAndroidLoadInfo;
begin
  Result := TryLoadWindowAndroid(L) and L.Loaded;
end;

function ProbeUIKit: Boolean;
var L: TWindowUIKitLoadInfo;
begin
  Result := TryLoadWindowUIKit(L) and L.Loaded;
end;

end.
