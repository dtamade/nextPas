program test_fpc_strutils;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.fpc.strutils,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestPosEx;
begin
  Check(PosEx('world', 'hello world') = 7, 'basic');
  Check(PosEx('o', 'hello world', 5) = 5, 'offset 5');
  Check(PosEx('o', 'hello world', 6) = 8, 'offset 6');
  Check(PosEx('xyz', 'hello') = 0, 'not found');
end;

procedure TestLeftRightMid;
begin
  Check(LeftStr('hello', 3) = 'hel', 'left 3');
  Check(RightStr('hello', 3) = 'llo', 'right 3');
  Check(MidStr('hello', 2, 3) = 'ell', 'mid 2,3');
  Check(LeftStr('hi', 10) = 'hi', 'left overflow');
  Check(RightStr('hi', 10) = 'hi', 'right overflow');
end;

procedure TestDupeReverse;
begin
  Check(DupeString('ab', 3) = 'ababab', 'dupe 3');
  Check(DupeString('x', 0) = '', 'dupe 0');
  Check(ReverseString('hello') = 'olleh', 'reverse');
  Check(ReverseString('') = '', 'reverse empty');
end;

procedure TestStartsEnds;
begin
  Check(StartsStr('hel', 'hello'), 'starts');
  Check(not StartsStr('world', 'hello'), 'not starts');
  Check(EndsStr('llo', 'hello'), 'ends');
  Check(not EndsStr('hel', 'hello'), 'not ends');
  Check(StartsText('HEL', 'hello'), 'starts nocase');
  Check(EndsText('LLO', 'hello'), 'ends nocase');
end;

procedure TestContains;
begin
  Check(ContainsStr('hello world', 'world'), 'contains');
  Check(not ContainsStr('hello', 'xyz'), 'not contains');
  Check(ContainsText('Hello World', 'WORLD'), 'contains nocase');
end;

procedure TestReplace;
begin
  Check(ReplaceStr('aXbXc', 'X', '-') = 'a-b-c', 'replace all');
  Check(ReplaceText('Hello', 'hello', 'HI') = 'HI', 'replace nocase');
end;

procedure TestSplit;
var A: specialize TArray<string>;
begin
  A := SplitString('a,b,c', ',');
  Check(Length(A) = 3, 'split count');
  Check(A[0] = 'a', 'split[0]');
  Check(A[1] = 'b', 'split[1]');
  Check(A[2] = 'c', 'split[2]');
end;

procedure TestIndex;
begin
  Check(IndexStr('beta', ['alpha', 'beta', 'gamma']) = 1, 'indexstr');
  Check(IndexStr('delta', ['alpha', 'beta']) = -1, 'indexstr not found');
  Check(IndexText('BETA', ['alpha', 'beta', 'gamma']) = 1, 'indextext');
end;

procedure TestStuff;
begin
  Check(StuffString('hello world', 7, 5, 'pascal') = 'hello pascal', 'stuff');
end;

procedure TestNaturalCompare;
begin
  Check(NaturalCompareText('file2', 'file10') < 0, 'file2 < file10');
  Check(NaturalCompareText('file10', 'file2') > 0, 'file10 > file2');
  Check(NaturalCompareText('abc', 'abc') = 0, 'equal');
end;

begin
  T := TTestRunner.Create('nextpas.core.fpc.strutils');
  T.Run('PosEx', @TestPosEx);
  T.Run('LeftStr/RightStr/MidStr', @TestLeftRightMid);
  T.Run('DupeString/ReverseString', @TestDupeReverse);
  T.Run('StartsStr/EndsStr', @TestStartsEnds);
  T.Run('ContainsStr/ContainsText', @TestContains);
  T.Run('ReplaceStr/ReplaceText', @TestReplace);
  T.Run('SplitString', @TestSplit);
  T.Run('IndexStr/IndexText', @TestIndex);
  T.Run('StuffString', @TestStuff);
  T.Run('NaturalCompareText', @TestNaturalCompare);
  T.Summary;
end.
