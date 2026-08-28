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
function WindowGtk4IsAvailable: Boolean; inline;
function CreateWindowGtk4(const AOptions: TWindowOptions): IWindow; inline;
function Gtk4LiveWindowCount: Integer; inline;
procedure WindowGtk4RunMainLoop; inline;
procedure WindowGtk4QuitMainLoop; inline;
{ 兼容旧命名（历史 shim 曾透出 gtk3 名，保留转发） }
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
  nextpas.core.gtk4.base,
  nextpas.core.gtk4.ffi,
  nextpas.core.gtk4.loader,
  nextpas.core.window.live;

type
  TGtkLoadInfo = TGtk4LoadInfo;

function TryLoadGtk(out AInfo: TGtkLoadInfo): Boolean; inline;
begin
  Result := TryLoadGtk4(AInfo);
end;

{$I nextpas.core.window.gtk.impl.inc}

function WindowGtk4IsAvailable: Boolean; inline;
begin
  Result := WindowGtkIsAvailable;
end;

function CreateWindowGtk4(const AOptions: TWindowOptions): IWindow; inline;
begin
  Result := CreateWindowGtk(AOptions);
end;

function Gtk4LiveWindowCount: Integer; inline;
begin
  Result := GtkLiveWindowCount;
end;

procedure WindowGtk4RunMainLoop; inline;
begin
  WindowGtkRunMainLoop;
end;

procedure WindowGtk4QuitMainLoop; inline;
begin
  WindowGtkQuitMainLoop;
end;

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
