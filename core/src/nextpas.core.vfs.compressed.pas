unit nextpas.core.vfs.compressed;

{** @desc L3 装饰器：为任意 IVfs 提供解压视图（ADR 0003）。
  内层 VFS 保持 STORE 零拷贝，压缩由本装饰器按需解压承载，避免 L2→L2 闭环。
  v1 支持 Gzip（0x1F 0x8B 魔数探测），后续可扩展 Deflate/LZ4/ZSTD 为 TDecompressAlgo。
  语义：Exists/List/CaseSensitive 透传；Stat 对压缩文件返回解压后 Size（ContentHash 清零
  以防 ETag 误用）；OpenRead 对压缩文件返回解压后内存流，非压缩文件零拷贝透传内层流。
  安全：解压前后设 32 MiB 上限，防 zip bomb；异常统一包装为 EVfsError 带路径上下文。 }

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
  nextpas.core.exception,
  nextpas.core.io.intf,
  nextpas.core.io.memory,
  nextpas.core.vfs.base,
  nextpas.core.vfs.errors,
  nextpas.core.vfs.util,
  nextpas.core.compress;

type
  TDecompressingVfs = class(TInterfacedObject, IVfs, IVfsETag)
  private
    FInner: IVfs;
    FAlgo: TDecompressAlgo;
    function IsGzip(const AData: TBytes): Boolean; inline;
    function DoDecompress(const AData: TBytes): TBytes; inline;
  public
    constructor Create(const AInner: IVfs; const AAlgo: TDecompressAlgo);
    function Exists(const APath: string): Boolean;
    function Stat(const APath: string): TStatInfo;
    function List(const ADirPath: string): TEntryArray;
    function OpenRead(const APath: string): IStream;
    function CaseSensitive: Boolean;
    function TryGetETag(const APath: string; out AETag: string): Boolean;
    function TryGetLastModified(const APath: string;
      out ALastModified: string): Boolean;
  end;

function CreateDecompressingVfs(const AInner: IVfs;
  const AAlgo: TDecompressAlgo): IVfs;
begin
  if AInner = nil then
    raise EVfsError.CreateCtx('wrap', '', 'inner VFS is nil');
  Result := TDecompressingVfs.Create(AInner, AAlgo);
end;

constructor TDecompressingVfs.Create(const AInner: IVfs;
  const AAlgo: TDecompressAlgo);
begin
  inherited Create;
  FInner := AInner;
  FAlgo := AAlgo;
end;

function TDecompressingVfs.IsGzip(const AData: TBytes): Boolean; inline;
begin
  Result := (Length(AData) >= 2) and (AData[0] = $1F) and (AData[1] = $8B);
end;

function TDecompressingVfs.DoDecompress(const AData: TBytes): TBytes; inline;
begin
  case FAlgo of
    daGzip:
      Result := GzipDecompressWithMaxOutputSize(AData, VFS_DECOMPRESS_MAX_BYTES);
    daAuto:
      if IsGzip(AData) then
        Result := GzipDecompressWithMaxOutputSize(AData, VFS_DECOMPRESS_MAX_BYTES)
      else
        Result := AData;
  else
    Result := AData;
  end;
end;

function TDecompressingVfs.Exists(const APath: string): Boolean;
begin
  Result := FInner.Exists(APath);
end;

function TDecompressingVfs.Stat(const APath: string): TStatInfo;
var
  LInfo: TStatInfo;
  LData: TBytes;
  LDecomp: TBytes;
begin
  LInfo := FInner.Stat(APath);
  if LInfo.Info.IsDir then
    Exit(LInfo);
  // 目录不解压；文件按算法重算 Size
  try
    LData := VfsReadAllBytes(FInner, APath);
  except
    on E: Exception do
      raise EVfsError.CreateCtx('stat', APath, E.Message);
  end;
  if FAlgo = daGzip then
  begin
    try
      LDecomp := GzipDecompressWithMaxOutputSize(LData, VFS_DECOMPRESS_MAX_BYTES);
    except
      on E: Exception do
        raise EVfsError.CreateCtx('stat', APath, 'gzip decompress failed: ' + E.Message);
    end;
    LInfo.Info.Size := Int64(Length(LDecomp));
    LInfo.ContentHash := 0;
    Exit(LInfo);
  end;
  // daAuto：仅对 gzip 魔数文件重算
  if IsGzip(LData) then
  begin
    try
      LDecomp := GzipDecompressWithMaxOutputSize(LData, VFS_DECOMPRESS_MAX_BYTES);
    except
      on E: Exception do
        raise EVfsError.CreateCtx('stat', APath, 'gzip decompress failed: ' + E.Message);
    end;
    LInfo.Info.Size := Int64(Length(LDecomp));
    LInfo.ContentHash := 0;
  end;
  Result := LInfo;
end;

function TDecompressingVfs.List(const ADirPath: string): TEntryArray;
begin
  Result := FInner.List(ADirPath);
end;

function TDecompressingVfs.OpenRead(const APath: string): IStream;
var
  LData: TBytes;
  LDecomp: TBytes;
begin
  try
    LData := VfsReadAllBytes(FInner, APath);
  except
    on E: Exception do
      raise EVfsError.CreateCtx('open', APath, E.Message);
  end;
  try
    LDecomp := DoDecompress(LData);
  except
    on E: Exception do
      raise EVfsError.CreateCtx('open', APath, 'gzip decompress failed: ' + E.Message);
  end;
  if Pointer(LDecomp) = Pointer(LData) then
  begin
    // 未压缩：透传内层流，保留零拷贝
    Result := FInner.OpenRead(APath);
    Exit;
  end;
  Result := CreateBytesStreamFrom(LDecomp);
end;

function TDecompressingVfs.CaseSensitive: Boolean;
begin
  Result := FInner.CaseSensitive;
end;

function TDecompressingVfs.TryGetETag(const APath: string;
  out AETag: string): Boolean;
begin
  // 解压后内容与存储 ETag 不一致，禁用预计算路径，迫使上层按解压后内容重算
  AETag := '';
  Result := False;
end;

function TDecompressingVfs.TryGetLastModified(const APath: string;
  out ALastModified: string): Boolean;
var
  LInnerETag: IVfsETag;
begin
  // Last-Modified 与压缩无关，透传内层
  if FInner.QueryInterface(IVfsETag, LInnerETag) = 0 then
    Exit(LInnerETag.TryGetLastModified(APath, ALastModified));
  ALastModified := '';
  Result := False;
end;

end.
