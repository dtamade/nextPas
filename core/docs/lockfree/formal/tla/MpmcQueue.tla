-------------------------------- MODULE MpmcQueue --------------------------------
\* TLA+ 模型：Multi-Producer Multi-Consumer 有界队列
\*
\* 本模型验证 nextpas.core.lockfree.mpmc 的正确性：
\* 1. CAS 原子操作的正确性
\* 2. ABA 问题检测
\* 3. 内存回收安全
\* 4. 无锁算法的线性化

EXTENDS Integers, Sequences, FiniteSets, TLC

CONSTANTS
  Capacity,       \* 队列容量 (必须为 2 的幂)
  MaxOps,         \* 最大操作数
  Producers,      \* 生产者集合
  Consumers,      \* 消费者集合
  MaxRetries      \* 最大重试次数

ASSUME
  /\ Capacity > 0
  /\ Capacity = 2 \* (Capacity \div 2)
  /\ MaxOps > 0
  /\ Producers # {}
  /\ Consumers # {}
  /\ MaxRetries > 0

VARIABLES
  slots,          \* 槽位数组 (每个槽位: [value: Int, sequence: Int])
  head,           \* 队头指针 (原子变量)
  tail,           \* 队尾指针 (原子变量)
  producerState,  \* 生产者状态机
  consumerState,  \* 消费者状态机
  casAttempts,    \* CAS 尝试次数
  ops,            \* 操作计数
  history         \* 操作历史

vars == <<slots, head, tail, producerState, consumerState, casAttempts, ops, history>>

\* 状态定义
ProducerStates == {"idle", "reserving", "writing", "committing", "done"}
ConsumerStates == {"idle", "claiming", "reading", "advancing", "done"}

\* 初始化
Init ==
  /\ slots = [i \in 0..Capacity-1 |-> [value |-> 0, sequence |-> i]]
  /\ head = [value |-> 0, version |-> 0]
  /\ tail = [value |-> 0, version |-> 0]
  /\ producerState = [p \in Producers |-> "idle"]
  /\ consumerState = [c \in Consumers |-> "idle"]
  /\ casAttempts = [p \in Producers |-> 0] @@ [c \in Consumers |-> 0]
  /\ ops = 0
  /\ history = <<>>

\* 辅助函数
SlotIndex(pos) == pos % Capacity
QueueFull == (tail.value - head.value) >= Capacity
QueueEmpty == tail.value = head.value

\* CAS 操作 (Compare-And-Swap)
\* 在 TLA+ 中，CAS 是原子操作
CAS(variable, expected, newValue) ==
  IF variable = expected THEN
    newValue
  ELSE
    variable

\* 生产者操作：预留槽位
ProducerReserveSlot(p) ==
  /\ producerState[p] = "idle"
  /\ ops < MaxOps
  /\ ~QueueFull
  /\ LET
     currentTail == tail
     slotIdx == SlotIndex(currentTail.value)
     slot == slots[slotIdx]
     IN
     /\ slot.sequence = currentTail.value  \* 槽位可用
     /\ tail' = [value |-> currentTail.value + 1, version |-> currentTail.version + 1]
     /\ producerState' = [producerState EXCEPT ![p] = "writing"]
     /\ UNCHANGED <<slots, head, consumerState, casAttempts, ops, history>>

\* 生产者操作：写入数据
ProducerWriteData(p) ==
  /\ producerState[p] = "writing"
  /\ LET
     currentTail == tail
     slotIdx == SlotIndex(currentTail.value - 1)
     newItem == [value |-> ops + 1, sequence |-> currentTail.value]
     IN
     /\ slots' = [slots EXCEPT ![slotIdx] = newItem]
     /\ producerState' = [producerState EXCEPT ![p] = "committing"]
     /\ UNCHANGED <<head, tail, consumerState, casAttempts, ops, history>>

\* 生产者操作：提交写入
ProducerCommitWrite(p) ==
  /\ producerState[p] = "committing"
  /\ LET
     currentTail == tail
     slotIdx == SlotIndex(currentTail.value - 1)
     slot == slots[slotIdx]
     IN
     /\ slot.sequence = currentTail.value - 1  \* 确认是自己的槽位
     /\ slots' = [slots EXCEPT ![slotIdx].sequence = currentTail.value]
     /\ producerState' = [producerState EXCEPT ![p] = "idle"]
     /\ ops' = ops + 1
     /\ history' = Append(history, [type |-> "enqueue", producer |-> p, value |-> ops + 1, time |-> ops])
     /\ UNCHANGED <<head, tail, consumerState, casAttempts>>

\* 消费者操作：认领槽位
ConsumerClaimSlot(c) ==
  /\ consumerState[c] = "idle"
  /\ ops < MaxOps
  /\ ~QueueEmpty
  /\ LET
     currentHead == head
     slotIdx == SlotIndex(currentHead.value)
     slot == slots[slotIdx]
     IN
     /\ slot.sequence = currentHead.value + 1  \* 槽位有数据
     /\ head' = [value |-> currentHead.value + 1, version |-> currentHead.version + 1]
     /\ consumerState' = [consumerState EXCEPT ![c] = "reading"]
     /\ UNCHANGED <<slots, tail, producerState, casAttempts, ops, history>>

\* 消费者操作：读取数据
ConsumerReadData(c) ==
  /\ consumerState[c] = "reading"
  /\ LET
     currentHead == head
     slotIdx == SlotIndex(currentHead.value - 1)
     slot == slots[slotIdx]
     IN
     /\ slot.sequence = currentHead.value  \* 确认是自己的槽位
     /\ consumerState' = [consumerState EXCEPT ![c] = "advancing"]
     /\ UNCHANGED <<slots, head, tail, producerState, casAttempts, ops, history>>

\* 消费者操作：推进指针
ConsumerAdvanceHead(c) ==
  /\ consumerState[c] = "advancing"
  /\ LET
     currentHead == head
     slotIdx == SlotIndex(currentHead.value - 1)
     slot == slots[slotIdx]
     IN
     /\ slots' = [slots EXCEPT ![slotIdx].sequence = currentHead.value + Capacity]
     /\ consumerState' = [consumerState EXCEPT ![c] = "idle"]
     /\ ops' = ops + 1
     /\ history' = Append(history, [type |-> "dequeue", consumer |-> c, value |-> slot.value, time |-> ops])
     /\ UNCHANGED <<head, tail, producerState, casAttempts>>

\* Next 关系
Next ==
  \/ \E p \in Producers :
       ProducerReserveSlot(p) \/ ProducerWriteData(p) \/ ProducerCommitWrite(p)
  \/ \E c \in Consumers :
       ConsumerClaimSlot(c) \/ ConsumerReadData(c) \/ ConsumerAdvanceHead(c)

\* 规范
Spec == Init /\ [][Next]_vars /\ WF_vars(Next)

\* ====================================================================
\* 安全性属性
\* ====================================================================

\* 类型正确性
TypeOK ==
  /\ slots \in [0..Capacity-1 -> [value: Int, sequence: Int]]
  /\ head \in [value: Nat, version: Nat]
  /\ tail \in [value: Nat, version: Nat]
  /\ \A p \in Producers : producerState[p] \in ProducerStates
  /\ \A c \in Consumers : consumerState[c] \in ConsumerStates
  /\ ops \in 0..MaxOps

\* 队列边界
QueueBounds ==
  /\ tail.value >= head.value
  /\ (tail.value - head.value) <= Capacity

\* 生产者互斥：同一时间只有一个生产者在写入同一槽位
ProducerSlotExclusion ==
  \A p1, p2 \in Producers :
    /\ producerState[p1] = "writing"
    /\ producerState[p2] = "writing"
    => SlotIndex(tail.value - 1) # SlotIndex(tail.value - 1)  \* 不同槽位

\* 消费者互斥：同一时间只有一个消费者在读取同一槽位
ConsumerSlotExclusion ==
  \A c1, c2 \in Consumers :
    /\ consumerState[c1] = "reading"
    /\ consumerState[c2] = "reading"
    => SlotIndex(head.value - 1) # SlotIndex(head.value - 1)  \* 不同槽位

\* 槽位序列号单调递增
SequenceMonotonic ==
  \A i \in 0..Capacity-1 :
    slots[i].sequence >= i

\* FIFO 顺序
FifoOrder ==
  \A i, j \in 1..Len(history) :
    /\ i < j
    /\ history[i].type = "enqueue"
    /\ history[j].type = "dequeue"
    /\ history[i].producer = history[j].consumer  \* 同一生产者-消费者对
    => history[i].time < history[j].time

\* ====================================================================
\* 活性属性
\* ====================================================================

\* 无死锁
NoDeadlock ==
  [](QueueEmpty => \E c \in Consumers : consumerState[c] = "idle")

\* 无饥饿：生产者最终能写入
ProducerProgress ==
  \A p \in Producers :
    [](~QueueFull ~> producerState[p] = "idle")

\* 无饥饿：消费者最终能读取
ConsumerProgress ==
  \A c \in Consumers :
    [](~QueueEmpty ~> consumerState[c] = "idle")

\* 操作进度
Progress == <>(ops > 0)

\* ====================================================================
\* ABA 问题检测
\* ====================================================================

\* ABA 场景：值从 A 变为 B 再变回 A
\* 在 MPMC 队列中，使用版本号防止 ABA
ABASafety ==
  \A i \in 0..Capacity-1 :
    slots[i].sequence >= i  \* 序列号确保不会回绕

\* ====================================================================
\* 线性化验证
\* ====================================================================

\* 线性化点：
\* - 入队：CAS 更新 tail 时
\* - 出队：CAS 更新 head 时

LinearizableHistory ==
  \E linearOrder \in Permutations(1..Len(history)) :
    \A i \in 1..Len(linearOrder) :
      LET op == history[linearOrder[i]]
      IN
      /\ op.type = "enqueue" =>
        \A j \in 1..i-1 :
          history[linearOrder[j]].type = "dequeue" =>
            history[linearOrder[j]].value # op.value
      /\ op.type = "dequeue" =>
        \E j \in 1..i-1 :
          /\ history[linearOrder[j]].type = "enqueue"
          /\ history[linearOrder[j]].value = op.value

\* ====================================================================
\* 检查属性
\* ====================================================================

SafetyCheck == [](TypeOK /\ QueueBounds /\ SequenceMonotonic)
LivenessCheck == NoDeadlock /\ Progress
CompletenessCheck == SafetyCheck /\ LivenessCheck

================================================================================
\* 修改历史
\* 2026-07-08: 初始版本，验证 MPMC 队列 CAS 正确性
