unit nextpas.core.text.unicode.collate;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.unicode.types;

type
  TCollationStrength = (
    csPrimary,
    csSecondary,
    csTertiary,
    csQuaternary,
    csIdentical
  );

  TCollationVariableWeighting = (
    cvwNonIgnorable,
    cvwShifted
  );

  TCollationOptions = record
    Strength: TCollationStrength;
    CaseLevel: Boolean;
    FrenchAccents: Boolean;
    NumericOrdering: Boolean;
    VariableWeighting: TCollationVariableWeighting;
  end;

  TCollationKey = array of Byte;

  IUnicodeCollator = interface
    ['{C3D4E5F6-A7B8-9012-CDEF-123456789012}']
    function Compare(const A, B: string): Integer;
    function GetSortKey(const AText: string): TCollationKey;
    function TextEquals(const A, B: string): Boolean;
    function StartsWith(const AText, APrefix: string): Boolean;
    function EndsWith(const AText, ASuffix: string): Boolean;
    function IndexOf(const AText, ASubstring: string): SizeInt;
    function Contains(const AText, ASubstring: string): Boolean;
  end;

type
  TCollationElement = record
    Primary: UInt16;
    Secondary: UInt16;
    Tertiary: UInt16;
    Quaternary: UInt16;
    Variable: Boolean;
    Codepoint: TUnicodeCodepoint;
    IsDigit: Boolean;
    DigitValue: UInt32;
  end;

  TCollationElementArray = array of TCollationElement;
  TCodepointArray = array of TUnicodeCodepoint;

  TUnicodeCollator = class(TInterfacedObject, IUnicodeCollator)
  private
    FOptions: TCollationOptions;
    { Scratch buffers reused across Compare/GetSortKey (instance-local). }
    FElsA: TCollationElementArray;
    FElsB: TCollationElementArray;
    FCpsBuf: TCodepointArray;
    function CollectElements(const ANormalized: string): TCollationElementArray;
    function CollectElementsInto(const ANormalized: string;
      var AElements: TCollationElementArray): SizeInt;
    function ElementsToSortKey(const AElements: TCollationElementArray;
      const ACount: SizeInt): TCollationKey; overload;
    function ElementsToSortKey(const AElements: TCollationElementArray): TCollationKey; overload;
    function CompareElements(const A: TCollationElementArray; const ACount: SizeInt;
      const B: TCollationElementArray; const BCount: SizeInt): Integer; overload;
    function CompareElements(const A, B: TCollationElementArray): Integer; overload;
  public
    constructor Create(const AOptions: TCollationOptions);
    function Compare(const A, B: string): Integer;
    function GetSortKey(const AText: string): TCollationKey;
    function TextEquals(const A, B: string): Boolean;
    function StartsWith(const AText, APrefix: string): Boolean;
    function EndsWith(const AText, ASuffix: string): Boolean;
    function IndexOf(const AText, ASubstring: string): SizeInt;
    function Contains(const AText, ASubstring: string): Boolean;
  end;

function DefaultCollationOptions: TCollationOptions;
function UCACollationOptions(const AVariable: TCollationVariableWeighting): TCollationOptions;
function UnicodeCollator: IUnicodeCollator;
function UnicodeCollatorWithOptions(const AOptions: TCollationOptions): IUnicodeCollator;
function GetCollationWeight(const ACp: TUnicodeCodepoint): UInt32;
function UnpackPrimary(const AWeight: UInt32): UInt16;
function UnpackSecondary(const AWeight: UInt32): Byte;
function UnpackTertiary(const AWeight: UInt32): Byte;

implementation

uses
  nextpas.core.text.unicode.normalize,
  nextpas.core.text.unicode.base,
  nextpas.core.text.unicode.props,
  nextpas.core.text.unicode.utils,
  nextpas.core.text.utf8,
  nextpas.core.sync;

{$I nextpas.core.text.unicode.collate.inc}

type
  TAsciiCollationCE = record
    Primary: UInt16;
    Secondary: UInt16;
    Tertiary: UInt16;
    Variable: Boolean;
    Len: Byte; { 0 = implicit fallback; 1 = single CE from pool; >1 rare multi }
    Offset: UInt32;
  end;

var
  GAsciiCE: array[0..127] of TAsciiCollationCE;
  GAsciiCEReady: Boolean;

const
  IMPLICIT_BASE_CORE_HAN = $FB40;
  IMPLICIT_BASE_OTHER_HAN = $FB80;
  IMPLICIT_BASE_UNASSIGNED = $FBC0;

function BytesEqual(const A: PByte; const B: PByte; const ALen: SizeInt): Boolean;
var
  I: SizeInt;
begin
  for I := 0 to ALen - 1 do
    if A[I] <> B[I] then
      Exit(False);
  Result := True;
end;

function GetCaseLevel(const ACp: TUnicodeCodepoint): Byte;
var
  LIsUpper, LIsLower: Boolean;
begin
  LIsUpper := IsUpper(ACp);
  LIsLower := IsLower(ACp);
  if LIsUpper and LIsLower then
    Result := 9
  else if LIsUpper then
    Result := 8
  else
    Result := 0;
end;

function UnpackCE(const APacked: UInt64; out APrimary, ASecondary, ATertiary: UInt16;
  out AVariable: Boolean): Boolean;
begin
  APrimary := UInt16(APacked and $FFFF);
  ASecondary := UInt16((APacked shr 16) and $FFFF);
  ATertiary := UInt16((APacked shr 32) and $FFFF);
  AVariable := ((APacked shr 48) and 1) <> 0;
  Result := (APrimary <> 0) or (ASecondary <> 0) or (ATertiary <> 0) or AVariable;
end;

function IsCoreHan(const ACp: TUnicodeCodepoint): Boolean; inline;
begin
  Result := ((ACp >= $4E00) and (ACp <= $9FFF)) or
            ((ACp >= $F900) and (ACp <= $FAFF));
end;

function IsOtherHan(const ACp: TUnicodeCodepoint): Boolean;
begin
  Result :=
    ((ACp >= $3400) and (ACp <= $4DBF)) or
    ((ACp >= $20000) and (ACp <= $2A6DF)) or
    ((ACp >= $2A700) and (ACp <= $2B739)) or
    ((ACp >= $2B740) and (ACp <= $2B81D)) or
    ((ACp >= $2B820) and (ACp <= $2CEA1)) or
    ((ACp >= $2CEB0) and (ACp <= $2EBE0)) or
    ((ACp >= $2EBF0) and (ACp <= $2EE5D)) or
    ((ACp >= $30000) and (ACp <= $3134A)) or
    ((ACp >= $31350) and (ACp <= $323AF));
end;

function ImplicitBase(const ACp: TUnicodeCodepoint): UInt16;
var
  I: Integer;
begin
  if IsCoreHan(ACp) then
    Exit(IMPLICIT_BASE_CORE_HAN);
  if IsOtherHan(ACp) then
    Exit(IMPLICIT_BASE_OTHER_HAN);
  for I := 0 to COLLATE_IMPLICIT_RANGE_COUNT - 1 do
  begin
    if (ACp >= COLLATE_IMP_LO[I]) and (ACp <= COLLATE_IMP_HI[I]) then
      Exit(UInt16(COLLATE_IMP_BASE[I]));
  end;
  Result := IMPLICIT_BASE_UNASSIGNED;
end;

function FindSmpIndex(const ACp: TUnicodeCodepoint): Integer;
var
  Lo, Hi, Mid: Integer;
begin
  Lo := 0;
  Hi := COLLATE_SMP_COUNT - 1;
  while Lo <= Hi do
  begin
    Mid := Lo + (Hi - Lo) div 2;
    if COLLATE_SMP_CP[Mid] < ACp then
      Lo := Mid + 1
    else if COLLATE_SMP_CP[Mid] > ACp then
      Hi := Mid - 1
    else
      Exit(Mid);
  end;
  Result := -1;
end;

function LookupExplicit(const ACp: TUnicodeCodepoint; out AOffset: UInt32; out ALen: Byte): Boolean;
var
  LIdx: UInt32;
  LSmp: Integer;
begin
  if ACp <= $FFFF then
  begin
    LIdx := COLLATE_BMP_INDEX[Byte(ACp shr 8), Byte(ACp and $FF)];
    if LIdx = 0 then
      Exit(False);
    AOffset := LIdx shr 8;
    ALen := Byte(LIdx and $FF);
    Exit(True);
  end;
  LSmp := FindSmpIndex(ACp);
  if LSmp < 0 then
    Exit(False);
  AOffset := COLLATE_SMP_OFF[LSmp];
  ALen := Byte(COLLATE_SMP_LEN[LSmp] and $FF);
  Result := ALen > 0;
end;

function FindContractionFirst(const AFirst: TUnicodeCodepoint): Integer;
var
  Lo, Hi, Mid: Integer;
begin
  Lo := 0;
  Hi := COLLATE_CONTRACTION_COUNT - 1;
  Result := -1;
  while Lo <= Hi do
  begin
    Mid := Lo + (Hi - Lo) div 2;
    if COLLATE_CTR_FIRST[Mid] < AFirst then
      Lo := Mid + 1
    else if COLLATE_CTR_FIRST[Mid] > AFirst then
      Hi := Mid - 1
    else
    begin
      while (Mid > 0) and (COLLATE_CTR_FIRST[Mid - 1] = AFirst) do
        Dec(Mid);
      Exit(Mid);
    end;
  end;
end;

function MatchContraction(const ACps: array of TUnicodeCodepoint; const APos, ACount: SizeInt;
  out AMatchLen: SizeInt; out AOffset: UInt32; out ALen: Byte;
  out ASkipCps: TCodepointArray; out ASkipCount: SizeInt): Boolean;
{ UTS#10: longest contiguous match, then extend by discontiguous non-starters. }
var
  LStart, LI, LJ, LRestLen: Integer;
  LFirst: TUnicodeCodepoint;
  LRestOff: UInt32;
  LNeed: TUnicodeCodepoint;
  LSearch, LFound, LK: SizeInt;
  LNeedCcc, LCcc: Byte;
  LBlocked: Boolean;
  LConsumed: array of Boolean;
  LLast: SizeInt;
  LCap: SizeInt;
  LOk: Boolean;
  LMatchIdx: Integer;
  LSeq: array of TUnicodeCodepoint;
  LSeqLen: SizeInt;
  LExtended: Boolean;
  LCandIdx: Integer;
  LTryLen: Integer;
  LPrefixOk: Boolean;
begin
  Result := False;
  ASkipCount := 0;
  SetLength(ASkipCps, 0);
  if APos >= ACount then
    Exit;
  LFirst := ACps[APos];
  LStart := FindContractionFirst(LFirst);
  if LStart < 0 then
    Exit;

  // --- Phase 1: longest contiguous multi-cp contraction ---
  LMatchIdx := -1;
  LLast := APos;
  LI := LStart;
  while (LI < COLLATE_CONTRACTION_COUNT) and (COLLATE_CTR_FIRST[LI] = LFirst) do
  begin
    LRestLen := Integer(COLLATE_CTR_REST_LEN[LI]);
    if (LRestLen > 0) and (APos + 1 + LRestLen <= ACount) then
    begin
      LOk := True;
      LRestOff := COLLATE_CTR_REST_OFF[LI];
      for LJ := 0 to LRestLen - 1 do
        if ACps[APos + 1 + LJ] <> COLLATE_CTR_REST[LRestOff + UInt32(LJ)] then
        begin
          LOk := False;
          Break;
        end;
      if LOk then
      begin
        LMatchIdx := LI;
        LLast := APos + LRestLen;
        Break; // longest first
      end;
    end;
    Inc(LI);
  end;

  // Build current sequence S
  SetLength(LSeq, 16);
  LSeq[0] := LFirst;
  LSeqLen := 1;
  if LMatchIdx >= 0 then
  begin
    LRestLen := Integer(COLLATE_CTR_REST_LEN[LMatchIdx]);
    LRestOff := COLLATE_CTR_REST_OFF[LMatchIdx];
    for LJ := 0 to LRestLen - 1 do
    begin
      if LSeqLen >= Length(LSeq) then
        SetLength(LSeq, LSeqLen * 2);
      LSeq[LSeqLen] := COLLATE_CTR_REST[LRestOff + UInt32(LJ)];
      Inc(LSeqLen);
    end;
  end;

  // Consumed mask for contiguous part
  SetLength(LConsumed, ACount);
  for LK := 0 to ACount - 1 do
    LConsumed[LK] := False;
  LConsumed[APos] := True;
  if LMatchIdx >= 0 then
    for LJ := 1 to LSeqLen - 1 do
      LConsumed[APos + LJ] := True;

  // --- Phase 2: extend S by discontiguous non-starters ---
  repeat
    LExtended := False;
    LSearch := LLast + 1;
    // find contraction = S + one non-starter C
    LI := LStart;
    while (LI < COLLATE_CONTRACTION_COUNT) and (COLLATE_CTR_FIRST[LI] = LFirst) do
    begin
      LRestLen := Integer(COLLATE_CTR_REST_LEN[LI]);
      LTryLen := LSeqLen - 1; // rest length of current S
      if LRestLen <> LTryLen + 1 then
      begin
        Inc(LI);
        Continue;
      end;
      LRestOff := COLLATE_CTR_REST_OFF[LI];
      // prefix of rest must equal S[1..]
      LPrefixOk := True;
      for LJ := 0 to LTryLen - 1 do
        if COLLATE_CTR_REST[LRestOff + UInt32(LJ)] <> LSeq[LJ + 1] then
        begin
          LPrefixOk := False;
          Break;
        end;
      if not LPrefixOk then
      begin
        Inc(LI);
        Continue;
      end;
      LNeed := COLLATE_CTR_REST[LRestOff + UInt32(LTryLen)];
      LNeedCcc := GetCanonicalCombiningClass(LNeed);
      if LNeedCcc = 0 then
      begin
        Inc(LI);
        Continue; // only non-starters for discontiguous extend
      end;
      // find LNeed at/after LSearch, discontiguous
      LFound := -1;
      LK := LSearch;
      while LK < ACount do
      begin
        if LConsumed[LK] then
        begin
          Inc(LK);
          Continue;
        end;
        LCcc := GetCanonicalCombiningClass(ACps[LK]);
        if ACps[LK] = LNeed then
        begin
          LBlocked := False;
          for LCap := LSearch to LK - 1 do
          begin
            if LConsumed[LCap] then
              Continue;
            LCcc := GetCanonicalCombiningClass(ACps[LCap]);
            if LCcc = 0 then
            begin
              LBlocked := True;
              Break;
            end;
            if LCcc >= LNeedCcc then
            begin
              LBlocked := True;
              Break;
            end;
          end;
          if not LBlocked then
          begin
            LFound := LK;
            Break;
          end;
        end
        else if LCcc = 0 then
          Break;
        Inc(LK);
      end;
      if LFound >= 0 then
      begin
        // extend
        if LSeqLen >= Length(LSeq) then
          SetLength(LSeq, LSeqLen * 2);
        LSeq[LSeqLen] := LNeed;
        Inc(LSeqLen);
        LConsumed[LFound] := True;
        if LFound > LLast then
          LLast := LFound;
        LMatchIdx := LI;
        LExtended := True;
        Break; // restart extension from new S
      end;
      Inc(LI);
    end;
  until not LExtended;

  if (LMatchIdx < 0) or (LSeqLen < 2) then
    Exit(False);

  AMatchLen := LLast - APos + 1;
  AOffset := COLLATE_CTR_CE_OFF[LMatchIdx];
  ALen := Byte(COLLATE_CTR_CE_LEN[LMatchIdx] and $FF);
  ASkipCount := 0;
  SetLength(ASkipCps, AMatchLen);
  for LK := APos + 1 to LLast - 1 do
    if not LConsumed[LK] then
    begin
      ASkipCps[ASkipCount] := ACps[LK];
      Inc(ASkipCount);
    end;
  SetLength(ASkipCps, ASkipCount);
  Result := True;
end;

procedure AppendImplicit(var ADst: TCollationElementArray; var ACount: SizeInt;
  const ACp: TUnicodeCodepoint);
var
  LBase: UInt16;
  LAAAA, LBBBB: UInt16;
  LCap: SizeInt;
begin
  LBase := ImplicitBase(ACp);
  LAAAA := UInt16(LBase + (ACp shr 15));
  LBBBB := UInt16((ACp and $7FFF) or $8000);
  LCap := Length(ADst);
  if ACount + 2 > LCap then
  begin
    if LCap = 0 then LCap := 16 else LCap := LCap * 2;
    while ACount + 2 > LCap do LCap := LCap * 2;
    SetLength(ADst, LCap);
  end;
  ADst[ACount].Primary := LAAAA;
  ADst[ACount].Secondary := $0020;
  ADst[ACount].Tertiary := $0002;
  ADst[ACount].Quaternary := 0;
  ADst[ACount].Variable := False;
  ADst[ACount].Codepoint := ACp;
  ADst[ACount].IsDigit := False;
  ADst[ACount].DigitValue := 0;
  Inc(ACount);
  ADst[ACount].Primary := LBBBB;
  ADst[ACount].Secondary := 0;
  ADst[ACount].Tertiary := 0;
  ADst[ACount].Quaternary := 0;
  ADst[ACount].Variable := False;
  ADst[ACount].Codepoint := ACp;
  ADst[ACount].IsDigit := False;
  ADst[ACount].DigitValue := 0;
  Inc(ACount);
end;

procedure AppendFromPool(var ADst: TCollationElementArray; var ACount: SizeInt;
  const AOffset: UInt32; const ALen: Byte; const ACp: TUnicodeCodepoint);
var
  I: Integer;
  LPacked: UInt64;
  LP, LS, LT: UInt16;
  LV: Boolean;
  LCap: SizeInt;
begin
  for I := 0 to Integer(ALen) - 1 do
  begin
    LPacked := COLLATE_CE_POOL[AOffset + UInt32(I)];
    if not UnpackCE(LPacked, LP, LS, LT, LV) then
      Continue;
    LCap := Length(ADst);
    if ACount >= LCap then
    begin
      if LCap = 0 then LCap := 16 else LCap := LCap * 2;
      SetLength(ADst, LCap);
    end;
    ADst[ACount].Primary := LP;
    ADst[ACount].Secondary := LS;
    ADst[ACount].Tertiary := LT;
    ADst[ACount].Quaternary := 0;
    ADst[ACount].Variable := LV;
    ADst[ACount].Codepoint := ACp;
    ADst[ACount].IsDigit := False;
    ADst[ACount].DigitValue := 0;
    Inc(ACount);
  end;
end;

procedure FillDigitSequences(var AElements: TCollationElementArray; const ACount: SizeInt);
var
  LI, LStart: SizeInt;
  LValue: UInt32;
  LDigit: UInt32;
begin
  LI := 0;
  while LI < ACount do
  begin
    if (AElements[LI].Codepoint >= $30) and (AElements[LI].Codepoint <= $39) then
    begin
      LStart := LI;
      LValue := 0;
      while (LI < ACount) and (AElements[LI].Codepoint >= $30) and (AElements[LI].Codepoint <= $39) do
      begin
        LDigit := AElements[LI].Codepoint - $30;
        if LValue <= (High(UInt32) - LDigit) div 10 then
          LValue := LValue * 10 + LDigit
        else
          LValue := High(UInt32);
        Inc(LI);
      end;
      while LStart < LI do
      begin
        AElements[LStart].IsDigit := True;
        AElements[LStart].DigitValue := LValue;
        Inc(LStart);
      end;
    end
    else
      Inc(LI);
  end;
end;

procedure ApplyVariableWeighting(var AElements: TCollationElementArray; const ACount: SizeInt;
  const AMode: TCollationVariableWeighting);
var
  I: SizeInt;
  LAfterVariable: Boolean;
begin
  if AMode = cvwNonIgnorable then
  begin
    for I := 0 to ACount - 1 do
      AElements[I].Quaternary := 0;
    Exit;
  end;
  // Shifted (UTS#10):
  // - variable CE: primary → quaternary; L1-L3 zero
  // - primary-ignorable CE following a variable: ignore at L1-L3 (and no quat)
  // - regular non-variable with primary≠0: quaternary = high (0xFFFF)
  LAfterVariable := False;
  for I := 0 to ACount - 1 do
  begin
    if AElements[I].Variable and (AElements[I].Primary <> 0) then
    begin
      AElements[I].Quaternary := AElements[I].Primary;
      AElements[I].Primary := 0;
      AElements[I].Secondary := 0;
      AElements[I].Tertiary := 0;
      LAfterVariable := True;
    end
    else if (AElements[I].Primary = 0) and LAfterVariable then
    begin
      AElements[I].Primary := 0;
      AElements[I].Secondary := 0;
      AElements[I].Tertiary := 0;
      AElements[I].Quaternary := 0;
      // stay in after-variable run
    end
    else if AElements[I].Primary <> 0 then
    begin
      LAfterVariable := False;
      if AElements[I].Variable then
      begin
        AElements[I].Quaternary := AElements[I].Primary;
        AElements[I].Primary := 0;
        AElements[I].Secondary := 0;
        AElements[I].Tertiary := 0;
        LAfterVariable := True;
      end
      else
        AElements[I].Quaternary := $FFFF;
    end
    else
    begin
      // primary ignorable not after variable: keep secondary/tertiary
      AElements[I].Quaternary := 0;
      LAfterVariable := False;
    end;
  end;
end;

var
  FUnicodeCollator: IUnicodeCollator;
  FCollatorLock: IMutex;

function DefaultCollationOptions: TCollationOptions;
begin
  Result.Strength := csTertiary;
  Result.CaseLevel := False;
  Result.FrenchAccents := False;
  Result.NumericOrdering := False;
  Result.VariableWeighting := cvwNonIgnorable;
end;

function UCACollationOptions(const AVariable: TCollationVariableWeighting): TCollationOptions;
begin
  Result.Strength := csIdentical;
  Result.CaseLevel := False;
  Result.FrenchAccents := False;
  Result.NumericOrdering := False;
  Result.VariableWeighting := AVariable;
end;

function UnicodeCollator: IUnicodeCollator;
begin
  if FUnicodeCollator = nil then
  begin
    FCollatorLock.Acquire;
    try
      if FUnicodeCollator = nil then
        FUnicodeCollator := TUnicodeCollator.Create(DefaultCollationOptions);
    finally
      FCollatorLock.Release;
    end;
  end;
  Result := FUnicodeCollator;
end;

function UnicodeCollatorWithOptions(const AOptions: TCollationOptions): IUnicodeCollator;
begin
  Result := TUnicodeCollator.Create(AOptions);
end;

function GetCollationWeight(const ACp: TUnicodeCodepoint): UInt32;
var
  LOff: UInt32;
  LLen: Byte;
  I: Integer;
  LP, LS, LT: UInt16;
  LV: Boolean;
  LBase: UInt16;
begin
  if ACp > UNICODE_MAX_CODEPOINT then
    Exit(0);
  if LookupExplicit(ACp, LOff, LLen) then
  begin
    for I := 0 to Integer(LLen) - 1 do
    begin
      if UnpackCE(COLLATE_CE_POOL[LOff + UInt32(I)], LP, LS, LT, LV) then
      begin
        if LP <> 0 then
          Exit((UInt32(LP) shl 16) or (UInt32(LS and $FF) shl 8) or UInt32(LT and $FF));
      end;
    end;
    Exit(0);
  end;
  LBase := ImplicitBase(ACp);
  LP := UInt16(LBase + (ACp shr 15));
  Result := (UInt32(LP) shl 16) or (UInt32($20) shl 8) or $02;
end;

function UnpackPrimary(const AWeight: UInt32): UInt16;
begin
  Result := UInt16(AWeight shr 16);
end;

function UnpackSecondary(const AWeight: UInt32): Byte;
begin
  Result := Byte((AWeight shr 8) and $FF);
end;

function UnpackTertiary(const AWeight: UInt32): Byte;
begin
  Result := Byte(AWeight and $FF);
end;

constructor TUnicodeCollator.Create(const AOptions: TCollationOptions);
begin
  inherited Create;
  FOptions := AOptions;
end;


procedure EnsureAsciiCETable;
var
  B: Integer;
  LOff: UInt32;
  LLen: Byte;
  LP, LS, LT: UInt16;
  LV: Boolean;
begin
  if GAsciiCEReady then Exit;
  for B := 0 to 127 do
  begin
    GAsciiCE[B].Len := 0;
    GAsciiCE[B].Offset := 0;
    GAsciiCE[B].Primary := 0;
    GAsciiCE[B].Secondary := 0;
    GAsciiCE[B].Tertiary := 0;
    GAsciiCE[B].Variable := False;
    if LookupExplicit(UInt32(B), LOff, LLen) then
    begin
      GAsciiCE[B].Len := LLen;
      GAsciiCE[B].Offset := LOff;
      if LLen >= 1 then
      begin
        UnpackCE(COLLATE_CE_POOL[LOff], LP, LS, LT, LV);
        GAsciiCE[B].Primary := LP;
        GAsciiCE[B].Secondary := LS;
        GAsciiCE[B].Tertiary := LT;
        GAsciiCE[B].Variable := LV;
      end;
    end;
  end;
  GAsciiCEReady := True;
end;

function TUnicodeCollator.CollectElementsInto(const ANormalized: string;
  var AElements: TCollationElementArray): SizeInt;
var
  LCpCount: SizeInt;
  LIter: TUTF8Iterator;
  LCp: UInt32;
  LPos, LMatchLen: SizeInt;
  LOff, LOff2: UInt32;
  LLen, LLen2: Byte;
  LCount: SizeInt;
  LSkipCps: TCodepointArray;
  LSkipCount: SizeInt;
  LSkipI: SizeInt;
  LNeed: SizeInt;
  LI: SizeInt;
  LByte: Byte;
begin
  LCount := 0;
  if ANormalized = '' then
    Exit(0);

  { Pure ASCII: no NFD expansion, no UCA contractions on 00..7F alone. }
  if IsAsciiString(ANormalized) then
  begin
    EnsureAsciiCETable;
    LNeed := Length(ANormalized) * 2 + 8;
    if Length(AElements) < LNeed then
      SetLength(AElements, LNeed);
    for LI := 1 to Length(ANormalized) do
    begin
      LByte := Byte(ANormalized[LI]);
      if GAsciiCE[LByte].Len = 1 then
      begin
        if LCount >= Length(AElements) then
          SetLength(AElements, Length(AElements) * 2 + 8);
        AElements[LCount].Primary := GAsciiCE[LByte].Primary;
        AElements[LCount].Secondary := GAsciiCE[LByte].Secondary;
        AElements[LCount].Tertiary := GAsciiCE[LByte].Tertiary;
        AElements[LCount].Quaternary := 0;
        AElements[LCount].Variable := GAsciiCE[LByte].Variable;
        AElements[LCount].Codepoint := LByte;
        AElements[LCount].IsDigit := False;
        AElements[LCount].DigitValue := 0;
        Inc(LCount);
      end
      else if GAsciiCE[LByte].Len > 1 then
        AppendFromPool(AElements, LCount, GAsciiCE[LByte].Offset, GAsciiCE[LByte].Len, LByte)
      else if LookupExplicit(LByte, LOff, LLen) then
        AppendFromPool(AElements, LCount, LOff, LLen, LByte)
      else
        AppendImplicit(AElements, LCount, LByte);
    end;
    ApplyVariableWeighting(AElements, LCount, FOptions.VariableWeighting);
    if FOptions.NumericOrdering then
      FillDigitSequences(AElements, LCount);
    Exit(LCount);
  end;

  LCpCount := 0;
  LNeed := Length(ANormalized) + 4;
  if Length(FCpsBuf) < LNeed then
    SetLength(FCpsBuf, LNeed);
  LIter.Init(PByte(PAnsiChar(ANormalized)), SizeUInt(Length(ANormalized)));
  while LIter.Next(LCp) do
  begin
    if LCpCount >= Length(FCpsBuf) then
      SetLength(FCpsBuf, Length(FCpsBuf) * 2);
    FCpsBuf[LCpCount] := LCp;
    Inc(LCpCount);
  end;

  LNeed := LCpCount * 2 + 8;
  if Length(AElements) < LNeed then
    SetLength(AElements, LNeed);
  LPos := 0;
  while LPos < LCpCount do
  begin
    { Fast reject: most codepoints never start a contraction (binary search once). }
    if (FindContractionFirst(FCpsBuf[LPos]) >= 0) and
       MatchContraction(FCpsBuf, LPos, LCpCount, LMatchLen, LOff, LLen, LSkipCps, LSkipCount) then
    begin
      AppendFromPool(AElements, LCount, LOff, LLen, FCpsBuf[LPos]);
      for LSkipI := 0 to LSkipCount - 1 do
      begin
        if LookupExplicit(LSkipCps[LSkipI], LOff2, LLen2) then
          AppendFromPool(AElements, LCount, LOff2, LLen2, LSkipCps[LSkipI])
        else
          AppendImplicit(AElements, LCount, LSkipCps[LSkipI]);
      end;
      Inc(LPos, LMatchLen);
    end
    else if LookupExplicit(FCpsBuf[LPos], LOff, LLen) then
    begin
      AppendFromPool(AElements, LCount, LOff, LLen, FCpsBuf[LPos]);
      Inc(LPos);
    end
    else
    begin
      AppendImplicit(AElements, LCount, FCpsBuf[LPos]);
      Inc(LPos);
    end;
  end;

  ApplyVariableWeighting(AElements, LCount, FOptions.VariableWeighting);
  if FOptions.NumericOrdering then
    FillDigitSequences(AElements, LCount);
  Result := LCount;
end;

function TUnicodeCollator.CollectElements(const ANormalized: string): TCollationElementArray;
var
  LCount: SizeInt;
begin
  { CollectElementsInto 向 AElements 填充前 LCount 个有效元素（容量可能
    超配）；此前实现先取计数再抹空重设，返回全零数据——真 bug。 }
  Result := nil;
  LCount := CollectElementsInto(ANormalized, Result);
  if Length(Result) <> LCount then
    SetLength(Result, LCount);
end;

procedure AppendU16BE(var AKey: TCollationKey; var APos: SizeInt; const AValue: UInt16);
begin
  if APos + 2 > Length(AKey) then
    SetLength(AKey, Length(AKey) * 2 + 16);
  AKey[APos] := Byte(AValue shr 8);
  AKey[APos + 1] := Byte(AValue and $FF);
  Inc(APos, 2);
end;

function TUnicodeCollator.ElementsToSortKey(const AElements: TCollationElementArray): TCollationKey;
begin
  Result := ElementsToSortKey(AElements, Length(AElements));
end;

function TUnicodeCollator.ElementsToSortKey(const AElements: TCollationElementArray;
  const ACount: SizeInt): TCollationKey;
var
  LKey: TCollationKey;
  LPos: SizeInt;
  I, N: SizeInt;
begin
  N := ACount;
  if N < 0 then N := 0;
  SetLength(LKey, N * 12 + 32);
  LPos := 0;

  for I := 0 to N - 1 do
    if AElements[I].Primary <> 0 then
      AppendU16BE(LKey, LPos, AElements[I].Primary);
  AppendU16BE(LKey, LPos, 0);

  if FOptions.Strength >= csSecondary then
  begin
    if FOptions.FrenchAccents then
    begin
      for I := N - 1 downto 0 do
        if AElements[I].Secondary <> 0 then
          AppendU16BE(LKey, LPos, AElements[I].Secondary);
    end
    else
      for I := 0 to N - 1 do
        if AElements[I].Secondary <> 0 then
          AppendU16BE(LKey, LPos, AElements[I].Secondary);
    AppendU16BE(LKey, LPos, 0);
  end;

  if FOptions.CaseLevel and (FOptions.Strength >= csSecondary) then
  begin
    for I := 0 to N - 1 do
      AppendU16BE(LKey, LPos, GetCaseLevel(AElements[I].Codepoint));
    AppendU16BE(LKey, LPos, 0);
  end;

  if FOptions.Strength >= csTertiary then
  begin
    for I := 0 to N - 1 do
      if AElements[I].Tertiary <> 0 then
        AppendU16BE(LKey, LPos, AElements[I].Tertiary);
    AppendU16BE(LKey, LPos, 0);
  end;

  if FOptions.VariableWeighting = cvwShifted then
  begin
    for I := 0 to N - 1 do
      if AElements[I].Quaternary <> 0 then
        AppendU16BE(LKey, LPos, AElements[I].Quaternary);
    AppendU16BE(LKey, LPos, 0);
  end;

  SetLength(LKey, LPos);
  Result := LKey;
end;

function TUnicodeCollator.CompareElements(const A, B: TCollationElementArray): Integer;
begin
  Result := CompareElements(A, Length(A), B, Length(B));
end;

function TUnicodeCollator.CompareElements(const A: TCollationElementArray; const ACount: SizeInt;
  const B: TCollationElementArray; const BCount: SizeInt): Integer;
var
  IA, IB: SizeInt;
  WA, WB: UInt16;
  NA, NB: SizeInt;
  HA, HB: Boolean;

  function NextPri(const E: TCollationElementArray; const ECount: SizeInt; var Idx: SizeInt; out W: UInt16): Boolean;
  var
    LDig: UInt32;
  begin
    while Idx < ECount do
    begin
      if FOptions.NumericOrdering and E[Idx].IsDigit then
      begin
        LDig := E[Idx].DigitValue;
        W := UInt16(LDig and $FFFF);
        while (Idx < ECount) and E[Idx].IsDigit and (E[Idx].DigitValue = LDig) do
          Inc(Idx);
        Exit(True);
      end;
      if E[Idx].Primary <> 0 then
      begin
        W := E[Idx].Primary;
        Inc(Idx);
        Exit(True);
      end;
      Inc(Idx);
    end;
    W := 0;
    Result := False;
  end;

  function NextSecFwd(const E: TCollationElementArray; const ECount: SizeInt; var Idx: SizeInt; out W: UInt16): Boolean;
  begin
    while Idx < ECount do
    begin
      if E[Idx].Secondary <> 0 then
      begin
        W := E[Idx].Secondary;
        Inc(Idx);
        Exit(True);
      end;
      Inc(Idx);
    end;
    W := 0;
    Result := False;
  end;

  function NextSecRev(const E: TCollationElementArray; const ECount: SizeInt; var Idx: SizeInt; out W: UInt16): Boolean;
  begin
    while Idx >= 0 do
    begin
      if E[Idx].Secondary <> 0 then
      begin
        W := E[Idx].Secondary;
        Dec(Idx);
        Exit(True);
      end;
      Dec(Idx);
    end;
    W := 0;
    Result := False;
  end;

  function NextTer(const E: TCollationElementArray; const ECount: SizeInt; var Idx: SizeInt; out W: UInt16): Boolean;
  begin
    while Idx < ECount do
    begin
      if E[Idx].Tertiary <> 0 then
      begin
        W := E[Idx].Tertiary;
        Inc(Idx);
        Exit(True);
      end;
      Inc(Idx);
    end;
    W := 0;
    Result := False;
  end;

  function NextQuat(const E: TCollationElementArray; const ECount: SizeInt; var Idx: SizeInt; out W: UInt16): Boolean;
  begin
    while Idx < ECount do
    begin
      if E[Idx].Quaternary <> 0 then
      begin
        W := E[Idx].Quaternary;
        Inc(Idx);
        Exit(True);
      end;
      Inc(Idx);
    end;
    W := 0;
    Result := False;
  end;

begin
  NA := ACount;
  NB := BCount;

  IA := 0; IB := 0;
  while True do
  begin
    HA := NextPri(A, NA, IA, WA);
    HB := NextPri(B, NB, IB, WB);
    if not HA and not HB then Break;
    if not HA then Exit(-1);
    if not HB then Exit(1);
    if WA < WB then Exit(-1);
    if WA > WB then Exit(1);
  end;

  if FOptions.Strength < csSecondary then Exit(0);

  if FOptions.FrenchAccents then
  begin
    IA := NA - 1; IB := NB - 1;
    while True do
    begin
      HA := NextSecRev(A, NA, IA, WA);
      HB := NextSecRev(B, NB, IB, WB);
      if not HA and not HB then Break;
      if not HA then Exit(-1);
      if not HB then Exit(1);
      if WA < WB then Exit(-1);
      if WA > WB then Exit(1);
    end;
  end
  else
  begin
    IA := 0; IB := 0;
    while True do
    begin
      HA := NextSecFwd(A, NA, IA, WA);
      HB := NextSecFwd(B, NB, IB, WB);
      if not HA and not HB then Break;
      if not HA then Exit(-1);
      if not HB then Exit(1);
      if WA < WB then Exit(-1);
      if WA > WB then Exit(1);
    end;
  end;

  if FOptions.CaseLevel then
  begin
    for IA := 0 to NA - 1 do
    begin
      if IA >= NB then Exit(1);
      WA := GetCaseLevel(A[IA].Codepoint);
      WB := GetCaseLevel(B[IA].Codepoint);
      if WA < WB then Exit(-1);
      if WA > WB then Exit(1);
    end;
    if NA < NB then Exit(-1);
  end;

  if FOptions.Strength < csTertiary then Exit(0);

  IA := 0; IB := 0;
  while True do
  begin
    HA := NextTer(A, NA, IA, WA);
    HB := NextTer(B, NB, IB, WB);
    if not HA and not HB then Break;
    if not HA then Exit(-1);
    if not HB then Exit(1);
    if WA < WB then Exit(-1);
    if WA > WB then Exit(1);
  end;

  if FOptions.VariableWeighting = cvwShifted then
  begin
    IA := 0; IB := 0;
    while True do
    begin
      HA := NextQuat(A, NA, IA, WA);
      HB := NextQuat(B, NB, IB, WB);
      if not HA and not HB then Break;
      if not HA then Exit(-1);
      if not HB then Exit(1);
      if WA < WB then Exit(-1);
      if WA > WB then Exit(1);
    end;
  end;

  Result := 0;
end;

function TUnicodeCollator.GetSortKey(const AText: string): TCollationKey;
var
  LNormalized: string;
  LCount: SizeInt;
begin
  if AText = '' then
  begin
    Result := nil;
    SetLength(Result, 0);
    Exit;
  end;
  if IsAsciiString(AText) then
    LNormalized := AText
  else if QuickCheckNFD(AText) then
    LNormalized := AText
  else
    LNormalized := NFD(AText);
  LCount := CollectElementsInto(LNormalized, FElsA);
  Result := ElementsToSortKey(FElsA, LCount);
end;

function TUnicodeCollator.Compare(const A, B: string): Integer;
var
  LNA, LNB: string;
  LCountA, LCountB: SizeInt;
  LIterA, LIterB: TUTF8Iterator;
  LCA, LCB: UInt32;
  HA, HB: Boolean;
  LAscii: Boolean;
begin
  if A = B then Exit(0);
  if A = '' then Exit(-1);
  if B = '' then Exit(1);

  LAscii := IsAsciiString(A) and IsAsciiString(B);
  if LAscii then
  begin
    LNA := A;
    LNB := B;
  end
  else
  begin
    { Avoid second full normalize when input is already NFD. }
    if QuickCheckNFD(A) then LNA := A else LNA := NFD(A);
    if QuickCheckNFD(B) then LNB := B else LNB := NFD(B);
  end;

  LCountA := CollectElementsInto(LNA, FElsA);
  LCountB := CollectElementsInto(LNB, FElsB);
  Result := CompareElements(FElsA, LCountA, FElsB, LCountB);
  if Result <> 0 then Exit;
  if FOptions.Strength < csIdentical then Exit(0);

  LIterA.Init(PByte(PAnsiChar(LNA)), SizeUInt(Length(LNA)));
  LIterB.Init(PByte(PAnsiChar(LNB)), SizeUInt(Length(LNB)));
  while True do
  begin
    HA := LIterA.Next(LCA);
    HB := LIterB.Next(LCB);
    if not HA and not HB then Exit(0);
    if not HA then Exit(-1);
    if not HB then Exit(1);
    if LCA < LCB then Exit(-1);
    if LCA > LCB then Exit(1);
  end;
end;

function TUnicodeCollator.TextEquals(const A, B: string): Boolean;
begin
  Result := Compare(A, B) = 0;
end;

function TUnicodeCollator.StartsWith(const AText, APrefix: string): Boolean;
var
  LPrefixLen: SizeInt;
begin
  LPrefixLen := Length(APrefix);
  if LPrefixLen > Length(AText) then Exit(False);
  if LPrefixLen = 0 then Exit(True);
  if BytesEqual(@AText[1], @APrefix[1], LPrefixLen) then Exit(True);
  Result := Compare(Copy(AText, 1, LPrefixLen), APrefix) = 0;
end;

function TUnicodeCollator.EndsWith(const AText, ASuffix: string): Boolean;
var
  LTextLen, LSuffixLen: SizeInt;
begin
  LSuffixLen := Length(ASuffix);
  LTextLen := Length(AText);
  if LSuffixLen > LTextLen then Exit(False);
  if LSuffixLen = 0 then Exit(True);
  if BytesEqual(@AText[LTextLen - LSuffixLen + 1], @ASuffix[1], LSuffixLen) then Exit(True);
  Result := Compare(Copy(AText, LTextLen - LSuffixLen + 1, LSuffixLen), ASuffix) = 0;
end;

function TUnicodeCollator.IndexOf(const AText, ASubstring: string): SizeInt;
var
  LI, LTextLen, LSubByteLen: SizeInt;
  LDecode: TUTF8DecodeResult;
begin
  if Length(ASubstring) = 0 then Exit(1);
  LTextLen := Length(AText);
  LSubByteLen := Length(ASubstring);
  if LSubByteLen > LTextLen then Exit(0);
  LI := 1;
  while LI <= LTextLen - LSubByteLen + 1 do
  begin
    if BytesEqual(@AText[LI], @ASubstring[1], LSubByteLen) then Exit(LI);
    if Compare(Copy(AText, LI, LSubByteLen), ASubstring) = 0 then Exit(LI);
    LDecode := UTF8Decode(@AText[LI], LTextLen - LI + 1);
    if LDecode.ByteLen > 0 then Inc(LI, LDecode.ByteLen) else Inc(LI);
  end;
  Result := 0;
end;

function TUnicodeCollator.Contains(const AText, ASubstring: string): Boolean;
begin
  Result := IndexOf(AText, ASubstring) > 0;
end;

initialization
  GAsciiCEReady := False;
  FCollatorLock := Mutex;

finalization


end.
