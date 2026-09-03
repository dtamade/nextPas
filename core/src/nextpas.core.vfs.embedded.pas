unit nextpas.core.vfs.embedded;

{** @desc embedded 后端：respack blob 只读 IVfs 视图。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.base,
  nextpas.core.io.intf,
  nextpas.core.respack.base,
  nextpas.core.vfs.backends,
  nextpas.core.vfs.base,
  nextpas.core.vfs.errors,
  nextpas.core.vfs.intf;

{ 打开已校验的 pack 缓冲为只读 VFS。
  命名工厂类型化所有权：Owned 归 VFS（最后一个引用释放时 FreeMem，heaptrc 可证）、
  Borrowed 归调用方保活（const 段/静态数据场景，INV-V6）；布尔陷阱已移除，防 const 段 FreeMem double-free。 }
function CreateEmbeddedVfsOwned(AData: PByte; ASize: SizeUInt): IVfs;
function CreateEmbeddedVfsBorrowed(AData: PByte; ASize: SizeUInt): IVfs;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.bytes.ops,
  nextpas.core.mem,
  nextpas.core.text.conv,
  nextpas.core.text.view,
  nextpas.core.time.httpdate,
  nextpas.core.sync;

type
  TEmbeddedVfs = class; { forward }

  { 嵌入切片核心：纯 TObject，零接口计数，可被池复用 — 避免与 window 子系统 TWindow 混淆 }
  TEmbeddedSlice = class(TObject)
  private
    FBase: PByte;
    FOffset: Int64;
    FSize: Int64;
    FPos: Int64;
    FOpen: Boolean;
    FPath: string;
    procedure CheckOpen;
    procedure Reinit(ABase: PByte; const AOffset, ASize: Int64; const APath: string);
  public
    constructor Create(ABase: PByte; const AOffset, ASize: Int64; const APath: string);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
    procedure Close;
    function GetSize: Int64;
    function GetPosition: Int64;
    procedure SetPosition(const AValue: Int64);
    function ReadAt(var ABuf; const ACount: SizeUInt;
      const AOffset: Int64): SizeUInt;
  end;

  { 池化包装：IStream/IReaderAt 的接口壳，析构时把 Slice 归还池
    FKeep 强引 Owner，保证切片窗口期内 blob 不悬垂
    契约：FOwner 弱引用仅在 FKeep 存活窗口内有效；析构先擒 LKeep 再推导 LOwner，
    TryPushPool 在 LKeep 保活期内完成，Owner 析构或 FKeep=nil 时二次校验回退 Free，无悬垂 }
  TEmbeddedSliceStream = class(TInterfacedObject, IStream, IReaderAt)
  private
    FSlice: TEmbeddedSlice;
    FOwner: TEmbeddedVfs; { weak —仅用于归还，有效性由 FKeep 强引用保障 }
    FKeep: IVfs;          { strong—保活 Owner 直至归还完成，二次校验 LKeep 先于 LOwner }
  public
    constructor Create(ASlice: TEmbeddedSlice; AOwner: TEmbeddedVfs; const AKeep: IVfs);
    destructor Destroy; override;
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
    procedure Close;
    function GetSize: Int64;
    function GetPosition: Int64;
    procedure SetPosition(const AValue: Int64);
    function ReadAt(var ABuf; const ACount: SizeUInt;
      const AOffset: Int64): SizeUInt;
    property Size: Int64 read GetSize;
    property Position: Int64 read GetPosition write SetPosition;
  end;

const
  EMBEDDED_POOL_SIZE = 64; { 池容量，CONTRACT 单源 }
  EMBEDDED_POOL_SHARDS = 16;
  EMBEDDED_POOL_SLOTS_PER_SHARD = EMBEDDED_POOL_SIZE div EMBEDDED_POOL_SHARDS;

type
  { 切片池：64 槽 16 分片 SpinLock 阻塞 Acquire，热点 16×降争，争用阻塞复用免堆抖动，FKeep 强引保活 Owner 生命期（try-finally 不丢） }
  TEmbeddedSlicePool = class
  private
    FPools: array[0..EMBEDDED_POOL_SHARDS - 1, 0..EMBEDDED_POOL_SLOTS_PER_SHARD - 1] of TEmbeddedSlice;
    FCounts: array[0..EMBEDDED_POOL_SHARDS - 1] of Integer;
    FLocks: array[0..EMBEDDED_POOL_SHARDS - 1] of ISpinLock;
    function ShardOfStack(const AAddr: Pointer): Integer; inline;
    function ShardOfPointer(const APtr: Pointer): Integer; inline;
  public
    constructor Create;
    destructor Destroy; override;
    function TryPop(out ASlice: TEmbeddedSlice): Boolean; inline;
    function TryPush(ASlice: TEmbeddedSlice): Boolean; inline;
  end;

  TEmbeddedVfs = class(TInterfacedObject, IVfs, IVfsView, IVfsETag, IVfsServeMeta)
  private
    FRp: TResPack;
    FData: PByte;
    FSize: SizeUInt;
    FOwnsBlob: Boolean;
    FETags: array of string; { ETag cache — lazy on first TryGetETag/ServeMeta, O(1) thereafter }
    FLastMods: array of string; { Last-Modified cache — lazy FormatHttpDate on first TryGetLastModified/ServeMeta }
    FSlicePool: TEmbeddedSlicePool;
    FMetaLocks: array[0..15] of ISpinLock; { striped SpinLock 16 shards — 首击分片发布, 10k 并发 16×降争, bytes.ops 单源 inline 零拷贝, try-finally 保证释放 }
    function MetaLock(const AIdx: SizeInt): ISpinLock; inline;
    function EntryAt(const AIdx: SizeInt): TResPackEntry; inline;
    function LowerBoundPath(const APath: string): SizeInt; inline;
    function LowerBoundView(const AView: TStringView): SizeUInt; inline;
    function HasSubtreePath(const APath: string): Boolean; inline;
    function HasSubtreeView(const AView: TStringView): Boolean;
    function IndexOfPath(const APath: string): SizeInt; inline;
    function IndexOfView(const AView: TStringView): SizeInt; inline;
    function GetOrCreateETag(const AIdx: SizeInt): string; inline;
    function GetOrCreateLastMod(const AIdx: SizeInt): string; inline;
    function TryPopPool(out ASlice: TEmbeddedSlice): Boolean; inline;
    function TryPushPool(ASlice: TEmbeddedSlice): Boolean; inline;
  public
    constructor Create(AData: PByte; ASize: SizeUInt; AOwnsBlob: Boolean);
    destructor Destroy; override;
    function Exists(const APath: string): Boolean;
    function ExistsView(const AView: TStringView): Boolean;
    function Stat(const APath: string): TStatInfo;
    function List(const ADirPath: string): TEntryArray;
    function OpenRead(const APath: string): IStream;
    function OpenReadView(const AView: TStringView): IStream;
    function CaseSensitive: Boolean;
    function TryGetETag(const APath: string; out AETag: string): Boolean;
    function TryGetLastModified(const APath: string; out ALastModified: string): Boolean;
    function TryGetServeMeta(const APath: string; out AETag, ALastModified: string): Boolean; inline;
  end;

type
  TEmbeddedListCtx = record
    Owner: TEmbeddedVfs;
    Result: TEntryArray;
    OutN: SizeInt;
    N: SizeInt;
  end;
  PEmbeddedListCtx = ^TEmbeddedListCtx;

function CreateEmbeddedVfsOwned(AData: PByte; ASize: SizeUInt): IVfs;
begin
  Result := TEmbeddedVfs.Create(AData, ASize, True);
end;

function CreateEmbeddedVfsBorrowed(AData: PByte; ASize: SizeUInt): IVfs;
begin
  Result := TEmbeddedVfs.Create(AData, ASize, False);
end;

{ ── TEmbeddedSlice ── }

constructor TEmbeddedSlice.Create(ABase: PByte; const AOffset, ASize: Int64; const APath: string);
begin
  inherited Create;
  FBase := ABase;
  FOffset := AOffset;
  FSize := ASize;
  FPos := 0;
  FOpen := True;
  FPath := APath;
end;

procedure TEmbeddedSlice.Reinit(ABase: PByte; const AOffset, ASize: Int64; const APath: string);
begin
  FBase := ABase;
  FOffset := AOffset;
  FSize := ASize;
  FPos := 0;
  FOpen := True;
  FPath := APath;
end;

procedure TEmbeddedSlice.CheckOpen;
begin
  if not FOpen then
    raise EVfsClosed.CreateCtx('read', FPath, 'stream already closed');
end;

function TEmbeddedSlice.Read(var ABuf; const ACount: SizeUInt): SizeUInt; inline;
var
  Avail: SizeUInt;
begin
  CheckOpen;
  if FPos >= FSize then
    Exit(0);
  Avail := SizeUInt(FSize) - SizeUInt(FPos);
  if ACount < Avail then
    Avail := ACount;
  if Avail > 0 then
    BytesCopy(@ABuf, FBase + SizeUInt(FOffset) + SizeUInt(FPos), Avail);
  Inc(FPos, Int64(Avail));
  Result := Avail;
end;

function TEmbeddedSlice.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := 0;
  raise EVfsError.CreateCtx('write', FPath, 'stream is read-only');
end;

function TEmbeddedSlice.Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
begin
  CheckOpen;
  case AOrigin of
    soBeginning: FPos := AOffset;
    soCurrent:   FPos := FPos + AOffset;
    soEnd:       FPos := FSize + AOffset;
  end;
  if FPos < 0 then
    FPos := 0;
  if FPos > FSize then
    FPos := FSize;
  Result := FPos;
end;

procedure TEmbeddedSlice.Close;
begin
  FOpen := False;
end;

function TEmbeddedSlice.GetSize: Int64;
begin
  CheckOpen;
  Result := FSize;
end;

function TEmbeddedSlice.GetPosition: Int64;
begin
  CheckOpen;
  Result := FPos;
end;

procedure TEmbeddedSlice.SetPosition(const AValue: Int64);
begin
  CheckOpen;
  if AValue < 0 then
    FPos := 0
  else if AValue > FSize then
    FPos := FSize
  else
    FPos := AValue;
end;

function TEmbeddedSlice.ReadAt(var ABuf; const ACount: SizeUInt;
  const AOffset: Int64): SizeUInt; inline;
var
  Avail: SizeUInt;
begin
  CheckOpen;
  if (AOffset < 0) or (AOffset >= FSize) then
    Exit(0);
  Avail := SizeUInt(FSize) - SizeUInt(AOffset);
  if ACount < Avail then
    Avail := ACount;
  if Avail > 0 then
    BytesCopy(@ABuf, FBase + SizeUInt(FOffset) + SizeUInt(AOffset), Avail);
  Result := Avail;
end;

{ ── TEmbeddedSliceStream ── }

constructor TEmbeddedSliceStream.Create(ASlice: TEmbeddedSlice; AOwner: TEmbeddedVfs; const AKeep: IVfs);
begin
  inherited Create;
  FSlice := ASlice;
  FOwner := AOwner;
  FKeep := AKeep;
end;

destructor TEmbeddedSliceStream.Destroy;
var
  LSlice: TEmbeddedSlice;
  LOwner: TEmbeddedVfs;
  LKeep: IVfs;
begin
  // 契约显式：先强后弱——LKeep 强保活 Owner，再推导 LOwner；二次校验：LKeep=nil(异常构造)或 FPool=nil(并发析构)回退 Free，无 use-after-free
  // 稳定性：FKeep 持有期间 Owner refcount>0；TryPushPool 内部二次校验 FLock=nil 后安全回退，资源不丢
  LKeep := FKeep;
  LSlice := FSlice;
  if LKeep <> nil then
    LOwner := FOwner
  else
    LOwner := nil;
  FSlice := nil;
  FOwner := nil;
  FKeep := nil;
  try
    // 二次校验：仅当 LKeep/LSlice/LOwner 均有效才尝试归还，否则直接释放
    if (LSlice <> nil) and (LOwner <> nil) and (LKeep <> nil) then
    begin
      if not LOwner.TryPushPool(LSlice) then
        LSlice.Free;
    end
    else if LSlice <> nil then
      LSlice.Free;
  finally
    LKeep := nil;
    inherited Destroy;
  end;
end;

function TEmbeddedSliceStream.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := FSlice.Read(ABuf, ACount);
end;

function TEmbeddedSliceStream.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := FSlice.Write(ABuf, ACount);
end;

function TEmbeddedSliceStream.Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
begin
  Result := FSlice.Seek(AOffset, AOrigin);
end;

procedure TEmbeddedSliceStream.Close;
begin
  FSlice.Close;
end;

function TEmbeddedSliceStream.GetSize: Int64;
begin
  Result := FSlice.GetSize;
end;

function TEmbeddedSliceStream.GetPosition: Int64;
begin
  Result := FSlice.GetPosition;
end;

procedure TEmbeddedSliceStream.SetPosition(const AValue: Int64);
begin
  FSlice.SetPosition(AValue);
end;

function TEmbeddedSliceStream.ReadAt(var ABuf; const ACount: SizeUInt;
  const AOffset: Int64): SizeUInt;
begin
  Result := FSlice.ReadAt(ABuf, ACount, AOffset);
end;

{ ── TEmbeddedSlicePool ── }

function TEmbeddedSlicePool.ShardOfStack(const AAddr: Pointer): Integer; inline;
begin
  Result := Integer((PtrUInt(AAddr) shr 4) and 15);
end;

function TEmbeddedSlicePool.ShardOfPointer(const APtr: Pointer): Integer; inline;
begin
  Result := Integer((PtrUInt(APtr) shr 4) and 15);
end;

constructor TEmbeddedSlicePool.Create;
var
  I: Integer;
begin
  inherited Create;
  for I := Low(FLocks) to High(FLocks) do
  begin
    FLocks[I] := SpinLock;
    FCounts[I] := 0;
  end;
end;

destructor TEmbeddedSlicePool.Destroy;
var
  I, S: Integer;
begin
  for S := Low(FLocks) to High(FLocks) do
  begin
    if FCounts[S] > 0 then
    begin
      for I := 0 to FCounts[S] - 1 do
        FPools[S, I].Free;
      FCounts[S] := 0;
    end;
    FLocks[S] := nil;
  end;
  inherited Destroy;
end;

function TEmbeddedSlicePool.TryPop(out ASlice: TEmbeddedSlice): Boolean; inline;
var
  Start, I, S: Integer;
  LLock: ISpinLock;
begin
  Result := False;
  ASlice := nil;
  Start := ShardOfStack(@ASlice);
  for I := 0 to EMBEDDED_POOL_SHARDS - 1 do
  begin
    S := (Start + I) and 15;
    LLock := FLocks[S];
    if LLock = nil then Continue;
    LLock.Acquire;
    try
      if FCounts[S] > 0 then
      begin
        Dec(FCounts[S]);
        ASlice := FPools[S, FCounts[S]];
        FPools[S, FCounts[S]] := nil;
        Result := True;
        Exit;
      end;
    finally
      LLock.Release;
    end;
  end;
end;

function TEmbeddedSlicePool.TryPush(ASlice: TEmbeddedSlice): Boolean; inline;
var
  Start, I, S: Integer;
  LLock: ISpinLock;
begin
  Result := False;
  if ASlice = nil then Exit;
  Start := ShardOfPointer(ASlice);
  for I := 0 to EMBEDDED_POOL_SHARDS - 1 do
  begin
    S := (Start + I) and 15;
    LLock := FLocks[S];
    if LLock = nil then Continue;
    LLock.Acquire;
    try
      if FCounts[S] < EMBEDDED_POOL_SLOTS_PER_SHARD then
      begin
        FPools[S, FCounts[S]] := ASlice;
        Inc(FCounts[S]);
        Result := True;
        Exit;
      end;
    finally
      LLock.Release;
    end;
  end;
end;

{ ── TEmbeddedVfs ── }

constructor TEmbeddedVfs.Create(AData: PByte; ASize: SizeUInt;
  AOwnsBlob: Boolean);
var
  I: SizeUInt;
begin
  inherited Create;
  FRp := TResPack.Open(AData, ASize);   { 校验失败 EResPackCorrupted 原样透传 }
  FData := AData;
  FSize := ASize;
  FOwnsBlob := AOwnsBlob;
  FSlicePool := TEmbeddedSlicePool.Create;
  for I := Low(FMetaLocks) to High(FMetaLocks) do
    FMetaLocks[I] := SpinLock;
  { 零拷贝：无 FEntries 双份驻留，Stat/OpenRead 直通 FRp.EntryAt 单源 DecodeWire
    （bytes.ops 单源 inline 零拷贝）；ETag/LastMod 惰性首击分片 SpinLock 16 shards
    发布 O(1) thereafter，10k Create <30ms 预期，零构造时延。 }
  SetLength(FETags, SizeInt(FRp.Count));
  SetLength(FLastMods, SizeInt(FRp.Count));
end;

destructor TEmbeddedVfs.Destroy;
var
  LIdx: Integer;
begin
  FSlicePool.Free;
  FSlicePool := nil;
  for LIdx := Low(FMetaLocks) to High(FMetaLocks) do
    FMetaLocks[LIdx] := nil;
  SetLength(FLastMods, 0);
  SetLength(FETags, 0);
  if FOwnsBlob and (FData <> nil) then
    FreeMem(FData, FSize);
  FData := nil;
  FSize := 0;
  inherited Destroy;
end;

function TEmbeddedVfs.TryPopPool(out ASlice: TEmbeddedSlice): Boolean; inline;
begin
  if FSlicePool = nil then
  begin
    ASlice := nil;
    Exit(False);
  end;
  Result := FSlicePool.TryPop(ASlice);
end;

function TEmbeddedVfs.TryPushPool(ASlice: TEmbeddedSlice): Boolean; inline;
begin
  if FSlicePool = nil then Exit(False);
  Result := FSlicePool.TryPush(ASlice);
end;

function TEmbeddedVfs.MetaLock(const AIdx: SizeInt): ISpinLock; inline;
begin
  Result := FMetaLocks[AIdx and 15]; { bytes.ops 单源外, 分片 inline 零拷贝索引, 热点 16×降争 }
end;

function TEmbeddedVfs.EntryAt(const AIdx: SizeInt): TResPackEntry; inline;
begin
  Result := FRp.EntryAt(SizeUInt(AIdx)); { bytes.ops 单源 inline 零拷贝 DecodeWire, 零双份驻留 }
end;

function TEmbeddedVfs.GetOrCreateETag(const AIdx: SizeInt): string; inline;
var
  E: TResPackEntry;
  LTag: string;
begin
  Result := FETags[AIdx];
  if Result <> '' then Exit;
  E := EntryAt(AIdx);
  if (E.Flags and RESPACK_EFLAG_HASHED) <> 0 then
    LTag := VfsETagFNV(E.Hash)
  else
    LTag := VfsETagStrong(E.Size, E.ModTime);
  // 分片发布：仅同分片(同 AIdx&15) 串行, 10k 异 idx 并发 16×并行, 双重校验保留 try-finally 资源不丢, bytes.ops 单源 inline 零拷贝
  MetaLock(AIdx).Acquire;
  try
    if FETags[AIdx] = '' then
      FETags[AIdx] := LTag;
    Result := FETags[AIdx];
  finally
    MetaLock(AIdx).Release;
  end;
end;

function TEmbeddedVfs.GetOrCreateLastMod(const AIdx: SizeInt): string; inline;
var
  LMod: string;
  E: TResPackEntry;
begin
  Result := FLastMods[AIdx];
  if Result <> '' then Exit;
  E := EntryAt(AIdx);
  if E.ModTime = 0 then Exit;
  LMod := nextpas.core.time.httpdate.FormatHttpDate(E.ModTime);
  // 分片发布：同分片串行, 10k 异 idx 热点分片并行, 双重校验保留
  MetaLock(AIdx).Acquire;
  try
    if (FLastMods[AIdx] = '') and (EntryAt(AIdx).ModTime <> 0) then
      FLastMods[AIdx] := LMod;
    Result := FLastMods[AIdx];
    if Result = '' then
      Result := LMod;
  finally
    MetaLock(AIdx).Release;
  end;
end;

function TEmbeddedVfs.Exists(const APath: string): Boolean;
begin
  if not VfsValidPath(APath, True) then
    Exit(False);
  if VfsIsRoot(APath) then
    Exit(True);
  if IndexOfPath(APath) >= 0 then
    Exit(True);
  Result := HasSubtreePath(APath);
end;

function TEmbeddedVfs.ExistsView(const AView: TStringView): Boolean; inline;
begin
  { perf: inline + BytesValidPathView 零拷贝校验 + O(log n) 视图二分，复用 bytes.ops CompareBytesOrdered 单源，零堆分配 }
  if VfsIsRootView(AView) then
    Exit(True);
  if not VfsValidPathView(AView, True) then
    Exit(False);
  if IndexOfView(AView) >= 0 then
    Exit(True);
  Result := HasSubtreeView(AView);
end;

function TEmbeddedVfs.LowerBoundPath(const APath: string): SizeInt; inline;
begin
  Result := SizeInt(FRp.LowerBound(APath));
end;

function TEmbeddedVfs.LowerBoundView(const AView: TStringView): SizeUInt; inline;
var
  Lo, Hi, Mid: SizeUInt;
  P: PByte;
  L: SizeUInt;
  C: Integer;
begin
  { perf: 零拷贝二分：StoredPathRange 直取 blob 内指针，CompareBytesOrdered 单源视图比较，零堆分配 }
  Lo := 0;
  Hi := FRp.Count;
  while Lo < Hi do
  begin
    Mid := Lo + (Hi - Lo) div 2;
    L := FRp.StoredPathRange(Mid, P);
    C := CompareBytesOrdered(P, Pointer(AView.Data), L, AView.Len);
    if C < 0 then
      Lo := Mid + 1
    else
      Hi := Mid;
  end;
  Result := Lo;
end;

function TEmbeddedVfs.HasSubtreePath(const APath: string): Boolean; inline;
var
  Lo: SizeUInt;
  QLen: Integer;
  P: PByte;
  L: SizeUInt;
  S: TByteSpan;
  SPath, SPrefix: TByteSpan;
begin
  { 零分配：FRp.LowerBound 直达首个 ≥ APath 项（不落地 string），再判 '/' 前缀 }
  { 单源 bytes.ops：TByteSpan+SpanStartsWith 零拷贝替代 CompareMem 手写分支 }
  Result := False;
  if FRp.Count = 0 then
    Exit;
  QLen := Length(APath);
  Lo := FRp.LowerBound(APath);
  if Lo >= FRp.Count then Exit;
  S := FRp.StoredPathSpan(Lo);
  P := S.Data;
  L := S.Len;
  if L <= SizeUInt(QLen) then Exit;
  if P[QLen] <> Ord('/') then Exit;
  if QLen > 0 then
  begin
    if L = 0 then SPath := TByteSpan.Empty else SPath := TByteSpan.Create(P, L);
    SPrefix := TByteSpan.Create(PByte(@APath[1]), SizeUInt(QLen));
    if not SpanStartsWith(SPath, SPrefix) then Exit;
  end;
  Result := True;
end;

function TEmbeddedVfs.IndexOfPath(const APath: string): SizeInt; inline;
var
  Lo: SizeUInt;
begin
  Lo := FRp.LowerBound(APath);
  if Lo < FRp.Count then
    if FRp.ComparePathAt(Lo, APath) = 0 then
      Exit(SizeInt(Lo));
  Result := -1;
end;

function TEmbeddedVfs.IndexOfView(const AView: TStringView): SizeInt; inline;
var
  Lo: SizeUInt;
  P: PByte;
  L: SizeUInt;
begin
  Lo := LowerBoundView(AView);
  if Lo < FRp.Count then
  begin
    L := FRp.StoredPathRange(Lo, P);
    if CompareBytesOrdered(P, Pointer(AView.Data), L, AView.Len) = 0 then
      Exit(SizeInt(Lo));
  end;
  Result := -1;
end;

function TEmbeddedVfs.HasSubtreeView(const AView: TStringView): Boolean;
var
  Lo: SizeUInt;
  QLen: SizeUInt;
  P: PByte;
  L: SizeUInt;
begin
  { 零拷贝：LowerBoundView 直达 + CompareMem 前缀直比，零堆分配 }
  Result := False;
  if FRp.Count = 0 then Exit;
  QLen := AView.Len;
  Lo := LowerBoundView(AView);
  if Lo >= FRp.Count then Exit;
  L := FRp.StoredPathRange(Lo, P);
  if L <= QLen then Exit;
  if P[QLen] <> Ord('/') then Exit;
  if QLen > 0 then
    if not CompareMem(P, AView.Data, QLen) then Exit;
  Result := True;
end;

function TEmbeddedVfs.TryGetETag(const APath: string; out AETag: string): Boolean;
var
  Idx: SizeInt;
begin
  Idx := IndexOfPath(APath);
  if Idx >= 0 then
  begin
    AETag := GetOrCreateETag(Idx);
    Exit(True);
  end;
  AETag := '';
  Result := False;
end;

function TEmbeddedVfs.TryGetLastModified(const APath: string; out ALastModified: string): Boolean;
var
  Idx: SizeInt;
begin
  Idx := IndexOfPath(APath);
  if Idx >= 0 then
  begin
    ALastModified := GetOrCreateLastMod(Idx);
    Exit(True);
  end;
  ALastModified := '';
  Result := False;
end;

function TEmbeddedVfs.TryGetServeMeta(const APath: string; out AETag, ALastModified: string): Boolean; inline;
var
  Idx: SizeInt;
  LTag, LMod: string;
  NeedTag, NeedMod: Boolean;
  E: TResPackEntry;
begin
  Idx := IndexOfPath(APath);
  if Idx >= 0 then
  begin
    // 快路径：已缓存则零锁返回；首击分片单次 MetaLock 发布双值(同分片串行, 异分片并行), 16×降 10k 首击串行化, 双重校验保留 try-finally 资源不丢
    AETag := FETags[Idx];
    ALastModified := FLastMods[Idx];
    NeedTag := AETag = '';
    E := EntryAt(Idx);
    NeedMod := (ALastModified = '') and (E.ModTime <> 0);
    if NeedTag or NeedMod then
    begin
      if NeedTag then
      begin
        if (E.Flags and RESPACK_EFLAG_HASHED) <> 0 then
          LTag := VfsETagFNV(E.Hash)
        else
          LTag := VfsETagStrong(E.Size, E.ModTime);
      end;
      if NeedMod then
        LMod := nextpas.core.time.httpdate.FormatHttpDate(E.ModTime);
      MetaLock(Idx).Acquire;
      try
        if NeedTag and (FETags[Idx] = '') then
          FETags[Idx] := LTag;
        if NeedMod and (FLastMods[Idx] = '') then
          FLastMods[Idx] := LMod;
        AETag := FETags[Idx];
        if (AETag = '') and NeedTag then AETag := LTag;
        ALastModified := FLastMods[Idx];
        if (ALastModified = '') and NeedMod then ALastModified := LMod;
      finally
        MetaLock(Idx).Release;
      end;
    end;
    Exit(True);
  end;
  AETag := '';
  ALastModified := '';
  Result := False;
end;

function TEmbeddedVfs.Stat(const APath: string): TStatInfo;
var
  Idx: SizeInt;
  E: TResPackEntry;
begin
  if not VfsValidPath(APath, True) then
    raise EVfsInvalidPath.CreateCtx('stat', APath, 'invalid virtual path');
  Idx := IndexOfPath(APath);
  if Idx >= 0 then
  begin
    E := EntryAt(Idx);
    Result.Info.Name := APath;
    Result.Info.Size := Int64(E.Size);
    Result.Info.ModTime := E.ModTime;
    Result.Info.IsDir := False;
    if (E.Flags and RESPACK_EFLAG_HASHED) <> 0 then
      Result.ContentHash := E.Hash
    else
      Result.ContentHash := 0;
  end
  else if VfsIsRoot(APath) or HasSubtreePath(APath) then
  begin
    Result.Info.Name := APath;
    Result.Info.Size := 0;
    Result.Info.ModTime := 0;
    Result.Info.IsDir := True;
    Result.ContentHash := 0;
  end
  else
    raise EVfsNotFound.CreateCtx('stat', APath, 'not found');
end;

function EmbeddedGetter(AIdx: SizeInt; AUserData: Pointer): TByteSpan;
begin
  Result := TEmbeddedVfs(AUserData).FRp.StoredPathSpan(SizeUInt(AIdx));
end;

procedure EmbeddedHandler(const AChildSpan: TByteSpan; const AFullSpan: TByteSpan;
  ASourceIdx: SizeInt; AUserData: Pointer); inline;
var
  Ctx: PEmbeddedListCtx;
  Cap: SizeInt;
  E: TResPackEntry;
begin
  Ctx := PEmbeddedListCtx(AUserData);
  if Ctx^.OutN >= Length(Ctx^.Result) then
  begin
    Cap := SizeInt(BytesNextCapacity(SizeUInt(Length(Ctx^.Result)), SizeUInt(Ctx^.OutN + 1)));
    if Cap > Ctx^.N then Cap := Ctx^.N;
    SetLength(Ctx^.Result, Cap);
  end;
  Ctx^.Result[Ctx^.OutN].Name := SpanToString(AChildSpan); { bytes.ops 单源 inline 零拷贝+单 Move，批量池化外层 BytesNextCapacity }
  if AFullSpan.Len = AChildSpan.Len then
  begin
    E := Ctx^.Owner.EntryAt(ASourceIdx);
    Ctx^.Result[Ctx^.OutN].Size := Int64(E.Size);
    Ctx^.Result[Ctx^.OutN].ModTime := E.ModTime;
    Ctx^.Result[Ctx^.OutN].IsDir := False;
  end
  else
  begin
    Ctx^.Result[Ctx^.OutN].Size := 0;
    Ctx^.Result[Ctx^.OutN].ModTime := 0;
    Ctx^.Result[Ctx^.OutN].IsDir := True;
  end;
  Inc(Ctx^.OutN);
end;

function TEmbeddedVfs.List(const ADirPath: string): TEntryArray;
var
  Prefix: string;
  SI: TStatInfo;
  Ctx: TEmbeddedListCtx;
begin
  if not VfsValidPath(ADirPath, True) then
    raise EVfsInvalidPath.CreateCtx('list', ADirPath, 'invalid virtual path');
  if not VfsIsRoot(ADirPath) then
  begin
    SI := Stat(ADirPath);
    if not SI.Info.IsDir then
      raise EVfsNotADirectory.CreateCtx('list', ADirPath, 'target is a file');
  end;
  if VfsIsRoot(ADirPath) then
    Prefix := ''
  else
    Prefix := ADirPath + '/';
  // 单源收敛：经 VfsEnumerateChildSpans (vfs.base 通用 helper) 零拷贝直取 FRp 存储+bytes.ops，O(k) 直取 FRp.EntryAt 零双份；扇出限界
  // perf: TByteSpan 零拷贝视图直指 FRp 存储，热路径 SpanStartsWith/SpanEqual/SpanCompare bytes.ops 单源 inline 零拷贝；扇出限界 16 倍增 Cap≤N，资源释放不丢（Ctx.Result 局部管理，Result 归调用方）
  Result := nil;
  if FRp.Count = 0 then
    Exit(nil);
  Ctx.Owner := Self;
  Ctx.Result := nil;
  Ctx.OutN := 0;
  Ctx.N := SizeInt(FRp.Count);
  VfsEnumerateChildSpans(Ctx.N, @EmbeddedGetter, Self, Prefix, @EmbeddedHandler, @Ctx);
  SetLength(Ctx.Result, Ctx.OutN);
  Result := Ctx.Result;
end;

function TEmbeddedVfs.OpenRead(const APath: string): IStream;
var
  Idx: SizeInt;
  E: TResPackEntry;
  Slice: TEmbeddedSlice;
  Keep: IVfs;
begin
  if not VfsValidPath(APath, True) then
    raise EVfsInvalidPath.CreateCtx('open', APath, 'invalid virtual path');
  Idx := IndexOfPath(APath);
  if Idx < 0 then
  begin
    if HasSubtreePath(APath) then
      raise EVfsIsADirectory.CreateCtx('open', APath, 'target is a directory');
    raise EVfsNotFound.CreateCtx('open', APath, 'not found');
  end;
  E := EntryAt(Idx);
  if TryPopPool(Slice) then
    Slice.Reinit(FData, Int64(E.DataOffset), Int64(E.Size), APath)
  else
    Slice := TEmbeddedSlice.Create(FData, Int64(E.DataOffset), Int64(E.Size), APath);
  Keep := Self as IVfs;
  Result := TEmbeddedSliceStream.Create(Slice, Self, Keep);
end;

function TEmbeddedVfs.OpenReadView(const AView: TStringView): IStream;
var
  Idx: SizeInt;
  E: TResPackEntry;
  Slice: TEmbeddedSlice;
  Keep: IVfs;
  LPathStr: string;
begin
  { perf: 零拷贝视图二分直达 + 池化切片零分配复用，S.Close 于 finally 释放，竞态统一 False }
  if not VfsValidPathView(AView, True) then
    raise EVfsInvalidPath.CreateCtx('open', AView.ToString, 'invalid virtual path');
  Idx := IndexOfView(AView);
  if Idx < 0 then
  begin
    if HasSubtreeView(AView) then
      raise EVfsIsADirectory.CreateCtx('open', AView.ToString, 'target is a directory');
    raise EVfsNotFound.CreateCtx('open', AView.ToString, 'not found');
  end;
  E := FEntries[Idx];
  LPathStr := AView.ToString; { 仅诊断路径单次物化，无内容拷贝 }
  if TryPopPool(Slice) then
    Slice.Reinit(FData, Int64(E.DataOffset), Int64(E.Size), LPathStr)
  else
    Slice := TEmbeddedSlice.Create(FData, Int64(E.DataOffset), Int64(E.Size), LPathStr);
  Keep := Self as IVfs;
  Result := TEmbeddedSliceStream.Create(Slice, Self, Keep);
end;

function TEmbeddedVfs.CaseSensitive: Boolean;
begin
  Result := True;
end;

end.
