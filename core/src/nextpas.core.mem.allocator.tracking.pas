unit nextpas.core.mem.allocator.tracking;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.error,
  nextpas.core.mem.intf,
  nextpas.core.mem.mutex;

type
  {** TTrackingAllocator
   *
   *  包装任意 IAllocator，记录所有分配/释放操作，
   *  用于测试时检测内存泄漏。
   *
   *  线程安全（内部用 TMemMutex 保护记录表）。
   *  仅用于测试/诊断场景，不建议在生产热路径使用。
   *
   *  内部使用 open-addressing hash map (MulHash64 + 线性探测)
   *  实现 O(1) 平均查找/插入/删除。
   *}
  TTrackingAllocator = class(TInterfacedObject, IAllocator)
  private
    FInner: IAllocator;
    FLock: TMemMutex;
    FNextAllocId: QWord;
    FCurrentTag: string;
    { Open-addressing hash map: Ptr → (Size, AllocId, Tag) }
    FKeys: array of PtrUInt;     { 0 = empty, 1 = tombstone }
    FSizes: array of SizeUInt;
    FAllocIds: array of QWord;
    FTags: array of string;
    FMask: SizeUInt;
    FHighShift: SizeUInt;
    FCount: SizeUInt;            { live entries }
    FFill: SizeUInt;             { live + tombstones }
    FTotalBytes: SizeUInt;       { sum of live sizes }
    procedure MapInit(aMinCapacity: SizeUInt);
    procedure MapClear;
    procedure MapGrow;
    function MapLookup(aKey: PtrUInt; out aSize: SizeUInt; out aAllocId: QWord; out aTag: string): Boolean;
    procedure MapInsert(aKey: PtrUInt; aSize: SizeUInt; aAllocId: QWord; const aTag: string);
    function MapDelete(aKey: PtrUInt; out aSize: SizeUInt; out aAllocId: QWord; out aTag: string): Boolean;
  public
    constructor Create(aInner: IAllocator);
    destructor Destroy; override;

    function GetMem(ASize: SizeUInt): Pointer; inline;
    function AllocMem(ASize: SizeUInt): Pointer; inline;
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
    procedure FreeMem(APtr: Pointer); inline;

    {** 设置当前分配标签（后续分配将使用此标签） }
    procedure SetTag(const ATag: string);
    {** 当前活跃分配数 }
    function ActiveAllocCount: SizeInt;
    {** 当前活跃分配字节 }
    function ActiveAllocBytes: SizeUInt;
    {** 是否有泄漏 }
    function HasLeaks: Boolean;
    {** 生成泄漏报告（包含每个未释放块的地址、大小和标签） }
    function ReportLeaks: string;
    {** 将所有仍存活的被追踪块归还底层分配器并清空账本——供作用域级
        追踪器（如 RunTestWithLeakCheck）在收尾时以干净堆退出；验证类
        API（HasLeaks/ReportLeaks）应在本调用之前取数。显式方法而非
        Destroy 自动释放：共享/可重建链场景下自动释放有双重释放风险 }
    procedure ReleaseTracked;
    {** 内部分配器 }
    property Inner: IAllocator read FInner;

    function Traits: TAllocatorTraits; inline;
  end;

implementation

uses
  nextpas.core.exception,
  nextpas.core.mem.utils;

const
  TRACK_MAP_MIN_CAP = 64;
  TRACK_TOMBSTONE = PtrUInt(1);

{ TTrackingAllocator }

constructor TTrackingAllocator.Create(aInner: IAllocator);
begin
  inherited Create;
  if aInner = nil then
    raise EArgumentNil.Create('TTrackingAllocator.Create: aInner cannot be nil');
  FInner := aInner;
  FNextAllocId := 1;
  FCurrentTag := '';
  FLock.Init;
  MapInit(TRACK_MAP_MIN_CAP);
end;

destructor TTrackingAllocator.Destroy;
begin
  FLock.Done;
  MapClear;
  FInner := nil;
  inherited Destroy;
end;

{ --- Hash map internals --- }

procedure TTrackingAllocator.MapInit(aMinCapacity: SizeUInt);
var
  LCap: SizeUInt;
  LIdx: SizeUInt;
begin
  LCap := TRACK_MAP_MIN_CAP;
  while LCap < aMinCapacity do
    LCap := LCap shl 1;
  SetLength(FKeys, LCap);
  SetLength(FSizes, LCap);
  SetLength(FAllocIds, LCap);
  SetLength(FTags, LCap);
  for LIdx := 0 to LCap - 1 do
  begin
    FKeys[LIdx] := 0;
    FSizes[LIdx] := 0;
    FAllocIds[LIdx] := 0;
    FTags[LIdx] := '';
  end;
  FMask := LCap - 1;
  FHighShift := SizeUInt(64 - Log2UInt(LCap));
  FCount := 0;
  FFill := 0;
  FTotalBytes := 0;
end;

procedure TTrackingAllocator.MapClear;
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
  end;
  FCount := 0;
  FFill := 0;
  FTotalBytes := 0;
end;

procedure TTrackingAllocator.MapGrow;
var
  LOldKeys: array of PtrUInt;
  LOldSizes: array of SizeUInt;
  LOldAllocIds: array of QWord;
  LOldTags: array of string;
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

  SetLength(FKeys, LOldCap shl 1);
  SetLength(FSizes, LOldCap shl 1);
  SetLength(FAllocIds, LOldCap shl 1);
  SetLength(FTags, LOldCap shl 1);
  FMask := (LOldCap shl 1) - 1;
  FHighShift := SizeUInt(64 - Log2UInt(FMask + 1));

  for LIdx := 0 to FMask do
  begin
    FKeys[LIdx] := 0;
    FSizes[LIdx] := 0;
    FAllocIds[LIdx] := 0;
    FTags[LIdx] := '';
  end;
  FCount := 0;
  FFill := 0;
  FTotalBytes := 0;

  for LIdx := 0 to LOldCap - 1 do
  begin
    LKey := LOldKeys[LIdx];
    if (LKey <> 0) and (LKey <> TRACK_TOMBSTONE) then
    begin
      LHash := MulHash64(LKey);
      LPos := (LHash shr FHighShift) and FMask;
      while FKeys[LPos] <> 0 do
        LPos := (LPos + 1) and FMask;
      FKeys[LPos] := LKey;
      FSizes[LPos] := LOldSizes[LIdx];
      FAllocIds[LPos] := LOldAllocIds[LIdx];
      FTags[LPos] := LOldTags[LIdx];
      Inc(FCount);
      Inc(FFill);
      Inc(FTotalBytes, LOldSizes[LIdx]);
    end;
  end;
end;

function TTrackingAllocator.MapLookup(aKey: PtrUInt; out aSize: SizeUInt; out aAllocId: QWord; out aTag: string): Boolean;
var
  LPos: SizeUInt;
  LHash: QWord;
begin
  Result := False;
  aSize := 0;
  aAllocId := 0;
  aTag := '';
  if (aKey = 0) or (aKey = TRACK_TOMBSTONE) then Exit(False);
  if Length(FKeys) = 0 then Exit(False);
  LHash := MulHash64(aKey);
  LPos := (LHash shr FHighShift) and FMask;
  while True do
  begin
    if FKeys[LPos] = 0 then Exit(False);
    if FKeys[LPos] = aKey then
    begin
      aSize := FSizes[LPos];
      aAllocId := FAllocIds[LPos];
      aTag := FTags[LPos];
      Exit(True);
    end;
    LPos := (LPos + 1) and FMask;
  end;
end;

procedure TTrackingAllocator.MapInsert(aKey: PtrUInt; aSize: SizeUInt; aAllocId: QWord; const aTag: string);
var
  LPos: SizeUInt;
  LHash: QWord;
  LTomb: SizeUInt;
begin
  if (aKey = 0) or (aKey = TRACK_TOMBSTONE) then Exit;
  { Grow if load factor > 50% (including tombstones) }
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
      { Replace existing (should be rare) }
      if FSizes[LPos] <= FTotalBytes then
        Dec(FTotalBytes, FSizes[LPos])
      else
        FTotalBytes := 0;
      FSizes[LPos] := aSize;
      FAllocIds[LPos] := aAllocId;
      FTags[LPos] := aTag;
      Inc(FTotalBytes, aSize);
      Exit;
    end;
    if (LTomb = High(SizeUInt)) and (FKeys[LPos] = TRACK_TOMBSTONE) then
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
  Inc(FCount);
  Inc(FTotalBytes, aSize);
end;

function TTrackingAllocator.MapDelete(aKey: PtrUInt; out aSize: SizeUInt; out aAllocId: QWord; out aTag: string): Boolean;
var
  LPos: SizeUInt;
  LHash: QWord;
begin
  aSize := 0;
  aAllocId := 0;
  aTag := '';
  Result := False;
  if (aKey = 0) or (aKey = TRACK_TOMBSTONE) then Exit;
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
      FKeys[LPos] := TRACK_TOMBSTONE;
      FSizes[LPos] := 0;
      FAllocIds[LPos] := 0;
      FTags[LPos] := '';
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

function TTrackingAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := FInner.GetMem(ASize);
  if Result <> nil then
  begin
    FLock.Acquire;
    try
      MapInsert(PtrUInt(Result), ASize, FNextAllocId, FCurrentTag);
      Inc(FNextAllocId);
    finally
      FLock.Release;
    end;
  end;
end;

function TTrackingAllocator.AllocMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := FInner.AllocMem(ASize);
  if Result <> nil then
  begin
    FLock.Acquire;
    try
      MapInsert(PtrUInt(Result), ASize, FNextAllocId, FCurrentTag);
      Inc(FNextAllocId);
    finally
      FLock.Release;
    end;
  end;
end;

function TTrackingAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
var
  LOldSize: SizeUInt;
  LOldAllocId: QWord;
  LOldTag: string;
  LHasOld: Boolean;
begin
  if ASize = 0 then begin FreeMem(APtr); Exit(nil); end;
  if APtr = nil then Exit(GetMem(ASize));
  Result := FInner.ReallocMem(APtr, ASize);
  FLock.Acquire;
  try
    if Result <> nil then
    begin
      LHasOld := MapLookup(PtrUInt(APtr), LOldSize, LOldAllocId, LOldTag);
      if not LHasOld then
      begin
        MapInsert(PtrUInt(Result), ASize, FNextAllocId, FCurrentTag);
        Inc(FNextAllocId);
      end
      else
      begin
        MapDelete(PtrUInt(APtr), LOldSize, LOldAllocId, LOldTag);
        try
          MapInsert(PtrUInt(Result), ASize, LOldAllocId, LOldTag);
        except
          MapInsert(PtrUInt(APtr), LOldSize, LOldAllocId, LOldTag);
          raise;
        end;
      end;
    end;
  finally
    FLock.Release;
  end;
end;

procedure TTrackingAllocator.FreeMem(APtr: Pointer); inline;
var
  LSize: SizeUInt;
  LAllocId: QWord;
  LTag: string;
begin
  if APtr = nil then
    Exit;
  FLock.Acquire;
  try
    if not MapDelete(PtrUInt(APtr), LSize, LAllocId, LTag) then
      raise EDoubleFree.Create(aeDoubleFree,
      FormatAllocErrorMsg('TTrackingAllocator', 'FreeMem', 'pointer not tracked (double-free or foreign pointer)'));
    try
      FInner.FreeMem(APtr);
    except
      { Restore tracking record so double-free detection still works. }
      MapInsert(PtrUInt(APtr), LSize, LAllocId, LTag);
      raise;
    end;
  finally
    FLock.Release;
  end;
end;

function TTrackingAllocator.ActiveAllocCount: SizeInt;
begin
  FLock.Acquire;
  try
    Result := SizeInt(FCount);
  finally
    FLock.Release;
  end;
end;

function TTrackingAllocator.ActiveAllocBytes: SizeUInt;
begin
  FLock.Acquire;
  try
    Result := FTotalBytes;
  finally
    FLock.Release;
  end;
end;

function TTrackingAllocator.HasLeaks: Boolean;
begin
  Result := ActiveAllocCount > 0;
end;

function PtrToHexString(AValue: PtrUInt): string;
const
  HexDigits: array[0..15] of AnsiChar = '0123456789ABCDEF';
var
  LBuf: array[0..SizeOf(Pointer) * 2 - 1] of AnsiChar;
  LIdx: Integer;
begin
  for LIdx := High(LBuf) downto 0 do
  begin
    LBuf[LIdx] := HexDigits[AValue and $F];
    AValue := AValue shr 4;
  end;
  SetString(Result, PAnsiChar(@LBuf[0]), Length(LBuf));
end;

function TTrackingAllocator.ReportLeaks: string;
var
  LIdx: SizeUInt;
  LLine: string;
  LCountStr: string;
begin
  FLock.Acquire;
  try
    if FCount = 0 then
      Exit('No leaks detected.');
    Str(FCount, LCountStr);
    Result := 'Leak report: ' + LCountStr + ' block(s) not freed:' + #10;
    for LIdx := 0 to FMask do
    begin
      if (FKeys[LIdx] <> 0) and (FKeys[LIdx] <> TRACK_TOMBSTONE) then
      begin
        Str(FAllocIds[LIdx], LLine);
        Result := Result + '  [' + LLine + '] $';
        Result := Result + PtrToHexString(FKeys[LIdx]);
        Str(FSizes[LIdx], LLine);
        Result := Result + ' size=' + LLine;
        if FTags[LIdx] <> '' then
          Result := Result + ' tag=' + FTags[LIdx];
        Result := Result + #10;
      end;
    end;
  finally
    FLock.Release;
  end;
end;

procedure TTrackingAllocator.SetTag(const ATag: string);
begin
  FCurrentTag := ATag;
end;

procedure TTrackingAllocator.ReleaseTracked;
var
  LIdx: SizeUInt;
  LFirstEx: Exception;
  LCurEx: Exception;
begin
  LFirstEx := nil;
  FLock.Acquire;
  try
    try
      for LIdx := 0 to FMask do
      begin
        if (FKeys[LIdx] <> 0) and (FKeys[LIdx] <> TRACK_TOMBSTONE) then
        try
          FInner.FreeMem(Pointer(FKeys[LIdx]));
        except
          LCurEx := Exception(AcquireExceptionObject);
          if LFirstEx = nil then
            LFirstEx := LCurEx
          else
            LCurEx.Free;
        end;
      end;
    finally
      MapClear;
    end;
    if LFirstEx <> nil then
      raise LFirstEx;
  finally
    FLock.Release;
  end;
end;

function TTrackingAllocator.Traits: TAllocatorTraits; inline;
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
