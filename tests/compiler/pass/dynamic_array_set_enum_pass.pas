{$mode objfpc}{$H+}
program test_dynamic_array_pass;
uses SysUtils;

type
  TIntArray = array of Integer;
  TStrArray = array of string;

var
  TestNum: Integer;

procedure Check(Condition: Boolean; const Msg: string);
begin
  if not Condition then
  begin
    WriteLn('FAIL: ', Msg);
    Halt(1);
  end;
end;

{ Test 1: Basic dynamic array creation and access }
procedure TestBasicDynArray;
var
  Arr: TIntArray;
begin
  SetLength(Arr, 5);
  Check(Length(Arr) = 5, 'dyn array length');
  Arr[0] := 10;
  Arr[4] := 50;
  Check(Arr[0] = 10, 'dyn array element 0');
  Check(Arr[4] = 50, 'dyn array element 4');
end;

{ Test 2: Dynamic array of strings }
procedure TestStringDynArray;
var
  Arr: TStrArray;
begin
  SetLength(Arr, 3);
  Arr[0] := 'hello';
  Arr[1] := 'world';
  Arr[2] := '!';
  Check(Arr[0] = 'hello', 'str array 0');
  Check(Arr[1] + Arr[2] = 'world!', 'str array concat');
end;

{ Test 3: Dynamic array as parameter }
function SumArray(const Arr: TIntArray): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to Length(Arr) - 1 do
    Result := Result + Arr[I];
end;

{ Test 4: Dynamic array return }
function MakeRange(N: Integer): TIntArray;
var
  I: Integer;
begin
  SetLength(Result, N);
  for I := 0 to N - 1 do
    Result[I] := I + 1;
end;

{ Test 5: Set operations }
procedure TestSetOperations;
type
  TCharSet = set of Char;
var
  Digits, Letters, All: TCharSet;
begin
  Digits := ['0'..'9'];
  Letters := ['a'..'z', 'A'..'Z'];
  All := Digits + Letters;
  Check('5' in Digits, 'digit in set');
  Check('a' in Letters, 'letter in set');
  Check(not ('!' in All), 'not in set');
  Check('5' in All, 'digit in union');
end;

{ Test 6: Enumerations }
procedure TestEnumerations;
type
  TColor = (clRed, clGreen, clBlue, clYellow);
  TColors = set of TColor;
var
  C: TColor;
  WarmColors: TColors;
begin
  C := clRed;
  Check(Ord(C) = 0, 'enum ord');
  Check(Succ(C) = clGreen, 'enum succ');
  Check(Pred(clGreen) = clRed, 'enum pred');
  WarmColors := [clRed, clYellow];
  Check(clRed in WarmColors, 'enum in set');
  Check(not (clBlue in WarmColors), 'enum not in set');
end;

begin
  TestNum := 0;

  Inc(TestNum); WriteLn('Test ', TestNum, ': Basic dyn array');
  TestBasicDynArray;

  Inc(TestNum); WriteLn('Test ', TestNum, ': String dyn array');
  TestStringDynArray;

  Inc(TestNum); WriteLn('Test ', TestNum, ': Sum array param');
  Check(SumArray(MakeRange(5)) = 15, 'sum 1..5');

  Inc(TestNum); WriteLn('Test ', TestNum, ': Make range');
  Check(Length(MakeRange(10)) = 10, 'range length');

  Inc(TestNum); WriteLn('Test ', TestNum, ': Set operations');
  TestSetOperations;

  Inc(TestNum); WriteLn('Test ', TestNum, ': Enumerations');
  TestEnumerations;

  WriteLn('All dynamic array/set/enum tests passed');
end.
