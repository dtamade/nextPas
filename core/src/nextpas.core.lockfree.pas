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
  nextpas.core.lockfree.rwlock,
  nextpas.core.lockfree.countdown,
  nextpas.core.lockfree.barrier,
  nextpas.core.lockfree.ratelimit,
  nextpas.core.lockfree.condvar,
  nextpas.core.lockfree.exchanger,
  nextpas.core.lockfree.phaser,
  nextpas.core.lockfree.stampedlock,
  nextpas.core.lockfree.ringbuffer,
  nextpas.core.lockfree.trie,
  nextpas.core.lockfree.timerwheel,
  nextpas.core.lockfree.timeoutqueue,
  nextpas.core.lockfree.workstealing;

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

  {** @desc 并发倒计时闩
    @details 类似 Go sync.WaitGroup，等待 N 个事件完成。
      支持 Done/DoneN/Wait/WaitTimeout。
    @see TCountDownLatch 详细文档和示例
  }
  TCountDownLatch = nextpas.core.lockfree.countdown.TCountDownLatch;

  {** @desc 并发循环屏障
    @details N 个线程在屏障点同步，所有线程到达后一起继续。
      支持 Await/AwaitTimeout/Reset。
    @see TCyclicBarrier 详细文档和示例
  }
  TCyclicBarrier = nextpas.core.lockfree.barrier.TCyclicBarrier;
  TCyclicBarrierWaitResult = nextpas.core.lockfree.barrier.TCyclicBarrierWaitResult;

  {** @desc 并发令牌桶限流器
    @details 以恒定速率生成令牌，请求消耗令牌。
      支持 TryAcquire/TryAcquireN。
    @see TTokenBucketLimiter 详细文档和示例
  }
  TTokenBucketLimiter = nextpas.core.lockfree.ratelimit.TTokenBucketLimiter;
  TLockFreeRateLimiterResult = nextpas.core.lockfree.ratelimit.TLockFreeRateLimiterResult;

  {** @desc 并发条件变量
    @details 配合 TConcurrentMutex 使用，实现条件等待。
      支持 Wait/WaitTimeout/Signal/Broadcast。
    @see TConditionVariable 详细文档和示例
  }
  TConditionVariable = nextpas.core.lockfree.condvar.TConditionVariable;
  TConditionVariableWaitResult = nextpas.core.lockfree.condvar.TConditionVariableWaitResult;

  {** @desc 并发交换器
    @details 两个线程交换值的同步点。
      支持 Exchange/ExchangeTimeout/Close。
    @see TExchangerImpl 详细文档和示例
  }
  generic TExchanger<T> = class(specialize TExchangerImpl<T>)
  end;
  TLockFreeExchangeResult = nextpas.core.lockfree.exchanger.TLockFreeExchangeResult;

  {** @desc 并发相位同步器
    @details 灵活的同步屏障，支持动态注册/注销。
      支持 Register/Arrive/ArriveAndAwaitAdvance/ArriveAndDeregister。
    @see TPhaser 详细文档和示例
  }
  TPhaser = nextpas.core.lockfree.phaser.TPhaser;
  TLockFreePhaserArriveResult = nextpas.core.lockfree.phaser.TLockFreePhaserArriveResult;

  {** @desc 并发戳锁
    @details 乐观读锁 + 悲观读写锁，读多写少场景比 RwLock 更高效。
      支持 ReadLock/WriteLock/TryOptimisticRead/Validate。
    @see TStampedLock 详细文档和示例
  }
  TStampedLock = nextpas.core.lockfree.stampedlock.TStampedLock;

  {** @desc 并发环形缓冲区
    @details 固定大小 FIFO 队列，基于数组实现。
      支持 TryWrite/TryRead/Wait/Timeout。
    @see TRingBufferImpl 详细文档和示例
  }
  generic TRingBuffer<T> = class(specialize TRingBufferImpl<T>)
  end;
  TLockFreeRingBufferResult = nextpas.core.lockfree.ringbuffer.TLockFreeRingBufferResult;

  {** @desc 并发 Trie 树
    @details 基于前缀树的并发键值存储。
      支持 Insert/Find/Delete/Contains/Count/Clear。
      适用于前缀匹配、自动补全、IP 路由等场景。
    @see TConcurrentTrieImpl 详细文档和示例
  }
  generic TConcurrentTrie<TValue> = class(specialize TConcurrentTrieImpl<TValue>)
  end;
  TLockFreeTrieResult = nextpas.core.lockfree.trie.TLockFreeTrieResult;

  {** @desc 并发定时器轮
    @details 高效管理大量定时任务的数据结构。
      支持 Schedule/Cancel/Tick/ProcessExpired。
    @see TTimerWheel 详细文档和示例
  }
  TTimerWheel = nextpas.core.lockfree.timerwheel.TTimerWheel;
  TLockFreeTimerResult = nextpas.core.lockfree.timerwheel.TLockFreeTimerResult;

  {** @desc 并发超时队列
    @details 元素带有过期时间的并发队列。
      过期元素自动跳过，返回下一个有效元素。
    @see TTimeoutQueueImpl 详细文档和示例
  }
  generic TTimeoutQueue<T> = class(specialize TTimeoutQueueImpl<T>)
  end;
  TLockFreeTimeoutQueueResult = nextpas.core.lockfree.timeoutqueue.TLockFreeTimeoutQueueResult;

  {** @desc 并发工作窃取线程池
    @details 每个工作线程有自己的双端队列。
      本地任务 LIFO push/pop，窃取任务 FIFO steal。
    @see TWorkStealingPool 详细文档和示例
  }
  TWorkStealingPool = nextpas.core.lockfree.workstealing.TWorkStealingPool;
  TLockFreeWorkStealingResult = nextpas.core.lockfree.workstealing.TLockFreeWorkStealingResult;

implementation

end.
