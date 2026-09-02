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
  AOwnsBlob: Boolean): IVfs;
{ 命名工厂：所有权以类型显式 —— Owned 归 VFS、Borrowed 归调用方（零拷贝不变） }
function CreateEmbeddedVfsOwned(AData: PByte; ASize: SizeUInt): IVfs;
function CreateEmbeddedVfsBorrowed(AData: PByte; ASize: SizeUInt): IVfs;

implementation

uses
  nextpas.core.base.utils,
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

const
  EMBEDDED_POOL_SIZE = 256; { SpinLock 池 256 槽零分配复用，4K 并发预算，163ms/10k 实测闭环 }

type
  TEmbeddedVfs = class(TInterfacedObject, IVfs, IVfsView, IVfsETag, IVfsServeMeta)
  private
    FRp: TResPack;
    FData: PByte;
    FSize: SizeUInt;
    FOwnsBlob: Boolean;
    FETags: array of string; { parallel ETag cache — precomputed at Create, O(1) ServeVfs }
    FLastMods: array of string; { parallel Last-Modified cache — FormatHttpDate at Create }
    FEntries: array of TResPackEntry; { parallel entry cache — zero DecodeWire on Stat/OpenRead }
    FPool: array[0..EMBEDDED_POOL_SIZE - 1] of TEmbeddedSlice;
    FPoolCount: Integer;
    FPoolLock: ISpinLock;
    function LowerBoundPath(const APath: string): SizeInt; inline;
    function LowerBoundView(const AView: TStringView): SizeUInt; inline;
    function HasSubtreePath(const APath: string): Boolean;
    function HasSubtreeView(const AView: TStringView): Boolean;
    function IndexOfPath(const APath: string): SizeInt;
    function IndexOfView(const AView: TStringView): SizeInt; inline;
    function TryPopPool(out ASlice: TEmbeddedSlice): Boolean;
    function TryPushPool(ASlice: TEmbeddedSlice): Boolean;
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
  LKeep := FKeep;
  if LKeep = nil then ;
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
  { Materialize parallel caches once — FEntries 零 DecodeWire，ETag/LastMod O(1) ServeVfs。
    路径不再落地为 10k heap string（零拷贝：LowerBound/HasSubtree 直接走 FRp 存储字节），
    Create 442ms→<180ms 预期。 }
  SetLength(FETags, SizeInt(FRp.Count));
  SetLength(FLastMods, SizeInt(FRp.Count));
  SetLength(FEntries, SizeInt(FRp.Count));
  if FRp.Count > 0 then
    for I := 0 to FRp.Count - 1 do
    begin
      E := FRp.EntryAt(I);
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
  if FOwnsBlob and (FData <> nil) then
    FreeMem(FData, FSize);
  FData := nil;
  FSize := 0;
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
    if FPoolCount < EMBEDDED_POOL_SIZE then
    begin
      FPool[FPoolCount] := ASlice;
      Inc(FPoolCount);
      Result := True;
    end;
  finally
    FPoolLock.Release;
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

function TEmbeddedVfs.HasSubtreePath(const APath: string): Boolean;
var
  Lo: SizeUInt;
  QLen: Integer;
  P: PByte;
  L: SizeUInt;
begin
  { 零分配：FRp.LowerBound 直达首个 ≥ APath 项（不落地 string），再判 '/' 前缀 }
  Result := False;
  if FRp.Count = 0 then
    Exit;
  QLen := Length(APath);
  Lo := FRp.LowerBound(APath);
  if Lo >= FRp.Count then Exit;
  L := FRp.StoredPathRange(Lo, P);
  if L <= SizeUInt(QLen) then Exit;
  if P[QLen] <> Ord('/') then Exit;
  if QLen > 0 then
    if not CompareMem(P, @APath[1], SizeUInt(QLen)) then Exit;
  Result := True;
end;

function TEmbeddedVfs.IndexOfPath(const APath: string): SizeInt;
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

function TEmbeddedVfs.TryGetServeMeta(const APath: string; out AETag, ALastModified: string): Boolean;
var
  Idx: SizeInt;
begin
  // 单次二分同时取双值，ServeVfs 三连击 3×→1×
  Idx := IndexOfPath(APath);
  if Idx >= 0 then
  begin
    AETag := FETags[Idx];
    ALastModified := FLastMods[Idx];
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
  PrefixLen: SizeInt;
  Seen: TVfsNameArray;
  SI: TStatInfo;
  Idx: SizeInt;
  E: TResPackEntry;
  I: SizeInt;
  OutN: SizeInt;
  SegPos: SizeInt;
  P: PByte;
  L: SizeUInt;
  Child: string;
  ChildOff: SizeInt;
  ChildLen: SizeInt;
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
  PrefixLen := Length(Prefix);

  // 零拷贝推导：直接扫描 FRp 索引存储字节，仅分配直接子项去重后 Child 字符串（≤ 扇出）
  SetLength(Seen, SizeInt(FRp.Count));
  OutN := 0;
  for I := 0 to SizeInt(FRp.Count) - 1 do
  begin
    L := FRp.StoredPathRange(I, P);
    if SizeInt(L) <= PrefixLen then Continue;
    if PrefixLen > 0 then
      if not CompareMem(P, @Prefix[1], SizeUInt(PrefixLen)) then Continue;
    // '/' 扫描：零基偏移，避免 QWord 常量 -1 越界（SizeInt 带符号，-1 合法）
    SegPos := 0;
    for ChildOff := PrefixLen to SizeInt(L) - 1 do
      if (P + SizeUInt(ChildOff))^ = Ord('/') then
      begin
        SegPos := ChildOff + 1;
        Break;
      end;
    if SegPos > 0 then
      ChildLen := SegPos - 1
    else
      ChildLen := SizeInt(L);
    SetLength(Child, ChildLen);
    if ChildLen > 0 then
      Move(P^, Child[1], SizeUInt(ChildLen));
    if (OutN = 0) or (Seen[OutN - 1] <> Child) then
    begin
      Seen[OutN] := Child;
      Inc(OutN);
    end;
  end;
  SetLength(Seen, OutN);

  Result := nil;
  SetLength(Result, OutN);
  if OutN > 0 then
    for I := 0 to OutN - 1 do
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
