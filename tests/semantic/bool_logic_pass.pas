program Bool_logic_pass;
function IsInRange(X, Lo, Hi: Integer): Integer;
begin
  if (X >= Lo) and (X <= Hi) then
    IsInRange := 1
  else
    IsInRange := 0;
end;
function IsSpecial(X: Integer): Integer;
begin
  if (X = 0) or (X = 255) then
    IsSpecial := 1
  else
    IsSpecial := 0;
end;
function IsNormal(X: Integer): Integer;
begin
  if not (IsSpecial(X) = 1) then
    IsNormal := 1
  else
    IsNormal := 0;
end;
var
  R: Integer;
begin
  R := IsInRange(50, 0, 100);
  R := R + IsSpecial(0);
  R := R + IsNormal(42);
end.
