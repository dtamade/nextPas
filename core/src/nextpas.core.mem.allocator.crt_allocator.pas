unit nextpas.core.mem.allocator.crt_allocator;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.mem.allocator.base;

type
  {**
   * TCrtAllocator
   * @desc 使用 C 运行时库 (CRT) 内存管理器实现的 IAllocator 具体类
   *}
  TCrtAllocator = class(TAllocator)
  protected
    function  DoGetMem(aSize: SizeUInt): Pointer; override;
    function  DoAllocMem(aSize: SizeUInt): Pointer; override;
    function  DoReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer; override;
    procedure DoFreeMem(aDst: Pointer); override;
  public
    function  Traits: TAllocatorTraits; override;
  end;

function GetCrtAllocator: IAllocator;
function TryGetCrtAllocator(out A: IAllocator): Boolean;

implementation

function  crt_malloc(aSize: SizeUInt): Pointer; cdecl external {$IFDEF MSWINDOWS}'msvcrt.dll'{$ELSE}'c'{$ENDIF} name 'malloc';
function  crt_calloc(aNum, aSize: SizeUInt): Pointer; cdecl external {$IFDEF MSWINDOWS}'msvcrt.dll'{$ELSE}'c'{$ENDIF} name 'calloc';
function  crt_realloc(aPtr: Pointer; aSize: SizeUInt): Pointer; cdecl external {$IFDEF MSWINDOWS}'msvcrt.dll'{$ELSE}'c'{$ENDIF} name 'realloc';
procedure crt_free(aPtr: Pointer); cdecl external {$IFDEF MSWINDOWS}'msvcrt.dll'{$ELSE}'c'{$ENDIF} name 'free';

var
  _CrtAllocatorObj: TAllocator = nil;
  _CrtAllocatorIntf: IAllocator = nil;
  GCrtAllocLock: TRTLCriticalSection;

function TCrtAllocator.DoGetMem(aSize: SizeUInt): Pointer;
begin
  Result := crt_malloc(aSize);
end;

function TCrtAllocator.DoAllocMem(aSize: SizeUInt): Pointer;
begin
  Result := crt_calloc(1, aSize);
end;

function TCrtAllocator.DoReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
begin
  Result := crt_realloc(aDst, aSize);
end;

procedure TCrtAllocator.DoFreeMem(aDst: Pointer);
begin
  crt_free(aDst);
end;

function TCrtAllocator.Traits: TAllocatorTraits;
begin
  Result := inherited Traits;
  // CRT semantics:
  // - AllocMem uses calloc path => zero initialized; GetMem not guaranteed
  // - No native aligned API exposed via this allocator
  // - No MemSize/usable_size available
  Result.ZeroInitialized := True;
  Result.SupportsAligned := False;
  Result.HasMemSize      := False;
end;

function GetCrtAllocator: IAllocator;
begin
  if _CrtAllocatorObj = nil then
  begin
    EnterCriticalSection(GCrtAllocLock);
    try
      if _CrtAllocatorObj = nil then
      begin
        _CrtAllocatorObj := TCrtAllocator.Create;
        _CrtAllocatorIntf := _CrtAllocatorObj as IAllocator; // anchor lifetime
      end;
    finally
      LeaveCriticalSection(GCrtAllocLock);
    end;
  end;
  Result := _CrtAllocatorIntf;
end;

function TryGetCrtAllocator(out A: IAllocator): Boolean;
begin
  try
    A := GetCrtAllocator;
    Result := True;
  except
    A := nil;
    Result := False;
  end;
end;

initialization
  InitCriticalSection(GCrtAllocLock);
finalization
  DoneCriticalSection(GCrtAllocLock);
  _CrtAllocatorIntf := nil;
  _CrtAllocatorObj := nil;

end.
