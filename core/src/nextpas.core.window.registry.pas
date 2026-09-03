unit nextpas.core.window.registry;

{ Registry — dynamic backend table (CONTRACT §4.3, L2 internal). }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.base,
  nextpas.core.window.intf,
  nextpas.core.window.queue,
  nextpas.core.window.live,
  nextpas.core.sync.intf,
  nextpas.core.window.registry.types;

type
  TBackendProbe = nextpas.core.window.registry.types.TBackendProbe;
  TBackendCreate = nextpas.core.window.registry.types.TBackendCreate;
  TBackendLive = nextpas.core.window.registry.types.TBackendLive;
  TBackendRun = nextpas.core.window.registry.types.TBackendRun;
  TBackendQuit = nextpas.core.window.registry.types.TBackendQuit;
  TBackendPump = nextpas.core.window.registry.types.TBackendPump;
  TBackendDesc = nextpas.core.window.registry.types.TBackendDesc;
  PBackendDesc = nextpas.core.window.registry.types.PBackendDesc;

procedure RegistryRegister(const ADesc: TBackendDesc);
procedure RegistryEnsureInited;
function RegistryFindBackend(AKind: TWindowKind): PBackendDesc;
function RegistryBackendAvailable(AKind: TWindowKind): Boolean;
function RegistryDefaultKind: TWindowKind;
function RegistryBackendDiagnostics: string;

// Live 聚合（gtk 家族求和，O(n)≤11 有界，解耦 window.gtk.impl）
function RegistryLiveGtkSmart: Integer;

// Dispatcher 单例（registry 托管，CreateEvent/TWindowQueue 单源，双重检查+互斥）
function RegistryEnsureDispatcherQueue: TWindowQueue;
function RegistryEnsureDispatcherWait: IEvent;

// Live 注册表工厂托管：window.live 单源 WindowFamilyToken 工厂复用，inline 零拷贝，消 8 后端重复手写 Create(WindowFamilyToken)
function RegistryCreateLiveRegistry: TWindowLiveRegistry; inline;
function RegistryCreateSdlLiveRegistry: TWindowSdlLiveRegistry; inline;
function RegistryEnsureLiveRegistry(var AReg: TWindowLiveRegistry): TWindowLiveRegistry; inline;
function RegistryEnsureSdlLiveRegistry(var AReg: TWindowSdlLiveRegistry): TWindowSdlLiveRegistry; inline;

// 创建/Run/Quit 聚合（与 ProbeGtk 同源，gtk4>gtk3>gtk2 智能回退）
function RegistryCreateGtkSmart(const AOptions: TWindowOptions): IWindow;
procedure RegistryRunGtkSmart;
procedure RegistryQuitGtkSmart;

// ParentHandle 桌面拦截单源：GRegistry.DesktopSet 集合位测 O(1) inline 零拷贝，desktop=win32/cocoa/gtk4/gtk3/gtk2/qt/sdl2 由 CBackendOrder[0..10] 11元过滤派生，attach=android/uikit/wasm/fake 不拒；wkGtk 为 wkGtk3 deprecated 别名不单列
function RegistryIsDesktopKind(AKind: TWindowKind): Boolean; inline;

// RunLoop / Pump 委托（factory 薄转发，原语归 registry 单源，仅聚合委托，不承载探测/诊断构建）
procedure RegistryRunLoop;
procedure RegistryExitLoop;
function RegistryPumpOnce: Boolean;
procedure RegistryPumpAll;

implementation

uses
  nextpas.core.exception, // Exception 自有根（owner=exception，L0）：后端裸异常兜底吞噬，不直连 FPC SysUtils
  nextpas.core.diagnostics, // L1 diagnostics → text.format/utils L0-L1 only, L2→L1 合规无迂回上依赖
  nextpas.core.atomic, // L0 原子聚合单源
  nextpas.core.bytes.ops, // L1 bytes.ops 单源 WindowGrowCapacity 0→32→2×
  nextpas.core.platform.sync,
  nextpas.core.platform.thread,
  nextpas.core.sync.event,
  nextpas.core.window.impl,
  nextpas.core.window.fake;

var
  GExitRequested: Int32 = 0;
  GRegistryLock: TPlatformMutex;
  GLockInited: Boolean = False;
  GDispatcherQueue: TWindowQueue = nil;
  GDispatcherWait: IEvent = nil;
  GFinalQueueTmp: TWindowQueue = nil;
  GRegistry: TWindowRegistry;

procedure EnsurePriorityMapInited;
begin
  if GRegistry.PriorityInited then Exit;
  // 调用方持锁（RegistryRegister）或单线程 init，无需二次加锁，双检已在 Registry 封装内
  GRegistry.EnsurePriorityLocked;
end;

procedure EnsureDesktopSetCold; // cold: not inline, 单次 O(11) 互斥外联，热路径零锁
var LLockRet: Int32;
begin
  if atomic_load(GRegistry.DesktopInited) <> 0 then Exit;
  if not GLockInited then
  begin
    GRegistry.EnsureDesktopLocked;
    atomic_store(GRegistry.DesktopInited, Int32(1));
    Exit;
  end;
  LLockRet := platform_mutex_lock(GRegistryLock);
  if LLockRet <> 0 then
  begin
    if atomic_load(GRegistry.DesktopInited) = 0 then
    begin
      GRegistry.EnsureDesktopLocked;
      atomic_store(GRegistry.DesktopInited, Int32(1));
    end;
    Exit;
  end;
  try
    if atomic_load(GRegistry.DesktopInited) = 0 then
    begin
      GRegistry.EnsureDesktopLocked;
      atomic_store(GRegistry.DesktopInited, Int32(1));
    end;
  finally
    platform_mutex_unlock(GRegistryLock);
  end;
end;

procedure EnsureBackendCapacity; inline;
begin
  // bytes.ops 单源扩容 0→32→2×，Registry 记录内联托管
  GRegistry.EnsureCapacity;
end;

function BackendPriority(AKind: TWindowKind): Integer; inline;
begin
  // 调用方持锁或已初始化后只读，inline 单次数组读零拷贝
  Result := GRegistry.PriorityOf(AKind);
end;

function RegistryIsDesktopKind(AKind: TWindowKind): Boolean; inline;
begin
  // 热路径纯 inline O(1) BT 零拷贝零堆零锁：DesktopSet 于 initialization eager 单源派生 CBackendOrder[11] 过滤，atomic_load acquire 快路径零额外拷贝无 mutex；冷路径 EnsureDesktopSetCold 单次 O(11) 互斥外联避 I-Cache 膨胀，消冷热混用拉低零拷贝纯粹性，bytes.ops 单源思想
  if atomic_load(GRegistry.DesktopInited) = 0 then EnsureDesktopSetCold;
  Result := AKind in GRegistry.DesktopSet;
end;

function ProbeFakeAlways: Boolean; inline;
begin
  Result := True;
end;

function RegistryCreateFake(const AOptions: TWindowOptions): IWindow;
begin
  Result := TFakeWindow.Create(AOptions);
end;

function LiveFake: Integer;
begin
  Result := FakeLiveWindowCount;
end;

procedure RunFake;
begin
  while atomic_load(GExitRequested) = 0 do
  begin
    if FakeLiveWindowCount > 0 then FakePumpAll else Break;
    if FakeLiveWindowCount = 0 then Break;
    if atomic_load(GExitRequested) <> 0 then Break;
    FakeWaitForActivity(Int64(-1));
    if atomic_load(GExitRequested) <> 0 then Break;
  end;
end;

procedure QuitFake;
begin
  FakeNotifyWaiter;
end;

function RegistryLiveGtkSmart: Integer;
var I, LSnap: Integer;
begin
  // fast path: WindowTotalLiveCount single read, O(1)
  if WindowTotalLiveCount = 0 then Exit(0);
  Result := 0;
  LSnap := atomic_load(GRegistry.Count);
  if LSnap > CBackendCount then LSnap := CBackendCount;
  if LSnap < 0 then LSnap := 0;
  for I := 0 to LSnap - 1 do
    if IsGtkFamilyKind(GRegistry.Backends[I].Kind) then
      if Assigned(GRegistry.Backends[I].Live) then
        Inc(Result, GRegistry.Backends[I].Live());
end;

function RegistryEnsureDispatcherQueue: TWindowQueue;
var LLockRet: Int32;
begin
  // 外联：含锁与堆分配禁 inline，避免热路径复制锁逻辑
  if atomic_load(GExitRequested) <> 0 then
  begin
  end else if GDispatcherQueue <> nil then Exit(GDispatcherQueue);
  if not GLockInited then
    raise EWindowInvalidState.Create('window registry lock not initialized');
  LLockRet := platform_mutex_lock(GRegistryLock);
  if LLockRet <> 0 then
    raise EWindowInvalidState.CreateFmt('window registry lock failed: %d', [LLockRet]);
  try
    if (GDispatcherQueue = nil) and (atomic_load(GExitRequested) = 0) then
      GDispatcherQueue := TWindowQueue.Create(WindowFamilyToken);
    Result := GDispatcherQueue;
  finally
    platform_mutex_unlock(GRegistryLock);
  end;
end;

function RegistryEnsureDispatcherWait: IEvent;
var LLockRet: Int32;
begin
  // 外联：含锁与接口分配禁 inline
  if atomic_load(GExitRequested) <> 0 then
  begin
  end else if GDispatcherWait <> nil then Exit(GDispatcherWait);
  if not GLockInited then
    raise EWindowInvalidState.Create('window registry lock not initialized');
  LLockRet := platform_mutex_lock(GRegistryLock);
  if LLockRet <> 0 then
    raise EWindowInvalidState.CreateFmt('window registry lock failed: %d', [LLockRet]);
  try
    if (GDispatcherWait = nil) and (atomic_load(GExitRequested) = 0) then
      GDispatcherWait := CreateEvent(False);
    Result := GDispatcherWait;
  finally
    platform_mutex_unlock(GRegistryLock);
  end;
end;

function RegistryCreateLiveRegistry: TWindowLiveRegistry; inline;
begin
  // 单源托管：委托 window.live WindowLiveRegistryCreate 单源 WindowFamilyToken，inline 零拷贝，消 8 后端重复
  Result := WindowLiveRegistryCreate;
end;

function RegistryCreateSdlLiveRegistry: TWindowSdlLiveRegistry; inline;
begin
  Result := WindowSdlLiveRegistryCreate;
end;

function RegistryEnsureLiveRegistry(var AReg: TWindowLiveRegistry): TWindowLiveRegistry; inline;
begin
  // 单源托管：复用 WindowLiveRegistryEnsure 单源，inline 零拷贝 O(1)，资源托管不丢，与 Dispatcher 托管镜像
  if AReg = nil then AReg := RegistryCreateLiveRegistry;
  Result := AReg;
end;

function RegistryEnsureSdlLiveRegistry(var AReg: TWindowSdlLiveRegistry): TWindowSdlLiveRegistry; inline;
begin
  if AReg = nil then AReg := RegistryCreateSdlLiveRegistry;
  Result := AReg;
end;

function GtkFallbackKind(AIdx: Integer): TWindowKind; inline;
begin
  Result := CBackendOrder[CGtkFallbackStart + AIdx];
end;

function FindGtkBackendAt(AIdx: Integer): PBackendDesc; inline;
var I: Integer;
  LKind: TWindowKind;
  LSnap: Int32;
begin
  Result := nil;
  if (AIdx < 0) or (AIdx >= CGtkFallbackCount) then Exit;
  LKind := GtkFallbackKind(AIdx);
  LSnap := atomic_load(GRegistry.Count);
  for I := 0 to LSnap - 1 do
    if GRegistry.Backends[I].Kind = LKind then Exit(@GRegistry.Backends[I]);
end;

function FindGtkBackendIndex(AIdx: Integer): Integer; inline;
var I: Integer; LKind: TWindowKind; LSnap: Int32;
begin
  Result := -1;
  if (AIdx < 0) or (AIdx >= CGtkFallbackCount) then Exit;
  LKind := GtkFallbackKind(AIdx);
  LSnap := atomic_load(GRegistry.Count);
  for I := 0 to LSnap - 1 do
    if GRegistry.Backends[I].Kind = LKind then Exit(I);
end;

function CachedProbeCold(AIndex: Integer; LKind: TWindowKind): Boolean; // cold: not inline, 互斥+dlopen 单次，热路径零锁
var LLockRet: Int32; LRes: Boolean;
begin
  if not GLockInited then
  begin
    Result := GRegistry.Backends[AIndex].Probe();
    Exit(Result);
  end;
  LLockRet := platform_mutex_lock(GRegistryLock);
  if LLockRet <> 0 then
  begin
    Result := GRegistry.Backends[AIndex].Probe();
    Exit(Result);
  end;
  try
    if atomic_load(GRegistry.ProbeValid[LKind]) <> 0 then Exit(atomic_load(GRegistry.ProbeCache[LKind]) <> 0);
    LRes := GRegistry.Backends[AIndex].Probe();
    atomic_store(GRegistry.ProbeCache[LKind], Int32(Ord(LRes)));
    atomic_store(GRegistry.ProbeValid[LKind], Int32(1));
    Result := LRes;
  finally
    platform_mutex_unlock(GRegistryLock);
  end;
end;

function CachedProbe(AIndex: Integer): Boolean; inline;
var LKind: TWindowKind;
begin
  // 冷热分离：热路径 atomic_load acquire 零拷贝无锁 O(1) 读 ProbeValid/Cache，消重复 dlopen；冷路径 CachedProbeCold 单次互斥+Probe 探测+atomic_store release 发布，零额外堆，bytes.ops 单源思想
  if (AIndex < 0) or (AIndex >= atomic_load(GRegistry.Count)) then Exit(False);
  if not Assigned(GRegistry.Backends[AIndex].Probe) then Exit(False);
  LKind := GRegistry.Backends[AIndex].Kind;
  if atomic_load(GRegistry.ProbeValid[LKind]) <> 0 then Exit(atomic_load(GRegistry.ProbeCache[LKind]) <> 0);
  Result := CachedProbeCold(AIndex, LKind);
end;

type
  TGtkVisitor = reference to procedure(B: PBackendDesc; var AStop: Boolean);

procedure EnumerateProbedGtkBackends(const AVisitor: TGtkVisitor);
var P, LIdx: Integer; B: PBackendDesc; LStop: Boolean;
begin
  // 外联：含 for+Probe 路由禁 inline避 I-Cache 复制膨胀；单源迭代器 gtk4>gtk3>gtk2 零重复分支，GRegistry.ProbeCache O(1) 零重复 dlopen 单源
  LStop := False;
  for P := 0 to CGtkFallbackCount - 1 do
  begin
    LIdx := FindGtkBackendIndex(P);
    if LIdx < 0 then Continue;
    if not CachedProbe(LIdx) then Continue;
    B := @GRegistry.Backends[LIdx];
    AVisitor(B, LStop);
    if LStop then Exit;
  end;
end;

function RegistryCreateGtkSmart(const AOptions: TWindowOptions): IWindow;
var LResult: IWindow; LFound: Boolean;
begin
  // 单源复用 EnumerateProbedGtkBackends，消三函数重复 for+Probe 循环，inline 零拷贝 Probe 委托
  LFound := False; LResult := nil;
  EnumerateProbedGtkBackends(procedure(B: PBackendDesc; var Stop: Boolean)
  begin
    if Assigned(B^.Create) then begin LResult := B^.Create(AOptions); Stop := True; LFound := True; end;
  end);
  if LFound then Exit(LResult);
  raise EWindowBackendUnavailable.Create('GTK backend not available (all families failed)');
end;

procedure RegistryRunGtkSmart;
var LFound: Boolean;
begin
  // 两阶段回退复用同一迭代器：先活窗>0，再任意可用，单源 Probe 零重复
  LFound := False;
  EnumerateProbedGtkBackends(procedure(B: PBackendDesc; var Stop: Boolean)
  begin
    if Assigned(B^.Live) and Assigned(B^.Run) and (B^.Live() > 0) then begin B^.Run(); Stop := True; LFound := True; end;
  end);
  if LFound then Exit;
  EnumerateProbedGtkBackends(procedure(B: PBackendDesc; var Stop: Boolean)
  begin
    if Assigned(B^.Run) then begin B^.Run(); Stop := True; end;
  end);
end;

procedure RegistryQuitGtkSmart;
begin
  // 全量 Quit 复用迭代器，单源 Probe+Quit，异常吞噬不丢稳定性
  EnumerateProbedGtkBackends(procedure(B: PBackendDesc; var Stop: Boolean)
  begin
    if Assigned(B^.Quit) then
      try B^.Quit(); except on E: Exception do ; end;
  end);
end;

procedure RegistryRegister(const ADesc: TBackendDesc);
var
  I, InsertIdx, LPrio: Integer;
  LLockRet: Int32;
begin
  if atomic_load(GRegistry.Inited) = 1 then
    raise EWindowInvalidState.CreateFmt('window registry late register rejected after init: %s', [WindowKindName(ADesc.Kind)]);
  if not GLockInited then
    raise EWindowInvalidState.Create('window registry lock not initialized');
  LLockRet := platform_mutex_lock(GRegistryLock);
  if LLockRet <> 0 then
    raise EWindowInvalidState.CreateFmt('window registry lock failed: %d', [LLockRet]);
  try
    if atomic_load(GRegistry.Inited) = 1 then
      raise EWindowInvalidState.CreateFmt('window registry late register rejected after init (locked): %s', [WindowKindName(ADesc.Kind)]);
    for I := 0 to GRegistry.Count - 1 do
      if GRegistry.Backends[I].Kind = ADesc.Kind then Exit;
    EnsureBackendCapacity;
    EnsurePriorityMapInited;
    LPrio := BackendPriority(ADesc.Kind);
    InsertIdx := GRegistry.Count;
    for I := 0 to GRegistry.Count - 1 do
      if LPrio < BackendPriority(GRegistry.Backends[I].Kind) then
      begin
        InsertIdx := I;
        Break;
      end;
    if InsertIdx < GRegistry.Count then
    begin
      for I := GRegistry.Count - 1 downto InsertIdx do
        GRegistry.Backends[I + 1] := GRegistry.Backends[I];
      GRegistry.Backends[InsertIdx] := ADesc;
    end
    else
      GRegistry.Backends[GRegistry.Count] := ADesc;
    atomic_fetch_add(GRegistry.Count, Int32(1));
    atomic_store(GRegistry.PumpLastIdx, Int32(-1));
  finally
    platform_mutex_unlock(GRegistryLock);
  end;
end;

procedure RegistryEnsureInited;
var
  I: Integer;
  LDesc: TBackendDesc;
  HasFake: Boolean;
  LLockRet: Int32;
begin
  if atomic_load(GRegistry.Inited) = 1 then Exit;
  if not GLockInited then
    raise EWindowInvalidState.Create('window registry lock not initialized');
  LLockRet := platform_mutex_lock(GRegistryLock);
  if LLockRet <> 0 then
    raise EWindowInvalidState.CreateFmt('window registry lock failed: %d', [LLockRet]);
  try
    if atomic_load(GRegistry.Inited) = 1 then Exit;
    if GRegistry.Count = 0 then
    begin
      EnsureBackendCapacity;
      LDesc.Kind := wkFake;
      LDesc.Probe := @ProbeFakeAlways;
      LDesc.Create := @RegistryCreateFake;
      LDesc.Live := @LiveFake;
      LDesc.Run := @RunFake;
      LDesc.Quit := @QuitFake;
      LDesc.Pump := nil;
      LDesc.Sonames := '';
      GRegistry.Backends[0] := LDesc;
      atomic_store(GRegistry.Count, Int32(1));
      atomic_store(GRegistry.PumpLastIdx, Int32(-1));
    end
    else
    begin
      HasFake := False;
      for I := 0 to GRegistry.Count - 1 do
        if GRegistry.Backends[I].Kind = wkFake then
        begin
          HasFake := True;
          Break;
        end;
      if not HasFake then
      begin
        EnsureBackendCapacity;
        LDesc.Kind := wkFake;
        LDesc.Probe := @ProbeFakeAlways;
        LDesc.Create := @RegistryCreateFake;
        LDesc.Live := @LiveFake;
        LDesc.Run := @RunFake;
        LDesc.Quit := @QuitFake;
        LDesc.Pump := nil;
        LDesc.Sonames := '';
        GRegistry.Backends[GRegistry.Count] := LDesc;
        atomic_fetch_add(GRegistry.Count, Int32(1));
        atomic_store(GRegistry.PumpLastIdx, Int32(-1));
      end;
    end;
    atomic_store(GRegistry.Inited, 1);
  finally
    platform_mutex_unlock(GRegistryLock);
  end;
end;

function RegistryFindBackend(AKind: TWindowKind): PBackendDesc;
var I: Integer;
begin
  RegistryEnsureInited;
  for I := 0 to GRegistry.Count - 1 do
    if GRegistry.Backends[I].Kind = AKind then
      Exit(@GRegistry.Backends[I]);
  Result := nil;
end;

function RegistryBackendAvailable(AKind: TWindowKind): Boolean;
var I: Integer;
begin
  RegistryEnsureInited;
  for I := 0 to GRegistry.Count - 1 do
    if GRegistry.Backends[I].Kind = AKind then
      Exit(CachedProbe(I));
  if AKind = wkGtk then
  begin
    for I := 0 to GRegistry.Count - 1 do
      if (GRegistry.Backends[I].Kind = wkGtk) or IsGtkFamilyKind(GRegistry.Backends[I].Kind) then
        if CachedProbe(I) then Exit(True);
    Exit(False);
  end;
  Result := False;
end;

function RegistryDefaultKind: TWindowKind;
var I: Integer;
begin
  RegistryEnsureInited;
  for I := 0 to GRegistry.Count - 1 do
    if CachedProbe(I) then
      Exit(GRegistry.Backends[I].Kind);
  Result := wkFake;
end;

function GetSonamesForKind(AKind: TWindowKind): string;
var I: Integer;
begin
  for I := 0 to GRegistry.Count - 1 do
    if GRegistry.Backends[I].Kind = AKind then
      Exit(GRegistry.Backends[I].Sonames);
  Result := '';
end;

function RegistryBackendDiagnostics: string;
var
  I: Integer;
  LAvail: Boolean;
  LDetail: string;
  B: TDiagnosticsBuilder;
begin
  RegistryEnsureInited;
  B.Clear;
  for I := 0 to GRegistry.Count - 1 do
  begin
    LAvail := CachedProbe(I);
    if GRegistry.Backends[I].Sonames <> '' then
      LDetail := 'sonames: ' + GRegistry.Backends[I].Sonames
    else if GRegistry.Backends[I].Kind = wkFake then
      LDetail := 'builtin'
    else if GRegistry.Backends[I].Kind = wkGtk then
      LDetail := 'sonames: ' + GetSonamesForKind(wkGtk4) + '|' + GetSonamesForKind(wkGtk3) + '|' + GetSonamesForKind(wkGtk2) + '; smart fallback gtk4>gtk3>gtk2'
    else
      LDetail := '';
    B.Add(WindowKindName(GRegistry.Backends[I].Kind), LAvail, LDetail);
  end;
  Result := B.Build;
end;

procedure RegistryRunLoop;
var
  I: Integer;
  B: PBackendDesc;
  LAllZero: Boolean;
begin
  RegistryEnsureInited;
  atomic_store(GExitRequested, 0);
  for I := 0 to GRegistry.Count - 1 do
  begin
    B := @GRegistry.Backends[I];
    if Assigned(B^.Live) and Assigned(B^.Run) and (B^.Live() > 0) and CachedProbe(I) then
    begin
      B^.Run();
      Exit;
    end;
  end;
  while atomic_load(GExitRequested) = 0 do
  begin
    for I := 0 to GRegistry.Count - 1 do
    begin
      B := @GRegistry.Backends[I];
      if Assigned(B^.Live) and Assigned(B^.Run) and (B^.Live() > 0) and CachedProbe(I) then
      begin
        B^.Run();
        Exit;
      end;
    end;
    if FakeLiveWindowCount > 0 then FakePumpAll
    else Break;
    LAllZero := True;
    for I := 0 to GRegistry.Count - 1 do
      if Assigned(GRegistry.Backends[I].Live) and (GRegistry.Backends[I].Live() > 0) then
      begin
        LAllZero := False;
        Break;
      end;
    if LAllZero and (FakeLiveWindowCount = 0) and (RegistryLiveGtkSmart = 0) then Break;
    FakeWaitForActivity(Int64(-1));
    if atomic_load(GExitRequested) <> 0 then Break;
  end;
end;

procedure RegistryExitLoop;
var I: Integer;
begin
  RegistryEnsureInited;
  atomic_store(GExitRequested, 1);
  for I := 0 to GRegistry.Count - 1 do
    if Assigned(GRegistry.Backends[I].Quit) and CachedProbe(I) then
      try
        GRegistry.Backends[I].Quit();
      except
        on E: Exception do
          ;
      end;
  FakeNotifyWaiter;
end;

function RegistryPumpOnce: Boolean;
var
  B: PBackendDesc;
  LDid: Boolean;
  LCachedIdx, LSnapCount, LIdx: Integer;
begin
  // fast path: single WindowTotalLiveCount read, 16ns
  if WindowTotalLiveCount = 0 then Exit(False);
  if atomic_load(GExitRequested) <> 0 then Exit(False);
  Result := False;
  LSnapCount := atomic_load(GRegistry.Count);
  if LSnapCount > CBackendCount then LSnapCount := CBackendCount;
  if LSnapCount < 0 then LSnapCount := 0;
  if FakeHasPendingPosts then
  begin
    FakePumpAll;
    Result := True;
  end;
  if LSnapCount = 0 then Exit(Result);
  LCachedIdx := atomic_load(GRegistry.PumpLastIdx);
  if (LCachedIdx >= 0) and (LCachedIdx < LSnapCount) then
  begin
    if LCachedIdx >= LSnapCount then
    begin
      atomic_store(GRegistry.PumpLastIdx, Int32(-1));
      LCachedIdx := -1;
    end else
    begin
      B := @GRegistry.Backends[LCachedIdx];
      if Assigned(B^.Pump) then
      begin
        // 零 Live 预读：直接 Pump，Pump 内已判空/无活窗返回 False，单次 Pump 零额外 Live 原子，回退按需再探
        LDid := B^.Pump();
        if LDid then Exit(True);
        // Pump 未做功：若后端已无活窗清缓存，供回退重探；单次 Live 零重复聚合
        if Assigned(B^.Live) and (B^.Live() = 0) then
        begin
          atomic_store(GRegistry.PumpLastIdx, Int32(-1));
          LCachedIdx := -1;
        end;
      end else
      begin
        atomic_store(GRegistry.PumpLastIdx, Int32(-1));
        LCachedIdx := -1;
      end;
    end;
  end else if LCachedIdx >= 0 then
  begin
    atomic_store(GRegistry.PumpLastIdx, Int32(-1));
    LCachedIdx := -1;
  end;
  if LSnapCount = 0 then Exit(Result);
  if (LCachedIdx < 0) or (LCachedIdx >= LSnapCount) then LIdx := 0
  else begin LIdx := LCachedIdx + 1; if LIdx >= LSnapCount then LIdx := 0; end;
  // 回退 O(1) — 单步轮转，复用 LSnapCount 零重复原子
  if (LIdx < 0) or (LIdx >= LSnapCount) then Exit(Result);
  B := @GRegistry.Backends[LIdx];
  if Assigned(B^.Pump) then
  begin
    LDid := B^.Pump();
    if LDid then begin Result := True; atomic_store(GRegistry.PumpLastIdx, Int32(LIdx)); Exit(Result); end;
  end;
end;

procedure RegistryPumpAll;
var
  LSnapCount, LIdx, LScanned, LAnyDid, LBudget: Integer;
  B: PBackendDesc;
  LExit: Int32;
begin
  // fast path: single WindowTotalLiveCount read
  if WindowTotalLiveCount = 0 then Exit;
  if atomic_load(GExitRequested) <> 0 then Exit;
  LSnapCount := atomic_load(GRegistry.Count);
  if LSnapCount > CBackendCount then LSnapCount := CBackendCount;
  if LSnapCount <= 0 then
  begin
    if FakeHasPendingPosts then FakePumpAll;
    Exit;
  end;
  if FakeHasPendingPosts then FakePumpAll;
  LBudget := 32;
  LIdx := atomic_load(GRegistry.PumpLastIdx);
  if (LIdx < 0) or (LIdx >= LSnapCount) then LIdx := 0
  else begin Inc(LIdx); if LIdx >= LSnapCount then LIdx := 0; end;
  repeat
    LAnyDid := 0;
    LScanned := 0;
    repeat
      if (LIdx >= 0) and (LIdx < LSnapCount) then
      begin
        B := @GRegistry.Backends[LIdx];
        if Assigned(B^.Pump) then
          if B^.Pump() then
          begin
            LAnyDid := 1;
            atomic_store(GRegistry.PumpLastIdx, Int32(LIdx));
          end;
      end;
      LIdx := LIdx + 1;
      if LIdx >= LSnapCount then LIdx := 0;
      Inc(LScanned);
    until LScanned >= LSnapCount;
    Dec(LBudget);
    if LAnyDid = 0 then Break;
    if LBudget <= 0 then Break;
    LExit := atomic_load(GExitRequested);
    if LExit <> 0 then Break;
  until False;
end;

// finalization helpers — single-source reset/capture, inline 零拷贝
procedure DoRegistryCaptureAndReset; inline;
var LSnap: Int32;
begin
  GFinalQueueTmp := GDispatcherQueue;
  GDispatcherQueue := nil;
  GDispatcherWait := nil;
  LSnap := atomic_load(GRegistry.Count);
  if LSnap > 0 then ManagedFinalizeArray(@GRegistry.Backends[0], TypeInfo(TBackendDesc), LSnap);
  SetLength(GRegistry.Backends, 0);
  atomic_store(GRegistry.Count, Int32(0));
  atomic_store(GRegistry.PumpLastIdx, Int32(-1));
  atomic_store(GRegistry.Inited, 0);
  FillChar(GRegistry.ProbeValid, SizeOf(GRegistry.ProbeValid), 0);
  FillChar(GRegistry.ProbeCache, SizeOf(GRegistry.ProbeCache), 0);
  atomic_store(GRegistry.DesktopInited, Int32(0));
  GRegistry.DesktopSet := [];
end;

procedure DoRegistryFreeCaptured; inline;
begin
  if GFinalQueueTmp <> nil then
  begin
    GFinalQueueTmp.Free;
    GFinalQueueTmp := nil;
  end;
end;

initialization
  GRegistry.PumpLastIdx := -1;
  if platform_mutex_init(GRegistryLock, PLATFORM_MUTEX_ERRORCHECK) = 0 then GLockInited := True;
  EnsurePriorityMapInited;
  // eager cold init: DesktopSet 单源派生 CBackendOrder[11]，消 RegistryIsDesktopKind 冷热混用 mutex，热路径纯 BT inline 零拷贝
  GRegistry.EnsureDesktopLocked;
  atomic_store(GRegistry.DesktopInited, Int32(1));

finalization
  atomic_store(GExitRequested, 1);
  FakeNotifyWaiter;
  // single-source lock-free reset, GExitRequested gates readers
  DoRegistryCaptureAndReset;
  DoRegistryFreeCaptured;
  if GLockInited then
  begin
    platform_mutex_destroy(GRegistryLock);
    GLockInited := False;
  end;
  atomic_store(GExitRequested, 0);

end.
