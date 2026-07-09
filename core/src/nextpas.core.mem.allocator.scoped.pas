{******************************************************************************
  nextpas.core.mem.allocator.scoped — 作用域分配器

  核心设计:
    1. 包装任意 IAllocator，记录所有分配
    2. 析构时自动释放所有未释放的分配（RAII 风格）
    3. 支持 Reset 提前释放（不销毁分配器）
    4. 线程安全（原子计数 + 临界区保护分配记录）

  使用模式:
    var LScoped: TScopedAllocator;
    LScoped := TScopedAllocator.Create(DefaultAllocator);
    try
      LPtr := LScoped.GetMem(1024);
      // 不需要手动 FreeMem，析构时自动释放
    finally
      LScoped.Free;  // 自动释放所有分配
    end;

  性能目标:
    - GetMem/FreeMem 额外开销 < 20ns（记录指针到数组）
    - Reset: O(n) 遍历释放
******************************************************************************}
unit nextpas.core.mem.allocator.scoped;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.mutex;

type
  {** TScopedAllocator
   *
   *  作用域分配器：析构时自动释放所有未释放的分配。
   *  内部维护分配记录数组，FreeMem 时移除记录。
   *  析构时遍历剩余记录并释放。
   *}
  TScopedAllocator = class(TInterfacedObject, IAllocator)
  private
    FInner: IAllocator;
    FLock: TMemMutex;
    FPointers: array of Pointer;
    FCount: Integer;
    FActiveBytes: SizeUInt;
    procedure Track(APtr: Pointer);
    procedure Untrack(APtr: Pointer);
  public
    constructor Create(AInner: IAllocator);
    destructor Destroy; override;

    function GetMem(ASize: SizeUInt): Pointer; inline;
    function AllocMem(ASize: SizeUInt): Pointer; inline;
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
    procedure FreeMem(APtr: Pointer); inline;

    {** 提前释放所有已跟踪的分配（不销毁分配器） }
    procedure Reset;

    {** 当前跟踪的分配数 }
    function TrackedCount: Integer;
    {** 当前跟踪的总字节数（近似值） }
    function TrackedBytes: SizeUInt;

    function Traits: TAllocatorTraits; inline;
  end;

implementation

{ TScopedAllocator }

constructor TScopedAllocator.Create(AInner: IAllocator);
begin
  inherited Create;
  FInner := AInner;
  FLock.Init;
  FPointers := nil;
  FCount := 0;
  FActiveBytes := 0;
end;

destructor TScopedAllocator.Destroy;
begin
  Reset;
  FLock.Done;
  FInner := nil;
  inherited Destroy;
end;

procedure TScopedAllocator.Track(APtr: Pointer);
begin
  FLock.Acquire;
  try
    if FCount >= Length(FPointers) then
      SetLength(FPointers, FCount + 16);
    FPointers[FCount] := APtr;
    Inc(FCount);
  finally
    FLock.Release;
  end;
end;

procedure TScopedAllocator.Untrack(APtr: Pointer);
var
  LI, LJ: Integer;
begin
  FLock.Acquire;
  try
    for LI := 0 to FCount - 1 do
    begin
      if FPointers[LI] = APtr then
      begin
        for LJ := LI to FCount - 2 do
          FPointers[LJ] := FPointers[LJ + 1];
        Dec(FCount);
        FPointers[FCount] := nil;
        Break;
      end;
    end;
  finally
    FLock.Release;
  end;
end;

function TScopedAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := FInner.GetMem(ASize);
  if Result <> nil then
  begin
    Track(Result);
    InterlockedExchangeAdd64(FActiveBytes, Int64(ASize));
  end;
end;

function TScopedAllocator.AllocMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := FInner.AllocMem(ASize);
  if Result <> nil then
  begin
    Track(Result);
    InterlockedExchangeAdd64(FActiveBytes, Int64(ASize));
  end;
end;

function TScopedAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
begin
  // Realloc: 旧指针 untrack，新指针 track
  if APtr <> nil then
    Untrack(APtr);
  Result := FInner.ReallocMem(APtr, ASize);
  if Result <> nil then
    Track(Result);
end;

procedure TScopedAllocator.FreeMem(APtr: Pointer); inline;
begin
  if APtr <> nil then
    Untrack(APtr);
  FInner.FreeMem(APtr);
end;

procedure TScopedAllocator.Reset;
var
  LI: Integer;
begin
  FLock.Acquire;
  try
    // 从后往前释放（LIFO 顺序，对 arena 友好）
    for LI := FCount - 1 downto 0 do
      FInner.FreeMem(FPointers[LI]);
    FCount := 0;
    FActiveBytes := 0;
    FillChar(FPointers[0], Length(FPointers) * SizeOf(Pointer), 0);
  finally
    FLock.Release;
  end;
end;

function TScopedAllocator.TrackedCount: Integer;
begin
  FLock.Acquire;
  try
    Result := FCount;
  finally
    FLock.Release;
  end;
end;

function TScopedAllocator.TrackedBytes: SizeUInt;
begin
  Result := SizeUInt(FActiveBytes);
end;

function TScopedAllocator.Traits: TAllocatorTraits; inline;
begin
  Result := FInner.Traits;
end;

end.
