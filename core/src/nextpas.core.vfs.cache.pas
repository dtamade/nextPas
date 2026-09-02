unit nextpas.core.vfs.cache;

{** @desc vfs 热点 List 缓存单源 helper：SwissTable 16槽 + RWLock 读并发零争用 + 阻塞写 + Copy隔离。
  单源收口 mount/overlay 的热点目录缓存（TryGet/Put）：SwissTable 单源、RWLock 单源、bytes.ops 外零拷贝、Copy O(k) Move 隔离防篡改。
  写路径采用阻塞 AcquireWrite（非 TryAcquireWrite），避免抢锁失败丢弃缓存导致的重复 O(k log k) Sort/Dedup。
  inline 热路径 + try-finally 资源不丢 + 析构 Free 不丢。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.vfs.base,
  nextpas.core.collections.hashmap.swiss.str,
  nextpas.core.sync;

const
  VFS_LIST_CACHE_CAP = 16;

type
  TVfsListCache = class
  private
    FTable: specialize TSwissTableStr<TEntryArray>;
    FLock: IRWLock;
  public
    constructor Create(const ACap: SizeUInt = VFS_LIST_CACHE_CAP);
    destructor Destroy; override;
    { 热点读：RWLock 读并发零争用，inline 热路径，SwissTable O(1) 哈希 + O(k) Copy 隔离（Move） }
    function TryGet(const APath: string; out AEntries: TEntryArray): Boolean; inline;
    { 热点写：阻塞 AcquireWrite 单源，Copy 隔离 Put，防惊群重复 Sort/Dedup；inline  }
    procedure Put(const APath: string; const AEntries: TEntryArray); inline;
  end;

implementation

constructor TVfsListCache.Create(const ACap: SizeUInt);
begin
  inherited Create;
  FTable := specialize TSwissTableStr<TEntryArray>.Create(ACap);
  FLock := RWLock;
end;

destructor TVfsListCache.Destroy;
begin
  if FTable <> nil then
  begin
    FTable.Free;
    FTable := nil;
  end;
  FLock := nil;
  inherited Destroy;
end;

function TVfsListCache.TryGet(const APath: string; out AEntries: TEntryArray): Boolean; inline;
var
  LCached: TEntryArray;
begin
  AEntries := nil;
  Result := False;
  if (FTable = nil) or (FLock = nil) then Exit;
  FLock.AcquireRead;
  try
    if FTable.TryGetValue(APath, LCached) then
    begin
      AEntries := Copy(LCached); { 隔离拷贝 O(k) Move，防调用方篡改共享缓存，bytes.ops 外零额外分配 }
      Result := True;
    end;
  finally
    FLock.ReleaseRead;
  end;
end;

procedure TVfsListCache.Put(const APath: string; const AEntries: TEntryArray); inline;
var
  LDummy: TEntryArray;
begin
  if (FTable = nil) or (FLock = nil) then Exit;
  FLock.AcquireWrite; { 阻塞写：抢锁失败不丢弃，避免热点并发下重复 O(k log k) Sort/Dedup； TryAcquireWrite 已退役 }
  try
    if FTable.TryGetValue(APath, LDummy) then Exit;
    FTable.Put(APath, Copy(AEntries)); { Copy 隔离 }
  finally
    FLock.ReleaseWrite;
  end;
end;

end.
