unit nextpas.core.id.nanoid;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.id.base;

function NanoId: TNanoIdString;
function NanoIdCustom(const AAlphabet: string; const ASize: Integer): TNanoIdString;

implementation

uses
  nextpas.core.id.rng;

function NanoId: TNanoIdString;
begin
  Result := NanoIdCustom(NANOID_DEFAULT_ALPHABET, NANOID_DEFAULT_LENGTH);
end;

function NanoIdCustom(const AAlphabet: string; const ASize: Integer): TNanoIdString;
var
  LAlphaLen, LI: Integer;
  LMask: Integer;
  LBuf: array[0..63] of Byte;
  LBufPos, LBufLen: Integer;
  LByte: Integer;
begin
  LAlphaLen := Length(AAlphabet);
  if LAlphaLen = 0 then Exit('');
  if ASize <= 0 then Exit('');

  LMask := 1;
  while LMask < LAlphaLen do
    LMask := LMask shl 1;
  Dec(LMask);

  SetLength(Result, ASize);
  LBufPos := 64;
  LBufLen := 64;
  LI := 1;
  while LI <= ASize do
  begin
    if LBufPos >= LBufLen then
    begin
      IdRngFillBytes(@LBuf[0], LBufLen);
      LBufPos := 0;
    end;
    LByte := LBuf[LBufPos] and LMask;
    Inc(LBufPos);
    if LByte < LAlphaLen then
    begin
      Result[LI] := AAlphabet[LByte + 1];
      Inc(LI);
    end;
  end;
end;

end.
