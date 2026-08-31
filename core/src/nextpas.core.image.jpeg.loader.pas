{**
 * nextpas.core.image.jpeg.loader - libjpeg 动态加载器（platform.dl）
 * 封装 dlopen/dlsym 探针与句柄生命周期；上层仅问 IsAvailable。
 *}
unit nextpas.core.image.jpeg.loader;

{$I nextpas.core.settings.inc}

interface

function JpegLoaderIsAvailable: Boolean;
function JpegLoaderProbe: Boolean;

implementation

uses
  nextpas.core.platform.dl,
  nextpas.core.image.jpeg.ffi;

var
  GLib: TPlatformLibrary;
  GProbed: Boolean;
  GAvail: Boolean;

function JpegLoaderProbe: Boolean;
var
  I: Integer;
  Lib: TPlatformLibrary;
  P: Pointer;
begin
  if GProbed then Exit(GAvail);
  GProbed := True;
  GAvail := False;
  for I := 0 to High(LIBJPEG_SO_NAMES) do
  begin
    if platform_dl_load(LIBJPEG_SO_NAMES[I], [dlfLazy], Lib) then
    begin
      P := platform_dl_symbol(Lib, LIBJPEG_PROBE_SYMBOL);
      if P <> nil then
      begin
        GLib := Lib;
        GAvail := True;
        Exit(True);
      end;
      platform_dl_release(Lib);
    end;
  end;
  Result := False;
end;

function JpegLoaderIsAvailable: Boolean;
begin
  Result := JpegLoaderProbe;
end;

initialization

finalization
  platform_dl_release(GLib);

end.
