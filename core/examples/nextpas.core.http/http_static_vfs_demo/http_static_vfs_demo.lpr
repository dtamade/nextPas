program http_static_vfs_demo;
{$I nextpas.core.settings.inc}
{** @desc S5 收官示例：respack 构建期打包 → typed const 编入 → IVfs → ServeVfs HTTP 服务。
  构建期：wwwroot/ 经 rp_pack 生成 assets_respack.inc（typed const，条目含 fnv32）；
  运行期三种形态：
    （无参，默认）embedded 后端 + 真实 HTTP server 自检：200/304/206/404/目录 404
                  逐项断言后退出——make run 即端到端冒烟。
    --dev         os 后端直读 wwwroot/，同一套自检——装配一行切换开发态。
    --serve [port] 长驻服务（默认 8080），供 curl 手工体验条件请求与 Range。 }
uses
  nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.vfs,
  nextpas.core.net,
  nextpas.core.net.base,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.platform.thread,
  nextpas.core.http,
  nextpas.core.http.router,
  nextpas.core.http.server,
  nextpas.core.text.conv;

{$I assets_respack.inc}   { DEMO_ASSETS / DEMO_ASSETS_SIZE }

type
  PServerCtx = ^TServerCtx;
  TServerCtx = record
    Server: THttpServer;
    Addr: string;
    Port: UInt16;
  end;

function ServerThreadFunc(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PServerCtx;
begin
  Result := nil;
  LCtx := PServerCtx(AArg);
  try
    LCtx^.Server.ListenAndServe(LCtx^.Addr, LCtx^.Port);
  except
  end;
  Dispose(LCtx);
end;

function StartServer(const AHandler: IHttpHandler; out AServer: THttpServer;
  out APort: UInt16): TPlatformThreadHandle;
var
  LCtx: PServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
begin
  AServer := THttpServer.Create(AHandler, THttpServerOptions.Default);
  New(LCtx);
  LCtx^.Server := AServer;
  LCtx^.Addr := '127.0.0.1';
  LCtx^.Port := 0;
  platform_thread_create(LHandle, @ServerThreadFunc, LCtx);
  LWait := 0;
  while (not AServer.IsRunning) and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;
  APort := AServer.LocalAddr.Port;
  Result := LHandle;
end;

procedure StopServer(var AServer: THttpServer; const AHandle: TPlatformThreadHandle);
var
  LRet: Pointer;
begin
  AServer.Shutdown;
  platform_thread_join(AHandle, LRet);
  AServer.Free;
  AServer := nil;
end;

function SendRawRequest(const APort: UInt16; const ARequest: string): string;
var
  LConn: ITcpStream;
  LBuf: array[0..8191] of Byte;
  LN: SizeUInt;
begin
  Result := '';
  LConn := TcpConnect('127.0.0.1', APort);
  try
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
    LConn.Write(ARequest[1], SizeUInt(Length(ARequest)));
    repeat
      try
        LN := LConn.Read(LBuf[0], 8192);
      except
        LN := 0;
      end;
      if LN > 0 then
      begin
        SetLength(Result, Length(Result) + Int32(LN));
        Move(LBuf[0], Result[Length(Result) - Int32(LN) + 1], LN);
      end;
    until LN = 0;
  finally
    LConn.Close;
  end;
end;

procedure Expect(const ACond: Boolean; const AMsg: string);
begin
  if not ACond then
    raise Exception.Create('self-check failed: ' + AMsg);
end;

{ 提取响应里首个 header 值（AName 须为小写）；找不到返回空串 }
function HeaderValue(const AResp, AName: string): string;
var
  LKeyStart, LValStart, LValEnd: SizeInt;
begin
  Result := '';
  LKeyStart := Pos(AName + ': ', AResp);
  if LKeyStart = 0 then
    Exit;
  LValStart := LKeyStart + Length(AName) + 2;
  LValEnd := LValStart;
  while (LValEnd <= Length(AResp)) and (AResp[LValEnd] <> #13) do
    Inc(LValEnd);
  Result := System.Copy(AResp, LValStart, LValEnd - LValStart);
end;

procedure RunSelfCheck(const APort: UInt16; const AExpectFnvETag: Boolean);
var
  LResp, LETag: string;
begin
  { 1. 200 全量 + MIME + ETag 形态 + Accept-Ranges }
  LResp := SendRawRequest(APort, 'GET /assets/index.html HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
  Expect(Pos('HTTP/1.1 200', LResp) > 0, 'index.html status 200');
  Expect(Pos('content-type: text/html', LResp) > 0, 'index.html mime');
  LETag := HeaderValue(LResp, 'etag');
  if AExpectFnvETag then
    Expect(Pos('"fnv-', LETag) = 1, 'index.html etag is fnv form: ' + LETag)
  else
    Expect(Length(LETag) > 0, 'index.html has strong etag');
  Expect(Pos('accept-ranges: bytes', LResp) > 0, 'accept-ranges advertised');

  { 2. 条件请求：取同一资源的 ETag 回传 → 304 }
  LResp := SendRawRequest(APort, 'GET /assets/app.js HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
  Expect(Pos('HTTP/1.1 200', LResp) > 0, 'app.js status 200');
  Expect(Pos('content-type: application/javascript', LResp) > 0, 'app.js mime');
  LETag := HeaderValue(LResp, 'etag');

  LResp := SendRawRequest(APort,
    'GET /assets/app.js HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'If-None-Match: ' + LETag + #13#10 +
    'Connection: close'#13#10#13#10);
  Expect(Pos('HTTP/1.1 304', LResp) > 0, 'if-none-match yields 304');

  { 3. Range 单区间 → 206 + 定位读前缀 }
  LResp := SendRawRequest(APort,
    'GET /assets/app.js HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Range: bytes=0-3'#13#10 +
    'Connection: close'#13#10#13#10);
  Expect(Pos('HTTP/1.1 206', LResp) > 0, 'range request yields 206');
  Expect(Pos('bytes 0-3/', HeaderValue(LResp, 'content-range')) = 1,
    'content-range total prefix');
  Expect(Pos('cons', LResp) > 0, 'range body is positioned read');

  { 4. 缺失条目 → 404；5. 目录 → 404（无自动 index） }
  LResp := SendRawRequest(APort, 'GET /assets/nope.png HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
  Expect(Pos('HTTP/1.1 404', LResp) > 0, 'missing entry yields 404');
  LResp := SendRawRequest(APort, 'GET /assets/images HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
  Expect(Pos('HTTP/1.1 404', LResp) > 0, 'directory yields 404');

  WriteLn('self-check: all requests OK (200/304/206/404/dir-404)');
end;

procedure RunEmbeddedOrDev(const AMode: string);
var
  LVfs: IVfs;
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
begin
  if AMode = '--dev' then
  begin
    LVfs := CreateOsVfs('wwwroot');
    WriteLn('backend: os (dev, reads wwwroot/)');
  end
  else
  begin
    LVfs := CreateEmbeddedVfsBorrowed(@DEMO_ASSETS[0], SizeUInt(DEMO_ASSETS_SIZE));
    WriteLn('backend: embedded (prod, serves in-blob pack)');
  end;

  LRouter := THttpRouter.Create;
  LRouter.Get('/assets/*filepath', ServeVfs(LVfs));
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    WriteLn('listening on 127.0.0.1:', LPort);
    RunSelfCheck(LPort, AMode <> '--dev');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure RunServeMode;
var
  LVfs: IVfs;
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
begin
  LPort := UInt16(StrToIntDef(ParamStr(2), 8080));
  LVfs := CreateEmbeddedVfsBorrowed(@DEMO_ASSETS[0], SizeUInt(DEMO_ASSETS_SIZE));
  LRouter := THttpRouter.Create;
  LRouter.Get('/assets/*filepath', ServeVfs(LVfs));
  LServer := THttpServer.Create(LRouter as IHttpHandler, THttpServerOptions.Default);
  try
    WriteLn('serving embedded assets on http://127.0.0.1:', LPort, '/assets/* (Ctrl+C to stop)');
    LServer.ListenAndServe('127.0.0.1', LPort);
  finally
    LServer.Free;
  end;
end;

var
  Mode: string;
begin
  try
    Mode := ParamStr(1);
    if Mode = '--serve' then
      RunServeMode
    else
      RunEmbeddedOrDev(Mode);
  except
    on E: Exception do
    begin
      WriteLn('demo: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
