program test_lockfree_hashtable;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  SysUtils,
  nextpas.core.atomic,
  nextpas.core.errors,
  nextpas.core.platform.thread,
  nextpas.core.lockfree.hashtable;

type
  TIntHashTable = specialize TLockFreeHashTableImpl<Integer, Integer>;
  TIntCollisionKeys = array[0..31] of Integer;

var
  GTests, GPassed: Integer;

const
  CONCURRENT_INSERT_THREADS = 8;
  CONCURRENT_INSERT_ROUNDS = 256;
  CONCURRENT_READ_THREADS = 4;
  CONCURRENT_READ_GROW_KEYS = 8192;

var
  GConcurrentTable: TIntHashTable;
  GBarrierCount: Int32;
  GBarrierGeneration: Int32;
  GConcurrentInsertOk: Int32;
  GConcurrentInsertErrors: Int32;
  GReadGrowTable: TIntHashTable;
  GReadGrowStop: Int32;
  GReadGrowPublishedKey: Int32;
  GReadGrowChecks: Int32;
  GReadGrowErrors: Int32;

procedure Check(ACond: Boolean; const AName: string);
begin
  Inc(GTests);
  if ACond then
    Inc(GPassed)
  else
    WriteLn('  FAIL: ', AName);
end;

function HashInteger(const AKey: Integer): UInt32;
var
  LBytes: PByte;
  LIndex: Integer;
begin
  Result := 2166136261;
  LBytes := PByte(@AKey);
  for LIndex := 0 to SizeOf(AKey) - 1 do
  begin
    Result := Result xor LBytes[LIndex];
    Result := Result * 16777619;
  end;
end;

procedure FillCollidingKeys(out AKeys: TIntCollisionKeys);
var
  LCandidate: Integer;
  LFound: Integer;
  LTargetBucket: UInt32;
begin
  LCandidate := 0;
  LFound := 0;
  LTargetBucket := HashInteger(LCandidate) and 63;
  while LFound < Length(AKeys) do
  begin
    if (HashInteger(LCandidate) and 63) = LTargetBucket then
    begin
      AKeys[LFound] := LCandidate;
      Inc(LFound);
    end;
    Inc(LCandidate);
  end;
end;

procedure TestBasicInsertFind;
var
  HT: TIntHashTable;
  LVal: Integer;
begin
  WriteLn('--- TestBasicInsertFind ---');
  HT := TIntHashTable.Create;
  try
    Check(HT.IsEmpty, 'empty initially');
    Check(HT.Insert(1, 100) = htOk, 'insert 1');
    Check(not HT.IsEmpty, 'not empty');
    Check(HT.ApproxCount = 1, 'count = 1');
    Check(HT.Find(1, LVal) = htOk, 'find 1');
    Check(LVal = 100, 'value = 100');
    Check(HT.Find(999, LVal) = htNotFound, 'find missing');
  finally
    HT.Free;
  end;
end;

procedure TestInsertOverwrite;
var
  HT: TIntHashTable;
  LVal: Integer;
begin
  WriteLn('--- TestInsertOverwrite ---');
  HT := TIntHashTable.Create;
  try
    HT.Insert(1, 100);
    Check(HT.Insert(1, 200) = htExists, 'duplicate key');
    Check(HT.Find(1, LVal) = htOk, 'find');
    Check(LVal = 100, 'original value preserved');
  finally
    HT.Free;
  end;
end;

procedure TestRemove;
var
  HT: TIntHashTable;
  LVal: Integer;
begin
  WriteLn('--- TestRemove ---');
  HT := TIntHashTable.Create;
  try
    HT.Insert(1, 100);
    HT.Insert(2, 200);
    Check(HT.Remove(1) = htOk, 'remove 1');
    Check(HT.Find(1, LVal) = htNotFound, 'find removed');
    Check(HT.Find(2, LVal) = htOk, 'find 2 still exists');
    Check(LVal = 200, 'value = 200');
    Check(HT.Remove(999) = htNotFound, 'remove missing');
  finally
    HT.Free;
  end;
end;

procedure TestContains;
var
  HT: TIntHashTable;
begin
  WriteLn('--- TestContains ---');
  HT := TIntHashTable.Create;
  try
    HT.Insert(42, 1);
    Check(HT.Contains(42), 'contains 42');
    Check(not HT.Contains(99), 'not contains 99');
    HT.Remove(42);
    Check(not HT.Contains(42), 'not contains after remove');
  finally
    HT.Free;
  end;
end;

procedure TestManyInserts;
var
  HT: TIntHashTable;
  LVal, I, LN: Integer;
begin
  WriteLn('--- TestManyInserts ---');
  LN := 1000;
  HT := TIntHashTable.Create(16);
  try
    for I := 1 to LN do
      Check(HT.Insert(I, I * 10) = htOk, 'insert ' + IntToStr(I));
    Check(HT.ApproxCount = LN, 'count = ' + IntToStr(LN));
    for I := 1 to LN do
    begin
      Check(HT.Find(I, LVal) = htOk, 'find ' + IntToStr(I));
      Check(LVal = I * 10, 'value');
    end;
  finally
    HT.Free;
  end;
end;

procedure TestInsertRemoveInsert;
var
  HT: TIntHashTable;
  LVal: Integer;
begin
  WriteLn('--- TestInsertRemoveInsert ---');
  HT := TIntHashTable.Create;
  try
    HT.Insert(1, 100);
    HT.Remove(1);
    Check(HT.Insert(1, 200) = htOk, 're-insert');
    Check(HT.Find(1, LVal) = htOk, 'find re-inserted');
    Check(LVal = 200, 'new value');
  finally
    HT.Free;
  end;
end;

procedure TestClose;
var
  HT: TIntHashTable;
begin
  WriteLn('--- TestClose ---');
  HT := TIntHashTable.Create;
  try
    HT.Insert(1, 100);
    HT.Close;
    Check(HT.IsClosed, 'is closed');
    Check(HT.Insert(2, 200) = htClosed, 'insert after close');
    Check(HT.Contains(1), 'can still read');
  finally
    HT.Free;
  end;
end;

procedure TestGrow;
var
  HT: TIntHashTable;
  LVal, I: Integer;
begin
  WriteLn('--- TestGrow ---');
  HT := TIntHashTable.Create(8);  // Small initial capacity
  try
    for I := 1 to 100 do
      HT.Insert(I, I);
    for I := 1 to 100 do
    begin
      Check(HT.Find(I, LVal) = htOk, 'find after grow');
      Check(LVal = I, 'value after grow');
    end;
  finally
    HT.Free;
  end;
end;

procedure TestTombstoneProbeChainAndChurn;
const
  INITIAL_INSERT_COUNT = 24;
  REMOVED_PREFIX_COUNT = 12;
  CHURN_ROUNDS = 128;
  CHURN_WIDTH = 8;
var
  HT: TIntHashTable;
  LKeys: TIntCollisionKeys;
  LIndex: Integer;
  LRound: Integer;
  LKey: Integer;
  LValue: Integer;
begin
  WriteLn('--- TestTombstoneProbeChainAndChurn ---');
  FillCollidingKeys(LKeys);
  HT := TIntHashTable.Create(64);
  try
    for LIndex := 0 to INITIAL_INSERT_COUNT - 1 do
      Check(HT.Insert(LKeys[LIndex], LKeys[LIndex]) = htOk,
        'insert colliding key before tombstones');
    for LIndex := 0 to REMOVED_PREFIX_COUNT - 1 do
      Check(HT.Remove(LKeys[LIndex]) = htOk, 'remove collision-chain prefix');
    for LIndex := REMOVED_PREFIX_COUNT to INITIAL_INSERT_COUNT - 1 do
      Check((HT.Find(LKeys[LIndex], LValue) = htOk) and
        (LValue = LKeys[LIndex]), 'tombstone does not break collision chain');

    for LIndex := INITIAL_INSERT_COUNT to High(LKeys) do
      Check(HT.Insert(LKeys[LIndex], LKeys[LIndex]) = htOk,
        'insert beyond tombstone chain');
    for LIndex := REMOVED_PREFIX_COUNT to High(LKeys) do
      Check((HT.Find(LKeys[LIndex], LValue) = htOk) and
        (LValue = LKeys[LIndex]), 'collision-chain value remains findable');
    Check(HT.ApproxCount = Length(LKeys) - REMOVED_PREFIX_COUNT,
      'count excludes tombstones');

    for LIndex := REMOVED_PREFIX_COUNT to High(LKeys) do
      Check(HT.Remove(LKeys[LIndex]) = htOk, 'remove collision-chain survivor');
    for LRound := 0 to CHURN_ROUNDS - 1 do
    begin
      for LIndex := 0 to CHURN_WIDTH - 1 do
      begin
        LKey := 100000 + LRound * CHURN_WIDTH + LIndex;
        Check(HT.Insert(LKey, LKey) = htOk, 'insert during tombstone churn');
      end;
      for LIndex := 0 to CHURN_WIDTH - 1 do
      begin
        LKey := 100000 + LRound * CHURN_WIDTH + LIndex;
        Check(HT.Remove(LKey) = htOk, 'remove during tombstone churn');
      end;
    end;
    Check(HT.IsEmpty, 'tombstone churn leaves table empty');
  finally
    HT.Free;
  end;
end;

procedure TestManagedTypesRejected;
var
  LManagedKeyTable: specialize TLockFreeHashTableImpl<string, Integer>;
  LManagedValueTable: specialize TLockFreeHashTableImpl<Integer, string>;
  LManagedKeyRejected: Boolean;
  LManagedValueRejected: Boolean;
begin
  WriteLn('--- TestManagedTypesRejected ---');
  LManagedKeyTable := nil;
  LManagedValueTable := nil;
  LManagedKeyRejected := False;
  LManagedValueRejected := False;
  try
    try
      LManagedKeyTable := specialize TLockFreeHashTableImpl<string, Integer>.Create;
    except
      on E: EArgumentError do
        LManagedKeyRejected := True;
    end;
    try
      LManagedValueTable := specialize TLockFreeHashTableImpl<Integer, string>.Create;
    except
      on E: EArgumentError do
        LManagedValueRejected := True;
    end;
    Check(LManagedKeyRejected, 'managed key type is rejected');
    Check(LManagedValueRejected, 'managed value type is rejected');
  finally
    LManagedKeyTable.Free;
    LManagedValueTable.Free;
  end;
end;

procedure ConcurrentInsertBarrier;
var
  LGeneration: Int32;
begin
  LGeneration := AtomicLoad32(GBarrierGeneration, moAcquire);
  if AtomicFetchAdd32(GBarrierCount, 1, moAcqRel) = CONCURRENT_INSERT_THREADS - 1 then
  begin
    AtomicStore32(GBarrierCount, 0, moRelease);
    AtomicFetchAdd32(GBarrierGeneration, 1, moAcqRel);
  end
  else
    while AtomicLoad32(GBarrierGeneration, moAcquire) = LGeneration do
      CpuPause;
end;

function ConcurrentInsertWorker(AArg: Pointer): Pointer; cdecl;
var
  LKey: Integer;
  LResult: TLockFreeHashTableResult;
begin
  Result := nil;
  for LKey := 1 to CONCURRENT_INSERT_ROUNDS do
  begin
    ConcurrentInsertBarrier;
    LResult := GConcurrentTable.Insert(LKey, LKey);
    if LResult = htOk then
      AtomicFetchAdd32(GConcurrentInsertOk, 1, moRelaxed)
    else if LResult <> htExists then
      AtomicFetchAdd32(GConcurrentInsertErrors, 1, moRelaxed);
    ConcurrentInsertBarrier;
  end;
end;

procedure TestConcurrentSameKeyInsertAndGrow;
var
  LHandles: array[0..CONCURRENT_INSERT_THREADS - 1] of TPlatformThreadHandle;
  LIndex: Integer;
  LReturnValue: Pointer;
  LValue: Integer;
begin
  WriteLn('--- TestConcurrentSameKeyInsertAndGrow ---');
  GConcurrentTable := TIntHashTable.Create(16);
  GBarrierCount := 0;
  GBarrierGeneration := 0;
  GConcurrentInsertOk := 0;
  GConcurrentInsertErrors := 0;
  try
    for LIndex := 0 to CONCURRENT_INSERT_THREADS - 1 do
      Check(platform_thread_create(LHandles[LIndex], @ConcurrentInsertWorker, nil) = 0,
        'create concurrent insert worker');
    for LIndex := 0 to CONCURRENT_INSERT_THREADS - 1 do
      Check(platform_thread_join(LHandles[LIndex], LReturnValue) = 0,
        'join concurrent insert worker');

    Check(GConcurrentInsertErrors = 0, 'concurrent inserts return only ok or exists');
    Check(GConcurrentInsertOk = CONCURRENT_INSERT_ROUNDS,
      'exactly one insert succeeds for each shared key');
    Check(GConcurrentTable.ApproxCount = CONCURRENT_INSERT_ROUNDS,
      'same-key races do not create duplicate entries');
    for LIndex := 1 to CONCURRENT_INSERT_ROUNDS do
      Check((GConcurrentTable.Find(LIndex, LValue) = htOk) and (LValue = LIndex),
        'all keys remain findable after concurrent growth');
  finally
    GConcurrentTable.Free;
    GConcurrentTable := nil;
  end;
end;

function ConcurrentReadDuringGrowWorker(AArg: Pointer): Pointer; cdecl;
var
  LPublishedKey: Int32;
  LValue: Integer;
begin
  Result := nil;
  while AtomicLoad32(GReadGrowStop, moAcquire) = 0 do
  begin
    if not GReadGrowTable.Contains(1) then
      AtomicFetchAdd32(GReadGrowErrors, 1, moRelaxed);
    if (GReadGrowTable.Find(1, LValue) <> htOk) or (LValue <> 1) then
      AtomicFetchAdd32(GReadGrowErrors, 1, moRelaxed);

    LPublishedKey := AtomicLoad32(GReadGrowPublishedKey, moAcquire);
    if (LPublishedKey >= 2) and
       ((GReadGrowTable.Find(LPublishedKey, LValue) <> htOk) or
        (LValue <> LPublishedKey)) then
      AtomicFetchAdd32(GReadGrowErrors, 1, moRelaxed);
    AtomicFetchAdd32(GReadGrowChecks, 1, moRelaxed);
  end;
end;

procedure TestConcurrentReadersDuringGrow;
var
  LHandles: array[0..CONCURRENT_READ_THREADS - 1] of TPlatformThreadHandle;
  LCreatedReaders: Integer;
  LJoinedReaders: Integer;
  LIndex: Integer;
  LKey: Integer;
  LReturnValue: Pointer;
  LSpinCount: Integer;
  LWriterErrors: Integer;
begin
  WriteLn('--- TestConcurrentReadersDuringGrow ---');
  GReadGrowTable := TIntHashTable.Create(16);
  GReadGrowStop := 0;
  GReadGrowPublishedKey := 1;
  GReadGrowChecks := 0;
  GReadGrowErrors := 0;
  LCreatedReaders := 0;
  LJoinedReaders := 0;
  try
    Check(GReadGrowTable.Insert(1, 1) = htOk, 'insert stable reader key');
    for LIndex := 0 to CONCURRENT_READ_THREADS - 1 do
    begin
      if platform_thread_create(LHandles[LIndex], @ConcurrentReadDuringGrowWorker, nil) <> 0 then
      begin
        Check(False, 'create reader-during-grow worker');
        Break;
      end;
      Inc(LCreatedReaders);
      Check(True, 'create reader-during-grow worker');
    end;

    LSpinCount := 0;
    while (AtomicLoad32(GReadGrowChecks, moAcquire) < LCreatedReaders) and
          (LSpinCount < 1000000) do
    begin
      platform_thread_yield;
      Inc(LSpinCount);
    end;
    Check((LCreatedReaders = 0) or
      (AtomicLoad32(GReadGrowChecks, moAcquire) >= LCreatedReaders),
      'reader-during-grow workers started');

    LWriterErrors := 0;
    for LKey := 2 to CONCURRENT_READ_GROW_KEYS do
    begin
      if GReadGrowTable.Insert(LKey, LKey) <> htOk then
        Inc(LWriterErrors);
      AtomicStore32(GReadGrowPublishedKey, LKey, moRelease);
      if (LKey and 63) = 0 then
        platform_thread_yield;
    end;
    AtomicStore32(GReadGrowStop, 1, moRelease);
    for LIndex := 0 to LCreatedReaders - 1 do
    begin
      Check(platform_thread_join(LHandles[LIndex], LReturnValue) = 0,
        'join reader-during-grow worker');
      Inc(LJoinedReaders);
    end;

    Check(LWriterErrors = 0, 'all inserts succeed while readers observe growth');
    Check(AtomicLoad32(GReadGrowChecks, moRelaxed) > 0,
      'reader-during-grow workers performed reads');
    Check(AtomicLoad32(GReadGrowErrors, moRelaxed) = 0,
      'contains and find remain stable during growth');
    Check(GReadGrowTable.ApproxCount = CONCURRENT_READ_GROW_KEYS,
      'reader-during-grow table retains every key');
  finally
    AtomicStore32(GReadGrowStop, 1, moRelease);
    for LIndex := LJoinedReaders to LCreatedReaders - 1 do
      platform_thread_join(LHandles[LIndex], LReturnValue);
    GReadGrowTable.Free;
    GReadGrowTable := nil;
  end;
end;

begin
  GTests := 0;
  GPassed := 0;

  TestBasicInsertFind;
  TestInsertOverwrite;
  TestRemove;
  TestContains;
  TestManyInserts;
  TestInsertRemoveInsert;
  TestClose;
  TestGrow;
  TestTombstoneProbeChainAndChurn;
  TestManagedTypesRejected;
  TestConcurrentSameKeyInsertAndGrow;
  TestConcurrentReadersDuringGrow;

  WriteLn;
  WriteLn(GPassed, '/', GTests, ' tests passed');
  if GPassed <> GTests then
    Halt(1);
end.
