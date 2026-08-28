unit nextpas.core.gtk2;

{** @desc nextpas.core.gtk2 门面：聚合 re-export GTK2 家族公共 API。
       依赖方向 base ← ffi ← loader ← 门面；与 gtk3/gtk4 互不依赖。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.gtk2.base,
  nextpas.core.gtk2.ffi,
  nextpas.core.gtk2.loader;

const
  GTK_WINDOW_TOPLEVEL = nextpas.core.gtk2.base.GTK_WINDOW_TOPLEVEL;
  GDK_WINDOW_STATE_WITHDRAWN = nextpas.core.gtk2.base.GDK_WINDOW_STATE_WITHDRAWN;
  GDK_WINDOW_STATE_ICONIFIED = nextpas.core.gtk2.base.GDK_WINDOW_STATE_ICONIFIED;
  GDK_WINDOW_STATE_MAXIMIZED = nextpas.core.gtk2.base.GDK_WINDOW_STATE_MAXIMIZED;
  GLIB_SOURCE_REMOVE = nextpas.core.gtk2.base.GLIB_SOURCE_REMOVE;
  GLIB_SOURCE_CONTINUE = nextpas.core.gtk2.base.GLIB_SOURCE_CONTINUE;
  G_PRIORITY_DEFAULT = nextpas.core.gtk2.base.G_PRIORITY_DEFAULT;

type
  TGtk2LoadInfo = nextpas.core.gtk2.loader.TGtk2LoadInfo;

function TryLoadGtk2(out AInfo: TGtk2LoadInfo): Boolean; inline;
procedure UnloadGtk2; inline;
function Gtk2LoadInfo: TGtk2LoadInfo; inline;
function Gtk2IsLoaded: Boolean; inline;

implementation

function TryLoadGtk2(out AInfo: TGtk2LoadInfo): Boolean;
begin
  Result := nextpas.core.gtk2.loader.TryLoadGtk2(AInfo);
end;

procedure UnloadGtk2;
begin
  nextpas.core.gtk2.loader.UnloadGtk2;
end;

function Gtk2LoadInfo: TGtk2LoadInfo;
begin
  Result := nextpas.core.gtk2.loader.Gtk2LoadInfo;
end;

function Gtk2IsLoaded: Boolean;
begin
  Result := nextpas.core.gtk2.loader.Gtk2IsLoaded;
end;

end.
