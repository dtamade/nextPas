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
function WindowGtk2IsAvailable: Boolean; inline;
function CreateWindowGtk2(const AOptions: TWindowOptions): IWindow; inline;
function Gtk2LiveWindowCount: Integer; inline;
procedure WindowGtk2RunMainLoop; inline;
procedure WindowGtk2QuitMainLoop; inline;
{ 兼容旧命名 }
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
  nextpas.core.gtk2.base,
  nextpas.core.gtk2.ffi,
  nextpas.core.gtk2.loader,
  nextpas.core.window.live;

type
  TGtkLoadInfo = TGtk2LoadInfo;

function TryLoadGtk(out AInfo: TGtkLoadInfo): Boolean; inline;
begin
  Result := TryLoadGtk2(AInfo);
end;

{$I nextpas.core.window.gtk.impl.inc}

function WindowGtk2IsAvailable: Boolean; inline;
begin
  Result := WindowGtkIsAvailable;
end;

function CreateWindowGtk2(const AOptions: TWindowOptions): IWindow; inline;
begin
  Result := CreateWindowGtk(AOptions);
end;

function Gtk2LiveWindowCount: Integer; inline;
begin
  Result := GtkLiveWindowCount;
end;

procedure WindowGtk2RunMainLoop; inline;
begin
  WindowGtkRunMainLoop;
end;

procedure WindowGtk2QuitMainLoop; inline;
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
