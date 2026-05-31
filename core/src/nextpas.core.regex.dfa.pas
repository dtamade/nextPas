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
  { Context encoding: (AtStart shl 1) or PrevIsWord
    0 = not at start, prev is non-word
    1 = not at start, prev is word
    2 = at start, prev is non-word
    3 = at start, prev is word }

  TDfaState = record
    PCs: array of UInt32;
    Hash: UInt32;
    IsMatch: Boolean;
    Next: array[0..3, 0..255] of UInt16;
    MatchOnTrans: array[0..3, 0..255] of Boolean; { match found during epsilon closure }
    AcceptEof: array[0..3] of Int8; { -1=unknown, 0=no, 1=yes }
  end;

  TDfaCache = record
    States: array[0..DFA_MAX_STATES - 1] of TDfaState;
    StateCount: UInt16;
    Overflow: Boolean;
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

function DfaIsFullMatch(const AProgram: TRegexProgram;
  const AInput: PAnsiChar; ALen: SizeUInt): Boolean;

function DfaFindAll(const AProgram: TRegexProgram;
  const AInput: PAnsiChar; ALen: SizeUInt): TMatchArray;

function ProgramHasAsserts(const AProgram: TRegexProgram): Boolean;

implementation

uses nextpas.core.text.scan, nextpas.core.regex.nfa;

{ --- Utility --- }

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
var j, ctx: Integer;
begin
  C.StateCount := 0;
  C.Overflow := False;
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
  for ctx := 0 to 3 do
  begin
    for j := 0 to 255 do
    begin
      C.States[0].Next[ctx, j] := DFA_UNKNOWN;
      C.States[0].MatchOnTrans[ctx, j] := False;
    end;
    C.States[0].AcceptEof[ctx] := -1;
  end;
  C.StateCount := 1;
end;

{ --- Epsilon closure with assertion context --- }
{ ARoots: set of PCs to start from
  AAtStart: whether we are at position 0
  APrevIsWord: whether the previous character was a word char
  ACurrIsWord: whether the current character (being consumed) is a word char
  AAtEnd: whether we are at the end of input
  Returns True if opMatch is reachable }

function EpsilonClose(var C: TDfaCache; const AProgram: TRegexProgram;
  const ARoots: array of UInt32; ARootCount: UInt32;
  AAtStart: Boolean; APrevIsWord: Boolean;
  ACurrIsWord: Boolean; AAtEnd: Boolean): Boolean;
var
  StackTop: UInt32;
  pc: UInt32;
  inst: TInstruction;
  i: UInt32;
  LBoundary: Boolean;
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
        case inst.Assert of
          akStart:
            if AAtStart then
            begin
              C.Stack[StackTop] := pc + 1; Inc(StackTop);
            end;
          akEnd:
            if AAtEnd then
            begin
              C.Stack[StackTop] := pc + 1; Inc(StackTop);
            end;
          akWordBoundary:
          begin
            LBoundary := APrevIsWord xor ACurrIsWord;
            if LBoundary then
            begin
              C.Stack[StackTop] := pc + 1; Inc(StackTop);
            end;
          end;
          akNotWordBoundary:
          begin
            LBoundary := APrevIsWord xor ACurrIsWord;
            if not LBoundary then
            begin
              C.Stack[StackTop] := pc + 1; Inc(StackTop);
            end;
          end;
        end;
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

function FindOrCreateState(var C: TDfaCache;
  const APCs: array of UInt32; ACount: UInt32): UInt16;
var
  LHash: UInt32;
  i: UInt16;
  j: UInt32;
  LMatch: Boolean;
  LNewIdx: UInt16;
  ctx: Integer;
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
  C.States[LNewIdx].IsMatch := False;
  for ctx := 0 to 3 do
  begin
    for j := 0 to 255 do
    begin
      C.States[LNewIdx].Next[ctx, j] := DFA_UNKNOWN;
      C.States[LNewIdx].MatchOnTrans[ctx, j] := False;
    end;
    C.States[LNewIdx].AcceptEof[ctx] := -1;
  end;

  Result := LNewIdx;
end;

{ --- Compute transition for (state, ctx, byte) --- }
{ Unanchored mode: injects PC 0 into roots }

function ComputeTransition(var C: TDfaCache; const AProgram: TRegexProgram;
  AStateIdx: UInt16; ACtx: Byte; AByte: Byte;
  AInjectStart: Boolean): UInt16;
var
  LRoots: array of UInt32;
  LPCCount: UInt32;
  i: UInt32;
  LCount: UInt32;
  LAtStart: Boolean;
  LPrevIsWord: Boolean;
  LCurrIsWord: Boolean;
  LHasMatch: Boolean;
begin
  // Build roots: current state's PCs + optionally PC 0 (start injection)
  LPCCount := UInt32(Length(C.States[AStateIdx].PCs));
  if AInjectStart then
  begin
    SetLength(LRoots, LPCCount + 1);
    if LPCCount > 0 then
      for i := 0 to LPCCount - 1 do
        LRoots[i] := C.States[AStateIdx].PCs[i];
    LRoots[LPCCount] := 0;
    Inc(LPCCount);
  end
  else
  begin
    SetLength(LRoots, LPCCount);
    if LPCCount > 0 then
      for i := 0 to LPCCount - 1 do
        LRoots[i] := C.States[AStateIdx].PCs[i];
  end;

  // Decode context
  LAtStart := (ACtx and 2) <> 0;
  LPrevIsWord := (ACtx and 1) <> 0;
  LCurrIsWord := IsWordChar(AByte);

  // Epsilon close with context (not at end since we're consuming a byte)
  LHasMatch := EpsilonClose(C, AProgram, LRoots, LPCCount,
    LAtStart, LPrevIsWord, LCurrIsWord, False);

  // Byte step
  ByteStep(C, AProgram, AByte);

  // Store match flag for this transition
  C.States[AStateIdx].MatchOnTrans[ACtx, AByte] := LHasMatch;

  if C.NextCount = 0 then
  begin
    C.States[AStateIdx].Next[ACtx, AByte] := DFA_DEAD;
    Exit(DFA_DEAD);
  end;

  // Sort and deduplicate
  SortPCs(C.NextPCs, C.NextCount);
  LCount := DeduplicatePCs(C.NextPCs, C.NextCount);

  // Find or create state
  Result := FindOrCreateState(C, C.NextPCs, LCount);

  if Result = DFA_UNKNOWN then Exit;  // overflow

  C.States[AStateIdx].Next[ACtx, AByte] := Result;
end;

{ --- Check if a state accepts at EOF with given context --- }

function CheckEofAccept(var C: TDfaCache; const AProgram: TRegexProgram;
  AStateIdx: UInt16; ACtx: Byte; AInjectStart: Boolean): Boolean;
var
  LRoots: array of UInt32;
  LPCCount: UInt32;
  i: UInt32;
  LAtStart: Boolean;
  LPrevIsWord: Boolean;
begin
  LPCCount := UInt32(Length(C.States[AStateIdx].PCs));
  if AInjectStart then
  begin
    SetLength(LRoots, LPCCount + 1);
    if LPCCount > 0 then
      for i := 0 to LPCCount - 1 do
        LRoots[i] := C.States[AStateIdx].PCs[i];
    LRoots[LPCCount] := 0;
    Inc(LPCCount);
  end
  else
  begin
    SetLength(LRoots, LPCCount);
    if LPCCount > 0 then
      for i := 0 to LPCCount - 1 do
        LRoots[i] := C.States[AStateIdx].PCs[i];
  end;

  LAtStart := (ACtx and 2) <> 0;
  LPrevIsWord := (ACtx and 1) <> 0;

  // At EOF: CurrIsWord = False (no char), AtEnd = True
  Result := EpsilonClose(C, AProgram, LRoots, LPCCount,
    LAtStart, LPrevIsWord, False, True);
end;

{ --- Check if epsilon closure of state reaches match with given context --- }
{ Used to determine if we have a match BEFORE consuming the next byte }

function CheckStateMatch(var C: TDfaCache; const AProgram: TRegexProgram;
  AStateIdx: UInt16; ACtx: Byte; ACurrIsWord: Boolean;
  AInjectStart: Boolean): Boolean;
var
  LRoots: array of UInt32;
  LPCCount: UInt32;
  i: UInt32;
  LAtStart: Boolean;
  LPrevIsWord: Boolean;
begin
  LPCCount := UInt32(Length(C.States[AStateIdx].PCs));
  if AInjectStart then
  begin
    SetLength(LRoots, LPCCount + 1);
    if LPCCount > 0 then
      for i := 0 to LPCCount - 1 do
        LRoots[i] := C.States[AStateIdx].PCs[i];
    LRoots[LPCCount] := 0;
    Inc(LPCCount);
  end
  else
  begin
    SetLength(LRoots, LPCCount);
    if LPCCount > 0 then
      for i := 0 to LPCCount - 1 do
        LRoots[i] := C.States[AStateIdx].PCs[i];
  end;

  LAtStart := (ACtx and 2) <> 0;
  LPrevIsWord := (ACtx and 1) <> 0;

  // Not at end (we're about to consume a byte), use CurrIsWord for boundary check
  Result := EpsilonClose(C, AProgram, LRoots, LPCCount,
    LAtStart, LPrevIsWord, ACurrIsWord, False);
end;

{ --- DfaIsMatch: unanchored search using lazy DFA with assertion context --- }

function DfaIsMatch(const AProgram: TRegexProgram;
  const AInput: PAnsiChar; ALen: SizeUInt): Boolean;
var
  Cache: TDfaCache;
  LCodeLen: UInt32;
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
  LCtx: Byte;
  LAtStart: Boolean;
  LPrevIsWord: Boolean;
  LCurrIsWord: Boolean;
  LRoots: array of UInt32;
begin
  Result := False;
  LCodeLen := Length(AProgram.Code);
  if LCodeLen = 0 then Exit;

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

  // Check if start state itself matches at startPos (epsilon close PC 0)
  LAtStart := (startPos = 0);
  LPrevIsWord := (startPos > 0) and IsWordChar(Ord(AInput[startPos - 1]));
  if startPos < ALen then
    LCurrIsWord := IsWordChar(Ord(AInput[startPos]))
  else
    LCurrIsWord := False;

  SetLength(LRoots, 1);
  LRoots[0] := 0;
  // Check at current position (before consuming any byte)
  if startPos < ALen then
  begin
    if EpsilonClose(Cache, AProgram, LRoots, 1,
         LAtStart, LPrevIsWord, LCurrIsWord, False) then
      Exit(True);
  end
  else
  begin
    // At EOF already
    if EpsilonClose(Cache, AProgram, LRoots, 1,
         LAtStart, LPrevIsWord, False, True) then
      Exit(True);
  end;

  // Start DFA simulation
  curState := 0;  // empty state
  pos := startPos;

  while pos < ALen do
  begin
    ch := Ord(AInput[pos]);
    LAtStart := (pos = 0);
    LPrevIsWord := (pos > 0) and IsWordChar(Ord(AInput[pos - 1]));
    LCtx := (Ord(LAtStart) shl 1) or Ord(LPrevIsWord);

    nextState := Cache.States[curState].Next[LCtx, ch];

    if nextState = DFA_UNKNOWN then
    begin
      nextState := ComputeTransition(Cache, AProgram, curState, LCtx, ch, True);
      if Cache.Overflow then
        Exit(NfaIsMatch(AProgram, AInput, ALen));
    end;

    // Check if match was found during this transition's epsilon closure
    if Cache.States[curState].MatchOnTrans[LCtx, ch] then
      Exit(True);

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
  end;

  // Final EOF check: inject PC 0 and check if match at end of input
  LPrevIsWord := (ALen > 0) and IsWordChar(Ord(AInput[ALen - 1]));
  LCtx := Ord(LPrevIsWord);
  if ALen = 0 then
    LCtx := LCtx or 2; // AtStart=True
  if curState > 0 then
  begin
    if CheckEofAccept(Cache, AProgram, curState, LCtx, True) then
      Exit(True);
  end
  else
  begin
    // curState = 0 (empty), check if PC 0 alone reaches match at EOF
    SetLength(LRoots, 1);
    LRoots[0] := 0;
    LAtStart := (ALen = 0);
    if EpsilonClose(Cache, AProgram, LRoots, 1,
         LAtStart, LPrevIsWord, False, True) then
      Exit(True);
  end;
end;

{ --- DfaIsFullMatch: anchored DFA, match only at EOF --- }

function DfaIsFullMatch(const AProgram: TRegexProgram;
  const AInput: PAnsiChar; ALen: SizeUInt): Boolean;
var
  Cache: TDfaCache;
  LCodeLen: UInt32;
  pos: SizeUInt;
  curState: UInt16;
  nextState: UInt16;
  ch: Byte;
  LCtx: Byte;
  LAtStart: Boolean;
  LPrevIsWord: Boolean;
  LRoots: array of UInt32;
  LInitState: UInt16;
  LCount: UInt32;
begin
  Result := False;
  LCodeLen := Length(AProgram.Code);
  if LCodeLen = 0 then Exit;

  DfaCacheInit(Cache, LCodeLen);

  // Create initial state from PC 0
  SetLength(LRoots, 1);
  LRoots[0] := 0;

  // Do epsilon closure at pos=0 to get initial consuming PCs
  // AtStart=True, PrevIsWord=False, CurrIsWord depends on first char, AtEnd=(ALen=0)
  if ALen = 0 then
  begin
    // Empty input: check if match at start+end
    Result := EpsilonClose(Cache, AProgram, LRoots, 1, True, False, False, True);
    Exit;
  end;

  // Epsilon close to get consuming PCs for initial state
  EpsilonClose(Cache, AProgram, LRoots, 1,
    True, False, IsWordChar(Ord(AInput[0])), False);

  // Byte step on first char to build initial state
  ByteStep(Cache, AProgram, Ord(AInput[0]));

  if Cache.NextCount = 0 then
  begin
    // Check if match at pos=0 with AtEnd=(ALen=1 would be handled below)
    // Actually if no consuming PCs matched the first byte, no full match possible
    // unless ALen=0 which is handled above
    Exit;
  end;

  SortPCs(Cache.NextPCs, Cache.NextCount);
  LCount := DeduplicatePCs(Cache.NextPCs, Cache.NextCount);
  LInitState := FindOrCreateState(Cache, Cache.NextPCs, LCount);
  if LInitState = DFA_UNKNOWN then
    Exit(NfaIsFullMatch(AProgram, AInput, ALen));
  if LInitState = DFA_DEAD then Exit;

  curState := LInitState;
  pos := 1;

  while pos < ALen do
  begin
    ch := Ord(AInput[pos]);
    // Anchored: AtStart=False after first byte, PrevIsWord based on prev char
    LPrevIsWord := IsWordChar(Ord(AInput[pos - 1]));
    LCtx := Ord(LPrevIsWord); // AtStart=False -> bit 1 = 0

    nextState := Cache.States[curState].Next[LCtx, ch];

    if nextState = DFA_UNKNOWN then
    begin
      // Anchored: don't inject start state
      nextState := ComputeTransition(Cache, AProgram, curState, LCtx, ch, False);
      if Cache.Overflow then
        Exit(NfaIsFullMatch(AProgram, AInput, ALen));
    end;

    if nextState = DFA_DEAD then Exit;

    curState := nextState;
    Inc(pos);
  end;

  // At EOF: check if match
  LPrevIsWord := IsWordChar(Ord(AInput[ALen - 1]));
  LCtx := Ord(LPrevIsWord);
  Result := CheckEofAccept(Cache, AProgram, curState, LCtx, False);
end;

{ --- DfaFindAll: find all non-overlapping matches (no captures) --- }
{ Uses anchored DFA from each candidate start position, longest match }

function DfaFindAll(const AProgram: TRegexProgram;
  const AInput: PAnsiChar; ALen: SizeUInt): TMatchArray;
var
  Cache: TDfaCache;
  LCodeLen: UInt32;
  LCount: SizeUInt;
  LStart: SizeUInt;
  LPos: SizeUInt;
  LMatchEnd: SizeInt;
  curState: UInt16;
  nextState: UInt16;
  ch: Byte;
  LCtx: Byte;
  LPrevIsWord: Boolean;
  LCurrIsWord: Boolean;
  LAtStart: Boolean;
  LRoots: array of UInt32;
  LPCCount: UInt32;
  LInitCount: UInt32;
  LPrefixByte: Byte;
  LHasPrefix: Boolean;
  LPrefixLen: SizeUInt;
  LPrefixStr: string;
  prefixPos: SizeInt;
  k: SizeUInt;
begin
  SetLength(Result, 0);
  LCodeLen := Length(AProgram.Code);
  if LCodeLen = 0 then Exit;

  DfaCacheInit(Cache, LCodeLen);
  LCount := 0;
  LStart := 0;

  LHasPrefix := AProgram.LiteralPrefixLen > 0;
  LPrefixLen := AProgram.LiteralPrefixLen;
  LPrefixStr := AProgram.LiteralPrefix;

  while LStart <= ALen do
  begin
    // Prefilter: skip to candidate
    if LHasPrefix and (LStart < ALen) then
    begin
      LPrefixByte := Byte(LPrefixStr[1]);
      while True do
      begin
        prefixPos := SizeInt(ScanFindByte(AInput + LStart, ALen - LStart, LPrefixByte));
        if prefixPos < 0 then begin SetLength(Result, LCount); Exit; end;
        LStart := LStart + SizeUInt(prefixPos);
        if LPrefixLen <= 1 then Break;
        if LStart + LPrefixLen > ALen then begin SetLength(Result, LCount); Exit; end;
        k := 1;
        while (k < LPrefixLen) and (AInput[LStart + k] = AnsiChar(LPrefixStr[k + 1])) do
          Inc(k);
        if k = LPrefixLen then Break;
        Inc(LStart);
        if LStart >= ALen then begin SetLength(Result, LCount); Exit; end;
      end;
    end
    else if (AProgram.StartClassSize > 0) and (AProgram.StartClassSize < 128) and
            (not LHasPrefix) and (LStart < ALen) then
    begin
      while (LStart < ALen) and
            (not CharBitmapTest(AProgram.StartClass, Ord(AInput[LStart]))) do
        Inc(LStart);
    end;

    // Run anchored DFA from LStart
    LMatchEnd := -1;

    // Check if empty match at LStart
    LAtStart := (LStart = 0);
    LPrevIsWord := (LStart > 0) and IsWordChar(Ord(AInput[LStart - 1]));
    if LStart < ALen then
      LCurrIsWord := IsWordChar(Ord(AInput[LStart]))
    else
      LCurrIsWord := False;

    SetLength(LRoots, 1);
    LRoots[0] := 0;

    if LStart >= ALen then
    begin
      // At EOF: check if empty match
      if EpsilonClose(Cache, AProgram, LRoots, 1,
           LAtStart, LPrevIsWord, False, True) then
        LMatchEnd := SizeInt(LStart);
    end
    else
    begin
      // Check if match before consuming first byte
      if EpsilonClose(Cache, AProgram, LRoots, 1,
           LAtStart, LPrevIsWord, LCurrIsWord, False) then
        LMatchEnd := SizeInt(LStart);

      // Now do byte step to build initial state
      ByteStep(Cache, AProgram, Ord(AInput[LStart]));

      if Cache.NextCount > 0 then
      begin
        SortPCs(Cache.NextPCs, Cache.NextCount);
        LInitCount := DeduplicatePCs(Cache.NextPCs, Cache.NextCount);
        curState := FindOrCreateState(Cache, Cache.NextPCs, LInitCount);

        if curState = DFA_UNKNOWN then
        begin
          // Overflow - fall back to NFA
          Result := NfaFindAll(AProgram, AInput, ALen);
          Exit;
        end;

        if curState <> DFA_DEAD then
        begin
          LPos := LStart + 1;

          // Check if match after consuming first byte
          LPrevIsWord := IsWordChar(Ord(AInput[LStart]));
          if LPos < ALen then
          begin
            LCurrIsWord := IsWordChar(Ord(AInput[LPos]));
            LCtx := Ord(LPrevIsWord);
            if CheckStateMatch(Cache, AProgram, curState, LCtx, LCurrIsWord, False) then
              LMatchEnd := SizeInt(LPos);
          end
          else
          begin
            LCtx := Ord(LPrevIsWord);
            if CheckEofAccept(Cache, AProgram, curState, LCtx, False) then
              LMatchEnd := SizeInt(LPos);
          end;

          // Continue consuming bytes
          while LPos < ALen do
          begin
            ch := Ord(AInput[LPos]);
            LPrevIsWord := IsWordChar(Ord(AInput[LPos - 1]));
            LCtx := Ord(LPrevIsWord); // AtStart=False after first byte

            nextState := Cache.States[curState].Next[LCtx, ch];
            if nextState = DFA_UNKNOWN then
            begin
              nextState := ComputeTransition(Cache, AProgram, curState, LCtx, ch, False);
              if Cache.Overflow then
              begin
                Result := NfaFindAll(AProgram, AInput, ALen);
                Exit;
              end;
            end;

            if nextState = DFA_DEAD then Break;

            curState := nextState;
            Inc(LPos);

            // Check if match at new position
            if LPos < ALen then
            begin
              LCurrIsWord := IsWordChar(Ord(AInput[LPos]));
              LPrevIsWord := IsWordChar(Ord(AInput[LPos - 1]));
              LCtx := Ord(LPrevIsWord);
              if CheckStateMatch(Cache, AProgram, curState, LCtx, LCurrIsWord, False) then
                LMatchEnd := SizeInt(LPos);
            end
            else
            begin
              LPrevIsWord := IsWordChar(Ord(AInput[LPos - 1]));
              LCtx := Ord(LPrevIsWord);
              if CheckEofAccept(Cache, AProgram, curState, LCtx, False) then
                LMatchEnd := SizeInt(LPos);
            end;
          end;
        end;
      end;
    end;

    // Record match if found
    if LMatchEnd >= 0 then
    begin
      if LCount >= SizeUInt(Length(Result)) then
        SetLength(Result, LCount + 32);
      Result[LCount].Start := SizeInt(LStart);
      Result[LCount].Len := LMatchEnd - SizeInt(LStart);
      Result[LCount].Groups := nil;
      Inc(LCount);

      if LMatchEnd > SizeInt(LStart) then
        LStart := SizeUInt(LMatchEnd)
      else
        Inc(LStart);
    end
    else
      Inc(LStart);
  end;

  SetLength(Result, LCount);
end;

end.
