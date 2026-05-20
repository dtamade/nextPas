program Case_statement_pass;
var
  X: Integer;
  C: Char;
  S: string;
begin
  X := 3;

  case X of
    1: S := 'one';
    2: S := 'two';
    3: S := 'three';
  end;

  case X of
    1, 2: S := 'low';
    3, 4, 5: S := 'mid';
  else
    S := 'high';
  end;

  C := 'B';
  case C of
    'A': X := 1;
    'B': X := 2;
    'C': X := 3;
  else
    X := 0;
  end;
end.
