program test_text_strings;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.text.strings;

var
  T: TTestRunner;

procedure TestContains;
var A: TStringArray;
begin
  A := TStringArray.Create('foo', 'bar', 'baz');
  Check(StringsContains(A, 'bar'), 'contains bar');
  Check(not StringsContains(A, 'qux'), 'not contains qux');
end;

procedure TestIndexOf;
var A: TStringArray;
begin
  A := TStringArray.Create('a', 'b', 'c', 'b');
  CheckEqual(Int64(1), Int64(StringsIndexOf(A, 'b')), 'indexOf b');
  CheckEqual(Int64(3), Int64(StringsLastIndexOf(A, 'b')), 'lastIndexOf b');
  CheckEqual(Int64(-1), Int64(StringsIndexOf(A, 'z')), 'indexOf missing');
end;

procedure TestSort;
var A: TStringArray;
begin
  A := TStringArray.Create('cherry', 'apple', 'banana');
  StringsSort(A);
  CheckEqual('apple', A[0], 'sorted[0]');
  CheckEqual('banana', A[1], 'sorted[1]');
  CheckEqual('cherry', A[2], 'sorted[2]');
end;

procedure TestReverse;
var A: TStringArray;
begin
  A := TStringArray.Create('a', 'b', 'c');
  StringsReverse(A);
  CheckEqual('c', A[0], 'rev[0]');
  CheckEqual('a', A[2], 'rev[2]');
end;

procedure TestJoin;
var A: TStringArray;
begin
  A := TStringArray.Create('hello', 'world');
  CheckEqual('hello,world', StringsJoin(A, ','), 'join comma');
  CheckEqual('hello world', StringsJoin(A, ' '), 'join space');
end;

function IsLong(const S: string): Boolean;
begin
  Result := Length(S) > 3;
end;

procedure TestFilter;
var A, B: TStringArray;
begin
  A := TStringArray.Create('hi', 'hello', 'yo', 'world');
  B := StringsFilter(A, @IsLong);
  CheckEqual(Int64(2), Int64(Length(B)), 'filter count');
  CheckEqual('hello', B[0], 'filter[0]');
  CheckEqual('world', B[1], 'filter[1]');
end;

function ToUpper(const S: string): string;
begin
  Result := UpperCase(S);
end;

procedure TestMap;
var A, B: TStringArray;
begin
  A := TStringArray.Create('foo', 'bar');
  B := StringsMap(A, @ToUpper);
  CheckEqual('FOO', B[0], 'map[0]');
  CheckEqual('BAR', B[1], 'map[1]');
end;

procedure TestUnique;
var A, B: TStringArray;
begin
  A := TStringArray.Create('a', 'b', 'a', 'c', 'b');
  B := StringsUnique(A);
  CheckEqual(Int64(3), Int64(Length(B)), 'unique count');
end;

procedure TestCount;
var A: TStringArray;
begin
  A := TStringArray.Create('x', 'y', 'x', 'x', 'z');
  CheckEqual(Int64(3), Int64(StringsCount(A, 'x')), 'count x');
  CheckEqual(Int64(0), Int64(StringsCount(A, 'w')), 'count w');
end;

procedure TestAppendDelete;
var A: TStringArray;
begin
  A := nil;
  StringsAppend(A, 'first');
  StringsAppend(A, 'second');
  StringsAppend(A, 'third');
  CheckEqual(Int64(3), Int64(Length(A)), 'append count');
  StringsDelete(A, 1);
  CheckEqual(Int64(2), Int64(Length(A)), 'after delete');
  CheckEqual('first', A[0], 'del[0]');
  CheckEqual('third', A[1], 'del[1]');
end;

procedure TestInsert;
var A: TStringArray;
begin
  A := TStringArray.Create('a', 'c');
  StringsInsert(A, 1, 'b');
  CheckEqual(Int64(3), Int64(Length(A)), 'insert count');
  CheckEqual('b', A[1], 'insert[1]');
end;

procedure TestSlice;
var A, B: TStringArray;
begin
  A := TStringArray.Create('a', 'b', 'c', 'd', 'e');
  B := StringsSlice(A, 1, 4);
  CheckEqual(Int64(3), Int64(Length(B)), 'slice len');
  CheckEqual('b', B[0], 'slice[0]');
  CheckEqual('d', B[2], 'slice[2]');
end;

procedure TestEmpty;
var A: TStringArray;
begin
  A := nil;
  Check(not StringsContains(A, 'x'), 'empty contains');
  CheckEqual(Int64(-1), Int64(StringsIndexOf(A, 'x')), 'empty indexOf');
  CheckEqual('', StringsJoin(A, ','), 'empty join');
end;

begin
  T := TTestRunner.Create('nextpas.core.text.strings');
  T.Run('Contains', @TestContains);
  T.Run('IndexOf/LastIndexOf', @TestIndexOf);
  T.Run('Sort', @TestSort);
  T.Run('Reverse', @TestReverse);
  T.Run('Join', @TestJoin);
  T.Run('Filter', @TestFilter);
  T.Run('Map', @TestMap);
  T.Run('Unique', @TestUnique);
  T.Run('Count', @TestCount);
  T.Run('Append/Delete', @TestAppendDelete);
  T.Run('Insert', @TestInsert);
  T.Run('Slice', @TestSlice);
  T.Run('Empty array', @TestEmpty);
  T.Summary;
end.
