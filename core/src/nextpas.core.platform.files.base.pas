unit nextpas.core.platform.files.base;

{$I nextpas.core.settings.inc}

interface

{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.windows.base;
{$ELSE}
uses
  nextpas.core.platform.posix.base;
{$ENDIF}

type
  {** @desc 文件句柄（平台无关封装） *}
  TPlatformFileHandle = record
  {$IFDEF NEXTPAS_WINDOWS}
    Value: HANDLE;
  {$ELSE}
    Value: cint;
  {$ENDIF}
    {** @desc 检查句柄是否有效
        @return True 如果句柄有效 *}
    function IsValid: Boolean; inline;
    {** @desc 检查句柄是否无效
        @return True 如果句柄无效 *}
    function IsInvalid: Boolean; inline;
  end;

  {** @desc 文件类型枚举 *}
  TPlatformFileType = (
    ftRegular,
    ftDirectory,
    ftSymlink,
    ftCharDevice,
    ftBlockDevice,
    ftFifo,
    ftSocket,
    ftUnknown
  );

  {** @desc 文件状态信息 *}
  TPlatformFileStat = record
    Size: Int64;
    FileType: TPlatformFileType;
    Mode: UInt32;
    ModTime: Int64;
    AccessTime: Int64;
    { POSIX CreateTime maps st_ctime, which is status-change time. }
    CreateTime: Int64;
    Uid: UInt32;
    Gid: UInt32;
    NLink: UInt32;
    Dev: UInt64;
    Ino: UInt64;
    {** @desc 检查是否为普通文件
        @return True 如果是普通文件 *}
    function IsRegular: Boolean; inline;
    {** @desc 检查是否为目录
        @return True 如果是目录 *}
    function IsDirectory: Boolean; inline;
    {** @desc 检查是否为符号链接
        @return True 如果是符号链接 *}
    function IsSymlink: Boolean; inline;
    {** @desc 检查是否为特殊文件（字符设备、块设备、FIFO、套接字）
        @return True 如果是特殊文件 *}
    function IsSpecial: Boolean; inline;
    {** @desc 检查所有者是否有读权限
        @return True 如果所有者有读权限 *}
    function IsOwnerReadable: Boolean; inline;
    {** @desc 检查所有者是否有写权限
        @return True 如果所有者有写权限 *}
    function IsOwnerWritable: Boolean; inline;
    {** @desc 检查所有者是否有执行权限
        @return True 如果所有者有执行权限 *}
    function IsOwnerExecutable: Boolean; inline;
    {** @desc 检查组是否有读权限
        @return True 如果组有读权限 *}
    function IsGroupReadable: Boolean; inline;
    {** @desc 检查组是否有写权限
        @return True 如果组有写权限 *}
    function IsGroupWritable: Boolean; inline;
    {** @desc 检查组是否有执行权限
        @return True 如果组有执行权限 *}
    function IsGroupExecutable: Boolean; inline;
    {** @desc 检查其他是否有读权限
        @return True 如果其他有读权限 *}
    function IsOtherReadable: Boolean; inline;
    {** @desc 检查其他是否有写权限
        @return True 如果其他有写权限 *}
    function IsOtherWritable: Boolean; inline;
    {** @desc 检查其他是否有执行权限
        @return True 如果其他有执行权限 *}
    function IsOtherExecutable: Boolean; inline;
  end;

  {** @desc 文件打开模式 *}
  TPlatformFileOpenMode = (
    fomReadOnly,
    fomWriteOnly,
    fomReadWrite
  );

  {** @desc 文件创建模式 *}
  TPlatformFileCreateMode = (
    fcmOpenExisting,
    fcmCreateAlways,
    fcmCreateNew,
    fcmOpenOrCreate,
    fcmTruncateExisting
  );

  {** @desc 文件定位原点 *}
  TPlatformFileSeekOrigin = (
    fsoBegin,
    fsoCurrent,
    fsoEnd
  );

  {** @desc 目录条目 *}
  TPlatformDirEntry = record
    Name: array[0..255] of AnsiChar;
    NameLen: Int32;
    FileType: TPlatformFileType;
    Ino: UInt64;
    {** @desc 检查是否为普通文件
        @return True 如果是普通文件 *}
    function IsRegular: Boolean; inline;
    {** @desc 检查是否为目录
        @return True 如果是目录 *}
    function IsDirectory: Boolean; inline;
    {** @desc 检查是否为符号链接
        @return True 如果是符号链接 *}
    function IsSymlink: Boolean; inline;
    {** @desc 检查是否为特殊文件（字符设备、块设备、FIFO、套接字）
        @return True 如果是特殊文件 *}
    function IsSpecial: Boolean; inline;
    {** @desc 检查是否为当前目录（.）
        @return True 如果是当前目录 *}
    function IsCurrentDir: Boolean; inline;
    {** @desc 检查是否为父目录（..）
        @return True 如果是父目录 *}
    function IsParentDir: Boolean; inline;
    {** @desc 检查是否为隐藏文件（以 . 开头）
        @return True 如果是隐藏文件 *}
    function IsHidden: Boolean; inline;
    {** @desc 检查是否为特殊目录（. 或 ..）
        @return True 如果是特殊目录 *}
    function IsSpecialDir: Boolean; inline;
    {** @desc 获取文件名字符串（带长度）
        @return 文件名字符串切片 *}
    function NameStr: AnsiString;
  end;

  {** @desc 目录遍历句柄（平台无关封装） *}
  TPlatformDirHandle = record
  {$IFDEF NEXTPAS_WINDOWS}
    FindHandle: HANDLE;
    FindData: WIN32_FIND_DATAW;
    First: Boolean;
    Finished: Boolean;
  {$ELSE}
    Fd: cint;
    Buf: array[0..4095] of Byte;
    Pos: Int32;
    Len: Int32;
  {$ENDIF}
    {** @desc 检查目录句柄是否有效
        @return True 如果句柄有效 *}
    function IsValid: Boolean; inline;
    {** @desc 检查目录句柄是否无效
        @return True 如果句柄无效 *}
    function IsInvalid: Boolean; inline;
  end;

const
  {** @desc 无效文件句柄 *}
  PLATFORM_FILE_INVALID_HANDLE: TPlatformFileHandle = (
  {$IFDEF NEXTPAS_WINDOWS}
    Value: HANDLE(PtrInt(-1))
  {$ELSE}
    Value: -1
  {$ENDIF}
  );

  { POSIX d_type constants for directory entries }
  {** @desc FIFO 类型 *}
  PLATFORM_DT_FIFO = 1;
  {** @desc 字符设备类型 *}
  PLATFORM_DT_CHR  = 2;
  {** @desc 目录类型 *}
  PLATFORM_DT_DIR  = 4;
  {** @desc 块设备类型 *}
  PLATFORM_DT_BLK  = 6;
  {** @desc 普通文件类型 *}
  PLATFORM_DT_REG  = 8;
  {** @desc 符号链接类型 *}
  PLATFORM_DT_LNK  = 10;
  {** @desc 套接字类型 *}
  PLATFORM_DT_SOCK = 12;

  { POSIX file permission bits }
  {** @desc 所有者读权限 *}
  PLATFORM_S_IRUSR = $0100;  { 0400 octal }
  {** @desc 所有者写权限 *}
  PLATFORM_S_IWUSR = $0080;  { 0200 octal }
  {** @desc 所有者执行权限 *}
  PLATFORM_S_IXUSR = $0040;  { 0100 octal }
  {** @desc 组读权限 *}
  PLATFORM_S_IRGRP = $0020;  { 0040 octal }
  {** @desc 组写权限 *}
  PLATFORM_S_IWGRP = $0010;  { 0020 octal }
  {** @desc 组执行权限 *}
  PLATFORM_S_IXGRP = $0008;  { 0010 octal }
  {** @desc 其他读权限 *}
  PLATFORM_S_IROTH = $0004;  { 0004 octal }
  {** @desc 其他写权限 *}
  PLATFORM_S_IWOTH = $0002;  { 0002 octal }
  {** @desc 其他执行权限 *}
  PLATFORM_S_IXOTH = $0001;  { 0001 octal }

  { Common permission combinations }
  {** @desc 所有者读写权限 *}
  PLATFORM_S_IRUSR_IWUSR = PLATFORM_S_IRUSR or PLATFORM_S_IWUSR;
  {** @desc 所有者读写执行权限 *}
  PLATFORM_S_IRWXU = PLATFORM_S_IRUSR or PLATFORM_S_IWUSR or PLATFORM_S_IXUSR;
  {** @desc 所有者和组读写权限 *}
  PLATFORM_S_IRWXU_IRWXG = PLATFORM_S_IRWXU or PLATFORM_S_IRGRP or PLATFORM_S_IWGRP or PLATFORM_S_IXGRP;
  {** @desc 所有者、组和其他读写执行权限 *}
  PLATFORM_S_IRWXA = PLATFORM_S_IRWXU_IRWXG or PLATFORM_S_IROTH or PLATFORM_S_IWOTH or PLATFORM_S_IXOTH;

implementation

function TPlatformFileHandle.IsValid: Boolean;
begin
{$IFDEF NEXTPAS_WINDOWS}
  Result := Value <> HANDLE(PtrInt(-1));
{$ELSE}
  Result := Value >= 0;
{$ENDIF}
end;

function TPlatformFileHandle.IsInvalid: Boolean;
begin
{$IFDEF NEXTPAS_WINDOWS}
  Result := Value = HANDLE(PtrInt(-1));
{$ELSE}
  Result := Value < 0;
{$ENDIF}
end;

function TPlatformFileStat.IsRegular: Boolean;
begin
  Result := FileType = ftRegular;
end;

function TPlatformFileStat.IsDirectory: Boolean;
begin
  Result := FileType = ftDirectory;
end;

function TPlatformFileStat.IsSymlink: Boolean;
begin
  Result := FileType = ftSymlink;
end;

function TPlatformFileStat.IsSpecial: Boolean;
begin
  Result := FileType in [ftCharDevice, ftBlockDevice, ftFifo, ftSocket];
end;

function TPlatformFileStat.IsOwnerReadable: Boolean;
begin
  Result := (Mode and PLATFORM_S_IRUSR) <> 0;
end;

function TPlatformFileStat.IsOwnerWritable: Boolean;
begin
  Result := (Mode and PLATFORM_S_IWUSR) <> 0;
end;

function TPlatformFileStat.IsOwnerExecutable: Boolean;
begin
  Result := (Mode and PLATFORM_S_IXUSR) <> 0;
end;

function TPlatformFileStat.IsGroupReadable: Boolean;
begin
  Result := (Mode and PLATFORM_S_IRGRP) <> 0;
end;

function TPlatformFileStat.IsGroupWritable: Boolean;
begin
  Result := (Mode and PLATFORM_S_IWGRP) <> 0;
end;

function TPlatformFileStat.IsGroupExecutable: Boolean;
begin
  Result := (Mode and PLATFORM_S_IXGRP) <> 0;
end;

function TPlatformFileStat.IsOtherReadable: Boolean;
begin
  Result := (Mode and PLATFORM_S_IROTH) <> 0;
end;

function TPlatformFileStat.IsOtherWritable: Boolean;
begin
  Result := (Mode and PLATFORM_S_IWOTH) <> 0;
end;

function TPlatformFileStat.IsOtherExecutable: Boolean;
begin
  Result := (Mode and PLATFORM_S_IXOTH) <> 0;
end;

function TPlatformDirHandle.IsValid: Boolean;
begin
{$IFDEF NEXTPAS_WINDOWS}
  Result := FindHandle <> HANDLE(INVALID_HANDLE_VALUE);
{$ELSE}
  Result := Fd >= 0;
{$ENDIF}
end;

function TPlatformDirHandle.IsInvalid: Boolean;
begin
{$IFDEF NEXTPAS_WINDOWS}
  Result := FindHandle = HANDLE(INVALID_HANDLE_VALUE);
{$ELSE}
  Result := Fd < 0;
{$ENDIF}
end;

function TPlatformDirEntry.IsRegular: Boolean;
begin
  Result := FileType = ftRegular;
end;

function TPlatformDirEntry.IsDirectory: Boolean;
begin
  Result := FileType = ftDirectory;
end;

function TPlatformDirEntry.IsSymlink: Boolean;
begin
  Result := FileType = ftSymlink;
end;

function TPlatformDirEntry.IsSpecial: Boolean;
begin
  Result := FileType in [ftCharDevice, ftBlockDevice, ftFifo, ftSocket];
end;

function TPlatformDirEntry.IsCurrentDir: Boolean;
begin
  Result := (NameLen = 1) and (Name[0] = '.');
end;

function TPlatformDirEntry.IsParentDir: Boolean;
begin
  Result := (NameLen = 2) and (Name[0] = '.') and (Name[1] = '.');
end;

function TPlatformDirEntry.IsHidden: Boolean;
begin
  Result := (NameLen > 0) and (Name[0] = '.');
end;

function TPlatformDirEntry.IsSpecialDir: Boolean;
begin
  Result := IsCurrentDir or IsParentDir;
end;

function TPlatformDirEntry.NameStr: AnsiString;
begin
  SetString(Result, PAnsiChar(@Name[0]), NameLen);
end;

end.
