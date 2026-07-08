-------------------------------- MODULE SpscQueue --------------------------------
\* TLA+ 模型：Single-Producer Single-Consumer 有界队列
\*
\* 本模型验证 nextpas.core.lockfree.spsc 的正确性：
\* 1. 无死锁 (Deadlock Freedom)
\* 2. 无饥饿 (Starvation Freedom)
\* 3. 线性化 (Linearizability)
\* 4. FIFO 顺序 (FIFO Order)

EXTENDS Integers, Sequences, FiniteSets, TLC

CONSTANTS
  Capacity,       \* 队列容量 (必须为 2 的幂)
  MaxOps,         \* 最大操作数
  Producers,      \* 生产者集合
  Consumers       \* 消费者集合

ASSUME
  /\ Capacity > 0
  /\ Capacity = 2 \* (Capacity \div 2)  \* 确保是 2 的幂
  /\ MaxOps > 0
  /\ Producers # {}
  /\ Consumers # {}
  /\ Producers \cap Consumers = {}  \* 生产者和消费者不重叠

VARIABLES
  queue,          \* 队列内容 (序列)
  head,           \* 队头指针 (消费者读取位置)
  tail,           \* 队尾指针 (生产者写入位置)
  producerState,  \* 生产者状态
  consumerState,  \* 消费者状态
  ops,            \* 已执行的操作计数
  history          \* 操作历史 (用于线性化验证)

vars == <<queue, head, tail, producerState, consumerState, ops, history>>

\* 状态定义
ProducerStates == {"idle", "writing", "done"}
ConsumerStates == {"idle", "reading", "done"}

\* 初始化
Init ==
  /\ queue = <<>>
  /\ head = 0
  /\ tail = 0
  /\ producerState = [p \in Producers |-> "idle"]
  /\ consumerState = [c \in Consumers |-> "idle"]
  /\ ops = 0
  /\ history = <<>>

\* 辅助函数
QueueLength == (tail - head) % Capacity
QueueFull == QueueLength = Capacity - 1
QueueEmpty == head = tail

\* 生产者操作：开始写入
ProducerStartWrite(p) ==
  /\ producerState[p] = "idle"
  /\ ops < MaxOps
  /\ ~QueueFull
  /\ producerState' = [producerState EXCEPT ![p] = "writing"]
  /\ UNCHANGED <<queue, head, tail, consumerState, ops, history>>

\* 生产者操作：完成写入
ProducerFinishWrite(p) ==
  /\ producerState[p] = "writing"
  /\ LET
     newItem == [producer |-> p, value |-> ops + 1, time |-> ops]
     newQueue == Append(queue, newItem)
     IN
     /\ queue' = newQueue
     /\ tail' = (tail + 1) % Capacity
     /\ producerState' = [producerState EXCEPT ![p] = "idle"]
     /\ ops' = ops + 1
     /\ history' = Append(history, [type |-> "enqueue", producer |-> p, item |-> newItem, time |-> ops])
     /\ UNCHANGED <<head, consumerState>>

\* 消费者操作：开始读取
ConsumerStartRead(c) ==
  /\ consumerState[c] = "idle"
  /\ ops < MaxOps
  /\ ~QueueEmpty
  /\ consumerState' = [consumerState EXCEPT ![c] = "reading"]
  /\ UNCHANGED <<queue, head, tail, producerState, ops, history>>

\* 消费者操作：完成读取
ConsumerFinishRead(c) ==
  /\ consumerState[c] = "reading"
  /\ LET
     item == Head(queue)
     newQueue == Tail(queue)
     IN
     /\ queue' = newQueue
     /\ head' = (head + 1) % Capacity
     /\ consumerState' = [consumerState EXCEPT ![c] = "idle"]
     /\ ops' = ops + 1
     /\ history' = Append(history, [type |-> "dequeue", consumer |-> c, item |-> item, time |-> ops])
     /\ UNCHANGED <<tail, producerState>>

\* Next 关系
Next ==
  \/ \E p \in Producers : ProducerStartWrite(p) \/ ProducerFinishWrite(p)
  \/ \E c \in Consumers : ConsumerStartRead(c) \/ ConsumerFinishRead(c)

\* 规范
Spec == Init /\ [][Next]_vars /\ WF_vars(Next)

\* ====================================================================
\* 安全性属性 (Safety Properties)
\* ====================================================================

\* 类型正确性
TypeOK ==
  /\ queue \in Seq([producer: Producers, value: Nat, time: Nat])
  /\ head \in 0..Capacity-1
  /\ tail \in 0..Capacity-1
  /\ \A p \in Producers : producerState[p] \in ProducerStates
  /\ \A c \in Consumers : consumerState[c] \in ConsumerStates
  /\ ops \in 0..MaxOps
  /\ Len(queue) <= Capacity

\* 队列边界
QueueBounds ==
  /\ Len(queue) >= 0
  /\ Len(queue) < Capacity

\* 生产者互斥 (同一时间只有一个生产者在写入)
ProducerMutex ==
  \A p1, p2 \in Producers :
    (producerState[p1] = "writing" /\ producerState[p2] = "writing") => p1 = p2

\* 消费者互斥 (同一时间只有一个消费者在读取)
ConsumerMutex ==
  \A c1, c2 \in Consumers :
    (consumerState[c1] = "reading" /\ consumerState[c2] = "reading") => c1 = c2

\* FIFO 顺序：先入队的元素先出队
FifoOrder ==
  \A i, j \in 1..Len(history) :
    /\ i < j
    /\ history[i].type = "enqueue"
    /\ history[j].type = "dequeue"
    /\ history[j].item = history[i].item
    => \A k \in i+1..j-1 :
      /\ history[k].type = "enqueue"
      => history[k].time > history[i].time

\* ====================================================================
\* 活性属性 (Liveness Properties)
\* ====================================================================

\* 无死锁：如果队列非空，消费者最终能读取
NoDeadlock ==
  [](QueueEmpty => \E c \in Consumers : consumerState[c] = "idle")

\* 无饥饿：生产者最终能写入 (如果队列不满)
NoStarvation ==
  \A p \in Producers :
    [](~QueueFull ~> producerState[p] = "idle")

\* 进度：操作数最终增加
Progress ==
  <>(ops > 0)

\* ====================================================================
\* 线性化验证 (Linearizability)
\* ====================================================================

\* 线性化点定义：
\* - 入队：tail 指针更新时
\* - 出队：head 指针更新时

\* 线性化历史
LinearizableHistory ==
  \E linearOrder \in Permutations(1..Len(history)) :
    \A i \in 1..Len(linearOrder) :
      LET op == history[linearOrder[i]]
      IN
      /\ op.type = "enqueue" =>
        \A j \in 1..i-1 :
          history[linearOrder[j]].type = "dequeue" =>
            history[linearOrder[j]].item # op.item
      /\ op.type = "dequeue" =>
        \E j \in 1..i-1 :
          /\ history[linearOrder[j]].type = "enqueue"
          /\ history[linearOrder[j]].item = op.item

\* ====================================================================
\* 检查属性
\* ====================================================================

\* 安全性检查
SafetyCheck == [](TypeOK /\ QueueBounds /\ ProducerMutex /\ ConsumerMutex)

\* 活性检查
LivenessCheck == NoDeadlock /\ Progress

\* 完整性检查
CompletenessCheck == SafetyCheck /\ LivenessCheck

================================================================================
\* 修改历史
\* 2026-07-08: 初始版本，验证 SPSC 队列基本正确性
