unit nextpas.core.webview.factory;

{** @desc webview 后端工厂与主循环入口（纯工厂职责）。

       S1 后端可用性事实源：仅 fake 编译内建；gtk 随 S3/S4 接入时把
       ResolveDefaultKind 切到平台优先并接入探测。默认 kind 的选择
       是本单元唯一职责，禁止散落到后端单元。

       工厂只管后端创建分发；探测已抽至 nextpas.core.webview.registry
       独立注册模块候选单源（Probe 单表 + 热点快照复用），Builder 已
       抽至 nextpas.core.webview.builder 单元，职责分离，高级感简洁。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.webview.base,
  nextpas.core.webview.intf,
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

{ 供 Builder 复用的带 Parent+Kind 路由（表驱动单源，显式 Kind fail-fast）；parent=nil 时等价 CreateWebviewOf }
function CreateWebviewEx(const AParent: IWindow; AKind: TWebviewKind;
  const AOptions: TWebviewOptions): IWebviewWindow;

{ M6 单泵统一：WebviewRunLoop/WebviewExitLoop 为 WindowRunLoop/WindowExitLoop 的 deprecated shim（inline 转发），单泵归 window.factory }
procedure WebviewRunLoop; inline; deprecated 'Use WindowRunLoop';
procedure WebviewExitLoop; inline; deprecated 'Use WindowExitLoop';

implementation

uses
  nextpas.core.system.typinfo,
  nextpas.core.window.factory,
  nextpas.core.webview.validation,
  nextpas.core.webview.registry,
  nextpas.core.webview.fake,
  nextpas.core.webview.gtk,
  nextpas.core.webview.webview2,
  nextpas.core.webview.wk;

type
  TWebviewCreate = function(const AOptions: TWebviewOptions): IWebviewWindow;
  TWebviewCreateOn = function(const AParent: IWindow; const AOptions: TWebviewOptions): IWebviewWindow;
  TWebviewFactoryDesc = record
    Kind: TWebviewKind;
    Create: TWebviewCreate;
    CreateOn: TWebviewCreateOn;
  end;
  PWebviewFactoryDesc = ^TWebviewFactoryDesc;

{ ---- 后端创建注册表：不可变声明式表（创建分发唯一真相，探测已抽 registry 候选单源，零耦合） ---- }

function CreateFake(const AOptions: TWebviewOptions): IWebviewWindow; inline;
begin
  Result := TFakeWebview.Create(AOptions);
end;

function CreateFakeOn(const AParent: IWindow; const AOptions: TWebviewOptions): IWebviewWindow; inline;
begin
  Result := TFakeWebview.CreateOn(AParent, AOptions);
end;

function CreateGtk(const AOptions: TWebviewOptions): IWebviewWindow; inline;
begin
  Result := TGtkWebview.Create(AOptions);
end;

function CreateGtkOn(const AParent: IWindow; const AOptions: TWebviewOptions): IWebviewWindow; inline;
begin
  if AParent = nil then
    Result := TGtkWebview.Create(AOptions)
  else
    Result := TGtkWebview.CreateOn(AParent, AOptions);
end;

function CreateWebView2(const AOptions: TWebviewOptions): IWebviewWindow; inline;
begin
  Result := TWebView2Webview.Create(AOptions);
end;

function CreateWebView2On(const AParent: IWindow; const AOptions: TWebviewOptions): IWebviewWindow; inline;
begin
  Result := TWebView2Webview.CreateOn(AParent, AOptions);
end;

function CreateWk(const AOptions: TWebviewOptions): IWebviewWindow; inline;
begin
  Result := TWkWebview.Create(AOptions);
end;

function CreateWkOn(const AParent: IWindow; const AOptions: TWebviewOptions): IWebviewWindow; inline;
begin
  Result := TWkWebview.CreateOn(AParent, AOptions);
end;

const
  WEBVIEW_BACKENDS: array[0..3] of TWebviewFactoryDesc = (
    (Kind: wvFake; Create: @CreateFake; CreateOn: @CreateFakeOn),
    (Kind: wvGtk; Create: @CreateGtk; CreateOn: @CreateGtkOn),
    (Kind: wvWebview2; Create: @CreateWebView2; CreateOn: @CreateWebView2On),
    (Kind: wvWk; Create: @CreateWk; CreateOn: @CreateWkOn)
  );

function FindBackend(AKind: TWebviewKind): PWebviewFactoryDesc; inline;
var I: Integer;
begin
  for I := Low(WEBVIEW_BACKENDS) to High(WEBVIEW_BACKENDS) do
    if WEBVIEW_BACKENDS[I].Kind = AKind then
      Exit(@WEBVIEW_BACKENDS[I]);
  Result := nil;
end;

function WebviewBackendAvailable(AKind: TWebviewKind): Boolean; inline;
begin
  // perf: inline 薄转发至 registry 单源快照复用 O(1) 命中零双检锁/零堆分配，未命中单次 RawProbe 落 loader 双检锁幂等缓存，热点路径零重复 TryLoad*，零拷贝
  Result := nextpas.core.webview.registry.WebviewProbeAvailable(AKind);
end;

function DefaultWebviewKind: TWebviewKind; inline;
begin
  // perf: inline 薄转发至 registry 快照复用 GDefaultSnapshot 命中零循环零 Probe/零双检锁，零拷贝/零堆分配
  Result := nextpas.core.webview.registry.WebviewDefaultKind;
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

{ 单表分发：新增后端仅需在 WEBVIEW_BACKENDS 登记，零重复 case；探测走 registry 快照单源 }
function TryCreateForKind(AKind: TWebviewKind; const AParent: IWindow;
  const AOptions: TWebviewOptions; out AWin: IWebviewWindow): Boolean; inline;
var
  B: PWebviewFactoryDesc;
begin
  if not WebviewBackendAvailable(AKind) then Exit(False);
  B := FindBackend(AKind);
  if B = nil then Exit(False);
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
begin
  if AParent = nil then
    Exit(CreateWebviewOf(AKind, AOptions));
  CheckWebviewOptions(AOptions);
  if TryCreateForKind(AKind, AParent, AOptions, Result) then Exit;
  // CONTRACT fail-fast: 显式 Kind 不可用即抛 EWebviewBackendUnavailable，不静默遍历其他后端/回退 fake，缺库部署可排查
  raise EWebviewBackendUnavailable.CreateFmt(
    'webview backend "%s" is not available in this build', [
    GetEnumName(TypeInfo(TWebviewKind), Ord(AKind))]);
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
  B: PWebviewFactoryDesc;
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

end.
