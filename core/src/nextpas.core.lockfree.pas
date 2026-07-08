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
  nextpas.core.lockfree.channel.spsc,
  nextpas.core.lockfree.hashmap,
  nextpas.core.lockfree.hashset,
  nextpas.core.lockfree.skiplist,
  nextpas.core.lockfree.btree,
  nextpas.core.lockfree.segqueue,
  nextpas.core.lockfree.spmc,
  nextpas.core.lockfree.selector,
  nextpas.core.lockfree.selector.impl,
  nextpas.core.lockfree.priority_queue,
  nextpas.core.lockfree.bag,
  nextpas.core.lockfree.multimap,
  nextpas.core.lockfree.bloom,
  nextpas.core.lockfree.lru,
  nextpas.core.lockfree.counter,
  nextpas.core.lockfree.semaphore,
  nextpas.core.lockfree.mutex,
  nextpas.core.lockfree.rwlock;

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
    @see TShardedHashMap 保持向后兼容
  }
  generic TConcurrentHashMap<TKey, TValue> = class(specialize TShardedHashMapImpl<TKey, TValue>)
  end;

  {** @desc 并发跳表
    @details 使用读写锁实现并发安全，支持有序键值对存储。
      读操作允许多读者并发，写操作独占访问。
    @see TConcurrentSkipListImpl 详细文档和示例
  }
  generic TConcurrentSkipList<TKey, TValue> = class(specialize TConcurrentSkipListImpl<TKey, TValue>)
  end;

  {** @desc 并发 B-Tree
    @details 使用读写锁实现并发安全，支持有序键值对存储和高效范围查询。
      读操作使用无锁读，写操作使用写锁独占访问。
    @see TConcurrentBTreeImpl 详细文档和示例
  }
  generic TConcurrentBTree<TKey, TValue> = class(specialize TConcurrentBTreeImpl<TKey, TValue>)
  end;

  {** @desc 并发 HashSet
    @details 基于 TShardedHashMap 实现，所有值固定为 True。
      支持 Insert/Remove/Contains/Count/ForEach/Clear。
    @see TConcurrentHashSetImpl 详细文档和示例
  }
  generic TConcurrentHashSet<TKey> = class(specialize TConcurrentHashSetImpl<TKey>)
  end;

  {** @desc 并发优先队列
    @details 基于二叉堆实现，使用互斥锁保证线程安全。
      最小堆：优先级值最小的元素最先出队。
    @see TConcurrentPriorityQueueImpl 详细文档和示例
  }
  generic TConcurrentPriorityQueue<T> = class(specialize TConcurrentPriorityQueueImpl<T>)
  end;

  {** @desc 无锁并发 Bag（允许重复元素）
    @details 基于 MPMC 队列实现，允许重复元素。
      支持 TryAdd/TryTake/Wait/Timeout/Close。
      适用于任务队列、工作池等场景。
    @see TLockFreeBagImpl 详细文档和示例
  }
  generic TLockFreeBag<T> = class(specialize TLockFreeBagImpl<T>)
  end;

  {** @desc 并发 MultiMap（一个键可以有多个值）
    @details 基于分片锁 HashMap 实现，每个键对应一个值列表。
      支持 Add/Find/Remove/Contains/Count。
      适用于索引、标签系统等场景。
    @see TLockFreeMultiMapImpl 详细文档和示例
  }
  generic TLockFreeMultiMap<TKey, TValue> = class(specialize TLockFreeMultiMapImpl<TKey, TValue>)
  end;

  {** @desc 并发布隆过滤器
    @details 基于多个哈希函数的概率数据结构。
      支持 Add/Contains/Clear/Count。
      适用于快速成员检查、去重等场景。
      注意：可能存在假阳性（false positive），但不会有假阴性（false negative）。
    @see TConcurrentBloomFilterImpl 详细文档和示例
  }
  generic TConcurrentBloomFilter<T> = class(specialize TConcurrentBloomFilterImpl<T>)
  end;

  {** @desc 并发 LRU 缓存
    @details 基于分片锁 HashMap + 双向链表实现。
      支持 Get/Put/Remove/Clear/Capacity/Count。
      适用于缓存、淘汰等场景。
    @see TConcurrentLruCacheImpl 详细文档和示例
  }
  generic TConcurrentLruCache<TKey, TValue> = class(specialize TConcurrentLruCacheImpl<TKey, TValue>)
  end;

  {** @desc 并发计数器
    @details 基于原子操作的高性能计数器。
      支持 Increment/Decrement/Add/Sub/Load/Store/Reset。
      适用于统计、计数等场景。
    @see TConcurrentCounter 详细文档和示例
  }
  TConcurrentCounter = nextpas.core.lockfree.counter.TConcurrentCounter;

  {** @desc 并发信号量
    @details 基于原子操作的信号量实现。
      支持 Acquire/Release/TryAcquire/AcquireTimeout。
      适用于资源池、限流等场景。
    @see TConcurrentSemaphore 详细文档和示例
  }
  TConcurrentSemaphore = nextpas.core.lockfree.semaphore.TConcurrentSemaphore;

  {** @desc 并发互斥锁
    @details 基于原子操作的互斥锁实现。
      支持 Lock/Unlock/TryLock/LockTimeout。
      适用于需要互斥访问的场景。
    @see TConcurrentMutex 详细文档和示例
  }
  TConcurrentMutex = nextpas.core.lockfree.mutex.TConcurrentMutex;

  {** @desc 并发读写锁
    @details 基于原子操作的读写锁实现。
      支持 ReadLock/WriteLock/Unlock/TryReadLock/TryWriteLock。
      适用于读多写少的场景。
    @see TConcurrentRwLock 详细文档和示例
  }
  TConcurrentRwLock = nextpas.core.lockfree.rwlock.TConcurrentRwLock;

implementation

end.
