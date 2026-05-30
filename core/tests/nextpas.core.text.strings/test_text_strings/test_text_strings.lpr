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

procedure TestParseLines;
var A: TStringArray;
begin
  A := StringsParseLines('hello' + #10 + 'world' + #10 + 'foo');
  CheckEqual(Int64(3), Int64(Length(A)), 'line count');
  CheckEqual('hello', A[0], 'line[0]');
  CheckEqual('world', A[1], 'line[1]');
  CheckEqual('foo', A[2], 'line[2]');
end;

procedure TestParseLinesWindows;
var A: TStringArray;
begin
  A := StringsParseLines('a' + #13#10 + 'b' + #13#10 + 'c');
  CheckEqual(Int64(3), Int64(Length(A)), 'crlf count');
  CheckEqual('a', A[0], 'crlf[0]');
  CheckEqual('b', A[1], 'crlf[1]');
end;

procedure TestParseKeyValues;
var P: TStringPairArray;
begin
  P := StringsParseKeyValues('name=Alice' + #10 + 'age=30' + #10 + 'city=Beijing');
  CheckEqual(Int64(3), Int64(Length(P)), 'pair count');
  CheckEqual('name', P[0].Key, 'key[0]');
  CheckEqual('Alice', P[0].Value, 'val[0]');
  CheckEqual('age', P[1].Key, 'key[1]');
  CheckEqual('30', P[1].Value, 'val[1]');
end;

procedure TestParseKeyValuesColon;
var P: TStringPairArray;
begin
  P := StringsParseKeyValues('vendor_id : GenuineIntel' + #10 + 'model name : Intel Core', ':');
  CheckEqual(Int64(2), Int64(Length(P)), 'colon count');
  CheckEqual('vendor_id', P[0].Key, 'key trimmed');
  CheckEqual('GenuineIntel', P[0].Value, 'val trimmed');
end;

procedure TestStringPairsGet;
var P: TStringPairArray;
begin
  P := StringsParseKeyValues('host=localhost' + #10 + 'port=8080');
  CheckEqual('localhost', StringPairsGet(P, 'host'), 'get host');
  CheckEqual('8080', StringPairsGet(P, 'port'), 'get port');
  CheckEqual('default', StringPairsGet(P, 'missing', 'default'), 'get default');
end;

procedure TestStringPairsContains;
var P: TStringPairArray;
begin
  P := StringsParseKeyValues('a=1' + #10 + 'b=2');
  Check(StringPairsContains(P, 'a'), 'contains a');
  Check(not StringPairsContains(P, 'c'), 'not contains c');
end;

procedure TestStringPairsKeys;
var P: TStringPairArray; K: TStringArray;
begin
  P := StringsParseKeyValues('x=1' + #10 + 'y=2' + #10 + 'z=3');
  K := StringPairsKeys(P);
  CheckEqual(Int64(3), Int64(Length(K)), 'keys count');
  CheckEqual('x', K[0], 'keys[0]');
  CheckEqual('z', K[2], 'keys[2]');
end;

procedure TestGlobMatch;
begin
  Check(GlobMatch('*.txt', 'hello.txt'), '*.txt match');
  Check(not GlobMatch('*.txt', 'hello.md'), '*.txt no match');
  Check(GlobMatch('test_?', 'test_1'), '? single char');
  Check(not GlobMatch('test_?', 'test_12'), '? too many');
  Check(GlobMatch('src/*.pas', 'src/main.pas'), 'path glob');
  Check(GlobMatch('*', 'anything'), '* matches all');
  Check(GlobMatch('a*b', 'aXYZb'), 'a*b middle');
  Check(GlobMatch('a*b', 'ab'), 'a*b empty middle');
  Check(not GlobMatch('a*b', 'aXYZc'), 'a*b no match');
  Check(GlobMatch('', ''), 'empty matches empty');
  Check(not GlobMatch('', 'x'), 'empty no match non-empty');
end;

procedure TestStringsGlob;
var A, B: TStringArray;
begin
  A := TStringArray.Create('main.pas', 'utils.pas', 'readme.md', 'test.lpr');
  B := StringsGlob(A, '*.pas');
  CheckEqual(Int64(2), Int64(Length(B)), 'glob count');
  CheckEqual('main.pas', B[0], 'glob[0]');
  CheckEqual('utils.pas', B[1], 'glob[1]');
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
  T.Run('ParseLines', @TestParseLines);
  T.Run('ParseLines (CRLF)', @TestParseLinesWindows);
  T.Run('ParseKeyValues', @TestParseKeyValues);
  T.Run('ParseKeyValues (colon)', @TestParseKeyValuesColon);
  T.Run('StringPairsGet', @TestStringPairsGet);
  T.Run('StringPairsContains', @TestStringPairsContains);
  T.Run('StringPairsKeys', @TestStringPairsKeys);
  T.Run('GlobMatch', @TestGlobMatch);
  T.Run('StringsGlob', @TestStringsGlob);
  T.Summary;
end.
