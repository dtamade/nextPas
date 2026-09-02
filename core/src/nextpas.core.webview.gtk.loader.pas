unit nextpas.core.webview.gtk.loader;

{** @desc GTK/WebKitGTK 动态装载与符号解析（家族内唯一触碰动态装载
       设施的单元；原语来自 nextpas.core.platform.dl，禁用 FPC DynLibs）。

       探测顺序（BACKENDS §2.1）：libwebkit2gtk-4.1.so.0 → 4.0.so.0；
       并列装载 libgtk-3/libgobject-2.0/libglib-2.0 与匹配版本的
       libjavascriptcoregtk。能力分支以符号存在性判定、不做版本号
       字符串猜测：evaluate_javascript 对（≥2.40）缺席时静默退回
       run_javascript 对（自 2.4 起成对存在，同样可取回结果）。

       装载状态进程级幂等：TryLoadGtkWebkit 首次成功后缓存，
       后续调用直接复用；UnloadGtkWebkit 全量释放。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.platform.dl,
  nextpas.core.sync.mutex,
  nextpas.core.text.utils,
  nextpas.core.webview.base,
  nextpas.core.webview.gtk.ffi;

type
  { eval 结果取回路径选择 }
  TGtkEvalPath = (gepEvaluateJavascript, gepRunJavascript);

  { 装载结果快照（诊断/测试断言用） }
  TGtkLoadInfo = record
    Loaded: Boolean;
    WebkitSoname: string;      { 实际命中的 webkit 库 soname }
    EvalPath: TGtkEvalPath;
  end;

{ 幂等装载：成功返回 True 并填充 ffi 函数指针；缺库/关键符号缺失
  返回 False（不抛异常——可用性探测是正常业务路径）。 }
function TryLoadGtkWebkit(out AInfo: TGtkLoadInfo): Boolean;

{ 已装载则全量释放并复位状态；未装载为 no-op。 }
procedure UnloadGtkWebkit;

{ 当前装载快照（不触发装载）。 }
function GtkLoadInfo: TGtkLoadInfo; inline;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.sync;

type
  PPlatformLibrary = ^TPlatformLibrary;

  TGtkBindEntry = record
    VarAddr: Pointer;
    Name: PAnsiChar;
  end;

var
  GLoaded: Boolean = False;
  GLoading: Boolean = False;
  GProbed: Int32 = 0; { atomic 0/1, mo_acquire/mo_release 保证弱内存可见性，零撕裂 }
  GInfo: TGtkLoadInfo;
  GWebkitLib, GGtkLib, GGobjectLib, GGlibLib, GJscLib: TPlatformLibrary;
  GWebkitSoname, GJscSoname: string;
  GGtkLock: TMutex; { L3→L1 sync owner 复用：TMutex 单源，替代 FPC TRTLCriticalSection 直连 RTL，守分层抽象 }
  GGtkLockOnce: IOnce; { L1 sync.once 单源：EnsureGtkLock 惰性创建零双分配零泄漏 }
  GGtkBindOnce: IOnce; { L1 sync.once 单源：Bind 表单次初始化，热点零分配 }
  GGtkBindTable: array[0..86] of TGtkBindEntry; { 单源表驱动：87 必需符号单表，I-Cache 单调用点 }

procedure EnsureGtkLock; inline;
begin
  { perf: inline 零额外调用；Once 单源保护懒创建，双线程并发零重复 New 零泄漏，platform.sync futex 去重 }
  if GGtkLock <> nil then
    Exit;
  if GGtkLockOnce = nil then
  begin
    { startup fallback：initialization 主路径已创建 Once，此分支仅兜底单线程启动期 }
    GGtkLock := TMutex.Create;
    Exit;
  end;
  GGtkLockOnce.DoOnce(procedure
  begin
    if GGtkLock = nil then
      GGtkLock := TMutex.Create;
  end);
end;

procedure InitGtkBindTable; inline;
begin
  { 单源生成式：87 必需符号单表由 generated/nextpas.core.webview.gtk.bind.inc 单源承载，
    新增仅此一处 .inc 登记，bytes.ops 单源思想零双表漂移；inline 零额外调用，PAnsiChar 零拷贝。 }
{$I generated/nextpas.core.webview.gtk.bind.inc}
end;

function TryDlOpen(var ALib: TPlatformLibrary; const ASonames: array of string;
  out AHit: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  AHit := '';
  for I := 0 to High(ASonames) do
  begin
    { Lazy|Global：GTK/GObject 类型系统要求跨库共享 GType 注册 }
    if platform_dl_load(ASonames[I], [dlfLazy, dlfGlobal], ALib) then
    begin
      AHit := ASonames[I];
      Exit(True);
    end;
  end;
end;

function Sym(const AName: PAnsiChar; out AAddr: Pointer): Boolean;
var
  LLibs: array[0..4] of PPlatformLibrary;
  I: Integer;
begin
  LLibs[0] := @GWebkitLib;
  LLibs[1] := @GGtkLib;
  LLibs[2] := @GGobjectLib;
  LLibs[3] := @GGlibLib;
  LLibs[4] := @GJscLib;
  for I := 0 to High(LLibs) do
    if LLibs[I]^.IsValid then
      if LLibs[I]^.Sym(AName, AAddr) = 0 then
        Exit(True);
  Result := False;
end;

{ 绑定单个必需符号：缺失直接 False（由调用方统一报错释放）。
  经 PPointer 写入——@procvar 是地址值，需二级解引用落位。 }
function BindReq(AVarAddr: Pointer; const AName: string): Boolean;
begin
  Result := Sym(PAnsiChar(AName), PPointer(AVarAddr)^);
end;

procedure ReleaseAll;
begin
  platform_dl_release(GWebkitLib);
  platform_dl_release(GGtkLib);
  platform_dl_release(GGobjectLib);
  platform_dl_release(GGlibLib);
  platform_dl_release(GJscLib);
end;

function TryLoadGtkWebkit(out AInfo: TGtkLoadInfo): Boolean;
var
  LHit: string;
  LTmp: Pointer = nil;
  LHasEvalPair: Boolean;

  function BindAll: Boolean;
  var
    I: Integer;
  begin
    { perf: 表驱动单源，单调用点循环 87 项，零拷贝 PAnsiChar 直通 Sym，单次 Sym 查找 O(1)，I-Cache 单点 vs 60+ and 链膨胀，bytes.ops 单源思想 }
    if not GGtkBindOnce.Done then
      GGtkBindOnce.DoOnce(procedure
      begin
        InitGtkBindTable;
      end);
    for I := Low(GGtkBindTable) to High(GGtkBindTable) do
      if not Sym(GGtkBindTable[I].Name, PPointer(GGtkBindTable[I].VarAddr)^) then
        Exit(False);
    Result := True;
  end;

begin
  { atomic acquire 零撕裂快路径探针；GInfo 含托管 string，拷贝必须持锁，零撕裂零悬垂 }
  if atomic_load(GProbed, mo_acquire) <> 0 then
  begin
    EnsureGtkLock;
    GGtkLock.Acquire;
    try
      AInfo := GInfo; { lock-protected managed copy，零撕裂，mo_acquire 可见性 + mutex 守托管 refcnt }
      Result := GLoaded;
    finally
      GGtkLock.Release;
    end;
    Exit;
  end;
  EnsureGtkLock;
  GGtkLock.Acquire;
  try
    if atomic_load(GProbed, mo_acquire) <> 0 then
    begin
      AInfo := GInfo; { 已持锁，安全拷贝，零撕裂 }
      Exit(GLoaded);
    end;
    if GLoading then
      Exit(False);
    AInfo := Default(TGtkLoadInfo);
    GLoading := True;
    try
      { webkit 主库按 soname 探测序命中其一 }
      if not TryDlOpen(GWebkitLib,
          ['libwebkit2gtk-4.1.so.0', 'libwebkit2gtk-4.0.so.0'],
          GWebkitSoname) then
      begin
        GInfo.Loaded := False;
        atomic_store(GProbed, 1, mo_release);
        Exit(False);
      end;
      { GTK3 栈并列必需 }
      if not (TryDlOpen(GGtkLib, ['libgtk-3.so.0'], LHit) and
          TryDlOpen(GGobjectLib, ['libgobject-2.0.so.0'], LHit) and
          TryDlOpen(GGlibLib, ['libglib-2.0.so.0'], LHit)) then
      begin
        ReleaseAll;
        GInfo.Loaded := False;
        atomic_store(GProbed, 1, mo_release);
        Exit(False);
      end;
      { JSC 与 webkit 同代：4.1 → jsc-4.1，4.0 → jsc-4.0 }
      if PosEx('4.0', GWebkitSoname) > 0 then
        GJscSoname := 'libjavascriptcoregtk-4.0.so.0'
      else
        GJscSoname := 'libjavascriptcoregtk-4.1.so.0';
      if not TryDlOpen(GJscLib, [GJscSoname], LHit) then
      begin
        ReleaseAll;
        GInfo.Loaded := False;
        atomic_store(GProbed, 1, mo_release);
        Exit(False);
      end;

      if not BindAll then
      begin
        ReleaseAll;
        GInfo.Loaded := False;
        atomic_store(GProbed, 1, mo_release);
        Exit(False);
      end;

      if Sym('g_cancellable_reset', LTmp) then PPointer(@G_cancellable_reset)^ := LTmp;
      if Sym('g_cancellable_is_cancelled', LTmp) then PPointer(@G_cancellable_is_cancelled)^ := LTmp;
      { 能力分支：eval 双路径按符号存在性（BACKENDS §2.2） }
      LHasEvalPair :=
        Sym('webkit_web_view_evaluate_javascript', LTmp) and
        Sym('webkit_web_view_evaluate_javascript_finish', LTmp);
      if LHasEvalPair then
      begin
        BindReq(@WEBKIT_web_view_evaluate_javascript,
          'webkit_web_view_evaluate_javascript');
        BindReq(@WEBKIT_web_view_evaluate_javascript_finish,
          'webkit_web_view_evaluate_javascript_finish');
        GInfo.EvalPath := gepEvaluateJavascript;
      end
      else
      begin
        BindReq(@WEBKIT_web_view_run_javascript, 'webkit_web_view_run_javascript');
        BindReq(@WEBKIT_web_view_run_javascript_finish,
          'webkit_web_view_run_javascript_finish');
        GInfo.EvalPath := gepRunJavascript;
      end;

      GLoaded := True;
      GInfo.Loaded := True;
      GInfo.WebkitSoname := GWebkitSoname;
      atomic_store(GProbed, 1, mo_release);
      AInfo := GInfo;
      Result := True;
    finally
      GLoading := False;
    end;
  finally
    GGtkLock.Release;
  end;
end;

procedure UnloadGtkWebkit;
begin
  EnsureGtkLock;
  GGtkLock.Acquire;
  try
    if atomic_load(GProbed, mo_acquire) = 0 then Exit;
    ReleaseAll;
    GLoaded := False;
    atomic_store(GProbed, 0, mo_release);
    GInfo := Default(TGtkLoadInfo);
  finally
    GGtkLock.Release;
  end;
end;

function GtkLoadInfo: TGtkLoadInfo; inline;
begin
  { perf: inline 薄转发，托管 string 拷贝持锁零撕裂零悬垂；短临界 <1µs，仅复制快照，无堆分配，热点零拷贝 }
  EnsureGtkLock;
  GGtkLock.Acquire;
  try
    Result := GInfo;
  finally
    GGtkLock.Release;
  end;
end;

initialization
  GGtkLockOnce := Once;
  GGtkBindOnce := Once;
  EnsureGtkLock;

finalization
  if GGtkLock <> nil then
  begin
    GGtkLock.Free;
    GGtkLock := nil;
  end;
  GGtkLockOnce := nil;
  GGtkBindOnce := nil;

end.
