unit nextpas.core.gtk3;

{** @desc nextpas.core.gtk3 门面：聚合 re-export GTK3 公共能力，不含逻辑。
       消费方大多数时候只需 uses 本单元；需更细粒度时可改引 base/ffi/loader。

       依赖方向：base ← ffi ← loader ← 门面（design-conventions §2）。
       纹理：显式 type 别名 + inline 转发 loader 函数，纯 re-export。 *}

{$I nextpas.core.settings.inc}
{$IF 0}
{$mode objfpc}{$H+}
{$ENDIF}

interface

uses
  nextpas.core.gtk3.base,
  nextpas.core.gtk3.ffi,
  nextpas.core.gtk3.loader;

{ ---- 类型：base 标量与常量载体 ---- }

type
  gboolean = nextpas.core.gtk3.base.gboolean;
  guint = nextpas.core.gtk3.base.guint;
  gulong = nextpas.core.gtk3.base.gulong;
  guint32 = nextpas.core.gtk3.base.guint32;
  gint = nextpas.core.gtk3.base.gint;

  {** 回调（ffi） *}
  TGCallback = nextpas.core.gtk3.ffi.TGCallback;
  TGDestroyNotify = nextpas.core.gtk3.ffi.TGDestroyNotify;
  TGIdleFunc = nextpas.core.gtk3.ffi.TGIdleFunc;
  TGtkDeleteEventFunc = nextpas.core.gtk3.ffi.TGtkDeleteEventFunc;
  TGtkConfigureEventFunc = nextpas.core.gtk3.ffi.TGtkConfigureEventFunc;
  TGtkFocusEventFunc = nextpas.core.gtk3.ffi.TGtkFocusEventFunc;
  TGtkWindowStateEventFunc = nextpas.core.gtk3.ffi.TGtkWindowStateEventFunc;
  TGtkNotifyScaleFunc = nextpas.core.gtk3.ffi.TGtkNotifyScaleFunc;
  TGtkDestroyFunc = nextpas.core.gtk3.ffi.TGtkDestroyFunc;

  {** 装载结果 *}
  TGtk3LoadInfo = nextpas.core.gtk3.loader.TGtk3LoadInfo;
  TWindowGtkLoadInfo = nextpas.core.gtk3.loader.TWindowGtkLoadInfo;

const
  GDK_WINDOW_STATE_WITHDRAWN  = nextpas.core.gtk3.base.GDK_WINDOW_STATE_WITHDRAWN;
  GDK_WINDOW_STATE_ICONIFIED  = nextpas.core.gtk3.base.GDK_WINDOW_STATE_ICONIFIED;
  GDK_WINDOW_STATE_MAXIMIZED  = nextpas.core.gtk3.base.GDK_WINDOW_STATE_MAXIMIZED;
  GLIB_SOURCE_REMOVE   = nextpas.core.gtk3.base.GLIB_SOURCE_REMOVE;
  GLIB_SOURCE_CONTINUE = nextpas.core.gtk3.base.GLIB_SOURCE_CONTINUE;
  G_PRIORITY_DEFAULT   = nextpas.core.gtk3.base.G_PRIORITY_DEFAULT;
  GTK_WINDOW_TOPLEVEL  = nextpas.core.gtk3.base.GTK_WINDOW_TOPLEVEL;

{ ---- 函数：loader inline 转发 ---- }

function TryLoadGtk3(out AInfo: TGtk3LoadInfo): Boolean; inline;
procedure UnloadGtk3; inline;
function Gtk3LoadInfo: TGtk3LoadInfo; inline;
function Gtk3IsLoaded: Boolean; inline;

{ 兼容：window 侧历史名称 }
function TryLoadWindowGtk(out AInfo: TWindowGtkLoadInfo): Boolean; inline;
procedure UnloadWindowGtk; inline;
function WindowGtkLoadInfo: TWindowGtkLoadInfo; inline;
function WindowGtkIsLoaded: Boolean; inline;

implementation

function TryLoadGtk3(out AInfo: TGtk3LoadInfo): Boolean;
begin
  Result := nextpas.core.gtk3.loader.TryLoadGtk3(AInfo);
end;

procedure UnloadGtk3;
begin
  nextpas.core.gtk3.loader.UnloadGtk3;
end;

function Gtk3LoadInfo: TGtk3LoadInfo;
begin
  Result := nextpas.core.gtk3.loader.Gtk3LoadInfo;
end;

function Gtk3IsLoaded: Boolean;
begin
  Result := nextpas.core.gtk3.loader.Gtk3IsLoaded;
end;

function TryLoadWindowGtk(out AInfo: TWindowGtkLoadInfo): Boolean;
begin
  Result := nextpas.core.gtk3.loader.TryLoadWindowGtk(AInfo);
end;

procedure UnloadWindowGtk;
begin
  nextpas.core.gtk3.loader.UnloadWindowGtk;
end;

function WindowGtkLoadInfo: TWindowGtkLoadInfo;
begin
  Result := nextpas.core.gtk3.loader.WindowGtkLoadInfo;
end;

function WindowGtkIsLoaded: Boolean;
begin
  Result := nextpas.core.gtk3.loader.WindowGtkIsLoaded;
end;

end.
