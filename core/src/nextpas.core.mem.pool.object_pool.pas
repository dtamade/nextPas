unit nextpas.core.mem.pool.object_pool;

{$I nextpas.core.settings.inc}

{**
 * @desc 对象池实现（P0-1 修复版本）
 *
 * @changes
 *   - ✅ P0-1: 修复 GUID 冲突（IObjectPool 使用独立 GUID）
 *   - ✅ P0-1: 修复回调存储（使用值语义，不保存栈参数地址）
 *   - ✅ P0-1: 修复计数语义（分离 InPoolCount/TotalCreated/MaxSize）
 *}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.rtl_allocator,
  nextpas.core.mem.pool;

type

  {** IObjectPool 独立 GUID（不与 IPool 冲突）*}
  generic IObjectPool<T: TObject> = interface(IPool)
  ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']  // ✅ P0-1: 新 GUID
    function  AcquireObject(out aObject: T): Boolean;
    procedure ReleaseObject(aObject: T);
  end;

  {**
   * TObjectPool<T>
   *
   * @desc
   *   泛型对象池，用于管理可重用对象的生命周期，减少频繁创建/销毁对象的开销。
   *   Generic object pool for managing reusable object lifecycles, reducing overhead from frequent creation/destruction.
   *
   * @usage
   *   适用于需要频繁创建和销毁相同类型对象的场景，如数据库连接池、线程池、消息对象池等。
   *   Ideal for scenarios requiring frequent creation/destruction of same-type objects like DB connection pools, thread pools, message object pools.
   *
   * @features
   *   - 自动对象管理：自动创建、初始化和终结对象
   *   - Builder 模式配置：使用 TConfig 简化配置
   *   - 生命周期回调：支持自定义创建、初始化和终结逻辑
   *   - 容量控制：可配置最大对象数量
   *   - 统计信息：跟踪总创建数和池中可用数
   *   - P0-1 修复：修复了 GUID 冲突、回调存储和计数语义问题
   *
   * @thread_safety
   *   不是线程安全的。多线程环境请使用外部同步或实现线程安全包装器。
   *   Not thread-safe. Use external synchronization or implement thread-safe wrapper for multi-threaded scenarios.
   *
   * @example
   *   // 定义可重用对象
   *   type
   *     TConnection = class
   *       Host: string;
   *       Port: Integer;
   *       procedure Connect;
   *       procedure Disconnect;
   *     end;
   *
   *   // 创建对象池（使用 Builder 模式）
   *   var Pool: specialize TObjectPool<TConnection>;
   *   Pool := specialize TObjectPool<TConnection>.Create(
   *     specialize TObjectPool<TConnection>.TConfig.Default
   *       .WithMaxSize(10)
   *       .WithCreator(
   *         function: TConnection
   *         begin
   *           Result := TConnection.Create;
   *         end)
   *       .WithInit(
   *         procedure(Conn: TConnection)
   *         begin
   *           Conn.Connect;
   *         end)
   *       .WithFinalize(
   *         procedure(Conn: TConnection)
   *         begin
   *           Conn.Disconnect;
   *         end)
   *   );
   *   try
   *     // 获取对象
   *     var Conn: TConnection;
   *     if Pool.AcquireObject(Conn) then
   *     begin
   *       try
   *         // 使用连接...
   *       finally
   *         Pool.ReleaseObject(Conn);
   *       end;
   *     end;
   *   finally
   *     Pool.Free;
   *   end;
   *
   * @performance
   *   - 获取：O(1) 从池中获取，O(1) 创建新对象（如果池为空）
   *   - 释放：O(1) 返回到池中
   *   - 内存开销：每个对象约 8 字节（指针）+ 对象本身大小
   *
   * @use_cases
   *   - 数据库连接池：管理数据库连接的重用
   *   - HTTP 客户端池：重用 HTTP 客户端对象
   *   - 缓冲区池：管理字节缓冲区的重用
   *   - 工作线程池：管理工作线程对象
   *
   * @see TConfig, IObjectPool, IPool, TFixedPool
   *}
  generic TObjectPool<T: TObject> = class(TInterfacedObject, IPool)
  type
    TObjectCreatorFunc     = function: T;
    TObjectCreatorMethod   = function: T of object;
    TObjectCreatorRefFunc  = reference to function: T;
    TObjectInitFunc        = procedure (aObject: T);
    TObjectInitMethod      = procedure (aObject: T) of object;
    TObjectInitRefFunc     = reference to procedure(aObject: T);
    TObjectFinalizeFunc    = procedure (aObject: T);
    TObjectFinalizeMethod  = procedure (aObject: T) of object;
    TObjectFinalizeRefFunc = reference to procedure(aObject: T);

    {**
     * TConfig - Builder 模式配置记录
     *
     * @desc 用于简化 TObjectPool 的构建配置
     *       简化了 24 个构造函数重载的问题
     *
     * @example
     *   Pool := TObjectPool<TMyObject>.Create(
     *     TObjectPool<TMyObject>.TConfig.Default
     *       .WithMaxSize(100)
     *       .WithCreator(@CreateMyObject)
     *       .WithInit(@InitMyObject)
     *   );
     *}
    TConfig = record
    private
      FAllocator: IAllocator;
      FMaxSize: SizeUInt;
      FCreator: TObjectCreatorRefFunc;
      FInit: TObjectInitRefFunc;
      FFinalize: TObjectFinalizeRefFunc;
    public
      {** 创建默认配置 | Create default configuration *}
      class function Default: TConfig; static;

      {** 设置分配器 | Set allocator *}
      function WithAllocator(aAllocator: IAllocator): TConfig;

      {** 设置最大对象数 | Set maximum objects *}
      function WithMaxSize(aMaxSize: SizeUInt): TConfig;

      {** 设置创建回调 | Set creator callback *}
      function WithCreator(aCreator: TObjectCreatorRefFunc): TConfig;

      {** 设置初始化回调 | Set init callback *}
      function WithInit(aInit: TObjectInitRefFunc): TConfig;

      {** 设置终结回调 | Set finalize callback *}
      function WithFinalize(aFinalize: TObjectFinalizeRefFunc): TConfig;

      {** 获取配置的分配器 | Get configured allocator *}
      property Allocator: IAllocator read FAllocator;
      {** 获取配置的最大对象数 | Get configured max size *}
      property MaxSize: SizeUInt read FMaxSize;
      {** 获取配置的创建回调 | Get configured creator *}
      property Creator: TObjectCreatorRefFunc read FCreator;
      {** 获取配置的初始化回调 | Get configured init *}
      property Init: TObjectInitRefFunc read FInit;
      {** 获取配置的终结回调 | Get configured finalize *}
      property Finalize: TObjectFinalizeRefFunc read FFinalize;
    end;
  private
    FAllocator:      IAllocator;
    FMaxSize:        SizeUInt;

    // ✅ P0-1: 明确的计数语义
    FTotalCreated:   SizeUInt;  // 总共创建的对象数（历史累计）
    FInPoolCount:    SizeUInt;  // 当前池中可用的对象数

    // Object storage
    FPool:     array of T;
    FFreeTop:  SizeInt;

    // ✅ P0-1: 回调存储使用值语义（不是指针）
    // RefFunc 类型可以包装所有回调类型
    FCreatorRef:  TObjectCreatorRefFunc;
    FInitRef:     TObjectInitRefFunc;
    FFinalizeRef: TObjectFinalizeRefFunc;

    FHasCreator:   Boolean;
    FHasInit:      Boolean;
    FHasFinalize:  Boolean;
  protected
    function  CreateObject: T;
    procedure InitObject(aObject: T);
    procedure FinalizeObject(aObject: T);

    function  GetMaxObjects: SizeUInt;
    function  GetInPoolCount: SizeUInt;
    function  GetTotalCreated: SizeUInt;

  public
    // ✅ P0-1: 简化构造函数（使用 RefFunc 统一处理）
    constructor Create(aAllocator: IAllocator; aMaxSize: SizeUInt;
                       aCreator: TObjectCreatorRefFunc;
                       aInit: TObjectInitRefFunc;
                       aFinalize: TObjectFinalizeRefFunc);
    constructor Create(aMaxSize: SizeUInt;
                       aCreator: TObjectCreatorRefFunc;
                       aInit: TObjectInitRefFunc = nil;
                       aFinalize: TObjectFinalizeRefFunc = nil);
    constructor Create(aCreator: TObjectCreatorRefFunc);

    {** Builder 模式构造函数 - 推荐使用 | Builder pattern constructor - recommended *}
    constructor Create(const aConfig: TConfig);

    destructor Destroy; override;

    function  Acquire(out aObject: Pointer): Boolean;
    function  TryAcquire(out aPtr: Pointer): Boolean;
    function  AcquireN(out aPtrs: array of Pointer; aCount: Integer): Integer;
    procedure Release(aObject: Pointer);
    procedure ReleaseN(const aPtrs: array of Pointer; aCount: Integer);

    function  AcquireObject(out aObject: T): Boolean;
    procedure ReleaseObject(aObject: T);

    procedure Reset;

    {** 池的最大容量 | Maximum pool capacity *}
    property MaxObjects: SizeUInt read GetMaxObjects;
    {** 当前池中可用的对象数 | Currently available objects in pool *}
    property InPoolCount: SizeUInt read GetInPoolCount;
    {** 总共创建的对象数 | Total objects ever created *}
    property TotalCreated: SizeUInt read GetTotalCreated;
    // 保留旧属性名以保持兼容
    property CurrentObjects: SizeUInt read GetInPoolCount;
  end;



implementation

{ TObjectPool<T>.TConfig }

class function TObjectPool.TConfig.Default: TConfig;
begin
  Result.FAllocator := nil;
  Result.FMaxSize := 100;
  Result.FCreator := nil;
  Result.FInit := nil;
  Result.FFinalize := nil;
end;

function TObjectPool.TConfig.WithAllocator(aAllocator: IAllocator): TConfig;
begin
  Result := Self;
  Result.FAllocator := aAllocator;
end;

function TObjectPool.TConfig.WithMaxSize(aMaxSize: SizeUInt): TConfig;
begin
  Result := Self;
  Result.FMaxSize := aMaxSize;
end;

function TObjectPool.TConfig.WithCreator(aCreator: TObjectCreatorRefFunc): TConfig;
begin
  Result := Self;
  Result.FCreator := aCreator;
end;

function TObjectPool.TConfig.WithInit(aInit: TObjectInitRefFunc): TConfig;
begin
  Result := Self;
  Result.FInit := aInit;
end;

function TObjectPool.TConfig.WithFinalize(aFinalize: TObjectFinalizeRefFunc): TConfig;
begin
  Result := Self;
  Result.FFinalize := aFinalize;
end;

{ TObjectPool<T> }

function TObjectPool.GetMaxObjects: SizeUInt;
begin
  Result := FMaxSize;
end;

function TObjectPool.GetInPoolCount: SizeUInt;
begin
  Result := FInPoolCount;
end;

function TObjectPool.GetTotalCreated: SizeUInt;
begin
  Result := FTotalCreated;
end;

function TObjectPool.CreateObject: T;
begin
  // ✅ P0-1: 使用值语义的回调
  if FHasCreator then
    Result := FCreatorRef()
  else
    Result := T.Create;
end;

procedure TObjectPool.InitObject(aObject: T);
begin
  // ✅ P0-1: 使用值语义的回调
  if FHasInit then
    FInitRef(aObject);
end;

procedure TObjectPool.FinalizeObject(aObject: T);
begin
  // ✅ P0-1: 使用值语义的回调
  if FHasFinalize then
    FFinalizeRef(aObject);
end;

// ✅ P0-1: 核心构造函数 - 使用值语义存储回调
constructor TObjectPool.Create(aAllocator: IAllocator; aMaxSize: SizeUInt;
                               aCreator: TObjectCreatorRefFunc;
                               aInit: TObjectInitRefFunc;
                               aFinalize: TObjectFinalizeRefFunc);
begin
  inherited Create;

  if aMaxSize = 0 then
    FMaxSize := 100
  else
    FMaxSize := aMaxSize;

  if aAllocator = nil then
    FAllocator := GetRtlAllocator
  else
    FAllocator := aAllocator;

  FTotalCreated := 0;
  FInPoolCount := 0;
  FFreeTop := 0;

  SetLength(FPool, FMaxSize);

  // ✅ P0-1: 直接存储回调值（不是指针）
  FCreatorRef := aCreator;
  FHasCreator := Assigned(aCreator);

  FInitRef := aInit;
  FHasInit := Assigned(aInit);

  FFinalizeRef := aFinalize;
  FHasFinalize := Assigned(aFinalize);
end;

constructor TObjectPool.Create(aMaxSize: SizeUInt;
                               aCreator: TObjectCreatorRefFunc;
                               aInit: TObjectInitRefFunc;
                               aFinalize: TObjectFinalizeRefFunc);
begin
  Create(nil, aMaxSize, aCreator, aInit, aFinalize);
end;

constructor TObjectPool.Create(aCreator: TObjectCreatorRefFunc);
begin
  Create(nil, 100, aCreator, nil, nil);
end;

constructor TObjectPool.Create(const aConfig: TConfig);
begin
  Create(aConfig.Allocator, aConfig.MaxSize, aConfig.Creator, aConfig.Init, aConfig.Finalize);
end;

destructor TObjectPool.Destroy;
var
  i: SizeInt;
begin
  // Free all objects in pool
  for i := 0 to FFreeTop - 1 do
  begin
    if FPool[i] <> nil then
      FPool[i].Free;
  end;

  SetLength(FPool, 0);

  // ✅ P0-1: 清理回调引用
  FCreatorRef := nil;
  FInitRef := nil;
  FFinalizeRef := nil;

  inherited Destroy;
end;

function TObjectPool.AcquireObject(out aObject: T): Boolean;
begin
  Result := False;
  aObject := nil;

  // Try to get from pool first
  if FFreeTop > 0 then
  begin
    Dec(FFreeTop);
    aObject := FPool[FFreeTop];
    FPool[FFreeTop] := nil;
    Dec(FInPoolCount);
    Result := True;
  end
  else
  begin
    // ✅ P0-1: 正确的 MaxSize 约束检查
    // TotalCreated 跟踪实际创建的对象数，不受归还影响
    if FTotalCreated < FMaxSize then
    begin
      aObject := CreateObject;
      if aObject <> nil then
      begin
        Inc(FTotalCreated);
        Result := True;
      end;
    end;
    // 如果已达 MaxSize，返回 False
  end;

  // Initialize object if we got one
  if Result and (aObject <> nil) and FHasInit then
    InitObject(aObject);
end;

procedure TObjectPool.ReleaseObject(aObject: T);
begin
  if aObject = nil then Exit;

  // Finalize object
  if FHasFinalize then
    FinalizeObject(aObject);

  // Return to pool if there's space
  if FFreeTop < SizeInt(FMaxSize) then
  begin
    FPool[FFreeTop] := aObject;
    Inc(FFreeTop);
    Inc(FInPoolCount);
  end
  else
  begin
    // Pool is full, destroy object
    aObject.Free;
    // 注意：TotalCreated 不减少，因为对象确实被创建过
  end;
end;

function TObjectPool.Acquire(out aObject: Pointer): Boolean;
var
  LObj: T;
begin
  Result := AcquireObject(LObj);
  aObject := Pointer(LObj);
end;

procedure TObjectPool.Release(aObject: Pointer);
begin
  if aObject <> nil then
    ReleaseObject(T(aObject));
end;

function TObjectPool.TryAcquire(out aPtr: Pointer): Boolean;
begin
  Result := Acquire(aPtr);
end;

function TObjectPool.AcquireN(out aPtrs: array of Pointer; aCount: Integer): Integer;
var
  I: Integer;
  LPtr: Pointer;
begin
  Result := 0;
  for I := 0 to aCount - 1 do
  begin
    if not Acquire(LPtr) then
      Break;
    aPtrs[I] := LPtr;
    Inc(Result);
  end;
end;

procedure TObjectPool.ReleaseN(const aPtrs: array of Pointer; aCount: Integer);
var
  I: Integer;
begin
  for I := 0 to aCount - 1 do
    Release(aPtrs[I]);
end;

procedure TObjectPool.Reset;
var
  i: SizeInt;
begin
  // Free all objects in pool
  for i := 0 to FFreeTop - 1 do
  begin
    if FPool[i] <> nil then
      FPool[i].Free;
  end;

  FFreeTop := 0;
  FInPoolCount := 0;
  FTotalCreated := 0;  // Reset 后允许重新创建
end;

end.