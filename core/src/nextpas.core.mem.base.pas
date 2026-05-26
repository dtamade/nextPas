unit nextpas.core.mem.base;

{$I nextpas.core.settings.inc}

interface

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
