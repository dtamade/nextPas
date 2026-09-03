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
// owner single source SIMD needs-escape predicate — bytes.ops/text.escape single source, VecWidth inline, zero-copy view, eliminates hand roll in js.intf/pure.base
function JsonNeedsEscape(const ASrc: PAnsiChar; const ALen: SizeUInt): Boolean; inline;
function JsonNeedsEscapeView(const ASrc: TStringView): Boolean; inline;
function JsonNeedsEscapeStr(const S: string): Boolean; inline;
// simple backslash unescape owner — bytes.ops single source, SIMD VecWidth inline, zero-copy, eliminates hand roll in js.eval
function TextNeedsBackslashUnescape(const ASrc: PAnsiChar; const ALen: SizeUInt): Boolean; inline;
function TextNeedsBackslashUnescapeView(const ASrc: TStringView): Boolean; inline;
function TextUnescapeBackslashToBuffer(const ASrc: PAnsiChar; const ALen: SizeUInt; const ADst: PAnsiChar): SizeUInt;
function TextUnescapeBackslashView(const ASrc: TStringView): string; inline;
// outer quote strip owner — single source for js.eval arg view (text.escape → pure.value → js.eval), O(1) first/last byte, zero-copy view, feed-back from js.eval
function TextIsQuotedView(const ASrc: TStringView): Boolean; inline;
function TextStripOuterQuotesView(const ASrc: TStringView): TStringView; inline;

implementation

uses
  nextpas.core.simd.base,
  nextpas.core.simd.vec,
  nextpas.core.bytes.ops,
  nextpas.core.text.char,
  nextpas.core.text.utf8;

function HexChar(const ANibble: Byte): AnsiChar; inline;
const
  H: array[0..15] of AnsiChar = '0123456789abcdef';
begin
  Result := H[ANibble and $F];
end;

function JsonNeedsEscape(const ASrc: PAnsiChar; const ALen: SizeUInt): Boolean; inline;
var LPos: SizeUInt; LCombined: TVecMask; LFirst: Int32;
begin
  // perf: SIMD single source VecWidth inline — same VecCmpEq pattern as JsonEscapeToBuffer/ToBuilder single source, owner text.escape, zero-copy
  LPos := 0;
  while LPos + VecWidth <= ALen do
  begin
    LCombined := VecCmpEq(@ASrc[LPos], Ord('"')) or VecCmpEq(@ASrc[LPos], Ord('\')) or VecCmpLtU(@ASrc[LPos], $20);
    if LCombined <> TVecMask(0) then Exit(True);
    Inc(LPos, VecWidth);
  end;
  while LPos < ALen do
  begin
    if IsJsonSpecial(Byte(ASrc[LPos])) then Exit(True);
    Inc(LPos);
  end;
  Result := False;
end;

function JsonNeedsEscapeView(const ASrc: TStringView): Boolean; inline;
begin
  // perf: zero-copy view warp, inline, bytes.ops single source via TStringView.Data/Len
  if ASrc.Len = 0 then Exit(False);
  Result := JsonNeedsEscape(ASrc.Data, ASrc.Len);
end;

function JsonNeedsEscapeStr(const S: string): Boolean; inline;
begin
  // perf: single SetString-free view via TStringView.FromStr, inline, zero-copy, SIMD single source
  if S = '' then Exit(False);
  Result := JsonNeedsEscape(PAnsiChar(S), SizeUInt(Length(S)));
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
                 VecCmpEq(@ASrc[LPos], Ord('\')) or
                 VecCmpLtU(@ASrc[LPos], $20);
    if LCombined = TVecMask(0) then
      Inc(LPos, VecWidth)
    else
    begin
      LFirst := VecCtz(LCombined);
      if Byte(ASrc[LPos + SizeUInt(LFirst)]) < $20 then
        Exit(-1);
      if ASrc[LPos + SizeUInt(LFirst)] = '"' then
        Exit(PtrInt(LPos) + LFirst);
      Inc(LPos, SizeUInt(LFirst) + 2);
    end;
  end;
  while LPos < ALen do
  begin
    if Byte(ASrc[LPos]) < $20 then
      Exit(-1)
    else if ASrc[LPos] = '\' then
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

function TextNeedsBackslashUnescape(const ASrc: PAnsiChar; const ALen: SizeUInt): Boolean; inline;
var LPos: SizeUInt;
begin
  LPos := 0;
  while LPos + VecWidth <= ALen do
  begin
    if VecCmpEq(@ASrc[LPos], Ord('\')) <> TVecMask(0) then Exit(True);
    Inc(LPos, VecWidth);
  end;
  while LPos < ALen do
  begin
    if ASrc[LPos] = '\' then Exit(True);
    Inc(LPos);
  end;
  Result := False;
end;

function TextNeedsBackslashUnescapeView(const ASrc: TStringView): Boolean; inline;
begin
  if ASrc.Len = 0 then Exit(False);
  Result := TextNeedsBackslashUnescape(ASrc.Data, ASrc.Len);
end;

function TextUnescapeBackslashToBuffer(const ASrc: PAnsiChar; const ALen: SizeUInt; const ADst: PAnsiChar): SizeUInt;
var LPos, LOut: SizeUInt; LMask: TVecMask; LFirst: Int32;
begin
  LPos := 0; LOut := 0;
  while LPos + VecWidth <= ALen do
  begin
    LMask := VecCmpEq(@ASrc[LPos], Ord('\'));
    if LMask = TVecMask(0) then
    begin
      BytesCopy(@ADst[LOut], @ASrc[LPos], VecWidth);
      Inc(LPos, VecWidth); Inc(LOut, VecWidth);
    end else
    begin
      LFirst := VecCtz(LMask);
      if LFirst > 0 then
      begin
        BytesCopy(@ADst[LOut], @ASrc[LPos], SizeUInt(LFirst));
        Inc(LPos, SizeUInt(LFirst)); Inc(LOut, SizeUInt(LFirst));
      end;
      Inc(LPos);
      if LPos < ALen then
      begin
        ADst[LOut] := ASrc[LPos];
        Inc(LOut); Inc(LPos);
      end;
    end;
  end;
  while LPos < ALen do
  begin
    if ASrc[LPos] <> '\' then
    begin ADst[LOut] := ASrc[LPos]; Inc(LOut); Inc(LPos); end
    else
    begin
      Inc(LPos);
      if LPos < ALen then begin ADst[LOut] := ASrc[LPos]; Inc(LOut); Inc(LPos); end;
    end;
  end;
  Result := LOut;
end;

function TextUnescapeBackslashView(const ASrc: TStringView): string; inline;
var LOut: SizeUInt;
begin
  if ASrc.Len = 0 then Exit('');
  SetLength(Result, ASrc.Len);
  LOut := TextUnescapeBackslashToBuffer(ASrc.Data, ASrc.Len, PAnsiChar(Result));
  SetLength(Result, LOut);
end;

function TextIsQuotedView(const ASrc: TStringView): Boolean; inline;
begin
  Result := (ASrc.Len >= 2) and ((ASrc.Data[0] = '"') or (ASrc.Data[0] = '''')) and (ASrc.Data[ASrc.Len - 1] = ASrc.Data[0]);
end;

function TextStripOuterQuotesView(const ASrc: TStringView): TStringView; inline;
begin
  if TextIsQuotedView(ASrc) then Result := ASrc.Slice(1, ASrc.Len - 2) else Result := ASrc;
end;

end.
