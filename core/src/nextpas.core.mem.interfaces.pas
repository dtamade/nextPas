unit nextpas.core.mem.interfaces;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.compat;

type
  IAllocator = nextpas.core.mem.compat.IAllocator deprecated 'Use nextpas.core.mem.compat.IAllocator instead';
  IMemPool = nextpas.core.mem.compat.IMemPool deprecated 'Use nextpas.core.mem.compat.IMemPool instead';
  IStackPool = nextpas.core.mem.compat.IStackPool deprecated 'Use nextpas.core.mem.compat.IStackPool instead';
  ISlabPool = nextpas.core.mem.compat.ISlabPool deprecated 'Use nextpas.core.mem.compat.ISlabPool instead';

{$WARNING 'nextpas.core.mem.interfaces is deprecated: use nextpas.core.mem.compat'}

implementation

end.
