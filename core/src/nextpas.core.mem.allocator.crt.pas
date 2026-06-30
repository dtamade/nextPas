unit nextpas.core.mem.allocator.crt;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.allocator.base;

type
  {**
   * TCrtAllocator
   * @desc 使用 C 运行时库 (CRT) 内存管理器实现的分配器。
   *       FreeMem/ASize 参数被忽略（CRT 通过 header 知道大小）。
   *}
  TCrtAllocator = class(TAllocator)
  protected
    function  DoGetMem(ASize: SizeUInt): Pointer; override;
    function  DoAllocMem(ASize: SizeUInt): Pointer; override;
    function  DoReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer; override;
    procedure DoFreeMem(ADst: Pointer); override;
  public
    function  Traits: TAllocatorTraits; override;
  end;

function GetCrtAllocator: TAllocator;
function TryGetCrtAllocator(out A: TAllocator): Boolean;

implementation

function  crt_malloc(ASize: SizeUInt): Pointer; cdecl external {$IFDEF MSWINDOWS}'msvcrt.dll'{$ELSE}'c'{$ENDIF} name 'malloc';
function  crt_calloc(aNum, ASize: SizeUInt): Pointer; cdecl external {$IFDEF MSWINDOWS}'msvcrt.dll'{$ELSE}'c'{$ENDIF} name 'calloc';
function  crt_realloc(APtr: Pointer; ASize: SizeUInt): Pointer; cdecl external {$IFDEF MSWINDOWS}'msvcrt.dll'{$ELSE}'c'{$ENDIF} name 'realloc';
procedure crt_free(APtr: Pointer); cdecl external {$IFDEF MSWINDOWS}'msvcrt.dll'{$ELSE}'c'{$ENDIF} name 'free';

var
  _CrtAllocatorObj: TCrtAllocator;
  _CrtAllocatorIntf: IAllocator;
  GCrtAllocLock: TRTLCriticalSection;

function TCrtAllocator.DoGetMem(ASize: SizeUInt): Pointer;
begin
  Result := crt_malloc(ASize);
end;

function TCrtAllocator.DoAllocMem(ASize: SizeUInt): Pointer;
begin
  Result := crt_calloc(1, ASize);
end;

function TCrtAllocator.DoReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer;
begin
  Result := crt_realloc(ADst, ASize);
end;

procedure TCrtAllocator.DoFreeMem(ADst: Pointer);
begin
  crt_free(ADst);
end;

function TCrtAllocator.Traits: TAllocatorTraits;
begin
  Result := inherited Traits;
  Result.ZeroInitialized := True;
end;

function GetCrtAllocator: TAllocator;
begin
  if _CrtAllocatorObj = nil then
  begin
    EnterCriticalSection(GCrtAllocLock);
    try
      if _CrtAllocatorObj = nil then
      begin
        _CrtAllocatorObj := TCrtAllocator.Create;
        _CrtAllocatorIntf := _CrtAllocatorObj as IAllocator;
      end;
    finally
      LeaveCriticalSection(GCrtAllocLock);
    end;
  end;
  Result := _CrtAllocatorObj;
end;

function TryGetCrtAllocator(out A: TAllocator): Boolean;
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
