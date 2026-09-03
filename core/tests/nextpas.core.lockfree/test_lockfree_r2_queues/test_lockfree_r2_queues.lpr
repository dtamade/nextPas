program test_lockfree_r2_queues;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.errors,
  nextpas.core.test,
  nextpas.core.lockfree.ringbuffer,
  nextpas.core.lockfree.timeoutqueue,
  nextpas.core.lockfree.channel,
  nextpas.core.lockfree.selector,
  nextpas.core.lockfree.selector.impl,
  nextpas.core.lockfree.msqueue,
  nextpas.core.lockfree.exchanger,
  nextpas.core.lockfree.deque_lf;

type
  TAction = procedure;
  TIntRingBuffer = specialize TRingBufferImpl<Integer>;
  TStringRingBuffer = specialize TRingBufferImpl<string>;
  TIntTimeoutQueue = specialize TTimeoutQueueImpl<Integer>;
  TStringTimeoutQueue = specialize TTimeoutQueueImpl<string>;
  TIntChannel = specialize TLockFreeChannelImpl<Integer>;
  TIntSelector = specialize TLockFreeSelectorImpl<Integer>;
  TStringMsQueue = specialize TLockFreeMsQueueImpl<string>;
  TStringExchanger = specialize TExchangerImpl<string>;

const
  SOURCE_ROOT = '../../../src/';

var
  T: TTestSuite;

function ReadSource(const AFileName: string): string;
begin
  Result := ReadFileText(SOURCE_ROOT + AFileName);
end;

procedure CheckContains(const AText, ANeedle, AMessage: string);
begin
  Check(Pos(ANeedle, AText) > 0, AMessage + ': missing "' + ANeedle + '"');
end;

procedure CheckNotContains(const AText, ANeedle, AMessage: string);
begin
  Check(Pos(ANeedle, AText) = 0, AMessage + ': unexpected "' + ANeedle + '"');
end;

procedure CheckBefore(const AText, AEarlier, ALater, AMessage: string);
var
  LEarlierPos: SizeInt;
  LLaterPos: SizeInt;
begin
  LEarlierPos := Pos(AEarlier, AText);
  LLaterPos := Pos(ALater, AText);
  Check(LEarlierPos > 0, AMessage + ': missing earlier marker');
  Check(LLaterPos > 0, AMessage + ': missing later marker');
  Check(LEarlierPos < LLaterPos, AMessage);
end;

function ExtractSection(const AText, AStartMarker, AEndMarker: string): string;
var
  LStart: SizeInt;
  LEnd: SizeInt;
  LRest: string;
begin
  LStart := Pos(AStartMarker, AText);
  Check(LStart > 0, 'missing section start: ' + AStartMarker);
  LRest := Copy(AText, LStart, Length(AText) - LStart + 1);
  LEnd := Pos(AEndMarker, LRest);
  Check(LEnd > 0, 'missing section end: ' + AEndMarker);
  Result := Copy(LRest, 1, LEnd - 1);
end;

procedure CreateManagedRingBuffer;
var
  LBuffer: TStringRingBuffer;
begin
  LBuffer := TStringRingBuffer.Create(1);
  LBuffer.Free;
end;

procedure CreateManagedTimeoutQueue;
var
  LQueue: TStringTimeoutQueue;
begin
  LQueue := TStringTimeoutQueue.Create(1, 1000000000);
  LQueue.Free;
end;

procedure CreateManagedMsQueue;
var
  LQueue: TStringMsQueue;
begin
  LQueue := TStringMsQueue.Create;
  LQueue.Free;
end;

procedure CreateManagedExchanger;
var
  LExchanger: TStringExchanger;
begin
  LExchanger := TStringExchanger.Create;
  LExchanger.Free;
end;

procedure CreateZeroCapacityDeque;
var
  LDeque: TLockFreeDeque;
begin
  LDeque := TLockFreeDeque.Create(0);
  LDeque.Free;
end;

procedure ExpectArgumentError(const AAction: TAction; const AMessage: string);
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    AAction;
  except
    on E: EArgumentError do
      LRaised := True;
    on E: Exception do
      Fail(AMessage + ': expected EArgumentError, got ' + E.ClassName);
  end;
  Check(LRaised, AMessage + ': expected EArgumentError');
end;

procedure TestRingBufferCapacityOne;
var
  LBuffer: TIntRingBuffer;
  LValue: Integer;
begin
  LBuffer := TIntRingBuffer.Create(1);
  try
    Check(rbWritten = LBuffer.TryWrite(42), 'capacity-one ring accepts one item');
    Check(LBuffer.IsFull, 'capacity-one ring reports full after one item');
    Check(rbFull = LBuffer.TryWrite(43), 'capacity-one ring rejects a second item');
    Check(rbWritten = LBuffer.TryRead(LValue), 'capacity-one ring returns its item');
    CheckEqual(Int64(42), Int64(LValue), 'capacity-one ring preserves value');
    Check(rbEmpty = LBuffer.TryRead(LValue), 'capacity-one ring becomes empty');
  finally
    LBuffer.Free;
  end;
end;

procedure TestTimeoutQueueCapacityOne;
var
  LQueue: TIntTimeoutQueue;
  LValue: Integer;
begin
  LQueue := TIntTimeoutQueue.Create(1, 1000000000);
  try
    Check(LQueue.TryEnqueue(42), 'capacity-one timeout queue accepts one item');
    Check(not LQueue.TryEnqueue(43), 'capacity-one timeout queue rejects a second item');
    Check(tqDequeued = LQueue.TryDequeue(LValue), 'capacity-one timeout queue returns its item');
    CheckEqual(Int64(42), Int64(LValue), 'capacity-one timeout queue preserves value');
    Check(tqEmpty = LQueue.TryDequeue(LValue), 'capacity-one timeout queue becomes empty');
  finally
    LQueue.Free;
  end;
end;

procedure TestManagedElementGuards;
begin
  ExpectArgumentError(@CreateManagedRingBuffer, 'ringbuffer managed element guard');
  ExpectArgumentError(@CreateManagedTimeoutQueue, 'timeout queue managed element guard');
  ExpectArgumentError(@CreateManagedMsQueue, 'MS queue managed element guard');
  ExpectArgumentError(@CreateManagedExchanger, 'exchanger managed element guard');
end;

procedure TestChannelResizeAfterWrap;
var
  LChannel: TIntChannel;
  LValue: Integer;
  LI: Integer;
begin
  LChannel := TIntChannel.Create(2);
  try
    for LI := 1 to 10 do
    begin
      Check(LChannel.TrySend(LI), 'pre-resize send succeeds');
      Check(LChannel.TryReceive(LValue), 'pre-resize receive succeeds');
      CheckEqual(Int64(LI), Int64(LValue), 'pre-resize value survives wrap');
    end;
    Check(LChannel.TrySend(99), 'live item enqueues before resize');
    Check(LChannel.TryResize(4), 'wrapped channel grows');
    CheckEqual(PtrUInt(4), LChannel.Capacity, 'channel reports resized capacity');
    Check(LChannel.TryReceive(LValue), 'migrated item remains readable');
    CheckEqual(Int64(99), Int64(LValue), 'resize preserves FIFO item');
    Check(LChannel.TrySend(100), 'rebased empty slot remains writable');
    Check(LChannel.TryReceive(LValue), 'post-resize item remains readable');
    CheckEqual(Int64(100), Int64(LValue), 'post-resize value survives');
  finally
    LChannel.Free;
  end;
end;

procedure TestEmptySelectorBoundaries;
var
  LSelector: TIntSelector;
  LResult: TSelectResult;
begin
  LSelector := TIntSelector.Create;
  try
    LResult := LSelector.TrySelect;
    Check(not LResult.Completed, 'empty TrySelect is incomplete');
    CheckEqual(PtrInt(-1), LResult.Index, 'empty TrySelect index is -1');
    LResult := LSelector.SelectTimeout(0);
    Check(not LResult.Completed, 'empty zero-timeout select is incomplete');
    CheckEqual(PtrInt(-1), LResult.Index, 'empty zero-timeout select index is -1');
  finally
    LSelector.Free;
  end;
end;

procedure TestChannelRejectsDifferentSelectorOwner;
var
  LChannel: TIntChannel;
  LSelector1: TIntSelector;
  LSelector2: TIntSelector;
  LValue1: Integer;
  LValue2: Integer;
  LRaised: Boolean;
begin
  LChannel := TIntChannel.Create(1);
  LSelector1 := TIntSelector.Create;
  LSelector2 := TIntSelector.Create;
  try
    LSelector1.AddRecv(LChannel, LValue1);
    LRaised := False;
    try
      LSelector2.AddRecv(LChannel, LValue2);
    except
      on E: EInvalidOperationError do
        LRaised := True;
    end;
    Check(LRaised, 'channel rejects replacement by a different selector');
  finally
    LSelector2.Free;
    LSelector1.Free;
    LChannel.Free;
  end;
end;

procedure TestMpmcBatchUsesPerSlotProtocol;
var
  LSource: string;
  LEnqueue: string;
  LDequeue: string;
begin
  LSource := ReadSource('nextpas.core.lockfree.mpmc.pas');
  LEnqueue := ExtractSection(LSource, 'function TMpmcQueueImpl.EnqueueBatch',
    'function TMpmcQueueImpl.DequeueBatch');
  LDequeue := ExtractSection(LSource, 'function TMpmcQueueImpl.DequeueBatch',
    'function TMpmcQueueImpl.IsEmpty');
  CheckContains(LEnqueue, 'TryEnqueue(AValues[Result])',
    'batch enqueue delegates every item to the slot protocol');
  CheckNotContains(LEnqueue, 'FEnqueuePos',
    'batch enqueue does not reserve positions outside the slot protocol');
  CheckContains(LDequeue, 'TryDequeue(AValues[Result])',
    'batch dequeue delegates every item to the slot protocol');
  CheckNotContains(LDequeue, 'FDequeuePos',
    'batch dequeue does not reserve positions outside the slot protocol');
end;

procedure TestCapacityValidationSourceContracts;
var
  LRing: string;
  LTimeout: string;
begin
  LRing := ReadSource('nextpas.core.lockfree.ringbuffer.pas');
  LTimeout := ReadSource('nextpas.core.lockfree.timeoutqueue.pas');
  CheckContains(LRing, 'if IsManagedType(T) then', 'ringbuffer rejects managed T');
  CheckContains(LTimeout, 'if IsManagedType(T) then', 'timeout queue rejects managed T');
  CheckContains(LRing, 'LockFreeNextPow2(PtrUInt(ACapacity))',
    'ringbuffer uses the shared checked capacity helper');
  CheckContains(LTimeout, 'LockFreeNextPow2(PtrUInt(ACapacity))',
    'timeout queue uses the shared checked capacity helper');
  CheckContains(LRing, 'ACapacity > (Int64(1) shl 62)',
    'ringbuffer rejects signed next-power overflow');
  CheckContains(LTimeout, 'ACapacity > (Int64(1) shl 62)',
    'timeout queue rejects signed next-power overflow');
end;

procedure TestChannelConcurrencySourceContracts;
var
  LSource: string;
  LResize: string;
begin
  LSource := ReadSource('nextpas.core.lockfree.channel.pas');
  LResize := ExtractSection(LSource, 'function TLockFreeChannelImpl.TryResize', 'end.' + LineEnding);
  CheckContains(LSource,
    'FOpStripes: array[0..CHANNEL_OP_STRIPES - 1] of TChannelOpStripe',
    'channel tracks admitted operations in striped counters (F-037)');
  CheckContains(LSource, 'procedure TLockFreeChannelImpl.EnterOperation',
    'channel has double-checked operation admission');
  CheckContains(LSource, 'procedure TLockFreeChannelImpl.LeaveOperation',
    'channel releases operation admission');
  CheckContains(LResize, 'atomic_load(FOpStripes[LI].Count, mo_acquire)',
    'resize waits for admitted operations across all stripes');
  CheckContains(LResize, 'atomic_store_64(FRecvPos, 0, mo_release)',
    'resize rebases receive position');
  CheckContains(LResize, 'atomic_store_64(FSendPos, Int64(LCount), mo_release)',
    'resize rebases send position');
  CheckContains(LSource, 'FNotifierCallbacks: Int32',
    'channel tracks callbacks during notifier unregister');
  CheckContains(LSource, 'FNotifierLock: Int32',
    'channel serializes notifier method-pointer access');
end;

procedure TestMsQueueConcurrencySourceContracts;
var
  LSource: string;
  LGrow: string;
  LDequeue: string;
begin
  LSource := ReadSource('nextpas.core.lockfree.msqueue.pas');
  LGrow := ExtractSection(LSource, 'procedure TLockFreeMsQueueImpl.Grow',
    'constructor TLockFreeMsQueueImpl.Create');
  LDequeue := ExtractSection(LSource, 'function TLockFreeMsQueueImpl.TryDequeue',
    'procedure TLockFreeMsQueueImpl.Close');
  CheckContains(LSource,
    'FOpStripes: array[0..MSQUEUE_OP_STRIPES - 1] of TMsQueueOpStripe',
    'MS queue tracks admitted operations in striped counters (F-041)');
  CheckContains(LSource, 'FResizing: Int32',
    'MS queue serializes growth');
  CheckContains(LGrow, 'atomic_load(FOpStripes[LI].Count, mo_acquire)',
    'growth waits for admitted operations across all stripes');
  CheckContains(LGrow, 'LNewNodes', 'MS queue grows into local node storage');
  CheckContains(LGrow, 'LNewNodes[LI].FFreeNext',
    'MS queue builds the free chain in local node storage (F-046: free link lives in the node line)');
  CheckBefore(LDequeue, 'LCandidateValue := FNodes[LNextIdx].FValue',
    'atomic_compare_exchange_strong_64(FHead', 'MS queue copies value before head CAS');
  CheckContains(LSource, 'if IsManagedType(T) then', 'MS queue rejects managed T');
end;

procedure TestSegQueueAllocationBeforeReservationContract;
var
  LSource: string;
  LEnqueue: string;
begin
  LSource := ReadSource('nextpas.core.lockfree.segqueue.pas');
  { Logical enqueue reserves inside Publish (Enqueue is a thin closed-check wrapper). }
  LEnqueue := ExtractSection(LSource, 'procedure TSegQueueImpl.Publish',
    'procedure TSegQueueImpl.Enqueue');
  CheckNotContains(LEnqueue, 'atomic_fetch_add_64(FEnqueuePos',
    'segment queue does not reserve before fallible allocation');
  CheckBefore(LEnqueue, 'FindOrCreateSegment(LPos)',
    'atomic_compare_exchange_strong_64(FEnqueuePos',
    'segment allocation completes before logical position reservation');
end;

procedure TestSegQueueFreePoolCasOrder;
var
  LSource: string;
begin
  LSource := ReadSource('nextpas.core.lockfree.segqueue.pas');
  CheckContains(LSource,
    'Pointer(LOldHead^.Next), mo_acq_rel',
    'segment free-pool pop uses expected then desired CAS order');
  CheckContains(LSource,
    'Pointer(LSeg), mo_acq_rel',
    'segment free-pool push uses expected then desired CAS order');
end;

procedure TestCountPublicationSourceContracts;
var
  LStack: string;
  LMpsc: string;
  LMpscEnqueue: string;
begin
  LStack := ReadSource('nextpas.core.lockfree.stack.pas');
  LMpsc := ReadSource('nextpas.core.lockfree.mpsc.pas');
  { Count + link publish live in PublishNode (Enqueue is a thin closed-check wrapper). }
  LMpscEnqueue := ExtractSection(LMpsc, 'procedure TMpscQueueImpl.PublishNode',
    'procedure TMpscQueueImpl.Enqueue');
  CheckContains(LStack, 'FCount: Int64', 'stack count is an independent atomic');
  CheckContains(LStack, 'if LCount > FCapacity then Break;',
    'stack ApproxCount must keep traversal best-effort with capacity cap');
  CheckContains(LMpsc, 'FEnqueued: Int64', 'MPSC enqueue count has unbounded-queue width');
  CheckContains(LMpsc, 'FDequeued: Int64',
    'MPSC dequeue count is a split single-writer counter (F-038)');
  CheckBefore(LMpscEnqueue, 'atomic_fetch_add_64(FEnqueued, 1',
    'StoreNode(LPrev^.Next', 'MPSC count publishes before the consumer-visible link');
  CheckBefore(LMpsc, 'atomic_load_64(FDequeued, mo_acquire)',
    'LEnqueued := atomic_load_64(FEnqueued, mo_relaxed)',
    'MPSC ApproxCount must read FDequeued first so the difference stays non-negative');
end;

procedure TestEliminationStackSourceContracts;
var
  LSource: string;
  LPop: string;
begin
  LSource := ReadSource('nextpas.core.lockfree.elimination_stack.pas');
  LPop := ExtractSection(LSource, 'function TEliminationStackImpl.TryPop',
    'procedure TEliminationStackImpl.Close');
  CheckContains(LSource, 'FCount: Int64', 'elimination stack uses an atomic count');
  CheckContains(LSource, 'atomic_fetch_add(FNextSlot, 1',
    'elimination slot selection is atomic');
  CheckNotContains(LPop, 'ELIM_STATE_EMPTY, ELIM_STATE_POP',
    'pop does not publish an offer state that push never matches');
  CheckContains(LSource, 'ELIM_STATE_CANCELLED',
    'close can exclusively cancel published offers');
end;

procedure TestLockedContainerBoundaryContracts;
var
  LPriority: string;
  LDeque: string;
  LCount: string;
begin
  ExpectArgumentError(@CreateZeroCapacityDeque, 'deque rejects zero capacity');
  LPriority := ReadSource('nextpas.core.lockfree.priority_queue.pas');
  LDeque := ReadSource('nextpas.core.lockfree.deque_spin.pas');
  CheckContains(LPriority, 'AInitialCapacity > MaxInt div SizeOf(T)',
    'priority queue validates allocation multiplication');
  LCount := ExtractSection(LPriority, 'function TConcurrentPriorityQueueImpl.Count',
    'function TConcurrentPriorityQueueImpl.IsEmpty');
  CheckContains(LCount, 'platform_mutex_lock(FMutex)',
    'priority queue count uses the writer mutex');
  CheckContains(LDeque, 'FCapacity > High(Int32) div 2',
    'deque_spin growth rejects Int32 overflow');
  CheckContains(LDeque, 'TConcurrentSpinDeque = class',
    'honest spin deque type name is TConcurrentSpinDeque');
  LDeque := ReadSource('nextpas.core.lockfree.deque_lf.pas');
  CheckContains(LDeque, 'TLockFreeDeque = TConcurrentSpinDeque',
    'deque_lf keeps TLockFreeDeque as historical type alias');
  CheckContains(LDeque, 'nextpas.core.lockfree.deque_spin',
    'deque_lf re-exports deque_spin implementation');
end;

procedure TestSelectorAndExchangerSourceContracts;
var
  LSelector: string;
  LAddSend: string;
  LExchanger: string;
  LExchange: string;
begin
  LSelector := ReadSource('nextpas.core.lockfree.selector.impl.pas');
  LAddSend := ExtractSection(LSelector, 'procedure TLockFreeSelectorImpl.AddSend',
    'procedure TLockFreeSelectorImpl.NotifyChange');
  LExchanger := ReadSource('nextpas.core.lockfree.exchanger.pas');
  LExchange := ExtractSection(LExchanger, 'function TExchangerImpl.Exchange(',
    'function TExchangerImpl.ExchangeTimeout');
  CheckContains(LSelector, 'if FCount = 0 then', 'selector handles an empty case set');
  CheckContains(LSelector, 'LStart := platform_monotonic_ns',
    'selector timeout uses one absolute monotonic start');
  CheckContains(LAddSend, 'except', 'selector AddSend cleans its heap copy on registration failure');
  CheckContains(LExchange, 'EXCHANGER_STATE_CLAIMED:',
    'exchanger waits through the valid claimed state');
  CheckContains(LExchanger, 'if IsManagedType(T) then', 'exchanger rejects managed T');
end;

begin
  T := TTestSuite.Create('nextpas.core.lockfree.r2.queues');
  T.Test('Ringbuffer capacity one', @TestRingBufferCapacityOne);
  T.Test('Timeout queue capacity one', @TestTimeoutQueueCapacityOne);
  T.Test('Managed element guards', @TestManagedElementGuards);
  T.Test('Channel resize after wrap', @TestChannelResizeAfterWrap);
  T.Test('Empty selector boundaries', @TestEmptySelectorBoundaries);
  T.Test('Channel rejects a different selector owner', @TestChannelRejectsDifferentSelectorOwner);
  T.Test('MPMC batch uses per-slot protocol', @TestMpmcBatchUsesPerSlotProtocol);
  T.Test('Capacity validation source contracts', @TestCapacityValidationSourceContracts);
  T.Test('Channel concurrency source contracts', @TestChannelConcurrencySourceContracts);
  T.Test('MS queue concurrency source contracts', @TestMsQueueConcurrencySourceContracts);
  T.Test('SegQueue allocation before reservation', @TestSegQueueAllocationBeforeReservationContract);
  T.Test('SegQueue free-pool CAS order', @TestSegQueueFreePoolCasOrder);
  T.Test('Count publication source contracts', @TestCountPublicationSourceContracts);
  T.Test('Elimination stack source contracts', @TestEliminationStackSourceContracts);
  T.Test('Locked container boundary contracts', @TestLockedContainerBoundaryContracts);
  T.Test('Selector and exchanger source contracts', @TestSelectorAndExchangerSourceContracts);
  if not T.Run then
    Halt(1);
end.
