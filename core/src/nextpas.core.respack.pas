unit nextpas.core.respack;

{** @desc 门面：纯 re-export + inline 转发，不含逻辑（design-conventions §2）。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.respack.base,
  nextpas.core.respack.reader,
  nextpas.core.respack.writer,
  nextpas.core.respack.writer.stream,
  nextpas.core.respack.dirsource,
  nextpas.core.respack.embed;

type
  TResPackHeader = nextpas.core.respack.base.TResPackHeader;
  TResPackEntry = nextpas.core.respack.base.TResPackEntry;
  TResPackDigest = nextpas.core.respack.base.TResPackDigest;
  TResPackDigestFunc = nextpas.core.respack.base.TResPackDigestFunc;
  TResPackInputEntry = nextpas.core.respack.base.TResPackInputEntry;
  TResPackInputArray = nextpas.core.respack.base.TResPackInputArray;
  TResPackBuildOptions = nextpas.core.respack.base.TResPackBuildOptions;
  TResPackBlob = nextpas.core.respack.base.TResPackBlob;
  TResPackLayoutInfo = nextpas.core.respack.writer.TResPackLayoutInfo;
  TResPackIncludeFunc = nextpas.core.respack.dirsource.TResPackIncludeFunc;
  TResPack = nextpas.core.respack.reader.TResPack;
  TResPackEmbedOptions = nextpas.core.respack.embed.TResPackEmbedOptions;
  TResPackIncOptions = nextpas.core.respack.embed.TResPackIncOptions;
  TResPackDirEntries = nextpas.core.respack.dirsource.TResPackDirEntries;
  TResPackWriteProc = nextpas.core.respack.writer.stream.TResPackWriteProc;

  EResPackError = nextpas.core.respack.base.EResPackError;
  EResPackCorrupted = nextpas.core.respack.base.EResPackCorrupted;
  EResPackDuplicatePath = nextpas.core.respack.base.EResPackDuplicatePath;
  EResPackInvalidPath = nextpas.core.respack.base.EResPackInvalidPath;
  EResPackNotFound = nextpas.core.respack.base.EResPackNotFound;
  EResPackTooLarge = nextpas.core.respack.base.EResPackTooLarge;
  EResPackDirSourceFailed = nextpas.core.respack.base.EResPackDirSourceFailed;

const
  RESPACK_VERSION = nextpas.core.respack.base.RESPACK_VERSION;
  RESPACK_CODEC_STORE = nextpas.core.respack.base.RESPACK_CODEC_STORE;
  RESPACK_FLAG_ALGO_MASK = nextpas.core.respack.base.RESPACK_FLAG_ALGO_MASK;
  RESPACK_FLAG_ALGO_SHIFT = nextpas.core.respack.base.RESPACK_FLAG_ALGO_SHIFT;
  RESPACK_DIGEST_ALGO_SHA256 = nextpas.core.respack.base.RESPACK_DIGEST_ALGO_SHA256;
  RESPACK_INC_DEFAULT_BYTES_PER_LINE =
    nextpas.core.respack.embed.RESPACK_INC_DEFAULT_BYTES_PER_LINE;

function ResPackOpen(const AData: PByte; const ASize: SizeUInt): TResPack; inline;
function ResPackBuild(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions): TResPackBlob; inline;
procedure ResPackBuildStream(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions; const AWrite: TResPackWriteProc); inline;
function ResPackBuildStreamSize(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions): UInt64; inline;
procedure ResPackFreeBlob(var ABlob: TResPackBlob); inline;
function ResPackValidPath(const APath: string;
  const AFileEntry: Boolean): Boolean; inline;
function ResPackFnv1a32(const AData: PByte; const ASize: SizeUInt): UInt32; inline;
function ResPackDefaultOptions: TResPackBuildOptions; inline;
function ResPackEntriesFromDir(const ARoot: string;
  const AInclude: TResPackIncludeFunc = nil): TResPackDirEntries; inline;
procedure ResPackBuildStreamFromDir(const ARoot: string;
  const AOpts: TResPackBuildOptions; const AWrite: TResPackWriteProc;
  const AInclude: TResPackIncludeFunc = nil); inline;
function ResPackBuildFromDir(const ARoot: string;
  const AOpts: TResPackBuildOptions;
  const AInclude: TResPackIncludeFunc = nil): TResPackBlob; inline;
function ResPackBuildStreamSizeFromDir(const ARoot: string;
  const AOpts: TResPackBuildOptions;
  const AInclude: TResPackIncludeFunc = nil): UInt64; inline;
function ResPackDefaultEmbedOptions: TResPackEmbedOptions; inline;
function ResPackDefaultIncOptions: TResPackIncOptions; inline;
function ResPackValidIdent(const AName: string): Boolean; inline;
function ResPackEmbedBuild(const ASourceDir: string;
  const AOpts: TResPackEmbedOptions): TResPackBlob; inline;
function ResPackEmbedIncSource(const ABlob: TResPackBlob;
  const AOpts: TResPackIncOptions): TBytes; inline;
function ResPackEmbedIncUnitSource(const ABlob: TResPackBlob;
  const AOpts: TResPackIncOptions; const AUnitName: string): TBytes; inline;
procedure ResPackExtractToDir(const ABlob: TResPackBlob;
  const ADestDir: string); inline;

implementation

function ResPackOpen(const AData: PByte; const ASize: SizeUInt): TResPack;
begin
  Result := nextpas.core.respack.reader.TResPack.Open(AData, ASize);
end;

function ResPackBuild(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions): TResPackBlob;
begin
  Result := nextpas.core.respack.writer.ResPackBuild(AEntries, AOpts);
end;

procedure ResPackBuildStream(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions; const AWrite: TResPackWriteProc);
begin
  nextpas.core.respack.writer.stream.ResPackBuildStream(AEntries, AOpts, AWrite);
end;

function ResPackBuildStreamSize(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions): UInt64;
begin
  Result := nextpas.core.respack.writer.stream.ResPackBuildStreamSize(AEntries, AOpts);
end;

procedure ResPackFreeBlob(var ABlob: TResPackBlob);
begin
  nextpas.core.respack.base.ResPackFreeBlob(ABlob);
end;

function ResPackValidPath(const APath: string;
  const AFileEntry: Boolean): Boolean;
begin
  Result := nextpas.core.respack.base.ResPackValidPath(APath, AFileEntry);
end;

function ResPackFnv1a32(const AData: PByte; const ASize: SizeUInt): UInt32;
begin
  Result := nextpas.core.respack.base.ResPackFnv1a32(AData, ASize);
end;

function ResPackDefaultOptions: TResPackBuildOptions;
begin
  Result := nextpas.core.respack.base.ResPackDefaultOptions;
end;

function ResPackEntriesFromDir(const ARoot: string;
  const AInclude: TResPackIncludeFunc): TResPackDirEntries;
begin
  Result := nextpas.core.respack.dirsource.ResPackEntriesFromDir(ARoot, AInclude);
end;

procedure ResPackBuildStreamFromDir(const ARoot: string;
  const AOpts: TResPackBuildOptions; const AWrite: TResPackWriteProc;
  const AInclude: TResPackIncludeFunc);
begin
  nextpas.core.respack.dirsource.ResPackBuildStreamFromDir(ARoot, AOpts, AWrite, AInclude);
end;

function ResPackBuildFromDir(const ARoot: string;
  const AOpts: TResPackBuildOptions; const AInclude: TResPackIncludeFunc): TResPackBlob;
begin
  Result := nextpas.core.respack.dirsource.ResPackBuildFromDir(ARoot, AOpts, AInclude);
end;

function ResPackBuildStreamSizeFromDir(const ARoot: string;
  const AOpts: TResPackBuildOptions; const AInclude: TResPackIncludeFunc): UInt64;
begin
  Result := nextpas.core.respack.dirsource.ResPackBuildStreamSizeFromDir(ARoot, AOpts, AInclude);
end;

function ResPackDefaultEmbedOptions: TResPackEmbedOptions;
begin
  Result := nextpas.core.respack.embed.ResPackDefaultEmbedOptions;
end;

function ResPackDefaultIncOptions: TResPackIncOptions;
begin
  Result := nextpas.core.respack.embed.ResPackDefaultIncOptions;
end;

function ResPackValidIdent(const AName: string): Boolean;
begin
  Result := nextpas.core.respack.embed.ResPackValidIdent(AName);
end;

function ResPackEmbedBuild(const ASourceDir: string;
  const AOpts: TResPackEmbedOptions): TResPackBlob;
begin
  Result := nextpas.core.respack.embed.ResPackEmbedBuild(ASourceDir, AOpts);
end;

function ResPackEmbedIncSource(const ABlob: TResPackBlob;
  const AOpts: TResPackIncOptions): TBytes;
begin
  Result := nextpas.core.respack.embed.ResPackEmbedIncSource(ABlob, AOpts);
end;

function ResPackEmbedIncUnitSource(const ABlob: TResPackBlob;
  const AOpts: TResPackIncOptions; const AUnitName: string): TBytes;
begin
  Result := nextpas.core.respack.embed.ResPackEmbedIncUnitSource(ABlob, AOpts,
    AUnitName);
end;

procedure ResPackExtractToDir(const ABlob: TResPackBlob;
  const ADestDir: string);
begin
  nextpas.core.respack.dirsource.ResPackExtractToDir(ABlob, ADestDir);
end;

end.
