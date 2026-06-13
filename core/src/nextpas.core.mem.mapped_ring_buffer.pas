{$CODEPAGE UTF8}
unit nextpas.core.mem.mapped_ring_buffer;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.mapped.ring_buffer;

{$WARNING 'deprecated: use nextpas.core.io.mapped.ring_buffer'}

type
  TMappedRingBufferMode = nextpas.core.io.mapped.ring_buffer.TMappedRingBufferMode;
  TMappedRingBuffer = nextpas.core.io.mapped.ring_buffer.TMappedRingBuffer;

implementation

end.
