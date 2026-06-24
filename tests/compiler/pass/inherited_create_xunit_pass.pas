{$mode objfpc}{$H+}
program test_inherited_create_xunit_pass;

{ P2-2 — cross-unit inherited Create (Codex candidate A verification).

  TBase.Create lives in unit inherited_create_xunit_parent. The program's
  own TDerived/TGrandChild inherit Create across 2 hops without redefining it.
  If stage0 fails to walk the inheritance chain when the parent type is
  imported from another unit, this program will not compile. }

uses
  inherited_create_xunit_parent;

type
  TDerived = class(TBase)
    { No Create — inherits TBase.Create from the imported unit }
  end;

  TGrandChild = class(TDerived)
    { No Create — inherits TBase.Create through TDerived }
  end;

var
  LD: TDerived;
  LG: TGrandChild;
begin
  LD := TDerived.Create(11);
  try
    if LD.GetValue <> 11 then
    begin
      WriteLn('FAIL: TDerived.Create(11) expected 11, got ', LD.GetValue);
      Halt(1);
    end;
  finally
    LD.Free;
  end;

  LG := TGrandChild.Create(22);
  try
    if LG.GetValue <> 22 then
    begin
      WriteLn('FAIL: TGrandChild.Create(22) expected 22, got ', LG.GetValue);
      Halt(2);
    end;
  finally
    LG.Free;
  end;

  WriteLn('inherited_create_xunit OK');
end.
