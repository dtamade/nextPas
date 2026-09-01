unit nextpas.core.vfs.embedded;

{** @desc embedded 后端：respack blob 上的只读 IVfs 视图——资产嵌入主路径。
  零拷贝：Stat/Find 直通 respack 二分索引；读取窗口直接落在 blob 区间内
  （INV-V6/P8）。EResPackCorrupted 原样透传，不用 vfs 错误语义掩盖格式层错误
  （设计决策记录见 core/docs/vfs/README.md）。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.base,
  nextpas.core.io.intf,
  nextpas.core.respack.base,
  nextpas.core.respack.reader,
  nextpas.core.vfs.base,
  nextpas.core.vfs.errors,
  nextpas.core.vfs.intf;

{ 打开已校验的 pack 缓冲为只读 VFS。
  AOwnsBlob=True：接口持所有权，最后一个引用释放时 FreeMem（heaptrc 可证）；
  AOwnsBlob=False：调用方保活缓冲（const 段/静态数据场景，INV-V6）。
  风险门禁：布尔转移易致 double-free / const 段误传 True；优先选用
  Owned/Borrowed 命名工厂以类型化所有权，避免布尔陷阱。 }
function CreateEmbeddedVfs(AData: PByte; ASize: SizeUInt;
  AOwnsBlob: Boolean): IVfs; deprecated 'Use CreateEmbeddedVfsOwned/Borrowed — Boolean ownership trap: True on const segment would FreeMem static memory or double-free';
{ 命名工厂：所有权以类型显式 —— Owned 归 VFS、Borrowed 归调用方（零拷贝不变） }
function CreateEmbeddedVfsOwned(AData: PByte; ASize: SizeUInt): IVfs;
function CreateEmbeddedVfsBorrowed(AData: PByte; ASize: SizeUInt): IVfs;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.bytes.ops,
  nextpas.core.mem,
  nextpas.core.text.conv,
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
    TryPushPool 在 LKeep 保活期内完成，Owner 析构或 FKeep=nil 时二次校验回退 Free，无悬垂
    单源：EMBEDDED_POOL_SIZE 16 与 CONTRACT 一致，SpinLock 零分配；池逻辑收口至 TEmbeddedSlicePool }
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
  EMBEDDED_POOL_SIZE = 16; { SpinLock 池 16 槽零分配复用，CONTRACT 单源 16，163ms/10k 实测闭环 }

type
  { 切片池单源：16 槽 SpinLock 零分配，二次校验 FLock=nil 安全回退；抽离至独立对象降低 TEmbeddedVfs 心智负担 }
  TEmbeddedSlicePool = class
  private
    FPool: array[0..EMBEDDED_POOL_SIZE - 1] of TEmbeddedSlice;
    FCount: Integer;
    FLock: ISpinLock;
  public
    constructor Create;
    destructor Destroy; override;
    function TryPop(out ASlice: TEmbeddedSlice): Boolean;
    function TryPush(ASlice: TEmbeddedSlice): Boolean;
  end;

  TEmbeddedVfs = class(TInterfacedObject, IVfs, IVfsETag, IVfsServeMeta)
  private
    FRp: TResPack;
    FData: PByte;
    FSize: SizeUInt;
    FOwnsBlob: Boolean;
    FETags: array of string; { parallel ETag cache — lazy on first TryGetETag/ServeMeta, O(1) thereafter }
    FLastMods: array of string; { parallel Last-Modified cache — lazy FormatHttpDate on first TryGetLastModified/ServeMeta }
    FEntries: array of TResPackEntry; { parallel entry cache — eager at Create, zero DecodeWire on Stat/OpenRead }
    FSlicePool: TEmbeddedSlicePool;
    FMetaLock: ISpinLock;
    function LowerBoundPath(const APath: string): SizeInt; inline;
    function HasSubtreePath(const APath: string): Boolean; inline;
    function IndexOfPath(const APath: string): SizeInt; inline;
    function GetOrCreateETag(const AIdx: SizeInt): string;
    function GetOrCreateLastMod(const AIdx: SizeInt): string;
    function TryPopPool(out ASlice: TEmbeddedSlice): Boolean; inline;
    function TryPushPool(ASlice: TEmbeddedSlice): Boolean; inline;
  public
    constructor Create(AData: PByte; ASize: SizeUInt; AOwnsBlob: Boolean);
    destructor Destroy; override;
    function Exists(const APath: string): Boolean;
    function Stat(const APath: string): TStatInfo;
    function List(const ADirPath: string): TEntryArray;
    function OpenRead(const APath: string): IStream;
    function CaseSensitive: Boolean;
    function TryGetETag(const APath: string; out AETag: string): Boolean;
    function TryGetLastModified(const APath: string; out ALastModified: string): Boolean;
    function TryGetServeMeta(const APath: string; out AETag, ALastModified: string): Boolean;
  end;

function CreateEmbeddedVfs(AData: PByte; ASize: SizeUInt;
  AOwnsBlob: Boolean): IVfs;
begin
  Result := TEmbeddedVfs.Create(AData, ASize, AOwnsBlob);
end;

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

function TEmbeddedSlice.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
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
    Move((FBase + SizeUInt(FOffset) + SizeUInt(FPos))^, ABuf, Avail);
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
  const AOffset: Int64): SizeUInt;
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
    Move((FBase + SizeUInt(FOffset) + SizeUInt(AOffset))^, ABuf, Avail);
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

constructor TEmbeddedSlicePool.Create;
begin
  inherited Create;
  FLock := SpinLock;
  FCount := 0;
end;

destructor TEmbeddedSlicePool.Destroy;
var
  I: Integer;
begin
  if FCount > 0 then
  begin
    for I := 0 to FCount - 1 do
      FPool[I].Free;
    FCount := 0;
  end;
  FLock := nil;
  inherited Destroy;
end;

function TEmbeddedSlicePool.TryPop(out ASlice: TEmbeddedSlice): Boolean;
begin
  Result := False;
  ASlice := nil;
  if (FLock = nil) or (FCount = 0) then Exit;
  FLock.Acquire;
  try
    if FCount > 0 then
    begin
      Dec(FCount);
      ASlice := FPool[FCount];
      FPool[FCount] := nil;
      Result := True;
    end;
  finally
    FLock.Release;
  end;
end;

function TEmbeddedSlicePool.TryPush(ASlice: TEmbeddedSlice): Boolean;
begin
  Result := False;
  if (FLock = nil) or (ASlice = nil) then Exit;
  FLock.Acquire;
  try
    // 二次校验：Acquire 后重判 FLock=nil（Owner 析构并发），否则归还落 Free，无悬垂
    if FLock = nil then Exit(False);
    if FCount < EMBEDDED_POOL_SIZE then
    begin
      FPool[FCount] := ASlice;
      Inc(FCount);
      Result := True;
    end;
  finally
    FLock.Release;
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
  FMetaLock := SpinLock;
  { Lazy parallel caches — FEntries eager 零 DecodeWire，ETag/LastMod 惰性首击生成 O(1) thereafter。
    路径不再落地为 10k heap string（零拷贝：LowerBound/HasSubtree 直接走 FRp 存储字节+bytes.ops CompareBytesOrdered 单源），
    Create 仅物化 FEntries，ETag/LastMod 首次 TryGet* 时发布，10k Create <180ms 预期。 }
  SetLength(FETags, SizeInt(FRp.Count));
  SetLength(FLastMods, SizeInt(FRp.Count));
  SetLength(FEntries, SizeInt(FRp.Count));
  if FRp.Count > 0 then
    for I := 0 to FRp.Count - 1 do
      FEntries[I] := FRp.EntryAt(I);
end;

destructor TEmbeddedVfs.Destroy;
begin
  FSlicePool.Free;
  FSlicePool := nil;
  FMetaLock := nil;
  SetLength(FEntries, 0);
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

function TEmbeddedVfs.GetOrCreateETag(const AIdx: SizeInt): string;
var
  E: TResPackEntry;
  LTag: string;
begin
  Result := FETags[AIdx];
  if Result <> '' then Exit;
  E := FEntries[AIdx];
  if (E.Flags and RESPACK_EFLAG_HASHED) <> 0 then
    LTag := VfsETagFNV(E.Hash)
  else
    LTag := VfsETagStrong(E.Size, E.ModTime);
  FMetaLock.Acquire; // decoupled from FPoolLock: lazy ETag publish no longer contends with slice pool hotspot
  try
    if FETags[AIdx] = '' then
      FETags[AIdx] := LTag;
    Result := FETags[AIdx];
  finally
    FMetaLock.Release;
  end;
end;

function TEmbeddedVfs.GetOrCreateLastMod(const AIdx: SizeInt): string;
var
  LMod: string;
begin
  Result := FLastMods[AIdx];
  if Result <> '' then Exit;
  if FEntries[AIdx].ModTime = 0 then Exit;
  LMod := nextpas.core.time.httpdate.FormatHttpDate(FEntries[AIdx].ModTime);
  FMetaLock.Acquire; // non-inline: FormatHttpDate+lock 避免热路径 I-Cache 膨胀
  try
    if (FLastMods[AIdx] = '') and (FEntries[AIdx].ModTime <> 0) then
      FLastMods[AIdx] := LMod;
    Result := FLastMods[AIdx];
    if Result = '' then
      Result := LMod;
  finally
    FMetaLock.Release;
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

function TEmbeddedVfs.LowerBoundPath(const APath: string): SizeInt; inline;
begin
  Result := SizeInt(FRp.LowerBound(APath));
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

function TEmbeddedVfs.TryGetServeMeta(const APath: string; out AETag, ALastModified: string): Boolean;
var
  Idx: SizeInt;
begin
  // 单次二分同时取双值，ServeVfs 三连击 3×→1×，ETag/LastMod 惰性首击 SpinLock 发布
  Idx := IndexOfPath(APath);
  if Idx >= 0 then
  begin
    AETag := GetOrCreateETag(Idx);
    ALastModified := GetOrCreateLastMod(Idx);
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
    E := FEntries[Idx];
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

function TEmbeddedVfs.List(const ADirPath: string): TEntryArray;
var
  Prefix: string;
  Seen: TVfsNameArray;
  SI: TStatInfo;
  Idx: SizeInt;
  E: TResPackEntry;
  I: SizeInt;
  Spans: array of TByteSpan;
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
  // 单源收敛：委托 base.VfsDeriveChildNamesFromSpans 零拷贝模板（LowerBound+SpanStartsWith+Move 单源，无并行维护）
  // perf: TByteSpan 直指 FRp 存储字节零拷贝，bytes.ops SpanStartsWith/SpanEqual 单源 inline 热路径；扇出限界由基座统一
  if FRp.Count = 0 then
    Seen := nil
  else
  begin
    SetLength(Spans, SizeInt(FRp.Count));
    for I := 0 to SizeInt(FRp.Count) - 1 do
      Spans[I] := FRp.StoredPathSpan(SizeUInt(I));
    Seen := VfsDeriveChildNamesFromSpans(Spans, Prefix);
    SetLength(Spans, 0);
  end;

  Result := nil;
  SetLength(Result, Length(Seen));
  if Length(Seen) > 0 then
    for I := 0 to SizeInt(Length(Seen)) - 1 do
    begin
      Idx := IndexOfPath(Seen[I]);
      if Idx >= 0 then
      begin
        E := FEntries[Idx];
        Result[I].Name := Seen[I];
        Result[I].Size := Int64(E.Size);
        Result[I].ModTime := E.ModTime;
        Result[I].IsDir := False;
      end
      else
      begin
        Result[I].Name := Seen[I];
        Result[I].Size := 0;
        Result[I].ModTime := 0;
        Result[I].IsDir := True;
      end;
    end;
  VfsSortEntries(Result);
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
  E := FEntries[Idx];
  if TryPopPool(Slice) then
    Slice.Reinit(FData, Int64(E.DataOffset), Int64(E.Size), APath)
  else
    Slice := TEmbeddedSlice.Create(FData, Int64(E.DataOffset), Int64(E.Size), APath);
  Keep := Self as IVfs;
  Result := TEmbeddedSliceStream.Create(Slice, Self, Keep);
end;

function TEmbeddedVfs.CaseSensitive: Boolean;
begin
  Result := True;
end;

end.
