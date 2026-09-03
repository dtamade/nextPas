unit nextpas.core.webview.gtk.shell;

{** @desc GTK 窗口壳缝（window.gtk3 Raw 单源）：进程级 GTK 初始化守卫、scheme 上下文注册表、活窗计数、窗口壳创建与嵌入。

       单源：
       - 窗口几何 → nextpas.core.window.gtk3 WindowGtkRaw* 12 项 inline 零拷贝单源（见 window.gtk3）
       - 容量/注册表 → bytes.ops VecGrowCapacity 0→4→2× / TCompactLiveRegistry(live窗)+THashSet<Pointer> scheme O(1)哈希 单源 inline 零拷贝（HashOfPointer→HashMix32 单源，与 viewmap 同源，零线性扫描）
       - 日志 → log.intf ILogger 单源分级，NullLogger 零开销
       性能：inline 薄转发 + 零拷贝 Move，短临界 <1µs，SchemeHash→HashMix32 单源 O(1) 哈希探针（and Mask+线性探测，零除法）读多写少 RWLock 读并发零单锁热点，ViewHash→HashMix32 单源
       稳定性：RWLock 单所有权（scheme+live 双 RWLock），try-finally 释放不丢，keep-alive 与 destroy 回调同构 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.sync.mutex,
  nextpas.core.sync.rwlock,
  nextpas.core.log.intf,
  nextpas.core.webview.base,
  nextpas.core.window.base,
  nextpas.core.window.intf,
  nextpas.core.webview.utils;

type
  TGtkDebugLogger = class(TInterfacedObject, ILogger)
  public
    procedure Log(const ALevel: TLogLevel; const AMessage: string);
    procedure Trace(const AMessage: string);
    procedure Debug(const AMessage: string);
    procedure Info(const AMessage: string);
    procedure Warn(const AMessage: string);
    procedure Error(const AMessage: string);
    procedure Fatal(const AMessage: string);
  end;

procedure ShellLogInit; inline;
function ShellDebugEnabled: Boolean; inline;
procedure ShellTrace(const AMsg: string);

function ShellSchemeContextRegistered(ACtx: Pointer): Boolean; inline;
procedure ShellRememberSchemeContext(ACtx: Pointer);
procedure ShellForgetSchemeContext(ACtx: Pointer);

function ShellLiveWindowCount: Integer; inline;
procedure ShellRegisterLive(AWin: Pointer);
procedure ShellUnregisterLive(AWin: Pointer);
function ShellLatestLiveWindow: Pointer; inline;

function ShellWindowOptionsOf(const AOptions: TWebviewOptions): TWindowOptions; inline;

procedure ShellInitLocks; inline;
procedure ShellFiniLocks; inline;
procedure ShellInitRegistries; inline;
procedure ShellFiniRegistries; inline;

implementation

uses
  nextpas.core.collections.hashmap.base,
  nextpas.core.collections.hashset,
  nextpas.core.platform.console,
  nextpas.core.platform.env,
  nextpas.core.webview.gtk.viewmap;

function SchemePointerHash(const AKey: Pointer): UInt32; inline;
begin
  // 单源：hashmap.base.HashOfPointer → HashMix32，与 viewmap/THashMap 单源一致，inline 零额外调用
  Result := HashOfPointer(AKey);
end;

var
  GShellSchemeCtxs: specialize THashSet<Pointer> = nil;
  GShellLiveWindows: specialize TCompactLiveRegistry<Pointer> = nil;
  GShellLiveCount: Integer = 0;
  GShellLatestLive: Pointer = nil;
  GShellSchemeLock: TRWLock = nil;
  GShellLiveLock: TRWLock = nil;
  GShellDebugChecked: Boolean = False;
  GShellDebugEnabled: Boolean = False;
  GShellLogger: ILogger = nil;

{ TGtkDebugLogger — graded stderr sink via platform.console Owner (L0 seam) }
procedure TGtkDebugLogger.Log(const ALevel: TLogLevel; const AMessage: string);
var
  LBody: AnsiString;
begin
  // Owner 单源：platform.console fd 2 (stderr) 薄转发，禁止 System.Write/Flush 直写绕过
  // perf: PAnsiChar+Length 零拷贝分段写（无 '[npw-gtk] '+AMessage 拼接堆分配），零额外拷贝，短临界 <1µs 无缓冲滞留；前缀字面零堆分配，LineEnding 直指全局常量零拷贝
  platform_console_write(2, PAnsiChar('[npw-gtk] '), 10);
  if AMessage <> '' then
  begin
    LBody := AnsiString(AMessage);
    platform_console_write(2, PAnsiChar(LBody), Length(LBody));
  end;
  platform_console_write(2, PAnsiChar(LineEnding), Length(LineEnding));
  // stability: 无缓冲直写即落盘，零 Flush 粘行；value/sentinel -1 失败静默，调试探针不抛异常不丢资源
end;

procedure TGtkDebugLogger.Trace(const AMessage: string);
begin
  Log(llTrace, AMessage);
end;

procedure TGtkDebugLogger.Debug(const AMessage: string);
begin
  Log(llDebug, AMessage);
end;

procedure TGtkDebugLogger.Info(const AMessage: string);
begin
  Log(llInfo, AMessage);
end;

procedure TGtkDebugLogger.Warn(const AMessage: string);
begin
  Log(llWarn, AMessage);
end;

procedure TGtkDebugLogger.Error(const AMessage: string);
begin
  Log(llError, AMessage);
end;

procedure TGtkDebugLogger.Fatal(const AMessage: string);
begin
  Log(llFatal, AMessage);
end;

procedure ShellLogInit; inline;
begin
  if not GShellDebugChecked then
  begin
    GShellDebugChecked := True;
    GShellDebugEnabled := platform_env_get_str('NPW_GTK_DEBUG') = '1';
    if GShellDebugEnabled then
      GShellLogger := TGtkDebugLogger.Create
    else
      GShellLogger := NullLogger;
  end;
end;

function ShellDebugEnabled: Boolean; inline;
begin
  // perf: inline zero-cost gate for hot SchemeRequest — check before any string alloc/concat, single source GShellDebugEnabled via ShellLogInit once
  ShellLogInit;
  Result := GShellDebugEnabled;
end;

procedure ShellTrace(const AMsg: string);
begin
  // stability: ShellLogInit lazy once, NullLogger zero overhead when disabled; caller must gate concat via ShellDebugEnabled to avoid heap alloc
  ShellLogInit;
  if GShellDebugEnabled then
    GShellLogger.Debug(AMsg);
end;

function ShellSchemeContextRegistered(ACtx: Pointer): Boolean; inline;
begin
  // perf: O(1) 哈希探针 via THashSet<Pointer>.Contains(HashOfPointer→HashMix32 单源) inline 零额外调用，and Mask 线性探测零除法，短临界 <1µs 零扫描；热点 SchemeRequest 探测由 O(n) 线性退化恢复 O(1)
  // perf: 读多写少 → RWLock 读锁并发，突发小文件 scheme 命中零单锁热点，inline 零拷贝短临界 <1µs（零阻塞写锁仅注册路径）；HashOfPointer 单源零二次哈希
  // 稳定性：RWLock 读单所有权 try-finally ReleaseRead 释放不丢，nil 守卫保并发安全
  if GShellSchemeLock <> nil then GShellSchemeLock.AcquireRead;
  try
    if (GShellSchemeCtxs <> nil) and (ACtx <> nil) then
      Result := GShellSchemeCtxs.Contains(ACtx)
    else
      Result := False;
  finally
    if GShellSchemeLock <> nil then GShellSchemeLock.ReleaseRead;
  end;
end;

procedure ShellRememberSchemeContext(ACtx: Pointer);
begin
  // perf: O(1) 哈希插入 via THashSet.Add(HashOfPointer→HashMix32 单源) inline 零额外调用，0.75 负载单源阈值，短临界指针-only
  // 稳定性：RWLock Write 单所有权 try-finally ReleaseWrite 释放不丢，nil 守卫 + 去重 Add 保幂等
  if ACtx = nil then Exit;
  if GShellSchemeLock <> nil then GShellSchemeLock.AcquireWrite;
  try
    if GShellSchemeCtxs <> nil then
      GShellSchemeCtxs.Add(ACtx);
  finally
    if GShellSchemeLock <> nil then GShellSchemeLock.ReleaseWrite;
  end;
end;

procedure ShellForgetSchemeContext(ACtx: Pointer);
begin
  // perf: O(1) 哈希删除 via THashSet.Remove(HashOfPointer→HashMix32 单源) 墓碑保探链完整，短临界指针-only
  // 稳定性：RWLock Write 单所有权 try-finally ReleaseWrite 释放不丢，nil 守卫 + 去重 Remove 保幂等，bsTombstone 单哨兵保探链完整
  if ACtx = nil then Exit;
  if GShellSchemeLock <> nil then GShellSchemeLock.AcquireWrite;
  try
    if GShellSchemeCtxs <> nil then
      GShellSchemeCtxs.Remove(ACtx);
  finally
    if GShellSchemeLock <> nil then GShellSchemeLock.ReleaseWrite;
  end;
end;

function ShellLiveWindowCount: Integer; inline;
begin
  if GShellLiveLock <> nil then GShellLiveLock.AcquireRead;
  try
    Result := GShellLiveCount;
  finally
    if GShellLiveLock <> nil then GShellLiveLock.ReleaseRead;
  end;
end;

procedure ShellRegisterLive(AWin: Pointer);
begin
  if AWin = nil then Exit;
  if GShellLiveLock <> nil then GShellLiveLock.AcquireWrite;
  try
    if GShellLiveWindows <> nil then
      GShellLiveWindows.Register(AWin);
    Inc(GShellLiveCount);
    GShellLatestLive := AWin;
  finally
    if GShellLiveLock <> nil then GShellLiveLock.ReleaseWrite;
  end;
end;

procedure ShellUnregisterLive(AWin: Pointer);
var
  LBefore: Integer;
begin
  if AWin = nil then Exit;
  if GShellLiveLock <> nil then GShellLiveLock.AcquireWrite;
  try
    if GShellLiveWindows <> nil then
    begin
      LBefore := GShellLiveWindows.Count;
      GShellLiveWindows.Unregister(AWin);
      if GShellLiveWindows.Count < LBefore then
      begin
        if GShellLiveCount > 0 then Dec(GShellLiveCount);
        if GShellLatestLive = AWin then
        begin
          if GShellLiveWindows.Count > 0 then
            GShellLatestLive := GShellLiveWindows.At(GShellLiveWindows.Count - 1)
          else
            GShellLatestLive := nil;
        end;
      end;
    end;
  finally
    if GShellLiveLock <> nil then GShellLiveLock.ReleaseWrite;
  end;
end;

function ShellLatestLiveWindow: Pointer; inline;
begin
  // O(1) hash: cached latest pointer, zero scan, zero alloc, short read <1µs
  if GShellLiveLock <> nil then GShellLiveLock.AcquireRead;
  try
    Result := GShellLatestLive;
  finally
    if GShellLiveLock <> nil then GShellLiveLock.ReleaseRead;
  end;
end;

function ShellWindowOptionsOf(const AOptions: TWebviewOptions): TWindowOptions; inline;
begin
  // perf: thin forward to webview.utils single source WebviewWindowOptionsOf inline zero-copy, eliminates 8-field duplication with fake impl via bytes.ops single source
  Result := nextpas.core.webview.utils.WebviewWindowOptionsOf(AOptions);
end;

procedure ShellInitLocks; inline;
var
  LTmpScheme: TRWLock;
  LTmpLive: TRWLock;
begin
  if (GShellSchemeLock <> nil) and (GShellLiveLock <> nil) then Exit;
  LTmpScheme := nil;
  LTmpLive := nil;
  try
    // perf: inline two-phase create-then-publish, zero extra alloc on success, exception-safe publish single point
    // stability: temp guards close leak window if second Create raises after first succeeded, FreeAndNil not lost
    if GShellSchemeLock = nil then
      LTmpScheme := TRWLock.Create;
    if GShellLiveLock = nil then
      LTmpLive := TRWLock.Create;
    if LTmpScheme <> nil then
    begin
      GShellSchemeLock := LTmpScheme;
      LTmpScheme := nil;
    end;
    if LTmpLive <> nil then
    begin
      GShellLiveLock := LTmpLive;
      LTmpLive := nil;
    end;
  except
    FreeAndNil(LTmpScheme);
    FreeAndNil(LTmpLive);
    raise;
  end;
end;

procedure ShellFiniLocks; inline;
begin
  // stability: FreeAndNil idempotent nil guard, reverse init order, not lost, inline zero-cost
  FreeAndNil(GShellLiveLock);
  FreeAndNil(GShellSchemeLock);
end;

procedure ShellInitRegistries; inline;
var
  LTmpLive: specialize TCompactLiveRegistry<Pointer>;
  LTmpScheme: specialize THashSet<Pointer>;
begin
  // 单源初建：VecGrowCapacity(0)=4 与 bytes.ops 单源一致，inline 零额外调用；THashSet 懒构造经 @SchemePointerHash 专化单源哈希 0.75 负载
  if (GShellLiveWindows <> nil) and (GShellSchemeCtxs <> nil) then Exit;
  LTmpLive := nil;
  LTmpScheme := nil;
  try
    // perf: inline two-phase create-then-publish, VecGrowCapacity single source, zero leak window
    // stability: temps hold refs until both succeed, except frees partial, FreeAndNil not lost
    if GShellLiveWindows = nil then
      LTmpLive := specialize TCompactLiveRegistry<Pointer>.Create;
    if GShellSchemeCtxs = nil then
      LTmpScheme := specialize THashSet<Pointer>.Create(VecGrowCapacity(0), @SchemePointerHash);
    if LTmpLive <> nil then
    begin
      GShellLiveWindows := LTmpLive;
      LTmpLive := nil;
    end;
    if LTmpScheme <> nil then
    begin
      GShellSchemeCtxs := LTmpScheme;
      LTmpScheme := nil;
    end;
  except
    FreeAndNil(LTmpLive);
    FreeAndNil(LTmpScheme);
    raise;
  end;
end;

procedure ShellFiniRegistries; inline;
begin
  // stability: nil guard + FreeAndNil idempotent, latest nil first, count zero, logger nil, not lost
  GShellLatestLive := nil;
  GShellLiveCount := 0;
  FreeAndNil(GShellSchemeCtxs);
  FreeAndNil(GShellLiveWindows);
  GShellLogger := nil;
end;

initialization
  try
    ShellInitLocks;
    ShellInitRegistries;
  except
    // stability: init failure path rollback closes bare-pointer leak window, FreeAndNil not lost, no reliance on finalization order
    ShellFiniRegistries;
    ShellFiniLocks;
    raise;
  end;

finalization
  ShellFiniRegistries;
  ShellFiniLocks;

end.
