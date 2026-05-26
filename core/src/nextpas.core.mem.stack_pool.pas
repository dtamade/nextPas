{
```text
   ______   ______     ______   ______     ______   ______
  /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \
  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \
   \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\
    \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/  Studio

```
# nextpas.core.mem.stack_pool

## Abstract 摘要

Stack-based memory pool implementation providing fast sequential allocation and bulk deallocation.
基于栈的内存池实现，提供快速的顺序分配和批量释放。

## Declaration 声明

For forwarding or using it for your own project, please retain the copyright notice of this project. Thank you.
转发或者用于自己项目请保留本项目的版权声明,谢谢.

Author:    fafafaStudio
Contact:   dtamade@gmail.com | QQ Group: 685403987 | QQ:179033731
Copyright: (c) 2025 fafafaStudio. All rights reserved.
}

unit nextpas.core.mem.stack_pool;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils, Classes,
  nextpas.core.base,
  nextpas.core.mem.allocator,
  nextpas.core.mem.error;

type
  {** 栈池异常 Stack pool exception *}
  EStackPoolError = class(EAllocError);

type
  TStackPoolConfig = record
    TotalSize: SizeUInt;
    Alignment: SizeUInt;    // 默认指针大小
    ZeroOnAlloc: Boolean;   // 分配后是否清零（默认False）
    Allocator: IAllocator;
  end;

type
  {**
   * TStackPool
   *
   * @desc 栈式内存池，提供快速的顺序分配和批量释放
   *       Stack-based memory pool for fast sequential allocation and bulk deallocation
   *
   * @threadsafety 非线程安全，需要外部同步
   *               Not thread-safe, requires external synchronization
   *}
  TStackPool = class
  protected
    FBuffer: Pointer;
    FSize: SizeUInt;
    FOffset: SizeUInt;
    FBaseAllocator: IAllocator;

    function GetAvailableSize: SizeUInt;
    function AlignOffset(aOffset, aAlignment: SizeUInt): SizeUInt;

  public
    {**
     * Create
     *
     * @desc 创建栈式内存池
     *       Create stack memory pool
     *
     * @param aSize 总大小 Total size
     * @param aAllocator 基础分配器 Base allocator (optional)
     *}
    constructor Create(aSize: SizeUInt; aAllocator: IAllocator = nil); overload;
    constructor Create(const aConfig: TStackPoolConfig); overload;

    {**
     * Destroy
     *
     * @desc 销毁栈式内存池
     *       Destroy stack memory pool
     *}
    destructor Destroy; override;

    {**
     * Alloc
     *
     * @desc 分配内存
     *       Allocate memory
     *
     * @param aSize 请求大小 Requested size
     * @param aAlignment 对齐要求 Alignment requirement (default: pointer size)
     * @return 内存指针 Memory pointer
     *}
    function Alloc(aSize: SizeUInt; aAlignment: SizeUInt = SizeOf(Pointer)): Pointer; inline;
    function AllocAligned(aSize: SizeUInt; aAlignment: SizeUInt): Pointer; inline;

    {**
     * TryAlloc
     *
     * @desc 尝试分配（不抛异常），失败返回 False
     *       Try to allocate (no exception), return False on failure
     *}
    function TryAlloc(aSize: SizeUInt; out APtr: Pointer; aAlignment: SizeUInt = SizeOf(Pointer)): Boolean; inline;
    function TryAllocAligned(aSize: SizeUInt; out APtr: Pointer; aAlignment: SizeUInt): Boolean; inline;

    {**
     * Reset
     *
     * @desc 重置栈，释放所有分配的内存
     *       Reset stack, free all allocated memory
     *}
    procedure Reset; inline;

    {**
     * SaveState
     *
     * @desc 保存当前状态
     *       Save current state
     *
     * @return 状态标记 State marker
     *}
    function SaveState: SizeUInt; inline;

    {**
     * RestoreState
     *
     * @desc 恢复到指定状态
     *       Restore to specified state
     *
     * @param aState 状态标记 State marker
     *}
    procedure RestoreState(aState: SizeUInt); inline;

    // 属性 Properties
    property TotalSize: SizeUInt read FSize;
    property UsedSize: SizeUInt read FOffset;
    property AvailableSize: SizeUInt read GetAvailableSize;

    function IsEmpty: Boolean;
    function IsFull: Boolean;
  end;

  // ============================================================================
  // 作用域栈池 (Scoped Stack Pool) - 支持 RAII 和自动回收
  // ============================================================================

  // Forward declarations
  TScopedStackPool = class;

  {**
   * TStackPoolStatistics
   *
   * @desc 栈池统计信息
   *}
  TStackPoolStatistics = record
    TotalAllocations: UInt64;     // 总分配次数
    TotalBytes: UInt64;           // 总分配字节数
    PeakUsage: SizeUInt;          // 峰值使用量
    CurrentUsage: SizeUInt;       // 当前使用量
    ScopeCreations: UInt64;       // 作用域创建次数
    ScopeDestructions: UInt64;    // 作用域销毁次数
    MaxScopeDepth: Integer;       // 最大作用域深度
    CurrentScopeDepth: Integer;   // 当前作用域深度
    FragmentationRatio: Double;   // 碎片化比率
  end;

  {**
   * TStackPoolPolicy
   *
   * @desc 栈池策略配置
   *}
  TStackPoolPolicy = record
    EnableStatistics: Boolean;    // 启用统计信息
    EnableScopeTracking: Boolean; // 启用作用域跟踪
    EnableAutoGrow: Boolean;      // 启用自动增长
    GrowthFactor: Single;         // 增长因子
    MaxSize: SizeUInt;            // 最大大小
    DefaultAlignment: SizeUInt;   // 默认对齐
    EnableDebugMode: Boolean;     // 启用调试模式

    class function Default: TStackPoolPolicy; static;
    class function HighPerformance: TStackPoolPolicy; static;
    class function Debug: TStackPoolPolicy; static;
  end;

  // 调试用内存映射条目类型
  TStackMemoryMapEntry = record
    Start: Pointer;
    Size: SizeUInt;
    Used: Boolean;
  end;

  {**
   * TStackPoolScope
   *
   * @desc 栈作用域，支持 RAII 自动回收
   *}
  TStackPoolScope = class
  private
    FPool: TScopedStackPool;
    FSavedState: SizeUInt;
    FActive: Boolean;
  public
    constructor Create(aPool: TScopedStackPool);
    destructor Destroy; override;

    {** 在当前作用域中分配内存 *}
    function Alloc(aSize: SizeUInt; aAlignment: SizeUInt = SizeOf(Pointer)): Pointer;

    {** 手动释放作用域（通常由析构函数自动调用） *}
    procedure Release;

    property Active: Boolean read FActive;
  end;

  {**
   * TStackPoolScopeManager
   *
   * @desc 栈作用域管理器，管理嵌套作用域
   *}
  TStackPoolScopeManager = class
  private
    FScopes: TList;
    FPool: TScopedStackPool;
  public
    constructor Create(aPool: TScopedStackPool);
    destructor Destroy; override;

    function PushScope: TStackPoolScope;
    procedure PopScope;
    procedure RemoveScope(aScope: TStackPoolScope);  // 从列表中移除（不释放）
    function GetCurrentScope: TStackPoolScope;
    function GetScopeDepth: Integer;
    procedure ClearAllScopes;
  end;

  {**
   * TScopedStackPool
   *
   * @desc 作用域栈池，支持嵌套作用域、自动回收、RAII 等高级功能
   *       原名 TEnhancedStackPool，整合命名规范后改名
   *
   * @threadsafety 非线程安全，需要外部同步
   *               Not thread-safe, requires external synchronization
   *
   * @warning 启用 EnableAutoGrow 时，扩容会使之前分配的指针失效。
   *          如果有活跃作用域，扩容将抛出异常以防止指针悬空。
   *}
  TScopedStackPool = class(TStackPool)
  private
    FPolicy: TStackPoolPolicy;
    FStatistics: TStackPoolStatistics;
    FScopeManager: TStackPoolScopeManager;
    FStateStack: array of SizeUInt;
    FStateStackTop: Integer;
    FMaxStateStack: Integer;

    procedure UpdateStatistics(aAllocSize: SizeUInt);
    procedure GrowPool(aRequiredSize: SizeUInt);
    function CalculateFragmentation: Double;

  public
    constructor Create(aSize: SizeUInt; const aPolicy: TStackPoolPolicy; aAllocator: IAllocator = nil);
    destructor Destroy; override;

    {** 分配内存（带策略支持） *}
    function Alloc(aSize: SizeUInt; aAlignment: SizeUInt = SizeOf(Pointer)): Pointer; reintroduce;

    {** 创建新的作用域 *}
    function CreateScope: TStackPoolScope;

    {** 推入状态到状态栈 *}
    function PushState: Boolean;

    {** 从状态栈弹出状态 *}
    function PopState: Boolean;

    {** 获取状态栈深度 *}
    function GetStateStackDepth: Integer;

    {** 分配对齐内存 *}
    function AllocAligned(aSize: SizeUInt; aAlignment: SizeUInt): Pointer; reintroduce;

    {** 分配并清零的内存 *}
    function AllocZeroed(aSize: SizeUInt; aAlignment: SizeUInt = 0): Pointer;

    {** 分配字符串内存 *}
    function AllocString(aLength: SizeUInt): PChar;

    {** 分配数组内存 *}
    function AllocArray(aElementSize: SizeUInt; aCount: SizeUInt; aAlignment: SizeUInt = 0): Pointer;

    {** 获取统计信息 *}
    function GetStatistics: TStackPoolStatistics;

    {** 重置统计信息 *}
    procedure ResetStatistics;

    {** 获取碎片化比率 *}
    function GetFragmentation: Double;

    {** 优化池状态 *}
    procedure Optimize;

    {** 获取内存映射信息（调试用） *}
    function GetMemoryMap(out aMap: array of TStackMemoryMapEntry): Integer;

    property Policy: TStackPoolPolicy read FPolicy write FPolicy;
    property Statistics: TStackPoolStatistics read GetStatistics;
    property ScopeManager: TStackPoolScopeManager read FScopeManager;
  end;

  {**
   * TAutoStackPoolScope
   *
   * @desc 自动栈作用域，支持 RAII 模式
   *}
  TAutoStackPoolScope = record
  private
    FScope: TStackPoolScope;
    FActive: Boolean;
  public
    class function Initialize(aPool: TScopedStackPool): TAutoStackPoolScope; static;
    procedure Finalize;
    function Alloc(aSize: SizeUInt; aAlignment: SizeUInt = SizeOf(Pointer)): Pointer;
    property Active: Boolean read FActive;
  end;

  // 向后兼容别名 (deprecated, will be removed in v3.0)
  TEnhancedStackPool = TScopedStackPool deprecated 'Use TScopedStackPool instead';
  TStackScope = TStackPoolScope deprecated 'Use TStackPoolScope instead';
  TAutoStackScope = TAutoStackPoolScope deprecated 'Use TAutoStackPoolScope instead';
  TStackScopeManager = TStackPoolScopeManager deprecated 'Use TStackPoolScopeManager instead';

// 向后兼容辅助函数 (deprecated)
function CreateDefaultStackPolicy: TStackPoolPolicy; deprecated 'Use TStackPoolPolicy.Default instead';
function CreateHighPerformanceStackPolicy: TStackPoolPolicy; deprecated 'Use TStackPoolPolicy.HighPerformance instead';
function CreateDebugStackPolicy: TStackPoolPolicy; deprecated 'Use TStackPoolPolicy.Debug instead';

implementation

uses
  nextpas.core.math;

constructor TStackPool.Create(const aConfig: TStackPoolConfig);
begin
  Create(aConfig.TotalSize, aConfig.Allocator);
  if aConfig.ZeroOnAlloc and (FBuffer <> nil) then
    FillChar(FBuffer^, FSize, 0);
end;

{ TStackPool }

constructor TStackPool.Create(aSize: SizeUInt; aAllocator: IAllocator);
begin
  inherited Create;

  if aSize = 0 then
    raise EStackPoolError.Create(aeInvalidLayout, 'Stack size cannot be zero');

  FSize := aSize;
  FOffset := 0;

  if aAllocator = nil then
    FBaseAllocator := nextpas.core.mem.allocator.GetRtlAllocator
  else
    FBaseAllocator := aAllocator;

  FBuffer := FBaseAllocator.GetMem(aSize);
  if FBuffer = nil then
    raise EStackPoolError.Create(aeOutOfMemory, 'Failed to allocate stack buffer');
end;

destructor TStackPool.Destroy;
begin
  if FBuffer <> nil then
    FBaseAllocator.FreeMem(FBuffer);
  inherited Destroy;
end;

function TStackPool.Alloc(aSize: SizeUInt; aAlignment: SizeUInt): Pointer;
var
  LAlignedOffset: SizeUInt;
begin
  Result := nil;
  if aSize = 0 then
    Exit;

  // 防御性：对齐为 0 则使用指针大小；且对齐必须为 2 的幂（否则回退为指针大小）
  if aAlignment = 0 then
    aAlignment := SizeOf(Pointer);
  if (aAlignment and (aAlignment - 1)) <> 0 then
    aAlignment := SizeOf(Pointer);

  // 计算对齐后的偏移（中文注释）：按对齐要求向上取整
  LAlignedOffset := AlignOffset(FOffset, aAlignment);

  // 溢出与界限检查
  if (LAlignedOffset > FSize) or (aSize > FSize - LAlignedOffset) then
    Exit;

  // 返回指针并更新偏移（使用类型化指针算术以避免 4055）
  Result := Pointer(PByte(FBuffer) + LAlignedOffset);
  FOffset := LAlignedOffset + aSize;
end;

procedure TStackPool.Reset;
begin
  FOffset := 0;
end;

function TStackPool.SaveState: SizeUInt;
begin
  Result := FOffset;
end;

function TStackPool.TryAlloc(aSize: SizeUInt; out APtr: Pointer; aAlignment: SizeUInt): Boolean;
begin
  APtr := Alloc(aSize, aAlignment);
  Result := APtr <> nil;
end;

procedure TStackPool.RestoreState(aState: SizeUInt);
begin
  if aState <= FSize then
    FOffset := aState;
end;

function TStackPool.GetAvailableSize: SizeUInt;
begin
  Result := FSize - FOffset;
end;

function TStackPool.IsEmpty: Boolean;
begin
  Result := FOffset = 0;
end;

function TStackPool.IsFull: Boolean;
begin
  Result := FOffset >= FSize;
end;

function TStackPool.AllocAligned(aSize: SizeUInt; aAlignment: SizeUInt): Pointer;
begin
  if aSize = 0 then Exit(nil);
  // ✅ M-4: 统一对齐验证逻辑，与 TAllocator.AllocAligned 保持一致
  if aAlignment = 0 then
    raise EInvalidArgument.Create('TStackPool.AllocAligned: aAlignment is 0');
  if aAlignment < SizeOf(Pointer) then
    raise EInvalidArgument.Create('TStackPool.AllocAligned: aAlignment must be >= pointer size');
  if (aAlignment and (aAlignment - 1)) <> 0 then
    raise EInvalidArgument.Create('TStackPool.AllocAligned: aAlignment must be power of two');
  Result := Alloc(aSize, aAlignment);
end;

function TStackPool.TryAllocAligned(aSize: SizeUInt; out APtr: Pointer; aAlignment: SizeUInt): Boolean;
begin
  try
    APtr := AllocAligned(aSize, aAlignment);
    Result := APtr <> nil;
  except
    APtr := nil;
    Result := False;
  end;
end;

function TStackPool.AlignOffset(aOffset, aAlignment: SizeUInt): SizeUInt;
begin
  if aAlignment <= 1 then
    Result := aOffset
  else
    Result := (aOffset + aAlignment - 1) and not (aAlignment - 1);
end;

// ============================================================================
// TStackPoolPolicy
// ============================================================================

class function TStackPoolPolicy.Default: TStackPoolPolicy;
begin
  Result.EnableStatistics := True;
  Result.EnableScopeTracking := True;
  Result.EnableAutoGrow := False;
  Result.GrowthFactor := 2.0;
  Result.MaxSize := 64 * 1024 * 1024; // 64MB
  Result.DefaultAlignment := SizeOf(Pointer);
  Result.EnableDebugMode := False;
end;

class function TStackPoolPolicy.HighPerformance: TStackPoolPolicy;
begin
  Result := TStackPoolPolicy.Default;
  Result.EnableStatistics := False;
  Result.EnableScopeTracking := False;
  Result.EnableDebugMode := False;
end;

class function TStackPoolPolicy.Debug: TStackPoolPolicy;
begin
  Result := TStackPoolPolicy.Default;
  Result.EnableDebugMode := True;
  Result.GrowthFactor := 1.5; // 更保守的增长
end;

// 向后兼容辅助函数
function CreateDefaultStackPolicy: TStackPoolPolicy;
begin
  Result := TStackPoolPolicy.Default;
end;

function CreateHighPerformanceStackPolicy: TStackPoolPolicy;
begin
  Result := TStackPoolPolicy.HighPerformance;
end;

function CreateDebugStackPolicy: TStackPoolPolicy;
begin
  Result := TStackPoolPolicy.Debug;
end;

// ============================================================================
// TStackPoolScope
// ============================================================================

constructor TStackPoolScope.Create(aPool: TScopedStackPool);
begin
  inherited Create;
  FPool := aPool;
  FSavedState := FPool.SaveState;
  FActive := True;

  if FPool.Policy.EnableStatistics then
    Inc(FPool.FStatistics.ScopeCreations);
end;

destructor TStackPoolScope.Destroy;
begin
  if FActive then
    Release;
  // 从 ScopeManager 中移除自己（如果存在）
  if Assigned(FPool) and Assigned(FPool.FScopeManager) then
    FPool.FScopeManager.RemoveScope(Self);
  inherited Destroy;
end;

function TStackPoolScope.Alloc(aSize: SizeUInt; aAlignment: SizeUInt): Pointer;
begin
  if not FActive then
  begin
    Result := nil;
    Exit;
  end;

  if aAlignment = 0 then
    aAlignment := FPool.Policy.DefaultAlignment;

  Result := FPool.Alloc(aSize, aAlignment);
end;

procedure TStackPoolScope.Release;
begin
  if not FActive then Exit;

  FPool.RestoreState(FSavedState);
  FActive := False;

  if FPool.Policy.EnableStatistics then
    Inc(FPool.FStatistics.ScopeDestructions);
end;

// ============================================================================
// TStackPoolScopeManager
// ============================================================================

constructor TStackPoolScopeManager.Create(aPool: TScopedStackPool);
begin
  inherited Create;
  FPool := aPool;
  FScopes := TList.Create;
end;

destructor TStackPoolScopeManager.Destroy;
begin
  ClearAllScopes;
  FScopes.Free;
  inherited Destroy;
end;

function TStackPoolScopeManager.PushScope: TStackPoolScope;
begin
  Result := TStackPoolScope.Create(FPool);
  FScopes.Add(Result);

  if FPool.Policy.EnableStatistics then
  begin
    FPool.FStatistics.CurrentScopeDepth := FScopes.Count;
    if FScopes.Count > FPool.FStatistics.MaxScopeDepth then
      FPool.FStatistics.MaxScopeDepth := FScopes.Count;
  end;
end;

procedure TStackPoolScopeManager.PopScope;
var
  LScope: TStackPoolScope;
begin
  if FScopes.Count = 0 then Exit;

  LScope := TStackPoolScope(FScopes.Last);
  FScopes.Delete(FScopes.Count - 1);
  // ✅ M-5: 设置 FPool 为 nil，避免 Destroy 中重复调用 RemoveScope
  LScope.FPool := nil;
  LScope.Free;

  if FPool.Policy.EnableStatistics then
    FPool.FStatistics.CurrentScopeDepth := FScopes.Count;
end;

procedure TStackPoolScopeManager.RemoveScope(aScope: TStackPoolScope);
var
  LIndex: Integer;
begin
  LIndex := FScopes.IndexOf(aScope);
  if LIndex >= 0 then
  begin
    FScopes.Delete(LIndex);
    if FPool.Policy.EnableStatistics then
      FPool.FStatistics.CurrentScopeDepth := FScopes.Count;
  end;
end;

function TStackPoolScopeManager.GetCurrentScope: TStackPoolScope;
begin
  if FScopes.Count > 0 then
    Result := TStackPoolScope(FScopes.Last)
  else
    Result := nil;
end;

function TStackPoolScopeManager.GetScopeDepth: Integer;
begin
  Result := FScopes.Count;
end;

procedure TStackPoolScopeManager.ClearAllScopes;
var
  LIndex: Integer;
begin
  for LIndex := FScopes.Count - 1 downto 0 do
    TStackPoolScope(FScopes[LIndex]).Free;
  FScopes.Clear;

  if FPool.Policy.EnableStatistics then
    FPool.FStatistics.CurrentScopeDepth := 0;
end;

// ============================================================================
// TScopedStackPool
// ============================================================================

constructor TScopedStackPool.Create(aSize: SizeUInt; const aPolicy: TStackPoolPolicy; aAllocator: IAllocator);
begin
  inherited Create(aSize, aAllocator);

  FPolicy := aPolicy;
  FillChar(FStatistics, SizeOf(FStatistics), 0);

  if FPolicy.EnableScopeTracking then
    FScopeManager := TStackPoolScopeManager.Create(Self)
  else
    FScopeManager := nil;

  // 初始化状态栈
  FMaxStateStack := 32; // 默认支持 32 层嵌套
  SetLength(FStateStack, FMaxStateStack);
  FStateStackTop := -1;
end;

destructor TScopedStackPool.Destroy;
begin
  if Assigned(FScopeManager) then
    FScopeManager.Free;
  SetLength(FStateStack, 0);
  inherited Destroy;
end;

function TScopedStackPool.Alloc(aSize: SizeUInt; aAlignment: SizeUInt): Pointer;
begin
  if aAlignment = 0 then
    aAlignment := FPolicy.DefaultAlignment;

  Result := inherited Alloc(aSize, aAlignment);

  if Result = nil then
  begin
    // 如果分配失败且启用自动增长，尝试扩容
    if FPolicy.EnableAutoGrow then
    begin
      GrowPool(aSize);
      Result := inherited Alloc(aSize, aAlignment);
    end;
  end;

  if (Result <> nil) and FPolicy.EnableStatistics then
    UpdateStatistics(aSize);
end;

function TScopedStackPool.CreateScope: TStackPoolScope;
begin
  if Assigned(FScopeManager) then
    Result := FScopeManager.PushScope
  else
    Result := TStackPoolScope.Create(Self);
end;

function TScopedStackPool.PushState: Boolean;
begin
  Result := False;

  if FStateStackTop >= FMaxStateStack - 1 then
  begin
    // 扩展状态栈
    FMaxStateStack := FMaxStateStack * 2;
    SetLength(FStateStack, FMaxStateStack);
  end;

  Inc(FStateStackTop);
  FStateStack[FStateStackTop] := SaveState;
  Result := True;
end;

function TScopedStackPool.PopState: Boolean;
begin
  Result := False;

  if FStateStackTop < 0 then Exit;

  RestoreState(FStateStack[FStateStackTop]);
  Dec(FStateStackTop);
  Result := True;
end;

function TScopedStackPool.GetStateStackDepth: Integer;
begin
  Result := FStateStackTop + 1;
end;

function TScopedStackPool.AllocAligned(aSize: SizeUInt; aAlignment: SizeUInt): Pointer;
begin
  Result := Alloc(aSize, aAlignment);
end;

function TScopedStackPool.AllocZeroed(aSize: SizeUInt; aAlignment: SizeUInt): Pointer;
begin
  Result := Alloc(aSize, aAlignment);
  if Result <> nil then
    FillChar(Result^, aSize, 0);
end;

function TScopedStackPool.AllocString(aLength: SizeUInt): PChar;
begin
  Result := PChar(AllocZeroed(aLength + 1, 1)); // +1 for null terminator
end;

function TScopedStackPool.AllocArray(aElementSize: SizeUInt; aCount: SizeUInt; aAlignment: SizeUInt): Pointer;
var
  LTotalSize: SizeUInt;
begin
  // ✅ m-3: 添加溢出检查
  if (aCount > 0) and (aElementSize > High(SizeUInt) div aCount) then
    Exit(nil);  // 溢出，返回 nil
  LTotalSize := aElementSize * aCount;
  Result := AllocZeroed(LTotalSize, aAlignment);
end;

function TScopedStackPool.GetStatistics: TStackPoolStatistics;
begin
  Result := Default(TStackPoolStatistics);
  if FPolicy.EnableStatistics then
  begin
    FStatistics.CurrentUsage := UsedSize;
    FStatistics.FragmentationRatio := CalculateFragmentation;
    Result := FStatistics;
  end;
end;

procedure TScopedStackPool.ResetStatistics;
begin
  FillChar(FStatistics, SizeOf(FStatistics), 0);
end;

function TScopedStackPool.GetFragmentation: Double;
begin
  Result := CalculateFragmentation;
end;

procedure TScopedStackPool.Optimize;
begin
  // 简化实现：栈池通常不需要优化，因为是顺序分配
  // 实际应用中可以实现内存整理等功能
end;

function TScopedStackPool.GetMemoryMap(out aMap: array of TStackMemoryMapEntry): Integer;
begin
  // 简化实现：返回单个已使用块
  Result := 0;
  if Length(aMap) > 0 then
  begin
    aMap[0].Start := FBuffer;
    aMap[0].Size := UsedSize;
    aMap[0].Used := True;
    Result := 1;
  end;
end;

procedure TScopedStackPool.UpdateStatistics(aAllocSize: SizeUInt);
begin
  if not FPolicy.EnableStatistics then Exit;

  Inc(FStatistics.TotalAllocations);
  FStatistics.TotalBytes := FStatistics.TotalBytes + aAllocSize;
  FStatistics.CurrentUsage := UsedSize;

  if FStatistics.CurrentUsage > FStatistics.PeakUsage then
    FStatistics.PeakUsage := FStatistics.CurrentUsage;
end;

procedure TScopedStackPool.GrowPool(aRequiredSize: SizeUInt);
var
  LNewSize, LMinRequired: SizeUInt;
  LNewBuffer: Pointer;
  LOldUsedSize: SizeUInt;
begin
  if not FPolicy.EnableAutoGrow then Exit;

  // ✅ C-2: 安全检查 - 如果有活跃作用域，禁止扩容（避免指针悬空）
  if Assigned(FScopeManager) and (FScopeManager.GetScopeDepth > 0) then
    raise EStackPoolError.Create(aeInternalError,
      'Cannot grow pool while scopes are active (would invalidate existing pointers)');

  // 计算最小所需大小
  LMinRequired := UsedSize + aRequiredSize;

  // 按增长因子计算新大小
  LNewSize := Round(FSize * FPolicy.GrowthFactor);

  // 确保新大小足够容纳所需
  if LNewSize < LMinRequired then
    LNewSize := LMinRequired;

  if LNewSize > FPolicy.MaxSize then
    LNewSize := FPolicy.MaxSize;

  if LNewSize <= FSize then Exit; // 无法增长

  // 分配新缓冲区
  LNewBuffer := FBaseAllocator.GetMem(LNewSize);
  if LNewBuffer = nil then Exit;

  // 复制现有数据
  LOldUsedSize := UsedSize;
  if LOldUsedSize > 0 then
    Move(FBuffer^, LNewBuffer^, LOldUsedSize);

  // 释放旧缓冲区
  FBaseAllocator.FreeMem(FBuffer);

  // 更新池状态
  FBuffer := LNewBuffer;
  FSize := LNewSize;
end;

function TScopedStackPool.CalculateFragmentation: Double;
begin
  // 栈池的碎片化很简单：已使用空间 / 总空间
  if FSize = 0 then
    Result := 0.0
  else
    Result := 1.0 - (UsedSize / FSize);
end;

// ============================================================================
// TAutoStackPoolScope
// ============================================================================

class function TAutoStackPoolScope.Initialize(aPool: TScopedStackPool): TAutoStackPoolScope;
begin
  Result.FScope := aPool.CreateScope;
  Result.FActive := True;
end;

procedure TAutoStackPoolScope.Finalize;
begin
  if FActive and Assigned(FScope) then
  begin
    FScope.Free;
    FScope := nil;
    FActive := False;
  end;
end;

function TAutoStackPoolScope.Alloc(aSize: SizeUInt; aAlignment: SizeUInt): Pointer;
begin
  if FActive and Assigned(FScope) then
    Result := FScope.Alloc(aSize, aAlignment)
  else
    Result := nil;
end;

end.
