unit nextpas.core.regex.nfa;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.regex.base,
  nextpas.core.regex.charclass;

function NfaIsMatch(const AProgram: TRegexProgram;
  const AInput: PAnsiChar; ALen: SizeUInt): Boolean;

function NfaSearch(const AProgram: TRegexProgram;
  const AInput: PAnsiChar; ALen: SizeUInt; AAnchored: Boolean;
  AStartPos: SizeUInt;
  out AMatch: TMatch): Boolean;

function NfaFindAll(const AProgram: TRegexProgram;
  const AInput: PAnsiChar; ALen: SizeUInt): TMatchArray;

implementation

uses SysUtils, nextpas.core.text.scan;

{ --- Sparse Set: O(1) add, contains, clear --- }

type
  TSparseSet = record
    Dense: array of UInt32;
    Sparse: array of UInt32;
    Count: UInt32;
    Cap: UInt32;
  end;

procedure SparseInit(out S: TSparseSet; ACap: UInt32);
begin
  S.Cap := ACap;
  SetLength(S.Dense, ACap);
  SetLength(S.Sparse, ACap);
  S.Count := 0;
end;

function SparseContains(const S: TSparseSet; AVal: UInt32): Boolean; inline;
begin
  Result := (AVal < S.Cap) and (S.Sparse[AVal] < S.Count) and
            (S.Dense[S.Sparse[AVal]] = AVal);
end;

function SparseAdd(var S: TSparseSet; AVal: UInt32): Boolean; inline;
begin
  if SparseContains(S, AVal) then Exit(False);
  S.Sparse[AVal] := S.Count;
  S.Dense[S.Count] := AVal;
  Inc(S.Count);
  Result := True;
end;

procedure SparseClear(var S: TSparseSet); inline;
begin
  S.Count := 0;
end;

{ --- NfaIsMatch: zero-allocation PC-only Thompson VM --- }
{ Uses iterative worklist for epsilon closure (no recursion) }

function NfaIsMatch(const AProgram: TRegexProgram;
  const AInput: PAnsiChar; ALen: SizeUInt): Boolean;
var
  CList, NList: array of UInt32;
  CCount, NCount: UInt32;
  Seen: TSparseSet;
  Stack: array of UInt32;
  StackTop: UInt32;
  LCodeLen: UInt32;
  pos: SizeUInt;
  i: UInt32;
  pc: UInt32;
  inst: TInstruction;
  ch: Byte;
  prefixPos: SizeInt;
  startPos: SizeUInt;
  LPrefixLen: SizeUInt;
  LPrefixByte: Byte;
  LHasPrefix: Boolean;
  LHasStartClass: Boolean;
  LPrefixStr: string;
  k: SizeUInt;

  procedure EpsilonClose(AStartPC: UInt32);
  var LInst: TInstruction;
  begin
    if AStartPC >= LCodeLen then Exit;
    if SparseContains(Seen, AStartPC) then Exit;
    StackTop := 0;
    Stack[StackTop] := AStartPC;
    Inc(StackTop);
    while StackTop > 0 do
    begin
      Dec(StackTop);
      pc := Stack[StackTop];
      if pc >= LCodeLen then Continue;
      if not SparseAdd(Seen, pc) then Continue;
      LInst := AProgram.Code[pc];
      case LInst.Op of
        opSplit:
        begin
          Stack[StackTop] := LInst.Y; Inc(StackTop);
          Stack[StackTop] := LInst.X; Inc(StackTop);
        end;
        opJump:
        begin
          Stack[StackTop] := LInst.Target; Inc(StackTop);
        end;
        opSave:
        begin
          Stack[StackTop] := pc + 1; Inc(StackTop);
        end;
        opAssert:
        begin
          case LInst.Assert of
            akStart:
              if pos = 0 then begin Stack[StackTop] := pc + 1; Inc(StackTop); end;
            akEnd:
              if pos = ALen then begin Stack[StackTop] := pc + 1; Inc(StackTop); end;
            akWordBoundary:
              if ((pos = 0) or not IsWordChar(Ord(AInput[pos - 1]))) <>
                 ((pos >= ALen) or not IsWordChar(Ord(AInput[pos]))) then
              begin Stack[StackTop] := pc + 1; Inc(StackTop); end;
            akNotWordBoundary:
              if not (((pos = 0) or not IsWordChar(Ord(AInput[pos - 1]))) <>
                      ((pos >= ALen) or not IsWordChar(Ord(AInput[pos])))) then
              begin Stack[StackTop] := pc + 1; Inc(StackTop); end;
          end;
        end;
      else
        CList[CCount] := pc;
        Inc(CCount);
      end;
    end;
  end;

begin
  Result := False;
  LCodeLen := Length(AProgram.Code);
  if LCodeLen = 0 then Exit;

  SetLength(CList, LCodeLen);
  SetLength(NList, LCodeLen);
  SetLength(Stack, LCodeLen * 2);
  SparseInit(Seen, LCodeLen);

  LHasPrefix := AProgram.LiteralPrefixLen > 0;
  LPrefixLen := AProgram.LiteralPrefixLen;
  LPrefixStr := AProgram.LiteralPrefix;
  LHasStartClass := (not LHasPrefix) and (AProgram.StartClassSize > 0) and
                    (AProgram.StartClassSize < 128);
  if LHasPrefix then
    LPrefixByte := Byte(LPrefixStr[1])
  else
    LPrefixByte := 0;

  startPos := 0;
  if LHasPrefix then
  begin
    prefixPos := SizeInt(ScanFindByte(AInput, ALen, LPrefixByte));
    if prefixPos < 0 then Exit;
    startPos := SizeUInt(prefixPos);
    // Verify full prefix at candidate position
    if LPrefixLen > 1 then
    begin
      while True do
      begin
        if startPos + LPrefixLen > ALen then Exit;
        k := 1;
        while (k < LPrefixLen) and (AInput[startPos + k] = AnsiChar(LPrefixStr[k + 1])) do
          Inc(k);
        if k = LPrefixLen then Break;
        // Skip to next candidate
        if startPos + 1 >= ALen then Exit;
        prefixPos := SizeInt(ScanFindByte(AInput + startPos + 1,
                      ALen - startPos - 1, LPrefixByte));
        if prefixPos < 0 then Exit;
        startPos := startPos + 1 + SizeUInt(prefixPos);
      end;
    end;
  end
  else if LHasStartClass then
  begin
    while (startPos < ALen) and
          (not CharBitmapTest(AProgram.StartClass, Ord(AInput[startPos]))) do
      Inc(startPos);
  end;

  pos := startPos;
  NCount := 0;

  while pos <= ALen do
  begin
    SparseClear(Seen);
    CCount := 0;
    if NCount > 0 then
      for i := 0 to NCount - 1 do
        EpsilonClose(NList[i]);
    EpsilonClose(0);

    if CCount > 0 then
      for i := 0 to CCount - 1 do
        if AProgram.Code[CList[i]].Op = opMatch then Exit(True);

    if pos = ALen then Break;
    if CCount = 0 then Break;

    NCount := 0;
    for i := 0 to CCount - 1 do
    begin
      inst := AProgram.Code[CList[i]];
      case inst.Op of
        opLiteral:
          if Ord(AInput[pos]) = inst.Ch then
          begin NList[NCount] := CList[i] + 1; Inc(NCount); end;
        opAnyChar:
          if AInput[pos] <> #10 then
          begin NList[NCount] := CList[i] + 1; Inc(NCount); end;
        opCharClass:
        begin
          ch := Ord(AInput[pos]);
          if CharBitmapTest(AProgram.Classes[inst.ClassIdx], ch) xor inst.Negated then
          begin NList[NCount] := CList[i] + 1; Inc(NCount); end;
        end;
      end;
    end;

    Inc(pos);

    // Prefilter skip: when no threads survived, jump to next candidate position
    if (NCount = 0) and (pos < ALen) then
    begin
      if LHasPrefix then
      begin
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
      else if LHasStartClass then
      begin
        while (pos < ALen) and
              (not CharBitmapTest(AProgram.StartClass, Ord(AInput[pos]))) do
          Inc(pos);
      end;
    end;
  end;
end;

{ --- NfaSearch: full Thompson VM with capture slots --- }
{ Uses slot pool to reduce per-thread allocation }

type
  TSlotArray = array of SizeInt;

  TThread = record
    PC: UInt32;
    SlotIdx: UInt32;
  end;

  TSlotPool = record
    Slots: array of TSlotArray;
    Count: UInt32;
    Cap: UInt32;
    NumSlots: UInt32;
  end;

procedure SlotPoolInit(out P: TSlotPool; ACap, ANumSlots: UInt32);
var i: UInt32;
begin
  P.Cap := ACap;
  P.NumSlots := ANumSlots;
  P.Count := 0;
  SetLength(P.Slots, ACap);
  if ACap > 0 then
    for i := 0 to ACap - 1 do
      SetLength(P.Slots[i], ANumSlots);
end;

function SlotPoolAlloc(var P: TSlotPool): UInt32;
var i: UInt32; oldCap: UInt32;
begin
  if P.Count >= P.Cap then
  begin
    oldCap := P.Cap;
    P.Cap := P.Cap * 2;
    SetLength(P.Slots, P.Cap);
    for i := oldCap to P.Cap - 1 do
      SetLength(P.Slots[i], P.NumSlots);
  end;
  Result := P.Count;
  Inc(P.Count);
end;

function SlotPoolClone(var P: TSlotPool; ASrcIdx: UInt32): UInt32;
begin
  Result := SlotPoolAlloc(P);
  Move(P.Slots[ASrcIdx][0], P.Slots[Result][0], P.NumSlots * SizeOf(SizeInt));
end;

type
  TThreadList2 = record
    Items: array of TThread;
    Count: UInt32;
    MaxCount: UInt32;
  end;

procedure InitThreadList2(out TL: TThreadList2; AMax: UInt32);
begin
  TL.MaxCount := AMax;
  SetLength(TL.Items, AMax);
  TL.Count := 0;
end;

function NfaSearch(const AProgram: TRegexProgram;
  const AInput: PAnsiChar; ALen: SizeUInt; AAnchored: Boolean;
  AStartPos: SizeUInt;
  out AMatch: TMatch): Boolean;
var
  CList, NList: TThreadList2;
  Pool: TSlotPool;
  Seen: TSparseSet;
  Stack: array of UInt32;
  StackSlot: array of UInt32;
  StackTop: UInt32;
  LCodeLen: UInt32;
  i, pos: SizeUInt;
  ch: Byte;
  inst: TInstruction;
  matched: Boolean;
  matchSlots: TSlotArray;
  initSlotIdx: UInt32;
  startPos: SizeUInt;
  prefixPos: SizeInt;
  curSlotIdx: UInt32;
  k: SizeUInt;

  procedure EpsilonClose(AStartPC, ASlotIdx: UInt32);
  var LInst: TInstruction; LPC, LSIdx, LNewIdx: UInt32;
  begin
    if AStartPC >= LCodeLen then Exit;
    if SparseContains(Seen, AStartPC) then Exit;
    StackTop := 0;
    Stack[StackTop] := AStartPC;
    StackSlot[StackTop] := ASlotIdx;
    Inc(StackTop);
    while StackTop > 0 do
    begin
      Dec(StackTop);
      LPC := Stack[StackTop];
      LSIdx := StackSlot[StackTop];
      if LPC >= LCodeLen then Continue;
      if not SparseAdd(Seen, LPC) then Continue;
      LInst := AProgram.Code[LPC];
      case LInst.Op of
        opSplit:
        begin
          Stack[StackTop] := LInst.Y;
          StackSlot[StackTop] := LSIdx;
          Inc(StackTop);
          Stack[StackTop] := LInst.X;
          StackSlot[StackTop] := LSIdx;
          Inc(StackTop);
        end;
        opJump:
        begin
          Stack[StackTop] := LInst.Target;
          StackSlot[StackTop] := LSIdx;
          Inc(StackTop);
        end;
        opSave:
        begin
          LNewIdx := SlotPoolClone(Pool, LSIdx);
          if LInst.Slot < Pool.NumSlots then
            Pool.Slots[LNewIdx][LInst.Slot] := SizeInt(pos);
          Stack[StackTop] := LPC + 1;
          StackSlot[StackTop] := LNewIdx;
          Inc(StackTop);
        end;
        opAssert:
        begin
          case LInst.Assert of
            akStart:
              if pos = 0 then begin
                Stack[StackTop] := LPC + 1; StackSlot[StackTop] := LSIdx; Inc(StackTop);
              end;
            akEnd:
              if pos = ALen then begin
                Stack[StackTop] := LPC + 1; StackSlot[StackTop] := LSIdx; Inc(StackTop);
              end;
            akWordBoundary:
              if ((pos = 0) or not IsWordChar(Ord(AInput[pos - 1]))) <>
                 ((pos >= ALen) or not IsWordChar(Ord(AInput[pos]))) then
              begin
                Stack[StackTop] := LPC + 1; StackSlot[StackTop] := LSIdx; Inc(StackTop);
              end;
            akNotWordBoundary:
              if not (((pos = 0) or not IsWordChar(Ord(AInput[pos - 1]))) <>
                      ((pos >= ALen) or not IsWordChar(Ord(AInput[pos])))) then
              begin
                Stack[StackTop] := LPC + 1; StackSlot[StackTop] := LSIdx; Inc(StackTop);
              end;
          end;
        end;
      else
        if CList.Count < CList.MaxCount then
        begin
          CList.Items[CList.Count].PC := LPC;
          CList.Items[CList.Count].SlotIdx := LSIdx;
          Inc(CList.Count);
        end;
      end;
    end;
  end;

begin
  AMatch.Start := -1;
  AMatch.Len := 0;
  AMatch.Groups := nil;
  Result := False;

  LCodeLen := Length(AProgram.Code);
  if LCodeLen = 0 then Exit;

  InitThreadList2(CList, LCodeLen);
  InitThreadList2(NList, LCodeLen);
  SparseInit(Seen, LCodeLen);
  SetLength(Stack, LCodeLen * 2);
  SetLength(StackSlot, LCodeLen * 2);

  SlotPoolInit(Pool, LCodeLen * 2, AProgram.NumSlots);

  SetLength(matchSlots, AProgram.NumSlots);
  matched := False;

  startPos := AStartPos;
  if (not AAnchored) and (AProgram.LiteralPrefixLen > 0) and (AStartPos < ALen) then
  begin
    prefixPos := SizeInt(ScanFindByte(AInput + AStartPos, ALen - AStartPos,
                  Byte(AProgram.LiteralPrefix[1])));
    if prefixPos < 0 then Exit;
    startPos := AStartPos + SizeUInt(prefixPos);
  end;

  pos := startPos;

  while pos <= ALen do
  begin
    SparseClear(Seen);
    CList.Count := 0;

    // Epsilon closure on NList items from previous byte step
    if NList.Count > 0 then
      for i := 0 to NList.Count - 1 do
        EpsilonClose(NList.Items[i].PC, NList.Items[i].SlotIdx);

    // Inject start state (unanchored search, before first match)
    if (not AAnchored) and (not matched) then
    begin
      initSlotIdx := SlotPoolAlloc(Pool);
      if AProgram.NumSlots > 0 then
        for i := 0 to AProgram.NumSlots - 1 do
          Pool.Slots[initSlotIdx][i] := -1;
      EpsilonClose(0, initSlotIdx);
    end;

    // Process consuming instructions
    NList.Count := 0;

    if CList.Count > 0 then
    for i := 0 to CList.Count - 1 do
    begin
      inst := AProgram.Code[CList.Items[i].PC];
      curSlotIdx := CList.Items[i].SlotIdx;
      case inst.Op of
        opLiteral:
          if (pos < ALen) and (Ord(AInput[pos]) = inst.Ch) then
          begin
            if NList.Count < NList.MaxCount then
            begin
              NList.Items[NList.Count].PC := CList.Items[i].PC + 1;
              NList.Items[NList.Count].SlotIdx := curSlotIdx;
              Inc(NList.Count);
            end;
          end;
        opAnyChar:
          if (pos < ALen) and (AInput[pos] <> #10) then
          begin
            if NList.Count < NList.MaxCount then
            begin
              NList.Items[NList.Count].PC := CList.Items[i].PC + 1;
              NList.Items[NList.Count].SlotIdx := curSlotIdx;
              Inc(NList.Count);
            end;
          end;
        opCharClass:
          if pos < ALen then
          begin
            ch := Ord(AInput[pos]);
            if CharBitmapTest(AProgram.Classes[inst.ClassIdx], ch) xor inst.Negated then
            begin
              if NList.Count < NList.MaxCount then
              begin
                NList.Items[NList.Count].PC := CList.Items[i].PC + 1;
                NList.Items[NList.Count].SlotIdx := curSlotIdx;
                Inc(NList.Count);
              end;
            end;
          end;
        opMatch:
        begin
          if (not matched) or
             (Pool.Slots[curSlotIdx][0] < matchSlots[0]) or
             ((Pool.Slots[curSlotIdx][0] = matchSlots[0]) and
              (SizeInt(pos) - Pool.Slots[curSlotIdx][0] > matchSlots[1] - matchSlots[0])) then
          begin
            matched := True;
            Move(Pool.Slots[curSlotIdx][0], matchSlots[0],
                 AProgram.NumSlots * SizeOf(SizeInt));
            matchSlots[1] := SizeInt(pos);
          end;
        end;
      end;
    end;

    Inc(pos);
    if (NList.Count = 0) and matched then Break;
    if (NList.Count = 0) and AAnchored then Break;

    // Prefilter skip for NfaSearch
    if (NList.Count = 0) and (not matched) and (pos < ALen) then
    begin
      if AProgram.LiteralPrefixLen > 0 then
      begin
        while True do
        begin
          prefixPos := SizeInt(ScanFindByte(AInput + pos, ALen - pos,
                        Byte(AProgram.LiteralPrefix[1])));
          if prefixPos < 0 then Exit;
          pos := pos + SizeUInt(prefixPos);
          if AProgram.LiteralPrefixLen <= 1 then Break;
          if pos + AProgram.LiteralPrefixLen > ALen then Exit;
          k := 1;
          while (k < AProgram.LiteralPrefixLen) and
                (AInput[pos + k] = AnsiChar(AProgram.LiteralPrefix[k + 1])) do
            Inc(k);
          if k = AProgram.LiteralPrefixLen then Break;
          Inc(pos);
          if pos >= ALen then Exit;
        end;
      end
      else if (AProgram.StartClassSize > 0) and (AProgram.StartClassSize < 128) then
      begin
        while (pos < ALen) and
              (not CharBitmapTest(AProgram.StartClass, Ord(AInput[pos]))) do
          Inc(pos);
      end;
    end;
  end;

  if matched then
  begin
    if Length(matchSlots) >= 2 then
    begin
      AMatch.Start := matchSlots[0];
      AMatch.Len := matchSlots[1] - matchSlots[0];
    end;
    if AProgram.NumSlots > 2 then
    begin
      SetLength(AMatch.Groups, (AProgram.NumSlots - 2) div 2);
      for i := 0 to High(AMatch.Groups) do
      begin
        AMatch.Groups[i].Start := matchSlots[(i + 1) * 2];
        if (matchSlots[(i + 1) * 2] >= 0) and (matchSlots[(i + 1) * 2 + 1] >= 0) then
          AMatch.Groups[i].Len := matchSlots[(i + 1) * 2 + 1] - matchSlots[(i + 1) * 2]
        else
          AMatch.Groups[i].Len := 0;
      end;
    end;
    Result := True;
  end;
end;

function NfaFindAll(const AProgram: TRegexProgram;
  const AInput: PAnsiChar; ALen: SizeUInt): TMatchArray;
var
  LMatch: TMatch;
  LPos: SizeUInt;
  LCount: SizeUInt;
begin
  SetLength(Result, 0);
  LCount := 0;
  LPos := 0;

  while LPos <= ALen do
  begin
    if not NfaSearch(AProgram, AInput, ALen, False, LPos, LMatch) then
      Break;

    if LCount >= SizeUInt(Length(Result)) then
      SetLength(Result, LCount + 32);
    Result[LCount] := LMatch;
    Inc(LCount);

    if LMatch.Len > 0 then
      LPos := SizeUInt(LMatch.Start) + SizeUInt(LMatch.Len)
    else
      LPos := SizeUInt(LMatch.Start) + 1;
  end;
  SetLength(Result, LCount);
end;

end.
