unit nextpas.core.gtk4;

{** @desc nextpas.core.gtk4 门面：聚合 re-export GTK4 家族公共 API。
       依赖方向 base ← ffi ← loader ← 门面；与 gtk3/window.gtk 互不依赖。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.gtk4.base,
  nextpas.core.gtk4.ffi,
  nextpas.core.gtk4.loader;

const
  GTK_WINDOW_TOPLEVEL = nextpas.core.gtk4.base.GTK_WINDOW_TOPLEVEL;
  GDK_WINDOW_STATE_WITHDRAWN = nextpas.core.gtk4.base.GDK_WINDOW_STATE_WITHDRAWN;
  GDK_WINDOW_STATE_ICONIFIED = nextpas.core.gtk4.base.GDK_WINDOW_STATE_ICONIFIED;
  GDK_WINDOW_STATE_MAXIMIZED = nextpas.core.gtk4.base.GDK_WINDOW_STATE_MAXIMIZED;
  GDK_SURFACE_STATE_WITHDRAWN = nextpas.core.gtk4.base.GDK_SURFACE_STATE_WITHDRAWN;
  GDK_SURFACE_STATE_ICONIFIED = nextpas.core.gtk4.base.GDK_SURFACE_STATE_ICONIFIED;
  GDK_SURFACE_STATE_MAXIMIZED = nextpas.core.gtk4.base.GDK_SURFACE_STATE_MAXIMIZED;
  GLIB_SOURCE_REMOVE = nextpas.core.gtk4.base.GLIB_SOURCE_REMOVE;
  GLIB_SOURCE_CONTINUE = nextpas.core.gtk4.base.GLIB_SOURCE_CONTINUE;
  G_PRIORITY_DEFAULT = nextpas.core.gtk4.base.G_PRIORITY_DEFAULT;

type
  TGtk4LoadInfo = nextpas.core.gtk4.loader.TGtk4LoadInfo;

function TryLoadGtk4(out AInfo: TGtk4LoadInfo): Boolean; inline;
procedure UnloadGtk4; inline;
function Gtk4LoadInfo: TGtk4LoadInfo; inline;
function Gtk4IsLoaded: Boolean; inline;

implementation

function TryLoadGtk4(out AInfo: TGtk4LoadInfo): Boolean;
begin
  Result := nextpas.core.gtk4.loader.TryLoadGtk4(AInfo);
end;

procedure UnloadGtk4;
begin
  nextpas.core.gtk4.loader.UnloadGtk4;
end;

function Gtk4LoadInfo: TGtk4LoadInfo;
begin
  Result := nextpas.core.gtk4.loader.Gtk4LoadInfo;
end;

function Gtk4IsLoaded: Boolean;
begin
  Result := nextpas.core.gtk4.loader.Gtk4IsLoaded;
end;

end.
