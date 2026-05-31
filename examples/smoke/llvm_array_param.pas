program test_array_param;

function Sum(Arr: array of Integer; Count: Integer): Integer;
var I, S: Integer;
begin
  S := 0;
  for I := 0 to Count - 1 do
    S := S + Arr[I];
  Result := S;
end;

var
  A: array of Integer;
begin
  SetLength(A, 4);
  A[0] := 10;
  A[1] := 20;
  A[2] := 30;
  A[3] := 40;
  Halt(Sum(A, 4));
end.
