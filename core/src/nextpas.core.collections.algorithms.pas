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
  SysUtils,
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

{ Internal helpers - do not use directly }
generic procedure _Swap<T>(var A, B: T); inline;
generic procedure _ReverseRange<T>(var aArr: array of T; aLo, aHi: SizeInt);
generic procedure _QuickSortImpl<T>(var aArr: array of T; aLo, aHi: SizeInt;
  aCompare: specialize TAlgoCompareFunc<T>; aData: Pointer);

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

{ QuickSort implementation }
generic procedure _QuickSortImpl<T>(var aArr: array of T; aLo, aHi: SizeInt;
  aCompare: specialize TAlgoCompareFunc<T>; aData: Pointer);
var
  i, j: SizeInt;
  Pivot: T;
begin
  if aLo >= aHi then Exit;

  i := aLo;
  j := aHi;
  Pivot := aArr[(aLo + aHi) div 2];

  repeat
    while aCompare(aArr[i], Pivot, aData) < 0 do Inc(i);
    while aCompare(aArr[j], Pivot, aData) > 0 do Dec(j);

    if i <= j then
    begin
      specialize _Swap<T>(aArr[i], aArr[j]);
      Inc(i);
      Dec(j);
    end;
  until i > j;

  if aLo < j then specialize _QuickSortImpl<T>(aArr, aLo, j, aCompare, aData);
  if i < aHi then specialize _QuickSortImpl<T>(aArr, i, aHi, aCompare, aData);
end;

{ Sort<T> }
generic procedure Sort<T>(var aArr: array of T; aCompare: specialize TAlgoCompareFunc<T>; aData: Pointer);
begin
  if Length(aArr) <= 1 then Exit;
  specialize _QuickSortImpl<T>(aArr, 0, High(aArr), aCompare, aData);
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

end.
