program Llvm_unit_init_chain;

{$mode objfpc}{$H+}

{ Host-free multi-unit + unit initialization evidence.
  Uses MuInitMid → MuInitLeaf (3 compilation units with program).
  Leaf init sets GMuAcc=3; mid init adds 30 → expect Halt(33).
  Empty np_unit_init_* stubs yield 0. }

uses
  MuInitMid;

begin
  Halt(MuTotal);
end.
