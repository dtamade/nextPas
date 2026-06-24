{$mode objfpc}{$H+}
program test_implicit_tobject_create_pass;

{ P2-2 edge regression B — implicit TObject.Create fallback.

  A class declared with NO explicit parent implicitly derives from TObject,
  which owns a parameterless constructor Create. Calling TImplicit.Create
  with zero arguments must resolve to TObject.Create via the implicit
  ancestry (no fallback happens here, but the chain must reach TObject).

  Cross-checked against FPC 3.3.1: identical behavior. }

type
  TImplicit = class
    FVal: LongInt;
  end;

var
  Obj: TImplicit;
begin
  Obj := TImplicit.Create;
  try
    Obj.FVal := 7;
    if Obj.FVal <> 7 then
    begin
      WriteLn('FAIL: expected 7, got ', Obj.FVal);
      Halt(1);
    end;
  finally
    Obj.Free;
  end;

  WriteLn('implicit_tobject_create OK');
end.
