unit nextpas.core.text.strings;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.base;

type
  TStringArray = nextpas.core.text.base.TStringArray;
  TStringPredicate = function(const S: string): Boolean;
  TStringMapper = function(const S: string): string;

function StringsContains(const AArr: TStringArray; const AValue: string): Boolean;
function StringsIndexOf(const AArr: TStringArray; const AValue: string): SizeInt;
function StringsLastIndexOf(const AArr: TStringArray; const AValue: string): SizeInt;
procedure StringsSort(var AArr: TStringArray);
procedure StringsReverse(var AArr: TStringArray);
function StringsJoin(const AArr: TStringArray; const ASep: string): string;
function StringsFilter(const AArr: TStringArray; APredicate: TStringPredicate): TStringArray;
function StringsMap(const AArr: TStringArray; AMapper: TStringMapper): TStringArray;
function StringsUnique(const AArr: TStringArray): TStringArray;
function StringsCount(const AArr: TStringArray; const AValue: string): SizeUInt;
procedure StringsAppend(var AArr: TStringArray; const AValue: string);
procedure StringsInsert(var AArr: TStringArray; AIndex: SizeUInt; const AValue: string);
procedure StringsDelete(var AArr: TStringArray; AIndex: SizeUInt);
function StringsSlice(const AArr: TStringArray; AStart, AEnd: SizeUInt): TStringArray;

implementation

uses
  SysUtils;

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

function StringsJoin(const AArr: TStringArray; const ASep: string): string;
var i: SizeInt;
begin
  if Length(AArr) = 0 then Exit('');
  Result := AArr[0];
  for i := 1 to High(AArr) do
    Result := Result + ASep + AArr[i];
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
  LSorted := Copy(AArr);
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

end.
