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
  BLOCK_SIZE = 128; { pdqsort block size }

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
  for I := (ALo + AHi) div 2 downto ALo do
    SiftDown(AArr, I, AHi);
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
    if B < C then Result := B
    else if A < C then Result := C
    else Result := A;
  end
  else
  begin
    if A < C then Result := A
    else if B < C then Result := C
    else Result := B;
  end;
end;

{ pdqsort-style block partition for Int32.
  Processes elements in blocks of BLOCK_SIZE, maintaining
  left/right offset buffers to reduce random writes. }
function BlockPartitionInt32(var AArr: array of Int32; ALo, AHi: Integer;
  APivot: Int32): Integer;
var
  LOffsetsL, LOffsetsR: array[0..BLOCK_SIZE-1] of Integer;
  LNumL, LNumR, LStartL, LStartR: Integer;
  LI, LJ, L, R: Integer;
  LTmp: Int32;
begin
  L := ALo;
  R := AHi;

  while R - L + 1 > 2 * BLOCK_SIZE do
  begin
    { Fill left block: indices where AArr[i] < pivot }
    LNumL := 0; LStartL := L;
    for LI := L to L + BLOCK_SIZE - 1 do
      if AArr[LI] < APivot then
      begin
        LOffsetsL[LNumL] := LI;
        Inc(LNumL);
      end;

    { Fill right block: indices where AArr[i] > pivot }
    LNumR := 0; LStartR := R - BLOCK_SIZE + 1;
    for LI := R downto LStartR do
      if AArr[LI] > APivot then
      begin
        LOffsetsR[LNumR] := LI;
        Inc(LNumR);
      end;

    { Swap elements from left/right blocks }
    if LNumL < LNumR then LJ := LNumL else LJ := LNumR;
    for LI := 0 to LJ - 1 do
    begin
      LTmp := AArr[LOffsetsL[LI]];
      AArr[LOffsetsL[LI]] := AArr[LOffsetsR[LI]];
      AArr[LOffsetsR[LI]] := LTmp;
    end;

    { Update bounds based on what's left }
    if LNumL > LNumR then
    begin
      { More elements < pivot on left than > pivot on right;
        remaining left elements go to the right side of partition }
      for LI := LNumR to LNumL - 1 do
      begin
        { Swap remaining left-block elements to the end }
        LTmp := AArr[LOffsetsL[LI]];
        AArr[LOffsetsL[LI]] := AArr[R];
        AArr[R] := LTmp;
        Dec(R);
      end;
      L := LStartL + BLOCK_SIZE;
    end
    else if LNumR > LNumL then
    begin
      for LI := LNumL to LNumR - 1 do
      begin
        LTmp := AArr[LOffsetsR[LI]];
        AArr[LOffsetsR[LI]] := AArr[L];
        AArr[L] := LTmp;
        Inc(L);
      end;
      R := LStartR - 1;
    end
    else
    begin
      L := LStartL + BLOCK_SIZE;
      R := LStartR - 1;
    end;
  end;

  { Final Hoare partition for remaining elements }
  LI := L;
  LJ := R;
  while True do
  begin
    while AArr[LI] < APivot do Inc(LI);
    while AArr[LJ] > APivot do Dec(LJ);
    if LI >= LJ then Break;
    LTmp := AArr[LI];
    AArr[LI] := AArr[LJ];
    AArr[LJ] := LTmp;
    Inc(LI);
    Dec(LJ);
  end;

  Result := LJ;
end;

procedure IntroSortInner(var AArr: array of Int32; ALo, AHi, ADepthLimit: Integer);
var
  LPivot: Int32;
  I, J, PMid: Integer;
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

    { Use block partition for large ranges, Hoare for small }
    if AHi - ALo > 2 * BLOCK_SIZE then
      PMid := BlockPartitionInt32(AArr, ALo, AHi, LPivot)
    else
    begin
      { Hoare partition }
      I := ALo;
      J := AHi;
      while True do
      begin
        while AArr[I] < LPivot do Inc(I);
        while AArr[J] > LPivot do Dec(J);
        if I >= J then Break;
        AArr[I] := AArr[I] xor AArr[J];
        AArr[J] := AArr[I] xor AArr[J];
        AArr[I] := AArr[I] xor AArr[J];
        Inc(I);
        Dec(J);
      end;
      PMid := J;
    end;

    { Recurse on smaller partition, iterate on larger (tail call elimination) }
    if PMid - ALo < AHi - PMid then
    begin
      IntroSortInner(AArr, ALo, PMid, ADepthLimit);
      ALo := PMid + 1;
    end
    else
    begin
      IntroSortInner(AArr, PMid + 1, AHi, ADepthLimit);
      AHi := PMid;
    end;
  end;

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
