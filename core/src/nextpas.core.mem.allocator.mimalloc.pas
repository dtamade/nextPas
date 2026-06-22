unit nextpas.core.mem.allocator.mimalloc;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.os.env,
  nextpas.core.errors,
  nextpas.core.path,
  nextpas.core.mem.allocator.base
  {$IFNDEF NEXTPAS_CORE_MIMALLOC_STATIC}
  ,nextpas.core.platform.dl
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
    function  DoMemSize(aPtr: Pointer): SizeUInt; override;
  public
    function  Traits: TAllocatorTraits; override;
  end;

function TryGetMimallocAllocator(out A: IAllocator): Boolean;
function GetMimallocAllocator: IAllocator;
function MimallocUsableSizeAvailable: Boolean;
function TryGetMimallocUsableSize(aPtr: Pointer; out aSize: SizeUInt): Boolean;

implementation

uses
  nextpas.core.exception,
  nextpas.core.text.conv;

{$IFDEF NEXTPAS_CORE_MIMALLOC_STATIC}
  {$LINKLIB mimalloc}
  {$IFDEF UNIX}
    {$LINKLIB c}
  {$ENDIF}
  // Static link/import: bind directly at link time
  function _mi_malloc(aSize: SizeUInt): Pointer; cdecl; external name 'mi_malloc';
  function _mi_calloc(aCount, aSize: SizeUInt): Pointer; cdecl; external name 'mi_calloc';
  function _mi_realloc(aPtr: Pointer; aNewSize: SizeUInt): Pointer; cdecl; external name 'mi_realloc';
  procedure _mi_free(aPtr: Pointer); cdecl; external name 'mi_free';
  function _mi_malloc_usable_size(aPtr: Pointer): SizeUInt; cdecl; external name 'mi_malloc_usable_size';
  function EnsureMimallocLoaded: Boolean; inline;
  begin
    Result := True;
  end;
{$ELSE}
  // Delayed loading of mimalloc to avoid loader-time failures
  var
    _miLib: TPlatformLibrary;
    _miLoaded: Boolean = False;
    _mi_malloc: function(aSize: SizeUInt): Pointer; cdecl = nil;
    _mi_calloc: function(aCount, aSize: SizeUInt): Pointer; cdecl = nil;
    _mi_realloc: function(aPtr: Pointer; aNewSize: SizeUInt): Pointer; cdecl = nil;
    _mi_free: procedure(aPtr: Pointer); cdecl = nil;
    _mi_malloc_usable_size: function(aPtr: Pointer): SizeUInt; cdecl = nil;
    GLoadLock: TRTLCriticalSection;

  function GetPlatformLibSubdir: string;
  begin
    // 使用 FPC 内置的目标平台常量，与 lazbuild 输出目录一致
    Result := LowerCase({$I %FPCTARGETCPU%}) + '-' + LowerCase({$I %FPCTARGETOS%});
  end;

  function TryLoadFromPath(const aBasePath, aLibName: string): TPlatformLibrary;
  var
    FullPath: string;
  begin
    FillChar(Result, SizeOf(Result), 0);
    FullPath := aBasePath + aLibName;
    platform_dl_open(PAnsiChar(AnsiString(FullPath)), PLATFORM_DL_NOW, Result);
  end;

  function IsLibValid(const ALib: TPlatformLibrary): Boolean; inline;
  begin
    {$IFDEF NEXTPAS_WINDOWS}
    Result := ALib.Handle <> 0;
    {$ELSE}
    Result := ALib.Handle <> nil;
    {$ENDIF}
  end;

  function TryLoadMimallocLibrary: TPlatformLibrary;
  var
    EnvPath, ExePath, LibSubdir: AnsiString;
  begin
    FillChar(Result, SizeOf(Result), 0);

    // 1. 环境变量优先（用户可完全控制）
    {$IFDEF MSWINDOWS}
    EnvPath := GetEnvironmentVariable('NEXTPAS_MIMALLOC_DLL');
    {$ELSE}
    EnvPath := GetEnvironmentVariable('NEXTPAS_MIMALLOC_SO');
    {$ENDIF}
    if (EnvPath <> '') then
    begin
      platform_dl_open(PAnsiChar(EnvPath), PLATFORM_DL_NOW, Result);
      if IsLibValid(Result) then Exit;
    end;

    // 2. 程序目录下的 lib/<platform>/ 目录
    ExePath := ExtractFilePath(ParamStr(0));
    LibSubdir := GetPlatformLibSubdir;
    if LibSubdir <> '' then
    begin
      {$IFDEF MSWINDOWS}
      Result := TryLoadFromPath(ExePath + 'lib' + DirectorySeparator + LibSubdir + DirectorySeparator, 'mimalloc.dll');
      if not IsLibValid(Result) then
        Result := TryLoadFromPath(ExePath + 'lib' + DirectorySeparator + LibSubdir + DirectorySeparator, 'mimalloc-redirect.dll');
      {$ELSE}
      Result := TryLoadFromPath(ExePath + 'lib' + DirectorySeparator + LibSubdir + DirectorySeparator, 'libmimalloc.so');
      if not IsLibValid(Result) then
        Result := TryLoadFromPath(ExePath + 'lib' + DirectorySeparator + LibSubdir + DirectorySeparator, 'libmimalloc.so.2');
      {$ENDIF}
      if IsLibValid(Result) then Exit;
    end;

    // 3. 系统路径回退
    {$IFDEF MSWINDOWS}
    Result := TryLoadFromPath('', 'mimalloc.dll');
    if not IsLibValid(Result) then Result := TryLoadFromPath('', 'mimalloc-redirect.dll');
    {$ELSE}
    Result := TryLoadFromPath('', 'libmimalloc.so');
    if not IsLibValid(Result) then Result := TryLoadFromPath('', 'libmimalloc.so.2');
    if not IsLibValid(Result) then Result := TryLoadFromPath('', 'mimalloc');
    {$ENDIF}
  end;

  function EnsureMimallocLoaded: Boolean;
  var
    LLib: TPlatformLibrary;
  begin
    if _miLoaded then Exit(True);
    EnterCriticalSection(GLoadLock);
    try
      if _miLoaded then Exit(True);
      // try load
      LLib := TryLoadMimallocLibrary;
      if not IsLibValid(LLib) then Exit(False);
      _miLib := LLib;
      platform_dl_sym(_miLib, 'mi_malloc', Pointer(_mi_malloc));
      platform_dl_sym(_miLib, 'mi_calloc', Pointer(_mi_calloc));
      platform_dl_sym(_miLib, 'mi_realloc', Pointer(_mi_realloc));
      platform_dl_sym(_miLib, 'mi_free', Pointer(_mi_free));
      platform_dl_sym(_miLib, 'mi_malloc_usable_size', Pointer(_mi_malloc_usable_size));
      _miLoaded := Assigned(_mi_malloc) and Assigned(_mi_calloc) and Assigned(_mi_realloc) and Assigned(_mi_free);
      if not _miLoaded then
      begin
        _mi_malloc_usable_size := nil;
        platform_dl_close(_miLib);
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

function MimallocUsableSizeAvailable: Boolean;
begin
  if not EnsureMimallocLoaded then
    Exit(False);
  {$IFDEF NEXTPAS_CORE_MIMALLOC_STATIC}
  Result := True;
  {$ELSE}
  Result := Assigned(_mi_malloc_usable_size);
  {$ENDIF}
end;

function TryGetMimallocUsableSize(aPtr: Pointer; out aSize: SizeUInt): Boolean;
begin
  aSize := 0;
  if aPtr = nil then
    Exit(False);
  if not MimallocUsableSizeAvailable then
    Exit(False);
  aSize := _mi_malloc_usable_size(aPtr);
  Result := True;
end;

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

function TMimallocAllocator.DoMemSize(aPtr: Pointer): SizeUInt;
begin
  if not TryGetMimallocUsableSize(aPtr, Result) then
    Result := 0;
end;

function TMimallocAllocator.Traits: TAllocatorTraits;
begin
  Result := inherited Traits;
  // mimalloc semantics:
  // - AllocMem uses mi_calloc => zero initialized; GetMem not guaranteed
  // - SupportsAligned remains False here (use aligned bridge or module)
  // - HasMemSize is true only when the optional usable-size symbol is present
  Result.ZeroInitialized := True;
  Result.SupportsAligned := False;
  Result.HasMemSize      := MimallocUsableSizeAvailable;
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
  {$IFNDEF NEXTPAS_CORE_MIMALLOC_STATIC}
  InitCriticalSection(GLoadLock);
  {$ENDIF}
  InitCriticalSection(GAllocatorLock);
finalization
  DoneCriticalSection(GAllocatorLock);
  {$IFNDEF NEXTPAS_CORE_MIMALLOC_STATIC}
  DoneCriticalSection(GLoadLock);
  {$ENDIF}
  _MimallocAllocatorIntf := nil;
  _MimallocAllocatorObj := nil;
  {$IFNDEF NEXTPAS_CORE_MIMALLOC_STATIC}
  if IsLibValid(_miLib) then
    platform_dl_close(_miLib);
  _mi_malloc := nil;
  _mi_calloc := nil;
  _mi_realloc := nil;
  _mi_free := nil;
  _mi_malloc_usable_size := nil;
  {$ENDIF}


end.
