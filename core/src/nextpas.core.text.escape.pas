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
  nextpas.core.simd.vec,
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
  LCombined: TVecMask;
  LFirst: Int32;
begin
  LPos := 0;
  LOut := 0;
  while LPos + VecWidth <= ALen do
  begin
    LCombined := VecCmpEq(@ASrc[LPos], Ord('"')) or
                 VecCmpEq(@ASrc[LPos], Ord('\')) or
                 VecCmpLtU(@ASrc[LPos], $20);
    if LCombined = TVecMask(0) then
    begin
      Move(ASrc[LPos], ADst[LOut], VecWidth);
      Inc(LPos, VecWidth);
      Inc(LOut, VecWidth);
    end
    else
    begin
      LFirst := VecCtz(LCombined);
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
  LCombined: TVecMask;
  LFirst: Int32;
  LEscLen: SizeUInt;
begin
  if ASrc.Len = 0 then Exit;
  ADst.Reserve(ASrc.Len);
  LPos := 0;
  while LPos + VecWidth <= ASrc.Len do
  begin
    LCombined := VecCmpEq(@ASrc.Data[LPos], Ord('"')) or
                 VecCmpEq(@ASrc.Data[LPos], Ord('\')) or
                 VecCmpLtU(@ASrc.Data[LPos], $20);
    if LCombined = TVecMask(0) then
    begin
      ADst.AppendBytes(@ASrc.Data[LPos], VecWidth);
      Inc(LPos, VecWidth);
    end
    else
    begin
      LFirst := VecCtz(LCombined);
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
  LCombined: TVecMask;
  LFirst: Int32;
begin
  LPos := 0;
  while LPos + VecWidth <= ALen do
  begin
    LCombined := VecCmpEq(@ASrc[LPos], Ord('"')) or
                 VecCmpEq(@ASrc[LPos], Ord('\'));
    if LCombined = TVecMask(0) then
      Inc(LPos, VecWidth)
    else
    begin
      LFirst := VecCtz(LCombined);
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

function EscapeParseHex4(const ASrc: PAnsiChar; const ALen: SizeUInt;
  const AStart: SizeUInt): Int32;
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

function JsonUnescapeToBuffer(const ASrc: PAnsiChar; const ALen: SizeUInt;
  const ADst: PAnsiChar; out AError: TUnescapeError): SizeUInt;
var
  LPos, LOut: SizeUInt;
  LCh: Byte;
  LHi, LLo: UInt32;
  LCP: UInt32;
  LEncLen: Byte;
  LMask: TVecMask;
  LFirst: Int32;
begin
  AError := ueNone;
  LPos := 0;
  LOut := 0;
  while LPos + VecWidth <= ALen do
  begin
    LMask := VecCmpEq(@ASrc[LPos], Ord('\')) or
             VecCmpLtU(@ASrc[LPos], $20);
    if LMask = TVecMask(0) then
    begin
      Move(ASrc[LPos], ADst[LOut], VecWidth);
      Inc(LPos, VecWidth);
      Inc(LOut, VecWidth);
    end
    else
    begin
      LFirst := VecCtz(LMask);
      if LFirst > 0 then
      begin
        Move(ASrc[LPos], ADst[LOut], LFirst);
        Inc(LPos, SizeUInt(LFirst));
        Inc(LOut, SizeUInt(LFirst));
      end;
      if Byte(ASrc[LPos]) < $20 then
      begin
        AError := ueInvalidEscape;
        Exit(LOut);
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
          LHi := UInt32(EscapeParseHex4(ASrc, ALen, LPos));
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
              LLo := UInt32(EscapeParseHex4(ASrc, ALen, LPos));
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
  end;
  while LPos < ALen do
  begin
    LCh := Byte(ASrc[LPos]);
    if LCh <> Ord('\') then
    begin
      if LCh < $20 then
      begin
        AError := ueInvalidEscape;
        Exit(LOut);
      end;
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
        LHi := UInt32(EscapeParseHex4(ASrc, ALen, LPos));
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
            LLo := UInt32(EscapeParseHex4(ASrc, ALen, LPos));
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
