program test_mapped_ring_buffer_sharded;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.mem.mapped_ring_buffer,
  nextpas.core.mem.mapped_ring_buffer.sharded;

var
  T: TTestRunner;

function UniqueSharedName(const ASuffix: string): string;
begin
  Result := 'nextpas_mapped_ring_sharded_' + IntToStr(GetProcessID) + '_' + ASuffix;
end;

procedure TestCreateAndOpenUsesTwoDigitShardNames;
var
  LBaseName: string;
  LCreator: TMappedRingBufferSharded;
  LOpened: TMappedRingBufferSharded;
begin
  LBaseName := UniqueSharedName('twodigit');
  LCreator := TMappedRingBufferSharded.Create;
  LOpened := TMappedRingBufferSharded.Create;
  try
    Check(LCreator.CreateShared(LBaseName, 2, 8, SizeOf(UInt64)), 'create sharded ring buffer');
    CheckEqual(Int64(2), Int64(LCreator.ShardCount), 'creator shard count');
    Check(LOpened.OpenShared(LBaseName, 2), 'open sharded ring buffer');
    CheckEqual(Int64(2), Int64(LOpened.ShardCount), 'opened shard count');
  finally
    LOpened.Free;
    LCreator.Free;
  end;
end;

procedure TestShardNamesRemainFormatCompatibleAboveTwoDigits;
var
  LBaseName: string;
  LCreator: TMappedRingBufferSharded;
  LShard: TMappedRingBuffer;
begin
  LBaseName := UniqueSharedName('hundred');
  LCreator := TMappedRingBufferSharded.Create;
  LShard := TMappedRingBuffer.Create;
  try
    Check(LCreator.CreateShared(LBaseName, 101, 2, SizeOf(UInt32)),
      'create sharded ring buffer with three-digit index');
    Check(LShard.OpenShared(LBaseName + '_sh100'), 'open shard 100 by compatible name');
  finally
    LShard.Free;
    LCreator.Free;
  end;
end;

procedure TestRejectsInvalidShardCount;
var
  LBuffer: TMappedRingBufferSharded;
begin
  LBuffer := TMappedRingBufferSharded.Create;
  try
    Check(not LBuffer.CreateShared(UniqueSharedName('invalid'), 0, 8, SizeOf(UInt64)),
      'zero shards should be rejected');
    CheckEqual(Int64(0), Int64(LBuffer.ShardCount), 'invalid create leaves shard count zero');
  finally
    LBuffer.Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.mem.mapped_ring_buffer_sharded');
  T.Run('create and open uses two-digit shard names', @TestCreateAndOpenUsesTwoDigitShardNames);
  T.Run('shard names remain format compatible above two digits', @TestShardNamesRemainFormatCompatibleAboveTwoDigits);
  T.Run('rejects invalid shard count', @TestRejectsInvalidShardCount);
  T.Summary;
end.
