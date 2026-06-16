program test_mapped_ring_buffer;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.mem.mapped_ring_buffer,
  nextpas.core.platform.files;

var
  T: TTestRunner;

function MappedRingBufferTestPath: string;
begin
  Result := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas_mapped_ring_buffer_' + IntToStr(GetProcessID) + '.dat';
end;

procedure RemoveMappedRingBufferTestFile(const APath: string);
begin
  if APath <> '' then
    platform_file_unlink(PAnsiChar(APath));
end;

procedure CheckMappedRingBufferTestFileRemoved(const APath: string);
begin
  if APath <> '' then
    Check(platform_file_unlink(PAnsiChar(APath)) = 0, 'remove file-backed ring buffer test file');
end;

procedure TestRejectsInvalidFileBackedShape;
var
  LPath: string;
  LBuffer: TMappedRingBuffer;
begin
  LPath := MappedRingBufferTestPath;
  RemoveMappedRingBufferTestFile(LPath);
  LBuffer := TMappedRingBuffer.Create;
  try
    Check(not LBuffer.CreateFile(LPath, 0, SizeOf(UInt32)), 'reject zero capacity');
    Check(not LBuffer.CreateFile(LPath, 4, 0), 'reject zero element size');
  finally
    LBuffer.Free;
    RemoveMappedRingBufferTestFile(LPath);
  end;
end;

procedure TestFileBackedPushPreservesHeaderForOpen;
var
  LPath: string;
  LCreator: TMappedRingBuffer;
  LOpener: TMappedRingBuffer;
  LValue: UInt32;
begin
  LPath := MappedRingBufferTestPath;
  LCreator := nil;
  LOpener := nil;
  RemoveMappedRingBufferTestFile(LPath);
  try
    LCreator := TMappedRingBuffer.Create;
    Check(LCreator.CreateFile(LPath, 4, SizeOf(UInt32)), 'create file-backed ring buffer');
    Check(LCreator.IsCreator, 'first CreateFile creates backing file');
    LValue := $11223344;
    Check(LCreator.Push(@LValue), 'push into creator-backed ring buffer');
    FreeAndNil(LCreator);

    LOpener := TMappedRingBuffer.Create;
    Check(LOpener.OpenFile(LPath), 'OpenFile validates header after creator push');
    Check(not LOpener.IsCreator, 'OpenFile attaches as non-creator');
    CheckEqual(Int64(4), Int64(LOpener.Capacity), 'capacity persisted');
    CheckEqual(Int64(SizeOf(UInt32)), Int64(LOpener.ElementSize), 'element size persisted');
  finally
    LOpener.Free;
    LCreator.Free;
    CheckMappedRingBufferTestFileRemoved(LPath);
  end;
end;

procedure TestOpenFileRejectsTruncatedBackingFile;
var
  LPath: string;
  LCreator: TMappedRingBuffer;
  LOpener: TMappedRingBuffer;
begin
  LPath := MappedRingBufferTestPath;
  LCreator := nil;
  LOpener := nil;
  RemoveMappedRingBufferTestFile(LPath);
  try
    LCreator := TMappedRingBuffer.Create;
    Check(LCreator.CreateFile(LPath, 256, SizeOf(UInt32)), 'create file-backed ring buffer for truncation test');
    FreeAndNil(LCreator);

    CheckEqual(Int64(0), Int64(platform_file_truncate_path(PAnsiChar(LPath), 1024)),
      'truncate backing file below mapped ring buffer layout size');

    LOpener := TMappedRingBuffer.Create;
    Check(not LOpener.OpenFile(LPath), 'OpenFile rejects a truncated mapped ring buffer backing file');
    Check(not LOpener.IsValid, 'failed OpenFile must not leave a valid mapped ring buffer');
  finally
    LOpener.Free;
    LCreator.Free;
    CheckMappedRingBufferTestFileRemoved(LPath);
  end;
end;

procedure TestBatchOperationsKeepSequenceSpaceContract;
var
  LPath: string;
  LBuffer: TMappedRingBuffer;
  LInput: array[0..4] of UInt32;
  LFullInput: array[0..3] of UInt32;
  LValue: UInt32;
begin
  LPath := MappedRingBufferTestPath;
  LBuffer := nil;
  RemoveMappedRingBufferTestFile(LPath);
  try
    LBuffer := TMappedRingBuffer.Create;
    Check(LBuffer.CreateFile(LPath, 4, SizeOf(UInt32), mrbProducer),
      'create producer ring buffer for batch contract');
    CheckEqual(Int64(0), Int64(LBuffer.UsedSpace), 'new ring buffer has no used slots');
    CheckEqual(Int64(4), Int64(LBuffer.AvailableSpace), 'new ring buffer exposes full capacity');
    Check(LBuffer.IsEmpty, 'new ring buffer is empty');
    Check(not LBuffer.IsFull, 'new ring buffer is not full');

    LInput[0] := 1;
    LInput[1] := 2;
    LInput[2] := 3;
    LInput[3] := 4;
    LInput[4] := 5;
    CheckEqual(Int64(3), Int64(LBuffer.PushBatch(@LInput[0], 3)), 'push first batch');
    CheckEqual(Int64(3), Int64(LBuffer.UsedSpace), 'used slots after first batch');
    CheckEqual(Int64(1), Int64(LBuffer.AvailableSpace), 'available slots after first batch');
    CheckEqual(Int64(1), Int64(LBuffer.PushBatch(@LInput[3], 2)), 'producer batch stops at full capacity');
    Check(LBuffer.IsFull, 'producer ring buffer is full');
    CheckEqual(Int64(4), Int64(LBuffer.UsedSpace), 'used slots after filling producer ring');
    CheckEqual(Int64(0), Int64(LBuffer.AvailableSpace), 'available slots after filling producer ring');

    LBuffer.Clear;
    Check(LBuffer.IsEmpty, 'clear resets empty state before full batch');
    CheckEqual(Int64(0), Int64(LBuffer.UsedSpace), 'used slots after clear before full batch');
    CheckEqual(Int64(4), Int64(LBuffer.AvailableSpace), 'available slots after clear before full batch');

    LFullInput[0] := 10;
    LFullInput[1] := 11;
    LFullInput[2] := 12;
    LFullInput[3] := 13;
    CheckEqual(Int64(4), Int64(LBuffer.PushBatch(@LFullInput[0], 4)), 'batch can fill every sequence slot');
    Check(LBuffer.IsFull, 'full batch marks ring buffer full');
    CheckEqual(Int64(4), Int64(LBuffer.UsedSpace), 'used slots after full batch');
    CheckEqual(Int64(0), Int64(LBuffer.AvailableSpace), 'available slots after full batch');

    LBuffer.Clear;
    Check(LBuffer.IsEmpty, 'clear resets empty state');
    CheckEqual(Int64(0), Int64(LBuffer.UsedSpace), 'used slots after clear');
    CheckEqual(Int64(4), Int64(LBuffer.AvailableSpace), 'available slots after clear');

    LValue := 99;
    Check(LBuffer.Push(@LValue), 'single push works after clear');
    CheckEqual(Int64(1), Int64(LBuffer.UsedSpace), 'single push updates stats after clear');
  finally
    LBuffer.Free;
    CheckMappedRingBufferTestFileRemoved(LPath);
  end;
end;

procedure TestProducerConsumerBatchStatsAndClearUseSameSequenceSlots;
var
  LPath: string;
  LProducer: TMappedRingBuffer;
  LConsumer: TMappedRingBuffer;
  LInput: array[0..4] of UInt32;
  LOutput: array[0..3] of UInt32;
begin
  LPath := MappedRingBufferTestPath;
  LProducer := nil;
  LConsumer := nil;
  RemoveMappedRingBufferTestFile(LPath);
  try
    LProducer := TMappedRingBuffer.Create;
    LConsumer := TMappedRingBuffer.Create;
    Check(LProducer.CreateFile(LPath, 4, SizeOf(UInt32), mrbProducer), 'create producer ring');
    Check(LConsumer.OpenFile(LPath, mrbConsumer), 'open consumer ring');

    LInput[0] := 10;
    LInput[1] := 11;
    LInput[2] := 12;
    LInput[3] := 13;
    LInput[4] := 14;
    CheckEqual(Int64(3), Int64(LProducer.PushBatch(@LInput[0], 3)), 'producer pushes first cross-endpoint batch');
    CheckEqual(Int64(3), Int64(LConsumer.UsedSpace), 'consumer sees first producer batch');

    FillChar(LOutput, SizeOf(LOutput), 0);
    CheckEqual(Int64(2), Int64(LConsumer.PopBatch(@LOutput[0], 2)), 'consumer pops partial producer batch');
    CheckEqual(Int64(10), Int64(LOutput[0]), 'first cross-endpoint value preserved');
    CheckEqual(Int64(11), Int64(LOutput[1]), 'second cross-endpoint value preserved');
    CheckEqual(Int64(1), Int64(LConsumer.UsedSpace), 'consumer keeps remaining readable slot');
    CheckEqual(Int64(3), Int64(LProducer.AvailableSpace), 'producer sees freed slots after partial consumer pop');

    CheckEqual(Int64(2), Int64(LProducer.PushBatch(@LInput[3], 2)), 'producer pushes wrap batch');
    FillChar(LOutput, SizeOf(LOutput), 0);
    CheckEqual(Int64(3), Int64(LConsumer.PopBatch(@LOutput[0], 3)), 'consumer pops wrapped producer batch');
    CheckEqual(Int64(12), Int64(LOutput[0]), 'wrapped cross-endpoint first value preserved');
    CheckEqual(Int64(13), Int64(LOutput[1]), 'wrapped cross-endpoint second value preserved');
    CheckEqual(Int64(14), Int64(LOutput[2]), 'wrapped cross-endpoint third value preserved');
    CheckEqual(Int64(0), Int64(LConsumer.UsedSpace), 'consumer stats clear after wrapped pop batch');
    CheckEqual(Int64(4), Int64(LProducer.AvailableSpace), 'producer sees freed slots after wrapped consumer pop');

    CheckEqual(Int64(4), Int64(LProducer.PushBatch(@LInput[0], 4)), 'refill before consumer clear');
    Check(LConsumer.IsFull, 'consumer incoming ring is full before clear');
    LConsumer.Clear;
    CheckEqual(Int64(0), Int64(LConsumer.UsedSpace), 'consumer clear discards readable slots');
    CheckEqual(Int64(4), Int64(LProducer.AvailableSpace), 'producer sees slots freed after consumer clear');
  finally
    LConsumer.Free;
    LProducer.Free;
    CheckMappedRingBufferTestFileRemoved(LPath);
  end;
end;

procedure TestOpenProducerCreatorConsumerUseReverseRing;
var
  LPath: string;
  LCreatorConsumer: TMappedRingBuffer;
  LOpenerProducer: TMappedRingBuffer;
  LInput: array[0..2] of UInt32;
  LOutput: UInt32;
begin
  LPath := MappedRingBufferTestPath;
  LCreatorConsumer := nil;
  LOpenerProducer := nil;
  RemoveMappedRingBufferTestFile(LPath);
  try
    LCreatorConsumer := TMappedRingBuffer.Create;
    LOpenerProducer := TMappedRingBuffer.Create;
    Check(LCreatorConsumer.CreateFile(LPath, 4, SizeOf(UInt32), mrbConsumer),
      'create consumer endpoint for reverse ring');
    Check(LOpenerProducer.OpenFile(LPath, mrbProducer),
      'open producer endpoint for reverse ring');

    LInput[0] := 21;
    LInput[1] := 22;
    LInput[2] := 23;
    CheckEqual(Int64(3), Int64(LOpenerProducer.PushBatch(@LInput[0], 3)),
      'opener producer writes reverse ring batch');
    CheckEqual(Int64(3), Int64(LCreatorConsumer.UsedSpace),
      'creator consumer sees reverse ring batch');
    CheckEqual(Int64(1), Int64(LOpenerProducer.AvailableSpace),
      'opener producer stats use reverse ring slots');

    LOutput := 0;
    Check(LCreatorConsumer.Peek(@LOutput), 'creator consumer peeks reverse ring');
    CheckEqual(Int64(21), Int64(LOutput), 'reverse ring peek preserves first value');
    CheckEqual(Int64(3), Int64(LCreatorConsumer.UsedSpace),
      'peek does not consume reverse ring slot');

    Check(LCreatorConsumer.Pop(@LOutput), 'creator consumer pops first reverse ring value');
    CheckEqual(Int64(21), Int64(LOutput), 'first reverse ring value preserved');
    CheckEqual(Int64(2), Int64(LCreatorConsumer.UsedSpace),
      'creator consumer stats update after reverse ring pop');
    CheckEqual(Int64(2), Int64(LOpenerProducer.AvailableSpace),
      'opener producer sees freed reverse ring slot');
  finally
    LOpenerProducer.Free;
    LCreatorConsumer.Free;
    CheckMappedRingBufferTestFileRemoved(LPath);
  end;
end;

procedure TestBidirectionalEndpointsPushAndPopBothDirections;
var
  LPath: string;
  LCreator: TMappedRingBuffer;
  LOpener: TMappedRingBuffer;
  LCreatorSend: array[0..1] of UInt32;
  LOpenerSend: array[0..1] of UInt32;
  LValue: UInt32;
  LCreatorReceive: array[0..1] of UInt32;
  LOpenerReceive: array[0..1] of UInt32;
begin
  LPath := MappedRingBufferTestPath;
  LCreator := nil;
  LOpener := nil;
  RemoveMappedRingBufferTestFile(LPath);
  try
    LCreator := TMappedRingBuffer.Create;
    LOpener := TMappedRingBuffer.Create;
    Check(LCreator.CreateFile(LPath, 2, SizeOf(UInt32), mrbBidirectional),
      'create bidirectional creator endpoint');
    Check(LOpener.OpenFile(LPath, mrbBidirectional),
      'open bidirectional peer endpoint');

    LCreatorSend[0] := 11;
    LCreatorSend[1] := 12;
    LOpenerSend[0] := 21;
    LOpenerSend[1] := 22;
    CheckEqual(Int64(2), Int64(LCreator.PushBatch(@LCreatorSend[0], 2)),
      'creator fills send direction');
    CheckEqual(Int64(2), Int64(LOpener.PushBatch(@LOpenerSend[0], 2)),
      'opener fills send direction');

    LValue := 0;
    Check(LCreator.Peek(@LValue), 'creator peeks opener payload');
    CheckEqual(Int64(21), Int64(LValue), 'creator sees opener first value');
    Check(LOpener.Peek(@LValue), 'opener peeks creator payload');
    CheckEqual(Int64(11), Int64(LValue), 'opener sees creator first value');

    Check(LCreator.Pop(@LValue), 'creator pops opener first value');
    CheckEqual(Int64(21), Int64(LValue), 'creator preserves opener first value');
    Check(LOpener.Pop(@LValue), 'opener pops creator first value');
    CheckEqual(Int64(11), Int64(LValue), 'opener preserves creator first value');

    LValue := 13;
    Check(LCreator.Push(@LValue), 'creator wraps send direction after peer pop');
    LValue := 23;
    Check(LOpener.Push(@LValue), 'opener wraps send direction after peer pop');

    FillChar(LCreatorReceive, SizeOf(LCreatorReceive), 0);
    FillChar(LOpenerReceive, SizeOf(LOpenerReceive), 0);
    CheckEqual(Int64(2), Int64(LCreator.PopBatch(@LCreatorReceive[0], 2)),
      'creator drains wrapped opener payload');
    CheckEqual(Int64(22), Int64(LCreatorReceive[0]), 'creator receives wrapped opener second value');
    CheckEqual(Int64(23), Int64(LCreatorReceive[1]), 'creator receives wrapped opener third value');
    CheckEqual(Int64(2), Int64(LOpener.PopBatch(@LOpenerReceive[0], 2)),
      'opener drains wrapped creator payload');
    CheckEqual(Int64(12), Int64(LOpenerReceive[0]), 'opener receives wrapped creator second value');
    CheckEqual(Int64(13), Int64(LOpenerReceive[1]), 'opener receives wrapped creator third value');

    Check(not LCreator.Pop(@LValue), 'creator receive direction is empty after drain');
    Check(not LOpener.Pop(@LValue), 'opener receive direction is empty after drain');
    Check(LCreator.IsEmpty, 'creator send direction is empty after peer drain');
    Check(LOpener.IsEmpty, 'opener send direction is empty after peer drain');
  finally
    LOpener.Free;
    LCreator.Free;
    CheckMappedRingBufferTestFileRemoved(LPath);
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.mem.mapped_ring_buffer');
  T.Run('rejects invalid file-backed shape', @TestRejectsInvalidFileBackedShape);
  T.Run('file-backed push preserves header for open', @TestFileBackedPushPreservesHeaderForOpen);
  T.Run('OpenFile rejects truncated backing file', @TestOpenFileRejectsTruncatedBackingFile);
  T.Run('batch operations keep sequence space contract', @TestBatchOperationsKeepSequenceSpaceContract);
  T.Run('producer consumer batch stats and clear use same sequence slots',
    @TestProducerConsumerBatchStatsAndClearUseSameSequenceSlots);
  T.Run('open producer creator consumer use reverse ring',
    @TestOpenProducerCreatorConsumerUseReverseRing);
  T.Run('bidirectional endpoints push and pop both directions',
    @TestBidirectionalEndpointsPushAndPopBothDirections);
  T.Summary;
end.
