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

Author:    nextpas.core
Contact:   dtamade@gmail.com | QQ Group: 685403987 | QQ:179033731
Copyright: (c) 2025 nextpas.core. All rights reserved.
}

unit nextpas.core.mem.stack_pool;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,            // ValidateAlignArg
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.rtl,   // ResolveAllocator

  nextpas.core.mem.error;

type
  {** 栈池异常 Stack pool exception *}
  EStackPoolError = class(EAllocError);

type
  {** TStackPool 配置参数 *}
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
    function AlignOffset(AOffset, AAlignment: SizeUInt): SizeUInt;

  public
    {**
     * Create
     *
     * @desc 创建栈式内存池
     *       Create stack memory pool
     *
     * @param ASize 总大小 Total size
     * @param AAllocator 基础分配器 Base allocator (optional)
     *}
    constructor Create(ASize: SizeUInt; AAllocator: IAllocator = nil); overload;
    {** 使用配置记录创建栈式内存池 *}
    constructor Create(const AConfig: TStackPoolConfig); overload;

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
     * @param ASize 请求大小 Requested size
     * @param AAlignment 对齐要求 Alignment requirement (default: pointer size)
     * @return 内存指针 Memory pointer
     *}
    function Alloc(ASize: SizeUInt; AAlignment: SizeUInt = SizeOf(Pointer)): Pointer; inline;
    {** 分配对齐内存，对齐值必须 >= SizeOf(Pointer) 且为 2 的幂 *}
    function AllocAligned(ASize: SizeUInt; AAlignment: SizeUInt): Pointer; inline;

    {**
     * TryAlloc
     *
     * @desc 尝试分配（不抛异常），失败返回 False
     *       Try to allocate (no exception), return False on failure
     *}
    function TryAlloc(ASize: SizeUInt; out APtr: Pointer; AAlignment: SizeUInt = SizeOf(Pointer)): Boolean; inline;
    {** 尝试分配对齐内存（不抛异常），失败返回 False *}
    function TryAllocAligned(ASize: SizeUInt; out APtr: Pointer; AAlignment: SizeUInt): Boolean; inline;

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
     * @param AState 状态标记（由 SaveState 返回）State marker (returned by SaveState)
     * @note AState 必须来自同一 pool 实例的 SaveState 调用，否则行为未定义
     *}
    procedure RestoreState(AState: SizeUInt); inline;

    // 属性 Properties
    {** 池总容量（字节） Total capacity in bytes *}
    property TotalSize: SizeUInt read FSize;
    {** 已使用量（字节） Used size in bytes *}
    property UsedSize: SizeUInt read FOffset;
    {** 剩余可用量（字节） Available size in bytes *}
    property AvailableSize: SizeUInt read GetAvailableSize;

    {** 检查栈池是否为空（无分配） *}
    function IsEmpty: Boolean;
    {** 检查栈池是否已满（无剩余空间） *}
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

    {** 返回默认策略：启用统计和作用域跟踪，2x 增长 *}
    class function Default: TStackPoolPolicy; static;
    {** 返回高性能策略：关闭统计和跟踪，最大化吞吐 *}
    class function HighPerformance: TStackPoolPolicy; static;
    {** 返回调试策略：启用调试模式，1.5x 保守增长 *}
    class function Debug: TStackPoolPolicy; static;
  end;

  {** 调试用内存映射条目 *}
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
    {** 创建栈作用域，保存当前池状态 *}
    constructor Create(APool: TScopedStackPool);
    {** 销毁作用域，自动回滚到保存的状态 *}
    destructor Destroy; override;

    {** 在当前作用域中分配内存 *}
    function Alloc(ASize: SizeUInt; AAlignment: SizeUInt = SizeOf(Pointer)): Pointer;

    {** 手动释放作用域（通常由析构函数自动调用） *}
    procedure Release;

    {** 作用域是否活跃（未释放） Whether the scope is active (not released) *}
    property Active: Boolean read FActive;
  end;

  {**
   * TStackPoolScopeManager
   *
   * @desc 栈作用域管理器，管理嵌套作用域
   *}
  TStackPoolScopeManager = class
  private
    FScopes: array of TStackPoolScope;
    FPool: TScopedStackPool;
  public
    {** 创建作用域管理器 *}
    constructor Create(APool: TScopedStackPool);
    {** 销毁管理器，清除所有未释放的作用域 *}
    destructor Destroy; override;

    {** 推入新的作用域，返回作用域对象 *}
    function PushScope: TStackPoolScope;
    {** 弹出并释放最顶层作用域 *}
    procedure PopScope;
    {** 从管理列表中移除指定作用域（不释放对象） *}
    procedure RemoveScope(AScope: TStackPoolScope);
    {** 获取当前最顶层作用域，无作用域时返回 nil *}
    function GetCurrentScope: TStackPoolScope;
    {** 获取当前作用域嵌套深度 *}
    function GetScopeDepth: Integer;
    {** 释放并清除所有作用域 *}
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
   * @warning EnableAutoGrow 使用 relocate-grow；池内已有分配或活跃作用域时
   *          扩容将抛出异常以防止旧指针悬空。
   *}
  TScopedStackPool = class(TStackPool)
  private
    FPolicy: TStackPoolPolicy;
    FStatistics: TStackPoolStatistics;
    FScopeManager: TStackPoolScopeManager;
    FStateStack: array of SizeUInt;
    FStateStackTop: Integer;
    FMaxStateStack: Integer;

    procedure UpdateStatistics(AAllocSize: SizeUInt);
    procedure GrowPool(ARequiredSize: SizeUInt);
    function CanRelocateBufferForGrow: Boolean;
    function CalculateFragmentation: Double;

  public
    {** 创建作用域栈池，指定大小、策略和可选的基础分配器 *}
    constructor Create(ASize: SizeUInt; const APolicy: TStackPoolPolicy; AAllocator: IAllocator = nil);
    {** 销毁作用域栈池，释放所有内部资源 *}
    destructor Destroy; override;

    {** 分配内存（带策略支持） *}
    function Alloc(ASize: SizeUInt; AAlignment: SizeUInt = SizeOf(Pointer)): Pointer; reintroduce;

    {** 创建新的作用域 *}
    function CreateScope: TStackPoolScope;

    {** 推入状态到状态栈 *}
    function PushState: Boolean;

    {** 从状态栈弹出状态 *}
    function PopState: Boolean;

    {** 获取状态栈深度 *}
    function GetStateStackDepth: Integer;

    {** 分配对齐内存 *}
    function AllocAligned(ASize: SizeUInt; AAlignment: SizeUInt): Pointer; reintroduce;

    {** 分配并清零的内存 *}
    function AllocZeroed(ASize: SizeUInt; AAlignment: SizeUInt = 0): Pointer;

    {** 分配字符串内存 *}
    function AllocString(ALength: SizeUInt): PChar;

    {** 分配数组内存 *}
    function AllocArray(AElementSize: SizeUInt; ACount: SizeUInt; AAlignment: SizeUInt = 0): Pointer;

    {** 获取统计信息 *}
    function GetStatistics: TStackPoolStatistics;

    {** 重置统计信息 *}
    procedure ResetStatistics;

    {** 获取碎片化比率 *}
    function GetFragmentation: Double;

    {** 优化池状态 *}
    procedure Optimize;

    {** 获取内存映射信息（调试用） *}
    function GetMemoryMap(out AMap: array of TStackMemoryMapEntry): Integer;

    {** 池策略配置 Pool policy configuration *}
    property Policy: TStackPoolPolicy read FPolicy write FPolicy;
    {** 当前统计信息 Current statistics *}
    property Statistics: TStackPoolStatistics read GetStatistics;
    {** 作用域管理器（可能为 nil） Scope manager (may be nil) *}
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
    {** 初始化自动作用域，关联到指定池 *}
    class function Initialize(APool: TScopedStackPool): TAutoStackPoolScope; static;
    {** 终结自动作用域，回滚分配状态 *}
    procedure Finalize;
    {** 在当前作用域中分配内存 *}
    function Alloc(ASize: SizeUInt; AAlignment: SizeUInt = SizeOf(Pointer)): Pointer;
    {** 自动作用域是否活跃 Whether the auto scope is active *}
    property Active: Boolean read FActive;
  end;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.math,
  nextpas.core.mem;

constructor TStackPool.Create(const AConfig: TStackPoolConfig);
begin
  Create(AConfig.TotalSize, AConfig.Allocator);
  if AConfig.ZeroOnAlloc and (FBuffer <> nil) then
    ZeroMem(FBuffer, FSize);
end;

{ TStackPool }

constructor TStackPool.Create(ASize: SizeUInt; AAllocator: IAllocator);
begin
  inherited Create;

  if ASize = 0 then
    raise EStackPoolError.Create(aeInvalidLayout,
      FormatAllocErrorMsg('TStackPool', 'Create', 'Stack size cannot be zero'));

  FSize := ASize;
  FOffset := 0;

  FBaseAllocator := ResolveAllocator(AAllocator);

  FBuffer := FBaseAllocator.GetMem(ASize);
  if FBuffer = nil then
    raise EOutOfMemory.Create(aeOutOfMemory,
      FormatAllocErrorMsg('TStackPool', 'Create', 'failed to allocate stack buffer (' + IntToStr(Int64(ASize)) + ' bytes)'));
end;

destructor TStackPool.Destroy;
begin
  if FBuffer <> nil then
    FreeMemOf(FBaseAllocator, FBuffer, FSize);
  inherited Destroy;
end;

function TStackPool.Alloc(ASize: SizeUInt; AAlignment: SizeUInt): Pointer;
var
  LAlignedOffset: SizeUInt;
begin
  Result := nil;
  if ASize = 0 then
    Exit;

  // 防御性：对齐为 0 则使用指针大小；且对齐必须为 2 的幂（否则回退为指针大小）
  if AAlignment = 0 then
    AAlignment := SizeOf(Pointer);
  if (AAlignment and (AAlignment - 1)) <> 0 then
    AAlignment := SizeOf(Pointer);

  // 计算对齐后的偏移（中文注释）：按对齐要求向上取整
  LAlignedOffset := AlignOffset(FOffset, AAlignment);

  // 溢出与界限检查
  if (LAlignedOffset > FSize) or (ASize > FSize - LAlignedOffset) then
    Exit;

  // 返回指针并更新偏移（使用类型化指针算术以避免 4055）
  Result := Pointer(PByte(FBuffer) + LAlignedOffset);
  FOffset := LAlignedOffset + ASize;
end;

procedure TStackPool.Reset;
begin
  FOffset := 0;
end;

function TStackPool.SaveState: SizeUInt;
begin
  Result := FOffset;
end;

function TStackPool.TryAlloc(ASize: SizeUInt; out APtr: Pointer; AAlignment: SizeUInt): Boolean;
begin
  APtr := Alloc(ASize, AAlignment);
  Result := APtr <> nil;
end;

procedure TStackPool.RestoreState(AState: SizeUInt);
begin
  if AState <= FSize then
    FOffset := AState;
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

function TStackPool.AllocAligned(ASize: SizeUInt; AAlignment: SizeUInt): Pointer;
begin
  if ASize = 0 then Exit(nil);
  if not ValidateAlignArg(AAlignment) then
    raise EInvalidArgument.Create('TStackPool.AllocAligned: AAlignment must be non-zero, >= pointer size, and power of two');
  Result := Alloc(ASize, AAlignment);
end;

function TStackPool.TryAllocAligned(ASize: SizeUInt; out APtr: Pointer; AAlignment: SizeUInt): Boolean;
begin
  try
    APtr := AllocAligned(ASize, AAlignment);
    Result := APtr <> nil;
  except
    APtr := nil;
    Result := False;
  end;
end;

function TStackPool.AlignOffset(AOffset, AAlignment: SizeUInt): SizeUInt;
var
  LAbs: PtrUInt;
begin
  { Align absolute address (FBuffer + offset), not offset alone — otherwise
    AllocAligned only works when GetMem returned a base already aligned to
    AAlignment (heap freelist dependent). }
  if (AAlignment <= 1) or (FBuffer = nil) then
    Exit(AOffset);
  LAbs := PtrUInt(FBuffer) + AOffset;
  LAbs := (LAbs + PtrUInt(AAlignment - 1)) and not PtrUInt(AAlignment - 1);
  Result := SizeUInt(LAbs - PtrUInt(FBuffer));
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


// ============================================================================
// TStackPoolScope
// ============================================================================

constructor TStackPoolScope.Create(APool: TScopedStackPool);
begin
  inherited Create;
  FPool := APool;
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

function TStackPoolScope.Alloc(ASize: SizeUInt; AAlignment: SizeUInt): Pointer;
begin
  if not FActive then
  begin
    Result := nil;
    Exit;
  end;

  if AAlignment = 0 then
    AAlignment := FPool.Policy.DefaultAlignment;

  Result := FPool.Alloc(ASize, AAlignment);
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

constructor TStackPoolScopeManager.Create(APool: TScopedStackPool);
begin
  inherited Create;
  FPool := APool;
  FScopes := nil;
end;

destructor TStackPoolScopeManager.Destroy;
begin
  ClearAllScopes;
  FScopes := nil;
  inherited Destroy;
end;

function TStackPoolScopeManager.PushScope: TStackPoolScope;
var
  LLen: Integer;
begin
  Result := TStackPoolScope.Create(FPool);
  LLen := Length(FScopes);
  SetLength(FScopes, LLen + 1);
  FScopes[LLen] := Result;

  if FPool.Policy.EnableStatistics then
  begin
    FPool.FStatistics.CurrentScopeDepth := Length(FScopes);
    if Length(FScopes) > FPool.FStatistics.MaxScopeDepth then
      FPool.FStatistics.MaxScopeDepth := Length(FScopes);
  end;
end;

procedure TStackPoolScopeManager.PopScope;
var
  LScope: TStackPoolScope;
  LLen: Integer;
begin
  LLen := Length(FScopes);
  if LLen = 0 then Exit;

  LScope := FScopes[LLen - 1];
  SetLength(FScopes, LLen - 1);
  LScope.Free;

  if FPool.Policy.EnableStatistics then
    FPool.FStatistics.CurrentScopeDepth := Length(FScopes);
end;

procedure TStackPoolScopeManager.RemoveScope(AScope: TStackPoolScope);
var
  LIndex, LLen, I: Integer;
begin
  LLen := Length(FScopes);
  LIndex := -1;
  for I := 0 to LLen - 1 do
    if FScopes[I] = AScope then
    begin
      LIndex := I;
      Break;
    end;
  if LIndex >= 0 then
  begin
    for I := LIndex to LLen - 2 do
      FScopes[I] := FScopes[I + 1];
    SetLength(FScopes, LLen - 1);
    if FPool.Policy.EnableStatistics then
      FPool.FStatistics.CurrentScopeDepth := Length(FScopes);
  end;
end;

function TStackPoolScopeManager.GetCurrentScope: TStackPoolScope;
begin
  if Length(FScopes) > 0 then
    Result := FScopes[High(FScopes)]
  else
    Result := nil;
end;

function TStackPoolScopeManager.GetScopeDepth: Integer;
begin
  Result := Length(FScopes);
end;

procedure TStackPoolScopeManager.ClearAllScopes;
var
  LIndex: Integer;
begin
  for LIndex := High(FScopes) downto 0 do
    FScopes[LIndex].Free;
  FScopes := nil;

  if FPool.Policy.EnableStatistics then
    FPool.FStatistics.CurrentScopeDepth := 0;
end;

// ============================================================================
// TScopedStackPool
// ============================================================================

constructor TScopedStackPool.Create(ASize: SizeUInt; const APolicy: TStackPoolPolicy; AAllocator: IAllocator);
begin
  inherited Create(ASize, AAllocator);

  FPolicy := APolicy;
  ZeroMem(@FStatistics, SizeOf(FStatistics));

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

function TScopedStackPool.Alloc(ASize: SizeUInt; AAlignment: SizeUInt): Pointer;
begin
  if AAlignment = 0 then
    AAlignment := FPolicy.DefaultAlignment;

  Result := inherited Alloc(ASize, AAlignment);

  if Result = nil then
  begin
    // 如果分配失败且启用自动增长，尝试扩容
    if FPolicy.EnableAutoGrow then
    begin
      GrowPool(ASize);
      Result := inherited Alloc(ASize, AAlignment);
    end;
  end;

  if (Result <> nil) and FPolicy.EnableStatistics then
    UpdateStatistics(ASize);
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

function TScopedStackPool.AllocAligned(ASize: SizeUInt; AAlignment: SizeUInt): Pointer;
begin
  if ASize = 0 then Exit(nil);
  if not ValidateAlignArg(AAlignment) then
    raise EInvalidArgument.Create('TScopedStackPool.AllocAligned: AAlignment must be non-zero, >= pointer size, and power of two');
  Result := Alloc(ASize, AAlignment);
end;

function TScopedStackPool.AllocZeroed(ASize: SizeUInt; AAlignment: SizeUInt): Pointer;
begin
  Result := Alloc(ASize, AAlignment);
  if Result <> nil then
    ZeroMem(Result, ASize);
end;

function TScopedStackPool.AllocString(ALength: SizeUInt): PChar;
begin
  Result := PChar(AllocZeroed(ALength + 1, 1)); // +1 for null terminator
end;

function TScopedStackPool.AllocArray(AElementSize: SizeUInt; ACount: SizeUInt; AAlignment: SizeUInt): Pointer;
var
  LTotalSize: SizeUInt;
begin
  // ✅ m-3: 添加溢出检查
  if (ACount > 0) and (AElementSize > High(SizeUInt) div ACount) then
    Exit(nil);  // 溢出，返回 nil
  LTotalSize := AElementSize * ACount;
  Result := AllocZeroed(LTotalSize, AAlignment);
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
  ZeroMem(@FStatistics, SizeOf(FStatistics));
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

function TScopedStackPool.GetMemoryMap(out AMap: array of TStackMemoryMapEntry): Integer;
begin
  // 简化实现：返回单个已使用块
  Result := 0;
  if Length(AMap) > 0 then
  begin
    AMap[0].Start := FBuffer;
    AMap[0].Size := UsedSize;
    AMap[0].Used := True;
    Result := 1;
  end;
end;

procedure TScopedStackPool.UpdateStatistics(AAllocSize: SizeUInt);
begin
  if not FPolicy.EnableStatistics then Exit;

  Inc(FStatistics.TotalAllocations);
  FStatistics.TotalBytes := FStatistics.TotalBytes + AAllocSize;
  FStatistics.CurrentUsage := UsedSize;

  if FStatistics.CurrentUsage > FStatistics.PeakUsage then
    FStatistics.PeakUsage := FStatistics.CurrentUsage;
end;

procedure TScopedStackPool.GrowPool(ARequiredSize: SizeUInt);
var
  LNewSize, LMinRequired: SizeUInt;
  LNewBuffer: Pointer;
  LOldUsedSize: SizeUInt;
begin
  if not FPolicy.EnableAutoGrow then Exit;

  if not CanRelocateBufferForGrow then
    raise EStackPoolError.Create(aeInternalError,
      FormatAllocErrorMsg('TStackPool', 'Release', 'Cannot grow pool while allocations or scopes are active (would invalidate existing pointers)'));

  // 计算最小所需大小
  LMinRequired := UsedSize + ARequiredSize;

  // 按增长因子计算新大小（用整数运算避免大值浮点精度丢失）
  if FPolicy.GrowthFactor <= 1.0 then
    LNewSize := FSize + FSize  // 最少 2x
  else if FPolicy.GrowthFactor >= 2.0 then
    LNewSize := FSize * 2
  else
    LNewSize := FSize + (FSize shr 1);  // 1.5x

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
    CopyMem(LNewBuffer, FBuffer, LOldUsedSize);

  // 释放旧缓冲区（FSize = 原 GetMem 字节数）
  FreeMemOf(FBaseAllocator, FBuffer, FSize);

  // 更新池状态
  FBuffer := LNewBuffer;
  FSize := LNewSize;
end;

function TScopedStackPool.CanRelocateBufferForGrow: Boolean;
begin
  Result := UsedSize = 0;
  if Result and Assigned(FScopeManager) then
    Result := FScopeManager.GetScopeDepth = 0;
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

class function TAutoStackPoolScope.Initialize(APool: TScopedStackPool): TAutoStackPoolScope;
begin
  Result.FScope := APool.CreateScope;
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

function TAutoStackPoolScope.Alloc(ASize: SizeUInt; AAlignment: SizeUInt): Pointer;
begin
  if FActive and Assigned(FScope) then
    Result := FScope.Alloc(ASize, AAlignment)
  else
    Result := nil;
end;

end.
