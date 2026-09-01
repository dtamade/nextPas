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

const
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

implementation

function IsSafeTarEntryName(const AName: string): Boolean;
begin
  Result := nextpas.core.tar.base.IsSafeTarEntryName(AName);
end;

procedure ValidateTarEntryName(const AName: string);
begin
  nextpas.core.tar.base.ValidateTarEntryName(AName);
end;

function DefaultTarAddOptions: TTarAddOptions;
begin
  Result := nextpas.core.tar.base.DefaultTarAddOptions;
end;

function DefaultTarReadOptions: TTarReadOptions;
begin
  Result := nextpas.core.tar.base.DefaultTarReadOptions;
end;

function DefaultTarExtractOptions: TTarExtractOptions;
begin
  Result := nextpas.core.tar.base.DefaultTarExtractOptions;
end;

function TarRegularMode(APermissionBits: Word): Word;
begin
  Result := nextpas.core.tar.base.TarRegularMode(APermissionBits);
end;

function TarDirectoryMode(APermissionBits: Word): Word;
begin
  Result := nextpas.core.tar.base.TarDirectoryMode(APermissionBits);
end;

procedure TarPackDirInto(const ADir: string; const AWriter: TTarWriter);
begin
  nextpas.core.tar.fs.TarPackDirInto(ADir, AWriter);
end;

function TarPackDir(const ADir: string): TBytes;
begin
  Result := nextpas.core.tar.fs.TarPackDir(ADir);
end;

procedure TarExtractToDirWithOptions(const AData: TBytes; const ADestDir: string; const AOptions: TTarExtractOptions);
begin
  nextpas.core.tar.fs.TarExtractToDirWithOptions(AData, ADestDir, AOptions);
end;

procedure TarExtractToDir(const AData: TBytes; const ADestDir: string);
begin
  nextpas.core.tar.fs.TarExtractToDir(AData, ADestDir);
end;

function TarBuilder: ITarBuilder;
begin
  Result := nextpas.core.tar.builder.TarBuilder;
end;

end.
