unit nextpas.core.webview.factory;

{** @desc webview 后端工厂与主循环入口（纯工厂职责）。

       S1 后端可用性事实源：仅 fake 编译内建；gtk 随 S3/S4 接入时把
       ResolveDefaultKind 切到平台优先并接入探测。默认 kind 的选择
       是本单元唯一职责，禁止散落到后端单元。

       工厂只管后端注册/探测/选择与创建分发；Builder 已抽至
       nextpas.core.webview.builder 单元，职责分离，高级感简洁。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.webview.base,
  nextpas.core.webview.intf,
  nextpas.core.webview.fake,
  nextpas.core.window.intf;

{ S1 默认后端（S4 切平台优先逻辑）；显式指定用 CreateWebviewOf }
function DefaultWebviewKind: TWebviewKind;

{ 后端编译内建与运行时可装载的合并事实 }
function WebviewBackendAvailable(AKind: TWebviewKind): Boolean;

{ 创建 fake 窗口（选项先过 CheckWebviewOptions）}
function CreateFakeWebview(
  const AOptions: TWebviewOptions): IWebviewWindow;

function CreateFakeWebviewOn(const AParent: IWindow;
  const AOptions: TWebviewOptions): IWebviewWindow;

{ 按 kind 创建；不可用抛 EWebviewBackendUnavailable（消息含已探测 kind 表）}
function CreateWebviewOf(AKind: TWebviewKind;
  const AOptions: TWebviewOptions): IWebviewWindow;

function CreateWebviewOn(const AParent: IWindow;
  const AOptions: TWebviewOptions): IWebviewWindow;

{ 供 Builder 复用的带 Parent+Kind 路由（表驱动单源，含回退）；parent=nil 时等价 CreateWebviewOf }
function CreateWebviewEx(const AParent: IWindow; AKind: TWebviewKind;
  const AOptions: TWebviewOptions): IWebviewWindow;

{ M6 单泵统一：WebviewRunLoop/WebviewExitLoop 为 WindowRunLoop/WindowExitLoop 的 deprecated shim（inline 转发），单泵归 window.factory }
procedure WebviewRunLoop; inline; deprecated 'Use WindowRunLoop';
procedure WebviewExitLoop; inline; deprecated 'Use WindowExitLoop';

implementation

uses
  nextpas.core.system.typinfo,
  nextpas.core.window.factory,
  nextpas.core.atomic,
  nextpas.core.sync.mutex,
  nextpas.core.webview.base,
  nextpas.core.webview.validation,
  nextpas.core.webview.gtk.loader,
  nextpas.core.webview.gtk,
  nextpas.core.webview.webview2.loader,
  nextpas.core.webview.webview2,
  nextpas.core.webview.wk.loader,
  nextpas.core.webview.wk;

type
  TWebviewProbe = function: Boolean;
  TWebviewCreate = function(const AOptions: TWebviewOptions): IWebviewWindow;
  TWebviewCreateOn = function(const AParent: IWindow; const AOptions: TWebviewOptions): IWebviewWindow;
  TWebviewBackendDesc = record
    Kind: TWebviewKind;
    Probe: TWebviewProbe;
    Create: TWebviewCreate;
    CreateOn: TWebviewCreateOn;
  end;
  PWebviewBackendDesc = ^TWebviewBackendDesc;

var
  GDefaultKind: TWebviewKind = wvFake;
  GDefaultReady: Int32 = 0; { atomic 0/1: ARM 弱内存下 double-checked 首检无锁读需 acquire/release 屏障，避免数据竞争 }
  GAvailProbed: array[TWebviewKind] of Int32 = (0, 0, 0, 0); { atomic 0/1 }
  GAvailYes: array[TWebviewKind] of Int32 = (0, 0, 0, 0); { atomic 0/1 }
  GFactoryLock: TMutex; { L3→L1 sync owner 复用：TMutex 单源，替代 FPC TRTLCriticalSection 直连 RTL，守分层抽象 }

{ ---- 后端注册表：表驱动唯一真相 ---- }

function ProbeFake: Boolean; inline;
begin
  Result := True;
end;

function CreateFake(const AOptions: TWebviewOptions): IWebviewWindow; inline;
begin
  Result := TFakeWebview.Create(AOptions);
end;

function CreateFakeOn(const AParent: IWindow; const AOptions: TWebviewOptions): IWebviewWindow; inline;
begin
  Result := TFakeWebview.CreateOn(AParent, AOptions);
end;

function ProbeGtk: Boolean;
var L: TGtkLoadInfo;
begin
  Result := TryLoadGtkWebkit(L);
end;

function CreateGtk(const AOptions: TWebviewOptions): IWebviewWindow; inline;
begin
  Result := TGtkWebview.Create(AOptions);
end;

function CreateGtkOn(const AParent: IWindow; const AOptions: TWebviewOptions): IWebviewWindow; inline;
begin
  // perf: inline zero-copy真嵌入 via window.gtk3 Raw has-a, L3→L2 single source, Parent nil fallback保持owner纯净
  if AParent = nil then
    Result := TGtkWebview.Create(AOptions)
  else
    Result := TGtkWebview.CreateOn(AParent, AOptions);
end;

function ProbeWebView2: Boolean;
var L: TWebView2LoadInfo;
begin
  Result := TryLoadWebView2(L);
end;

function CreateWebView2(const AOptions: TWebviewOptions): IWebviewWindow; inline;
begin
  Result := TWebView2Webview.Create(AOptions);
end;

function CreateWebView2On(const AParent: IWindow; const AOptions: TWebviewOptions): IWebviewWindow; inline;
begin
  Result := TWebView2Webview.CreateOn(AParent, AOptions);
end;

function ProbeWk: Boolean;
var L: TWkLoadInfo;
begin
  Result := TryLoadWk(L);
end;

function CreateWk(const AOptions: TWebviewOptions): IWebviewWindow; inline;
begin
  Result := TWkWebview.Create(AOptions);
end;

function CreateWkOn(const AParent: IWindow; const AOptions: TWebviewOptions): IWebviewWindow; inline;
begin
  Result := TWkWebview.CreateOn(AParent, AOptions);
end;

var
  WEBVIEW_BACKENDS: array[0..3] of TWebviewBackendDesc;
  BACKENDS_INITED: Boolean = False;

procedure InitBackends; inline;
begin
  if BACKENDS_INITED then Exit;
  // bytes.ops 单源：WEBVIEW_BACKENDS 唯一真相单表驱动，新增后端仅此一处登记，零双表漂移；顺序 Fake首位 + 探测优先 Webview2→Gtk→Wk与window.factory同构高级感极简
  WEBVIEW_BACKENDS[0].Kind := wvFake;     WEBVIEW_BACKENDS[0].Probe := @ProbeFake;     WEBVIEW_BACKENDS[0].Create := @CreateFake;     WEBVIEW_BACKENDS[0].CreateOn := @CreateFakeOn;
  WEBVIEW_BACKENDS[1].Kind := wvWebview2; WEBVIEW_BACKENDS[1].Probe := @ProbeWebView2; WEBVIEW_BACKENDS[1].Create := @CreateWebView2; WEBVIEW_BACKENDS[1].CreateOn := @CreateWebView2On;
  WEBVIEW_BACKENDS[2].Kind := wvGtk;      WEBVIEW_BACKENDS[2].Probe := @ProbeGtk;      WEBVIEW_BACKENDS[2].Create := @CreateGtk;      WEBVIEW_BACKENDS[2].CreateOn := @CreateGtkOn;
  WEBVIEW_BACKENDS[3].Kind := wvWk;       WEBVIEW_BACKENDS[3].Probe := @ProbeWk;       WEBVIEW_BACKENDS[3].Create := @CreateWk;       WEBVIEW_BACKENDS[3].CreateOn := @CreateWkOn;
  BACKENDS_INITED := True;
end;

function FindBackend(AKind: TWebviewKind): PWebviewBackendDesc; inline;
var I: Integer;
begin
  InitBackends;
  for I := Low(WEBVIEW_BACKENDS) to High(WEBVIEW_BACKENDS) do
    if WEBVIEW_BACKENDS[I].Kind = AKind then
      Exit(@WEBVIEW_BACKENDS[I]);
  Result := nil;
end;

function RawProbe(AKind: TWebviewKind): Boolean; inline;
var B: PWebviewBackendDesc;
begin
  if AKind = wvFake then Exit(True);
  B := FindBackend(AKind);
  if (B = nil) or not Assigned(B^.Probe) then Exit(False);
  Result := B^.Probe();
end;

procedure EnsureFactoryLock; inline;
var
  LNew: TMutex;
  LPrev: Pointer;
begin
  { perf: inline 零额外调用；CAS 单次分配无泄漏，并发首访零重复创建，双检零分配 }
  if GFactoryLock <> nil then Exit;
  LNew := TMutex.Create;
  LPrev := InterlockedCompareExchange(PPointer(@GFactoryLock)^, Pointer(LNew), nil);
  if LPrev <> nil then
    LNew.Free;
end;

{$PUSH}{$WARNINGS OFF}
function WebviewBackendAvailable(AKind: TWebviewKind): Boolean;
begin
  if (AKind < Low(TWebviewKind)) or (AKind > High(TWebviewKind)) then Exit(False);
  if AKind = wvFake then Exit(True);
  // ARM 弱内存首检：atomic_load acquire 保证 GAvailYes 可见性，避免无锁读数据竞争
  if atomic_load(GAvailProbed[Ord(AKind)]) <> 0 then
    Exit(atomic_load(GAvailYes[Ord(AKind)]) <> 0);
  EnsureFactoryLock;
  GFactoryLock.Acquire;
  try
    if atomic_load(GAvailProbed[Ord(AKind)]) <> 0 then
      Exit(atomic_load(GAvailYes[Ord(AKind)]) <> 0);
    { perf: inline RawProbe 单锁单探零间隙，去重并发 dlopen，单临界区零重复探测 }
    atomic_store(GAvailYes[Ord(AKind)], Ord(RawProbe(AKind)));
    atomic_thread_fence(mo_release);
    atomic_store(GAvailProbed[Ord(AKind)], 1);
    Result := atomic_load(GAvailYes[Ord(AKind)]) <> 0;
  finally
    GFactoryLock.Release;
  end;
end;
{$POP}

function DefaultWebviewKind: TWebviewKind;
var
  I: Integer;
  LKind: TWebviewKind;
begin
  // ARM 弱内存首检：acquire load 保证 GDefaultKind 可见性
  if atomic_load(GDefaultReady) <> 0 then
  begin
    atomic_thread_fence(mo_acquire);
    Exit(GDefaultKind);
  end;
  EnsureFactoryLock;
  GFactoryLock.Acquire;
  try
    if atomic_load(GDefaultReady) <> 0 then Exit(GDefaultKind);
  finally
    GFactoryLock.Release;
  end;
  // 单源单表驱动：遍历 WEBVIEW_BACKENDS 优先级序（含Fake跳过）零重复分支，bytes.ops Vec单源思想 inline零额外调用
  InitBackends;
  for I := Low(WEBVIEW_BACKENDS) to High(WEBVIEW_BACKENDS) do
  begin
    LKind := WEBVIEW_BACKENDS[I].Kind;
    if LKind = wvFake then Continue;
    if WebviewBackendAvailable(LKind) then
    begin
      GFactoryLock.Acquire;
      try
        if atomic_load(GDefaultReady) <> 0 then Exit(GDefaultKind);
        GDefaultKind := LKind;
        atomic_thread_fence(mo_release);
        atomic_store(GDefaultReady, 1);
        Result := GDefaultKind;
      finally
        GFactoryLock.Release;
      end;
      Exit(Result);
    end;
  end;
  GFactoryLock.Acquire;
  try
    if atomic_load(GDefaultReady) <> 0 then Exit(GDefaultKind);
    GDefaultKind := wvFake;
    atomic_thread_fence(mo_release);
    atomic_store(GDefaultReady, 1);
    if atomic_load(GAvailProbed[Ord(wvFake)]) = 0 then
    begin
      atomic_store(GAvailYes[Ord(wvFake)], 1);
      atomic_thread_fence(mo_release);
      atomic_store(GAvailProbed[Ord(wvFake)], 1);
    end;
    Result := wvFake;
  finally
    GFactoryLock.Release;
  end;
end;

function CreateFakeWebview(
  const AOptions: TWebviewOptions): IWebviewWindow;
begin
  CheckWebviewOptions(AOptions);
  Result := TFakeWebview.Create(AOptions);
end;

function CreateFakeWebviewOn(const AParent: IWindow;
  const AOptions: TWebviewOptions): IWebviewWindow;
begin
  CheckWebviewOptions(AOptions);
  if AParent = nil then
    raise EWebviewInvalidState.Create('CreateFakeWebviewOn: AParent must not be nil');
  Result := TFakeWebview.CreateOn(AParent, AOptions);
end;

{ 单表分发：新增后端仅需在 WEBVIEW_BACKENDS 登记，零重复 case }
function TryCreateForKind(AKind: TWebviewKind; const AParent: IWindow;
  const AOptions: TWebviewOptions; out AWin: IWebviewWindow): Boolean; inline;
var
  B: PWebviewBackendDesc;
begin
  B := FindBackend(AKind);
  if (B = nil) or not Assigned(B^.Probe) or not B^.Probe() then Exit(False);
  if AParent = nil then
  begin
    if not Assigned(B^.Create) then Exit(False);
    AWin := B^.Create(AOptions);
  end
  else
  begin
    if not Assigned(B^.CreateOn) then Exit(False);
    AWin := B^.CreateOn(AParent, AOptions);
  end;
  Result := True;
end;

function CreateWebviewEx(const AParent: IWindow; AKind: TWebviewKind;
  const AOptions: TWebviewOptions): IWebviewWindow;
var
  I: Integer;
  LCand: TWebviewKind;
begin
  if AParent = nil then
    Exit(CreateWebviewOf(AKind, AOptions));
  CheckWebviewOptions(AOptions);
  // 单源单表驱动：优先 AKind，回退按 WEBVIEW_BACKENDS 优先级序（含Fake跳过）零重复分支，bytes.ops单源 inline零拷贝 O(n) n≤3
  if TryCreateForKind(AKind, AParent, AOptions, Result) then Exit;
  InitBackends;
  for I := Low(WEBVIEW_BACKENDS) to High(WEBVIEW_BACKENDS) do
  begin
    LCand := WEBVIEW_BACKENDS[I].Kind;
    if (LCand = AKind) or (LCand = wvFake) then Continue;
    if TryCreateForKind(LCand, AParent, AOptions, Result) then Exit;
  end;
  Result := TFakeWebview.CreateOn(AParent, AOptions);
end;

function CreateWebviewOn(const AParent: IWindow;
  const AOptions: TWebviewOptions): IWebviewWindow;
begin
  Result := CreateWebviewEx(AParent, DefaultWebviewKind, AOptions);
end;

{$PUSH}{$WARNINGS OFF}
function CreateWebviewOf(AKind: TWebviewKind;
  const AOptions: TWebviewOptions): IWebviewWindow;
var
  B: PWebviewBackendDesc;
begin
  if not WebviewBackendAvailable(AKind) then
    raise EWebviewBackendUnavailable.CreateFmt(
      'webview backend "%s" is not available in this build', [
      GetEnumName(TypeInfo(TWebviewKind), Ord(AKind))]);
  B := FindBackend(AKind);
  if (B <> nil) and Assigned(B^.Create) then
    Exit(B^.Create(AOptions));
  raise EWebviewBackendUnavailable.CreateFmt(
    'webview backend "%s" is registered but has no factory yet', [
    GetEnumName(TypeInfo(TWebviewKind), Ord(AKind))]);
end;
{$POP}

procedure WebviewRunLoop; inline;
begin
  WindowRunLoop;
end;

procedure WebviewExitLoop; inline;
begin
  WindowExitLoop;
end;

initialization
  GFactoryLock := TMutex.Create;

finalization
  if GFactoryLock <> nil then
  begin
    GFactoryLock.Free;
    GFactoryLock := nil;
  end;

end.
