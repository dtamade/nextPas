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
function ViewToInt64(const AView: TStringView; out AValue: Int64): Boolean; inline;
function ViewToUInt64(const AView: TStringView; out AValue: UInt64): Boolean; inline;

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
begin
  if (AValue = 0) and (AMinDigits <= 1) then
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
  while Result < AMinDigits do
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

end.
