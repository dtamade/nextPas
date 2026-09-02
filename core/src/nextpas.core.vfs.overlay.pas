unit nextpas.core.vfs.overlay;

{** @desc 叠加视图：多 IVfs 同根优先级叠加（游戏 patch>dlc>base 热更模型）。
  与 mount 互补：mount 是异前缀聚合（a→FsA, b→FsB），overlay 是同根覆盖
  （同一虚拟路径多层，首命中胜出）。INV-O1：列表按传入优先级有序，Exists/Stat/
  OpenRead 按序首命中；List('.') 去重合并按首层优先保留。
  INV-V2 不可变快照+热点缓存：发布后只读，SwissTable 16槽 RWLock 读并发零争用/
  阻塞 AcquireWrite 热点 List 缓存单源 helper via vfs.cache（对齐 mount §6，防 TryAcquireWrite 丢弃致重复 O(k log k)），首击 k 路归并 O(k·m) 零哈希零额外堆（仅 Result 一次分配，头 Span 缓存+SpanCompare/SpanEqual 零拷贝 inline via bytes.ops，BestSpan 视图免 string 拷贝/refcnt，去重后已有序免二次 VfsSortEntries）后续 O(1) 哈希+O(k) Copy 隔离；bytes.ops
  VfsNameCompare/SpanCompare/SpanEqual 零拷贝单源，VfsSortEntries 单源（归并已有序不再二次排序）。 }

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
  nextpas.core.bytes.ops;

type
  TOverlayVfs = class(TInterfacedObject, IVfs, IVfsETag, IVfsServeMeta)
  private
    FList: array of IVfs; { 不可变快照：构造期冻结只读，发布后热点 List SwissTable 16槽 RWLock 缓存对齐 mount §6，读并发零争用 }
    FListCache: TVfsListCache; { 热点目录缓存单源 helper：SwissTable 16槽 + RWLock 读并发零争用 + 阻塞写 + Copy隔离（mount/overlay 单源 via vfs.cache） }
    function FindFirstStat(const APath: string; out AInfo: TStatInfo; out AFs: IVfs): Boolean;
    function FindStat(const APath: string; out AInfo: TStatInfo): Boolean;
    function FindFirstStat(const APath: string; out AInfo: TStatInfo; out AFs: IVfs): Boolean; inline;
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
function TOverlayVfs.TryGetCached(const APath: string; out AIdx: Integer): Boolean;
begin
  AIdx := -2;
  Result := False;
  if (FIndex = nil) or (FIndexLock = nil) then Exit;
  FIndexLock.AcquireRead;
  try
    Result := TOverlayIndex(FIndex).TryGetValue(APath, AIdx);
  finally
    FIndexLock.ReleaseRead;
  end;
end;

procedure TOverlayVfs.CacheResult(const APath: string; const AIdx: Integer);
var
  LDummy: Integer;
{ 单次探测首命中：按优先级依次 Stat，首成功即胜出；EVfsNotFound 继续下层，
  EVfsInvalidPath 透传；零二次 Exists 二分，inline 热路径 }
function TOverlayVfs.FindFirstStat(const APath: string; out AInfo: TStatInfo; out AFs: IVfs): Boolean; inline;
var
  I: Integer;
begin
  if (FIndex = nil) or (FIndexLock = nil) then Exit;
  if not FIndexLock.TryAcquireWrite then Exit;
  try
    if TOverlayIndex(FIndex).TryGetValue(APath, LDummy) then Exit;
    TOverlayIndex(FIndex).Put(APath, AIdx);
  finally
    FIndexLock.ReleaseWrite;
  end;
end;

function TOverlayVfs.TryGetListCached(const ADirPath: string; out AEntries: TEntryArray): Boolean;
var
  LCached: TEntryArray;
begin
  AEntries := nil;
  Result := False;
  if (FListCache = nil) or (FListLock = nil) then Exit;
  FListLock.AcquireRead;
  try
    if TOverlayListCache(FListCache).TryGetValue(ADirPath, LCached) then
    begin
      AEntries := Copy(LCached); { 隔离拷贝 O(k) Move，RWLock读并发零争用，防调用方篡改共享缓存 }
      Result := True;
    end;
  finally
    FListLock.ReleaseRead;
  end;
end;

procedure TOverlayVfs.CacheList(const ADirPath: string; const AEntries: TEntryArray);
var
  LDummy: TEntryArray;
begin
  if (FListCache = nil) or (FListLock = nil) then Exit;
  if not FListLock.TryAcquireWrite then Exit;
  try
    if TOverlayListCache(FListCache).TryGetValue(ADirPath, LDummy) then Exit;
    TOverlayListCache(FListCache).Put(ADirPath, Copy(AEntries)); { Copy 隔离：热点目录增量缓存 O(k) 零拷贝防脏，TryAcquireWrite非阻塞防惊群 }
  finally
    FListLock.ReleaseWrite;
  end;
end;

{ 索引加速首命中：hash O(1) 首命中避 m 次二分；miss/layer负缓存防穿透；
  命中层单次 Stat 直达（零二次二分），RWLock读并发零争用/TryAcquireWrite非阻塞写防穿透惊群，bytes.ops零拷贝单源；非inline（循环+RWLock+try-except禁inline） }
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

{ 指数扩容单源：bytes.ops BytesNextCapacity 几何倍增（BYTES_BUILDER_MIN_GROW 起步×2，均摊 O(1)），单源防漂移；inline 零拷贝，单次 SetLength+Move，避免多层叠加时 O(n²) realloc+Move；ALimit 回缩守零浪费（小目录<64 按限界裁剪不对齐 BYTES_BUILDER_MIN_GROW 预分配，复用 mount 同款模板 vialimit）；资源释放不丢（LCurs/Result/Idx 局部托管，无 Seen 堆表） }
procedure OverlayEnsureCapEntries(var AArr: TEntryArray; const ANeed: SizeInt; const ALimit: SizeInt); inline;
var
  LCap: SizeUInt;
begin
  if ANeed <= Length(AArr) then Exit;
  LCap := BytesNextCapacity(SizeUInt(Length(AArr)), SizeUInt(ANeed));
  { BytesNextCapacity 最小 64，小目录(<64)按 ALimit 回缩以守零浪费；derive/mount 模板 16 起步，此处以限界对齐 bytes.ops 单源 }
  if (ALimit > 0) and (SizeInt(LCap) > ALimit) then LCap := SizeUInt(ALimit);
  if SizeInt(LCap) < ANeed then LCap := SizeUInt(ANeed);
  if LCap = 0 then LCap := SizeUInt(ANeed);
  SetLength(AArr, SizeInt(LCap));
end;

{ k 路归并去重 List：零哈希零额外堆（热点 Miss 仅 Result 一次分配，后续 O(1) 哈希+O(k) Copy 缓存）；各层 List 已有序（os/embedded/memtree VfsSortEntries 单源），按字典序归并同时按首层优先去重，SpanCompare/SpanEqual 零拷贝单源 via bytes.ops inline（头 Span 缓存 FromStr 视图，BestSpan 零拷贝免 string 拷贝/refcnt，长目录热点路径比较每轮 2m 次 Span 构造→每元素 1 次），去重后已有序免二次 VfsSortEntries，BytesNextCapacity 指数扩容均摊 O(1) 复用 mount 同款模板 inline（ALimit 回缩<64 零浪费），资源释放不丢（LCurs/CurSpans/Result/Idx 局部托管，无 Seen 堆表 try-finally）。 }
function TOverlayVfs.List(const ADirPath: string): TEntryArray;
var
  I: Integer;
  OutN: SizeInt;
  LTotal: SizeInt;
  LStat: TStatInfo;
  LCurs: array of TEntryArray;
  Idx: array of SizeInt;
  CurSpans: array of TByteSpan; { 头 Span 缓存：零拷贝 FromStr 视图直指 LCurs Name 存储，inline SpanCompare/SpanEqual bytes.ops 单源，热点长目录每元素一次构造 }
  BestSpan: TByteSpan; { BestSpan 视图免 string 拷贝/refcnt，零额外堆 }
  BestLayer, BestIdx: Integer;
  Lcmp: Integer;
begin
  if not VfsValidPath(ADirPath, True) then
    raise EVfsInvalidPath.CreateCtx('list', ADirPath, 'invalid virtual path');
  { 热点目录缓存：SwissTable 16槽 RWLock 读并发零争用/阻塞 AcquireWrite 单源 helper，首击 k 路归并零哈希零额外堆（仅 Result 一次分配，去重后已有序）后续 O(1) 哈希+O(k) Copy 隔离，对齐 mount §6，零拷贝 VfsNameCompare via bytes.ops SpanCompare 单源 inline 免二次 VfsSortEntries }
  if TryGetListCached(ADirPath, Result) then Exit;
  if not VfsIsRoot(ADirPath) then
  begin
    if not FindStat(ADirPath, LStat) then
      raise EVfsNotFound.CreateCtx('list', ADirPath, 'not found');
    if not LStat.Info.IsDir then
      raise EVfsNotADirectory.CreateCtx('list', ADirPath, 'target is a file');
  end;
  { 预取各层 List 以得精确 ALimit 上界：sum Length 为去重前最大扇出，bytes.ops BytesNextCapacity 按此限界回缩，小目录<64 避免 BYTES_BUILDER_MIN_GROW=64 预分配浪费；零拷贝 Move 单源 }
  SetLength(LCurs, Length(FList));
  LTotal := 0;
  for I := 0 to High(FList) do
  begin
    try LCurs[I] := FList[I].List(ADirPath);
    except on E: EVfsNotFound do Continue; on E: EVfsNotADirectory do Continue; end;
    Inc(LTotal, Length(LCurs[I]));
    { 契约：各后端 List 已有序（os VfsSortEntries、memtree/embedded 有序枚举单源），归并前不二次排序以守零额外 O(k log k)；若需强保序可在此对 LCurs[I] VfsSortEntries（bytes.ops 单源 inline） }
  end;
  if LTotal = 0 then
  begin
    Result := nil;
    CacheList(ADirPath, Result);
    Exit(nil);
  end;
  SetLength(Idx, Length(LCurs));
  for I := 0 to High(Idx) do Idx[I] := 0;
  { 头 Span 缓存初始化：每层头元素 FromStr 零拷贝视图（TByteSpan 直指 string 存储，无 Copy），BestSpan 视图免 string 拷贝，长目录热点路径比较每轮 2m 次构造→每元素 1 次，inline 零拷贝 }
  SetLength(CurSpans, Length(LCurs));
  for I := 0 to High(LCurs) do
    if Length(LCurs[I]) > 0 then
      CurSpans[I] := TByteSpan.FromStr(LCurs[I][0].Name) { bytes.ops 单源 inline 零拷贝 }
    else
      CurSpans[I] := TByteSpan.Empty;
  Result := nil;
  OutN := 0;
  { k 路归并：O(k·m)（m=层数，常量 2~3）零哈希零额外堆，仅 Result 按 LTotal 指数扩容（OverlayEnsureCapEntries 单源，<64 回缩）；SpanCompare/SpanEqual 零拷贝 inline via bytes.ops 单源（CurSpans 缓存+BestSpan 视图），去重后已有序免 VfsSortEntries }
  while True do
  begin
    BestIdx := -1;
    BestLayer := -1;
    BestSpan := TByteSpan.Empty;
    for I := 0 to High(LCurs) do
    begin
      if Idx[I] >= Length(LCurs[I]) then Continue;
      if BestIdx = -1 then
      begin
        BestIdx := I;
        BestLayer := I;
        BestSpan := CurSpans[I]; { 零拷贝视图赋值，无 string 拷贝/refcnt }
      end
      else
      begin
        Lcmp := SpanCompare(CurSpans[I], BestSpan); { bytes.ops 单源 inline 零拷贝，长目录热点路径零额外 Span 构造 }
        if Lcmp < 0 then
        begin
          BestIdx := I;
          BestLayer := I;
          BestSpan := CurSpans[I];
        end
        else if Lcmp = 0 then
        begin
          if I < BestLayer then BestLayer := I;
        end;
      end;
    end;
    if BestIdx = -1 then Break;
    OverlayEnsureCapEntries(Result, OutN + 1, LTotal);
    Result[OutN] := LCurs[BestLayer][Idx[BestLayer]];
    Inc(OutN);
    for I := 0 to High(LCurs) do
      if (Idx[I] < Length(LCurs[I])) and SpanEqual(CurSpans[I], BestSpan) then { bytes.ops SpanEqual 单源 inline，Len 短路+Memequal，免 SpanCompare 全比较 }
      begin
        Inc(Idx[I]);
        if Idx[I] < Length(LCurs[I]) then
          CurSpans[I] := TByteSpan.FromStr(LCurs[I][Idx[I]].Name) { 推进时单次 FromStr 零拷贝更新，每元素 1 次 }
        else
          CurSpans[I] := TByteSpan.Empty;
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
  { 已归并有序，无需二次 VfsSortEntries；bytes.ops 单源 VfsNameCompare 零拷贝已在归并中承载 }
  CacheList(ADirPath, Result);
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
