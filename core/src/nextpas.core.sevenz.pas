unit nextpas.core.sevenz;
{**
 * @desc nextpas.core.sevenz 的容器门面。
 *
 * 聚合 7z 归档读端/写端、文件系统联邦层、条目元数据、错误类型与
 * LZMA 编解码器后端契约，方便消费者只 `uses nextpas.core.sevenz`
 * 即可完成常见读写与宿主文件系统联办。
 *
 * 范围原则：
 *   - 容器级能力（含 sevenz.fs 联邦层 AddTree/AddFileFromFs/ExtractToFs/
 *     FlushExtractedToFs 全族）通过类型别名与 inline forward 显式转发。
 *   - 头部 TLV/varint 编解码、区间编码器等低层机制留在对应子模块，
 *     避免门面膨胀。
 *   - 需要定制 folder/coder 拓扑时直接引用
 *     nextpas.core.sevenz.header 与 nextpas.core.sevenz.coders。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.compress.base,
  nextpas.core.sevenz.base,
  nextpas.core.sevenz.intf,
  nextpas.core.sevenz.filters,
  nextpas.core.sevenz.reader,
  nextpas.core.sevenz.writer,
  nextpas.core.sevenz.fs,
  nextpas.core.compress.bzip2;

type
  TSevenZEntryKind = nextpas.core.sevenz.base.TSevenZEntryKind;
  TSevenZEntryInfo = nextpas.core.sevenz.base.TSevenZEntryInfo;
  ESevenZError = nextpas.core.sevenz.base.ESevenZError;
  ESevenZLimitError = nextpas.core.sevenz.base.ESevenZLimitError;
  TSevenZLzmaBackend = nextpas.core.sevenz.intf.TSevenZLzmaBackend;
  TSevenZCompressionLevel =
    nextpas.core.sevenz.intf.TSevenZCompressionLevel;
  TSevenZFilter = nextpas.core.sevenz.intf.TSevenZFilter;
  TSevenZLzmaEncoded = nextpas.core.sevenz.intf.TSevenZLzmaEncoded;
  TSevenZEntryInfoArray = nextpas.core.sevenz.intf.TSevenZEntryInfoArray;
  TSevenZExtracted = nextpas.core.sevenz.intf.TSevenZExtracted;
  TSevenZExtractedArray = nextpas.core.sevenz.intf.TSevenZExtractedArray;
  TSevenZEntryEnumerator = nextpas.core.sevenz.intf.TSevenZEntryEnumerator;
  ISevenZLzmaDecoder = nextpas.core.sevenz.intf.ISevenZLzmaDecoder;
  ISevenZLzmaEncoder = nextpas.core.sevenz.intf.ISevenZLzmaEncoder;
  ISevenZReader = nextpas.core.sevenz.intf.ISevenZReader;
  ISevenZWriter = nextpas.core.sevenz.intf.ISevenZWriter;
  TSevenZReaderImpl = nextpas.core.sevenz.reader.TSevenZReaderImpl;
  TSevenZWriterImpl = nextpas.core.sevenz.writer.TSevenZWriterImpl;
  TSevenZWriterBuilderImpl = nextpas.core.sevenz.writer.TSevenZWriterBuilderImpl;
  ISevenZWriterBuilder = nextpas.core.sevenz.intf.ISevenZWriterBuilder;

const
  sekFile = nextpas.core.sevenz.base.sekFile;
  sekDirectory = nextpas.core.sevenz.base.sekDirectory;

  szlbAuto = nextpas.core.sevenz.intf.szlbAuto;
  szlbPurePascal = nextpas.core.sevenz.intf.szlbPurePascal;
  szlbFfi = nextpas.core.sevenz.intf.szlbFfi;

  szclNone = nextpas.core.sevenz.intf.szclNone;
  szclFastest = nextpas.core.sevenz.intf.szclFastest;
  szclDefault = nextpas.core.sevenz.intf.szclDefault;
  szclBest = nextpas.core.sevenz.intf.szclBest;

  szfBcjX86 = nextpas.core.sevenz.intf.szfBcjX86;
  szfBcjArm = nextpas.core.sevenz.intf.szfBcjArm;
  szfBcjArm64 = nextpas.core.sevenz.intf.szfBcjArm64;
  szfBcjPpc = nextpas.core.sevenz.intf.szfBcjPpc;
  szfBcjIa64 = nextpas.core.sevenz.intf.szfBcjIa64;
  szfBcjSparc = nextpas.core.sevenz.intf.szfBcjSparc;
  szfBcjArmt = nextpas.core.sevenz.intf.szfBcjArmt;
  szfBcjRiscv = nextpas.core.sevenz.intf.szfBcjRiscv;
  szfDelta = nextpas.core.sevenz.intf.szfDelta;

  { 过滤链深度上限 }
  C_MAX_FILTERS = nextpas.core.sevenz.intf.C_MAX_FILTERS;

{ 过滤器注册表：单入口 MethodId/Props/Convert 与方法支持判定 }
function SevenZFilterMethodId(AFilter: TSevenZFilter): UInt64; inline;
function SevenZFilterFromMethodId(AMethodId: UInt64; out AFilter: TSevenZFilter): Boolean; inline;
function SevenZIsSupportedMethod(AMethodId: UInt64): Boolean; inline;
function SevenZMethodName(AMethodId: UInt64): string; inline;
function SevenZBZip2Available: Boolean; inline;

{ 名字编码：UTF-8 ↔ UTF-16LE（7z 条目名统一 UTF-16LE 存储） }
function SevenZUtf16LeToUtf8(const ABytes: TBytes): string; inline;
function SevenZUtf8ToUtf16Le(const S: string): TBytes; inline;

{ 时间换算：Unix 秒 ↔ Windows FILETIME（100ns tick） }
function SevenZUnixToFILETIME(AUnixSec: Int64): UInt64; inline;
function SevenZFILETIMEToUnix(ATicks: UInt64): Int64; inline;

{ 工厂：读写端快速构造（门面 inline forward） }
function SevenZCreateWriter: ISevenZWriter; inline;
function SevenZCreateWriterBuilder: ISevenZWriterBuilder; inline;
function SevenZCreateReader(const AArchive: TBytes): ISevenZReader; inline;
function SevenZCreateReaderWithPassword(const AArchive: TBytes; const APassword: string): ISevenZReader; inline;
function SevenZCreateReaderFrom(const AReader: IReader): ISevenZReader; inline;
function SevenZCreateReaderFromWithPassword(const AReader: IReader; const APassword: string): ISevenZReader; inline;
function SevenZLevelToDeflateLevel(ALevel: TSevenZCompressionLevel): TCompressionLevel; inline;
function SevenZLevelToBZip2BlockSize(ALevel: TSevenZCompressionLevel): Integer; inline;

{ 文件系统联邦层：宿主文件 ↔ 归档条目（L2 单入口显式转发，复用 fs 单源实现） }
procedure SevenZAddFileFromFs(const AWriter: ISevenZWriter; const AHostPath, AEntryName: string); inline;
procedure SevenZAddFileFromFsWithTime(const AWriter: ISevenZWriter; const AHostPath, AEntryName: string; AUseFsMTime: Boolean); inline;
procedure SevenZAddTree(const AWriter: ISevenZWriter; const AHostDir, AEntryPrefix: string); inline;
procedure SevenZAddTreeWithFilter(const AWriter: ISevenZWriter; const AHostDir, AEntryPrefix: string; const AInclude: string); inline;
function SevenZExtractToFs(const AReader: ISevenZReader; AIndex: Integer; const AHostPath: string): Int64; inline;
procedure SevenZExtractAllToFs(const AReader: ISevenZReader; const ABaseDir: string); inline;
function SevenZExtractByPrefixToFs(const AReader: ISevenZReader; const APrefix, ABaseDir: string): Integer; inline;
function SevenZExtractBySuffixToFs(const AReader: ISevenZReader; const ASuffix, ABaseDir: string): Integer; inline;
function SevenZExtractByGlobToFs(const AReader: ISevenZReader; const APattern, ABaseDir: string): Integer; inline;
function SevenZTryExtractByGlobToFs(const AReader: ISevenZReader; const APattern, ABaseDir: string; out AError: string): Boolean; inline;
function SevenZExtractByPrefixIgnoreCaseToFs(const AReader: ISevenZReader; const APrefix, ABaseDir: string): Integer; inline;
function SevenZExtractBySuffixIgnoreCaseToFs(const AReader: ISevenZReader; const ASuffix, ABaseDir: string): Integer; inline;
function SevenZExtractByGlobIgnoreCaseToFs(const AReader: ISevenZReader; const APattern, ABaseDir: string): Integer; inline;
function SevenZTryExtractByGlobIgnoreCaseToFs(const AReader: ISevenZReader; const APattern, ABaseDir: string; out AError: string): Boolean; inline;
function SevenZTryExtractByPrefixIgnoreCaseToFs(const AReader: ISevenZReader; const APrefix, ABaseDir: string; out AError: string): Boolean; inline;
function SevenZTryExtractBySuffixIgnoreCaseToFs(const AReader: ISevenZReader; const ASuffix, ABaseDir: string; out AError: string): Boolean; inline;

implementation

function SevenZUtf16LeToUtf8(const ABytes: TBytes): string;
begin
  Result := nextpas.core.sevenz.base.SevenZUtf16LeToUtf8(ABytes);
end;

function SevenZUtf8ToUtf16Le(const S: string): TBytes;
begin
  Result := nextpas.core.sevenz.base.SevenZUtf8ToUtf16Le(S);
end;

function SevenZUnixToFILETIME(AUnixSec: Int64): UInt64;
begin
  Result := nextpas.core.sevenz.base.SevenZUnixToFILETIME(AUnixSec);
end;

function SevenZFILETIMEToUnix(ATicks: UInt64): Int64;
begin
  Result := nextpas.core.sevenz.base.SevenZFILETIMEToUnix(ATicks);
end;

function SevenZFilterMethodId(AFilter: TSevenZFilter): UInt64;
begin
  Result := nextpas.core.sevenz.filters.SevenZFilterMethodId(AFilter);
end;

function SevenZFilterFromMethodId(AMethodId: UInt64; out AFilter: TSevenZFilter): Boolean;
begin
  Result := nextpas.core.sevenz.filters.SevenZFilterFromMethodId(AMethodId, AFilter);
end;

function SevenZIsSupportedMethod(AMethodId: UInt64): Boolean;
begin
  Result := nextpas.core.sevenz.filters.SevenZIsSupportedMethod(AMethodId);
end;

function SevenZMethodName(AMethodId: UInt64): string;
begin
  Result := nextpas.core.sevenz.base.SevenZMethodName(AMethodId);
end;

function SevenZBZip2Available: Boolean;
begin
  Result := BZip2FfiIsAvailable;
end;

function SevenZCreateWriter: ISevenZWriter;
begin
  Result := TSevenZWriterImpl.Create;
end;

function SevenZCreateWriterBuilder: ISevenZWriterBuilder;
begin
  Result := nextpas.core.sevenz.writer.SevenZCreateWriterBuilder;
end;

function SevenZLevelToDeflateLevel(ALevel: TSevenZCompressionLevel): TCompressionLevel;
begin
  Result := nextpas.core.sevenz.intf.SevenZLevelToDeflateLevel(ALevel);
end;

function SevenZLevelToBZip2BlockSize(ALevel: TSevenZCompressionLevel): Integer;
begin
  Result := nextpas.core.sevenz.intf.SevenZLevelToBZip2BlockSize(ALevel);
end;

function SevenZCreateReader(const AArchive: TBytes): ISevenZReader;
begin
  Result := TSevenZReaderImpl.Create(AArchive);
end;

function SevenZCreateReaderWithPassword(const AArchive: TBytes; const APassword: string): ISevenZReader;
begin
  Result := TSevenZReaderImpl.CreateWithPassword(AArchive, APassword);
end;

function SevenZCreateReaderFrom(const AReader: IReader): ISevenZReader;
begin
  Result := TSevenZReaderImpl.CreateFromReader(AReader);
end;

function SevenZCreateReaderFromWithPassword(const AReader: IReader; const APassword: string): ISevenZReader;
begin
  Result := TSevenZReaderImpl.CreateFromReaderWithPassword(AReader, APassword);
end;

procedure SevenZAddFileFromFs(const AWriter: ISevenZWriter; const AHostPath, AEntryName: string);
begin
  nextpas.core.sevenz.fs.SevenZAddFileFromFs(AWriter, AHostPath, AEntryName);
end;

procedure SevenZAddFileFromFsWithTime(const AWriter: ISevenZWriter; const AHostPath, AEntryName: string; AUseFsMTime: Boolean);
begin
  nextpas.core.sevenz.fs.SevenZAddFileFromFsWithTime(AWriter, AHostPath, AEntryName, AUseFsMTime);
end;

procedure SevenZAddTree(const AWriter: ISevenZWriter; const AHostDir, AEntryPrefix: string);
begin
  nextpas.core.sevenz.fs.SevenZAddTree(AWriter, AHostDir, AEntryPrefix);
end;

procedure SevenZAddTreeWithFilter(const AWriter: ISevenZWriter; const AHostDir, AEntryPrefix: string; const AInclude: string);
begin
  nextpas.core.sevenz.fs.SevenZAddTreeWithFilter(AWriter, AHostDir, AEntryPrefix, AInclude);
end;

function SevenZExtractToFs(const AReader: ISevenZReader; AIndex: Integer; const AHostPath: string): Int64;
begin
  Result := nextpas.core.sevenz.fs.SevenZExtractToFs(AReader, AIndex, AHostPath);
end;

procedure SevenZExtractAllToFs(const AReader: ISevenZReader; const ABaseDir: string);
begin
  nextpas.core.sevenz.fs.SevenZExtractAllToFs(AReader, ABaseDir);
end;

function SevenZExtractByPrefixToFs(const AReader: ISevenZReader; const APrefix, ABaseDir: string): Integer;
begin
  Result := nextpas.core.sevenz.fs.SevenZExtractByPrefixToFs(AReader, APrefix, ABaseDir);
end;

function SevenZExtractBySuffixToFs(const AReader: ISevenZReader; const ASuffix, ABaseDir: string): Integer;
begin
  Result := nextpas.core.sevenz.fs.SevenZExtractBySuffixToFs(AReader, ASuffix, ABaseDir);
end;

function SevenZExtractByGlobToFs(const AReader: ISevenZReader; const APattern, ABaseDir: string): Integer;
begin
  Result := nextpas.core.sevenz.fs.SevenZExtractByGlobToFs(AReader, APattern, ABaseDir);
end;

function SevenZTryExtractByGlobToFs(const AReader: ISevenZReader; const APattern, ABaseDir: string; out AError: string): Boolean;
begin
  Result := nextpas.core.sevenz.fs.SevenZTryExtractByGlobToFs(AReader, APattern, ABaseDir, AError);
end;

function SevenZExtractByPrefixIgnoreCaseToFs(const AReader: ISevenZReader; const APrefix, ABaseDir: string): Integer;
begin
  Result := nextpas.core.sevenz.fs.SevenZExtractByPrefixIgnoreCaseToFs(AReader, APrefix, ABaseDir);
end;

function SevenZExtractBySuffixIgnoreCaseToFs(const AReader: ISevenZReader; const ASuffix, ABaseDir: string): Integer;
begin
  Result := nextpas.core.sevenz.fs.SevenZExtractBySuffixIgnoreCaseToFs(AReader, ASuffix, ABaseDir);
end;

function SevenZExtractByGlobIgnoreCaseToFs(const AReader: ISevenZReader; const APattern, ABaseDir: string): Integer;
begin
  Result := nextpas.core.sevenz.fs.SevenZExtractByGlobIgnoreCaseToFs(AReader, APattern, ABaseDir);
end;

function SevenZTryExtractByGlobIgnoreCaseToFs(const AReader: ISevenZReader; const APattern, ABaseDir: string; out AError: string): Boolean;
begin
  Result := nextpas.core.sevenz.fs.SevenZTryExtractByGlobIgnoreCaseToFs(AReader, APattern, ABaseDir, AError);
end;

function SevenZTryExtractByPrefixIgnoreCaseToFs(const AReader: ISevenZReader; const APrefix, ABaseDir: string; out AError: string): Boolean;
begin
  Result := nextpas.core.sevenz.fs.SevenZTryExtractByPrefixIgnoreCaseToFs(AReader, APrefix, ABaseDir, AError);
end;

function SevenZTryExtractBySuffixIgnoreCaseToFs(const AReader: ISevenZReader; const ASuffix, ABaseDir: string; out AError: string): Boolean;
begin
  Result := nextpas.core.sevenz.fs.SevenZTryExtractBySuffixIgnoreCaseToFs(AReader, ASuffix, ABaseDir, AError);
end;

end.
