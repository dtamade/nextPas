unit nextpas.core.tar.base;
{**
 * @desc Tar 基座：类型、常量与名安全谓词，L2 单点。
 * 仅依赖 nextpas.core.base / exception，无 FPC RTL 直引。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.exception;

type
  TTarEntryKind = (
    tekRegular,
    tekHardLink,
    tekSymlink,
    tekCharDevice,
    tekBlockDevice,
    tekDirectory,
    tekFifo
  );

  {** @desc 单条目头元数据（ustar/pax 归一后） *}
  TTarHeader = record
    Name: string;
    LinkName: string;
    Kind: TTarEntryKind;
    Mode: Cardinal;
    UID: Cardinal;
    GID: Cardinal;
    Size: Int64;
    MTimeUnix: Int64;
    UName: string;
    GName: string;
  end;

  {** @desc 写入选项（按条目覆盖 header 字段） *}
  TTarAddOptions = record
    Mode: Cardinal;
    UID: Cardinal;
    GID: Cardinal;
    MTimeUnix: Int64;
    UName: string;
    GName: string;
  end;

  {** @desc 读取选项：单条目与总量 bomb 守卫 *}
  TTarReadOptions = record
    MaxEntrySize: SizeUInt;
    MaxTotalSize: UInt64;
  end;

  {** @desc 落盘选项 *}
  TTarExtractOptions = record
    RestoreMode: Boolean;
    SkipSpecial: Boolean;
    MaxEntrySize: SizeUInt;
    MaxTotalSize: UInt64;
  end;

const
  C_TAR_BLOCK_SIZE = 512;
  C_TAR_NAME_FIELD = 100;
  C_TAR_PREFIX_FIELD = 155;
  C_TAR_MAX_NAME_BYTES = 512;

  { ustar 固定 }
  C_TAR_MAGIC_USTAR = 'ustar';
  C_TAR_VERSION_00 = '00';

  { 默认 bomb 上限（复用 compress GZIP_MAX 1GiB 级别，保持 zip 对齐） }
  C_TAR_DEFAULT_MAX_ENTRY = SizeUInt(1) shl 30;
  C_TAR_DEFAULT_MAX_TOTAL: UInt64 = 0;

function IsSafeTarEntryName(const AName: string): Boolean; inline;
procedure ValidateTarEntryName(const AName: string);

function DefaultTarAddOptions: TTarAddOptions; inline;
function DefaultTarReadOptions: TTarReadOptions; inline;
function DefaultTarExtractOptions: TTarExtractOptions; inline;

{** posix 权限位助手（与 zip 对称，保持调用方手感一致） *}
function TarRegularMode(APermissionBits: Word): Word; inline;
function TarDirectoryMode(APermissionBits: Word): Word; inline;

implementation

uses
  nextpas.core.text.conv;

function IsSafeTarEntryName(const AName: string): Boolean; inline;
var
  LI, LSegStart: Integer;
begin
  Result := False;
  if AName = '' then
    Exit;
  if Length(AName) > C_TAR_MAX_NAME_BYTES then
    Exit;
  if AName[1] = '/' then
    Exit;
  if (Length(AName) >= 2) and (AName[2] = ':') and
     (UpCase(AName[1]) in ['A'..'Z']) then
    Exit;
  LSegStart := 1;
  for LI := 1 to Length(AName) + 1 do
  begin
    if (LI <= Length(AName)) and (AName[LI] <> '/') then
    begin
      if AName[LI] = '\' then
        Exit;
      Continue;
    end;
    if LI - LSegStart = 0 then
    begin
      if LI <= Length(AName) then
        Exit; { // 空段，尾随 '/' 的终段空合法 }
    end
    else if LI - LSegStart = 1 then
    begin
      if AName[LSegStart] = '.' then
        Exit;
    end
    else if (LI - LSegStart = 2) and (AName[LSegStart] = '.') and
       (AName[LSegStart + 1] = '.') then
      Exit;
    LSegStart := LI + 1;
  end;
  Result := True;
end;

procedure ValidateTarEntryName(const AName: string);
begin
  if AName = '' then
    raise EArgumentError.Create('tar entry name must not be empty');
  if Length(AName) > C_TAR_MAX_NAME_BYTES then
    raise EArgumentError.Create('tar entry name exceeds ' +
      IntToStr(C_TAR_MAX_NAME_BYTES) + ' bytes');
  if not IsSafeTarEntryName(AName) then
    raise EArgumentError.Create('tar entry name is not safe: ' + AName);
end;

function DefaultTarAddOptions: TTarAddOptions; inline;
begin
  Result.Mode := 0;
  Result.UID := 0;
  Result.GID := 0;
  Result.MTimeUnix := 0;
  Result.UName := '';
  Result.GName := '';
end;

function DefaultTarReadOptions: TTarReadOptions; inline;
begin
  Result.MaxEntrySize := C_TAR_DEFAULT_MAX_ENTRY;
  Result.MaxTotalSize := C_TAR_DEFAULT_MAX_TOTAL;
end;

function DefaultTarExtractOptions: TTarExtractOptions; inline;
begin
  Result.RestoreMode := True;
  Result.SkipSpecial := True;
  Result.MaxEntrySize := 0;
  Result.MaxTotalSize := 0;
end;

function TarRegularMode(APermissionBits: Word): Word; inline;
begin
  Result := $8000 or (APermissionBits and $0FFF);
end;

function TarDirectoryMode(APermissionBits: Word): Word; inline;
begin
  Result := $4000 or (APermissionBits and $0FFF);
end;

end.
