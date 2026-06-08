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

function NanoIdAlphabetIsValid(const AAlphabet: string): Boolean;
var
  LSeen: array[Byte] of Boolean;
  LI: Integer;
  LCode: Byte;
begin
  if Length(AAlphabet) < 2 then Exit(False);
  if Length(AAlphabet) > 256 then Exit(False);
  FillChar(LSeen, SizeOf(LSeen), 0);
  for LI := 1 to Length(AAlphabet) do
  begin
    LCode := Byte(AAlphabet[LI]);
    if LSeen[LCode] then Exit(False);
    LSeen[LCode] := True;
  end;
  Result := True;
end;

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
  if ASize <= 0 then Exit('');
  if not NanoIdAlphabetIsValid(AAlphabet) then Exit('');

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
