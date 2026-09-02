unit nextpas.core.compress;
{**
 * @desc 压缩门面：Gzip、Deflate、LZ4、Zlib。
 * @note Tar 已晋升独立 L2 nextpas.core.tar 并完成单源收敛：兼容薄转发 nextpas.core.compress.tar 已删除（空存根已移除），本门面不再 re-export Tar 以守 L2→L0-L1 依赖（见 module-registry 与 docs/tar/CONTRACT.md）。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.compress.base,
  nextpas.core.compress.intf,
  nextpas.core.compress.deflate,
  nextpas.core.compress.gzip,
  nextpas.core.compress.zstd
  {$IFDEF NEXTPAS_USE_LZ4_NATIVE}
  , nextpas.core.compress.lz4.native
  {$ENDIF}
  {$IFNDEF NEXTPAS_USE_LZ4_NATIVE}
  , nextpas.core.compress.lz4
  {$ENDIF}
  ;

type
  TCompressionLevel = nextpas.core.compress.base.TCompressionLevel;
  ICompressWriter = nextpas.core.compress.intf.ICompressWriter;
  IDecompressReader = nextpas.core.compress.intf.IDecompressReader;

function DeflateWriter(const ADst: IWriter;
  const ALevel: TCompressionLevel = clDefault): ICompressWriter; inline;
function DeflateReader(const ASrc: IReader): IDecompressReader; inline;
function DeflateReaderWithMaxOutputSize(const ASrc: IReader;
  const AMaxOutputSize: SizeUInt): IDecompressReader; inline;
function GzipWriter(const ADst: IWriter;
  const ALevel: TCompressionLevel = clDefault): ICompressWriter; inline;
function GzipReader(const ASrc: IReader): IDecompressReader; inline;
function GzipReaderWithMaxOutputSize(const ASrc: IReader;
  const AMaxOutputSize: SizeUInt): IDecompressReader; inline;
function DeflateCompress(const AData: TBytes;
  const ALevel: TCompressionLevel = clDefault): TBytes; inline;
function DeflateDecompress(const AData: TBytes): TBytes; inline;
function DeflateDecompressWithMaxOutputSize(const AData: TBytes;
  const AMaxOutputSize: SizeUInt): TBytes; inline;
function DeflateDecompressWithEndPos(const AData: TBytes; AStart: SizeUInt;
  out AEndPos: SizeUInt): TBytes; inline;
function DeflateDecompressPtrWithEndPos(AData: PByte; ACount, AStart: SizeUInt;
  out AEndPos: SizeUInt): TBytes; inline;
function RawDeflateCompress(const AData: TBytes;
  const ALevel: TCompressionLevel = clDefault): TBytes; inline;
function RawDeflateDecompress(const AData: TBytes): TBytes; inline;
function RawDeflateDecompressWithMaxOutputSize(const AData: TBytes;
  const AMaxOutputSize: SizeUInt): TBytes; inline;
function RawDeflateDecompressSized(const AData: TBytes;
  const AExpectedOutputSize, AMaxOutputSize: SizeUInt): TBytes; inline;
function RawDeflateDecompressToBuffer(const AData: TBytes; const ADst: PByte;
  const ADstLen: SizeUInt; const AMaxOutputSize: SizeUInt): SizeUInt; inline;
function RawDeflateMessageCompress(const AData: TBytes;
  const ALevel: TCompressionLevel = clDefault): TBytes; inline;
function RawDeflateMessageDecompress(const AData: TBytes;
  const AMaxOutputSize: SizeUInt): TBytes; inline;
function DeflateRawCompress(const AData: TBytes;
  const ALevel: TCompressionLevel = clDefault): TBytes; inline;
function GzipCompress(const AData: TBytes;
  const ALevel: TCompressionLevel = clDefault): TBytes; inline;
function GzipDecompress(const AData: TBytes): TBytes; inline;
function GzipDecompressWithMaxOutputSize(const AData: TBytes;
  const AMaxOutputSize: SizeUInt): TBytes; inline;
function Lz4Compress(const AData: TBytes): TBytes; inline;
function Lz4Decompress(const AData: TBytes; const AOriginalSize: Int32): TBytes; inline;
function Lz4DecompressWithMaxOutputSize(const AData: TBytes;
  const AOriginalSize: Int32; const AMaxOutputSize: SizeUInt): TBytes; inline;
function Lz4CompressBound(const AInputSize: SizeUInt): SizeUInt; inline;

function ZstdCompress(const AData: TBytes;
  ALevel: Integer = nextpas.core.compress.zstd.ZSTD_DEFAULT_LEVEL): TBytes; inline;
function ZstdDecompress(const AData: TBytes): TBytes; inline;
function ZstdCompressBound(const AInputSize: SizeUInt): SizeUInt; inline;
function ZstdVersionString: string; inline;

implementation

uses
  nextpas.core.errors;

function DeflateWriter(const ADst: IWriter;
  const ALevel: TCompressionLevel): ICompressWriter;
begin
  Result := nextpas.core.compress.deflate.CreateDeflateWriter(ADst, ALevel);
end;

function DeflateReader(const ASrc: IReader): IDecompressReader;
begin
  Result := nextpas.core.compress.deflate.CreateDeflateReader(ASrc);
end;

function DeflateReaderWithMaxOutputSize(const ASrc: IReader;
  const AMaxOutputSize: SizeUInt): IDecompressReader;
begin
  Result := nextpas.core.compress.deflate.CreateDeflateReaderWithMaxOutputSize(
    ASrc, AMaxOutputSize);
end;

function GzipWriter(const ADst: IWriter;
  const ALevel: TCompressionLevel): ICompressWriter;
begin
  Result := nextpas.core.compress.gzip.CreateGzipWriter(ADst, ALevel);
end;

function GzipReader(const ASrc: IReader): IDecompressReader;
begin
  Result := nextpas.core.compress.gzip.CreateGzipReader(ASrc);
end;

function GzipReaderWithMaxOutputSize(const ASrc: IReader;
  const AMaxOutputSize: SizeUInt): IDecompressReader;
begin
  Result := nextpas.core.compress.gzip.CreateGzipReaderWithMaxOutputSize(
    ASrc, AMaxOutputSize);
end;

function DeflateCompress(const AData: TBytes;
  const ALevel: TCompressionLevel): TBytes;
begin
  Result := nextpas.core.compress.deflate.DeflateCompress(AData, ALevel);
end;

function DeflateDecompress(const AData: TBytes): TBytes;
begin
  Result := nextpas.core.compress.deflate.DeflateDecompress(AData);
end;

function DeflateDecompressWithMaxOutputSize(const AData: TBytes;
  const AMaxOutputSize: SizeUInt): TBytes;
begin
  Result := nextpas.core.compress.deflate.DeflateDecompressWithMaxOutputSize(
    AData, AMaxOutputSize);
end;

function DeflateDecompressWithEndPos(const AData: TBytes; AStart: SizeUInt;
  out AEndPos: SizeUInt): TBytes;
begin
  Result := nextpas.core.compress.deflate.DeflateDecompressWithEndPos(AData,
    AStart, AEndPos);
end;

function DeflateDecompressPtrWithEndPos(AData: PByte; ACount, AStart: SizeUInt;
  out AEndPos: SizeUInt): TBytes;
begin
  Result := nextpas.core.compress.deflate.DeflateDecompressPtrWithEndPos(AData,
    ACount, AStart, AEndPos);
end;

function RawDeflateCompress(const AData: TBytes;
  const ALevel: TCompressionLevel): TBytes;
begin
  Result := nextpas.core.compress.deflate.RawDeflateCompress(AData, ALevel);
end;

function RawDeflateDecompress(const AData: TBytes): TBytes;
begin
  Result := nextpas.core.compress.deflate.RawDeflateDecompress(AData);
end;

function RawDeflateDecompressWithMaxOutputSize(const AData: TBytes;
  const AMaxOutputSize: SizeUInt): TBytes;
begin
  Result := nextpas.core.compress.deflate.RawDeflateDecompressWithMaxOutputSize(
    AData, AMaxOutputSize);
end;

function RawDeflateDecompressSized(const AData: TBytes;
  const AExpectedOutputSize, AMaxOutputSize: SizeUInt): TBytes;
begin
  Result := nextpas.core.compress.deflate.RawDeflateDecompressSized(
    AData, AExpectedOutputSize, AMaxOutputSize);
end;

function RawDeflateDecompressToBuffer(const AData: TBytes; const ADst: PByte;
  const ADstLen: SizeUInt; const AMaxOutputSize: SizeUInt): SizeUInt;
begin
  Result := nextpas.core.compress.deflate.RawDeflateDecompressToBuffer(
    AData, ADst, ADstLen, AMaxOutputSize);
end;

function RawDeflateMessageCompress(const AData: TBytes;
  const ALevel: TCompressionLevel): TBytes;
begin
  Result := nextpas.core.compress.deflate.RawDeflateMessageCompress(AData, ALevel);
end;

function RawDeflateMessageDecompress(const AData: TBytes;
  const AMaxOutputSize: SizeUInt): TBytes;
begin
  Result := nextpas.core.compress.deflate.RawDeflateMessageDecompress(AData, AMaxOutputSize);
end;

function DeflateRawCompress(const AData: TBytes;
  const ALevel: TCompressionLevel): TBytes;
begin
  Result := nextpas.core.compress.deflate.DeflateRawCompress(AData, ALevel);
end;

function GzipCompress(const AData: TBytes;
  const ALevel: TCompressionLevel): TBytes;
begin
  Result := nextpas.core.compress.gzip.GzipCompress(AData, ALevel);
end;

function GzipDecompress(const AData: TBytes): TBytes;
begin
  Result := nextpas.core.compress.gzip.GzipDecompress(AData);
end;

function GzipDecompressWithMaxOutputSize(const AData: TBytes;
  const AMaxOutputSize: SizeUInt): TBytes;
begin
  Result := nextpas.core.compress.gzip.GzipDecompressWithMaxOutputSize(AData,
    AMaxOutputSize);
end;

function Lz4Compress(const AData: TBytes): TBytes;
begin
  {$IFDEF NEXTPAS_USE_LZ4_NATIVE}
  Result := nextpas.core.compress.lz4.native.NativeLz4Compress(AData);
  {$ELSE}
  Result := nextpas.core.compress.lz4.Lz4Compress(AData);
  {$ENDIF}
end;

function Lz4Decompress(const AData: TBytes; const AOriginalSize: Int32): TBytes;
begin
  {$IFDEF NEXTPAS_USE_LZ4_NATIVE}
  Result := nextpas.core.compress.lz4.native.NativeLz4Decompress(AData, AOriginalSize);
  {$ELSE}
  Result := nextpas.core.compress.lz4.Lz4Decompress(AData, AOriginalSize);
  {$ENDIF}
end;

function Lz4DecompressWithMaxOutputSize(const AData: TBytes;
  const AOriginalSize: Int32; const AMaxOutputSize: SizeUInt): TBytes;
begin
  {$IFDEF NEXTPAS_USE_LZ4_NATIVE}
  Result := nextpas.core.compress.lz4.native.NativeLz4DecompressWithMaxOutputSize(
    AData, AOriginalSize, AMaxOutputSize);
  {$ELSE}
  Result := nextpas.core.compress.lz4.Lz4DecompressWithMaxOutputSize(AData,
    AOriginalSize, AMaxOutputSize);
  {$ENDIF}
end;

function Lz4CompressBound(const AInputSize: SizeUInt): SizeUInt;
begin
  if AInputSize > LZ4_MAX_INPUT_SIZE then
    raise EIOError.Create('lz4: input size exceeds limit');
  {$IFDEF NEXTPAS_USE_LZ4_NATIVE}
  Result := SizeUInt(nextpas.core.compress.lz4.native.NativeLz4CompressBound(Int32(AInputSize)));
  {$ELSE}
  Result := nextpas.core.compress.lz4.Lz4CompressBound(AInputSize);
  {$ENDIF}
end;

function ZstdCompress(const AData: TBytes;
  ALevel: Integer): TBytes;
begin
  Result := nextpas.core.compress.zstd.ZstdCompress(AData, ALevel);
end;

function ZstdDecompress(const AData: TBytes): TBytes;
begin
  Result := nextpas.core.compress.zstd.ZstdDecompress(AData);
end;

function ZstdCompressBound(const AInputSize: SizeUInt): SizeUInt;
begin
  Result := nextpas.core.compress.zstd.ZstdCompressBound(AInputSize);
end;

function ZstdVersionString: string;
begin
  Result := nextpas.core.compress.zstd.ZstdVersionString;
end;

end.
