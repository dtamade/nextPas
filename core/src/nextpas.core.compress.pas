unit nextpas.core.compress;
{**
 * @desc 压缩门面：Gzip、Deflate、LZ4、Zlib。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.compress.base,
  nextpas.core.compress.intf,
  nextpas.core.compress.deflate,
  nextpas.core.compress.bzip2,
  nextpas.core.compress.gzip
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

const
  GZIP_MAX_DECOMPRESS_BYTES = nextpas.core.compress.base.GZIP_MAX_DECOMPRESS_BYTES;

function DeflateWriter(const ADst: IWriter;
  const ALevel: TCompressionLevel = clDefault): ICompressWriter; inline;
function DeflateReader(const ASrc: IReader): IDecompressReader; inline;
function DeflateReaderEmbedded(const ASrc: IReader): IDecompressReader; inline;
function DeflateReaderWithMaxOutputSize(const ASrc: IReader;
  const AMaxOutputSize: SizeUInt): IDecompressReader; inline;
function RawDeflateWriter(const ADst: IWriter;
  const ALevel: TCompressionLevel = clDefault): ICompressWriter; inline;
function RawDeflateReader(const ASrc: IReader): IDecompressReader; inline;
function RawDeflateReaderWithMaxOutputSize(const ASrc: IReader;
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
function BZip2DecompressWithMaxOutputSize(const AData: TBytes;
  const AMaxOutputSize: SizeUInt): TBytes; inline;
function BZip2Decompress(const AData: TBytes): TBytes; inline;
function BZip2Compress(const AData: TBytes; ABlockSize100k: Integer = 9): TBytes; inline;
function BZip2FfiIsAvailable: Boolean; inline;

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

function DeflateReaderEmbedded(const ASrc: IReader): IDecompressReader;
begin
  Result := nextpas.core.compress.deflate.CreateDeflateReaderEmbedded(ASrc);
end;

function DeflateReaderWithMaxOutputSize(const ASrc: IReader;
  const AMaxOutputSize: SizeUInt): IDecompressReader;
begin
  Result := nextpas.core.compress.deflate.CreateDeflateReaderWithMaxOutputSize(
    ASrc, AMaxOutputSize);
end;

function RawDeflateWriter(const ADst: IWriter;
  const ALevel: TCompressionLevel): ICompressWriter;
begin
  Result := nextpas.core.compress.deflate.CreateRawDeflateWriter(ADst, ALevel);
end;

function RawDeflateReader(const ASrc: IReader): IDecompressReader;
begin
  Result := nextpas.core.compress.deflate.CreateRawDeflateReader(ASrc);
end;

function RawDeflateReaderWithMaxOutputSize(const ASrc: IReader;
  const AMaxOutputSize: SizeUInt): IDecompressReader;
begin
  Result := nextpas.core.compress.deflate.CreateRawDeflateReaderWithMaxOutputSize(
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

function BZip2DecompressWithMaxOutputSize(const AData: TBytes;
  const AMaxOutputSize: SizeUInt): TBytes;
begin
  Result := nextpas.core.compress.bzip2.BZip2DecompressWithMaxOutputSize(AData, AMaxOutputSize);
end;

function BZip2Decompress(const AData: TBytes): TBytes;
begin
  Result := nextpas.core.compress.bzip2.BZip2Decompress(AData);
end;

function BZip2Compress(const AData: TBytes; ABlockSize100k: Integer): TBytes;
begin
  Result := nextpas.core.compress.bzip2.BZip2Compress(AData, ABlockSize100k);
end;

function BZip2FfiIsAvailable: Boolean;
begin
  Result := nextpas.core.compress.bzip2.BZip2FfiIsAvailable;
end;

end.
