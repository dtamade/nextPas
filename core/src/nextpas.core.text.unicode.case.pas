unit nextpas.core.text.unicode.&case;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.unicode.base,
  nextpas.core.text.utf8;

function CodepointToLower(const ACp: TUnicodeCodepoint): TUnicodeCodepoint; inline;
function CodepointToUpper(const ACp: TUnicodeCodepoint): TUnicodeCodepoint; inline;
function CodepointToTitle(const ACp: TUnicodeCodepoint): TUnicodeCodepoint; inline;
function CaseFoldSimple(const ACp: TUnicodeCodepoint): TUnicodeCodepoint; inline;
function CaseFoldFull(const ACp: TUnicodeCodepoint; out ADst: TCaseFoldMap): Byte; inline;
function UTF8ToUpper(const AValue: string): string;
function UTF8ToLower(const AValue: string): string;
function UTF8CaseFold(const AValue: string): string;
function UTF8CaseFoldSimple(const AValue: string): string;

implementation

{$I nextpas.core.text.unicode.data.inc}
{$I nextpas.core.text.unicode.casefold.inc}

type
  TAsciiMapMode = (
    ammUpper,
    ammLower
  );

function IsAsciiUpper(const ACp: TUnicodeCodepoint): Boolean; inline;
begin
  Result := (ACp >= Ord('A')) and (ACp <= Ord('Z'));
end;

function IsAsciiLower(const ACp: TUnicodeCodepoint): Boolean; inline;
begin
  Result := (ACp >= Ord('a')) and (ACp <= Ord('z'));
end;

function AsciiToLower(const ACp: TUnicodeCodepoint): TUnicodeCodepoint; inline;
begin
  if IsAsciiUpper(ACp) then
    Result := ACp or $20
  else
    Result := ACp;
end;

function AsciiToUpper(const ACp: TUnicodeCodepoint): TUnicodeCodepoint; inline;
begin
  if IsAsciiLower(ACp) then
    Result := ACp and $FFFFFFDF
  else
    Result := ACp;
end;

function ApplyDelta(const ACp: TUnicodeCodepoint; const ADelta: Int32): TUnicodeCodepoint; inline;
begin
  Result := TUnicodeCodepoint(Int64(ACp) + ADelta);
end;

function ApplySimpleMap(const ACp: TUnicodeCodepoint; const ABmpRanges: array of TCodepointRange2;
  const ASmpRanges: array of TCodepointRange2): TUnicodeCodepoint;
var
  LIdx: Int32;
begin
  if ACp > UNICODE_MAX_CODEPOINT then
    Exit(ACp);

  if ACp <= $FFFF then
  begin
    LIdx := FindRange2(ACp, ABmpRanges);
    if LIdx >= 0 then
      Exit(ApplyDelta(ACp, ABmpRanges[LIdx].Delta));
  end
  else
  begin
    LIdx := FindRange2(ACp, ASmpRanges);
    if LIdx >= 0 then
      Exit(ApplyDelta(ACp, ASmpRanges[LIdx].Delta));
  end;

  Result := ACp;
end;

procedure ClearCaseFoldMap(out AMap: TCaseFoldMap);
var
  LIdx: SizeInt;
begin
  for LIdx := 0 to High(AMap) do
    AMap[LIdx] := 0;
end;

function FindFullFold(const ACp: TUnicodeCodepoint; out AMap: TCaseFoldMap; out ALen: Byte): Boolean;
var
  LLo: SizeInt;
  LHi: SizeInt;
  LMid: SizeInt;
begin
  LLo := 0;
  LHi := High(CASE_FOLD_FULL);
  while LLo <= LHi do
  begin
    LMid := LLo + ((LHi - LLo) div 2);
    if ACp < CASE_FOLD_FULL[LMid].Cp then
      LHi := LMid - 1
    else if ACp > CASE_FOLD_FULL[LMid].Cp then
      LLo := LMid + 1
    else
    begin
      AMap := CASE_FOLD_FULL[LMid].Map;
      ALen := CASE_FOLD_FULL[LMid].Len;
      Exit(True);
    end;
  end;

  Result := False;
end;

function IsAsciiString(const AValue: string): Boolean;
var
  LIdx: SizeInt;
begin
  for LIdx := 1 to Length(AValue) do
  begin
    if Ord(AValue[LIdx]) > $7F then
      Exit(False);
  end;
  Result := True;
end;

function MapAsciiString(const AValue: string; const AMode: TAsciiMapMode): string;
var
  LIdx: SizeInt;
  LByte: Byte;
begin
  SetLength(Result, Length(AValue));
  for LIdx := 1 to Length(AValue) do
  begin
    LByte := Ord(AValue[LIdx]);
    case AMode of
      ammUpper:
        if (LByte >= Ord('a')) and (LByte <= Ord('z')) then
          LByte := LByte and $DF;
      ammLower:
        if (LByte >= Ord('A')) and (LByte <= Ord('Z')) then
          LByte := LByte or $20;
    end;
    Result[LIdx] := AnsiChar(LByte);
  end;
end;

procedure EnsureOutputCapacity(var AValue: string; const ARequired: SizeInt);
var
  LCapacity: SizeInt;
begin
  if Length(AValue) >= ARequired then
    Exit;

  LCapacity := Length(AValue);
  if LCapacity < 32 then
    LCapacity := 32;
  while LCapacity < ARequired do
    LCapacity := LCapacity * 2;
  SetLength(AValue, LCapacity);
end;

procedure AppendUtf8Codepoint(var ADst: string; var AUsed: SizeInt; const ACp: TUnicodeCodepoint);
var
  LBuf: array[0..3] of Byte;
  LLen: Byte;
  LIdx: Byte;
begin
  LLen := UTF8Encode(ACp, @LBuf[0]);
  if LLen = 0 then
    LLen := UTF8Encode($FFFD, @LBuf[0]);

  EnsureOutputCapacity(ADst, AUsed + LLen);
  for LIdx := 0 to LLen - 1 do
    ADst[AUsed + LIdx + 1] := AnsiChar(LBuf[LIdx]);
  Inc(AUsed, LLen);
end;

procedure AppendUpperCodepoint(var ADst: string; var AUsed: SizeInt; const ACp: TUnicodeCodepoint);
begin
  if ACp = $00DF then
  begin
    AppendUtf8Codepoint(ADst, AUsed, Ord('S'));
    AppendUtf8Codepoint(ADst, AUsed, Ord('S'));
  end
  else
    AppendUtf8Codepoint(ADst, AUsed, CodepointToUpper(ACp));
end;

function CodepointToLower(const ACp: TUnicodeCodepoint): TUnicodeCodepoint;
begin
  if ACp < 128 then
    Exit(AsciiToLower(ACp));
  Result := ApplySimpleMap(ACp, BMP_LOWER_DELTA, SMP_LOWER_DELTA);
end;

function CodepointToUpper(const ACp: TUnicodeCodepoint): TUnicodeCodepoint;
begin
  if ACp < 128 then
    Exit(AsciiToUpper(ACp));
  Result := ApplySimpleMap(ACp, BMP_UPPER_DELTA, SMP_UPPER_DELTA);
end;

function CodepointToTitle(const ACp: TUnicodeCodepoint): TUnicodeCodepoint;
begin
  if ACp < 128 then
    Exit(AsciiToUpper(ACp));
  Result := ApplySimpleMap(ACp, BMP_TITLE_DELTA, SMP_TITLE_DELTA);
end;

function CaseFoldSimple(const ACp: TUnicodeCodepoint): TUnicodeCodepoint;
var
  LIdx: Int32;
begin
  if ACp < 128 then
    Exit(AsciiToLower(ACp));

  if ACp > UNICODE_MAX_CODEPOINT then
    Exit(ACp);

  LIdx := FindRange2(ACp, CASE_FOLD_SIMPLE_DELTA);
  if LIdx >= 0 then
    Exit(ApplyDelta(ACp, CASE_FOLD_SIMPLE_DELTA[LIdx].Delta));

  if ACp = $0130 then
    Exit(Ord('i'));

  Result := ACp;
end;

function CaseFoldFull(const ACp: TUnicodeCodepoint; out ADst: TCaseFoldMap): Byte;
begin
  if FindFullFold(ACp, ADst, Result) then
    Exit;

  ClearCaseFoldMap(ADst);
  ADst[0] := CaseFoldSimple(ACp);
  Result := 1;
end;

function UTF8ToUpper(const AValue: string): string;
var
  LIter: TUTF8Iterator;
  LCp: UInt32;
  LUsed: SizeInt;
begin
  if IsAsciiString(AValue) then
    Exit(MapAsciiString(AValue, ammUpper));

  SetLength(Result, Length(AValue));
  LUsed := 0;
  LIter.Init(PByte(PAnsiChar(AValue)), SizeUInt(Length(AValue)));
  while LIter.Next(LCp) do
    AppendUpperCodepoint(Result, LUsed, LCp);
  SetLength(Result, LUsed);
end;

function UTF8ToLower(const AValue: string): string;
var
  LIter: TUTF8Iterator;
  LCp: UInt32;
  LUsed: SizeInt;
begin
  if IsAsciiString(AValue) then
    Exit(MapAsciiString(AValue, ammLower));

  SetLength(Result, Length(AValue));
  LUsed := 0;
  LIter.Init(PByte(PAnsiChar(AValue)), SizeUInt(Length(AValue)));
  while LIter.Next(LCp) do
    AppendUtf8Codepoint(Result, LUsed, CodepointToLower(LCp));
  SetLength(Result, LUsed);
end;

function UTF8CaseFold(const AValue: string): string;
var
  LIter: TUTF8Iterator;
  LCp: UInt32;
  LMap: TCaseFoldMap;
  LLen: Byte;
  LUsed: SizeInt;
  LIdx: Byte;
begin
  if IsAsciiString(AValue) then
    Exit(MapAsciiString(AValue, ammLower));

  SetLength(Result, Length(AValue));
  LUsed := 0;
  LIter.Init(PByte(PAnsiChar(AValue)), SizeUInt(Length(AValue)));
  while LIter.Next(LCp) do
  begin
    LLen := CaseFoldFull(LCp, LMap);
    for LIdx := 0 to LLen - 1 do
      AppendUtf8Codepoint(Result, LUsed, LMap[LIdx]);
  end;
  SetLength(Result, LUsed);
end;

function UTF8CaseFoldSimple(const AValue: string): string;
var
  LIter: TUTF8Iterator;
  LCp: UInt32;
  LUsed: SizeInt;
begin
  if IsAsciiString(AValue) then
    Exit(MapAsciiString(AValue, ammLower));

  SetLength(Result, Length(AValue));
  LUsed := 0;
  LIter.Init(PByte(PAnsiChar(AValue)), SizeUInt(Length(AValue)));
  while LIter.Next(LCp) do
    AppendUtf8Codepoint(Result, LUsed, CaseFoldSimple(LCp));
  SetLength(Result, LUsed);
end;

end.
