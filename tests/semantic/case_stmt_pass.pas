program case_stmt_pass;

var
  X, Y: Integer;
begin
  X := 2;
  case X of
    1: Y := 10;
    2: Y := 20;
    3: Y := 30;
    else Y := 0;
  end;
end.
