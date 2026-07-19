unit nextpas.core.text.unicode.bidi;

{**
 * UAX #9 Unicode Bidirectional Algorithm (Unicode 16.0), through L2.
 * L3/L4 out of scope (matches UCD BidiCharacterTest / BidiTest notes).
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.unicode.types;

const
  BIDI_LEVEL_REMOVED = $FF;
  BIDI_MAX_DEPTH = 125;

type
  TBidiLevel = Byte;
  TBidiLevelArray = array of TBidiLevel;
  TBidiIndexArray = array of SizeInt;
  TBidiClassArray = array of TBidiClass;

  { AParagraphDir: 0=force LTR, 1=force RTL, 2=auto P2/P3. }
  TBidiResolveResult = record
    ParagraphLevel: TBidiLevel;
    Levels: TBidiLevelArray;
    VisualToLogical: TBidiIndexArray;
  end;

function ResolveBidiClasses(const AClasses: array of TBidiClass;
  const AParagraphDir: Integer = 2): TBidiResolveResult;

function ResolveBidiClassesWithBrackets(const AClasses: array of TBidiClass;
  const ACodepoints: array of TUnicodeCodepoint;
  const AParagraphDir: Integer = 2): TBidiResolveResult;

function ResolveBidi(const AText: string;
  const AParagraphDir: Integer = 2): TBidiResolveResult;

implementation

uses
  nextpas.core.text.unicode.props,
  nextpas.core.text.utf8;

type
  TStackEntry = record
    Level: Byte;
    OverrideCls: TBidiClass;
    Isolate: Boolean;
  end;

function IsIsolateInitiator(const C: TBidiClass): Boolean; inline;
begin
  Result := C in [bcLRI, bcRLI, bcFSI];
end;

function IsRemovedByX9(const C: TBidiClass): Boolean; inline;
begin
  Result := C in [bcRLE, bcLRE, bcRLO, bcLRO, bcPDF, bcBN];
end;

function LeastGreaterOdd(const L: Integer): Integer; inline;
begin
  Result := L + 1;
  if (Result and 1) = 0 then
    Inc(Result);
end;

function LeastGreaterEven(const L: Integer): Integer; inline;
begin
  Result := L + 1;
  if (Result and 1) <> 0 then
    Inc(Result);
end;

function ResolveParagraphLevel(const AClasses: array of TBidiClass;
  const AParagraphDir: Integer): Byte;
var
  I, Isolate: Integer;
  C: TBidiClass;
begin
  if AParagraphDir = 0 then Exit(0);
  if AParagraphDir = 1 then Exit(1);
  Isolate := 0;
  for I := 0 to High(AClasses) do
  begin
    C := AClasses[I];
    if IsIsolateInitiator(C) then
      Inc(Isolate)
    else if C = bcPDI then
    begin
      if Isolate > 0 then Dec(Isolate);
    end
    else if Isolate = 0 then
    begin
      if C = bcL then Exit(0);
      if C in [bcR, bcAL] then Exit(1);
    end;
  end;
  Result := 0;
end;

function FsiDirection(const AClasses: array of TBidiClass; const AFrom: Integer): TBidiClass;
var
  I, Isolate: Integer;
  C: TBidiClass;
begin
  Result := bcL;
  Isolate := 0;
  for I := AFrom + 1 to High(AClasses) do
  begin
    C := AClasses[I];
    if IsIsolateInitiator(C) then
      Inc(Isolate)
    else if C = bcPDI then
    begin
      if Isolate = 0 then Break;
      Dec(Isolate);
    end
    else if Isolate = 0 then
    begin
      if C = bcL then Exit(bcL);
      if C in [bcR, bcAL] then Exit(bcR);
    end;
  end;
end;

procedure ApplyExplicit(const AOrig: array of TBidiClass; const AParaLevel: Byte;
  var ATypes: TBidiClassArray; var ALevels: TBidiLevelArray);
var
  N, I, StackTop, OverflowIsolate, OverflowEmbedding, ValidIsolate: Integer;
  Stack: array[0..BIDI_MAX_DEPTH + 2] of TStackEntry;
  NewLevel: Integer;
  C: TBidiClass;

  procedure Push(const ALevel: Byte; const AOverride: TBidiClass; const AIsolate: Boolean);
  begin
    if StackTop >= High(Stack) then Exit;
    Inc(StackTop);
    Stack[StackTop].Level := ALevel;
    Stack[StackTop].OverrideCls := AOverride;
    Stack[StackTop].Isolate := AIsolate;
  end;

begin
  N := Length(AOrig);
  StackTop := 0;
  Stack[0].Level := AParaLevel;
  Stack[0].OverrideCls := bcON;
  Stack[0].Isolate := False;
  OverflowIsolate := 0;
  OverflowEmbedding := 0;
  ValidIsolate := 0;

  for I := 0 to N - 1 do
  begin
    C := AOrig[I];
    ATypes[I] := C;
    case C of
      bcRLE:
        begin
          ALevels[I] := Stack[StackTop].Level;
          NewLevel := LeastGreaterOdd(Stack[StackTop].Level);
          if (OverflowIsolate = 0) and (OverflowEmbedding = 0) and (NewLevel <= BIDI_MAX_DEPTH) then
            Push(Byte(NewLevel), bcON, False)
          else if OverflowIsolate = 0 then
            Inc(OverflowEmbedding);
        end;
      bcLRE:
        begin
          ALevels[I] := Stack[StackTop].Level;
          NewLevel := LeastGreaterEven(Stack[StackTop].Level);
          if (OverflowIsolate = 0) and (OverflowEmbedding = 0) and (NewLevel <= BIDI_MAX_DEPTH) then
            Push(Byte(NewLevel), bcON, False)
          else if OverflowIsolate = 0 then
            Inc(OverflowEmbedding);
        end;
      bcRLO:
        begin
          ALevels[I] := Stack[StackTop].Level;
          NewLevel := LeastGreaterOdd(Stack[StackTop].Level);
          if (OverflowIsolate = 0) and (OverflowEmbedding = 0) and (NewLevel <= BIDI_MAX_DEPTH) then
            Push(Byte(NewLevel), bcR, False)
          else if OverflowIsolate = 0 then
            Inc(OverflowEmbedding);
        end;
      bcLRO:
        begin
          ALevels[I] := Stack[StackTop].Level;
          NewLevel := LeastGreaterEven(Stack[StackTop].Level);
          if (OverflowIsolate = 0) and (OverflowEmbedding = 0) and (NewLevel <= BIDI_MAX_DEPTH) then
            Push(Byte(NewLevel), bcL, False)
          else if OverflowIsolate = 0 then
            Inc(OverflowEmbedding);
        end;
      bcRLI:
        begin
          ALevels[I] := Stack[StackTop].Level;
          if Stack[StackTop].OverrideCls <> bcON then
            ATypes[I] := Stack[StackTop].OverrideCls;
          NewLevel := LeastGreaterOdd(Stack[StackTop].Level);
          if (OverflowIsolate = 0) and (OverflowEmbedding = 0) and (NewLevel <= BIDI_MAX_DEPTH) then
          begin
            Inc(ValidIsolate);
            Push(Byte(NewLevel), bcON, True);
          end
          else
            Inc(OverflowIsolate);
        end;
      bcLRI:
        begin
          ALevels[I] := Stack[StackTop].Level;
          if Stack[StackTop].OverrideCls <> bcON then
            ATypes[I] := Stack[StackTop].OverrideCls;
          NewLevel := LeastGreaterEven(Stack[StackTop].Level);
          if (OverflowIsolate = 0) and (OverflowEmbedding = 0) and (NewLevel <= BIDI_MAX_DEPTH) then
          begin
            Inc(ValidIsolate);
            Push(Byte(NewLevel), bcON, True);
          end
          else
            Inc(OverflowIsolate);
        end;
      bcFSI:
        begin
          ALevels[I] := Stack[StackTop].Level;
          if Stack[StackTop].OverrideCls <> bcON then
            ATypes[I] := Stack[StackTop].OverrideCls;
          if FsiDirection(AOrig, I) = bcR then
            NewLevel := LeastGreaterOdd(Stack[StackTop].Level)
          else
            NewLevel := LeastGreaterEven(Stack[StackTop].Level);
          if (OverflowIsolate = 0) and (OverflowEmbedding = 0) and (NewLevel <= BIDI_MAX_DEPTH) then
          begin
            Inc(ValidIsolate);
            Push(Byte(NewLevel), bcON, True);
          end
          else
            Inc(OverflowIsolate);
        end;
      bcPDI:
        begin
          if OverflowIsolate > 0 then
            Dec(OverflowIsolate)
          else if ValidIsolate > 0 then
          begin
            OverflowEmbedding := 0;
            while (StackTop > 0) and (not Stack[StackTop].Isolate) do
              Dec(StackTop);
            if StackTop > 0 then
            begin
              Dec(StackTop);
              Dec(ValidIsolate);
            end;
          end;
          ALevels[I] := Stack[StackTop].Level;
          if Stack[StackTop].OverrideCls <> bcON then
            ATypes[I] := Stack[StackTop].OverrideCls;
        end;
      bcPDF:
        begin
          ALevels[I] := Stack[StackTop].Level;
          if OverflowIsolate = 0 then
          begin
            if OverflowEmbedding > 0 then
              Dec(OverflowEmbedding)
            else if (StackTop > 0) and (not Stack[StackTop].Isolate) then
              Dec(StackTop);
          end;
        end;
      bcB:
        begin
          ALevels[I] := AParaLevel;
          StackTop := 0;
          Stack[0].Level := AParaLevel;
          Stack[0].OverrideCls := bcON;
          Stack[0].Isolate := False;
          OverflowIsolate := 0;
          OverflowEmbedding := 0;
          ValidIsolate := 0;
        end;
    else
      begin
        ALevels[I] := Stack[StackTop].Level;
        if Stack[StackTop].OverrideCls <> bcON then
          ATypes[I] := Stack[StackTop].OverrideCls;
      end;
    end;
  end;
end;

procedure ProcessRun(var ATypes: TBidiClassArray; var ALevels: TBidiLevelArray;
  const AOrig: array of TBidiClass;
  const ACodepoints: array of TUnicodeCodepoint; const AHasCp: Boolean;
  const ARunStart, ARunLimit: Integer; const ALevel: Byte;
  const ASos, AEos: TBidiClass);
var
  J, K, Start, Limit, StackTop: Integer;
  LastType, LastStrong, Dir, LeftT, RightT, Strong: TBidiClass;
  Pairing: array of Integer;
  BrStack: array of Integer;
  OpenCp: TUnicodeCodepoint;
begin
  { W1 NSM }
  LastType := ASos;
  for J := ARunStart to ARunLimit do
  begin
    if ALevels[J] = BIDI_LEVEL_REMOVED then Continue;
    if ATypes[J] = bcNSM then
      ATypes[J] := LastType
    else
    begin
      LastType := ATypes[J];
      if IsIsolateInitiator(ATypes[J]) or (ATypes[J] = bcPDI) then
        LastType := bcON;
    end;
  end;

  { W2 EN after AL → AN }
  LastStrong := ASos;
  for J := ARunStart to ARunLimit do
  begin
    if ALevels[J] = BIDI_LEVEL_REMOVED then Continue;
    if ATypes[J] in [bcR, bcL, bcAL] then
      LastStrong := ATypes[J]
    else if (ATypes[J] = bcEN) and (LastStrong = bcAL) then
      ATypes[J] := bcAN;
  end;

  { W3 AL → R }
  for J := ARunStart to ARunLimit do
    if (ALevels[J] <> BIDI_LEVEL_REMOVED) and (ATypes[J] = bcAL) then
      ATypes[J] := bcR;

  { W4 ES/CS between numbers }
  for J := ARunStart to ARunLimit do
  begin
    if ALevels[J] = BIDI_LEVEL_REMOVED then Continue;
    if not (ATypes[J] in [bcES, bcCS]) then Continue;
    Start := J - 1;
    while (Start >= ARunStart) and (ALevels[Start] = BIDI_LEVEL_REMOVED) do Dec(Start);
    Limit := J + 1;
    while (Limit <= ARunLimit) and (ALevels[Limit] = BIDI_LEVEL_REMOVED) do Inc(Limit);
    if (Start < ARunStart) or (Limit > ARunLimit) then Continue;
    if (ATypes[J] = bcES) and (ATypes[Start] = bcEN) and (ATypes[Limit] = bcEN) then
      ATypes[J] := bcEN
    else if (ATypes[J] = bcCS) and (ATypes[Start] = ATypes[Limit]) and
            (ATypes[Start] in [bcEN, bcAN]) then
      ATypes[J] := ATypes[Start];
  end;

  { W5 ET near EN }
  for J := ARunStart to ARunLimit do
  begin
    if (ALevels[J] = BIDI_LEVEL_REMOVED) or (ATypes[J] <> bcEN) then Continue;
    K := J - 1;
    while (K >= ARunStart) and ((ALevels[K] = BIDI_LEVEL_REMOVED) or (ATypes[K] = bcET)) do
    begin
      if ALevels[K] <> BIDI_LEVEL_REMOVED then ATypes[K] := bcEN;
      Dec(K);
    end;
    K := J + 1;
    while (K <= ARunLimit) and ((ALevels[K] = BIDI_LEVEL_REMOVED) or (ATypes[K] = bcET)) do
    begin
      if ALevels[K] <> BIDI_LEVEL_REMOVED then ATypes[K] := bcEN;
      Inc(K);
    end;
  end;

  { W6 ES/ET/CS → ON }
  for J := ARunStart to ARunLimit do
    if (ALevels[J] <> BIDI_LEVEL_REMOVED) and (ATypes[J] in [bcES, bcET, bcCS]) then
      ATypes[J] := bcON;

  { W7 EN → L after L }
  LastStrong := ASos;
  for J := ARunStart to ARunLimit do
  begin
    if ALevels[J] = BIDI_LEVEL_REMOVED then Continue;
    if ATypes[J] in [bcL, bcR] then
      LastStrong := ATypes[J]
    else if (ATypes[J] = bcEN) and (LastStrong = bcL) then
      ATypes[J] := bcL;
  end;

  { N0 brackets — only when codepoints available }
  if AHasCp then
  begin
    SetLength(Pairing, Length(ATypes));
    for J := 0 to High(Pairing) do
      Pairing[J] := -1;
    SetLength(BrStack, ARunLimit - ARunStart + 4);
    StackTop := 0;
    for J := ARunStart to ARunLimit do
    begin
      if ALevels[J] = BIDI_LEVEL_REMOVED then Continue;
      case GetBidiPairedBracketType(ACodepoints[J]) of
        bpbtOpen:
          begin
            BrStack[StackTop] := J;
            Inc(StackTop);
          end;
        bpbtClose:
          begin
            OpenCp := GetBidiPairedBracket(ACodepoints[J]);
            K := StackTop - 1;
            while K >= 0 do
            begin
              if ACodepoints[BrStack[K]] = OpenCp then
              begin
                Pairing[BrStack[K]] := J;
                Pairing[J] := BrStack[K];
                StackTop := K;
                Break;
              end;
              Dec(K);
            end;
          end;
      end;
    end;
    for J := ARunStart to ARunLimit do
    begin
      if (ALevels[J] = BIDI_LEVEL_REMOVED) or (Pairing[J] < 0) then Continue;
      if GetBidiPairedBracketType(ACodepoints[J]) <> bpbtOpen then Continue;
      { determine bracket direction N0 }
      Strong := bcON;
      for K := J + 1 to Pairing[J] - 1 do
      begin
        if ALevels[K] = BIDI_LEVEL_REMOVED then Continue;
        if ATypes[K] = bcL then
        begin
          if Strong = bcON then Strong := bcL
          else if Strong = bcR then begin Strong := bcON; Break; end;
        end
        else if ATypes[K] in [bcR, bcAN, bcEN] then
        begin
          if Strong = bcON then Strong := bcR
          else if Strong = bcL then begin Strong := bcON; Break; end;
        end;
      end;
      Dir := Strong;
      if Dir = bcON then
      begin
        { use embedding direction / preceding strong — simplified N0 }
        if (ALevel and 1) <> 0 then Dir := bcR else Dir := bcL;
      end;
      if Dir <> bcON then
      begin
        ATypes[J] := Dir;
        ATypes[Pairing[J]] := Dir;
      end;
    end;
  end;

  { N1/N2 neutrals }
  J := ARunStart;
  while J <= ARunLimit do
  begin
    if ALevels[J] = BIDI_LEVEL_REMOVED then begin Inc(J); Continue; end;
    if not ((ATypes[J] in [bcB, bcS, bcWS, bcON]) or IsIsolateInitiator(ATypes[J]) or
            (ATypes[J] = bcPDI)) then
    begin
      Inc(J);
      Continue;
    end;
    Start := J;
    while J <= ARunLimit do
    begin
      if ALevels[J] = BIDI_LEVEL_REMOVED then begin Inc(J); Continue; end;
      if (ATypes[J] in [bcB, bcS, bcWS, bcON]) or IsIsolateInitiator(ATypes[J]) or
         (ATypes[J] = bcPDI) then
        Inc(J)
      else
        Break;
    end;
    Limit := J - 1;
    while (Limit >= Start) and (ALevels[Limit] = BIDI_LEVEL_REMOVED) do Dec(Limit);

    K := Start - 1;
    while (K >= ARunStart) and (ALevels[K] = BIDI_LEVEL_REMOVED) do Dec(K);
    if K < ARunStart then LeftT := ASos
    else
    begin
      LeftT := ATypes[K];
      if LeftT in [bcAN, bcEN] then LeftT := bcR;
    end;
    K := Limit + 1;
    while (K <= ARunLimit) and (ALevels[K] = BIDI_LEVEL_REMOVED) do Inc(K);
    if K > ARunLimit then RightT := AEos
    else
    begin
      RightT := ATypes[K];
      if RightT in [bcAN, bcEN] then RightT := bcR;
    end;

    if (LeftT = RightT) and (LeftT in [bcL, bcR]) then
      Dir := LeftT
    else if (ALevel and 1) <> 0 then
      Dir := bcR
    else
      Dir := bcL;

    for K := Start to Limit do
      if (ALevels[K] <> BIDI_LEVEL_REMOVED) and
         ((ATypes[K] in [bcB, bcS, bcWS, bcON]) or IsIsolateInitiator(ATypes[K]) or
          (ATypes[K] = bcPDI)) then
        ATypes[K] := Dir;
  end;

  { I1/I2 }
  for J := ARunStart to ARunLimit do
  begin
    if ALevels[J] = BIDI_LEVEL_REMOVED then Continue;
    if (ALevel and 1) = 0 then
    begin
      if ATypes[J] = bcR then
        ALevels[J] := ALevel + 1
      else if ATypes[J] in [bcAN, bcEN] then
        ALevels[J] := ALevel + 2
      else
        ALevels[J] := ALevel;
    end
    else
    begin
      if ATypes[J] in [bcL, bcEN, bcAN] then
        ALevels[J] := ALevel + 1
      else
        ALevels[J] := ALevel;
    end;
  end;
end;

procedure ResolveCore(const AOrig: array of TBidiClass;
  const ACodepoints: array of TUnicodeCodepoint; const AHasCp: Boolean;
  const AParaLevel: Byte; var AOutLevels: TBidiLevelArray;
  var AVisual: TBidiIndexArray);
var
  N, I, J, K, RunStart, RunLimit, Level, PrevLevel, NextLevel, MaxLevel, Lev: Integer;
  Types: TBidiClassArray;
  Levels: TBidiLevelArray;
  Sos, Eos: TBidiClass;
  VisCount, Tmp: Integer;
begin
  N := Length(AOrig);
  SetLength(Types, N);
  SetLength(Levels, N);
  SetLength(AOutLevels, N);
  if N = 0 then
  begin
    SetLength(AVisual, 0);
    Exit;
  end;

  ApplyExplicit(AOrig, AParaLevel, Types, Levels);

  for I := 0 to N - 1 do
    if IsRemovedByX9(AOrig[I]) then
      Levels[I] := BIDI_LEVEL_REMOVED;

  I := 0;
  while I < N do
  begin
    if Levels[I] = BIDI_LEVEL_REMOVED then begin Inc(I); Continue; end;
    RunStart := I;
    Level := Levels[I];
    while (I < N) and ((Levels[I] = BIDI_LEVEL_REMOVED) or (Levels[I] = Level)) do
      Inc(I);
    RunLimit := I - 1;
    while (RunStart <= RunLimit) and (Levels[RunStart] = BIDI_LEVEL_REMOVED) do
      Inc(RunStart);
    while (RunLimit >= RunStart) and (Levels[RunLimit] = BIDI_LEVEL_REMOVED) do
      Dec(RunLimit);
    if RunStart > RunLimit then Continue;

    PrevLevel := AParaLevel;
    for J := RunStart - 1 downto 0 do
      if Levels[J] <> BIDI_LEVEL_REMOVED then
      begin
        PrevLevel := Levels[J];
        Break;
      end;
    NextLevel := AParaLevel;
    for J := RunLimit + 1 to N - 1 do
      if Levels[J] <> BIDI_LEVEL_REMOVED then
      begin
        NextLevel := Levels[J];
        Break;
      end;
    if PrevLevel > Level then J := PrevLevel else J := Level;
    if (J and 1) <> 0 then Sos := bcR else Sos := bcL;
    if NextLevel > Level then J := NextLevel else J := Level;
    if (J and 1) <> 0 then Eos := bcR else Eos := bcL;

    ProcessRun(Types, Levels, AOrig, ACodepoints, AHasCp, RunStart, RunLimit,
      Byte(Level), Sos, Eos);
  end;

  for I := 0 to N - 1 do
    if IsRemovedByX9(AOrig[I]) then
      AOutLevels[I] := BIDI_LEVEL_REMOVED
    else
      AOutLevels[I] := Levels[I];

  { L1 }
  for I := 0 to N - 1 do
  begin
    if AOutLevels[I] = BIDI_LEVEL_REMOVED then Continue;
    if AOrig[I] in [bcS, bcB] then
      AOutLevels[I] := AParaLevel;
  end;
  I := N - 1;
  while I >= 0 do
  begin
    if AOutLevels[I] = BIDI_LEVEL_REMOVED then begin Dec(I); Continue; end;
    if AOrig[I] in [bcWS, bcFSI, bcLRI, bcRLI, bcPDI, bcS, bcB] then
      AOutLevels[I] := AParaLevel
    else
      Break;
    Dec(I);
  end;
  for I := 0 to N - 1 do
  begin
    if AOutLevels[I] = BIDI_LEVEL_REMOVED then Continue;
    if AOrig[I] in [bcS, bcB] then
    begin
      J := I - 1;
      while J >= 0 do
      begin
        if AOutLevels[J] = BIDI_LEVEL_REMOVED then begin Dec(J); Continue; end;
        if AOrig[J] in [bcWS, bcFSI, bcLRI, bcRLI, bcPDI] then
          AOutLevels[J] := AParaLevel
        else
          Break;
        Dec(J);
      end;
    end;
  end;

  { L2 }
  MaxLevel := 0;
  for I := 0 to N - 1 do
    if (AOutLevels[I] <> BIDI_LEVEL_REMOVED) and (AOutLevels[I] > MaxLevel) then
      MaxLevel := AOutLevels[I];
  SetLength(AVisual, N);
  VisCount := 0;
  for I := 0 to N - 1 do
    if AOutLevels[I] <> BIDI_LEVEL_REMOVED then
    begin
      AVisual[VisCount] := I;
      Inc(VisCount);
    end;
  SetLength(AVisual, VisCount);
  Lev := MaxLevel;
  while Lev > 0 do
  begin
    I := 0;
    while I < VisCount do
    begin
      if AOutLevels[AVisual[I]] < Lev then begin Inc(I); Continue; end;
      J := I;
      while (I < VisCount) and (AOutLevels[AVisual[I]] >= Lev) do Inc(I);
      K := I - 1;
      while J < K do
      begin
        Tmp := AVisual[J];
        AVisual[J] := AVisual[K];
        AVisual[K] := Tmp;
        Inc(J);
        Dec(K);
      end;
    end;
    Dec(Lev);
  end;
end;

function ResolveBidiClasses(const AClasses: array of TBidiClass;
  const AParagraphDir: Integer): TBidiResolveResult;
var
  Dummy: array of TUnicodeCodepoint;
  Dyn: TBidiClassArray;
  I: Integer;
  Para: Byte;
begin
  SetLength(Dyn, Length(AClasses));
  for I := 0 to High(AClasses) do
    Dyn[I] := AClasses[I];
  SetLength(Dummy, 0);
  Para := ResolveParagraphLevel(Dyn, AParagraphDir);
  Result.ParagraphLevel := Para;
  ResolveCore(Dyn, Dummy, False, Para, Result.Levels, Result.VisualToLogical);
end;

function ResolveBidiClassesWithBrackets(const AClasses: array of TBidiClass;
  const ACodepoints: array of TUnicodeCodepoint;
  const AParagraphDir: Integer): TBidiResolveResult;
var
  DynC: TBidiClassArray;
  DynP: array of TUnicodeCodepoint;
  I: Integer;
  Para: Byte;
begin
  SetLength(DynC, Length(AClasses));
  SetLength(DynP, Length(ACodepoints));
  for I := 0 to High(AClasses) do
    DynC[I] := AClasses[I];
  for I := 0 to High(ACodepoints) do
    DynP[I] := ACodepoints[I];
  Para := ResolveParagraphLevel(DynC, AParagraphDir);
  Result.ParagraphLevel := Para;
  ResolveCore(DynC, DynP, Length(DynP) = Length(DynC), Para, Result.Levels,
    Result.VisualToLogical);
end;

function ResolveBidi(const AText: string;
  const AParagraphDir: Integer): TBidiResolveResult;
var
  Classes: TBidiClassArray;
  Cps: array of TUnicodeCodepoint;
  Pos, Len, Count: SizeInt;
  Dec: TUTF8DecodeResult;
begin
  Len := Length(AText);
  SetLength(Classes, Len);
  SetLength(Cps, Len);
  Count := 0;
  Pos := 1;
  while Pos <= Len do
  begin
    Dec := UTF8Decode(@AText[Pos], Len - Pos + 1);
    if Dec.ByteLen = 0 then
    begin
      Classes[Count] := bcL;
      Cps[Count] := $FFFD;
      Inc(Count);
      Inc(Pos);
    end
    else
    begin
      Classes[Count] := GetBidiClass(Dec.CodePoint);
      Cps[Count] := Dec.CodePoint;
      Inc(Count);
      Inc(Pos, Dec.ByteLen);
    end;
  end;
  SetLength(Classes, Count);
  SetLength(Cps, Count);
  Result := ResolveBidiClassesWithBrackets(Classes, Cps, AParagraphDir);
end;

end.
