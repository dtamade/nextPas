{$mode objfpc}{$H+}
program generic_ctor_propagation_pass;

{ L5: 泛型构造器传播 — 特化泛型时构造器应正确复制 }

type
  generic TBox<T> = class
    FValue: T;
    constructor Create(const AValue: T);
  end;

constructor TBox.Create(const AValue: T);
begin
  FValue := AValue;
end;

type
  TIntBox = specialize TBox<Integer>;
  TStrBox = specialize TBox<string>;

var
  IB: TIntBox;
  SB: TStrBox;
begin
  IB := TIntBox.Create(42);
  if IB.FValue <> 42 then Halt(1);
  IB.Free;

  SB := TStrBox.Create('hello');
  if SB.FValue <> 'hello' then Halt(2);
  SB.Free;
end.
