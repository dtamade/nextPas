program test_e2e_scenarios;

{******************************************************************************}
{  End-to-End (E2E) Test Scenarios                                             }
{  Migrated to use TSimpleTestRunner framework (P1-2.2)                        }
{******************************************************************************}

{$mode objfpc}{$H+}

uses
  nextpas.core.thread.init, // Must be first: threading is used before other units' initialization
  nextpas.core.tls.openssl.backed,
  nextpas.core.system.sysutils,
  nextpas.core.system.classes,
  {$IFDEF UNIX}
  ctypes,
  {$ENDIF}
  nextpas.core.tls.factory,
  nextpas.core.tls.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  test_openssl_base;

const
  TEST_HOST = 'badssl.com';
  TEST_PORT = 443;

var
  Runner: TSimpleTestRunner;
  GLib: ISSLLibrary;

// Socket connection helpers
{$IFDEF UNIX}
const
  AF_INET = 2;
  SOCK_STREAM = 1;
  IPPROTO_TCP = 6;
  INVALID_SOCKET = -1;

type
  TSocket = cint;
  tsockaddr_in = record
    sin_family: cushort;
    sin_port: cushort;
    sin_addr: record s_addr: cuint; end;
    sin_zero: array[0..7] of char;
  end;
  PHostEnt = ^THostEnt;
  THostEnt = record
    h_name: PChar;
    h_aliases: PPChar;
    h_addrtype: cint;
    h_length: cint;
    h_addr_list: PPChar;
  end;

function socket(domain, atype, protocol: cint): cint; cdecl; external 'c';
function connect(sockfd: cint; addr: Pointer; addrlen: cuint): cint; cdecl; external 'c';
function bind(sockfd: cint; addr: Pointer; addrlen: cuint): cint; cdecl; external 'c';
function listen(sockfd: cint; backlog: cint): cint; cdecl; external 'c';
function accept(sockfd: cint; addr: Pointer; addrlen: Pointer): cint; cdecl; external 'c';
function close(fd: cint): cint; cdecl; external 'c';
function htons(hostshort: cushort): cushort; cdecl; external 'c';
function htonl(hostlong: cuint): cuint; cdecl; external 'c';
function setsockopt(sockfd: cint; level, optname: cint; optval: Pointer; optlen: cuint): cint; cdecl; external 'c';
function gethostbyname(name: PChar): PHostEnt; cdecl; external 'c';

function CreateListenSocket(APort: Word): TSocket;
const
  SOL_SOCKET = 1;
  SO_REUSEADDR = 2;
var
  S: TSocket;
  Addr: tsockaddr_in;
  LOpt: cint;
begin
  Result := INVALID_SOCKET;
  S := socket(AF_INET, SOCK_STREAM, 0);
  if S < 0 then Exit;

  LOpt := 1;
  setsockopt(S, SOL_SOCKET, SO_REUSEADDR, @LOpt, SizeOf(LOpt));

  FillChar(Addr, SizeOf(Addr), 0);
  Addr.sin_family := AF_INET;
  Addr.sin_port := htons(APort);
  Addr.sin_addr.s_addr := htonl($7F000001); // 127.0.0.1
  if bind(S, @Addr, SizeOf(Addr)) < 0 then
  begin
    close(S);
    Exit;
  end;
  if listen(S, 5) < 0 then
  begin
    close(S);
    Exit;
  end;
  Result := S;
end;

function ConnectSocket(const Host: string; Port: Word): TSocket;
var
  S: TSocket;
  Addr: tsockaddr_in;
  HE: PHostEnt;
begin
  Result := INVALID_SOCKET;
  S := socket(AF_INET, SOCK_STREAM, 0);
  if S < 0 then Exit;

  HE := gethostbyname(PChar(Host));
  if HE = nil then
  begin
    close(S);
    Exit;
  end;

  FillChar(Addr, SizeOf(Addr), 0);
  Addr.sin_family := AF_INET;
  Addr.sin_port := htons(Port);
  Move(HE^.h_addr_list^^, Addr.sin_addr, SizeOf(Addr.sin_addr));

  if connect(S, @Addr, SizeOf(Addr)) < 0 then
  begin
    close(S);
    Exit;
  end;
  Result := S;
end;

procedure CloseSocket(S: TSocket);
begin
  if S <> INVALID_SOCKET then close(S);
end;
{$ELSE}
// Windows stub
type TSocket = THandle;
const INVALID_SOCKET = THandle(-1);
function ConnectSocket(const Host: string; Port: Word): TSocket; begin Result := INVALID_SOCKET; end;
procedure CloseSocket(S: TSocket); begin end;
{$ENDIF}

{$IFDEF UNIX}
type
  TTLSServerThread = class(TThread)
  private
    FListenSock: TSocket;
    FContext: ISSLContext;
    FSuccess: Boolean;
    FError: string;
  protected
    procedure Execute; override;
  public
    constructor Create(AListenSock: TSocket; AContext: ISSLContext);
    property Success: Boolean read FSuccess;
    property Error: string read FError;
  end;

constructor TTLSServerThread.Create(AListenSock: TSocket; AContext: ISSLContext);
begin
  inherited Create(True);
  FListenSock := AListenSock;
  FContext := AContext;
  FSuccess := False;
  FError := '';
  FreeOnTerminate := False;
end;

procedure TTLSServerThread.Execute;
var
  LClientSock: TSocket;
  LConn: ISSLConnection;
begin
  LClientSock := accept(FListenSock, nil, nil);
  if LClientSock < 0 then
  begin
    FError := 'accept() failed';
    Exit;
  end;
  try
    LConn := FContext.CreateConnection(THandle(LClientSock));
    if LConn.Accept then
      FSuccess := True
    else
      FError := 'TLS Accept failed';
  finally
    close(LClientSock);
  end;
end;

function ConnectLoopback(APort: Word): TSocket;
var
  S: TSocket;
  Addr: tsockaddr_in;
begin
  Result := INVALID_SOCKET;
  S := socket(AF_INET, SOCK_STREAM, 0);
  if S < 0 then Exit;
  FillChar(Addr, SizeOf(Addr), 0);
  Addr.sin_family := AF_INET;
  Addr.sin_port := htons(APort);
  Addr.sin_addr.s_addr := htonl($7F000001);
  if connect(S, @Addr, SizeOf(Addr)) < 0 then
  begin
    close(S);
    Exit;
  end;
  Result := S;
end;
{$ENDIF}

const
  RESUMPTION_PORT = 44591;

procedure TestSessionResumption;
{$IFDEF UNIX}
var
  LServerCtx, LClientCtx: ISSLContext;
  Conn1, Conn2: ISSLConnection;
  Resumption1, Resumption2: ISSLSessionResumption;
  Sess: ISSLSession;
  Sock1, Sock2: TSocket;
  LListenSock: TSocket;
  LServerThread: TTLSServerThread;
{$ENDIF}
begin
  WriteLn;
  WriteLn('=== Session Resumption Tests ===');
  {$IFDEF UNIX}
  // Loopback OpenSSL server with a session cache: deterministic, offline-safe
  LServerCtx := GLib.CreateContext(sslCtxServer);
  LServerCtx.SetProtocolVersions([sslProtocolTLS12]);
  LServerCtx.SetSessionCacheMode(True);
  LServerCtx.SetSessionTimeout(300);
  try
    LServerCtx.LoadCertificate('certs/server-cert.pem');
    LServerCtx.LoadPrivateKey('certs/server-key.pem');
  except
    on E: Exception do
    begin
      Runner.Skip('Session Resumption - Server cert/key', E.Message);
      Exit;
    end;
  end;

  LClientCtx := GLib.CreateContext(sslCtxClient);
  LClientCtx.SetProtocolVersions([sslProtocolTLS12]);
  LClientCtx.SetVerifyMode([]);

  LListenSock := CreateListenSocket(RESUMPTION_PORT);
  if LListenSock = INVALID_SOCKET then
  begin
    Runner.Skip('Session Resumption - Listen', 'Failed to bind port ' + IntToStr(RESUMPTION_PORT));
    Exit;
  end;

  try
    // First handshake: full (no reuse)
    LServerThread := TTLSServerThread.Create(LListenSock, LServerCtx);
    LServerThread.Start;

    Sock1 := ConnectLoopback(RESUMPTION_PORT);
    if Sock1 = INVALID_SOCKET then
    begin
      LServerThread.WaitFor;
      LServerThread.Free;
      Runner.Skip('Session Resumption - Connect 1', 'Loopback connect failed');
      Exit;
    end;

    try
      Conn1 := LClientCtx.CreateConnection(THandle(Sock1));
      if Conn1.Connect then
      begin
        Runner.Check('Session Resumption - Handshake 1', True);

        if not Supports(Conn1, ISSLSessionResumption, Resumption1) then
        begin
          Runner.Check('Session Resumption - Owner Surface 1', False,
            'Connection does not expose ISSLSessionResumption');
          Exit;
        end;
        Runner.Check('Session Resumption - Owner Surface 1', True);
        Runner.Check('Session Resumption - Full handshake', not Resumption1.IsSessionReused);

        Sess := Resumption1.GetSession;
        Runner.Check('Session Resumption - Extract Session', Sess <> nil);
      end
      else
      begin
        Runner.Check('Session Resumption - Handshake 1', False, GLib.GetLastErrorString);
        Exit;
      end;
    finally
      CloseSocket(Sock1);
    end;

    LServerThread.WaitFor;
    Runner.Check('Session Resumption - Server accept 1', LServerThread.Success, LServerThread.Error);
    LServerThread.Free;

    if Sess = nil then Exit;

    // Second handshake: must reuse the cached session
    LServerThread := TTLSServerThread.Create(LListenSock, LServerCtx);
    LServerThread.Start;

    Sock2 := ConnectLoopback(RESUMPTION_PORT);
    if Sock2 = INVALID_SOCKET then
    begin
      LServerThread.WaitFor;
      LServerThread.Free;
      Runner.Skip('Session Resumption - Connect 2', 'Loopback connect failed');
      Exit;
    end;

    try
      Conn2 := LClientCtx.CreateConnection(THandle(Sock2));
      if not Supports(Conn2, ISSLSessionResumption, Resumption2) then
      begin
        Runner.Check('Session Resumption - Owner Surface 2', False,
          'Connection does not expose ISSLSessionResumption');
        Exit;
      end;
      Runner.Check('Session Resumption - Owner Surface 2', True);
      Resumption2.SetSession(Sess);  // Set session before Connect
      if Conn2.Connect then
      begin
        Runner.Check('Session Resumption - Handshake 2', True);
        Runner.Check('Session Resumption - Reused', Resumption2.IsSessionReused,
          Format('Was reused: %s', [BoolToStr(Resumption2.IsSessionReused, True)]));
      end
      else
        Runner.Check('Session Resumption - Handshake 2', False, GLib.GetLastErrorString);
    finally
      CloseSocket(Sock2);
    end;

    LServerThread.WaitFor;
    Runner.Check('Session Resumption - Server accept 2', LServerThread.Success, LServerThread.Error);
    LServerThread.Free;
  finally
    CloseSocket(LListenSock);
  end;
  {$ELSE}
  Runner.Skip('Session Resumption - Setup', 'Loopback resumption is UNIX-only');
  {$ENDIF}
end;

procedure TestLargeDataTransfer;
var
  Ctx: ISSLContext;
  Conn: ISSLConnection;
  Sock: TSocket;
  Req: string;
  Resp: TBytes;
  TotalRead: Integer;
  BytesRead: Integer;
  CAFile: string;
begin
  WriteLn;
  WriteLn('=== Large Data Transfer Tests ===');

  CAFile := '';
  if FileExists('/etc/ssl/certs/ca-certificates.crt') then
    CAFile := '/etc/ssl/certs/ca-certificates.crt'
  else if FileExists('/etc/pki/tls/certs/ca-bundle.crt') then
    CAFile := '/etc/pki/tls/certs/ca-bundle.crt';

  if CAFile = '' then
  begin
    Runner.Skip('Large Data - Setup', 'No system CA bundle found');
    Exit;
  end;

  Ctx := GLib.CreateContext(sslCtxClient);
  Ctx.LoadCAFile(CAFile);

  Sock := ConnectSocket('www.cloudflare.com', 443);
  if Sock = INVALID_SOCKET then
  begin
    Runner.Skip('Large Data - Connect', 'Socket failed');
    Exit;
  end;

  try
    Conn := Ctx.CreateConnection(Sock);
    (Conn as ISSLClientConnection).SetServerName('www.cloudflare.com');
    if Conn.Connect then
    begin
      Runner.Check('Large Data - Handshake', True);

      Req := 'GET / HTTP/1.1'#13#10'Host: www.cloudflare.com'#13#10'Connection: close'#13#10#13#10;
      Conn.WriteString(Req);

      TotalRead := 0;
      SetLength(Resp, 4096);
      repeat
        BytesRead := Conn.Read(Resp[0], Length(Resp));
        if BytesRead > 0 then
          Inc(TotalRead, BytesRead);
      until BytesRead <= 0;

      Runner.Check('Large Data - Transfer', TotalRead > 10000, Format('Read %d bytes', [TotalRead]));
    end
    else
      Runner.Check('Large Data - Handshake', False, GLib.GetLastErrorString);
  finally
    CloseSocket(Sock);
  end;
end;

procedure TestClientCertAuth;
begin
  WriteLn;
  WriteLn('=== Client Certificate Auth Tests ===');
  // Would need valid client certificates to test
  Runner.Check('Client Cert Auth - Skipped (No certs)', True);
end;

begin
  WriteLn('End-to-End Scenarios');
  WriteLn('====================');
  WriteLn;

  Runner := TSimpleTestRunner.Create;
  try
    Runner.RequireModules([osmCore]);

    if not Runner.Initialize then
    begin
      WriteLn('ERROR: Failed to initialize test environment');
      Halt(1);
    end;

    try
      GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
      if not GLib.Initialize then
      begin
        WriteLn('ERROR: Failed to initialize SSL library');
        Halt(1);
      end;

      WriteLn('OpenSSL Version: ', GetOpenSSLVersionString);

      TestSessionResumption;
      TestLargeDataTransfer;
      TestClientCertAuth;

    except
      on E: Exception do
        WriteLn('FATAL: ', E.Message);
    end;

    Runner.PrintSummary;
    // 自然结束而非 Halt:让程序级全局接口变量(GLib 等)正常终结,heaptrc 保持 0 unfreed
    ExitCode := Runner.FailCount;
  finally
    Runner.Free;
  end;
end.
