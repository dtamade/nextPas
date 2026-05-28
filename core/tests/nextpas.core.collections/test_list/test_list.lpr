program test_list;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.collections,
  nextpas.core.collections.base,
  nextpas.core.collections.list.intf;

type
  IIntList = specialize IList<Integer>;

var
  T: TTestRunner;

procedure TestPushFrontPopFront;
var
  LL: IIntList;
begin
  LL := specialize MakeList<Integer>;
  LL.PushFront(1);
  LL.PushFront(2);
  LL.PushFront(3);
  CheckEqual(Int64(3), Int64(LL.GetCount), 'count');
  CheckEqual(Int64(3), Int64(LL.PopFront), 'pop front LIFO');
  CheckEqual(Int64(2), Int64(LL.PopFront), 'pop front 2');
  CheckEqual(Int64(1), Int64(LL.PopFront), 'pop front 3');
  Check(LL.IsEmpty, 'empty after all pops');
end;

procedure TestPushBackPopBack;
var
  LL: IIntList;
begin
  LL := specialize MakeList<Integer>;
  LL.PushBack(10);
  LL.PushBack(20);
  LL.PushBack(30);
  CheckEqual(Int64(30), Int64(LL.PopBack), 'pop back LIFO');
  CheckEqual(Int64(20), Int64(LL.PopBack), 'pop back 2');
  CheckEqual(Int64(10), Int64(LL.PopBack), 'pop back 3');
end;

procedure TestFrontBack;
var
  LL: IIntList;
begin
  LL := specialize MakeList<Integer>;
  LL.PushBack(1);
  LL.PushBack(2);
  LL.PushBack(3);
  CheckEqual(Int64(1), Int64(LL.Front), 'front');
  CheckEqual(Int64(3), Int64(LL.Back), 'back');
  CheckEqual(Int64(3), Int64(LL.GetCount), 'front/back do not remove');
end;

procedure TestTryFrontTryBack;
var
  LL: IIntList;
  LVal: Integer;
begin
  LL := specialize MakeList<Integer>;
  Check(not LL.TryFront(LVal), 'try front on empty');
  Check(not LL.TryBack(LVal), 'try back on empty');
  LL.PushBack(42);
  Check(LL.TryFront(LVal), 'try front succeeds');
  CheckEqual(Int64(42), Int64(LVal), 'try front value');
  Check(LL.TryBack(LVal), 'try back succeeds');
  CheckEqual(Int64(42), Int64(LVal), 'try back value');
end;

procedure TestTryPopFrontTryPopBack;
var
  LL: IIntList;
  LVal: Integer;
begin
  LL := specialize MakeList<Integer>;
  Check(not LL.TryPopFront(LVal), 'try pop front on empty');
  Check(not LL.TryPopBack(LVal), 'try pop back on empty');
  LL.PushBack(10);
  LL.PushBack(20);
  Check(LL.TryPopFront(LVal), 'try pop front');
  CheckEqual(Int64(10), Int64(LVal), 'pop front value');
  Check(LL.TryPopBack(LVal), 'try pop back');
  CheckEqual(Int64(20), Int64(LVal), 'pop back value');
  Check(LL.IsEmpty, 'empty');
end;

procedure TestMixedPushPop;
var
  LL: IIntList;
begin
  LL := specialize MakeList<Integer>;
  LL.PushFront(2);
  LL.PushBack(3);
  LL.PushFront(1);
  LL.PushBack(4);
  CheckEqual(Int64(4), Int64(LL.GetCount), 'count');
  CheckEqual(Int64(1), Int64(LL.Front), 'front is 1');
  CheckEqual(Int64(4), Int64(LL.Back), 'back is 4');
  CheckEqual(Int64(1), Int64(LL.PopFront), 'pop 1');
  CheckEqual(Int64(4), Int64(LL.PopBack), 'pop 4');
  CheckEqual(Int64(2), Int64(LL.PopFront), 'pop 2');
  CheckEqual(Int64(3), Int64(LL.PopBack), 'pop 3');
end;

procedure TestClear;
var
  LL: IIntList;
begin
  LL := specialize MakeList<Integer>;
  LL.PushBack(1);
  LL.PushBack(2);
  LL.PushBack(3);
  LL.Clear;
  Check(LL.IsEmpty, 'empty after clear');
  CheckEqual(Int64(0), Int64(LL.GetCount), 'count 0');
end;

procedure TestStringType;
var
  LS: specialize IList<string>;
  LVal: string;
begin
  LS := specialize MakeList<string>;
  LS.PushBack('hello');
  LS.PushBack('world');
  CheckEqual(Int64(2), Int64(LS.GetCount), 'string list count');
  Check(LS.TryPopFront(LVal), 'pop string');
  CheckEqual('hello', LVal, 'string value');
end;

procedure TestTryLoadFromTryAppend;
var
  LL: IIntList;
  LSrc: specialize IList<Integer>;
begin
  LL := specialize MakeList<Integer>;
  LSrc := specialize MakeList<Integer>;
  LSrc.PushBack(10);
  LSrc.PushBack(20);
  LSrc.PushBack(30);
  Check(LL.TryLoadFrom(LSrc as TCollection), 'try load from');
  CheckEqual(Int64(3), Int64(LL.GetCount), 'loaded count');

  LSrc.Clear;
  LSrc.PushBack(40);
  LSrc.PushBack(50);
  Check(LL.TryAppend(LSrc as TCollection), 'try append');
  CheckEqual(Int64(5), Int64(LL.GetCount), 'appended count');
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.list');
  T.Run('PushFront/PopFront', @TestPushFrontPopFront);
  T.Run('PushBack/PopBack', @TestPushBackPopBack);
  T.Run('Front/Back', @TestFrontBack);
  T.Run('TryFront/TryBack', @TestTryFrontTryBack);
  T.Run('TryPopFront/TryPopBack', @TestTryPopFrontTryPopBack);
  T.Run('Mixed Push/Pop', @TestMixedPushPop);
  T.Run('Clear', @TestClear);
  T.Run('String type (leak check)', @TestStringType);
  T.Run('TryLoadFrom/TryAppend', @TestTryLoadFromTryAppend);
  T.Summary;
end.
