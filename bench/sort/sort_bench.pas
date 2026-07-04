program sort_bench;
{$mode ObjFPC}{$H+}

uses
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.intf,
  nextpas.core.text.conv;

const
  N = 100000;
  N2 = 1000000;

var
  GArr: array[0..N-1] of Int64;
  GArr2: array[0..N2-1] of Int64;
  GSorted: array[0..N-1] of Int64;
  GReverse: array[0..N-1] of Int64;
  I: Integer;

function Int64Cmp(Data: Pointer; const A, B: Int64): Integer;
begin
  if A < B then Result := -1
  else if A > B then Result := 1
  else Result := 0;
end;

procedure InsertionSort(var A: array of Int64; Lo, Hi: Integer);
var I, J: Integer; T: Int64;
begin
  for I := Lo + 1 to Hi do
  begin
    T := A[I];
    J := I - 1;
    while (J >= Lo) and (A[J] > T) do
    begin
      A[J + 1] := A[J];
      Dec(J);
    end;
    A[J + 1] := T;
  end;
end;

procedure SiftDown(var A: array of Int64; Start, End_: Integer);
var Root, Child, Swap_: Integer; T: Int64;
begin
  Root := Start;
  while True do
  begin
    Child := 2 * Root + 1;
    if Child > End_ then Break;
    Swap_ := Root;
    if A[Swap_] < A[Child] then Swap_ := Child;
    if (Child + 1 <= End_) and (A[Swap_] < A[Child + 1]) then Swap_ := Child + 1;
    if Swap_ = Root then Break;
    T := A[Root]; A[Root] := A[Swap_]; A[Swap_] := T;
    Root := Swap_;
  end;
end;

procedure HeapSort(var A: array of Int64; Lo, Hi: Integer);
var I, End_: Integer; T: Int64;
begin
  End_ := Hi - Lo;
  for I := (End_ - 1) div 2 downto 0 do
    SiftDown(A, I, End_);
  for I := End_ downto 1 do
  begin
    T := A[0]; A[0] := A[I]; A[I] := T;
    SiftDown(A, 0, I - 1);
  end;
end;

function MedianOf3(var A: array of Int64; Lo, Hi: Integer): Int64;
var Mid: Integer;
begin
  Mid := Lo + (Hi - Lo) div 2;
  if A[Lo] > A[Mid] then
  begin
    if A[Mid] > A[Hi] then Result := A[Mid]
    else if A[Lo] > A[Hi] then Result := A[Hi]
    else Result := A[Lo];
  end
  else
  begin
    if A[Lo] > A[Hi] then Result := A[Lo]
    else if A[Mid] > A[Hi] then Result := A[Hi]
    else Result := A[Mid];
  end;
end;

procedure IntroSort(var A: array of Int64; Lo, Hi: Integer; DepthLimit: Integer);
var I, J: Integer; Pivot, T: Int64;
begin
  while Hi - Lo > 16 do
  begin
    if DepthLimit = 0 then
    begin
      HeapSort(A, Lo, Hi);
      Exit;
    end;
    Dec(DepthLimit);
    Pivot := MedianOf3(A, Lo, Hi);
    I := Lo;
    J := Hi;
    repeat
      while A[I] < Pivot do Inc(I);
      while A[J] > Pivot do Dec(J);
      if I <= J then
      begin
        T := A[I]; A[I] := A[J]; A[J] := T;
        Inc(I); Dec(J);
      end;
    until I > J;
    if J - Lo < Hi - I then
    begin
      IntroSort(A, Lo, J, DepthLimit);
      Lo := I;
    end
    else
    begin
      IntroSort(A, I, Hi, DepthLimit);
      Hi := J;
    end;
  end;
  InsertionSort(A, Lo, Hi);
end;

procedure DoSort(var A: array of Int64; Count: Integer);
begin
  IntroSort(A, 0, Count - 1, 2 * (Count div 16));
end;

procedure InitData;
var Seed: UInt32;
begin
  Seed := 12345;
  for I := 0 to N - 1 do
  begin
    Seed := Seed * 1103515245 + 12345;
    GArr[I] := Int64(Seed);
    GSorted[I] := I;
    GReverse[I] := N - I;
  end;
  Seed := 12345;
  for I := 0 to N2 - 1 do
  begin
    Seed := Seed * 1103515245 + 12345;
    GArr2[I] := Int64(Seed);
  end;
end;

procedure BenchSort100k(const ACtx: IBenchContext);
var Tmp: array[0..N-1] of Int64;
begin
  Move(GArr[0], Tmp[0], N * SizeOf(Int64));
  DoSort(Tmp, N);
  ACtx.SetBytes(N * SizeOf(Int64));
  if Tmp[0] > Tmp[1] then WriteLn('');
end;

procedure BenchSort1M(const ACtx: IBenchContext);
var Tmp: array[0..N2-1] of Int64;
begin
  Move(GArr2[0], Tmp[0], N2 * SizeOf(Int64));
  DoSort(Tmp, N2);
  ACtx.SetBytes(N2 * SizeOf(Int64));
  if Tmp[0] > Tmp[1] then WriteLn('');
end;

procedure BenchSortSorted(const ACtx: IBenchContext);
var Tmp: array[0..N-1] of Int64;
begin
  Move(GSorted[0], Tmp[0], N * SizeOf(Int64));
  DoSort(Tmp, N);
  ACtx.SetBytes(N * SizeOf(Int64));
  if Tmp[0] > Tmp[1] then WriteLn('');
end;

procedure BenchSortReverse(const ACtx: IBenchContext);
var Tmp: array[0..N-1] of Int64;
begin
  Move(GReverse[0], Tmp[0], N * SizeOf(Int64));
  DoSort(Tmp, N);
  ACtx.SetBytes(N * SizeOf(Int64));
  if Tmp[0] > Tmp[1] then WriteLn('');
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  InitData;

  WriteLn('=== nextPas Sort Benchmark ===');
  WriteLn('Introsort implementation, Int64 arrays');
  WriteLn;

  LSuite := TBenchSuite.Create('sort')
    .SetMinDuration(TDuration.FromMilliseconds(100))
    .SetMaxIterations(10000)
    .SetMinSamples(6)
    .SetWarmupIters(3);

  LSuite.Add('Sort/100k', @BenchSort100k);
  LSuite.Add('Sort/1M', @BenchSort1M);
  LSuite.Add('Sort/Sorted/100k', @BenchSortSorted);
  LSuite.Add('Sort/Reverse/100k', @BenchSortReverse);

  LResults := LSuite.Run;

  WriteLn;
  WriteLn('=== benchstat format ===');
  WriteLn(LResults.ToBenchStat);
end.
