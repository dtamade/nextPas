unit nextpas.core.mem.base;

{$I nextpas.core.settings.inc}

interface

const
  MEM_DEFAULT_ALIGN = SizeOf(Pointer);
  MEM_CACHE_LINE_SIZE = 64;
  MEM_PAGE_SIZE = 4096;

type
  TAllocatorKind = (
    akDefault,
    akArena,
    akPool,
    akMimalloc
  );

  TArenaMarker = SizeUInt;

implementation

end.
