program type_compat_alias_pass;

type
  TMyInt = Integer;
  TMyBool = Boolean;
  TMyString = string;

function AddInts(A, B: Integer): Integer;
begin
  AddInts := A + B;
end;

var
  X: TMyInt;
  Y: Integer;
  Z: TMyInt;
  B: TMyBool;
  S: TMyString;
begin
  X := 42;
  Y := X;
  Z := Y + X;
  B := True;
  S := 'hello';
  X := AddInts(X, Y);
  Z := Z + X;
  if B then
    X := 1
  else
    X := 0;
end.
