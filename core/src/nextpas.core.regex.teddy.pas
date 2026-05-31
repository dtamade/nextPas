unit nextpas.core.regex.teddy;

{$I nextpas.core.settings.inc}
{$asmmode intel}

interface

uses
  nextpas.core.simd.base;

type
  TTeddyMatcher = record
    Patterns: array of string;
    PatternCount: Integer;
    Lo0: TVecU8x16;
    Hi0: TVecU8x16;
    Lo1: TVecU8x16;
    Hi1: TVecU8x16;
    MinPatLen: SizeUInt;
  end;

function TeddyBuild(const APatterns: array of string; ACount: Integer): TTeddyMatcher;
function TeddyIsMatch(const AMatcher: TTeddyMatcher;
  const AInput: PAnsiChar; ALen: SizeUInt): Boolean;

implementation

uses
  nextpas.core.simd.cpuinfo;

function TeddyBuild(const APatterns: array of string; ACount: Integer): TTeddyMatcher;
var
  i: Integer;
  LByte: Byte;
  LBit: Byte;
begin
  Result.PatternCount := ACount;
  SetLength(Result.Patterns, ACount);
  Result.MinPatLen := High(SizeUInt);

  FillChar(Result.Lo0, 16, 0);
  FillChar(Result.Hi0, 16, 0);
  FillChar(Result.Lo1, 16, 0);
  FillChar(Result.Hi1, 16, 0);

  for i := 0 to ACount - 1 do
  begin
    Result.Patterns[i] := APatterns[i];
    if SizeUInt(Length(APatterns[i])) < Result.MinPatLen then
      Result.MinPatLen := Length(APatterns[i]);
    LBit := 1 shl i;

    LByte := Byte(APatterns[i][1]);
    Result.Lo0.u[LByte and $0F] := Result.Lo0.u[LByte and $0F] or LBit;
    Result.Hi0.u[LByte shr 4] := Result.Hi0.u[LByte shr 4] or LBit;

    if Length(APatterns[i]) >= 2 then
    begin
      LByte := Byte(APatterns[i][2]);
      Result.Lo1.u[LByte and $0F] := Result.Lo1.u[LByte and $0F] or LBit;
      Result.Hi1.u[LByte shr 4] := Result.Hi1.u[LByte shr 4] or LBit;
    end;
  end;

  if Result.MinPatLen < 2 then
    Result.PatternCount := 0;
end;

function TeddyVerify(const AMatcher: TTeddyMatcher;
  const AInput: PAnsiChar; APos: SizeUInt; ALen: SizeUInt): Boolean; inline;
var
  i: Integer;
  LPatLen: SizeUInt;
  k: SizeUInt;
  LPat: PAnsiChar;
begin
  for i := 0 to AMatcher.PatternCount - 1 do
  begin
    LPatLen := Length(AMatcher.Patterns[i]);
    if APos + LPatLen > ALen then Continue;
    if AInput[APos] <> AMatcher.Patterns[i][1] then Continue;
    LPat := PAnsiChar(AMatcher.Patterns[i]);
    Result := True;
    for k := 1 to LPatLen - 1 do
      if AInput[APos + k] <> LPat[k] then
      begin
        Result := False;
        Break;
      end;
    if Result then Exit;
  end;
  Result := False;
end;

{$IFDEF CPUX86_64}
function TeddyIsMatchSSSE3(const AMatcher: TTeddyMatcher;
  const AInput: PAnsiChar; ALen: SizeUInt): Boolean;
var
  LPos: SizeUInt;
  LCandMask: UInt32;
  LBit: Integer;
  LNibbleMask: TVecU8x16;
  LLo0, LHi0, LLo1, LHi1: TVecU8x16;
  LCand0, LCand1: TVecU8x16;
begin
  FillChar(LNibbleMask, 16, $0F);
  LLo0 := AMatcher.Lo0;
  LHi0 := AMatcher.Hi0;
  LLo1 := AMatcher.Lo1;
  LHi1 := AMatcher.Hi1;
  LPos := 0;

  while LPos + 17 <= ALen do
  begin
    asm
      mov    rax, [AInput]
      add    rax, [LPos]
      movdqu xmm0, [rax]
      movdqu xmm6, [LNibbleMask]
      movdqa xmm1, xmm0
      pand   xmm1, xmm6
      movdqa xmm2, xmm0
      psrlw  xmm2, 4
      pand   xmm2, xmm6
      movdqu xmm3, [LLo0]
      pshufb xmm3, xmm1
      movdqu xmm4, [LHi0]
      pshufb xmm4, xmm2
      pand   xmm3, xmm4
      movdqu [LCand0], xmm3

      movdqu xmm0, [rax + 1]
      movdqa xmm1, xmm0
      pand   xmm1, xmm6
      movdqa xmm2, xmm0
      psrlw  xmm2, 4
      pand   xmm2, xmm6
      movdqu xmm3, [LLo1]
      pshufb xmm3, xmm1
      movdqu xmm4, [LHi1]
      pshufb xmm4, xmm2
      pand   xmm3, xmm4
      movdqu [LCand1], xmm3
    end;

    LCandMask := 0;
    asm
      movdqu xmm0, [LCand0]
      movdqu xmm1, [LCand1]
      pand   xmm0, xmm1
      pxor   xmm2, xmm2
      pcmpeqb xmm2, xmm0
      pmovmskb eax, xmm2
      not    eax
      and    eax, $FFFF
      mov    [LCandMask], eax
    end;

    while LCandMask <> 0 do
    begin
      asm
        bsf eax, [LCandMask]
        mov [LBit], eax
      end;
      if TeddyVerify(AMatcher, AInput, LPos + SizeUInt(LBit), ALen) then
        Exit(True);
      LCandMask := LCandMask and (LCandMask - 1);
    end;
    Inc(LPos, 16);
  end;

  while LPos < ALen do
  begin
    if TeddyVerify(AMatcher, AInput, LPos, ALen) then
      Exit(True);
    Inc(LPos);
  end;
  Result := False;
end;
{$ENDIF}

function TeddyIsMatchScalar(const AMatcher: TTeddyMatcher;
  const AInput: PAnsiChar; ALen: SizeUInt): Boolean;
var
  LPos: SizeUInt;
  LB0, LB1, LCand: Byte;
begin
  if ALen < 2 then Exit(False);
  LPos := 0;
  while LPos + 1 < ALen do
  begin
    LB0 := Byte(AInput[LPos]);
    LB1 := Byte(AInput[LPos + 1]);
    LCand := (AMatcher.Lo0.u[LB0 and $0F] and AMatcher.Hi0.u[LB0 shr 4]) and
             (AMatcher.Lo1.u[LB1 and $0F] and AMatcher.Hi1.u[LB1 shr 4]);
    if LCand <> 0 then
      if TeddyVerify(AMatcher, AInput, LPos, ALen) then
        Exit(True);
    Inc(LPos);
  end;
  Result := False;
end;

function TeddyIsMatch(const AMatcher: TTeddyMatcher;
  const AInput: PAnsiChar; ALen: SizeUInt): Boolean;
begin
  if ALen < AMatcher.MinPatLen then Exit(False);
  {$IFDEF CPUX86_64}
  if HasSSSE3 then
    Exit(TeddyIsMatchSSSE3(AMatcher, AInput, ALen));
  {$ENDIF}
  Result := TeddyIsMatchScalar(AMatcher, AInput, ALen);
end;

end.
