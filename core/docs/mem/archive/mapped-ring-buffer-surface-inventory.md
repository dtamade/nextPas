# mapped_ring_buffer surface inventory

## Source units

| Unit | Lines | Location |
|------|-------|----------|
| `nextpas.core.mem.mapped_ring_buffer` | ~940 | `core/src/nextpas.core.mem.mapped_ring_buffer.pas` |
| `nextpas.core.mem.mapped_ring_buffer.sharded` | ~165 | `core/src/nextpas.core.mem.mapped_ring_buffer.sharded.pas` |

## Public types

### mapped_ring_buffer.pas

- `TMappedRingBufferMode` (enum: `mrbProducer`, `mrbConsumer`, `mrbBidirectional`)
- `TMappedRingBuffer` (class)
  - `CreateFile`, `OpenFile`, `CreateShared`, `OpenShared`, `Close`
  - `Push`, `Pop`, `Peek`, `PushBatch`, `PopBatch`
  - `Clear`, `IsEmpty`, `IsFull`, `IsValid`
  - Properties: `Capacity`, `ElementSize`, `AvailableSpace`, `UsedSpace`, `Mode`, `IsCreator`

### mapped_ring_buffer.sharded.pas

- `TMappedRingBufferSharded` (class)
  - `CreateShared`, `OpenShared`, `Close`
  - `Push`, `Pop`, `TryPush`, `TryPop`
  - Property: `ShardCount`

## Internal dependencies

- `mapped_ring_buffer.pas` uses: `nextpas.core.base.utils`, `nextpas.core.mem.memory_map`
- `mapped_ring_buffer.sharded.pas` uses: `nextpas.core.mem.mutex`, `nextpas.core.mem.mapped_ring_buffer`

## Consumers

No external consumers exist outside the mapped family:
- `mapped_ring_buffer.sharded.pas` depends on `mapped_ring_buffer.pas`
- No test program directly uses `mapped_ring_buffer` or `mapped_ring_buffer.sharded`
- `test_sharded_pools` tests sharded blockpool and slab, not ring_buffer
