unit nextpas.core.mem.mapped_ring_buffer;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.mapped.ring_buffer;

type
  TMappedRingBufferMode = nextpas.core.io.mapped.ring_buffer.TMappedRingBufferMode
    deprecated 'Use nextpas.core.io.mapped.ring_buffer.TMappedRingBufferMode';
  TMappedRingBuffer = nextpas.core.io.mapped.ring_buffer.TMappedRingBuffer
    deprecated 'Use nextpas.core.io.mapped.ring_buffer.TMappedRingBuffer';

const
  mrbProducer: nextpas.core.io.mapped.ring_buffer.TMappedRingBufferMode =
    nextpas.core.io.mapped.ring_buffer.mrbProducer;
  mrbConsumer: nextpas.core.io.mapped.ring_buffer.TMappedRingBufferMode =
    nextpas.core.io.mapped.ring_buffer.mrbConsumer;
  mrbBidirectional: nextpas.core.io.mapped.ring_buffer.TMappedRingBufferMode =
    nextpas.core.io.mapped.ring_buffer.mrbBidirectional;

{$WARNING 'nextpas.core.mem.mapped_ring_buffer is deprecated: use nextpas.core.io.mapped.ring_buffer'}

implementation

end.
