unit nextpas.core.text.scan;

{$I nextpas.core.settings.inc}
{$IFDEF CPUX86_64}{$asmmode intel}{$ENDIF}

interface

uses
  nextpas.core.text.view;

type
  TJsonStringValidationError = (
    jsveNone,
    jsveInvalidEscape,
    jsveControlChar
  );

function ScanFindByte(const AData: PAnsiChar; const ALen: SizeUInt;
  const A: Byte): PtrInt;
function ScanFindByte2(const AData: PAnsiChar; const ALen: SizeUInt;
  const A, B: Byte): PtrInt;
function ScanFindByte3(const AData: PAnsiChar; const ALen: SizeUInt;
  const A, B, C: Byte): PtrInt;
function ScanFindInRange(const AData: PAnsiChar; const ALen: SizeUInt;
  const ALo, AHi: Byte): PtrInt;
function ScanFindNotInRange(const AData: PAnsiChar; const ALen: SizeUInt;
  const ALo, AHi: Byte): PtrInt;
function ScanSkipWhitespace(const AData: PAnsiChar; const ALen: SizeUInt): SizeUInt;
function ScanJsonNumber(const AData: PAnsiChar; const ALen: SizeUInt): SizeUInt;
function ScanFindSubstring(const AData: PAnsiChar; const ADataLen: SizeUInt;
  const ANeedle: PAnsiChar; const ANeedleLen: SizeUInt): PtrInt;
function ScanFindSubstringCI(const AData: PAnsiChar; const ADataLen: SizeUInt;
  const ANeedle: PAnsiChar; const ANeedleLen: SizeUInt): PtrInt;
function ScanMatchLiteral(const AData: PAnsiChar; const ALen: SizeUInt;
  const AExpected: PAnsiChar; const AExpectedLen: Byte): Boolean; inline;
function JsonValidateStringToken(const AData: PAnsiChar; const ALen: SizeUInt;
  out AError: TJsonStringValidationError;
  out AErrorOffset: SizeUInt): Boolean;
function ScanIsJsonNumberToken(const AData: PAnsiChar;
  const ALen: SizeUInt): Boolean;
function ScanJsonNumberHasIncompleteExponent(const AData: PAnsiChar;
  const ALen: SizeUInt): Boolean;
{ Length of a number-like prefix that ends in an incomplete exponent (e/E[+/-]
  without digits). Returns 0 when the input is not that shape. }
function ScanJsonNumberIncompleteExponentSpan(const AData: PAnsiChar;
  const ALen: SizeUInt): SizeUInt;
procedure ViewSkipWhitespace(var AView: TStringView); inline;
function ViewMatchLiteral(var AView: TStringView;
  const AExpected: PAnsiChar; const AExpectedLen: Byte): Boolean; inline;

type
  TScanSingleEntry = record
    Ch: AnsiChar;
    Need: Boolean;
    Found: Boolean;
    Pos: SizeUInt;
  end;
  TScanLitEntry = record
    View: TStringView;
    Need: Boolean;
    Found: Boolean;
    First: AnsiChar;
  end;

// table-driven zero-copy single-pass predicate+literal scan — L1 single source via VecWidth predicate table (simd.vec VecCmpEq/VecCtz), bytes.ops single source via TStringView Slice.Equals, B/op=0, reuse candidate for js.eval single-pass + json literal fast path sharing generic predicate table, not inline per red-line 2 (O(n) loop, I-Cache), L0-L3 keep, text.scan owner
procedure ScanPredicateTable(const V: TStringView; var Singles: array of TScanSingleEntry; var Lits: array of TScanLitEntry);

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.errors,
  nextpas.core.simd.base,
  nextpas.core.simd.vec,
  nextpas.core.simd.cpuinfo,
  nextpas.core.text.char;

function ScanFindByte(const AData: PAnsiChar; const ALen: SizeUInt;
  const A: Byte): PtrInt;
var
  LPos: SizeUInt;
  LMask: TVecMask;
begin
  LPos := 0;
  while LPos + VecWidth <= ALen do
  begin
    LMask := VecCmpEq(@AData[LPos], A);
    if LMask <> TVecMask(0) then
      Exit(PtrInt(LPos) + VecCtz(LMask));
    Inc(LPos, VecWidth);
  end;
  while LPos < ALen do
  begin
    if Byte(AData[LPos]) = A then
      Exit(PtrInt(LPos));
    Inc(LPos);
  end;
  Result := -1;
end;

function ScanFindByte2(const AData: PAnsiChar; const ALen: SizeUInt;
  const A, B: Byte): PtrInt;
var
  LPos: SizeUInt;
  LCombined: TVecMask;
begin
  LPos := 0;
  while LPos + VecWidth <= ALen do
  begin
    LCombined := VecCmpEq(@AData[LPos], A) or VecCmpEq(@AData[LPos], B);
    if LCombined <> TVecMask(0) then
      Exit(PtrInt(LPos) + VecCtz(LCombined));
    Inc(LPos, VecWidth);
  end;
  while LPos < ALen do
  begin
    if (Byte(AData[LPos]) = A) or (Byte(AData[LPos]) = B) then
      Exit(PtrInt(LPos));
    Inc(LPos);
  end;
  Result := -1;
end;

function ScanFindByte3(const AData: PAnsiChar; const ALen: SizeUInt;
  const A, B, C: Byte): PtrInt;
var
  LPos: SizeUInt;
  LCombined: TVecMask;
begin
  LPos := 0;
  while LPos + VecWidth <= ALen do
  begin
    LCombined := VecCmpEq(@AData[LPos], A) or
                 VecCmpEq(@AData[LPos], B) or
                 VecCmpEq(@AData[LPos], C);
    if LCombined <> TVecMask(0) then
      Exit(PtrInt(LPos) + VecCtz(LCombined));
    Inc(LPos, VecWidth);
  end;
  while LPos < ALen do
  begin
    if (Byte(AData[LPos]) = A) or (Byte(AData[LPos]) = B) or
       (Byte(AData[LPos]) = C) then
      Exit(PtrInt(LPos));
    Inc(LPos);
  end;
  Result := -1;
end;

function ScanFindInRange(const AData: PAnsiChar; const ALen: SizeUInt;
  const ALo, AHi: Byte): PtrInt;
var
  LPos: SizeUInt;
  LMask: TVecMask;
begin
  LPos := 0;
  while LPos + VecWidth <= ALen do
  begin
    LMask := VecCmpRange(@AData[LPos], ALo, AHi);
    if LMask <> TVecMask(0) then
      Exit(PtrInt(LPos) + VecCtz(LMask));
    Inc(LPos, VecWidth);
  end;
  while LPos < ALen do
  begin
    if (Byte(AData[LPos]) >= ALo) and (Byte(AData[LPos]) <= AHi) then
      Exit(PtrInt(LPos));
    Inc(LPos);
  end;
  Result := -1;
end;

function ScanFindNotInRange(const AData: PAnsiChar; const ALen: SizeUInt;
  const ALo, AHi: Byte): PtrInt;
var
  LPos: SizeUInt;
  LMask: TVecMask;
begin
  LPos := 0;
  while LPos + VecWidth <= ALen do
  begin
    LMask := not VecCmpRange(@AData[LPos], ALo, AHi);
    LMask := LMask and TVecMask(not TVecMask(0));
    if LMask <> TVecMask(0) then
      Exit(PtrInt(LPos) + VecCtz(LMask));
    Inc(LPos, VecWidth);
  end;
  while LPos < ALen do
  begin
    if (Byte(AData[LPos]) < ALo) or (Byte(AData[LPos]) > AHi) then
      Exit(PtrInt(LPos));
    Inc(LPos);
  end;
  Result := -1;
end;

function ScanSkipWhitespace(const AData: PAnsiChar; const ALen: SizeUInt): SizeUInt;
var
  LPos: SizeUInt;
  LWsMask: TVecMask;
begin
  LPos := 0;
  while LPos + VecWidth <= ALen do
  begin
    LWsMask := VecCmpEq(@AData[LPos], Ord(' ')) or
               VecCmpEq(@AData[LPos], 9) or
               VecCmpEq(@AData[LPos], 10) or
               VecCmpEq(@AData[LPos], 13);
    if LWsMask = TVecMask(not TVecMask(0)) then
      Inc(LPos, VecWidth)
    else
      Exit(LPos + SizeUInt(VecCtz(not LWsMask and TVecMask(not TVecMask(0)))));
  end;
  while LPos < ALen do
  begin
    if not IsWhitespace(Byte(AData[LPos])) then
      Exit(LPos);
    Inc(LPos);
  end;
  Result := LPos;
end;

function ScanJsonNumber(const AData: PAnsiChar; const ALen: SizeUInt): SizeUInt;
var
  LPos: SizeUInt;
  LCh: Byte;

  function ScanDigitsFrom(const AStart: SizeUInt): SizeUInt;
  var
    LDigitPos: SizeUInt;
    LMask: TVecMask;
  begin
    LDigitPos := AStart;
    while LDigitPos + VecWidth <= ALen do
    begin
      LMask := VecCmpRange(@AData[LDigitPos], Ord('0'), Ord('9'));
      if LMask = TVecMask(not TVecMask(0)) then
        Inc(LDigitPos, VecWidth)
      else
      begin
        Inc(LDigitPos, SizeUInt(VecCtz(not LMask and TVecMask(not TVecMask(0)))));
        Break;
      end;
    end;
    if LDigitPos + VecWidth > ALen then
      while (LDigitPos < ALen) and IsDigit(Byte(AData[LDigitPos])) do
        Inc(LDigitPos);
    Result := LDigitPos;
  end;
begin
  LPos := 0;
  if (LPos < ALen) and (AData[LPos] = '-') then
    Inc(LPos);

  if LPos >= ALen then
    Exit(0);

  LCh := Byte(AData[LPos]);
  if LCh = Ord('0') then
  begin
    Inc(LPos);
    if (LPos < ALen) and IsDigit(Byte(AData[LPos])) then
      Exit(0);
  end
  else if (LCh >= Ord('1')) and (LCh <= Ord('9')) then
    LPos := ScanDigitsFrom(LPos)
  else
    Exit(0);

  if (LPos < ALen) and (AData[LPos] = '.') then
  begin
    if ((LPos + 1) >= ALen) or not IsDigit(Byte(AData[LPos + 1])) then
      Exit(0);
    Inc(LPos);
    LPos := ScanDigitsFrom(LPos);
  end;

  if LPos < ALen then
  begin
    LCh := Byte(AData[LPos]);
    if (LCh = Ord('e')) or (LCh = Ord('E')) then
    begin
      Inc(LPos);
      if LPos < ALen then
      begin
        LCh := Byte(AData[LPos]);
        if (LCh = Ord('+')) or (LCh = Ord('-')) then
          Inc(LPos);
      end;
      if (LPos >= ALen) or not IsDigit(Byte(AData[LPos])) then
        Exit(0);
      LPos := ScanDigitsFrom(LPos);
    end;
  end;
  Result := LPos;
end;

function ScanFindSubstring(const AData: PAnsiChar; const ADataLen: SizeUInt;
  const ANeedle: PAnsiChar; const ANeedleLen: SizeUInt): PtrInt;
var
  LFirstByte, LLastByte: Byte;
  LSearchLen: SizeUInt;
  LPos: SizeUInt;
  LMask1, LMask2, LCombined: TVecMask;
  LBit: Int32;
  LCandidate: SizeUInt;
  {$IFDEF CPUX86_64}
  LMask32: UInt32;
  {$ENDIF}
begin
  if ANeedleLen = 0 then
    Exit(0);
  if ANeedleLen = 1 then
    Exit(ScanFindByte(AData, ADataLen, Byte(ANeedle[0])));
  if ANeedleLen > ADataLen then
    Exit(-1);

  LFirstByte := Byte(ANeedle[0]);
  LLastByte := Byte(ANeedle[ANeedleLen - 1]);
  LSearchLen := ADataLen - ANeedleLen + 1;

  {$IFDEF CPUX86_64}
  if HasAVX2 then
  begin
    LPos := 0;
    while LPos + 32 <= LSearchLen do
    begin
      asm
        movzx eax, byte [LFirstByte]
        vmovd xmm0, eax
        vpbroadcastb ymm0, xmm0
        movzx eax, byte [LLastByte]
        vmovd xmm1, eax
        vpbroadcastb ymm1, xmm1

        mov rcx, [AData]
        add rcx, [LPos]
        vpcmpeqb ymm2, ymm0, ymmword [rcx]

        mov rax, [ANeedleLen]
        dec rax
        add rcx, rax
        vpcmpeqb ymm3, ymm1, ymmword [rcx]

        vpand ymm2, ymm2, ymm3
        vpmovmskb eax, ymm2
        mov [LMask32], eax
      end;
      while LMask32 <> 0 do
      begin
        asm
          bsf eax, [LMask32]
          mov [LBit], eax
        end;
        LCandidate := LPos + SizeUInt(LBit);
        if LCandidate < LSearchLen then
        begin
          if CompareMem(@AData[LCandidate + 1], @ANeedle[1], ANeedleLen - 2) then
          begin
            asm vzeroupper end;
            Exit(PtrInt(LCandidate));
          end;
        end;
        LMask32 := LMask32 and (LMask32 - 1);
      end;
      Inc(LPos, 32);
    end;
    asm vzeroupper end;
    // Fall through to SSE2/scalar for remaining bytes
  end;
  {$ENDIF}

  LPos := 0;
  while LPos + VecWidth <= LSearchLen do
  begin
    LMask1 := VecCmpEq(@AData[LPos], LFirstByte);
    LMask2 := VecCmpEq(@AData[LPos + ANeedleLen - 1], LLastByte);
    LCombined := LMask1 and LMask2;
    while LCombined <> TVecMask(0) do
    begin
      LBit := VecCtz(LCombined);
      LCandidate := LPos + SizeUInt(LBit);
      if LCandidate < LSearchLen then
      begin
        if CompareMem(@AData[LCandidate + 1], @ANeedle[1], ANeedleLen - 2) then
          Exit(PtrInt(LCandidate));
      end;
      LCombined := LCombined and (LCombined - 1);
    end;
    Inc(LPos, VecWidth);
  end;

  { Scalar tail }
  while LPos < LSearchLen do
  begin
    if (Byte(AData[LPos]) = LFirstByte) and
       (Byte(AData[LPos + ANeedleLen - 1]) = LLastByte) then
    begin
      if CompareMem(@AData[LPos + 1], @ANeedle[1], ANeedleLen - 2) then
        Exit(PtrInt(LPos));
    end;
    Inc(LPos);
  end;
  Result := -1;
end;

function ASCIIToLower(const ACh: Byte): Byte; inline;
begin
  Result := ACh;
  if (Result >= Ord('A')) and (Result <= Ord('Z')) then
    Inc(Result, 32);
end;

function ASCIIToUpper(const ACh: Byte): Byte; inline;
begin
  Result := ACh;
  if (Result >= Ord('a')) and (Result <= Ord('z')) then
    Dec(Result, 32);
end;

function CIMatch(const AData, ANeedle: PAnsiChar; ALen: SizeUInt): Boolean; inline;
var K: SizeUInt;
begin
  for K := 0 to ALen - 1 do
  begin
    if ASCIIToLower(Byte(AData[K])) <> ASCIIToLower(Byte(ANeedle[K])) then
      Exit(False);
  end;
  Result := True;
end;

function ScanFindSubstringCI(const AData: PAnsiChar; const ADataLen: SizeUInt;
  const ANeedle: PAnsiChar; const ANeedleLen: SizeUInt): PtrInt;
var
  LFirstLo, LFirstHi, LLastLo, LLastHi: Byte;
  LSearchLen: SizeUInt;
  LPos: SizeUInt;
  LMask1, LMask2, LCombined: TVecMask;
  LBit: Int32;
  LCandidate: SizeUInt;
begin
  if ANeedleLen = 0 then Exit(0);
  if ANeedleLen > ADataLen then Exit(-1);

  LFirstLo := ASCIIToLower(Byte(ANeedle[0]));
  LFirstHi := ASCIIToUpper(Byte(ANeedle[0]));
  LLastLo := ASCIIToLower(Byte(ANeedle[ANeedleLen - 1]));
  LLastHi := ASCIIToUpper(Byte(ANeedle[ANeedleLen - 1]));
  LSearchLen := ADataLen - ANeedleLen + 1;

  LPos := 0;
  while LPos + VecWidth <= LSearchLen do
  begin
    LMask1 := VecCmpEq(@AData[LPos], LFirstLo) or VecCmpEq(@AData[LPos], LFirstHi);
    LMask2 := VecCmpEq(@AData[LPos + ANeedleLen - 1], LLastLo) or
              VecCmpEq(@AData[LPos + ANeedleLen - 1], LLastHi);
    LCombined := LMask1 and LMask2;
    while LCombined <> TVecMask(0) do
    begin
      LBit := VecCtz(LCombined);
      LCandidate := LPos + SizeUInt(LBit);
      if LCandidate < LSearchLen then
        if CIMatch(@AData[LCandidate], ANeedle, ANeedleLen) then
          Exit(PtrInt(LCandidate));
      LCombined := LCombined and (LCombined - 1);
    end;
    Inc(LPos, VecWidth);
  end;

  while LPos < LSearchLen do
  begin
    if CIMatch(@AData[LPos], ANeedle, ANeedleLen) then
      Exit(PtrInt(LPos));
    Inc(LPos);
  end;
  Result := -1;
end;

function ScanMatchLiteral(const AData: PAnsiChar; const ALen: SizeUInt;
  const AExpected: PAnsiChar; const AExpectedLen: Byte): Boolean;
var
  I: SizeUInt;
begin
  if AExpectedLen = 0 then
    Exit(True);
  if ALen < AExpectedLen then
    Exit(False);
  I := 0;
  while I < AExpectedLen do
  begin
    if AData[I] <> AExpected[I] then
      Exit(False);
    Inc(I);
  end;
  Result := True;
end;

procedure ViewSkipWhitespace(var AView: TStringView);
var
  LSkipped: SizeUInt;
begin
  LSkipped := ScanSkipWhitespace(AView.Data, AView.Len);
  if LSkipped > 0 then
    AView.Advance(LSkipped);
end;

function ViewMatchLiteral(var AView: TStringView;
  const AExpected: PAnsiChar; const AExpectedLen: Byte): Boolean;
begin
  Result := ScanMatchLiteral(AView.Data, AView.Len, AExpected, AExpectedLen);
  if Result then
    AView.Advance(AExpectedLen);
end;

function JsonValidateParseHex4(const AData: PAnsiChar; const ALen: SizeUInt;
  const AStart: SizeUInt): Int32;
var
  I: SizeUInt;
  D, V: Int32;
begin
  V := 0;
  for I := AStart to AStart + 3 do
  begin
    if I >= ALen then
      Exit(-1);
    D := HexDigitValue(Byte(AData[I]));
    if D < 0 then
      Exit(-1);
    V := (V shl 4) or D;
  end;
  Result := V;
end;

function JsonValidateStringToken(const AData: PAnsiChar; const ALen: SizeUInt;
  out AError: TJsonStringValidationError;
  out AErrorOffset: SizeUInt): Boolean;
var
  LPos: SizeUInt;
  LCh: Byte;
  LHi, LLo: UInt32;
begin
  { RFC 8259 §7: reject control bytes and invalid/truncated escapes. }
  AError := jsveNone;
  AErrorOffset := 0;
  LPos := 0;
  while LPos < ALen do
  begin
    LCh := Byte(AData[LPos]);
    if LCh < $20 then
    begin
      AError := jsveControlChar;
      AErrorOffset := LPos;
      Exit(False);
    end;
    if LCh <> Ord('\') then
    begin
      Inc(LPos);
      Continue;
    end;

    AErrorOffset := LPos;
    Inc(LPos);
    if LPos >= ALen then
    begin
      AError := jsveInvalidEscape;
      Exit(False);
    end;
    LCh := Byte(AData[LPos]);
    Inc(LPos);
    case LCh of
      Ord('"'), Ord('\'), Ord('/'), Ord('b'), Ord('f'), Ord('n'), Ord('r'),
      Ord('t'):
        ;
      Ord('u'):
      begin
        if LPos + 4 > ALen then
        begin
          AError := jsveInvalidEscape;
          Exit(False);
        end;
        LHi := UInt32(JsonValidateParseHex4(AData, ALen, LPos));
        if Int32(LHi) < 0 then
        begin
          AError := jsveInvalidEscape;
          Exit(False);
        end;
        Inc(LPos, 4);
        if (LHi >= $D800) and (LHi <= $DBFF) then
        begin
          if (LPos + 6 > ALen) or (AData[LPos] <> '\') or
            (AData[LPos + 1] <> 'u') then
          begin
            AError := jsveInvalidEscape;
            Exit(False);
          end;
          Inc(LPos, 2);
          LLo := UInt32(JsonValidateParseHex4(AData, ALen, LPos));
          if (Int32(LLo) < 0) or (LLo < $DC00) or (LLo > $DFFF) then
          begin
            AError := jsveInvalidEscape;
            Exit(False);
          end;
          Inc(LPos, 4);
        end
        else if (LHi >= $DC00) and (LHi <= $DFFF) then
        begin
          AError := jsveInvalidEscape;
          Exit(False);
        end;
      end;
    else
      AError := jsveInvalidEscape;
      Exit(False);
    end;
  end;
  Result := True;
end;

function ScanIsJsonNumberToken(const AData: PAnsiChar;
  const ALen: SizeUInt): Boolean;
var
  LPos: SizeUInt;
  LCh: Byte;
begin
  Result := False;
  if ALen = 0 then
    Exit;
  LPos := 0;
  // optional minus
  if Byte(AData[0]) = Ord('-') then
  begin
    LPos := 1;
    if LPos >= ALen then
      Exit;
  end;
  LCh := Byte(AData[LPos]);
  // integer part: must start with 1-9 or be just "0"
  if LCh = Ord('0') then
    Inc(LPos)
  else if (LCh >= Ord('1')) and (LCh <= Ord('9')) then
  begin
    Inc(LPos);
    while (LPos < ALen) and (Byte(AData[LPos]) >= Ord('0'))
      and (Byte(AData[LPos]) <= Ord('9')) do
      Inc(LPos);
  end
  else
    Exit;
  // optional fraction
  if (LPos < ALen) and (Byte(AData[LPos]) = Ord('.')) then
  begin
    Inc(LPos);
    if (LPos >= ALen) or (Byte(AData[LPos]) < Ord('0'))
      or (Byte(AData[LPos]) > Ord('9')) then
      Exit;
    while (LPos < ALen) and (Byte(AData[LPos]) >= Ord('0'))
      and (Byte(AData[LPos]) <= Ord('9')) do
      Inc(LPos);
  end;
  // optional exponent
  if (LPos < ALen) and ((Byte(AData[LPos]) = Ord('e')) or (Byte(AData[LPos]) = Ord('E'))) then
  begin
    Inc(LPos);
    if (LPos < ALen) and ((Byte(AData[LPos]) = Ord('+')) or (Byte(AData[LPos]) = Ord('-'))) then
      Inc(LPos);
    if (LPos >= ALen) or (Byte(AData[LPos]) < Ord('0'))
      or (Byte(AData[LPos]) > Ord('9')) then
      Exit;
    while (LPos < ALen) and (Byte(AData[LPos]) >= Ord('0'))
      and (Byte(AData[LPos]) <= Ord('9')) do
      Inc(LPos);
  end;
  Result := LPos >= ALen;
end;

function ScanJsonNumberHasIncompleteExponent(const AData: PAnsiChar;
  const ALen: SizeUInt): Boolean;
var
  LPos: SizeUInt;
begin
  Result := False;
  if ALen = 0 then
    Exit;
  // Find 'e' or 'E' from the end region
  LPos := ALen;
  while LPos > 0 do
  begin
    Dec(LPos);
    if (Byte(AData[LPos]) = Ord('e')) or (Byte(AData[LPos]) = Ord('E')) then
    begin
      // exponent exists but may be incomplete (no digits after e/E [+/-])
      Inc(LPos);
      if (LPos < ALen) and ((Byte(AData[LPos]) = Ord('+')) or (Byte(AData[LPos]) = Ord('-'))) then
        Inc(LPos);
      // incomplete if no digits follow
      Result := LPos >= ALen;
      Exit;
    end;
  end;
end;

function ScanJsonNumberIncompleteExponentSpan(const AData: PAnsiChar;
  const ALen: SizeUInt): SizeUInt;
var
  LPos: SizeUInt;
  LCh: Byte;
begin
  Result := 0;
  LPos := 0;
  if (LPos < ALen) and (AData[LPos] = '-') then
    Inc(LPos);
  if LPos >= ALen then
    Exit;
  LCh := Byte(AData[LPos]);
  if LCh = Ord('0') then
  begin
    Inc(LPos);
    if (LPos < ALen) and IsDigit(Byte(AData[LPos])) then
      Exit;
  end
  else if (LCh >= Ord('1')) and (LCh <= Ord('9')) then
  begin
    Inc(LPos);
    while (LPos < ALen) and IsDigit(Byte(AData[LPos])) do
      Inc(LPos);
  end
  else
    Exit;

  if (LPos < ALen) and (AData[LPos] = '.') then
  begin
    if ((LPos + 1) >= ALen) or not IsDigit(Byte(AData[LPos + 1])) then
      Exit;
    Inc(LPos);
    while (LPos < ALen) and IsDigit(Byte(AData[LPos])) do
      Inc(LPos);
  end;

  if LPos >= ALen then
    Exit;
  LCh := Byte(AData[LPos]);
  if (LCh <> Ord('e')) and (LCh <> Ord('E')) then
    Exit;
  Inc(LPos);
  if (LPos < ALen) and
    ((Byte(AData[LPos]) = Ord('+')) or (Byte(AData[LPos]) = Ord('-'))) then
    Inc(LPos);
  if (LPos < ALen) and IsDigit(Byte(AData[LPos])) then
    Exit;
  Result := LPos;
end;

// ScanPredicateTable — generic table-driven single-pass SIMD VecWidth predicate table single source, zero-copy views via TStringView Slice.Equals (bytes.ops single source), VecWidth single pass + tail VecWidth overlapping single pass (short <VecWidth scalar branchless), not inline per red-line 2 (O(n) single scan vs O(k*n) multi-pass), B/op=0, reuse candidate for js.eval + json literal fast path
procedure ScanPredicateTable(const V: TStringView; var Singles: array of TScanSingleEntry; var Lits: array of TScanLitEntry);
var
  LLen, LPos: SizeUInt;
  LCombined: TVecMask;
  I, J: Integer;
  B: AnsiChar;
  function AllDone: Boolean; inline;
  var K: Integer;
  begin
    for K := 0 to High(Singles) do if Singles[K].Need and not Singles[K].Found then Exit(False);
    for K := 0 to High(Lits) do if Lits[K].Need and not Lits[K].Found then Exit(False);
    Result := True;
  end;
  procedure ProcessMaskedChunk(const ABase: SizeUInt; const AMask: TVecMask); inline;
  var
    LLocalMask: TVecMask;
    LLocalBit: Int32;
    K: Integer;
  begin
    LLocalMask := AMask;
    while LLocalMask <> TVecMask(0) do
    begin
      LLocalBit := VecCtz(LLocalMask);
      B := V.Data[ABase + SizeUInt(LLocalBit)];
      for K := 0 to High(Singles) do if Singles[K].Need and not Singles[K].Found and (B = Singles[K].Ch) then
      begin
        Singles[K].Found := True;
        Singles[K].Pos := ABase + SizeUInt(LLocalBit);
        Singles[K].Need := False;
        Break;
      end;
      for K := 0 to High(Lits) do if Lits[K].Need and not Lits[K].Found and (B = Lits[K].First) then
        if (ABase + SizeUInt(LLocalBit) + Lits[K].View.Len <= LLen) and V.Slice(ABase + SizeUInt(LLocalBit), Lits[K].View.Len).Equals(Lits[K].View) then
        begin
          Lits[K].Found := True;
          Lits[K].Need := False;
          Break;
        end;
      LLocalMask := LLocalMask and not TVecMask(TVecMask(1) shl LLocalBit);
      if AllDone then Break;
    end;
  end;
begin
  LLen := V.Len;
  if LLen = 0 then Exit;
  for I := 0 to High(Lits) do if Lits[I].View.Len > 0 then Lits[I].First := Lits[I].View.Data[0];
  LPos := 0;
  while LPos + VecWidth <= LLen do
  begin
    if AllDone then Break;
    LCombined := TVecMask(0);
    for I := 0 to High(Singles) do if Singles[I].Need and not Singles[I].Found then LCombined := LCombined or VecCmpEq(@V.Data[LPos], Ord(Singles[I].Ch));
    for I := 0 to High(Lits) do if Lits[I].Need and not Lits[I].Found then LCombined := LCombined or VecCmpEq(@V.Data[LPos], Byte(Lits[I].First));
    if LCombined = TVecMask(0) then begin Inc(LPos, VecWidth); Continue; end;
    ProcessMaskedChunk(LPos, LCombined);
    if AllDone then Break;
    Inc(LPos, VecWidth);
  end;
  if AllDone then Exit;
  if LPos < LLen then
  begin
    if LLen >= VecWidth then
    begin
      LPos := LLen - VecWidth;
      if not AllDone then
      begin
        LCombined := TVecMask(0);
        for I := 0 to High(Singles) do if Singles[I].Need and not Singles[I].Found then LCombined := LCombined or VecCmpEq(@V.Data[LPos], Ord(Singles[I].Ch));
        for I := 0 to High(Lits) do if Lits[I].Need and not Lits[I].Found then LCombined := LCombined or VecCmpEq(@V.Data[LPos], Byte(Lits[I].First));
        if LCombined <> TVecMask(0) then ProcessMaskedChunk(LPos, LCombined);
      end;
    end else
    begin
      while LPos < LLen do
      begin
        if AllDone then Break;
        B := V.Data[LPos];
        for J := 0 to High(Singles) do if Singles[J].Need and not Singles[J].Found and (B = Singles[J].Ch) then
        begin Singles[J].Found := True; Singles[J].Pos := LPos; Singles[J].Need := False; Break; end;
        for J := 0 to High(Lits) do if Lits[J].Need and not Lits[J].Found and (B = Lits[J].First) and (LPos + Lits[J].View.Len <= LLen) and V.Slice(LPos, Lits[J].View.Len).Equals(Lits[J].View) then
        begin Lits[J].Found := True; Lits[J].Need := False; Break; end;
        Inc(LPos);
      end;
    end;
  end;
end;

end.
