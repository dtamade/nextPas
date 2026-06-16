program test_memory_manager_crt_compile_gate;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.mem.manager.crt;

procedure TouchCrtManagerContracts;
begin
  if IsCrtMemoryManagerInstalled then
    UninstallCrtMemoryManager;
  if not IsCrtMemoryManagerInstalled then
    InstallCrtMemoryManager;
end;

begin
  TouchCrtManagerContracts;
end.
