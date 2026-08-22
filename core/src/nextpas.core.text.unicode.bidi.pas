unit nextpas.core.text.unicode.bidi;

{**
 * UAX #9 Unicode Bidirectional Algorithm (Unicode 16.0), through L2.
 * Structure aligned with golang.org/x/text/unicode/bidi (BSD license).
 * L3/L4 out of scope per UCD BidiCharacterTest notes.
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

{ UAX#9 L2 visual reorder from resolved levels only (codepoint indices).
  Skips BIDI_LEVEL_REMOVED. VisualToLogical[i] = logical index of visual position i. }
function ReorderBidiVisually(const ALevels: array of TBidiLevel): TBidiIndexArray;

{ Inverse of VisualToLogical. LogicalToVisual[log] = visual index, or -1 if removed. }
function InvertBidiIndexMap(const AVisualToLogical: array of SizeInt;
  const ALogicalCount: SizeInt): TBidiIndexArray;

{ Resolve + reorder UTF-8 by codepoint visual order (TUI display string). }
function ApplyBidiVisualOrder(const AText: string;
  const AParagraphDir: Integer = 2): string;

implementation

uses
  nextpas.core.text.unicode.props,
  nextpas.core.text.unicode.normalize,
  nextpas.core.text.utf8;

const
  MAX_PAIR_DEPTH = 63;

type
  TStackEntry = record
    Level: Byte;
    OverrideCls: TBidiClass;
    Isolate: Boolean;
  end;

  TRunSeq = record
    Indexes: array of Integer;
    Types: array of TBidiClass;
    Levels: array of Byte;
    Level: Byte;
    Sos, Eos: TBidiClass;
  end;

function IsIsolateInit(const C: TBidiClass): Boolean; inline;
begin
  Result := C in [bcLRI, bcRLI, bcFSI];
end;

function IsRemovedX9(const C: TBidiClass): Boolean; inline;
begin
  Result := C in [bcRLE, bcLRE, bcRLO, bcLRO, bcPDF, bcBN];
end;

function IsWhitespaceLike(const C: TBidiClass): Boolean; inline;
begin
  Result := C in [bcWS, bcFSI, bcLRI, bcRLI, bcPDI, bcLRE, bcRLE, bcLRO, bcRLO, bcPDF, bcBN];
end;

function TypeForLevel(const L: Integer): TBidiClass; inline;
begin
  if (L and 1) <> 0 then
    Result := bcR
  else
    Result := bcL;
end;

function MaxI(const A, B: Integer): Integer; inline;
begin
  if A > B then Result := A else Result := B;
end;

function ResolveParagraphLevel(const ATypes: array of TBidiClass;
  const AStart, AEnd: Integer): Byte;
var
  I, Depth: Integer;
  C: TBidiClass;
begin
  Depth := 0;
  for I := AStart to AEnd - 1 do
  begin
    C := ATypes[I];
    if IsIsolateInit(C) then
      Inc(Depth)
    else if C = bcPDI then
    begin
      if Depth > 0 then Dec(Depth);
    end
    else if Depth = 0 then
    begin
      if C = bcL then Exit(0);
      if C in [bcR, bcAL] then Exit(1);
    end;
  end;
  Result := 0;
end;

procedure RunParagraph(const AInitial: array of TBidiClass;
  const APairTypes: array of Byte; { 0 none 1 open 2 close }
  const APairValues: array of TUnicodeCodepoint;
  const AHasPairs: Boolean;
  const AParaDir: Integer;
  out AParaLevel: Byte;
  out AResultLevels: TBidiLevelArray;
  out AVisual: TBidiIndexArray);
var
  N, I, J, K, Depth, StackTop: Integer;
  OverflowIsolate, OverflowEmbedding, ValidIsolate: Integer;
  ResultTypes: TBidiClassArray;
  ResultLevels: array of Integer; { -1 = will become x for X9, or working level }
  MatchingPDI, MatchingInit: array of Integer;
  Stack: array[0..BIDI_MAX_DEPTH + 2] of TStackEntry;
  NewLevel: Integer;
  C: TBidiClass;
  IsIsolate, IsRTL: Boolean;
  LevelRuns: array of array of Integer;
  RunCount, RunLen: Integer;
  RunForChar: array of Integer;
  CurrentRun: array of Integer;
  CurLen: Integer;
  Sequences: array of TRunSeq;
  SeqCount: Integer;
  Seq: TRunSeq;
  PrevLevel, SuccLevel, Level: Integer;
  First, Last, RunIdx: Integer;
  MaxLevel, Lev, VisCount, Tmp, Start, Limit: Integer;
  Openers: array of Integer;
  OpenerCount: Integer;
  Pairs: array of record Opener, Closer: Integer; end;
  PairCount: Integer;
  DirEmbed, DirOpposite, Dir, Lead, Trail: TBidiClass;
  PairVal: TUnicodeCodepoint;

  procedure PushStack(const ALevel: Byte; const AOverride: TBidiClass; const AIso: Boolean);
  begin
    Inc(StackTop);
    Stack[StackTop].Level := ALevel;
    Stack[StackTop].OverrideCls := AOverride;
    Stack[StackTop].Isolate := AIso;
  end;

  procedure PopStack;
  begin
    if StackTop > 0 then
      Dec(StackTop);
  end;

begin
  N := Length(AInitial);
  SetLength(ResultTypes, N);
  SetLength(ResultLevels, N);
  SetLength(MatchingPDI, N);
  SetLength(MatchingInit, N);
  SetLength(AResultLevels, N);
  SetLength(AVisual, 0);

  for I := 0 to N - 1 do
  begin
    ResultTypes[I] := AInitial[I];
    ResultLevels[I] := 0;
    MatchingPDI[I] := -1;
    MatchingInit[I] := -1;
  end;

  if N = 0 then
  begin
    AParaLevel := 0;
    Exit;
  end;

  { BD9 matching isolates }
  for I := 0 to N - 1 do
  begin
    if not IsIsolateInit(ResultTypes[I]) then
      Continue;
    Depth := 1;
    MatchingPDI[I] := N;
    for J := I + 1 to N - 1 do
    begin
      if IsIsolateInit(ResultTypes[J]) then
        Inc(Depth)
      else if ResultTypes[J] = bcPDI then
      begin
        Dec(Depth);
        if Depth = 0 then
        begin
          MatchingPDI[I] := J;
          MatchingInit[J] := I;
          Break;
        end;
      end;
    end;
  end;

  { P2/P3 or forced }
  if AParaDir = 0 then
    AParaLevel := 0
  else if AParaDir = 1 then
    AParaLevel := 1
  else
    AParaLevel := ResolveParagraphLevel(ResultTypes, 0, N);

  for I := 0 to N - 1 do
    ResultLevels[I] := AParaLevel;

  { X1–X8 }
  StackTop := 0;
  Stack[0].Level := AParaLevel;
  Stack[0].OverrideCls := bcON;
  Stack[0].Isolate := False;
  OverflowIsolate := 0;
  OverflowEmbedding := 0;
  ValidIsolate := 0;

  for I := 0 to N - 1 do
  begin
    C := ResultTypes[I];
    case C of
      bcRLE, bcLRE, bcRLO, bcLRO, bcRLI, bcLRI, bcFSI:
        begin
          IsIsolate := IsIsolateInit(C);
          IsRTL := C in [bcRLE, bcRLO, bcRLI];
          if C = bcFSI then
            IsRTL := ResolveParagraphLevel(ResultTypes, I + 1, MatchingPDI[I]) = 1;

          if IsIsolate then
          begin
            ResultLevels[I] := Stack[StackTop].Level;
            if Stack[StackTop].OverrideCls <> bcON then
              ResultTypes[I] := Stack[StackTop].OverrideCls;
          end;

          if IsRTL then
            NewLevel := (Stack[StackTop].Level + 1) or 1
          else
            NewLevel := (Stack[StackTop].Level + 2) and not 1;

          if (NewLevel <= BIDI_MAX_DEPTH) and (OverflowIsolate = 0) and
             (OverflowEmbedding = 0) then
          begin
            if IsIsolate then
              Inc(ValidIsolate);
            case C of
              bcLRO: PushStack(Byte(NewLevel), bcL, IsIsolate);
              bcRLO: PushStack(Byte(NewLevel), bcR, IsIsolate);
            else
              PushStack(Byte(NewLevel), bcON, IsIsolate);
            end;
            if not IsIsolate then
              ResultLevels[I] := NewLevel;
          end
          else if IsIsolate then
            Inc(OverflowIsolate)
          else if OverflowIsolate = 0 then
            Inc(OverflowEmbedding);
        end;
      bcPDI:
        begin
          if OverflowIsolate > 0 then
            Dec(OverflowIsolate)
          else if ValidIsolate > 0 then
          begin
            OverflowEmbedding := 0;
            while not Stack[StackTop].Isolate do
              PopStack;
            PopStack;
            Dec(ValidIsolate);
          end;
          ResultLevels[I] := Stack[StackTop].Level;
          if Stack[StackTop].OverrideCls <> bcON then
            ResultTypes[I] := Stack[StackTop].OverrideCls;
        end;
      bcPDF:
        begin
          ResultLevels[I] := Stack[StackTop].Level;
          if OverflowIsolate = 0 then
          begin
            if OverflowEmbedding > 0 then
              Dec(OverflowEmbedding)
            else if (not Stack[StackTop].Isolate) and (StackTop >= 1) then
              PopStack;
          end;
        end;
      bcB:
        begin
          StackTop := 0;
          Stack[0].Level := AParaLevel;
          Stack[0].OverrideCls := bcON;
          Stack[0].Isolate := False;
          OverflowIsolate := 0;
          OverflowEmbedding := 0;
          ValidIsolate := 0;
          ResultLevels[I] := AParaLevel;
        end;
    else
      begin
        ResultLevels[I] := Stack[StackTop].Level;
        if Stack[StackTop].OverrideCls <> bcON then
          ResultTypes[I] := Stack[StackTop].OverrideCls;
      end;
    end;
  end;

  { Level runs excluding X9-removed (initial types) }
  SetLength(LevelRuns, N);
  RunCount := 0;
  RunLen := 0;
  Level := -1;
  for I := 0 to N - 1 do
  begin
    if IsRemovedX9(AInitial[I]) then
      Continue;
    if ResultLevels[I] <> Level then
    begin
      if Level >= 0 then
      begin
        SetLength(LevelRuns[RunCount], RunLen);
        Inc(RunCount);
      end;
      Level := ResultLevels[I];
      RunLen := 0;
      SetLength(LevelRuns[RunCount], N);
    end;
    LevelRuns[RunCount][RunLen] := I;
    Inc(RunLen);
  end;
  if RunLen > 0 then
  begin
    SetLength(LevelRuns[RunCount], RunLen);
    Inc(RunCount);
  end;
  SetLength(LevelRuns, RunCount);

  SetLength(RunForChar, N);
  for I := 0 to RunCount - 1 do
    for J := 0 to High(LevelRuns[I]) do
      RunForChar[LevelRuns[I][J]] := I;

  { Isolating run sequences BD13 }
  SetLength(Sequences, RunCount);
  SeqCount := 0;
  for I := 0 to RunCount - 1 do
  begin
    First := LevelRuns[I][0];
    if (AInitial[First] = bcPDI) and (MatchingInit[First] <> -1) then
      Continue;

    SetLength(CurrentRun, N);
    CurLen := 0;
    RunIdx := I;
    while True do
    begin
      for J := 0 to High(LevelRuns[RunIdx]) do
      begin
        CurrentRun[CurLen] := LevelRuns[RunIdx][J];
        Inc(CurLen);
      end;
      Last := CurrentRun[CurLen - 1];
      if IsIsolateInit(AInitial[Last]) and (MatchingPDI[Last] < N) then
        RunIdx := RunForChar[MatchingPDI[Last]]
      else
        Break;
    end;

    SetLength(Seq.Indexes, CurLen);
    SetLength(Seq.Types, CurLen);
    for J := 0 to CurLen - 1 do
    begin
      Seq.Indexes[J] := CurrentRun[J];
      Seq.Types[J] := ResultTypes[CurrentRun[J]];
    end;
    Level := ResultLevels[Seq.Indexes[0]];
    Seq.Level := Byte(Level);

    PrevLevel := AParaLevel;
    for J := Seq.Indexes[0] - 1 downto 0 do
      if not IsRemovedX9(AInitial[J]) then
      begin
        PrevLevel := ResultLevels[J];
        Break;
      end;
    SuccLevel := AParaLevel;
    for J := Seq.Indexes[CurLen - 1] + 1 to N - 1 do
      if not IsRemovedX9(AInitial[J]) then
      begin
        SuccLevel := ResultLevels[J];
        Break;
      end;
    { if sequence ends with isolate initiator, eos is para embedding for the isolate? }
    if IsIsolateInit(AInitial[Seq.Indexes[CurLen - 1]]) then
      SuccLevel := Level;

    Seq.Sos := TypeForLevel(MaxI(PrevLevel, Level));
    Seq.Eos := TypeForLevel(MaxI(SuccLevel, Level));
    Sequences[SeqCount] := Seq;
    Inc(SeqCount);
  end;
  SetLength(Sequences, SeqCount);

  { Process each isolating run }
  for I := 0 to SeqCount - 1 do
  begin
    Seq := Sequences[I];
    { W1 NSM }
    C := Seq.Sos;
    for J := 0 to High(Seq.Types) do
      if Seq.Types[J] = bcNSM then
        Seq.Types[J] := C
      else
        C := Seq.Types[J];

    { W2 }
    for J := 0 to High(Seq.Types) do
      if Seq.Types[J] = bcEN then
        for K := J - 1 downto 0 do
          if Seq.Types[K] in [bcL, bcR, bcAL] then
          begin
            if Seq.Types[K] = bcAL then
              Seq.Types[J] := bcAN;
            Break;
          end;

    { W3 }
    for J := 0 to High(Seq.Types) do
      if Seq.Types[J] = bcAL then
        Seq.Types[J] := bcR;

    { W4 }
    for J := 1 to High(Seq.Types) - 1 do
      if Seq.Types[J] in [bcES, bcCS] then
      begin
        if (Seq.Types[J - 1] = bcEN) and (Seq.Types[J + 1] = bcEN) then
          Seq.Types[J] := bcEN
        else if (Seq.Types[J] = bcCS) and (Seq.Types[J - 1] = bcAN) and
                (Seq.Types[J + 1] = bcAN) then
          Seq.Types[J] := bcAN;
      end;

    { W5 }
    J := 0;
    while J <= High(Seq.Types) do
    begin
      if Seq.Types[J] <> bcET then
      begin
        Inc(J);
        Continue;
      end;
      Start := J;
      while (J <= High(Seq.Types)) and (Seq.Types[J] = bcET) do
        Inc(J);
      Limit := J;
      C := Seq.Sos;
      if Start > 0 then
        C := Seq.Types[Start - 1];
      if C <> bcEN then
      begin
        C := Seq.Eos;
        if Limit <= High(Seq.Types) then
          C := Seq.Types[Limit];
      end;
      if C = bcEN then
        for K := Start to Limit - 1 do
          Seq.Types[K] := bcEN;
    end;

    { W6 }
    for J := 0 to High(Seq.Types) do
      if Seq.Types[J] in [bcES, bcET, bcCS] then
        Seq.Types[J] := bcON;

    { W7 }
    for J := 0 to High(Seq.Types) do
      if Seq.Types[J] = bcEN then
      begin
        C := Seq.Sos;
        for K := J - 1 downto 0 do
          if Seq.Types[K] in [bcL, bcR] then
          begin
            C := Seq.Types[K];
            Break;
          end;
        if C = bcL then
          Seq.Types[J] := bcL;
      end;

    { N0 brackets }
    if AHasPairs then
    begin
      if (Seq.Level and 1) <> 0 then
        DirEmbed := bcR
      else
        DirEmbed := bcL;
      SetLength(Openers, MAX_PAIR_DEPTH + 1);
      OpenerCount := 0;
      SetLength(Pairs, Length(Seq.Indexes));
      PairCount := 0;
      for J := 0 to High(Seq.Indexes) do
      begin
        if Seq.Types[J] <> bcON then
          Continue;
        case APairTypes[Seq.Indexes[J]] of
          1: { open }
            begin
              if OpenerCount = MAX_PAIR_DEPTH then
              begin
                OpenerCount := 0;
                Break;
              end;
              Openers[OpenerCount] := J;
              Inc(OpenerCount);
            end;
          2: { close }
            begin
              K := OpenerCount - 1;
              while K >= 0 do
              begin
                if APairValues[Seq.Indexes[Openers[K]]] =
                   APairValues[Seq.Indexes[J]] then
                begin
                  Pairs[PairCount].Opener := Openers[K];
                  Pairs[PairCount].Closer := J;
                  Inc(PairCount);
                  OpenerCount := K;
                  Break;
                end;
                Dec(K);
              end;
            end;
        end;
      end;
      { sort pairs by opener }
      for J := 0 to PairCount - 2 do
        for K := J + 1 to PairCount - 1 do
          if Pairs[K].Opener < Pairs[J].Opener then
          begin
            Tmp := Pairs[J].Opener;
            Pairs[J].Opener := Pairs[K].Opener;
            Pairs[K].Opener := Tmp;
            Tmp := Pairs[J].Closer;
            Pairs[J].Closer := Pairs[K].Closer;
            Pairs[K].Closer := Tmp;
          end;

      for J := 0 to PairCount - 1 do
      begin
        DirOpposite := bcON;
        Dir := bcON;
        for K := Pairs[J].Opener + 1 to Pairs[J].Closer - 1 do
        begin
          case Seq.Types[K] of
            bcEN, bcAN, bcAL, bcR: C := bcR;
            bcL: C := bcL;
          else
            C := bcON;
          end;
          if C = bcON then Continue;
          if C = DirEmbed then
          begin
            Dir := DirEmbed;
            Break;
          end;
          DirOpposite := C;
        end;
        if Dir = bcON then
          Dir := DirOpposite;
        if Dir <> bcON then
        begin
          if Dir <> DirEmbed then
          begin
            { check strong before opener }
            C := Seq.Sos;
            for K := Pairs[J].Opener - 1 downto 0 do
            begin
              case Seq.Types[K] of
                bcEN, bcAN, bcAL, bcR:
                  begin
                    C := bcR;
                    Break;
                  end;
                bcL:
                  begin
                    C := bcL;
                    Break;
                  end;
              end;
            end;
            if C <> Dir then
              Dir := DirEmbed;
          end;
          Seq.Types[Pairs[J].Opener] := Dir;
          Seq.Types[Pairs[J].Closer] := Dir;
          { also NSM after brackets that were ON — Go setBracketsToType }
          K := Pairs[J].Opener + 1;
          while (K < Length(Seq.Types)) and (AInitial[Seq.Indexes[K]] = bcNSM) do
          begin
            Seq.Types[K] := Dir;
            Inc(K);
          end;
          K := Pairs[J].Closer + 1;
          while (K < Length(Seq.Types)) and (AInitial[Seq.Indexes[K]] = bcNSM) do
          begin
            Seq.Types[K] := Dir;
            Inc(K);
          end;
        end;
      end;
    end;

    { N1/N2 }
    J := 0;
    while J <= High(Seq.Types) do
    begin
      if not ((Seq.Types[J] in [bcWS, bcON, bcB, bcS]) or IsIsolateInit(Seq.Types[J]) or
              (Seq.Types[J] = bcPDI)) then
      begin
        Inc(J);
        Continue;
      end;
      Start := J;
      while (J <= High(Seq.Types)) and
            ((Seq.Types[J] in [bcWS, bcON, bcB, bcS]) or IsIsolateInit(Seq.Types[J]) or
             (Seq.Types[J] = bcPDI)) do
        Inc(J);
      Limit := J;
      if Start = 0 then
        Lead := Seq.Sos
      else
      begin
        Lead := Seq.Types[Start - 1];
        if Lead in [bcAN, bcEN] then
          Lead := bcR;
      end;
      if Limit > High(Seq.Types) then
        Trail := Seq.Eos
      else
      begin
        Trail := Seq.Types[Limit];
        if Trail in [bcAN, bcEN] then
          Trail := bcR;
      end;
      if Lead = Trail then
        Dir := Lead
      else
        Dir := TypeForLevel(Seq.Level);
      for K := Start to Limit - 1 do
        Seq.Types[K] := Dir;
    end;

    { I1/I2 }
    SetLength(Seq.Levels, Length(Seq.Types));
    for J := 0 to High(Seq.Types) do
      Seq.Levels[J] := Seq.Level;
    if (Seq.Level and 1) = 0 then
    begin
      for J := 0 to High(Seq.Types) do
        if Seq.Types[J] = bcR then
          Seq.Levels[J] := Seq.Level + 1
        else if Seq.Types[J] in [bcAN, bcEN] then
          Seq.Levels[J] := Seq.Level + 2;
    end
    else
    begin
      for J := 0 to High(Seq.Types) do
        if Seq.Types[J] <> bcR then
          Seq.Levels[J] := Seq.Level + 1;
    end;

    { apply back }
    for J := 0 to High(Seq.Indexes) do
    begin
      ResultTypes[Seq.Indexes[J]] := Seq.Types[J];
      ResultLevels[Seq.Indexes[J]] := Seq.Levels[J];
    end;
  end;

  { Output levels: X9 → REMOVED; else working level }
  for I := 0 to N - 1 do
    if IsRemovedX9(AInitial[I]) then
      AResultLevels[I] := BIDI_LEVEL_REMOVED
    else
      AResultLevels[I] := Byte(ResultLevels[I]);

  { L1 using initial types }
  for I := 0 to N - 1 do
  begin
    if AResultLevels[I] = BIDI_LEVEL_REMOVED then
      Continue;
    if AInitial[I] in [bcB, bcS] then
    begin
      AResultLevels[I] := AParaLevel;
      J := I - 1;
      while J >= 0 do
      begin
        if IsWhitespaceLike(AInitial[J]) or IsRemovedX9(AInitial[J]) then
        begin
          if not IsRemovedX9(AInitial[J]) then
            AResultLevels[J] := AParaLevel;
          { X9 removed stay x in UCD tests — do not rewrite }
        end
        else
          Break;
        Dec(J);
      end;
    end;
  end;
  { trailing WS on single line }
  J := N - 1;
  while J >= 0 do
  begin
    if IsRemovedX9(AInitial[J]) then
    begin
      Dec(J);
      Continue;
    end;
    if IsWhitespaceLike(AInitial[J]) or (AInitial[J] in [bcB, bcS]) then
      AResultLevels[J] := AParaLevel
    else
      Break;
    Dec(J);
  end;

  { L2 reorder: skip removed }
  MaxLevel := 0;
  for I := 0 to N - 1 do
    if (AResultLevels[I] <> BIDI_LEVEL_REMOVED) and (AResultLevels[I] > MaxLevel) then
      MaxLevel := AResultLevels[I];
  SetLength(AVisual, N);
  VisCount := 0;
  for I := 0 to N - 1 do
    if AResultLevels[I] <> BIDI_LEVEL_REMOVED then
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
      if AResultLevels[AVisual[I]] < Lev then
      begin
        Inc(I);
        Continue;
      end;
      Start := I;
      while (I < VisCount) and (AResultLevels[AVisual[I]] >= Lev) do
        Inc(I);
      J := Start;
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

function CanonicalOpenId(const ACp: TUnicodeCodepoint): TUnicodeCodepoint;
{ Opening-bracket identity after canonical decomposition (UAX#9 N0). }
var
  Dst: array[0..31] of TUnicodeCodepoint;
  Len: Byte;
  Compat: Boolean;
begin
  Result := ACp;
  if GetDecompositionMapping(ACp, Dst, Len, Compat) and (Len >= 1) and (not Compat) then
    Result := Dst[0];
end;

procedure FillPairArrays(const ACodepoints: array of TUnicodeCodepoint;
  var APairTypes: array of Byte; var APairValues: array of TUnicodeCodepoint);
var
  I: Integer;
  T: TBidiPairedBracketType;
  OpenId: TUnicodeCodepoint;
begin
  for I := 0 to High(ACodepoints) do
  begin
    T := GetBidiPairedBracketType(ACodepoints[I]);
    case T of
      bpbtOpen:
        begin
          APairTypes[I] := 1;
          APairValues[I] := CanonicalOpenId(ACodepoints[I]);
        end;
      bpbtClose:
        begin
          APairTypes[I] := 2;
          { pair id = canonical form of the matching opener }
          OpenId := GetBidiPairedBracket(ACodepoints[I]);
          APairValues[I] := CanonicalOpenId(OpenId);
        end;
    else
      begin
        APairTypes[I] := 0;
        APairValues[I] := 0;
      end;
    end;
  end;
end;

function ResolveBidiClasses(const AClasses: array of TBidiClass;
  const AParagraphDir: Integer): TBidiResolveResult;
var
  DummyPT: array of Byte;
  DummyPV: array of TUnicodeCodepoint;
  Dyn: TBidiClassArray;
  I: Integer;
begin
  SetLength(Dyn, Length(AClasses));
  for I := 0 to High(AClasses) do
    Dyn[I] := AClasses[I];
  SetLength(DummyPT, Length(Dyn));
  SetLength(DummyPV, Length(Dyn));
  for I := 0 to High(DummyPT) do
  begin
    DummyPT[I] := 0;
    DummyPV[I] := 0;
  end;
  RunParagraph(Dyn, DummyPT, DummyPV, False, AParagraphDir,
    Result.ParagraphLevel, Result.Levels, Result.VisualToLogical);
end;

function ResolveBidiClassesWithBrackets(const AClasses: array of TBidiClass;
  const ACodepoints: array of TUnicodeCodepoint;
  const AParagraphDir: Integer): TBidiResolveResult;
var
  Dyn: TBidiClassArray;
  PT: array of Byte;
  PV: array of TUnicodeCodepoint;
  I: Integer;
  HasP: Boolean;
begin
  SetLength(Dyn, Length(AClasses));
  for I := 0 to High(AClasses) do
    Dyn[I] := AClasses[I];
  SetLength(PT, Length(AClasses));
  SetLength(PV, Length(AClasses));
  HasP := Length(ACodepoints) = Length(AClasses);
  if HasP then
    FillPairArrays(ACodepoints, PT, PV)
  else
    for I := 0 to High(PT) do
    begin
      PT[I] := 0;
      PV[I] := 0;
    end;
  RunParagraph(Dyn, PT, PV, HasP, AParagraphDir,
    Result.ParagraphLevel, Result.Levels, Result.VisualToLogical);
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


function ReorderBidiVisually(const ALevels: array of TBidiLevel): TBidiIndexArray;
var
  N, I, J, K, Start, VisCount, MaxLevel, Lev: SizeInt;
  Tmp: SizeInt;
begin
  N := Length(ALevels);
  if N = 0 then
  begin
    Result := nil;
    SetLength(Result, 0);
    Exit;
  end;
  MaxLevel := 0;
  for I := 0 to N - 1 do
    if (ALevels[I] <> BIDI_LEVEL_REMOVED) and (ALevels[I] > MaxLevel) then
      MaxLevel := ALevels[I];
  SetLength(Result, N);
  VisCount := 0;
  for I := 0 to N - 1 do
    if ALevels[I] <> BIDI_LEVEL_REMOVED then
    begin
      Result[VisCount] := I;
      Inc(VisCount);
    end;
  SetLength(Result, VisCount);
  Lev := MaxLevel;
  while Lev > 0 do
  begin
    I := 0;
    while I < VisCount do
    begin
      if ALevels[Result[I]] < Lev then
      begin
        Inc(I);
        Continue;
      end;
      Start := I;
      while (I < VisCount) and (ALevels[Result[I]] >= Lev) do
        Inc(I);
      J := Start;
      K := I - 1;
      while J < K do
      begin
        Tmp := Result[J];
        Result[J] := Result[K];
        Result[K] := Tmp;
        Inc(J);
        Dec(K);
      end;
    end;
    Dec(Lev);
  end;
end;

function InvertBidiIndexMap(const AVisualToLogical: array of SizeInt;
  const ALogicalCount: SizeInt): TBidiIndexArray;
var
  I, L: SizeInt;
begin
  Result := nil;
  SetLength(Result, ALogicalCount);
  for I := 0 to ALogicalCount - 1 do
    Result[I] := -1;
  for I := 0 to High(AVisualToLogical) do
  begin
    L := AVisualToLogical[I];
    if (L >= 0) and (L < ALogicalCount) then
      Result[L] := I;
  end;
end;

function ApplyBidiVisualOrder(const AText: string;
  const AParagraphDir: Integer): string;
var
  LRes: TBidiResolveResult;
  LCps: array of TUnicodeCodepoint;
  LCount, I, LUsed, LVis: SizeInt;
  LIter: TUTF8Iterator;
  LCp: UInt32;
  LBuf: array[0..3] of Byte;
  LLen: Byte;
  J: Integer;
begin
  if AText = '' then
    Exit('');
  LRes := ResolveBidi(AText, AParagraphDir);
  LCount := 0;
  SetLength(LCps, Length(AText) + 4);
  LIter.Init(PByte(PAnsiChar(AText)), SizeUInt(Length(AText)));
  while LIter.Next(LCp) do
  begin
    if LCount >= Length(LCps) then
      SetLength(LCps, Length(LCps) * 2);
    LCps[LCount] := LCp;
    Inc(LCount);
  end;
  if LCount = 0 then
    Exit('');
  SetLength(Result, LCount * 4 + 8);
  LUsed := 0;
  for I := 0 to High(LRes.VisualToLogical) do
  begin
    LVis := LRes.VisualToLogical[I];
    if (LVis < 0) or (LVis >= LCount) then
      Continue;
    LLen := UTF8Encode(LCps[LVis], @LBuf[0]);
    if LLen = 0 then
      Continue;
    if LUsed + LLen > Length(Result) then
      SetLength(Result, (LUsed + LLen) * 2 + 8);
    for J := 0 to Integer(LLen) - 1 do
      Result[LUsed + J + 1] := Chr(LBuf[J]);
    Inc(LUsed, LLen);
  end;
  SetLength(Result, LUsed);
end;


end.
