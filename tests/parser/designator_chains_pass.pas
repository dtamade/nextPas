program Designator_chains_pass;
type
  TPoint = record
    X: Integer;
    Y: Integer;
  end;
  TLine = record
    Start: TPoint;
    Finish: TPoint;
  end;
var
  P: TPoint;
  L: TLine;
  Arr: array[1..10] of Integer;
  S: string;
  I: Integer;
begin
  P.X := 10;
  P.Y := 20;
  L.Start.X := 1;
  L.Finish.Y := 2;
  Arr[1] := 42;
  Arr[2 + 1] := 99;
  I := Arr[1];
  S := 'hello';
  I := Length(S);
end.
