unit nextpas.core.vfs;

{** @desc 门面：纯 re-export + inline 薄转发，不含逻辑（design-conventions §2，182 行≈22% 800 阈值，13 子模块聚合为族完整性，扇出度高但阈值内；后续decorator独立族L7拆分可降门面耦合与阈值压力，inline 零拷贝复用 bytes.ops 单源，CONTRACT 单源，try-finally 不丢）。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.vfs.base,
  nextpas.core.vfs.errors,
  nextpas.core.vfs.intf,
  nextpas.core.vfs.memtree,
  nextpas.core.vfs.os,
  nextpas.core.vfs.embedded,
  nextpas.core.vfs.sub,
  nextpas.core.vfs.mount,
  nextpas.core.vfs.overlay,
  nextpas.core.vfs.transform,
  nextpas.core.vfs.compressed,
  nextpas.core.vfs.util;

type
  { re-export 8 别名：base/intf/errors/memtree/util/transform/mount }
  TEntryInfo = nextpas.core.vfs.base.TEntryInfo;
  TEntryArray = nextpas.core.vfs.base.TEntryArray;
  TStatInfo = nextpas.core.vfs.base.TStatInfo;
  IVfs = nextpas.core.vfs.intf.IVfs;
  IVfsETag = nextpas.core.vfs.intf.IVfsETag;
  IVfsServeMeta = nextpas.core.vfs.intf.IVfsServeMeta;
  TVfsMemEntry = nextpas.core.vfs.memtree.TVfsMemEntry;
  TVfsTreeBuilder = nextpas.core.vfs.memtree.TVfsTreeBuilder;
  TVfsVisitProc = nextpas.core.vfs.util.TVfsVisitProc;

  EVfsError = nextpas.core.vfs.errors.EVfsError;
  EVfsNotFound = nextpas.core.vfs.errors.EVfsNotFound;
  EVfsNotADirectory = nextpas.core.vfs.errors.EVfsNotADirectory;
  EVfsIsADirectory = nextpas.core.vfs.errors.EVfsIsADirectory;
  EVfsInvalidPath = nextpas.core.vfs.errors.EVfsInvalidPath;
  EVfsClosed = nextpas.core.vfs.errors.EVfsClosed;

  TVfsTransformFunc = nextpas.core.vfs.transform.TVfsTransformFunc;
  TVfsShouldTransformFunc = nextpas.core.vfs.transform.TVfsShouldTransformFunc;
  TVfsHeaderPredicateFunc = nextpas.core.vfs.transform.TVfsHeaderPredicateFunc;
  TVfsMountEntry = nextpas.core.vfs.mount.TVfsMountEntry;

{ 工厂/视图/装饰器/辅助 15 inline 薄转发，零拷贝复用 bytes.ops 单源 }
function CreateMemTreeVfs(AItems: array of TVfsMemEntry): IVfs; inline;
function CreateOsVfs(const ARoot: string): IVfs; inline;
function CreateEmbeddedVfsOwned(AData: PByte; ASize: SizeUInt): IVfs; inline;
function CreateEmbeddedVfsBorrowed(AData: PByte; ASize: SizeUInt): IVfs; inline;
function CreateSubVfs(const ABase: IVfs; const ASubRoot: string): IVfs; inline;
function CreateTransformingVfs(const AInner: IVfs;
  const ATransform: TVfsTransformFunc;
  const AShould: TVfsShouldTransformFunc = nil): IVfs; inline; overload;
function CreateTransformingVfs(const AInner: IVfs;
  const ATransform: TVfsTransformFunc;
  const AShould: TVfsShouldTransformFunc;
  const AHeaderPred: TVfsHeaderPredicateFunc): IVfs; inline; overload;
function CreateDecompressingVfs(const AInner: IVfs): IVfs; inline;
function VfsMountEntry(const APrefix: string; const AFs: IVfs): TVfsMountEntry; inline;
function CreateMountedVfs(const AMounts: array of TVfsMountEntry): IVfs; inline;
function CreateOverlayVfs(const AList: array of IVfs): IVfs; inline;

function VfsValidPath(const APath: string; const AAllowRoot: Boolean): Boolean; inline;
function VfsIsRoot(const APath: string): Boolean; inline;
function VfsNameCompare(const AA, AB: string): Integer; inline;
procedure VfsSortEntries(var AItems: TEntryArray); inline;

function VfsStat(const AFs: IVfs; const APath: string): TStatInfo; inline;
function VfsList(const AFs: IVfs; const ADirPath: string): TEntryArray; inline;
function VfsReadAllBytes(const AFs: IVfs; const APath: string): TBytes; inline;
function VfsReadAllText(const AFs: IVfs; const APath: string): string; inline;
procedure VfsWalk(const AFs: IVfs; const ARoot: string;
  const AVisit: TVfsVisitProc); inline;

implementation

{ 薄转发：inline 单源委托，零额外分配，资源释放由 owner（memtree/embedded/os）持有不丢 }

function CreateMemTreeVfs(AItems: array of TVfsMemEntry): IVfs;
begin
  Result := nextpas.core.vfs.memtree.CreateMemTreeVfs(AItems);
end;

function CreateOsVfs(const ARoot: string): IVfs;
begin
  Result := nextpas.core.vfs.os.CreateOsVfs(ARoot);
end;

function CreateEmbeddedVfsOwned(AData: PByte; ASize: SizeUInt): IVfs;
begin
  Result := nextpas.core.vfs.embedded.CreateEmbeddedVfsOwned(AData, ASize);
end;

function CreateEmbeddedVfsBorrowed(AData: PByte; ASize: SizeUInt): IVfs;
begin
  Result := nextpas.core.vfs.embedded.CreateEmbeddedVfsBorrowed(AData, ASize);
end;

function CreateSubVfs(const ABase: IVfs; const ASubRoot: string): IVfs;
begin
  Result := nextpas.core.vfs.sub.CreateSubVfs(ABase, ASubRoot);
end;

function CreateTransformingVfs(const AInner: IVfs;
  const ATransform: TVfsTransformFunc;
  const AShould: TVfsShouldTransformFunc): IVfs;
begin
  Result := nextpas.core.vfs.transform.CreateTransformingVfs(AInner, ATransform, AShould);
end;

function CreateTransformingVfs(const AInner: IVfs;
  const ATransform: TVfsTransformFunc;
  const AShould: TVfsShouldTransformFunc;
  const AHeaderPred: TVfsHeaderPredicateFunc): IVfs;
begin
  Result := nextpas.core.vfs.transform.CreateTransformingVfs(AInner, ATransform, AShould, AHeaderPred);
end;

function CreateDecompressingVfs(const AInner: IVfs): IVfs;
begin
  Result := nextpas.core.vfs.compressed.CreateDecompressingVfs(AInner);
end;

function VfsMountEntry(const APrefix: string; const AFs: IVfs): TVfsMountEntry;
begin
  Result := nextpas.core.vfs.mount.VfsMountEntry(APrefix, AFs);
end;

function CreateMountedVfs(const AMounts: array of TVfsMountEntry): IVfs;
begin
  Result := nextpas.core.vfs.mount.CreateMountedVfs(AMounts);
end;

function CreateOverlayVfs(const AList: array of IVfs): IVfs;
begin
  Result := nextpas.core.vfs.overlay.CreateOverlayVfs(AList);
end;

function VfsValidPath(const APath: string; const AAllowRoot: Boolean): Boolean;
begin
  Result := nextpas.core.vfs.base.VfsValidPath(APath, AAllowRoot);
end;

function VfsIsRoot(const APath: string): Boolean;
begin
  Result := nextpas.core.vfs.base.VfsIsRoot(APath);
end;

function VfsNameCompare(const AA, AB: string): Integer;
begin
  Result := nextpas.core.vfs.base.VfsNameCompare(AA, AB);
end;

procedure VfsSortEntries(var AItems: TEntryArray);
begin
  nextpas.core.vfs.base.VfsSortEntries(AItems);
end;

function VfsStat(const AFs: IVfs; const APath: string): TStatInfo;
begin
  Result := nextpas.core.vfs.util.VfsStat(AFs, APath);
end;

function VfsList(const AFs: IVfs; const ADirPath: string): TEntryArray;
begin
  Result := nextpas.core.vfs.util.VfsList(AFs, ADirPath);
end;

function VfsReadAllBytes(const AFs: IVfs; const APath: string): TBytes;
begin
  Result := nextpas.core.vfs.util.VfsReadAllBytes(AFs, APath);
end;

function VfsReadAllText(const AFs: IVfs; const APath: string): string;
begin
  Result := nextpas.core.vfs.util.VfsReadAllText(AFs, APath);
end;

procedure VfsWalk(const AFs: IVfs; const ARoot: string;
  const AVisit: TVfsVisitProc);
begin
  nextpas.core.vfs.util.VfsWalk(AFs, ARoot, AVisit);
end;

end.
