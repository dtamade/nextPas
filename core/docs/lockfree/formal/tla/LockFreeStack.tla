-------------------------------- MODULE LockFreeStack --------------------------------
\* TLA+ 模型：有界 Lock-Free Stack（LIFO）+ Close
\*
\* 抽象 nextpas.core.lockfree.stack 的最小属性：
\* 1. TypeOK
\* 2. 有界容量（bounded capacity）
\* 3. LIFO 顺序
\* 4. Close 后拒绝 publish（push）
\*
\* 模型刻意简化（单逻辑 pusher/popper 交错 + closed 标志），
\* 作为 R8 研究加深工件；运行时契约以 CONTRACT 为准。

EXTENDS Integers, Sequences, FiniteSets, TLC

CONSTANTS
  Capacity,       \* 栈容量（最大元素数）
  MaxOps,         \* 最大操作数
  Producers,      \* 生产者集合（push）
  Consumers       \* 消费者集合（pop）

ASSUME
  /\ Capacity > 0
  /\ MaxOps > 0
  /\ Producers # {}
  /\ Consumers # {}

VARIABLES
  stack,          \* 栈内容（序列：尾部 = top）
  closed,         \* Close 标志
  producerState,  \* 生产者状态
  consumerState,  \* 消费者状态
  ops,            \* 操作计数
  history         \* 操作历史

vars == <<stack, closed, producerState, consumerState, ops, history>>

ProducerStates == {"idle", "pushing", "done"}
ConsumerStates == {"idle", "popping", "done"}

Init ==
  /\ stack = <<>>
  /\ closed = FALSE
  /\ producerState = [p \in Producers |-> "idle"]
  /\ consumerState = [c \in Consumers |-> "idle"]
  /\ ops = 0
  /\ history = <<>>

StackLen == Len(stack)
StackFull == StackLen = Capacity
StackEmpty == StackLen = 0

\* Close：拒绝后续 push；已有元素仍可 pop
DoClose ==
  /\ ~closed
  /\ closed' = TRUE
  /\ history' = Append(history, [type |-> "close", time |-> ops])
  /\ UNCHANGED <<stack, producerState, consumerState, ops>>

\* Push 开始：未 closed 且未满
ProducerStartPush(p) ==
  /\ producerState[p] = "idle"
  /\ ops < MaxOps
  /\ ~closed
  /\ ~StackFull
  /\ producerState' = [producerState EXCEPT ![p] = "pushing"]
  /\ UNCHANGED <<stack, closed, consumerState, ops, history>>

\* Push 完成：元素入栈顶（Append）
ProducerFinishPush(p) ==
  /\ producerState[p] = "pushing"
  /\ ~closed
  /\ ~StackFull
  /\ LET
     newItem == [producer |-> p, value |-> ops + 1, time |-> ops]
     IN
     /\ stack' = Append(stack, newItem)
     /\ producerState' = [producerState EXCEPT ![p] = "idle"]
     /\ ops' = ops + 1
     /\ history' = Append(history, [type |-> "push", producer |-> p, item |-> newItem, time |-> ops])
     /\ UNCHANGED <<closed, consumerState>>

\* Closed 后 push 尝试失败（观测为 reject，不改变 stack）
ProducerPushRejectedClosed(p) ==
  /\ producerState[p] = "idle"
  /\ ops < MaxOps
  /\ closed
  /\ producerState' = [producerState EXCEPT ![p] = "idle"]
  /\ ops' = ops + 1
  /\ history' = Append(history, [type |-> "push_rejected_closed", producer |-> p, time |-> ops])
  /\ UNCHANGED <<stack, closed, consumerState>>

\* Pop 开始：非空
ConsumerStartPop(c) ==
  /\ consumerState[c] = "idle"
  /\ ops < MaxOps
  /\ ~StackEmpty
  /\ consumerState' = [consumerState EXCEPT ![c] = "popping"]
  /\ UNCHANGED <<stack, closed, producerState, ops, history>>

\* Pop 完成：从栈顶取（序列尾部）
ConsumerFinishPop(c) ==
  /\ consumerState[c] = "popping"
  /\ ~StackEmpty
  /\ LET
     item == stack[Len(stack)]
     newStack == SubSeq(stack, 1, Len(stack) - 1)
     IN
     /\ stack' = newStack
     /\ consumerState' = [consumerState EXCEPT ![c] = "idle"]
     /\ ops' = ops + 1
     /\ history' = Append(history, [type |-> "pop", consumer |-> c, item |-> item, time |-> ops])
     /\ UNCHANGED <<closed, producerState>>

Next ==
  \/ DoClose
  \/ \E p \in Producers :
       ProducerStartPush(p) \/ ProducerFinishPush(p) \/ ProducerPushRejectedClosed(p)
  \/ \E c \in Consumers :
       ConsumerStartPop(c) \/ ConsumerFinishPop(c)

Spec == Init /\ [][Next]_vars /\ WF_vars(Next)

\* ====================================================================
\* 安全性
\* ====================================================================

TypeOK ==
  /\ stack \in Seq([producer: Producers, value: Nat, time: Nat])
  /\ closed \in BOOLEAN
  /\ \A p \in Producers : producerState[p] \in ProducerStates
  /\ \A c \in Consumers : consumerState[c] \in ConsumerStates
  /\ ops \in 0..MaxOps
  /\ Len(stack) <= Capacity

BoundedCapacity ==
  /\ Len(stack) >= 0
  /\ Len(stack) <= Capacity

\* Close 后不得成功 push（history 中 closed 之后无 type=push）
CloseRejectsPublish ==
  \A i, j \in 1..Len(history) :
    /\ i < j
    /\ history[i].type = "close"
    => history[j].type # "push"

\* LIFO：若 pop 的 item 曾 push，则其间不得存在“更晚 push 且仍未 pop”的违背
\* 简化：连续 push A 再 push B 后，第一次成功 pop 必须是 B
LifoAdjacent ==
  \A i \in 1..(Len(history) - 2) :
    /\ history[i].type = "push"
    /\ history[i+1].type = "push"
    /\ history[i+2].type = "pop"
    => history[i+2].item = history[i+1].item

SafetyCheck == [](TypeOK /\ BoundedCapacity /\ CloseRejectsPublish)

================================================================================
\* 2026-07-17: R8 加深 — 最小 Stack LIFO + Close 拒绝 publish
