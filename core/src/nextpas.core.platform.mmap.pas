unit nextpas.core.platform.mmap;

{$I nextpas.core.settings.inc}

interface

type
  TPlatformMappedFile = record
    Addr: Pointer;
    Size: PtrUInt;
  {$IFDEF NEXTPAS_WINDOWS}
    FileHandle: PtrUInt;
    MapHandle: PtrUInt;
  {$ENDIF}
  end;

function platform_mmap_file(const APath: PAnsiChar; out AMap: TPlatformMappedFile): Int32;
function platform_mmap_close(var AMap: TPlatformMappedFile): Int32;

implementation

{$IFDEF NEXTPAS_UNIX}
uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi
{$IFDEF NEXTPAS_LINUX}
  , nextpas.core.platform.linux.base
  , nextpas.core.platform.linux.ffi
{$ENDIF}
{$IFDEF NEXTPAS_MACOS}
  , nextpas.core.platform.darwin.base
{$ENDIF}
{$IFDEF NEXTPAS_FREEBSD}
  , nextpas.core.platform.freebsd.base
{$ENDIF}
  ;

function platform_mmap_file(const APath: PAnsiChar; out AMap: TPlatformMappedFile): Int32;
var
  LFd: Int32;
  LSize: Int64;
  LAddr: Pointer;
{$IFDEF NEXTPAS_LINUX}
  LStat: TPlatformLinuxStat;
{$ENDIF}
{$IFDEF NEXTPAS_MACOS}
  LStat: TDarwinStat;
{$ENDIF}
{$IFDEF NEXTPAS_FREEBSD}
  LStat: TFreeBSDStat;
{$ENDIF}
begin
  FillChar(AMap, SizeOf(AMap), 0);
  LFd := open(APath, O_RDONLY, 0);
  if LFd < 0 then
    Exit(platform_get_errno);

{$IFDEF NEXTPAS_LINUX}
  if fstatat(AT_FDCWD, APath, LStat, 0) <> 0 then
  begin
    close(LFd);
    Exit(platform_get_errno);
  end;
  LSize := LStat.st_size;
{$ENDIF}
{$IFDEF NEXTPAS_MACOS}
  if fpstat(APath, @LStat) <> 0 then
  begin
    close(LFd);
    Exit(platform_get_errno);
  end;
  LSize := LStat.st_size;
{$ENDIF}
{$IFDEF NEXTPAS_FREEBSD}
  if fpstat(APath, @LStat) <> 0 then
  begin
    close(LFd);
    Exit(platform_get_errno);
  end;
  LSize := LStat.st_size;
{$ENDIF}

  if LSize = 0 then
  begin
    close(LFd);
    Exit(22); // EINVAL - cannot mmap empty file
  end;

  LAddr := mmap(nil, PtrUInt(LSize), PLATFORM_POSIX_PROT_READ,
    PLATFORM_POSIX_MAP_PRIVATE, LFd, 0);
  close(LFd);

  if PtrUInt(LAddr) = PLATFORM_POSIX_MAP_FAILED_PTR then
    Exit(platform_get_errno);

  AMap.Addr := LAddr;
  AMap.Size := PtrUInt(LSize);
  Result := 0;
end;

function platform_mmap_close(var AMap: TPlatformMappedFile): Int32;
begin
  if AMap.Addr = nil then
    Exit(9); // EBADF
  if munmap(AMap.Addr, AMap.Size) <> 0 then
    Result := platform_get_errno
  else
    Result := 0;
  AMap.Addr := nil;
  AMap.Size := 0;
end;
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.windows.base,
  nextpas.core.platform.windows.ffi,
  nextpas.core.platform.windows.utf16;

function platform_mmap_file(const APath: PAnsiChar; out AMap: TPlatformMappedFile): Int32;
var
  LFile, LMap: HANDLE;
  LSizeHigh: DWORD;
  LSizeLow: DWORD;
  LAddr: Pointer;
  LPath: UnicodeString;
begin
  FillChar(AMap, SizeOf(AMap), 0);
  if not platform_windows_utf8_to_wide_checked(APath, LPath) then
    Exit(Int32(ERROR_INVALID_NAME));
  LFile := CreateFileW(PWideChar(LPath), GENERIC_READ, FILE_SHARE_READ, nil,
    OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nil);
  if LFile = HANDLE(PtrInt(-1)) then
    Exit(Int32(GetLastError));
  LSizeHigh := 0;
  LSizeLow := GetFileSize(LFile, @LSizeHigh);
  if (LSizeLow = 0) and (LSizeHigh = 0) then
  begin
    CloseHandle(LFile);
    Exit(Int32(87)); // ERROR_INVALID_PARAMETER
  end;
  LMap := CreateFileMappingA(LFile, nil, PAGE_READONLY, 0, 0, nil);
  if LMap = nil then
  begin
    CloseHandle(LFile);
    Exit(Int32(GetLastError));
  end;
  LAddr := MapViewOfFile(LMap, FILE_MAP_READ, 0, 0, 0);
  if LAddr = nil then
  begin
    CloseHandle(LMap);
    CloseHandle(LFile);
    Exit(Int32(GetLastError));
  end;
  AMap.Addr := LAddr;
  AMap.Size := PtrUInt(LSizeHigh) shl 32 or PtrUInt(LSizeLow);
  AMap.FileHandle := PtrUInt(LFile);
  AMap.MapHandle := PtrUInt(LMap);
  Result := 0;
end;

function platform_mmap_close(var AMap: TPlatformMappedFile): Int32;
begin
  if AMap.Addr = nil then
    Exit(Int32(6)); // ERROR_INVALID_HANDLE
  UnmapViewOfFile(AMap.Addr);
  CloseHandle(HANDLE(AMap.MapHandle));
  CloseHandle(HANDLE(AMap.FileHandle));
  AMap.Addr := nil;
  AMap.Size := 0;
  AMap.FileHandle := 0;
  AMap.MapHandle := 0;
  Result := 0;
end;
{$ENDIF}

{$IF not defined(NEXTPAS_UNIX) and not defined(NEXTPAS_WINDOWS)}
function platform_mmap_file(const APath: PAnsiChar; out AMap: TPlatformMappedFile): Int32;
begin FillChar(AMap, SizeOf(AMap), 0); Result := -1; end;
function platform_mmap_close(var AMap: TPlatformMappedFile): Int32;
begin Result := -1; end;
{$ENDIF}

end.
