unit nextpas.core.mem.allocator.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.base,
  nextpas.core.mem.utils,
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
   * @desc 内存分配器的抽象基类，实现了 IAllocator 接口。
   *
   * 设计：
   * - 简单子类只需 override Do* 模板方法（DoGetMem/DoAllocMem/DoReallocMem/DoFreeMem）
   * - 基类 public 方法处理 nil/0 守卫后委托给 Do* 方法
   * - 包装型分配器可 override FreeMem(APtr, ASize) / ReallocMem(APtr, AOldSize, ANewSize)
   *   以插入跟踪/日志等逻辑
   *}
  TAllocator = class(TInterfacedObject, IAllocator)
  protected
    { Template methods — simple subclasses override these.
      The base class public methods (FreeMem, ReallocMem) handle nil/0 guards
      and delegate to these. }
    function DoGetMem(ASize: SizeUInt): Pointer; virtual; abstract;
    {** Default: DoGetMem + ZeroMem. Subclasses with native zero-fill (calloc, AllocMem)
        should override for efficiency. }
    function DoAllocMem(ASize: SizeUInt): Pointer; virtual;
    function DoReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer; virtual; abstract;
    procedure DoFreeMem(ADst: Pointer); virtual; abstract;
    function DoMemSize(APtr: Pointer): SizeUInt; virtual;
  public
    { === IAllocator 接口实现（1-param 签名） === }
    function  GetMem(ASize: SizeUInt): Pointer; {$IFDEF NEXTPAS_CORE_INLINE}inline;{$ENDIF}
    function  AllocMem(ASize: SizeUInt): Pointer; {$IFDEF NEXTPAS_CORE_INLINE}inline;{$ENDIF}
    function  ReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer; {$IFDEF NEXTPAS_CORE_INLINE}inline;{$ENDIF}
    procedure FreeMem(ADst: Pointer); {$IFDEF NEXTPAS_CORE_INLINE}inline;{$ENDIF}
    function  MemSize(APtr: Pointer): SizeUInt; {$IFDEF NEXTPAS_CORE_INLINE}inline;{$ENDIF}
    {** 2-参数 FreeMem。基类忽略 ASize，委托给 1-param FreeMem(APtr)。
        子类无需 override 此方法。 }
    procedure FreeMem(APtr: Pointer; ASize: SizeUInt);

    {** 3-参数 ReallocMem（含 nil/0 守卫）。委托给 DoReallocMem(APtr, ANewSize)。
        子类无需 override 此方法，只需实现 DoReallocMem。
        包装型分配器（如 TTrackingAllocator）可 override 以插入跟踪逻辑。 }
    function ReallocMem(APtr: Pointer; AOldSize, ANewSize: SizeUInt): Pointer; virtual;

    { === Batch API — 基类默认为循环调用，子类可 override 高性能版本 === }
    function BatchGetMem(ASize: SizeUInt; ACount: Word;
      ABlocks: PPointer): Word; virtual;
    procedure BatchFreeMem(ASize: SizeUInt; ACount: Word;
      ABlocks: PPointer); virtual;

    // 对齐分配（默认 over-allocate 实现，子类可覆盖为原生对齐）
    // 注意：覆盖 AllocAligned 的子类必须同时覆盖 FreeAligned
    function  AllocAligned(ASize, AAlignment: SizeUInt): Pointer; virtual;
    procedure FreeAligned(APtr: Pointer); virtual;
    function  Traits: TAllocatorTraits; virtual;
  end;

  {** Forward-looking alias. Use this in new code. }
  TMemAllocator = TAllocator;

implementation

{$PUSH}
{$WARN 4055 OFF} // pointer/ordinal conversions in aligned alloc helpers

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

function TAllocator.DoAllocMem(ASize: SizeUInt): Pointer;
begin
  Result := DoGetMem(ASize);
  if Result <> nil then
    FillChar(Result^, ASize, 0);
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

procedure TAllocator.FreeMem(APtr: Pointer; ASize: SizeUInt);
begin
  { ASize 被忽略 —— 委托给 1-param 路径，由 DoFreeMem 处理。 }
  FreeMem(APtr);
end;

function TAllocator.ReallocMem(APtr: Pointer; AOldSize, ANewSize: SizeUInt): Pointer;
begin
  { 含 nil/0 守卫。AOldSize 被忽略 —— 委托给 DoReallocMem(APtr, ANewSize)。 }
  if APtr = nil then
    Exit(GetMem(ANewSize));
  if ANewSize = 0 then
  begin
    FreeMem(APtr);
    Exit(nil);
  end;
  Result := DoReallocMem(APtr, ANewSize);
end;

{ --- Batch API 默认实现（循环调用） --- }

function TAllocator.BatchGetMem(ASize: SizeUInt; ACount: Word;
  ABlocks: PPointer): Word;
var
  I: Word;
  LPtr: PPointer;
begin
  Result := 0;
  LPtr := ABlocks;
  for I := 0 to ACount - 1 do
  begin
    LPtr^ := GetMem(ASize);
    if LPtr^ = nil then
      Break;
    Inc(Result);
    Inc(LPtr);
  end;
end;

procedure TAllocator.BatchFreeMem(ASize: SizeUInt; ACount: Word;
  ABlocks: PPointer);
var
  I: Word;
  LPtr: PPointer;
begin
  LPtr := ABlocks;
  for I := 0 to ACount - 1 do
  begin
    if LPtr^ <> nil then
      FreeMem(LPtr^, ASize);
    Inc(LPtr);
  end;
end;

{ --- 对齐分配（over-allocate 实现） --- }

function TAllocator.AllocAligned(ASize, AAlignment: SizeUInt): Pointer;
var
  LRaw: Pointer;
  LAlignMask: SizeUInt;
  LExtra: SizeUInt;
  LNeeded: SizeUInt;
  LHeaderPtr: PPointer;
begin
  if ASize = 0 then Exit(nil);
  if not ValidateAlignArg(AAlignment) then
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
  Result := AlignUpUnChecked(Pointer(PtrUInt(LRaw) + SizeOf(Pointer)), AAlignment);
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
