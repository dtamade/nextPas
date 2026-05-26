unit nextpas.core.bytes.base;

{$I nextpas.core.settings.inc}

interface

type
  TEndian = (
    enLittle,
    enBig
  );

  TByteOrder = TEndian;

const
  NATIVE_ENDIAN: TEndian = enLittle;

implementation

end.
