unit nextpas.core.platform.mmap;

{$I nextpas.core.settings.inc}

interface

type
  TPlatformMapAccess = (
    pmaRead,
    pmaWrite,
    pmaReadWrite,
    pmaCopyOnWrite
  );

  TPlatformMapFlag = (
    pmfShared,
    pmfPrivate,
    pmfAnonymous,
    pmfFixed,
    pmfLocked
  );
  TPlatformMapFlags = set of TPlatformMapFlag;

  TPlatformMappedFile = record
    Addr: Pointer;
    Size: PtrUInt;
    FileHandle: PtrInt;
    MapHandle: PtrInt;
    Access: TPlatformMapAccess;
    Flags: TPlatformMapFlags;
    IsOpen: Boolean;
    IsAnonymous: Boolean;
    IsSharedMemory: Boolean;
    IsCreator: Boolean;
    IsFileBacked: Boolean;
    SharedName: string;
    BackingPath: string;
  end;

function platform_mmap_file(const APath: PAnsiChar; out AMap: TPlatformMappedFile): Int32;
function platform_mmap_open_file(const APath: PAnsiChar; AAccess: TPlatformMapAccess;
  AFlags: TPlatformMapFlags; ASize: UInt64; AOffset: UInt64;
  out AMap: TPlatformMappedFile): Int32;
function platform_mmap_create_anonymous(ASize: UInt64; AAccess: TPlatformMapAccess;
  AFlags: TPlatformMapFlags; out AMap: TPlatformMappedFile): Int32;
function platform_mmap_flush(var AMap: TPlatformMappedFile; AOffset: UInt64;
  ASize: UInt64): Int32;
function platform_mmap_lock(var AMap: TPlatformMappedFile; AOffset: UInt64;
  ASize: UInt64): Int32;
function platform_mmap_unlock(var AMap: TPlatformMappedFile; AOffset: UInt64;
  ASize: UInt64): Int32;
function platform_mmap_close(var AMap: TPlatformMappedFile): Int32;
function platform_mmap_page_size: UInt64;

function platform_shm_create(const AName: PAnsiChar; ASize: UInt64;
  AAccess: TPlatformMapAccess; out AMap: TPlatformMappedFile): Int32;
function platform_shm_open(const AName: PAnsiChar; AAccess: TPlatformMapAccess;
  out AMap: TPlatformMappedFile): Int32;
function platform_shm_close(var AMap: TPlatformMappedFile): Int32;

implementation

uses
  SysUtils,
  nextpas.core.platform.files,
  nextpas.core.platform.files.base
{$IFDEF NEXTPAS_UNIX}
  , nextpas.core.platform.posix.base
  , nextpas.core.platform.posix.ffi
  {$IFDEF NEXTPAS_LINUX}
  , nextpas.core.platform.linux.base
  {$ENDIF}
  {$IFDEF NEXTPAS_ANDROID}
  , nextpas.core.platform.android.base
  {$ENDIF}
  {$IFDEF NEXTPAS_MACOS}
  , nextpas.core.platform.darwin.base
  {$ENDIF}
  {$IFDEF NEXTPAS_FREEBSD}
  , nextpas.core.platform.freebsd.base
  {$ENDIF}
  {$IF not defined(NEXTPAS_LINUX) and not defined(NEXTPAS_ANDROID) and not defined(NEXTPAS_MACOS) and not defined(NEXTPAS_FREEBSD)}
  , nextpas.core.platform.unix.base
  {$ENDIF}
{$ENDIF}
{$IFDEF NEXTPAS_WINDOWS}
  , nextpas.core.platform.windows.base
  , nextpas.core.platform.windows.ffi
{$ENDIF}
  ;

const
  PLATFORM_MMAP_EBADF = 9;
  PLATFORM_MMAP_EINVAL = 22;
  PLATFORM_MMAP_ENOMEM = 12;
  PLATFORM_MMAP_INVALID_HANDLE = PtrInt(-1);

procedure ResetMap(out AMap: TPlatformMappedFile);
begin
  AMap.Addr := nil;
  AMap.Size := 0;
  AMap.FileHandle := PLATFORM_MMAP_INVALID_HANDLE;
  AMap.MapHandle := PLATFORM_MMAP_INVALID_HANDLE;
  AMap.Access := pmaRead;
  AMap.Flags := [];
  AMap.IsOpen := False;
  AMap.IsAnonymous := False;
  AMap.IsSharedMemory := False;
  AMap.IsCreator := False;
  AMap.IsFileBacked := False;
  AMap.SharedName := '';
  AMap.BackingPath := '';
end;

function MapFitsPtrUInt(ASize: UInt64): Boolean; inline;
begin
  Result := SizeOf(PtrUInt) >= SizeOf(UInt64);
end;

function CheckedRange(const AMap: TPlatformMappedFile; AOffset: UInt64; ASize: UInt64;
  out APtr: Pointer; out ARangeSize: PtrUInt): Boolean;
begin
  Result := False;
  APtr := nil;
  ARangeSize := 0;
  if (not AMap.IsOpen) or (AMap.Addr = nil) then Exit;
  if AOffset > UInt64(AMap.Size) then Exit;
  if ASize > UInt64(AMap.Size) - AOffset then Exit;
  if not MapFitsPtrUInt(ASize) then Exit;

  APtr := Pointer(PByte(AMap.Addr) + PtrUInt(AOffset));
  ARangeSize := PtrUInt(ASize);
  Result := True;
end;

function FileStatSize(const APath: PAnsiChar; out ASize: UInt64): Int32;
var
  LStat: TPlatformFileStat;
begin
  Result := platform_file_stat(APath, LStat);
  if Result = 0 then
  begin
    if LStat.Size < 0 then
      ASize := 0
    else
      ASize := UInt64(LStat.Size);
  end
  else
    ASize := 0;
end;

function FileExistsByStat(const APath: PAnsiChar): Boolean;
var
  LSize: UInt64;
begin
  Result := FileStatSize(APath, LSize) = 0;
end;

function OpenModeForAccess(AAccess: TPlatformMapAccess): TPlatformFileOpenMode;
begin
  case AAccess of
    pmaRead: Result := fomReadOnly;
    pmaWrite: Result := fomWriteOnly;
    pmaReadWrite: Result := fomReadWrite;
    pmaCopyOnWrite: Result := fomReadOnly;
  end;
end;

function CreateModeForPath(const APath: PAnsiChar): TPlatformFileCreateMode;
begin
  if FileExistsByStat(APath) then
    Result := fcmOpenExisting
  else
    Result := fcmOpenOrCreate;
end;

function OpenMappedFileHandle(const APath: PAnsiChar; AAccess: TPlatformMapAccess;
  out AHandle: TPlatformFileHandle; out AFileSize: UInt64): Int32;
var
  LStat: TPlatformFileStat;
begin
  Result := platform_file_open(APath, OpenModeForAccess(AAccess),
    CreateModeForPath(APath), AHandle);
  if Result <> 0 then Exit;

  Result := platform_file_fstat(AHandle, LStat);
  if Result <> 0 then
  begin
    platform_file_close(AHandle);
    Exit;
  end;

  if LStat.Size < 0 then
    AFileSize := 0
  else
    AFileSize := UInt64(LStat.Size);
end;

{$IFDEF NEXTPAS_UNIX}
function PosixProtection(AAccess: TPlatformMapAccess): Int32;
begin
  case AAccess of
    pmaRead: Result := PLATFORM_POSIX_PROT_READ;
    pmaWrite: Result := PLATFORM_POSIX_PROT_WRITE;
    pmaReadWrite: Result := PLATFORM_POSIX_PROT_READ or PLATFORM_POSIX_PROT_WRITE;
    pmaCopyOnWrite: Result := PLATFORM_POSIX_PROT_READ or PLATFORM_POSIX_PROT_WRITE;
  end;
end;

function PosixMapFlags(AFlags: TPlatformMapFlags): Int32;
begin
  if pmfShared in AFlags then
    Result := PLATFORM_POSIX_MAP_SHARED
  else
    Result := PLATFORM_POSIX_MAP_PRIVATE;

  if pmfAnonymous in AFlags then
    Result := Result or PLATFORM_POSIX_MAP_ANONYMOUS;
  if pmfFixed in AFlags then
    Result := Result or PLATFORM_POSIX_MAP_FIXED;
end;

function PosixMapFd(AFd: cint; ASize: UInt64; AOffset: UInt64;
  AAccess: TPlatformMapAccess; AFlags: TPlatformMapFlags;
  out AMap: TPlatformMappedFile): Int32;
var
  LAddr: Pointer;
begin
  if (ASize = 0) or (not MapFitsPtrUInt(ASize)) then
    Exit(PLATFORM_MMAP_EINVAL);

  LAddr := mmap(nil, PtrUInt(ASize), PosixProtection(AAccess),
    PosixMapFlags(AFlags), AFd, Int64(AOffset));
  if PtrUInt(LAddr) = PLATFORM_POSIX_MAP_FAILED_PTR then
    Exit(platform_get_errno);

  AMap.Addr := LAddr;
  AMap.Size := PtrUInt(ASize);
  AMap.FileHandle := PtrInt(AFd);
  AMap.MapHandle := PLATFORM_MMAP_INVALID_HANDLE;
  AMap.Access := AAccess;
  AMap.Flags := AFlags;
  AMap.IsOpen := True;
  AMap.IsAnonymous := pmfAnonymous in AFlags;
  Result := 0;
end;

function PosixGetEnvString(const AName: PAnsiChar): string;
var
  P: PAnsiChar;
begin
  P := getenv(AName);
  if P = nil then
    Result := ''
  else
    Result := string(P);
end;

function NormalizeSharedName(const AName: string): string;
begin
  if (AName <> '') and (AName[1] = '/') then
    Result := AName
  else
    Result := '/' + AName;
end;

function BuildSharedFallbackPath(const AName: string): string;
var
  LDir: string;
  LBase: string;
begin
  LDir := PosixGetEnvString('NEXTPAS_SHM_DIR');
  if LDir = '' then
    LDir := '/tmp';

  LBase := AName;
  if (LBase <> '') and (LBase[1] = '/') then
    Delete(LBase, 1, 1);
  LBase := StringReplace(LBase, '/', '_', [rfReplaceAll]);

  if (LDir <> '') and (LDir[Length(LDir)] <> '/') then
    LDir := LDir + '/';
  Result := LDir + 'fafafa_shm_' + LBase;
end;

function ShouldFallbackShm(AErr: Int32): Boolean;
begin
  Result := (AErr = 1) or (AErr = 2) or (AErr = 13) or
    (AErr = 38) or (AErr = 78);
end;

function OpenSharedFallback(const AName: string; ASize: UInt64; AAccess: TPlatformMapAccess;
  ACreate: Boolean; out AMap: TPlatformMappedFile): Int32;
var
  LFallback: string;
  LExists: Boolean;
  LSize: UInt64;
begin
  LFallback := BuildSharedFallbackPath(AName);
  LExists := FileExistsByStat(PAnsiChar(LFallback));
  if (not ACreate) and (not LExists) then
    Exit(2);

  LSize := ASize;
  Result := platform_mmap_open_file(PAnsiChar(LFallback), AAccess, [pmfShared], LSize, 0, AMap);
  if Result <> 0 then Exit;

  AMap.IsSharedMemory := True;
  AMap.IsFileBacked := True;
  AMap.IsCreator := ACreate and (not LExists);
  AMap.SharedName := AName;
  AMap.BackingPath := LFallback;
end;
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
function UInt64High(AValue: UInt64): DWORD; inline;
begin
  Result := DWORD((AValue shr 32) and UInt64($FFFFFFFF));
end;

function UInt64Low(AValue: UInt64): DWORD; inline;
begin
  Result := DWORD(AValue and UInt64($FFFFFFFF));
end;

function WindowsProtection(AAccess: TPlatformMapAccess): DWORD;
begin
  case AAccess of
    pmaRead: Result := PAGE_READONLY;
    pmaWrite: Result := PAGE_READWRITE;
    pmaReadWrite: Result := PAGE_READWRITE;
    pmaCopyOnWrite: Result := PAGE_WRITECOPY;
  end;
end;

function WindowsSharedProtection(AAccess: TPlatformMapAccess): DWORD;
begin
  case AAccess of
    pmaCopyOnWrite: Result := PAGE_WRITECOPY;
  else
    Result := PAGE_READWRITE;
  end;
end;

function WindowsMapAccess(AAccess: TPlatformMapAccess): DWORD;
begin
  case AAccess of
    pmaRead: Result := FILE_MAP_READ;
    pmaWrite: Result := FILE_MAP_WRITE;
    pmaReadWrite: Result := FILE_MAP_READ or FILE_MAP_WRITE;
    pmaCopyOnWrite: Result := FILE_MAP_COPY;
  end;
end;

function WindowsSharedName(const AName: string): string;
begin
  if Pos('\', AName) = 0 then
    Result := 'Local\' + AName
  else
    Result := AName;
end;
{$ENDIF}

function platform_mmap_file(const APath: PAnsiChar; out AMap: TPlatformMappedFile): Int32;
var
  LSize: UInt64;
begin
  ResetMap(AMap);
  Result := FileStatSize(APath, LSize);
  if Result <> 0 then Exit;
  Result := platform_mmap_open_file(APath, pmaRead, [pmfPrivate], 0, 0, AMap);
end;

function platform_mmap_open_file(const APath: PAnsiChar; AAccess: TPlatformMapAccess;
  AFlags: TPlatformMapFlags; ASize: UInt64; AOffset: UInt64;
  out AMap: TPlatformMappedFile): Int32;
var
  LFile: TPlatformFileHandle;
  LFileSize: UInt64;
  LMapSize: UInt64;
begin
  ResetMap(AMap);
  if APath = nil then
    Exit(PLATFORM_MMAP_EINVAL);

  Result := OpenMappedFileHandle(APath, AAccess, LFile, LFileSize);
  if Result <> 0 then Exit;

  if ASize = 0 then
    LMapSize := LFileSize
  else
    LMapSize := ASize;

  if LMapSize = 0 then
  begin
    platform_file_close(LFile);
    Exit(PLATFORM_MMAP_EINVAL);
  end;
  if not MapFitsPtrUInt(LMapSize) then
  begin
    platform_file_close(LFile);
    Exit(PLATFORM_MMAP_EINVAL);
  end;

  if LFileSize < LMapSize then
  begin
    Result := platform_file_truncate(LFile, Int64(LMapSize));
    if Result <> 0 then
    begin
      platform_file_close(LFile);
      Exit;
    end;
  end;

{$IFDEF NEXTPAS_UNIX}
  Result := PosixMapFd(LFile.Value, LMapSize, AOffset, AAccess, AFlags, AMap);
  if Result <> 0 then
  begin
    platform_file_close(LFile);
    Exit;
  end;
{$ENDIF}
{$IFDEF NEXTPAS_WINDOWS}
  AMap.MapHandle := PtrInt(CreateFileMappingA(LFile.Value, nil,
    WindowsProtection(AAccess), UInt64High(LMapSize), UInt64Low(LMapSize), nil));
  if AMap.MapHandle = 0 then
  begin
    Result := Int32(GetLastError);
    platform_file_close(LFile);
    ResetMap(AMap);
    Exit;
  end;

  AMap.Addr := MapViewOfFile(HANDLE(PtrUInt(AMap.MapHandle)), WindowsMapAccess(AAccess),
    UInt64High(AOffset), UInt64Low(AOffset), PtrUInt(LMapSize));
  if AMap.Addr = nil then
  begin
    Result := Int32(GetLastError);
    CloseHandle(HANDLE(PtrUInt(AMap.MapHandle)));
    platform_file_close(LFile);
    ResetMap(AMap);
    Exit;
  end;

  AMap.Size := PtrUInt(LMapSize);
  AMap.Access := AAccess;
  AMap.Flags := AFlags;
  AMap.IsOpen := True;
  AMap.IsAnonymous := False;
{$ENDIF}

  AMap.FileHandle := PtrInt(LFile.Value);
  Result := 0;
end;

function platform_mmap_create_anonymous(ASize: UInt64; AAccess: TPlatformMapAccess;
  AFlags: TPlatformMapFlags; out AMap: TPlatformMappedFile): Int32;
begin
  ResetMap(AMap);
  if (ASize = 0) or (not MapFitsPtrUInt(ASize)) then
    Exit(PLATFORM_MMAP_EINVAL);

{$IFDEF NEXTPAS_UNIX}
  Result := PosixMapFd(-1, ASize, 0, AAccess, AFlags + [pmfAnonymous], AMap);
  if Result = 0 then
  begin
    AMap.FileHandle := PLATFORM_MMAP_INVALID_HANDLE;
    AMap.IsAnonymous := True;
  end;
{$ENDIF}
{$IFDEF NEXTPAS_WINDOWS}
  AMap.MapHandle := PtrInt(CreateFileMappingA(HANDLE(PtrUInt(INVALID_HANDLE_VALUE)),
    nil, WindowsProtection(AAccess), UInt64High(ASize), UInt64Low(ASize), nil));
  if AMap.MapHandle = 0 then
    Exit(Int32(GetLastError));

  AMap.Addr := MapViewOfFile(HANDLE(PtrUInt(AMap.MapHandle)), WindowsMapAccess(AAccess),
    0, 0, PtrUInt(ASize));
  if AMap.Addr = nil then
  begin
    Result := Int32(GetLastError);
    CloseHandle(HANDLE(PtrUInt(AMap.MapHandle)));
    ResetMap(AMap);
    Exit;
  end;

  AMap.Size := PtrUInt(ASize);
  AMap.FileHandle := PLATFORM_MMAP_INVALID_HANDLE;
  AMap.Access := AAccess;
  AMap.Flags := AFlags + [pmfAnonymous];
  AMap.IsOpen := True;
  AMap.IsAnonymous := True;
  Result := 0;
{$ENDIF}
{$IF not defined(NEXTPAS_UNIX) and not defined(NEXTPAS_WINDOWS)}
  Result := -1;
{$ENDIF}
end;

function platform_mmap_flush(var AMap: TPlatformMappedFile; AOffset: UInt64;
  ASize: UInt64): Int32;
var
  LPtr: Pointer;
  LSize: PtrUInt;
begin
  if not CheckedRange(AMap, AOffset, ASize, LPtr, LSize) then
    Exit(PLATFORM_MMAP_EINVAL);

{$IFDEF NEXTPAS_UNIX}
  if msync(LPtr, LSize, MS_SYNC) = 0 then
    Result := 0
  else
    Result := platform_get_errno;
{$ENDIF}
{$IFDEF NEXTPAS_WINDOWS}
  if FlushViewOfFile(LPtr, LSize) then
    Result := 0
  else
    Result := Int32(GetLastError);
{$ENDIF}
{$IF not defined(NEXTPAS_UNIX) and not defined(NEXTPAS_WINDOWS)}
  Result := -1;
{$ENDIF}
end;

function platform_mmap_lock(var AMap: TPlatformMappedFile; AOffset: UInt64;
  ASize: UInt64): Int32;
var
  LPtr: Pointer;
  LSize: PtrUInt;
begin
  if not CheckedRange(AMap, AOffset, ASize, LPtr, LSize) then
    Exit(PLATFORM_MMAP_EINVAL);

{$IFDEF NEXTPAS_UNIX}
  if mlock(LPtr, LSize) = 0 then
    Result := 0
  else
    Result := platform_get_errno;
{$ENDIF}
{$IFDEF NEXTPAS_WINDOWS}
  if VirtualLock(LPtr, LSize) then
    Result := 0
  else
    Result := Int32(GetLastError);
{$ENDIF}
{$IF not defined(NEXTPAS_UNIX) and not defined(NEXTPAS_WINDOWS)}
  Result := -1;
{$ENDIF}
end;

function platform_mmap_unlock(var AMap: TPlatformMappedFile; AOffset: UInt64;
  ASize: UInt64): Int32;
var
  LPtr: Pointer;
  LSize: PtrUInt;
begin
  if not CheckedRange(AMap, AOffset, ASize, LPtr, LSize) then
    Exit(PLATFORM_MMAP_EINVAL);

{$IFDEF NEXTPAS_UNIX}
  if munlock(LPtr, LSize) = 0 then
    Result := 0
  else
    Result := platform_get_errno;
{$ENDIF}
{$IFDEF NEXTPAS_WINDOWS}
  if VirtualUnlock(LPtr, LSize) then
    Result := 0
  else
    Result := Int32(GetLastError);
{$ENDIF}
{$IF not defined(NEXTPAS_UNIX) and not defined(NEXTPAS_WINDOWS)}
  Result := -1;
{$ENDIF}
end;

function platform_mmap_close(var AMap: TPlatformMappedFile): Int32;
var
  LResult: Int32;
{$IFDEF NEXTPAS_UNIX}
  LFile: TPlatformFileHandle;
{$ENDIF}
begin
  if (not AMap.IsOpen) or (AMap.Addr = nil) then
    Exit(PLATFORM_MMAP_EBADF);

  LResult := 0;
{$IFDEF NEXTPAS_UNIX}
  if munmap(AMap.Addr, AMap.Size) <> 0 then
    LResult := platform_get_errno;
  if AMap.FileHandle <> PLATFORM_MMAP_INVALID_HANDLE then
  begin
    LFile.Value := cint(AMap.FileHandle);
    platform_file_close(LFile);
  end;
  if AMap.IsSharedMemory and AMap.IsCreator then
  begin
    if AMap.IsFileBacked then
    begin
      if AMap.BackingPath <> '' then
        platform_file_unlink(PAnsiChar(AMap.BackingPath));
    end
    else if AMap.SharedName <> '' then
      shm_unlink(PAnsiChar(AMap.SharedName));
  end;
{$ENDIF}
{$IFDEF NEXTPAS_WINDOWS}
  if not UnmapViewOfFile(AMap.Addr) then
    LResult := Int32(GetLastError);
  if AMap.MapHandle <> PLATFORM_MMAP_INVALID_HANDLE then
    CloseHandle(HANDLE(PtrUInt(AMap.MapHandle)));
  if AMap.FileHandle <> PLATFORM_MMAP_INVALID_HANDLE then
    CloseHandle(HANDLE(PtrUInt(AMap.FileHandle)));
{$ENDIF}

  ResetMap(AMap);
  Result := LResult;
end;

function platform_mmap_page_size: UInt64;
{$IFDEF NEXTPAS_WINDOWS}
var
  LInfo: SYSTEM_INFO;
begin
  GetSystemInfo(LInfo);
  Result := LInfo.dwPageSize;
end;
{$ELSEIF DEFINED(NEXTPAS_UNIX)}
var
  LPageSize: PtrInt;
begin
  LPageSize := 0;
  if _SC_PAGESIZE >= 0 then
    LPageSize := sysconf(_SC_PAGESIZE);
  if LPageSize > 0 then
    Result := UInt64(LPageSize)
  else
    Result := 4096;
end;
{$ELSE}
begin
  Result := 4096;
end;
{$ENDIF}

function platform_shm_create(const AName: PAnsiChar; ASize: UInt64;
  AAccess: TPlatformMapAccess; out AMap: TPlatformMappedFile): Int32;
var
  LName: string;
{$IFDEF NEXTPAS_UNIX}
  LSharedName: string;
  LFd: cint;
  LHandle: TPlatformFileHandle;
  LErr: Int32;
{$ENDIF}
{$IFDEF NEXTPAS_WINDOWS}
  LWinName: string;
{$ENDIF}
begin
  ResetMap(AMap);
  if (AName = nil) or (AName^ = #0) or (ASize = 0) or (not MapFitsPtrUInt(ASize)) then
    Exit(PLATFORM_MMAP_EINVAL);

  LName := string(AName);
{$IFDEF NEXTPAS_UNIX}
  LSharedName := NormalizeSharedName(LName);
  LFd := shm_open(PAnsiChar(LSharedName), O_CREAT or O_EXCL or O_RDWR,
    PLATFORM_FILE_MODE_DEFAULT);
  if LFd < 0 then
  begin
    LFd := shm_open(PAnsiChar(LSharedName), O_RDWR, 0);
    if LFd < 0 then
    begin
      LErr := platform_get_errno;
      if ShouldFallbackShm(LErr) then
        Exit(OpenSharedFallback(LName, ASize, AAccess, True, AMap));
      Exit(LErr);
    end;
    AMap.IsCreator := False;
  end
  else
  begin
    AMap.IsCreator := True;
    LHandle.Value := LFd;
    Result := platform_file_truncate(LHandle, Int64(ASize));
    if Result <> 0 then
    begin
      platform_file_close(LHandle);
      shm_unlink(PAnsiChar(LSharedName));
      ResetMap(AMap);
      Exit;
    end;
  end;

  Result := PosixMapFd(LFd, ASize, 0, AAccess, [pmfShared], AMap);
  if Result <> 0 then
  begin
    close(LFd);
    if AMap.IsCreator then
      shm_unlink(PAnsiChar(LSharedName));
    ResetMap(AMap);
    Exit;
  end;
  AMap.IsSharedMemory := True;
  AMap.SharedName := LSharedName;
{$ENDIF}
{$IFDEF NEXTPAS_WINDOWS}
  LWinName := WindowsSharedName(LName);
  AMap.MapHandle := PtrInt(CreateFileMappingA(HANDLE(PtrUInt(INVALID_HANDLE_VALUE)),
    nil, WindowsSharedProtection(AAccess), UInt64High(ASize), UInt64Low(ASize),
    PAnsiChar(LWinName)));
  if AMap.MapHandle = 0 then
  begin
    Result := Int32(GetLastError);
    ResetMap(AMap);
    Exit;
  end;

  AMap.IsCreator := GetLastError <> ERROR_ALREADY_EXISTS;
  AMap.Addr := MapViewOfFile(HANDLE(PtrUInt(AMap.MapHandle)), WindowsMapAccess(AAccess),
    0, 0, PtrUInt(ASize));
  if AMap.Addr = nil then
  begin
    Result := Int32(GetLastError);
    CloseHandle(HANDLE(PtrUInt(AMap.MapHandle)));
    ResetMap(AMap);
    Exit;
  end;

  AMap.Size := PtrUInt(ASize);
  AMap.Access := AAccess;
  AMap.Flags := [pmfShared];
  AMap.IsOpen := True;
  AMap.IsSharedMemory := True;
  AMap.SharedName := LWinName;
  Result := 0;
{$ENDIF}
{$IF not defined(NEXTPAS_UNIX) and not defined(NEXTPAS_WINDOWS)}
  Result := -1;
{$ENDIF}
end;

function platform_shm_open(const AName: PAnsiChar; AAccess: TPlatformMapAccess;
  out AMap: TPlatformMappedFile): Int32;
var
  LName: string;
{$IFDEF NEXTPAS_UNIX}
  LSharedName: string;
  LFd: cint;
  LHandle: TPlatformFileHandle;
  LStat: TPlatformFileStat;
  LSize: UInt64;
  LErr: Int32;
{$ENDIF}
{$IFDEF NEXTPAS_WINDOWS}
  LWinName: string;
  LMemInfo: MEMORY_BASIC_INFORMATION;
{$ENDIF}
begin
  ResetMap(AMap);
  if (AName = nil) or (AName^ = #0) then
    Exit(PLATFORM_MMAP_EINVAL);

  LName := string(AName);
{$IFDEF NEXTPAS_UNIX}
  LSharedName := NormalizeSharedName(LName);
  case AAccess of
    pmaRead, pmaCopyOnWrite: LFd := shm_open(PAnsiChar(LSharedName), O_RDONLY, 0);
  else
    LFd := shm_open(PAnsiChar(LSharedName), O_RDWR, 0);
  end;
  if LFd < 0 then
  begin
    LErr := platform_get_errno;
    if ShouldFallbackShm(LErr) then
      Exit(OpenSharedFallback(LName, 0, AAccess, False, AMap));
    Exit(LErr);
  end;

  LHandle.Value := LFd;
  Result := platform_file_fstat(LHandle, LStat);
  if Result <> 0 then
  begin
    platform_file_close(LHandle);
    Exit;
  end;
  if LStat.Size <= 0 then
  begin
    platform_file_close(LHandle);
    Exit(PLATFORM_MMAP_EINVAL);
  end;
  LSize := UInt64(LStat.Size);

  Result := PosixMapFd(LFd, LSize, 0, AAccess, [pmfShared], AMap);
  if Result <> 0 then
  begin
    close(LFd);
    ResetMap(AMap);
    Exit;
  end;
  AMap.IsSharedMemory := True;
  AMap.IsCreator := False;
  AMap.SharedName := LSharedName;
{$ENDIF}
{$IFDEF NEXTPAS_WINDOWS}
  LWinName := WindowsSharedName(LName);
  AMap.MapHandle := PtrInt(OpenFileMappingA(WindowsMapAccess(AAccess), False,
    PAnsiChar(LWinName)));
  if AMap.MapHandle = 0 then
  begin
    AMap.MapHandle := PtrInt(OpenFileMappingA(FILE_MAP_READ, False, PAnsiChar(LWinName)));
    if AMap.MapHandle = 0 then
    begin
      Result := Int32(GetLastError);
      ResetMap(AMap);
      Exit;
    end;
  end;

  AMap.Addr := MapViewOfFile(HANDLE(PtrUInt(AMap.MapHandle)), WindowsMapAccess(AAccess),
    0, 0, 0);
  if AMap.Addr = nil then
  begin
    Result := Int32(GetLastError);
    CloseHandle(HANDLE(PtrUInt(AMap.MapHandle)));
    ResetMap(AMap);
    Exit;
  end;

  if VirtualQuery(AMap.Addr, @LMemInfo, SizeOf(LMemInfo)) = 0 then
  begin
    Result := Int32(GetLastError);
    UnmapViewOfFile(AMap.Addr);
    CloseHandle(HANDLE(PtrUInt(AMap.MapHandle)));
    ResetMap(AMap);
    Exit;
  end;

  AMap.Size := LMemInfo.RegionSize;
  AMap.Access := AAccess;
  AMap.Flags := [pmfShared];
  AMap.IsOpen := True;
  AMap.IsSharedMemory := True;
  AMap.IsCreator := False;
  AMap.SharedName := LWinName;
  Result := 0;
{$ENDIF}
{$IF not defined(NEXTPAS_UNIX) and not defined(NEXTPAS_WINDOWS)}
  Result := -1;
{$ENDIF}
end;

function platform_shm_close(var AMap: TPlatformMappedFile): Int32;
begin
  Result := platform_mmap_close(AMap);
end;

end.
