program Helper_type_pass;

{$mode objfpc}{$H+}
{$modeswitch typehelpers}

type
  TIntegerHelper = type helper for Integer
    function ToString: string;
    function IsPositive: Boolean;
  end;

function TIntegerHelper.ToString: string;
begin
  Str(Self, Result);
end;

function TIntegerHelper.IsPositive: Boolean;
begin
  Result := Self > 0;
end;

var
  X: Integer;
  S: string;
  B: Boolean;
begin
  X := 42;
  S := X.ToString;
  B := X.IsPositive;
end.
