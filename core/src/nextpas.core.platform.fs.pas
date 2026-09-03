{**
 * nextpas.core.platform.fs - 高层文件系统操作
 *
 * 职责：文件系统级操作（exists/is_file/mkdir_p/copy_file/write_atomic/read_file/walk）
 * 层次：路径级操作，依赖 files.pas 的底层 fd 操作（L0）
 *  单源纪律：Move/FillChar 单源仅 bytes.ops.BytesCopy/BytesZero (inline 单 Move/Fill 零拷贝，L0 platform.fs 亦经 bytes.ops 单源复用无分散；门禁 test_bytes_ops_source_contracts)
 *
 * 与 files.pas 的关系：
 *   - files.pas = 底层 fd 操作（open/close/read/write/stat/dir）
 *   - fs.pas = 高层文件系统操作（exists/is_file/mkdir_p/copy_file/walk）
 *   - fs.pas 依赖 files.pas
 *}
unit nextpas.core.platform.fs;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.files.base,
  nextpas.core.platform.posix.errno,
  nextpas.core.platform.error;

type
  {** @desc 目录遍历操作枚举 *}
  TPlatformWalkAction = (
    pwaContinue,
    pwaSkipSubtree,
    pwaStop
  );

  {** @desc 目录遍历条目 *}
  TPlatformWalkEntry = record
    Path: PAnsiChar;
    PathLen: Int32;
    Name: PAnsiChar;
    NameLen: Int32;
    FileType: TPlatformFileType;
    Depth: Int32;
    ErrorCode: Int32;
    {** @desc 检查是否为普通文件
        @return True 如果是普通文件 *}
    function IsRegular: Boolean; inline;
    {** @desc 检查是否为目录
        @return True 如果是目录 *}
    function IsDirectory: Boolean; inline;
    {** @desc 检查是否为符号链接
        @return True 如果是符号链接 *}
    function IsSymlink: Boolean; inline;
    {** @desc 检查是否有错误
        @return True 如果有错误 *}
    function HasError: Boolean; inline;
    {** @desc 检查是否为当前目录（.）
        @return True 如果是当前目录 *}
    function IsCurrentDir: Boolean; inline;
    {** @desc 检查是否为父目录（..）
        @return True 如果是父目录 *}
    function IsParentDir: Boolean; inline;
    {** @desc 检查是否为隐藏文件（以 . 开头）
        @return True 如果是隐藏文件 *}
    function IsHidden: Boolean; inline;
  end;

  {** @desc 目录遍历回调函数类型 *}
  TPlatformWalkCallback = function(const AEntry: TPlatformWalkEntry;
    AUserData: Pointer): TPlatformWalkAction;

const
  {** @desc 遍历完成 *}
  PLATFORM_WALK_COMPLETED = 0;
  {** @desc 遍历被停止 *}
  PLATFORM_WALK_STOPPED   = 1;
  {** @desc 遍历参数错误 *}
  PLATFORM_WALK_BADARGS   = -1;
  {** @desc 最大遍历深度 *}
  PLATFORM_WALK_MAX_DEPTH = 256;
  {** @desc 短读错误 — alias PLATFORM_ERR_IO (单一错误族，不再使用平行 -6) *}
  PLATFORM_FS_SHORT_READ_ERROR = PLATFORM_ERR_IO;
  {** @desc 路径过长 — alias PLATFORM_ERR_PATH_TOO_LONG (-7 域钳制) *}
  PLATFORM_FS_PATH_TOO_LONG = PLATFORM_ERR_PATH_TOO_LONG;
  {** @desc 动态读取初始块大小（64KB） *}
  PLATFORM_FS_READ_CHUNK_SIZE = 65536;

{** @desc 检查路径是否存在
    @param APath 路径
    @return True 存在 *}
function platform_fs_exists(const APath: PAnsiChar): Boolean;

{** @desc 检查路径是否为普通文件
    @param APath 路径
    @return True 是普通文件 *}
function platform_fs_is_file(const APath: PAnsiChar): Boolean;

{** @desc 检查路径是否为目录
    @param APath 路径
    @return True 是目录 *}
function platform_fs_is_dir(const APath: PAnsiChar): Boolean;

{** @desc 检查路径是否可执行
    @param APath 路径
    @return True 可执行 *}
function platform_fs_is_executable(const APath: PAnsiChar): Boolean;

{** @desc 检查路径是否为符号链接
    @param APath 路径
    @return True 是符号链接 *}
function platform_fs_is_symlink(const APath: PAnsiChar): Boolean;

{** @desc 读取符号链接目标路径
    @param APath 符号链接路径
    @param ABuf 输出缓冲区
    @param ABufSize 缓冲区大小
    @return >= 0 目标路径长度，PLATFORM_ERR_* 错误码 *}
function platform_fs_readlink(const APath: PAnsiChar; ABuf: PAnsiChar; ABufSize: Int32): Int32;

{** @desc 修改文件权限
    @param APath 文件路径
    @param AMode 权限位（如 &755）
    @return 0 成功，否则返回错误码 *}
function platform_fs_chmod(const APath: PAnsiChar; AMode: UInt32): Int32;

{** @desc 截断文件到指定大小
    @param APath 文件路径
    @param ASize 目标大小（字节）
    @return 0 成功，否则返回错误码 *}
function platform_fs_truncate(const APath: PAnsiChar; ASize: Int64): Int32;

{** @desc 强制将文件数据刷入磁盘
    @param AHandle 文件句柄
    @return 0 成功，否则返回错误码 *}
function platform_fs_sync(const AHandle: TPlatformFileHandle): Int32;

{** @desc 获取文件大小
    @param APath 文件路径
    @param ASize 输出文件大小
    @return 0 成功，否则返回错误码 *}
function platform_fs_file_size(const APath: PAnsiChar; out ASize: Int64): Int32;

{** @desc 获取临时目录路径
    @param ABuf 输出缓冲区
    @param ABufSize 缓冲区大小
    @return 写入字节数 *}
function platform_fs_temp_dir(ABuf: PAnsiChar; ABufSize: Int32): Int32;

{** @desc 创建临时文件（已废弃，请使用 platform_fs_mktemp_handle）
    @param APrefix 文件名前缀
    @param ASuffix 文件名后缀
    @param APathBuf 输出路径缓冲区
    @param APathBufLen 路径缓冲区大小
    @param AFd 输出文件描述符
    @return 0 成功 *}
function platform_fs_mktemp(const APrefix: PAnsiChar; const ASuffix: PAnsiChar;
  APathBuf: PAnsiChar; APathBufLen: Int32; out AFd: Int32): Int32; deprecated 'Use platform_fs_mktemp_handle instead';

{** @desc 创建临时文件（返回文件句柄）
    @param APrefix 文件名前缀
    @param ASuffix 文件名后缀
    @param APathBuf 输出路径缓冲区
    @param APathBufLen 路径缓冲区大小
    @param AHandle 输出文件句柄
    @return 0 成功 *}
function platform_fs_mktemp_handle(const APrefix: PAnsiChar; const ASuffix: PAnsiChar;
  APathBuf: PAnsiChar; APathBufLen: Int32; out AHandle: TPlatformFileHandle): Int32;

{** @desc 递归创建目录（类似 mkdir -p）
    @param APath 目录路径
    @param AMode 目录权限
    @return 0 成功，否则返回错误码 *}
function platform_fs_mkdir_p(const APath: PAnsiChar; AMode: UInt32): Int32;

{** @desc 复制文件
    @param ASrc 源文件路径
    @param ADst 目标文件路径
    @return 0 成功，否则返回错误码 *}
function platform_fs_copy_file(const ASrc: PAnsiChar; const ADst: PAnsiChar): Int32;

{** @desc CoW 克隆文件（reflink/clonefile），不支持时回退普通复制
    @param ASrc 源文件路径
    @param ADst 目标文件路径
    @return 0 成功，否则返回错误码
    @note Linux: ioctl FICLONE (btrfs/xfs)；macOS: clonefile (APFS)
          不支持时回退 platform_fs_copy_file（透明降级） *}
function platform_fs_clone_file(const ASrc: PAnsiChar; const ADst: PAnsiChar): Int32;

{** @desc 移动文件（rename 或 copy+delete）
    @param ASrc 源文件路径
    @param ADst 目标文件路径
    @return 0 成功，否则返回错误码 *}
function platform_fs_move_file(const ASrc: PAnsiChar; const ADst: PAnsiChar): Int32;

{** @desc 删除文件
    @param APath 文件路径
    @return 0 成功，否则返回错误码 *}
function platform_fs_remove_file(const APath: PAnsiChar): Int32;

{** @desc 删除空目录
    @param APath 目录路径
    @return 0 成功，否则返回错误码 *}
function platform_fs_remove_dir(const APath: PAnsiChar): Int32;

{** @desc 重命名文件或目录
    @param AOldPath 原路径
    @param ANewPath 新路径
    @return 0 成功，否则返回错误码 *}
function platform_fs_rename(const AOldPath: PAnsiChar; const ANewPath: PAnsiChar): Int32;

{** @desc 原子写入文件（写入临时文件后 rename）
    @param APath 目标文件路径
    @param AData 数据指针
    @param ALen 数据长度
    @param APerm 临时文件创建权限（POSIX mode；创建时即生效，
          避免「0666&umask 落盘 → rename → 事后 chmod」窗口） *}
function platform_fs_write_atomic(const APath: PAnsiChar;
  AData: Pointer; ALen: PtrUInt; APerm: UInt32): Int32;

{** @desc 读取整个文件到内存（自动分配缓冲区）
    @param APath 文件路径
    @param AData 输出数据指针（需调用 platform_fs_free_buf 释放）
    @param ALen 输出数据长度
    @return 0 成功，否则返回错误码 *}
function platform_fs_read_file(const APath: PAnsiChar;
  out AData: Pointer; out ALen: PtrUInt): Int32;

{** @desc 读取文件到预分配缓冲区
    @param APath 文件路径
    @param ABuf 预分配缓冲区
    @param ABufCapacity 缓冲区容量
    @param ALen 输出实际读取长度
    @return 0 成功，否则返回错误码 *}
function platform_fs_read_file_into(const APath: PAnsiChar;
  ABuf: Pointer; ABufCapacity: PtrUInt; out ALen: PtrUInt): Int32;

{** @desc 释放 platform_fs_read_file 分配的缓冲区
    @param AData 数据指针 *}
procedure platform_fs_free_buf(AData: Pointer);

{** @desc 递归遍历目录树
    @param ARoot 根目录路径
    @param ACallback 遍历回调函数
    @param AUserData 用户数据指针
    @param AFollowSymlinks 是否跟随符号链接
    @return 0 完成，1 被停止，负值错误 *}
function platform_fs_walk(const ARoot: PAnsiChar;
  ACallback: TPlatformWalkCallback; AUserData: Pointer;
  AFollowSymlinks: Boolean): Int32;

implementation

uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.platform.files,
  nextpas.core.platform.env,
  nextpas.core.platform.random
{$IFDEF NEXTPAS_LINUX}
  , nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.linux.ffi
{$ENDIF}
{$IFDEF NEXTPAS_MACOS}
  , nextpas.core.platform.darwin.ffi
{$ENDIF}
  ;

function TPlatformWalkEntry.IsRegular: Boolean;
begin
  Result := FileType = ftRegular;
end;

function TPlatformWalkEntry.IsDirectory: Boolean;
begin
  Result := FileType = ftDirectory;
end;

function TPlatformWalkEntry.IsSymlink: Boolean;
begin
  Result := FileType = ftSymlink;
end;

function TPlatformWalkEntry.HasError: Boolean;
begin
  Result := ErrorCode <> 0;
end;

function TPlatformWalkEntry.IsCurrentDir: Boolean;
begin
  Result := (NameLen = 1) and (Name^ = '.');
end;

function TPlatformWalkEntry.IsParentDir: Boolean;
begin
  Result := (NameLen = 2) and (Name^ = '.') and ((Name + 1)^ = '.');
end;

function TPlatformWalkEntry.IsHidden: Boolean;
begin
  Result := (NameLen > 0) and (Name^ = '.');
end;

const
  { short write — alias PLATFORM_ERR_IO (single error family; was parallel -5) }
  PLATFORM_FS_SHORT_WRITE_ERROR = PLATFORM_ERR_IO;
  { POSIX permission bits — universal across all Unix systems }
  PLATFORM_S_IXUSR = $0040;  { 0100 octal: owner execute }
  PLATFORM_S_IXGRP = $0008;  { 0010 octal: group execute }
  PLATFORM_S_IXOTH = $0001;  { 0001 octal: other execute }

function platform_fs_write_all(const AHandle: TPlatformFileHandle;
  AData: Pointer; ALen: PtrUInt): Int32;
var
  LTotal, LWritten: PtrUInt;
begin
  LTotal := 0;
  while LTotal < ALen do
  begin
    Result := platform_file_write(AHandle,
      Pointer(PtrUInt(AData) + LTotal), ALen - LTotal, LWritten);
    if Result <> 0 then
      Exit;
    if LWritten = 0 then
      Exit(PLATFORM_FS_SHORT_WRITE_ERROR);
    Inc(LTotal, LWritten);
  end;
  Result := 0;
end;

function platform_fs_read_all(const AHandle: TPlatformFileHandle;
  AData: Pointer; ALen: PtrUInt; out ABytesRead: PtrUInt): Int32;
var
  LChunk: PtrUInt;
begin
  ABytesRead := 0;
  while ABytesRead < ALen do
  begin
    Result := platform_file_read(AHandle,
      Pointer(PtrUInt(AData) + ABytesRead), ALen - ABytesRead, LChunk);
    if Result <> 0 then
      Exit;
    if LChunk = 0 then
      Exit(PLATFORM_FS_SHORT_READ_ERROR);
    Inc(ABytesRead, LChunk);
  end;
  Result := 0;
end;

type
  PPtrUIntLocal = ^PtrUInt;

const
  PLATFORM_FS_BUF_HDR = SizeOf(PtrUInt);

{ payload = raw + header; header stores allocation size for sized FreeMem }
function PlatformFsRawToPayload(ARaw: Pointer): Pointer; inline;
begin
  Result := Pointer(PtrUInt(ARaw) + PLATFORM_FS_BUF_HDR);
end;

function PlatformFsPayloadToRaw(AData: Pointer): Pointer; inline;
begin
  Result := Pointer(PtrUInt(AData) - PLATFORM_FS_BUF_HDR);
end;

procedure PlatformFsFreePayload(AData: Pointer); inline;
var
  LRaw: Pointer;
  LSize: PtrUInt;
begin
  if AData = nil then Exit;
  LRaw := PlatformFsPayloadToRaw(AData);
  LSize := PPtrUIntLocal(LRaw)^;
  FreeMem(LRaw, LSize + PLATFORM_FS_BUF_HDR);
end;

{**
 * platform_fs_read_until_eof - Read file until EOF with dynamic buffer
 *
 * Eliminates TOCTOU race: no stat() before read(), buffer grows as needed.
 * Caller must FreeMem the returned buffer on success via platform_fs_free_buf.
 * L0: uses System GetMem/FreeMem (must not uses nextpas.core.mem; mem depends on platform).
 *
 * @param AHandle  Open file handle (read-only)
 * @param AData    Receives allocated buffer (nil on error)
 * @param ALen     Receives actual bytes read (0 on error)
 * @return 0 on success, error code on failure
 *}
function platform_fs_read_until_eof(const AHandle: TPlatformFileHandle;
  out AData: Pointer; out ALen: PtrUInt): Int32;
var
  LRaw, LNewRaw: Pointer;
  LBuf: Pointer;
  LBufSize, LTotal, LChunk: PtrUInt;
  LNewBuf: Pointer;
  LNewSize: PtrUInt;
begin
  AData := nil;
  ALen := 0;

  LBufSize := PLATFORM_FS_READ_CHUNK_SIZE;
  GetMem(LRaw, LBufSize + PLATFORM_FS_BUF_HDR);
  if LRaw = nil then
    Exit(PLATFORM_ERR_INVALID);
  PPtrUIntLocal(LRaw)^ := LBufSize;
  LBuf := PlatformFsRawToPayload(LRaw);

  LTotal := 0;
  repeat
    if LBufSize - LTotal < 4096 then
    begin
      LNewSize := LBufSize * 2;
      if LNewSize < LBufSize then
      begin
        FreeMem(LRaw, LBufSize + PLATFORM_FS_BUF_HDR);
        Exit(PLATFORM_ERR_INVALID);
      end;
      GetMem(LNewRaw, LNewSize + PLATFORM_FS_BUF_HDR);
      if LNewRaw = nil then
      begin
        FreeMem(LRaw, LBufSize + PLATFORM_FS_BUF_HDR);
        Exit(PLATFORM_ERR_INVALID);
      end;
      PPtrUIntLocal(LNewRaw)^ := LNewSize;
      LNewBuf := PlatformFsRawToPayload(LNewRaw);
      if LTotal > 0 then
        BytesCopy(LNewBuf, LBuf, LTotal); // perf: inline single Move via bytes.ops.BytesCopy single source (zero-copy, L0 platform.fs reuse bytes.ops, sized FreeMem not lost)
      FreeMem(LRaw, LBufSize + PLATFORM_FS_BUF_HDR);
      LRaw := LNewRaw;
      LBuf := LNewBuf;
      LBufSize := LNewSize;
    end;

    Result := platform_file_read(AHandle,
      Pointer(PtrUInt(LBuf) + LTotal), LBufSize - LTotal - 1, LChunk);
    if Result <> 0 then
    begin
      FreeMem(LRaw, LBufSize + PLATFORM_FS_BUF_HDR);
      Exit;
    end;
    if LChunk = 0 then
      Break;
    Inc(LTotal, LChunk);
  until False;

  PAnsiChar(LBuf)[LTotal] := #0;
  AData := LBuf;
  ALen := LTotal;
  Result := 0;
end;

function platform_fs_exists(const APath: PAnsiChar): Boolean;
var
  LStat: TPlatformFileStat;
begin
  Result := platform_file_stat(APath, LStat) = 0;
end;

function platform_fs_is_file(const APath: PAnsiChar): Boolean;
var
  LStat: TPlatformFileStat;
begin
  if platform_file_stat(APath, LStat) <> 0 then
    Exit(False);
  Result := LStat.FileType = ftRegular;
end;

function platform_fs_is_dir(const APath: PAnsiChar): Boolean;
var
  LStat: TPlatformFileStat;
begin
  if platform_file_stat(APath, LStat) <> 0 then
    Exit(False);
  Result := LStat.FileType = ftDirectory;
end;


function platform_fs_is_executable(const APath: PAnsiChar): Boolean;
{$IFDEF NEXTPAS_UNIX}
var
  LStat: TPlatformFileStat;
begin
  if platform_file_stat(APath, LStat) <> 0 then
    Exit(False);
  if LStat.FileType <> ftRegular then
    Exit(False);
  Result := (LStat.Mode and (PLATFORM_S_IXUSR or PLATFORM_S_IXGRP or PLATFORM_S_IXOTH)) <> 0;
end;
{$ELSE}
var
  LStat: TPlatformFileStat;
begin
  { Windows: treat existing non-directory files as executable candidates.
    PATHEXT / ACL filtering is owned by process.pathresolve LookPath. }
  if (APath = nil) or (APath^ = #0) then
    Exit(False);
  if platform_file_stat(APath, LStat) <> 0 then
    Exit(False);
  Result := LStat.FileType <> ftDirectory;
end;
{$ENDIF}
function platform_fs_file_size(const APath: PAnsiChar; out ASize: Int64): Int32;
var
  LStat: TPlatformFileStat;
begin
  ASize := 0;
  Result := platform_file_stat(APath, LStat);
  if Result = 0 then
    ASize := LStat.Size;
end;

function platform_fs_temp_dir(ABuf: PAnsiChar; ABufSize: Int32): Int32;
var
  LLen: Int32;
  LResult: Int32;
begin
  if (ABuf = nil) or (ABufSize <= 0) then
    Exit(PLATFORM_ERR_INVALID);
{$IFDEF NEXTPAS_WINDOWS}
  LResult := platform_env_get('TEMP', ABuf, ABufSize, LLen);
  if LResult <> 0 then
    LResult := platform_env_get('TMP', ABuf, ABufSize, LLen);
  if LResult <> 0 then
  begin
    if ABufSize >= 4 then
    begin
      ABuf[0] := 'C'; ABuf[1] := ':'; ABuf[2] := '\';
      ABuf[3] := #0;
      Exit(3);
    end;
    Exit(PLATFORM_ERR_INVALID);
  end;
  Result := LLen;
{$ELSE}
  LResult := platform_env_get('TMPDIR', ABuf, ABufSize, LLen);
  if LResult = 0 then
    Result := LLen
  else
  begin
    if ABufSize >= 5 then
    begin
      ABuf[0] := '/'; ABuf[1] := 't'; ABuf[2] := 'm'; ABuf[3] := 'p';
      ABuf[4] := #0;
      Result := 4;
    end
    else
      Result := PLATFORM_ERR_INVALID;
  end;
{$ENDIF}
end;

function platform_fs_mkdir_p(const APath: PAnsiChar; AMode: UInt32): Int32;
var
  LBuf: array[0..4095] of AnsiChar;
  LLen, I: Int32;
  LR: Int32;
begin
  if (APath = nil) or (APath[0] = #0) then
    Exit(PLATFORM_ERR_INVALID);
  LLen := 0;
  while (LLen < 4095) and (APath[LLen] <> #0) do
  begin
    LBuf[LLen] := APath[LLen];
    Inc(LLen);
  end;
  LBuf[LLen] := #0;
  if LLen >= 4095 then Exit(PLATFORM_ERR_PATH_TOO_LONG);

  I := 1;
  while I <= LLen do
  begin
  {$IFDEF NEXTPAS_WINDOWS}
    if (LBuf[I] = '\') or (LBuf[I] = '/') or (I = LLen) then
  {$ELSE}
    if (LBuf[I] = '/') or (I = LLen) then
  {$ENDIF}
    begin
      if I = LLen then
      begin
        if platform_file_lstat(@LBuf[0], LSt) = 0 then
        begin
          if LSt.FileType = ftSymlink then
          begin
            if (platform_file_stat(@LBuf[0], LSt) = 0) and (LSt.FileType = ftDirectory) then
              Exit(0)
            else
              Exit(PLATFORM_ERR_ENOTDIR);
          end;
          if LSt.FileType = ftDirectory then
            Exit(0);
          Exit(PLATFORM_ERR_ENOTDIR);
        end;
        LR := platform_file_mkdir(@LBuf[0], AMode);
        if (LR <> 0) and platform_fs_is_dir(@LBuf[0]) then
          LR := 0
        else if (LR = 0) then
        begin
          if platform_file_lstat(@LBuf[0], LSt) = 0 then
            if LSt.FileType = ftSymlink then
              if not ((platform_file_stat(@LBuf[0], LSt) = 0) and (LSt.FileType = ftDirectory)) then
                Exit(PLATFORM_ERR_ENOTDIR);
        end;
        LR := platform_file_mkdir(@LBuf[0], AMode);
        if (LR <> 0) and platform_fs_is_dir(@LBuf[0]) then
          LR := 0;
        if LR <> 0 then Exit(LR);
      end
      else
      begin
        LBuf[I] := #0;
        LR := platform_file_mkdir(@LBuf[0], AMode);
        if (LR <> 0) and (not platform_fs_is_dir(@LBuf[0])) then
        begin
          if LSt.FileType = ftSymlink then
          begin
            if (platform_file_stat(@LBuf[0], LSt) = 0) and (LSt.FileType = ftDirectory) then
            begin
              LBuf[I] := '/';
            end
            else
            begin
              LBuf[I] := '/';
              Exit(PLATFORM_ERR_ENOTDIR);
            end;
          end else
          if LSt.FileType <> ftDirectory then
          begin
            LBuf[I] := '/';
            Exit(PLATFORM_ERR_ENOTDIR);
          end;
        end
        else
        begin
          LR := platform_file_mkdir(@LBuf[0], AMode);
          if (LR <> 0) and (not platform_fs_is_dir(@LBuf[0])) then
          begin
            if LR = PLATFORM_ERR_EXIST then
              LR := PLATFORM_ERR_ENOTDIR;
            LBuf[I] := '/';
            Exit(LR);
          end;
          if platform_file_lstat(@LBuf[0], LSt) = 0 then
            if LSt.FileType = ftSymlink then
              if not ((platform_file_stat(@LBuf[0], LSt) = 0) and (LSt.FileType = ftDirectory)) then
              begin
                LBuf[I] := '/';
                Exit(PLATFORM_ERR_ENOTDIR);
              end;
          if LR = PLATFORM_ERR_EXIST then
            LR := PLATFORM_ERR_ENOTDIR;
          LBuf[I] := '/';
          Exit(LR);
        end;
      {$IFDEF NEXTPAS_WINDOWS}
        LBuf[I] := '\';
      {$ELSE}
        LBuf[I] := '/';
      {$ENDIF}
      end;
    end;
    Inc(I);
  end;
  Result := 0;
end;

function platform_fs_copy_file(const ASrc: PAnsiChar; const ADst: PAnsiChar): Int32;
var
  LSrcH, LDstH: TPlatformFileHandle;
  LBuf: array[0..8191] of Byte;
  LRead: PtrUInt;
  LR, LCloseR: Int32;
{$IFDEF NEXTPAS_LINUX}
  LStat: TPlatformFileStat;
  LTotal: Int64;
  LSent: ssize_t;
  LHasSourceSize: Boolean;
{$ENDIF}
begin
  LR := platform_file_open(ASrc, fomReadOnly, fcmOpenExisting, LSrcH);
  if LR <> 0 then Exit(LR);
  LR := platform_file_open(ADst, fomWriteOnly, fcmCreateAlways, LDstH);
  if LR <> 0 then
  begin
    platform_file_close(LSrcH);
    Exit(LR);
  end;

{$IFDEF NEXTPAS_LINUX}
  { Linux: try sendfile for zero-copy transfer }
  LR := -1;
  LTotal := 0;
  LHasSourceSize := platform_file_fstat(LSrcH, LStat) = 0;
  if LHasSourceSize then
  begin
    while LTotal < LStat.Size do
    begin
      LSent := nextpas.core.platform.linux.ffi.sendfile(
        LDstH.Value, LSrcH.Value, nil, size_t(LStat.Size - LTotal));
      if LSent < 0 then
      begin
        LR := platform_get_errno;
        Break;
      end;
      if LSent = 0 then
        Break;
      Inc(LTotal, LSent);
    end;
    if LTotal = LStat.Size then
      LR := 0;
  end;

  { Fallback to read/write if sendfile failed }
  if LR <> 0 then
  begin
    { Continue from where sendfile left off using pread/pwrite
      to avoid data corruption from restarting at file beginning. }
    LRead := 0;
    repeat
      LR := platform_file_pread(LSrcH, @LBuf[0], SizeOf(LBuf), LTotal, LRead);
      if LR <> 0 then Break;
      if LRead = 0 then Break;
      LR := platform_fs_write_all(LDstH, @LBuf[0], LRead);
      if LR <> 0 then Break;
      Inc(LTotal, Int64(LRead));
      if LHasSourceSize then
        if LTotal >= LStat.Size then
          Break;
    until False;
    if LHasSourceSize then
      if LTotal >= LStat.Size then
        LR := 0;
  end;
{$ENDIF}

  { Non-Linux: standard read/write loop }
{$IFNDEF NEXTPAS_LINUX}
  repeat
    LR := platform_file_read(LSrcH, @LBuf[0], SizeOf(LBuf), LRead);
    if (LR <> 0) or (LRead = 0) then Break;
    LR := platform_fs_write_all(LDstH, @LBuf[0], LRead);
  until LR <> 0;
{$ENDIF}


  LCloseR := platform_file_close(LDstH);
  if (LR = 0) and (LCloseR <> 0) then
    LR := LCloseR;
  LCloseR := platform_file_close(LSrcH);
  if (LR = 0) and (LCloseR <> 0) then
    LR := LCloseR;
  Result := LR;
end;

function platform_fs_clone_file(const ASrc: PAnsiChar; const ADst: PAnsiChar): Int32;
{$IFDEF NEXTPAS_LINUX}
var
  LSrcH, LDstH: TPlatformFileHandle;
  LR, LCloseR: Int32;
begin
  { Linux: ioctl(FICLONE) — dst 成为 src 的 reflink（共享数据块）
    失败（非 btrfs/xfs）时回退 platform_fs_copy_file }
  LR := platform_file_open(ASrc, fomReadOnly, fcmOpenExisting, LSrcH);
  if LR <> 0 then
    Exit(platform_fs_copy_file(ASrc, ADst));
  LR := platform_file_open(ADst, fomWriteOnly, fcmCreateAlways, LDstH);
  if LR <> 0 then
  begin
    platform_file_close(LSrcH);
    Exit(platform_fs_copy_file(ASrc, ADst));
  end;
  LR := nextpas.core.platform.linux.ffi.ioctl(
    LDstH.Value, FICLONE, @LSrcH.Value);
  if LR <> 0 then
  begin
    { FICLONE 不支持 → 回退普通复制 }
    platform_file_close(LDstH);
    platform_file_close(LSrcH);
    Exit(platform_fs_copy_file(ASrc, ADst));
  end;
  LCloseR := platform_file_close(LDstH);
  if (LR = 0) and (LCloseR <> 0) then
    LR := LCloseR;
  LCloseR := platform_file_close(LSrcH);
  if (LR = 0) and (LCloseR <> 0) then
    LR := LCloseR;
  Result := LR;
end;
{$ENDIF}
{$IFDEF NEXTPAS_MACOS}
begin
  { macOS: clonefile(src, dst, 0) — APFS reflink
    失败（非 APFS）时回退 platform_fs_copy_file }
  if nextpas.core.platform.darwin.ffi.clonefile(ASrc, ADst, 0) = 0 then
    Result := 0
  else
    Result := platform_fs_copy_file(ASrc, ADst);
end;
{$ENDIF}
{$IFNDEF NEXTPAS_LINUX}
{$IFNDEF NEXTPAS_MACOS}
begin
  { 其他平台：无 CoW 原语，回退普通复制 }
  Result := platform_fs_copy_file(ASrc, ADst);
end;
{$ENDIF}
{$ENDIF}

{ 目录部分提取：含 '/' → 最后一个 '/' 及其前；否则 "."（当前目录）。
  rename 后 fsync 目录使目录项持久化（对齐 Go persistLocked dir sync）。
  失败忽略——rename 已原子完成，未持久化目录项只意味着崩溃后回退
  旧文件/无文件，绝不撕裂。 }
procedure SyncDirOf(const APath: PAnsiChar);
var
  LDirBuf: array[0..1023] of AnsiChar;
  LPathLen, LSlash, LI: Int32;
begin
  if APath = nil then
    Exit;
  LPathLen := 0;
  LSlash := -1;
  while (LPathLen < 1010) and (APath[LPathLen] <> #0) do
  begin
    if APath[LPathLen] = '/' then
      LSlash := LPathLen;
    Inc(LPathLen);
  end;
  if LSlash < 0 then
  begin
    LDirBuf[0] := '.';
    LDirBuf[1] := #0;
  end
  else
  begin
    for LI := 0 to LSlash do
      LDirBuf[LI] := APath[LI];
    LDirBuf[LSlash + 1] := #0;
  end;
  platform_file_sync_dir(@LDirBuf[0]);
end;

function platform_fs_write_atomic(const APath: PAnsiChar;
  AData: Pointer; ALen: PtrUInt; APerm: UInt32): Int32;
const
  HEX: array[0..15] of AnsiChar = '0123456789abcdef';
  MAX_ATOMIC_TEMP_ATTEMPTS = 16;
var
  LTmpPath: array[0..1023] of AnsiChar;
  LBaseLen, LPathLen, I, LAttempt: Int32;
  LH: TPlatformFileHandle;
  LR: Int32;
  LRand: array[0..5] of Byte;
begin
  if (APath = nil) or (APath[0] = #0) then
    Exit(PLATFORM_ERR_INVALID);
  LBaseLen := 0;
  { Invariant: 1024 buffer - 1(dot) - 12(hex) - 1(NUL) = 1010 max base path }
  while (LBaseLen < 1010) and (APath[LBaseLen] <> #0) do
  begin
    LTmpPath[LBaseLen] := APath[LBaseLen];
    Inc(LBaseLen);
  end;
  LR := -1;
  for LAttempt := 0 to MAX_ATOMIC_TEMP_ATTEMPTS - 1 do
  begin
    LPathLen := LBaseLen;
    LTmpPath[LPathLen] := '.'; Inc(LPathLen);
    if platform_random_bytes(@LRand[0], 6) <> 0 then
      Exit(platform_get_errno);
    for I := 0 to 5 do
    begin
      LTmpPath[LPathLen] := HEX[LRand[I] shr 4]; Inc(LPathLen);
      LTmpPath[LPathLen] := HEX[LRand[I] and $0F]; Inc(LPathLen);
    end;
    LTmpPath[LPathLen] := #0;

    { 临时文件创建即带最终权限（对齐 Go os.WriteFile 0600：umask 只会
      剥位不会加位，绝不存在组/其他可读窗口——含写满数据后的 fsync
      期间与 rename 后的瞬间）。}
    LR := platform_file_open_ex(@LTmpPath[0], fomWriteOnly, fcmCreateNew,
      False, False, APerm, LH);
    if LR = 0 then
      Break;
  end;
  if LR <> 0 then Exit(LR);

  if ALen > 0 then
  begin
    LR := platform_fs_write_all(LH, AData, ALen);
    if LR <> 0 then
    begin
      platform_file_close(LH);
      platform_file_unlink(@LTmpPath[0]);
      Exit(LR);
    end;
  end;

  LR := platform_file_sync(LH);
  if LR <> 0 then
  begin
    platform_file_close(LH);
    platform_file_unlink(@LTmpPath[0]);
    Exit(LR);
  end;

  LR := platform_file_close(LH);
  if LR <> 0 then
  begin
    platform_file_unlink(@LTmpPath[0]);
    Exit(LR);
  end;

  LR := platform_file_rename(@LTmpPath[0], APath);
  if LR <> 0 then
    platform_file_unlink(@LTmpPath[0])
  else
  begin
    { rename 后 fsync 目录：断电后 rename 的目录项持久化（对齐 Go
      persistLocked 的 dir sync；失败忽略——rename 已原子完成，
      目录项未持久化只意味着崩溃后回退旧文件/无文件，绝不撕裂）。 }
    SyncDirOf(APath);
  end;
  Result := LR;
end;

function platform_fs_mktemp_impl(APathBuf: PAnsiChar; APathBufLen: Int32;
  const APrefix, ASuffix: PAnsiChar; out AHandle: TPlatformFileHandle): Int32;
const
  HEX_CHARS: array[0..15] of AnsiChar = '0123456789abcdef';
  MAX_ATTEMPTS = 16;
var
  LTmpDir: array[0..511] of AnsiChar;
  LTmpLen, LPrefixLen, LSuffixLen, LPos, I, LAttempt: Int32;
  LRandBytes: array[0..7] of Byte;
begin
  AHandle := PLATFORM_FILE_INVALID_HANDLE;
  if (APathBuf = nil) or (APathBufLen <= 0) then
    Exit(PLATFORM_ERR_INVALID);

  LTmpLen := platform_fs_temp_dir(@LTmpDir[0], SizeOf(LTmpDir));
  if LTmpLen < 0 then
    Exit(LTmpLen);

  LPrefixLen := 0;
  if APrefix <> nil then
    while APrefix[LPrefixLen] <> #0 do Inc(LPrefixLen);

  LSuffixLen := 0;
  if ASuffix <> nil then
    while ASuffix[LSuffixLen] <> #0 do Inc(LSuffixLen);

  if LTmpLen + 1 + LPrefixLen + 16 + LSuffixLen + 1 > APathBufLen then
    Exit(PLATFORM_ERR_INVALID);

  for LAttempt := 0 to MAX_ATTEMPTS - 1 do
  begin
    LPos := 0;
    BytesCopy(APathBuf, @LTmpDir[0], LTmpLen); // perf: inline single Move via bytes.ops.BytesCopy single source (zero-copy)
    LPos := LTmpLen;
  {$IFDEF NEXTPAS_WINDOWS}
    if (LPos > 0) and (APathBuf[LPos-1] <> '\') then
    begin APathBuf[LPos] := '\'; Inc(LPos); end;
  {$ELSE}
    if (LPos > 0) and (APathBuf[LPos-1] <> '/') then
    begin APathBuf[LPos] := '/'; Inc(LPos); end;
  {$ENDIF}

    if LPrefixLen > 0 then
    begin
      BytesCopy(@APathBuf[LPos], APrefix, LPrefixLen); // perf: inline single Move via bytes.ops.BytesCopy single source (zero-copy)
      Inc(LPos, LPrefixLen);
    end;

    if platform_random_bytes(@LRandBytes[0], 8) <> 0 then
      Exit(PLATFORM_ERR_INVALID);
    for I := 0 to 7 do
    begin
      APathBuf[LPos] := HEX_CHARS[(LRandBytes[I] shr 4) and $F];
      Inc(LPos);
      APathBuf[LPos] := HEX_CHARS[LRandBytes[I] and $F];
      Inc(LPos);
    end;

    if LSuffixLen > 0 then
    begin
      BytesCopy(@APathBuf[LPos], ASuffix, LSuffixLen); // perf: inline single Move via bytes.ops.BytesCopy single source (zero-copy)
      Inc(LPos, LSuffixLen);
    end;
    APathBuf[LPos] := #0;

    Result := platform_file_open(APathBuf, fomReadWrite, fcmCreateNew, AHandle);
    if Result = 0 then
      Exit(0);
  end;
  Result := PLATFORM_ERR_INVALID;
end;

function platform_fs_mktemp(const APrefix: PAnsiChar; const ASuffix: PAnsiChar;
  APathBuf: PAnsiChar; APathBufLen: Int32; out AFd: Int32): Int32; deprecated 'Use platform_fs_mktemp_handle instead';
var
  LHandle: TPlatformFileHandle;
begin
  AFd := -1;
  Result := platform_fs_mktemp_impl(APathBuf, APathBufLen, APrefix, ASuffix, LHandle);
  if Result = 0 then
  begin
  {$IFDEF NEXTPAS_WINDOWS}
    AFd := Int32(PtrUInt(LHandle.Value));
  {$ELSE}
    AFd := LHandle.Value;
  {$ENDIF}
  end;
end;

function platform_fs_mktemp_handle(const APrefix: PAnsiChar; const ASuffix: PAnsiChar;
  APathBuf: PAnsiChar; APathBufLen: Int32; out AHandle: TPlatformFileHandle): Int32;
begin
  Result := platform_fs_mktemp_impl(APathBuf, APathBufLen, APrefix, ASuffix, AHandle);
end;

function platform_fs_read_file(const APath: PAnsiChar;
  out AData: Pointer; out ALen: PtrUInt): Int32;
var
  LH: TPlatformFileHandle;
  LR, LCloseR: Int32;
begin
  AData := nil;
  ALen := 0;
  LR := platform_file_open(APath, fomReadOnly, fcmOpenExisting, LH);
  if LR <> 0 then
    Exit(LR);
  { Read until EOF — no TOCTOU race (no stat before read) }
  LR := platform_fs_read_until_eof(LH, AData, ALen);
  LCloseR := platform_file_close(LH);
  if (LR = 0) and (LCloseR <> 0) then
    LR := LCloseR;
  if LR <> 0 then
  begin
    if AData <> nil then
      PlatformFsFreePayload(AData);
    AData := nil;
    ALen := 0;
  end;
  Result := LR;
end;

function platform_fs_read_file_into(const APath: PAnsiChar;
  ABuf: Pointer; ABufCapacity: PtrUInt; out ALen: PtrUInt): Int32;
var
  LH: TPlatformFileHandle;
  LTotal, LChunk: PtrUInt;
  LR, LCloseR: Int32;
begin
  ALen := 0;
  if ABuf = nil then
    Exit(PLATFORM_ERR_INVALID);
  if ABufCapacity = 0 then
    Exit(PLATFORM_FS_SHORT_READ_ERROR);

  LR := platform_file_open(APath, fomReadOnly, fcmOpenExisting, LH);
  if LR <> 0 then
    Exit(LR);

  { Read until EOF or buffer full — no TOCTOU race }
  LTotal := 0;
  repeat
    if LTotal >= ABufCapacity then
    begin
      { Buffer full but file has more data }
      LR := PLATFORM_FS_SHORT_READ_ERROR;
      Break;
    end;
    LR := platform_file_read(LH,
      Pointer(PtrUInt(ABuf) + LTotal), ABufCapacity - LTotal, LChunk);
    if LR <> 0 then
      Break;
    if LChunk = 0 then
      Break; { EOF }
    Inc(LTotal, LChunk);
  until False;

  LCloseR := platform_file_close(LH);
  if (LR = 0) and (LCloseR <> 0) then
    LR := LCloseR;
  ALen := LTotal;
  Result := LR;
end;

procedure platform_fs_free_buf(AData: Pointer);
begin
  PlatformFsFreePayload(AData);
end;

function WalkResolveType(APathBuf: PAnsiChar; ADirType: TPlatformFileType;
  AFollowSymlinks: Boolean; out AErrCode: Int32): TPlatformFileType;
var
  LStat: TPlatformFileStat;
  LResult: Int32;
begin
  AErrCode := 0;
  if ADirType <> ftUnknown then
  begin
    if AFollowSymlinks and (ADirType = ftSymlink) then
    begin
      LResult := platform_file_stat(APathBuf, LStat);
      if LResult = 0 then
        Exit(LStat.FileType);
      AErrCode := LResult;
      Exit(ftSymlink);
    end;
    Exit(ADirType);
  end;
  if AFollowSymlinks then
  begin
    if platform_file_stat(APathBuf, LStat) = 0 then
      Exit(LStat.FileType);
  end;
  AErrCode := platform_file_lstat(APathBuf, LStat);
  if AErrCode <> 0 then
    Exit(ftUnknown);
  Result := LStat.FileType;
end;

function WalkRecurse(APathBuf: PAnsiChar; APathLen: Int32;
  ACallback: TPlatformWalkCallback; AUserData: Pointer;
  AFollowSymlinks: Boolean; ADepth: Int32): Int32;
var
  LHandle: TPlatformDirHandle;
  LDirEntry: TPlatformDirEntry;
  LEntry: TPlatformWalkEntry;
  LAction: TPlatformWalkAction;
  LChildLen, LNameLen: Int32;
  LR, LErrCode: Int32;
  LChildType: TPlatformFileType;
begin
  if ADepth >= PLATFORM_WALK_MAX_DEPTH then
    Exit(PLATFORM_WALK_COMPLETED);

  LR := platform_dir_open(APathBuf, LHandle);
  if LR <> 0 then
  begin
    FillChar(LEntry, SizeOf(LEntry), 0);
    LEntry.Path := APathBuf;
    LEntry.PathLen := APathLen;
    LEntry.Name := APathBuf;
    LEntry.NameLen := APathLen;
    LEntry.FileType := ftDirectory;
    LEntry.Depth := ADepth;
    LEntry.ErrorCode := LR;
    LAction := ACallback(LEntry, AUserData);
    if LAction = pwaStop then
      Exit(PLATFORM_WALK_STOPPED);
    Exit(PLATFORM_WALK_COMPLETED);
  end;

  while True do
  begin
    LR := platform_dir_read(LHandle, LDirEntry);
    if LR <> 0 then
      Break;

    LNameLen := LDirEntry.NameLen;
    LChildLen := APathLen + 1 + LNameLen;
    if LChildLen >= 4095 then
    begin
      { Path too long — report error via callback, don't silently skip }
      FillChar(LEntry, SizeOf(LEntry), 0);
      LEntry.Path := APathBuf;
      LEntry.PathLen := APathLen;
      LEntry.Name := @LDirEntry.Name[0];
      LEntry.NameLen := LNameLen;
      LEntry.FileType := LDirEntry.FileType;
      LEntry.Depth := ADepth + 1;
      LEntry.ErrorCode := PLATFORM_FS_PATH_TOO_LONG;
      LAction := ACallback(LEntry, AUserData);
      if LAction = pwaStop then
      begin
        platform_dir_close(LHandle);
        Exit(PLATFORM_WALK_STOPPED);
      end;
      Continue;
    end;

  {$IFDEF NEXTPAS_WINDOWS}
    APathBuf[APathLen] := '\';
  {$ELSE}
    APathBuf[APathLen] := '/';
  {$ENDIF}
    BytesCopy(@APathBuf[APathLen + 1], @LDirEntry.Name[0], LNameLen); // perf: inline single Move via bytes.ops.BytesCopy single source (zero-copy)
    APathBuf[LChildLen] := #0;

    LChildType := WalkResolveType(APathBuf, LDirEntry.FileType,
      AFollowSymlinks, LErrCode);

    FillChar(LEntry, SizeOf(LEntry), 0);
    LEntry.Path := APathBuf;
    LEntry.PathLen := LChildLen;
    LEntry.Name := @APathBuf[APathLen + 1];
    LEntry.NameLen := LNameLen;
    LEntry.FileType := LChildType;
    LEntry.Depth := ADepth + 1;
    LEntry.ErrorCode := LErrCode;

    LAction := ACallback(LEntry, AUserData);

    if LAction = pwaStop then
    begin
      APathBuf[APathLen] := #0;
      platform_dir_close(LHandle);
      Exit(PLATFORM_WALK_STOPPED);
    end;

    if (LAction <> pwaSkipSubtree) and (LChildType = ftDirectory) and
       (LErrCode = 0) then
    begin
      LR := WalkRecurse(APathBuf, LChildLen, ACallback, AUserData,
        AFollowSymlinks, ADepth + 1);
      if LR = PLATFORM_WALK_STOPPED then
      begin
        APathBuf[APathLen] := #0;
        platform_dir_close(LHandle);
        Exit(PLATFORM_WALK_STOPPED);
      end;
    end;

    APathBuf[APathLen] := #0;
  end;

  platform_dir_close(LHandle);
  Result := PLATFORM_WALK_COMPLETED;
end;

function platform_fs_walk(const ARoot: PAnsiChar;
  ACallback: TPlatformWalkCallback; AUserData: Pointer;
  AFollowSymlinks: Boolean): Int32;
var
  LPathBuf: array[0..4095] of AnsiChar;
  LRootLen: Int32;
  LEntry: TPlatformWalkEntry;
  LAction: TPlatformWalkAction;
  LStat: TPlatformFileStat;
  LR: Int32;
  LFileType: TPlatformFileType;
begin
  FillChar(LPathBuf, SizeOf(LPathBuf), 0);
  if (ARoot = nil) or (ARoot[0] = #0) or (ACallback = nil) then
    Exit(PLATFORM_WALK_BADARGS);

  LRootLen := 0;
  while (LRootLen < 4095) and (ARoot[LRootLen] <> #0) do
  begin
    LPathBuf[LRootLen] := ARoot[LRootLen];
    Inc(LRootLen);
  end;
  while (LRootLen > 1) and ((LPathBuf[LRootLen - 1] = '/') or (LPathBuf[LRootLen - 1] = '\')) do
    Dec(LRootLen);
  LPathBuf[LRootLen] := #0;

  if AFollowSymlinks then
    LR := platform_file_stat(@LPathBuf[0], LStat)
  else
    LR := platform_file_lstat(@LPathBuf[0], LStat);

  if LR <> 0 then
    LFileType := ftUnknown
  else
    LFileType := LStat.FileType;

  FillChar(LEntry, SizeOf(LEntry), 0);
  LEntry.Path := @LPathBuf[0];
  LEntry.PathLen := LRootLen;
  LEntry.Name := @LPathBuf[0];
  LEntry.NameLen := LRootLen;
  LEntry.FileType := LFileType;
  LEntry.Depth := 0;
  if LR <> 0 then
    LEntry.ErrorCode := LR;

  LAction := ACallback(LEntry, AUserData);
  if LAction = pwaStop then
    Exit(PLATFORM_WALK_STOPPED);
  if (LAction = pwaSkipSubtree) or (LFileType <> ftDirectory) then
    Exit(PLATFORM_WALK_COMPLETED);

  Result := WalkRecurse(@LPathBuf[0], LRootLen, ACallback, AUserData,
    AFollowSymlinks, 0);
end;

{ Move file - rename or copy+delete }
function platform_fs_move_file(const ASrc: PAnsiChar; const ADst: PAnsiChar): Int32;
begin
  Result := platform_file_rename(ASrc, ADst);
  if Result = 0 then Exit;
  Result := platform_fs_copy_file(ASrc, ADst);
  if Result = 0 then
    platform_fs_remove_file(ASrc);
end;

{ Remove file }
function platform_fs_remove_file(const APath: PAnsiChar): Int32;
begin
  Result := platform_file_unlink(APath);
end;

{ Remove empty directory }
function platform_fs_remove_dir(const APath: PAnsiChar): Int32;
begin
  Result := platform_file_rmdir(APath);
end;

{ Rename file or directory }
function platform_fs_rename(const AOldPath: PAnsiChar; const ANewPath: PAnsiChar): Int32;
begin
  Result := platform_file_rename(AOldPath, ANewPath);
end;

{ Check if path is a symbolic link }
function platform_fs_is_symlink(const APath: PAnsiChar): Boolean;
var
  LStat: TPlatformFileStat;
begin
  if (APath = nil) or (APath[0] = #0) then
    Exit(False);
  Result := (platform_file_lstat(APath, LStat) = 0) and (LStat.FileType = ftSymlink);
end;

{ Read symbolic link target }
function platform_fs_readlink(const APath: PAnsiChar; ABuf: PAnsiChar; ABufSize: Int32): Int32;
var
  LLen: Int32;
begin
  if (ABuf = nil) or (ABufSize <= 0) then
    Exit(PLATFORM_ERR_INVALID);
  Result := platform_file_readlink(APath, ABuf, ABufSize, LLen);
  if Result = 0 then
    Result := LLen;
end;

{ Change file permissions }
function platform_fs_chmod(const APath: PAnsiChar; AMode: UInt32): Int32;
begin
  Result := platform_file_chmod(APath, AMode);
end;

{ Truncate file to specified size }
function platform_fs_truncate(const APath: PAnsiChar; ASize: Int64): Int32;
begin
  Result := platform_file_truncate_path(APath, ASize);
end;

{ Flush file data to disk }
function platform_fs_sync(const AHandle: TPlatformFileHandle): Int32;
begin
  Result := platform_file_sync(AHandle);
end;

end.
