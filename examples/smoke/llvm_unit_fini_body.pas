program Llvm_unit_fini_body;

{$mode objfpc}{$H+}

{ Host-free fixture for unit finalization IR evidence.
  Halt(MuFiniRead) expects 1 (init only). Finalization body is asserted via
  LLVM IR (store in np_unit_fini_*), not exit code. }

uses
  MuFiniLeaf;

begin
  Halt(MuFiniRead);
end.
