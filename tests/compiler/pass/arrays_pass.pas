{$mode objfpc}{$H+}
program test_arrays_pass;

type
  TIntArray = array of LongInt;

function SumArray(const A: TIntArray): LongInt;
var
  I: LongInt;
begin
  Result := 0;
  for I := 0 to High(A) do
    Inc(Result, A[I]);
end;

var
  A, B: TIntArray;
  I: LongInt;
begin
  { dynamic array creation }
  SetLength(A, 10);
  for I := 0 to High(A) do
    A[I] := I * I;

  if SumArray(A) <> 285 then Halt(1);

  { copy }
  B := Copy(A);
  if Length(B) <> 10 then Halt(2);
  if B[5] <> 25 then Halt(3);

  { slice copy }
  B := Copy(A, 3, 4);
  if Length(B) <> 4 then Halt(4);
  if B[0] <> 9 then Halt(5);

  { High/Low }
  if High(A) <> 9 then Halt(6);
  if Low(A) <> 0 then Halt(7);

  { SetLength grow }
  SetLength(A, 20);
  if Length(A) <> 20 then Halt(8);
  if A[9] <> 81 then Halt(9); { existing data preserved }

  WriteLn('arrays OK');
end.
