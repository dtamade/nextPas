{
# nextpas.core.mem.allocator.sampling

## 摘要

Sampling allocator — 采样分配器（1/N 采样记录）。

特性:
- 每 N 次分配记录一次采样
- 采样记录：大小、时间戳
- 非采样分配零开销（直接透传）
- 统计：总分配数、采样数、采样率

适用场景: 生产环境性能分析、分配热点识别。

Author:    nextpas.core
Copyright: (c) 2025 nextpas.core. All rights reserved.
}

unit nextpas.core.mem.allocator.sampling;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.intf;

type
  {** 采样记录 }
  TSampleEntry = record
    Size: SizeUInt;
    Timestamp: UInt64;
    SequenceNum: UInt64;
  end;

  {** TSamplingAllocator
   *
   *  采样分配器。
   *  每 N 次分配记录一次采样，用于性能分析。
   *
   *  使用模式:
   *    var LSampling: TSamplingAllocator;
   *    LSampling := TSamplingAllocator.Create(DefaultAllocator, 1000);
   *    try
   *      // ... 正常使用 ...
   *      WriteLn('Total allocs: ', LSampling.TotalAllocs);
   *      WriteLn('Samples: ', LSampling.SampleCount);
   *    finally
   *      LSampling.Free;
   *    end;
   *}
  TSamplingAllocator = class(TInterfacedObject, IAllocator)
  private
    FInner: IAllocator;
    FSampleRate: UInt32;
    FTotalAllocs: UInt64;
    FSequenceNum: UInt64;
    { 采样记录 }
    FSamples: array of TSampleEntry;
    FSampleCount: UInt32;
    FSampleCapacity: UInt32;
    procedure GrowSamples;
    function NowMs: UInt64;
  public
    {** 创建采样分配器
     *  @param AInner 内部分配器
     *  @param ASampleRate 采样率（每 N 次分配采样一次，默认 1000）
     *}
    constructor Create(AInner: IAllocator; ASampleRate: UInt32 = 1000);
    destructor Destroy; override;

    function GetMem(ASize: SizeUInt): Pointer; inline;
    function AllocMem(ASize: SizeUInt): Pointer; inline;
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
    procedure FreeMem(APtr: Pointer); inline;

    {** 总分配次数 }
    function TotalAllocs: UInt64;
    {** 采样数量 }
    function SampleCount: UInt32;
    {** 获取指定索引的采样记录 }
    function GetSample(AIndex: UInt32): TSampleEntry;
    {** 重置统计 }
    procedure ResetStats;
    {** 采样率 }
    property SampleRate: UInt32 read FSampleRate;
    {** 内部分配器 }
    property Inner: IAllocator read FInner;

    function Traits: TAllocatorTraits; inline;
  end;

implementation

uses
  nextpas.core.mem.error,
  nextpas.core.platform.time;

const
  SAMPLE_INITIAL_CAP = 256;

function MonotonicMs: UInt64;
begin
  Result := platform_monotonic_ns div 1000000;
end;

{ TSamplingAllocator }

constructor TSamplingAllocator.Create(AInner: IAllocator; ASampleRate: UInt32);
begin
  inherited Create;
  if AInner = nil then
    raise EAllocError.Create(aeInvalidLayout, FormatAllocErrorMsg('TSamplingAllocator', 'Create', 'AInner cannot be nil'));
  if ASampleRate = 0 then
    ASampleRate := 1;
  FInner := AInner;
  FSampleRate := ASampleRate;
  FTotalAllocs := 0;
  FSequenceNum := 0;
  FSampleCount := 0;
  FSampleCapacity := SAMPLE_INITIAL_CAP;
  SetLength(FSamples, FSampleCapacity);
end;

destructor TSamplingAllocator.Destroy;
begin
  SetLength(FSamples, 0);
  FInner := nil;
  inherited Destroy;
end;

procedure TSamplingAllocator.GrowSamples;
begin
  FSampleCapacity := FSampleCapacity shl 1;
  SetLength(FSamples, FSampleCapacity);
end;

function TSamplingAllocator.NowMs: UInt64;
begin
  Result := MonotonicMs;
end;

function TSamplingAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := FInner.GetMem(ASize);
  if Result <> nil then
  begin
    Inc(FTotalAllocs);
    Inc(FSequenceNum);
    { 采样 }
    if (FTotalAllocs mod FSampleRate) = 0 then
    begin
      if FSampleCount >= FSampleCapacity then
        GrowSamples;
      FSamples[FSampleCount].Size := ASize;
      FSamples[FSampleCount].Timestamp := NowMs;
      FSamples[FSampleCount].SequenceNum := FSequenceNum;
      Inc(FSampleCount);
    end;
  end;
end;

function TSamplingAllocator.AllocMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := FInner.AllocMem(ASize);
  if Result <> nil then
  begin
    Inc(FTotalAllocs);
    Inc(FSequenceNum);
    if (FTotalAllocs mod FSampleRate) = 0 then
    begin
      if FSampleCount >= FSampleCapacity then
        GrowSamples;
      FSamples[FSampleCount].Size := ASize;
      FSamples[FSampleCount].Timestamp := NowMs;
      FSamples[FSampleCount].SequenceNum := FSequenceNum;
      Inc(FSampleCount);
    end;
  end;
end;

function TSamplingAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
begin
  if ASize = 0 then begin FreeMem(APtr); Exit(nil); end;
  if APtr = nil then Exit(GetMem(ASize));
  Result := FInner.ReallocMem(APtr, ASize);
end;

procedure TSamplingAllocator.FreeMem(APtr: Pointer); inline;
begin
  if APtr = nil then Exit;
  FInner.FreeMem(APtr);
end;

function TSamplingAllocator.TotalAllocs: UInt64;
begin
  Result := FTotalAllocs;
end;

function TSamplingAllocator.SampleCount: UInt32;
begin
  Result := FSampleCount;
end;

function TSamplingAllocator.GetSample(AIndex: UInt32): TSampleEntry;
begin
  if AIndex >= FSampleCount then
    raise EAllocError.Create(aeInvalidLayout, FormatAllocErrorMsg('TSamplingAllocator', 'GetSample', 'index out of range'));
  Result := FSamples[AIndex];
end;

procedure TSamplingAllocator.ResetStats;
begin
  FTotalAllocs := 0;
  FSequenceNum := 0;
  FSampleCount := 0;
end;

function TSamplingAllocator.Traits: TAllocatorTraits; inline;
begin
  if FInner <> nil then
    Result := FInner.Traits
  else
  begin
    Result.ZeroInitialized := False;
    Result.ThreadSafe := False;
    Result.SupportsRealloc := False;
  end;
end;

end.
