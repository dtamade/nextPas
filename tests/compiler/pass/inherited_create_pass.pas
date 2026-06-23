{$mode objfpc}{$H+}
program test_inherited_create_pass;

{ Test: class inherits Create from parent without defining its own.
  Verifies P2-2 — stage0 must walk inheritance chain to find Create. }

type
  TBase = class
  private
    FValue: Integer;
  public
    constructor Create(AValue: Integer);
    function GetValue: Integer;
  end;

  TDerived = class(TBase)
    { No Create — inherits TBase.Create }
  end;

  TGrandChild = class(TDerived)
    { No Create — inherits TBase.Create through TDerived }
  end;

constructor TBase.Create(AValue: Integer);
begin
  FValue := AValue;
end;

function TBase.GetValue: Integer;
begin
  Result := FValue;
end;

var
  LBase: TBase;
  LDerived: TDerived;
  LGrandChild: TGrandChild;
begin
  { 1. Base class — should work }
  LBase := TBase.Create(10);
  try
    if LBase.GetValue <> 10 then
    begin
      WriteLn('FAIL: TBase.Create(10) expected 10, got ', LBase.GetValue);
      Halt(1);
    end;
  finally
    LBase.Free;
  end;

  { 2. Derived class — inherits Create from TBase }
  LDerived := TDerived.Create(20);
  try
    if LDerived.GetValue <> 20 then
    begin
      WriteLn('FAIL: TDerived.Create(20) expected 20, got ', LDerived.GetValue);
      Halt(2);
    end;
  finally
    LDerived.Free;
  end;

  { 3. GrandChild — inherits Create through two levels }
  LGrandChild := TGrandChild.Create(30);
  try
    if LGrandChild.GetValue <> 30 then
    begin
      WriteLn('FAIL: TGrandChild.Create(30) expected 30, got ', LGrandChild.GetValue);
      Halt(3);
    end;
  finally
    LGrandChild.Free;
  end;

  { 4. Polymorphic use — assign derived to base variable }
  LDerived := TDerived.Create(42);
  try
    LBase := LDerived;
    if LBase.GetValue <> 42 then
    begin
      WriteLn('FAIL: polymorphic access expected 42, got ', LBase.GetValue);
      Halt(4);
    end;
  finally
    LDerived.Free;
  end;

  WriteLn('inherited_create OK');
end.
