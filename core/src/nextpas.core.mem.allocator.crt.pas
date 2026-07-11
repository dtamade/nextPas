unit nextpas.core.mem.allocator.crt;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.intf,
  nextpas.core.errors;

type
  {**
   * TCrtAllocator
   * @desc 使用 C 运行时库 (CRT) 内存管理器实现的 IAllocator 具体类
   *}
  TCrtAllocator = class(TInterfacedObject, IAllocator)
  public

    function GetMem(ASize: SizeUInt): Pointer; inline;

    function AllocMem(ASize: SizeUInt): Pointer; inline;

    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;

    procedure FreeMem(APtr: Pointer); inline;
    function  Traits: TAllocatorTraits; inline;
  end;

function GetCrtAllocator: IAllocator;
function TryGetCrtAllocator(out A: IAllocator): Boolean;

implementation

uses
  nextpas.core.platform.sync;

function  crt_malloc(ASize: SizeUInt): Pointer; cdecl external {$IFDEF MSWINDOWS}'msvcrt.dll'{$ELSE}'c'{$ENDIF} name 'malloc';
function  crt_calloc(aNum, ASize: SizeUInt): Pointer; cdecl external {$IFDEF MSWINDOWS}'msvcrt.dll'{$ELSE}'c'{$ENDIF} name 'calloc';
function  crt_realloc(APtr: Pointer; ASize: SizeUInt): Pointer; cdecl external {$IFDEF MSWINDOWS}'msvcrt.dll'{$ELSE}'c'{$ENDIF} name 'realloc';
procedure crt_free(APtr: Pointer); cdecl external {$IFDEF MSWINDOWS}'msvcrt.dll'{$ELSE}'c'{$ENDIF} name 'free';

var
  _CrtAllocatorObj: TInterfacedObject = nil;
  _CrtAllocatorIntf: IAllocator = nil;
  GCrtAllocLock: TPlatformMutex;

function TCrtAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
begin
  if ASize = 0 then
    Exit(nil);
  Result := crt_malloc(ASize);
end;

function TCrtAllocator.AllocMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := crt_calloc(1, ASize);
end;

function TCrtAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
begin
  Result := crt_realloc(APtr, ASize);
end;

procedure TCrtAllocator.FreeMem(APtr: Pointer); inline;
begin
  crt_free(APtr);
end;

function TCrtAllocator.Traits: TAllocatorTraits; inline;
begin
  // CRT semantics:
  // - AllocMem uses calloc path => zero initialized; GetMem not guaranteed
  // - Standard CRT allocation entry points are thread-safe
  // - No native aligned API exposed via this allocator
  // - No MemSize/usable_size available
  Result.ZeroInitialized := True;
  Result.ThreadSafe := True;
  Result.SupportsRealloc := True;  // CRT realloc is supported via crt_realloc
end;

function GetCrtAllocator: IAllocator;
begin
  { GCrtAllocLock is TPlatformMutex — zero-initialized, no explicit Init needed.
    See allocator.rtl.pas for full rationale. }
  if _CrtAllocatorObj = nil then
  begin
    platform_mutex_lock(GCrtAllocLock);
    try
      if _CrtAllocatorObj = nil then
      begin
        _CrtAllocatorObj := TCrtAllocator.Create;
        _CrtAllocatorIntf := _CrtAllocatorObj as IAllocator; // anchor lifetime
      end;
    finally
      platform_mutex_unlock(GCrtAllocLock);
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

finalization
  _CrtAllocatorIntf := nil;
  _CrtAllocatorObj := nil;

end.
