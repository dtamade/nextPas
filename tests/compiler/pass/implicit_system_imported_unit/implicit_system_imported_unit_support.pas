unit implicit_system_imported_unit_support;

{$mode objfpc}{$H+}

interface

type
  TImplicitSystemBuffer = record
    Data: PByte;
    Len: SizeUInt;
  end;

function MakeBuffer(AData: PByte; ALen: SizeUInt): TImplicitSystemBuffer;

implementation

function MakeBuffer(AData: PByte; ALen: SizeUInt): TImplicitSystemBuffer;
begin
  Result.Data := AData;
  Result.Len := ALen;
end;

end.
