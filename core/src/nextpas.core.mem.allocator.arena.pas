unit nextpas.core.mem.allocator.arena;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.error,
  nextpas.core.mem.debug_wrap,
  nextpas.core.mem.arena.intf,
  nextpas.core.mem.arena.base,
  nextpas.core.base.utils,
  nextpas.core.mem.arena.virtual;

type
  {** TLocalArenaAllocator
   *
   *  Capacity-bounded IAllocator over TLocalArena.
   *  FreeMem is no-op; reclaim by dropping the interface (or Reset).
   *  CreateArenaAllocator factory uses this backend.
   *  Non-thread-safe.
   *}
  TLocalArenaAllocator = class(TInterfacedObject, IAllocator)
  private
    FArena: IArena;
  public
    constructor Create(ACapacity: SizeUInt); overload;
    constructor Create(const AArena: IArena); overload;

    function GetMem(ASize: SizeUInt): Pointer; inline;
    function AllocMem(ASize: SizeUInt): Pointer; inline;
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
    procedure FreeMem(APtr: Pointer); inline;
    function Traits: TAllocatorTraits; inline;

    procedure Reset;
    property Arena: IArena read FArena;
  end;

  {** TVirtualArenaAllocator
   *
   *  将 TVirtualArena 包装为 IAllocator 接口。
   *  分配通过 TVirtualArena 的 bump 指针完成，FreeMem 为 no-op。
   *  Reset 方法一次性释放所有内存。
   *
   *  注意：ReallocMem 不支持（arena 不跟踪单个分配大小）。
   *  非线程安全。}
  TVirtualArenaAllocator = class(TInterfacedObject, IAllocator)
  private
    FArena: TVirtualArena;
  public
    {** 创建 TVirtualArenaAllocator }
    constructor Create(AAlignment: SizeUInt = DEFAULT_ALIGNMENT);
    destructor Destroy; override;

    function GetMem(ASize: SizeUInt): Pointer; inline;
    function AllocMem(ASize: SizeUInt): Pointer; inline;
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
    procedure FreeMem(APtr: Pointer); inline;
    function Traits: TAllocatorTraits; inline;

    {** 重置 Arena（保留 mmap 映射，从头开始分配） }
    procedure Reset;

    {** 直接访问内部 TVirtualArena }
    property Arena: TVirtualArena read FArena;
  end;

{** 兼容性别名（VirtualArena 路径；容量边界请用 TLocalArenaAllocator） }
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
    function Stats: TArenaStats;

    {** 直接访问内部 TVirtualArena }
    property Arena: TVirtualArena read FArena;
  end;

implementation

uses
  nextpas.core.mem.arena.local;

{ TLocalArenaAllocator }

constructor TLocalArenaAllocator.Create(ACapacity: SizeUInt);
begin
  Create(TLocalArena.Create(ACapacity) as IArena);
end;

constructor TLocalArenaAllocator.Create(const AArena: IArena);
begin
  inherited Create;
  FArena := AArena;
end;

function TLocalArenaAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
begin
  if ASize = 0 then
    Exit(nil);
  Result := FArena.Alloc(ASize);
end;

function TLocalArenaAllocator.AllocMem(ASize: SizeUInt): Pointer; inline;
begin
  if ASize = 0 then
    Exit(nil);
  Result := FArena.AllocZeroed(ASize);
end;

function TLocalArenaAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
begin
  Result := nil;
  if (APtr = nil) and (ASize = 0) then
    Exit;
  raise EAllocError.Create(aeReallocNotSupported,
    FormatAllocErrorMsg('TLocalArenaAllocator', 'ReallocMem',
      'arena does not track individual allocation sizes'));
end;

procedure TLocalArenaAllocator.FreeMem(APtr: Pointer); inline;
begin
  if APtr = nil then
    Exit;
  { Default: no-op (arena owns the block). Opt-in ARENA_STRICT makes mix-ups loud. }
  if IsMemArenaStrictEnabled then
    raise EAllocError.Create(aeInvalidPointer,
      FormatAllocErrorMsg('TLocalArenaAllocator', 'FreeMem',
        'arena block; use Reset/RestoreToMark (ARENA_STRICT)'));
end;

procedure TLocalArenaAllocator.Reset;
begin
  FArena.Reset;
end;

function TLocalArenaAllocator.Traits: TAllocatorTraits; inline;
begin
  Result.ZeroInitialized := True;
  Result.ThreadSafe := False;
  Result.SupportsRealloc := False;
end;

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

function TVirtualArenaAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := FArena.Alloc(ASize);
end;

function TVirtualArenaAllocator.AllocMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := FArena.AllocZeroed(ASize);
end;

function TVirtualArenaAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
begin
  raise EAllocError.Create(aeReallocNotSupported,
    FormatAllocErrorMsg('TVirtualArenaAllocator', 'ReallocMem',
      'arena does not track individual allocation sizes'));
end;

procedure TVirtualArenaAllocator.FreeMem(APtr: Pointer); inline;
begin
  if APtr = nil then
    Exit;
  if IsMemArenaStrictEnabled then
    raise EAllocError.Create(aeInvalidPointer,
      FormatAllocErrorMsg('TVirtualArenaAllocator', 'FreeMem',
        'arena block; use Reset (ARENA_STRICT)'));
end;

procedure TVirtualArenaAllocator.Reset;
begin
  FArena.Reset;
end;

function TVirtualArenaAllocator.Traits: TAllocatorTraits; inline;
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

function TVirtualArenaAdapter.Stats: TArenaStats;
begin
  Result := FArena.Stats;
end;

end.
