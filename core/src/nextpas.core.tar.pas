unit nextpas.core.tar;
{**
 * @desc Tar 归档容器门面：re-export 全量公共面（L2），唯一公共入口。
 * 结构为 512 字节头 + pad 载荷 + 两零块收尾，标准 tar 可直接读写。
 * 条目名严格 IsSafeTarEntryName，pax/GNU 长名与 base-256 双路径兼容。
 * 内部共享内核 nextpas.core.tar.common 不在此 re-export，禁止门面外直引。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.tar.base,
  nextpas.core.tar.intf,
  nextpas.core.tar.reader,
  nextpas.core.tar.writer,
  nextpas.core.tar.fs,
  nextpas.core.tar.builder;

type
  TTarEntryKind = nextpas.core.tar.base.TTarEntryKind;
  TTarHeader = nextpas.core.tar.base.TTarHeader;
  TTarAddOptions = nextpas.core.tar.base.TTarAddOptions;
  TTarReadOptions = nextpas.core.tar.base.TTarReadOptions;
  TTarExtractOptions = nextpas.core.tar.base.TTarExtractOptions;
  TTarReader = nextpas.core.tar.reader.TTarReader;
  TTarWriter = nextpas.core.tar.writer.TTarWriter;
  ITarBuilder = nextpas.core.tar.intf.ITarBuilder;
  ITarStreamBuilder = nextpas.core.tar.builder.ITarStreamBuilder;

const
  tekRegular = nextpas.core.tar.base.tekRegular;
  tekHardLink = nextpas.core.tar.base.tekHardLink;
  tekSymlink = nextpas.core.tar.base.tekSymlink;
  tekCharDevice = nextpas.core.tar.base.tekCharDevice;
  tekBlockDevice = nextpas.core.tar.base.tekBlockDevice;
  tekDirectory = nextpas.core.tar.base.tekDirectory;
  tekFifo = nextpas.core.tar.base.tekFifo;
  C_TAR_BLOCK_SIZE = nextpas.core.tar.base.C_TAR_BLOCK_SIZE;
  C_TAR_DEFAULT_MAX_ENTRY = nextpas.core.tar.base.C_TAR_DEFAULT_MAX_ENTRY;
  C_TAR_MAX_NAME_BYTES = nextpas.core.tar.base.C_TAR_MAX_NAME_BYTES;

function IsSafeTarEntryName(const AName: string): Boolean; inline;
procedure ValidateTarEntryName(const AName: string); inline;
function DefaultTarAddOptions: TTarAddOptions; inline;
function DefaultTarReadOptions: TTarReadOptions; inline;
function DefaultTarExtractOptions: TTarExtractOptions; inline;
function TarRegularMode(APermissionBits: Word): Word; inline;
function TarDirectoryMode(APermissionBits: Word): Word; inline;

procedure TarPackDirInto(const ADir: string; const AWriter: TTarWriter); inline;
function TarPackDir(const ADir: string): TBytes; inline;
procedure TarExtractToDirWithOptions(const AData: TBytes; const ADestDir: string; const AOptions: TTarExtractOptions); inline;
procedure TarExtractToDir(const AData: TBytes; const ADestDir: string); inline;
function TarBuilder: ITarBuilder; inline;
function TarBuilderWithCapacity(const AEstimatedTotal: SizeUInt): ITarBuilder; inline;
function TarBuilderCapacityFor(const AEstimatedTotal: SizeUInt): SizeUInt; inline;
function AsStreamBuilder(const ABuilder: ITarBuilder): ITarStreamBuilder; inline;
function TarBuilderAddFromReader(const ABuilder: ITarBuilder; const AHdr: TTarHeader; const AReader: IReader): ITarBuilder; inline;

implementation

function IsSafeTarEntryName(const AName: string): Boolean; inline;
begin
  Result := nextpas.core.tar.base.IsSafeTarEntryName(AName);
end;

procedure ValidateTarEntryName(const AName: string); inline;
begin
  nextpas.core.tar.base.ValidateTarEntryName(AName);
end;

function DefaultTarAddOptions: TTarAddOptions; inline;
begin
  Result := nextpas.core.tar.base.DefaultTarAddOptions;
end;

function DefaultTarReadOptions: TTarReadOptions; inline;
begin
  Result := nextpas.core.tar.base.DefaultTarReadOptions;
end;

function DefaultTarExtractOptions: TTarExtractOptions; inline;
begin
  Result := nextpas.core.tar.base.DefaultTarExtractOptions;
end;

function TarRegularMode(APermissionBits: Word): Word; inline;
begin
  Result := nextpas.core.tar.base.TarRegularMode(APermissionBits);
end;

function TarDirectoryMode(APermissionBits: Word): Word; inline;
begin
  Result := nextpas.core.tar.base.TarDirectoryMode(APermissionBits);
end;

procedure TarPackDirInto(const ADir: string; const AWriter: TTarWriter); inline;
begin
  nextpas.core.tar.fs.TarPackDirInto(ADir, AWriter);
end;

function TarPackDir(const ADir: string): TBytes; inline;
begin
  Result := nextpas.core.tar.fs.TarPackDir(ADir);
end;

procedure TarExtractToDirWithOptions(const AData: TBytes; const ADestDir: string; const AOptions: TTarExtractOptions); inline;
begin
  nextpas.core.tar.fs.TarExtractToDirWithOptions(AData, ADestDir, AOptions);
end;

procedure TarExtractToDir(const AData: TBytes; const ADestDir: string); inline;
begin
  nextpas.core.tar.fs.TarExtractToDir(AData, ADestDir);
end;

function TarBuilder: ITarBuilder; inline;
begin
  Result := nextpas.core.tar.builder.TarBuilder;
end;

function TarBuilderWithCapacity(const AEstimatedTotal: SizeUInt): ITarBuilder; inline;
begin
  Result := nextpas.core.tar.builder.TarBuilderWithCapacity(AEstimatedTotal);
end;

function TarBuilderCapacityFor(const AEstimatedTotal: SizeUInt): SizeUInt; inline;
begin
  Result := nextpas.core.tar.base.TarBuilderCapacityFor(AEstimatedTotal);
end;

function AsStreamBuilder(const ABuilder: ITarBuilder): ITarStreamBuilder; inline;
begin
  Result := nextpas.core.tar.builder.AsStreamBuilder(ABuilder);
end;

function TarBuilderAddFromReader(const ABuilder: ITarBuilder; const AHdr: TTarHeader; const AReader: IReader): ITarBuilder; inline;
begin
  Result := nextpas.core.tar.builder.TarBuilderAddFromReader(ABuilder, AHdr, AReader);
end;

end.
