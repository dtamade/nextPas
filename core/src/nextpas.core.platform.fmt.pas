unit nextpas.core.platform.fmt;

{$I nextpas.core.settings.inc}

interface

function platform_fmt_int(AValue: Int64; ABuf: PAnsiChar; ABufLen: Int32): Int32;
function platform_fmt_uint(AValue: UInt64; ABuf: PAnsiChar; ABufLen: Int32): Int32;
function platform_fmt_hex(AValue: UInt64; ABuf: PAnsiChar; ABufLen: Int32): Int32;

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

end.
