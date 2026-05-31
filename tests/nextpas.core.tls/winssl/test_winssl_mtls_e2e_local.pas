program test_winssl_mtls_e2e_local;

{$mode objfpc}{$H+}{$J-}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

uses
  {$IFDEF WINDOWS}Windows, WinSock2,{$ENDIF}
  SysUtils, Classes,
  
  nextpas.core.tls.base,
  nextpas.core.tls.winssl.lib;

var
  Total, Passed, Failed: Integer;
  Section: string;

procedure BeginSection(const aName: string);
begin
  Section := aName;
  WriteLn; WriteLn('=== ', aName, ' ===');
end;

procedure Check(const aName: string; ok: Boolean; const details: string = '');
begin
  Inc(Total);
  Write('  [', Section, '] ', aName, ': ');
  if ok then begin Inc(Passed); WriteLn('PASS'); end
  else begin Inc(Failed); WriteLn('FAIL'); if details <> '' then WriteLn('    ', details); end;
end;

function InitWinsock: Boolean; var W: TWSAData; begin Result := WSAStartup(MAKEWORD(2,2), W) = 0; end;
procedure CleanupWinsock; begin WSACleanup; end;

function ConnectToHost(const aHost: string; aPort: Word; out aSocket: TSocket): Boolean;
var A: TSockAddrIn; H: PHostEnt; InAddr: TInAddr; Tm: Integer;
begin
  Result := False; aSocket := INVALID_SOCKET;
  aSocket := socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if aSocket = INVALID_SOCKET then Exit;
  Tm := 10000; setsockopt(aSocket, SOL_SOCKET, SO_RCVTIMEO, @Tm, SizeOf(Tm));
  setsockopt(aSocket, SOL_SOCKET, SO_SNDTIMEO, @Tm, SizeOf(Tm));
  H := gethostbyname(PAnsiChar(AnsiString(aHost)));
  if H = nil then begin closesocket(aSocket); aSocket := INVALID_SOCKET; Exit; end;
  FillChar(A, SizeOf(A), 0); A.sin_family := AF_INET; A.sin_port := htons(aPort);
  Move(H^.h_addr_list^^, InAddr, SizeOf(InAddr)); A.sin_addr := InAddr;
  Result := connect(aSocket, @A, SizeOf(A)) = 0;
  if not Result then begin closesocket(aSocket); aSocket := INVALID_SOCKET; end;
end;

function Env(const name: string; const defVal: string): string; begin Result := GetEnvironmentVariable(name); if Result = '' then Result := defVal; end;
function EnvDefault(const name: string): string; begin Result := GetEnvironmentVariable(name); end;

procedure Test_mTLS_E2E_Local;
var
  Lib: ISSLLibrary; Ctx: ISSLContext; Conn: ISSLConnection; ClientConn: ISSLClientConnection;
  Host, Pfx, PfxPass, CaFile: string; Port: Integer; S: TSocket; ok: Boolean;
begin
  BeginSection('WinSSL mTLS E2E (local s_server)');

  {$IFNDEF WINDOWS}
  Check('平台', False, 'Windows only'); Exit;
  {$ENDIF}

  Host := Env('FAFAFA_WINSSL_MTLS_SERVER', '127.0.0.1');
  Port := StrToIntDef(Env('FAFAFA_WINSSL_MTLS_PORT', '44330'), 44330);
  Pfx := Env('FAFAFA_WINSSL_PFX', '');
  PfxPass := Env('FAFAFA_WINSSL_PFX_PASSWORD', '');
  CaFile := Env('FAFAFA_TLS_CA', '');

  if (Pfx = '') then begin Check('环境变量', False, '缺少 FAFAFA_WINSSL_PFX'); Exit; end;

  if not InitWinsock then begin Check('初始化 Winsock', False); Exit; end;
  try
    Lib := CreateWinSSLLibrary;
    if (Lib = nil) or (not Lib.Initialize) then begin Check('初始化 WinSSL 库', False); Exit; end;
    Check('初始化 WinSSL 库', True);

    Ctx := Lib.CreateContext(sslCtxClient);
    Check('创建客户端上下文', Ctx <> nil);
    if Ctx = nil then Exit;

    Ctx.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);
    try
      Ctx.LoadPrivateKey(Pfx, PfxPass);
      Check('加载客户端 PFX 证书与私钥', True);
    except on E: Exception do
      begin Check('加载客户端 PFX', False, E.Message); Exit; end;
    end;

    if CaFile <> '' then
    begin
      try
        Ctx.LoadCAFile(CaFile);
        Check('加载 CA（用于验证服务端证书）', True);
      except on E: Exception do Check('加载 CA', False, E.Message);
      end;
    end;

    if not ConnectToHost(Host, Port, S) then begin Check('TCP 连接到 ' + Host + ':' + IntToStr(Port), False); Exit; end;
    try
      Conn := Ctx.CreateConnection(THandle(S));
      Check('创建 SSL 连接对象', Conn <> nil);
      if Conn = nil then Exit;

      Check('连接支持 ISSLClientConnection',
        Supports(Conn, ISSLClientConnection, ClientConn));
      if not Supports(Conn, ISSLClientConnection, ClientConn) then Exit;

      ClientConn.SetServerName(Host);

      ok := (Conn <> nil) and (Conn.DoHandshake = sslHsCompleted);
      Check('mTLS 握手', ok);
      if ok then Conn.Shutdown;
    finally
      if S <> INVALID_SOCKET then closesocket(S);
    end;

  finally
    CleanupWinsock;
  end;
end;

begin
  Total := 0; Passed := 0; Failed := 0;
  Test_mTLS_E2E_Local;
  WriteLn; WriteLn('总计: ', Total, ' 通过: ', Passed, ' 失败: ', Failed);
  if Failed > 0 then Halt(1);
end.




















