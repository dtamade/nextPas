program Llvm_kernel_unit_sdb;

{$mode objfpc}{$H+}

{ Batch 8 / K1: real thin-kernel unit host-free ladder tier1.
  Uses units/linux-x86_64/np_source_database (not Mu* toys).
  Expected: Halt(0).
  claim-level=kernel-unit-ladder-host-free-not-m2a }

uses
  np_source_database;

begin
  Halt(0);
end.
