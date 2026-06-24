program test_mapped_ring_buffer_sharded;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.testing,
  nextpas.core.mem.mapped_ring_buffer,
  nextpas.core.mem.mapped_ring_buffer.sharded;

var
  T: TTestRunner;

procedure TestRejectsInvalidShardCounts;
var
  LBuffer: TMappedRingBufferSharded;
begin
  LBuffer := TMappedRingBufferSharded.Create;
  try
    Check(not LBuffer.CreateShared('nextpas_mapped_ring_buffer_sharded_invalid', 0, 4, SizeOf(UInt32)),
      'CreateShared rejects zero shard count');
    Check(not LBuffer.OpenShared('nextpas_mapped_ring_buffer_sharded_invalid', 0),
      'OpenShared rejects zero shard count');
  finally
    LBuffer.Free;
  end;
end;

function ShardedRingBufferTestName: string;
begin
  Result := 'nextpas_mapped_ring_buffer_sharded_' + IntToStr(GetProcessID);
end;

procedure CheckSharedShardExists(const AName: string);
var
  LShard: TMappedRingBuffer;
begin
  LShard := TMappedRingBuffer.Create;
  try
    Check(LShard.OpenShared(AName), 'open shared shard ' + AName);
    Check(LShard.IsValid, 'shared shard is valid ' + AName);
  finally
    LShard.Free;
  end;
end;

procedure TestSharedShardNamesUseStableTwoDigitSuffixes;
var
  LBaseName: string;
  LBuffer: TMappedRingBufferSharded;
begin
  LBaseName := ShardedRingBufferTestName;
  LBuffer := TMappedRingBufferSharded.Create;
  try
    Check(LBuffer.CreateShared(LBaseName, 11, 2, SizeOf(UInt32)),
      'create sharded ring buffer');
    CheckEqual(Int64(11), Int64(LBuffer.ShardCount), 'shard count');

    CheckSharedShardExists(LBaseName + '_sh00');
    CheckSharedShardExists(LBaseName + '_sh09');
    CheckSharedShardExists(LBaseName + '_sh10');
  finally
    LBuffer.Free;
  end;
end;

procedure TestShardsExposeUnderlyingSequenceCapacity;
var
  LBaseName: string;
  LProducer: TMappedRingBufferSharded;
  LConsumer: TMappedRingBufferSharded;
  LInput: UInt32;
  LOutput: UInt32;
begin
  LBaseName := ShardedRingBufferTestName + '_capacity';
  LProducer := nil;
  LConsumer := nil;
  try
    LProducer := TMappedRingBufferSharded.Create;
    LConsumer := TMappedRingBufferSharded.Create;
    Check(LProducer.CreateShared(LBaseName, 2, 2, SizeOf(UInt32)),
      'create sharded ring buffer for capacity contract');
    Check(LConsumer.OpenShared(LBaseName, 2),
      'open sharded ring buffer consumer for capacity contract');

    LInput := 1;
    Check(LProducer.Push(@LInput), 'push first shard value');
    LInput := 2;
    Check(LProducer.Push(@LInput), 'push second shard value');
    LInput := 3;
    Check(LProducer.Push(@LInput), 'push third shard value');
    LInput := 4;
    Check(LProducer.Push(@LInput), 'push fourth shard value');
    LInput := 5;
    Check(not LProducer.Push(@LInput), 'full shards reject overflow value');

    LOutput := 0;
    Check(LConsumer.Pop(@LOutput), 'pop first shard value');
    CheckEqual(Int64(1), Int64(LOutput), 'first sharded value preserved');
    Check(LConsumer.Pop(@LOutput), 'pop second shard value');
    CheckEqual(Int64(2), Int64(LOutput), 'second sharded value preserved');
    Check(LConsumer.Pop(@LOutput), 'pop third shard value');
    CheckEqual(Int64(3), Int64(LOutput), 'third sharded value preserved');
    Check(LConsumer.Pop(@LOutput), 'pop fourth shard value');
    CheckEqual(Int64(4), Int64(LOutput), 'fourth sharded value preserved');
    Check(not LConsumer.Pop(@LOutput), 'empty shards reject extra pop');
  finally
    LConsumer.Free;
    LProducer.Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.mem.mapped_ring_buffer.sharded');
  T.Run('rejects invalid shard counts', @TestRejectsInvalidShardCounts);
  T.Run('shared shard names use stable two-digit suffixes', @TestSharedShardNamesUseStableTwoDigitSuffixes);
  T.Run('shards expose underlying sequence capacity', @TestShardsExposeUnderlyingSequenceCapacity);
  T.Summary;
end.
