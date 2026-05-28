unit nextpas.core.platform.files;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.files.base;

function platform_file_open(const APath: PAnsiChar; AMode: TPlatformFileOpenMode;
  ACreate: TPlatformFileCreateMode; out AHandle: TPlatformFileHandle): Int32;
function platform_file_close(var AHandle: TPlatformFileHandle): Int32;
function platform_file_read(const AHandle: TPlatformFileHandle; ABuf: Pointer;
  ACount: PtrUInt; out ABytesRead: PtrUInt): Int32;
function platform_file_write(const AHandle: TPlatformFileHandle; ABuf: Pointer;
  ACount: PtrUInt; out ABytesWritten: PtrUInt): Int32;
function platform_file_seek(const AHandle: TPlatformFileHandle; AOffset: Int64;
  AOrigin: TPlatformFileSeekOrigin; out ANewPos: Int64): Int32;
function platform_file_sync(const AHandle: TPlatformFileHandle): Int32;
function platform_file_truncate(const AHandle: TPlatformFileHandle; ASize: Int64): Int32;
function platform_file_stat(const APath: PAnsiChar; out AStat: TPlatformFileStat): Int32;
function platform_file_mkdir(const APath: PAnsiChar; AMode: UInt32): Int32;
function platform_file_rmdir(const APath: PAnsiChar): Int32;
function platform_file_unlink(const APath: PAnsiChar): Int32;
function platform_file_rename(const AOldPath: PAnsiChar; const ANewPath: PAnsiChar): Int32;
function platform_file_getcwd(ABuf: PAnsiChar; ASize: PtrUInt): PAnsiChar;
function platform_file_chdir(const APath: PAnsiChar): Int32;
function platform_dir_open(const APath: PAnsiChar; out AHandle: TPlatformDirHandle): Int32;
function platform_dir_read(var AHandle: TPlatformDirHandle; out AEntry: TPlatformDirEntry): Int32;
function platform_dir_close(var AHandle: TPlatformDirHandle): Int32;

implementation

{$IFDEF NEXTPAS_UNIX}
uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi
{$IFDEF NEXTPAS_LINUX}
  , nextpas.core.platform.linux.base
  , nextpas.core.platform.linux.ffi
{$ENDIF}
  ;
{$ENDIF}
{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.windows.base,
  nextpas.core.platform.windows.ffi;
{$ENDIF}

{$IFDEF NEXTPAS_UNIX}
function platform_file_open(const APath: PAnsiChar; AMode: TPlatformFileOpenMode;
  ACreate: TPlatformFileCreateMode; out AHandle: TPlatformFileHandle): Int32;
var
  LFlags: Int32;
begin
  case AMode of
    fomReadOnly:  LFlags := 0;
    fomWriteOnly: LFlags := 1;
    fomReadWrite: LFlags := 2;
  end;
  case ACreate of
    fcmOpenExisting:    ;
    fcmCreateAlways:    LFlags := LFlags or $40 or $200;
    fcmCreateNew:       LFlags := LFlags or $40 or $80;
    fcmOpenOrCreate:    LFlags := LFlags or $40;
    fcmTruncateExisting: LFlags := LFlags or $200;
  end;
  AHandle.Value := open(APath, LFlags, 438);
  if AHandle.Value < 0 then
    Result := -1
  else
    Result := 0;
end;

function platform_file_close(var AHandle: TPlatformFileHandle): Int32;
begin
  if AHandle.Value < 0 then
    Exit(-1);
  if close(AHandle.Value) = 0 then
    Result := 0
  else
    Result := -1;
  AHandle.Value := -1;
end;

function platform_file_read(const AHandle: TPlatformFileHandle; ABuf: Pointer;
  ACount: PtrUInt; out ABytesRead: PtrUInt): Int32;
var
  LResult: PtrInt;
begin
  LResult := read(AHandle.Value, ABuf, ACount);
  if LResult < 0 then
  begin
    ABytesRead := 0;
    Result := -1;
  end
  else
  begin
    ABytesRead := PtrUInt(LResult);
    Result := 0;
  end;
end;

function platform_file_write(const AHandle: TPlatformFileHandle; ABuf: Pointer;
  ACount: PtrUInt; out ABytesWritten: PtrUInt): Int32;
var
  LResult: PtrInt;
begin
  LResult := write(AHandle.Value, ABuf, ACount);
  if LResult < 0 then
  begin
    ABytesWritten := 0;
    Result := -1;
  end
  else
  begin
    ABytesWritten := PtrUInt(LResult);
    Result := 0;
  end;
end;

function platform_file_seek(const AHandle: TPlatformFileHandle; AOffset: Int64;
  AOrigin: TPlatformFileSeekOrigin; out ANewPos: Int64): Int32;
var
  LWhence: Int32;
  LResult: Int64;
begin
  case AOrigin of
    fsoBegin:   LWhence := 0;
    fsoCurrent: LWhence := 1;
    fsoEnd:     LWhence := 2;
  end;
  LResult := lseek(AHandle.Value, AOffset, LWhence);
  if LResult < 0 then
  begin
    ANewPos := -1;
    Result := -1;
  end
  else
  begin
    ANewPos := LResult;
    Result := 0;
  end;
end;

function platform_file_sync(const AHandle: TPlatformFileHandle): Int32;
begin
  if fsync(AHandle.Value) = 0 then
    Result := 0
  else
    Result := -1;
end;

function platform_file_truncate(const AHandle: TPlatformFileHandle; ASize: Int64): Int32;
begin
  if ftruncate(AHandle.Value, ASize) = 0 then
    Result := 0
  else
    Result := -1;
end;

function platform_file_stat(const APath: PAnsiChar; out AStat: TPlatformFileStat): Int32;
var
{$IFDEF NEXTPAS_LINUX}
  LStat: TPlatformLinuxStat;
{$ENDIF}
begin
  FillChar(AStat, SizeOf(AStat), 0);
{$IFDEF NEXTPAS_LINUX}
  if __xstat(_STAT_VER_LINUX, APath, LStat) <> 0 then
    Exit(-1);
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
  case LStat.st_mode and S_IFMT of
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
  Result := 0;
{$ELSE}
  Result := -1;
{$ENDIF}
end;

function platform_file_mkdir(const APath: PAnsiChar; AMode: UInt32): Int32;
begin
  if mkdir(APath, AMode) = 0 then
    Result := 0
  else
    Result := -1;
end;

function platform_file_rmdir(const APath: PAnsiChar): Int32;
begin
  if rmdir(APath) = 0 then
    Result := 0
  else
    Result := -1;
end;

function platform_file_unlink(const APath: PAnsiChar): Int32;
begin
  if unlink(APath) = 0 then
    Result := 0
  else
    Result := -1;
end;

function platform_file_rename(const AOldPath: PAnsiChar; const ANewPath: PAnsiChar): Int32;
begin
  if rename(AOldPath, ANewPath) = 0 then
    Result := 0
  else
    Result := -1;
end;

function platform_file_getcwd(ABuf: PAnsiChar; ASize: PtrUInt): PAnsiChar;
begin
  Result := getcwd(ABuf, ASize);
end;

function platform_file_chdir(const APath: PAnsiChar): Int32;
begin
  if chdir(APath) = 0 then
    Result := 0
  else
    Result := -1;
end;

function platform_dir_open(const APath: PAnsiChar; out AHandle: TPlatformDirHandle): Int32;
begin
  FillChar(AHandle, SizeOf(AHandle), 0);
{$IFDEF NEXTPAS_LINUX}
  AHandle.Fd := open(APath, O_RDONLY or O_DIRECTORY, 0);
{$ELSE}
  AHandle.Fd := open(APath, 0 {O_RDONLY}, 0);
{$ENDIF}
  if AHandle.Fd < 0 then
    Result := -1
  else
    Result := 0;
end;

function platform_dir_read(var AHandle: TPlatformDirHandle; out AEntry: TPlatformDirEntry): Int32;
{$IFDEF NEXTPAS_LINUX}
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
begin
  FillChar(AEntry, SizeOf(AEntry), 0);
{$IFDEF NEXTPAS_LINUX}
  while True do
  begin
    if AHandle.Pos >= AHandle.Len then
    begin
      AHandle.Len := Int32(getdents64(AHandle.Fd, @AHandle.Buf[0], SizeOf(AHandle.Buf)));
      if AHandle.Len <= 0 then
      begin
        if AHandle.Len = 0 then
          Result := 1
        else
          Result := -1;
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
    case LDent^.d_type of
      8:  AEntry.FileType := ftRegular;
      4:  AEntry.FileType := ftDirectory;
      10: AEntry.FileType := ftSymlink;
      2:  AEntry.FileType := ftCharDevice;
      6:  AEntry.FileType := ftBlockDevice;
      1:  AEntry.FileType := ftFifo;
      12: AEntry.FileType := ftSocket;
    else
      AEntry.FileType := ftUnknown;
    end;
    Result := 0;
    Exit;
  end;
{$ELSE}
  Result := 1;
{$ENDIF}
end;

function platform_dir_close(var AHandle: TPlatformDirHandle): Int32;
begin
  if AHandle.Fd >= 0 then
  begin
    close(AHandle.Fd);
    AHandle.Fd := -1;
    Result := 0;
  end
  else
    Result := -1;
end;
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
function platform_file_open(const APath: PAnsiChar; AMode: TPlatformFileOpenMode;
  ACreate: TPlatformFileCreateMode; out AHandle: TPlatformFileHandle): Int32;
var
  LAccess, LDisposition: DWORD;
begin
  case AMode of
    fomReadOnly:  LAccess := GENERIC_READ;
    fomWriteOnly: LAccess := GENERIC_WRITE;
    fomReadWrite: LAccess := GENERIC_READ or GENERIC_WRITE;
  end;
  case ACreate of
    fcmOpenExisting:     LDisposition := OPEN_EXISTING;
    fcmCreateAlways:     LDisposition := CREATE_ALWAYS;
    fcmCreateNew:        LDisposition := DWORD(1);
    fcmOpenOrCreate:     LDisposition := OPEN_ALWAYS;
    fcmTruncateExisting: LDisposition := TRUNCATE_EXISTING;
  end;
  AHandle.Value := CreateFileA(APath, LAccess, FILE_SHARE_READ, nil, LDisposition, $80, nil);
  if AHandle.Value = HANDLE(PtrInt(-1)) then
    Result := -1
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
    Result := -1;
  AHandle.Value := HANDLE(PtrInt(-1));
end;

function platform_file_read(const AHandle: TPlatformFileHandle; ABuf: Pointer;
  ACount: PtrUInt; out ABytesRead: PtrUInt): Int32;
var
  LRead: DWORD;
begin
  LRead := 0;
  if ReadFile(AHandle.Value, ABuf, DWORD(ACount), @LRead, nil) then
  begin
    ABytesRead := LRead;
    Result := 0;
  end
  else
  begin
    ABytesRead := 0;
    Result := -1;
  end;
end;

function platform_file_write(const AHandle: TPlatformFileHandle; ABuf: Pointer;
  ACount: PtrUInt; out ABytesWritten: PtrUInt): Int32;
var
  LWritten: DWORD;
begin
  LWritten := 0;
  if WriteFile(AHandle.Value, ABuf, DWORD(ACount), @LWritten, nil) then
  begin
    ABytesWritten := LWritten;
    Result := 0;
  end
  else
  begin
    ABytesWritten := 0;
    Result := -1;
  end;
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
    Result := -1;
  end;
end;

function platform_file_sync(const AHandle: TPlatformFileHandle): Int32;
begin
  if FlushFileBuffers(AHandle.Value) then
    Result := 0
  else
    Result := -1;
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
    Result := -1;
end;

function platform_file_stat(const APath: PAnsiChar; out AStat: TPlatformFileStat): Int32;
var
  LData: WIN32_FILE_ATTRIBUTE_DATA;
  LSize: UInt64;
begin
  FillChar(AStat, SizeOf(AStat), 0);
  if not GetFileAttributesExA(APath, GetFileExInfoStandard, @LData) then
    Exit(-1);
  LSize := UInt64(LData.nFileSizeHigh) shl 32 or LData.nFileSizeLow;
  AStat.Size := Int64(LSize);
  AStat.Mode := LData.dwFileAttributes;
  if (LData.dwFileAttributes and $10) <> 0 then
    AStat.FileType := ftDirectory
  else
    AStat.FileType := ftRegular;
  Result := 0;
end;

function platform_file_mkdir(const APath: PAnsiChar; AMode: UInt32): Int32;
begin
  if CreateDirectoryA(APath, nil) then
    Result := 0
  else
    Result := -1;
end;

function platform_file_rmdir(const APath: PAnsiChar): Int32;
begin
  if RemoveDirectoryA(APath) then
    Result := 0
  else
    Result := -1;
end;

function platform_file_unlink(const APath: PAnsiChar): Int32;
begin
  if DeleteFileA(APath) then
    Result := 0
  else
    Result := -1;
end;

function platform_file_rename(const AOldPath: PAnsiChar; const ANewPath: PAnsiChar): Int32;
begin
  if MoveFileA(AOldPath, ANewPath) then
    Result := 0
  else
    Result := -1;
end;

function platform_file_getcwd(ABuf: PAnsiChar; ASize: PtrUInt): PAnsiChar;
begin
  if GetCurrentDirectoryA(DWORD(ASize), ABuf) > 0 then
    Result := ABuf
  else
    Result := nil;
end;

function platform_file_chdir(const APath: PAnsiChar): Int32;
begin
  if SetCurrentDirectoryA(APath) then
    Result := 0
  else
    Result := -1;
end;

function platform_dir_open(const APath: PAnsiChar; out AHandle: TPlatformDirHandle): Int32;
begin
  FillChar(AHandle, SizeOf(AHandle), 0);
  AHandle.FindHandle := HANDLE(PtrInt(-1));
  AHandle.First := True;
  AHandle.Finished := False;
  Result := 0;
end;

function platform_dir_read(var AHandle: TPlatformDirHandle; out AEntry: TPlatformDirEntry): Int32;
begin
  FillChar(AEntry, SizeOf(AEntry), 0);
  if AHandle.Finished then
  begin
    Result := 1;
    Exit;
  end;
  Result := 1;
end;

function platform_dir_close(var AHandle: TPlatformDirHandle): Int32;
begin
  if AHandle.FindHandle <> HANDLE(PtrInt(-1)) then
  begin
    FindClose(AHandle.FindHandle);
    AHandle.FindHandle := HANDLE(PtrInt(-1));
  end;
  Result := 0;
end;
{$ENDIF}

{$IF not defined(NEXTPAS_UNIX) and not defined(NEXTPAS_WINDOWS)}
function platform_file_open(const APath: PAnsiChar; AMode: TPlatformFileOpenMode; ACreate: TPlatformFileCreateMode; out AHandle: TPlatformFileHandle): Int32; begin Result := -1; end;
function platform_file_close(var AHandle: TPlatformFileHandle): Int32; begin Result := -1; end;
function platform_file_read(const AHandle: TPlatformFileHandle; ABuf: Pointer; ACount: PtrUInt; out ABytesRead: PtrUInt): Int32; begin ABytesRead := 0; Result := -1; end;
function platform_file_write(const AHandle: TPlatformFileHandle; ABuf: Pointer; ACount: PtrUInt; out ABytesWritten: PtrUInt): Int32; begin ABytesWritten := 0; Result := -1; end;
function platform_file_seek(const AHandle: TPlatformFileHandle; AOffset: Int64; AOrigin: TPlatformFileSeekOrigin; out ANewPos: Int64): Int32; begin ANewPos := -1; Result := -1; end;
function platform_file_sync(const AHandle: TPlatformFileHandle): Int32; begin Result := -1; end;
function platform_file_truncate(const AHandle: TPlatformFileHandle; ASize: Int64): Int32; begin Result := -1; end;
function platform_file_stat(const APath: PAnsiChar; out AStat: TPlatformFileStat): Int32; begin FillChar(AStat, SizeOf(AStat), 0); Result := -1; end;
function platform_file_mkdir(const APath: PAnsiChar; AMode: UInt32): Int32; begin Result := -1; end;
function platform_file_rmdir(const APath: PAnsiChar): Int32; begin Result := -1; end;
function platform_file_unlink(const APath: PAnsiChar): Int32; begin Result := -1; end;
function platform_file_rename(const AOldPath: PAnsiChar; const ANewPath: PAnsiChar): Int32; begin Result := -1; end;
function platform_file_getcwd(ABuf: PAnsiChar; ASize: PtrUInt): PAnsiChar; begin Result := nil; end;
function platform_file_chdir(const APath: PAnsiChar): Int32; begin Result := -1; end;
function platform_dir_open(const APath: PAnsiChar; out AHandle: TPlatformDirHandle): Int32; begin FillChar(AHandle, SizeOf(AHandle), 0); Result := -1; end;
function platform_dir_read(var AHandle: TPlatformDirHandle; out AEntry: TPlatformDirEntry): Int32; begin FillChar(AEntry, SizeOf(AEntry), 0); Result := 1; end;
function platform_dir_close(var AHandle: TPlatformDirHandle): Int32; begin Result := -1; end;
{$ENDIF}

end.
