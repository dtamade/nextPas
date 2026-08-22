{******************************************************************************
  nextpas.core.lockfree.suffixarray

  Concurrent Suffix Array — lock-free string pattern matching.

  Design:
  - Pre-sorted suffix indices for binary search
  - O(m log n) pattern search where m = pattern length, n = text length
  - Spin lock for coherent build/search publication
  - LCP array for enhanced search (optional)

  Use cases: full-text search, pattern matching, bioinformatics.

  2026-07-06  Phase 3
******************************************************************************}
{$mode ObjFPC}{$H+}{$J-}
unit nextpas.core.lockfree.suffixarray;

interface

uses
  nextpas.core.errors;

type
  TSuffixArrayResult = (
    sarOk,
    sarEmpty,
    sarInvalidRange
  );

  TSuffixArrayMatch = record
    Index: Int32;
    Length: Int32;
  end;

  TSuffixArray = class
  private
    FText: AnsiString;
    FSuffixArray: array of Int32;
    FLCP: array of Int32;
    FLength: Int32;
    FBuilt: Boolean;
    FLock: Int32;

    function CompareSuffix(AIdx1, AIdx2: Int32): Int32;
    procedure BuildSuffixArray;
    procedure BuildLCP;
    procedure Lock;
    procedure Unlock;
  public
    constructor Create;
    destructor Destroy; override;

    function Build(const AText: AnsiString): TSuffixArrayResult;
    function Search(const APattern: AnsiString): specialize TArray<TSuffixArrayMatch>;
    function Contains(const APattern: AnsiString): Boolean;
    function Count(const APattern: AnsiString): Int32;
    function TextLength: Int32;
    function IsBuilt: Boolean;
  end;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.lockfree.base;

constructor TSuffixArray.Create;
begin
  inherited Create;
  FText := '';
  SetLength(FSuffixArray, 0);
  SetLength(FLCP, 0);
  FLength := 0;
  FBuilt := False;
  FLock := 0;
end;

destructor TSuffixArray.Destroy;
begin
  SetLength(FSuffixArray, 0);
  SetLength(FLCP, 0);
  inherited Destroy;
end;

function TSuffixArray.CompareSuffix(AIdx1, AIdx2: Int32): Int32;
var
  I, LLen1, LLen2, LMinLen: Int32;
begin
  LLen1 := FLength - AIdx1;
  LLen2 := FLength - AIdx2;
  if LLen1 < LLen2 then LMinLen := LLen1 else LMinLen := LLen2;

  for I := 0 to LMinLen - 1 do
  begin
    if FText[AIdx1 + I + 1] < FText[AIdx2 + I + 1] then
      Exit(-1);
    if FText[AIdx1 + I + 1] > FText[AIdx2 + I + 1] then
      Exit(1);
  end;

  { Shorter suffix comes first }
  if LLen1 < LLen2 then Exit(-1);
  if LLen1 > LLen2 then Exit(1);
  Result := 0;
end;

procedure TSuffixArray.Lock;
var
  LSpin: Integer;
  LCasExpected: Int32;
begin
  LSpin := 0;
  while True do
  begin
    LCasExpected := 0;
    if atomic_compare_exchange_strong(FLock, LCasExpected, 1, mo_acq_rel, mo_acquire) then
      Break;
    Inc(LSpin);
    if LSpin > LOCKFREE_SPIN_COUNT then
    begin
      if LSpin > LOCKFREE_SPIN_COUNT + LOCKFREE_YIELD_COUNT then
        LSpin := LOCKFREE_SPIN_COUNT;
      ThreadSwitch;
    end
    else
      CpuPause;
  end;
end;

procedure TSuffixArray.Unlock;
begin
  atomic_store(FLock, 0, mo_release);
end;

procedure TSuffixArray.BuildSuffixArray;
var
  I, J, LGap, LTemp: Int32;
  LSwapped: Boolean;
begin
  { Simple O(n log^2 n) sort — sufficient for moderate text sizes }
  for I := 0 to FLength - 1 do
    FSuffixArray[I] := I;

  { Shell sort with gap sequence }
  LGap := FLength;
  repeat
    LGap := LGap div 2;
    if LGap < 1 then Break;
    repeat
      LSwapped := False;
      for I := 0 to FLength - 1 - LGap do
      begin
        J := I + LGap;
        if CompareSuffix(FSuffixArray[I], FSuffixArray[J]) > 0 then
        begin
          LTemp := FSuffixArray[I];
          FSuffixArray[I] := FSuffixArray[J];
          FSuffixArray[J] := LTemp;
          LSwapped := True;
        end;
      end;
    until not LSwapped;
  until LGap <= 1;
end;

procedure TSuffixArray.BuildLCP;
var
  I, J, LLen: Int32;
begin
  SetLength(FLCP, FLength);
  FLCP[0] := 0;
  for I := 1 to FLength - 1 do
  begin
    J := FSuffixArray[I - 1];
    LLen := 0;
    while (FSuffixArray[I] + LLen < FLength) and (J + LLen < FLength) and
          (FText[FSuffixArray[I] + LLen + 1] = FText[J + LLen + 1]) do
      Inc(LLen);
    FLCP[I] := LLen;
  end;
end;

function TSuffixArray.Build(const AText: AnsiString): TSuffixArrayResult;
begin
  Lock;
  try
    if Length(AText) = 0 then
    begin
      FText := '';
      SetLength(FSuffixArray, 0);
      SetLength(FLCP, 0);
      FLength := 0;
      FBuilt := False;
      Exit(sarEmpty);
    end;

    FText := AText;
    FLength := Length(AText);
    SetLength(FSuffixArray, FLength);
    BuildSuffixArray;
    BuildLCP;
    FBuilt := True;
    Result := sarOk;
  finally
    Unlock;
  end;
end;

function TSuffixArray.Search(const APattern: AnsiString): specialize TArray<TSuffixArrayMatch>;
var
  LPatLen, LLo, LHi, LMid, LCmp, LStart, LEnd, I, J: Int32;
  LMatch: TSuffixArrayMatch;

  function ComparePrefix(ASuffixIdx: Int32): Int32;
  var
    K, LMax: Int32;
  begin
    LMax := LPatLen;
    if ASuffixIdx + LMax > FLength then
      LMax := FLength - ASuffixIdx;
    for K := 0 to LMax - 1 do
    begin
      if FText[ASuffixIdx + K + 1] < APattern[K + 1] then
        Exit(-1);
      if FText[ASuffixIdx + K + 1] > APattern[K + 1] then
        Exit(1);
    end;
    if LMax < LPatLen then
      Result := -1 { suffix shorter than pattern }
    else
      Result := 0;
  end;

begin
  Result := nil;
  Lock;
  try
    if not FBuilt or (Length(APattern) = 0) then
      Exit;

    LPatLen := Length(APattern);
    LLo := 0;
    LHi := FLength - 1;
    while LLo <= LHi do
    begin
      LMid := (LLo + LHi) div 2;
      LCmp := ComparePrefix(FSuffixArray[LMid]);
      if LCmp >= 0 then
        LHi := LMid - 1
      else
        LLo := LMid + 1;
    end;
    LStart := LLo;

    LLo := LStart;
    LHi := FLength - 1;
    while LLo <= LHi do
    begin
      LMid := (LLo + LHi) div 2;
      LCmp := ComparePrefix(FSuffixArray[LMid]);
      if LCmp > 0 then
        LHi := LMid - 1
      else
        LLo := LMid + 1;
    end;
    LEnd := LHi;

    if LStart <= LEnd then
    begin
      SetLength(Result, LEnd - LStart + 1);
      for I := LStart to LEnd do
      begin
        LMatch.Index := FSuffixArray[I];
        LMatch.Length := LPatLen;
        Result[I - LStart] := LMatch;
      end;
      for I := 0 to High(Result) - 1 do
        for J := I + 1 to High(Result) do
          if Result[I].Index > Result[J].Index then
          begin
            LMatch := Result[I];
            Result[I] := Result[J];
            Result[J] := LMatch;
          end;
    end;
  finally
    Unlock;
  end;
end;

function TSuffixArray.Contains(const APattern: AnsiString): Boolean;
begin
  Result := Length(Search(APattern)) > 0;
end;

function TSuffixArray.Count(const APattern: AnsiString): Int32;
begin
  Result := Length(Search(APattern));
end;

function TSuffixArray.TextLength: Int32;
begin
  Lock;
  try
    Result := FLength;
  finally
    Unlock;
  end;
end;

function TSuffixArray.IsBuilt: Boolean;
begin
  Lock;
  try
    Result := FBuilt;
  finally
    Unlock;
  end;
end;

end.
