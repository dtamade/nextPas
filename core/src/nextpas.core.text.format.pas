unit nextpas.core.text.format;

{$I nextpas.core.settings.inc}

interface

function TextFormat(const AFmt: string; const AArgs: array of const): string;

implementation

uses
  nextpas.core.text.conv;

function TextFormat(const AFmt: string; const AArgs: array of const): string;
var
  LIdx, LLen, LArgIdx: Integer;
  LWidth: Integer;
  LZeroPad: Boolean;
  LCh: Char;

  procedure AppendStr(const AStr: string);
  begin
    Result := Result + AStr;
  end;

  procedure AppendPadded(const AStr: string; const AWidth: Integer; const AZero: Boolean);
  var
    LPad: Integer;
    LPadCh: Char;
  begin
    LPad := AWidth - Length(AStr);
    if LPad <= 0 then
      AppendStr(AStr)
    else
    begin
      if AZero then
        LPadCh := '0'
      else
        LPadCh := ' ';
      AppendStr(TextOfChar(LPadCh, LPad) + AStr);
    end;
  end;

  function FormatInt(const AVal: Int64): string;
  begin
    Result := IntToStr(AVal);
  end;

  function FormatUInt(const AVal: UInt64): string;
  begin
    Result := UIntToStr(AVal);
  end;

  function FormatHex(const AVal: UInt64; const AUpper: Boolean): string;
  const
    HEX_LOW: array[0..15] of Char = '0123456789abcdef';
    HEX_UP: array[0..15] of Char = '0123456789ABCDEF';
  var
    LBuf: array[0..15] of Char;
    LI, LBufIdx: Integer;
    LV: UInt64;
  begin
    LV := AVal;
    LBufIdx := 15;
    if LV = 0 then
    begin
      LBuf[LBufIdx] := '0';
      Dec(LBufIdx);
    end
    else
      while LV > 0 do
      begin
        if AUpper then
          LBuf[LBufIdx] := HEX_UP[LV and $F]
        else
          LBuf[LBufIdx] := HEX_LOW[LV and $F];
        LV := LV shr 4;
        Dec(LBufIdx);
      end;
    SetLength(Result, 15 - LBufIdx);
    Move(LBuf[LBufIdx + 1], Result[1], 15 - LBufIdx);
  end;

  function FormatFloat(const AVal: Double; const APrec: Integer): string;
  var
    LInt: Int64;
    LFrac: Double;
    LI, LDigit: Integer;
    LNeg: Boolean;
  begin
    LNeg := AVal < 0;
    if LNeg then
      LFrac := -AVal
    else
      LFrac := AVal;
    LInt := Trunc(LFrac);
    LFrac := LFrac - LInt;
    Result := IntToStr(LInt);
    if LNeg then
      Result := '-' + Result;
    Result := Result + '.';
    for LI := 1 to APrec do
    begin
      LFrac := LFrac * 10;
      LDigit := Trunc(LFrac);
      Result := Result + Char(Ord('0') + LDigit);
      LFrac := LFrac - LDigit;
    end;
  end;

  function GetArgInt(const AArgIdx: Integer): Int64;
  begin
    Result := 0;
    if AArgIdx > High(AArgs) then Exit;
    case AArgs[AArgIdx].VType of
      vtInteger: Result := AArgs[AArgIdx].VInteger;
      vtInt64: Result := AArgs[AArgIdx].VInt64^;
      vtQWord: Result := Int64(AArgs[AArgIdx].VQWord^);
    end;
  end;

  function GetArgUInt(const AArgIdx: Integer): UInt64;
  begin
    Result := 0;
    if AArgIdx > High(AArgs) then Exit;
    case AArgs[AArgIdx].VType of
      vtInteger: Result := UInt64(AArgs[AArgIdx].VInteger);
      vtInt64: Result := UInt64(AArgs[AArgIdx].VInt64^);
      vtQWord: Result := AArgs[AArgIdx].VQWord^;
    end;
  end;

  function GetArgStr(const AArgIdx: Integer): string;
  begin
    Result := '';
    if AArgIdx > High(AArgs) then Exit;
    case AArgs[AArgIdx].VType of
      vtString: Result := AArgs[AArgIdx].VString^;
      vtAnsiString: Result := AnsiString(AArgs[AArgIdx].VAnsiString);
      vtChar: Result := AArgs[AArgIdx].VChar;
      vtPChar: Result := AArgs[AArgIdx].VPChar;
    end;
  end;

  function GetArgFloat(const AArgIdx: Integer): Double;
  begin
    Result := 0.0;
    if AArgIdx > High(AArgs) then Exit;
    case AArgs[AArgIdx].VType of
      vtExtended: Result := AArgs[AArgIdx].VExtended^;
      vtInteger: Result := AArgs[AArgIdx].VInteger;
      vtInt64: Result := AArgs[AArgIdx].VInt64^;
    end;
  end;

begin
  Result := '';
  LLen := Length(AFmt);
  LIdx := 1;
  LArgIdx := 0;
  while LIdx <= LLen do
  begin
    LCh := AFmt[LIdx];
    if LCh <> '%' then
    begin
      Result := Result + LCh;
      Inc(LIdx);
      Continue;
    end;
    Inc(LIdx);
    if LIdx > LLen then
      Break;
    if AFmt[LIdx] = '%' then
    begin
      Result := Result + '%';
      Inc(LIdx);
      Continue;
    end;
    LWidth := 0;
    LZeroPad := False;
    if AFmt[LIdx] = '0' then
    begin
      LZeroPad := True;
      Inc(LIdx);
    end;
    while (LIdx <= LLen) and (AFmt[LIdx] >= '0') and (AFmt[LIdx] <= '9') do
    begin
      LWidth := LWidth * 10 + (Ord(AFmt[LIdx]) - Ord('0'));
      Inc(LIdx);
    end;
    if (LIdx <= LLen) and (AFmt[LIdx] = '.') then
    begin
      Inc(LIdx);
      LWidth := 0;
      while (LIdx <= LLen) and (AFmt[LIdx] >= '0') and (AFmt[LIdx] <= '9') do
      begin
        LWidth := LWidth * 10 + (Ord(AFmt[LIdx]) - Ord('0'));
        Inc(LIdx);
      end;
    end;
    if LIdx > LLen then
      Break;
    case AFmt[LIdx] of
      'd': begin
        AppendPadded(FormatInt(GetArgInt(LArgIdx)), LWidth, LZeroPad);
        Inc(LArgIdx);
      end;
      'u': begin
        AppendPadded(FormatUInt(GetArgUInt(LArgIdx)), LWidth, LZeroPad);
        Inc(LArgIdx);
      end;
      'x': begin
        AppendPadded(FormatHex(GetArgUInt(LArgIdx), False), LWidth, LZeroPad);
        Inc(LArgIdx);
      end;
      'X': begin
        AppendPadded(FormatHex(GetArgUInt(LArgIdx), True), LWidth, LZeroPad);
        Inc(LArgIdx);
      end;
      's': begin
        AppendPadded(GetArgStr(LArgIdx), LWidth, False);
        Inc(LArgIdx);
      end;
      'f': begin
        if LWidth = 0 then LWidth := 6;
        AppendStr(FormatFloat(GetArgFloat(LArgIdx), LWidth));
        Inc(LArgIdx);
      end;
    end;
    Inc(LIdx);
  end;
end;

end.
