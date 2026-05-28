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
  NATIVE_ENDIAN = endLittle;

  BYTES_BUILDER_DEFAULT_CAPACITY = SizeUInt(256);
  BYTES_BUILDER_MIN_GROW = SizeUInt(64);

implementation

end.
