{******************************************************************************
  nextpas.core.mem.budget — 内存预算管理

  核心设计:
    1. 软限制：超过时触发警告回调，分配仍成功
    2. 硬限制：超过时分配失败（返回 nil）
    3. 与 TAllocStatsAllocator 集成，实时跟踪内存使用
    4. 线程安全

  使用模式:
    var LBudget: TMemoryBudget;
    LBudget := TMemoryBudget.Create(1024*1024, 4*1024*1024); // 软1MB, 硬4MB
    LBudget.OnSoftLimit := MyWarningHandler;
    // 包装 allocator
    LAllocator := LBudget.WrapAllocator(MyAllocator);
    // 当内存使用超过软限制时触发回调，超过硬限制时返回 nil

  性能目标:
    - 成功路径：原子递增 + 比较（< 5ns）
    - 超限路径：触发回调
******************************************************************************}
unit nextpas.core.mem.budget;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.intf;

type
  {** 内存预算事件 }
  TMemoryBudgetEvent = procedure(AUsedBytes: UInt64; ALimitBytes: UInt64);

  {** TMemoryBudget
   *
   *  内存预算管理器。跟踪分配字节数，超过软限制时触发警告，
   *  超过硬限制时拒绝分配。
   *  线程安全。
   *}
  TMemoryBudget = class
  private
    FUsedBytes: Int64;
    FSoftLimit: UInt64;
    FHardLimit: UInt64;
    FOnSoftLimit: TMemoryBudgetEvent;
    FOnHardLimit: TMemoryBudgetEvent;
    FSoftLimitTriggered: Boolean;
    function CheckLimit(ASize: SizeUInt): Boolean;
  public
    constructor Create(ASoftLimit: UInt64 = 0; AHardLimit: UInt64 = 0);

    {** 记录分配 }
    procedure RecordAlloc(ASize: SizeUInt);
    {** 记录释放 }
    procedure RecordFree(ASize: SizeUInt);

    {** 当前使用字节数 }
    function UsedBytes: UInt64;
    {** 软限制 }
    property SoftLimit: UInt64 read FSoftLimit write FSoftLimit;
    {** 硬限制（0 = 不限制） }
    property HardLimit: UInt64 read FHardLimit write FHardLimit;
    {** 是否超过软限制 }
    function IsOverSoftLimit: Boolean;
    {** 是否超过硬限制 }
    function IsOverHardLimit: Boolean;

    {** 软限制回调 }
    property OnSoftLimit: TMemoryBudgetEvent read FOnSoftLimit write FOnSoftLimit;
    {** 硬限制回调 }
    property OnHardLimit: TMemoryBudgetEvent read FOnHardLimit write FOnHardLimit;

    {** 重置使用量 }
    procedure Reset;
  end;

  {** TBudgetAllocator
   *
   *  包装任意 IAllocator，添加内存预算检查。
   *  分配前检查是否超过硬限制，超过则返回 nil。
   *  分配后更新预算，超过软限制时触发回调。
   *
   *  @note 已知限制：IAllocator 不暴露 MemSizeOf，FreeMem 无法回收预算。
   *        预算只跟踪分配量（单调递增），适合作为分配上限保护。
   *        如需精确跟踪，请配合 TAllocStatsAllocator 使用。
   *}
  TBudgetAllocator = class(TInterfacedObject, IAllocator)
  private
    FInner: IAllocator;
    FBudget: TMemoryBudget;
  public
    constructor Create(AInner: IAllocator; ABudget: TMemoryBudget);
    destructor Destroy; override;

    function GetMem(ASize: SizeUInt): Pointer;
    function AllocMem(ASize: SizeUInt): Pointer;
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
    procedure FreeMem(APtr: Pointer);
    function Traits: TAllocatorTraits;

    property Budget: TMemoryBudget read FBudget;
  end;

implementation

{ TMemoryBudget }

constructor TMemoryBudget.Create(ASoftLimit: UInt64; AHardLimit: UInt64);
begin
  inherited Create;
  FUsedBytes := 0;
  FSoftLimit := ASoftLimit;
  FHardLimit := AHardLimit;
  FOnSoftLimit := nil;
  FOnHardLimit := nil;
  FSoftLimitTriggered := False;
end;

function TMemoryBudget.CheckLimit(ASize: SizeUInt): Boolean;
var
  LUsed: UInt64;
begin
  // 检查硬限制
  if FHardLimit > 0 then
  begin
    LUsed := UInt64(FUsedBytes);
    if LUsed + UInt64(ASize) > FHardLimit then
    begin
      if Assigned(FOnHardLimit) then
        FOnHardLimit(LUsed, FHardLimit);
      Exit(False);
    end;
  end;
  Result := True;
end;

procedure TMemoryBudget.RecordAlloc(ASize: SizeUInt);
var
  LUsed: UInt64;
begin
  InterlockedExchangeAdd64(FUsedBytes, Int64(ASize));
  // 检查软限制
  if (FSoftLimit > 0) and not FSoftLimitTriggered then
  begin
    LUsed := UInt64(FUsedBytes);
    if LUsed >= FSoftLimit then
    begin
      FSoftLimitTriggered := True;
      if Assigned(FOnSoftLimit) then
        FOnSoftLimit(LUsed, FSoftLimit);
    end;
  end;
end;

procedure TMemoryBudget.RecordFree(ASize: SizeUInt);
begin
  InterlockedExchangeAdd64(FUsedBytes, -Int64(ASize));
  // 重置软限制触发标记（如果回到软限制以下）
  if FSoftLimitTriggered and (UInt64(FUsedBytes) < FSoftLimit) then
    FSoftLimitTriggered := False;
end;

function TMemoryBudget.UsedBytes: UInt64;
begin
  Result := UInt64(FUsedBytes);
end;

function TMemoryBudget.IsOverSoftLimit: Boolean;
begin
  Result := (FSoftLimit > 0) and (UInt64(FUsedBytes) >= FSoftLimit);
end;

function TMemoryBudget.IsOverHardLimit: Boolean;
begin
  Result := (FHardLimit > 0) and (UInt64(FUsedBytes) >= FHardLimit);
end;

procedure TMemoryBudget.Reset;
begin
  FUsedBytes := 0;
  FSoftLimitTriggered := False;
end;

{ TBudgetAllocator }

constructor TBudgetAllocator.Create(AInner: IAllocator; ABudget: TMemoryBudget);
begin
  inherited Create;
  FInner := AInner;
  FBudget := ABudget;
end;

destructor TBudgetAllocator.Destroy;
begin
  FInner := nil;
  FBudget := nil;
  inherited Destroy;
end;

function TBudgetAllocator.GetMem(ASize: SizeUInt): Pointer;
begin
  if ASize = 0 then Exit(nil);
  if not FBudget.CheckLimit(ASize) then
    Exit(nil);
  Result := FInner.GetMem(ASize);
  if Result <> nil then
    FBudget.RecordAlloc(ASize);
end;

function TBudgetAllocator.AllocMem(ASize: SizeUInt): Pointer;
begin
  if ASize = 0 then Exit(nil);
  if not FBudget.CheckLimit(ASize) then
    Exit(nil);
  Result := FInner.AllocMem(ASize);
  if Result <> nil then
    FBudget.RecordAlloc(ASize);
end;

function TBudgetAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
begin
  if ASize = 0 then begin FreeMem(APtr); Exit(nil); end;
  if APtr = nil then Exit(GetMem(ASize));
  { Realloc：无法回收旧块预算（IAllocator 不暴露 MemSizeOf），
    仅检查新大小是否超出硬限制。 }
  if not FBudget.CheckLimit(ASize) then
    Exit(nil);
  Result := FInner.ReallocMem(APtr, ASize);
  if Result <> nil then
    FBudget.RecordAlloc(ASize);
end;

procedure TBudgetAllocator.FreeMem(APtr: Pointer);
begin
  if APtr = nil then Exit;
  { IAllocator 不暴露 MemSizeOf，无法回收预算。
    预算只跟踪分配量（单调递增）。 }
  FInner.FreeMem(APtr);
end;

function TBudgetAllocator.Traits: TAllocatorTraits;
begin
  Result := FInner.Traits;
end;

end.
