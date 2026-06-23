unit nextpas.core.mem.allocator.arena;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.base.utils,
  nextpas.core.mem.arena.virtual;

type
  {** TVirtualArenaAllocator
   *
   *  将 TVirtualArena 包装为 IAllocator 接口。
   *  分配通过 TVirtualArena 的 bump 指针完成，DoFreeMem 为 no-op。
   *  Reset 方法一次性释放所有内存。
   *
   *  注意：DoReallocMem 会分配新块并复制数据，效率不如原地扩展。
   *  非线程安全。}
  TVirtualArenaAllocator = class(TAllocator)
  private
    FArena: TVirtualArena;
  protected
    function DoGetMem(aSize: SizeUInt): Pointer; override;
    function DoAllocMem(aSize: SizeUInt): Pointer; override;
    function DoReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer; override;
    procedure DoFreeMem(aDst: Pointer); override;
  public
    {** 创建 TVirtualArenaAllocator }
    constructor Create(AAlignment: SizeUInt = DEFAULT_ALIGNMENT);
    destructor Destroy; override;

    {** 重置 Arena（保留 mmap 映射，从头开始分配） }
    procedure Reset;

    {** 直接访问内部 TVirtualArena }
    property Arena: TVirtualArena read FArena;

    {** IAllocator traits }
    function Traits: TAllocatorTraits; override;
  end;

{** 兼容性别名 }
TFastArenaAllocator = TVirtualArenaAllocator;

implementation

{ TVirtualArenaAllocator }

constructor TVirtualArenaAllocator.Create(AAlignment: SizeUInt);
begin
  inherited Create;
  TVirtualArena_Init(FArena, AAlignment);
end;

destructor TVirtualArenaAllocator.Destroy;
begin
  TVirtualArena_Release(FArena);
  inherited;
end;

function TVirtualArenaAllocator.DoGetMem(aSize: SizeUInt): Pointer;
begin
  Result := FArena.Alloc(aSize);
end;

function TVirtualArenaAllocator.DoAllocMem(aSize: SizeUInt): Pointer;
begin
  Result := FArena.AllocZeroed(aSize);
end;

function TVirtualArenaAllocator.DoReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
begin
  Result := FArena.Alloc(aSize);
  if (Result <> nil) and (aDst <> nil) then
  begin
    { Arena 不跟踪单个分配大小，保守复制 aSize 字节。 }
    CopyMem(Result, aDst, aSize);
  end;
end;

procedure TVirtualArenaAllocator.DoFreeMem(aDst: Pointer);
begin
  { Arena 不支持单个释放 — no-op }
end;

procedure TVirtualArenaAllocator.Reset;
begin
  FArena.Reset;
end;

function TVirtualArenaAllocator.Traits: TAllocatorTraits;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe      := False;
  Result.HasMemSize      := False;
  Result.SupportsAligned := True;
end;

end.
