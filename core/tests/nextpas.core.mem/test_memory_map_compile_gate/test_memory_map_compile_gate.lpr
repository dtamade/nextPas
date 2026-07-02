program test_memory_map_compile_gate;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.mem.allocator,
  nextpas.core.mem.allocator.mmap,
  nextpas.core.mem.memory_map;

var
  LMap: TMemoryMap;
  LAllocator: IAllocator;

begin
  LMap := TMemoryMap.Create;
  try
    LAllocator := CreateAnonymousMemoryMapAllocator(4096);
  finally
    LMap.Free;
  end;
end.
