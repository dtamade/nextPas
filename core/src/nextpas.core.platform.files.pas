{**
 * nextpas.core.platform.files - 底层文件 I/O 操作
 *
 * 职责：文件描述符级操作（open/close/read/write/seek/stat/dir）
 * 层次：fd 级操作，不包含路径遍历或目录树操作
 *
 * 与 fs.pas 的关系：
 *   - files.pas = 底层 fd 操作（open/close/read/write/stat/dir）
 *   - fs.pas = 高层文件系统操作（exists/is_file/mkdir_p/copy_file/walk）
 *   - fs.pas 依赖 files.pas
 *}
unit nextpas.core.platform.files;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.files.base,
  nextpas.core.platform.error;

{** @desc 打开文件
    @param APath 文件路径
    @param AMode 打开模式（只读/只写/读写）
    @param ACreate 创建模式
    @param AHandle 输出文件句柄
    @return 0 成功，否则返回错误码 *}
function platform_file_open(const APath: PAnsiChar; AMode: TPlatformFileOpenMode;
  ACreate: TPlatformFileCreateMode; out AHandle: TPlatformFileHandle): Int32;

{** @desc 打开文件（扩展参数）
    @param APath 文件路径
    @param AMode 打开模式
    @param ACreate 创建模式
    @param AAppend 是否追加模式
    @param ASync 是否同步模式
    @param APerm 文件权限
    @param AHandle 输出文件句柄
    @return 0 成功，否则返回错误码 *}
function platform_file_open_ex(const APath: PAnsiChar; AMode: TPlatformFileOpenMode;
  ACreate: TPlatformFileCreateMode; AAppend: Boolean; ASync: Boolean;
  APerm: UInt32; out AHandle: TPlatformFileHandle): Int32;

{** @desc 关闭文件
    @param AHandle 文件句柄（置为无效）
    @return 0 成功，否则返回错误码 *}
function platform_file_close(var AHandle: TPlatformFileHandle): Int32;

{** @desc 读取文件数据
    @param AHandle 文件句柄
    @param ABuf 读取缓冲区
    @param ALen 读取长度
    @param ABytesRead 输出实际读取字节数
    @return 0 成功，否则返回错误码 *}
function platform_file_read(const AHandle: TPlatformFileHandle; ABuf: Pointer;
  ALen: PtrUInt; out ABytesRead: PtrUInt): Int32;

{** @desc 写入文件数据
    @param AHandle 文件句柄
    @param ABuf 写入缓冲区
    @param ALen 写入长度
    @param ABytesWritten 输出实际写入字节数
    @return 0 成功，否则返回错误码 *}
function platform_file_write(const AHandle: TPlatformFileHandle; ABuf: Pointer;
  ALen: PtrUInt; out ABytesWritten: PtrUInt): Int32;

{** @desc 从指定偏移读取文件数据（不影响文件位置）
    @param AHandle 文件句柄
    @param ABuf 读取缓冲区
    @param ALen 读取长度
    @param AOffset 文件偏移
    @param ABytesRead 输出实际读取字节数
    @return 0 成功，否则返回错误码 *}
function platform_file_pread(const AHandle: TPlatformFileHandle; ABuf: Pointer;
  ALen: PtrUInt; AOffset: Int64; out ABytesRead: PtrUInt): Int32;

{** @desc 从指定偏移写入文件数据（不影响文件位置）
    @param AHandle 文件句柄
    @param ABuf 写入缓冲区
    @param ALen 写入长度
    @param AOffset 文件偏移
    @param ABytesWritten 输出实际写入字节数
    @return 0 成功，否则返回错误码 *}
function platform_file_pwrite(const AHandle: TPlatformFileHandle; ABuf: Pointer;
  ALen: PtrUInt; AOffset: Int64; out ABytesWritten: PtrUInt): Int32;

{** @desc 定位文件位置
    @param AHandle 文件句柄
    @param AOffset 偏移量
    @param AOrigin 定位原点（Begin/Current/End）
    @param ANewPos 输出新位置
    @return 0 成功，否则返回错误码 *}
function platform_file_seek(const AHandle: TPlatformFileHandle; AOffset: Int64;
  AOrigin: TPlatformFileSeekOrigin; out ANewPos: Int64): Int32;

{** @desc 同步文件到磁盘
    @param AHandle 文件句柄
    @return 0 成功，否则返回错误码 *}
function platform_file_sync(const AHandle: TPlatformFileHandle): Int32;

{** @desc 截断文件到指定大小（通过句柄）
    @param AHandle 文件句柄
    @param ASize 目标大小
    @return 0 成功，否则返回错误码 *}
function platform_file_truncate(const AHandle: TPlatformFileHandle; ASize: Int64): Int32;

{** @desc 获取文件状态（通过路径，跟随符号链接）
    @param APath 文件路径
    @param AStat 输出文件状态
    @return 0 成功，否则返回错误码 *}
function platform_file_stat(const APath: PAnsiChar; out AStat: TPlatformFileStat): Int32;

{** @desc 获取文件状态（通过路径，不跟随符号链接）
    @param APath 文件路径
    @param AStat 输出文件状态
    @return 0 成功，否则返回错误码 *}
function platform_file_lstat(const APath: PAnsiChar; out AStat: TPlatformFileStat): Int32;

{** @desc 获取文件状态（通过句柄）
    @param AHandle 文件句柄
    @param AStat 输出文件状态
    @return 0 成功，否则返回错误码 *}
function platform_file_fstat(const AHandle: TPlatformFileHandle; out AStat: TPlatformFileStat): Int32;

{** @desc 修改文件权限
    @param APath 文件路径
    @param AMode 新权限
    @return 0 成功，否则返回错误码 *}
function platform_file_chmod(const APath: PAnsiChar; AMode: UInt32): Int32;

{** @desc 截断文件到指定大小（通过路径）
    @param APath 文件路径
    @param ASize 目标大小
    @return 0 成功，否则返回错误码 *}
function platform_file_truncate_path(const APath: PAnsiChar; ASize: Int64): Int32;

{** @desc 创建目录
    @param APath 目录路径
    @param AMode 目录权限
    @return 0 成功，否则返回错误码 *}
function platform_file_mkdir(const APath: PAnsiChar; AMode: UInt32): Int32;

{** @desc 删除空目录
    @param APath 目录路径
    @return 0 成功，否则返回错误码 *}
function platform_file_rmdir(const APath: PAnsiChar): Int32;

{** @desc 删除文件
    @param APath 文件路径
    @return 0 成功，否则返回错误码 *}
function platform_file_unlink(const APath: PAnsiChar): Int32;

{** @desc 重命名文件或目录
    @param AOldPath 原路径
    @param ANewPath 新路径
    @return 0 成功，否则返回错误码 *}
function platform_file_rename(const AOldPath: PAnsiChar; const ANewPath: PAnsiChar): Int32;

{** @desc 获取当前工作目录
    @param ABuf 输出缓冲区
    @param ASize 缓冲区大小
    @return 缓冲区指针，失败返回 nil *}
function platform_file_getcwd(ABuf: PAnsiChar; ASize: PtrUInt): PAnsiChar;

{** @desc 更改当前工作目录
    @param APath 目标目录路径
    @return 0 成功，否则返回错误码 *}
function platform_file_chdir(const APath: PAnsiChar): Int32;

{** @desc 获取文件锁（阻塞）
    @param AHandle 文件句柄
    @param AExclusive True 独占锁，False 共享锁
    @return 0 成功，否则返回错误码 *}
function platform_file_lock(const AHandle: TPlatformFileHandle; AExclusive: Boolean): Int32;

{** @desc 尝试获取文件锁（非阻塞）
    @param AHandle 文件句柄
    @param AExclusive True 独占锁，False 共享锁
    @return 0 成功，PLATFORM_ERR_BUSY 锁被占用 *}
function platform_file_trylock(const AHandle: TPlatformFileHandle; AExclusive: Boolean): Int32;

{** @desc 释放文件锁
    @param AHandle 文件句柄
    @return 0 成功，否则返回错误码 *}
function platform_file_unlock(const AHandle: TPlatformFileHandle): Int32;

{** @desc 创建符号链接
    @param ATarget 链接目标
    @param ALinkPath 链接路径
    @return 0 成功，否则返回错误码 *}
function platform_file_symlink(const ATarget: PAnsiChar; const ALinkPath: PAnsiChar): Int32;

{** @desc 读取符号链接目标
    @param APath 符号链接路径
    @param ABuf 输出缓冲区
    @param ABufSize 缓冲区大小
    @param ALen 输出实际长度
    @return 0 成功，否则返回错误码 *}
function platform_file_readlink(const APath: PAnsiChar; ABuf: PAnsiChar; ABufSize: Int32; out ALen: Int32): Int32;

{** @desc 打开目录
    @param APath 目录路径
    @param AHandle 输出目录句柄
    @return 0 成功，否则返回错误码 *}
function platform_dir_open(const APath: PAnsiChar; out AHandle: TPlatformDirHandle): Int32;

{** @desc 读取目录条目
    @param AHandle 目录句柄
    @param AEntry 输出目录条目
    @return 0 成功，1 无更多条目，否则返回错误码 *}
function platform_dir_read(var AHandle: TPlatformDirHandle; out AEntry: TPlatformDirEntry): Int32;

{** @desc 关闭目录
    @param AHandle 目录句柄（置为无效）
    @return 0 成功，否则返回错误码 *}
function platform_dir_close(var AHandle: TPlatformDirHandle): Int32;

implementation

{$IFDEF NEXTPAS_UNIX}
uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.posix.helpers
{$IFDEF NEXTPAS_LINUX}
  , nextpas.core.platform.linux.base
  , nextpas.core.platform.linux.ffi
{$ENDIF}
{$IFDEF NEXTPAS_MACOS}
  , nextpas.core.platform.darwin.base
  , nextpas.core.platform.darwin.ffi
{$ENDIF}
{$IFDEF NEXTPAS_FREEBSD}
  , nextpas.core.platform.freebsd.base
  , nextpas.core.platform.freebsd.ffi
{$ENDIF}
{$IFDEF NEXTPAS_ANDROID}
  , nextpas.core.platform.android.base
  , nextpas.core.platform.android.ffi
{$ENDIF}
  ;

{ 文件描述符转换辅助函数 }
function FdToFileHandle(AFd: cint; out AHandle: TPlatformFileHandle): Int32; inline;
begin
  Result := PosixFdToHandle(AFd, AHandle.Value);
end;
{$ENDIF}
{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.windows.base,
  nextpas.core.platform.windows.ffi,
  nextpas.core.platform.windows.utf16;
{$ENDIF}

const
  {** @desc 默认文件创建权限（0666 八进制） *}
  PLATFORM_DEFAULT_FILE_MODE = 438;

{$IFDEF NEXTPAS_UNIX}
function platform_file_open(const APath: PAnsiChar; AMode: TPlatformFileOpenMode;
  ACreate: TPlatformFileCreateMode; out AHandle: TPlatformFileHandle): Int32;
begin
  Result := platform_file_open_ex(APath, AMode, ACreate, False, False, PLATFORM_DEFAULT_FILE_MODE, AHandle);
end;

function platform_file_open_ex(const APath: PAnsiChar; AMode: TPlatformFileOpenMode;
  ACreate: TPlatformFileCreateMode; AAppend: Boolean; ASync: Boolean;
  APerm: UInt32; out AHandle: TPlatformFileHandle): Int32;
var
  LFlags: Int32;
begin
  AHandle.Value := -1;
  if APath = nil then
    Exit(PLATFORM_ERR_INVALID);
  case AMode of
    fomReadOnly:  LFlags := O_RDONLY;
    fomWriteOnly: LFlags := O_WRONLY;
    fomReadWrite: LFlags := O_RDWR;
  end;
  case ACreate of
    fcmOpenExisting:    ;
    fcmCreateAlways:    LFlags := LFlags or O_CREAT or O_TRUNC;
    fcmCreateNew:       LFlags := LFlags or O_CREAT or O_EXCL;
    fcmOpenOrCreate:    LFlags := LFlags or O_CREAT;
    fcmTruncateExisting: LFlags := LFlags or O_TRUNC;
  end;
  if AAppend then
    LFlags := LFlags or O_APPEND;
  if ASync then
    LFlags := LFlags or O_SYNC;
  LFlags := LFlags or O_CLOEXEC;
  Result := FdToFileHandle(open(APath, LFlags, APerm), AHandle);
end;

function platform_file_close(var AHandle: TPlatformFileHandle): Int32;
begin
  if AHandle.Value < 0 then
    Exit(PLATFORM_ERR_BADF);
  Result := PosixCheck(close(AHandle.Value));
  AHandle.Value := -1;
end;

function platform_file_read(const AHandle: TPlatformFileHandle; ABuf: Pointer;
  ALen: PtrUInt; out ABytesRead: PtrUInt): Int32;
begin
  ABytesRead := 0;
  if ABuf = nil then
    Exit(PLATFORM_ERR_INVALID);
  if ALen = 0 then
    Exit(0);
  Result := PosixSsizeToResult(read(AHandle.Value, ABuf, ALen), ABytesRead);
end;

function platform_file_write(const AHandle: TPlatformFileHandle; ABuf: Pointer;
  ALen: PtrUInt; out ABytesWritten: PtrUInt): Int32;
begin
  ABytesWritten := 0;
  if ABuf = nil then
    Exit(PLATFORM_ERR_INVALID);
  if ALen = 0 then
    Exit(0);
  Result := PosixSsizeToResult(write(AHandle.Value, ABuf, ALen), ABytesWritten);
end;

function platform_file_pread(const AHandle: TPlatformFileHandle; ABuf: Pointer;
  ALen: PtrUInt; AOffset: Int64; out ABytesRead: PtrUInt): Int32;
begin
  ABytesRead := 0;
  if ABuf = nil then
    Exit(PLATFORM_ERR_INVALID);
  if ALen = 0 then
    Exit(0);
  Result := PosixSsizeToResult(pread(AHandle.Value, ABuf, ALen, AOffset), ABytesRead);
end;

function platform_file_pwrite(const AHandle: TPlatformFileHandle; ABuf: Pointer;
  ALen: PtrUInt; AOffset: Int64; out ABytesWritten: PtrUInt): Int32;
begin
  ABytesWritten := 0;
  if ABuf = nil then
    Exit(PLATFORM_ERR_INVALID);
  if ALen = 0 then
    Exit(0);
  Result := PosixSsizeToResult(pwrite(AHandle.Value, ABuf, ALen, AOffset), ABytesWritten);
end;

function platform_file_seek(const AHandle: TPlatformFileHandle; AOffset: Int64;
  AOrigin: TPlatformFileSeekOrigin; out ANewPos: Int64): Int32;
var
  LWhence: Int32;
begin
  case AOrigin of
    fsoBegin:   LWhence := 0;
    fsoCurrent: LWhence := 1;
    fsoEnd:     LWhence := 2;
  end;
  Result := PosixOffToResult(lseek(AHandle.Value, AOffset, LWhence), ANewPos);
end;

function platform_file_sync(const AHandle: TPlatformFileHandle): Int32;
begin
  Result := PosixCheck(fsync(AHandle.Value));
end;

function platform_file_truncate(const AHandle: TPlatformFileHandle; ASize: Int64): Int32;
begin
  Result := PosixCheck(ftruncate(AHandle.Value, ASize));
end;

function ClassifyDirEntryDType(ADType: Byte): TPlatformFileType;
begin
  case ADType of
    PLATFORM_DT_REG:  Result := ftRegular;
    PLATFORM_DT_DIR:  Result := ftDirectory;
    PLATFORM_DT_LNK:  Result := ftSymlink;
    PLATFORM_DT_CHR:  Result := ftCharDevice;
    PLATFORM_DT_BLK:  Result := ftBlockDevice;
    PLATFORM_DT_FIFO: Result := ftFifo;
    PLATFORM_DT_SOCK: Result := ftSocket;
  else
    Result := ftUnknown;
  end;
end;

procedure ClassifyStatType(var AStat: TPlatformFileStat);
begin
  case AStat.Mode and S_IFMT of
    S_IFREG:  AStat.FileType := ftRegular;
    S_IFDIR:  AStat.FileType := ftDirectory;
    S_IFLNK:  AStat.FileType := ftSymlink;
    S_IFCHR:  AStat.FileType := ftCharDevice;
    S_IFBLK:  AStat.FileType := ftBlockDevice;
    S_IFIFO:  AStat.FileType := ftFifo;
    S_IFSOCK: AStat.FileType := ftSocket;
  else
    AStat.FileType := ftUnknown;
  end;
end;

{$IFDEF NEXTPAS_LINUX}
procedure FillPlatformStat(const LStat: TPlatformLinuxStat; out AStat: TPlatformFileStat);
begin
  FillChar(AStat, SizeOf(AStat), 0);
  AStat.Size := LStat.st_size;
  AStat.Mode := LStat.st_mode;
  AStat.Uid := LStat.st_uid;
  AStat.Gid := LStat.st_gid;
  AStat.NLink := UInt32(LStat.st_nlink);
  AStat.Dev := LStat.st_dev;
  AStat.Ino := LStat.st_ino;
  AStat.ModTime := Int64(LStat.st_mtime) * 1000000000 + Int64(LStat.st_mtime_nsec);
  AStat.AccessTime := Int64(LStat.st_atime) * 1000000000 + Int64(LStat.st_atime_nsec);
  AStat.CreateTime := Int64(LStat.st_ctime) * 1000000000 + Int64(LStat.st_ctime_nsec);
  ClassifyStatType(AStat);
end;
{$ENDIF}
{$IFDEF NEXTPAS_MACOS}
procedure FillPlatformStat(const LStat: TDarwinStat; out AStat: TPlatformFileStat);
begin
  FillChar(AStat, SizeOf(AStat), 0);
  AStat.Size := LStat.st_size;
  AStat.Mode := UInt32(LStat.st_mode);
  AStat.Uid := LStat.st_uid;
  AStat.Gid := LStat.st_gid;
  AStat.NLink := UInt32(LStat.st_nlink);
  AStat.Dev := UInt64(LStat.st_dev);
  AStat.Ino := LStat.st_ino;
  AStat.ModTime := LStat.st_mtime * 1000000000 + LStat.st_mtimensec;
  AStat.AccessTime := LStat.st_atime * 1000000000 + LStat.st_atimensec;
  AStat.CreateTime := LStat.st_ctime * 1000000000 + LStat.st_ctimensec;
  ClassifyStatType(AStat);
end;
{$ENDIF}
{$IFDEF NEXTPAS_FREEBSD}
procedure FillPlatformStat(const LStat: TFreeBSDStat; out AStat: TPlatformFileStat);
begin
  FillChar(AStat, SizeOf(AStat), 0);
  AStat.Size := LStat.st_size;
  AStat.Mode := UInt32(LStat.st_mode);
  AStat.Uid := LStat.st_uid;
  AStat.Gid := LStat.st_gid;
  AStat.NLink := UInt32(LStat.st_nlink);
  AStat.Dev := LStat.st_dev;
  AStat.Ino := LStat.st_ino;
  AStat.ModTime := LStat.st_mtime * 1000000000 + LStat.st_mtimensec;
  AStat.AccessTime := LStat.st_atime * 1000000000 + LStat.st_atimensec;
  AStat.CreateTime := LStat.st_ctime * 1000000000 + LStat.st_ctimensec;
  ClassifyStatType(AStat);
end;
{$ENDIF}
{$IFDEF NEXTPAS_ANDROID}
procedure FillPlatformStat(const LStat: TPlatformAndroidStat; out AStat: TPlatformFileStat);
begin
  FillChar(AStat, SizeOf(AStat), 0);
  AStat.Size := LStat.st_size;
  AStat.Mode := LStat.st_mode;
  AStat.Uid := LStat.st_uid;
  AStat.Gid := LStat.st_gid;
  AStat.NLink := UInt32(LStat.st_nlink);
  AStat.Dev := LStat.st_dev;
  AStat.Ino := LStat.st_ino;
  AStat.ModTime := Int64(LStat.st_mtime) * 1000000000 + Int64(LStat.st_mtime_nsec);
  AStat.AccessTime := Int64(LStat.st_atime) * 1000000000 + Int64(LStat.st_atime_nsec);
  AStat.CreateTime := Int64(LStat.st_ctime) * 1000000000 + Int64(LStat.st_ctime_nsec);
  ClassifyStatType(AStat);
end;
{$ENDIF}

function platform_file_stat(const APath: PAnsiChar; out AStat: TPlatformFileStat): Int32;
var
  LStat: {$IFDEF NEXTPAS_LINUX}TPlatformLinuxStat{$ENDIF}
         {$IFDEF NEXTPAS_MACOS}TDarwinStat{$ENDIF}
         {$IFDEF NEXTPAS_FREEBSD}TFreeBSDStat{$ENDIF}
         {$IFDEF NEXTPAS_ANDROID}TPlatformAndroidStat{$ENDIF};
begin
  if APath = nil then
  begin
    FillChar(AStat, SizeOf(AStat), 0);
    Exit(PLATFORM_ERR_INVALID);
  end;
{$IFDEF NEXTPAS_LINUX}
  if fstatat(AT_FDCWD, APath, LStat, 0) <> 0 then
    Exit(platform_get_errno);
{$ELSEIF defined(NEXTPAS_ANDROID)}
  if syscall(ANDROID_SYSCALL_NEWFSTATAT, PtrUInt(PLATFORM_ANDROID_AT_FDCWD),
    PtrUInt(APath), PtrUInt(@LStat), 0, 0, 0) <> 0 then
    Exit(platform_get_errno);
{$ELSE}
  if fpstat(APath, @LStat) <> 0 then
    Exit(platform_get_errno);
{$ENDIF}
  FillPlatformStat(LStat, AStat);
  Result := 0;
end;

function platform_file_lstat(const APath: PAnsiChar; out AStat: TPlatformFileStat): Int32;
var
  LStat: {$IFDEF NEXTPAS_LINUX}TPlatformLinuxStat{$ENDIF}
         {$IFDEF NEXTPAS_MACOS}TDarwinStat{$ENDIF}
         {$IFDEF NEXTPAS_FREEBSD}TFreeBSDStat{$ENDIF}
         {$IFDEF NEXTPAS_ANDROID}TPlatformAndroidStat{$ENDIF};
begin
  if APath = nil then
  begin
    FillChar(AStat, SizeOf(AStat), 0);
    Exit(PLATFORM_ERR_INVALID);
  end;
{$IFDEF NEXTPAS_LINUX}
  if fstatat(AT_FDCWD, APath, LStat, AT_SYMLINK_NOFOLLOW) <> 0 then
    Exit(platform_get_errno);
{$ELSEIF defined(NEXTPAS_ANDROID)}
  if syscall(ANDROID_SYSCALL_NEWFSTATAT, PtrUInt(PLATFORM_ANDROID_AT_FDCWD),
    PtrUInt(APath), PtrUInt(@LStat),
    PtrUInt(PLATFORM_ANDROID_AT_SYMLINK_NOFOLLOW), 0, 0) <> 0 then
    Exit(platform_get_errno);
{$ELSE}
  if fplstat(APath, @LStat) <> 0 then
    Exit(platform_get_errno);
{$ENDIF}
  FillPlatformStat(LStat, AStat);
  Result := 0;
end;

function platform_file_fstat(const AHandle: TPlatformFileHandle; out AStat: TPlatformFileStat): Int32;
var
  LStat: {$IFDEF NEXTPAS_LINUX}TPlatformLinuxStat{$ENDIF}
         {$IFDEF NEXTPAS_MACOS}TDarwinStat{$ENDIF}
         {$IFDEF NEXTPAS_FREEBSD}TFreeBSDStat{$ENDIF}
         {$IFDEF NEXTPAS_ANDROID}TPlatformAndroidStat{$ENDIF};
begin
{$IFDEF NEXTPAS_LINUX}
  if __fxstat(1, AHandle.Value, LStat) <> 0 then
    Exit(platform_get_errno);
{$ELSEIF defined(NEXTPAS_ANDROID)}
  if syscall(ANDROID_SYSCALL_FSTAT, PtrUInt(AHandle.Value),
    PtrUInt(@LStat), 0, 0, 0, 0) <> 0 then
    Exit(platform_get_errno);
{$ELSE}
  if fpfstat(AHandle.Value, @LStat) <> 0 then
    Exit(platform_get_errno);
{$ENDIF}
  FillPlatformStat(LStat, AStat);
  Result := 0;
end;

function platform_file_chmod(const APath: PAnsiChar; AMode: UInt32): Int32;
begin
  if APath = nil then
    Exit(PLATFORM_ERR_INVALID);
  Result := PosixCheck(chmod(APath, AMode));
end;

function platform_file_truncate_path(const APath: PAnsiChar; ASize: Int64): Int32;
begin
  if APath = nil then
    Exit(PLATFORM_ERR_INVALID);
  Result := PosixCheck(truncate(APath, ASize));
end;

function platform_file_mkdir(const APath: PAnsiChar; AMode: UInt32): Int32;
begin
  if APath = nil then
    Exit(PLATFORM_ERR_INVALID);
  Result := PosixCheck(mkdir(APath, AMode));
end;

function platform_file_rmdir(const APath: PAnsiChar): Int32;
begin
  if APath = nil then
    Exit(PLATFORM_ERR_INVALID);
  Result := PosixCheck(rmdir(APath));
end;

function platform_file_unlink(const APath: PAnsiChar): Int32;
begin
  if APath = nil then
    Exit(PLATFORM_ERR_INVALID);
  Result := PosixCheck(unlink(APath));
end;

function platform_file_rename(const AOldPath: PAnsiChar; const ANewPath: PAnsiChar): Int32;
begin
  if (AOldPath = nil) or (ANewPath = nil) then
    Exit(PLATFORM_ERR_INVALID);
  Result := PosixCheck(rename(AOldPath, ANewPath));
end;

function platform_file_getcwd(ABuf: PAnsiChar; ASize: PtrUInt): PAnsiChar;
begin
  if (ABuf = nil) or (ASize = 0) then
    Exit(nil);
  Result := getcwd(ABuf, ASize);
end;

function platform_file_chdir(const APath: PAnsiChar): Int32;
begin
  if APath = nil then
    Exit(PLATFORM_ERR_INVALID);
  Result := PosixCheck(chdir(APath));
end;

function platform_file_lock(const AHandle: TPlatformFileHandle; AExclusive: Boolean): Int32;
var
  LFlags: Int32;
begin
  if AExclusive then
    LFlags := LOCK_EX
  else
    LFlags := LOCK_SH;
  Result := PosixCheck(nextpas.core.platform.posix.ffi.flock(AHandle.Value, LFlags));
end;

function platform_file_trylock(const AHandle: TPlatformFileHandle; AExclusive: Boolean): Int32;
var
  LFlags: Int32;
begin
  if AExclusive then
    LFlags := LOCK_EX or LOCK_NB
  else
    LFlags := LOCK_SH or LOCK_NB;
  if nextpas.core.platform.posix.ffi.flock(AHandle.Value, LFlags) = 0 then
    Result := 0
  else
    Result := platform_get_errno;
end;

function platform_file_unlock(const AHandle: TPlatformFileHandle): Int32;
begin
  if nextpas.core.platform.posix.ffi.flock(AHandle.Value, LOCK_UN) = 0 then
    Result := 0
  else
    Result := platform_get_errno;
end;

function platform_file_symlink(const ATarget: PAnsiChar; const ALinkPath: PAnsiChar): Int32;
begin
  if (ATarget = nil) or (ALinkPath = nil) then
    Exit(PLATFORM_ERR_INVALID);
  Result := PosixCheck(symlink(ATarget, ALinkPath));
end;

function platform_file_readlink(const APath: PAnsiChar; ABuf: PAnsiChar; ABufSize: Int32; out ALen: Int32): Int32;
var
  LStat: TPlatformFileStat;
  LResult: PtrInt;
  LCopyLen: Int32;
begin
  ALen := 0;
  if APath = nil then
    Exit(PLATFORM_ERR_INVALID);
  if (ABuf = nil) or (ABufSize <= 0) then
    Exit(PLATFORM_ERR_INVALID);
  Result := platform_file_lstat(APath, LStat);
  if Result <> 0 then
    Exit;
  if LStat.Size < 0 then
    Exit(-1);
  if LStat.Size > High(Int32) then
    Exit(-1);
  ALen := Int32(LStat.Size);
  LCopyLen := ALen;
  if LCopyLen >= ABufSize then
    LCopyLen := ABufSize - 1;
  if LCopyLen <= 0 then
  begin
    ABuf[0] := #0;
    Result := 0;
    Exit;
  end;
  LResult := readlink(APath, ABuf, LCopyLen);
  if LResult < 0 then
    Exit(PosixCheck(-1));
  ABuf[LResult] := #0;
  Result := 0;
end;

function platform_dir_open(const APath: PAnsiChar; out AHandle: TPlatformDirHandle): Int32;
begin
  FillChar(AHandle, SizeOf(AHandle), 0);
  if APath = nil then
    Exit(PLATFORM_ERR_INVALID);
  Result := PosixFdToHandle(open(APath, O_RDONLY or O_DIRECTORY, 0), AHandle.Fd);
end;

function platform_dir_read(var AHandle: TPlatformDirHandle; out AEntry: TPlatformDirEntry): Int32;
{$IF defined(NEXTPAS_LINUX) or defined(NEXTPAS_ANDROID)}
type
  PDirent64 = ^TDirent64;
  TDirent64 = packed record
    d_ino: UInt64;
    d_off: Int64;
    d_reclen: UInt16;
    d_type: Byte;
    d_name: array[0..0] of AnsiChar;
  end;
var
  LDent: PDirent64;
  LNameLen: Int32;
  LNamePtr: PAnsiChar;
{$ENDIF}
{$IFDEF NEXTPAS_MACOS}
type
  PDarwinDirent = ^TDarwinDirent;
  TDarwinDirent = packed record
    d_ino: UInt64;
    d_seekoff: UInt64;
    d_reclen: UInt16;
    d_namlen: UInt16;
    d_type: Byte;
    d_name: array[0..0] of AnsiChar;
  end;
var
  LDent: PDarwinDirent;
  LNameLen: Int32;
  LNamePtr: PAnsiChar;
  LBase: Int64;
{$ENDIF}
{$IFDEF NEXTPAS_FREEBSD}
type
  PFreeBSDDirent = ^TFreeBSDDirent;
  TFreeBSDDirent = packed record
    d_fileno: UInt64;
    d_off: Int64;
    d_reclen: UInt16;
    d_type: Byte;
    d_pad0: Byte;
    d_namlen: UInt16;
    d_pad1: UInt16;
    d_name: array[0..0] of AnsiChar;
  end;
var
  LDent: PFreeBSDDirent;
  LNameLen: Int32;
  LNamePtr: PAnsiChar;
{$ENDIF}
begin
  FillChar(AEntry, SizeOf(AEntry), 0);
{$IF defined(NEXTPAS_LINUX) or defined(NEXTPAS_ANDROID)}
  while True do
  begin
    if AHandle.Pos >= AHandle.Len then
    begin
{$IFDEF NEXTPAS_ANDROID}
      AHandle.Len := Int32(syscall(ANDROID_SYSCALL_GETDENTS64,
        PtrUInt(AHandle.Fd), PtrUInt(@AHandle.Buf[0]), SizeOf(AHandle.Buf),
        0, 0, 0));
{$ELSE}
      AHandle.Len := Int32(getdents64(AHandle.Fd, @AHandle.Buf[0], SizeOf(AHandle.Buf)));
{$ENDIF}
      if AHandle.Len <= 0 then
      begin
        if AHandle.Len = 0 then
          Result := 1
        else
          Result := platform_get_errno;
        Exit;
      end;
      AHandle.Pos := 0;
    end;
    LDent := PDirent64(@AHandle.Buf[AHandle.Pos]);
    Inc(AHandle.Pos, LDent^.d_reclen);
    LNamePtr := @LDent^.d_name[0];
    if (LNamePtr[0] = '.') and (LNamePtr[1] = #0) then
      Continue;
    if (LNamePtr[0] = '.') and (LNamePtr[1] = '.') and (LNamePtr[2] = #0) then
      Continue;
    LNameLen := 0;
    while (LNameLen < 255) and (LNamePtr[LNameLen] <> #0) do
    begin
      AEntry.Name[LNameLen] := LNamePtr[LNameLen];
      Inc(LNameLen);
    end;
    AEntry.Name[LNameLen] := #0;
    AEntry.NameLen := LNameLen;
    AEntry.Ino := LDent^.d_ino;
    AEntry.FileType := ClassifyDirEntryDType(LDent^.d_type);
    Result := 0;
    Exit;
  end;
{$ENDIF}
{$IFDEF NEXTPAS_MACOS}
  LBase := 0;
  while True do
  begin
    if AHandle.Pos >= AHandle.Len then
    begin
      AHandle.Len := Int32(getdirentries(AHandle.Fd, @AHandle.Buf[0], SizeOf(AHandle.Buf), @LBase));
      if AHandle.Len <= 0 then
      begin
        if AHandle.Len = 0 then
          Result := 1
        else
          Result := platform_get_errno;
        Exit;
      end;
      AHandle.Pos := 0;
    end;
    LDent := PDarwinDirent(@AHandle.Buf[AHandle.Pos]);
    Inc(AHandle.Pos, LDent^.d_reclen);
    LNamePtr := @LDent^.d_name[0];
    if (LNamePtr[0] = '.') and (LNamePtr[1] = #0) then
      Continue;
    if (LNamePtr[0] = '.') and (LNamePtr[1] = '.') and (LNamePtr[2] = #0) then
      Continue;
    LNameLen := Int32(LDent^.d_namlen);
    if LNameLen > 255 then
      LNameLen := 255;
    Move(LNamePtr^, AEntry.Name[0], LNameLen);
    AEntry.Name[LNameLen] := #0;
    AEntry.NameLen := LNameLen;
    AEntry.Ino := LDent^.d_ino;
    AEntry.FileType := ClassifyDirEntryDType(LDent^.d_type);
    Result := 0;
    Exit;
  end;
{$ENDIF}
{$IFDEF NEXTPAS_FREEBSD}
  while True do
  begin
    if AHandle.Pos >= AHandle.Len then
    begin
      AHandle.Len := Int32(getdents(AHandle.Fd, @AHandle.Buf[0], SizeOf(AHandle.Buf)));
      if AHandle.Len <= 0 then
      begin
        if AHandle.Len = 0 then
          Result := 1
        else
          Result := platform_get_errno;
        Exit;
      end;
      AHandle.Pos := 0;
    end;
    LDent := PFreeBSDDirent(@AHandle.Buf[AHandle.Pos]);
    Inc(AHandle.Pos, LDent^.d_reclen);
    LNamePtr := @LDent^.d_name[0];
    if (LNamePtr[0] = '.') and (LNamePtr[1] = #0) then
      Continue;
    if (LNamePtr[0] = '.') and (LNamePtr[1] = '.') and (LNamePtr[2] = #0) then
      Continue;
    LNameLen := Int32(LDent^.d_namlen);
    if LNameLen > 255 then
      LNameLen := 255;
    Move(LNamePtr^, AEntry.Name[0], LNameLen);
    AEntry.Name[LNameLen] := #0;
    AEntry.NameLen := LNameLen;
    AEntry.Ino := LDent^.d_fileno;
    AEntry.FileType := ClassifyDirEntryDType(LDent^.d_type);
    Result := 0;
    Exit;
  end;
{$ENDIF}
end;

function platform_dir_close(var AHandle: TPlatformDirHandle): Int32;
begin
  if AHandle.Fd >= 0 then
  begin
    Result := PosixCheck(close(AHandle.Fd));
    AHandle.Fd := -1;
  end
  else
    Result := PLATFORM_ERR_BADF;
end;
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
function platform_file_open(const APath: PAnsiChar; AMode: TPlatformFileOpenMode;
  ACreate: TPlatformFileCreateMode; out AHandle: TPlatformFileHandle): Int32;
begin
  Result := platform_file_open_ex(APath, AMode, ACreate, False, False, PLATFORM_DEFAULT_FILE_MODE, AHandle);
end;

function platform_file_open_ex(const APath: PAnsiChar; AMode: TPlatformFileOpenMode;
  ACreate: TPlatformFileCreateMode; AAppend: Boolean; ASync: Boolean;
  APerm: UInt32; out AHandle: TPlatformFileHandle): Int32;
const
  FILE_APPEND_DATA = $0004;
  FILE_FLAG_WRITE_THROUGH = $80000000;
var
  LAccess, LDisposition, LFlags: DWORD;
  LPath: UnicodeString;
begin
  if not platform_windows_utf8_to_wide_checked(APath, LPath) then
    Exit(Int32(ERROR_INVALID_NAME));
  case AMode of
    fomReadOnly:  LAccess := GENERIC_READ;
    fomWriteOnly: LAccess := GENERIC_WRITE;
    fomReadWrite: LAccess := GENERIC_READ or GENERIC_WRITE;
  end;
  if AAppend then
    LAccess := LAccess or FILE_APPEND_DATA;
  case ACreate of
    fcmOpenExisting:     LDisposition := OPEN_EXISTING;
    fcmCreateAlways:     LDisposition := CREATE_ALWAYS;
    fcmCreateNew:        LDisposition := DWORD(1);
    fcmOpenOrCreate:     LDisposition := OPEN_ALWAYS;
    fcmTruncateExisting: LDisposition := TRUNCATE_EXISTING;
  end;
  LFlags := $80;
  if ASync then
    LFlags := LFlags or FILE_FLAG_WRITE_THROUGH;
  AHandle.Value := CreateFileW(PWideChar(LPath), LAccess, FILE_SHARE_READ, nil,
    LDisposition, LFlags, nil);
  if AHandle.Value = HANDLE(PtrInt(-1)) then
    Result := Int32(GetLastError)
  else
    Result := 0;
end;

function platform_file_close(var AHandle: TPlatformFileHandle): Int32;
begin
  if AHandle.Value = HANDLE(PtrInt(-1)) then
    Exit(-1);
  if CloseHandle(AHandle.Value) then
    Result := 0
  else
    Result := Int32(GetLastError);
  AHandle.Value := HANDLE(PtrInt(-1));
end;

function platform_file_read(const AHandle: TPlatformFileHandle; ABuf: Pointer;
  ALen: PtrUInt; out ABytesRead: PtrUInt): Int32;
var
  LRead: DWORD;
begin
  ABytesRead := 0;
  if ABuf = nil then
    Exit(PLATFORM_ERR_INVALID);
  if ALen = 0 then
    Exit(0);
  LRead := 0;
  if ReadFile(AHandle.Value, ABuf, DWORD(ALen), @LRead, nil) then
  begin
    ABytesRead := LRead;
    Result := 0;
  end
  else
    Result := Int32(GetLastError);
end;

function platform_file_write(const AHandle: TPlatformFileHandle; ABuf: Pointer;
  ALen: PtrUInt; out ABytesWritten: PtrUInt): Int32;
var
  LWritten: DWORD;
begin
  ABytesWritten := 0;
  if ABuf = nil then
    Exit(PLATFORM_ERR_INVALID);
  if ALen = 0 then
    Exit(0);
  LWritten := 0;
  if WriteFile(AHandle.Value, ABuf, DWORD(ALen), @LWritten, nil) then
  begin
    ABytesWritten := LWritten;
    Result := 0;
  end
  else
    Result := Int32(GetLastError);
end;

function platform_file_pread(const AHandle: TPlatformFileHandle; ABuf: Pointer;
  ALen: PtrUInt; AOffset: Int64; out ABytesRead: PtrUInt): Int32;
var
  LOvl: OVERLAPPED;
  LRead: DWORD;
begin
  ABytesRead := 0;
  if ABuf = nil then
    Exit(PLATFORM_ERR_INVALID);
  if ALen = 0 then
    Exit(0);
  FillChar(LOvl, SizeOf(LOvl), 0);
  LOvl.Offset := DWORD(AOffset and $FFFFFFFF);
  LOvl.OffsetHigh := DWORD((AOffset shr 32) and $FFFFFFFF);
  LRead := 0;
  if ReadFile(AHandle.Value, ABuf, DWORD(ALen), @LRead, @LOvl) then
  begin
    ABytesRead := LRead;
    Result := 0;
  end
  else
    Result := Int32(GetLastError);
end;

function platform_file_pwrite(const AHandle: TPlatformFileHandle; ABuf: Pointer;
  ALen: PtrUInt; AOffset: Int64; out ABytesWritten: PtrUInt): Int32;
var
  LOvl: OVERLAPPED;
  LWritten: DWORD;
begin
  ABytesWritten := 0;
  if ABuf = nil then
    Exit(PLATFORM_ERR_INVALID);
  if ALen = 0 then
    Exit(0);
  FillChar(LOvl, SizeOf(LOvl), 0);
  LOvl.Offset := DWORD(AOffset and $FFFFFFFF);
  LOvl.OffsetHigh := DWORD((AOffset shr 32) and $FFFFFFFF);
  LWritten := 0;
  if WriteFile(AHandle.Value, ABuf, DWORD(ALen), @LWritten, @LOvl) then
  begin
    ABytesWritten := LWritten;
    Result := 0;
  end
  else
    Result := Int32(GetLastError);
end;

function platform_file_seek(const AHandle: TPlatformFileHandle; AOffset: Int64;
  AOrigin: TPlatformFileSeekOrigin; out ANewPos: Int64): Int32;
var
  LMethod: DWORD;
begin
  case AOrigin of
    fsoBegin:   LMethod := FILE_BEGIN;
    fsoCurrent: LMethod := FILE_CURRENT;
    fsoEnd:     LMethod := FILE_END;
  end;
  if SetFilePointerEx(AHandle.Value, AOffset, @ANewPos, LMethod) then
    Result := 0
  else
  begin
    ANewPos := -1;
    Result := Int32(GetLastError);
  end;
end;

function platform_file_sync(const AHandle: TPlatformFileHandle): Int32;
begin
  if FlushFileBuffers(AHandle.Value) then
    Result := 0
  else
    Result := Int32(GetLastError);
end;

function platform_file_truncate(const AHandle: TPlatformFileHandle; ASize: Int64): Int32;
var
  LNewPos: Int64;
begin
  if not SetFilePointerEx(AHandle.Value, ASize, @LNewPos, FILE_BEGIN) then
    Exit(-1);
  if SetEndOfFile(AHandle.Value) then
    Result := 0
  else
    Result := Int32(GetLastError);
end;

function platform_file_stat(const APath: PAnsiChar; out AStat: TPlatformFileStat): Int32;
var
  LData: WIN32_FILE_ATTRIBUTE_DATA;
  LSize: UInt64;
  LPath: UnicodeString;
begin
  FillChar(AStat, SizeOf(AStat), 0);
  if not platform_windows_utf8_to_wide_checked(APath, LPath) then
    Exit(Int32(ERROR_INVALID_NAME));
  if not GetFileAttributesExW(PWideChar(LPath), GetFileExInfoStandard, @LData) then
    Exit(Int32(GetLastError));
  LSize := UInt64(LData.nFileSizeHigh) shl 32 or LData.nFileSizeLow;
  AStat.Size := Int64(LSize);
  AStat.Mode := LData.dwFileAttributes;
  if (LData.dwFileAttributes and $400) <> 0 then
    AStat.FileType := ftSymlink
  else if (LData.dwFileAttributes and $10) <> 0 then
    AStat.FileType := ftDirectory
  else
    AStat.FileType := ftRegular;
  Result := 0;
end;

function platform_file_lstat(const APath: PAnsiChar; out AStat: TPlatformFileStat): Int32;
begin
  { Windows GetFileAttributesEx does not follow reparse points by default,
    so stat already reports symlink type. lstat == stat on this backend. }
  Result := platform_file_stat(APath, AStat);
end;

function platform_file_fstat(const AHandle: TPlatformFileHandle; out AStat: TPlatformFileStat): Int32;
var
  LInfo: BY_HANDLE_FILE_INFORMATION;
  LSize: UInt64;
begin
  FillChar(AStat, SizeOf(AStat), 0);
  if not GetFileInformationByHandle(AHandle.Value, @LInfo) then
    Exit(Int32(GetLastError));
  LSize := UInt64(LInfo.nFileSizeHigh) shl 32 or LInfo.nFileSizeLow;
  AStat.Size := Int64(LSize);
  AStat.Mode := LInfo.dwFileAttributes;
  AStat.NLink := LInfo.nNumberOfLinks;
  if (LInfo.dwFileAttributes and $400) <> 0 then
    AStat.FileType := ftSymlink
  else if (LInfo.dwFileAttributes and $10) <> 0 then
    AStat.FileType := ftDirectory
  else
    AStat.FileType := ftRegular;
  Result := 0;
end;

function platform_file_chmod(const APath: PAnsiChar; AMode: UInt32): Int32;
const
  FILE_ATTRIBUTE_READONLY = $1;
  FILE_ATTRIBUTE_NORMAL = $80;
var
  LData: WIN32_FILE_ATTRIBUTE_DATA;
  LAttr: DWORD;
  LPath: UnicodeString;
begin
  if not platform_windows_utf8_to_wide_checked(APath, LPath) then
    Exit(Int32(ERROR_INVALID_NAME));
  if not GetFileAttributesExW(PWideChar(LPath), GetFileExInfoStandard, @LData) then
    Exit(Int32(GetLastError));
  LAttr := LData.dwFileAttributes;
  { Map owner-write bit (0o200 = $80) to the read-only attribute. }
  if (AMode and $80) <> 0 then
    LAttr := LAttr and not DWORD(FILE_ATTRIBUTE_READONLY)
  else
    LAttr := LAttr or FILE_ATTRIBUTE_READONLY;
  if SetFileAttributesW(PWideChar(LPath), LAttr) then
    Result := 0
  else
    Result := Int32(GetLastError);
end;

function platform_file_truncate_path(const APath: PAnsiChar; ASize: Int64): Int32;
var
  LHandle: TPlatformFileHandle;
begin
  Result := platform_file_open(APath, fomReadWrite, fcmOpenExisting, LHandle);
  if Result <> 0 then
    Exit;
  Result := platform_file_truncate(LHandle, ASize);
  platform_file_close(LHandle);
end;

function platform_file_mkdir(const APath: PAnsiChar; AMode: UInt32): Int32;
var
  LPath: UnicodeString;
begin
  if not platform_windows_utf8_to_wide_checked(APath, LPath) then
    Exit(Int32(ERROR_INVALID_NAME));
  if CreateDirectoryW(PWideChar(LPath), nil) then
    Result := 0
  else
    Result := Int32(GetLastError);
end;

function platform_file_rmdir(const APath: PAnsiChar): Int32;
var
  LPath: UnicodeString;
begin
  if not platform_windows_utf8_to_wide_checked(APath, LPath) then
    Exit(Int32(ERROR_INVALID_NAME));
  if RemoveDirectoryW(PWideChar(LPath)) then
    Result := 0
  else
    Result := Int32(GetLastError);
end;

function platform_file_unlink(const APath: PAnsiChar): Int32;
var
  LPath: UnicodeString;
begin
  if not platform_windows_utf8_to_wide_checked(APath, LPath) then
    Exit(Int32(ERROR_INVALID_NAME));
  if DeleteFileW(PWideChar(LPath)) then
    Result := 0
  else
    Result := Int32(GetLastError);
end;

function platform_file_rename(const AOldPath: PAnsiChar; const ANewPath: PAnsiChar): Int32;
var
  LOldPath: UnicodeString;
  LNewPath: UnicodeString;
begin
  if not platform_windows_utf8_to_wide_checked(AOldPath, LOldPath) then
    Exit(Int32(ERROR_INVALID_NAME));
  if not platform_windows_utf8_to_wide_checked(ANewPath, LNewPath) then
    Exit(Int32(ERROR_INVALID_NAME));
  if MoveFileW(PWideChar(LOldPath), PWideChar(LNewPath)) then
    Result := 0
  else
    Result := Int32(GetLastError);
end;

function platform_file_getcwd(ABuf: PAnsiChar; ASize: PtrUInt): PAnsiChar;
var
  LWide: array[0..MAX_PATH - 1] of WideChar;
  LLen: DWORD;
  LUtf8Len: Int32;
begin
  if (ABuf = nil) or (ASize = 0) then
    Exit(nil);
  LLen := GetCurrentDirectoryW(MAX_PATH, @LWide[0]);
  if (LLen = 0) or (LLen >= MAX_PATH) then
    Exit(nil);
  if platform_windows_wide_to_utf8_buffer(@LWide[0], ABuf, Int32(ASize), LUtf8Len) then
    Result := ABuf
  else
    Result := nil;
end;

function platform_file_chdir(const APath: PAnsiChar): Int32;
var
  LPath: UnicodeString;
begin
  if not platform_windows_utf8_to_wide_checked(APath, LPath) then
    Exit(Int32(ERROR_INVALID_NAME));
  if SetCurrentDirectoryW(PWideChar(LPath)) then
    Result := 0
  else
    Result := Int32(GetLastError);
end;

function platform_file_lock(const AHandle: TPlatformFileHandle; AExclusive: Boolean): Int32;
var
  LFlags: DWORD;
  LOvl: OVERLAPPED;
begin
  FillChar(LOvl, SizeOf(LOvl), 0);
  LFlags := 0;
  if AExclusive then
    LFlags := LOCKFILE_EXCLUSIVE_LOCK;
  if LockFileEx(AHandle.Value, LFlags, 0, $FFFFFFFF, $FFFFFFFF, @LOvl) then
    Result := 0
  else
    Result := Int32(GetLastError);
end;

function platform_file_trylock(const AHandle: TPlatformFileHandle; AExclusive: Boolean): Int32;
var
  LFlags: DWORD;
  LOvl: OVERLAPPED;
begin
  FillChar(LOvl, SizeOf(LOvl), 0);
  LFlags := LOCKFILE_FAIL_IMMEDIATELY;
  if AExclusive then
    LFlags := LFlags or LOCKFILE_EXCLUSIVE_LOCK;
  if LockFileEx(AHandle.Value, LFlags, 0, $FFFFFFFF, $FFFFFFFF, @LOvl) then
    Result := 0
  else
    Result := Int32(GetLastError);
end;

function platform_file_unlock(const AHandle: TPlatformFileHandle): Int32;
var
  LOvl: OVERLAPPED;
begin
  FillChar(LOvl, SizeOf(LOvl), 0);
  if UnlockFileEx(AHandle.Value, 0, $FFFFFFFF, $FFFFFFFF, @LOvl) then
    Result := 0
  else
    Result := Int32(GetLastError);
end;

function platform_file_symlink(const ATarget: PAnsiChar; const ALinkPath: PAnsiChar): Int32;
var
  LFlags: DWORD;
  LStat: TPlatformFileStat;
  LTarget: UnicodeString;
  LLinkPath: UnicodeString;
begin
  if not platform_windows_utf8_to_wide_checked(ATarget, LTarget) then
    Exit(Int32(ERROR_INVALID_NAME));
  if not platform_windows_utf8_to_wide_checked(ALinkPath, LLinkPath) then
    Exit(Int32(ERROR_INVALID_NAME));
  LFlags := 0;
  if platform_file_stat(ATarget, LStat) = 0 then
    if LStat.FileType = ftDirectory then
      LFlags := 1;
  if not CreateSymbolicLinkW(PWideChar(LLinkPath), PWideChar(LTarget), LFlags) then
    Result := Int32(GetLastError)
  else
    Result := 0;
end;

function platform_file_readlink(const APath: PAnsiChar; ABuf: PAnsiChar; ABufSize: Int32; out ALen: Int32): Int32;
var
  LHandle: HANDLE;
  LBytesReturned: DWORD;
  LPath: UnicodeString;
  LWideBuf: array[0..MAX_PATH - 1] of WideChar;
  LUtf8: AnsiString;
  LStart: Int32;
begin
  ALen := 0;
  if (ABuf = nil) or (ABufSize <= 0) then
    Exit(PLATFORM_ERR_INVALID);
  if not platform_windows_utf8_to_wide_checked(APath, LPath) then
    Exit(Int32(ERROR_INVALID_NAME));
  LHandle := CreateFileW(PWideChar(LPath), 0,
    FILE_SHARE_READ or FILE_SHARE_WRITE or FILE_SHARE_DELETE,
    nil, OPEN_EXISTING, $02200000, nil);
  if LHandle = HANDLE(PtrInt(-1)) then
    Exit(Int32(GetLastError));
  LBytesReturned := GetFinalPathNameByHandleW(LHandle, @LWideBuf[0], MAX_PATH, 0);
  CloseHandle(LHandle);
  if (LBytesReturned = 0) or (LBytesReturned >= MAX_PATH) then
    Exit(Int32(GetLastError));
  LWideBuf[LBytesReturned] := #0;
  if not platform_windows_wide_to_utf8_checked(@LWideBuf[0], LUtf8) then
    Exit(Int32(ERROR_INVALID_NAME));
  LStart := 0;
  if (Length(LUtf8) >= 4) and (LUtf8[1] = '\') and (LUtf8[2] = '\') and
     (LUtf8[3] = '?') and (LUtf8[4] = '\') then
    LStart := 4;
  if LStart > 0 then
    Delete(LUtf8, 1, LStart);
  ALen := platform_windows_copy_utf8_to_buffer(LUtf8, ABuf, ABufSize);
  Result := 0;
end;

function platform_dir_open(const APath: PAnsiChar; out AHandle: TPlatformDirHandle): Int32;
var
  LPath: UnicodeString;
  LPattern: UnicodeString;
  LLen: Int32;
begin
  FillChar(AHandle, SizeOf(AHandle), 0);
  AHandle.FindHandle := HANDLE(PtrInt(-1));
  AHandle.First := True;
  AHandle.Finished := False;

  if not platform_windows_utf8_to_wide_checked(APath, LPath) then
    Exit(Int32(ERROR_INVALID_NAME));
  LPattern := LPath;
  LLen := Length(LPattern);
  if (LLen > 0) and (LPattern[LLen] <> '\') and (LPattern[LLen] <> '/') then
  begin
    LPattern := LPattern + '\';
    Inc(LLen);
  end;
  LPattern := LPattern + '*';

  AHandle.FindHandle := FindFirstFileW(PWideChar(LPattern), @AHandle.FindData);
  if AHandle.FindHandle = HANDLE(PtrInt(-1)) then
  begin
    AHandle.Finished := True;
    Result := Int32(GetLastError);
    Exit;
  end;
  Result := 0;
end;

function platform_dir_read(var AHandle: TPlatformDirHandle; out AEntry: TPlatformDirEntry): Int32;
var
  LNamePtr: PWideChar;
  LNameUtf8: AnsiString;
begin
  FillChar(AEntry, SizeOf(AEntry), 0);
  if AHandle.Finished then
    Exit(1);

  while True do
  begin
    if not AHandle.First then
    begin
      if not FindNextFileW(AHandle.FindHandle, @AHandle.FindData) then
      begin
        AHandle.Finished := True;
        Exit(1);
      end;
    end;
    AHandle.First := False;

    LNamePtr := @AHandle.FindData.cFileName[0];
    if (LNamePtr[0] = '.') and (LNamePtr[1] = #0) then
      Continue;
    if (LNamePtr[0] = '.') and (LNamePtr[1] = '.') and (LNamePtr[2] = #0) then
      Continue;

    if not platform_windows_wide_to_utf8_checked(LNamePtr, LNameUtf8) then
      Exit(Int32(ERROR_INVALID_NAME));
    AEntry.NameLen := platform_windows_copy_utf8_to_buffer(LNameUtf8,
      @AEntry.Name[0], SizeOf(AEntry.Name));
    AEntry.Ino := 0;

    if (AHandle.FindData.dwFileAttributes and $400) <> 0 then
      AEntry.FileType := ftSymlink
    else if (AHandle.FindData.dwFileAttributes and $10) <> 0 then
      AEntry.FileType := ftDirectory
    else
      AEntry.FileType := ftRegular;

    Result := 0;
    Exit;
  end;
end;

function platform_dir_close(var AHandle: TPlatformDirHandle): Int32;
begin
  if AHandle.FindHandle <> HANDLE(PtrInt(-1)) then
  begin
    if FindClose(AHandle.FindHandle) then
      Result := 0
    else
      Result := Int32(GetLastError);
    AHandle.FindHandle := HANDLE(PtrInt(-1));
  end
  else
    Result := Int32(ERROR_INVALID_HANDLE);
end;
{$ENDIF}

{$IF not defined(NEXTPAS_UNIX) and not defined(NEXTPAS_WINDOWS)}
function platform_file_open(const APath: PAnsiChar; AMode: TPlatformFileOpenMode; ACreate: TPlatformFileCreateMode; out AHandle: TPlatformFileHandle): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_file_open_ex(const APath: PAnsiChar; AMode: TPlatformFileOpenMode; ACreate: TPlatformFileCreateMode; AAppend: Boolean; ASync: Boolean; APerm: UInt32; out AHandle: TPlatformFileHandle): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_file_close(var AHandle: TPlatformFileHandle): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_file_read(const AHandle: TPlatformFileHandle; ABuf: Pointer; ALen: PtrUInt; out ABytesRead: PtrUInt): Int32; begin ABytesRead := 0; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_file_write(const AHandle: TPlatformFileHandle; ABuf: Pointer; ALen: PtrUInt; out ABytesWritten: PtrUInt): Int32; begin ABytesWritten := 0; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_file_pread(const AHandle: TPlatformFileHandle; ABuf: Pointer; ALen: PtrUInt; AOffset: Int64; out ABytesRead: PtrUInt): Int32; begin ABytesRead := 0; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_file_pwrite(const AHandle: TPlatformFileHandle; ABuf: Pointer; ALen: PtrUInt; AOffset: Int64; out ABytesWritten: PtrUInt): Int32; begin ABytesWritten := 0; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_file_seek(const AHandle: TPlatformFileHandle; AOffset: Int64; AOrigin: TPlatformFileSeekOrigin; out ANewPos: Int64): Int32; begin ANewPos := -1; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_file_sync(const AHandle: TPlatformFileHandle): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_file_truncate(const AHandle: TPlatformFileHandle; ASize: Int64): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_file_stat(const APath: PAnsiChar; out AStat: TPlatformFileStat): Int32; begin FillChar(AStat, SizeOf(AStat), 0); Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_file_lstat(const APath: PAnsiChar; out AStat: TPlatformFileStat): Int32; begin FillChar(AStat, SizeOf(AStat), 0); Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_file_fstat(const AHandle: TPlatformFileHandle; out AStat: TPlatformFileStat): Int32; begin FillChar(AStat, SizeOf(AStat), 0); Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_file_chmod(const APath: PAnsiChar; AMode: UInt32): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_file_truncate_path(const APath: PAnsiChar; ASize: Int64): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_file_mkdir(const APath: PAnsiChar; AMode: UInt32): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_file_rmdir(const APath: PAnsiChar): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_file_unlink(const APath: PAnsiChar): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_file_rename(const AOldPath: PAnsiChar; const ANewPath: PAnsiChar): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_file_getcwd(ABuf: PAnsiChar; ASize: PtrUInt): PAnsiChar; begin Result := nil; end;
function platform_file_chdir(const APath: PAnsiChar): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_file_lock(const AHandle: TPlatformFileHandle; AExclusive: Boolean): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_file_trylock(const AHandle: TPlatformFileHandle; AExclusive: Boolean): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_file_unlock(const AHandle: TPlatformFileHandle): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_file_symlink(const ATarget: PAnsiChar; const ALinkPath: PAnsiChar): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_file_readlink(const APath: PAnsiChar; ABuf: PAnsiChar; ABufSize: Int32; out ALen: Int32): Int32; begin ALen := 0; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_dir_open(const APath: PAnsiChar; out AHandle: TPlatformDirHandle): Int32; begin FillChar(AHandle, SizeOf(AHandle), 0); Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_dir_read(var AHandle: TPlatformDirHandle; out AEntry: TPlatformDirEntry): Int32; begin FillChar(AEntry, SizeOf(AEntry), 0); Result := 1; end;
function platform_dir_close(var AHandle: TPlatformDirHandle): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
{$ENDIF}

end.
