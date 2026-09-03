program demo_webview_respack;

{** @desc respack 集成示例：同一份前端资源在三种后端形态间切换，
    演示 CONTRACT §3.4 推荐的集成路径——用 vfs 家族产物做内嵌 provider。

    三种形态（--dev / --dev-server 互斥）：
    - 默认 (prod)：CreateEmbeddedVfs(@DEMO_ASSETS) 零拷贝读 pack blob
      → TVfsAssetProvider 适配为 IWebviewAssetProvider → MountEmbedded
      → npres://app/index.html
    - --dev       ：CreateOsVfs('wwwroot') 直读磁盘目录，改完刷新即生效
    - --dev-server http://host:port ：DevServerUrl 开发模式——资产面惰性
      （挂载 no-op、解析恒 404）且首窗跳过 npres 注册；同时 InitialUrl
      指向 dev server，页面经 http 直连（本机 WebKit 网络进程搁浅环境下
      http 导航为 no-event，示例优雅降级仅检验惰性语义）。

    推荐开法：
      make run            # prod，嵌套资源
      make run-dev        # os 目录热重载
      make run-dev-server # vite / next dev server（需本机网络进程可用）

    无 GTK 后端时优雅退出（demo-skip），CI 可跑。 }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.vfs,
  nextpas.core.webview.base,
  nextpas.core.webview,
  nextpas.core.webview.vfs,
  nextpas.core.window.base,
  nextpas.core.window.factory, nextpas.core.text;

{$I assets_respack.inc}  { DEMO_ASSETS / DEMO_ASSETS_SIZE —— 构建期生成 }

function DevServerFromArgs(out AUrl: string): Boolean;
var
  I: Integer;
begin
  AUrl := '';
  for I := 1 to ParamCount do
  begin
    if ParamStr(I) = '--dev-server' then
    begin
      if I < ParamCount then
        AUrl := ParamStr(I + 1);
      Exit(True);
    end;
    if Pos('--dev-server=', ParamStr(I)) = 1 then
    begin
      AUrl := Copy(ParamStr(I), 14, MaxInt);
      Exit(True);
    end;
  end;
  Result := False;
end;

function HasFlag(const AFlag: string): Boolean;
var
  I: Integer;
begin
  for I := 1 to ParamCount do
    if ParamStr(I) = AFlag then
      Exit(True);
  Result := False;
end;

var
  LDevServer: string;
  LIsDevServer: Boolean;
  LIsDev: Boolean;
  LVfs: IVfs;
  LProvider: IWebviewAssetProvider;
  LWin: IWebviewWindow;
  LBuilder: IWebviewBuilder;
begin
  if not WebviewBackendAvailable(wvGtk) then
  begin
    WriteLn('demo-skip no-gtk-backend');
    Halt(0);
  end;

  LIsDevServer := DevServerFromArgs(LDevServer);
  LIsDev := HasFlag('--dev');

  if LIsDevServer and LIsDev then
  begin
    WriteLn('flags --dev and --dev-server are mutually exclusive');
    Halt(1);
  end;

  if LIsDevServer then
  begin
    if LDevServer = '' then
      LDevServer := 'http://127.0.0.1:5173';
    WriteLn('mode: dev-server (', LDevServer, ') — assets inert, http straight');
    LVfs := nil;
    LProvider := nil;
  end
  else if LIsDev then
  begin
    WriteLn('mode: dev (os vfs, wwwroot/) — edit wwwroot/ and reload');
    LVfs := CreateOsVfs('wwwroot');
    LProvider := CreateVfsAssetProvider(LVfs);
  end
  else
  begin
    WriteLn('mode: prod (embedded vfs, pack blob)');
    LVfs := CreateEmbeddedVfsBorrowed(@DEMO_ASSETS[0], SizeUInt(DEMO_ASSETS_SIZE));
    LProvider := CreateVfsAssetProvider(LVfs);
  end;

  LBuilder := TWebviewBuilder.New
    .Title('nextPas WebView — respack')
    .Size(1060, 720)
    .Kind(wvGtk);

  if LIsDevServer then
  begin
    LBuilder := LBuilder.DevServerUrl(LDevServer).InitialUrl(LDevServer);
  end
  else
  begin
    { 构造期导航由 InitialUrl 承担，Build 后的显式 Navigate 可省；
      此处仍演示 Builder 形态——与 Run("url") 等价 }
    LBuilder := LBuilder.InitialUrl('npres://app/index.html');
  end;

  try
    LWin := LBuilder.Build;
  except
    on E: EWebviewBackendUnavailable do
    begin
      WriteLn('demo-skip no-gtk-backend (', E.Message, ')');
      Halt(0);
    end;
  end;

  if not LIsDevServer then
    LWin.Assets.MountEmbedded('', LProvider);

  LWin.Invokes.Register('demo.ping',
    function(const APayloadJson: string): string
    begin
      Result := '{"pong":true,"echo":' + APayloadJson + '}';
    end);

  LWin.OnNavigationFinished(
    procedure(const AEvent: TWebviewNavigationEvent)
    begin
      WriteLn('[nav finished] ', AEvent.Url);
      LWin.Emit('demo.event', '{"note":"hello from Pascal via respack"}');
    end);
  LWin.OnNavigationFailed(
    procedure(const AEvent: TWebviewNavigationEvent)
    begin
      WriteLn('[nav failed] ', AEvent.Url, ' code=', AEvent.ErrorCode, ' ', AEvent.ErrorMessage);
    end);
  LWin.Window.OnEvent(
    procedure(const AEvent: TWindowEvent)
    begin
      if AEvent.Kind = weClosed then
        WindowExitLoop;
    end);

  LWin.Window.Show;

  { 构造期 InitialUrl 已触发首帧导航；dev-server 模式同样已指向 http。
    无需额外 Navigate，直接进主循环即可——若需编程导航，Build 后
    LWin.Navigate('npres://app/other.html') 仍可。 }
  if LIsDevServer then
    WriteLn('navigating to dev server: ', LDevServer)
  else
    WriteLn('serving npres://app/index.html via VFS adapter (',
      LVfs.CaseSensitive, ' case-sensitive)');

  WindowRunLoop;
  LWin := nil;
end.
