unit nextpas.core.vfs.compressed;

{** @desc L3 解压薄门面：经通用 transform 装饰器承载 gzip 解压（ADR 0003）。
  本单元仅保留策略（VFS_DECOMPRESS_MAX_BYTES、Gzip 魔数、daAuto/daGzip 语义），
  模板复用 nextpas.core.vfs.transform，消除 120+ 行样板重复（复用度）。
  STORE 零拷贝与 32MiB 防 bomb 约束由 transform 承载；daAuto 经 4K 头部预判避免 Stat 全量读取。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.vfs.intf,
  nextpas.core.compress.base;

type
  TDecompressAlgo = (daAuto, daGzip);

const
  VFS_DECOMPRESS_MAX_BYTES = nextpas.core.compress.base.GZIP_MAX_DECOMPRESS_BYTES;

function CreateDecompressingVfs(const AInner: IVfs;
  const AAlgo: TDecompressAlgo = daAuto): IVfs;

implementation

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.io.intf,
  nextpas.core.io.memory,
  nextpas.core.vfs.base,
  nextpas.core.vfs.errors,
  nextpas.core.vfs.transform,
  nextpas.core.vfs.util,
  nextpas.core.compress;

const
  COMPRESSED_HEADER_PEEK = 4096;

function GzipTransform(const AData: TBytes): TBytes;
begin
  Result := GzipDecompressWithMaxOutputSize(AData, VFS_DECOMPRESS_MAX_BYTES);
end;

function IsGzipPred(const AData: TBytes): Boolean; inline;
begin
  Result := (Length(AData) >= 2) and (AData[0] = GZIP_MAGIC_1) and (AData[1] = GZIP_MAGIC_2);
end;

type
  TAutoDecompressingVfs = class(TInterfacedObject, IVfs, IVfsETag)
  private
    FInner: IVfs;
    FTransformVfs: IVfs;
    function IsGzipHeader(const APath: string): Boolean;
  public
    constructor Create(const AInner: IVfs);
    function Exists(const APath: string): Boolean; inline;
    function Stat(const APath: string): TStatInfo;
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
  FTransformVfs := CreateTransformingVfs(AInner, @GzipTransform, @IsGzipPred);
end;

function TAutoDecompressingVfs.IsGzipHeader(const APath: string): Boolean;
var LStream: IStream; LBuf: array[0..COMPRESSED_HEADER_PEEK-1] of Byte; LRead: SizeUInt; LHeader: TBytes;
begin
  Result := False;
  try
    LStream := FInner.OpenRead(APath);
  except
    on E: Exception do raise EVfsError.CreateCtx('stat', APath, E.Message);
  end;
  LRead := LStream.Read(LBuf[0], COMPRESSED_HEADER_PEEK);
  SetLength(LHeader, LRead);
  if LRead > 0 then Move(LBuf[0], LHeader[0], LRead);
  Result := IsGzipPred(LHeader);
end;

function TAutoDecompressingVfs.Exists(const APath: string): Boolean; inline;
begin
  Result := FInner.Exists(APath);
end;

function TAutoDecompressingVfs.Stat(const APath: string): TStatInfo;
var LInfo: TStatInfo;
begin
  LInfo := FInner.Stat(APath);
  if LInfo.Info.IsDir then Exit(LInfo);
  if not IsGzipHeader(APath) then Exit(LInfo);
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
    daGzip: Result := CreateTransformingVfs(AInner, @GzipTransform, nil);
    daAuto: Result := TAutoDecompressingVfs.Create(AInner);
  else
    Result := CreateTransformingVfs(AInner, @GzipTransform, nil);
  end;
end;

end.
