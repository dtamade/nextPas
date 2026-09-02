unit nextpas.core.vfs.mount;

{** @desc mount 视图：多 IVfs 按前缀挂载的只读复合视图（Go fs.FS 组合对等物）。
  完整性：补齐 respack/vfs 对多源资产聚合的最后一块（P2），超越 Go embed 单包。
  INV-M1：挂载表按前缀长度降序（最长匹配），'.' 前缀表根直通。
  错误语义：Op/Path 保持调用方视角，复用 sub 同款改写策略。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.vfs.base,
  nextpas.core.vfs.cache,
  nextpas.core.vfs.errors,
  nextpas.core.vfs.intf;

type
  TVfsMountEntry = record
    Prefix: string; { '' 或 '.' 表根挂载；否则合法虚拟路径如 'assets' }
    Fs: IVfs;
  end;
  TVfsMountArray = array of TVfsMountEntry;

function VfsMountEntry(const APrefix: string; const AFs: IVfs): TVfsMountEntry; inline;

{ AMounts 至少1项；Prefix 必须 ValidPath(AllowRoot True) 且去重；Fs 非空。
  '.' 与 '' 等价为根；根挂载与前缀挂载不可混搭重复（根唯一）。 }
function CreateMountedVfs(const AMounts: array of TVfsMountEntry): IVfs;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.bytes.ops,
  nextpas.core.collections.algorithms,
  nextpas.core.collections.hashmap.swiss.str;

type
  TStrVfsMap = specialize TSwissTableStr<IVfs>;
  TMountedVfs = class(TInterfacedObject, IVfs, IVfsETag, IVfsServeMeta)
  private
    FMounts: TVfsMountArray;
    FMountMap: TStrVfsMap; { O(1) exact-hit 索引：IsMountPoint/FindMount 热路径单源哈希，零线性扫描 }
    FHasRoot: Boolean;
    FRootFs: IVfs;
    FListCache: TVfsListCache; { 热点目录缓存单源 helper：SwissTable 16槽 + RWLock 读并发零争用 + 阻塞写 + Copy隔离（mount/overlay 单源 via vfs.cache） }
    function FindMount(const APath: string; out ARemain: string; out AFs: IVfs): Boolean; inline;
    function IsMountPoint(const APath: string): Boolean; inline;
    function TryGetListCached(const ADirPath: string; out AEntries: TEntryArray): Boolean; inline;
    procedure CacheList(const ADirPath: string; const AEntries: TEntryArray); inline;
  public
    constructor Create(const AMounts: array of TVfsMountEntry);
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

function VfsMountEntry(const APrefix: string; const AFs: IVfs): TVfsMountEntry; inline;
begin
  Result.Prefix := APrefix;
  Result.Fs := AFs;
end;

function CreateMountedVfs(const AMounts: array of TVfsMountEntry): IVfs;
begin
  Result := TMountedVfs.Create(AMounts);
end;

function NormalizePrefix(const S: string): string; inline;
var
  L: Integer;
begin
  Result := S;
  if (Result = '') or VfsIsRoot(Result) then Exit('.');
  L := Length(Result);
  while (L > 0) and (Result[L] = '/') do Dec(L);
  if L <> Length(Result) then SetLength(Result, L);
end;

function CompareMountEntry(const A, B: TVfsMountEntry; Data: Pointer): SizeInt; inline;
begin
  if Length(A.Prefix) > Length(B.Prefix) then Exit(-1);
  if Length(A.Prefix) < Length(B.Prefix) then Exit(1);
  Result := VfsNameCompare(A.Prefix, B.Prefix);
end;

constructor TMountedVfs.Create(const AMounts: array of TVfsMountEntry);
var
  I, J: Integer;
  P: string;
begin
  inherited Create;
  if Length(AMounts) = 0 then
    raise EVfsError.CreateCtx('mount', '', 'mounted vfs requires at least one mount');
  SetLength(FMounts, Length(AMounts));
  FHasRoot := False;
  for I := 0 to High(AMounts) do
  begin
    P := NormalizePrefix(AMounts[I].Prefix);
    if not VfsValidPath(P, True) then
      raise EVfsInvalidPath.CreateCtx('mount', P, 'invalid mount prefix');
    if AMounts[I].Fs = nil then
      raise EVfsError.CreateCtx('mount', P, 'mount fs must not be nil');
    for J := 0 to I - 1 do
      if FMounts[J].Prefix = P then
        raise EVfsError.CreateCtx('mount', P, 'duplicate mount prefix');
    FMounts[I].Prefix := P;
    FMounts[I].Fs := AMounts[I].Fs;
    if VfsIsRoot(P) then
    begin
      if FHasRoot then
        raise EVfsError.CreateCtx('mount', P, 'duplicate root mount');
      FHasRoot := True;
      FRootFs := AMounts[I].Fs;
    end;
  end;
  // 最长匹配优先：按长度降序（复用 collections 单源 Sort，O(n log n)）
  if Length(FMounts) > 1 then
    specialize Sort<TVfsMountEntry>(FMounts, @CompareMountEntry, nil);
  // re-evaluate root after sort
  FHasRoot := False;
  FRootFs := nil;
  for I := 0 to High(FMounts) do
    if VfsIsRoot(FMounts[I].Prefix) then
    begin
      FHasRoot := True;
      FRootFs := FMounts[I].Fs;
      Break;
    end;
  // 构建哈希索引 O(n)：FindMount/IsMountPoint 热路径 O(1)/O(depth) 单源 SwissTable，零线性扫描
  FMountMap := TStrVfsMap.Create(Length(FMounts));
  for I := 0 to High(FMounts) do
    FMountMap.Put(FMounts[I].Prefix, FMounts[I].Fs);
  FListCache := TVfsListCache.Create;
end;

destructor TMountedVfs.Destroy;
begin
  if FListCache <> nil then
  begin
    FListCache.Free;
    FListCache := nil;
  end;
  if Assigned(FMountMap) then FMountMap.Free;
  inherited Destroy;
end;

{ 热点缓存单源 helper：SwissTable 16槽 + RWLock 读并发零争用 + 阻塞写 + Copy隔离（mount/overlay 单源 via vfs.cache），inline 热路径 }
function TMountedVfs.TryGetListCached(const ADirPath: string; out AEntries: TEntryArray): Boolean; inline;
begin
  Result := (FListCache <> nil) and FListCache.TryGet(ADirPath, AEntries);
end;

procedure TMountedVfs.CacheList(const ADirPath: string; const AEntries: TEntryArray); inline;
begin
  if FListCache = nil then Exit;
  FListCache.Put(ADirPath, AEntries); { 阻塞写单源 helper，抢锁不丢弃防重复 O(k log k) Sort/Dedup }
end;

{ 单源容量模板：derive 通用 16 倍增 Cap≤N via bytes.ops BytesNextCapacity，inline 零拷贝单源，复用 base VfsDerive* 同款策略 }
procedure MountEnsureListCap(var AArr: TEntryArray; const ANeed: SizeInt; const ALimit: SizeInt); inline;
var
  LCap: SizeUInt;
begin
  if ANeed <= Length(AArr) then Exit;
  LCap := BytesNextCapacity(SizeUInt(Length(AArr)), SizeUInt(ANeed));
  { BytesNextCapacity 最小 64，mount 热点目录扇出通常 <64，需按 ALimit 回缩以守零浪费；derive 模板 16 起步，此处以限界对齐 }
  if (ALimit > 0) and (SizeInt(LCap) > ALimit) then LCap := SizeUInt(ALimit);
  if SizeInt(LCap) < ANeed then LCap := SizeUInt(ANeed);
  if LCap = 0 then LCap := SizeUInt(ANeed);
  SetLength(AArr, SizeInt(LCap));
end;

{ 零拷贝 Top 段提取：bytes.ops TByteSpan 单源，SpanToString 单 Move，复用 derive 通用模板 }
function MountTopSegment(const APrefix: string): string; inline;
var
  S: TByteSpan;
  P: SizeInt;
begin
  if Length(APrefix) = 0 then Exit('');
  S := TByteSpan.Create(PByte(@APrefix[1]), SizeUInt(Length(APrefix)));
  P := SpanIndexOf(S, Byte(Ord('/')));
  if P >= 0 then
    Result := SpanToString(S.Slice(0, SizeUInt(P)))
  else
    Result := APrefix;
end;

function MountChildSegment(const APrefix, AParent: string): string; inline;
var
  SPrefix, SParent: TByteSpan;
  SRem: TByteSpan;
  P: SizeInt;
begin
  { AParent 已校验为 APrefix 父路径；零拷贝 Slice 提取直接子段 }
  SPrefix := TByteSpan.Create(PByte(@APrefix[1]), SizeUInt(Length(APrefix)));
  SParent := TByteSpan.Create(PByte(@AParent[1]), SizeUInt(Length(AParent)));
  { 跳过 parent + '/' }
  SRem := SPrefix.Slice(SParent.Len + 1, SPrefix.Len - (SParent.Len + 1));
  P := SpanIndexOf(SRem, Byte(Ord('/')));
  if P >= 0 then
    Result := SpanToString(SRem.Slice(0, SizeUInt(P)))
  else
    Result := SpanToString(SRem);
end;

function TMountedVfs.IsMountPoint(const APath: string): Boolean; inline;
begin
  // O(1) 哈希命中：SwissTable 单源哈希，inline 热路径零线性扫描
  Result := FMountMap.ContainsKey(APath);
end;

function TMountedVfs.FindMount(const APath: string; out ARemain: string; out AFs: IVfs): Boolean; inline;
var
  FoundFs: IVfs;
  LPos: Integer;
  PathSpan, CandSpan, RemSpan: TByteSpan;
begin
  if VfsIsRoot(APath) then
  begin
    // 根请求不直接映射到子 Fs，由调用方按需分发
    ARemain := '.';
    AFs := nil;
    Exit(False);
  end;
  // O(1) exact-hit 哈希
  if FMountMap.TryGetValue(APath, FoundFs) then
  begin
    if VfsIsRoot(APath) then
    begin
      ARemain := '.';
      AFs := nil;
      Exit(False);
    end;
    ARemain := '.';
    AFs := FoundFs;
    Exit(True);
  end;
  // O(depth) 前缀剥离哈希：零拷贝 TByteSpan 视图单源 via bytes.ops，inline 热路径，无逐段 Copy 分配
  // 单源 VfsIsParentPath 语义由 '/' 边界剥离保证，Candidate 零分配 Span 切片，ARemain 仅命中时一次 SpanToString 单 Move
  if Length(APath) = 0 then PathSpan := TByteSpan.Empty
  else PathSpan := TByteSpan.Create(PByte(@APath[1]), SizeUInt(Length(APath)));
  LPos := Length(APath);
  while LPos > 0 do
  begin
    while (LPos > 0) and (APath[LPos] <> '/') do Dec(LPos);
    if LPos <= 0 then Break;
    CandSpan := PathSpan.Slice(0, SizeUInt(LPos - 1));
    if FMountMap.TryGetValueSpan(CandSpan, FoundFs) then
    begin
      if (CandSpan.Len = 1) and (CandSpan.Data^ = Ord('.')) then
      begin
        Dec(LPos);
        Continue;
      end;
      RemSpan := PathSpan.Slice(SizeUInt(LPos), PathSpan.Len - SizeUInt(LPos));
      ARemain := SpanToString(RemSpan); { 零拷贝视图+单 Move，bytes.ops 单源 }
      AFs := FoundFs;
      Exit(True);
    end;
    Dec(LPos);
  end;
  // 尝试根挂载兜底
  if FHasRoot then
  begin
    ARemain := APath;
    AFs := FRootFs;
    Exit(True);
  end;
  Result := False;
end;

function TMountedVfs.Exists(const APath: string): Boolean;
var
  Rem: string;
  Fs: IVfs;
begin
  if not VfsValidPath(APath, True) then Exit(False);
  if VfsIsRoot(APath) then Exit(True);
  if IsMountPoint(APath) then Exit(True);
  if FindMount(APath, Rem, Fs) then
    Exit(Fs.Exists(Rem));
  Result := False;
end;

function TMountedVfs.Stat(const APath: string): TStatInfo;
var
  Rem: string;
  Fs: IVfs;
  I: Integer;
begin
  if not VfsValidPath(APath, True) then
    raise EVfsInvalidPath.CreateCtx('stat', APath, 'invalid virtual path');
  if VfsIsRoot(APath) then
  begin
    Result.Info.Name := '.';
    Result.Info.Size := 0;
    Result.Info.ModTime := 0;
    Result.Info.IsDir := True;
    Result.ContentHash := 0;
    Exit;
  end;
  if IsMountPoint(APath) then
  begin
    // 挂载点视为目录（底层须为目录，已由子 Fs 保证）
    Result.Info.Name := APath;
    Result.Info.Size := 0;
    Result.Info.ModTime := 0;
    Result.Info.IsDir := True;
    Result.ContentHash := 0;
    Exit;
  end;
  if FindMount(APath, Rem, Fs) then
  begin
    Result := Fs.Stat(Rem);
    Result.Info.Name := APath;
    Exit;
  end;
  raise EVfsNotFound.CreateCtx('stat', APath, 'not found');
end;

function TMountedVfs.List(const ADirPath: string): TEntryArray;
var
  Rem: string;
  Fs: IVfs;
  I, OutN: Integer;
  Child: string;
  BaseList: TEntryArray;
begin
  if not VfsValidPath(ADirPath, True) then
    raise EVfsInvalidPath.CreateCtx('list', ADirPath, 'invalid virtual path');
  { 热点目录缓存：高基数目录重复 List O(n log n) Sort/Dedup → O(1) 哈希 + O(k) Copy，SwissTable 16槽 RWLock 读并发零争用/阻塞 AcquireWrite 单源 helper via vfs.cache 对齐 overlay，inline 热路径 }
  if TryGetListCached(ADirPath, Result) then Exit;
  if VfsIsRoot(ADirPath) then
  begin
    { 根：合并所有挂载点的顶层 List（O(n log n) Sort+线性去重，零拷贝前缀扫描） }
    { 单源模板：扇出限界 16 倍增 Cap≤N via bytes.ops BytesNextCapacity，复用 derive 通用模板，零 Copy 切片 via MountTopSegment }
    if FHasRoot and (Length(FMounts) = 1) then
    begin
      Result := FRootFs.List('.');
      CacheList(ADirPath, Result);
      Exit;
    end;
    Result := nil;
    OutN := 0;
    for I := 0 to High(FMounts) do
      if not VfsIsRoot(FMounts[I].Prefix) then
      begin
        Child := MountTopSegment(FMounts[I].Prefix); { 零拷贝 TByteSpan+SpanToString 单 Move，bytes.ops 单源 }
        MountEnsureListCap(Result, OutN + 1, Length(FMounts));
        Result[OutN].Name := Child;
        Result[OutN].Size := 0;
        Result[OutN].ModTime := 0;
        Result[OutN].IsDir := True;
        Inc(OutN);
      end;
    { 若有根挂载，合并其根 List（延迟去重，单次 Sort） }
    if FHasRoot then
    begin
      BaseList := FRootFs.List('.');
      for I := 0 to High(BaseList) do
      begin
        MountEnsureListCap(Result, OutN + 1, Length(FMounts) + Length(BaseList));
        { 精确限界：避免尾部过度预分配，剩余量校正 }
        if Length(Result) > OutN + (Length(BaseList) - I) then
          SetLength(Result, OutN + (Length(BaseList) - I));
        Result[OutN] := BaseList[I];
        Inc(OutN);
      end;
    end;
    SetLength(Result, OutN);
    VfsSortEntries(Result);
    VfsDedupSortedEntries(Result);
    CacheList(ADirPath, Result);
    Exit;
  end;
  if IsMountPoint(ADirPath) then
  begin
    if FMountMap.TryGetValue(ADirPath, Fs) then
    begin
      Result := Fs.List('.');
      CacheList(ADirPath, Result);
      Exit;
    end;
  end;
  if FindMount(ADirPath, Rem, Fs) then
  begin
    Result := Fs.List(Rem);
    CacheList(ADirPath, Result);
    Exit;
  end;
  { 若是前缀的父目录，需聚合子挂载点（复用 VfsIsParentPath 单源，bytes.ops 零拷贝） }
  { 例如 mounts: a/b, a/c  => List('a') 应返回 b,c }
  { 单源模板：扇出限界 16 倍增 Cap≤N via bytes.ops MountEnsureListCap，复用 derive 通用模板 }
  Result := nil;
  OutN := 0;
  for I := 0 to High(FMounts) do
  begin
    if VfsIsRoot(FMounts[I].Prefix) then Continue;
    if not VfsIsParentPath(ADirPath, FMounts[I].Prefix) then Continue;
    Child := MountChildSegment(FMounts[I].Prefix, ADirPath); { 零拷贝 Span Slice + 单 Move，bytes.ops 单源 }
    MountEnsureListCap(Result, OutN + 1, Length(FMounts));
    Result[OutN].Name := Child;
    Result[OutN].Size := 0;
    Result[OutN].ModTime := 0;
    Result[OutN].IsDir := True;
    Inc(OutN);
  end;
  if OutN > 0 then
  begin
    SetLength(Result, OutN);
    VfsSortEntries(Result);
    VfsDedupSortedEntries(Result);
    CacheList(ADirPath, Result);
    Exit;
  end;
  raise EVfsNotFound.CreateCtx('list', ADirPath, 'not found');
end;

function TMountedVfs.OpenRead(const APath: string): IStream;
var
  Rem: string;
  Fs: IVfs;
begin
  if not VfsValidPath(APath, True) then
    raise EVfsInvalidPath.CreateCtx('open', APath, 'invalid virtual path');
  if VfsIsRoot(APath) or IsMountPoint(APath) then
    raise EVfsIsADirectory.CreateCtx('open', APath, 'target is a directory');
  if FindMount(APath, Rem, Fs) then
    Exit(Fs.OpenRead(Rem));
  raise EVfsNotFound.CreateCtx('open', APath, 'not found');
end;

function TMountedVfs.CaseSensitive: Boolean;
var
  I: Integer;
  First: Boolean;
begin
  if Length(FMounts) = 0 then Exit(True);
  First := FMounts[0].Fs.CaseSensitive;
  for I := 1 to High(FMounts) do
    if FMounts[I].Fs.CaseSensitive <> First then Exit(True);
  Result := First;
end;

function TMountedVfs.TryGetETag(const APath: string; out AETag: string): Boolean;
var
  Rem: string;
  Fs: IVfs;
begin
  // 单源 VfsETagHelper via bytes.ops 外零分配，Supports 级联同构收口（overlay 同源）
  AETag := '';
  if not FindMount(APath, Rem, Fs) then Exit(False);
  Result := VfsETagHelperTryGetETag(Fs, Rem, AETag);
end;

function TMountedVfs.TryGetLastModified(const APath: string; out ALastModified: string): Boolean;
var
  Rem: string;
  Fs: IVfs;
begin
  ALastModified := '';
  if not FindMount(APath, Rem, Fs) then Exit(False);
  Result := VfsETagHelperTryGetLastModified(Fs, Rem, ALastModified);
end;

function TMountedVfs.TryGetServeMeta(const APath: string; out AETag, ALastModified: string): Boolean;
var
  Rem: string;
  Fs: IVfs;
begin
  AETag := '';
  ALastModified := '';
  if not FindMount(APath, Rem, Fs) then Exit(False);
  Result := VfsETagHelperTryGetServeMeta(Fs, Rem, AETag, ALastModified);
end;

end.
