unit nextpas.core.platform.freetype.ffi;

{$I nextpas.core.settings.inc}

{**
 * FreeType 2 FFI declarations — 最小子集用于字形光栅化
 *
 * 类型、常量和类型化函数指针全局变量，用于 libfreetype 的以下功能：
 *   - 加载 TrueType/OpenType 字体文件
 *   - 设置像素大小
 *   - 加载和渲染字形到位图
 *
 * 所有结构体偏移量已在 x86_64 上通过 gcc offsetof 验证。
 * 零实现逻辑 — 伴生单元 nextpas.core.platform.freetype 处理加载。
 *}

interface

{$PACKRECORDS 1}

type
  {** @desc FreeType 库句柄（不透明） *}
  FT_Library  = type Pointer;
  {** @desc FreeType 字体面句柄（不透明） *}
  FT_Face     = type Pointer;
  {** @desc FreeType 编码类型 *}
  FT_Encoding = type UInt32;

  { 标量类型 — 已通过 gcc sizeof 验证 }
  {** @desc FreeType 错误码 *}
  FT_Error = type Int32;
  {** @desc FreeType 无符号整数 *}
  FT_UInt  = type UInt32;
  {** @desc FreeType 有符号整数 *}
  FT_Int   = type Int32;
  {** @desc FreeType 长整型 *}
  FT_Long  = type Int64;
  {** @desc FreeType 无符号长整型 *}
  FT_ULong = type UInt64;
  {** @desc FreeType 16.16 定点数 *}
  FT_Fixed = type Int64;
  {** @desc FreeType 26.6 定点数 *}
  FT_Pos   = type Int64;
  {** @desc FreeType 26.6 定点数（用于字体大小） *}
  FT_F26Dot6 = type Int64;

  {** @desc 2D 向量 — 16 字节 *}
  FT_Vector = record
    X: FT_Pos;
    Y: FT_Pos;
  end;

  {** @desc 字形度量 — 40 字节 *}
  FT_Glyph_Metrics = record
    Width: FT_Pos;             { offset 0 }
    Height: FT_Pos;            { offset 8 }
    HoriBearingX: FT_Pos;      { offset 16 }
    HoriBearingY: FT_Pos;      { offset 24 }
    HoriAdvance: FT_Pos;       { offset 32 }
    VertBearingX: FT_Pos;
    VertBearingY: FT_Pos;
    VertAdvance: FT_Pos;
  end;

  {** @desc 位图描述符 — 40 字节
      @note PACKRECORDS 1 需要显式填充以满足指针对齐 *}
  FT_Bitmap = record
    Rows: UInt32;              { offset 0 }
    Width: UInt32;             { offset 4 }
    Pitch: Int32;              { offset 8 (signed, can be negative) }
    _pad0: array[0..3] of Byte; { offset 12: padding for 8-byte alignment }
    Buffer: PByte;             { offset 16 }
    NumGrays: UInt16;          { offset 24 }
    PaletteMode: Byte;         { offset 26 }
    PixelMode: Byte;           { offset 27 }
    _pad1: array[0..3] of Byte; { offset 28: padding for pointer alignment }
    Palette: Pointer;          { offset 32 }
  end;

  {** @desc FreeType 通用结构体 *}
  FT_Generic = record
    Data: Pointer;
    Finalizer: Pointer;
  end;

  { 指针类型用于间接访问 }
  PFT_GlyphSlotRec = ^FT_GlyphSlotRec;
  PFT_Bitmap = ^FT_Bitmap;
  PFT_Glyph_Metrics = ^FT_Glyph_Metrics;

  { FT_GlyphSlotRec — the glyph slot structure.
    PACKRECORDS 1 requires explicit padding. All offsets gcc verified.
      library      @ 0   (8 bytes, Pointer)
      face         @ 8   (8 bytes, Pointer)
      next         @ 16  (8 bytes, Pointer)
      glyph_index  @ 24  (4 bytes, FT_UInt)
      metrics      @ 48  (64 bytes, FT_Glyph_Metrics)
      advance      @ 128 (16 bytes, FT_Vector)
      bitmap       @ 152 (40 bytes, FT_Bitmap)
      bitmap_left  @ 192 (4 bytes, FT_Int)
      bitmap_top   @ 196 (4 bytes, FT_Int)
  }
  FT_GlyphSlotRec = record
    _pad0: array[0..23] of Byte;   { 0-23: library, face, next }
    GlyphIndex: FT_UInt;           { offset 24 }
    _pad1: array[0..19] of Byte;   { 28-47: padding to metrics }
    Metrics: FT_Glyph_Metrics;     { offset 48, 64 bytes }
    _pad2: array[0..15] of Byte;   { 112-127: padding to advance }
    Advance: FT_Vector;            { offset 128, 16 bytes }
    _pad3: array[0..7] of Byte;    { 144-151: padding to bitmap }
    Bitmap: FT_Bitmap;             { offset 152, 40 bytes }
    BitmapLeft: FT_Int;            { offset 192 }
    BitmapTop: FT_Int;             { offset 196 }
    { rest of struct is unused for rasterization }
  end;

const
  { Pixel modes }
  FT_PIXEL_MODE_NONE = 0;
  FT_PIXEL_MODE_MONO = 1;
  FT_PIXEL_MODE_GRAY = 2;

  { Load flags }
  FT_LOAD_DEFAULT = 0;
  FT_LOAD_RENDER  = 4;

  { Encoding }
  FT_ENCODING_UNICODE = $00746E55;  { 'Unic' }

  { Error codes }
  FT_ERR_OK = 0;

type
  { --- FreeType function pointer types --- }

  TFT_Init_FreeType = function(out ALibrary: FT_Library): FT_Error; cdecl;
  TFT_Done_FreeType = function(ALibrary: FT_Library): FT_Error; cdecl;
  TFT_New_Face = function(ALibrary: FT_Library;
    AFilePath: PAnsiChar; AFaceIndex: FT_Long;
    out AFace: FT_Face): FT_Error; cdecl;
  TFT_Done_Face = function(AFace: FT_Face): FT_Error; cdecl;
  TFT_Set_Pixel_Sizes = function(AFace: FT_Face;
    APixelWidth, APixelHeight: FT_UInt): FT_Error; cdecl;
  TFT_Load_Glyph = function(AFace: FT_Face; AGlyphIndex: FT_UInt;
    ALoadFlags: Int32): FT_Error; cdecl;
  TFT_Get_Char_Index = function(AFace: FT_Face;
    ACharCode: FT_ULong): FT_UInt; cdecl;

var
  FT_Init_FreeType: TFT_Init_FreeType;
  FT_Done_FreeType: TFT_Done_FreeType;
  FT_New_Face: TFT_New_Face;
  FT_Done_Face: TFT_Done_Face;
  FT_Set_Pixel_Sizes: TFT_Set_Pixel_Sizes;
  FT_Load_Glyph: TFT_Load_Glyph;
  FT_Get_Char_Index: TFT_Get_Char_Index;

implementation

end.
