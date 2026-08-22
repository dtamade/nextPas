unit nextpas.core.lockfree.priority_queue;
{**
 * @desc Concurrent priority queue using a binary heap with mutex protection.
 *
 * Uses a min-heap by default (lowest priority value = highest priority).
 * Thread-safe for all operations. Uses platform mutex for synchronization.
 *
 * @see java.util.concurrent.PriorityBlockingQueue — reference implementation
 * @see Go container/heap — similar heap-based priority queue
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem,
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.platform.sync;

type
  {**
   * 并发优先队列。
   *
   * 基于二叉堆实现，使用互斥锁保证线程安全。
   * 最小堆：优先级值最小的元素最先出队。
   *
   * @constraints
   *   - T 必须是 unmanaged 类型
   *   - 所有公共方法是线程安全的
   *}
  generic TConcurrentPriorityQueueImpl<T> = class
  public type
    TCompareFunc = function(const ALeft, ARight: T): Integer;
  private type
    PHeapArray = ^THeapArray;
    THeapArray = array[0..MaxInt div SizeOf(T) - 1] of T;
  private
    FData: PHeapArray;
    FCount: Integer;
    FCapacity: Integer;
    FCompare: TCompareFunc;
    FMutex: TPlatformMutex;
    procedure Grow;
    procedure SiftUp(AIndex: Integer);
    procedure SiftDown(AIndex: Integer);
    function CompareItems(const ALeft, ARight: T): Integer;
  public
    {** @desc 创建并发优先队列
      @param ACompare 比较函数，返回负数表示 ALeft < ARight
      @param AInitialCapacity 初始容量，默认64 }
    constructor Create(const ACompare: TCompareFunc; const AInitialCapacity: Integer = 64);
    destructor Destroy; override;

    {** @desc 入队
      @param AValue 要入队的值
      @note 线程安全，自动扩容 }
    procedure Enqueue(const AValue: T);

    {** @desc 尝试出队
      @param AValue 出队的值
      @return True 如果队列非空，False 如果队列为空
      @note 线程安全 }
    function TryDequeue(out AValue: T): Boolean;

    {** @desc 尝试查看队首元素（不出队）
      @param AValue 队首的值
      @return True 如果队列非空，False 如果队列为空
      @note 线程安全 }
    function TryPeek(out AValue: T): Boolean;

    {** @desc 清空队列 }
    procedure Clear;

    {** @desc 队列当前大小 }
    function Count: Integer;

    {** @desc 队列是否为空 }
    function IsEmpty: Boolean;

    {** @desc 队列当前容量 }
    function Capacity: Integer;
  end;

  generic TConcurrentPriorityQueue<T> = class(specialize TConcurrentPriorityQueueImpl<T>)
  end;

implementation

constructor TConcurrentPriorityQueueImpl.Create(const ACompare: TCompareFunc; const AInitialCapacity: Integer);
begin
  if IsManagedType(T) then
    raise EArgumentError.Create('TConcurrentPriorityQueue: T must be unmanaged');
  if not Assigned(ACompare) then
    raise EArgumentError.Create('TConcurrentPriorityQueue: compare function required');
  if AInitialCapacity < 1 then
    raise EArgumentError.Create('TConcurrentPriorityQueue: capacity must be > 0');
  if AInitialCapacity > MaxInt div SizeOf(T) then
    raise EArgumentError.Create('TConcurrentPriorityQueue: capacity exceeds allocation limit');
  inherited Create;
  FCompare := ACompare;
  FCapacity := AInitialCapacity;
  FCount := 0;
  FData := GetMem(FCapacity * SizeOf(T));
  platform_mutex_init(FMutex, PLATFORM_MUTEX_ERRORCHECK);
end;

destructor TConcurrentPriorityQueueImpl.Destroy;
begin
  platform_mutex_destroy(FMutex);
  if FData <> nil then
    FreeMem(FData, FCapacity * SizeOf(T));
  inherited;
end;

function TConcurrentPriorityQueueImpl.CompareItems(const ALeft, ARight: T): Integer;
begin
  Result := FCompare(ALeft, ARight);
end;

procedure TConcurrentPriorityQueueImpl.Grow;
var
  LNewCap: Integer;
  LNewData: PHeapArray;
begin
  if FCapacity > (MaxInt div SizeOf(T)) div 2 then
    raise EOutOfMemoryError.Create(FormatAllocErrorMsg('LockFree', 'Grow', 'TConcurrentPriorityQueue.Grow: capacity overflow'));
  LNewCap := FCapacity * 2;
  LNewData := GetMem(LNewCap * SizeOf(T));
  Move(FData^[0], LNewData^[0], FCount * SizeOf(T));
  FreeMem(FData, FCapacity * SizeOf(T));
  FData := LNewData;
  FCapacity := LNewCap;
end;

procedure TConcurrentPriorityQueueImpl.SiftUp(AIndex: Integer);
var
  LParent: Integer;
  LTemp: T;
begin
  while AIndex > 0 do
  begin
    LParent := (AIndex - 1) div 2;
    if CompareItems(FData^[AIndex], FData^[LParent]) < 0 then
    begin
      LTemp := FData^[AIndex];
      FData^[AIndex] := FData^[LParent];
      FData^[LParent] := LTemp;
      AIndex := LParent;
    end
    else
      Break;
  end;
end;

procedure TConcurrentPriorityQueueImpl.SiftDown(AIndex: Integer);
var
  LSmallest, LLeft, LRight: Integer;
  LTemp: T;
begin
  while True do
  begin
    LSmallest := AIndex;
    LLeft := 2 * AIndex + 1;
    LRight := 2 * AIndex + 2;
    if (LLeft < FCount) and (CompareItems(FData^[LLeft], FData^[LSmallest]) < 0) then
      LSmallest := LLeft;
    if (LRight < FCount) and (CompareItems(FData^[LRight], FData^[LSmallest]) < 0) then
      LSmallest := LRight;
    if LSmallest <> AIndex then
    begin
      LTemp := FData^[AIndex];
      FData^[AIndex] := FData^[LSmallest];
      FData^[LSmallest] := LTemp;
      AIndex := LSmallest;
    end
    else
      Break;
  end;
end;

procedure TConcurrentPriorityQueueImpl.Enqueue(const AValue: T);
begin
  platform_mutex_lock(FMutex);
  try
    if FCount >= FCapacity then
      Grow;
    FData^[FCount] := AValue;
    Inc(FCount);
    SiftUp(FCount - 1);
  finally
    platform_mutex_unlock(FMutex);
  end;
end;

function TConcurrentPriorityQueueImpl.TryDequeue(out AValue: T): Boolean;
begin
  platform_mutex_lock(FMutex);
  try
    if FCount = 0 then
      Exit(False);
    AValue := FData^[0];
    Dec(FCount);
    if FCount > 0 then
    begin
      FData^[0] := FData^[FCount];
      SiftDown(0);
    end;
    Result := True;
  finally
    platform_mutex_unlock(FMutex);
  end;
end;

function TConcurrentPriorityQueueImpl.TryPeek(out AValue: T): Boolean;
begin
  platform_mutex_lock(FMutex);
  try
    if FCount = 0 then
      Exit(False);
    AValue := FData^[0];
    Result := True;
  finally
    platform_mutex_unlock(FMutex);
  end;
end;

procedure TConcurrentPriorityQueueImpl.Clear;
begin
  platform_mutex_lock(FMutex);
  try
    FCount := 0;
  finally
    platform_mutex_unlock(FMutex);
  end;
end;

function TConcurrentPriorityQueueImpl.Count: Integer;
begin
  platform_mutex_lock(FMutex);
  try
    Result := FCount;
  finally
    platform_mutex_unlock(FMutex);
  end;
end;

function TConcurrentPriorityQueueImpl.IsEmpty: Boolean;
begin
  platform_mutex_lock(FMutex);
  try
    Result := FCount = 0;
  finally
    platform_mutex_unlock(FMutex);
  end;
end;

function TConcurrentPriorityQueueImpl.Capacity: Integer;
begin
  platform_mutex_lock(FMutex);
  try
    Result := FCapacity;
  finally
    platform_mutex_unlock(FMutex);
  end;
end;

end.
