{$mode objfpc}{$H+}
program type_check_class_pass;

{ 类型检查：class 类型操作 }

type
  TBase = class
    FValue: Integer;
    function GetValue: Integer;
  end;

  TDerived = class(TBase)
    FExtra: Integer;
  end;

function TBase.GetValue: Integer;
begin
  GetValue := FValue;
end;

var
  B: TBase;
  D: TDerived;
  V: Integer;
begin
  B := TBase.Create;
  B.FValue := 42;
  V := B.GetValue;
  if V <> 42 then Halt(1);

  D := TDerived.Create;
  D.FValue := 100;
  D.FExtra := 200;
  V := D.GetValue;
  if V <> 100 then Halt(2);

  { 多态赋值 }
  B := D;
  V := B.GetValue;
  if V <> 100 then Halt(3);
end.
