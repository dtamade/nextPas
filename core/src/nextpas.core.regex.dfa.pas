unit nextpas.core.regex.dfa;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.regex.base,
  nextpas.core.regex.charclass;

const
  DFA_MAX_STATES = 256;
  DFA_UNKNOWN    = $FFFF;
  DFA_DEAD       = $FFFE;

type
  TDfaState = record
    PCs: array of UInt32;
    Hash: UInt32;
    IsMatch: Boolean;
    Next: array[0..255] of UInt16;
  end;

  TDfaCache = record
    States: array[0..DFA_MAX_STATES - 1] of TDfaState;
    StateCount: UInt16;
    Overflow: Boolean;
    HasAsserts: Boolean;
    Seen: array of Boolean;
    CloseList: array of UInt32;
    CloseCount: UInt32;
    NextPCs: array of UInt32;
    NextCount: UInt32;
    Stack: array of UInt32;
    CodeLen: UInt32;
  end;

function DfaIsMatch(const AProgram: TRegexProgram;
  const AInput: PAnsiChar; ALen: SizeUInt): Boolean;

function DfaFindAll(const AProgram: TRegexProgram;
  const AInput: PAnsiChar; ALen: SizeUInt): TMatchArray;

function ProgramHasAsserts(const AProgram: TRegexProgram): Boolean;

implementation

uses nextpas.core.text.scan, nextpas.core.regex.nfa;

{ --- Utility --- }

{ Forward declaration for NFA fallback }
function NfaIsMatchFallback(const AProgram: TRegexProgram;
  const AInput: PAnsiChar; ALen: SizeUInt): Boolean;
begin
  Result := NfaIsMatch(AProgram, AInput, ALen);
end;

function ProgramHasAsserts(const AProgram: TRegexProgram): Boolean;
var i: UInt32; LLen: UInt32;
begin
  LLen := Length(AProgram.Code);
  if LLen = 0 then Exit(False);
  for i := 0 to LLen - 1 do
    if AProgram.Code[i].Op = opAssert then
      Exit(True);
  Result := False;
end;

{ --- Hash a sorted PC array --- }

function HashPCs(const APCs: array of UInt32; ACount: UInt32): UInt32;
var i: UInt32;
begin
  Result := ACount;
  if ACount = 0 then Exit;
  for i := 0 to ACount - 1 do
    Result := Result xor (APCs[i] * 2654435761);
end;

{ --- Initialize DFA cache --- }

procedure DfaCacheInit(var C: TDfaCache; ACodeLen: UInt32);
var j: Integer;
begin
  C.StateCount := 0;
  C.Overflow := False;
  C.HasAsserts := False;
  C.CodeLen := ACodeLen;
  SetLength(C.Seen, ACodeLen);
  SetLength(C.CloseList, ACodeLen);
  C.CloseCount := 0;
  SetLength(C.NextPCs, ACodeLen);
  C.NextCount := 0;
  SetLength(C.Stack, ACodeLen * 3);
  // Initialize the empty start state (state 0 = no active PCs)
  SetLength(C.States[0].PCs, 0);
  C.States[0].Hash := 0;
  C.States[0].IsMatch := False;
  for j := 0 to 255 do
    C.States[0].Next[j] := DFA_UNKNOWN;
  C.StateCount := 1;
end;

{ --- Epsilon closure: collect consuming PCs and detect opMatch --- }
{ Returns True if opMatch is reachable }

function EpsilonClose(var C: TDfaCache; const AProgram: TRegexProgram;
  const ARoots: array of UInt32; ARootCount: UInt32;
  APos: SizeUInt; ALen: SizeUInt; const AInput: PAnsiChar): Boolean;
var
  StackTop: UInt32;
  pc: UInt32;
  inst: TInstruction;
  i: UInt32;
begin
  Result := False;
  C.CloseCount := 0;
  if ARootCount = 0 then Exit;

  // Clear seen
  if C.CodeLen > 0 then
    FillChar(C.Seen[0], C.CodeLen * SizeOf(Boolean), 0);

  // Push all roots
  StackTop := 0;
  for i := 0 to ARootCount - 1 do
  begin
    if ARoots[i] < C.CodeLen then
    begin
      C.Stack[StackTop] := ARoots[i];
      Inc(StackTop);
    end;
  end;

  while StackTop > 0 do
  begin
    Dec(StackTop);
    pc := C.Stack[StackTop];
    if pc >= C.CodeLen then Continue;
    if C.Seen[pc] then Continue;
    C.Seen[pc] := True;

    inst := AProgram.Code[pc];
    case inst.Op of
      opSplit:
      begin
        if StackTop + 2 <= UInt32(Length(C.Stack)) then
        begin
          C.Stack[StackTop] := inst.Y; Inc(StackTop);
          C.Stack[StackTop] := inst.X; Inc(StackTop);
        end;
      end;
      opJump:
      begin
        C.Stack[StackTop] := inst.Target; Inc(StackTop);
      end;
      opSave:
      begin
        C.Stack[StackTop] := pc + 1; Inc(StackTop);
      end;
      opMatch:
        Result := True;
      opLiteral, opAnyChar, opCharClass:
      begin
        C.CloseList[C.CloseCount] := pc;
        Inc(C.CloseCount);
      end;
      opAssert:
      begin
        // DFA cannot handle assertions - signal overflow
        C.HasAsserts := True;
      end;
    end;
  end;
end;

{ --- Byte step: given consuming PCs and a byte, compute next PCs --- }

procedure ByteStep(var C: TDfaCache; const AProgram: TRegexProgram; AByte: Byte);
var
  i: UInt32;
  pc: UInt32;
  inst: TInstruction;
begin
  C.NextCount := 0;
  if C.CloseCount = 0 then Exit;
  for i := 0 to C.CloseCount - 1 do
  begin
    pc := C.CloseList[i];
    inst := AProgram.Code[pc];
    case inst.Op of
      opLiteral:
        if AByte = inst.Ch then
        begin
          C.NextPCs[C.NextCount] := pc + 1;
          Inc(C.NextCount);
        end;
      opAnyChar:
        if AByte <> 10 then  // not newline
        begin
          C.NextPCs[C.NextCount] := pc + 1;
          Inc(C.NextCount);
        end;
      opCharClass:
        if CharBitmapTest(AProgram.Classes[inst.ClassIdx], AByte) xor inst.Negated then
        begin
          C.NextPCs[C.NextCount] := pc + 1;
          Inc(C.NextCount);
        end;
    end;
  end;
end;

{ --- Sort UInt32 array (insertion sort, small arrays) --- }

procedure SortPCs(var APCs: array of UInt32; ACount: UInt32);
var i, j: UInt32; tmp: UInt32;
begin
  if ACount <= 1 then Exit;
  for i := 1 to ACount - 1 do
  begin
    tmp := APCs[i];
    j := i;
    while (j > 0) and (APCs[j - 1] > tmp) do
    begin
      APCs[j] := APCs[j - 1];
      Dec(j);
    end;
    APCs[j] := tmp;
  end;
end;

{ --- Deduplicate sorted array in-place --- }

function DeduplicatePCs(var APCs: array of UInt32; ACount: UInt32): UInt32;
var i, w: UInt32;
begin
  if ACount <= 1 then Exit(ACount);
  w := 1;
  for i := 1 to ACount - 1 do
    if APCs[i] <> APCs[w - 1] then
    begin
      APCs[w] := APCs[i];
      Inc(w);
    end;
  Result := w;
end;

{ --- Find or create a DFA state for a given PC set --- }
{ Returns state index, or DFA_DEAD if empty, or DFA_UNKNOWN on overflow }

function FindOrCreateState(var C: TDfaCache; const AProgram: TRegexProgram;
  const APCs: array of UInt32; ACount: UInt32;
  APos: SizeUInt; ALen: SizeUInt; const AInput: PAnsiChar): UInt16;
var
  LHash: UInt32;
  i: UInt16;
  j: UInt32;
  LMatch: Boolean;
  LNewIdx: UInt16;
  LRoots: array of UInt32;
begin
  if ACount = 0 then Exit(DFA_DEAD);

  LHash := HashPCs(APCs, ACount);

  // Linear probe for existing state
  for i := 0 to C.StateCount - 1 do
  begin
    if (C.States[i].Hash = LHash) and
       (UInt32(Length(C.States[i].PCs)) = ACount) then
    begin
      LMatch := True;
      for j := 0 to ACount - 1 do
        if C.States[i].PCs[j] <> APCs[j] then
        begin
          LMatch := False;
          Break;
        end;
      if LMatch then Exit(i);
    end;
  end;

  // Need to create new state
  if C.StateCount >= DFA_MAX_STATES then
  begin
    C.Overflow := True;
    Exit(DFA_UNKNOWN);
  end;

  LNewIdx := C.StateCount;
  Inc(C.StateCount);

  SetLength(C.States[LNewIdx].PCs, ACount);
  for j := 0 to ACount - 1 do
    C.States[LNewIdx].PCs[j] := APCs[j];
  C.States[LNewIdx].Hash := LHash;
  for j := 0 to 255 do
    C.States[LNewIdx].Next[j] := DFA_UNKNOWN;

  // Compute IsMatch by doing epsilon closure on these PCs
  SetLength(LRoots, ACount);
  for j := 0 to ACount - 1 do
    LRoots[j] := APCs[j];
  C.States[LNewIdx].IsMatch := EpsilonClose(C, AProgram, LRoots, ACount,
    APos, ALen, AInput);

  Result := LNewIdx;
end;

{ --- Compute transition for (state, byte) --- }
{ Returns next state index, DFA_DEAD, or DFA_UNKNOWN on overflow }

function ComputeTransition(var C: TDfaCache; const AProgram: TRegexProgram;
  AStateIdx: UInt16; AByte: Byte;
  APos: SizeUInt; ALen: SizeUInt; const AInput: PAnsiChar): UInt16;
var
  LRoots: array of UInt32;
  LPCCount: UInt32;
  i: UInt32;
  LCount: UInt32;
begin
  // Build roots: current state's PCs + PC 0 (start injection for unanchored)
  LPCCount := UInt32(Length(C.States[AStateIdx].PCs));
  SetLength(LRoots, LPCCount + 1);
  if LPCCount > 0 then
    for i := 0 to LPCCount - 1 do
      LRoots[i] := C.States[AStateIdx].PCs[i];
  LRoots[LPCCount] := 0;  // start state injection

  // Epsilon close to get consuming PCs
  EpsilonClose(C, AProgram, LRoots, LPCCount + 1, APos, ALen, AInput);
  if C.HasAsserts then
  begin
    C.Overflow := True;
    Exit(DFA_UNKNOWN);
  end;

  // Byte step
  ByteStep(C, AProgram, AByte);

  if C.NextCount = 0 then
  begin
    C.States[AStateIdx].Next[AByte] := DFA_DEAD;
    Exit(DFA_DEAD);
  end;

  // Sort and deduplicate
  SortPCs(C.NextPCs, C.NextCount);
  LCount := DeduplicatePCs(C.NextPCs, C.NextCount);

  // Find or create state
  Result := FindOrCreateState(C, AProgram, C.NextPCs, LCount,
    APos + 1, ALen, AInput);

  if Result = DFA_UNKNOWN then Exit;  // overflow

  C.States[AStateIdx].Next[AByte] := Result;
end;

{ --- DfaIsMatch: unanchored search using lazy DFA --- }

function DfaIsMatch(const AProgram: TRegexProgram;
  const AInput: PAnsiChar; ALen: SizeUInt): Boolean;
var
  Cache: TDfaCache;
  LCodeLen: UInt32;
  LPCCount: UInt32;
  pos: SizeUInt;
  curState: UInt16;
  nextState: UInt16;
  ch: Byte;
  LPrefixByte: Byte;
  LHasPrefix: Boolean;
  LPrefixLen: SizeUInt;
  LPrefixStr: string;
  prefixPos: SizeInt;
  startPos: SizeUInt;
  k: SizeUInt;
  LRoots: array of UInt32;
  LInitialMatch: Boolean;
begin
  Result := False;
  LCodeLen := Length(AProgram.Code);
  if LCodeLen = 0 then Exit;

  // Check for assertions - fall back to NFA
  if ProgramHasAsserts(AProgram) then
    Exit(NfaIsMatchFallback(AProgram, AInput, ALen));

  DfaCacheInit(Cache, LCodeLen);

  // Prefilter: find start position
  LHasPrefix := AProgram.LiteralPrefixLen > 0;
  LPrefixLen := AProgram.LiteralPrefixLen;
  LPrefixStr := AProgram.LiteralPrefix;
  startPos := 0;

  if LHasPrefix then
  begin
    LPrefixByte := Byte(LPrefixStr[1]);
    prefixPos := SizeInt(ScanFindByte(AInput, ALen, LPrefixByte));
    if prefixPos < 0 then Exit;
    startPos := SizeUInt(prefixPos);
    if LPrefixLen > 1 then
    begin
      while True do
      begin
        if startPos + LPrefixLen > ALen then Exit;
        k := 1;
        while (k < LPrefixLen) and (AInput[startPos + k] = AnsiChar(LPrefixStr[k + 1])) do
          Inc(k);
        if k = LPrefixLen then Break;
        if startPos + 1 >= ALen then Exit;
        prefixPos := SizeInt(ScanFindByte(AInput + startPos + 1,
                      ALen - startPos - 1, LPrefixByte));
        if prefixPos < 0 then Exit;
        startPos := startPos + 1 + SizeUInt(prefixPos);
      end;
    end;
  end
  else if (AProgram.StartClassSize > 0) and (AProgram.StartClassSize < 128) then
  begin
    while (startPos < ALen) and
          (not CharBitmapTest(AProgram.StartClass, Ord(AInput[startPos]))) do
      Inc(startPos);
  end;

  // Check if start state itself matches (epsilon close PC 0)
  SetLength(LRoots, 1);
  LRoots[0] := 0;
  LInitialMatch := EpsilonClose(Cache, AProgram, LRoots, 1, startPos, ALen, AInput);
  if Cache.HasAsserts then
    Exit(NfaIsMatchFallback(AProgram, AInput, ALen));
  if LInitialMatch then Exit(True);

  // Start DFA simulation
  curState := 0;  // empty state
  pos := startPos;

  while pos < ALen do
  begin
    ch := Ord(AInput[pos]);
    nextState := Cache.States[curState].Next[ch];

    if nextState = DFA_UNKNOWN then
    begin
      nextState := ComputeTransition(Cache, AProgram, curState, ch, pos, ALen, AInput);
      if Cache.Overflow then
        Exit(NfaIsMatchFallback(AProgram, AInput, ALen));
    end;

    if nextState = DFA_DEAD then
    begin
      // No threads survived - skip to next candidate
      Inc(pos);
      if LHasPrefix and (pos < ALen) then
      begin
        LPrefixByte := Byte(LPrefixStr[1]);
        while True do
        begin
          prefixPos := SizeInt(ScanFindByte(AInput + pos, ALen - pos, LPrefixByte));
          if prefixPos < 0 then Exit;
          pos := pos + SizeUInt(prefixPos);
          if LPrefixLen <= 1 then Break;
          if pos + LPrefixLen > ALen then Exit;
          k := 1;
          while (k < LPrefixLen) and (AInput[pos + k] = AnsiChar(LPrefixStr[k + 1])) do
            Inc(k);
          if k = LPrefixLen then Break;
          Inc(pos);
          if pos >= ALen then Exit;
        end;
      end
      else if (AProgram.StartClassSize > 0) and (AProgram.StartClassSize < 128) and
              (not LHasPrefix) then
      begin
        while (pos < ALen) and
              (not CharBitmapTest(AProgram.StartClass, Ord(AInput[pos]))) do
          Inc(pos);
      end;
      curState := 0;  // reset to empty state
      Continue;
    end;

    curState := nextState;
    Inc(pos);

    // Check if current state is a match state
    if Cache.States[curState].IsMatch then
      Exit(True);
  end;

  // Check EOF: epsilon close current state + PC 0
  if curState > 0 then
  begin
    LPCCount := UInt32(Length(Cache.States[curState].PCs));
    SetLength(LRoots, LPCCount + 1);
    if LPCCount > 0 then
      for k := 0 to LPCCount - 1 do
        LRoots[k] := Cache.States[curState].PCs[k];
    LRoots[LPCCount] := 0;
    if EpsilonClose(Cache, AProgram, LRoots, LPCCount + 1, ALen, ALen, AInput) then
      Exit(True);
  end
  else
  begin
    // curState = 0 (empty), check if PC 0 alone reaches match at EOF
    SetLength(LRoots, 1);
    LRoots[0] := 0;
    if EpsilonClose(Cache, AProgram, LRoots, 1, ALen, ALen, AInput) then
      Exit(True);
  end;
end;

{ --- DfaFindAll: find all non-overlapping matches (no captures) --- }
{ For v1, delegates to NFA since the per-call DFA cache doesn't amortize well
  across multiple match positions. The DFA's main benefit is for IsMatch. }

function DfaFindAll(const AProgram: TRegexProgram;
  const AInput: PAnsiChar; ALen: SizeUInt): TMatchArray;
begin
  Result := NfaFindAll(AProgram, AInput, ALen);
end;

end.
