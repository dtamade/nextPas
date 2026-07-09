{
# nextpas.core.mem.allocator.prediction

## 摘要

分配预测器 — 基于历史模式的预分配策略。

特性:
- 跟踪每个 size class 的分配频率
- 识别最热门的分配大小
- 预分配热门大小的块（减少首次分配延迟）

适用场景: 启动预热、请求处理预分配。

Author:    fafafaStudio
Copyright: (c) 2025 fafafaStudio. All rights reserved.
}

unit nextpas.core.mem.allocator.prediction;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.sizeclass;

const
  {** 预测结果最大条目数 }
  PREDICTION_MAX_ENTRIES = 16;

type
  {** 预测条目: size class 索引 + 分配次数 }
  TPredictionEntry = record
    SizeClassIndex: Int32;
    AllocCount: QWord;
    UsableSize: SizeUInt;
  end;

  {** 预测结果 }
  TPredictionResult = record
    Entries: array[0..PREDICTION_MAX_ENTRIES - 1] of TPredictionEntry;
    Count: Integer;
  end;

  {** TPredictionAllocator
   *
   *  包装任意 IAllocator，跟踪分配频率模式。
   *  可预测最热门的分配大小并预分配。
   *}
  TPredictionAllocator = class(TInterfacedObject, IAllocator)
  private
    FInner: IAllocator;
    FAllocCounts: array[0..MEM_SIZECLASS_COUNT - 1] of QWord;
    FTotalAllocs: QWord;
    procedure RecordAlloc(ASize: SizeUInt);
  public
    constructor Create(AInner: IAllocator);
    destructor Destroy; override;

    function GetMem(ASize: SizeUInt): Pointer; inline;
    function AllocMem(ASize: SizeUInt): Pointer; inline;
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
    procedure FreeMem(APtr: Pointer); inline;

    {** 获取 top-N 热门分配大小 }
    function Predict(ATopN: Integer = 8): TPredictionResult;
    {** 预分配：为 top-N 热门大小各预分配 ACountPerClass 块 }
    procedure PreAllocate(ATopN: Integer = 4; ACountPerClass: Word = 8);
    {** 重置频率统计 }
    procedure ResetStats;
    {** 总分配次数 }
    property TotalAllocations: QWord read FTotalAllocs;

    function Traits: TAllocatorTraits; inline;
  end;

implementation

{ TPredictionAllocator }

constructor TPredictionAllocator.Create(AInner: IAllocator);
begin
  inherited Create;
  if AInner = nil then
    raise EArgumentNil.Create('TPredictionAllocator.Create: AInner cannot be nil');
  FInner := AInner;
  ResetStats;
end;

destructor TPredictionAllocator.Destroy;
begin
  FInner := nil;
  inherited Destroy;
end;

procedure TPredictionAllocator.ResetStats;
var
  LI: Int32;
begin
  for LI := 0 to MEM_SIZECLASS_COUNT - 1 do
    FAllocCounts[LI] := 0;
  FTotalAllocs := 0;
end;

procedure TPredictionAllocator.RecordAlloc(ASize: SizeUInt);
var
  LClass: Int32;
begin
  LClass := SizeClassIndex(ASize);
  if (LClass >= 0) and (LClass < MEM_SIZECLASS_COUNT) then
    Inc(FAllocCounts[LClass]);
  Inc(FTotalAllocs);
end;

function TPredictionAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := FInner.GetMem(ASize);
  if Result <> nil then
    RecordAlloc(ASize);
end;

function TPredictionAllocator.AllocMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := FInner.AllocMem(ASize);
  if Result <> nil then
    RecordAlloc(ASize);
end;

function TPredictionAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
begin
  Result := FInner.ReallocMem(APtr, ASize);
  if (Result <> nil) and (ASize > 0) then
    RecordAlloc(ASize);
end;

procedure TPredictionAllocator.FreeMem(APtr: Pointer); inline;
begin
  FInner.FreeMem(APtr);
end;

function TPredictionAllocator.Predict(ATopN: Integer): TPredictionResult;
var
  LI, LJ, LMaxIdx: Int32;
  LMaxCount: QWord;
  LUsed: array[0..MEM_SIZECLASS_COUNT - 1] of Boolean;
begin
  if ATopN > PREDICTION_MAX_ENTRIES then
    ATopN := PREDICTION_MAX_ENTRIES;
  if ATopN < 1 then
    ATopN := 1;
  FillChar(LUsed, SizeOf(LUsed), False);
  Result.Count := 0;
  { Simple selection sort for top-N }
  for LI := 0 to ATopN - 1 do
  begin
    LMaxIdx := -1;
    LMaxCount := 0;
    for LJ := 0 to MEM_SIZECLASS_COUNT - 1 do
    begin
      if (not LUsed[LJ]) and (FAllocCounts[LJ] > LMaxCount) then
      begin
        LMaxCount := FAllocCounts[LJ];
        LMaxIdx := LJ;
      end;
    end;
    if LMaxIdx < 0 then
      Break;
    LUsed[LMaxIdx] := True;
    Result.Entries[Result.Count].SizeClassIndex := LMaxIdx;
    Result.Entries[Result.Count].AllocCount := LMaxCount;
    Result.Entries[Result.Count].UsableSize := SizeClassSize(LMaxIdx);
    Inc(Result.Count);
  end;
end;

procedure TPredictionAllocator.PreAllocate(ATopN: Integer;
  ACountPerClass: Word);
var
  LPrediction: TPredictionResult;
  LI, LJ: Integer;
  LPtr: Pointer;
begin
  LPrediction := Predict(ATopN);
  for LI := 0 to LPrediction.Count - 1 do
  begin
    for LJ := 0 to ACountPerClass - 1 do
    begin
      LPtr := FInner.GetMem(LPrediction.Entries[LI].UsableSize);
      if LPtr = nil then
        Break;
      { Immediately free — this warms the TLS cache / central pool }
      FInner.FreeMem(LPtr);
    end;
  end;
end;

function TPredictionAllocator.Traits: TAllocatorTraits; inline;
begin
  if FInner <> nil then
    Result := FInner.Traits
  else
  begin
    Result.ZeroInitialized := False;
    Result.ThreadSafe := False;
    Result.SupportsRealloc := True;
  end;
end;

end.
