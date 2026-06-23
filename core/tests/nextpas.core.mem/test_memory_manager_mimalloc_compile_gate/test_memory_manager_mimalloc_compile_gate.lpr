program test_memory_manager_mimalloc_compile_gate;

{$I nextpas.core.settings.inc}

{$IFNDEF NEXTPAS_CORE_MIMALLOC_ALLOCATOR}
  {$fatal NEXTPAS_CORE_MIMALLOC_ALLOCATOR must be enabled for the mimalloc manager compile gate}
{$ENDIF}

uses
  nextpas.core.mem.manager.mimalloc;

procedure TouchMimallocManagerContracts;
begin
  if IsMimallocMemoryManagerInstalled then
    UninstallMimallocMemoryManager;
  if not IsMimallocMemoryManagerInstalled then
    InstallMimallocMemoryManager;
end;

begin
  TouchMimallocManagerContracts;
end.
