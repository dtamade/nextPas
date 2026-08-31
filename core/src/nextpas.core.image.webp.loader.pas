{**
 * nextpas.core.image.webp.loader - libwebp 动态加载器
 *}
unit nextpas.core.image.webp.loader;

{$I nextpas.core.settings.inc}

interface

function WebPLoaderIsAvailable: Boolean;

implementation

uses
  nextpas.core.platform.dl,
  nextpas.core.image.webp.ffi;

var
  GLib: TPlatformLibrary;
  GProbed: Boolean;
  GAvail: Boolean;

function WebPLoaderProbe: Boolean;
var
  I, J: Integer;
  Lib: TPlatformLibrary;
  P: Pointer;
  Ok: Boolean;
begin
  if GProbed then Exit(GAvail);
  GProbed := True;
  GAvail := False;
  for I := 0 to High(LIBWEBP_SO_NAMES) do
  begin
    if platform_dl_load(LIBWEBP_SO_NAMES[I], [dlfLazy], Lib) then
    begin
      Ok := True;
      for J := 0 to High(LIBWEBP_PROBE_SYMBOLS) do
      begin
        P := platform_dl_symbol(Lib, LIBWEBP_PROBE_SYMBOLS[J]);
        if P = nil then begin Ok := False; Break; end;
      end;
      if Ok then
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

function WebPLoaderIsAvailable: Boolean;
begin
  Result := WebPLoaderProbe;
end;

initialization

finalization
  platform_dl_release(GLib);

end.
