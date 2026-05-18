program Open_array_pass;

{$mode objfpc}{$H+}

function Sum(const Values: array of Integer): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := Low(Values) to High(Values) do
    Result := Result + Values[I];
end;

function First(const Arr: array of Integer): Integer;
begin
  if Length(Arr) > 0 then
    Result := Arr[0]
  else
    Result := 0;
end;

var
  Total: Integer;
begin
  Total := Sum([1, 2, 3, 4, 5]);
  Total := First([10, 20, 30]);
end.
