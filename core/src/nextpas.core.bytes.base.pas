unit nextpas.core.bytes.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.base;

type
  TEndianness = nextpas.core.platform.base.TEndianness;
  TEndian = TEndianness;
  TByteOrder = TEndianness;

const
  endLittle = nextpas.core.platform.base.endLittle;
  endBig = nextpas.core.platform.base.endBig;
  enLittle = endLittle;
  enBig = endBig;
  // owner: platform.base.CURRENT_ENDIAN (single source, cross-compile stable via NEXTPAS_BIG_ENDIAN)
  // perf: true const alias -> inline compare in bytes.binary ToEndian*, zero-copy, no extra branch
{$IFDEF NEXTPAS_BIG_ENDIAN}
  NATIVE_ENDIAN = endBig;
{$ELSE}
  NATIVE_ENDIAN = endLittle;
{$ENDIF}

  BYTES_BUILDER_DEFAULT_CAPACITY = SizeUInt(256);
  BYTES_BUILDER_MIN_GROW = SizeUInt(64);

implementation

end.
