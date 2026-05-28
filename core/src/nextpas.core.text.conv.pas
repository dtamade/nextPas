unit nextpas.core.text.conv;

{$I nextpas.core.settings.inc}

interface

function IntToStr(const AValue: Int64): string;
function UIntToStr(const AValue: UInt64): string;
function IntToHex(const AValue: UInt64; const ADigits: Integer): string;

function StrToInt(const AStr: string): Int64;
function TryStrToInt(const AStr: string; out AValue: Int64): Boolean;
function TryStrToInt32(const AStr: string; out AValue: Integer): Boolean;
function TryStrToUInt64(const AStr: string; out AValue: UInt64): Boolean;

function FloatToStr(const AValue: Double): string;
function TryStrToFloat(const AStr: string; out AValue: Double): Boolean;

function TextOfChar(const ACh: Char; const ACount: Integer): string;

implementation

uses
  SysUtils;

function IntToStr(const AValue: Int64): string;
var
  LBuf: array[0..20] of Char;
  LIdx: Integer;
  LNeg: Boolean;
  LVal: UInt64;
begin
  if AValue = 0 then
    Exit('0');
  LNeg := AValue < 0;
  if LNeg then
    LVal := UInt64(-AValue)
  else
    LVal := UInt64(AValue);
  LIdx := High(LBuf);
  while LVal > 0 do
  begin
    LBuf[LIdx] := Char(Ord('0') + LVal mod 10);
    LVal := LVal div 10;
    Dec(LIdx);
  end;
  if LNeg then
  begin
    LBuf[LIdx] := '-';
    Dec(LIdx);
  end;
  SetLength(Result, High(LBuf) - LIdx);
  Move(LBuf[LIdx + 1], Result[1], High(LBuf) - LIdx);
end;

function UIntToStr(const AValue: UInt64): string;
var
  LBuf: array[0..20] of Char;
  LIdx: Integer;
  LVal: UInt64;
begin
  if AValue = 0 then
    Exit('0');
  LVal := AValue;
  LIdx := High(LBuf);
  while LVal > 0 do
  begin
    LBuf[LIdx] := Char(Ord('0') + LVal mod 10);
    LVal := LVal div 10;
    Dec(LIdx);
  end;
  SetLength(Result, High(LBuf) - LIdx);
  Move(LBuf[LIdx + 1], Result[1], High(LBuf) - LIdx);
end;

function IntToHex(const AValue: UInt64; const ADigits: Integer): string;
const
  HEX_CHARS: array[0..15] of Char = '0123456789ABCDEF';
var
  LBuf: array[0..15] of Char;
  LIdx, LLen: Integer;
  LVal: UInt64;
begin
  LVal := AValue;
  LIdx := 15;
  if LVal = 0 then
  begin
    LBuf[LIdx] := '0';
    Dec(LIdx);
  end
  else
    while LVal > 0 do
    begin
      LBuf[LIdx] := HEX_CHARS[LVal and $F];
      LVal := LVal shr 4;
      Dec(LIdx);
    end;
  LLen := 15 - LIdx;
  while LLen < ADigits do
  begin
    LBuf[LIdx] := '0';
    Dec(LIdx);
    Inc(LLen);
  end;
  SetLength(Result, LLen);
  Move(LBuf[LIdx + 1], Result[1], LLen);
end;

function TryStrToInt(const AStr: string; out AValue: Int64): Boolean;
var
  LIdx, LLen: Integer;
  LNeg: Boolean;
  LResult: UInt64;
  LDigit: Integer;
begin
  Result := False;
  LLen := Length(AStr);
  LIdx := 1;
  while (LIdx <= LLen) and (AStr[LIdx] = ' ') do
    Inc(LIdx);
  if LIdx > LLen then
    Exit;
  LNeg := False;
  if AStr[LIdx] = '-' then
  begin
    LNeg := True;
    Inc(LIdx);
  end
  else if AStr[LIdx] = '+' then
    Inc(LIdx);
  if LIdx > LLen then
    Exit;
  LResult := 0;
  while LIdx <= LLen do
  begin
    if (AStr[LIdx] < '0') or (AStr[LIdx] > '9') then
    begin
      if AStr[LIdx] = ' ' then
      begin
        Inc(LIdx);
        while (LIdx <= LLen) and (AStr[LIdx] = ' ') do
          Inc(LIdx);
        if LIdx <= LLen then
          Exit;
        Break;
      end;
      Exit;
    end;
    LDigit := Ord(AStr[LIdx]) - Ord('0');
    if LResult > (High(UInt64) - UInt64(LDigit)) div 10 then
      Exit;
    LResult := LResult * 10 + UInt64(LDigit);
    Inc(LIdx);
  end;
  if LNeg then
  begin
    if LResult > UInt64(High(Int64)) + 1 then
      Exit;
    AValue := -Int64(LResult);
  end
  else
  begin
    if LResult > UInt64(High(Int64)) then
      Exit;
    AValue := Int64(LResult);
  end;
  Result := True;
end;

function StrToInt(const AStr: string): Int64;
begin
  if not TryStrToInt(AStr, Result) then
    raise Exception.CreateFmt('StrToInt: invalid integer "%s"', [AStr]);
end;

function TryStrToInt32(const AStr: string; out AValue: Integer): Boolean;
var
  LVal: Int64;
begin
  Result := TryStrToInt(AStr, LVal);
  if Result then
  begin
    if (LVal < Low(Integer)) or (LVal > High(Integer)) then
      Exit(False);
    AValue := Integer(LVal);
  end;
end;

function TryStrToUInt64(const AStr: string; out AValue: UInt64): Boolean;
var
  LIdx, LLen: Integer;
  LDigit: Integer;
begin
  Result := False;
  LLen := Length(AStr);
  LIdx := 1;
  while (LIdx <= LLen) and (AStr[LIdx] = ' ') do
    Inc(LIdx);
  if LIdx > LLen then
    Exit;
  if AStr[LIdx] = '+' then
    Inc(LIdx);
  if (LIdx > LLen) or (AStr[LIdx] < '0') or (AStr[LIdx] > '9') then
    Exit;
  AValue := 0;
  while LIdx <= LLen do
  begin
    if (AStr[LIdx] < '0') or (AStr[LIdx] > '9') then
    begin
      if AStr[LIdx] = ' ' then
      begin
        Inc(LIdx);
        while (LIdx <= LLen) and (AStr[LIdx] = ' ') do
          Inc(LIdx);
        if LIdx <= LLen then
          Exit;
        Break;
      end;
      Exit;
    end;
    LDigit := Ord(AStr[LIdx]) - Ord('0');
    if AValue > (High(UInt64) - UInt64(LDigit)) div 10 then
      Exit;
    AValue := AValue * 10 + UInt64(LDigit);
    Inc(LIdx);
  end;
  Result := True;
end;

function FloatToStr(const AValue: Double): string;
var
  LInt: Int64;
  LFrac: Double;
  LFracStr: string;
  LDigit: Integer;
  LI: Integer;
  LNeg: Boolean;
begin
  if AValue = 0.0 then
    Exit('0');
  LNeg := AValue < 0;
  if LNeg then
    LFrac := -AValue
  else
    LFrac := AValue;
  LInt := Trunc(LFrac);
  LFrac := LFrac - LInt;
  Result := nextpas.core.text.conv.IntToStr(LInt);
  if LNeg then
    Result := '-' + Result;
  LFracStr := '.';
  for LI := 1 to 6 do
  begin
    LFrac := LFrac * 10;
    LDigit := Trunc(LFrac);
    LFracStr := LFracStr + Char(Ord('0') + LDigit);
    LFrac := LFrac - LDigit;
  end;
  LI := Length(LFracStr);
  while (LI > 2) and (LFracStr[LI] = '0') do
    Dec(LI);
  if LI = 1 then
    Exit;
  Result := Result + Copy(LFracStr, 1, LI);
end;

function TryStrToFloat(const AStr: string; out AValue: Double): Boolean;
var
  LIdx, LLen: Integer;
  LNeg: Boolean;
  LIntPart: UInt64;
  LFracPart: UInt64;
  LFracDiv: Double;
begin
  Result := False;
  LLen := Length(AStr);
  LIdx := 1;
  while (LIdx <= LLen) and (AStr[LIdx] = ' ') do
    Inc(LIdx);
  if LIdx > LLen then
    Exit;
  LNeg := False;
  if AStr[LIdx] = '-' then
  begin
    LNeg := True;
    Inc(LIdx);
  end
  else if AStr[LIdx] = '+' then
    Inc(LIdx);
  if (LIdx > LLen) or (((AStr[LIdx] < '0') or (AStr[LIdx] > '9')) and (AStr[LIdx] <> '.')) then
    Exit;
  LIntPart := 0;
  while (LIdx <= LLen) and (AStr[LIdx] >= '0') and (AStr[LIdx] <= '9') do
  begin
    LIntPart := LIntPart * 10 + UInt64(Ord(AStr[LIdx]) - Ord('0'));
    Inc(LIdx);
  end;
  LFracPart := 0;
  LFracDiv := 1.0;
  if (LIdx <= LLen) and (AStr[LIdx] = '.') then
  begin
    Inc(LIdx);
    while (LIdx <= LLen) and (AStr[LIdx] >= '0') and (AStr[LIdx] <= '9') do
    begin
      LFracPart := LFracPart * 10 + UInt64(Ord(AStr[LIdx]) - Ord('0'));
      LFracDiv := LFracDiv * 10.0;
      Inc(LIdx);
    end;
  end;
  while (LIdx <= LLen) and (AStr[LIdx] = ' ') do
    Inc(LIdx);
  if LIdx <= LLen then
    Exit;
  AValue := Double(LIntPart) + Double(LFracPart) / LFracDiv;
  if LNeg then
    AValue := -AValue;
  Result := True;
end;

function TextOfChar(const ACh: Char; const ACount: Integer): string;
var
  LI: Integer;
begin
  if ACount <= 0 then
    Exit('');
  SetLength(Result, ACount);
  for LI := 1 to ACount do
    Result[LI] := ACh;
end;

end.