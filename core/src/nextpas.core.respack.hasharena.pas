unit nextpas.core.respack.hasharena;

{** @desc respack 去重/交叠哈希 arena 单源：桶数/单 slab 分配，供 writer.layout/reader 共用。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.respack.base,
  nextpas.core.mem.arena.local;

type
  // MIN=256 为哈希分散下限(CONTRACT 锁定)；writer.layout N<=4 已走线性免 arena、
  // reader overlap tiny(N=2..4)仍 MIN 256 单 slab(256*8=2K)Open 期一次性、try..finally 释放，相对 Total 可忽略，保留 MIN。
  TResPackDedupBuckets = record
    const MIN = 256; // MIN 256 保障哈希分散，tiny pack 2K slab 可忽略
    const MAX = 65536;
    class function BucketCountFor(const ANeeded: SizeUInt): SizeUInt; static; inline;
  end;

procedure ResPackDedupInit(const AN: SizeUInt; out AArena: TLocalArena; out ABucketsHead: PSizeInt; out ASlotNext: PSizeInt; out ABucketCount: SizeUInt);
procedure ResPackOverlapInit(const AN: SizeUInt; out AArena: TLocalArena; out ABucketsHead: PSizeInt; out ASlotNext: PSizeInt; out ADistinct: PResPackDistinct; out ABucketCount: SizeUInt);
procedure ResPackDedupDone(var AArena: TLocalArena); inline;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.bytes.ops;

class function TResPackDedupBuckets.BucketCountFor(const ANeeded: SizeUInt): SizeUInt; inline;
var
  Target: SizeUInt;
begin
  if ANeeded <= MIN then Exit(MIN);
  if ANeeded >= MAX then Exit(MAX);
  Target := ANeeded;
  Result := BytesNextCapacity(MIN, Target);
  if Result > MAX then Result := MAX;
  if Result < MIN then Result := MIN;
end;

{ 算桶数+建 arena+分配填$FF 单源；Alloc 返回 slab 内指针零拷贝，$FF 为 -1 链终止哨兵 }
procedure ResPackHashArenaInit(const AN: SizeUInt; const AExtra: SizeUInt; const ATag: string; out AArena: TLocalArena; out ABucketsHead: PSizeInt; out ASlotNext: PSizeInt; out ABucketCount: SizeUInt);
var
  NeedBuckets, Total, Target: SizeUInt;
begin
  AArena := nil;
  ABucketsHead := nil;
  ASlotNext := nil;
  ABucketCount := 0;
  Target := 0;
  if not TryMulSizeUInt(AN, 2, Target) then
    Target := High(SizeUInt);
  ABucketCount := TResPackDedupBuckets.BucketCountFor(Target);
  if not TryMulSizeUInt(ABucketCount + AN, SizeUInt(SizeOf(SizeInt)), NeedBuckets) then
    raise EResPackTooLarge.Create('respack: ' + ATag + ' arena size overflow');
  if not TryAddSizeUInt(NeedBuckets, AExtra, Total) then
    raise EResPackTooLarge.Create('respack: ' + ATag + ' arena size overflow');
  try
    AArena := TLocalArena.Create(Total);
  except
    on E: EOutOfMemoryError do
      raise EResPackTooLarge.Create('respack: ' + ATag + ' arena too large');
  end;
  ABucketsHead := PSizeInt(AArena.Alloc(ABucketCount * SizeUInt(SizeOf(SizeInt))));
  ASlotNext := PSizeInt(AArena.Alloc(AN * SizeUInt(SizeOf(SizeInt))));
  if (ABucketsHead = nil) or (ASlotNext = nil) then
  begin
    ABucketsHead := nil;
    ASlotNext := nil;
    ABucketCount := 0;
    AArena.Free;
    AArena := nil;
    raise EResPackTooLarge.Create('respack: ' + ATag + ' arena alloc failed');
  end;
  FillChar(ABucketsHead^, ABucketCount * SizeUInt(SizeOf(SizeInt)), $FF);
  FillChar(ASlotNext^, AN * SizeUInt(SizeOf(SizeInt)), $FF);
end;

procedure ResPackDedupInit(const AN: SizeUInt; out AArena: TLocalArena; out ABucketsHead: PSizeInt; out ASlotNext: PSizeInt; out ABucketCount: SizeUInt);
begin
  AArena := nil;
  ABucketsHead := nil;
  ASlotNext := nil;
  ABucketCount := 0;
  if AN = 0 then Exit;
  ResPackHashArenaInit(AN, 0, 'dedup', AArena, ABucketsHead, ASlotNext, ABucketCount);
end;

procedure ResPackOverlapInit(const AN: SizeUInt; out AArena: TLocalArena; out ABucketsHead: PSizeInt; out ASlotNext: PSizeInt; out ADistinct: PResPackDistinct; out ABucketCount: SizeUInt);
var
  NeedDistinct: SizeUInt;
begin
  AArena := nil;
  ABucketsHead := nil;
  ASlotNext := nil;
  ADistinct := nil;
  ABucketCount := 0;
  if AN <= 1 then Exit;
  if not TryMulSizeUInt(AN, SizeUInt(SizeOf(TResPackDistinct)), NeedDistinct) then
    raise EResPackTooLarge.Create('respack: overlap distinct size overflow');
  ResPackHashArenaInit(AN, NeedDistinct, 'overlap', AArena, ABucketsHead, ASlotNext, ABucketCount);
  ADistinct := PResPackDistinct(AArena.Alloc(AN * SizeUInt(SizeOf(TResPackDistinct))));
  if ADistinct = nil then
  begin
    ABucketsHead := nil;
    ASlotNext := nil;
    ABucketCount := 0;
    AArena.Free;
    AArena := nil;
    raise EResPackTooLarge.Create('respack: overlap arena alloc failed');
  end;
end;

procedure ResPackDedupDone(var AArena: TLocalArena); inline;
begin
  if AArena <> nil then
  begin
    AArena.Free;
    AArena := nil;
  end;
end;

end.