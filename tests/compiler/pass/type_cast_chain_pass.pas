{$mode objfpc}{$H+}
program test_type_cast_chain_pass;

type
  TBase = class
    function GetValue: LongInt; virtual;
    function Add(A, B: LongInt): LongInt;
  end;

  TChild = class(TBase)
    function GetValue: LongInt; override;
    function DoCast: LongInt;
  end;

function TBase.GetValue: LongInt;
begin
  Result := 10;
end;

function TBase.Add(A, B: LongInt): LongInt;
begin
  Result := A + B;
end;

function TChild.GetValue: LongInt;
begin
  Result := 42;
end;

function TChild.DoCast: LongInt;
begin
  { P1: type cast chain call — (Self as TBase).Method(...) }
  Result := (Self as TBase).GetValue;
end;

var
  C: TChild;
  B: TBase;
begin
  C := TChild.Create;
  { type cast chain with method call }
  WriteLn(C.DoCast);
  { type cast chain with function call + args }
  WriteLn((C as TBase).Add(3, 4));
  C.Free;
end.
