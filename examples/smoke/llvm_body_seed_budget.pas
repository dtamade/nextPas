program Llvm_body_seed_budget;

{$mode objfpc}{$H+}

{ Body-seed reachability budget fixture (multi-unit flood, host-free).
  BsFloodMid → BsFloodLeaf: ~120 dead free functions + live path.
  Program only calls LiveMid → encoded << registered if reachability works.
  claim-level=body-seed-reachability-partial-not-m2a
  Note: llvm_kernel_unit_sdb residual hang is separate (core text.conv graph). }

uses
  BsFloodMid;

begin
  Halt(LiveMid);  { LiveLeaf=7 via LiveMid passthrough }
end.
