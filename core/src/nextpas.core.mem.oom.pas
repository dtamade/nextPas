{******************************************************************************
  nextpas.core.mem.oom — OOM 回调处理器

  核心设计:
    1. 注册链：多个 handler 按注册顺序调用
    2. 每个 handler 可释放缓存/GC/降级策略，返回 ARetry=True 表示重试
    3. 线程安全（临界区保护注册表）
    4. 可包装任意 IAllocator，分配失败时自动触发 handler 链

  使用模式:
    var LOom: TOomHandler;
    LOom := TOomHandler.Create;
    LOom.Register(MyOomCallback);
    // 作为 allocator 使用
    LPtr := LOom.GetMem(1024);  // 失败时自动触发 handler 链

  性能目标:
    - 成功路径：零额外开销（不经过 OOM handler）
    - 失败路径：遍历 handler 链，最多重试一次
******************************************************************************}
unit nextpas.core.mem.oom;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.mutex;

type
  {** OOM 事件回调
   *  ARequestedSize: 请求分配的字节数
   *  ARetry: 设为 True 表示应重试分配 }
  TOomEvent = procedure(ARequestedSize: SizeUInt; var ARetry: Boolean);

  {** TOomHandler
   *
   *  OOM 回调处理器链。当分配失败时，按注册顺序调用所有 handler。
   *  任一 handler 返回 ARetry=True 则重试分配。
   *  线程安全。
   *}
  TOomHandler = class
  private
    FLock: TMemMutex;
    FHandlers: array of TOomEvent;
    FCount: Integer;
  public
    constructor Create;
    destructor Destroy; override;

    {** 注册 OOM handler }
    procedure Register(AHandler: TOomEvent);
    {** 注销 OOM handler }
    procedure Unregister(AHandler: TOomEvent);

    {** 尝试处理 OOM：遍历 handler 链，返回 True 表示应重试 }
    function TryHandle(ARequestedSize: SizeUInt): Boolean;
    {** 已注册 handler 数量 }
    function Count: Integer;
  end;

  {** TOomAllocator
   *
   *  包装任意 IAllocator，分配失败时触发 OOM handler 链。
   *  成功路径零额外开销（直接委托内部分配器）。
   *}
  TOomAllocator = class(TAllocator)
  private
    FInner: IAllocator;
    FOomHandler: TOomHandler;
  protected
    function DoGetMem(ASize: SizeUInt): Pointer; override;
    function DoAllocMem(ASize: SizeUInt): Pointer; override;
    function DoReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; override;
    procedure DoFreeMem(APtr: Pointer); override;
  public
    constructor Create(AInner: IAllocator; AOomHandler: TOomHandler);
    destructor Destroy; override;

    property OomHandler: TOomHandler read FOomHandler;
    function Traits: TAllocatorTraits; override;
  end;

implementation

{ TOomHandler }

constructor TOomHandler.Create;
begin
  inherited Create;
  FLock.Init;
  FHandlers := nil;
  FCount := 0;
end;

destructor TOomHandler.Destroy;
begin
  FLock.Done;
  FHandlers := nil;
  inherited Destroy;
end;

procedure TOomHandler.Register(AHandler: TOomEvent);
begin
  FLock.Acquire;
  try
    if FCount >= Length(FHandlers) then
      SetLength(FHandlers, FCount + 8);
    FHandlers[FCount] := AHandler;
    Inc(FCount);
  finally
    FLock.Release;
  end;
end;

procedure TOomHandler.Unregister(AHandler: TOomEvent);
var
  LI, LJ: Integer;
begin
  FLock.Acquire;
  try
    for LI := 0 to FCount - 1 do
    begin
      if Pointer(FHandlers[LI]) = Pointer(AHandler) then
      begin
        for LJ := LI to FCount - 2 do
          FHandlers[LJ] := FHandlers[LJ + 1];
        Dec(FCount);
        FHandlers[FCount] := nil;
        Break;
      end;
    end;
  finally
    FLock.Release;
  end;
end;

function TOomHandler.TryHandle(ARequestedSize: SizeUInt): Boolean;
var
  LI: Integer;
  LRetry: Boolean;
begin
  Result := False;
  FLock.Acquire;
  try
    for LI := 0 to FCount - 1 do
    begin
      LRetry := False;
      FHandlers[LI](ARequestedSize, LRetry);
      if LRetry then
      begin
        Result := True;
        Break;
      end;
    end;
  finally
    FLock.Release;
  end;
end;

function TOomHandler.Count: Integer;
begin
  FLock.Acquire;
  try
    Result := FCount;
  finally
    FLock.Release;
  end;
end;

{ TOomAllocator }

constructor TOomAllocator.Create(AInner: IAllocator; AOomHandler: TOomHandler);
begin
  inherited Create;
  FInner := AInner;
  FOomHandler := AOomHandler;
end;

destructor TOomAllocator.Destroy;
begin
  FInner := nil;
  FOomHandler := nil;
  inherited Destroy;
end;

function TOomAllocator.DoGetMem(ASize: SizeUInt): Pointer;
begin
  Result := FInner.GetMem(ASize);
  // 分配失败时触发 OOM handler 链，最多重试一次
  if (Result = nil) and (ASize > 0) and FOomHandler.TryHandle(ASize) then
    Result := FInner.GetMem(ASize);
end;

function TOomAllocator.DoAllocMem(ASize: SizeUInt): Pointer;
begin
  Result := FInner.AllocMem(ASize);
  if (Result = nil) and (ASize > 0) and FOomHandler.TryHandle(ASize) then
    Result := FInner.AllocMem(ASize);
end;

function TOomAllocator.DoReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
begin
  Result := FInner.ReallocMem(APtr, ASize);
  if (Result = nil) and (ASize > 0) and FOomHandler.TryHandle(ASize) then
    Result := FInner.ReallocMem(APtr, ASize);
end;

procedure TOomAllocator.DoFreeMem(APtr: Pointer);
begin
  FInner.FreeMem(APtr);
end;

function TOomAllocator.Traits: TAllocatorTraits;
begin
  Result := FInner.Traits;
end;

end.
