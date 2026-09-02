unit nextpas.core.vfs.overlay;

{** @desc 叠加视图：多 IVfs 同根优先级叠加（游戏 patch>dlc>base 热更模型）。
  与 mount 互补：mount 是异前缀聚合（a→FsA, b→FsB），overlay 是同根覆盖
  （同一虚拟路径多层，首命中胜出）。INV-O1：列表按传入优先级有序，Exists/Stat/
  OpenRead 按序首命中；List('.') 去重合并按首层优先保留。
  INV-V2 不可变快照+热点缓存：发布后只读，SwissTable 16槽 RWLock 读并发零争用/
  阻塞 AcquireWrite 热点 List 缓存单源 helper via vfs.cache（对齐 mount §6，防 TryAcquireWrite 丢弃致重复 O(k log k)），首击流式增量哈希去重 O(k)+O(k log k)
  VfsSortEntries 去重后排序后续 O(1) 哈希+O(k) Copy 隔离；bytes.ops
  VfsNameCompare SpanCompare 零拷贝单源，VfsSortEntries 单源。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.vfs.base,
  nextpas.core.vfs.cache,
  nextpas.core.vfs.errors,
  nextpas.core.vfs.intf;

function CreateOverlayVfs(const AList: array of IVfs): IVfs;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.bytes.ops,
  nextpas.core.collections.hashmap.swiss.str;

type
  TOverlayVfs = class(TInterfacedObject, IVfs, IVfsETag, IVfsServeMeta)
  private
    FList: array of IVfs; { 不可变快照：构造期冻结只读，发布后热点 List SwissTable 16槽 RWLock 缓存对齐 mount §6，读并发零争用 }
    FListCache: TVfsListCache; { 热点目录缓存单源 helper：SwissTable 16槽 + RWLock 读并发零争用 + 阻塞写 + Copy隔离（mount/overlay 单源 via vfs.cache） }
    function FindFirstStat(const APath: string; out AInfo: TStatInfo; out AFs: IVfs): Boolean;
    function FindStat(const APath: string; out AInfo: TStatInfo): Boolean; inline;
    function TryGetListCached(const ADirPath: string; out AEntries: TEntryArray): Boolean; inline;
    procedure CacheList(const ADirPath: string; const AEntries: TEntryArray); inline;
  public
    constructor Create(const AList: array of IVfs);
    destructor Destroy; override;
    function Exists(const APath: string): Boolean;
    function Stat(const APath: string): TStatInfo;
    function List(const ADirPath: string): TEntryArray;
    function OpenRead(const APath: string): IStream;
    function CaseSensitive: Boolean; inline;
    function TryGetETag(const APath: string; out AETag: string): Boolean;
    function TryGetLastModified(const APath: string; out ALastModified: string): Boolean;
    function TryGetServeMeta(const APath: string; out AETag, ALastModified: string): Boolean;
  end;

function CreateOverlayVfs(const AList: array of IVfs): IVfs;
begin
  Result := TOverlayVfs.Create(AList);
end;

constructor TOverlayVfs.Create(const AList: array of IVfs);
var
  I: Integer;
begin
  inherited Create;
  if Length(AList) = 0 then
    raise EVfsError.CreateCtx('overlay', '', 'overlay requires at least one fs');
  SetLength(FList, Length(AList));
  for I := 0 to High(AList) do
  begin
    if AList[I] = nil then
      raise EVfsError.CreateCtx('overlay', '', 'overlay fs must not be nil');
    FList[I] := AList[I];
  end;
  FListCache := TVfsListCache.Create;
end;

destructor TOverlayVfs.Destroy;
begin
  if FListCache <> nil then
  begin
    FListCache.Free;
    FListCache := nil;
  end;
  SetLength(FList, 0);
  inherited Destroy;
end;

{ 热点缓存单源 helper：SwissTable 16槽 + RWLock 读并发零争用 + 阻塞写 + Copy隔离（mount/overlay 单源 via vfs.cache），inline 热路径 }
function TOverlayVfs.TryGetListCached(const ADirPath: string; out AEntries: TEntryArray): Boolean; inline;
begin
  Result := (FListCache <> nil) and FListCache.TryGet(ADirPath, AEntries);
end;

procedure TOverlayVfs.CacheList(const ADirPath: string; const AEntries: TEntryArray); inline;
begin
  if FListCache = nil then Exit;
  FListCache.Put(ADirPath, AEntries); { 阻塞写单源 helper，抢锁不丢弃防重复 O(k log k) Sort/Dedup }
end;

{ 首命中直达：O(m) 层线性探测，零缓存/零锁，命中层单次 Stat 直达；
  bytes.ops 零拷贝单源由 List 侧 VfsNameCompare 承载；非 inline（循环+try-except禁 inline） }
function TOverlayVfs.FindFirstStat(const APath: string; out AInfo: TStatInfo; out AFs: IVfs): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(FList) do
  begin
    try
      AInfo := FList[I].Stat(APath);
      AFs := FList[I];
      Exit(True);
    except
      on E: EVfsNotFound do Continue;
      on E: EVfsInvalidPath do raise;
    end;
  end;
  AFs := nil;
  Result := False;
end;

function TOverlayVfs.FindStat(const APath: string; out AInfo: TStatInfo): Boolean; inline;
var
  LFs: IVfs;
begin
  Result := FindFirstStat(APath, AInfo, LFs);
end;

function TOverlayVfs.Exists(const APath: string): Boolean; inline;
var
  LInfo: TStatInfo;
  LFs: IVfs;
begin
  if not VfsValidPath(APath, True) then Exit(False);
  if VfsIsRoot(APath) then Exit(True);
  { 单次 Stat 探测替代 Exists 循环，避免层数多时重复二分；inline 零拷贝 VfsValidPath }
  Result := FindFirstStat(APath, LInfo, LFs);
end;

function TOverlayVfs.Stat(const APath: string): TStatInfo;
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
  if FindStat(APath, Result) then
  begin
    Result.Info.Name := APath;
    Exit;
  end;
  raise EVfsNotFound.CreateCtx('stat', APath, 'not found');
end;

{ 指数扩容单源：bytes.ops BytesNextCapacity 几何倍增（BYTES_BUILDER_MIN_GROW 起步×2，均摊 O(1)），单源防漂移；inline 零拷贝，单次 SetLength+Move，避免多层叠加时 O(n²) realloc+Move；资源释放不丢（Seen 哈希表 try-finally 托管异常自动释放，Result/Cur 局部托管） }
procedure OverlayEnsureCapEntries(var AArr: TEntryArray; const ANeed: SizeInt); inline;
var
  LCap: SizeUInt;
begin
  if ANeed <= Length(AArr) then Exit;
  LCap := BytesNextCapacity(SizeUInt(Length(AArr)), SizeUInt(ANeed));
  SetLength(AArr, SizeInt(LCap));
end;

{ 流式增量去重 List：优先级顺序 O(k) 哈希去重 + 去重后 O(k log k) VfsSortEntries 单源排序，避免全量 Temp 物化后 Sort+Unique+Copy 双重拷贝；bytes.ops VfsNameCompare SpanCompare 零拷贝单源 via VfsSortEntries，BytesNextCapacity 指数扩容均摊 O(1) 复用 mount 同款模板 inline。 }
function TOverlayVfs.List(const ADirPath: string): TEntryArray;
var
  I, J: Integer;
  OutN: SizeInt;
  Cur: TEntryArray;
  LStat: TStatInfo;
  Seen: specialize TSwissTableStr<Byte>;
begin
  if not VfsValidPath(ADirPath, True) then
    raise EVfsInvalidPath.CreateCtx('list', ADirPath, 'invalid virtual path');
  { 热点目录缓存：SwissTable 16槽 RWLock 读并发零争用/阻塞 AcquireWrite 单源 helper，首击流式增量哈希去重+去重后排序 后续 O(1) 哈希+O(k) Copy 隔离，对齐 mount §6，零拷贝 VfsNameCompare via bytes.ops SpanCompare 单源 inline via VfsSortEntries }
  if TryGetListCached(ADirPath, Result) then Exit;
  if not VfsIsRoot(ADirPath) then
  begin
    if not FindStat(ADirPath, LStat) then
      raise EVfsNotFound.CreateCtx('list', ADirPath, 'not found');
    if not LStat.Info.IsDir then
      raise EVfsNotADirectory.CreateCtx('list', ADirPath, 'target is a file');
  end;
  Result := nil;
  OutN := 0;
  Seen := specialize TSwissTableStr<Byte>.Create(16);
  try
    for I := 0 to High(FList) do
    begin
      try Cur := FList[I].List(ADirPath);
      except on E: EVfsNotFound do Continue; on E: EVfsNotADirectory do Continue; end;
      if Length(Cur) = 0 then Continue;
      for J := 0 to High(Cur) do
      begin
        if Seen.ContainsKey(Cur[J].Name) then Continue;
        Seen.Put(Cur[J].Name, 0);
        { 指数扩容单源：bytes.ops BytesNextCapacity 几何倍增×2，均摊 O(1) inline+Move 零拷贝，单源复用 mount 模板 via OverlayEnsureCapEntries }
        OverlayEnsureCapEntries(Result, OutN + 1);
        Result[OutN] := Cur[J];
        Inc(OutN);
      end;
    end;
    if OutN = 0 then
    begin
      SetLength(Result, 0);
      Result := nil;
      CacheList(ADirPath, Result);
      Exit(nil);
    end;
    SetLength(Result, SizeInt(OutN));
    VfsSortEntries(Result);
    CacheList(ADirPath, Result);
  finally
    Seen.Free;
  end;
end;

function TOverlayVfs.OpenRead(const APath: string): IStream;
var
  LInfo: TStatInfo;
  LFs: IVfs;
begin
  if not VfsValidPath(APath, True) then
    raise EVfsInvalidPath.CreateCtx('open', APath, 'invalid virtual path');
  if VfsIsRoot(APath) then
    raise EVfsIsADirectory.CreateCtx('open', APath, 'target is a directory');
  { 单次 Stat 首命中替代 Exists+Stat 双探测；IsDir 即抛 IsADirectory，否则直透 OpenRead，零重复二分 }
  if FindFirstStat(APath, LInfo, LFs) then
  begin
    if LInfo.Info.IsDir then
      raise EVfsIsADirectory.CreateCtx('open', APath, 'target is a directory');
    Exit(LFs.OpenRead(APath));
  end;
  raise EVfsNotFound.CreateCtx('open', APath, 'not found');
end;

{ 同根优先级：CaseSensitive 取首层优先，与 Exists/Stat/OpenRead 首命中一致；
  异构时不再保守退 True，避免与 List 字节序去重（VfsNameCompare via bytes.ops SpanCompare 零拷贝）产生大小写同名异壳歧义 }
function TOverlayVfs.CaseSensitive: Boolean; inline;
begin
  if Length(FList) = 0 then Exit(True);
  Result := FList[0].CaseSensitive;
end;

function TOverlayVfs.TryGetETag(const APath: string; out AETag: string): Boolean;
var
  LInfo: TStatInfo;
  LFs: IVfs;
begin
  // 单源 VfsETagHelper：复用 mount 同源 Supports 级联 via bytes.ops 外零分配，inline
  AETag := '';
  if VfsIsRoot(APath) then Exit(False);
  if not FindFirstStat(APath, LInfo, LFs) then Exit(False);
  if LInfo.Info.IsDir then Exit(False);
  Result := VfsETagHelperTryGetETag(LFs, APath, AETag);
end;

function TOverlayVfs.TryGetLastModified(const APath: string; out ALastModified: string): Boolean;
var
  LInfo: TStatInfo;
  LFs: IVfs;
begin
  ALastModified := '';
  if VfsIsRoot(APath) then Exit(False);
  if not FindFirstStat(APath, LInfo, LFs) then Exit(False);
  if LInfo.Info.IsDir then Exit(False);
  Result := VfsETagHelperTryGetLastModified(LFs, APath, ALastModified);
end;

function TOverlayVfs.TryGetServeMeta(const APath: string; out AETag, ALastModified: string): Boolean;
var
  LInfo: TStatInfo;
  LFs: IVfs;
begin
  AETag := '';
  ALastModified := '';
  if VfsIsRoot(APath) then Exit(False);
  if not FindFirstStat(APath, LInfo, LFs) then Exit(False);
  if LInfo.Info.IsDir then Exit(False);
  Result := VfsETagHelperTryGetServeMeta(LFs, APath, AETag, ALastModified);
end;

end.
