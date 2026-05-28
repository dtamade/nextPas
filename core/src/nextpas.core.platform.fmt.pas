unit nextpas.core.platform.fmt;

{$I nextpas.core.settings.inc}

interface

function platform_fmt_int(AValue: Int64; ABuf: PAnsiChar; ABufLen: Int32): Int32;
function platform_fmt_uint(AValue: UInt64; ABuf: PAnsiChar; ABufLen: Int32): Int32;
function platform_fmt_hex(AValue: UInt64; ABuf: PAnsiChar; ABufLen: Int32): Int32;
function platform_fmt_buf(const AFmt: PAnsiChar; const AArgs: array of const;
  ABuf: PAnsiChar; ABufLen: Int32): Int32;

function platform_parse_int(const AStr: PAnsiChar; ALen: Int32; out AValue: Int64): Int32;
function platform_parse_uint(const AStr: PAnsiChar; ALen: Int32; out AValue: UInt64): Int32;
function platform_parse_hex(const AStr: PAnsiChar; ALen: Int32; out AValue: UInt64): Int32;

function platform_str_lower(const ASrc: PAnsiChar; ALen: Int32;
  ADst: PAnsiChar; ADstLen: Int32): Int32;
function platform_str_trim(const ASrc: PAnsiChar; ALen: Int32;
  ADst: PAnsiChar; ADstLen: Int32): Int32;

implementation

function platform_fmt_uint(AValue: UInt64; ABuf: PAnsiChar; ABufLen: Int32): Int32;
var
  LTmp: array[0..19] of AnsiChar;
  LPos, LLen, I: Int32;
begin
  if (ABuf = nil) or (ABufLen <= 0) then
    Exit(-1);
  if AValue = 0 then
  begin
    if ABufLen >= 2 then
    begin
      ABuf[0] := '0';
      ABuf[1] := #0;
    end
    else
      ABuf[0] := #0;
    Exit(1);
  end;
  LPos := 20;
  while AValue > 0 do
  begin
    Dec(LPos);
    LTmp[LPos] := AnsiChar(Ord('0') + (AValue mod 10));
    AValue := AValue div 10;
  end;
  LLen := 20 - LPos;
  if LLen >= ABufLen then
  begin
    for I := 0 to ABufLen - 2 do
      ABuf[I] := LTmp[LPos + I];
    ABuf[ABufLen - 1] := #0;
  end
  else
  begin
    for I := 0 to LLen - 1 do
      ABuf[I] := LTmp[LPos + I];
    ABuf[LLen] := #0;
  end;
  Result := LLen;
end;

function platform_fmt_int(AValue: Int64; ABuf: PAnsiChar; ABufLen: Int32): Int32;
var
  LLen: Int32;
begin
  if (ABuf = nil) or (ABufLen <= 0) then
    Exit(-1);
  if AValue < 0 then
  begin
    if ABufLen < 2 then
    begin
      ABuf[0] := #0;
      Exit(-1);
    end;
    ABuf[0] := '-';
    LLen := platform_fmt_uint(UInt64(-AValue), @ABuf[1], ABufLen - 1);
    if LLen < 0 then Exit(-1);
    Result := LLen + 1;
  end
  else
    Result := platform_fmt_uint(UInt64(AValue), ABuf, ABufLen);
end;

function platform_fmt_hex(AValue: UInt64; ABuf: PAnsiChar; ABufLen: Int32): Int32;
const
  HexChars: array[0..15] of AnsiChar = '0123456789ABCDEF';
var
  LTmp: array[0..15] of AnsiChar;
  LPos, LLen, I: Int32;
begin
  if (ABuf = nil) or (ABufLen <= 0) then
    Exit(-1);
  if AValue = 0 then
  begin
    if ABufLen >= 2 then
    begin
      ABuf[0] := '0';
      ABuf[1] := #0;
    end
    else
      ABuf[0] := #0;
    Exit(1);
  end;
  LPos := 16;
  while AValue > 0 do
  begin
    Dec(LPos);
    LTmp[LPos] := HexChars[AValue and $F];
    AValue := AValue shr 4;
  end;
  LLen := 16 - LPos;
  if LLen >= ABufLen then
  begin
    for I := 0 to ABufLen - 2 do
      ABuf[I] := LTmp[LPos + I];
    ABuf[ABufLen - 1] := #0;
  end
  else
  begin
    for I := 0 to LLen - 1 do
      ABuf[I] := LTmp[LPos + I];
    ABuf[LLen] := #0;
  end;
  Result := LLen;
end;

function platform_fmt_buf(const AFmt: PAnsiChar; const AArgs: array of const;
  ABuf: PAnsiChar; ABufLen: Int32): Int32;
var
  LFmtLen, LOut, LArgIdx, I, LTmpLen: Int32;
  LTmp: array[0..31] of AnsiChar;
  LSrc: PAnsiChar;
begin
  if (ABuf = nil) or (ABufLen <= 0) then
    Exit(-1);
  LFmtLen := 0;
  if AFmt <> nil then
    while AFmt[LFmtLen] <> #0 do Inc(LFmtLen);
  LOut := 0;
  LArgIdx := 0;
  I := 0;
  while (I < LFmtLen) and (LOut < ABufLen - 1) do
  begin
    if (AFmt[I] = '%') and (I + 1 < LFmtLen) then
    begin
      Inc(I);
      case AFmt[I] of
        'd': begin
          if LArgIdx <= High(AArgs) then
          begin
            case AArgs[LArgIdx].VType of
              vtInteger: platform_fmt_int(AArgs[LArgIdx].VInteger, @LTmp[0], 32);
              vtInt64:   platform_fmt_int(AArgs[LArgIdx].VInt64^, @LTmp[0], 32);
            else
              LTmp[0] := '?'; LTmp[1] := #0;
            end;
            LTmpLen := 0;
            while LTmp[LTmpLen] <> #0 do Inc(LTmpLen);
            // copy LTmp to output
            LTmpLen := 0;
            while (LTmp[LTmpLen] <> #0) and (LOut < ABufLen - 1) do
            begin
              ABuf[LOut] := LTmp[LTmpLen];
              Inc(LOut);
              Inc(LTmpLen);
            end;
            Inc(LArgIdx);
          end;
          Inc(I);
        end;
        'u': begin
          if LArgIdx <= High(AArgs) then
          begin
            case AArgs[LArgIdx].VType of
              vtInteger: platform_fmt_uint(UInt64(AArgs[LArgIdx].VInteger), @LTmp[0], 32);
              vtInt64:   platform_fmt_uint(UInt64(AArgs[LArgIdx].VInt64^), @LTmp[0], 32);
              vtQWord:   platform_fmt_uint(AArgs[LArgIdx].VQWord^, @LTmp[0], 32);
            else
              LTmp[0] := '?'; LTmp[1] := #0;
            end;
            LTmpLen := 0;
            while (LTmp[LTmpLen] <> #0) and (LOut < ABufLen - 1) do
            begin
              ABuf[LOut] := LTmp[LTmpLen];
              Inc(LOut);
              Inc(LTmpLen);
            end;
            Inc(LArgIdx);
          end;
          Inc(I);
        end;
        'x': begin
          if LArgIdx <= High(AArgs) then
          begin
            case AArgs[LArgIdx].VType of
              vtInteger: platform_fmt_hex(UInt64(UInt32(AArgs[LArgIdx].VInteger)), @LTmp[0], 32);
              vtInt64:   platform_fmt_hex(UInt64(AArgs[LArgIdx].VInt64^), @LTmp[0], 32);
              vtQWord:   platform_fmt_hex(AArgs[LArgIdx].VQWord^, @LTmp[0], 32);
            else
              LTmp[0] := '?'; LTmp[1] := #0;
            end;
            LTmpLen := 0;
            while (LTmp[LTmpLen] <> #0) and (LOut < ABufLen - 1) do
            begin
              ABuf[LOut] := LTmp[LTmpLen];
              Inc(LOut);
              Inc(LTmpLen);
            end;
            Inc(LArgIdx);
          end;
          Inc(I);
        end;
        's': begin
          if LArgIdx <= High(AArgs) then
          begin
            LSrc := nil;
            case AArgs[LArgIdx].VType of
              vtPChar:     LSrc := AArgs[LArgIdx].VPChar;
              vtAnsiString: LSrc := PAnsiChar(AArgs[LArgIdx].VAnsiString);
              vtString:    LSrc := @AArgs[LArgIdx].VString^[1];
            end;
            if LSrc <> nil then
              while (LSrc^ <> #0) and (LOut < ABufLen - 1) do
              begin
                ABuf[LOut] := LSrc^;
                Inc(LOut);
                Inc(LSrc);
              end;
            Inc(LArgIdx);
          end;
          Inc(I);
        end;
        '%': begin
          ABuf[LOut] := '%';
          Inc(LOut);
          Inc(I);
        end;
      else
        ABuf[LOut] := '%';
        Inc(LOut);
      end;
    end
    else
    begin
      ABuf[LOut] := AFmt[I];
      Inc(LOut);
      Inc(I);
    end;
  end;
  ABuf[LOut] := #0;
  Result := LOut;
end;

function platform_parse_uint(const AStr: PAnsiChar; ALen: Int32; out AValue: UInt64): Int32;
var
  I: Int32;
  LDigit: UInt64;
  LPrev: UInt64;
begin
  AValue := 0;
  if (AStr = nil) or (ALen <= 0) then
    Exit(-1);
  for I := 0 to ALen - 1 do
  begin
    if (AStr[I] < '0') or (AStr[I] > '9') then
      Exit(-1);
    LDigit := UInt64(Ord(AStr[I]) - Ord('0'));
    LPrev := AValue;
    AValue := AValue * 10 + LDigit;
    if AValue < LPrev then
    begin
      AValue := 0;
      Exit(-1);
    end;
  end;
  Result := 0;
end;

function platform_parse_int(const AStr: PAnsiChar; ALen: Int32; out AValue: Int64): Int32;
var
  LU: UInt64;
  LNeg: Boolean;
  LStart, LActualLen: Int32;
begin
  AValue := 0;
  if (AStr = nil) or (ALen <= 0) then
    Exit(-1);
  LNeg := AStr[0] = '-';
  if LNeg or (AStr[0] = '+') then
    LStart := 1
  else
    LStart := 0;
  LActualLen := ALen - LStart;
  if LActualLen <= 0 then
    Exit(-1);
  if platform_parse_uint(@AStr[LStart], LActualLen, LU) <> 0 then
    Exit(-1);
  if LNeg then
  begin
    if LU > UInt64(High(Int64)) + 1 then
      Exit(-1);
    AValue := -Int64(LU);
  end
  else
  begin
    if LU > UInt64(High(Int64)) then
      Exit(-1);
    AValue := Int64(LU);
  end;
  Result := 0;
end;

function platform_parse_hex(const AStr: PAnsiChar; ALen: Int32; out AValue: UInt64): Int32;
var
  I: Int32;
  LDigit: UInt64;
  C: AnsiChar;
begin
  AValue := 0;
  if (AStr = nil) or (ALen <= 0) then
    Exit(-1);
  for I := 0 to ALen - 1 do
  begin
    C := AStr[I];
    case C of
      '0'..'9': LDigit := UInt64(Ord(C) - Ord('0'));
      'a'..'f': LDigit := UInt64(Ord(C) - Ord('a') + 10);
      'A'..'F': LDigit := UInt64(Ord(C) - Ord('A') + 10);
    else
      Exit(-1);
    end;
    if (AValue and $F000000000000000) <> 0 then
    begin
      AValue := 0;
      Exit(-1);
    end;
    AValue := (AValue shl 4) or LDigit;
  end;
  Result := 0;
end;

function platform_str_lower(const ASrc: PAnsiChar; ALen: Int32;
  ADst: PAnsiChar; ADstLen: Int32): Int32;
var
  I, LLen: Int32;
  C: AnsiChar;
begin
  if (ADst = nil) or (ADstLen <= 0) then
    Exit(-1);
  if ASrc = nil then
  begin
    ADst[0] := #0;
    Exit(0);
  end;
  if ALen < 0 then
  begin
    ALen := 0;
    while ASrc[ALen] <> #0 do Inc(ALen);
  end;
  LLen := ALen;
  if LLen >= ADstLen then
    LLen := ADstLen - 1;
  for I := 0 to LLen - 1 do
  begin
    C := ASrc[I];
    if (C >= 'A') and (C <= 'Z') then
      C := AnsiChar(Ord(C) + 32);
    ADst[I] := C;
  end;
  ADst[LLen] := #0;
  Result := LLen;
end;

function platform_str_trim(const ASrc: PAnsiChar; ALen: Int32;
  ADst: PAnsiChar; ADstLen: Int32): Int32;
var
  LStart, LEnd, LLen: Int32;
begin
  if (ADst = nil) or (ADstLen <= 0) then
    Exit(-1);
  if ASrc = nil then
  begin
    ADst[0] := #0;
    Exit(0);
  end;
  if ALen < 0 then
  begin
    ALen := 0;
    while ASrc[ALen] <> #0 do Inc(ALen);
  end;
  LStart := 0;
  while (LStart < ALen) and (ASrc[LStart] <= ' ') do
    Inc(LStart);
  LEnd := ALen;
  while (LEnd > LStart) and (ASrc[LEnd - 1] <= ' ') do
    Dec(LEnd);
  LLen := LEnd - LStart;
  if LLen >= ADstLen then
    LLen := ADstLen - 1;
  if LLen > 0 then
    Move(ASrc[LStart], ADst[0], LLen);
  ADst[LLen] := #0;
  Result := LLen;
end;

end.
