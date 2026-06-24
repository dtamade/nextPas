unit nextpas.core.platform.freetype;

{$I nextpas.core.settings.inc}

// FreeType 2 runtime loader.
//
// Loads libfreetype.so.6 via dlopen/dlsym at runtime. Avoids hard link
// dependency so binaries run without FreeType installed.
// Ref-counted load/unload for nested use (e.g. multiple font instances).

interface

uses
  nextpas.core.platform.dl,
  nextpas.core.platform.freetype.ffi;

const
  FT_ERR_NOT_LOADED  = -1;
  FT_ERR_LOAD_FAILED = -2;

function ft_load: Int32;
procedure ft_unload;
function ft_is_loaded: Boolean;

implementation

var
  GLib: TPlatformLibrary;
  GLoaded: Boolean = False;
  GRefCount: Int32 = 0;

function ft_load: Int32;
var
  LPtr: Pointer;
begin
  if GLoaded then
  begin
    Inc(GRefCount);
    Exit(FT_ERR_OK);
  end;

  if platform_dl_open('libfreetype.so.6', PLATFORM_DL_NOW, GLib) <> 0 then
    Exit(FT_ERR_LOAD_FAILED);

  if platform_dl_sym(GLib, 'FT_Init_FreeType', LPtr) <> 0 then
  begin ft_unload; Exit(FT_ERR_LOAD_FAILED); end;
  Pointer(FT_Init_FreeType) := LPtr;

  if platform_dl_sym(GLib, 'FT_Done_FreeType', LPtr) <> 0 then
  begin ft_unload; Exit(FT_ERR_LOAD_FAILED); end;
  Pointer(FT_Done_FreeType) := LPtr;

  if platform_dl_sym(GLib, 'FT_New_Face', LPtr) <> 0 then
  begin ft_unload; Exit(FT_ERR_LOAD_FAILED); end;
  Pointer(FT_New_Face) := LPtr;

  if platform_dl_sym(GLib, 'FT_Done_Face', LPtr) <> 0 then
  begin ft_unload; Exit(FT_ERR_LOAD_FAILED); end;
  Pointer(FT_Done_Face) := LPtr;

  if platform_dl_sym(GLib, 'FT_Set_Pixel_Sizes', LPtr) <> 0 then
  begin ft_unload; Exit(FT_ERR_LOAD_FAILED); end;
  Pointer(FT_Set_Pixel_Sizes) := LPtr;

  if platform_dl_sym(GLib, 'FT_Load_Glyph', LPtr) <> 0 then
  begin ft_unload; Exit(FT_ERR_LOAD_FAILED); end;
  Pointer(FT_Load_Glyph) := LPtr;

  if platform_dl_sym(GLib, 'FT_Get_Char_Index', LPtr) <> 0 then
  begin ft_unload; Exit(FT_ERR_LOAD_FAILED); end;
  Pointer(FT_Get_Char_Index) := LPtr;

  GLoaded := True;
  GRefCount := 1;
  Result := FT_ERR_OK;
end;

procedure ft_unload;
begin
  if not GLoaded then
    Exit;
  Dec(GRefCount);
  if GRefCount > 0 then
    Exit;

  Pointer(FT_Init_FreeType) := nil;
  Pointer(FT_Done_FreeType) := nil;
  Pointer(FT_New_Face) := nil;
  Pointer(FT_Done_Face) := nil;
  Pointer(FT_Set_Pixel_Sizes) := nil;
  Pointer(FT_Load_Glyph) := nil;
  Pointer(FT_Get_Char_Index) := nil;
  platform_dl_close(GLib);
  GLoaded := False;
end;

function ft_is_loaded: Boolean;
begin
  Result := GLoaded;
end;

end.
