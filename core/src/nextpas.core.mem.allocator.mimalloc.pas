unit nextpas.core.mem.allocator.mimalloc;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.mem.allocator.base
  {$IFNDEF FAFAFA_CORE_MIMALLOC_STATIC}
  ,dynlibs
  {$ENDIF}
  ;

type
  {**
   * TMimallocAllocator
   * @desc 使用 mimalloc 库的 IAllocator 实现
   *}
  TMimallocAllocator = class(TAllocator)
  protected
    function  DoGetMem(aSize: SizeUInt): Pointer; override;
    function  DoAllocMem(aSize: SizeUInt): Pointer; override;
    function  DoReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer; override;
    procedure DoFreeMem(aDst: Pointer); override;
  public
    function  Traits: TAllocatorTraits; override;
  end;

function TryGetMimallocAllocator(out A: IAllocator): Boolean;
function GetMimallocAllocator: IAllocator;

implementation

{$IFDEF FAFAFA_CORE_MIMALLOC_STATIC}
  {$LINKLIB mimalloc}
  {$IFDEF UNIX}
    {$LINKLIB c}
  {$ENDIF}
  // Static link/import: bind directly at link time
  function _mi_malloc(aSize: SizeUInt): Pointer; cdecl; external name 'mi_malloc';
  function _mi_calloc(aCount, aSize: SizeUInt): Pointer; cdecl; external name 'mi_calloc';
  function _mi_realloc(aPtr: Pointer; aNewSize: SizeUInt): Pointer; cdecl; external name 'mi_realloc';
  procedure _mi_free(aPtr: Pointer); cdecl; external name 'mi_free';
  function EnsureMimallocLoaded: Boolean; inline;
  begin
    Result := True;
  end;
{$ELSE}
  // Delayed loading of mimalloc to avoid loader-time failures
  var
    _miLib: TLibHandle = 0;
    _miLoaded: Boolean = False;
    _mi_malloc: function(aSize: SizeUInt): Pointer; cdecl = nil;
    _mi_calloc: function(aCount, aSize: SizeUInt): Pointer; cdecl = nil;
    _mi_realloc: function(aPtr: Pointer; aNewSize: SizeUInt): Pointer; cdecl = nil;
    _mi_free: procedure(aPtr: Pointer); cdecl = nil;
    GLoadLock: TRTLCriticalSection;

  function GetPlatformLibSubdir: string;
  begin
    // 使用 FPC 内置的目标平台常量，与 lazbuild 输出目录一致
    Result := LowerCase({$I %FPCTARGETCPU%}) + '-' + LowerCase({$I %FPCTARGETOS%});
  end;

  function TryLoadFromPath(const aBasePath, aLibName: string): TLibHandle;
  var
    FullPath: string;
  begin
    FullPath := aBasePath + aLibName;
    Result := LoadLibrary(PChar(FullPath));
  end;

  function TryLoadMimallocLibrary: TLibHandle;
  var
    EnvPath, ExePath, LibSubdir: AnsiString;
  begin
    Result := 0;

    // 1. 环境变量优先（用户可完全控制）
    {$IFDEF MSWINDOWS}
    EnvPath := GetEnvironmentVariable('FAFAFA_MIMALLOC_DLL');
    {$ELSE}
    EnvPath := GetEnvironmentVariable('FAFAFA_MIMALLOC_SO');
    {$ENDIF}
    if (EnvPath <> '') then
    begin
      Result := LoadLibrary(PChar(EnvPath));
      if Result <> 0 then Exit;
    end;

    // 2. 程序目录下的 lib/<platform>/ 目录
    ExePath := ExtractFilePath(ParamStr(0));
    LibSubdir := GetPlatformLibSubdir;
    if LibSubdir <> '' then
    begin
      {$IFDEF MSWINDOWS}
      Result := TryLoadFromPath(ExePath + 'lib' + DirectorySeparator + LibSubdir + DirectorySeparator, 'mimalloc.dll');
      if Result = 0 then
        Result := TryLoadFromPath(ExePath + 'lib' + DirectorySeparator + LibSubdir + DirectorySeparator, 'mimalloc-redirect.dll');
      {$ELSE}
      Result := TryLoadFromPath(ExePath + 'lib' + DirectorySeparator + LibSubdir + DirectorySeparator, 'libmimalloc.so');
      if Result = 0 then
        Result := TryLoadFromPath(ExePath + 'lib' + DirectorySeparator + LibSubdir + DirectorySeparator, 'libmimalloc.so.2');
      {$ENDIF}
      if Result <> 0 then Exit;
    end;

    // 3. 系统路径回退
    {$IFDEF MSWINDOWS}
    Result := LoadLibrary('mimalloc.dll');
    if Result = 0 then Result := LoadLibrary('mimalloc-redirect.dll');
    {$ELSE}
    Result := LoadLibrary('libmimalloc.so');
    if Result = 0 then Result := LoadLibrary('libmimalloc.so.2');
    if Result = 0 then Result := LoadLibrary('mimalloc');
    {$ENDIF}
  end;

  function EnsureMimallocLoaded: Boolean;
  var
    LLib: TLibHandle;
  begin
    if _miLoaded then Exit(True);
    EnterCriticalSection(GLoadLock);
    try
      if _miLoaded then Exit(True);
      // try load
      LLib := TryLoadMimallocLibrary;
      if LLib = 0 then Exit(False);
      _miLib := LLib;
      Pointer(_mi_malloc) := GetProcedureAddress(_miLib, 'mi_malloc');
      Pointer(_mi_calloc) := GetProcedureAddress(_miLib, 'mi_calloc');
      Pointer(_mi_realloc) := GetProcedureAddress(_miLib, 'mi_realloc');
      Pointer(_mi_free) := GetProcedureAddress(_miLib, 'mi_free');
      _miLoaded := Assigned(_mi_malloc) and Assigned(_mi_calloc) and Assigned(_mi_realloc) and Assigned(_mi_free);
      if not _miLoaded then
      begin
        FreeLibrary(_miLib);
        _miLib := 0;
      end;
      Result := _miLoaded;
    finally
      LeaveCriticalSection(GLoadLock);
    end;
  end;
{$ENDIF}

var
  _MimallocAllocatorObj: TAllocator = nil;
  _MimallocAllocatorIntf: IAllocator = nil;
  GAllocatorLock: TRTLCriticalSection;

function TMimallocAllocator.DoGetMem(aSize: SizeUInt): Pointer;
begin
  if not EnsureMimallocLoaded then
    raise Exception.Create('mimalloc not available: cannot load library');
  Result := _mi_malloc(aSize);
end;

function TMimallocAllocator.DoAllocMem(aSize: SizeUInt): Pointer;
begin
  if not EnsureMimallocLoaded then
    raise Exception.Create('mimalloc not available: cannot load library');
  Result := _mi_calloc(1, aSize);
end;

function TMimallocAllocator.DoReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
begin
  if not EnsureMimallocLoaded then
    raise Exception.Create('mimalloc not available: cannot load library');
  Result := _mi_realloc(aDst, aSize);
end;

procedure TMimallocAllocator.DoFreeMem(aDst: Pointer);
begin
  if not EnsureMimallocLoaded then
    Exit; // free path when library missing: nothing to do
  _mi_free(aDst);
end;

function TMimallocAllocator.Traits: TAllocatorTraits;
begin
  Result := inherited Traits;
  // mimalloc semantics:
  // - AllocMem uses mi_calloc => zero initialized; GetMem not guaranteed
  // - SupportsAligned remains False here (use aligned bridge or module)
  // - HasMemSize stays False until we wire mi_usable_size with contract/tests
  Result.ZeroInitialized := True;
  Result.SupportsAligned := False;
  Result.HasMemSize      := False;
end;

function GetMimallocAllocator: IAllocator;
begin
  if _MimallocAllocatorObj = nil then
  begin
    EnterCriticalSection(GAllocatorLock);
    try
      if _MimallocAllocatorObj = nil then
      begin
        _MimallocAllocatorObj := TMimallocAllocator.Create;
        _MimallocAllocatorIntf := _MimallocAllocatorObj as IAllocator; // anchor lifetime
      end;
    finally
      LeaveCriticalSection(GAllocatorLock);
    end;
  end;
  Result := _MimallocAllocatorIntf;
end;
function TryGetMimallocAllocator(out A: IAllocator): Boolean;
begin
  try
    A := GetMimallocAllocator;
    Result := True;
  except
    A := nil;
    Result := False;
  end;
end;

initialization
  {$IFNDEF FAFAFA_CORE_MIMALLOC_STATIC}
  InitCriticalSection(GLoadLock);
  {$ENDIF}
  InitCriticalSection(GAllocatorLock);
finalization
  DoneCriticalSection(GAllocatorLock);
  {$IFNDEF FAFAFA_CORE_MIMALLOC_STATIC}
  DoneCriticalSection(GLoadLock);
  {$ENDIF}
  _MimallocAllocatorIntf := nil;
  _MimallocAllocatorObj := nil;
  {$IFNDEF FAFAFA_CORE_MIMALLOC_STATIC}
  if _miLib <> 0 then
    FreeLibrary(_miLib);
  _miLib := 0;
  {$ENDIF}


end.
