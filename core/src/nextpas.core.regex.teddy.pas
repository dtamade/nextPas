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
    LoNibbleTable: TVecU8x16;
    HiNibbleTable: TVecU8x16;
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
  LLoNib, LHiNib: Byte;
  LBit: Byte;
  LHiUsed: Integer;
begin
  Result.PatternCount := ACount;
  SetLength(Result.Patterns, ACount);
  Result.MinPatLen := High(SizeUInt);

  FillChar(Result.LoNibbleTable, 16, 0);
  FillChar(Result.HiNibbleTable, 16, 0);

  for i := 0 to ACount - 1 do
  begin
    Result.Patterns[i] := APatterns[i];
    if SizeUInt(Length(APatterns[i])) < Result.MinPatLen then
      Result.MinPatLen := Length(APatterns[i]);

    LByte := Byte(APatterns[i][1]);
    LLoNib := LByte and $0F;
    LHiNib := LByte shr 4;
    LBit := 1 shl i;
    Result.LoNibbleTable.u[LLoNib] := Result.LoNibbleTable.u[LLoNib] or LBit;
    Result.HiNibbleTable.u[LHiNib] := Result.HiNibbleTable.u[LHiNib] or LBit;
  end;
end;

function TeddyVerify(const AMatcher: TTeddyMatcher;
  const AInput: PAnsiChar; APos: SizeUInt; ALen: SizeUInt): Boolean;
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
  LLoTable, LHiTable: TVecU8x16;
  LNibbleMask: TVecU8x16;
  LInput, LLo, LHi, LCandVec: TVecU8x16;
  LCandMask: UInt32;
  LBit: Integer;
begin
  LLoTable := AMatcher.LoNibbleTable;
  LHiTable := AMatcher.HiNibbleTable;
  FillChar(LNibbleMask, 16, $0F);

  LPos := 0;
  while LPos + 16 <= ALen do
  begin
    Move(AInput[LPos], LInput, 16);
    asm
      movdqu xmm0, [LInput]
      movdqa xmm1, xmm0
      movdqu xmm6, [LNibbleMask]
      pand   xmm1, xmm6
      movdqu xmm2, [LLoTable]
      pshufb xmm2, xmm1
      psrlw  xmm0, 4
      pand   xmm0, xmm6
      movdqu xmm3, [LHiTable]
      pshufb xmm3, xmm0
      pand   xmm2, xmm3
      movdqu [LCandVec], xmm2
    end;
    LCandMask := 0;
    asm
      movdqu xmm0, [LCandVec]
      pxor   xmm1, xmm1
      pcmpeqb xmm1, xmm0
      pmovmskb eax, xmm1
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
  LByte, LCand: Byte;
begin
  LPos := 0;
  while LPos < ALen do
  begin
    LByte := Byte(AInput[LPos]);
    LCand := AMatcher.LoNibbleTable.u[LByte and $0F] and
             AMatcher.HiNibbleTable.u[LByte shr 4];
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
