unit nextpas.core.text.strings;

{$I nextpas.core.settings.inc}
{$modeswitch typehelpers}

interface

uses
  nextpas.core.text.base;

type
  TStringArray = nextpas.core.text.base.TStringArray;
  TStringPredicate = function(const S: string): Boolean;
  TStringMapper = function(const S: string): string;

  TStringPair = record
    Key: string;
    Value: string;
  end;
  TStringPairArray = array of TStringPair;
  TStringChunks = array of TStringArray;

  TStringArrayHelper = type helper for TStringArray
    procedure Add(const AValue: string);
    procedure Insert(AIndex: SizeUInt; const AValue: string);
    procedure Delete(AIndex: SizeUInt);
    procedure Clear;
    procedure Sort;
    procedure Reverse;
    function Contains(const AValue: string): Boolean;
    function IndexOf(const AValue: string): SizeInt;
    function Count: SizeInt; inline;
    function IsEmpty: Boolean; inline;
    function Join(const ASep: string): string;
    function Slice(AStart, AEnd: SizeUInt): TStringArray;
    function Filter(APredicate: TStringPredicate): TStringArray;
    function Map(AMapper: TStringMapper): TStringArray;
    function Unique: TStringArray;
    function TrimAll: TStringArray;
    function ToUpper: TStringArray;
    function ToLower: TStringArray;
    function RemoveEmpty: TStringArray;
  end;

function StringsContains(const AArr: TStringArray; const AValue: string): Boolean;
function StringsIndexOf(const AArr: TStringArray; const AValue: string): SizeInt;
function StringsLastIndexOf(const AArr: TStringArray; const AValue: string): SizeInt;
procedure StringsSort(var AArr: TStringArray);
procedure StringsReverse(var AArr: TStringArray);
function StringsSplit(const AValue, ADelimiter: string): TStringArray;
function StringsJoin(const AArr: TStringArray; const ASep: string): string;
function StringsFilter(const AArr: TStringArray; APredicate: TStringPredicate): TStringArray;
function StringsMap(const AArr: TStringArray; AMapper: TStringMapper): TStringArray;
function StringsUnique(const AArr: TStringArray): TStringArray;
function StringsCount(const AArr: TStringArray; const AValue: string): SizeUInt;
procedure StringsAppend(var AArr: TStringArray; const AValue: string);
procedure StringsInsert(var AArr: TStringArray; AIndex: SizeUInt; const AValue: string);
procedure StringsDelete(var AArr: TStringArray; AIndex: SizeUInt);
function StringsSlice(const AArr: TStringArray; AStart, AEnd: SizeUInt): TStringArray;

{ Key-Value parsing utilities }
function StringsParseLines(const AText: string): TStringArray;
function StringsParseKeyValues(const AText: string; ASeparator: Char = '='): TStringPairArray;
function StringPairsGet(const APairs: TStringPairArray; const AKey: string; const ADefault: string = ''): string;
function StringPairsContains(const APairs: TStringPairArray; const AKey: string): Boolean;
function StringPairsKeys(const APairs: TStringPairArray): TStringArray;

{ Batch transform utilities }
function StringsTrimAll(const AArr: TStringArray): TStringArray;
function StringsToUpper(const AArr: TStringArray): TStringArray;
function StringsToLower(const AArr: TStringArray): TStringArray;
function StringsRemoveEmpty(const AArr: TStringArray): TStringArray;

{ Pattern matching }
function GlobMatch(const APattern, AStr: string): Boolean;
function StringsGlob(const AArr: TStringArray; const APattern: string): TStringArray;

{ Additional utilities }
function StringsRepeat(const AValue: string; ACount: SizeUInt): TStringArray;
function StringsChunk(const AArr: TStringArray; ASize: SizeUInt): TStringChunks;

{ Split utilities }
function StringsSplit(const AStr: string; ASep: Char; ARemoveEmpty: Boolean = False): TStringArray;

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.mem.utils;

function StringsContains(const AArr: TStringArray; const AValue: string): Boolean;
var i: SizeInt;
begin
  for i := 0 to High(AArr) do
    if AArr[i] = AValue then Exit(True);
  Result := False;
end;

function StringsIndexOf(const AArr: TStringArray; const AValue: string): SizeInt;
var i: SizeInt;
begin
  for i := 0 to High(AArr) do
    if AArr[i] = AValue then Exit(i);
  Result := -1;
end;

function StringsLastIndexOf(const AArr: TStringArray; const AValue: string): SizeInt;
var i: SizeInt;
begin
  for i := High(AArr) downto 0 do
    if AArr[i] = AValue then Exit(i);
  Result := -1;
end;

procedure StringsSort(var AArr: TStringArray);

  procedure DoQuickSort(var A: TStringArray; Lo, Hi: SizeInt);
  var i, j: SizeInt; pivot, tmp: string;
  begin
    if Lo >= Hi then Exit;
    i := Lo; j := Hi;
    pivot := A[(Lo + Hi) shr 1];
    while i <= j do
    begin
      while A[i] < pivot do Inc(i);
      while A[j] > pivot do Dec(j);
      if i <= j then
      begin
        tmp := A[i]; A[i] := A[j]; A[j] := tmp;
        Inc(i); Dec(j);
      end;
    end;
    if Lo < j then DoQuickSort(A, Lo, j);
    if i < Hi then DoQuickSort(A, i, Hi);
  end;

begin
  if Length(AArr) > 1 then
    DoQuickSort(AArr, 0, High(AArr));
end;

procedure StringsReverse(var AArr: TStringArray);
var i, j: SizeInt; tmp: string;
begin
  i := 0; j := High(AArr);
  while i < j do
  begin
    tmp := AArr[i]; AArr[i] := AArr[j]; AArr[j] := tmp;
    Inc(i); Dec(j);
  end;
end;

function StringsSplit(const AValue, ADelimiter: string): TStringArray;
var
  LPos: SizeInt;
  LStart: SizeInt;
  LDelimLen: SizeInt;
  LCount: SizeInt;
  LCapacity: SizeInt;
begin
  Result := nil;
  LDelimLen := Length(ADelimiter);
  if LDelimLen = 0 then
  begin
    SetLength(Result, 1);
    Result[0] := AValue;
    Exit;
  end;

  LCount := 0;
  LCapacity := 0;
  LStart := 1;
  repeat
    LPos := Pos(ADelimiter, AValue, LStart);
    if LPos = 0 then
      LPos := Length(AValue) + 1;
    if LCount >= LCapacity then
    begin
      if LCapacity = 0 then
        LCapacity := 8
      else
        LCapacity := LCapacity * 2;
      SetLength(Result, LCapacity);
    end;
    Result[LCount] := System.Copy(AValue, LStart, LPos - LStart);
    Inc(LCount);
    LStart := LPos + LDelimLen;
  until LPos > Length(AValue);
  SetLength(Result, LCount);
end;

function StringsJoin(const AArr: TStringArray; const ASep: string): string;
var
  i: SizeInt;
  LTotal, LSepLen, LPos: SizeInt;
begin
  if Length(AArr) = 0 then Exit('');
  if Length(AArr) = 1 then Exit(AArr[0]);
  LSepLen := Length(ASep);
  LTotal := 0;
  for i := 0 to High(AArr) do
    Inc(LTotal, Length(AArr[i]));
  Inc(LTotal, LSepLen * (Length(AArr) - 1));
  SetLength(Result, LTotal);
  LPos := 1;
  if Length(AArr[0]) > 0 then
  begin
    CopyNonOverlap(@AArr[0][1], @Result[LPos], Length(AArr[0]));
    Inc(LPos, Length(AArr[0]));
  end;
  for i := 1 to High(AArr) do
  begin
    if LSepLen > 0 then
    begin
      CopyNonOverlap(@ASep[1], @Result[LPos], LSepLen);
      Inc(LPos, LSepLen);
    end;
    if Length(AArr[i]) > 0 then
    begin
      CopyNonOverlap(@AArr[i][1], @Result[LPos], Length(AArr[i]));
      Inc(LPos, Length(AArr[i]));
    end;
  end;
end;

function StringsFilter(const AArr: TStringArray; APredicate: TStringPredicate): TStringArray;
var i, LCount: SizeInt;
begin
  SetLength(Result, Length(AArr));
  LCount := 0;
  for i := 0 to High(AArr) do
    if APredicate(AArr[i]) then
    begin
      Result[LCount] := AArr[i];
      Inc(LCount);
    end;
  SetLength(Result, LCount);
end;

function StringsMap(const AArr: TStringArray; AMapper: TStringMapper): TStringArray;
var i: SizeInt;
begin
  SetLength(Result, Length(AArr));
  for i := 0 to High(AArr) do
    Result[i] := AMapper(AArr[i]);
end;

function StringsUnique(const AArr: TStringArray): TStringArray;
var i, LCount: SizeInt; LSorted: TStringArray;
begin
  if Length(AArr) = 0 then Exit(nil);
  LSorted := System.Copy(AArr);
  StringsSort(LSorted);
  SetLength(Result, Length(LSorted));
  Result[0] := LSorted[0];
  LCount := 1;
  for i := 1 to High(LSorted) do
    if LSorted[i] <> LSorted[i - 1] then
    begin
      Result[LCount] := LSorted[i];
      Inc(LCount);
    end;
  SetLength(Result, LCount);
end;

function StringsCount(const AArr: TStringArray; const AValue: string): SizeUInt;
var i: SizeInt;
begin
  Result := 0;
  for i := 0 to High(AArr) do
    if AArr[i] = AValue then Inc(Result);
end;

procedure StringsAppend(var AArr: TStringArray; const AValue: string);
var L: SizeInt;
begin
  L := Length(AArr);
  SetLength(AArr, L + 1);
  AArr[L] := AValue;
end;

procedure StringsDelete(var AArr: TStringArray; AIndex: SizeUInt);
var i: SizeUInt;
begin
  if AIndex > High(AArr) then Exit;
  for i := AIndex to High(AArr) - 1 do
    AArr[i] := AArr[i + 1];
  SetLength(AArr, Length(AArr) - 1);
end;

procedure StringsInsert(var AArr: TStringArray; AIndex: SizeUInt; const AValue: string);
var i, L: SizeUInt;
begin
  L := Length(AArr);
  if AIndex > L then AIndex := L;
  SetLength(AArr, L + 1);
  for i := L downto AIndex + 1 do
    AArr[i] := AArr[i - 1];
  AArr[AIndex] := AValue;
end;

function StringsSlice(const AArr: TStringArray; AStart, AEnd: SizeUInt): TStringArray;
var i, LLen: SizeUInt;
begin
  if AEnd > SizeUInt(Length(AArr)) then AEnd := Length(AArr);
  if AStart >= AEnd then Exit(nil);
  LLen := AEnd - AStart;
  SetLength(Result, LLen);
  for i := 0 to LLen - 1 do
    Result[i] := AArr[AStart + i];
end;

{ Key-Value parsing }

function StringsParseLines(const AText: string): TStringArray;
var
  i, LStart, LCount, LLen: SizeInt;
begin
  LLen := Length(AText);
  if LLen = 0 then Exit(nil);

  LCount := 0;
  for i := 1 to LLen do
    if AText[i] = #10 then Inc(LCount);
  Inc(LCount);

  SetLength(Result, LCount);
  LCount := 0;
  LStart := 1;
  for i := 1 to LLen do
  begin
    if AText[i] = #10 then
    begin
      if (i > LStart) and (AText[i - 1] = #13) then
        Result[LCount] := System.Copy(AText, LStart, i - LStart - 1)
      else
        Result[LCount] := System.Copy(AText, LStart, i - LStart);
      Inc(LCount);
      LStart := i + 1;
    end;
  end;
  if LStart <= LLen then
  begin
    Result[LCount] := System.Copy(AText, LStart, LLen - LStart + 1);
    Inc(LCount);
  end;
  SetLength(Result, LCount);
end;

function StringsParseKeyValues(const AText: string; ASeparator: Char): TStringPairArray;
var
  LLines: TStringArray;
  i, LSepPos: SizeInt;
  LCount: SizeInt;
  LLine: string;
begin
  LLines := StringsParseLines(AText);
  SetLength(Result, Length(LLines));
  LCount := 0;
  for i := 0 to High(LLines) do
  begin
    LLine := LLines[i];
    LSepPos := Pos(ASeparator, LLine);
    if LSepPos > 0 then
    begin
      Result[LCount].Key := Trim(System.Copy(LLine, 1, LSepPos - 1));
      Result[LCount].Value := Trim(System.Copy(LLine, LSepPos + 1, Length(LLine) - LSepPos));
      Inc(LCount);
    end;
  end;
  SetLength(Result, LCount);
end;

function StringPairsGet(const APairs: TStringPairArray; const AKey: string; const ADefault: string): string;
var i: SizeInt;
begin
  for i := 0 to High(APairs) do
    if APairs[i].Key = AKey then Exit(APairs[i].Value);
  Result := ADefault;
end;

function StringPairsContains(const APairs: TStringPairArray; const AKey: string): Boolean;
var i: SizeInt;
begin
  for i := 0 to High(APairs) do
    if APairs[i].Key = AKey then Exit(True);
  Result := False;
end;

function StringPairsKeys(const APairs: TStringPairArray): TStringArray;
var i: SizeInt;
begin
  SetLength(Result, Length(APairs));
  for i := 0 to High(APairs) do
    Result[i] := APairs[i].Key;
end;

{ Batch transforms }

function StringsTrimAll(const AArr: TStringArray): TStringArray;
var i: SizeInt;
begin
  SetLength(Result, Length(AArr));
  for i := 0 to High(AArr) do
    Result[i] := Trim(AArr[i]);
end;

function StringsToUpper(const AArr: TStringArray): TStringArray;
var i: SizeInt;
begin
  SetLength(Result, Length(AArr));
  for i := 0 to High(AArr) do
    Result[i] := UpperCase(AArr[i]);
end;

function StringsToLower(const AArr: TStringArray): TStringArray;
var i: SizeInt;
begin
  SetLength(Result, Length(AArr));
  for i := 0 to High(AArr) do
    Result[i] := LowerCase(AArr[i]);
end;

function StringsRemoveEmpty(const AArr: TStringArray): TStringArray;
var i, LCount: SizeInt;
begin
  SetLength(Result, Length(AArr));
  LCount := 0;
  for i := 0 to High(AArr) do
    if AArr[i] <> '' then
    begin
      Result[LCount] := AArr[i];
      Inc(LCount);
    end;
  SetLength(Result, LCount);
end;

{ Pattern matching — glob style: * matches any, ? matches one char }

function GlobMatch(const APattern, AStr: string): Boolean;
var
  LP, LS, LStarP, LStarS: SizeInt;
begin
  LP := 1; LS := 1;
  LStarP := 0; LStarS := 0;

  while LS <= Length(AStr) do
  begin
    if (LP <= Length(APattern)) and ((APattern[LP] = '?') or (APattern[LP] = AStr[LS])) then
    begin
      Inc(LP); Inc(LS);
    end
    else if (LP <= Length(APattern)) and (APattern[LP] = '*') then
    begin
      LStarP := LP;
      LStarS := LS;
      Inc(LP);
    end
    else if LStarP > 0 then
    begin
      LP := LStarP + 1;
      Inc(LStarS);
      LS := LStarS;
    end
    else
      Exit(False);
  end;

  while (LP <= Length(APattern)) and (APattern[LP] = '*') do
    Inc(LP);
  Result := LP > Length(APattern);
end;

function StringsGlob(const AArr: TStringArray; const APattern: string): TStringArray;
var i, LCount: SizeInt;
begin
  SetLength(Result, Length(AArr));
  LCount := 0;
  for i := 0 to High(AArr) do
    if GlobMatch(APattern, AArr[i]) then
    begin
      Result[LCount] := AArr[i];
      Inc(LCount);
    end;
  SetLength(Result, LCount);
end;

{ TStringArrayHelper }

procedure TStringArrayHelper.Add(const AValue: string);
begin
  StringsAppend(Self, AValue);
end;

procedure TStringArrayHelper.Insert(AIndex: SizeUInt; const AValue: string);
begin
  StringsInsert(Self, AIndex, AValue);
end;

procedure TStringArrayHelper.Delete(AIndex: SizeUInt);
begin
  StringsDelete(Self, AIndex);
end;

procedure TStringArrayHelper.Clear;
begin
  Self := nil;
end;

procedure TStringArrayHelper.Sort;
begin
  StringsSort(Self);
end;

procedure TStringArrayHelper.Reverse;
begin
  StringsReverse(Self);
end;

function TStringArrayHelper.Contains(const AValue: string): Boolean;
begin
  Result := StringsContains(Self, AValue);
end;

function TStringArrayHelper.IndexOf(const AValue: string): SizeInt;
begin
  Result := StringsIndexOf(Self, AValue);
end;

function TStringArrayHelper.Count: SizeInt;
begin
  Result := Length(Self);
end;

function TStringArrayHelper.IsEmpty: Boolean;
begin
  Result := Length(Self) = 0;
end;

function TStringArrayHelper.Join(const ASep: string): string;
begin
  Result := StringsJoin(Self, ASep);
end;

function TStringArrayHelper.Slice(AStart, AEnd: SizeUInt): TStringArray;
begin
  Result := StringsSlice(Self, AStart, AEnd);
end;

function TStringArrayHelper.Filter(APredicate: TStringPredicate): TStringArray;
begin
  Result := StringsFilter(Self, APredicate);
end;

function TStringArrayHelper.Map(AMapper: TStringMapper): TStringArray;
begin
  Result := StringsMap(Self, AMapper);
end;

function TStringArrayHelper.Unique: TStringArray;
begin
  Result := StringsUnique(Self);
end;

function TStringArrayHelper.TrimAll: TStringArray;
begin
  Result := StringsTrimAll(Self);
end;

function TStringArrayHelper.ToUpper: TStringArray;
begin
  Result := StringsToUpper(Self);
end;

function TStringArrayHelper.ToLower: TStringArray;
begin
  Result := StringsToLower(Self);
end;

function TStringArrayHelper.RemoveEmpty: TStringArray;
begin
  Result := StringsRemoveEmpty(Self);
end;

function StringsRepeat(const AValue: string; ACount: SizeUInt): TStringArray;
var I: SizeUInt;
begin
  SetLength(Result, ACount);
  for I := 0 to ACount - 1 do
    Result[I] := AValue;
end;

function StringsChunk(const AArr: TStringArray; ASize: SizeUInt): TStringChunks;
var
  I, LChunkCount, LRemain: SizeUInt;
  J, LStart: SizeUInt;
begin
  if (Length(AArr) = 0) or (ASize = 0) then
  begin
    Result := nil;
    Exit;
  end;
  LChunkCount := (SizeUInt(Length(AArr)) + ASize - 1) div ASize;
  SetLength(Result, LChunkCount);
  LStart := 0;
  for I := 0 to LChunkCount - 1 do
  begin
    LRemain := SizeUInt(Length(AArr)) - LStart;
    if LRemain > ASize then LRemain := ASize;
    SetLength(Result[I], LRemain);
    for J := 0 to LRemain - 1 do
      Result[I][J] := AArr[LStart + J];
    Inc(LStart, LRemain);
  end;
end;

{== Split ==}

function StringsSplit(const AStr: string; ASep: Char; ARemoveEmpty: Boolean): TStringArray;
var
  I, LSegStart, LSegCount, LLen: Integer;
begin
  Result := nil;
  LLen := Length(AStr);
  if LLen = 0 then
  begin
    if not ARemoveEmpty then
    begin
      SetLength(Result, 1);
      Result[0] := '';
    end;
    Exit;
  end;
  // First pass: count segments
  LSegCount := 1;
  for I := 1 to LLen do
    if AStr[I] = ASep then
      Inc(LSegCount);
  // Second pass: fill
  SetLength(Result, LSegCount);
  LSegStart := 1;
  LSegCount := 0;
  for I := 1 to LLen do
    if AStr[I] = ASep then
    begin
      if (I > LSegStart) or not ARemoveEmpty then
      begin
        SetString(Result[LSegCount], PChar(@AStr[LSegStart]), I - LSegStart);
        Inc(LSegCount);
      end;
      LSegStart := I + 1;
    end;
  // Last segment
  if (LLen >= LSegStart) or not ARemoveEmpty then
  begin
    SetString(Result[LSegCount], PChar(@AStr[LSegStart]), LLen - LSegStart + 1);
    Inc(LSegCount);
  end;
  // Trim if remove-empty shrank the array
  if LSegCount < Length(Result) then
    SetLength(Result, LSegCount);
end;

end.
