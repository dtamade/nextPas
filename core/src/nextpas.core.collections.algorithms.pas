unit nextpas.core.collections.algorithms;

{$I nextpas.core.settings.inc}

{**
 * nextpas.core.collections.algorithms - 泛型算法模块
 *
 * 提供 STL/Rust 风格的泛型算法:
 * - Sort         : 排序 (QuickSort 实现)
 * - BinarySearch : 二分查找
 * - FindIf       : 条件查找
 * - Partition    : 分区
 * - Unique       : 去重 (需已排序)
 * - RotateLeft   : 左旋转
 * - RotateRight  : 右旋转
 *}

interface

uses
  nextpas.core.errors,
  nextpas.core.collections.base;

type
  { 泛型比较函数类型 }
  generic TAlgoCompareFunc<T> = function(const A, B: T; aData: Pointer): SizeInt;

  { 泛型谓词函数类型 }
  generic TAlgoPredicateFunc<T> = function(const aElement: T; aData: Pointer): Boolean;

{**
 * Sort<T> - 泛型排序算法 (QuickSort)
 *
 * @param aArr      要排序的动态数组
 * @param aCompare  比较函数，返回 <0 表示 A<B, 0 表示 A=B, >0 表示 A>B
 * @param aData     传递给比较函数的用户数据
 *}
generic procedure Sort<T>(var aArr: array of T; aCompare: specialize TAlgoCompareFunc<T>; aData: Pointer);

{**
 * BinarySearch<T> - 二分查找
 *
 * @param aArr      已排序的数组
 * @param aValue    要查找的值
 * @param aCompare  比较函数
 * @param aData     用户数据
 * @param aIndex    输出找到的索引
 * @return          是否找到
 *}
generic function BinarySearch<T>(const aArr: array of T; const aValue: T;
  aCompare: specialize TAlgoCompareFunc<T>; aData: Pointer; out aIndex: SizeInt): Boolean;

generic function LowerBound<T>(const aArr: array of T; const aValue: T;
  aCompare: specialize TAlgoCompareFunc<T>; aData: Pointer): SizeInt;

{**
 * FindIf<T> - 条件查找
 *
 * @param aArr        数组
 * @param aPredicate  谓词函数
 * @param aData       用户数据
 * @param aIndex      输出找到的索引
 * @return            是否找到
 *}
generic function FindIf<T>(const aArr: array of T;
  aPredicate: specialize TAlgoPredicateFunc<T>; aData: Pointer; out aIndex: SizeInt): Boolean;

{**
 * Partition<T> - 分区算法
 *
 * 将满足谓词的元素移到前面，不满足的移到后面
 *
 * @param aArr        数组
 * @param aPredicate  谓词函数
 * @param aData       用户数据
 * @return            分区点索引（第一个不满足谓词的元素位置）
 *}
generic function Partition<T>(var aArr: array of T;
  aPredicate: specialize TAlgoPredicateFunc<T>; aData: Pointer): SizeInt;

{**
 * Unique<T> - 去重算法 (数组必须已排序)
 *
 * @param aArr      已排序的数组
 * @param aCompare  比较函数
 * @param aData     用户数据
 * @return          去重后的新长度
 *}
generic function Unique<T>(var aArr: array of T;
  aCompare: specialize TAlgoCompareFunc<T>; aData: Pointer): SizeInt;

{**
 * RotateLeft<T> - 左旋转
 *
 * @param aArr    数组
 * @param aCount  旋转位数
 *}
generic procedure RotateLeft<T>(var aArr: array of T; aCount: SizeUInt);

{**
 * RotateRight<T> - 右旋转
 *
 * @param aArr    数组
 * @param aCount  旋转位数
 *}
generic procedure RotateRight<T>(var aArr: array of T; aCount: SizeUInt);

{ === Phase 4: 新算法扩展 === }

{**
 * IsSorted<T> - 检查数组是否已排序
 *}
generic function IsSorted<T>(const aArr: array of T;
  aCompare: specialize TAlgoCompareFunc<T>; aData: Pointer): Boolean;

{**
 * MinElement<T> - 查找最小元素索引
 *}
generic function MinElement<T>(const aArr: array of T;
  aCompare: specialize TAlgoCompareFunc<T>; aData: Pointer; out aIndex: SizeInt): Boolean;

{**
 * MaxElement<T> - 查找最大元素索引
 *}
generic function MaxElement<T>(const aArr: array of T;
  aCompare: specialize TAlgoCompareFunc<T>; aData: Pointer; out aIndex: SizeInt): Boolean;

{**
 * AllOf<T> - 检查所有元素是否都满足谓词
 *}
generic function AllOf<T>(const aArr: array of T;
  aPredicate: specialize TAlgoPredicateFunc<T>; aData: Pointer): Boolean;

{**
 * AnyOf<T> - 检查是否有任一元素满足谓词
 *}
generic function AnyOf<T>(const aArr: array of T;
  aPredicate: specialize TAlgoPredicateFunc<T>; aData: Pointer): Boolean;

{**
 * NoneOf<T> - 检查是否没有元素满足谓词
 *}
generic function NoneOf<T>(const aArr: array of T;
  aPredicate: specialize TAlgoPredicateFunc<T>; aData: Pointer): Boolean;

{**
 * StableSort<T> - 稳定排序算法 (MergeSort)
 *}
generic procedure StableSort<T>(var aArr: array of T;
  aCompare: specialize TAlgoCompareFunc<T>; aData: Pointer);

{**
 * Merge<T> - 合并两个有序数组
 *}
generic function Merge<T>(const aFirst, aSecond: array of T;
  aCompare: specialize TAlgoCompareFunc<T>; aData: Pointer): specialize TGenericArray<T>;

{**
 * SortInt32 - 特化的 Int32 IntroSort (无函数指针开销)
 *
 * @param aArr  要排序的 Int32 数组
 *}
procedure SortInt32(var aArr: array of Int32);

const
  { Visible to interface generics; keep private by naming convention. }
  _INSERTION_SORT_THRESHOLD = 16;

{ Internal helpers - do not use directly }
generic procedure _Swap<T>(var A, B: T); inline;
generic procedure _ReverseRange<T>(var aArr: array of T; aLo, aHi: SizeInt);
generic procedure _InsertionSortImpl<T>(var aArr: array of T; aLo, aHi: SizeInt;
  aCompare: specialize TAlgoCompareFunc<T>; aData: Pointer);
generic procedure _SiftDownImpl<T>(var aArr: array of T; aStart, aEnd: SizeInt;
  aCompare: specialize TAlgoCompareFunc<T>; aData: Pointer);
generic procedure _HeapSortImpl<T>(var aArr: array of T; aLo, aHi: SizeInt;
  aCompare: specialize TAlgoCompareFunc<T>; aData: Pointer);
generic function _MedianOfThreeIdx<T>(const aArr: array of T; aLo, aMid, aHi: SizeInt;
  aCompare: specialize TAlgoCompareFunc<T>; aData: Pointer): SizeInt;
generic procedure _IntroSortImpl<T>(var aArr: array of T; aLo, aHi: SizeInt;
  aDepthLimit: SizeInt; aCompare: specialize TAlgoCompareFunc<T>; aData: Pointer);

implementation

{ Internal helper: swap two elements }
generic procedure _Swap<T>(var A, B: T);
var
  Tmp: T;
begin
  Tmp := A;
  A := B;
  B := Tmp;
end;

{ Internal helper: reverse a range }
generic procedure _ReverseRange<T>(var aArr: array of T; aLo, aHi: SizeInt);
begin
  while aLo < aHi do
  begin
    specialize _Swap<T>(aArr[aLo], aArr[aHi]);
    Inc(aLo);
    Dec(aHi);
  end;
end;

{ Insertion sort for small partitions }
generic procedure _InsertionSortImpl<T>(var aArr: array of T; aLo, aHi: SizeInt;
  aCompare: specialize TAlgoCompareFunc<T>; aData: Pointer);
var
  I, J: SizeInt;
  Tmp: T;
begin
  for I := aLo + 1 to aHi do
  begin
    Tmp := aArr[I];
    J := I - 1;
    while (J >= aLo) and (aCompare(aArr[J], Tmp, aData) > 0) do
    begin
      aArr[J + 1] := aArr[J];
      Dec(J);
    end;
    aArr[J + 1] := Tmp;
  end;
end;

{ Heapsort sift-down }
generic procedure _SiftDownImpl<T>(var aArr: array of T; aStart, aEnd: SizeInt;
  aCompare: specialize TAlgoCompareFunc<T>; aData: Pointer);
var
  LRoot, LChild, LSwap: SizeInt;
begin
  LRoot := aStart;
  while True do
  begin
    LChild := 2 * LRoot + 1;
    if LChild > aEnd then Break;
    LSwap := LRoot;
    if aCompare(aArr[LSwap], aArr[LChild], aData) < 0 then
      LSwap := LChild;
    if (LChild + 1 <= aEnd) and (aCompare(aArr[LSwap], aArr[LChild + 1], aData) < 0) then
      LSwap := LChild + 1;
    if LSwap = LRoot then Break;
    specialize _Swap<T>(aArr[LRoot], aArr[LSwap]);
    LRoot := LSwap;
  end;
end;

{ Heapsort — guaranteed O(n log n) worst case }
generic procedure _HeapSortImpl<T>(var aArr: array of T; aLo, aHi: SizeInt;
  aCompare: specialize TAlgoCompareFunc<T>; aData: Pointer);
var
  I: SizeInt;
begin
  for I := (aLo + aHi) div 2 downto aLo do
    specialize _SiftDownImpl<T>(aArr, I, aHi, aCompare, aData);
  for I := aHi downto aLo + 1 do
  begin
    specialize _Swap<T>(aArr[aLo], aArr[I]);
    specialize _SiftDownImpl<T>(aArr, aLo, I - 1, aCompare, aData);
  end;
end;

{ Median-of-three pivot selection }
generic function _MedianOfThreeIdx<T>(const aArr: array of T; aLo, aMid, aHi: SizeInt;
  aCompare: specialize TAlgoCompareFunc<T>; aData: Pointer): SizeInt;
begin
  if aCompare(aArr[aLo], aArr[aMid], aData) < 0 then
  begin
    if aCompare(aArr[aMid], aArr[aHi], aData) < 0 then
      Result := aMid
    else if aCompare(aArr[aLo], aArr[aHi], aData) < 0 then
      Result := aHi
    else
      Result := aLo;
  end
  else
  begin
    if aCompare(aArr[aLo], aArr[aHi], aData) < 0 then
      Result := aLo
    else if aCompare(aArr[aMid], aArr[aHi], aData) < 0 then
      Result := aHi
    else
      Result := aMid;
  end;
end;

{ IntroSort — QuickSort + InsertionSort + HeapSort fallback
  pdqsort-inspired: top-level sorted detection, Tukey ninther pivot }
generic procedure _IntroSortImpl<T>(var aArr: array of T; aLo, aHi: SizeInt;
  aDepthLimit: SizeInt; aCompare: specialize TAlgoCompareFunc<T>; aData: Pointer);
var
  I, J, PivotIdx, Mid, N: SizeInt;
  Pivot: T;
  AlreadySorted: Boolean;
begin
  { Top-level sorted/revsorted detection (only for large ranges) }
  N := aHi - aLo;
  if N > _INSERTION_SORT_THRESHOLD then
  begin
    AlreadySorted := True;
    for I := aLo + 1 to aHi do
    begin
      if aCompare(aArr[I - 1], aArr[I], aData) > 0 then
      begin
        AlreadySorted := False;
        Break;
      end;
    end;
    if AlreadySorted then Exit;
    { Check reverse-sorted }
    AlreadySorted := True;
    for I := aLo + 1 to aHi do
    begin
      if aCompare(aArr[I - 1], aArr[I], aData) < 0 then
      begin
        AlreadySorted := False;
        Break;
      end;
    end;
    if AlreadySorted then
    begin
      specialize _ReverseRange<T>(aArr, aLo, aHi);
      Exit;
    end;
  end;

  while aHi - aLo > _INSERTION_SORT_THRESHOLD do
  begin
    if aDepthLimit = 0 then
    begin
      specialize _HeapSortImpl<T>(aArr, aLo, aHi, aCompare, aData);
      Exit;
    end;
    Dec(aDepthLimit);

    { Pivot selection: Tukey's ninther for large, median-of-three otherwise }
    Mid := aLo + (aHi - aLo) div 2;
    if aHi - aLo > 128 then
    begin
      { Tukey's ninther: median of three medians-of-three }
      N := (aHi - aLo) div 8;
      PivotIdx := specialize _MedianOfThreeIdx<T>(aArr,
        specialize _MedianOfThreeIdx<T>(aArr, aLo, aLo + N, aLo + 2 * N, aCompare, aData),
        specialize _MedianOfThreeIdx<T>(aArr, Mid - N, Mid, Mid + N, aCompare, aData),
        specialize _MedianOfThreeIdx<T>(aArr, aHi - 2 * N, aHi - N, aHi, aCompare, aData),
        aCompare, aData);
    end
    else
      PivotIdx := specialize _MedianOfThreeIdx<T>(aArr, aLo, Mid, aHi, aCompare, aData);
    Pivot := aArr[PivotIdx];

    { Hoare partition }
    I := aLo;
    J := aHi;
    repeat
      while aCompare(aArr[I], Pivot, aData) < 0 do Inc(I);
      while aCompare(aArr[J], Pivot, aData) > 0 do Dec(J);
      if I <= J then
      begin
        specialize _Swap<T>(aArr[I], aArr[J]);
        Inc(I);
        Dec(J);
      end;
    until I > J;

    { Recurse on smaller partition, iterate on larger (tail call elimination) }
    if J - aLo < aHi - J then
    begin
      specialize _IntroSortImpl<T>(aArr, aLo, J, aDepthLimit, aCompare, aData);
      aLo := I;
    end
    else
    begin
      specialize _IntroSortImpl<T>(aArr, I, aHi, aDepthLimit, aCompare, aData);
      aHi := J;
    end;
  end;

  { Insertion sort for small partition }
  specialize _InsertionSortImpl<T>(aArr, aLo, aHi, aCompare, aData);
end;

{ Sort<T> — IntroSort: O(n log n) guaranteed, fast on all inputs }
generic procedure Sort<T>(var aArr: array of T; aCompare: specialize TAlgoCompareFunc<T>; aData: Pointer);
var
  N, DepthLimit: SizeInt;
begin
  N := Length(aArr);
  if N <= 1 then Exit;
  DepthLimit := 1;
  while (1 shl DepthLimit) < N do
    Inc(DepthLimit);
  specialize _IntroSortImpl<T>(aArr, 0, High(aArr), DepthLimit * 2, aCompare, aData);
end;

{ BinarySearch<T> }
generic function BinarySearch<T>(const aArr: array of T; const aValue: T;
  aCompare: specialize TAlgoCompareFunc<T>; aData: Pointer; out aIndex: SizeInt): Boolean;
var
  Lo, Hi, Mid: SizeInt;
  Cmp: SizeInt;
begin
  aIndex := -1;
  if Length(aArr) = 0 then Exit(False);

  Lo := 0;
  Hi := High(aArr);

  while Lo <= Hi do
  begin
    Mid := Lo + (Hi - Lo) div 2;
    Cmp := aCompare(aArr[Mid], aValue, aData);

    if Cmp = 0 then
    begin
      aIndex := Mid;
      Exit(True);
    end
    else if Cmp < 0 then
      Lo := Mid + 1
    else
      Hi := Mid - 1;
  end;

  Result := False;
end;

{ LowerBound<T> - first index where aArr[idx] >= aValue (insert position) }
generic function LowerBound<T>(const aArr: array of T; const aValue: T;
  aCompare: specialize TAlgoCompareFunc<T>; aData: Pointer): SizeInt;
var
  Lo, Hi, Mid: SizeInt;
  Cmp: SizeInt;
begin
  // perf: O(log n) lower_bound single source via aCompare, zero-copy, inline candidates reuse CompareDriverEntry
  Lo := 0;
  Hi := Length(aArr);
  while Lo < Hi do
  begin
    Mid := Lo + (Hi - Lo) div 2;
    Cmp := aCompare(aArr[Mid], aValue, aData);
    if Cmp < 0 then
      Lo := Mid + 1
    else
      Hi := Mid;
  end;
  Result := Lo;
end;

{ FindIf<T> }
generic function FindIf<T>(const aArr: array of T;
  aPredicate: specialize TAlgoPredicateFunc<T>; aData: Pointer; out aIndex: SizeInt): Boolean;
var
  i: SizeInt;
begin
  aIndex := -1;
  for i := 0 to High(aArr) do
  begin
    if aPredicate(aArr[i], aData) then
    begin
      aIndex := i;
      Exit(True);
    end;
  end;
  Result := False;
end;

{ Partition<T> }
generic function Partition<T>(var aArr: array of T;
  aPredicate: specialize TAlgoPredicateFunc<T>; aData: Pointer): SizeInt;
var
  i, j: SizeInt;
begin
  if Length(aArr) = 0 then Exit(0);

  i := 0;
  j := High(aArr);

  while True do
  begin
    // Find first element that doesn't match predicate
    while (i <= j) and aPredicate(aArr[i], aData) do
      Inc(i);

    // Find last element that matches predicate
    while (j >= i) and not aPredicate(aArr[j], aData) do
      Dec(j);

    if i >= j then Break;

    specialize _Swap<T>(aArr[i], aArr[j]);
    Inc(i);
    Dec(j);
  end;

  Result := i;
end;

{ Unique<T> }
generic function Unique<T>(var aArr: array of T;
  aCompare: specialize TAlgoCompareFunc<T>; aData: Pointer): SizeInt;
var
  i, WritePos: SizeInt;
begin
  if Length(aArr) = 0 then Exit(0);
  if Length(aArr) = 1 then Exit(1);

  WritePos := 1;
  for i := 1 to High(aArr) do
  begin
    if aCompare(aArr[i], aArr[WritePos - 1], aData) <> 0 then
    begin
      if WritePos <> i then
        aArr[WritePos] := aArr[i];
      Inc(WritePos);
    end;
  end;

  Result := WritePos;
end;

{ RotateLeft<T> }
generic procedure RotateLeft<T>(var aArr: array of T; aCount: SizeUInt);
var
  Len: SizeInt;
  EffectiveCount: SizeUInt;
begin
  Len := Length(aArr);
  if (Len <= 1) or (aCount = 0) then Exit;

  EffectiveCount := aCount mod SizeUInt(Len);
  if EffectiveCount = 0 then Exit;

  // Reverse first part, reverse second part, reverse all
  specialize _ReverseRange<T>(aArr, 0, EffectiveCount - 1);
  specialize _ReverseRange<T>(aArr, EffectiveCount, Len - 1);
  specialize _ReverseRange<T>(aArr, 0, Len - 1);
end;

{ RotateRight<T> }
generic procedure RotateRight<T>(var aArr: array of T; aCount: SizeUInt);
var
  Len: SizeInt;
  EffectiveCount: SizeUInt;
begin
  Len := Length(aArr);
  if (Len <= 1) or (aCount = 0) then Exit;

  EffectiveCount := aCount mod SizeUInt(Len);
  if EffectiveCount = 0 then Exit;

  // Rotate right by N = Rotate left by (Len - N)
  specialize RotateLeft<T>(aArr, SizeUInt(Len) - EffectiveCount);
end;

{ Phase 4: IsSorted<T> }
generic function IsSorted<T>(const aArr: array of T;
  aCompare: specialize TAlgoCompareFunc<T>; aData: Pointer): Boolean;
var
  i: SizeInt;
begin
  if Length(aArr) <= 1 then Exit(True);
  for i := 0 to High(aArr) - 1 do
    if aCompare(aArr[i], aArr[i + 1], aData) > 0 then Exit(False);
  Result := True;
end;

{ Phase 4: MinElement<T> }
generic function MinElement<T>(const aArr: array of T;
  aCompare: specialize TAlgoCompareFunc<T>; aData: Pointer; out aIndex: SizeInt): Boolean;
var
  i, MinIdx: SizeInt;
begin
  aIndex := -1;
  if Length(aArr) = 0 then Exit(False);
  MinIdx := 0;
  for i := 1 to High(aArr) do
    if aCompare(aArr[i], aArr[MinIdx], aData) < 0 then MinIdx := i;
  aIndex := MinIdx;
  Result := True;
end;

{ Phase 4: MaxElement<T> }
generic function MaxElement<T>(const aArr: array of T;
  aCompare: specialize TAlgoCompareFunc<T>; aData: Pointer; out aIndex: SizeInt): Boolean;
var
  i, MaxIdx: SizeInt;
begin
  aIndex := -1;
  if Length(aArr) = 0 then Exit(False);
  MaxIdx := 0;
  for i := 1 to High(aArr) do
    if aCompare(aArr[i], aArr[MaxIdx], aData) > 0 then MaxIdx := i;
  aIndex := MaxIdx;
  Result := True;
end;

{ Phase 4: AllOf<T> }
generic function AllOf<T>(const aArr: array of T;
  aPredicate: specialize TAlgoPredicateFunc<T>; aData: Pointer): Boolean;
var
  i: SizeInt;
begin
  for i := 0 to High(aArr) do
    if not aPredicate(aArr[i], aData) then Exit(False);
  Result := True;
end;

{ Phase 4: AnyOf<T> }
generic function AnyOf<T>(const aArr: array of T;
  aPredicate: specialize TAlgoPredicateFunc<T>; aData: Pointer): Boolean;
var
  i: SizeInt;
begin
  for i := 0 to High(aArr) do
    if aPredicate(aArr[i], aData) then Exit(True);
  Result := False;
end;

{ Phase 4: NoneOf<T> }
generic function NoneOf<T>(const aArr: array of T;
  aPredicate: specialize TAlgoPredicateFunc<T>; aData: Pointer): Boolean;
var
  i: SizeInt;
begin
  for i := 0 to High(aArr) do
    if aPredicate(aArr[i], aData) then Exit(False);
  Result := True;
end;

{ Phase 4: StableSort<T> - MergeSort }
generic procedure StableSort<T>(var aArr: array of T;
  aCompare: specialize TAlgoCompareFunc<T>; aData: Pointer);

  procedure MergeSort(var aArr: array of T; aLo, aHi: SizeInt; var aTmp: array of T);
  var
    Mid, i, j, k: SizeInt;
  begin
    if aLo >= aHi then Exit;
    Mid := aLo + (aHi - aLo) div 2;
    MergeSort(aArr, aLo, Mid, aTmp);
    MergeSort(aArr, Mid + 1, aHi, aTmp);
    if aCompare(aArr[Mid], aArr[Mid + 1], aData) <= 0 then Exit;
    for i := aLo to aHi do aTmp[i] := aArr[i];
    i := aLo; j := Mid + 1; k := aLo;
    while (i <= Mid) and (j <= aHi) do
    begin
      if aCompare(aTmp[i], aTmp[j], aData) <= 0 then
      begin aArr[k] := aTmp[i]; Inc(i); end
      else
      begin aArr[k] := aTmp[j]; Inc(j); end;
      Inc(k);
    end;
    while i <= Mid do begin aArr[k] := aTmp[i]; Inc(i); Inc(k); end;
  end;

var
  Tmp: array of T;
begin
  if Length(aArr) <= 1 then Exit;
  Tmp := nil;
  SetLength(Tmp, Length(aArr));
  MergeSort(aArr, 0, High(aArr), Tmp);
end;

{ Phase 4: Merge<T> }
generic function Merge<T>(const aFirst, aSecond: array of T;
  aCompare: specialize TAlgoCompareFunc<T>; aData: Pointer): specialize TGenericArray<T>;
var
  LenA, LenB, i, j, k: SizeInt;
begin
  Result := nil;
  LenA := Length(aFirst); LenB := Length(aSecond);
  if LenA + LenB = 0 then Exit;
  SetLength(Result, LenA + LenB);
  i := 0; j := 0; k := 0;
  while (i < LenA) and (j < LenB) do
  begin
    if aCompare(aFirst[i], aSecond[j], aData) <= 0 then
    begin Result[k] := aFirst[i]; Inc(i); end
    else
    begin Result[k] := aSecond[j]; Inc(j); end;
    Inc(k);
  end;
  while i < LenA do begin Result[k] := aFirst[i]; Inc(i); Inc(k); end;
  while j < LenB do begin Result[k] := aSecond[j]; Inc(j); Inc(k); end;
end;

{ SortInt32 — specialized IntroSort for Int32 without function pointer overhead }
procedure _InsertionSortInt32(var aArr: array of Int32; aLo, aHi: SizeInt);
var
  I, J: SizeInt;
  Tmp: Int32;
begin
  for I := aLo + 1 to aHi do
  begin
    Tmp := aArr[I];
    J := I - 1;
    while (J >= aLo) and (aArr[J] > Tmp) do
    begin
      aArr[J + 1] := aArr[J];
      Dec(J);
    end;
    aArr[J + 1] := Tmp;
  end;
end;

procedure _SiftDownInt32(var aArr: array of Int32; aStart, aEnd: SizeInt);
var
  LRoot, LChild, LSwap: SizeInt;
begin
  LRoot := aStart;
  while True do
  begin
    LChild := 2 * LRoot + 1;
    if LChild > aEnd then Break;
    LSwap := LRoot;
    if aArr[LSwap] < aArr[LChild] then
      LSwap := LChild;
    if (LChild + 1 <= aEnd) and (aArr[LSwap] < aArr[LChild + 1]) then
      LSwap := LChild + 1;
    if LSwap = LRoot then Break;
    aArr[LRoot] := aArr[LRoot] xor aArr[LSwap];
    aArr[LSwap] := aArr[LRoot] xor aArr[LSwap];
    aArr[LRoot] := aArr[LRoot] xor aArr[LSwap];
    LRoot := LSwap;
  end;
end;

procedure _HeapSortInt32(var aArr: array of Int32; aLo, aHi: SizeInt);
var
  I: SizeInt;
begin
  for I := (aLo + aHi) div 2 downto aLo do
    _SiftDownInt32(aArr, I, aHi);
  for I := aHi downto aLo + 1 do
  begin
    aArr[aLo] := aArr[aLo] xor aArr[I];
    aArr[I] := aArr[aLo] xor aArr[I];
    aArr[aLo] := aArr[aLo] xor aArr[I];
    _SiftDownInt32(aArr, aLo, I - 1);
  end;
end;

procedure _IntroSortInt32(var aArr: array of Int32; aLo, aHi: SizeInt; aDepthLimit: SizeInt);
var
  I, J, Mid, PivotIdx, N: SizeInt;
  Pivot, Tmp: Int32;
begin
  while aHi - aLo > 16 do
  begin
    if aDepthLimit = 0 then
    begin
      _HeapSortInt32(aArr, aLo, aHi);
      Exit;
    end;
    Dec(aDepthLimit);

    { Pivot: Tukey's ninther for large, median-of-three otherwise }
    Mid := aLo + (aHi - aLo) div 2;
    if aHi - aLo > 128 then
    begin
      N := (aHi - aLo) div 8;
      PivotIdx := aLo + N;
      if aArr[aLo] < aArr[aLo + N] then
      begin
        if aArr[aLo + N] < aArr[aLo + 2*N] then PivotIdx := aLo + N
        else if aArr[aLo] < aArr[aLo + 2*N] then PivotIdx := aLo + 2*N
        else PivotIdx := aLo;
      end
      else
      begin
        if aArr[aLo] < aArr[aLo + 2*N] then PivotIdx := aLo
        else if aArr[aLo + N] < aArr[aLo + 2*N] then PivotIdx := aLo + 2*N;
      end;
      I := PivotIdx; { save first median }

      PivotIdx := Mid - N;
      if aArr[Mid - N] < aArr[Mid] then
      begin
        if aArr[Mid] < aArr[Mid + N] then PivotIdx := Mid
        else if aArr[Mid - N] < aArr[Mid + N] then PivotIdx := Mid + N
        else PivotIdx := Mid - N;
      end
      else
      begin
        if aArr[Mid - N] < aArr[Mid + N] then PivotIdx := Mid - N
        else if aArr[Mid] < aArr[Mid + N] then PivotIdx := Mid + N;
      end;
      J := PivotIdx; { save second median }

      PivotIdx := aHi - 2*N;
      if aArr[aHi - 2*N] < aArr[aHi - N] then
      begin
        if aArr[aHi - N] < aArr[aHi] then PivotIdx := aHi - N
        else if aArr[aHi - 2*N] < aArr[aHi] then PivotIdx := aHi
        else PivotIdx := aHi - 2*N;
      end
      else
      begin
        if aArr[aHi - 2*N] < aArr[aHi] then PivotIdx := aHi - 2*N
        else if aArr[aHi - N] < aArr[aHi] then PivotIdx := aHi;
      end;
      { median of three medians }
      if aArr[I] < aArr[J] then
      begin
        if aArr[J] < aArr[PivotIdx] then PivotIdx := J
        else if aArr[I] < aArr[PivotIdx] then { keep PivotIdx }
        else PivotIdx := I;
      end
      else
      begin
        if aArr[I] < aArr[PivotIdx] then PivotIdx := I
        else if aArr[J] < aArr[PivotIdx] then { keep PivotIdx }
        else PivotIdx := J;
      end;
    end
    else
    begin
      { Median-of-three }
      if aArr[aLo] < aArr[Mid] then
      begin
        if aArr[Mid] < aArr[aHi] then PivotIdx := Mid
        else if aArr[aLo] < aArr[aHi] then PivotIdx := aHi
        else PivotIdx := aLo;
      end
      else
      begin
        if aArr[aLo] < aArr[aHi] then PivotIdx := aLo
        else if aArr[Mid] < aArr[aHi] then PivotIdx := aHi
        else PivotIdx := Mid;
      end;
    end;
    Pivot := aArr[PivotIdx];

    { Hoare partition }
    I := aLo;
    J := aHi;
    repeat
      while aArr[I] < Pivot do Inc(I);
      while aArr[J] > Pivot do Dec(J);
      if I <= J then
      begin
        Tmp := aArr[I]; aArr[I] := aArr[J]; aArr[J] := Tmp;
        Inc(I);
        Dec(J);
      end;
    until I > J;

    { Tail call elimination: recurse on smaller partition }
    if J - aLo < aHi - J then
    begin
      _IntroSortInt32(aArr, aLo, J, aDepthLimit);
      aLo := I;
    end
    else
    begin
      _IntroSortInt32(aArr, I, aHi, aDepthLimit);
      aHi := J;
    end;
  end;

  _InsertionSortInt32(aArr, aLo, aHi);
end;

procedure SortInt32(var aArr: array of Int32);
var
  N, DepthLimit: SizeInt;
begin
  N := Length(aArr);
  if N <= 1 then Exit;
  DepthLimit := 1;
  while (1 shl DepthLimit) < N do
    Inc(DepthLimit);
  _IntroSortInt32(aArr, 0, High(aArr), DepthLimit * 2);
end;

end.
