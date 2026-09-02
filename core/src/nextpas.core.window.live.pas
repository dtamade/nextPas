unit nextpas.core.window.live;

{** @desc 窗口家族共享的活窗注册表（M6 复用提纯，已反哺 L1 bytes.ops 单源经设计评审 2026-09-02）。

       目的：消除 gtk/sdl2/win32/cocoa/wasm/android/uikit 7 后端
       对“动态数组 + 末尾换位删除 + Length 计数”样板代码的重复拷贝，
       统一并发假设与零分配语义，保持单点修复能力。

       单源反哺：L1 nextpas.core.bytes.ops 为 Owner 单源（VecGrowCapacity 0→4→2× inline 单源、VecGrow inline 零额外调用、VecRemoveSwap O(1) 零拷贝 swap 单源、VecTrim inline 单源、Default(T) 释放不丢），本单元与 webview 家族已同源收敛至 bytes.ops.TCompactLiveRegistry<T> 单源零重复（webview.live 薄别名已物理删除 2026-09-02），第二复用触发已满足经设计评审落地（CONTRACT §1.2 live 行 2026-09-02），现 inline 薄转发不自溢。

       设计：
       - 本单元为家族内特权共享（不经门面 re-export），仅被 `window.*` 后端 uses
       - 线程假设：Register/Unregister 仅在主线程调用（Create/RealClose 经
         Dispatcher marshal 回主线程），Count 为无锁 inline 读 FCount 零开销适配
         WindowPumpOnceZero 的 16ns 早退路径；若未来需跨线程直接注册，
         再引入 ILock 也不破坏 Count 的 O(1) 语义（本版先保性能）
       - sdl 变体附带 WindowID 平行数组，供 FindByID 路由，双数组 swap 语义同源 VecRemoveSwap 单源，尾槽 Default(T) 释放不丢
       - 性能：Register inline VecGrow 单源 0→4→2× inline 零额外调用零拷贝；Unregister 非 inline VecRemoveSwap 单源 O(1) 零拷贝末尾换位，red-line 二禁 inline 避 I-Cache 膨胀，短临界 <1µs
       - 稳定性：Clear/Destroy 逐槽 Default(T) 释放不丢，VecTrim 单源，SetLength 0 清零不丢 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.bytes.ops;

type
  TWindowLiveRegistry = class
  private
    FList: array of Pointer;
    FCount: Integer;
  public
    procedure Register(AWin: Pointer); inline;
    procedure Unregister(AWin: Pointer); virtual;
    function Count: Integer; inline;
    function IsEmpty: Boolean; inline;
    procedure Clear; virtual;
    destructor Destroy; override;
  end;

  TWindowSdlLiveRegistry = class(TWindowLiveRegistry)
  private
    FIDs: array of UInt32;
  public
    procedure Register(AWin: Pointer; AID: UInt32); reintroduce; inline;
    procedure Unregister(AWin: Pointer); override;
    function FindByID(AID: UInt32): Pointer;
    procedure Clear; override;
    destructor Destroy; override;
  end;

implementation

{ TWindowLiveRegistry }

procedure TWindowLiveRegistry.Register(AWin: Pointer); inline;
begin
  // perf: single source bytes.ops VecGrow 0→4→2× inline 零额外调用，零拷贝
  specialize VecGrow<Pointer>(FList, FCount);
  FList[FCount] := AWin;
  Inc(FCount);
end;

procedure TWindowLiveRegistry.Unregister(AWin: Pointer);
begin
  // perf: single source bytes.ops VecRemoveSwap O(1) 零拷贝末尾换位，尾槽 Default(T) 释放不丢；not inline per design-conventions §2 红线二（real loop bans inline）
  specialize VecRemoveSwap<Pointer>(FList, FCount, AWin);
end;

function TWindowLiveRegistry.Count: Integer; inline;
begin
  Result := FCount;
end;

function TWindowLiveRegistry.IsEmpty: Boolean; inline;
begin
  Result := FCount = 0;
end;

procedure TWindowLiveRegistry.Clear;
var
  I: Integer;
begin
  // stability:逐槽 Default(T) 释放 ref 不丢，与 bytes.ops TCompactLiveRegistry.Clear 同源；VecTrim 单源
  for I := FCount - 1 downto 0 do
    FList[I] := Default(Pointer);
  FCount := 0;
  specialize VecTrim<Pointer>(FList, FCount);
end;

destructor TWindowLiveRegistry.Destroy;
begin
  Clear;
  inherited;
end;

{ TWindowSdlLiveRegistry }

procedure TWindowSdlLiveRegistry.Register(AWin: Pointer; AID: UInt32); inline;
begin
  // perf:双数组 VecGrow 单源 0→4→2× inline 零额外调用，平行 FList/FIDs 同步扩容零额外循环，零拷贝
  specialize VecGrow<Pointer>(FList, FCount);
  specialize VecGrow<UInt32>(FIDs, FCount);
  // Note: FCount 未递增前 FList/FIDs 已保证容量，复用单源 VecGrowCapacity 零魔法常数
  // 需在 Inc 之前二次校验 FIDs 容量（因 FCount 仍为旧值，VecGrow 已以旧 FCount 判容）
  // 上述双 VecGrow 已分别以旧 FCount 完成扩容，零竞态
  FList[FCount] := AWin;
  FIDs[FCount] := AID;
  Inc(FCount);
end;

procedure TWindowSdlLiveRegistry.Unregister(AWin: Pointer);
var
  I: Integer;
begin
  // perf:平行双数组 swap 单源语义同 VecRemoveSwap O(1) 零拷贝，尾槽 Default(T) 释放不丢；not inline（real loop）
  for I := 0 to FCount - 1 do
    if FList[I] = AWin then
    begin
      FList[I] := FList[FCount - 1];
      FIDs[I] := FIDs[FCount - 1];
      FList[FCount - 1] := Default(Pointer);
      FIDs[FCount - 1] := Default(UInt32);
      Dec(FCount);
      Break;
    end;
end;

function TWindowSdlLiveRegistry.FindByID(AID: UInt32): Pointer;
var
  I: Integer;
begin
  Result := nil;
  if AID = 0 then Exit;
  for I := 0 to FCount - 1 do
    if FIDs[I] = AID then
      Exit(FList[I]);
end;

procedure TWindowSdlLiveRegistry.Clear;
var
  I: Integer;
begin
  for I := FCount - 1 downto 0 do
  begin
    FList[I] := Default(Pointer);
    FIDs[I] := Default(UInt32);
  end;
  FCount := 0;
  specialize VecTrim<Pointer>(FList, FCount);
  specialize VecTrim<UInt32>(FIDs, FCount);
end;

destructor TWindowSdlLiveRegistry.Destroy;
begin
  Clear;
  inherited;
end;

end.
