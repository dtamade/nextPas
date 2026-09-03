unit nextpas.core.vfs.decorator;

{** @desc decorator 族聚合：transform + compressed 单点收口（L3 单缝装饰器族，Registry 单缝白名单过渡、L7 拆分为独立族后移除白名单；复用 bytes.ops 单源 inline 零拷贝，CONTRACT 单源，try-finally 不丢）。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.vfs.base,
  nextpas.core.vfs.intf,
  nextpas.core.vfs.transform,
  nextpas.core.vfs.compressed;

type
  TVfsTransformFunc = nextpas.core.vfs.transform.TVfsTransformFunc;
  TVfsShouldTransformFunc = nextpas.core.vfs.transform.TVfsShouldTransformFunc;
  TVfsHeaderPredicateFunc = nextpas.core.vfs.transform.TVfsHeaderPredicateFunc;
  TDecompressAlgo = nextpas.core.vfs.compressed.TDecompressAlgo;

const
  VFS_DECOMPRESS_MAX_BYTES = nextpas.core.vfs.base.VFS_DECOMPRESS_MAX_BYTES;

function CreateTransformingVfs(const AInner: IVfs;
  const ATransform: TVfsTransformFunc;
  const AShould: TVfsShouldTransformFunc = nil): IVfs; overload; inline;
function CreateTransformingVfs(const AInner: IVfs;
  const ATransform: TVfsTransformFunc;
  const AShould: TVfsShouldTransformFunc;
  const AHeaderPred: TVfsHeaderPredicateFunc): IVfs; overload; inline;
function CreateDecompressingVfs(const AInner: IVfs;
  const AAlgo: TDecompressAlgo = daAuto): IVfs; inline;

implementation

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

function CreateDecompressingVfs(const AInner: IVfs;
  const AAlgo: TDecompressAlgo): IVfs;
begin
  Result := nextpas.core.vfs.compressed.CreateDecompressingVfs(AInner, AAlgo);
end;

end.
