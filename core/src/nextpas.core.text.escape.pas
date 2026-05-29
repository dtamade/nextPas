unit nextpas.core.text.escape;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view,
  nextpas.core.text.builder;

type
  TUnescapeError = (ueNone, ueInvalidEscape, ueInvalidUnicode, ueTruncated);

function JsonEscapeToBuffer(const ASrc: PAnsiChar; const ALen: SizeUInt;
  const ADst: PAnsiChar): SizeUInt;
procedure JsonEscapeToBuilder(const ASrc: TStringView; var ADst: TStringBuilder);
function JsonUnescapeToBuffer(const ASrc: PAnsiChar; const ALen: SizeUInt;
  const ADst: PAnsiChar; out AError: TUnescapeError): SizeUInt;
function JsonFindStringEnd(const ASrc: PAnsiChar; const ALen: SizeUInt): PtrInt;

implementation

uses
  nextpas.core.simd.base,
  nextpas.core.simd.vec16,
  nextpas.core.text.char,
  nextpas.core.text.utf8;

function HexChar(const ANibble: Byte): AnsiChar; inline;
const
  H: array[0..15] of AnsiChar = '0123456789abcdef';
begin
  Result := H[ANibble and $F];
end;

procedure EmitEscapeSeq(const ACh: Byte; const ADst: PAnsiChar; var APos: SizeUInt); inline;
begin
  ADst[APos] := '\'; Inc(APos);
  case ACh of
    Ord('"'):  begin ADst[APos] := '"'; Inc(APos); end;
    Ord('\'): begin ADst[APos] := '\'; Inc(APos); end;
    8:         begin ADst[APos] := 'b'; Inc(APos); end;
    9:         begin ADst[APos] := 't'; Inc(APos); end;
    10:        begin ADst[APos] := 'n'; Inc(APos); end;
    12:        begin ADst[APos] := 'f'; Inc(APos); end;
    13:        begin ADst[APos] := 'r'; Inc(APos); end;
  else
    ADst[APos] := 'u'; Inc(APos);
    ADst[APos] := '0'; Inc(APos);
    ADst[APos] := '0'; Inc(APos);
    ADst[APos] := HexChar((ACh shr 4) and $F); Inc(APos);
    ADst[APos] := HexChar(ACh and $F); Inc(APos);
  end;
end;

function JsonEscapeToBuffer(const ASrc: PAnsiChar; const ALen: SizeUInt;
  const ADst: PAnsiChar): SizeUInt;
var
  LPos, LOut: SizeUInt;
  LMaskQuote, LMaskBs, LMaskCtrl, LCombined: TMask16;
  LFirst: Int32;
  LSafeRun: SizeUInt;
begin
  LPos := 0;
  LOut := 0;
  while LPos + 16 <= ALen do
  begin
    LMaskQuote := Vec16CmpEq(@ASrc[LPos], Ord('"'));
    LMaskBs := Vec16CmpEq(@ASrc[LPos], Ord('\'));
    LMaskCtrl := Vec16CmpLtU(@ASrc[LPos], $20);
    LCombined := LMaskQuote or LMaskBs or LMaskCtrl;
    if LCombined = MASK16_NONE_SET then
    begin
      Move(ASrc[LPos], ADst[LOut], 16);
      Inc(LPos, 16);
      Inc(LOut, 16);
    end
    else
    begin
      LFirst := Vec16Ctz(LCombined);
      if LFirst > 0 then
      begin
        Move(ASrc[LPos], ADst[LOut], LFirst);
        Inc(LPos, SizeUInt(LFirst));
        Inc(LOut, SizeUInt(LFirst));
      end;
      EmitEscapeSeq(Byte(ASrc[LPos]), ADst, LOut);
      Inc(LPos);
    end;
  end;
  while LPos < ALen do
  begin
    if IsJsonSpecial(Byte(ASrc[LPos])) then
      EmitEscapeSeq(Byte(ASrc[LPos]), ADst, LOut)
    else
    begin
      ADst[LOut] := ASrc[LPos];
      Inc(LOut);
    end;
    Inc(LPos);
  end;
  Result := LOut;
end;

procedure JsonEscapeToBuilder(const ASrc: TStringView; var ADst: TStringBuilder);
var
  LBuf: array[0..5] of AnsiChar;
  LPos: SizeUInt;
  LMaskQuote, LMaskBs, LMaskCtrl, LCombined: TMask16;
  LFirst: Int32;
  LEscLen: SizeUInt;
begin
  if ASrc.Len = 0 then Exit;
  ADst.Reserve(ASrc.Len);
  LPos := 0;
  while LPos + 16 <= ASrc.Len do
  begin
    LMaskQuote := Vec16CmpEq(@ASrc.Data[LPos], Ord('"'));
    LMaskBs := Vec16CmpEq(@ASrc.Data[LPos], Ord('\'));
    LMaskCtrl := Vec16CmpLtU(@ASrc.Data[LPos], $20);
    LCombined := LMaskQuote or LMaskBs or LMaskCtrl;
    if LCombined = MASK16_NONE_SET then
    begin
      ADst.AppendBytes(@ASrc.Data[LPos], 16);
      Inc(LPos, 16);
    end
    else
    begin
      LFirst := Vec16Ctz(LCombined);
      if LFirst > 0 then
      begin
        ADst.AppendBytes(@ASrc.Data[LPos], SizeUInt(LFirst));
        Inc(LPos, SizeUInt(LFirst));
      end;
      LEscLen := 0;
      EmitEscapeSeq(Byte(ASrc.Data[LPos]), @LBuf[0], LEscLen);
      ADst.AppendBytes(@LBuf[0], LEscLen);
      Inc(LPos);
    end;
  end;
  while LPos < ASrc.Len do
  begin
    if IsJsonSpecial(Byte(ASrc.Data[LPos])) then
    begin
      LEscLen := 0;
      EmitEscapeSeq(Byte(ASrc.Data[LPos]), @LBuf[0], LEscLen);
      ADst.AppendBytes(@LBuf[0], LEscLen);
    end
    else
      ADst.AppendChar(ASrc.Data[LPos]);
    Inc(LPos);
  end;
end;

function JsonFindStringEnd(const ASrc: PAnsiChar; const ALen: SizeUInt): PtrInt;
var
  LPos: SizeUInt;
  LMaskQuote, LMaskBs, LCombined: TMask16;
  LFirst: Int32;
begin
  LPos := 0;
  while LPos + 16 <= ALen do
  begin
    LMaskQuote := Vec16CmpEq(@ASrc[LPos], Ord('"'));
    LMaskBs := Vec16CmpEq(@ASrc[LPos], Ord('\'));
    LCombined := LMaskQuote or LMaskBs;
    if LCombined = MASK16_NONE_SET then
      Inc(LPos, 16)
    else
    begin
      LFirst := Vec16Ctz(LCombined);
      if ASrc[LPos + SizeUInt(LFirst)] = '"' then
        Exit(PtrInt(LPos) + LFirst);
      Inc(LPos, SizeUInt(LFirst) + 2);
    end;
  end;
  while LPos < ALen do
  begin
    if ASrc[LPos] = '\' then
      Inc(LPos, 2)
    else if ASrc[LPos] = '"' then
      Exit(PtrInt(LPos))
    else
      Inc(LPos);
  end;
  Result := -1;
end;

function JsonUnescapeToBuffer(const ASrc: PAnsiChar; const ALen: SizeUInt;
  const ADst: PAnsiChar; out AError: TUnescapeError): SizeUInt;
var
  LPos, LOut: SizeUInt;
  LCh: Byte;
  LHi, LLo: UInt32;
  LCP: UInt32;
  LEncLen: Byte;

  function ParseHex4(AStart: SizeUInt): Int32;
  var
    I: SizeUInt;
    D, V: Int32;
  begin
    V := 0;
    for I := AStart to AStart + 3 do
    begin
      if I >= ALen then Exit(-1);
      D := HexDigitValue(Byte(ASrc[I]));
      if D < 0 then Exit(-1);
      V := (V shl 4) or D;
    end;
    Result := V;
  end;

begin
  AError := ueNone;
  LPos := 0;
  LOut := 0;
  while LPos < ALen do
  begin
    LCh := Byte(ASrc[LPos]);
    if LCh <> Ord('\') then
    begin
      ADst[LOut] := AnsiChar(LCh);
      Inc(LOut);
      Inc(LPos);
      Continue;
    end;
    Inc(LPos);
    if LPos >= ALen then
    begin
      AError := ueTruncated;
      Exit(LOut);
    end;
    LCh := Byte(ASrc[LPos]);
    Inc(LPos);
    case LCh of
      Ord('"'):  begin ADst[LOut] := '"'; Inc(LOut); end;
      Ord('\'): begin ADst[LOut] := '\'; Inc(LOut); end;
      Ord('/'):  begin ADst[LOut] := '/'; Inc(LOut); end;
      Ord('b'):  begin ADst[LOut] := #8; Inc(LOut); end;
      Ord('f'):  begin ADst[LOut] := #12; Inc(LOut); end;
      Ord('n'):  begin ADst[LOut] := #10; Inc(LOut); end;
      Ord('r'):  begin ADst[LOut] := #13; Inc(LOut); end;
      Ord('t'):  begin ADst[LOut] := #9; Inc(LOut); end;
      Ord('u'):
      begin
        if LPos + 4 > ALen then
        begin
          AError := ueTruncated;
          Exit(LOut);
        end;
        LHi := UInt32(ParseHex4(LPos));
        if Int32(LHi) < 0 then
        begin
          AError := ueInvalidUnicode;
          Exit(LOut);
        end;
        Inc(LPos, 4);
        if (LHi >= $D800) and (LHi <= $DBFF) then
        begin
          if (LPos + 6 <= ALen) and (ASrc[LPos] = '\') and (ASrc[LPos + 1] = 'u') then
          begin
            Inc(LPos, 2);
            LLo := UInt32(ParseHex4(LPos));
            if (Int32(LLo) < 0) or (LLo < $DC00) or (LLo > $DFFF) then
            begin
              AError := ueInvalidUnicode;
              Exit(LOut);
            end;
            Inc(LPos, 4);
            LCP := ((LHi - $D800) shl 10) or (LLo - $DC00) + $10000;
          end
          else
          begin
            AError := ueInvalidUnicode;
            Exit(LOut);
          end;
        end
        else if (LHi >= $DC00) and (LHi <= $DFFF) then
        begin
          AError := ueInvalidUnicode;
          Exit(LOut);
        end
        else
          LCP := LHi;
        LEncLen := UTF8Encode(LCP, @ADst[LOut]);
        if LEncLen = 0 then
        begin
          AError := ueInvalidUnicode;
          Exit(LOut);
        end;
        Inc(LOut, LEncLen);
      end;
    else
      AError := ueInvalidEscape;
      Exit(LOut);
    end;
  end;
  Result := LOut;
end;

end.
