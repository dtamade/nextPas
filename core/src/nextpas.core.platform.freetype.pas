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

{** @desc 加载 FreeType 动态库并解析符号（引用计数）
    @return FT_ERR_OK 成功，FT_ERR_LOAD_FAILED 加载失败 *}
function ft_load: Int32;

{** @desc 释放 FreeType 引用（引用计数归零时卸载） *}
procedure ft_unload;

{** @desc 检查 FreeType 是否已加载
    @return True 已加载 *}
function ft_is_loaded: Boolean;

implementation

var
  GLib: TPlatformLibrary;
  GLoaded: Boolean = False;
  GRefCount: Int32 = 0;

function TryLoadSymbol(const AName: PAnsiChar; out APtr: Pointer): Boolean;
begin
  Result := platform_dl_sym(GLib, AName, APtr) = 0;
end;

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

  if not TryLoadSymbol('FT_Init_FreeType', LPtr) then
  begin ft_unload; Exit(FT_ERR_LOAD_FAILED); end;
  Pointer(FT_Init_FreeType) := LPtr;

  if not TryLoadSymbol('FT_Done_FreeType', LPtr) then
  begin ft_unload; Exit(FT_ERR_LOAD_FAILED); end;
  Pointer(FT_Done_FreeType) := LPtr;

  if not TryLoadSymbol('FT_New_Face', LPtr) then
  begin ft_unload; Exit(FT_ERR_LOAD_FAILED); end;
  Pointer(FT_New_Face) := LPtr;

  if not TryLoadSymbol('FT_Done_Face', LPtr) then
  begin ft_unload; Exit(FT_ERR_LOAD_FAILED); end;
  Pointer(FT_Done_Face) := LPtr;

  if not TryLoadSymbol('FT_Set_Pixel_Sizes', LPtr) then
  begin ft_unload; Exit(FT_ERR_LOAD_FAILED); end;
  Pointer(FT_Set_Pixel_Sizes) := LPtr;

  if not TryLoadSymbol('FT_Load_Glyph', LPtr) then
  begin ft_unload; Exit(FT_ERR_LOAD_FAILED); end;
  Pointer(FT_Load_Glyph) := LPtr;

  if not TryLoadSymbol('FT_Get_Char_Index', LPtr) then
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
