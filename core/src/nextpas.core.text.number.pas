unit nextpas.core.text.number;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view;

function IntToBuffer(const AValue: Int64; const ADst: PAnsiChar): Int32;
function UIntToBuffer(const AValue: UInt64; const ADst: PAnsiChar): Int32;
function IntToHexBuffer(const AValue: UInt64; const ADst: PAnsiChar;
  const AMinDigits: Int32 = 1): Int32;
function ParseInt64(const AData: PAnsiChar; const ALen: SizeUInt;
  out AValue: Int64): Boolean;
function ParseUInt64(const AData: PAnsiChar; const ALen: SizeUInt;
  out AValue: UInt64): Boolean;
function FloatToBuffer(const AValue: Double; const ADst: PAnsiChar): Int32;
function FloatToJsonBuffer(const AValue: Double; const ADst: PAnsiChar): Int32;
function ParseDouble(const AData: PAnsiChar; const ALen: SizeUInt;
  out AValue: Double): Boolean;
function ViewToInt64(const AView: TStringView; out AValue: Int64): Boolean; inline;
function ViewToUInt64(const AView: TStringView; out AValue: UInt64): Boolean; inline;
function ViewToDouble(const AView: TStringView; out AValue: Double): Boolean; inline;

implementation

uses
  nextpas.core.text.char;

const
  DIGIT_PAIRS: array[0..99] of array[0..1] of AnsiChar = (
    '00','01','02','03','04','05','06','07','08','09',
    '10','11','12','13','14','15','16','17','18','19',
    '20','21','22','23','24','25','26','27','28','29',
    '30','31','32','33','34','35','36','37','38','39',
    '40','41','42','43','44','45','46','47','48','49',
    '50','51','52','53','54','55','56','57','58','59',
    '60','61','62','63','64','65','66','67','68','69',
    '70','71','72','73','74','75','76','77','78','79',
    '80','81','82','83','84','85','86','87','88','89',
    '90','91','92','93','94','95','96','97','98','99'
  );

  HEX_CHARS: array[0..15] of AnsiChar = '0123456789abcdef';

function UIntToBuffer(const AValue: UInt64; const ADst: PAnsiChar): Int32;
var
  LBuf: array[0..20] of AnsiChar;
  LIdx: Int32;
  LVal: UInt64;
  LPair: UInt64;
begin
  if AValue = 0 then
  begin
    ADst[0] := '0';
    Result := 1;
    Exit;
  end;
  LIdx := 20;
  LVal := AValue;
  while LVal >= 100 do
  begin
    LPair := LVal mod 100;
    LVal := LVal div 100;
    Dec(LIdx, 2);
    LBuf[LIdx] := DIGIT_PAIRS[LPair][0];
    LBuf[LIdx + 1] := DIGIT_PAIRS[LPair][1];
  end;
  if LVal >= 10 then
  begin
    Dec(LIdx, 2);
    LBuf[LIdx] := DIGIT_PAIRS[LVal][0];
    LBuf[LIdx + 1] := DIGIT_PAIRS[LVal][1];
  end
  else
  begin
    Dec(LIdx);
    LBuf[LIdx] := AnsiChar(Ord('0') + LVal);
  end;
  Result := 20 - LIdx;
  Move(LBuf[LIdx], ADst^, Result);
end;

function IntToBuffer(const AValue: Int64; const ADst: PAnsiChar): Int32;
var
  LU: UInt64;
begin
  if AValue < 0 then
  begin
    ADst[0] := '-';
    if AValue = Low(Int64) then
      LU := UInt64(9223372036854775808)
    else
      LU := UInt64(-AValue);
    Result := UIntToBuffer(LU, ADst + 1) + 1;
  end
  else
    Result := UIntToBuffer(UInt64(AValue), ADst);
end;

function IntToHexBuffer(const AValue: UInt64; const ADst: PAnsiChar;
  const AMinDigits: Int32): Int32;
var
  LBuf: array[0..15] of AnsiChar;
  LIdx: Int32;
  LVal: UInt64;
  LMin: Int32;
begin
  LMin := AMinDigits;
  if LMin > 16 then LMin := 16;
  if (AValue = 0) and (LMin <= 1) then
  begin
    ADst[0] := '0';
    Result := 1;
    Exit;
  end;
  LIdx := 16;
  LVal := AValue;
  while LVal > 0 do
  begin
    Dec(LIdx);
    LBuf[LIdx] := HEX_CHARS[LVal and $F];
    LVal := LVal shr 4;
  end;
  Result := 16 - LIdx;
  while Result < LMin do
  begin
    Dec(LIdx);
    LBuf[LIdx] := '0';
    Inc(Result);
  end;
  Move(LBuf[LIdx], ADst^, Result);
end;

function ParseUInt64(const AData: PAnsiChar; const ALen: SizeUInt;
  out AValue: UInt64): Boolean;
var
  I: SizeUInt;
  D: Int32;
  LPrev: UInt64;
begin
  AValue := 0;
  if ALen = 0 then
    Exit(False);
  for I := 0 to ALen - 1 do
  begin
    if not IsDigit(Byte(AData[I])) then
      Exit(False);
    D := Byte(AData[I]) - Ord('0');
    LPrev := AValue;
    AValue := AValue * 10 + UInt64(D);
    if AValue < LPrev then
      Exit(False);
  end;
  Result := True;
end;

function ParseInt64(const AData: PAnsiChar; const ALen: SizeUInt;
  out AValue: Int64): Boolean;
var
  LU: UInt64;
  LNeg: Boolean;
  LStart: SizeUInt;
begin
  AValue := 0;
  if ALen = 0 then
    Exit(False);
  LNeg := AData[0] = '-';
  if LNeg or (AData[0] = '+') then
    LStart := 1
  else
    LStart := 0;
  if LStart >= ALen then
    Exit(False);
  if not ParseUInt64(AData + LStart, ALen - LStart, LU) then
    Exit(False);
  if LNeg then
  begin
    if LU > UInt64(9223372036854775808) then
      Exit(False);
    if LU = UInt64(9223372036854775808) then
      AValue := Low(Int64)
    else
      AValue := -Int64(LU);
  end
  else
  begin
    if LU > UInt64(High(Int64)) then
      Exit(False);
    AValue := Int64(LU);
  end;
  Result := True;
end;

function ViewToInt64(const AView: TStringView; out AValue: Int64): Boolean;
begin
  Result := ParseInt64(AView.Data, AView.Len, AValue);
end;

function ViewToUInt64(const AView: TStringView; out AValue: UInt64): Boolean;
begin
  Result := ParseUInt64(AView.Data, AView.Len, AValue);
end;

{$I nextpas.core.text.number.ieee.inc}
{$push}{$R-}
{$I nextpas.core.text.number.pow10.inc}
{$pop}
{$I nextpas.core.text.number.ryu.inc}

function EiselLemire(const AMant: UInt64; const AExp10: Int32;
  out AValue: Double): Boolean; forward;
function ParseDoubleFallback(const AData: PAnsiChar; const ALen: SizeUInt;
  out AValue: Double): Boolean; forward;

function FloatToJsonBuffer(const AValue: Double; const ADst: PAnsiChar): Int32;
begin
  if DoubleIsNaN(AValue) or DoubleIsInf(AValue) then
  begin
    Move('null', ADst^, 4);
    Exit(4);
  end;
  Result := FloatToBuffer(AValue, ADst);
end;

function EiselLemire(const AMant: UInt64; const AExp10: Int32;
  out AValue: Double): Boolean;
const
  EL_MIN = -307;
  EL_MAX = 288;
  TAIL = UInt64((UInt64(1) shl 9) - 1);
var
  S1, S2, S2E, Hi, Lo, H2, L2, Ad, Bt: UInt64;
  E2: Int32;
  Cz: UInt32;
  Raw: UInt64;
begin
  Result := False;
  AValue := 0.0;
  if (AExp10 < EL_MIN) or (AExp10 > EL_MAX) then Exit;
  S2 := POW10_TABLE[AExp10 - POW10_MIN_EXP].Hi;
  S2E := POW10_TABLE[AExp10 - POW10_MIN_EXP].Lo;
  E2 := SarLongint(AExp10 * 217706 - 4128768, 16);
  Cz := UInt32(63 - BsrQWord(AMant));
  S1 := AMant shl Cz;
  Dec(E2, Int32(Cz));
  UMul128(S1, S2, Hi, Lo);
  Bt := Hi and TAIL;
  if (Bt - 1) >= (TAIL - 1) then
  begin
    UMul128(S1, S2E, H2, L2);
    Ad := Lo + H2;
    if (Ad + 1) <= UInt64(1) then Exit;
    if (Ad < Lo) or (Ad < H2) then Inc(Hi);
  end;
  Hi := Hi + (Lo shr 63);
  Inc(E2, 64);
  Cz := UInt32(63 - BsrQWord(Hi));
  Hi := Hi shl Cz;
  Dec(E2, Int32(Cz));
  if (Hi and ((UInt64(1) shl 11) - 1)) >= (UInt64(1) shl 10) then
    Hi := Hi + (UInt64(1) shl 11);
  Hi := Hi shr 11;
  Inc(E2, 63);
  if Hi >= (UInt64(1) shl 53) then
  begin
    Hi := Hi shr 1;
    Inc(E2);
  end;
  if E2 >= 1024 then Exit;
  if E2 >= -1022 then
  begin
    Inc(E2, 1023);
    Raw := (UInt64(E2) shl 52) or (Hi and DOUBLE_MANTISSA_MASK);
  end
  else if E2 >= -1074 then
  begin
    Hi := Hi shr (-1022 - E2);
    Raw := Hi and DOUBLE_MANTISSA_MASK;
  end
  else
  begin
    AValue := 0.0;
    Exit(True);
  end;
  PUInt64(@AValue)^ := Raw;
  Result := True;
end;

function ParseDoubleFallback(const AData: PAnsiChar; const ALen: SizeUInt;
  out AValue: Double): Boolean;
var
  LBuf: array[0..1023] of AnsiChar;
  LCode: Integer;
  LActualLen: SizeUInt;
begin
  LActualLen := ALen;
  if LActualLen > 1023 then LActualLen := 1023;
  Move(AData^, LBuf[0], LActualLen);
  LBuf[LActualLen] := #0;
  Val(PAnsiChar(@LBuf[0]), AValue, LCode);
  Result := LCode = 0;
end;

function ParseDouble(const AData: PAnsiChar; const ALen: SizeUInt;
  out AValue: Double): Boolean;
var
  LPos: SizeUInt;
  LNeg: Boolean;
  LMant: UInt64;
  LExp: Int32;
  LExpNeg: Boolean;
  LExpVal: Int32;
  LHasDot: Boolean;
  LFracDigits: Int32;
begin
  AValue := 0.0;
  if ALen = 0 then
    Exit(False);

  LPos := 0;
  LNeg := False;
  if AData[LPos] = '-' then
  begin
    LNeg := True;
    Inc(LPos);
  end
  else if AData[LPos] = '+' then
    Inc(LPos);

  if LPos >= ALen then
    Exit(False);

  if (ALen - LPos >= 3) and (AData[LPos] = 'N') and
     (AData[LPos+1] = 'a') and (AData[LPos+2] = 'N') then
  begin
    AValue := 0.0 / 0.0;
    Exit(True);
  end;
  if (ALen - LPos >= 8) and (AData[LPos] = 'I') and (AData[LPos+1] = 'n') and
     (AData[LPos+2] = 'f') and (AData[LPos+3] = 'i') and (AData[LPos+4] = 'n') and
     (AData[LPos+5] = 'i') and (AData[LPos+6] = 't') and (AData[LPos+7] = 'y') then
  begin
    if LNeg then
      AValue := -1.0 / 0.0
    else
      AValue := 1.0 / 0.0;
    Exit(True);
  end;

  LMant := 0;
  LHasDot := False;
  LFracDigits := 0;

  if not IsDigit(Byte(AData[LPos])) then
    Exit(False);

  while (LPos < ALen) and IsDigit(Byte(AData[LPos])) do
  begin
    if LMant < UInt64(1844674407370955161) then
      LMant := LMant * 10 + UInt64(Byte(AData[LPos]) - Ord('0'))
    else
      Inc(LFracDigits, -1);
    Inc(LPos);
  end;

  if (LPos < ALen) and (AData[LPos] = '.') then
  begin
    LHasDot := True;
    Inc(LPos);
    while (LPos < ALen) and IsDigit(Byte(AData[LPos])) do
    begin
      if LMant < UInt64(1844674407370955161) then
      begin
        LMant := LMant * 10 + UInt64(Byte(AData[LPos]) - Ord('0'));
        Inc(LFracDigits);
      end;
      Inc(LPos);
    end;
  end;

  LExpVal := 0;
  if (LPos < ALen) and ((AData[LPos] = 'e') or (AData[LPos] = 'E')) then
  begin
    Inc(LPos);
    LExpNeg := False;
    if LPos < ALen then
    begin
      if AData[LPos] = '-' then begin LExpNeg := True; Inc(LPos); end
      else if AData[LPos] = '+' then Inc(LPos);
    end;
    while (LPos < ALen) and IsDigit(Byte(AData[LPos])) do
    begin
      LExpVal := LExpVal * 10 + (Byte(AData[LPos]) - Ord('0'));
      if LExpVal > 999 then
        Exit(False);
      Inc(LPos);
    end;
    if LExpNeg then
      LExpVal := -LExpVal;
  end;

  LExp := LExpVal - LFracDigits;

  if LPos <> ALen then
    Exit(False);

  if (LMant = 0) then
  begin
    if LNeg then
      AValue := DoublePack(True, 0, 0)
    else
      AValue := 0.0;
    Exit(True);
  end;

  if EiselLemire(LMant, LExp, AValue) then
  begin
    if LNeg then
      PUInt64(@AValue)^ := PUInt64(@AValue)^ or DOUBLE_SIGN_MASK;
    Exit(True);
  end;

  Result := ParseDoubleFallback(AData, ALen, AValue);
end;

function ViewToDouble(const AView: TStringView; out AValue: Double): Boolean;
begin
  Result := ParseDouble(AView.Data, AView.Len, AValue);
end;

end.
