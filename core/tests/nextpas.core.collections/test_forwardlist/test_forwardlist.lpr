program test_forwardlist;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.collections,
  nextpas.core.collections.base,
  nextpas.core.collections.forward_list.intf,
  nextpas.core.collections.forward_list;

type
  IIntFList = specialize IForwardList<Integer>;
  TIntFList = specialize TForwardList<Integer>;
  TIntIter = specialize TIter<Integer>;
  TIntArray = specialize TGenericArray<Integer>;

function IsEven(const V: Integer; Data: Pointer): Boolean;
begin
  Result := (V mod 2) = 0;
end;

function EqualsInt(const L, R: Integer; Data: Pointer): Boolean;
begin
  Result := L = R;
end;

procedure CheckListValues(AList: TIntFList; const AExpected: array of Integer; const AMessage: string);
var
  LItems: TIntArray;
  I: Integer;
begin
  LItems := AList.ToArray;
  CheckEqual(Int64(Length(AExpected)), Int64(Length(LItems)), AMessage + ' length');
  for I := Low(AExpected) to High(AExpected) do
    CheckEqual(Int64(AExpected[I]), Int64(LItems[I]), AMessage + ' item ' + IntToStr(I));
end;

var
  T: TTestRunner;

procedure TestPushFrontPopFront;
var
  LL: IIntFList;
begin
  LL := specialize MakeForwardList<Integer>;
  LL.PushFront(1);
  LL.PushFront(2);
  LL.PushFront(3);
  CheckEqual(Int64(3), Int64(LL.GetCount), 'count');
  CheckEqual(Int64(3), Int64(LL.PopFront), 'pop 3 (LIFO)');
  CheckEqual(Int64(2), Int64(LL.PopFront), 'pop 2');
  CheckEqual(Int64(1), Int64(LL.PopFront), 'pop 1');
  Check(LL.IsEmpty, 'empty');
end;

procedure TestFront;
var
  LL: IIntFList;
begin
  LL := specialize MakeForwardList<Integer>;
  LL.PushFront(42);
  LL.PushFront(10);
  CheckEqual(Int64(10), Int64(LL.Front), 'front is last pushed');
  CheckEqual(Int64(2), Int64(LL.GetCount), 'front does not remove');
end;

procedure TestTryFrontEmpty;
var
  LL: IIntFList;
  LVal: Integer;
begin
  LL := specialize MakeForwardList<Integer>;
  Check(not LL.TryFront(LVal), 'try front on empty');
  LL.PushFront(7);
  Check(LL.TryFront(LVal), 'try front on non-empty');
  CheckEqual(Int64(7), Int64(LVal), 'try front value');
end;

procedure TestTryPopFrontEmpty;
var
  LL: IIntFList;
  LVal: Integer;
begin
  LL := specialize MakeForwardList<Integer>;
  Check(not LL.TryPopFront(LVal), 'try pop on empty');
  LL.PushFront(5);
  Check(LL.TryPopFront(LVal), 'try pop on non-empty');
  CheckEqual(Int64(5), Int64(LVal), 'popped value');
  Check(LL.IsEmpty, 'empty after pop');
end;

procedure TestRemoveByValue;
var
  LL: IIntFList;
begin
  LL := specialize MakeForwardList<Integer>;
  LL.PushFront(1);
  LL.PushFront(2);
  LL.PushFront(3);
  LL.PushFront(2);
  CheckEqual(Int64(2), Int64(LL.Remove(2)), 'remove all 2s');
  CheckEqual(Int64(2), Int64(LL.GetCount), 'count after remove');
end;

procedure TestRemoveByValueWithEquals;
var
  LL: IIntFList;
begin
  LL := specialize MakeForwardList<Integer>;
  LL.PushFront(10);
  LL.PushFront(20);
  LL.PushFront(10);
  CheckEqual(Int64(2), Int64(LL.Remove(10, @EqualsInt, nil)), 'remove with equals func');
  CheckEqual(Int64(1), Int64(LL.GetCount), 'count');
end;

procedure TestRemoveIf;
var
  LL: IIntFList;
begin
  LL := specialize MakeForwardList<Integer>;
  LL.PushFront(1);
  LL.PushFront(2);
  LL.PushFront(3);
  LL.PushFront(4);
  CheckEqual(Int64(2), Int64(LL.RemoveIf(@IsEven, nil)), 'remove evens');
  CheckEqual(Int64(2), Int64(LL.GetCount), 'count after removeif');
end;

procedure TestClear;
var
  LL: IIntFList;
begin
  LL := specialize MakeForwardList<Integer>;
  LL.PushFront(1);
  LL.PushFront(2);
  LL.Clear;
  Check(LL.IsEmpty, 'empty after clear');
  CheckEqual(Int64(0), Int64(LL.GetCount), 'count 0');
end;

procedure TestStringType;
var
  LS: specialize IForwardList<string>;
  LVal: string;
begin
  LS := specialize MakeForwardList<string>;
  LS.PushFront('hello');
  LS.PushFront('world');
  CheckEqual(Int64(2), Int64(LS.GetCount), 'string count');
  Check(LS.TryPopFront(LVal), 'pop string');
  CheckEqual('world', LVal, 'string value');
end;

procedure TestFind;
var
  LL: TIntFList;
  LIter: TIntIter;
begin
  LL := TIntFList.Create;
  try
    LL.PushFront(10);
    LL.PushFront(20);
    LL.PushFront(30);
    LIter := LL.Find(20);
    Check(LIter.MoveNext, 'find 20 succeeds');
    CheckEqual(Int64(20), Int64(LIter.GetCurrent), 'found value');
  finally
    LL.Free;
  end;
end;

procedure TestFindIf;
var
  LL: TIntFList;
  LIter: TIntIter;
begin
  LL := TIntFList.Create;
  try
    LL.PushFront(1);
    LL.PushFront(3);
    LL.PushFront(4);
    LL.PushFront(5);
    LIter := LL.FindIf(@IsEven, nil);
    Check(LIter.MoveNext, 'findif finds even');
    CheckEqual(Int64(4), Int64(LIter.GetCurrent), 'found 4');
  finally
    LL.Free;
  end;
end;

procedure TestInsertAfterEraseAfter;
var
  LL: TIntFList;
  LIter, LInserted: TIntIter;
begin
  LL := TIntFList.Create;
  try
    LL.PushFront(3);
    LL.PushFront(1);
    LIter := LL.Find(1);
    Check(LIter.MoveNext, 'find 1');
    LInserted := LL.InsertAfter(LIter, 2);
    CheckEqual(Int64(3), Int64(LL.GetCount), 'count after insert');
    CheckEqual(Int64(1), Int64(LL.Front), 'front still 1');

    LIter := LL.Find(2);
    Check(LIter.MoveNext, 'find inserted 2');
    LL.EraseAfter(LIter);
    CheckEqual(Int64(2), Int64(LL.GetCount), 'count after erase');
  finally
    LL.Free;
  end;
end;

procedure TestTryLoadFromTryAppend;
var
  LL: TIntFList;
  LSrc: TIntFList;
begin
  LL := TIntFList.Create;
  LSrc := TIntFList.Create;
  try
    LSrc.PushFront(3);
    LSrc.PushFront(2);
    LSrc.PushFront(1);
    Check(LL.TryLoadFrom(LSrc), 'try load from');
    CheckEqual(Int64(3), Int64(LL.GetCount), 'loaded count');

    LSrc.Clear;
    LSrc.PushFront(5);
    LSrc.PushFront(4);
    Check(LL.TryAppend(LSrc), 'try append');
    CheckEqual(Int64(5), Int64(LL.GetCount), 'appended count');
  finally
    LSrc.Free;
    LL.Free;
  end;
end;

procedure TestSpliceSingleTailKeepsSourceAppendIsolated;
var
  Dst, Src: TIntFList;
  Pos, BeforeTail: TIntIter;
  NewValue: Integer;
begin
  Dst := TIntFList.Create;
  Src := TIntFList.Create;
  try
    Dst.PushFront(10);

    Src.PushFront(3);
    Src.PushFront(2);
    Src.PushFront(1);

    Pos := Dst.BeforeBegin;
    BeforeTail := Src.Find(2);
    CheckEqual(Int64(2), Int64(BeforeTail.Current), 'find node before source tail');

    Dst.Splice(Pos, Src, BeforeTail);
    CheckEqual(Int64(2), Int64(Src.GetCount), 'source count after moving tail');
    CheckEqual(Int64(2), Int64(Dst.GetCount), 'destination count after moving tail');

    NewValue := 4;
    Check(Src.TryAppend(@NewValue, 1), 'append to source after tail splice');
    CheckEqual(Int64(3), Int64(Src.GetCount), 'source count after append');
    CheckEqual(Int64(2), Int64(Dst.GetCount), 'destination count remains isolated');
    CheckEqual(Int64(4), Int64(Src.ToArray[2]), 'source append stays in source');
    CheckEqual(Int64(10), Int64(Dst.ToArray[1]), 'destination tail remains original');
  finally
    Src.Free;
    Dst.Free;
  end;
end;

procedure TestSpliceRangeTailKeepsSourceAppendIsolated;
var
  Dst, Src: TIntFList;
  Pos, FirstMoved, EndIter: TIntIter;
  NewValue: Integer;
begin
  Dst := TIntFList.Create;
  Src := TIntFList.Create;
  try
    Dst.PushFront(10);

    Src.PushFront(4);
    Src.PushFront(3);
    Src.PushFront(2);
    Src.PushFront(1);

    Pos := Dst.BeforeBegin;
    FirstMoved := Src.Find(3);
    CheckEqual(Int64(3), Int64(FirstMoved.Current), 'find source tail range head');
    EndIter := Src.CEnd;

    Dst.Splice(Pos, Src, FirstMoved, EndIter);
    CheckEqual(Int64(2), Int64(Src.GetCount), 'source count after moving tail range');
    CheckEqual(Int64(3), Int64(Dst.GetCount), 'destination count after moving tail range');

    NewValue := 5;
    Check(Src.TryAppend(@NewValue, 1), 'append to source after tail range splice');
    CheckEqual(Int64(3), Int64(Src.GetCount), 'source count after range append');
    CheckEqual(Int64(3), Int64(Dst.GetCount), 'destination count remains isolated after range append');
    CheckEqual(Int64(5), Int64(Src.ToArray[2]), 'source range append stays in source');
    CheckEqual(Int64(10), Int64(Dst.ToArray[2]), 'destination range tail remains original');
  finally
    Src.Free;
    Dst.Free;
  end;
end;

procedure TestSpliceAllKeepsDestinationAfterSourceFree;
var
  Dst, Src: TIntFList;
  Pos: TIntIter;
begin
  Dst := TIntFList.Create;
  Src := TIntFList.Create;
  try
    Dst.PushFront(10);
    Src.PushFront(2);
    Src.PushFront(1);

    Pos := Dst.BeforeBegin;
    Dst.Splice(Pos, Src);
    CheckEqual(Int64(0), Int64(Src.GetCount), 'source count after splice all');
    CheckListValues(Dst, [1, 2, 10], 'destination after splice all');

    Src.Free;
    Src := nil;
    CheckListValues(Dst, [1, 2, 10], 'destination after splice source free');
  finally
    Src.Free;
    Dst.Free;
  end;
end;

procedure TestMergeKeepsDestinationAfterSourceFree;
var
  Dst, Src: TIntFList;
begin
  Dst := TIntFList.Create;
  Src := TIntFList.Create;
  try
    Dst.PushFront(3);
    Dst.PushFront(1);
    Src.PushFront(4);
    Src.PushFront(2);

    Dst.Merge(Src);
    CheckEqual(Int64(0), Int64(Src.GetCount), 'source count after merge');
    CheckListValues(Dst, [1, 2, 3, 4], 'destination after merge');

    Src.Free;
    Src := nil;
    CheckListValues(Dst, [1, 2, 3, 4], 'destination after merge source free');
  finally
    Src.Free;
    Dst.Free;
  end;
end;

procedure TestMergeCopyKeepsDestinationAfterTempFree;
var
  Dst, Src: TIntFList;
begin
  Dst := TIntFList.Create;
  Src := TIntFList.Create;
  try
    Dst.PushFront(3);
    Dst.PushFront(1);
    Src.PushFront(4);
    Src.PushFront(2);

    Dst.MergeCopy(Src);
    CheckListValues(Src, [2, 4], 'source after merge copy');
    CheckListValues(Dst, [1, 2, 3, 4], 'destination after merge copy');
  finally
    Src.Free;
    Dst.Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.forwardlist');
  T.Run('PushFront/PopFront', @TestPushFrontPopFront);
  T.Run('Front', @TestFront);
  T.Run('TryFront empty', @TestTryFrontEmpty);
  T.Run('TryPopFront empty', @TestTryPopFrontEmpty);
  T.Run('Remove by value', @TestRemoveByValue);
  T.Run('Remove with equals func', @TestRemoveByValueWithEquals);
  T.Run('RemoveIf', @TestRemoveIf);
  T.Run('Clear', @TestClear);
  T.Run('String type (leak check)', @TestStringType);
  T.Run('Find', @TestFind);
  T.Run('FindIf', @TestFindIf);
  T.Run('InsertAfter/EraseAfter', @TestInsertAfterEraseAfter);
  T.Run('TryLoadFrom/TryAppend', @TestTryLoadFromTryAppend);
  T.Run('Splice single tail keeps source append isolated', @TestSpliceSingleTailKeepsSourceAppendIsolated);
  T.Run('Splice range tail keeps source append isolated', @TestSpliceRangeTailKeepsSourceAppendIsolated);
  T.Run('Splice all keeps destination after source free', @TestSpliceAllKeepsDestinationAfterSourceFree);
  T.Run('Merge keeps destination after source free', @TestMergeKeepsDestinationAfterSourceFree);
  T.Run('MergeCopy keeps destination after temp free', @TestMergeCopyKeepsDestinationAfterTempFree);
  T.Summary;
end.
