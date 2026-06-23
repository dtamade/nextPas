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
    function DoGetMem(ASize: SizeUInt): Pointer; virtual; abstract;
    function DoAllocMem(ASize: SizeUInt): Pointer; virtual; abstract;
    function DoReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer; virtual; abstract;
    procedure DoFreeMem(ADst: Pointer); virtual; abstract;
    function DoMemSize(APtr: Pointer): SizeUInt; virtual;
  public
    function  GetMem(ASize: SizeUInt): Pointer; {$IFDEF NEXTPAS_CORE_INLINE}inline;{$ENDIF}
    function  AllocMem(ASize: SizeUInt): Pointer; {$IFDEF NEXTPAS_CORE_INLINE}inline;{$ENDIF}
    function  ReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer; {$IFDEF NEXTPAS_CORE_INLINE}inline;{$ENDIF}
    procedure FreeMem(ADst: Pointer); {$IFDEF NEXTPAS_CORE_INLINE}inline;{$ENDIF}
    function  MemSize(APtr: Pointer): SizeUInt; {$IFDEF NEXTPAS_CORE_INLINE}inline;{$ENDIF}
    // 对齐分配（默认回退实现，子类可覆盖为原生对齐）
    function  AllocAligned(ASize, AAlignment: SizeUInt): Pointer;
    procedure FreeAligned(APtr: Pointer);
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

function TAllocator.DoMemSize(APtr: Pointer): SizeUInt;
begin
  Result := 0;
end;

function TAllocator.MemSize(APtr: Pointer): SizeUInt;
begin
  if APtr = nil then
    Exit(0);
  Result := DoMemSize(APtr);
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
    raise EArgumentNil.Create('TAllocator.FreeMem: ADst cannot be nil.');
    {$ELSE}
    Exit;
    {$ENDIF}
  end;
  DoFreeMem(ADst);
end;

function TAllocator.AllocAligned(ASize, AAlignment: SizeUInt): Pointer;
var
  LRaw: Pointer;
  LAlignMask: SizeUInt;
  LExtra: SizeUInt;
  LNeeded: SizeUInt;
  LHeaderPtr: PPointer;
begin
  if ASize = 0 then Exit(nil);
  if (AAlignment < SizeOf(Pointer)) or (not IsPowerOfTwo(AAlignment)) then
    Exit(nil);
  // Over-allocate and store the original pointer just before the aligned block
  LAlignMask := AAlignment - 1;
  LExtra := LAlignMask + SizeOf(Pointer);
  if LExtra < LAlignMask then
    Exit(nil);
  LNeeded := ASize + LExtra;
  if LNeeded < ASize then
    Exit(nil);
  LRaw := GetMem(LNeeded);
  if LRaw = nil then Exit(nil);
  Result := AlignUpPtr(Pointer(PtrUInt(LRaw) + SizeOf(Pointer)), AAlignment);
  LHeaderPtr := PPointer(PtrUInt(Result) - SizeOf(Pointer));
  LHeaderPtr^ := LRaw;
end;

procedure TAllocator.FreeAligned(APtr: Pointer);
var
  LRaw: Pointer;
  LHeaderPtr: PPointer;
begin
  if APtr = nil then Exit;
  LHeaderPtr := PPointer(PtrUInt(APtr) - SizeOf(Pointer));
  LRaw := LHeaderPtr^;
  FreeMem(LRaw);
end;

{$POP}

end.
