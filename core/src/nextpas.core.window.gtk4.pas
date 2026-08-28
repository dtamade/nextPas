unit nextpas.core.window.gtk4;

{** @desc GTK4 后端（薄适配层，消费独立 L2 gtk4 家族）。
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

{ 族显式别名（gtk4） }
function WindowGtk4IsAvailable: Boolean;
function CreateWindowGtk4(const AOptions: TWindowOptions): IWindow;
function Gtk4LiveWindowCount: Integer;
procedure WindowGtk4RunMainLoop;
procedure WindowGtk4QuitMainLoop;

implementation

uses
  nextpas.core.math,
  nextpas.core.errors,
  nextpas.core.text.ansi,
  nextpas.core.platform.thread,
  nextpas.core.sync.intf,
  nextpas.core.sync.mutex,
  nextpas.core.gtk4.base,
  nextpas.core.gtk4.ffi,
  nextpas.core.gtk4.loader,
  nextpas.core.window.live;

type
  TGtkLoadInfo = TGtk4LoadInfo;

function TryLoadGtk(out AInfo: TGtkLoadInfo): Boolean;
begin
  Result := TryLoadGtk4(AInfo);
end;

{$I nextpas.core.window.gtk.impl.inc}

function WindowGtk4IsAvailable: Boolean;
begin
  Result := WindowGtkIsAvailable;
end;

function CreateWindowGtk4(const AOptions: TWindowOptions): IWindow;
begin
  Result := CreateWindowGtk(AOptions);
end;

function Gtk4LiveWindowCount: Integer;
begin
  Result := GtkLiveWindowCount;
end;

procedure WindowGtk4RunMainLoop;
begin
  WindowGtkRunMainLoop;
end;

procedure WindowGtk4QuitMainLoop;
begin
  WindowGtkQuitMainLoop;
end;

finalization
  GLiveRegistry.Free;

end.
