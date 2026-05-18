program Exception_handling_pass;

{$mode objfpc}{$H+}

var
  X: Integer;
begin
  try
    X := 10;
    X := X div 1;
  except
    X := -1;
  end;

  try
    X := 42;
  finally
    X := 0;
  end;
end.
