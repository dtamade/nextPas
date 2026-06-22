unit nextpas.core.mem.arena.chunked;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.math,
  nextpas.core.mem.base,
  nextpas.core.mem.error,
  nextpas.core.mem.intf,
  nextpas.core.mem.arena.base,
  nextpas.core.mem.arena.intf;

type
  {** TChunkedArena
   *
   *  基于段的可增长 Arena 分配器（Bump Allocator），使用单调递增的标记管理虚拟地址空间。
   *  支持几何增长或线性增长策略。
   *
   *  非线程安全。多线程环境请自行加锁。
   *}
{ TODO: 几何扩容优化 — 需要引入 FSegmentCount 字段
  当前 Length(FSegments) = count = capacity (线性增长)
  几何扩容后 Length(FSegments) = capacity ≠ count
  重构点: ~15 处 Length(FSegments) / High(FSegments) 引用改为 FSegmentCount }
  TChunkedArena = class(TInterfacedObject, IArena)
  private
    type
      TSegment = record
        Raw: Pointer;
        RawSize: SizeUInt;
        Base: PByte;
        Size: SizeUInt;
        Used: SizeUInt;
        StartOffset: SizeUInt;
      end;
      PSegment = ^TSegment;
  private
    FSegments: array of TSegment;
    FActive: SizeInt;
    FTotalSize: SizeUInt;
    FAlignment: SizeUInt;
    FMaxSize: SizeUInt;
    FGrowthKind: TArenaGrowthKind;
    FGrowthFactor: Double;
    FGrowthStep: SizeUInt;
    FGrowthBaseSize: SizeUInt;
    FKeepSegments: Boolean;
    FAllocator: IAllocator;
    FPeakUsed: SizeUInt;
    FTotalAllocs: QWord;
    { Chunk cache: freed segments cached for reuse (Go-style reuse→ready→new) }
    FFreeSegments: array of TSegment;
    FFreeCount: SizeInt;
    FCacheLimit: SizeInt;
  private
    function CurrentUsed: SizeUInt; inline;
    function AlignPtr(aPtr: PByte; aAlign: SizeUInt): PByte; inline;
    function CalcRequiredMinSize(aSize, aAlignment: SizeUInt; out aMinSize: SizeUInt): Boolean;
    function CalcNextSegmentSize(aMinSize: SizeUInt; out aUpdateGrowthBase: Boolean): SizeUInt;
    function AddSegment(aMinSize: SizeUInt): Boolean;
    function TryReuseSegment(aMinSize: SizeUInt): Boolean;
    procedure FreeSegment(aIndex: SizeInt);
    procedure CacheSegment(aIndex: SizeInt);
    procedure ShrinkToSegmentCount(aCount: SizeInt);
    procedure NormalizeState(aActiveIndex: SizeInt; aActiveUsed: SizeUInt);
    procedure ClearCache;
  public
    constructor Create(const aConfig: TArenaConfig); overload;
    constructor Create(aInitialSize: SizeUInt; aMaxSize: SizeUInt = 0); overload;
    destructor Destroy; override;

    { IArena }
    function Alloc(aSize: SizeUInt): Pointer;
    function AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
    function AllocZeroed(aSize: SizeUInt): Pointer;
    function SaveMark: TArenaMark;
    procedure RestoreToMark(aMark: TArenaMark);
    procedure Reset;
    function UsedSize: SizeUInt;
    function RemainingSize: SizeUInt;
    function Stats: TArenaStats;

    { Diagnostics }
    function SegmentCount: SizeUInt; inline;
    property PeakUsed: SizeUInt read FPeakUsed;
    property TotalAllocCount: QWord read FTotalAllocs;
    property Alignment: SizeUInt read FAlignment;
  end;

implementation

{$PUSH}
{$WARN 4055 OFF} // pointer/ordinal conversions in arena internals

const
  { Max cached freed segments to reuse on next Reset (Go-style chunk cache) }
  CHUNK_CACHE_LIMIT = 8;

function TChunkedArena.AlignPtr(aPtr: PByte; aAlign: SizeUInt): PByte;
var
  LMask: PtrUInt;
  LPtrU: PtrUInt;
begin
  if aAlign <= 1 then
    Exit(aPtr);
  LMask := PtrUInt(aAlign - 1);
  LPtrU := PtrUInt(aPtr);
  if LMask > (High(PtrUInt) - LPtrU) then
    Exit(nil);
  Result := PByte((LPtrU + LMask) and not LMask);
end;

function TChunkedArena.CurrentUsed: SizeUInt;
begin
  if (FActive < 0) or (FActive > High(FSegments)) then
    Exit(0);
  Result := FSegments[FActive].StartOffset + FSegments[FActive].Used;
end;

function TChunkedArena.CalcRequiredMinSize(aSize, aAlignment: SizeUInt; out aMinSize: SizeUInt): Boolean;
var
  LAlignPad: SizeUInt;
begin
  aMinSize := 0;
  if aAlignment <= 1 then
  begin
    aMinSize := aSize;
    Exit(True);
  end;

  LAlignPad := aAlignment - 1;
  if aSize > (High(SizeUInt) - LAlignPad) then
    Exit(False);
  aMinSize := aSize + LAlignPad;
  Result := True;
end;

function TChunkedArena.CalcNextSegmentSize(aMinSize: SizeUInt; out aUpdateGrowthBase: Boolean): SizeUInt;
var
  LBaseSize: SizeUInt;
  LGrowthBase: SizeUInt;
  LFactor: Double;
  LTmp: Double;
  LThreshold: SizeUInt;
begin
  aUpdateGrowthBase := True;
  if Length(FSegments) = 0 then
  begin
    Result := aMinSize;
    Exit;
  end;

  LGrowthBase := FGrowthBaseSize;
  if LGrowthBase = 0 then
    LGrowthBase := FSegments[High(FSegments)].Size;
  case FGrowthKind of
    agkLinear:
      begin
        LBaseSize := LGrowthBase + FGrowthStep;
        if LBaseSize < LGrowthBase then
          Exit(0);
      end;
  else
    begin
      LFactor := FGrowthFactor;
      if LFactor < 1.1 then
        LFactor := 2.0;
      LTmp := Double(LGrowthBase) * LFactor;
      if (LTmp <= 0.0) or (LTmp > Double(High(SizeUInt))) then
        Exit(0);
      LBaseSize := SizeUInt(Trunc(LTmp));
      if LBaseSize <= LGrowthBase then
        LBaseSize := LGrowthBase;
    end;
  end;

  if LBaseSize < aMinSize then
  begin
    LThreshold := LBaseSize;
    if LThreshold > (High(SizeUInt) div 8) then
      LThreshold := High(SizeUInt)
    else
      LThreshold := LThreshold * 8;
    if (LBaseSize <> 0) and (aMinSize > LThreshold) then
    begin
      aUpdateGrowthBase := False;
      Result := aMinSize;
      Exit;
    end;

    Result := aMinSize;
    Exit;
  end;

  Result := LBaseSize;
end;

function TChunkedArena.AddSegment(aMinSize: SizeUInt): Boolean;
var
  LSegSize: SizeUInt;
  LUpdateGrowthBase: Boolean;
  LAllocSize: SizeUInt;
  LRaw: Pointer;
  LAddr, LAligned: PtrUInt;
  LMask: SizeUInt;
  LSeg: TSegment;
  LIdx: SizeInt;
begin
  Result := False;
  LUpdateGrowthBase := True;

  if aMinSize = 0 then
    Exit(False);

  { Try cache first (Go-style reuse→ready→new) }
  if TryReuseSegment(aMinSize) then
    Exit(True);

  if (FMaxSize <> 0) and (FTotalSize >= FMaxSize) then
    Exit(False);

  if Length(FSegments) = 0 then
    LSegSize := aMinSize
  else
    LSegSize := CalcNextSegmentSize(aMinSize, LUpdateGrowthBase);

  if LSegSize = 0 then
    Exit(False);

  if (FMaxSize <> 0) and (LSegSize > (FMaxSize - FTotalSize)) then
  begin
    if aMinSize > (FMaxSize - FTotalSize) then
      Exit(False);
    LSegSize := FMaxSize - FTotalSize;
  end;

  if FAlignment <= 1 then
    LAllocSize := LSegSize
  else
    LAllocSize := LSegSize + (FAlignment - 1);
  if LAllocSize < LSegSize then
    Exit(False);

  if FAllocator <> nil then
  begin
    LRaw := FAllocator.GetMem(LAllocSize);
    if LRaw = nil then
      Exit(False);
  end
  else
  begin
    GetMem(LRaw, LAllocSize);
    if LRaw = nil then
      Exit(False);
  end;

  LAddr := PtrUInt(LRaw);
  if FAlignment <= 1 then
    LAligned := LAddr
  else
  begin
    LMask := FAlignment - 1;
    if PtrUInt(LMask) > (High(PtrUInt) - LAddr) then
    begin
      if FAllocator <> nil then
        FAllocator.FreeMem(LRaw)
      else
        FreeMem(LRaw);
      Exit(False);
    end;
    LAligned := (LAddr + PtrUInt(LMask)) and not PtrUInt(LMask);
  end;

  if (High(SizeUInt) - FTotalSize) < LSegSize then
  begin
    if FAllocator <> nil then
      FAllocator.FreeMem(LRaw)
    else
      FreeMem(LRaw);
    Exit(False);
  end;

  LSeg.Raw := LRaw;
  LSeg.RawSize := LAllocSize;
  LSeg.Base := PByte(LAligned);
  LSeg.Size := LSegSize;
  LSeg.Used := 0;
  LSeg.StartOffset := FTotalSize;

  LIdx := Length(FSegments);
  SetLength(FSegments, LIdx + 1);
  FSegments[LIdx] := LSeg;
  Inc(FTotalSize, LSegSize);
  if (LIdx = 0) or LUpdateGrowthBase then
    FGrowthBaseSize := LSegSize;
  Result := True;
end;

procedure TChunkedArena.FreeSegment(aIndex: SizeInt);
var
  LRaw: Pointer;
begin
  if (aIndex < 0) or (aIndex > High(FSegments)) then
    Exit;
  LRaw := FSegments[aIndex].Raw;
  FSegments[aIndex].Raw := nil;
  FSegments[aIndex].Base := nil;
  FSegments[aIndex].Size := 0;
  FSegments[aIndex].Used := 0;
  FSegments[aIndex].RawSize := 0;
  if LRaw = nil then
    Exit;
  if FAllocator <> nil then
    FAllocator.FreeMem(LRaw)
  else
    FreeMem(LRaw);
end;

{ CacheSegment - move segment to free list for reuse instead of freeing }

procedure TChunkedArena.CacheSegment(aIndex: SizeInt);
var
  LSeg: TSegment;
begin
  if (aIndex < 0) or (aIndex > High(FSegments)) then
    Exit;
  if FFreeCount >= FCacheLimit then
  begin
    FreeSegment(aIndex);
    Exit;
  end;
  LSeg := FSegments[aIndex];
  if LSeg.Raw = nil then
    Exit;
  { Reset used count for reuse }
  LSeg.Used := 0;
  LSeg.StartOffset := 0;
  if FFreeCount >= Length(FFreeSegments) then
    SetLength(FFreeSegments, FFreeCount + 4);
  FFreeSegments[FFreeCount] := LSeg;
  Inc(FFreeCount);
  { Clear original slot }
  FSegments[aIndex].Raw := nil;
  FSegments[aIndex].Base := nil;
  FSegments[aIndex].Size := 0;
  FSegments[aIndex].Used := 0;
  FSegments[aIndex].RawSize := 0;
end;

{ TryReuseSegment - find a cached segment large enough and reuse it }

function TChunkedArena.TryReuseSegment(aMinSize: SizeUInt): Boolean;
var
  I: SizeInt;
  LSeg: TSegment;
  LIdx: SizeInt;
begin
  Result := False;
  for I := FFreeCount - 1 downto 0 do
  begin
    if FFreeSegments[I].Size >= aMinSize then
    begin
      LSeg := FFreeSegments[I];
      { Remove from cache (swap with last) }
      FFreeSegments[I] := FFreeSegments[FFreeCount - 1];
      Dec(FFreeCount);
      { Add as new active segment }
      LSeg.Used := 0;
      LSeg.StartOffset := FTotalSize;
      LIdx := Length(FSegments);
      SetLength(FSegments, LIdx + 1);
      FSegments[LIdx] := LSeg;
      Inc(FTotalSize, LSeg.Size);
      FActive := LIdx;
      FGrowthBaseSize := LSeg.Size;
      Result := True;
      Exit;
    end;
  end;
end;

{ ClearCache - free all cached segments }

procedure TChunkedArena.ClearCache;
var
  I: SizeInt;
begin
  for I := 0 to FFreeCount - 1 do
  begin
    if FFreeSegments[I].Raw <> nil then
    begin
      if FAllocator <> nil then
        FAllocator.FreeMem(FFreeSegments[I].Raw)
      else
        FreeMem(FFreeSegments[I].Raw);
    end;
    FFreeSegments[I].Raw := nil;
  end;
  FFreeCount := 0;
  SetLength(FFreeSegments, 0);
end;

procedure TChunkedArena.ShrinkToSegmentCount(aCount: SizeInt);
var
  LIdx: SizeInt;
begin
  if aCount < 0 then
    aCount := 0;
  if aCount > Length(FSegments) then
    Exit;

  for LIdx := High(FSegments) downto aCount do
    FreeSegment(LIdx);

  SetLength(FSegments, aCount);
  if aCount = 0 then
  begin
    FTotalSize := 0;
    FActive := -1;
    Exit;
  end;

  FTotalSize := FSegments[High(FSegments)].StartOffset + FSegments[High(FSegments)].Size;
  if FActive > High(FSegments) then
    FActive := High(FSegments);
end;

procedure TChunkedArena.NormalizeState(aActiveIndex: SizeInt; aActiveUsed: SizeUInt);
var
  LIndex: SizeInt;
begin
  if Length(FSegments) = 0 then
  begin
    FActive := -1;
    Exit;
  end;

  if aActiveIndex < 0 then
    aActiveIndex := 0;
  if aActiveIndex > High(FSegments) then
    aActiveIndex := High(FSegments);

  for LIndex := 0 to aActiveIndex - 1 do
    FSegments[LIndex].Used := FSegments[LIndex].Size;

  if aActiveUsed > FSegments[aActiveIndex].Size then
    aActiveUsed := FSegments[aActiveIndex].Size;
  FSegments[aActiveIndex].Used := aActiveUsed;

  if FKeepSegments then
  begin
    for LIndex := aActiveIndex + 1 to High(FSegments) do
      FSegments[LIndex].Used := 0;
  end
  else
    ShrinkToSegmentCount(aActiveIndex + 1);

  FActive := aActiveIndex;
end;

constructor TChunkedArena.Create(const aConfig: TArenaConfig);
var
  LAlign: SizeUInt;
  LInitSize: SizeUInt;
begin
  inherited Create;

  LInitSize := aConfig.InitialSize;
  if LInitSize = 0 then
    raise EAllocError.Create(aeInvalidLayout, 'TChunkedArena: initial size must be > 0');
  if (aConfig.MaxSize <> 0) and (LInitSize > aConfig.MaxSize) then
    raise EAllocError.Create(aeInvalidLayout, 'TChunkedArena: initial size exceeds max size');

  FGrowthKind := aConfig.GrowthKind;
  FGrowthFactor := aConfig.GrowthFactor;
  FGrowthStep := aConfig.GrowthStep;
  if (FGrowthKind = agkLinear) and (FGrowthStep = 0) then
    FGrowthStep := LInitSize;
  if (FGrowthKind = agkGeometric) and (FGrowthFactor < 1.1) then
    FGrowthFactor := 2.0;

  FMaxSize := aConfig.MaxSize;
  FKeepSegments := aConfig.KeepSegments;
  FAllocator := nil;

  LAlign := aConfig.Alignment;
  if LAlign = 0 then
    LAlign := DEFAULT_ALIGNMENT;
  if (LAlign and (LAlign - 1)) <> 0 then
    raise EAllocError.Create(aeAlignmentNotSupported, 'TChunkedArena: alignment must be power of 2');
  if LAlign < MEM_DEFAULT_ALIGN then
    LAlign := MEM_DEFAULT_ALIGN;
  FAlignment := LAlign;

  SetLength(FSegments, 0);
  FActive := -1;
  FTotalSize := 0;
  FGrowthBaseSize := 0;
  FPeakUsed := 0;
  FTotalAllocs := 0;
  FFreeSegments := nil;
  FFreeCount := 0;
  FCacheLimit := CHUNK_CACHE_LIMIT;

  if not AddSegment(LInitSize) then
    raise EOutOfMemory.Create(aeOutOfMemory, 'TChunkedArena: failed to allocate initial segment');
  FActive := 0;
end;

constructor TChunkedArena.Create(aInitialSize: SizeUInt; aMaxSize: SizeUInt);
var
  LConfig: TArenaConfig;
begin
  LConfig := TArenaConfig.Default(aInitialSize);
  LConfig.MaxSize := aMaxSize;
  Create(LConfig);
end;

destructor TChunkedArena.Destroy;
begin
  ClearCache;
  ShrinkToSegmentCount(0);
  inherited Destroy;
end;

function TChunkedArena.Alloc(aSize: SizeUInt): Pointer;
begin
  Result := AllocAligned(aSize, MEM_DEFAULT_ALIGN);
end;

function TChunkedArena.AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
var
  LAlign: SizeUInt;
  LPtr: PByte;
  LSegPtr: PSegment;
  LOffset: SizeUInt;
  LNewUsed: SizeUInt;
  LMinSegSize: SizeUInt;
begin
  Result := nil;
  if aSize = 0 then
    Exit;

  LAlign := aAlignment;
  if LAlign = 0 then
    LAlign := MEM_DEFAULT_ALIGN;
  if (LAlign < MEM_DEFAULT_ALIGN) or ((LAlign and (LAlign - 1)) <> 0) then
    Exit;

  if not CalcRequiredMinSize(aSize, LAlign, LMinSegSize) then
    Exit;

  if (FActive < 0) or (FActive > High(FSegments)) then
    Exit;

  while True do
  begin
    LSegPtr := @FSegments[FActive];

    LPtr := AlignPtr(LSegPtr^.Base + LSegPtr^.Used, LAlign);
    if LPtr = nil then
      Exit;
    LOffset := SizeUInt(PtrUInt(LPtr) - PtrUInt(LSegPtr^.Base));

    if (LOffset <= LSegPtr^.Size) and (aSize <= (LSegPtr^.Size - LOffset)) then
    begin
      LNewUsed := LOffset + aSize;
      LSegPtr^.Used := LNewUsed;
      Inc(FTotalAllocs);
      if CurrentUsed > FPeakUsed then
        FPeakUsed := CurrentUsed;
      Exit(LPtr);
    end;

    LSegPtr^.Used := LSegPtr^.Size;
    if FActive < High(FSegments) then
    begin
      Inc(FActive);
      Continue;
    end;

    if not AddSegment(LMinSegSize) then
      Exit;
    Inc(FActive);
  end;
end;

function TChunkedArena.AllocZeroed(aSize: SizeUInt): Pointer;
begin
  Result := Alloc(aSize);
  if Result <> nil then
    FillChar(Result^, aSize, 0);
end;

function TChunkedArena.SaveMark: TArenaMark;
begin
  Result.FrontOffset := CurrentUsed;
  Result.BackOffset := 0;
  Result.TotalUsed := CurrentUsed;
end;

procedure TChunkedArena.RestoreToMark(aMark: TArenaMark);
var
  LMark: SizeUInt;
  LActiveIdx: SizeInt;
  LEnd: SizeUInt;
  LSegOffset: SizeUInt;
  LLeft: SizeInt;
  LRight: SizeInt;
  LMid: SizeInt;
begin
  LMark := SizeUInt(aMark.FrontOffset);
  if LMark > FTotalSize then
    raise EAllocError.Create(aeInvalidLayout, 'TChunkedArena.RestoreToMark: marker out of range');

  if Length(FSegments) = 0 then
    Exit;

  LLeft := 0;
  LRight := High(FSegments);
  while LLeft < LRight do
  begin
    LMid := (LLeft + LRight) shr 1;
    LEnd := FSegments[LMid].StartOffset + FSegments[LMid].Size;
    if LMark <= LEnd then
      LRight := LMid
    else
      LLeft := LMid + 1;
  end;

  LActiveIdx := LLeft;
  LSegOffset := LMark - FSegments[LActiveIdx].StartOffset;
  if (LSegOffset = FSegments[LActiveIdx].Size) and (LActiveIdx < High(FSegments)) then
  begin
    Inc(LActiveIdx);
    LSegOffset := 0;
  end;
  NormalizeState(LActiveIdx, LSegOffset);
end;

procedure TChunkedArena.Reset;
var
  LIdx: SizeInt;
begin
  if Length(FSegments) = 0 then
    Exit;

  if not FKeepSegments then
  begin
    { Cache all segments except the first for reuse }
    for LIdx := High(FSegments) downto 1 do
      CacheSegment(LIdx);
    SetLength(FSegments, 1);
    FSegments[0].Used := 0;
    FSegments[0].StartOffset := 0;
    FTotalSize := FSegments[0].Size;
    FActive := 0;
    Exit;
  end;

  for LIdx := 0 to High(FSegments) do
    FSegments[LIdx].Used := 0;
  FActive := 0;
end;

function TChunkedArena.UsedSize: SizeUInt;
begin
  Result := CurrentUsed;
end;

function TChunkedArena.RemainingSize: SizeUInt;
var
  LUsed: SizeUInt;
begin
  LUsed := CurrentUsed;
  if LUsed >= FTotalSize then
    Exit(0);
  Result := FTotalSize - LUsed;
end;

function TChunkedArena.Stats: TArenaStats;
begin
  Result.TotalAllocated := FTotalSize;
  Result.TotalUsed := CurrentUsed;
  Result.PeakUsed := FPeakUsed;
  Result.AllocCount := SizeUInt(FTotalAllocs);
end;

function TChunkedArena.SegmentCount: SizeUInt;
begin
  Result := SizeUInt(Length(FSegments));
end;

{$POP}

end.
