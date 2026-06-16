unit nextpas.core.text.format;

{$I nextpas.core.settings.inc}

interface

function TextFormat(const AFmt: string; const AArgs: array of const): string;

implementation

uses
  nextpas.core.base,
  nextpas.core.text.builder,
  nextpas.core.text.number;

const
  MAX_FORMAT_WIDTH = 1048576;
  MAX_FORMAT_PRECISION = 1024;

function TextFormat(const AFmt: string; const AArgs: array of const): string;
var
  LIdx, LLen, LArgIdx: Integer;
  LWidth, LPrec: Integer;
  LLeftAlign: Boolean;
  LZeroPad: Boolean;
  LCh: Char;
  LSb: TStringBuilder;

  procedure RaiseInvalidFormat(const AMessage: string);
  begin
    raise EInvalidArgument.Create('TextFormat: ' + AMessage);
  end;

  procedure RaiseFormatOverflow(const AMessage: string);
  begin
    raise EOverflow.Create('TextFormat: ' + AMessage);
  end;

  procedure AppendCheckedDigit(var AValue: Integer; const ADigit, ALimit: Integer;
    const AName: string);
  begin
    if AValue > (ALimit - ADigit) div 10 then
      RaiseFormatOverflow(AName + ' exceeds supported limit');
    AValue := AValue * 10 + ADigit;
  end;

  procedure RequireArg(const AIdx: Integer);
  begin
    if AIdx > High(AArgs) then
      RaiseInvalidFormat('missing format argument');
  end;

  procedure SbAppendPadded(const AStr: string);
  var LPad: Integer; LPadCh: Char;
  begin
    LPad := LWidth - Length(AStr);
    if LPad <= 0 then
      LSb.AppendStr(AStr)
    else
    begin
      if LLeftAlign then
      begin
        LSb.AppendStr(AStr);
        LSb.AppendChars(' ', LPad);
      end
      else
      begin
        if LZeroPad then LPadCh := '0' else LPadCh := ' ';
        LSb.AppendChars(AnsiChar(LPadCh), LPad);
        LSb.AppendStr(AStr);
      end;
    end;
  end;

  function BufferToString(const ABuffer: PAnsiChar; const ALen: Int32): string;
  begin
    SetLength(Result, ALen);
    if ALen > 0 then
      Move(ABuffer^, Result[1], ALen);
  end;

  function FormatInt(const AVal: Int64): string;
  var
    LBuf: array[0..20] of AnsiChar;
    LLen: Int32;
  begin
    LLen := IntToBuffer(AVal, @LBuf[0]);
    Result := BufferToString(@LBuf[0], LLen);
  end;

  function FormatUInt(const AVal: UInt64): string;
  var
    LBuf: array[0..19] of AnsiChar;
    LLen: Int32;
  begin
    LLen := UIntToBuffer(AVal, @LBuf[0]);
    Result := BufferToString(@LBuf[0], LLen);
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
    LFrac, LRound: Double;
    LI, LDigit: Integer;
    LNeg: Boolean;
    LAbs: Double;
  begin
    if AVal <> AVal then Exit('NaN');
    if AVal = 1.0/0.0 then Exit('Inf');
    if AVal = -1.0/0.0 then Exit('-Inf');
    LNeg := AVal < 0;
    if LNeg then LAbs := -AVal else LAbs := AVal;
    if LAbs >= 9.2e18 then
    begin
      Str(AVal:0:ADigits, Result);
      Exit;
    end;
    LRound := 0.5;
    for LI := 1 to ADigits do LRound := LRound / 10;
    LAbs := LAbs + LRound;
    LInt := Trunc(LAbs);
    LFrac := LAbs - LInt;
    Result := FormatInt(LInt);
    if LNeg then Result := '-' + Result;
    Result := Result + '.';
    for LI := 1 to ADigits do
    begin
      LFrac := LFrac * 10;
      LDigit := Trunc(LFrac);
      if LDigit > 9 then LDigit := 9;
      Result := Result + Char(Ord('0') + LDigit);
      LFrac := LFrac - LDigit;
    end;
  end;

  function ApplyIntegerPrecision(const AStr: string; const AMinDigits: Integer): string;
  var
    LDigits: Integer;
    LPad: Integer;
    LStart: Integer;
  begin
    Result := AStr;
    if AMinDigits <= 0 then
      Exit;

    LStart := 1;
    if (Length(Result) > 0) and (Result[1] = '-') then
      LStart := 2;

    LDigits := Length(Result) - LStart + 1;
    LPad := AMinDigits - LDigits;
    if LPad <= 0 then
      Exit;

    if LStart = 2 then
      Result := '-' + StringOfChar('0', LPad) + Copy(Result, 2, MaxInt)
    else
      Result := StringOfChar('0', LPad) + Result;
  end;

  function GetArgInt(const AIdx: Integer): Int64;
  begin
    RequireArg(AIdx);
    case AArgs[AIdx].VType of
      vtInteger: Result := AArgs[AIdx].VInteger;
      vtInt64: Result := AArgs[AIdx].VInt64^;
      vtQWord:
      begin
        if AArgs[AIdx].VQWord^ > UInt64(High(Int64)) then
          RaiseFormatOverflow('unsigned value exceeds Int64');
        Result := Int64(AArgs[AIdx].VQWord^);
      end;
    else
      RaiseInvalidFormat('argument type does not match %d');
    end;
  end;

  function GetArgUInt(const AIdx: Integer): UInt64;
  begin
    RequireArg(AIdx);
    case AArgs[AIdx].VType of
      vtInteger: Result := UInt64(AArgs[AIdx].VInteger);
      vtInt64: Result := UInt64(AArgs[AIdx].VInt64^);
      vtQWord: Result := AArgs[AIdx].VQWord^;
    else
      RaiseInvalidFormat('argument type does not match unsigned conversion');
    end;
  end;

  function GetArgStr(const AIdx: Integer): string;
  begin
    RequireArg(AIdx);
    case AArgs[AIdx].VType of
      vtString: Result := AArgs[AIdx].VString^;
      vtAnsiString: Result := AnsiString(AArgs[AIdx].VAnsiString);
      vtChar: Result := AArgs[AIdx].VChar;
      vtPChar:
        if AArgs[AIdx].VPChar = nil then
          Result := ''
        else
          Result := AArgs[AIdx].VPChar;
    else
      RaiseInvalidFormat('argument type does not match %s');
    end;
  end;

  function GetArgFloat(const AIdx: Integer): Double;
  begin
    RequireArg(AIdx);
    case AArgs[AIdx].VType of
      vtExtended: Result := AArgs[AIdx].VExtended^;
      vtInteger: Result := AArgs[AIdx].VInteger;
      vtInt64: Result := AArgs[AIdx].VInt64^;
      vtQWord: Result := AArgs[AIdx].VQWord^;
    else
      RaiseInvalidFormat('argument type does not match %f');
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
      if LIdx > LLen then
        RaiseInvalidFormat('dangling percent');
      if AFmt[LIdx] = '%' then
      begin
        LSb.AppendChar('%');
        Inc(LIdx);
        Continue;
      end;
      LWidth := 0;
      LPrec := -1;
      LLeftAlign := False;
      LZeroPad := False;
      if AFmt[LIdx] = '-' then
      begin
        LLeftAlign := True;
        Inc(LIdx);
      end;
      if (LIdx <= LLen) and (AFmt[LIdx] = '0') and (not LLeftAlign) then
      begin
        LZeroPad := True;
        Inc(LIdx);
      end;
      while (LIdx <= LLen) and (AFmt[LIdx] >= '0') and (AFmt[LIdx] <= '9') do
      begin
        AppendCheckedDigit(LWidth, Ord(AFmt[LIdx]) - Ord('0'),
          MAX_FORMAT_WIDTH, 'width');
        Inc(LIdx);
      end;
      if (LIdx <= LLen) and (AFmt[LIdx] = '.') then
      begin
        Inc(LIdx);
        LPrec := 0;
        while (LIdx <= LLen) and (AFmt[LIdx] >= '0') and (AFmt[LIdx] <= '9') do
        begin
          AppendCheckedDigit(LPrec, Ord(AFmt[LIdx]) - Ord('0'),
            MAX_FORMAT_PRECISION, 'precision');
          Inc(LIdx);
        end;
      end;
      if LIdx > LLen then
        RaiseInvalidFormat('missing conversion specifier');
      case AFmt[LIdx] of
        'd': begin
          SbAppendPadded(ApplyIntegerPrecision(FormatInt(GetArgInt(LArgIdx)), LPrec));
          Inc(LArgIdx);
        end;
        'u': begin
          SbAppendPadded(ApplyIntegerPrecision(FormatUInt(GetArgUInt(LArgIdx)), LPrec));
          Inc(LArgIdx);
        end;
        'x': begin
          SbAppendPadded(ApplyIntegerPrecision(FormatHex(GetArgUInt(LArgIdx), False), LPrec));
          Inc(LArgIdx);
        end;
        'X': begin
          SbAppendPadded(ApplyIntegerPrecision(FormatHex(GetArgUInt(LArgIdx), True), LPrec));
          Inc(LArgIdx);
        end;
        's': begin
          SbAppendPadded(GetArgStr(LArgIdx));
          Inc(LArgIdx);
        end;
        'f': begin
          if LPrec < 0 then LPrec := 6;
          SbAppendPadded(FormatFloat(GetArgFloat(LArgIdx), LPrec));
          Inc(LArgIdx);
        end;
      else
        RaiseInvalidFormat('unsupported conversion specifier');
      end;
      Inc(LIdx);
    end;
    Result := LSb.ToString;
  finally
    LSb.Done;
  end;
end;

end.
