unit nextpas.core.vfs.backends;

{** @desc vfs 后端聚合：三后端单缝收口（L2→L2 单点 seam）。
  L2 双缝过渡期（os→fs 与 embedded→respack.reader）经此单元统一收口——
  仅此单元持有跨模块 L2 依赖（fs / respack.reader），embedded 经此单缝间接复用，
  消除 L2 同层多点直连；source-contract 以此为单点门禁，门面经此扇出收敛至单缝理想。
  bytes.ops 单源 inline 零拷贝，try-finally 资源不丢。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.vfs.intf,
  nextpas.core.respack.base,
  nextpas.core.respack.reader,
  nextpas.core.vfs.memtree;

type
  // Respack 视图重导出：embedded 经此单缝复用，不直连 reader
  TResPack = nextpas.core.respack.reader.TResPack;
  TResPackEntry = nextpas.core.respack.base.TResPackEntry;
  TResPackHeader = nextpas.core.respack.base.TResPackHeader;
  // Memtree 视图重导出：门面经此单缝收口
  TVfsMemEntry = nextpas.core.vfs.memtree.TVfsMemEntry;
  TVfsTreeBuilder = nextpas.core.vfs.memtree.TVfsTreeBuilder;

const
  RESPACK_EFLAG_HASHED = nextpas.core.respack.base.RESPACK_EFLAG_HASHED;
  RESPACK_EFLAG_KNOWN  = nextpas.core.respack.base.RESPACK_EFLAG_KNOWN;
  RESPACK_CODEC_STORE  = nextpas.core.respack.base.RESPACK_CODEC_STORE;
  RESPACK_ENTRY_SIZE   = nextpas.core.respack.base.RESPACK_ENTRY_SIZE;
  RESPACK_DATA_ALIGN   = nextpas.core.respack.base.RESPACK_DATA_ALIGN;

function CreateMemTreeVfs(AItems: array of TVfsMemEntry): IVfs; inline;
function CreateOsVfs(const ARoot: string): IVfs; inline;
function CreateEmbeddedVfsOwned(AData: PByte; ASize: SizeUInt): IVfs; inline;
function CreateEmbeddedVfsBorrowed(AData: PByte; ASize: SizeUInt): IVfs; inline;

implementation

uses
  nextpas.core.vfs.embedded,
  nextpas.core.vfs.os;

function CreateMemTreeVfs(AItems: array of TVfsMemEntry): IVfs; inline;
begin
  Result := nextpas.core.vfs.memtree.CreateMemTreeVfs(AItems);
end;

function CreateOsVfs(const ARoot: string): IVfs; inline;
begin
  Result := nextpas.core.vfs.os.CreateOsVfs(ARoot);
end;

function CreateEmbeddedVfsOwned(AData: PByte; ASize: SizeUInt): IVfs; inline;
begin
  Result := nextpas.core.vfs.embedded.CreateEmbeddedVfsOwned(AData, ASize);
end;

function CreateEmbeddedVfsBorrowed(AData: PByte; ASize: SizeUInt): IVfs; inline;
begin
  Result := nextpas.core.vfs.embedded.CreateEmbeddedVfsBorrowed(AData, ASize);
end;

end.
