unit nextpas.core.regex.nfa;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.regex.base,
  nextpas.core.regex.charclass;

function NfaSearch(const AProgram: TRegexProgram;
  const AInput: PAnsiChar; ALen: SizeUInt; AAnchored: Boolean;
  out AMatch: TMatch): Boolean;

function NfaFindAll(const AProgram: TRegexProgram;
  const AInput: PAnsiChar; ALen: SizeUInt): TMatchArray;

implementation

uses SysUtils, nextpas.core.text.scan;

const
  MAX_THREADS = 4096;

type
  TThread = record
    PC: UInt32;
    Slots: array of SizeInt;
  end;
  TThreadList = record
    Items: array of TThread;
    Count: UInt32;
    Gen: array of UInt32;
    CurGen: UInt32;
  end;

procedure InitThreadList(var TL: TThreadList; AMaxPC: UInt32);
begin
  SetLength(TL.Items, MAX_THREADS);
  TL.Count := 0;
  SetLength(TL.Gen, AMaxPC + 1);
  FillChar(TL.Gen[0], (AMaxPC + 1) * SizeOf(UInt32), 0);
  TL.CurGen := 1;
end;

procedure ClearThreadList(var TL: TThreadList);
begin
  TL.Count := 0;
  Inc(TL.CurGen);
end;

procedure AddThread(var TL: TThreadList; const AProgram: TRegexProgram;
  APC: UInt32; const ASlots: array of SizeInt; APos: SizeUInt;
  const AInput: PAnsiChar; ALen: SizeUInt);
var inst: TInstruction; newSlots: array of SizeInt; i: Integer;
begin
  if APC >= UInt32(Length(AProgram.Code)) then Exit;
  if TL.Gen[APC] = TL.CurGen then Exit;
  TL.Gen[APC] := TL.CurGen;

  inst := AProgram.Code[APC];
  case inst.Op of
    opSplit:
    begin
      AddThread(TL, AProgram, inst.X, ASlots, APos, AInput, ALen);
      AddThread(TL, AProgram, inst.Y, ASlots, APos, AInput, ALen);
    end;
    opJump:
      AddThread(TL, AProgram, inst.Target, ASlots, APos, AInput, ALen);
    opSave:
    begin
      SetLength(newSlots, Length(ASlots));
      for i := 0 to High(ASlots) do newSlots[i] := ASlots[i];
      if inst.Slot < UInt32(Length(newSlots)) then
        newSlots[inst.Slot] := SizeInt(APos);
      AddThread(TL, AProgram, APC + 1, newSlots, APos, AInput, ALen);
    end;
    opAssert:
    begin
      case inst.Assert of
        akStart: if APos = 0 then AddThread(TL, AProgram, APC + 1, ASlots, APos, AInput, ALen);
        akEnd: if APos = ALen then AddThread(TL, AProgram, APC + 1, ASlots, APos, AInput, ALen);
        akWordBoundary:
        begin
          if ((APos = 0) or not IsWordChar(Ord(AInput[APos - 1]))) <>
             ((APos >= ALen) or not IsWordChar(Ord(AInput[APos]))) then
            AddThread(TL, AProgram, APC + 1, ASlots, APos, AInput, ALen);
        end;
        akNotWordBoundary:
        begin
          if not (((APos = 0) or not IsWordChar(Ord(AInput[APos - 1]))) <>
                  ((APos >= ALen) or not IsWordChar(Ord(AInput[APos])))) then
            AddThread(TL, AProgram, APC + 1, ASlots, APos, AInput, ALen);
        end;
      end;
    end;
  else
    if TL.Count < MAX_THREADS then
    begin
      TL.Items[TL.Count].PC := APC;
      SetLength(TL.Items[TL.Count].Slots, Length(ASlots));
      for i := 0 to High(ASlots) do
        TL.Items[TL.Count].Slots[i] := ASlots[i];
      Inc(TL.Count);
    end;
  end;
end;

function NfaSearch(const AProgram: TRegexProgram;
  const AInput: PAnsiChar; ALen: SizeUInt; AAnchored: Boolean;
  out AMatch: TMatch): Boolean;
var
  CList, NList, Tmp: TThreadList;
  i, pos: SizeUInt;
  ch: Byte;
  inst: TInstruction;
  matched: Boolean;
  matchSlots: array of SizeInt;
  initSlots: array of SizeInt;
  startPos: SizeUInt;
  prefixPos: SizeInt;
begin
  AMatch.Start := -1;
  AMatch.Len := 0;
  AMatch.Groups := nil;
  Result := False;

  if Length(AProgram.Code) = 0 then Exit;

  InitThreadList(CList, Length(AProgram.Code));
  InitThreadList(NList, Length(AProgram.Code));

  SetLength(initSlots, AProgram.NumSlots);
  for i := 0 to High(initSlots) do initSlots[i] := -1;
  SetLength(matchSlots, AProgram.NumSlots);
  matched := False;

  startPos := 0;

  // SIMD prefilter: skip to first candidate position
  if (not AAnchored) and (AProgram.LiteralPrefixLen > 0) then
  begin
    prefixPos := SizeInt(ScanFindByte(AInput, ALen, Byte(AProgram.LiteralPrefix[1])));
    if prefixPos < 0 then Exit;
    startPos := SizeUInt(prefixPos);
  end;

  pos := startPos;
  ClearThreadList(CList);
  AddThread(CList, AProgram, 0, initSlots, pos, AInput, ALen);

  while pos <= ALen do
  begin
    if (not AAnchored) and (not matched) then
      AddThread(CList, AProgram, 0, initSlots, pos, AInput, ALen);

    ClearThreadList(NList);

    if CList.Count > 0 then
    for i := 0 to CList.Count - 1 do
    begin
      inst := AProgram.Code[CList.Items[i].PC];
      case inst.Op of
        opLiteral:
        begin
          if (pos < ALen) and (Ord(AInput[pos]) = inst.Ch) then
            AddThread(NList, AProgram, CList.Items[i].PC + 1,
              CList.Items[i].Slots, pos + 1, AInput, ALen);
        end;
        opAnyChar:
        begin
          if (pos < ALen) and (AInput[pos] <> #10) then
            AddThread(NList, AProgram, CList.Items[i].PC + 1,
              CList.Items[i].Slots, pos + 1, AInput, ALen);
        end;
        opCharClass:
        begin
          if pos < ALen then
          begin
            ch := Ord(AInput[pos]);
            if CharBitmapTest(AProgram.Classes[inst.ClassIdx], ch) xor inst.Negated then
              AddThread(NList, AProgram, CList.Items[i].PC + 1,
                CList.Items[i].Slots, pos + 1, AInput, ALen);
          end;
        end;
        opMatch:
        begin
          if (Length(CList.Items[i].Slots) >= 2) and
             ((not matched) or (CList.Items[i].Slots[0] < matchSlots[0]) or
             ((CList.Items[i].Slots[0] = matchSlots[0]) and
              (SizeInt(pos) - CList.Items[i].Slots[0] > matchSlots[1] - matchSlots[0]))) then
          begin
            matched := True;
            Move(CList.Items[i].Slots[0], matchSlots[0], Length(matchSlots) * SizeOf(SizeInt));
            if Length(matchSlots) >= 2 then
              matchSlots[1] := SizeInt(pos)
            else
            begin
              AMatch.Start := CList.Items[i].Slots[0];
              AMatch.Len := SizeInt(pos) - AMatch.Start;
            end;
          end;
        end;
      end;
    end;

    Tmp := CList; CList := NList; NList := Tmp;
    Inc(pos);

    if (CList.Count = 0) and matched then Break;
    if (CList.Count = 0) and AAnchored then Break;
  end;

  if matched then
  begin
    if Length(matchSlots) >= 2 then
    begin
      AMatch.Start := matchSlots[0];
      AMatch.Len := matchSlots[1] - matchSlots[0];
    end;
    // Extract capture groups
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

  // Cleanup thread lists to avoid leaking Slots arrays
  for i := 0 to High(CList.Items) do CList.Items[i].Slots := nil;
  for i := 0 to High(NList.Items) do NList.Items[i].Slots := nil;
end;

function NfaFindAll(const AProgram: TRegexProgram;
  const AInput: PAnsiChar; ALen: SizeUInt): TMatchArray;
var
  LMatch: TMatch;
  LPos: SizeUInt;
  LCount: SizeUInt;
  LSubInput: PAnsiChar;
  LSubLen: SizeUInt;
begin
  SetLength(Result, 0);
  LCount := 0;
  LPos := 0;

  while LPos <= ALen do
  begin
    LSubInput := AInput + LPos;
    LSubLen := ALen - LPos;
    if not NfaSearch(AProgram, LSubInput, LSubLen, True, LMatch) then
    begin
      // Try unanchored from next position
      Inc(LPos);
      Continue;
    end;

    // Adjust offsets
    LMatch.Start := LMatch.Start + SizeInt(LPos);

    if LCount >= SizeUInt(Length(Result)) then
      SetLength(Result, LCount + 32);
    Result[LCount] := LMatch;
    Inc(LCount);

    // Advance past match (handle empty match)
    if LMatch.Len > 0 then
      LPos := SizeUInt(LMatch.Start) + SizeUInt(LMatch.Len)
    else
      Inc(LPos);
  end;
  SetLength(Result, LCount);
end;

end.
