unit nextpas.core.respack;

{** @desc 门面：纯 re-export + inline 转发，不含逻辑（design-conventions §2）。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.respack.base,
  nextpas.core.respack.reader,
  nextpas.core.respack.writer,
  nextpas.core.respack.dirsource;

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

function ResPackOpen(const AData: PByte; const ASize: SizeUInt): TResPack; inline;
function ResPackBuild(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions): TResPackBlob; inline;
procedure ResPackFreeBlob(var ABlob: TResPackBlob); inline;
function ResPackValidPath(const APath: string;
  const AFileEntry: Boolean): Boolean; inline;
function ResPackFnv1a32(const AData: PByte; const ASize: SizeUInt): UInt32; inline;
function ResPackDefaultOptions: TResPackBuildOptions; inline;
function ResPackEntriesFromDir(const ARoot: string;
  const AInclude: TResPackIncludeFunc = nil): TResPackInputArray; inline;

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
  const AInclude: TResPackIncludeFunc): TResPackInputArray;
begin
  Result := nextpas.core.respack.dirsource.ResPackEntriesFromDir(ARoot, AInclude);
end;

end.
