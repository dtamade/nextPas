program Try_except_pass;

{$mode objfpc}{$H+}

var
  X: Integer;
  S: string;
begin
  try
    S := 'hello';
    X := 42;
  finally
    S := '';
  end;
end.
