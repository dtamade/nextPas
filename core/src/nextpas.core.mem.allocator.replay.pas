{
# nextpas.core.mem.allocator.replay

## 摘要

Replay allocator — 分配模式录制/回放（调试用）。

特性:
- 录制：记录每次分配/释放的 (操作, 大小, 顺序号)
- 序列化：二进制格式，紧凑高效
- 回放：按相同顺序在目标分配器上重放
- 用途：重现生产环境的分配模式进行测试

适用场景: 调试内存问题、性能分析、回归测试。

Author:    fafafaStudio
Copyright: (c) 2025 fafafaStudio. All rights reserved.
}

unit nextpas.core.mem.allocator.replay;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.intf;

type
  {** 录制操作类型 }
  TReplayOp = (
    roGetMem,     { GetMem(size) }
    roAllocMem,   { AllocMem(size) }
    roFreeMem     { FreeMem }
  );

  {** 录制条目 }
  TReplayEntry = record
    Op: TReplayOp;
    Size: SizeUInt;
    SequenceNum: UInt32;
  end;

  {** 录制结果 }
  TReplayResult = record
    TotalOps: UInt32;
    AllocOps: UInt32;
    FreeOps: UInt32;
    PeakAllocs: UInt32;
    PeakBytes: SizeUInt;
  end;

  {** TReplayAllocator
   *
   *  包装任意 IAllocator，录制分配模式用于回放。
   *
   *  使用模式:
   *    var LReplay: TReplayAllocator;
   *    LReplay := TReplayAllocator.Create(DefaultAllocator);
   *    try
   *      LReplay.StartRecording;
   *      // ... 正常使用 ...
   *      LReplay.StopRecording;
   *      LReplay.SaveToFile('alloc_pattern.bin');
   *    finally
   *      LReplay.Free;
   *    end;
   *
   *  回放:
   *    var LReplay: TReplayAllocator;
   *    LReplay := TReplayAllocator.Create;
   *    try
   *      LReplay.LoadFromFile('alloc_pattern.bin');
   *      LReplay.Replay(SomeAllocator);
   *    finally
   *      LReplay.Free;
   *    end;
   *}
  TReplayAllocator = class(TInterfacedObject, IAllocator)
  private
    FInner: IAllocator;
    FRecording: Boolean;
    FEntries: array of TReplayEntry;
    FEntryCount: UInt32;
    FEntryCapacity: UInt32;
    FSequenceNum: UInt32;
    FActiveAllocs: UInt32;
    FActiveBytes: SizeUInt;
    FPeakAllocs: UInt32;
    FPeakBytes: SizeUInt;
    procedure GrowEntries;
    procedure RecordOp(AOp: TReplayOp; ASize: SizeUInt);
  public
    {** 创建录制分配器（无内部分配器，仅用于加载/回放） }
    constructor Create; overload;
    {** 创建录制分配器（包装内部分配器，用于录制） }
    constructor Create(AInner: IAllocator); overload;
    destructor Destroy; override;

    function GetMem(ASize: SizeUInt): Pointer; inline;
    function AllocMem(ASize: SizeUInt): Pointer; inline;
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
    procedure FreeMem(APtr: Pointer); inline;

    {** 开始录制 }
    procedure StartRecording;
    {** 停止录制 }
    procedure StopRecording;
    {** 是否正在录制 }
    function IsRecording: Boolean;
    {** 清空录制数据 }
    procedure Clear;

    {** 保存到文件 }
    procedure SaveToFile(const AFileName: string);
    {** 从文件加载 }
    procedure LoadFromFile(const AFileName: string);
    {** 获取录制结果 }
    function GetResult: TReplayResult;
    {** 录制条目数 }
    function EntryCount: UInt32;
    {** 获取指定索引的条目 }
    function GetEntry(AIndex: UInt32): TReplayEntry;

    {** 回放到目标分配器 }
    procedure Replay(ATarget: IAllocator);

    function Traits: TAllocatorTraits; inline;
  end;

implementation

uses
  nextpas.core.mem.error;

const
  REPLAY_INITIAL_CAP = 1024;
  REPLAY_FILE_MAGIC = $52504C59; { 'RPLY' }
  REPLAY_FILE_VERSION = 1;

type
  TReplayFileHeader = record
    Magic: UInt32;
    Version: UInt32;
    EntryCount: UInt32;
    Reserved: UInt32;
  end;

{ TReplayAllocator }

constructor TReplayAllocator.Create;
begin
  inherited Create;
  FInner := nil;
  FRecording := False;
  FEntryCount := 0;
  FEntryCapacity := REPLAY_INITIAL_CAP;
  SetLength(FEntries, FEntryCapacity);
  FSequenceNum := 0;
  FActiveAllocs := 0;
  FActiveBytes := 0;
  FPeakAllocs := 0;
  FPeakBytes := 0;
end;

constructor TReplayAllocator.Create(AInner: IAllocator);
begin
  Create;
  if AInner = nil then
    raise EAllocError.Create(aeInvalidLayout, 'TReplayAllocator.Create: AInner cannot be nil');
  FInner := AInner;
end;

destructor TReplayAllocator.Destroy;
begin
  SetLength(FEntries, 0);
  FInner := nil;
  inherited Destroy;
end;

procedure TReplayAllocator.GrowEntries;
begin
  FEntryCapacity := FEntryCapacity shl 1;
  SetLength(FEntries, FEntryCapacity);
end;

procedure TReplayAllocator.RecordOp(AOp: TReplayOp; ASize: SizeUInt);
begin
  if not FRecording then Exit;
  if FEntryCount >= FEntryCapacity then
    GrowEntries;
  FEntries[FEntryCount].Op := AOp;
  FEntries[FEntryCount].Size := ASize;
  FEntries[FEntryCount].SequenceNum := FSequenceNum;
  Inc(FEntryCount);
  Inc(FSequenceNum);

  { 更新统计 }
  case AOp of
    roGetMem, roAllocMem:
      begin
        Inc(FActiveAllocs);
        Inc(FActiveBytes, ASize);
        if FActiveAllocs > FPeakAllocs then
          FPeakAllocs := FActiveAllocs;
        if FActiveBytes > FPeakBytes then
          FPeakBytes := FActiveBytes;
      end;
    roFreeMem:
      begin
        if FActiveAllocs > 0 then
          Dec(FActiveAllocs);
      end;
  end;
end;

function TReplayAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := nil;
  if FInner <> nil then
    Result := FInner.GetMem(ASize);
  RecordOp(roGetMem, ASize);
end;

function TReplayAllocator.AllocMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := nil;
  if FInner <> nil then
    Result := FInner.AllocMem(ASize);
  RecordOp(roAllocMem, ASize);
end;

function TReplayAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
begin
  if ASize = 0 then begin FreeMem(APtr); Exit(nil); end;
  if APtr = nil then Exit(GetMem(ASize));
  Result := nil;
  if FInner <> nil then
    Result := FInner.ReallocMem(APtr, ASize);
  { ReallocMem 录制为 FreeMem + GetMem }
  if APtr <> nil then
    RecordOp(roFreeMem, 0);
  RecordOp(roGetMem, ASize);
end;

procedure TReplayAllocator.FreeMem(APtr: Pointer); inline;
begin
  if FInner <> nil then
    FInner.FreeMem(APtr);
  RecordOp(roFreeMem, 0);
end;

procedure TReplayAllocator.StartRecording;
begin
  FRecording := True;
end;

procedure TReplayAllocator.StopRecording;
begin
  FRecording := False;
end;

function TReplayAllocator.IsRecording: Boolean;
begin
  Result := FRecording;
end;

procedure TReplayAllocator.Clear;
begin
  FEntryCount := 0;
  FSequenceNum := 0;
  FActiveAllocs := 0;
  FActiveBytes := 0;
  FPeakAllocs := 0;
  FPeakBytes := 0;
end;

procedure TReplayAllocator.SaveToFile(const AFileName: string);
var
  LFile: file;
  LHeader: TReplayFileHeader;
begin
  AssignFile(LFile, AFileName);
  Rewrite(LFile, 1);
  try
    LHeader.Magic := REPLAY_FILE_MAGIC;
    LHeader.Version := REPLAY_FILE_VERSION;
    LHeader.EntryCount := FEntryCount;
    LHeader.Reserved := 0;
    BlockWrite(LFile, LHeader, SizeOf(LHeader));
    if FEntryCount > 0 then
      BlockWrite(LFile, FEntries[0], FEntryCount * SizeOf(TReplayEntry));
  finally
    CloseFile(LFile);
  end;
end;

procedure TReplayAllocator.LoadFromFile(const AFileName: string);
var
  LFile: file;
  LHeader: TReplayFileHeader;
begin
  AssignFile(LFile, AFileName);
  Reset(LFile, 1);
  try
    BlockRead(LFile, LHeader, SizeOf(LHeader));
    if LHeader.Magic <> REPLAY_FILE_MAGIC then
      raise EAllocError.Create(aeInvalidLayout, 'TReplayAllocator.LoadFromFile: invalid file magic');
    if LHeader.Version <> REPLAY_FILE_VERSION then
      raise EAllocError.Create(aeInvalidLayout, 'TReplayAllocator.LoadFromFile: unsupported version');

    FEntryCount := LHeader.EntryCount;
    FEntryCapacity := FEntryCount;
    if FEntryCapacity < REPLAY_INITIAL_CAP then
      FEntryCapacity := REPLAY_INITIAL_CAP;
    SetLength(FEntries, FEntryCapacity);

    if FEntryCount > 0 then
      BlockRead(LFile, FEntries[0], FEntryCount * SizeOf(TReplayEntry));
  finally
    CloseFile(LFile);
  end;
end;

function TReplayAllocator.GetResult: TReplayResult;
var
  LI: UInt32;
begin
  Result.TotalOps := FEntryCount;
  Result.AllocOps := 0;
  Result.FreeOps := 0;
  Result.PeakAllocs := FPeakAllocs;
  Result.PeakBytes := FPeakBytes;

  for LI := 0 to FEntryCount - 1 do
  begin
    case FEntries[LI].Op of
      roGetMem, roAllocMem: Inc(Result.AllocOps);
      roFreeMem: Inc(Result.FreeOps);
    end;
  end;
end;

function TReplayAllocator.EntryCount: UInt32;
begin
  Result := FEntryCount;
end;

function TReplayAllocator.GetEntry(AIndex: UInt32): TReplayEntry;
begin
  if AIndex >= FEntryCount then
    raise EAllocError.Create(aeInvalidLayout, 'TReplayAllocator.GetEntry: index out of range');
  Result := FEntries[AIndex];
end;

procedure TReplayAllocator.Replay(ATarget: IAllocator);
var
  LI: UInt32;
  LPtrs: array of Pointer;
  LAllocIdx: UInt32;
begin
  if ATarget = nil then
    raise EAllocError.Create(aeInvalidLayout, 'TReplayAllocator.Replay: ATarget cannot be nil');

  { 简单回放：按顺序执行，不跟踪指针 }
  LAllocIdx := 0;
  SetLength(LPtrs, FPeakAllocs + 1);

  for LI := 0 to FEntryCount - 1 do
  begin
    case FEntries[LI].Op of
      roGetMem:
        begin
          if LAllocIdx < Length(LPtrs) then
          begin
            LPtrs[LAllocIdx] := ATarget.GetMem(FEntries[LI].Size);
            Inc(LAllocIdx);
          end;
        end;
      roAllocMem:
        begin
          if LAllocIdx < Length(LPtrs) then
          begin
            LPtrs[LAllocIdx] := ATarget.AllocMem(FEntries[LI].Size);
            Inc(LAllocIdx);
          end;
        end;
      roFreeMem:
        begin
          if LAllocIdx > 0 then
          begin
            Dec(LAllocIdx);
            if LPtrs[LAllocIdx] <> nil then
              ATarget.FreeMem(LPtrs[LAllocIdx]);
            LPtrs[LAllocIdx] := nil;
          end;
        end;
    end;
  end;

  { 释放剩余分配 }
  while LAllocIdx > 0 do
  begin
    Dec(LAllocIdx);
    if LPtrs[LAllocIdx] <> nil then
      ATarget.FreeMem(LPtrs[LAllocIdx]);
  end;

  SetLength(LPtrs, 0);
end;

function TReplayAllocator.Traits: TAllocatorTraits; inline;
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
