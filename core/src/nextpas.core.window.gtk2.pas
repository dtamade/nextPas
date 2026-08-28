unit nextpas.core.window.gtk2;

{** @desc GTK2 后端（薄适配层，消费独立 L2 gtk2 家族）。
       共享实现见 nextpas.core.window.gtk.impl.inc，本单元仅保留
       uses 与族别名转发。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.base,
  nextpas.core.window.intf;

function WindowGtkIsAvailable: Boolean;
function CreateWindowGtk(const AOptions: TWindowOptions): IWindow;
function GtkLiveWindowCount: Integer;
procedure WindowGtkRunMainLoop;
procedure WindowGtkQuitMainLoop;

{ 族显式别名（gtk2） }
function WindowGtk2IsAvailable: Boolean;
function CreateWindowGtk2(const AOptions: TWindowOptions): IWindow;
function Gtk2LiveWindowCount: Integer;
procedure WindowGtk2RunMainLoop;
procedure WindowGtk2QuitMainLoop;

implementation

uses
  nextpas.core.math,
  nextpas.core.errors,
  nextpas.core.text.ansi,
  nextpas.core.platform.thread,
  nextpas.core.sync.intf,
  nextpas.core.sync.mutex,
  nextpas.core.gtk2.base,
  nextpas.core.gtk2.ffi,
  nextpas.core.gtk2.loader,
  nextpas.core.window.live;

type
  TGtkLoadInfo = TGtk2LoadInfo;

function TryLoadGtk(out AInfo: TGtkLoadInfo): Boolean;
begin
  Result := TryLoadGtk2(AInfo);
end;

{$I nextpas.core.window.gtk.impl.inc}

function WindowGtk2IsAvailable: Boolean;
begin
  Result := WindowGtkIsAvailable;
end;

function CreateWindowGtk2(const AOptions: TWindowOptions): IWindow;
begin
  Result := CreateWindowGtk(AOptions);
end;

function Gtk2LiveWindowCount: Integer;
begin
  Result := GtkLiveWindowCount;
end;

procedure WindowGtk2RunMainLoop;
begin
  WindowGtkRunMainLoop;
end;

procedure WindowGtk2QuitMainLoop;
begin
  WindowGtkQuitMainLoop;
end;

finalization
  GLiveRegistry.Free;

end.
