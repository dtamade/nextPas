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
  enLittle = nextpas.core.platform.base.endLittle;
  enBig = nextpas.core.platform.base.endBig;
  // owner: platform.base.CURRENT_ENDIAN (single source, cross-compile stable via NEXTPAS_BIG_ENDIAN)
  // perf: typed-const alias -> inline compare in bytes.binary ToEndian*, zero-copy, no extra branch
  NATIVE_ENDIAN: TEndianness = nextpas.core.platform.base.CURRENT_ENDIAN;

  BYTES_BUILDER_DEFAULT_CAPACITY = SizeUInt(256);
  BYTES_BUILDER_MIN_GROW = SizeUInt(64);

implementation

end.
