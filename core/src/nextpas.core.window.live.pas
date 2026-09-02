unit nextpas.core.window.live;

{** @desc 窗口家族共享的活窗注册表（M6 复用提纯）。

       目的：消除 gtk/sdl2/win32/cocoa/wasm/android/uikit 7 后端
       对“动态数组 + 末尾换位删除 + Length 计数”样板代码的重复拷贝，
       统一并发假设与零分配语义，保持单点修复能力。

       设计：
       - 本单元为家族内特权共享（不经门面 re-export），仅被 `window.*` 后端 uses
       - 线程假设：Register/Unregister 仅在主线程调用（Create/RealClose 经
         Dispatcher marshal 回主线程），Count 为无锁 inline 读，零开销适配
         WindowPumpOnceZero 的 16ns 早退路径；若未来需跨线程直接注册，
         再引入 ILock 也不破坏 Count 的 O(1) 语义（本版先保性能）
       - sdl 变体附带 WindowID 平行数组，供 FindByID 路由
       - 跨家族评估（webview.live 紧凑 Vec 重复）：与 webview.live 已评估，
         二者同复用 bytes.ops 单源思想（webview 侧 VecGrowCapacity 0→4→2×
         inline 零拷贝、VecRemoveSwap O(1) 零拷贝 swap；本单元 n≤7 极小紧凑
         Vec 保持 Length 计数 1-by-1 零额外容量 bookkeeping， swap 语义同源
         bytes.ops），无跨家族重复实现；若抽通用辅助/池模块需反哺 L1
         collections/通用池 owner 并经设计评审，当前不自行外溢（L0-L3 守恒）。 *}

{$I nextpas.core.settings.inc}

interface

type
  TWindowLiveRegistry = class
  private
    FList: array of Pointer;
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

procedure TWindowLiveRegistry.Register(AWin: Pointer);
begin
  SetLength(FList, Length(FList) + 1);
  FList[High(FList)] := AWin;
end;

procedure TWindowLiveRegistry.Unregister(AWin: Pointer);
var
  I: Integer;
begin
  for I := High(FList) downto 0 do
    if FList[I] = AWin then
    begin
      FList[I] := FList[High(FList)];
      SetLength(FList, Length(FList) - 1);
      Break;
    end;
end;

function TWindowLiveRegistry.Count: Integer;
begin
  Result := Length(FList);
end;

function TWindowLiveRegistry.IsEmpty: Boolean;
begin
  Result := Length(FList) = 0;
end;

procedure TWindowLiveRegistry.Clear;
begin
  SetLength(FList, 0);
end;

destructor TWindowLiveRegistry.Destroy;
begin
  Clear;
  inherited;
end;

{ TWindowSdlLiveRegistry }

procedure TWindowSdlLiveRegistry.Register(AWin: Pointer; AID: UInt32);
begin
  inherited Register(AWin);
  SetLength(FIDs, Length(FIDs) + 1);
  FIDs[High(FIDs)] := AID;
end;

procedure TWindowSdlLiveRegistry.Unregister(AWin: Pointer);
var
  I: Integer;
begin
  for I := High(FList) downto 0 do
    if FList[I] = AWin then
    begin
      FList[I] := FList[High(FList)];
      FIDs[I] := FIDs[High(FIDs)];
      SetLength(FList, Length(FList) - 1);
      SetLength(FIDs, Length(FIDs) - 1);
      Break;
    end;
end;

function TWindowSdlLiveRegistry.FindByID(AID: UInt32): Pointer;
var
  I: Integer;
begin
  Result := nil;
  if AID = 0 then Exit;
  for I := 0 to High(FIDs) do
    if FIDs[I] = AID then
      Exit(FList[I]);
end;

procedure TWindowSdlLiveRegistry.Clear;
begin
  inherited Clear;
  SetLength(FIDs, 0);
end;

destructor TWindowSdlLiveRegistry.Destroy;
begin
  Clear;
  inherited;
end;

end.
