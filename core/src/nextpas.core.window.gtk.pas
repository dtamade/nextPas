unit nextpas.core.window.gtk;

{** @desc GTK 后端 shim（deprecated since 2.0, removal 4.0）：纯转发至 nextpas.core.window.gtk3。
      11×4 严格下保留的唯一历史别名，零逻辑（8 inline forward），已冻结不再扩展；
      新代码请直接 uses nextpas.core.window.gtk3 或经 factory `TWindowBuilder`。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.base,
  nextpas.core.window.intf,
  nextpas.core.window.gtk3;

function WindowGtkIsAvailable: Boolean; inline;
function CreateWindowGtk(const AOptions: TWindowOptions): IWindow; inline;
function GtkLiveWindowCount: Integer; inline;
procedure WindowGtkRunMainLoop; inline;
procedure WindowGtkQuitMainLoop; inline;

{ 新命名别名（与 window.gtk3 一致） }
function WindowGtk3IsAvailable: Boolean; inline;
function CreateWindowGtk3(const AOptions: TWindowOptions): IWindow; inline;
function Gtk3LiveWindowCount: Integer; inline;
procedure WindowGtk3RunMainLoop; inline;
procedure WindowGtk3QuitMainLoop; inline;

implementation

function WindowGtkIsAvailable: Boolean;
begin
  Result := nextpas.core.window.gtk3.WindowGtkIsAvailable;
end;

function CreateWindowGtk(const AOptions: TWindowOptions): IWindow;
begin
  Result := nextpas.core.window.gtk3.CreateWindowGtk(AOptions);
end;

function GtkLiveWindowCount: Integer;
begin
  Result := nextpas.core.window.gtk3.GtkLiveWindowCount;
end;

procedure WindowGtkRunMainLoop;
begin
  nextpas.core.window.gtk3.WindowGtkRunMainLoop;
end;

procedure WindowGtkQuitMainLoop;
begin
  nextpas.core.window.gtk3.WindowGtkQuitMainLoop;
end;

function WindowGtk3IsAvailable: Boolean;
begin
  Result := nextpas.core.window.gtk3.WindowGtk3IsAvailable;
end;

function CreateWindowGtk3(const AOptions: TWindowOptions): IWindow;
begin
  Result := nextpas.core.window.gtk3.CreateWindowGtk3(AOptions);
end;

function Gtk3LiveWindowCount: Integer;
begin
  Result := nextpas.core.window.gtk3.Gtk3LiveWindowCount;
end;

procedure WindowGtk3RunMainLoop;
begin
  nextpas.core.window.gtk3.WindowGtk3RunMainLoop;
end;

procedure WindowGtk3QuitMainLoop;
begin
  nextpas.core.window.gtk3.WindowGtk3QuitMainLoop;
end;

end.
