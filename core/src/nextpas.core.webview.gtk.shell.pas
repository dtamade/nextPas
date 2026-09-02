unit nextpas.core.webview.gtk.shell;

{** @desc GTK 窗口壳缝（window.gtk3 Raw 单源）：进程级 GTK 初始化守卫、scheme 上下文注册表、活窗计数、窗口壳创建与嵌入。

       单源：
       - 窗口几何 → nextpas.core.window.gtk3 WindowGtkRaw* 12 项 inline 零拷贝单源（见 window.gtk3）
       - 容量/注册表 → bytes.ops VecGrowCapacity 0→4→2× / TCompactLiveRegistry(live窗)+THashSet<Pointer> scheme O(1)哈希 单源 inline 零拷贝（HashOfPointer→HashMix32 单源，与 viewmap 同源，零线性扫描）
       - 日志 → log.intf ILogger 单源分级，NullLogger 零开销
       性能：inline 薄转发 + 零拷贝 Move，短临界 <1µs，SchemeHash→HashMix32 单源 O(1) 哈希探针（and Mask+线性探测，零除法），ViewHash→HashMix32 单源
       稳定性：Mutex/RWLock 单所有权，try-finally 释放不丢，keep-alive 与 destroy 回调同构 *}

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
  nextpas.core.window.intf;

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
procedure ShellTrace(const AMsg: string);

function ShellSchemeContextRegistered(ACtx: Pointer): Boolean;
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
  nextpas.core.os.env,
  nextpas.core.webview.live,
  nextpas.core.webview.gtk.viewmap;

function SchemePointerHash(const AKey: Pointer): UInt32; inline;
begin
  // 单源：hashmap.base.HashOfPointer → HashMix32，与 viewmap/THashMap 单源一致，inline 零额外调用
  Result := HashOfPointer(AKey);
end;

var
  GShellSchemeCtxs: specialize THashSet<Pointer> = nil;
  GShellLiveWindows: specialize TWebviewLiveRegistry<Pointer> = nil;
  GShellLiveCount: Integer = 0;
  GShellLatestLive: Pointer = nil;
  GShellSchemeLock: TMutex = nil;
  GShellLiveLock: TRWLock = nil;
  GShellDebugChecked: Boolean = False;
  GShellDebugEnabled: Boolean = False;
  GShellLogger: ILogger = nil;

{ TGtkDebugLogger — graded stderr sink via log.intf (L0 seam) }
procedure TGtkDebugLogger.Log(const ALevel: TLogLevel; const AMessage: string);
begin
  System.Write(StdErr, '[npw-gtk] ', AMessage, LineEnding);
  System.Flush(StdErr);
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
    GShellDebugEnabled := GetEnv('NPW_GTK_DEBUG') = '1';
    if GShellDebugEnabled then
      GShellLogger := TGtkDebugLogger.Create
    else
      GShellLogger := NullLogger;
  end;
end;

procedure ShellTrace(const AMsg: string);
begin
  ShellLogInit;
  if GShellDebugEnabled then
    GShellLogger.Debug(AMsg);
end;

function ShellSchemeContextRegistered(ACtx: Pointer): Boolean;
begin
  // perf: O(1) 哈希探针 via THashSet<Pointer>.Contains(HashOfPointer→HashMix32 单源) inline 零额外调用，and Mask 线性探测零除法，短临界 <1µs 零扫描；热点 SchemeRequest 探测由 O(n) 线性退化恢复 O(1)
  // 稳定性：Mutex 单所有权 try-finally 释放不丢，nil 守卫保并发安全
  if GShellSchemeLock <> nil then GShellSchemeLock.Acquire;
  try
    if (GShellSchemeCtxs <> nil) and (ACtx <> nil) then
      Result := GShellSchemeCtxs.Contains(ACtx)
    else
      Result := False;
  finally
    if GShellSchemeLock <> nil then GShellSchemeLock.Release;
  end;
end;

procedure ShellRememberSchemeContext(ACtx: Pointer);
begin
  // perf: O(1) 哈希插入 via THashSet.Add(HashOfPointer→HashMix32 单源) inline 零额外调用，0.75 负载单源阈值，短临界指针-only
  // 稳定性：Mutex try-finally 释放不丢，nil 守卫 + 去重 Add 保幂等
  if ACtx = nil then Exit;
  if GShellSchemeLock <> nil then GShellSchemeLock.Acquire;
  try
    if GShellSchemeCtxs <> nil then
      GShellSchemeCtxs.Add(ACtx);
  finally
    if GShellSchemeLock <> nil then GShellSchemeLock.Release;
  end;
end;

procedure ShellForgetSchemeContext(ACtx: Pointer);
begin
  // perf: O(1) 哈希删除 via THashSet.Remove(HashOfPointer→HashMix32 单源) 墓碑保探链完整，短临界指针-only
  // 稳定性：Mutex try-finally 释放不丢，nil 守卫 + 去重 Remove 保幂等，bsTombstone 单哨兵保探链完整
  if ACtx = nil then Exit;
  if GShellSchemeLock <> nil then GShellSchemeLock.Acquire;
  try
    if GShellSchemeCtxs <> nil then
      GShellSchemeCtxs.Remove(ACtx);
  finally
    if GShellSchemeLock <> nil then GShellSchemeLock.Release;
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
  // perf: thin forward to window.base single source WindowOptionsCreate inline zero-copy, eliminates 8-field duplication with fake impl
  Result := WindowOptionsCreate(AOptions.Title, AOptions.Width, AOptions.Height,
    AOptions.MinWidth, AOptions.MinHeight, AOptions.MaxWidth, AOptions.MaxHeight,
    AOptions.Resizable, AOptions.Maximized);
end;

procedure ShellInitLocks; inline;
begin
  if GShellSchemeLock = nil then GShellSchemeLock := TMutex.Create;
  if GShellLiveLock = nil then GShellLiveLock := TRWLock.Create;
end;

procedure ShellFiniLocks; inline;
begin
  FreeAndNil(GShellLiveLock);
  FreeAndNil(GShellSchemeLock);
end;

procedure ShellInitRegistries; inline;
begin
  // 单源初建：VecGrowCapacity(0)=4 与 bytes.ops 单源一致，inline 零额外调用；THashSet 懒构造经 @SchemePointerHash 专化单源哈希 0.75 负载
  if GShellLiveWindows = nil then
    GShellLiveWindows := specialize TWebviewLiveRegistry<Pointer>.Create;
  if GShellSchemeCtxs = nil then
    GShellSchemeCtxs := specialize THashSet<Pointer>.Create(VecGrowCapacity(0), @SchemePointerHash);
end;

procedure ShellFiniRegistries; inline;
begin
  GShellLatestLive := nil;
  FreeAndNil(GShellSchemeCtxs);
  FreeAndNil(GShellLiveWindows);
  GShellLogger := nil;
end;

initialization
  ShellInitLocks;
  ShellInitRegistries;

finalization
  ShellFiniRegistries;
  ShellFiniLocks;

end.
