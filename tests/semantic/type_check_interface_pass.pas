{$mode objfpc}{$H+}
program type_check_interface_pass;

{ 类型检查：interface 类型操作 }

type
  ICalculator = interface
    function Add(A, B: Integer): Integer;
  end;

  TCalc = class(TInterfacedObject, ICalculator)
    function Add(A, B: Integer): Integer;
  end;

function TCalc.Add(A, B: Integer): Integer;
begin
  Add := A + B;
end;

var
  C: TCalc;
  Intf: ICalculator;
  R: Integer;
begin
  C := TCalc.Create;
  R := C.Add(3, 4);
  if R <> 7 then Halt(1);

  Intf := C;
  R := Intf.Add(5, 6);
  if R <> 11 then Halt(2);
end.
