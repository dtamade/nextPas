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

function NextCapacity(const ACurrent, ARequired: SizeUInt): SizeUInt; inline;

implementation

function NextCapacity(const ACurrent, ARequired: SizeUInt): SizeUInt;
begin
  Result := ACurrent;
  while Result < ARequired do
  begin
    if Result <= High(SizeUInt) div 2 then
      Result := Result * 2
    else
    begin
      Result := ARequired;
      Break;
    end;
  end;
end;

end.
