unit nextpas.core.audio.codec.flac.sse;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

procedure FlacSseLpcRestore(const ACoeff: array of Integer; var AData: array of Integer);
function FlacSseCrc8(const AData: TBytes): Byte;
function FlacSseCrc16(const AData: TBytes): Word;

implementation

procedure FlacSseLpcRestore(const ACoeff: array of Integer; var AData: array of Integer);
var I, J, S: Integer;
begin
  if (Length(ACoeff) = 0) or (Length(AData) = 0) then Exit;
  for I := Length(ACoeff) to High(AData) do
  begin
    S := 0;
    for J := 0 to High(ACoeff) do
      S := S + ACoeff[J] * AData[I - J - 1];
    AData[I] := AData[I] + (S shr 8);
  end;
end;

function FlacSseCrc8(const AData: TBytes): Byte;
var I, J: Integer; C: Byte;
begin
  Result := 0;
  for I := 0 to High(AData) do
  begin
    C := AData[I];
    Result := Result xor C;
    for J := 0 to 7 do
      if (Result and $80) <> 0 then
        Result := Byte((Result shl 1) xor $07)
      else
        Result := Byte(Result shl 1);
  end;
end;

function FlacSseCrc16(const AData: TBytes): Word;
var I, J: Integer; C: Byte;
begin
  Result := 0;
  for I := 0 to High(AData) do
  begin
    C := AData[I];
    Result := Result xor (Word(C) shl 8);
    for J := 0 to 7 do
      if (Result and $8000) <> 0 then
        Result := Word((Result shl 1) xor $8005)
      else
        Result := Word(Result shl 1);
  end;
end;

end.
