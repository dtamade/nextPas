unit nextpas.core.window.wasm.loader;

{** @desc WASM canvas 动态装载（家族内唯一触 platform.dl 的单元）。
       原语一律来自 nextpas.core.platform.dl，禁用 FPC DynLibs。

       Emscripten 环境下 5 个 env import 经 dlsym(RTLD_DEFAULT) 探测；
       非 wasm 宿主（Linux/Windows/macOS）诚实失败（Loaded=False）。
       GetDevicePixelRatio 可选。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.dl,
  nextpas.core.window.wasm.ffi;

type
  TWindowWasmLoadInfo = record
    Loaded: Boolean;
    HasDevicePixelRatio: Boolean;
  end;

function TryLoadWindowWasm(out AInfo: TWindowWasmLoadInfo): Boolean;
procedure UnloadWindowWasm;
function WindowWasmLoadInfo: TWindowWasmLoadInfo;
function WindowWasmIsLoaded: Boolean;
const
  WINDOW_WASM_SONAMES = 'env:emscripten_*|libemscripten.so|libwasm.so';
function WindowWasmSonames: string; inline;

implementation

var
  GLoaded: Boolean = False;
  GLoading: Boolean = False;
  GInfo: TWindowWasmLoadInfo;
  GWasmLib: TPlatformLibrary;

function TryDlOpen(var ALib: TPlatformLibrary; const ASonames: array of string): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(ASonames) do
    if platform_dl_load(ASonames[I], [dlfLazy, dlfGlobal], ALib) then
      Exit(True);
  Result := False;
end;

function BindReq(AVarAddr: Pointer; const AName: string): Boolean;
var
  LAddr: Pointer;
begin
  if GWasmLib.Sym(PAnsiChar(AName), LAddr) = 0 then
  begin
    PPointer(AVarAddr)^ := LAddr;
    Exit(True);
  end;
  Result := False;
end;

procedure ReleaseAll;
begin
  platform_dl_release(GWasmLib);
end;

function TryLoadWindowWasm(out AInfo: TWindowWasmLoadInfo): Boolean;

  function BindAll: Boolean;
  begin
    Result :=
      BindReq(@emscripten_get_canvas_element_size, 'emscripten_get_canvas_element_size') and
      BindReq(@emscripten_set_canvas_element_size, 'emscripten_set_canvas_element_size') and
      BindReq(@emscripten_get_element_css_size, 'emscripten_get_element_css_size') and
      BindReq(@emscripten_set_element_css_size, 'emscripten_set_element_css_size');
    BindReq(@emscripten_get_device_pixel_ratio, 'emscripten_get_device_pixel_ratio');
  end;

begin
  if GLoaded then
  begin
    AInfo := GInfo;
    Exit(True);
  end;
  if GLoading then Exit(False);
  FillChar(AInfo, SizeOf(AInfo), 0);
  GLoading := True;
  try
    // On non-wasm hosts, there is no env import library → honest unavailable.
    // Try RTLD_DEFAULT via empty soname trick: platform_dl_load('') may return current exe.
    // If that fails, we simply report not loaded.
    if not TryDlOpen(GWasmLib, ['']) then
    begin
      // Fallback: try to probe via explicit emscripten soname (unlikely on Linux)
      if not TryDlOpen(GWasmLib, ['libemscripten.so', 'libwasm.so']) then
      begin
        Exit(False);
      end;
    end;
    if not BindAll then
    begin
      ReleaseAll;
      Exit(False);
    end;
    // At least one of the canvas symbols must be present; otherwise not wasm
    GLoaded := True;
    GInfo.Loaded := True;
    GInfo.HasDevicePixelRatio := Assigned(emscripten_get_device_pixel_ratio);
    AInfo := GInfo;
    Result := True;
  finally
    GLoading := False;
  end;
end;

procedure UnloadWindowWasm;
begin
  if not GLoaded then Exit;
  ReleaseAll;
  GLoaded := False;
  GInfo := Default(TWindowWasmLoadInfo);
end;

function WindowWasmLoadInfo: TWindowWasmLoadInfo;
begin
  Result := GInfo;
end;

function WindowWasmIsLoaded: Boolean;
begin
  Result := GLoaded;
end;

function WindowWasmSonames: string; inline;
begin
  Result := WINDOW_WASM_SONAMES;
end;

end.
