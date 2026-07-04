unit nextpas.core.mem.allocator.arena;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.error,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.arena.intf,
  nextpas.core.mem.arena.base,
  nextpas.core.base.utils,
  nextpas.core.mem.arena.virtual;

type
  {** TVirtualArenaAllocator
   *
   *  将 TVirtualArena 包装为 IAllocator 接口。
   *  分配通过 TVirtualArena 的 bump 指针完成，DoFreeMem 为 no-op。
   *  Reset 方法一次性释放所有内存。
   *
   *  注意：DoReallocMem 不支持（arena 不跟踪单个分配大小）。
   *  非线程安全。}
  TVirtualArenaAllocator = class(TAllocator)
  private
    FArena: TVirtualArena;
  protected
    function DoGetMem(ASize: SizeUInt): Pointer; override;
    function DoAllocMem(ASize: SizeUInt): Pointer; override;
    function DoReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer; override;
    procedure DoFreeMem(ADst: Pointer); override;
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

type
  {** TVirtualArenaAdapter
   *
   *  将 TVirtualArena record 包装为 IArena 接口。
   *  使 TVirtualArena 可用于需要 IArena 的多态场景
   *  （如 TArenaConcurrent、TFallbackArena）。
   *
   *  非线程安全。需要并发访问时用 TArenaConcurrent 包装。
   *}
  TVirtualArenaAdapter = class(TInterfacedObject, IArena)
  private
    FArena: TVirtualArena;
  public
    constructor Create(AAlignment: SizeUInt = DEFAULT_ALIGNMENT);
    destructor Destroy; override;

    { IArena }
    function Alloc(ASize: SizeUInt): Pointer;
    function AllocAligned(ASize, AAlign: SizeUInt): Pointer;
    function AllocZeroed(ASize: SizeUInt): Pointer;
    function SaveMark: TArenaMark;
    procedure RestoreToMark(AMark: TArenaMark);
    procedure Reset;
    function UsedSize: SizeUInt;
    function RemainingSize: SizeUInt;
    function Stats: TArenaStats;

    {** 直接访问内部 TVirtualArena }
    property Arena: TVirtualArena read FArena;
  end;

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
  inherited Destroy;
end;

function TVirtualArenaAllocator.DoGetMem(ASize: SizeUInt): Pointer;
begin
  Result := FArena.Alloc(ASize);
end;

function TVirtualArenaAllocator.DoAllocMem(ASize: SizeUInt): Pointer;
begin
  Result := FArena.AllocZeroed(ASize);
end;

function TVirtualArenaAllocator.DoReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer;
begin
  raise EAllocError.Create(aeReallocNotSupported,
    'TVirtualArenaAllocator.ReallocMem: arena does not track individual allocation sizes');
end;

procedure TVirtualArenaAllocator.DoFreeMem(ADst: Pointer);
begin
  { Arena 不支持单个释放 — no-op }
end;

procedure TVirtualArenaAllocator.Reset;
begin
  FArena.Reset;
end;

function TVirtualArenaAllocator.Traits: TAllocatorTraits;
begin
  Result.ZeroInitialized := True;
  Result.ThreadSafe      := False;
  Result.SupportsRealloc := False;
end;

{ TVirtualArenaAdapter }

constructor TVirtualArenaAdapter.Create(AAlignment: SizeUInt);
begin
  inherited Create;
  TVirtualArena_Init(FArena, AAlignment);
end;

destructor TVirtualArenaAdapter.Destroy;
begin
  TVirtualArena_Release(FArena);
  inherited Destroy;
end;

function TVirtualArenaAdapter.Alloc(ASize: SizeUInt): Pointer;
begin
  Result := FArena.Alloc(ASize);
end;

function TVirtualArenaAdapter.AllocAligned(ASize, AAlign: SizeUInt): Pointer;
begin
  Result := FArena.AllocAligned(ASize, AAlign);
end;

function TVirtualArenaAdapter.AllocZeroed(ASize: SizeUInt): Pointer;
begin
  Result := FArena.AllocZeroed(ASize);
end;

function TVirtualArenaAdapter.SaveMark: TArenaMark;
begin
  Result := FArena.SaveMark;
end;

procedure TVirtualArenaAdapter.RestoreToMark(AMark: TArenaMark);
begin
  FArena.RestoreToMark(AMark);
end;

procedure TVirtualArenaAdapter.Reset;
begin
  FArena.Reset;
end;

function TVirtualArenaAdapter.UsedSize: SizeUInt;
begin
  Result := FArena.TotalUsed;
end;

function TVirtualArenaAdapter.RemainingSize: SizeUInt;
var
  LTotal: SizeUInt;
begin
  LTotal := FArena.TotalAllocated;
  if LTotal > FArena.TotalUsed then
    Result := LTotal - FArena.TotalUsed
  else
    Result := 0;
end;

function TVirtualArenaAdapter.Stats: TArenaStats;
begin
  Result := FArena.Stats;
end;

end.
