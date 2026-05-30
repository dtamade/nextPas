unit nextpas.core.text.format;

{$I nextpas.core.settings.inc}

interface

function TextFormat(const AFmt: string; const AArgs: array of const): string;

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.text.builder;

function TextFormat(const AFmt: string; const AArgs: array of const): string;
var
  LIdx, LLen, LArgIdx: Integer;
  LWidth, LPrec: Integer;
  LZeroPad: Boolean;
  LCh: Char;
  LSb: TStringBuilder;

  procedure SbAppendPadded(const AStr: string);
  var LPad: Integer; LPadCh: Char;
  begin
    LPad := LWidth - Length(AStr);
    if LPad <= 0 then
      LSb.AppendStr(AStr)
    else
    begin
      if LZeroPad then LPadCh := '0' else LPadCh := ' ';
      LSb.AppendChars(AnsiChar(LPadCh), LPad);
      LSb.AppendStr(AStr);
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
    LBufIdx: Integer;
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

  function FormatFloat(const AVal: Double; const ADigits: Integer): string;
  var
    LInt: Int64;
    LFrac: Double;
    LI, LDigit: Integer;
    LNeg: Boolean;
    LAbs: Double;
  begin
    if AVal <> AVal then Exit('NaN');
    if AVal = 1.0/0.0 then Exit('Inf');
    if AVal = -1.0/0.0 then Exit('-Inf');
    LNeg := AVal < 0;
    if LNeg then LAbs := -AVal else LAbs := AVal;
    LInt := Trunc(LAbs);
    LFrac := LAbs - LInt;
    Result := IntToStr(LInt);
    if LNeg then Result := '-' + Result;
    Result := Result + '.';
    for LI := 1 to ADigits do
    begin
      LFrac := LFrac * 10;
      LDigit := Trunc(LFrac);
      Result := Result + Char(Ord('0') + LDigit);
      LFrac := LFrac - LDigit;
    end;
  end;

  function GetArgInt(const AIdx: Integer): Int64;
  begin
    Result := 0;
    if AIdx > High(AArgs) then Exit;
    case AArgs[AIdx].VType of
      vtInteger: Result := AArgs[AIdx].VInteger;
      vtInt64: Result := AArgs[AIdx].VInt64^;
      vtQWord: Result := Int64(AArgs[AIdx].VQWord^);
    end;
  end;

  function GetArgUInt(const AIdx: Integer): UInt64;
  begin
    Result := 0;
    if AIdx > High(AArgs) then Exit;
    case AArgs[AIdx].VType of
      vtInteger: Result := UInt64(AArgs[AIdx].VInteger);
      vtInt64: Result := UInt64(AArgs[AIdx].VInt64^);
      vtQWord: Result := AArgs[AIdx].VQWord^;
    end;
  end;

  function GetArgStr(const AIdx: Integer): string;
  begin
    Result := '';
    if AIdx > High(AArgs) then Exit;
    case AArgs[AIdx].VType of
      vtString: Result := AArgs[AIdx].VString^;
      vtAnsiString: Result := AnsiString(AArgs[AIdx].VAnsiString);
      vtChar: Result := AArgs[AIdx].VChar;
      vtPChar: Result := AArgs[AIdx].VPChar;
    end;
  end;

  function GetArgFloat(const AIdx: Integer): Double;
  begin
    Result := 0.0;
    if AIdx > High(AArgs) then Exit;
    case AArgs[AIdx].VType of
      vtExtended: Result := AArgs[AIdx].VExtended^;
      vtInteger: Result := AArgs[AIdx].VInteger;
      vtInt64: Result := AArgs[AIdx].VInt64^;
    end;
  end;

begin
  LLen := Length(AFmt);
  if LLen = 0 then Exit('');
  LSb.Init(LLen + Length(AArgs) * 8);
  try
    LIdx := 1;
    LArgIdx := 0;
    while LIdx <= LLen do
    begin
      LCh := AFmt[LIdx];
      if LCh <> '%' then
      begin
        LSb.AppendChar(AnsiChar(LCh));
        Inc(LIdx);
        Continue;
      end;
      Inc(LIdx);
      if LIdx > LLen then Break;
      if AFmt[LIdx] = '%' then
      begin
        LSb.AppendChar('%');
        Inc(LIdx);
        Continue;
      end;
      LWidth := 0;
      LPrec := -1;
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
        LPrec := 0;
        while (LIdx <= LLen) and (AFmt[LIdx] >= '0') and (AFmt[LIdx] <= '9') do
        begin
          LPrec := LPrec * 10 + (Ord(AFmt[LIdx]) - Ord('0'));
          Inc(LIdx);
        end;
      end;
      if LIdx > LLen then Break;
      case AFmt[LIdx] of
        'd': begin
          SbAppendPadded(FormatInt(GetArgInt(LArgIdx)));
          Inc(LArgIdx);
        end;
        'u': begin
          SbAppendPadded(FormatUInt(GetArgUInt(LArgIdx)));
          Inc(LArgIdx);
        end;
        'x': begin
          SbAppendPadded(FormatHex(GetArgUInt(LArgIdx), False));
          Inc(LArgIdx);
        end;
        'X': begin
          SbAppendPadded(FormatHex(GetArgUInt(LArgIdx), True));
          Inc(LArgIdx);
        end;
        's': begin
          SbAppendPadded(GetArgStr(LArgIdx));
          Inc(LArgIdx);
        end;
        'f': begin
          if LPrec < 0 then LPrec := 6;
          LSb.AppendStr(FormatFloat(GetArgFloat(LArgIdx), LPrec));
          Inc(LArgIdx);
        end;
      end;
      Inc(LIdx);
    end;
    Result := LSb.ToString;
  finally
    LSb.Done;
  end;
end;

end.
