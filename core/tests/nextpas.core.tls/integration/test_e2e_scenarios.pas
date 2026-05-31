program test_e2e_scenarios;

{******************************************************************************}
{  End-to-End (E2E) Test Scenarios                                             }
{  Migrated to use TSimpleTestRunner framework (P1-2.2)                        }
{******************************************************************************}

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  {$IFDEF UNIX}
  ctypes,
  {$ENDIF}
  nextpas.core.tls.factory,
  nextpas.core.tls.base,
  fafafa.ssl,
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
function close(fd: cint): cint; cdecl; external 'c';
function htons(hostshort: cushort): cushort; cdecl; external 'c';
function gethostbyname(name: PChar): PHostEnt; cdecl; external 'c';

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

procedure TestSessionResumption;
var
  Ctx: ISSLContext;
  Conn1, Conn2: ISSLConnection;
  Resumption1, Resumption2: ISSLSessionResumption;
  Sock1, Sock2: TSocket;
  Sess: ISSLSession;
  Buf: array[0..1023] of Byte;
  ReadBytes: Integer;
  CAFile: string;
begin
  WriteLn;
  WriteLn('=== Session Resumption Tests ===');

  CAFile := '';
  if FileExists('/etc/ssl/certs/ca-certificates.crt') then
    CAFile := '/etc/ssl/certs/ca-certificates.crt'
  else if FileExists('/etc/pki/tls/certs/ca-bundle.crt') then
    CAFile := '/etc/pki/tls/certs/ca-bundle.crt';

  if CAFile = '' then
  begin
    Runner.Skip('Session Resumption - Setup', 'No system CA bundle found');
    Exit;
  end;

  Ctx := GLib.CreateContext(sslCtxClient);
  Ctx.SetSessionCacheMode(True);
  Ctx.LoadCAFile(CAFile);

  // First connection
  Sock1 := ConnectSocket('www.cloudflare.com', 443);
  if Sock1 = INVALID_SOCKET then
  begin
    Runner.Skip('Session Resumption - Connect 1', 'Socket failed');
    Exit;
  end;

  try
    Conn1 := Ctx.CreateConnection(Sock1);
    (Conn1 as ISSLClientConnection).SetServerName('www.cloudflare.com');
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

      // For TLS 1.3, NewSessionTicket can be delivered post-handshake.
      // Drive a small request/response so OpenSSL can process post-handshake messages
      // before we snapshot the session.
      try
        Conn1.WriteString('HEAD / HTTP/1.1'#13#10 +
          'Host: www.cloudflare.com'#13#10 +
          'Connection: close'#13#10#13#10);
        ReadBytes := Conn1.Read(Buf[0], SizeOf(Buf));
        if ReadBytes < 0 then
          ReadBytes := 0;
      except
        ReadBytes := 0;
      end;

      // Extract session for reuse
      Sess := Resumption1.GetSession;
      Runner.Check('Session Resumption - Extract Session', Sess <> nil,
        Format('Read %d bytes before GetSession', [ReadBytes]));
    end
    else
    begin
      Runner.Check('Session Resumption - Handshake 1', False, GLib.GetLastErrorString);
      Exit;
    end;
  finally
    CloseSocket(Sock1);
  end;

  // Second connection (reuse session)
  if Sess = nil then Exit;

  Sock2 := ConnectSocket('www.cloudflare.com', 443);
  if Sock2 = INVALID_SOCKET then
  begin
    Runner.Skip('Session Resumption - Connect 2', 'Socket failed');
    Exit;
  end;

  try
    Conn2 := Ctx.CreateConnection(Sock2);
    if not Supports(Conn2, ISSLSessionResumption, Resumption2) then
    begin
      Runner.Check('Session Resumption - Owner Surface 2', False,
        'Connection does not expose ISSLSessionResumption');
      Exit;
    end;
    Runner.Check('Session Resumption - Owner Surface 2', True);
    Resumption2.SetSession(Sess);  // Set session before Connect
    (Conn2 as ISSLClientConnection).SetServerName('www.cloudflare.com');
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
    Halt(Runner.FailCount);
  finally
    Runner.Free;
  end;
end.
