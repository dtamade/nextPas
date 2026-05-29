unit nextpas.core.platform.fmt;

{$I nextpas.core.settings.inc}

interface

function platform_fmt_int(AValue: Int64; ABuf: PAnsiChar; ABufLen: Int32): Int32;
function platform_fmt_uint(AValue: UInt64; ABuf: PAnsiChar; ABufLen: Int32): Int32;
function platform_fmt_hex(AValue: UInt64; ABuf: PAnsiChar; ABufLen: Int32): Int32;
function platform_fmt_float(AValue: Double; ADecimals: Int32; ABuf: PAnsiChar; ABufLen: Int32): Int32;
function platform_fmt_buf(const AFmt: PAnsiChar; const AArgs: array of const;
  ABuf: PAnsiChar; ABufLen: Int32): Int32;

function platform_parse_int(const AStr: PAnsiChar; ALen: Int32; out AValue: Int64): Int32;
function platform_parse_uint(const AStr: PAnsiChar; ALen: Int32; out AValue: UInt64): Int32;
function platform_parse_hex(const AStr: PAnsiChar; ALen: Int32; out AValue: UInt64): Int32;
function platform_parse_float(const AStr: PAnsiChar; ALen: Int32; out AValue: Double): Int32;

function platform_str_lower(const ASrc: PAnsiChar; ALen: Int32;
  ADst: PAnsiChar; ADstLen: Int32): Int32;
function platform_str_trim(const ASrc: PAnsiChar; ALen: Int32;
  ADst: PAnsiChar; ADstLen: Int32): Int32;
function platform_str_equal_nocase(const A: PAnsiChar; ALen: Int32;
  const B: PAnsiChar; BLen: Int32): Boolean;
function platform_str_find(const AHaystack: PAnsiChar; AHLen: Int32;
  const ANeedle: PAnsiChar; ANLen: Int32): Int32;
function platform_str_starts_with(const AStr: PAnsiChar; ALen: Int32;
  const APrefix: PAnsiChar; APLen: Int32): Boolean;
function platform_str_ends_with(const AStr: PAnsiChar; ALen: Int32;
  const ASuffix: PAnsiChar; ASLen: Int32): Boolean;

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

function platform_fmt_float(AValue: Double; ADecimals: Int32; ABuf: PAnsiChar; ABufLen: Int32): Int32;
var
  LNeg: Boolean;
  LIntPart: UInt64;
  LFracPart: UInt64;
  LMul: UInt64;
  LPos, LIntLen, I: Int32;
  LIntBuf: array[0..31] of AnsiChar;
  LFracBuf: array[0..31] of AnsiChar;
  LAbsVal: Double;
begin
  if (ABuf = nil) or (ABufLen <= 0) then
    Exit(-1);
  if ADecimals < 0 then ADecimals := 0;
  if ADecimals > 18 then ADecimals := 18;

  LNeg := AValue < 0;
  if LNeg then LAbsVal := -AValue else LAbsVal := AValue;

  LMul := 1;
  for I := 1 to ADecimals do
    LMul := LMul * 10;

  LIntPart := Trunc(LAbsVal);
  LFracPart := Round((LAbsVal - LIntPart) * LMul);
  if LFracPart >= LMul then
  begin
    Inc(LIntPart);
    LFracPart := 0;
  end;

  platform_fmt_uint(LIntPart, @LIntBuf[0], 32);
  LIntLen := 0;
  while LIntBuf[LIntLen] <> #0 do Inc(LIntLen);

  LPos := 0;
  if LNeg then
  begin
    if LPos >= ABufLen - 1 then begin ABuf[0] := #0; Exit(-1); end;
    ABuf[LPos] := '-'; Inc(LPos);
  end;
  for I := 0 to LIntLen - 1 do
  begin
    if LPos >= ABufLen - 1 then Break;
    ABuf[LPos] := LIntBuf[I]; Inc(LPos);
  end;

  if ADecimals > 0 then
  begin
    if LPos >= ABufLen - 1 then begin ABuf[LPos] := #0; Exit(LPos); end;
    ABuf[LPos] := '.'; Inc(LPos);

    platform_fmt_uint(LFracPart, @LFracBuf[0], 32);
    LIntLen := 0;
    while LFracBuf[LIntLen] <> #0 do Inc(LIntLen);

    for I := LIntLen to ADecimals - 1 do
    begin
      if LPos >= ABufLen - 1 then Break;
      ABuf[LPos] := '0'; Inc(LPos);
    end;
    for I := 0 to LIntLen - 1 do
    begin
      if LPos >= ABufLen - 1 then Break;
      ABuf[LPos] := LFracBuf[I]; Inc(LPos);
    end;
  end;

  ABuf[LPos] := #0;
  Result := LPos;
end;

function platform_fmt_buf(const AFmt: PAnsiChar; const AArgs: array of const;
  ABuf: PAnsiChar; ABufLen: Int32): Int32;
var
  LFmtLen, LOut, LArgIdx, I, LTmpLen, LWidth, LPad, J: Int32;
  LTmp: array[0..63] of AnsiChar;
  LSrc: PAnsiChar;
  LLeftAlign, LZeroPad: Boolean;

  procedure EmitPadded;
  var K: Int32;
  begin
    LTmpLen := 0;
    while LTmp[LTmpLen] <> #0 do Inc(LTmpLen);
    LPad := LWidth - LTmpLen;
    if LPad < 0 then LPad := 0;
    if (not LLeftAlign) and (LPad > 0) then
      for K := 1 to LPad do
        if LOut < ABufLen - 1 then
        begin
          if LZeroPad then ABuf[LOut] := '0' else ABuf[LOut] := ' ';
          Inc(LOut);
        end;
    for K := 0 to LTmpLen - 1 do
      if LOut < ABufLen - 1 then
      begin ABuf[LOut] := LTmp[K]; Inc(LOut); end;
    if LLeftAlign and (LPad > 0) then
      for K := 1 to LPad do
        if LOut < ABufLen - 1 then
        begin ABuf[LOut] := ' '; Inc(LOut); end;
  end;

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
      LLeftAlign := False;
      LZeroPad := False;
      LWidth := 0;

      if (I < LFmtLen) and (AFmt[I] = '-') then
      begin LLeftAlign := True; Inc(I); end;
      if (I < LFmtLen) and (AFmt[I] = '0') and (not LLeftAlign) then
      begin LZeroPad := True; Inc(I); end;
      while (I < LFmtLen) and (AFmt[I] >= '0') and (AFmt[I] <= '9') do
      begin
        LWidth := LWidth * 10 + (Ord(AFmt[I]) - Ord('0'));
        Inc(I);
      end;

      if I >= LFmtLen then Break;
      case AFmt[I] of
        'd': begin
          if LArgIdx <= High(AArgs) then
          begin
            case AArgs[LArgIdx].VType of
              vtInteger: platform_fmt_int(AArgs[LArgIdx].VInteger, @LTmp[0], 64);
              vtInt64:   platform_fmt_int(AArgs[LArgIdx].VInt64^, @LTmp[0], 64);
            else
              LTmp[0] := '?'; LTmp[1] := #0;
            end;
            EmitPadded;
            Inc(LArgIdx);
          end;
          Inc(I);
        end;
        'u': begin
          if LArgIdx <= High(AArgs) then
          begin
            case AArgs[LArgIdx].VType of
              vtInteger: platform_fmt_uint(UInt64(AArgs[LArgIdx].VInteger), @LTmp[0], 64);
              vtInt64:   platform_fmt_uint(UInt64(AArgs[LArgIdx].VInt64^), @LTmp[0], 64);
              vtQWord:   platform_fmt_uint(AArgs[LArgIdx].VQWord^, @LTmp[0], 64);
            else
              LTmp[0] := '?'; LTmp[1] := #0;
            end;
            EmitPadded;
            Inc(LArgIdx);
          end;
          Inc(I);
        end;
        'x': begin
          if LArgIdx <= High(AArgs) then
          begin
            case AArgs[LArgIdx].VType of
              vtInteger: platform_fmt_hex(UInt64(UInt32(AArgs[LArgIdx].VInteger)), @LTmp[0], 64);
              vtInt64:   platform_fmt_hex(UInt64(AArgs[LArgIdx].VInt64^), @LTmp[0], 64);
              vtQWord:   platform_fmt_hex(AArgs[LArgIdx].VQWord^, @LTmp[0], 64);
            else
              LTmp[0] := '?'; LTmp[1] := #0;
            end;
            EmitPadded;
            Inc(LArgIdx);
          end;
          Inc(I);
        end;
        's': begin
          if LArgIdx <= High(AArgs) then
          begin
            LSrc := nil;
            case AArgs[LArgIdx].VType of
              vtPChar:      LSrc := AArgs[LArgIdx].VPChar;
              vtAnsiString: LSrc := PAnsiChar(AArgs[LArgIdx].VAnsiString);
              vtString:     LSrc := @AArgs[LArgIdx].VString^[1];
            end;
            if LSrc = nil then LSrc := '';
            LTmpLen := 0;
            while LSrc[LTmpLen] <> #0 do Inc(LTmpLen);
            LPad := LWidth - LTmpLen;
            if LPad < 0 then LPad := 0;
            if (not LLeftAlign) and (LPad > 0) then
              for J := 1 to LPad do
                if LOut < ABufLen - 1 then begin ABuf[LOut] := ' '; Inc(LOut); end;
            for J := 0 to LTmpLen - 1 do
              if LOut < ABufLen - 1 then begin ABuf[LOut] := LSrc[J]; Inc(LOut); end;
            if LLeftAlign and (LPad > 0) then
              for J := 1 to LPad do
                if LOut < ABufLen - 1 then begin ABuf[LOut] := ' '; Inc(LOut); end;
            Inc(LArgIdx);
          end;
          Inc(I);
        end;
        'f': begin
          if LArgIdx <= High(AArgs) then
          begin
            case AArgs[LArgIdx].VType of
              vtExtended: platform_fmt_float(AArgs[LArgIdx].VExtended^, 6, @LTmp[0], 64);
            else
              LTmp[0] := '?'; LTmp[1] := #0;
            end;
            EmitPadded;
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

function platform_str_equal_nocase(const A: PAnsiChar; ALen: Int32;
  const B: PAnsiChar; BLen: Int32): Boolean;
var
  I: Int32;
  CA, CB: AnsiChar;
begin
  if ALen <> BLen then Exit(False);
  if ALen = 0 then Exit(True);
  if (A = nil) or (B = nil) then Exit(A = B);
  for I := 0 to ALen - 1 do
  begin
    CA := A[I];
    CB := B[I];
    if (CA >= 'A') and (CA <= 'Z') then CA := AnsiChar(Ord(CA) + 32);
    if (CB >= 'A') and (CB <= 'Z') then CB := AnsiChar(Ord(CB) + 32);
    if CA <> CB then Exit(False);
  end;
  Result := True;
end;

function platform_str_find(const AHaystack: PAnsiChar; AHLen: Int32;
  const ANeedle: PAnsiChar; ANLen: Int32): Int32;
var
  I, J: Int32;
  LMatch: Boolean;
begin
  if (ANLen <= 0) or (ANeedle = nil) then Exit(0);
  if (AHLen < ANLen) or (AHaystack = nil) then Exit(-1);
  for I := 0 to AHLen - ANLen do
  begin
    LMatch := True;
    for J := 0 to ANLen - 1 do
      if AHaystack[I + J] <> ANeedle[J] then
      begin
        LMatch := False;
        Break;
      end;
    if LMatch then Exit(I);
  end;
  Result := -1;
end;

function platform_str_starts_with(const AStr: PAnsiChar; ALen: Int32;
  const APrefix: PAnsiChar; APLen: Int32): Boolean;
var
  I: Int32;
begin
  if APLen <= 0 then Exit(True);
  if (ALen < APLen) or (AStr = nil) or (APrefix = nil) then Exit(False);
  for I := 0 to APLen - 1 do
    if AStr[I] <> APrefix[I] then Exit(False);
  Result := True;
end;

function platform_str_ends_with(const AStr: PAnsiChar; ALen: Int32;
  const ASuffix: PAnsiChar; ASLen: Int32): Boolean;
var
  I, LOffset: Int32;
begin
  if ASLen <= 0 then Exit(True);
  if (ALen < ASLen) or (AStr = nil) or (ASuffix = nil) then Exit(False);
  LOffset := ALen - ASLen;
  for I := 0 to ASLen - 1 do
    if AStr[LOffset + I] <> ASuffix[I] then Exit(False);
  Result := True;
end;

function platform_parse_float(const AStr: PAnsiChar; ALen: Int32; out AValue: Double): Int32;
var
  I: Int32;
  LNeg: Boolean;
  LIntPart: UInt64;
  LFracPart: UInt64;
  LFracDiv: Double;
  LExpPart: Int32;
  LExpNeg: Boolean;
  LHasDot: Boolean;
begin
  AValue := 0.0;
  if (AStr = nil) or (ALen <= 0) then Exit(-1);

  I := 0;
  LNeg := False;
  if AStr[I] = '-' then begin LNeg := True; Inc(I); end
  else if AStr[I] = '+' then Inc(I);
  if I >= ALen then Exit(-1);

  LIntPart := 0;
  LHasDot := False;
  while (I < ALen) and (AStr[I] >= '0') and (AStr[I] <= '9') do
  begin
    LIntPart := LIntPart * 10 + UInt64(Ord(AStr[I]) - Ord('0'));
    Inc(I);
  end;

  LFracPart := 0;
  LFracDiv := 1.0;
  if (I < ALen) and (AStr[I] = '.') then
  begin
    LHasDot := True;
    Inc(I);
    while (I < ALen) and (AStr[I] >= '0') and (AStr[I] <= '9') do
    begin
      LFracPart := LFracPart * 10 + UInt64(Ord(AStr[I]) - Ord('0'));
      LFracDiv := LFracDiv * 10.0;
      Inc(I);
    end;
  end;

  if (I = 0) or ((not LHasDot) and (I = Ord(LNeg))) then Exit(-1);

  AValue := Double(LIntPart) + Double(LFracPart) / LFracDiv;

  if (I < ALen) and ((AStr[I] = 'e') or (AStr[I] = 'E')) then
  begin
    Inc(I);
    LExpNeg := False;
    if (I < ALen) and (AStr[I] = '-') then begin LExpNeg := True; Inc(I); end
    else if (I < ALen) and (AStr[I] = '+') then Inc(I);
    LExpPart := 0;
    while (I < ALen) and (AStr[I] >= '0') and (AStr[I] <= '9') do
    begin
      LExpPart := LExpPart * 10 + (Ord(AStr[I]) - Ord('0'));
      Inc(I);
    end;
    if LExpNeg then
      while LExpPart > 0 do begin AValue := AValue / 10.0; Dec(LExpPart); end
    else
      while LExpPart > 0 do begin AValue := AValue * 10.0; Dec(LExpPart); end;
  end;

  if LNeg then AValue := -AValue;
  if I <> ALen then Exit(-1);
  Result := 0;
end;

end.
