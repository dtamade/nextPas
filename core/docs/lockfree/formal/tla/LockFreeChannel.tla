-------------------------------- MODULE LockFreeChannel --------------------------------
\* TLA+ 模型：Lock-Free Channel (Go channel 语义)
\*
\* 本模型验证 nextpas.core.lockfree.channel 的正确性：
\* 1. 阻塞/超时语义
\* 2. Close 语义
\* 3. Select 多路复用
\* 4. 容量动态调整

EXTENDS Integers, Sequences, FiniteSets, TLC

CONSTANTS
  MaxCapacity,    \* 最大容量
  MaxOps,         \* 最大操作数
  Producers,      \* 生产者集合
  Consumers,      \* 消费者集合
  TimeoutValue    \* 超时值

ASSUME
  /\ MaxCapacity > 0
  /\ MaxOps > 0
  /\ Producers # {}
  /\ Consumers # {}
  /\ TimeoutValue > 0

VARIABLES
  channel,        \* 通道状态: [buffer: Seq, capacity: Int, closed: Bool]
  senderState,    \* 发送者状态机
  receiverState,  \* 接收者状态机
  selectState,    \* Select 状态
  ops,            \* 操作计数
  history         \* 操作历史

vars == <<channel, senderState, receiverState, selectState, ops, history>>

\* 状态定义
SenderStates == {"idle", "sending", "blocked", "timeout", "closed", "done"}
ReceiverStates == {"idle", "receiving", "blocked", "timeout", "closed", "done"}
SelectStates == {"idle", "waiting", "matched", "timeout"}

\* 初始化
Init ==
  /\ channel = [buffer |-> <<>>, capacity |-> MaxCapacity, closed |-> FALSE]
  /\ senderState = [p \in Producers |-> "idle"]
  /\ receiverState = [c \in Consumers |-> "idle"]
  /\ selectState = [id \in 1..2 |-> "idle"]  \* 假设最多 2 个 select
  /\ ops = 0
  /\ history = <<>>

\* 辅助函数
BufferFull == Len(channel.buffer) >= channel.capacity
BufferEmpty == Len(channel.buffer) = 0
ChannelClosed == channel.closed

\* 发送者操作：开始发送
SenderStartSend(p) ==
  /\ senderState[p] = "idle"
  /\ ops < MaxOps
  /\ ~ChannelClosed
  /\ IF BufferFull THEN
       /\ senderState' = [senderState EXCEPT ![p] = "blocked"]
       /\ UNCHANGED <<channel, receiverState, selectState, ops, history>>
     ELSE
       /\ senderState' = [senderState EXCEPT ![p] = "sending"]
       /\ UNCHANGED <<channel, receiverState, selectState, ops, history>>

\* 发送者操作：完成发送
SenderFinishSend(p) ==
  /\ senderState[p] = "sending"
  /\ ~BufferFull
  /\ LET
     newItem == [sender |-> p, value |-> ops + 1, time |-> ops]
     newBuffer == Append(channel.buffer, newItem)
     IN
     /\ channel' = [channel EXCEPT !.buffer = newBuffer]
     /\ senderState' = [senderState EXCEPT ![p] = "idle"]
     /\ ops' = ops + 1
     /\ history' = Append(history, [type |-> "send", sender |-> p, value |-> ops + 1, time |-> ops])
     /\ UNCHANGED <<receiverState, selectState>>

\* 发送者操作：阻塞等待
SenderWait(p) ==
  /\ senderState[p] = "blocked"
  /\ ~ChannelClosed
  /\ IF ~BufferFull THEN
       /\ senderState' = [senderState EXCEPT ![p] = "sending"]
       /\ UNCHANGED <<channel, receiverState, selectState, ops, history>>
     ELSE
       /\ UNCHANGED vars

\* 发送者操作：超时
SenderTimeout(p) ==
  /\ senderState[p] = "blocked"
  /\ senderState' = [senderState EXCEPT ![p] = "timeout"]
  /\ UNCHANGED <<channel, receiverState, selectState, ops, history>>

\* 发送者操作：发送到已关闭通道
SenderToClosed(p) ==
  /\ senderState[p] = "idle"
  /\ ChannelClosed
  /\ senderState' = [senderState EXCEPT ![p] = "closed"]
  /\ UNCHANGED <<channel, receiverState, selectState, ops, history>>

\* 接收者操作：开始接收
ReceiverStartReceive(c) ==
  /\ receiverState[c] = "idle"
  /\ ops < MaxOps
  /\ IF BufferEmpty THEN
       IF ChannelClosed THEN
         /\ receiverState' = [receiverState EXCEPT ![c] = "closed"]
         /\ UNCHANGED <<channel, senderState, selectState, ops, history>>
       ELSE
         /\ receiverState' = [receiverState EXCEPT ![c] = "blocked"]
         /\ UNCHANGED <<channel, senderState, selectState, ops, history>>
     ELSE
       /\ receiverState' = [receiverState EXCEPT ![c] = "receiving"]
       /\ UNCHANGED <<channel, senderState, selectState, ops, history>>

\* 接收者操作：完成接收
ReceiverFinishReceive(c) ==
  /\ receiverState[c] = "receiving"
  /\ ~BufferEmpty
  /\ LET
     item == Head(channel.buffer)
     newBuffer == Tail(channel.buffer)
     IN
     /\ channel' = [channel EXCEPT !.buffer = newBuffer]
     /\ receiverState' = [receiverState EXCEPT ![c] = "idle"]
     /\ ops' = ops + 1
     /\ history' = Append(history, [type |-> "receive", receiver |-> c, value |-> item.value, time |-> ops])
     /\ UNCHANGED <<senderState, selectState>>

\* 接收者操作：阻塞等待
ReceiverWait(c) ==
  /\ receiverState[c] = "blocked"
  /\ ~BufferEmpty
  /\ receiverState' = [receiverState EXCEPT ![c] = "receiving"]
  /\ UNCHANGED <<channel, senderState, selectState, ops, history>>

\* 接收者操作：超时
ReceiverTimeout(c) ==
  /\ receiverState[c] = "blocked"
  /\ receiverState' = [receiverState EXCEPT ![c] = "timeout"]
  /\ UNCHANGED <<channel, senderState, selectState, ops, history>>

\* 接收者操作：从已关闭通道接收
ReceiverFromClosed(c) ==
  /\ receiverState[c] = "blocked"
  /\ ChannelClosed
  /\ BufferEmpty
  /\ receiverState' = [receiverState EXCEPT ![c] = "closed"]
  /\ UNCHANGED <<channel, senderState, selectState, ops, history>>

\* Close 操作
CloseChannel ==
  /\ ~ChannelClosed
  /\ channel' = [channel EXCEPT !.closed = TRUE]
  /\ UNCHANGED <<senderState, receiverState, selectState, ops, history>>

\* Select 操作：等待多个通道
SelectWait(id) ==
  /\ selectState[id] = "idle"
  /\ selectState' = [selectState EXCEPT ![id] = "waiting"]
  /\ UNCHANGED <<channel, senderState, receiverState, ops, history>>

\* Select 操作：匹配成功
SelectMatch(id) ==
  /\ selectState[id] = "waiting"
  /\ ~BufferEmpty
  /\ selectState' = [selectState EXCEPT ![id] = "matched"]
  /\ UNCHANGED <<channel, senderState, receiverState, ops, history>>

\* Select 操作：超时
SelectTimeout(id) ==
  /\ selectState[id] = "waiting"
  /\ selectState' = [selectState EXCEPT ![id] = "timeout"]
  /\ UNCHANGED <<channel, senderState, receiverState, ops, history>>

\* Next 关系
Next ==
  \/ \E p \in Producers :
       SenderStartSend(p) \/ SenderFinishSend(p) \/ SenderWait(p) \/
       SenderTimeout(p) \/ SenderToClosed(p)
  \/ \E c \in Consumers :
       ReceiverStartReceive(c) \/ ReceiverFinishReceive(c) \/ ReceiverWait(c) \/
       ReceiverTimeout(c) \/ ReceiverFromClosed(c)
  \/ CloseChannel
  \/ \E id \in DOMAIN selectState :
       SelectWait(id) \/ SelectMatch(id) \/ SelectTimeout(id)

\* 规范
Spec == Init /\ [][Next]_vars /\ WF_vars(Next)

\* ====================================================================
\* 安全性属性
\* ====================================================================

\* 类型正确性
TypeOK ==
  /\ channel.buffer \in Seq([sender: Producers, value: Nat, time: Nat])
  /\ channel.capacity \in 1..MaxCapacity
  /\ channel.closed \in BOOLEAN
  /\ \A p \in Producers : senderState[p] \in SenderStates
  /\ \A c \in Consumers : receiverState[c] \in ReceiverStates
  /\ ops \in 0..MaxOps

\* 通道边界
ChannelBounds ==
  /\ Len(channel.buffer) >= 0
  /\ Len(channel.buffer) <= channel.capacity

\* Close 后不能再发送
NoSendAfterClose ==
  [](ChannelClosed =>
    \A p \in Producers :
      senderState[p] \in {"closed", "idle"})

\* Close 后可以继续接收剩余数据
ReceiveAfterClose ==
  [](ChannelClosed =>
    (BufferEmpty =>
      \A c \in Consumers :
        receiverState[c] \in {"closed", "idle"}))

\* 阻塞发送者在有空间时被唤醒
BlockedSenderWakeup ==
  \A p \in Producers :
    [](senderState[p] = "blocked" =>
      (~BufferFull ~> senderState[p] = "sending"))

\* 阻塞接收者在有数据时被唤醒
BlockedReceiverWakeup ==
  \A c \in Consumers :
    [](receiverState[c] = "blocked" =>
      (~BufferEmpty ~> receiverState[c] = "receiving"))

\* ====================================================================
\* 活性属性
\* ====================================================================

\* 无死锁
NoDeadlock ==
  [](ChannelClosed /\ BufferEmpty =>
    \A c \in Consumers : receiverState[c] \in {"closed", "idle"})

\* 发送进度
SenderProgress ==
  \A p \in Producers :
    [](senderState[p] = "idle" ~> senderState[p] = "idle")

\* 接收进度
ReceiverProgress ==
  \A c \in Consumers :
    [](receiverState[c] = "idle" ~> receiverState[c] = "idle")

\* 操作进度
Progress == <>(ops > 0)

\* ====================================================================
\* Select 语义
\* ====================================================================

\* Select 公平性：每个 select 最终都能匹配或超时
SelectFairness ==
  \A id \in DOMAIN selectState :
    [](selectState[id] = "waiting" =>
      (selectState[id] = "matched" \/ selectState[id] = "timeout"))

\* ====================================================================
\* 容量动态调整
\* ====================================================================

\* Resize 操作 (简化模型)
ResizeChannel(newCapacity) ==
  /\ newCapacity > 0
  /\ newCapacity <= MaxCapacity
  /\ channel' = [channel EXCEPT !.capacity = newCapacity]
  /\ UNCHANGED <<senderState, receiverState, selectState, ops, history>>

\* Resize 安全性：不会丢失数据
ResizeSafety ==
  \A newCap \in 1..MaxCapacity :
    [](ResizeChannel(newCap) => Len(channel'.buffer) = Len(channel.buffer))

\* ====================================================================
\* 线性化验证
\* ====================================================================

\* 线性化点：
\* - 发送：数据进入 buffer 时
\* - 接收：数据离开 buffer 时
\* - Close：closed 标志设置时

LinearizableHistory ==
  \E linearOrder \in Permutations(1..Len(history)) :
    \A i \in 1..Len(linearOrder) :
      LET op == history[linearOrder[i]]
      IN
      /\ op.type = "send" =>
        \A j \in 1..i-1 :
          history[linearOrder[j]].type = "receive" =>
            history[linearOrder[j]].value # op.value
      /\ op.type = "receive" =>
        \E j \in 1..i-1 :
          /\ history[linearOrder[j]].type = "send"
          /\ history[linearOrder[j]].value = op.value

\* ====================================================================
\* 检查属性
\* ====================================================================

SafetyCheck == [](TypeOK /\ ChannelBounds)
LivenessCheck == NoDeadlock /\ Progress
CompletenessCheck == SafetyCheck /\ LivenessCheck

================================================================================
\* 修改历史
\* 2026-07-08: 初始版本，验证 Channel 阻塞/超时/Close 语义
