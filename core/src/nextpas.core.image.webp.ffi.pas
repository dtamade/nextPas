{**
 * nextpas.core.image.webp.ffi - libwebp ABI 声明（FFI seam）
 *}
unit nextpas.core.image.webp.ffi;

{$I nextpas.core.settings.inc}

interface

const
  LIBWEBP_SO_NAMES: array[0..2] of AnsiString = (
    'libwebp.so.7',
    'libwebp.so',
    'libwebp.so.6'
  );
  LIBWEBP_PROBE_SYMBOLS: array[0..1] of AnsiString = (
    'WebPGetInfo',
    'WebPEncodeRGBA'
  );

type
  TWebPGetInfoFunc = function(const AData: PByte; ADataSize: LongWord; out AWidth, AHeight: Integer): Integer; cdecl;
  TWebPEncodeRgbaFunc = function(const ARgba: PByte; AWidth, AHeight, AStride: Integer; AQuality: Single; out AOutput: PByte): LongWord; cdecl;

implementation

end.
