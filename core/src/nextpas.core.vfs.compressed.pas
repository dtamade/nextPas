unit nextpas.core.vfs.compressed;

{** @desc L3 解压薄门面：经通用 transform 单缝装饰器承载 gzip 解压（ADR 0003，L3 单缝寄居 L2 家族正名，Registry 单缝白名单过渡，L7 到期聚合为 nextpas.core.vfs.decorator 独立 L3 族后移除白名单固化 L0-L3 单向，复用阻塞候选已显式标注独立族）。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.vfs.base,
  nextpas.core.vfs.intf;

type
  { 单源别名：复用 vfs.base 契约词汇（枚举值 daAuto/daGzip 单源声明于 vfs.base，
    纯门面消费者经门面 uses 链直接可见，无二次声明无二义）。 }
  TDecompressAlgo = nextpas.core.vfs.base.TDecompressAlgo;

const
  { 单源别名：复用 vfs.base 32MiB（canonical 为 compress.base GZIP_MAX）。 }
  VFS_DECOMPRESS_MAX_BYTES = nextpas.core.vfs.base.VFS_DECOMPRESS_MAX_BYTES;

function CreateDecompressingVfs(const AInner: IVfs;
  const AAlgo: TDecompressAlgo = daAuto): IVfs;

implementation

uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.exception,
  nextpas.core.io.intf,
  nextpas.core.io.memory,
  nextpas.core.vfs.errors,
  nextpas.core.vfs.transform,
  nextpas.core.vfs.util,
  nextpas.core.compress.gzip;

function GzipTransform(const AData: TBytes): TBytes; inline;
begin
  Result := nextpas.core.compress.gzip.GzipDecompressWithMaxOutputSize(AData, VFS_DECOMPRESS_MAX_BYTES);
end;

function IsGzipPred(const AData: TBytes): Boolean; inline;
begin
  // bytes.ops 单源：零拷贝 inline 魔数判定，复用 BytesIsGzip
  Result := nextpas.core.bytes.ops.BytesIsGzip(AData);
end;

function IsGzipHeaderPred(const AHeader: TBytes; const ATotalSize: Int64): Boolean; inline;
begin
  // bytes.ops 单源：4K HeaderPred 零拷贝 inline，复用 BytesIsGzipHeader 单源
  Result := nextpas.core.bytes.ops.BytesIsGzipHeader(AHeader, ATotalSize);
end;

type
  TAutoDecompressingVfs = class(TInterfacedObject, IVfs, IVfsETag)
  private
    FInner: IVfs;
    FTransformVfs: IVfs;
  public
    constructor Create(const AInner: IVfs);
    function Exists(const APath: string): Boolean; inline;
    function Stat(const APath: string): TStatInfo; inline;
    function List(const ADirPath: string): TEntryArray; inline;
    function OpenRead(const APath: string): IStream; inline;
    function CaseSensitive: Boolean; inline;
    function TryGetETag(const APath: string; out AETag: string): Boolean; inline;
    function TryGetLastModified(const APath: string; out ALastModified: string): Boolean; inline;
  end;

constructor TAutoDecompressingVfs.Create(const AInner: IVfs);
begin
  inherited Create;
  FInner := AInner;
  // daAuto 经 transform 4K HeaderPred 承载：Should 全量判定 + HeaderPred 免大文件 Stat 全量 IO，双谓词复用 bytes.ops 单源；零额外IO
  FTransformVfs := CreateTransformingVfs(AInner, @GzipTransform, @IsGzipPred, @IsGzipHeaderPred);
end;

function TAutoDecompressingVfs.Exists(const APath: string): Boolean; inline;
begin
  Result := FInner.Exists(APath);
end;

function TAutoDecompressingVfs.Stat(const APath: string): TStatInfo; inline;
begin
  // single 4K path: 复用 transform.TryPeekHeader/HeaderPred 单源，消除二次 OpenRead/Read/Close；资源释放由 transform 承载
  Result := FTransformVfs.Stat(APath);
end;

function TAutoDecompressingVfs.List(const ADirPath: string): TEntryArray; inline;
begin
  Result := FInner.List(ADirPath);
end;

function TAutoDecompressingVfs.OpenRead(const APath: string): IStream; inline;
begin
  Result := FTransformVfs.OpenRead(APath);
end;

function TAutoDecompressingVfs.CaseSensitive: Boolean; inline;
begin
  Result := FInner.CaseSensitive;
end;

function TAutoDecompressingVfs.TryGetETag(const APath: string; out AETag: string): Boolean; inline;
begin
  AETag := ''; Result := False;
end;

function TAutoDecompressingVfs.TryGetLastModified(const APath: string; out ALastModified: string): Boolean; inline;
var LInnerETag: IVfsETag;
begin
  if FInner.QueryInterface(IVfsETag, LInnerETag) = 0 then Exit(LInnerETag.TryGetLastModified(APath, ALastModified));
  ALastModified := ''; Result := False;
end;

function CreateDecompressingVfs(const AInner: IVfs; const AAlgo: TDecompressAlgo): IVfs;
begin
  if AInner = nil then raise EVfsError.CreateCtx('wrap', '', 'inner VFS is nil');
  case AAlgo of
    daGzip: Result := CreateTransformingVfs(AInner, @GzipTransform, nil, nil);
    daAuto: Result := TAutoDecompressingVfs.Create(AInner);
  else
    Result := CreateTransformingVfs(AInner, @GzipTransform, nil, nil);
  end;
end;

end.
