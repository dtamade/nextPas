unit nextpas.core.mem.mapped_ring_buffer.sharded;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.mapped.ring_buffer.sharded;

type
  TMappedRingBufferSharded = nextpas.core.io.mapped.ring_buffer.sharded.TMappedRingBufferSharded
    deprecated 'Use nextpas.core.io.mapped.ring_buffer.sharded.TMappedRingBufferSharded';

{$WARNING 'nextpas.core.mem.mapped_ring_buffer.sharded is deprecated: use nextpas.core.io.mapped.ring_buffer.sharded'}

implementation

end.
