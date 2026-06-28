program class_method_local_overload_resolution_pass;

{$mode objfpc}{$H+}

function CeilValue(const AValue: Single): Int64; overload;
begin
  Result := 3;
end;

function CeilValue(const AValue: Double): Int64; overload;
begin
  Result := 4;
end;

type
  TGrow = class
    function UseSingle: Int64;
  end;

function TGrow.UseSingle: Int64;
var
  LValue: Single;
begin
  LValue := 1.5;
  Result := CeilValue(LValue);
end;

var
  Grow: TGrow;
begin
  Grow := TGrow.Create;
  if Grow.UseSingle <> 3 then
    Halt(1);
  Grow.Free;
end.
