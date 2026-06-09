program test_memory_map_compile_gate;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.mem.allocator,
  nextpas.core.mem.allocator.memory_map_allocator,
  nextpas.core.mem.memory_map,
  nextpas.core.mem.mapped_slab_pool;

var
  LMap: TMemoryMap;
  LAllocator: IAllocator;
  LPool: TMappedSlabPool;

begin
  LMap := TMemoryMap.Create;
  LPool := TMappedSlabPool.Create;
  try
    LAllocator := CreateAnonymousMemoryMapAllocator(4096);
  finally
    LPool.Free;
    LMap.Free;
  end;
end.
