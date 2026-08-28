unit nextpas.core.vfs.compressed;

{** @desc L3 解压薄门面：经通用 transform 装饰器承载 gzip 解压（ADR 0003）。
  本单元仅保留策略（VFS_DECOMPRESS_MAX_BYTES、Gzip 魔数、daAuto/daGzip 语义），
  模板复用 nextpas.core.vfs.transform，消除 120+ 行样板重复（复用度）。
  STORE 零拷贝与 32MiB 防 bomb 约束由 transform 承载。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.vfs.intf;

type
  TDecompressAlgo = (daAuto, daGzip);

const
  VFS_DECOMPRESS_MAX_BYTES = 32 * 1024 * 1024;

function CreateDecompressingVfs(const AInner: IVfs;
  const AAlgo: TDecompressAlgo = daAuto): IVfs;

implementation

uses
  nextpas.core.base,
  nextpas.core.vfs.errors,
  nextpas.core.vfs.transform,
  nextpas.core.compress;

function GzipTransform(const AData: TBytes): TBytes;
begin
  Result := GzipDecompressWithMaxOutputSize(AData, VFS_DECOMPRESS_MAX_BYTES);
end;

function IsGzipPred(const AData: TBytes): Boolean; inline;
begin
  Result := (Length(AData) >= 2) and (AData[0] = $1F) and (AData[1] = $8B);
end;

function CreateDecompressingVfs(const AInner: IVfs; const AAlgo: TDecompressAlgo): IVfs;
begin
  if AInner = nil then raise EVfsError.CreateCtx('wrap', '', 'inner VFS is nil');
  case AAlgo of
    daGzip: Result := CreateTransformingVfs(AInner, @GzipTransform, nil);
    daAuto: Result := CreateTransformingVfs(AInner, @GzipTransform, @IsGzipPred);
  else
    Result := CreateTransformingVfs(AInner, @GzipTransform, nil);
  end;
end;

end.
