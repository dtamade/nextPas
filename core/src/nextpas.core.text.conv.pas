unit nextpas.core.text.conv;

{$I nextpas.core.settings.inc}

interface

function IntToStr(const AValue: Int64): string; inline;
function UIntToStr(const AValue: UInt64): string; inline;
function FloatToStr(const AValue: Double): string; inline;
function FloatToStrF(const AValue: Double; ADecimals: Integer): string;
function FormatFloat(const AFmt: string; const AValue: Double): string;
function BoolToStr(const AValue: Boolean): string; inline;

function StrToInt(const AStr: string): Int64; inline;
function StrToIntDef(const AStr: string; const ADefault: Int64): Int64; inline;
function StrToInt64Def(const AStr: string; const ADefault: Int64): Int64; inline;
function TryStrToInt(const AStr: string; out AValue: Int64): Boolean;
function TryStrToInt(const AStr: string; out AValue: Integer): Boolean;
function TryStrToInt64(const AStr: string; out AValue: Int64): Boolean; inline;
function StrToFloat(const AStr: string): Double; inline;
function StrToFloatDef(const AStr: string; const ADefault: Double): Double;
function TryStrToFloat(const AStr: string; out AValue: Double): Boolean;
function TryStrToFloat(const AStr: string; out AValue: Single): Boolean;

function Format(const AFmt: string; const AArgs: array of const): string;

function LowerCase(const AStr: string): string;
function UpperCase(const AStr: string): string;
function Trim(const AStr: string): string;
function TrimLeft(const AStr: string): string;
function TrimRight(const AStr: string): string;
function StringReplace(const AStr, AOld, ANew: string; AAll: Boolean = False): string;

function TextOfChar(const ACh: Char; const ACount: Integer): string; inline;
function IntToHex(const AValue: UInt64; const ADigits: Integer): string;
function TryStrToInt32(const AStr: string; out AValue: Integer): Boolean;
function TryStrToUInt64(const AStr: string; out AValue: UInt64): Boolean;

implementation

uses
  nextpas.core.text.number;

{== Integer/String conversion — uses System.Str/Val ==}

function IntToStr(const AValue: Int64): string;
begin
  Str(AValue, Result);
end;

function UIntToStr(const AValue: UInt64): string;
begin
  Str(AValue, Result);
end;

{== Float/String conversion ==}

function FloatToStr(const AValue: Double): string;
var LI, LDot: Integer;
begin
  Str(AValue:0:15, Result);
  LDot := Pos('.', Result);
  if LDot > 0 then
  begin
    LI := Length(Result);
    while (LI > LDot) and (Result[LI] = '0') do
      Dec(LI);
    if LI = LDot then
      SetLength(Result, LDot - 1)
    else
      SetLength(Result, LI);
  end;
end;

function FloatToStrF(const AValue: Double; ADecimals: Integer): string;
begin
  Str(AValue:0:ADecimals, Result);
end;

function FormatFloat(const AFmt: string; const AValue: Double): string;
var LDecimals, LI: Integer;
begin
  LDecimals := 0;
  LI := Pos('.', AFmt);
  if LI > 0 then
    while (LI + LDecimals + 1 <= Length(AFmt)) and
          (AFmt[LI + LDecimals + 1] in ['0', '#']) do
      Inc(LDecimals);
  if LDecimals > 0 then
    Str(AValue:0:LDecimals, Result)
  else
    Str(AValue:0:2, Result);
  while (Length(Result) > 0) and (Result[1] = ' ') do
    Delete(Result, 1, 1);
end;

function BoolToStr(const AValue: Boolean): string;
begin
  if AValue then Result := 'true' else Result := 'false';
end;

{== String to number ==}

function StrToInt(const AStr: string): Int64;
var LCode: Integer;
begin
  Val(AStr, Result, LCode);
  if LCode <> 0 then
    Result := 0;
end;

function StrToIntDef(const AStr: string; const ADefault: Int64): Int64;
var LCode: Integer;
begin
  Val(AStr, Result, LCode);
  if LCode <> 0 then
    Result := ADefault;
end;

function StrToInt64Def(const AStr: string; const ADefault: Int64): Int64;
var LCode: Integer;
begin
  Val(AStr, Result, LCode);
  if LCode <> 0 then
    Result := ADefault;
end;

function TryStrToInt(const AStr: string; out AValue: Int64): Boolean;
var LCode: Integer; LStart, LEnd: Integer;
begin
  LStart := 1;
  LEnd := Length(AStr);
  while (LStart <= LEnd) and (AStr[LStart] <= ' ') do Inc(LStart);
  while (LEnd >= LStart) and (AStr[LEnd] <= ' ') do Dec(LEnd);
  if LStart > LEnd then begin AValue := 0; Exit(False); end;
  if (LStart = 1) and (LEnd = Length(AStr)) then
    Val(AStr, AValue, LCode)
  else
    Val(Copy(AStr, LStart, LEnd - LStart + 1), AValue, LCode);
  Result := (LCode = 0);
end;

function TryStrToInt(const AStr: string; out AValue: Integer): Boolean;
var LVal: Int64; LCode: Integer;
begin
  Val(AStr, LVal, LCode);
  Result := (LCode = 0) and (LVal >= Low(Integer)) and (LVal <= High(Integer));
  if Result then AValue := Integer(LVal);
end;

function TryStrToInt64(const AStr: string; out AValue: Int64): Boolean;
var LCode: Integer;
begin
  Val(AStr, AValue, LCode);
  Result := (LCode = 0);
end;

function StrToFloat(const AStr: string): Double;
var LCode: Integer;
begin
  Val(AStr, Result, LCode);
  if LCode <> 0 then
    Result := 0.0;
end;

function StrToFloatDef(const AStr: string; const ADefault: Double): Double;
var LCode: Integer;
begin
  Val(AStr, Result, LCode);
  if LCode <> 0 then
    Result := ADefault;
end;

function TryStrToFloat(const AStr: string; out AValue: Double): Boolean;
var LCode: Integer; LStart, LEnd: Integer;
begin
  LStart := 1;
  LEnd := Length(AStr);
  while (LStart <= LEnd) and (AStr[LStart] <= ' ') do Inc(LStart);
  while (LEnd >= LStart) and (AStr[LEnd] <= ' ') do Dec(LEnd);
  if LStart > LEnd then begin AValue := 0.0; Exit(False); end;
  if (LStart = 1) and (LEnd = Length(AStr)) then
    Val(AStr, AValue, LCode)
  else
    Val(Copy(AStr, LStart, LEnd - LStart + 1), AValue, LCode);
  Result := (LCode = 0);
end;

function TryStrToFloat(const AStr: string; out AValue: Single): Boolean;
var LDbl: Double; LCode: Integer;
begin
  Val(AStr, LDbl, LCode);
  Result := (LCode = 0);
  if Result then AValue := Single(LDbl);
end;

{== Format — self-contained printf-style implementation ==}

function Format(const AFmt: string; const AArgs: array of const): string;
var
  LI, LArgIdx, LLen: Integer;
  LTmp: string;
  LWidth, LPrec: Integer;
  LZeroPad, LLeftAlign: Boolean;
  LFmtStart: Integer;
  LPadLen: Integer;
  LBuf: array[0..1023] of AnsiChar;
  LBufPos: Integer;
  LOverflow: string;

  procedure BufAppendChar(C: AnsiChar); inline;
  begin
    if LBufPos <= High(LBuf) then
    begin
      LBuf[LBufPos] := C;
      Inc(LBufPos);
    end
    else
      LOverflow := LOverflow + C;
  end;

  procedure BufAppendStr(const S: string);
  var LK, LSLen, LSpace: Integer;
  begin
    LSLen := Length(S);
    if LSLen = 0 then Exit;
    LSpace := High(LBuf) - LBufPos + 1;
    if LSLen <= LSpace then
    begin
      Move(S[1], LBuf[LBufPos], LSLen);
      Inc(LBufPos, LSLen);
    end
    else
    begin
      if LSpace > 0 then
      begin
        Move(S[1], LBuf[LBufPos], LSpace);
        LBufPos := High(LBuf) + 1;
        LOverflow := LOverflow + Copy(S, LSpace + 1, LSLen - LSpace);
      end
      else
        LOverflow := LOverflow + S;
    end;
  end;

  procedure BufAppendPad(C: AnsiChar; ACount: Integer);
  var LK, LSpace: Integer;
  begin
    if ACount <= 0 then Exit;
    LSpace := High(LBuf) - LBufPos + 1;
    if ACount <= LSpace then
    begin
      FillChar(LBuf[LBufPos], ACount, Ord(C));
      Inc(LBufPos, ACount);
    end
    else
    begin
      if LSpace > 0 then
      begin
        FillChar(LBuf[LBufPos], LSpace, Ord(C));
        LBufPos := High(LBuf) + 1;
        LOverflow := LOverflow + StringOfChar(C, ACount - LSpace);
      end
      else
        LOverflow := LOverflow + StringOfChar(C, ACount);
    end;
  end;

  procedure ParseWidthPrec;
  var LDigit: Integer;
  begin
    LWidth := 0;
    LPrec := -1;
    LZeroPad := False;
    LLeftAlign := False;
    LFmtStart := LI;
    if (LI <= LLen) and (AFmt[LI] = '-') then begin LLeftAlign := True; Inc(LI); end;
    if (LI <= LLen) and (AFmt[LI] = '0') then begin LZeroPad := True; end;
    while (LI <= LLen) and (AFmt[LI] in ['0'..'9']) do
    begin
      LWidth := LWidth * 10 + (Ord(AFmt[LI]) - Ord('0'));
      Inc(LI);
    end;
    if (LI <= LLen) and (AFmt[LI] = '.') then
    begin
      Inc(LI);
      LPrec := 0;
      while (LI <= LLen) and (AFmt[LI] in ['0'..'9']) do
      begin
        LPrec := LPrec * 10 + (Ord(AFmt[LI]) - Ord('0'));
        Inc(LI);
      end;
    end;
  end;

  procedure EmitPadInt(const S: string);
  var LMinDigits, LPad, LSLen: Integer; LNeg: Boolean;
      LDigStart, LDigLen: Integer;
  begin
    LSLen := Length(S);
    LNeg := (LSLen > 0) and (S[1] = '-');
    if LNeg then begin LDigStart := 2; LDigLen := LSLen - 1; end
    else begin LDigStart := 1; LDigLen := LSLen; end;
    LMinDigits := LPrec;
    if LMinDigits < 0 then LMinDigits := 1;
    LPad := LWidth - LDigLen;
    if LMinDigits > LDigLen then LPad := LWidth - LMinDigits;
    if LNeg then Dec(LPad);
    if LPad < 0 then LPad := 0;

    if LLeftAlign then
    begin
      if LNeg then BufAppendChar('-');
      if LMinDigits > LDigLen then BufAppendPad('0', LMinDigits - LDigLen);
      BufAppendStr(Copy(S, LDigStart, LDigLen));
      BufAppendPad(' ', LPad);
    end
    else if LZeroPad and (LPrec < 0) then
    begin
      if LNeg then BufAppendChar('-');
      BufAppendPad('0', LPad);
      BufAppendStr(Copy(S, LDigStart, LDigLen));
    end
    else
    begin
      BufAppendPad(' ', LPad);
      if LNeg then BufAppendChar('-');
      if LMinDigits > LDigLen then BufAppendPad('0', LMinDigits - LDigLen);
      BufAppendStr(Copy(S, LDigStart, LDigLen));
    end;
  end;

  procedure EmitPadStr(const S: string);
  var LActual: Integer;
  begin
    LActual := Length(S);
    if (LPrec >= 0) and (LActual > LPrec) then LActual := LPrec;
    LPadLen := LWidth - LActual;
    if LPadLen < 0 then LPadLen := 0;
    if LLeftAlign then
    begin
      BufAppendStr(Copy(S, 1, LActual));
      BufAppendPad(' ', LPadLen);
    end
    else
    begin
      BufAppendPad(' ', LPadLen);
      BufAppendStr(Copy(S, 1, LActual));
    end;
  end;

begin
  LBufPos := 0;
  LOverflow := '';
  LArgIdx := 0;
  LLen := Length(AFmt);
  LI := 1;
  while LI <= LLen do
  begin
    if (AFmt[LI] = '%') and (LI < LLen) then
    begin
      Inc(LI);
      ParseWidthPrec;
      if LI > LLen then Break;
      case AFmt[LI] of
        'd', 'i':
          if LArgIdx <= High(AArgs) then
          begin
            case AArgs[LArgIdx].VType of
              vtInteger:  Str(AArgs[LArgIdx].VInteger, LTmp);
              vtInt64:    Str(AArgs[LArgIdx].VInt64^, LTmp);
              vtQWord:    Str(AArgs[LArgIdx].VQWord^, LTmp);
            else Str(0, LTmp);
            end;
            while (Length(LTmp) > 0) and (LTmp[1] = ' ') do Delete(LTmp, 1, 1);
            EmitPadInt(LTmp);
            Inc(LArgIdx);
          end;
        'u':
          if LArgIdx <= High(AArgs) then
          begin
            case AArgs[LArgIdx].VType of
              vtInteger:  Str(Cardinal(AArgs[LArgIdx].VInteger), LTmp);
              vtInt64:    Str(UInt64(AArgs[LArgIdx].VInt64^), LTmp);
              vtQWord:    Str(AArgs[LArgIdx].VQWord^, LTmp);
            else Str(UInt64(0), LTmp);
            end;
            while (Length(LTmp) > 0) and (LTmp[1] = ' ') do Delete(LTmp, 1, 1);
            EmitPadInt(LTmp);
            Inc(LArgIdx);
          end;
        's':
          if LArgIdx <= High(AArgs) then
          begin
            case AArgs[LArgIdx].VType of
              vtString:      LTmp := AArgs[LArgIdx].VString^;
              vtAnsiString:  LTmp := AnsiString(AArgs[LArgIdx].VAnsiString);
              vtPChar:       LTmp := AArgs[LArgIdx].VPChar;
              vtChar:        LTmp := AArgs[LArgIdx].VChar;
            else LTmp := '?';
            end;
            EmitPadStr(LTmp);
            Inc(LArgIdx);
          end;
        'x', 'X':
          if LArgIdx <= High(AArgs) then
          begin
            case AArgs[LArgIdx].VType of
              vtInteger:  LTmp := IntToHex(UInt64(Cardinal(AArgs[LArgIdx].VInteger)), 1);
              vtInt64:    LTmp := IntToHex(UInt64(AArgs[LArgIdx].VInt64^), 1);
              vtQWord:    LTmp := IntToHex(AArgs[LArgIdx].VQWord^, 1);
            else LTmp := '0';
            end;
            if AFmt[LI] = 'x' then LTmp := System.LowerCase(LTmp);
            LPrec := -1;
            EmitPadInt(LTmp);
            Inc(LArgIdx);
          end;
        'f', 'e', 'g':
          if LArgIdx <= High(AArgs) then
          begin
            if LPrec < 0 then LPrec := 6;
            case AArgs[LArgIdx].VType of
              vtExtended: Str(AArgs[LArgIdx].VExtended^:0:LPrec, LTmp);
            else Str(0.0:0:LPrec, LTmp);
            end;
            BufAppendStr(LTmp);
            Inc(LArgIdx);
          end;
        '%': BufAppendChar('%');
      else
        BufAppendChar('%');
        BufAppendChar(AFmt[LI]);
      end;
      Inc(LI);
    end
    else
    begin
      BufAppendChar(AFmt[LI]);
      Inc(LI);
    end;
  end;
  if LOverflow = '' then
    SetString(Result, @LBuf[0], LBufPos)
  else
  begin
    SetString(Result, @LBuf[0], LBufPos);
    Result := Result + LOverflow;
  end;
end;

{== String manipulation ==}

function LowerCase(const AStr: string): string;
var LI: Integer;
begin
  Result := AStr;
  for LI := 1 to Length(Result) do
    if (Result[LI] >= 'A') and (Result[LI] <= 'Z') then
      Result[LI] := Chr(Ord(Result[LI]) + 32);
end;

function UpperCase(const AStr: string): string;
var LI: Integer;
begin
  Result := AStr;
  for LI := 1 to Length(Result) do
    if (Result[LI] >= 'a') and (Result[LI] <= 'z') then
      Result[LI] := Chr(Ord(Result[LI]) - 32);
end;

function Trim(const AStr: string): string;
var LStart, LEnd: Integer;
begin
  LStart := 1;
  LEnd := Length(AStr);
  while (LStart <= LEnd) and (AStr[LStart] <= ' ') do Inc(LStart);
  while (LEnd >= LStart) and (AStr[LEnd] <= ' ') do Dec(LEnd);
  Result := Copy(AStr, LStart, LEnd - LStart + 1);
end;

function TrimLeft(const AStr: string): string;
var LStart: Integer;
begin
  LStart := 1;
  while (LStart <= Length(AStr)) and (AStr[LStart] <= ' ') do Inc(LStart);
  Result := Copy(AStr, LStart, MaxInt);
end;

function TrimRight(const AStr: string): string;
var LEnd: Integer;
begin
  LEnd := Length(AStr);
  while (LEnd >= 1) and (AStr[LEnd] <= ' ') do Dec(LEnd);
  Result := Copy(AStr, 1, LEnd);
end;

function StringReplace(const AStr, AOld, ANew: string; AAll: Boolean): string;
var LPos, LStart, LOldLen: Integer;
begin
  if AOld = '' then Exit(AStr);
  Result := '';
  LOldLen := Length(AOld);
  LStart := 1;
  repeat
    LPos := Pos(AOld, AStr, LStart);
    if LPos = 0 then
    begin
      Result := Result + Copy(AStr, LStart, MaxInt);
      Break;
    end;
    Result := Result + Copy(AStr, LStart, LPos - LStart) + ANew;
    LStart := LPos + LOldLen;
    if not AAll then
    begin
      Result := Result + Copy(AStr, LStart, MaxInt);
      Break;
    end;
  until LStart > Length(AStr);
end;

{== Misc ==}

function TextOfChar(const ACh: Char; const ACount: Integer): string;
begin
  Result := StringOfChar(ACh, ACount);
end;

function IntToHex(const AValue: UInt64; const ADigits: Integer): string;
var LBuf: array[0..31] of AnsiChar; LLen, I: Int32;
begin
  LLen := nextpas.core.text.number.IntToHexBuffer(AValue, @LBuf[0], ADigits);
  SetLength(Result, LLen);
  for I := 0 to LLen - 1 do
    if (LBuf[I] >= 'a') and (LBuf[I] <= 'f') then
      Result[I + 1] := Chr(Ord(LBuf[I]) - 32)
    else
      Result[I + 1] := LBuf[I];
end;

function TryStrToInt32(const AStr: string; out AValue: Integer): Boolean;
var LCode: Integer; LVal: Int32;
begin
  Val(AStr, LVal, LCode);
  AValue := LVal;
  Result := LCode = 0;
end;

function TryStrToUInt64(const AStr: string; out AValue: UInt64): Boolean;
var LCode: Integer;
begin
  Val(AStr, AValue, LCode);
  Result := LCode = 0;
end;

end.
