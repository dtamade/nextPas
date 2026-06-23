unit nextpas.core.mem.allocator.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.base,
  nextpas.core.mem.intf
  {$IFDEF NEXTPAS_CORE_STRICT_NULL_FREE}
  , nextpas.core.base
  {$ENDIF}
  ;

type
  TAllocatorTraits = nextpas.core.mem.intf.TAllocatorTraits;
  IAllocator = nextpas.core.mem.intf.IAllocator;

  {**
   * TAllocator
   *
   * @desc 内存分配器的抽象基类, 实现了 IAllocator 接口
   *}
  TAllocator = class(TInterfacedObject, IAllocator)
  protected
    function DoGetMem(aSize: SizeUInt): Pointer; virtual; abstract;
    function DoAllocMem(aSize: SizeUInt): Pointer; virtual; abstract;
    function DoReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer; virtual; abstract;
    procedure DoFreeMem(aDst: Pointer); virtual; abstract;
    function DoMemSize(aPtr: Pointer): SizeUInt; virtual;
  public
    function  GetMem(aSize: SizeUInt): Pointer; {$IFDEF NEXTPAS_CORE_INLINE}inline;{$ENDIF}
    function  AllocMem(aSize: SizeUInt): Pointer; {$IFDEF NEXTPAS_CORE_INLINE}inline;{$ENDIF}
    function  ReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer; {$IFDEF NEXTPAS_CORE_INLINE}inline;{$ENDIF}
    procedure FreeMem(aDst: Pointer); {$IFDEF NEXTPAS_CORE_INLINE}inline;{$ENDIF}
    function  MemSize(aPtr: Pointer): SizeUInt; {$IFDEF NEXTPAS_CORE_INLINE}inline;{$ENDIF}
    // 对齐分配（默认回退实现，子类可覆盖为原生对齐）
    function  AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
    procedure FreeAligned(aPtr: Pointer);
    function  Traits: TAllocatorTraits; virtual;
  end;


implementation

{$PUSH}
{$WARN 4055 OFF} // pointer/ordinal conversions in aligned alloc helpers

function AlignUpPtr(P: Pointer; AAlignment: SizeUInt): Pointer; inline;
var
  LAddr, LMask: PtrUInt;
begin
  LAddr := PtrUInt(P);
  LMask := PtrUInt(AAlignment - 1);
  Result := Pointer((LAddr + LMask) and not LMask);
end;

function TAllocator.Traits: TAllocatorTraits;
begin
  // 基类缺省值：
  // - ThreadSafe=True: 大多数 RTL 分配器线程安全
  // - ZeroInitialized=False: GetMem 不保证零填充
  // - HasMemSize=False: 不支持查询块大小
  // - SupportsAligned=False: 通过 over-allocate 模拟
  Result.ZeroInitialized := False;
  Result.ThreadSafe      := True;
  Result.HasMemSize      := False;
  Result.SupportsAligned := False;
end;

function TAllocator.DoMemSize(aPtr: Pointer): SizeUInt;
begin
  Result := 0;
end;

function TAllocator.MemSize(aPtr: Pointer): SizeUInt;
begin
  if aPtr = nil then
    Exit(0);
  Result := DoMemSize(aPtr);
end;

function TAllocator.GetMem(aSize: SizeUInt): Pointer;
begin
  if aSize = 0 then
    Exit(nil);
  Result := DoGetMem(aSize);
end;

function TAllocator.AllocMem(aSize: SizeUInt): Pointer;
begin
  if aSize = 0 then
    Exit(nil);
  Result := DoAllocMem(aSize);
end;

function TAllocator.ReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
begin
  if aSize = 0 then
  begin
    if aDst <> nil then
      DoFreeMem(aDst);
    Exit(nil);
  end;
  if aDst = nil then
    Exit(GetMem(aSize));
  Result := DoReallocMem(aDst, aSize);
end;

procedure TAllocator.FreeMem(aDst: Pointer);
begin
  if aDst = nil then
  begin
    {$IFDEF NEXTPAS_CORE_STRICT_NULL_FREE}
    raise EArgumentNil.Create('TAllocator.FreeMem: aDst cannot be nil.');
    {$ELSE}
    Exit;
    {$ENDIF}
  end;
  DoFreeMem(aDst);
end;

function TAllocator.AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
var
  LRaw: Pointer;
  LAlignMask: SizeUInt;
  LExtra: SizeUInt;
  LNeeded: SizeUInt;
  LHeaderPtr: PPointer;
begin
  if aSize = 0 then Exit(nil);
  if (aAlignment < SizeOf(Pointer)) or (not IsPowerOfTwo(aAlignment)) then
    Exit(nil);
  // Over-allocate and store the original pointer just before the aligned block
  LAlignMask := aAlignment - 1;
  LExtra := LAlignMask + SizeOf(Pointer);
  if LExtra < LAlignMask then
    Exit(nil);
  LNeeded := aSize + LExtra;
  if LNeeded < aSize then
    Exit(nil);
  LRaw := GetMem(LNeeded);
  if LRaw = nil then Exit(nil);
  Result := AlignUpPtr(Pointer(PtrUInt(LRaw) + SizeOf(Pointer)), aAlignment);
  LHeaderPtr := PPointer(PtrUInt(Result) - SizeOf(Pointer));
  LHeaderPtr^ := LRaw;
end;

procedure TAllocator.FreeAligned(aPtr: Pointer);
var
  LRaw: Pointer;
  LHeaderPtr: PPointer;
begin
  if aPtr = nil then Exit;
  LHeaderPtr := PPointer(PtrUInt(aPtr) - SizeOf(Pointer));
  LRaw := LHeaderPtr^;
  FreeMem(LRaw);
end;

{$POP}

end.
