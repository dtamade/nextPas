program Var_init_pass;

{$mode objfpc}{$H+}

type
  TStringArray = array of string;

var
  X: Integer = 42;
  S: string = 'hello';
  Arr: TStringArray;
  I: Integer;
begin
  I := X;
  SetLength(Arr, 3);
  Arr[0] := S;
  Arr[1] := 'world';
  Arr[2] := Arr[0] + ' ' + Arr[1];
  I := Length(Arr);
end.
