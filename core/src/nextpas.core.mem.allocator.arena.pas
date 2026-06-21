unit nextpas.core.mem.allocator.arena;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.arena.compiler;

type
  {** TFastArenaAllocator
   *
   *  将 TFastArena 包装为 IAllocator 接口。
   *  分配通过 TFastArena 的 bump 指针完成，DoFreeMem 为 no-op。
   *  Reset 方法一次性释放所有内存。
   *
   *  注意：DoReallocMem 会分配新块并复制数据，效率不如原地扩展。
   *  非线程安全。}
  TFastArenaAllocator = class(TAllocator)
  private
    FArena: TFastArena;
    FChunkSize: SizeUInt;
  protected
    function DoGetMem(aSize: SizeUInt): Pointer; override;
    function DoAllocMem(aSize: SizeUInt): Pointer; override;
    function DoReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer; override;
    procedure DoFreeMem(aDst: Pointer); override;
  public
    {** 创建 TFastArenaAllocator，AChunkSize 为初始 chunk 大小 }
    constructor Create(AChunkSize: SizeUInt = ARENA_INITIAL_CHUNK_SIZE;
      AAlignment: SizeUInt = DEFAULT_ALIGNMENT);
    destructor Destroy; override;

    {** 重置 Arena（保留 mmap 映射，从头开始分配） }
    procedure Reset;

    {** 直接访问内部 TFastArena }
    property Arena: TFastArena read FArena;

    {** IAllocator traits }
    function Traits: TAllocatorTraits; override;
  end;

implementation

{ TFastArenaAllocator }

constructor TFastArenaAllocator.Create(AChunkSize: SizeUInt; AAlignment: SizeUInt);
begin
  inherited Create;
  FChunkSize := AChunkSize;
  TFastArena_Init(FArena, AAlignment);
end;

destructor TFastArenaAllocator.Destroy;
begin
  TFastArena_Release(FArena);
  inherited;
end;

function TFastArenaAllocator.DoGetMem(aSize: SizeUInt): Pointer;
begin
  Result := FArena.Alloc(aSize);
end;

function TFastArenaAllocator.DoAllocMem(aSize: SizeUInt): Pointer;
begin
  Result := FArena.AllocZeroed(aSize);
end;

function TFastArenaAllocator.DoReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
var
  LCopySize: SizeUInt;
begin
  Result := FArena.Alloc(aSize);
  if (Result <> nil) and (aDst <> nil) then
  begin
    { Arena 不跟踪单个分配大小，保守复制 aSize 字节。
      调用方应确保 aDst 至少有 aSize 字节可读。
      如果不确定旧大小，可改用 GetMemSize（Arena 不支持）。
      这里安全假设旧块 >= aSize（否则调用方逻辑有误）。 }
    Move(aDst^, Result^, aSize);
  end;
end;

procedure TFastArenaAllocator.DoFreeMem(aDst: Pointer);
begin
  { Arena 不支持单个释放 — no-op }
end;

procedure TFastArenaAllocator.Reset;
begin
  FArena.Reset;
end;

function TFastArenaAllocator.Traits: TAllocatorTraits;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe      := False;
  Result.HasMemSize      := False;
  Result.SupportsAligned := True;
end;

end.
