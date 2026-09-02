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
  nextpas.core.sync,
  nextpas.core.webview.base,
  nextpas.core.webview.validation,
  nextpas.core.webview.fake,
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
  GDefaultOnce: IOnce;
  GDefaultKind: TWebviewKind;
  GBackendsOnce: IOnce;
  GAvailOnce: array[TWebviewKind] of IOnce;
  GAvailYes: array[TWebviewKind] of Boolean;

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

procedure InitBackends; inline;
begin
  if GBackendsOnce.Done then Exit;
  GBackendsOnce.DoOnce(procedure
  begin
    WEBVIEW_BACKENDS[0].Kind := wvFake;     WEBVIEW_BACKENDS[0].Probe := @ProbeFake;     WEBVIEW_BACKENDS[0].Create := @CreateFake;     WEBVIEW_BACKENDS[0].CreateOn := @CreateFakeOn;
    WEBVIEW_BACKENDS[1].Kind := wvGtk;      WEBVIEW_BACKENDS[1].Probe := @ProbeGtk;      WEBVIEW_BACKENDS[1].Create := @CreateGtk;      WEBVIEW_BACKENDS[1].CreateOn := @CreateGtkOn;
    WEBVIEW_BACKENDS[2].Kind := wvWebview2; WEBVIEW_BACKENDS[2].Probe := @ProbeWebView2; WEBVIEW_BACKENDS[2].Create := @CreateWebView2; WEBVIEW_BACKENDS[2].CreateOn := @CreateWebView2On;
    WEBVIEW_BACKENDS[3].Kind := wvWk;       WEBVIEW_BACKENDS[3].Probe := @ProbeWk;       WEBVIEW_BACKENDS[3].Create := @CreateWk;       WEBVIEW_BACKENDS[3].CreateOn := @CreateWkOn;
  end);
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

{$PUSH}{$WARNINGS OFF}
function WebviewBackendAvailable(AKind: TWebviewKind): Boolean; inline;
begin
  if (AKind < Low(TWebviewKind)) or (AKind > High(TWebviewKind)) then Exit(False);
  if AKind = wvFake then Exit(True);
  // perf: per-kind Once single source inline zero-copy, L1 sync.once去重幂等
  if GAvailOnce[AKind].Done then Exit(GAvailYes[AKind]);
  GAvailOnce[AKind].DoOnce(procedure
  begin
    GAvailYes[AKind] := RawProbe(AKind);
  end);
  Result := GAvailYes[AKind];
end;
{$POP}

function DefaultWebviewKind: TWebviewKind; inline;
begin
  // perf: single Once single source inline zero-copy, table-driven
  if GDefaultOnce.Done then Exit(GDefaultKind);
  GDefaultOnce.DoOnce(procedure
  var
    I: Integer;
    LKind: TWebviewKind;
  begin
    InitBackends;
    for I := Low(WEBVIEW_BACKENDS) to High(WEBVIEW_BACKENDS) do
    begin
      LKind := WEBVIEW_BACKENDS[I].Kind;
      if LKind = wvFake then Continue;
      if WebviewBackendAvailable(LKind) then
      begin
        GDefaultKind := LKind;
        Exit;
      end;
    end;
    GDefaultKind := wvFake;
  end);
  Result := GDefaultKind;
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
  GDefaultOnce := Once;
  GDefaultKind := wvFake;
  GBackendsOnce := Once;
  GAvailOnce[wvFake] := Once; GAvailYes[wvFake] := True;
  GAvailOnce[wvGtk] := Once;
  GAvailOnce[wvWebview2] := Once;
  GAvailOnce[wvWk] := Once;

finalization
  GDefaultOnce := nil;
  GBackendsOnce := nil;
  GAvailOnce[wvFake] := nil;
  GAvailOnce[wvGtk] := nil;
  GAvailOnce[wvWebview2] := nil;
  GAvailOnce[wvWk] := nil;

end.
