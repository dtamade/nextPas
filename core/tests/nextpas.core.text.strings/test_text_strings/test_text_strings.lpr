program test_text_strings;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.strings, nextpas.core.base, nextpas.core.text.conv;

var
  T: TTestSuite;

procedure TestContains;
var A: TStringArray;
begin
  A := TStringArray.Create('foo', 'bar', 'baz');
  Check(StringsContains(A, 'bar'), 'contains bar');
  Check(not StringsContains(A, 'qux'), 'not contains qux');
end;

{ R7 边界用例：空列表 / 空串 / 尾命中（proxy888 白名单判定收归本函数后
  由本套件兜底，保证 5 域消费行为一致） }
procedure TestContainsBoundary;
var A: TStringArray;
begin
  { 空列表恒 False }
  A := nil;
  Check(not StringsContains(A, 'x'), 'empty list false');
  { 空串 value：列表含空串则命中，否则不命中 }
  A := TStringArray.Create('a', '');
  Check(StringsContains(A, ''), 'empty value hit');
  Check(not StringsContains(A, 'b'), 'empty value no hit other');
  A := TStringArray.Create('a', 'b');
  Check(not StringsContains(A, ''), 'empty value miss');
  { 尾命中：末位元素命中 }
  A := TStringArray.Create('a', 'b', 'zz');
  Check(StringsContains(A, 'zz'), 'tail hit');
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

procedure TestSplit;
var
  A: TStringArray;
begin
  A := StringsSplit('a,b,c', ',');
  CheckEqual(Int64(3), Int64(Length(A)), 'split count');
  CheckEqual('a', A[0], 'split[0]');
  CheckEqual('c', A[2], 'split[2]');

  A := StringsSplit(',a,', ',');
  CheckEqual(Int64(3), Int64(Length(A)), 'leading and trailing delimiter');
  CheckEqual('', A[0], 'leading empty');
  CheckEqual('', A[2], 'trailing empty');

  A := StringsSplit('abc', '');
  CheckEqual(Int64(1), Int64(Length(A)), 'empty delimiter count');
  CheckEqual('abc', A[0], 'empty delimiter value');
end;

procedure TestSplitEscaped;
var
  A: TStringArray;
begin
  A := StringsSplitEscaped('', ',');
  CheckEqual(Int64(0), Int64(Length(A)), 'empty input');

  A := StringsSplitEscaped('a,b,c', ',');
  CheckEqual(Int64(3), Int64(Length(A)), 'plain count');
  CheckEqual('a', A[0], 'plain[0]');
  CheckEqual('c', A[2], 'plain[2]');

  A := StringsSplitEscaped('a\,b', ',');
  CheckEqual(Int64(1), Int64(Length(A)), 'escaped comma count');
  CheckEqual('a,b', A[0], 'escaped comma value');

  A := StringsSplitEscaped('x\\y', ',');
  CheckEqual(Int64(1), Int64(Length(A)), 'escaped backslash count');
  CheckEqual('x\y', A[0], 'escaped backslash value');

  A := StringsSplitEscaped('a,b\,c,d', ',');
  CheckEqual(Int64(3), Int64(Length(A)), 'mixed count');
  CheckEqual('b,c', A[1], 'mixed middle');

  A := StringsSplitEscaped('a,', ',');
  CheckEqual(Int64(2), Int64(Length(A)), 'trailing delimiter count');
  CheckEqual('', A[1], 'trailing empty');

  A := StringsSplitEscaped('a\', ',');
  CheckEqual(Int64(1), Int64(Length(A)), 'trailing escape count');
  CheckEqual('a\', A[0], 'trailing escape value');
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
  T := TTestSuite.Create('nextpas.core.text.strings');
  T.Test('Contains', @TestContains);
  T.Test('Contains (boundary)', @TestContainsBoundary);
  T.Test('IndexOf/LastIndexOf', @TestIndexOf);
  T.Test('Sort', @TestSort);
  T.Test('Reverse', @TestReverse);
  T.Test('Join', @TestJoin);
  T.Test('Split', @TestSplit);
  T.Test('SplitEscaped', @TestSplitEscaped);
  T.Test('Filter', @TestFilter);
  T.Test('Map', @TestMap);
  T.Test('Unique', @TestUnique);
  T.Test('Count', @TestCount);
  T.Test('Append/Delete', @TestAppendDelete);
  T.Test('Insert', @TestInsert);
  T.Test('Slice', @TestSlice);
  T.Test('Empty array', @TestEmpty);
  T.Test('ParseLines', @TestParseLines);
  T.Test('ParseLines (CRLF)', @TestParseLinesWindows);
  T.Test('ParseKeyValues', @TestParseKeyValues);
  T.Test('ParseKeyValues (colon)', @TestParseKeyValuesColon);
  T.Test('StringPairsGet', @TestStringPairsGet);
  T.Test('StringPairsContains', @TestStringPairsContains);
  T.Test('StringPairsKeys', @TestStringPairsKeys);
  T.Test('GlobMatch', @TestGlobMatch);
  T.Test('StringsGlob', @TestStringsGlob);
  if not T.Run then Halt(1);
end.
