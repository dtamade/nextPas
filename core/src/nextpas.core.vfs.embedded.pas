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
  AOwnsBlob=False：调用方保活缓冲（const 段/静态数据场景，INV-V6）。 }
function CreateEmbeddedVfs(AData: PByte; ASize: SizeUInt;
  AOwnsBlob: Boolean): IVfs;

implementation

uses
  nextpas.core.base.utils,
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
    procedure CheckOpen;
    procedure Reinit(ABase: PByte; const AOffset, ASize: Int64);
  public
    constructor Create(ABase: PByte; const AOffset, ASize: Int64);
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
    FKeep 强引 Owner，保证切片窗口期内 blob 不悬垂 }
  TEmbeddedSliceStream = class(TInterfacedObject, IStream, IReaderAt)
  private
    FSlice: TEmbeddedSlice;
    FOwner: TEmbeddedVfs; { weak —仅用于归还 }
    FKeep: IVfs;          { strong—保活 }
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

  TEmbeddedVfs = class(TInterfacedObject, IVfs, IVfsETag)
  private
    FRp: TResPack;
    FData: PByte;
    FSize: SizeUInt;
    FOwnsBlob: Boolean;
    FPaths: TVfsNameArray; { cached sorted file paths — O(1) reuse, avoids per-call EntryPaths alloc }
    FETags: array of string; { parallel ETag cache — precomputed at Create, O(1) ServeVfs }
    FLastMods: array of string; { parallel Last-Modified cache — FormatHttpDate at Create }
    FEntries: array of TResPackEntry; { parallel entry cache — zero DecodeWire on Stat/OpenRead }
    FPool: array[0..15] of TEmbeddedSlice; { 16-slot SpinLock 池，零分配复用 }
    FPoolCount: Integer;
    FPoolLock: ISpinLock;
    function EntryPaths: TVfsNameArray; inline;
    function LowerBoundPath(const APath: string): SizeInt; inline;
    function HasSubtreePath(const APath: string): Boolean;
    function IndexOfPath(const APath: string): SizeInt;
    function TryPopPool(out ASlice: TEmbeddedSlice): Boolean;
    function TryPushPool(ASlice: TEmbeddedSlice): Boolean;
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
  end;

function CreateEmbeddedVfs(AData: PByte; ASize: SizeUInt;
  AOwnsBlob: Boolean): IVfs;
begin
  Result := TEmbeddedVfs.Create(AData, ASize, AOwnsBlob);
end;

{ ── TEmbeddedSlice ── }

constructor TEmbeddedSlice.Create(ABase: PByte; const AOffset, ASize: Int64);
begin
  inherited Create;
  FBase := ABase;
  FOffset := AOffset;
  FSize := ASize;
  FPos := 0;
  FOpen := True;
end;

procedure TEmbeddedSlice.Reinit(ABase: PByte; const AOffset, ASize: Int64);
begin
  FBase := ABase;
  FOffset := AOffset;
  FSize := ASize;
  FPos := 0;
  FOpen := True;
end;

procedure TEmbeddedSlice.CheckOpen;
begin
  if not FOpen then
    raise EVfsClosed.CreateCtx('read', '', 'stream already closed');
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
  raise EVfsError.CreateCtx('write', '', 'stream is read-only');
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
  LKeep := FKeep;
  LOwner := FOwner;
  LSlice := FSlice;
  FSlice := nil;
  FOwner := nil;
  FKeep := nil;
  if (LSlice <> nil) and (LOwner <> nil) then
  begin
    if not LOwner.TryPushPool(LSlice) then
      LSlice.Free;
  end
  else if LSlice <> nil then
    LSlice.Free;
  LKeep := nil;
  inherited Destroy;
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

{ ── TEmbeddedVfs ── }

constructor TEmbeddedVfs.Create(AData: PByte; ASize: SizeUInt;
  AOwnsBlob: Boolean);
var
  I: SizeUInt;
  E: TResPackEntry;
begin
  inherited Create;
  FRp := TResPack.Open(AData, ASize);   { 校验失败 EResPackCorrupted 原样透传 }
  FData := AData;
  FSize := ASize;
  FOwnsBlob := AOwnsBlob;
  FPoolLock := SpinLock;
  FPoolCount := 0;
  { Materialize sorted path index + parallel caches once — O(n) upfront, O(1) per ServeVfs/Stat/OpenRead.
    FEntries avoids per-request DecodeWire + respack binary search. }
  SetLength(FPaths, FRp.Count);
  SetLength(FETags, FRp.Count);
  SetLength(FLastMods, FRp.Count);
  SetLength(FEntries, FRp.Count);
  if FRp.Count > 0 then
    for I := 0 to FRp.Count - 1 do
    begin
      E := FRp.EntryAt(I);
      FPaths[I] := FRp.PathOf(E);
      FEntries[I] := E;
      if (E.Flags and RESPACK_EFLAG_HASHED) <> 0 then
        FETags[I] := VfsETagFNV(E.Hash)
      else
        FETags[I] := VfsETagStrong(E.Size, E.ModTime);
      if E.ModTime > 0 then
        FLastMods[I] := nextpas.core.time.httpdate.FormatHttpDate(E.ModTime)
      else
        FLastMods[I] := '';
    end;
end;

destructor TEmbeddedVfs.Destroy;
var
  I: Integer;
begin
  if FPoolCount > 0 then
  begin
    for I := 0 to FPoolCount - 1 do
      FPool[I].Free;
    FPoolCount := 0;
  end;
  FPoolLock := nil;
  SetLength(FEntries, 0);
  SetLength(FLastMods, 0);
  SetLength(FETags, 0);
  SetLength(FPaths, 0);
  if FOwnsBlob and (FData <> nil) then
    FreeMem(FData);
  FData := nil;
  inherited Destroy;
end;

function TEmbeddedVfs.TryPopPool(out ASlice: TEmbeddedSlice): Boolean;
begin
  Result := False;
  ASlice := nil;
  if (FPoolLock = nil) or (FPoolCount = 0) then Exit;
  FPoolLock.Acquire;
  try
    if FPoolCount > 0 then
    begin
      Dec(FPoolCount);
      ASlice := FPool[FPoolCount];
      FPool[FPoolCount] := nil;
      Result := True;
    end;
  finally
    FPoolLock.Release;
  end;
end;

function TEmbeddedVfs.TryPushPool(ASlice: TEmbeddedSlice): Boolean;
begin
  Result := False;
  if (FPoolLock = nil) or (ASlice = nil) then Exit;
  FPoolLock.Acquire;
  try
    if FPoolCount < Length(FPool) then
    begin
      FPool[FPoolCount] := ASlice;
      Inc(FPoolCount);
      Result := True;
    end;
  finally
    FPoolLock.Release;
  end;
end;

function TEmbeddedVfs.EntryPaths: TVfsNameArray;
begin
  Result := FPaths; { zero-alloc reuse — caller must not mutate }
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
var
  Lo, Hi, Mid: SizeInt;
  C: Integer;
begin
  Lo := 0;
  Hi := Length(FPaths);
  while Lo < Hi do
  begin
    Mid := (Lo + Hi) shr 1;
    C := CompareBytesOrdered(Pointer(PChar(FPaths[Mid])), Pointer(PChar(APath)),
      SizeUInt(Length(FPaths[Mid])), SizeUInt(Length(APath)));
    if C < 0 then
      Lo := Mid + 1
    else
      Hi := Mid;
  end;
  Result := Lo;
end;

function TEmbeddedVfs.HasSubtreePath(const APath: string): Boolean;
var
  Lo: SizeInt;
  QLen: Integer;
begin
  { 子目录存在性：零分配——以 LowerBound 直达首个 ≥ APath 项，再判 '/' 前缀
    复用统一 LowerBoundPath，消除与 IndexOfPath 的二分重复 }
  Result := False;
  if Length(FPaths) = 0 then
    Exit;
  QLen := Length(APath);
  Lo := LowerBoundPath(APath);
  if Lo >= Length(FPaths) then Exit;
  if Length(FPaths[Lo]) <= QLen then Exit;
  if FPaths[Lo][QLen + 1] <> '/' then Exit;
  if QLen > 0 then
    if not CompareMem(@FPaths[Lo][1], @APath[1], SizeUInt(QLen)) then Exit;
  Result := True;
end;

function TEmbeddedVfs.IndexOfPath(const APath: string): SizeInt;
var
  Lo: SizeInt;
begin
  Lo := LowerBoundPath(APath);
  if (Lo < Length(FPaths))
    and (CompareBytesOrdered(Pointer(PChar(FPaths[Lo])), Pointer(PChar(APath)),
      SizeUInt(Length(FPaths[Lo])), SizeUInt(Length(APath))) = 0) then
    Exit(Lo);
  Result := -1;
end;

function TEmbeddedVfs.TryGetETag(const APath: string; out AETag: string): Boolean;
var
  Idx: SizeInt;
begin
  Idx := IndexOfPath(APath);
  if Idx >= 0 then
  begin
    AETag := FETags[Idx];
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
    ALastModified := FLastMods[Idx];
    Exit(True);
  end;
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
  I: SizeUInt;
begin
  if not VfsValidPath(ADirPath, True) then
    raise EVfsInvalidPath.CreateCtx('list', ADirPath, 'invalid virtual path');
  if not VfsIsRoot(ADirPath) then
  begin
    { 目录存在性：是文件则 NotADirectory，两者皆非则 NotFound }
    SI := Stat(ADirPath);
    if not SI.Info.IsDir then
      raise EVfsNotADirectory.CreateCtx('list', ADirPath, 'target is a file');
  end;
  if VfsIsRoot(ADirPath) then
    Prefix := ''
  else
    Prefix := ADirPath + '/';

  Seen := VfsDeriveChildNames(EntryPaths, Prefix);

  Result := nil;
  SetLength(Result, SizeUInt(Length(Seen)));
  if SizeUInt(Length(Seen)) > 0 then
    for I := 0 to SizeUInt(Length(Seen)) - 1 do
    begin
      { 零 Stat 直填：Seen 已是规范名，省 ValidPath + Stat 二次封装
        以 IndexOfPath 直命中 FEntries；未命中即为虚拟目录 }
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
    Slice.Reinit(FData, Int64(E.DataOffset), Int64(E.Size))
  else
    Slice := TEmbeddedSlice.Create(FData, Int64(E.DataOffset), Int64(E.Size));
  Keep := Self as IVfs;
  Result := TEmbeddedSliceStream.Create(Slice, Self, Keep);
end;

function TEmbeddedVfs.CaseSensitive: Boolean;
begin
  Result := True;
end;

end.
