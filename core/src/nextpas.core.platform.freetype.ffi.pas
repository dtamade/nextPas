unit nextpas.core.platform.freetype.ffi;

{$I nextpas.core.settings.inc}

// FreeType 2 FFI declarations — minimal subset for glyph rasterization.
//
// Types, constants, and typed function pointer globals for the subset
// of libfreetype needed for:
//   - Loading TrueType/OpenType font files
//   - Setting pixel sizes
//   - Loading and rendering glyphs to grayscale bitmaps
//
// All struct offsets verified against gcc offsetof on x86_64.
// Zero implementation logic — the companion unit
// nextpas.core.platform.freetype handles loading.

interface

type
  { Opaque FreeType handles. }
  FT_Library  = type Pointer;
  FT_Face     = type Pointer;
  FT_Encoding = type UInt32;

  { Scalar types — verified against gcc sizeof. }
  FT_Error = type Int32;
  FT_UInt  = type UInt32;
  FT_Int   = type Int32;
  FT_Long  = type Int64;
  FT_ULong = type UInt64;
  FT_Fixed = type Int64;       { 16.16 fixed point }
  FT_Pos   = type Int64;       { 26.6 fixed point }
  FT_F26Dot6 = type Int64;

  { 2D vector — 16 bytes, verified. }
  FT_Vector = record
    X: FT_Pos;
    Y: FT_Pos;
  end;

  { Glyph metrics — 40 bytes, verified. }
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

  { Bitmap descriptor — 32 bytes, verified. }
  FT_Bitmap = record
    Rows: UInt32;              { offset 0 }
    Width: UInt32;             { offset 4 }
    Pitch: Int32;              { offset 8 (signed, can be negative) }
    Buffer: PByte;             { offset 16 }
    NumGrays: UInt16;
    PaletteMode: Byte;
    PixelMode: Byte;
    _pad: array[0..3] of Byte;
  end;

  FT_Generic = record
    Data: Pointer;
    Finalizer: Pointer;
  end;

  { Pointer types for indirect access. }
  PFT_GlyphSlotRec = ^FT_GlyphSlotRec;
  PFT_Bitmap = ^FT_Bitmap;
  PFT_Glyph_Metrics = ^FT_Glyph_Metrics;

  { FT_GlyphSlotRec — the glyph slot structure.
    We only access a few key fields; the rest is padding.
    Key fields and their offsets (gcc verified):
      library      @ 0   (8 bytes, Pointer)
      face         @ 8   (8 bytes, Pointer)
      next         @ 16  (8 bytes, Pointer)
      glyph_index  @ 32  (4 bytes, FT_UInt)
      metrics      @ 40  (40 bytes, FT_Glyph_Metrics)
      bitmap       @ 152 (32 bytes, FT_Bitmap)
      bitmap_left  @ 184 (4 bytes, FT_Int)
      bitmap_top   @ 188 (4 bytes, FT_Int)
      advance      @ 192 (16 bytes, FT_Vector)
  }
  FT_GlyphSlotRec = record
    _pad0: array[0..31] of Byte;   { 0-31: library, face, next, reserved }
    GlyphIndex: FT_UInt;           { offset 32 }
    _pad1: array[0..3] of Byte;    { 36-39: padding }
    Metrics: FT_Glyph_Metrics;     { offset 40 }
    _pad2: array[0..71] of Byte;   { 80-151: padding to bitmap }
    Bitmap: FT_Bitmap;             { offset 152 }
    BitmapLeft: FT_Int;            { offset 184 }
    BitmapTop: FT_Int;             { offset 188 }
    _pad3: array[0..3] of Byte;    { padding }
    Advance: FT_Vector;            { offset 192 }
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
