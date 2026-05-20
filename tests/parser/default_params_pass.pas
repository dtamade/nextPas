program Default_params_pass;

{$mode objfpc}{$H+}

function Add(A: Integer; B: Integer = 0; C: Integer = 0): Integer;
begin
  Result := A + B + C;
end;

procedure Log(const Msg: string; Level: Integer = 0);
begin
end;

var
  X: Integer;
begin
  X := Add(1);
  X := Add(1, 2);
  X := Add(1, 2, 3);
  Log('hello');
  Log('world', 1);
end.
