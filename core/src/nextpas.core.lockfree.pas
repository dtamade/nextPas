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
  nextpas.core.lockfree.workstealing,
  nextpas.core.lockfree.snapshot,
  nextpas.core.lockfree.graph,
  nextpas.core.lockfree.msqueue,
  nextpas.core.lockfree.forkjoin,
  nextpas.core.lockfree.cowarray,
  nextpas.core.lockfree.disjointset,
  nextpas.core.lockfree.hashtable,
  nextpas.core.lockfree.sortedset,
  nextpas.core.lockfree.bitset,
  nextpas.core.lockfree.linkedlist,
  nextpas.core.lockfree.statscounter,
  nextpas.core.lockfree.consistent_hashring,
  nextpas.core.lockfree.trie_hmt,
  nextpas.core.lockfree.intervaltree,
  nextpas.core.lockfree.fibheap,
  nextpas.core.lockfree.countminsketch,
  nextpas.core.lockfree.hyperloglog,
  nextpas.core.lockfree.cuckooset,
  nextpas.core.lockfree.suffixarray,
  nextpas.core.lockfree.persistent_vector,
  nextpas.core.lockfree.roaring_bitmap,
  nextpas.core.lockfree.counting_bloom,
  nextpas.core.lockfree.lru_cache,
  nextpas.core.lockfree.deque_lf,
  nextpas.core.lockfree.trie_map,
  nextpas.core.lockfree.skiplist_map,
  nextpas.core.lockfree.ttl_cache,
  nextpas.core.lockfree.timeseries_ringbuffer,
  nextpas.core.lockfree.dag,
  nextpas.core.lockfree.merkle_tree,
  nextpas.core.lockfree.crdt,
  nextpas.core.lockfree.actor,
  nextpas.core.lockfree.rope,
  nextpas.core.lockfree.lfu,
  nextpas.core.lockfree.scalable_bloom,
  nextpas.core.lockfree.flatcombining,
  nextpas.core.lockfree.rcu,
  nextpas.core.lockfree.rbtree,
  nextpas.core.lockfree.fenwick,
  nextpas.core.lockfree.treap,
  nextpas.core.lockfree.scapegoat,
  nextpas.core.lockfree.radix,
  nextpas.core.lockfree.bplus,
  nextpas.core.lockfree.tdigest,
  nextpas.core.lockfree.spacesaving,
  nextpas.core.lockfree.arccache,
  nextpas.core.lockfree.adjmap,
  nextpas.core.lockfree.matrix,
  nextpas.core.lockfree.wrr;

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

  {** @desc 并发快照隔离
    @details 每个事务看到数据库在事务开始时的快照。
      支持多版本并发控制 (MVCC)。
    @see TSnapshotIsolationImpl 详细文档和示例
  }
  generic TSnapshotIsolation<TValue> = class(specialize TSnapshotIsolationImpl<TValue>)
  end;
  TSnapshotResult = nextpas.core.lockfree.snapshot.TSnapshotResult;

  {** @desc 并发无锁图
    @details 基于邻接表的并发图数据结构。
      支持 AddVertex/RemoveVertex/AddEdge/RemoveEdge/HasEdge。
    @see TLockFreeGraph 详细文档和示例
  }
  TLockFreeGraph = nextpas.core.lockfree.graph.TLockFreeGraph;
  TLockFreeGraphResult = nextpas.core.lockfree.graph.TLockFreeGraphResult;

  {** @desc Michael-Scott 无锁无界 MPMC 队列
    @details 经典无锁队列算法，使用 index-based 节点池。
      入队 CAS 更新 tail.next，出队 CAS 移动 head。
      Sentinel 节点简化空队列边界处理。支持自动扩容和 Close 语义。
    @see TLockFreeMsQueueImpl 详细文档和示例
  }
  generic TLockFreeMsQueue<T> = class(specialize TLockFreeMsQueueImpl<T>)
  end;
  TLockFreeMsQueueResult = nextpas.core.lockfree.msqueue.TLockFreeMsQueueResult;

  {** @desc ForkJoin 并行执行框架
    @details 类似 Java ForkJoinPool，支持递归分治任务。
      每个工作者有本地双端队列，本地 LIFO + 窃取 FIFO。
    @see TLockFreeForkJoinPool 详细文档和示例
  }
  TLockFreeForkJoinPool = nextpas.core.lockfree.forkjoin.TLockFreeForkJoinPool;
  TForkJoinTask = nextpas.core.lockfree.forkjoin.TForkJoinTask;
  TForkJoinTaskProc = nextpas.core.lockfree.forkjoin.TForkJoinTaskProc;
  TLockFreeForkJoinResult = nextpas.core.lockfree.forkjoin.TLockFreeForkJoinResult;

  {** @desc 写时复制数组
    @details 读无锁，写时复制整个数组。适合读多写极少场景。
      线程安全的快照语义，支持索引访问、追加、替换、删除。
    @see TCopyOnWriteArrayImpl 详细文档和示例
  }
  generic TCopyOnWriteArray<T> = class(specialize TCopyOnWriteArrayImpl<T>)
  end;
  TLockFreeCowArrayResult = nextpas.core.lockfree.cowarray.TLockFreeCowArrayResult;

  {** @desc 并查集（不相交集合）
    @details 支持路径压缩 + 按秩合并。均摊 O(α(n)) ≈ O(1)。
      适用于动态连通性查询、聚类、图算法。
    @see TLockFreeDisjointSet 详细文档和示例
  }
  TLockFreeDisjointSet = nextpas.core.lockfree.disjointset.TLockFreeDisjointSet;
  TLockFreeDisjointSetResult = nextpas.core.lockfree.disjointset.TLockFreeDisjointSetResult;

  {** @desc 无锁哈希表（开放寻址）
    @details 使用 CAS 操作实现无锁并发访问。
      开放寻址 + 线性探测，2 的幂容量，自动扩容。
    @see TLockFreeHashTableImpl 详细文档和示例
  }
  generic TLockFreeHashTable<TKey, TValue> = class(specialize TLockFreeHashTableImpl<TKey, TValue>)
  end;
  TLockFreeHashTableResult = nextpas.core.lockfree.hashtable.TLockFreeHashTableResult;

  {** @desc 并发有序集合
    @details 基于有序数组实现，写时复制，读无锁。
      二分查找，支持 Insert/Remove/Contains/Count。
    @see TConcurrentSortedSetImpl 详细文档和示例
  }
  generic TConcurrentSortedSet<T> = class(specialize TConcurrentSortedSetImpl<T>)
  end;
  TLockFreeSortedSetResult = nextpas.core.lockfree.sortedset.TLockFreeSortedSetResult;

  {** @desc 并发位集合
    @details 使用原子 CAS 操作每一位。
      支持 Set/Clear/Flip/Test/TestAndSet/TestAndClear，自动扩容。
    @see TConcurrentBitSet 详细文档和示例
  }
  TConcurrentBitSet = nextpas.core.lockfree.bitset.TConcurrentBitSet;
  TLockFreeBitSetResult = nextpas.core.lockfree.bitset.TLockFreeBitSetResult;

  {** @desc 并发有序链表
    @details 基于读写锁的并发链表，支持有序插入和遍历。
      保持升序排列，支持 Insert/Remove/Contains/Get/Clear。
    @see TConcurrentLinkedListImpl 详细文档和示例
  }
  generic TConcurrentLinkedList<T> = class(specialize TConcurrentLinkedListImpl<T>)
  end;
  TLockFreeLinkedListResult = nextpas.core.lockfree.linkedlist.TLockFreeLinkedListResult;

  {** @desc 并发统计计数器
    @details 支持 min/max/sum/count/mean 的并发统计。
      所有操作原子化，适用性能监控和指标收集。
    @see TConcurrentStatsCounter 详细文档和示例
  }
  TConcurrentStatsCounter = nextpas.core.lockfree.statscounter.TConcurrentStatsCounter;

  {** @desc 一致性哈希环
    @details 用于分布式系统的虚拟节点哈希环。
      支持 AddNode/RemoveNode/GetNode/GetNodes。
    @see TConsistentHashRing 详细文档和示例
  }
  TConsistentHashRing = nextpas.core.lockfree.consistent_hashring.TConsistentHashRing;
  TConsistentHashRingResult = nextpas.core.lockfree.consistent_hashring.TConsistentHashRingResult;

  {** @desc Hash Mapped Trie (HMT)
    @details 持久化不可变 Trie，支持路径复制和原子快照。
      适用于持久化映射、版本快照、函数式编程。
    @see THashMappedTrie 详细文档和示例
  }
  THashMappedTrie = nextpas.core.lockfree.trie_hmt.THashMappedTrie;
  THmtResult = nextpas.core.lockfree.trie_hmt.THmtResult;

  {** @desc 并发区间树
    @details 基于 AVL 树的区间重叠查询。写用自旋锁，读无锁（COW 快照）。
      适用于日程安排、IP 范围查找、基因组区间。
    @see TIntervalTree 详细文档和示例
  }
  TIntervalTree = nextpas.core.lockfree.intervaltree.TIntervalTree;
  TIntervalTreeResult = nextpas.core.lockfree.intervaltree.TIntervalTreeResult;

  {** @desc 并发 Fibonacci 堆
    @details 摊还 O(1) 插入/合并，O(log n) 提取最小值。
      适用于 Dijkstra 算法、优先队列合并。
    @see TLockFreeFibonacciHeap 详细文档和示例
  }
  TLockFreeFibonacciHeap = nextpas.core.lockfree.fibheap.TLockFreeFibonacciHeap;
  TFibHeapResult = nextpas.core.lockfree.fibheap.TFibHeapResult;

  {** @desc Count-Min Sketch
    @details 概率频率估计器，O(1) 更新和查询。
      适用于网络流量分析、频率估计、限流。
    @see TCountMinSketch 详细文档和示例
  }
  TCountMinSketch = nextpas.core.lockfree.countminsketch.TCountMinSketch;

  {** @desc HyperLogLog
    @details 概率基数估计器，标准误差 1.04/sqrt(2^p)。
      适用于唯一计数、基数估计。
    @see THyperLogLog 详细文档和示例
  }
  THyperLogLog = nextpas.core.lockfree.hyperloglog.THyperLogLog;

  {** @desc Cuckoo Hash Set
    @details O(1) 最坏情况查找的并发集合。
      双哈希表 + 布谷鸟驱逐，写用自旋锁，读无锁。
    @see TCuckooSet 详细文档和示例
  }
  TCuckooSet = nextpas.core.lockfree.cuckooset.TCuckooSet;
  TCuckooSetResult = nextpas.core.lockfree.cuckooset.TCuckooSetResult;

  {** @desc 后缀数组
    @details 预排序后缀索引，O(m log n) 模式搜索。
      适用于全文搜索、模式匹配、生物信息学。
    @see TSuffixArray 详细文档和示例
  }
  TSuffixArray = nextpas.core.lockfree.suffixarray.TSuffixArray;
  TSuffixArrayResult = nextpas.core.lockfree.suffixarray.TSuffixArrayResult;
  TSuffixArrayMatch = nextpas.core.lockfree.suffixarray.TSuffixArrayMatch;

  {** @desc 持久化不可变向量
    @details O(n) append/assoc，O(1) nth。所有操作返回新向量。
    @see TPersistentVector 详细文档和示例
  }
  TPersistentVector = nextpas.core.lockfree.persistent_vector.TPersistentVector;
  TPVectorResult = nextpas.core.lockfree.persistent_vector.TPVectorResult;

  {** @desc Roaring Bitmap
    @details 压缩位图，支持 AND/OR/XOR 集合操作。
    @see TRoaringBitmap 详细文档和示例
  }
  TRoaringBitmap = nextpas.core.lockfree.roaring_bitmap.TRoaringBitmap;
  TRBResult = nextpas.core.lockfree.roaring_bitmap.TRBResult;

  {** @desc Counting Bloom Filter
    @details 支持删除的布隆过滤器，原子计数器。
    @see TCountingBloomFilter 详细文档和示例
  }
  TCountingBloomFilter = nextpas.core.lockfree.counting_bloom.TCountingBloomFilter;
  TCBFResult = nextpas.core.lockfree.counting_bloom.TCBFResult;

  {** @desc Concurrent LRU Cache (AnsiString 专用)
    @details 线程安全的最近最少使用缓存，哈希表+双向链表。AnsiString 键值。
    @see TConcurrentStringLRUCache 详细文档和示例
  }
  TConcurrentStringLRUCache = nextpas.core.lockfree.lru_cache.TConcurrentLRUCache;
  TStringLRUCacheResult = nextpas.core.lockfree.lru_cache.TLRUCacheResult;

  {** @desc Lock-Free Deque
    @details 双端队列，支持 PushLeft/PushRight/PopLeft/PopRight。
    @see TLockFreeDeque 详细文档和示例
  }
  TLockFreeDeque = nextpas.core.lockfree.deque_lf.TLockFreeDeque;
  TDequeResult = nextpas.core.lockfree.deque_lf.TDequeResult;

  {** @desc Concurrent Trie Map — 并发字典树映射
    @details O(k) 查找/插入/删除，k = key 长度。16-way 分支。
    @see TConcurrentTrieMap 详细文档和示例
  }
  TConcurrentTrieMap = nextpas.core.lockfree.trie_map.TConcurrentTrieMap;
  TTrieMapResult = nextpas.core.lockfree.trie_map.TTrieMapResult;
  TTrieMapForEachCallback = nextpas.core.lockfree.trie_map.TTrieMapForEachCallback;

  {** @desc Concurrent SkipList Map — 并发有序映射
    @details O(log n) 查找/插入/删除，基于跳表。支持有序遍历。
    @see TConcurrentSkipListMap 详细文档和示例
  }
  TConcurrentSkipListMap = nextpas.core.lockfree.skiplist_map.TConcurrentSkipListMap;
  TSkipListMapResult = nextpas.core.lockfree.skiplist_map.TSkipListMapResult;
  TSkipListMapForEachCallback = nextpas.core.lockfree.skiplist_map.TSkipListMapForEachCallback;

  {** @desc TTL Cache — 带过期时间的并发缓存
    @details 支持全局默认 TTL 和 per-entry TTL。惰性清理过期条目。
    @see TTTLCache 详细文档和示例
  }
  TTTLCache = nextpas.core.lockfree.ttl_cache.TTTLCache;
  TTTLCacheResult = nextpas.core.lockfree.ttl_cache.TTTLCacheResult;

  {** @desc Time Series Ring Buffer — 时间序列环形缓冲区
    @details 固定容量环形缓冲区，每个条目带时间戳。支持 TTL 过期和时间范围查询。
    @see TTimeSeriesRingBuffer 详细文档和示例
  }
  TTimeSeriesRingBuffer = nextpas.core.lockfree.timeseries_ringbuffer.TTimeSeriesRingBuffer;
  TTSRingResult = nextpas.core.lockfree.timeseries_ringbuffer.TTSRingResult;

  {** @desc Concurrent DAG — 有向无环图
    @details 拓扑排序、环检测、路径查找。每节点自旋锁保证并发安全。
    @see TConcurrentDAG 详细文档和示例
  }
  TConcurrentDAG = nextpas.core.lockfree.dag.TConcurrentDAG;
  TDagResult = nextpas.core.lockfree.dag.TDagResult;
  TDagTopoCallback = nextpas.core.lockfree.dag.TDagTopoCallback;

  {** @desc Merkle Tree — 哈希树
    @details FNV-1a 哈希，数据完整性验证。
    @see TMerkleTree 详细文档和示例
  }
  TMerkleTree = nextpas.core.lockfree.merkle_tree.TMerkleTree;
  TMerkleResult = nextpas.core.lockfree.merkle_tree.TMerkleResult;

  {** @desc CRDT — 冲突自由复制数据类型
    @details G-Counter, PN-Counter, LWW-Register, OR-Set。
    @see TGCounter/TPNCounter/TLWWRegister/TORSet 详细文档和示例
  }
  TGCounter = nextpas.core.lockfree.crdt.TGCounter;
  TPNCounter = nextpas.core.lockfree.crdt.TPNCounter;
  TLWWRegister = nextpas.core.lockfree.crdt.TLWWRegister;
  TORSet = nextpas.core.lockfree.crdt.TORSet;
  TCRDTResult = nextpas.core.lockfree.crdt.TCRDTResult;

  {** @desc Actor — 消息驱动并发模型
    @details 每个 Actor 有独立邮箱，按顺序处理消息。
    @see TActor/TActorSystem 详细文档和示例
  }
  TActor = nextpas.core.lockfree.actor.TActor;
  TActorSystem = nextpas.core.lockfree.actor.TActorSystem;
  TActorResult = nextpas.core.lockfree.actor.TActorResult;
  TActorMessage = nextpas.core.lockfree.actor.TActorMessage;
  TActorHandler = nextpas.core.lockfree.actor.TActorHandler;

  {** @desc Rope — 大字符串数据结构
    @details 二叉树结构，O(log n) 拼接/切片/插入/删除。
    @see TRope 详细文档和示例
  }
  TRope = nextpas.core.lockfree.rope.TRope;
  TRopeResult = nextpas.core.lockfree.rope.TRopeResult;

  {** @desc LFU 缓存 — 频率淘汰策略
    @details 访问频率最低的条目优先被淘汰。
    @see TConcurrentLFUCache 详细文档和示例
  }
  TLockFreeLfuAddResult = nextpas.core.lockfree.lfu.TLockFreeLfuAddResult;

  {** @desc 可扩容布隆过滤器
    @details 当前层 FPR 超过阈值时自动添加新层。
    @see TScalableBloomFilter 详细文档和示例
  }

  {** @desc Flat Combining 同步原语
    @details 高竞争下批量操作，吞吐量远优于传统锁。
    @see TFlatCombiningLock/TFlatCombiningCounter 详细文档和示例
  }
  TFlatCombiningLock = nextpas.core.lockfree.flatcombining.TFlatCombiningLock;
  TFlatCombiningCounter = nextpas.core.lockfree.flatcombining.TFlatCombiningCounter;
  TFCOpType = nextpas.core.lockfree.flatcombining.TFCOpType;

  {** @desc RCU — Read-Copy-Update
    @details 读操作无锁，写操作 Copy-on-Write。适用于读多写少场景。
    @see TRcuDomain/TRcuPublisher 详细文档和示例
  }
  TRcuDomain = nextpas.core.lockfree.rcu.TRcuDomain;
  TRcuGuard = nextpas.core.lockfree.rcu.TRcuGuard;

  {** @desc 并发红黑树
    @details 自平衡 BST，O(log n) 查找/插入/删除。
    @see TConcurrentRBTree 详细文档和示例
  }
  TConcurrentRBTree = nextpas.core.lockfree.rbtree.TConcurrentRBTree;
  TRBTreeResult = nextpas.core.lockfree.rbtree.TRBTreeResult;
  TRBForEachCallback = nextpas.core.lockfree.rbtree.TRBForEachCallback;

  {** @desc Fenwick Tree — 二叉索引树
    @details O(log n) 前缀和查询和单点更新。
    @see TConcurrentFenwickTree 详细文档和示例
  }
  TConcurrentFenwickTree = nextpas.core.lockfree.fenwick.TConcurrentFenwickTree;
  TFenwickResult = nextpas.core.lockfree.fenwick.TFenwickResult;

  {** @desc Treap — 随机化 BST
    @details 期望 O(log n) 查找/插入/删除。
    @see TConcurrentTreap 详细文档和示例
  }
  TConcurrentTreap = nextpas.core.lockfree.treap.TConcurrentTreap;
  TTreapResult = nextpas.core.lockfree.treap.TTreapResult;
  TTreapForEachCallback = nextpas.core.lockfree.treap.TTreapForEachCallback;

  {** @desc Scapegoat Tree — 无旋转平衡 BST
    @details 摊还 O(log n)，并发友好。
    @see TConcurrentScapegoatTree 详细文档和示例
  }
  TConcurrentScapegoatTree = nextpas.core.lockfree.scapegoat.TConcurrentScapegoatTree;
  TScapegoatResult = nextpas.core.lockfree.scapegoat.TScapegoatResult;
  TScapegoatForEachCallback = nextpas.core.lockfree.scapegoat.TScapegoatForEachCallback;

  {** @desc Radix Tree — 压缩前缀树
    @details O(k) 字符串查找/插入/删除。
    @see TConcurrentRadixTree 详细文档和示例
  }
  TConcurrentRadixTree = nextpas.core.lockfree.radix.TConcurrentRadixTree;
  TRadixResult = nextpas.core.lockfree.radix.TRadixResult;
  TRadixForEachCallback = nextpas.core.lockfree.radix.TRadixForEachCallback;

  {** @desc B+ Tree — 数据库索引结构
    @details 叶子节点链表连接，支持高效范围查询。
    @see TConcurrentBPlusTree 详细文档和示例
  }
  TConcurrentBPlusTree = nextpas.core.lockfree.bplus.TConcurrentBPlusTree;
  TBplusResult = nextpas.core.lockfree.bplus.TBplusResult;
  TBplusForEachCallback = nextpas.core.lockfree.bplus.TBplusForEachCallback;
  TBplusRangeCallback = nextpas.core.lockfree.bplus.TBplusRangeCallback;

  {** @desc T-Digest — 流式分位数估计
    @details P50/P99/P999 高精度估计，监控标配。
    @see TTDigestImpl 详细文档和示例
  }
  TTDigest = nextpas.core.lockfree.tdigest.TTDigestImpl;
  TTDigestStatus = nextpas.core.lockfree.tdigest.TTDigestStatus;

  {** @desc Space-Saving — Top-K 频繁项检测
    @details 流式 Heavy Hitters，O(log K) 插入。
    @see TSpaceSavingImpl 详细文档和示例
  }
  TSpaceSaving = nextpas.core.lockfree.spacesaving.TSpaceSavingImpl;
  TSpaceSavingStatus = nextpas.core.lockfree.spacesaving.TSpaceSavingStatus;
  TSpaceSavingResult = nextpas.core.lockfree.spacesaving.TSpaceSavingResult;

  {** @desc ARC Cache — 自适应替换缓存
    @details 比 LRU 更智能，自动平衡 recency/frequency。
    @see TARCCacheImpl 详细文档和示例
  }
  TARCCache = nextpas.core.lockfree.arccache.TARCCacheImpl;
  TARCCacheStatus = nextpas.core.lockfree.arccache.TARCCacheStatus;

  {** @desc Adjacency Map — 加权图邻接表
    @details 支持 Dijkstra 最短路径。
    @see TAdjMapImpl 详细文档和示例
  }
  TAdjMap = nextpas.core.lockfree.adjmap.TAdjMapImpl;
  TAdjMapStatus = nextpas.core.lockfree.adjmap.TAdjMapStatus;
  TPathResult = nextpas.core.lockfree.adjmap.TPathResult;

  {** @desc Concurrent Matrix — 并发矩阵运算
    @details 支持 Multiply/Transpose/Inverse/Determinant。
    @see TMatrixImpl 详细文档和示例
  }
  TMatrix = nextpas.core.lockfree.matrix.TMatrixImpl;
  TMatrixStatus = nextpas.core.lockfree.matrix.TMatrixStatus;

  {** @desc Weighted Round Robin — 加权轮询负载均衡器
    @details Nginx 平滑加权轮询算法。
    @see TWRRImpl 详细文档和示例
  }
  TWRR = nextpas.core.lockfree.wrr.TWRRImpl;
  TWRRStatus = nextpas.core.lockfree.wrr.TWRRStatus;

implementation

end.
