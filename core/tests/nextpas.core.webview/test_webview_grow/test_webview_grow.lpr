program test_webview_grow;
{ VecGrowCapacity 单源容量门禁（base 纯类型已下沉至 bytes.ops 单源）：0→4→2× 同构语义
  + Count 精确追加/移除/Close 仿真（驱动 wk FPendingEvals 家族逻辑）。
  heaptrc 0 unfreed 硬门。perf: bytes.ops VecGrowCapacity inline 单源零额外调用 }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.bytes.ops;

procedure TestGrowCapacityTable;
begin
  CheckEqual(4, VecGrowCapacity(0));
  CheckEqual(2, VecGrowCapacity(1));
  CheckEqual(4, VecGrowCapacity(2));
  CheckEqual(6, VecGrowCapacity(3));
  CheckEqual(8, VecGrowCapacity(4));
  CheckEqual(10, VecGrowCapacity(5));
  CheckEqual(14, VecGrowCapacity(7));
  CheckEqual(16, VecGrowCapacity(8));
  CheckEqual(32, VecGrowCapacity(16));
  CheckEqual(200, VecGrowCapacity(100));
  CheckEqual(0, VecGrowCapacity(0) - 4);
end;

procedure TestGrowSequenceCountPrecise;
var
  Arr: array of Integer;
  Count, I, Cap: Integer;
begin
  Count := 0;
  Arr := nil;
  for I := 1 to 9 do
  begin
    if Count = Length(Arr) then
      SetLength(Arr, VecGrowCapacity(Length(Arr)));
    Arr[Count] := I * 10;
    Inc(Count);
  end;
  CheckEqual(9, Count);
  Cap := Length(Arr);
  CheckEqual(16, Cap);
  for I := 0 to Count - 1 do
    CheckEqual((I+1)*10, Arr[I]);
  for I := Count to Cap - 1 do
    CheckEqual(0, Arr[I]);
end;

procedure TestGrowRemoveShiftSemantics;
var
  Arr: array of Integer;
  Count, I, J: Integer;
begin
  Count := 0;
  Arr := nil;
  for I := 1 to 6 do
  begin
    if Count = Length(Arr) then
      SetLength(Arr, VecGrowCapacity(Length(Arr)));
    Arr[Count] := I;
    Inc(Count);
  end;
  CheckEqual(6, Count);
  // 移除索引2 (值3)
  for J := 2 to Count - 2 do
    Arr[J] := Arr[J+1];
  Dec(Count);
  if Count < Length(Arr) then
    Arr[Count] := 0;
  CheckEqual(5, Count);
  CheckEqual(1, Arr[0]); CheckEqual(2, Arr[1]); CheckEqual(4, Arr[2]);
  CheckEqual(5, Arr[3]); CheckEqual(6, Arr[4]);
  CheckEqual(0, Arr[5]);
  // 移除首元素
  for J := 0 to Count - 2 do
    Arr[J] := Arr[J+1];
  Dec(Count);
  if Count < Length(Arr) then
    Arr[Count] := 0;
  CheckEqual(4, Count);
  CheckEqual(2, Arr[0]); CheckEqual(4, Arr[1]);
  // Close 语义：清空 Count 保留容量
  Count := 0;
  CheckEqual(0, Count);
  Check(Length(Arr) >= 4, 'capacity retained after Close');
end;

procedure TestGrowZeroToFourBoundary;
var
  Empty: array of Integer;
begin
  Empty := nil;
  CheckEqual(4, VecGrowCapacity(0));
  CheckEqual(4, VecGrowCapacity(Length(Empty)));
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.webview.grow');
  T.Test('VecGrowCapacity table 0->4->2x', @TestGrowCapacityTable);
  T.Test('grow sequence Count precise', @TestGrowSequenceCountPrecise);
  T.Test('grow remove shift Count semantics', @TestGrowRemoveShiftSemantics);
  T.Test('zero to four boundary', @TestGrowZeroToFourBoundary);
  if not T.Run then Halt(1);
end.
