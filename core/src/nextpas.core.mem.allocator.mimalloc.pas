unit nextpas.core.mem.allocator.mimalloc;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.intf,
  nextpas.core.errors
  {$IFNDEF NEXTPAS_CORE_MIMALLOC_STATIC}
  ,nextpas.core.mem.allocator.mimalloc.loader
  ,nextpas.core.platform.dl
  {$ENDIF}
  ;

type
  {**
   * TMimallocAllocator
   * @desc 使用 mimalloc 库的 IAllocator 实现
   *}
  TMimallocAllocator = class(TInterfacedObject, IAllocator)
  public

    function GetMem(ASize: SizeUInt): Pointer; inline;

    function AllocMem(ASize: SizeUInt): Pointer; inline;

    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;

    procedure FreeMem(APtr: Pointer); inline;
    {** 查询 mimalloc 分配的实际可用大小（独立方法，非 IAllocator 接口） }
    function  UsableSize(APtr: Pointer): SizeUInt;
    function  Traits: TAllocatorTraits; inline;
  end;

function TryGetMimallocAllocator(out A: IAllocator): Boolean;
function GetMimallocAllocator: IAllocator;
function MimallocUsableSizeAvailable: Boolean;
function TryGetMimallocUsableSize(APtr: Pointer; out ASize: SizeUInt): Boolean;

implementation

uses
  nextpas.core.mem.error,
  nextpas.core.platform.sync;

{$IFDEF NEXTPAS_CORE_MIMALLOC_STATIC}
  {$LINKLIB mimalloc}
  {$IFDEF UNIX}
    {$LINKLIB c}
  {$ENDIF}
  // Static link/import: bind directly at link time
  function _mi_malloc(ASize: SizeUInt): Pointer; cdecl; external name 'mi_malloc';
  function _mi_calloc(aCount, ASize: SizeUInt): Pointer; cdecl; external name 'mi_calloc';
  function _mi_realloc(APtr: Pointer; aNewSize: SizeUInt): Pointer; cdecl; external name 'mi_realloc';
  procedure _mi_free(APtr: Pointer); cdecl; external name 'mi_free';
  function _mi_malloc_usable_size(APtr: Pointer): SizeUInt; cdecl; external name 'mi_malloc_usable_size';
  function EnsureMimallocLoaded: Boolean; inline;
  begin
    Result := True;
  end;
{$ELSE}
  // Delayed loading of mimalloc to avoid loader-time failures
  var
    _miLib: TPlatformLibrary;
    _miLoaded: Boolean = False;
    _mi_malloc: function(ASize: SizeUInt): Pointer; cdecl = nil;
    _mi_calloc: function(aCount, ASize: SizeUInt): Pointer; cdecl = nil;
    _mi_realloc: function(APtr: Pointer; aNewSize: SizeUInt): Pointer; cdecl = nil;
    _mi_free: procedure(APtr: Pointer); cdecl = nil;
    _mi_malloc_usable_size: function(APtr: Pointer): SizeUInt; cdecl = nil;
    GLoadLock: TPlatformMutex;

  function IsLibValid(const ALib: TPlatformLibrary): Boolean; inline;
  begin
    {$IFDEF NEXTPAS_WINDOWS}
    Result := ALib.Handle <> 0;
    {$ELSE}
    Result := ALib.Handle <> nil;
    {$ENDIF}
  end;

  function EnsureMimallocLoaded: Boolean;
  var
    LLib: TPlatformLibrary;
  begin
    if _miLoaded then Exit(True);
    platform_mutex_lock(GLoadLock);
    try
      if _miLoaded then Exit(True);
      if not TryLoadMimallocLibrary(LLib) then
        Exit(False);
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
      platform_mutex_unlock(GLoadLock);
    end;
  end;
{$ENDIF}

var
  _MimallocAllocatorObj: TInterfacedObject = nil;
  _MimallocAllocatorIntf: IAllocator = nil;
  GAllocatorLock: TPlatformMutex;

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

function TryGetMimallocUsableSize(APtr: Pointer; out ASize: SizeUInt): Boolean;
begin
  ASize := 0;
  if APtr = nil then
    Exit(False);
  if not MimallocUsableSizeAvailable then
    Exit(False);
  ASize := _mi_malloc_usable_size(APtr);
  Result := True;
end;

function TMimallocAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
begin
  if not EnsureMimallocLoaded then
    raise EAllocError.Create(aeInternalError, 'mimalloc not available: cannot load library');
  Result := _mi_malloc(ASize);
end;

function TMimallocAllocator.AllocMem(ASize: SizeUInt): Pointer; inline;
begin
  if not EnsureMimallocLoaded then
    raise EAllocError.Create(aeInternalError, 'mimalloc not available: cannot load library');
  Result := _mi_calloc(1, ASize);
end;

function TMimallocAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
begin
  if not EnsureMimallocLoaded then
    raise EAllocError.Create(aeInternalError, 'mimalloc not available: cannot load library');
  Result := _mi_realloc(APtr, ASize);
end;

procedure TMimallocAllocator.FreeMem(APtr: Pointer); inline;
begin
  if not EnsureMimallocLoaded then
    raise EAllocError.Create(aeInternalError,
      'TMimallocAllocator.FreeMem: mimalloc library unavailable (was previously loaded)');
  _mi_free(APtr);
end;

function TMimallocAllocator.UsableSize(APtr: Pointer): SizeUInt;
begin
  if not TryGetMimallocUsableSize(APtr, Result) then
    Result := 0;
end;

function TMimallocAllocator.Traits: TAllocatorTraits; inline;
begin
  Result.ZeroInitialized := True;
  Result.ThreadSafe := True;
  Result.SupportsRealloc := True;
end;

function GetMimallocAllocator: IAllocator;
begin
  if _MimallocAllocatorObj = nil then
  begin
    platform_mutex_lock(GAllocatorLock);
    try
      if _MimallocAllocatorObj = nil then
      begin
        _MimallocAllocatorObj := TMimallocAllocator.Create;
        _MimallocAllocatorIntf := _MimallocAllocatorObj as IAllocator; // anchor lifetime
      end;
    finally
      platform_mutex_unlock(GAllocatorLock);
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

finalization
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
