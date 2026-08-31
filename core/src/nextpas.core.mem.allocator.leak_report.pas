{
# nextpas.core.mem.allocator.leak_report

## 摘要

增强泄漏报告分配器 — 带时间戳、调用者地址和按标签聚合的泄漏报告。

特性:
- 每次分配记录时间戳和调用者地址
- 按标签聚合泄漏统计（数量/字节/调用者）
- 最老分配排序（检测长期泄漏）
- 线程安全

适用场景: 测试/诊断环境，定位泄漏源。

Author:    nextpas.core
Copyright: (c) 2025 nextpas.core. All rights reserved.
}

unit nextpas.core.mem.allocator.leak_report;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.mutex;

const
  {** 默认按标签聚合的最大标签数 }
  MAX_TAG_SUMMARIES = 64;

type
  {** 单次分配的泄漏记录 }
  TLeakEntry = record
    Address: PtrUInt;
    Size: SizeUInt;
    AllocId: QWord;
    Tag: string;
    CallerAddr: PtrUInt;
    AllocTimeMs: QWord;
  end;

  {** 按标签聚合的泄漏统计 }
  TTagSummary = record
    Tag: string;
    Count: Integer;
    TotalBytes: SizeUInt;
    CallerAddrs: array[0..7] of PtrUInt; { 最多 8 个不同调用者 }
    CallerCount: Integer;
  end;

  {** 泄漏报告结果 }
  TLeakReportResult = record
    TotalLeaks: Integer;
    TotalLeakBytes: SizeUInt;
    Tags: array[0..MAX_TAG_SUMMARIES - 1] of TTagSummary;
    TagCount: Integer;
  end;

  {** TLeakReportAllocator
   *
   *  包装任意 IAllocator，增强泄漏报告能力。
   *  记录每次分配的时间戳和调用者地址。
   *
   *  @warning 有内存和性能开销，仅用于测试/诊断场景。
   *}
  TLeakReportAllocator = class(TInterfacedObject, IAllocator)
  private
    FInner: IAllocator;
    FLock: TMemMutex;
    FNextAllocId: QWord;
    FCurrentTag: string;
    FStartTimeMs: QWord;
    { Open-addressing hash map: PtrUInt → entry }
    FKeys: array of PtrUInt;
    FSizes: array of SizeUInt;
    FAllocIds: array of QWord;
    FTags: array of string;
    FCallers: array of PtrUInt;
    FTimestamps: array of QWord;
    FMask: SizeUInt;
    FHighShift: SizeUInt;
    FCount: SizeUInt;
    FFill: SizeUInt;
    FTotalBytes: SizeUInt;
    procedure MapInit(aMinCapacity: SizeUInt);
    procedure MapClear;
    procedure MapGrow;
    procedure MapInsert(aKey: PtrUInt; aSize: SizeUInt; aAllocId: QWord;
      const aTag: string; aCaller: PtrUInt; aTimeMs: QWord);
    function MapDelete(aKey: PtrUInt; out aSize: SizeUInt;
      out aAllocId: QWord; out aTag: string; out aCaller: PtrUInt;
      out aTimeMs: QWord): Boolean;
    function NowMs: QWord;
  public

    function GetMem(ASize: SizeUInt): Pointer; inline;

    function AllocMem(ASize: SizeUInt): Pointer; inline;

    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;

    procedure FreeMem(APtr: Pointer); inline;
    constructor Create(AInner: IAllocator);
    destructor Destroy; override;

    {** 设置当前分配标签 }
    procedure SetTag(const ATag: string);
    {** 当前活跃分配数 }
    function ActiveAllocCount: SizeInt;
    {** 当前活跃分配字节 }
    function ActiveAllocBytes: SizeUInt;
    {** 是否有泄漏 }
    function HasLeaks: Boolean;

    {** 获取所有未释放分配的详细列表 }
    procedure GetLeakEntries(out AEntries: array of TLeakEntry;
      out ACount: Integer);
    {** 按标签聚合泄漏报告 }
    function ReportByTag: TLeakReportResult;
    {** 获取当前时间的毫秒数 (monotonic) }
    class function CurrentTimeMs: QWord;

    function Traits: TAllocatorTraits; inline;
  end;

implementation

uses
  nextpas.core.mem.utils,
  nextpas.core.mem.error,
  nextpas.core.platform.time;

const
  LEAK_MAP_MIN_CAP = 64;
  LEAK_TOMBSTONE = PtrUInt(1);

{ 获取单调时钟毫秒数 }
function MonotonicMs: QWord;
begin
  Result := platform_monotonic_ns div 1000000;
end;

{ 获取调用者的调用者地址 (跳过 GetMem/GetMem 帧) }
function GetCallerAddress: Pointer;
begin
  Result := get_caller_addr(get_frame);
end;

{ --- TLeakReportAllocator --- }

class function TLeakReportAllocator.CurrentTimeMs: QWord;
begin
  Result := MonotonicMs;
end;

function TLeakReportAllocator.NowMs: QWord;
begin
  Result := MonotonicMs - FStartTimeMs;
end;

constructor TLeakReportAllocator.Create(AInner: IAllocator);
begin
  inherited Create;
  if AInner = nil then
    raise EArgumentNil.Create('TLeakReportAllocator.Create: AInner cannot be nil');
  FInner := AInner;
  FNextAllocId := 1;
  FCurrentTag := '';
  FStartTimeMs := MonotonicMs;
  FLock.Init;
  MapInit(LEAK_MAP_MIN_CAP);
end;

destructor TLeakReportAllocator.Destroy;
begin
  FLock.Done;
  MapClear;
  FInner := nil;
  inherited Destroy;
end;

{ --- Hash map internals --- }

procedure TLeakReportAllocator.MapInit(aMinCapacity: SizeUInt);
var
  LCap: SizeUInt;
  LIdx: SizeUInt;
begin
  LCap := LEAK_MAP_MIN_CAP;
  while LCap < aMinCapacity do
    LCap := LCap shl 1;
  SetLength(FKeys, LCap);
  SetLength(FSizes, LCap);
  SetLength(FAllocIds, LCap);
  SetLength(FTags, LCap);
  SetLength(FCallers, LCap);
  SetLength(FTimestamps, LCap);
  for LIdx := 0 to LCap - 1 do
  begin
    FKeys[LIdx] := 0;
    FSizes[LIdx] := 0;
    FAllocIds[LIdx] := 0;
    FTags[LIdx] := '';
    FCallers[LIdx] := 0;
    FTimestamps[LIdx] := 0;
  end;
  FMask := LCap - 1;
  FHighShift := SizeUInt(64 - Log2UInt(LCap));
  FCount := 0;
  FFill := 0;
  FTotalBytes := 0;
end;

procedure TLeakReportAllocator.MapClear;
var
  LIdx: SizeUInt;
begin
  if Length(FKeys) = 0 then Exit;
  for LIdx := 0 to FMask do
  begin
    FKeys[LIdx] := 0;
    FSizes[LIdx] := 0;
    FAllocIds[LIdx] := 0;
    FTags[LIdx] := '';
    FCallers[LIdx] := 0;
    FTimestamps[LIdx] := 0;
  end;
  FCount := 0;
  FFill := 0;
  FTotalBytes := 0;
end;

procedure TLeakReportAllocator.MapGrow;
var
  LOldKeys: array of PtrUInt;
  LOldSizes: array of SizeUInt;
  LOldAllocIds: array of QWord;
  LOldTags: array of string;
  LOldCallers: array of PtrUInt;
  LOldTimestamps: array of QWord;
  LOldCap: SizeUInt;
  LIdx: SizeUInt;
  LKey: PtrUInt;
  LPos: SizeUInt;
  LHash: QWord;
begin
  LOldCap := FMask + 1;
  LOldKeys := FKeys;
  LOldSizes := FSizes;
  LOldAllocIds := FAllocIds;
  LOldTags := FTags;
  LOldCallers := FCallers;
  LOldTimestamps := FTimestamps;

  SetLength(FKeys, LOldCap shl 1);
  SetLength(FSizes, LOldCap shl 1);
  SetLength(FAllocIds, LOldCap shl 1);
  SetLength(FTags, LOldCap shl 1);
  SetLength(FCallers, LOldCap shl 1);
  SetLength(FTimestamps, LOldCap shl 1);
  FMask := (LOldCap shl 1) - 1;
  FHighShift := SizeUInt(64 - Log2UInt(FMask + 1));

  for LIdx := 0 to FMask do
  begin
    FKeys[LIdx] := 0;
    FSizes[LIdx] := 0;
    FAllocIds[LIdx] := 0;
    FTags[LIdx] := '';
    FCallers[LIdx] := 0;
    FTimestamps[LIdx] := 0;
  end;
  FCount := 0;
  FFill := 0;
  FTotalBytes := 0;

  for LIdx := 0 to LOldCap - 1 do
  begin
    LKey := LOldKeys[LIdx];
    if (LKey <> 0) and (LKey <> LEAK_TOMBSTONE) then
    begin
      LHash := MulHash64(LKey);
      LPos := (LHash shr FHighShift) and FMask;
      while FKeys[LPos] <> 0 do
        LPos := (LPos + 1) and FMask;
      FKeys[LPos] := LKey;
      FSizes[LPos] := LOldSizes[LIdx];
      FAllocIds[LPos] := LOldAllocIds[LIdx];
      FTags[LPos] := LOldTags[LIdx];
      FCallers[LPos] := LOldCallers[LIdx];
      FTimestamps[LPos] := LOldTimestamps[LIdx];
      Inc(FCount);
      Inc(FFill);
      Inc(FTotalBytes, LOldSizes[LIdx]);
    end;
  end;
end;

procedure TLeakReportAllocator.MapInsert(aKey: PtrUInt; aSize: SizeUInt;
  aAllocId: QWord; const aTag: string; aCaller: PtrUInt; aTimeMs: QWord);
var
  LPos: SizeUInt;
  LHash: QWord;
  LTomb: SizeUInt;
begin
  if (aKey = 0) or (aKey = LEAK_TOMBSTONE) then Exit;
  if (FFill + 1) > ((FMask + 1) shr 1) then
    MapGrow;
  LHash := MulHash64(aKey);
  LPos := (LHash shr FHighShift) and FMask;
  LTomb := High(SizeUInt);
  while True do
  begin
    if FKeys[LPos] = 0 then Break;
    if FKeys[LPos] = aKey then
    begin
      if FSizes[LPos] <= FTotalBytes then
        Dec(FTotalBytes, FSizes[LPos])
      else
        FTotalBytes := 0;
      FSizes[LPos] := aSize;
      FAllocIds[LPos] := aAllocId;
      FTags[LPos] := aTag;
      FCallers[LPos] := aCaller;
      FTimestamps[LPos] := aTimeMs;
      Inc(FTotalBytes, aSize);
      Exit;
    end;
    if (LTomb = High(SizeUInt)) and (FKeys[LPos] = LEAK_TOMBSTONE) then
      LTomb := LPos;
    LPos := (LPos + 1) and FMask;
  end;
  if LTomb <> High(SizeUInt) then
    LPos := LTomb
  else
    Inc(FFill);
  FKeys[LPos] := aKey;
  FSizes[LPos] := aSize;
  FAllocIds[LPos] := aAllocId;
  FTags[LPos] := aTag;
  FCallers[LPos] := aCaller;
  FTimestamps[LPos] := aTimeMs;
  Inc(FCount);
  Inc(FTotalBytes, aSize);
end;

function TLeakReportAllocator.MapDelete(aKey: PtrUInt; out aSize: SizeUInt;
  out aAllocId: QWord; out aTag: string; out aCaller: PtrUInt;
  out aTimeMs: QWord): Boolean;
var
  LPos: SizeUInt;
  LHash: QWord;
begin
  aSize := 0;
  aAllocId := 0;
  aTag := '';
  aCaller := 0;
  aTimeMs := 0;
  Result := False;
  if (aKey = 0) or (aKey = LEAK_TOMBSTONE) then Exit;
  if Length(FKeys) = 0 then Exit;
  LHash := MulHash64(aKey);
  LPos := (LHash shr FHighShift) and FMask;
  while True do
  begin
    if FKeys[LPos] = 0 then Exit;
    if FKeys[LPos] = aKey then
    begin
      aSize := FSizes[LPos];
      aAllocId := FAllocIds[LPos];
      aTag := FTags[LPos];
      aCaller := FCallers[LPos];
      aTimeMs := FTimestamps[LPos];
      FKeys[LPos] := LEAK_TOMBSTONE;
      FSizes[LPos] := 0;
      FAllocIds[LPos] := 0;
      FTags[LPos] := '';
      FCallers[LPos] := 0;
      FTimestamps[LPos] := 0;
      if FCount > 0 then Dec(FCount);
      if aSize <= FTotalBytes then
        Dec(FTotalBytes, aSize)
      else
        FTotalBytes := 0;
      Exit(True);
    end;
    LPos := (LPos + 1) and FMask;
  end;
end;

{ --- IAllocator implementation --- }

function TLeakReportAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
var
  LCaller: PtrUInt;
begin
  Result := FInner.GetMem(ASize);
  if Result <> nil then
  begin
    LCaller := PtrUInt(GetCallerAddress);
    FLock.Acquire;
    try
      MapInsert(PtrUInt(Result), ASize, FNextAllocId, FCurrentTag,
        LCaller, NowMs);
      Inc(FNextAllocId);
    finally
      FLock.Release;
    end;
  end;
end;

function TLeakReportAllocator.AllocMem(ASize: SizeUInt): Pointer; inline;
var
  LCaller: PtrUInt;
begin
  Result := FInner.AllocMem(ASize);
  if Result <> nil then
  begin
    LCaller := PtrUInt(GetCallerAddress);
    FLock.Acquire;
    try
      MapInsert(PtrUInt(Result), ASize, FNextAllocId, FCurrentTag,
        LCaller, NowMs);
      Inc(FNextAllocId);
    finally
      FLock.Release;
    end;
  end;
end;

function TLeakReportAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
var
  LOldSize: SizeUInt;
  LOldAllocId: QWord;
  LOldTag: string;
  LOldCaller: PtrUInt;
  LOldTime: QWord;
  LCaller: PtrUInt;
begin
  Result := FInner.ReallocMem(APtr, ASize);
  LCaller := PtrUInt(GetCallerAddress);
  FLock.Acquire;
  try
    if Result <> nil then
    begin
      if APtr <> nil then
      begin
        MapDelete(PtrUInt(APtr), LOldSize, LOldAllocId, LOldTag,
          LOldCaller, LOldTime);
        MapInsert(PtrUInt(Result), ASize, LOldAllocId, LOldTag,
          LCaller, LOldTime);
      end
      else
      begin
        MapInsert(PtrUInt(Result), ASize, FNextAllocId, FCurrentTag,
          LCaller, NowMs);
        Inc(FNextAllocId);
      end;
    end;
  finally
    FLock.Release;
  end;
end;

procedure TLeakReportAllocator.FreeMem(APtr: Pointer); inline;
var
  LSize: SizeUInt;
  LAllocId: QWord;
  LTag: string;
  LCaller: PtrUInt;
  LTime: QWord;
begin
  if APtr = nil then Exit;
  FLock.Acquire;
  try
    if not MapDelete(PtrUInt(APtr), LSize, LAllocId, LTag, LCaller, LTime) then
      raise EDoubleFree.Create(aeDoubleFree,
      FormatAllocErrorMsg('TLeakReportAllocator', 'FreeMem', 'pointer not tracked'));
    try
      FInner.FreeMem(APtr);
    except
      MapInsert(PtrUInt(APtr), LSize, LAllocId, LTag, LCaller, LTime);
      raise;
    end;
  finally
    FLock.Release;
  end;
end;

procedure TLeakReportAllocator.SetTag(const ATag: string);
begin
  FCurrentTag := ATag;
end;

function TLeakReportAllocator.ActiveAllocCount: SizeInt;
begin
  FLock.Acquire;
  try
    Result := SizeInt(FCount);
  finally
    FLock.Release;
  end;
end;

function TLeakReportAllocator.ActiveAllocBytes: SizeUInt;
begin
  FLock.Acquire;
  try
    Result := FTotalBytes;
  finally
    FLock.Release;
  end;
end;

function TLeakReportAllocator.HasLeaks: Boolean;
begin
  Result := ActiveAllocCount > 0;
end;

procedure TLeakReportAllocator.GetLeakEntries(out AEntries: array of TLeakEntry;
  out ACount: Integer);
var
  LIdx: SizeUInt;
begin
  ACount := 0;
  FLock.Acquire;
  try
    for LIdx := 0 to FMask do
    begin
      if (FKeys[LIdx] <> 0) and (FKeys[LIdx] <> LEAK_TOMBSTONE) then
      begin
        if ACount <= High(AEntries) then
        begin
          AEntries[ACount].Address := FKeys[LIdx];
          AEntries[ACount].Size := FSizes[LIdx];
          AEntries[ACount].AllocId := FAllocIds[LIdx];
          AEntries[ACount].Tag := FTags[LIdx];
          AEntries[ACount].CallerAddr := FCallers[LIdx];
          AEntries[ACount].AllocTimeMs := FTimestamps[LIdx];
        end;
        Inc(ACount);
      end;
    end;
  finally
    FLock.Release;
  end;
end;

function TLeakReportAllocator.ReportByTag: TLeakReportResult;
var
  LIdx: SizeUInt;
  LTag: string;
  LCaller: PtrUInt;
  LSize: SizeUInt;
  LI, LJ: Integer;
  LFound: Boolean;
begin
  Result.TotalLeaks := 0;
  Result.TotalLeakBytes := 0;
  Result.TagCount := 0;
  for LI := 0 to MAX_TAG_SUMMARIES - 1 do
  begin
    Result.Tags[LI].Tag := '';
    Result.Tags[LI].Count := 0;
    Result.Tags[LI].TotalBytes := 0;
    Result.Tags[LI].CallerCount := 0;
  end;
  FLock.Acquire;
  try
    for LIdx := 0 to FMask do
    begin
      if (FKeys[LIdx] = 0) or (FKeys[LIdx] = LEAK_TOMBSTONE) then
        Continue;
      LTag := FTags[LIdx];
      LCaller := FCallers[LIdx];
      LSize := FSizes[LIdx];
      Inc(Result.TotalLeaks);
      Inc(Result.TotalLeakBytes, LSize);

      { Find or create tag summary }
      LFound := False;
      for LI := 0 to Result.TagCount - 1 do
      begin
        if Result.Tags[LI].Tag = LTag then
        begin
          Inc(Result.Tags[LI].Count);
          Inc(Result.Tags[LI].TotalBytes, LSize);
          { Add caller if not already tracked }
          for LJ := 0 to Result.Tags[LI].CallerCount - 1 do
            if Result.Tags[LI].CallerAddrs[LJ] = LCaller then
            begin
              LFound := True;
              Break;
            end;
          if not LFound and (Result.Tags[LI].CallerCount < 8) then
          begin
            Result.Tags[LI].CallerAddrs[Result.Tags[LI].CallerCount] := LCaller;
            Inc(Result.Tags[LI].CallerCount);
          end;
          LFound := True;
          Break;
        end;
      end;
      if not LFound and (Result.TagCount < MAX_TAG_SUMMARIES) then
      begin
        Result.Tags[Result.TagCount].Tag := LTag;
        Result.Tags[Result.TagCount].Count := 1;
        Result.Tags[Result.TagCount].TotalBytes := LSize;
        Result.Tags[Result.TagCount].CallerAddrs[0] := LCaller;
        Result.Tags[Result.TagCount].CallerCount := 1;
        Inc(Result.TagCount);
      end;
    end;
  finally
    FLock.Release;
  end;
end;

function TLeakReportAllocator.Traits: TAllocatorTraits; inline;
begin
  if FInner <> nil then
    Result := FInner.Traits
  else
  begin
    Result.ZeroInitialized := False;
    Result.SupportsRealloc := True;
  end;
  Result.ThreadSafe := True;
end;

end.
