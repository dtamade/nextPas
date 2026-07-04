unit nextpas.core.mem.allocator.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.base,
  nextpas.core.mem.utils,
  nextpas.core.mem.intf
  ;

type
  TAllocatorTraits = nextpas.core.mem.intf.TAllocatorTraits;
  IAllocator = nextpas.core.mem.intf.IAllocator;
  TMemAllocator = nextpas.core.mem.intf.IAllocator;

  {**
   * TAllocator
   *
   * @desc 内存分配器的抽象基类, 实现了 IAllocator 接口
   *}
  TAllocator = class(TInterfacedObject, IAllocator)
  protected
    function DoGetMem(ASize: SizeUInt): Pointer; virtual; abstract;
    function DoAllocMem(ASize: SizeUInt): Pointer; virtual; abstract;
    function DoReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer; virtual; abstract;
    procedure DoFreeMem(ADst: Pointer); virtual; abstract;
  public
    function  GetMem(ASize: SizeUInt): Pointer; {$IFDEF NEXTPAS_CORE_INLINE}inline;{$ENDIF}
    function  AllocMem(ASize: SizeUInt): Pointer; {$IFDEF NEXTPAS_CORE_INLINE}inline;{$ENDIF}
    function  ReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer; {$IFDEF NEXTPAS_CORE_INLINE}inline;{$ENDIF}
    procedure FreeMem(ADst: Pointer); {$IFDEF NEXTPAS_CORE_INLINE}inline;{$ENDIF}
    function  Traits: TAllocatorTraits; virtual;
  end;


implementation

{$PUSH}
{$WARN 4055 OFF} // pointer/ordinal conversions in aligned alloc helpers

function TAllocator.Traits: TAllocatorTraits;
begin
  // 基类缺省值：
  // - ThreadSafe=True: 大多数 RTL 分配器线程安全
  // - ZeroInitialized=False: GetMem 不保证零填充
  Result.ZeroInitialized := False;
  Result.ThreadSafe      := True;
  Result.SupportsRealloc := True;
end;

function TAllocator.GetMem(ASize: SizeUInt): Pointer;
begin
  if ASize = 0 then
    Exit(nil);
  Result := DoGetMem(ASize);
end;

function TAllocator.AllocMem(ASize: SizeUInt): Pointer;
begin
  if ASize = 0 then
    Exit(nil);
  Result := DoAllocMem(ASize);
end;

function TAllocator.ReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer;
begin
  if ASize = 0 then
  begin
    if ADst <> nil then
      DoFreeMem(ADst);
    Exit(nil);
  end;
  if ADst = nil then
    Exit(GetMem(ASize));
  Result := DoReallocMem(ADst, ASize);
end;

procedure TAllocator.FreeMem(ADst: Pointer);
begin
  if ADst = nil then
  begin
    {$IFDEF NEXTPAS_CORE_STRICT_NULL_FREE}
    Assert(False, 'TAllocator.FreeMem: ADst must not be nil');
    {$ELSE}
    Exit;
    {$ENDIF}
  end;
  DoFreeMem(ADst);
end;

{$POP}

end.
