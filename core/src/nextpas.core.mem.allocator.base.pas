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
   * Phase 0: 保留 IAllocator 接口兼容。新增 2-参数 FreeMem 和 3-参数 ReallocMem
   *          作为虚方法（默认实现委托给 Do* 模板方法）。
   *          Phase 1 将子类迁移到直接 override 新签名。
   *          Phase 6 删除 Do* 模板方法和旧签名。
   *}
  TAllocator = class(TInterfacedObject, IAllocator)
  protected
    { Template methods — subclasses override these (Phase 0-1 only).
      Phase 1 will migrate subclasses to override the new public signatures directly.
      Phase 6 will remove these. }
    function DoGetMem(ASize: SizeUInt): Pointer; virtual; abstract;
    function DoAllocMem(ASize: SizeUInt): Pointer; virtual; abstract;
    function DoReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer; virtual; abstract;
    procedure DoFreeMem(ADst: Pointer); virtual; abstract;
    function DoMemSize(APtr: Pointer): SizeUInt; virtual;
  public
    { === 旧签名（Phase 0: 实现 IAllocator 接口。Phase 6: 删除） === }
    function  GetMem(ASize: SizeUInt): Pointer; {$IFDEF NEXTPAS_CORE_INLINE}inline;{$ENDIF}
    function  AllocMem(ASize: SizeUInt): Pointer; {$IFDEF NEXTPAS_CORE_INLINE}inline;{$ENDIF}
    function  ReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer; {$IFDEF NEXTPAS_CORE_INLINE}inline;{$ENDIF}
    procedure FreeMem(ADst: Pointer); {$IFDEF NEXTPAS_CORE_INLINE}inline;{$ENDIF}
    function  MemSize(APtr: Pointer): SizeUInt; {$IFDEF NEXTPAS_CORE_INLINE}inline;{$ENDIF}

    { === 新签名（Phase 0: 虚方法，子类可选 override。Phase 1: 成为 abstract 主路径） === }
    {** 2-参数 FreeMem。Phase 0 默认实现忽略 ASize，委托给 DoFreeMem(APtr)。
        Phase 1 子类 override 后成为主路径，DoFreeMem 废弃。 }
    procedure FreeMem(APtr: Pointer; ASize: SizeUInt); virtual;

    {** 3-参数 ReallocMem。Phase 0 默认实现忽略 AOldSize，委托给 DoReallocMem(APtr, ANewSize)。
        Phase 1 子类 override 后成为主路径，DoReallocMem 废弃。 }
    function ReallocMem(APtr: Pointer; AOldSize, ANewSize: SizeUInt): Pointer; virtual;

    { === Batch API — 基类默认为循环调用，子类可 override 高性能版本 === }
    function BatchGetMem(ASize: SizeUInt; ACount: Word;
      ABlocks: PPointer): Word; virtual;
    procedure BatchFreeMem(ASize: SizeUInt; ACount: Word;
      ABlocks: PPointer); virtual;

    // 对齐分配（默认 over-allocate 实现，子类可覆盖为原生对齐）
    // 注意：覆盖 AllocAligned 的子类必须同时覆盖 FreeAligned
    function  AllocAligned(ASize, AAlignment: SizeUInt): Pointer;
    procedure FreeAligned(APtr: Pointer);
    function  Traits: TAllocatorTraits; virtual;
  end;

  {** Forward-looking alias. Use this in new code.
      Phase 6 will redefine this as the standalone base class. }
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

{ --- 新签名默认实现 (Phase 0) --- }

procedure TAllocator.FreeMem(APtr: Pointer; ASize: SizeUInt);
begin
  { Phase 0: 委托给旧 1-参数路径。ASize 被忽略。
    Phase 1: 子类 override 后直接用 ASize 做 size class lookup。 }
  FreeMem(APtr);
end;

function TAllocator.ReallocMem(APtr: Pointer; AOldSize, ANewSize: SizeUInt): Pointer;
begin
  { Phase 0: 委托给旧 2-参数路径。AOldSize 被忽略。
    Phase 1: 子类 override 后用 AOldSize 做 same-class check。 }
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
begin
  Result := 0;
  for I := 0 to ACount - 1 do
  begin
    PPointer(PByte(ABlocks) + I * SizeOf(Pointer))^ := GetMem(ASize);
    if PPointer(PByte(ABlocks) + I * SizeOf(Pointer))^ = nil then
      Break;
    Inc(Result);
  end;
end;

procedure TAllocator.BatchFreeMem(ASize: SizeUInt; ACount: Word;
  ABlocks: PPointer);
var
  I: Word;
  LPtr: Pointer;
begin
  for I := 0 to ACount - 1 do
  begin
    LPtr := PPointer(PByte(ABlocks) + I * SizeOf(Pointer))^;
    if LPtr <> nil then
      FreeMem(LPtr, ASize);
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
