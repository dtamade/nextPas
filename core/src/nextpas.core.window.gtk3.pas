unit nextpas.core.window.gtk3;

{** @desc GTK3 后端（薄适配层，消费独立 L2 gtk3 家族）。
       共享实现见 nextpas.core.window.gtk.impl.inc，本单元仅保留
       uses 与族别名转发，消除与 gtk4/gtk2 的 786 行重复。 *}

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

{ 族显式别名（与旧 shim 兼容） }
function WindowGtk3IsAvailable: Boolean; inline;
function CreateWindowGtk3(const AOptions: TWindowOptions): IWindow; inline;
function Gtk3LiveWindowCount: Integer; inline;
procedure WindowGtk3RunMainLoop; inline;
procedure WindowGtk3QuitMainLoop; inline;

implementation

uses
  Math,
  SysUtils,
  nextpas.core.errors,
  nextpas.core.platform.thread,
  nextpas.core.sync.intf,
  nextpas.core.sync.mutex,
  nextpas.core.gtk3.base,
  nextpas.core.gtk3.ffi,
  nextpas.core.gtk3.loader,
  nextpas.core.window.live;

type
  TGtkLoadInfo = TGtk3LoadInfo;

function TryLoadGtk(out AInfo: TGtkLoadInfo): Boolean; inline;
begin
  Result := TryLoadGtk3(AInfo);
end;

{$I nextpas.core.window.gtk.impl.inc}

function WindowGtk3IsAvailable: Boolean; inline;
begin
  Result := WindowGtkIsAvailable;
end;

function CreateWindowGtk3(const AOptions: TWindowOptions): IWindow; inline;
begin
  Result := CreateWindowGtk(AOptions);
end;

function Gtk3LiveWindowCount: Integer; inline;
begin
  Result := GtkLiveWindowCount;
end;

procedure WindowGtk3RunMainLoop; inline;
begin
  WindowGtkRunMainLoop;
end;

procedure WindowGtk3QuitMainLoop; inline;
begin
  WindowGtkQuitMainLoop;
end;

end.
