unit nextpas.core.bytes.base;

{$I nextpas.core.settings.inc}

interface

type
  TEndianness = (
    endLittle,
    endBig
  );
  TEndian = TEndianness;
  TByteOrder = TEndianness;

const
  enLittle = endLittle;
  enBig = endBig;
{$IF DEFINED(FPC_BIG_ENDIAN)}
  NATIVE_ENDIAN = endBig;
{$ELSE}
  NATIVE_ENDIAN = endLittle;
{$ENDIF}

  BYTES_BUILDER_DEFAULT_CAPACITY = SizeUInt(256);
  BYTES_BUILDER_MIN_GROW = SizeUInt(64);

implementation

end.
