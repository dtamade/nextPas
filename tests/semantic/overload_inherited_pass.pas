{$mode objfpc}{$H+}
program overload_inherited_pass;

{ 重载解析：继承方法 }

type
  TBase = class
    function Value: Integer; virtual;
  end;

  TDerived = class(TBase)
    function Value: Integer; override;
  end;

function TBase.Value: Integer;
begin
  Value := 1;
end;

function TDerived.Value: Integer;
begin
  Value := inherited Value + 10;
end;

var
  B: TBase;
  D: TDerived;
begin
  B := TBase.Create;
  if B.Value <> 1 then Halt(1);

  D := TDerived.Create;
  if D.Value <> 11 then Halt(2);

  B := D;
  if B.Value <> 11 then Halt(3);
end.
