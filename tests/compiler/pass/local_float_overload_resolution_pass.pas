program local_float_overload_resolution_pass;

{$mode objfpc}{$H+}

function CeilValue(const AValue: Single): Int64; overload;
begin
  Result := 3;
end;

function CeilValue(const AValue: Double): Int64; overload;
begin
  Result := 4;
end;

function UseSingle: Int64;
var
  LValue: Single;
begin
  LValue := 1.5;
  Result := CeilValue(LValue);
end;

begin
  if UseSingle <> 3 then
    Halt(1);
end.
