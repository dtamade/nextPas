{**
 * np_sort_utils.pas — IntroSort (introspective sort) for Int32 arrays
 *
 * Quicksort + Heapsort fallback (depth limit) + Insertion sort for small partitions
 * Similar to Go's pdqsort / C++ std::sort
 *}
unit np_sort_utils;

{$mode objfpc}{$H+}

interface

procedure IntroSortInt32(var AArr: array of Int32);

implementation

const
  INSERTION_SORT_THRESHOLD = 16;

procedure InsertionSortInt32(var AArr: array of Int32; ALo, AHi: Integer);
var
  I, J, Key: Integer;
begin
  for I := ALo + 1 to AHi do
  begin
    Key := AArr[I];
    J := I - 1;
    while (J >= ALo) and (AArr[J] > Key) do
    begin
      AArr[J + 1] := AArr[J];
      Dec(J);
    end;
    AArr[J + 1] := Key;
  end;
end;

procedure SiftDown(var AArr: array of Int32; AStart, AEnd: Integer);
var
  LRoot, LChild, LSwap: Integer;
  LTmp: Int32;
begin
  LRoot := AStart;
  while True do
  begin
    LChild := 2 * LRoot + 1;
    if LChild > AEnd then
      Break;
    LSwap := LRoot;
    if AArr[LSwap] < AArr[LChild] then
      LSwap := LChild;
    if (LChild + 1 <= AEnd) and (AArr[LSwap] < AArr[LChild + 1]) then
      LSwap := LChild + 1;
    if LSwap = LRoot then
      Break;
    LTmp := AArr[LRoot];
    AArr[LRoot] := AArr[LSwap];
    AArr[LSwap] := LTmp;
    LRoot := LSwap;
  end;
end;

procedure HeapSortInt32(var AArr: array of Int32; ALo, AHi: Integer);
var
  I: Integer;
  LTmp: Int32;
begin
  { Build max heap }
  for I := (ALo + AHi) div 2 downto ALo do
    SiftDown(AArr, I, AHi);
  { Extract elements }
  for I := AHi downto ALo + 1 do
  begin
    LTmp := AArr[ALo];
    AArr[ALo] := AArr[I];
    AArr[I] := LTmp;
    SiftDown(AArr, ALo, I - 1);
  end;
end;

function MedianOfThree(A, B, C: Int32): Int32;
begin
  if A < B then
  begin
    if B < C then
      Result := B
    else if A < C then
      Result := C
    else
      Result := A;
  end
  else
  begin
    if A < C then
      Result := A
    else if B < C then
      Result := C
    else
      Result := B;
  end;
end;

procedure IntroSortInner(var AArr: array of Int32; ALo, AHi, ADepthLimit: Integer);
var
  LPivot, LTmp: Int32;
  I, J: Integer;
begin
  while AHi - ALo > INSERTION_SORT_THRESHOLD do
  begin
    if ADepthLimit = 0 then
    begin
      HeapSortInt32(AArr, ALo, AHi);
      Exit;
    end;
    Dec(ADepthLimit);

    { Pivot selection: Tukey's ninther for large, median-of-three otherwise }
    if AHi - ALo > 128 then
    begin
      { Tukey's ninther: median of three medians-of-three }
      I := (AHi - ALo) div 8;
      LPivot := MedianOfThree(
        MedianOfThree(AArr[ALo], AArr[ALo + I], AArr[ALo + 2*I]),
        MedianOfThree(AArr[ALo + 3*I], AArr[ALo + (AHi - ALo) div 2], AArr[AHi - 3*I]),
        MedianOfThree(AArr[AHi - 2*I], AArr[AHi - I], AArr[AHi]));
    end
    else
      LPivot := MedianOfThree(
        AArr[ALo],
        AArr[ALo + (AHi - ALo) div 2],
        AArr[AHi]);

    { Hoare partition }
    I := ALo;
    J := AHi;
    while True do
    begin
      while AArr[I] < LPivot do Inc(I);
      while AArr[J] > LPivot do Dec(J);
      if I >= J then Break;
      LTmp := AArr[I];
      AArr[I] := AArr[J];
      AArr[J] := LTmp;
      Inc(I);
      Dec(J);
    end;

    { Recurse on smaller partition, iterate on larger (tail call elimination) }
    if J - ALo < AHi - J then
    begin
      IntroSortInner(AArr, ALo, J, ADepthLimit);
      ALo := J + 1;
    end
    else
    begin
      IntroSortInner(AArr, J + 1, AHi, ADepthLimit);
      AHi := J;
    end;
  end;

  { Insertion sort for small partition }
  InsertionSortInt32(AArr, ALo, AHi);
end;

procedure IntroSortInt32(var AArr: array of Int32);
var
  N, DepthLimit: Integer;
begin
  N := Length(AArr);
  if N <= 1 then Exit;
  DepthLimit := 1;
  while (1 shl DepthLimit) < N do
    Inc(DepthLimit);
  IntroSortInner(AArr, 0, N - 1, DepthLimit * 2);
end;

end.
