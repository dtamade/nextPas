unit nextpas.core.lockfree;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base,
  nextpas.core.lockfree.spsc,
  nextpas.core.lockfree.mpmc,
  nextpas.core.lockfree.stack,
  nextpas.core.lockfree.mpsc,
  nextpas.core.lockfree.deque,
  nextpas.core.lockfree.ebr,
  nextpas.core.lockfree.hazard,
  nextpas.core.lockfree.channel,
  nextpas.core.lockfree.hashmap,
  nextpas.core.lockfree.segqueue,
  nextpas.core.lockfree.spmc;

const
  SEGQUEUE_SEGMENT_CAPACITY = nextpas.core.lockfree.segqueue.SEGQUEUE_SEGMENT_CAPACITY;
  HAZARD_DEFAULT_HP_COUNT = nextpas.core.lockfree.hazard.HAZARD_DEFAULT_HP_COUNT;
  HAZARD_RETIRE_BATCH = nextpas.core.lockfree.hazard.HAZARD_RETIRE_BATCH;

type
  TEbrDomain = nextpas.core.lockfree.ebr.TEbrDomain;
  TEbrGuard = nextpas.core.lockfree.ebr.TEbrGuard;
  TLockFreeReclaimProc = nextpas.core.lockfree.ebr.TLockFreeReclaimProc;
  THazardDomain = nextpas.core.lockfree.hazard.THazardDomain;

  generic TSpscQueue<T> = class(specialize TSpscQueueImpl<T>)
  end;

  generic TMpmcQueue<T> = class(specialize TMpmcQueueImpl<T>)
  end;

  generic TLockFreeStack<T> = class(specialize TLockFreeStackImpl<T>)
  end;

  generic TMpscQueue<T> = class(specialize TMpscQueueImpl<T>)
  end;

  generic TWorkStealingDeque<T> = class(specialize TWorkStealingDequeImpl<T>)
  end;

  generic TSegQueue<T> = class(specialize TSegQueueImpl<T>)
  end;

  generic TSpmcQueue<T> = class(specialize TSpmcQueueImpl<T>)
  end;

  generic TLockFreeChannel<T> = class(specialize TLockFreeChannelImpl<T>)
  end;

  generic TLockFreeHashMap<TKey, TValue> = class(specialize TLockFreeHashMapImpl<TKey, TValue>)
  end;

implementation

end.
