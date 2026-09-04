unit nextpas.core.vfs;

{** @desc 门面：纯 re-export + inline 薄转发，不含逻辑（design-conventions §2；backends 后端族 + decorator 族双单点聚合、门面扇出收敛 12→10、族完整性保留，bytes.ops 单源 inline 零拷贝，CONTRACT 单源，try-finally 不丢；L7 后端独立族 + L7 装饰器独立族双收口已落地单缝理想）。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.text.view,
  nextpas.core.vfs.base,
  nextpas.core.vfs.errors,
  nextpas.core.vfs.intf,
  nextpas.core.vfs.backends,
  nextpas.core.vfs.sub,
  nextpas.core.vfs.mount,
  nextpas.core.vfs.overlay,
  nextpas.core.vfs.decorator,
  nextpas.core.vfs.util;

type
  { re-export：base/intf/errors/backends/util/decorator/mount/vfs 各族类型与错误类 }
  TBytes = nextpas.core.base.TBytes;
  TEntryInfo = nextpas.core.vfs.base.TEntryInfo;
  TEntryArray = nextpas.core.vfs.base.TEntryArray;
  TStatInfo = nextpas.core.vfs.base.TStatInfo;
  IVfs = nextpas.core.vfs.intf.IVfs;
  IVfsETag = nextpas.core.vfs.intf.IVfsETag;
  IVfsServeMeta = nextpas.core.vfs.intf.IVfsServeMeta;
  IVfsView = nextpas.core.vfs.intf.IVfsView;
  TVfsMemEntry = nextpas.core.vfs.backends.TVfsMemEntry;
  TVfsTreeBuilder = nextpas.core.vfs.backends.TVfsTreeBuilder;
  TVfsVisitProc = nextpas.core.vfs.util.TVfsVisitProc;

  EVfsError = nextpas.core.vfs.errors.EVfsError;
  EVfsNotFound = nextpas.core.vfs.errors.EVfsNotFound;
  EVfsNotADirectory = nextpas.core.vfs.errors.EVfsNotADirectory;
  EVfsIsADirectory = nextpas.core.vfs.errors.EVfsIsADirectory;
  EVfsInvalidPath = nextpas.core.vfs.errors.EVfsInvalidPath;
  EVfsClosed = nextpas.core.vfs.errors.EVfsClosed;

  TVfsTransformFunc = nextpas.core.vfs.decorator.TVfsTransformFunc;
  TVfsShouldTransformFunc = nextpas.core.vfs.decorator.TVfsShouldTransformFunc;
  TVfsHeaderPredicateFunc = nextpas.core.vfs.decorator.TVfsHeaderPredicateFunc;
  TDecompressAlgo = nextpas.core.vfs.decorator.TDecompressAlgo;
  TVfsMountEntry = nextpas.core.vfs.mount.TVfsMountEntry;
  TVfsMountArray = nextpas.core.vfs.mount.TVfsMountArray;

const
  { 单源别名：复用 decorator 32MiB（canonical 为 compress.base GZIP_MAX），无字面量漂移 }
  VFS_DECOMPRESS_MAX_BYTES = nextpas.core.vfs.decorator.VFS_DECOMPRESS_MAX_BYTES;

  { 枚举值单源直通：daAuto/daGzip 唯一声明于 vfs.base，此处同名常量影子别名
    使纯门面消费者可直接命名（单元内遮蔽 imported 标识符合法，与 backends
    重导出 RESPACK_* 同模式）；已同时 uses 原声明单元的作用域内引用须加限定。 }
  daAuto: TDecompressAlgo = nextpas.core.vfs.base.daAuto;
  daGzip: TDecompressAlgo = nextpas.core.vfs.base.daGzip;

{ 工厂/视图/装饰器/辅助 inline 薄转发，零拷贝复用 bytes.ops 单源 }
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
function CreateDecompressingVfs(const AInner: IVfs): IVfs; inline; overload;
function CreateDecompressingVfs(const AInner: IVfs;
  const AAlgo: TDecompressAlgo): IVfs; inline; overload;
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
function VfsExistsView(const AFs: IVfs; const AView: TStringView): Boolean; inline;
function VfsReadAllBytesView(const AFs: IVfs; const AView: TStringView): TBytes; inline;
function VfsReadAllTextView(const AFs: IVfs; const AView: TStringView): string; inline;
procedure VfsWalk(const AFs: IVfs; const ARoot: string;
  const AVisit: TVfsVisitProc); inline;

implementation

{ 薄转发：inline 单源委托，零额外分配，资源释放由 owner（memtree/embedded/os）持有不丢 }

function CreateMemTreeVfs(AItems: array of TVfsMemEntry): IVfs;
begin
  Result := nextpas.core.vfs.backends.CreateMemTreeVfs(AItems);
end;

function CreateOsVfs(const ARoot: string): IVfs;
begin
  Result := nextpas.core.vfs.backends.CreateOsVfs(ARoot);
end;

function CreateEmbeddedVfsOwned(AData: PByte; ASize: SizeUInt): IVfs;
begin
  Result := nextpas.core.vfs.backends.CreateEmbeddedVfsOwned(AData, ASize);
end;

function CreateEmbeddedVfsBorrowed(AData: PByte; ASize: SizeUInt): IVfs;
begin
  Result := nextpas.core.vfs.backends.CreateEmbeddedVfsBorrowed(AData, ASize);
end;

function CreateSubVfs(const ABase: IVfs; const ASubRoot: string): IVfs;
begin
  Result := nextpas.core.vfs.sub.CreateSubVfs(ABase, ASubRoot);
end;

function CreateTransformingVfs(const AInner: IVfs;
  const ATransform: TVfsTransformFunc;
  const AShould: TVfsShouldTransformFunc): IVfs;
begin
  Result := nextpas.core.vfs.decorator.CreateTransformingVfs(AInner, ATransform, AShould);
end;

function CreateTransformingVfs(const AInner: IVfs;
  const ATransform: TVfsTransformFunc;
  const AShould: TVfsShouldTransformFunc;
  const AHeaderPred: TVfsHeaderPredicateFunc): IVfs;
begin
  Result := nextpas.core.vfs.decorator.CreateTransformingVfs(AInner, ATransform, AShould, AHeaderPred);
end;

function CreateDecompressingVfs(const AInner: IVfs): IVfs;
begin
  Result := nextpas.core.vfs.decorator.CreateDecompressingVfs(AInner);
end;

function CreateDecompressingVfs(const AInner: IVfs;
  const AAlgo: TDecompressAlgo): IVfs;
begin
  Result := nextpas.core.vfs.decorator.CreateDecompressingVfs(AInner, AAlgo);
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

function VfsExistsView(const AFs: IVfs; const AView: TStringView): Boolean;
begin
  Result := nextpas.core.vfs.util.VfsExistsView(AFs, AView);
end;

function VfsReadAllBytesView(const AFs: IVfs; const AView: TStringView): TBytes;
begin
  Result := nextpas.core.vfs.util.VfsReadAllBytesView(AFs, AView);
end;

function VfsReadAllTextView(const AFs: IVfs; const AView: TStringView): string;
begin
  Result := nextpas.core.vfs.util.VfsReadAllTextView(AFs, AView);
end;

procedure VfsWalk(const AFs: IVfs; const ARoot: string;
  const AVisit: TVfsVisitProc);
begin
  nextpas.core.vfs.util.VfsWalk(AFs, ARoot, AVisit);
end;

end.
