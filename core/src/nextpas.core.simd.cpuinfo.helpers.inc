type
  TCpuInfoStringArray = array of string;

// CPUInfo-local helper subset only. These helpers replace the narrow L1 text
// surface previously used by CPUInfo; they are not a general text helper API.
// New CPUInfo code should prefer the CpuInfo* names below over compatibility
// aliases such as Trim, LowerCase, Format, StringsAppend, or StringsJoin.

function CpuInfoTrim(const AStr: string): string;
var
  LStart: Integer;
  LFinish: Integer;
begin
  LStart := 1;
  LFinish := Length(AStr);
  while (LStart <= LFinish) and (AStr[LStart] <= ' ') do
    Inc(LStart);
  while (LFinish >= LStart) and (AStr[LFinish] <= ' ') do
    Dec(LFinish);
  Result := Copy(AStr, LStart, LFinish - LStart + 1);
end;

function CpuInfoLowerCaseAscii(const AStr: string): string;
var
  LIndex: Integer;
begin
  Result := AStr;
  for LIndex := 1 to Length(Result) do
    if (Result[LIndex] >= 'A') and (Result[LIndex] <= 'Z') then
      Result[LIndex] := Chr(Ord(Result[LIndex]) + 32);
end;

function CpuInfoUpperCaseAscii(const AStr: string): string;
var
  LIndex: Integer;
begin
  Result := AStr;
  for LIndex := 1 to Length(Result) do
    if (Result[LIndex] >= 'a') and (Result[LIndex] <= 'z') then
      Result[LIndex] := Chr(Ord(Result[LIndex]) - 32);
end;

function CpuInfoStrToIntDef(const AStr: string; const ADefault: Int64): Int64;
var
  LCode: Integer;
begin
  Val(CpuInfoTrim(AStr), Result, LCode);
  if LCode <> 0 then
    Result := ADefault;
end;

function CpuInfoIntToStr(const AValue: Int64): string;
begin
  Str(AValue, Result);
  Result := CpuInfoTrim(Result);
end;

function CpuInfoUIntToStr(const AValue: UInt64): string;
begin
  Str(AValue, Result);
  Result := CpuInfoTrim(Result);
end;

function CpuInfoBoolToStr(const AValue: Boolean): string;
begin
  if AValue then
    Result := 'true'
  else
    Result := 'false';
end;

function CpuInfoBoolToStr(const AValue: Boolean; const ATrue, AFalse: string): string;
begin
  if AValue then
    Result := ATrue
  else
    Result := AFalse;
end;

function CpuInfoIntToHex(const AValue: UInt64; const ADigits: Integer): string;
const
  HEX_DIGITS: array[0..15] of Char = '0123456789ABCDEF';
var
  LIndex: Integer;
  LValue: UInt64;
  LDigits: Integer;
begin
  LDigits := ADigits;
  if LDigits < 1 then
    LDigits := 1;

  SetLength(Result, LDigits);
  LValue := AValue;
  for LIndex := LDigits downto 1 do
  begin
    Result[LIndex] := HEX_DIGITS[LValue and $F];
    LValue := LValue shr 4;
  end;
end;

function CpuInfoFormatFixed(const AValue: Double; const ADecimals: Integer): string;
var
  LDecimals: Integer;
begin
  LDecimals := ADecimals;
  if LDecimals < 0 then
    LDecimals := 6;
  if LDecimals > 15 then
    LDecimals := 15;
  Str(AValue:0:LDecimals, Result);
  Result := CpuInfoTrim(Result);
end;

function CpuInfoPosEx(const ASubStr, AStr: string; const AOffset: Integer = 1): Integer;
var
  LIndex: Integer;
  LSubIndex: Integer;
  LStart: Integer;
  LMatch: Boolean;
begin
  Result := 0;
  if ASubStr = '' then
    Exit;

  LStart := AOffset;
  if LStart < 1 then
    LStart := 1;
  if (LStart > Length(AStr)) or (Length(ASubStr) > Length(AStr)) then
    Exit;

  for LIndex := LStart to Length(AStr) - Length(ASubStr) + 1 do
  begin
    LMatch := True;
    for LSubIndex := 1 to Length(ASubStr) do
      if AStr[LIndex + LSubIndex - 1] <> ASubStr[LSubIndex] then
      begin
        LMatch := False;
        Break;
      end;
    if LMatch then
      Exit(LIndex);
  end;
end;

function CpuInfoVarRecToFloat(const AValue: TVarRec): Double;
begin
  case AValue.VType of
    vtInteger:
      Result := AValue.VInteger;
    vtInt64:
      Result := AValue.VInt64^;
    vtQWord:
      Result := AValue.VQWord^;
    vtExtended:
      Result := AValue.VExtended^;
  else
    Result := 0.0;
  end;
end;

function CpuInfoFormat(const AFmt: string; const AArgs: array of const): string;
var
  LIndex: Integer;
  LArgIndex: Integer;
  LDecimals: Integer;
  LDigits: string;
  LCode: Integer;
begin
  Result := '';
  LIndex := 1;
  LArgIndex := 0;

  while LIndex <= Length(AFmt) do
  begin
    if (AFmt[LIndex] = '%') and (LIndex < Length(AFmt)) then
    begin
      Inc(LIndex);
      if AFmt[LIndex] = '%' then
      begin
        Result := Result + '%';
        Inc(LIndex);
        Continue;
      end;

      LDecimals := 6;
      if AFmt[LIndex] = '.' then
      begin
        Inc(LIndex);
        LDigits := '';
        while (LIndex <= Length(AFmt)) and (AFmt[LIndex] in ['0'..'9']) do
        begin
          LDigits := LDigits + AFmt[LIndex];
          Inc(LIndex);
        end;
        Val(LDigits, LDecimals, LCode);
        if LCode <> 0 then
          LDecimals := 6;
      end;

      if (LIndex <= Length(AFmt)) and (AFmt[LIndex] = 'f') then
      begin
        if LArgIndex <= High(AArgs) then
          Result := Result + CpuInfoFormatFixed(CpuInfoVarRecToFloat(AArgs[LArgIndex]), LDecimals)
        else
          Result := Result + CpuInfoFormatFixed(0.0, LDecimals);
        Inc(LArgIndex);
        Inc(LIndex);
        Continue;
      end;

      Result := Result + '%';
      Continue;
    end;

    Result := Result + AFmt[LIndex];
    Inc(LIndex);
  end;
end;

procedure CpuInfoStringsAppend(var AArr: TCpuInfoStringArray; const AValue: string);
begin
  SetLength(AArr, Length(AArr) + 1);
  AArr[High(AArr)] := AValue;
end;

function CpuInfoStringsJoin(const AArr: TCpuInfoStringArray; const ASep: string): string;
var
  LIndex: Integer;
begin
  Result := '';
  for LIndex := 0 to High(AArr) do
  begin
    if LIndex > 0 then
      Result := Result + ASep;
    Result := Result + AArr[LIndex];
  end;
end;

function Trim(const AStr: string): string; inline;
begin
  Result := CpuInfoTrim(AStr);
end;

function LowerCase(const AStr: string): string; inline;
begin
  Result := CpuInfoLowerCaseAscii(AStr);
end;

function UpperCase(const AStr: string): string; inline;
begin
  Result := CpuInfoUpperCaseAscii(AStr);
end;

function StrToIntDef(const AStr: string; const ADefault: Int64): Int64; inline;
begin
  Result := CpuInfoStrToIntDef(AStr, ADefault);
end;

function IntToStr(const AValue: Int64): string; inline;
begin
  Result := CpuInfoIntToStr(AValue);
end;

function BoolToStr(const AValue: Boolean): string; inline; overload;
begin
  Result := CpuInfoBoolToStr(AValue);
end;

function IntToHex(const AValue: UInt64; const ADigits: Integer): string; inline;
begin
  Result := CpuInfoIntToHex(AValue, ADigits);
end;

function PosEx(const ASubStr, AStr: string; const AOffset: Integer = 1): Integer; inline;
begin
  Result := CpuInfoPosEx(ASubStr, AStr, AOffset);
end;

function Format(const AFmt: string; const AArgs: array of const): string;
begin
  Result := CpuInfoFormat(AFmt, AArgs);
end;

procedure StringsAppend(var AArr: TCpuInfoStringArray; const AValue: string); inline;
begin
  CpuInfoStringsAppend(AArr, AValue);
end;

function StringsJoin(const AArr: TCpuInfoStringArray; const ASep: string): string; inline;
begin
  Result := CpuInfoStringsJoin(AArr, ASep);
end;
