unit nextpas.core.mem.adapters;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.compat;

type
  TMemPoolAdapter = nextpas.core.mem.compat.TMemPoolAdapter deprecated 'Use nextpas.core.mem.compat.TMemPoolAdapter instead';
  TStackPoolAdapter = nextpas.core.mem.compat.TStackPoolAdapter deprecated 'Use nextpas.core.mem.compat.TStackPoolAdapter instead';
  TSlabPoolAdapter = nextpas.core.mem.compat.TSlabPoolAdapter deprecated 'Use nextpas.core.mem.compat.TSlabPoolAdapter instead';

{$WARNING 'nextpas.core.mem.adapters is deprecated: use nextpas.core.mem.compat'}

implementation

end.
