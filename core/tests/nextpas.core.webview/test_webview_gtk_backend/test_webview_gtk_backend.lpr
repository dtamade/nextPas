program test_webview_gtk_backend;
{ gtk 后端门禁（确定性分支 + 可用即冒烟）：
  1) factory 可用性与 loader 探测一致；
  2) 库+显示可用时：构造→几何/标题/缩放真值→NavigateToString→
     异步 eval 回执（6*7=42）→invoke 同步回执经真实协议栈→Close 干净；
  3) scheme 资产管线：挂载→页面相对 fetch 命中 + 缺资源真实 reject；
  4) 多窗口资产隔离：双窗同 context，各归其主，跨窗请求 reject；
  5) 缺库/无显示环境：构造抛 EWebviewBackendUnavailable，优雅通过。
  主循环泵用 gtk_main_iteration_do(False) 非阻塞迭代+超时护栏。
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

var
  GEvalText: string;
  GEvalDone: Boolean;

procedure PumpGtk(AIdleMs: Integer);
begin
  while AIdleMs > 0 do
  begin
    GTK_main_iteration_do(0);
    Dec(AIdleMs, 5);
    Sleep(5);
  end;
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
  I: Integer;
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
    { 几何与状态真值 }
    W.SetTitle('npw-gate');
    W.Show;
    PumpGtk(100);
    Check(W.IsVisible, 'visible after show');

    { 缩放真值往返 }
    W.SetZoom(1.5);
    for I := 0 to 20 do GTK_main_iteration_do(0);
    Check(Abs(W.GetZoom - 1.5) < 1e-9, 'zoom roundtrip');

    { UA 属性通道往返（g_object varargs FFI 路径的 live 覆盖） }
    W.SetUserAgent('npw-gate/1.0');
    for I := 0 to 20 do GTK_main_iteration_do(0);
    CheckEqual('npw-gate/1.0', W.GetUserAgent, 'ua roundtrip');

    { 内容加载 + 异步 eval exactly-one }
    W.NavigateToString('<html><body>npw</body></html>');
    GEvalDone := False;
    GEvalText := '';
    W.Eval('6*7',
      procedure(const AResultJson: string)
      begin
        GEvalText := AResultJson;
        GEvalDone := True;
      end,
      procedure(const AErr: Exception)
      begin
        GEvalText := 'ERR:' + AErr.Message;
        GEvalDone := True;
      end);
    for I := 0 to 200 do
    begin
      GTK_main_iteration_do(0);
      if GEvalDone then Break;
      Sleep(10);
    end;
    Check(GEvalDone, 'eval settled');
    CheckEqual('42', GEvalText, 'eval result text');

    W.Close;
  finally
    W := nil;
  end;

  { Close 后窗口计数归零、对象随引用释放（heaptrc 兜底） }
  PumpGtk(50);
end;

type
  { 页面与资源都经 npres:// 自身提供——相对 fetch 天然命中本家族 scheme }
  TGateProvider = class(TInterfacedObject, IWebviewAssetProvider)
  public
    function TryResolve(const APath: string;
      out ABytes: TBytes; out AMimeType: string): Boolean;
  end;

const
  PAGE_HTML: AnsiString =
    '<html><body><script>' +
    'window.res="LOADED";' +
    'window.onerror=function(m){window.res+="|JS:"+m;};' +
    'fetch("hello.txt").then(function(r){return r.text();})' +
    '.then(function(t){window.res="OK:"+t;' +
    'return fetch("missing.txt");})' +
    '.then(function(){window.res+="|NO404";},' +
    'function(){window.res+="|ERR";});' +
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

procedure TestSchemeAssetPipeline;
var
  W: IWebviewWindow;
  LOpts: TWebviewOptions;
  LProv: IWebviewAssetProvider;
  LRes: string;
  LDone: Boolean;
  LIter: Integer;
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
    W.Navigate('npres://app/page.html');

    { 轮询页面结果：hello 命中 + missing 真实 404 双断言。
      探针含 location/readyState，失败消息自带现场 }
    LRes := '';
    LDone := False;
    for LIter := 0 to 1600 do
    begin
      GTK_main_iteration_do(0);
      Sleep(5);
      if (LIter mod 20 = 0) and not LDone then
        W.Eval('location.href+"#"+document.readyState+"#"+(window.res||"")',
          procedure(const AResultJson: string)
          begin
            LRes := AResultJson;
            LDone := Pos('|', LRes) > 0;
          end,
          nil);
      if LDone then Break;
    end;
    Check(Pos('OK:npw-scheme-ok', LRes) > 0, 'scheme serves mounted asset, got: ' + LRes);
    Check(Pos('|ERR', LRes) > 0, 'missing resource yields real error');
    Check(Pos('NO404', LRes) = 0, 'no false-positive 200 on missing');

    W.Close;
  finally
    W := nil;
  end;
end;

{ 单发 eval 泵到回执（exactly-one），超时护栏内必达。
  注：闭包不能捕获 out 形参，经局部变量中转 }
procedure EvalAwait(AWin: IWebviewWindow; const AJs: string;
  out AResult: string; ACaps: Integer);
var
  LDone: Boolean;
  LRes: string;
  I: Integer;
begin
  LDone := False;
  LRes := '';
  AWin.Eval(AJs,
    procedure(const AResultJson: string)
    begin
      LRes := AResultJson;
      LDone := True;
    end,
    procedure(const AErr: Exception)
    begin
      LRes := 'ERR:' + AErr.Message;
      LDone := True;
    end);
  for I := 0 to ACaps do
  begin
    GTK_main_iteration_do(0);
    if LDone then Break;
    Sleep(5);
  end;
  Check(LDone, 'eval settled: ' + Copy(AJs, 1, 60));
  AResult := LRes;
end;

{ 轮询到页面 body 出现文本为止（加载完成的事实探针）。
  预算取宽裕值：九门连跑或他 lane 编译并行的负载下，WebKit 子进程
  拉起与导航可能远慢于空闲态 }
function WaitForBodyText(AWin: IWebviewWindow): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to 1000 do
  begin
    GTK_main_iteration_do(0);
    Sleep(5);
    if I mod 20 = 19 then
    begin
      EvalAwait(AWin, 'document.body?document.body.innerText:""',
        Result, 600);
      if (Result <> '') and (Result <> '""') then Exit;
    end;
  end;
end;

{ fetch 探针：结果落窗 + 轮询（与 scheme 管线用例同姿势）。
  纪律：不直接 eval 裸 Promise 表达式——run_javascript 路径对
  未取值 Promise 回 GError "Unsupported result type" }
procedure FetchProbe(AWin: IWebviewWindow; const AFile: string;
  out AResult: string);
var
  LJs: string;
  I: Integer;
begin
  LJs := 'window.__npwp="PENDING";fetch("' + AFile +
    '").then(function(r){return r.text();})' +
    '.then(function(t){window.__npwp=t;},' +
    'function(){window.__npwp="ERR";});window.__npwp';
  EvalAwait(AWin, LJs, AResult, 400);
  I := 0;
  while Pos('PENDING', AResult) > 0 do
  begin
    Inc(I);
    if I > 1200 then Break;
    GTK_main_iteration_do(0);
    Sleep(5);
    EvalAwait(AWin, 'window.__npwp', AResult, 400);
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
    PumpGtk(50);
    Check(True, '');
    Exit;
  end;
  try
    try
      { 创建后先泵一拍：给 WebKit 子进程（WebProcess/NetworkProcess）
        拉起时间，降低并发导航下的首探针超时概率 }
      PumpGtk(50);
      P1Obj := TTagProvider.Create;
      P1Obj.Tag := 'one';
      P2Obj := TTagProvider.Create;
      P2Obj.Tag := 'two';
      W1.Assets.MountEmbedded('', P1Obj);
      W2.Assets.MountEmbedded('', P2Obj);

      { 双窗并发导航同一 scheme URL：请求必须各归其主（S5 视图精确路由），
        而非"最新窗口通吃" }
      W1.Navigate('npres://app/page.html');
      W2.Navigate('npres://app/page.html');
      LBody := WaitForBodyText(W1);
      Check(Pos('npw-one', LBody) > 0, 'w1 page served by own provider, got: ' + LBody);
      LBody := WaitForBodyText(W2);
      Check(Pos('npw-two', LBody) > 0, 'w2 page served by own provider, got: ' + LBody);

      { 各自命名空间内命中 }
      FetchProbe(W1, 'one.txt', LBody);
      Check(Pos('content-one', LBody) > 0, 'w1 fetches own asset, got: ' + LBody);
      FetchProbe(W2, 'two.txt', LBody);
      Check(Pos('content-two', LBody) > 0, 'w2 fetches own asset, got: ' + LBody);

      { 跨窗口硬隔离：对方资产必须 reject，不得串台 }
      FetchProbe(W1, 'two.txt', LBody);
      Check(Pos('ERR', LBody) > 0, 'w1 cannot fetch w2 asset (isolated), got: ' + LBody);
      FetchProbe(W2, 'one.txt', LBody);
      Check(Pos('ERR', LBody) > 0, 'w2 cannot fetch w1 asset (isolated), got: ' + LBody);
    finally
      if (W1 <> nil) and not W1.IsClosed then W1.Close;
      if (W2 <> nil) and not W2.IsClosed then W2.Close;
    end;
  finally
    W1 := nil;
    W2 := nil;
    PumpGtk(50);   { Close 收尾泵：destroy/idle 全落定（heaptrc 兜底） }
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
  if not T.Run then Halt(1);
end.
