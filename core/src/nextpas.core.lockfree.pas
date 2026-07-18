unit nextpas.core.lockfree;

{**
 * @desc T1 runtime-core facade for nextpas.core.lockfree.
 *
 * Default entry pulls only the runtime-critical surface:
 * queues (SPSC/MPMC/MPSC/SPMC/SegQueue/MSQueue), stack, work-stealing deque,
 * EBR/Hazard, channel + selector, sharded hashmap (+ ConcurrentHashMap alias).
 *
 * T2/T3 structures (trees, caches, CRDT, RTM/NUMA extensions, sync primitives
 * beyond core queues, probabilistic filters, etc.) remain available only by
 * importing their own units (e.g. nextpas.core.lockfree.skiplist).
 *
 * Progress guarantees vary by type; see core/docs/lockfree/README.md matrix.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base,
  nextpas.core.lockfree.spsc,
  nextpas.core.lockfree.mpmc,
  nextpas.core.lockfree.mpsc,
  nextpas.core.lockfree.spmc,
  nextpas.core.lockfree.segqueue,
  nextpas.core.lockfree.msqueue,
  nextpas.core.lockfree.stack,
  nextpas.core.lockfree.deque,
  nextpas.core.lockfree.ebr,
  nextpas.core.lockfree.hazard,
  nextpas.core.lockfree.channel,
  nextpas.core.lockfree.selector,
  nextpas.core.lockfree.selector.impl,
  nextpas.core.lockfree.hashmap;

const
  SEGQUEUE_SEGMENT_CAPACITY = nextpas.core.lockfree.segqueue.SEGQUEUE_SEGMENT_CAPACITY;
  HAZARD_DEFAULT_HP_COUNT = nextpas.core.lockfree.hazard.HAZARD_DEFAULT_HP_COUNT;
  HAZARD_RETIRE_BATCH = nextpas.core.lockfree.hazard.HAZARD_RETIRE_BATCH;

type
  TEbrDomain = nextpas.core.lockfree.ebr.TEbrDomain;
  TEbrGuard = nextpas.core.lockfree.ebr.TEbrGuard;
  TLockFreeReclaimProc = nextpas.core.lockfree.ebr.TLockFreeReclaimProc;
  THazardDomain = nextpas.core.lockfree.hazard.THazardDomain;
  THazardGuard = nextpas.core.lockfree.hazard.THazardGuard;
  TSelectResult = nextpas.core.lockfree.selector.TSelectResult;
  TLockFreeMsQueueResult = nextpas.core.lockfree.msqueue.TLockFreeMsQueueResult;
  TLockFreeTryError = nextpas.core.lockfree.base.TLockFreeTryError;

  {** @desc QSBR 域（TQSBRDomain 是 TEbrDomain 的语义别名）
    @details Quiescent-State Based Reclamation：仅当 FActiveCount=0 时回收所有退休节点。
      适用场景：SegQueue 等临界区极短的无锁数据结构。
    @see TEbrDomain 保持向后兼容
    @see THazardDomain 用于读多写少、临界区较长的场景
  }
  TQSBRDomain = TEbrDomain;
  TQSBRGuard = TEbrGuard;

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

  {** @desc 多路 Channel 复用器（类型安全泛型包装）
    @details 所有 case 必须使用相同类型 T。支持阻塞和超时两种等待模式。
    @see TLockFreeSelectorImpl 详细文档和示例
  }
  generic TLockFreeSelector<T> = class(specialize TLockFreeSelectorImpl<T>)
  end;

  generic TShardedHashMap<TKey, TValue> = class(specialize TShardedHashMapImpl<TKey, TValue>)
  end;

  {** @desc 并发安全的分片锁 HashMap（TShardedHashMap 的语义别名）
    @details 使用分片自旋锁实现并发安全，适合低到中等竞争场景。
      与 TShardedHashMap 完全等价，仅命名更准确。
      Progress: lock-based concurrent (NOT lock-free).
    @see TShardedHashMap 保持向后兼容
  }
  generic TConcurrentHashMap<TKey, TValue> = class(specialize TShardedHashMapImpl<TKey, TValue>)
  end;

  {** @desc Michael-Scott 无锁无界 MPMC 队列
    @details 经典无锁队列算法，使用 index-based 节点池。
      入队 CAS 更新 tail.next，出队 CAS 移动 head。
      Sentinel 节点简化空队列边界处理。支持自动扩容和 Close 语义。
    @see TLockFreeMsQueueImpl 详细文档和示例
  }
  generic TLockFreeMsQueue<T> = class(specialize TLockFreeMsQueueImpl<T>)
  end;

implementation

end.
