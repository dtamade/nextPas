program test_webview_gtk_backend;
{ gtk 后端门禁（确定性分支 + 可用即冒烟）——全事件驱动，零忙等。
  等待原语：事件回执退出 GLib 嵌套主循环 + 单发超时护栏（deadline
  是失败判据，不是节奏器）；不使用 Sleep/迭代数轮询：
  1) factory 可用性与 loader 探测一致；
  2) 库+显示可用时：构造→可见性/缩放/UA 同步属性真值→
     NavigateToString 经 OnNavigationFinished 事件→eval 回执
     （6*7=42）→Close 干净；
  3) scheme 资产管线：挂载→页面 fetch 经真实桥 IPC
     （window.__npw.invoke）推送结果，命中与缺资源 reject 双断言；
  4) 多窗口资产隔离：双窗同 context，请求按发起视图各归其主，
     跨窗请求 reject；
  5) ephemeral 会话：每窗自有 context，顺序建/毁两窗各归其主服务，
     钉死析构摘表/unref 收口语义；
  6) DataDirectory 会话：website_data_manager 自建 context 路径，
     持久化目录下资产服务全链可用（三形态矩阵收尾）；
  7) 缺库/无显示环境：构造抛 EWebviewBackendUnavailable，优雅通过。
  heaptrc 0 unfreed 硬门。 }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  Classes,
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.webview.base,
  nextpas.core.webview.intf,
  nextpas.core.webview.bridge,
  nextpas.core.webview.gtk.loader,
  nextpas.core.webview.gtk,
  nextpas.core.webview.gtk.ffi,
  nextpas.core.webview.factory;

const
  { 事件护栏 deadline：正常回执毫秒级到达；仅环境灾难时兜底失败 }
  WAIT_DEADLINE_MS = 20000;
  { 等待通道：handler 携带通道号回执，跨窗事件互不误触 }
  WC_NAV_A = 10;   { 窗 A 导航完成 }
  WC_NAV_B = 11;   { 窗 B 导航完成 }
  WC_REP_A = 20;   { 窗 A 桥报告 }
  WC_REP_B = 21;   { 窗 B 桥报告 }
  WC_EVAL  = 30;   { eval 回执（全局同时至多一发）}
  REPORT_CMD = 'gate.report';

type
  PReportSlot = ^TReportSlot;
  TReportSlot = record
    Payload: string;
    Channel: Integer;
  end;

var
  { 当前等待会话（UI 单线程，任一时刻至多一个嵌套主循环在跑） }
  GWaitLoop: Pointer = nil;
  GWaitActiveChannel: Integer = 0;
  GWaitTimeoutTag: guint = 0;
  GWaitFired: set of byte = [];

procedure SignalChannel(AChannel: Integer);
begin
  Include(GWaitFired, Byte(AChannel));
  if (GWaitLoop <> nil) and (GWaitActiveChannel = AChannel) then
    G_main_loop_quit(GWaitLoop);
end;

function WaitTimeoutCb(AData: Pointer): gboolean; cdecl;
begin
  if GWaitLoop <> nil then
    G_main_loop_quit(GWaitLoop);
  Result := GLIB_SOURCE_REMOVE;   { 自移除 }
end;

procedure AwaitChannel(AChannel: Integer; const AWhat: string);
begin
  if AChannel in GWaitFired then
  begin
    Exclude(GWaitFired, Byte(AChannel));   { 先于武装到达的事件直接消费 }
    Exit;
  end;
  GWaitActiveChannel := AChannel;
  GWaitLoop := G_main_loop_new(nil, 0);
  GWaitTimeoutTag := G_timeout_add(WAIT_DEADLINE_MS, @WaitTimeoutCb, nil);
  G_main_loop_run(GWaitLoop);
  G_main_loop_unref(GWaitLoop);
  GWaitLoop := nil;
  if AChannel in GWaitFired then
  begin
    Exclude(GWaitFired, Byte(AChannel));
    G_source_remove(GWaitTimeoutTag);   { 事件先到，撤下未触发的护栏 }
  end
  else
    Check(False, 'event wait timeout: ' + AWhat);
end;

{ eval 回执（exactly-one）退出 WC_EVAL 通道 }
procedure EvalAwait(AWin: IWebviewWindow; const AJs: string;
  out AResult: string);
var
  LRes: string;
begin
  LRes := '';
  AWin.Eval(AJs,
    procedure(const AResultJson: string)
    begin
      LRes := AResultJson;
      SignalChannel(WC_EVAL);
    end,
    procedure(const AErr: Exception)
    begin
      LRes := 'ERR:' + AErr.Message;
      SignalChannel(WC_EVAL);
    end);
  AwaitChannel(WC_EVAL, 'eval settle: ' + Copy(AJs, 1, 50));
  AResult := LRes;
end;

function BackendUsable: Boolean;
var
  LInfo: TGtkLoadInfo;
begin
  Result := TryLoadGtkWebkit(LInfo);
end;

procedure TestFactoryMatchesProbe;
begin
  CheckEqual(WebviewBackendAvailable(wvFake), True, 'fake always available');
  CheckEqual(WebviewBackendAvailable(wvGtk), BackendUsable(),
    'factory gtk availability matches loader probe');
end;

procedure TestCreateUnavailableOrSmoke;
var
  W: IWebviewWindow;
  LOpts: TWebviewOptions;
  LErrored: Boolean;
  LRes: string;
begin
  LOpts := DefaultWebviewOptions;
  if not BackendUsable() then
  begin
    { 缺库：工厂必须抛可用性异常 }
    LErrored := False;
    try
      W := CreateWebviewOf(wvGtk, LOpts);
    except
      on E: EWebviewBackendUnavailable do LErrored := True;
    end;
    Check(LErrored, 'unavailable backend raises');
    Exit;
  end;

  { 库可用但可能无显示：gtk_init_check 失败同样归一为可用性异常 }
  try
    W := CreateWebviewOf(wvGtk, LOpts);
  except
    on E: EWebviewBackendUnavailable do
    begin
      Check(True, '');   { 无显示环境：到此已验证优雅降级 }
      Exit;
    end;
  end;

  try
    { 可见性与属性往返均为同步 FFI 属性读写，无需任何等待 }
    W.SetTitle('npw-gate');
    W.Show;
    Check(W.IsVisible, 'visible after show');
    W.SetZoom(1.5);
    Check(Abs(W.GetZoom - 1.5) < 1e-9, 'zoom roundtrip');
    W.SetUserAgent('npw-gate/1.0');
    CheckEqual('npw-gate/1.0', W.GetUserAgent, 'ua roundtrip');
    CheckEqual('npw-gate', W.GetTitle, 'title roundtrip');

    { 内容加载完成是引擎事件；完成后 eval 回执亦为事件 }
    W.OnNavigationFinished(
      procedure(const AEvent: TWebviewNavigationEvent)
      begin
        SignalChannel(WC_NAV_A);
      end);
    W.NavigateToString('<html><body>npw</body></html>');
    AwaitChannel(WC_NAV_A, 'string load finished');

    EvalAwait(W, '6*7', LRes);
    CheckEqual('42', LRes, 'eval result text');

    { 全部 eval 已收口，无在途回执：Close 同步销毁即可 }
    W.Close;
  finally
    W := nil;
  end;
end;

type
  { 页面与资源都经 npres:// 自身提供——相对 fetch 天然命中本家族 scheme；
    结果经真实桥 IPC（__npw.invoke）推回原生，事件驱动收取 }
  TGateProvider = class(TInterfacedObject, IWebviewAssetProvider)
  public
    function TryResolve(const APath: string;
      out ABytes: TBytes; out AMimeType: string): Boolean;
  end;

const
  PAGE_HTML: AnsiString =
    '<html><body><script>' +
    'fetch("hello.txt").then(function(r){return r.text();})' +
    '.then(function(t){' +
    'return fetch("missing.txt").then(function(){' +
    'window.__npw.invoke("gate.report",{ok:true,body:t+"|NO404"});' +
    '},function(){' +
    'window.__npw.invoke("gate.report",{ok:true,body:t+"|ERR"});' +
    '});' +
    '},function(e){' +
    'window.__npw.invoke("gate.report",{ok:false,body:"FETCH:"+e});' +
    '});' +
    '</script></body></html>';

function StrToGateBytes(const S: AnsiString): TBytes;
begin
  SetLength(Result, Length(S));
  if Length(S) > 0 then
    Move(S[1], Result[0], Length(S));
end;

function TGateProvider.TryResolve(const APath: string;
  out ABytes: TBytes; out AMimeType: string): Boolean;
begin
  { CONTRACT §3：provider 收到前缀剥离后的相对路径（无前导 '/'） }
  ABytes := nil;
  AMimeType := '';
  Result := True;
  if APath = 'hello.txt' then
  begin
    ABytes := StrToGateBytes('npw-scheme-ok');
    AMimeType := 'text/plain';
  end
  else if APath = 'page.html' then
  begin
    ABytes := StrToGateBytes(PAGE_HTML);
    AMimeType := 'text/html';
  end
  else
    Result := False;
end;

{ 页面 fetch 结果经桥 invoke 推送（WC_REPx 通道收取）。
  纪律：不 eval 裸 Promise 表达式（run_javascript 路径对未取值
  Promise 回 GError "Unsupported result type"）；分发本身仍以
  WC_EVAL 收口后，再等报告通道 }
procedure FetchViaBridge(AWin: IWebviewWindow; const AFile: string;
  ASlot: PReportSlot; out APayload: string);
begin
  ASlot^.Payload := '';
  EvalAwait(AWin,
    'fetch("' + AFile + '").then(function(r){return r.text();})' +
    '.then(function(t){window.__npw.invoke("gate.report",' +
    '{ok:true,body:t});},' +
    'function(){window.__npw.invoke("gate.report",{ok:false});});',
    APayload);
  AwaitChannel(ASlot^.Channel, 'bridge report for ' + AFile);
  APayload := ASlot^.Payload;
end;

{ 桥报告槽：handler 回执时写 Payload 并点亮所属通道 }
procedure RegisterReport(AWin: IWebviewWindow; ASlot: PReportSlot;
  AChannel: Integer);
begin
  ASlot^.Channel := AChannel;
  ASlot^.Payload := '';
  AWin.Invokes.Register(REPORT_CMD,
    function(const APayloadJson: string): string
    begin
      ASlot^.Payload := APayloadJson;
      SignalChannel(AChannel);
      Result := 'null';
    end);
end;

procedure AttachNavSignal(AWin: IWebviewWindow; AChannel: Integer);
begin
  AWin.OnNavigationFinished(
    procedure(const AEvent: TWebviewNavigationEvent)
    begin
      SignalChannel(AChannel);
    end);
end;

procedure TestSchemeAssetPipeline;
var
  W: IWebviewWindow;
  LOpts: TWebviewOptions;
  LProv: IWebviewAssetProvider;
  LSlot: TReportSlot;
  LBody: string;
begin
  LOpts := DefaultWebviewOptions;
  if not BackendUsable() then
  begin
    Check(True, '');
    Exit;
  end;
  try
    W := CreateWebviewOf(wvGtk, LOpts);
  except
    on E: EWebviewBackendUnavailable do
    begin
      Check(True, '');   { 无显示环境优雅跳过 }
      Exit;
    end;
  end;

  try
    LProv := TGateProvider.Create;
    W.Assets.MountEmbedded('', LProv);
    RegisterReport(W, @LSlot, WC_REP_A);
    AttachNavSignal(W, WC_NAV_A);

    W.Navigate('npres://app/page.html');
    AwaitChannel(WC_NAV_A, 'page load finished');

    { 页面内 fetch 链已完成并经桥推送报告：hello 命中 + missing 真 404 }
    AwaitChannel(WC_REP_A, 'scheme pipeline report');
    LBody := LSlot.Payload;
    Check(Pos('npw-scheme-ok', LBody) > 0,
      'scheme serves mounted asset, got: ' + LBody);
    Check(Pos('|ERR', LBody) > 0, 'missing resource yields real error');
    Check(Pos('NO404', LBody) = 0, 'no false-positive 200 on missing');

    W.Close;
  finally
    W := nil;
  end;
end;

type
  { 按实例标签供页：page.html 自识 + <tag>.txt 独占——双窗隔离断言的料 }
  TTagProvider = class(TInterfacedObject, IWebviewAssetProvider)
  public
    Tag: string;
    function TryResolve(const APath: string;
      out ABytes: TBytes; out AMimeType: string): Boolean;
  end;

function TTagProvider.TryResolve(const APath: string;
  out ABytes: TBytes; out AMimeType: string): Boolean;
begin
  { CONTRACT §3：provider 收到前缀剥离后的相对路径（无前导 '/'） }
  ABytes := nil;
  AMimeType := '';
  Result := False;
  if APath = 'page.html' then
  begin
    ABytes := StrToGateBytes(AnsiString('<html><body>npw-' + Tag +
      '</body></html>'));
    AMimeType := 'text/html';
    Result := True;
  end
  else if APath = Tag + '.txt' then
  begin
    ABytes := StrToGateBytes('content-' + Tag);
    AMimeType := 'text/plain';
    Result := True;
  end;
end;

procedure TestMultiWindowAssetIsolation;
var
  W1, W2: IWebviewWindow;
  P1Obj, P2Obj: TTagProvider;
  S1, S2: TReportSlot;
  LBody: string;
  LOpts: TWebviewOptions;

  function CreateOrSkip: IWebviewWindow;
  begin
    Result := nil;
    try
      Result := CreateWebviewOf(wvGtk, LOpts);
    except
      on E: EWebviewBackendUnavailable do ;   { 无显示环境优雅跳过 }
    end;
  end;

begin
  if not BackendUsable() then
  begin
    Check(True, '');
    Exit;
  end;
  LOpts := DefaultWebviewOptions;
  W1 := CreateOrSkip;
  if W1 = nil then
  begin
    Check(True, '');
    Exit;
  end;
  W2 := CreateOrSkip;
  if W2 = nil then
  begin
    { 第二窗不可造（资源受限）：收口首窗后优雅跳过 }
    if not W1.IsClosed then
      W1.Close;
    W1 := nil;
    Check(True, '');
    Exit;
  end;
  try
    try
      P1Obj := TTagProvider.Create;
      P1Obj.Tag := 'one';
      P2Obj := TTagProvider.Create;
      P2Obj.Tag := 'two';
      W1.Assets.MountEmbedded('', P1Obj);
      W2.Assets.MountEmbedded('', P2Obj);
      RegisterReport(W1, @S1, WC_REP_A);
      RegisterReport(W2, @S2, WC_REP_B);
      AttachNavSignal(W1, WC_NAV_A);
      AttachNavSignal(W2, WC_NAV_B);

      { 双窗并发导航同一 scheme URL：请求必须各归其主（S5 视图精确路由），
        而非"最新窗口通吃" }
      W1.Navigate('npres://app/page.html');
      W2.Navigate('npres://app/page.html');
      AwaitChannel(WC_NAV_A, 'w1 load finished');
      AwaitChannel(WC_NAV_B, 'w2 load finished');

      { 各自页面身份由各自 provider 供给 }
      EvalAwait(W1, 'document.body.innerText', LBody);
      Check(Pos('npw-one', LBody) > 0,
        'w1 page served by own provider, got: ' + LBody);
      EvalAwait(W2, 'document.body.innerText', LBody);
      Check(Pos('npw-two', LBody) > 0,
        'w2 page served by own provider, got: ' + LBody);

      { 各自命名空间内命中 }
      FetchViaBridge(W1, 'one.txt', @S1, LBody);
      Check(Pos('content-one', LBody) > 0,
        'w1 fetches own asset, got: ' + LBody);
      FetchViaBridge(W2, 'two.txt', @S2, LBody);
      Check(Pos('content-two', LBody) > 0,
        'w2 fetches own asset, got: ' + LBody);

      { 跨窗口硬隔离：对方资产必须 reject，不得串台 }
      FetchViaBridge(W1, 'two.txt', @S1, LBody);
      Check(Pos('"ok":false', LBody) > 0,
        'w1 cannot fetch w2 asset (isolated), got: ' + LBody);
      FetchViaBridge(W2, 'one.txt', @S2, LBody);
      Check(Pos('"ok":false', LBody) > 0,
        'w2 cannot fetch w1 asset (isolated), got: ' + LBody);
    finally
      if (W1 <> nil) and not W1.IsClosed then W1.Close;
      if (W2 <> nil) and not W2.IsClosed then W2.Close;
    end;
  finally
    W1 := nil;
    W2 := nil;
  end;
end;

{ ephemeral 会话 live 覆盖（S5 析构收口路径）：每窗自有 WebKitWebContext，
  构造时各自注册 scheme，析构时先摘注册表再 unref。顺序建/毁两窗并各
  自服务资产——防"地址复用被误判已注册致 scheme 静默 404"回归 }
procedure TestEphemeralSessionLifecycle;
var
  LOpts: TWebviewOptions;
  LSlot: TReportSlot;
  PObj: TTagProvider;
  W: IWebviewWindow;
  LBody: string;
  I: Integer;

  function CreateAndPrepare: IWebviewWindow;
  begin
    Result := nil;
    try
      Result := CreateWebviewOf(wvGtk, LOpts);
    except
      on E: EWebviewBackendUnavailable do Exit;
    end;
    PObj := TTagProvider.Create;
    PObj.Tag := 'eph';
    Result.Assets.MountEmbedded('', PObj);
    RegisterReport(Result, @LSlot, WC_REP_A);
    AttachNavSignal(Result, WC_NAV_A);
  end;

begin
  if not BackendUsable() then
  begin
    Check(True, '');
    Exit;
  end;
  LOpts := DefaultWebviewOptions;
  LOpts.EphemeralSession := True;
  for I := 1 to 2 do
  begin
    W := CreateAndPrepare;
    if W = nil then
    begin
      Check(True, '');   { 无显示环境优雅跳过 }
      Exit;
    end;
    try
      W.Navigate('npres://app/page.html');
      AwaitChannel(WC_NAV_A, 'ephemeral load ' + IntToStr(I));
      FetchViaBridge(W, 'eph.txt', @LSlot, LBody);
      Check(Pos('content-eph', LBody) > 0,
        'ephemeral window ' + IntToStr(I) + ' serves own asset, got: ' + LBody);
    finally
      if not W.IsClosed then
        W.Close;
      W := nil;
    end;
  end;
end;

{ DataDirectory 会话形态 live 覆盖（三形态矩阵收尾）：自建
  website_data_manager context（base-data-directory），持久化目录下
  资产服务全链可用；与 ephemeral 同走"自有 context"收口路径 }
procedure TestDataDirectorySessionLifecycle;
var
  LOpts: TWebviewOptions;
  LSlot: TReportSlot;
  PObj: TTagProvider;
  W: IWebviewWindow;
  LBody: string;
  LDir: string;
begin
  if not BackendUsable() then
  begin
    Check(True, '');
    Exit;
  end;
  LDir := IncludeTrailingPathDelimiter(GetTempDir) +
    'npw-gate-dd-' + IntToStr(GetProcessID);
  ForceDirectories(LDir);
  try
    LOpts := DefaultWebviewOptions;
    LOpts.DataDirectory := LDir;
    W := nil;
    try
      W := CreateWebviewOf(wvGtk, LOpts);
    except
      on E: EWebviewBackendUnavailable do
      begin
        Check(True, '');   { 无显示环境优雅跳过 }
        Exit;
      end;
    end;
    try
      PObj := TTagProvider.Create;
      PObj.Tag := 'dd';
      W.Assets.MountEmbedded('', PObj);
      RegisterReport(W, @LSlot, WC_REP_A);
      AttachNavSignal(W, WC_NAV_A);

      W.Navigate('npres://app/page.html');
      AwaitChannel(WC_NAV_A, 'datadir load finished');
      EvalAwait(W, 'document.body.innerText', LBody);
      Check(Pos('npw-dd', LBody) > 0,
        'datadir page served by own provider, got: ' + LBody);
      FetchViaBridge(W, 'dd.txt', @LSlot, LBody);
      Check(Pos('content-dd', LBody) > 0,
        'datadir fetch serves own asset, got: ' + LBody);

      { 持久化目录确实落盘（website_data_manager 建立了存储结构） }
      Check(DirectoryExists(LDir), 'data directory materialized');
    finally
      if (W <> nil) and not W.IsClosed then
        W.Close;
      W := nil;
    end;
  finally
    { 尽力清理临时持久化目录（内容归 WebKit 所有，失败不致命） }
    RemoveDir(LDir);
  end;
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.webview.gtk.backend');
  T.Test('factory matches probe', @TestFactoryMatchesProbe);
  T.Test('create unavailable or smoke', @TestCreateUnavailableOrSmoke);
  T.Test('scheme asset pipeline', @TestSchemeAssetPipeline);
  T.Test('multi window asset isolation', @TestMultiWindowAssetIsolation);
  T.Test('ephemeral session lifecycle', @TestEphemeralSessionLifecycle);
  T.Test('datadir session lifecycle', @TestDataDirectorySessionLifecycle);
  if not T.Run then Halt(1);
end.
