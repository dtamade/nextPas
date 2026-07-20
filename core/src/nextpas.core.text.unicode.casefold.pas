unit nextpas.core.text.unicode.casefold;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.unicode.types,
  nextpas.core.text.unicode.base,
  nextpas.core.text.utf8;

type
  { Default clRoot matches UCD root / existing harness.
    clTurkish / clAzeri enable CaseFold T + SpecialCasing tr/az. }
  TCaseLocale = (
    clRoot,
    clTurkish,
    clAzeri
  );

  TCaseOptions = record
    Locale: TCaseLocale;
  end;

function DefaultCaseOptions: TCaseOptions; inline;

function CodepointToLower(const ACp: TUnicodeCodepoint): TUnicodeCodepoint; inline;
function CodepointToUpper(const ACp: TUnicodeCodepoint): TUnicodeCodepoint; inline;
function CodepointToTitle(const ACp: TUnicodeCodepoint): TUnicodeCodepoint; inline;
function CaseFoldSimple(const ACp: TUnicodeCodepoint): TUnicodeCodepoint; overload; inline;
function CaseFoldFull(const ACp: TUnicodeCodepoint; out ADst: TCaseFoldMap): Byte; overload; inline;

function CaseFoldSimple(const ACp: TUnicodeCodepoint; const AOptions: TCaseOptions): TUnicodeCodepoint; overload;
function CaseFoldFull(const ACp: TUnicodeCodepoint; out ADst: TCaseFoldMap;
  const AOptions: TCaseOptions): Byte; overload;

function UTF8ToUpper(const AValue: string): string; overload;
function UTF8ToLower(const AValue: string): string; overload;
function UTF8ToTitle(const AValue: string): string; overload;
function UTF8CaseFold(const AValue: string): string; overload;
function UTF8CaseFoldSimple(const AValue: string): string; overload;

function UTF8ToUpper(const AValue: string; const AOptions: TCaseOptions): string; overload;
function UTF8ToLower(const AValue: string; const AOptions: TCaseOptions): string; overload;
function UTF8ToTitle(const AValue: string; const AOptions: TCaseOptions): string; overload;
function UTF8CaseFold(const AValue: string; const AOptions: TCaseOptions): string; overload;
function UTF8CaseFoldSimple(const AValue: string; const AOptions: TCaseOptions): string; overload;

{ SpecialCasing 1:N (unconditional). Returns False if no entry. }
function MapSpecialLower(const ACp: TUnicodeCodepoint; out ADst: TCaseFoldMap; out ALen: Byte): Boolean;
function MapSpecialUpper(const ACp: TUnicodeCodepoint; out ADst: TCaseFoldMap; out ALen: Byte): Boolean;
function MapSpecialTitle(const ACp: TUnicodeCodepoint; out ADst: TCaseFoldMap; out ALen: Byte): Boolean;

implementation

uses
  nextpas.core.text.unicode.utils,
  nextpas.core.text.unicode.props,
  nextpas.core.text.unicode.normalize;

{$I nextpas.core.text.unicode.data.inc}
{$I nextpas.core.text.unicode.casefold.inc}

type
  TAsciiMapMode = (
    ammUpper,
    ammLower
  );

  TSpecialCasingEntry = record
    Cp: TUnicodeCodepoint;
    LowerLen: Byte;
    TitleLen: Byte;
    UpperLen: Byte;
    Lower: array[0..7] of TUnicodeCodepoint;
    Title: array[0..7] of TUnicodeCodepoint;
    Upper: array[0..7] of TUnicodeCodepoint;
  end;

{$I nextpas.core.text.unicode.special_casing.inc}

const
  GREEK_CAPITAL_SIGMA = $03A3;
  GREEK_SMALL_SIGMA = $03C3;
  GREEK_SMALL_FINAL_SIGMA = $03C2;
  CP_LATIN_CAPITAL_I = $0049;
  CP_LATIN_SMALL_I = $0069;
  CP_LATIN_CAPITAL_I_DOT = $0130;
  CP_LATIN_SMALL_DOTLESS_I = $0131;
  CP_COMBINING_DOT_ABOVE = $0307;

  { CaseFold simple for U+0000..U+00FF (from CaseFolding C/S) }
  CASE_FOLD_LATIN1: array[0..255] of UInt16 = (
    $0000, $0001, $0002, $0003, $0004, $0005, $0006, $0007, $0008, $0009, $000A, $000B, $000C, $000D, $000E, $000F,
    $0010, $0011, $0012, $0013, $0014, $0015, $0016, $0017, $0018, $0019, $001A, $001B, $001C, $001D, $001E, $001F,
    $0020, $0021, $0022, $0023, $0024, $0025, $0026, $0027, $0028, $0029, $002A, $002B, $002C, $002D, $002E, $002F,
    $0030, $0031, $0032, $0033, $0034, $0035, $0036, $0037, $0038, $0039, $003A, $003B, $003C, $003D, $003E, $003F,
    $0040, $0061, $0062, $0063, $0064, $0065, $0066, $0067, $0068, $0069, $006A, $006B, $006C, $006D, $006E, $006F,
    $0070, $0071, $0072, $0073, $0074, $0075, $0076, $0077, $0078, $0079, $007A, $005B, $005C, $005D, $005E, $005F,
    $0060, $0061, $0062, $0063, $0064, $0065, $0066, $0067, $0068, $0069, $006A, $006B, $006C, $006D, $006E, $006F,
    $0070, $0071, $0072, $0073, $0074, $0075, $0076, $0077, $0078, $0079, $007A, $007B, $007C, $007D, $007E, $007F,
    $0080, $0081, $0082, $0083, $0084, $0085, $0086, $0087, $0088, $0089, $008A, $008B, $008C, $008D, $008E, $008F,
    $0090, $0091, $0092, $0093, $0094, $0095, $0096, $0097, $0098, $0099, $009A, $009B, $009C, $009D, $009E, $009F,
    $00A0, $00A1, $00A2, $00A3, $00A4, $00A5, $00A6, $00A7, $00A8, $00A9, $00AA, $00AB, $00AC, $00AD, $00AE, $00AF,
    $00B0, $00B1, $00B2, $00B3, $00B4, $03BC, $00B6, $00B7, $00B8, $00B9, $00BA, $00BB, $00BC, $00BD, $00BE, $00BF,
    $00E0, $00E1, $00E2, $00E3, $00E4, $00E5, $00E6, $00E7, $00E8, $00E9, $00EA, $00EB, $00EC, $00ED, $00EE, $00EF,
    $00F0, $00F1, $00F2, $00F3, $00F4, $00F5, $00F6, $00D7, $00F8, $00F9, $00FA, $00FB, $00FC, $00FD, $00FE, $00DF,
    $00E0, $00E1, $00E2, $00E3, $00E4, $00E5, $00E6, $00E7, $00E8, $00E9, $00EA, $00EB, $00EC, $00ED, $00EE, $00EF,
    $00F0, $00F1, $00F2, $00F3, $00F4, $00F5, $00F6, $00F7, $00F8, $00F9, $00FA, $00FB, $00FC, $00FD, $00FE, $00FF
  );

function DefaultCaseOptions: TCaseOptions;
begin
  Result.Locale := clRoot;
end;

function IsTurkicLocale(const ALocale: TCaseLocale): Boolean; inline;
begin
  Result := ALocale in [clTurkish, clAzeri];
end;



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
  LLo, LHi, LMid: SizeInt;
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

function FindSpecialCasing(const ACp: TUnicodeCodepoint): Integer;
var
  Lo, Hi, Mid: Integer;
begin
  Lo := 0;
  Hi := SPECIAL_CASING_COUNT - 1;
  while Lo <= Hi do
  begin
    Mid := Lo + (Hi - Lo) div 2;
    if SPECIAL_CASING[Mid].Cp < ACp then
      Lo := Mid + 1
    else if SPECIAL_CASING[Mid].Cp > ACp then
      Hi := Mid - 1
    else
      Exit(Mid);
  end;
  Result := -1;
end;

function MapSpecialLower(const ACp: TUnicodeCodepoint; out ADst: TCaseFoldMap; out ALen: Byte): Boolean;
var
  I, Idx: Integer;
begin
  Idx := FindSpecialCasing(ACp);
  if Idx < 0 then
    Exit(False);
  ALen := SPECIAL_CASING[Idx].LowerLen;
  if ALen = 0 then
    Exit(False);
  ClearCaseFoldMap(ADst);
  for I := 0 to Integer(ALen) - 1 do
    ADst[I] := SPECIAL_CASING[Idx].Lower[I];
  Result := True;
end;

function MapSpecialUpper(const ACp: TUnicodeCodepoint; out ADst: TCaseFoldMap; out ALen: Byte): Boolean;
var
  I, Idx: Integer;
begin
  Idx := FindSpecialCasing(ACp);
  if Idx < 0 then
    Exit(False);
  ALen := SPECIAL_CASING[Idx].UpperLen;
  if ALen = 0 then
    Exit(False);
  ClearCaseFoldMap(ADst);
  for I := 0 to Integer(ALen) - 1 do
    ADst[I] := SPECIAL_CASING[Idx].Upper[I];
  Result := True;
end;

function MapSpecialTitle(const ACp: TUnicodeCodepoint; out ADst: TCaseFoldMap; out ALen: Byte): Boolean;
var
  I, Idx: Integer;
begin
  Idx := FindSpecialCasing(ACp);
  if Idx < 0 then
    Exit(False);
  ALen := SPECIAL_CASING[Idx].TitleLen;
  if ALen = 0 then
    Exit(False);
  ClearCaseFoldMap(ADst);
  for I := 0 to Integer(ALen) - 1 do
    ADst[I] := SPECIAL_CASING[Idx].Title[I];
  Result := True;
end;

function MapAsciiString(const AValue: string; const AMode: TAsciiMapMode): string;
var
  LLen, LIdx: SizeInt;
  LSrc, LDst: PByte;
  LByte: Byte;
begin
  LLen := Length(AValue);
  if LLen = 0 then
    Exit('');
  SetLength(Result, LLen);
  LSrc := PByte(@AValue[1]);
  LDst := PByte(@Result[1]);
  if AMode = ammLower then
  begin
    for LIdx := 0 to LLen - 1 do
    begin
      LByte := LSrc[LIdx];
      if (LByte >= Ord('A')) and (LByte <= Ord('Z')) then
        LByte := LByte or $20;
      LDst[LIdx] := LByte;
    end;
  end
  else
  begin
    for LIdx := 0 to LLen - 1 do
    begin
      LByte := LSrc[LIdx];
      if (LByte >= Ord('a')) and (LByte <= Ord('z')) then
        LByte := LByte and $DF;
      LDst[LIdx] := LByte;
    end;
  end;
end;

procedure AppendMap(var ADst: string; var AUsed: SizeInt; const AMap: TCaseFoldMap; const ALen: Byte);
var
  I: Integer;
begin
  for I := 0 to Integer(ALen) - 1 do
    AppendUtf8Codepoint(ADst, AUsed, AMap[I]);
end;

function CodepointToLower(const ACp: TUnicodeCodepoint): TUnicodeCodepoint;
var
  LMap: TCaseFoldMap;
  LLen: Byte;
begin
  if ACp < 128 then
    Exit(AsciiToLower(ACp));
  { 1:1 special lower only; 1:N left to string APIs }
  if MapSpecialLower(ACp, LMap, LLen) and (LLen = 1) then
    Exit(LMap[0]);
  Result := ApplySimpleMap(ACp, BMP_LOWER_DELTA, SMP_LOWER_DELTA);
end;

function CodepointToUpper(const ACp: TUnicodeCodepoint): TUnicodeCodepoint;
var
  LMap: TCaseFoldMap;
  LLen: Byte;
begin
  if ACp < 128 then
    Exit(AsciiToUpper(ACp));
  if MapSpecialUpper(ACp, LMap, LLen) and (LLen = 1) then
    Exit(LMap[0]);
  Result := ApplySimpleMap(ACp, BMP_UPPER_DELTA, SMP_UPPER_DELTA);
end;

function CodepointToTitle(const ACp: TUnicodeCodepoint): TUnicodeCodepoint;
var
  LMap: TCaseFoldMap;
  LLen: Byte;
begin
  if ACp < 128 then
    Exit(AsciiToUpper(ACp));
  if MapSpecialTitle(ACp, LMap, LLen) and (LLen = 1) then
    Exit(LMap[0]);
  Result := ApplySimpleMap(ACp, BMP_TITLE_DELTA, SMP_TITLE_DELTA);
end;

function CaseFoldSimpleRoot(const ACp: TUnicodeCodepoint): TUnicodeCodepoint;
var
  LIdx: Int32;
begin
  if ACp <= $FF then
    Exit(CASE_FOLD_LATIN1[ACp]);

  if ACp > UNICODE_MAX_CODEPOINT then
    Exit(ACp);

  LIdx := FindRange2(ACp, CASE_FOLD_SIMPLE_DELTA);
  if LIdx >= 0 then
    Exit(ApplyDelta(ACp, CASE_FOLD_SIMPLE_DELTA[LIdx].Delta));

  if ACp = $0130 then
    Exit(Ord('i'));

  Result := ACp;
end;

function CaseFoldSimple(const ACp: TUnicodeCodepoint): TUnicodeCodepoint;
begin
  Result := CaseFoldSimpleRoot(ACp);
end;

function CaseFoldSimple(const ACp: TUnicodeCodepoint; const AOptions: TCaseOptions): TUnicodeCodepoint;
begin
  if IsTurkicLocale(AOptions.Locale) then
  begin
    if ACp = CP_LATIN_CAPITAL_I then
      Exit(CP_LATIN_SMALL_DOTLESS_I);
    if ACp = CP_LATIN_CAPITAL_I_DOT then
      Exit(CP_LATIN_SMALL_I);
  end;
  Result := CaseFoldSimpleRoot(ACp);
end;

function CaseFoldFull(const ACp: TUnicodeCodepoint; out ADst: TCaseFoldMap): Byte;
begin
  Result := CaseFoldFull(ACp, ADst, DefaultCaseOptions);
end;

function CaseFoldFull(const ACp: TUnicodeCodepoint; out ADst: TCaseFoldMap;
  const AOptions: TCaseOptions): Byte;
begin
  if IsTurkicLocale(AOptions.Locale) then
  begin
    if (ACp = CP_LATIN_CAPITAL_I) or (ACp = CP_LATIN_CAPITAL_I_DOT) then
    begin
      ClearCaseFoldMap(ADst);
      ADst[0] := CaseFoldSimple(ACp, AOptions);
      Exit(1);
    end;
  end;
  if FindFullFold(ACp, ADst, Result) then
    Exit;
  ClearCaseFoldMap(ADst);
  ADst[0] := CaseFoldSimpleRoot(ACp);
  Result := 1;
end;

function IsCasedCp(const ACp: TUnicodeCodepoint): Boolean; inline;
begin
  Result := HasBinaryProperty(ACp, ubpCased);
end;

function IsCaseIgnorableCp(const ACp: TUnicodeCodepoint): Boolean; inline;
begin
  Result := HasBinaryProperty(ACp, ubpCaseIgnorable);
end;

{ Final_Sigma: preceded by cased letter (with only case-ignorables between),
  and not followed by cased letter (with only case-ignorables between). }
function IsFinalSigmaContext(const ACps: array of TUnicodeCodepoint; const ACount, AIdx: SizeInt): Boolean;
var
  J: SizeInt;
  LSawCasedBefore: Boolean;
begin
  LSawCasedBefore := False;
  J := AIdx - 1;
  while J >= 0 do
  begin
    if IsCasedCp(ACps[J]) then
    begin
      LSawCasedBefore := True;
      Break;
    end;
    if not IsCaseIgnorableCp(ACps[J]) then
      Break;
    Dec(J);
  end;
  if not LSawCasedBefore then
    Exit(False);

  J := AIdx + 1;
  while J < ACount do
  begin
    if IsCasedCp(ACps[J]) then
      Exit(False); // not final
    if not IsCaseIgnorableCp(ACps[J]) then
      Break;
    Inc(J);
  end;
  Result := True;
end;

function NextNonIgnorable(const ACps: array of TUnicodeCodepoint; const ACount, AFrom: SizeInt): SizeInt;
var
  J: SizeInt;
begin
  J := AFrom;
  while J < ACount do
  begin
    if not IsCaseIgnorableCp(ACps[J]) then
      Exit(J);
    Inc(J);
  end;
  Result := -1;
end;

function PrevNonIgnorable(const ACps: array of TUnicodeCodepoint; const AFrom: SizeInt): SizeInt;
var
  J: SizeInt;
begin
  J := AFrom;
  while J >= 0 do
  begin
    if not IsCaseIgnorableCp(ACps[J]) then
      Exit(J);
    Dec(J);
  end;
  Result := -1;
end;

{ UAX §3.13 Before_Dot: followed by U+0307; intervening ccc neither 0 nor 230. }
function FindBeforeDotMark(const ACps: array of TUnicodeCodepoint; const ACount, AIndex: SizeInt): SizeInt;
var
  J: SizeInt;
  LCcc: Byte;
begin
  J := AIndex + 1;
  while J < ACount do
  begin
    if ACps[J] = CP_COMBINING_DOT_ABOVE then
      Exit(J);
    LCcc := GetCanonicalCombiningClass(ACps[J]);
    if (LCcc = 0) or (LCcc = 230) then
      Exit(-1);
    Inc(J);
  end;
  Result := -1;
end;

{ After_I: last preceding cased/base (non-ignorable) is U+0049; no intervening ccc=230. }
function IsAfterI(const ACps: array of TUnicodeCodepoint; const AIndex: SizeInt): Boolean;
var
  J: SizeInt;
  LCcc: Byte;
begin
  J := AIndex - 1;
  while J >= 0 do
  begin
    LCcc := GetCanonicalCombiningClass(ACps[J]);
    if LCcc = 230 then
      Exit(False);
    if not IsCaseIgnorableCp(ACps[J]) then
      Exit(ACps[J] = CP_LATIN_CAPITAL_I);
    Dec(J);
  end;
  Result := False;
end;

function UTF8ToUpper(const AValue: string): string;
begin
  Result := UTF8ToUpper(AValue, DefaultCaseOptions);
end;

function UTF8ToUpper(const AValue: string; const AOptions: TCaseOptions): string;
var
  LIter: TUTF8Iterator;
  LCp: UInt32;
  LUsed: SizeInt;
  LMap: TCaseFoldMap;
  LLen: Byte;
  LTurkic: Boolean;
begin
  LTurkic := IsTurkicLocale(AOptions.Locale);
  if (not LTurkic) and IsAsciiString(AValue) then
    Exit(MapAsciiString(AValue, ammUpper));

  SetLength(Result, Length(AValue) * 2 + 8);
  LUsed := 0;
  LIter.Init(PByte(PAnsiChar(AValue)), SizeUInt(Length(AValue)));
  while LIter.Next(LCp) do
  begin
    if LTurkic then
    begin
      if LCp = CP_LATIN_SMALL_I then
      begin
        AppendUtf8Codepoint(Result, LUsed, CP_LATIN_CAPITAL_I_DOT);
        Continue;
      end;
      if LCp = CP_LATIN_SMALL_DOTLESS_I then
      begin
        AppendUtf8Codepoint(Result, LUsed, CP_LATIN_CAPITAL_I);
        Continue;
      end;
    end;
    if MapSpecialUpper(LCp, LMap, LLen) then
      AppendMap(Result, LUsed, LMap, LLen)
    else
      AppendUtf8Codepoint(Result, LUsed, CodepointToUpper(LCp));
  end;
  SetLength(Result, LUsed);
end;

function UTF8ToLower(const AValue: string): string;
begin
  Result := UTF8ToLower(AValue, DefaultCaseOptions);
end;

function UTF8ToLower(const AValue: string; const AOptions: TCaseOptions): string;
var
  LCps: array of TUnicodeCodepoint;
  LSkip: array of Boolean;
  LCount, I, LNext: SizeInt;
  LIter: TUTF8Iterator;
  LCp: UInt32;
  LUsed: SizeInt;
  LMap: TCaseFoldMap;
  LLen: Byte;
  LOut: TUnicodeCodepoint;
  LTurkic: Boolean;
begin
  LTurkic := IsTurkicLocale(AOptions.Locale);
  if (not LTurkic) and IsAsciiString(AValue) then
    Exit(MapAsciiString(AValue, ammLower));

  LCount := 0;
  SetLength(LCps, Length(AValue) + 4);
  LIter.Init(PByte(PAnsiChar(AValue)), SizeUInt(Length(AValue)));
  while LIter.Next(LCp) do
  begin
    if LCount >= Length(LCps) then
      SetLength(LCps, Length(LCps) * 2);
    LCps[LCount] := LCp;
    Inc(LCount);
  end;
  SetLength(LSkip, LCount);
  for I := 0 to LCount - 1 do
    LSkip[I] := False;

  SetLength(Result, Length(AValue) * 2 + 8);
  LUsed := 0;
  for I := 0 to LCount - 1 do
  begin
    if LSkip[I] then
      Continue;
    LCp := LCps[I];

    if LTurkic then
    begin
      { SpecialCasing tr/az: İ → i (not i+0307) }
      if LCp = CP_LATIN_CAPITAL_I_DOT then
      begin
        AppendUtf8Codepoint(Result, LUsed, CP_LATIN_SMALL_I);
        Continue;
      end;
      { Not_Before_Dot: I → ı; Before_Dot: I → i and 0307 removed via After_I }
      if LCp = CP_LATIN_CAPITAL_I then
      begin
        LNext := FindBeforeDotMark(LCps, LCount, I);
        if LNext >= 0 then
        begin
          AppendUtf8Codepoint(Result, LUsed, CP_LATIN_SMALL_I);
          LSkip[LNext] := True;
        end
        else
          AppendUtf8Codepoint(Result, LUsed, CP_LATIN_SMALL_DOTLESS_I);
        Continue;
      end;
      { 0307 After_I → empty (if not already consumed with I) }
      if LCp = CP_COMBINING_DOT_ABOVE then
      begin
        if IsAfterI(LCps, I) then
          Continue;
      end;
    end;

    if LCp = GREEK_CAPITAL_SIGMA then
    begin
      if IsFinalSigmaContext(LCps, LCount, I) then
        LOut := GREEK_SMALL_FINAL_SIGMA
      else
        LOut := GREEK_SMALL_SIGMA;
      AppendUtf8Codepoint(Result, LUsed, LOut);
    end
    else if MapSpecialLower(LCp, LMap, LLen) then
      AppendMap(Result, LUsed, LMap, LLen)
    else
      AppendUtf8Codepoint(Result, LUsed, CodepointToLower(LCp));
  end;
  SetLength(Result, LUsed);
end;

function UTF8ToTitle(const AValue: string): string;
begin
  Result := UTF8ToTitle(AValue, DefaultCaseOptions);
end;

function UTF8ToTitle(const AValue: string; const AOptions: TCaseOptions): string;
var
  LIter: TUTF8Iterator;
  LCp: UInt32;
  LUsed: SizeInt;
  LMap: TCaseFoldMap;
  LLen: Byte;
  LTurkic: Boolean;
begin
  if AValue = '' then
    Exit('');
  LTurkic := IsTurkicLocale(AOptions.Locale);
  if (not LTurkic) and IsAsciiString(AValue) then
    Exit(MapAsciiString(AValue, ammUpper));

  SetLength(Result, Length(AValue) * 2 + 8);
  LUsed := 0;
  LIter.Init(PByte(PAnsiChar(AValue)), SizeUInt(Length(AValue)));
  while LIter.Next(LCp) do
  begin
    if LTurkic then
    begin
      if LCp = CP_LATIN_SMALL_I then
      begin
        AppendUtf8Codepoint(Result, LUsed, CP_LATIN_CAPITAL_I_DOT);
        Continue;
      end;
      if LCp = CP_LATIN_SMALL_DOTLESS_I then
      begin
        AppendUtf8Codepoint(Result, LUsed, CP_LATIN_CAPITAL_I);
        Continue;
      end;
    end;
    if MapSpecialTitle(LCp, LMap, LLen) then
      AppendMap(Result, LUsed, LMap, LLen)
    else
      AppendUtf8Codepoint(Result, LUsed, CodepointToTitle(LCp));
  end;
  SetLength(Result, LUsed);
end;

function UTF8CaseFold(const AValue: string): string;
begin
  Result := UTF8CaseFold(AValue, DefaultCaseOptions);
end;

function UTF8CaseFold(const AValue: string; const AOptions: TCaseOptions): string;
var
  LIter: TUTF8Iterator;
  LCp: UInt32;
  LMap: TCaseFoldMap;
  LLen: Byte;
  LUsed: SizeInt;
  LIdx: Byte;
  LTurkic: Boolean;
begin
  LTurkic := IsTurkicLocale(AOptions.Locale);
  if (not LTurkic) and IsAsciiString(AValue) then
    Exit(MapAsciiString(AValue, ammLower));

  SetLength(Result, Length(AValue) * 2 + 8);
  LUsed := 0;
  LIter.Init(PByte(PAnsiChar(AValue)), SizeUInt(Length(AValue)));
  while LIter.Next(LCp) do
  begin
    LLen := CaseFoldFull(LCp, LMap, AOptions);
    for LIdx := 0 to LLen - 1 do
      AppendUtf8Codepoint(Result, LUsed, LMap[LIdx]);
  end;
  SetLength(Result, LUsed);
end;

function UTF8CaseFoldSimple(const AValue: string): string;
begin
  Result := UTF8CaseFoldSimple(AValue, DefaultCaseOptions);
end;

function UTF8CaseFoldSimple(const AValue: string; const AOptions: TCaseOptions): string;
var
  LIter: TUTF8Iterator;
  LCp: UInt32;
  LUsed: SizeInt;
  LTurkic: Boolean;
begin
  LTurkic := IsTurkicLocale(AOptions.Locale);
  if (not LTurkic) and IsAsciiString(AValue) then
    Exit(MapAsciiString(AValue, ammLower));

  SetLength(Result, Length(AValue) * 2 + 8);
  LUsed := 0;
  LIter.Init(PByte(PAnsiChar(AValue)), SizeUInt(Length(AValue)));
  while LIter.Next(LCp) do
    AppendUtf8Codepoint(Result, LUsed, CaseFoldSimple(LCp, AOptions));
  SetLength(Result, LUsed);
end;

end.
