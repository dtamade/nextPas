program bench_tls_handshake;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.text.format,
  nextpas.core.platform.socket,
  nextpas.core.crypto.x25519,
  nextpas.core.tls.tls13.clienthello,
  nextpas.core.tls.tls13.keyschedule,
  nextpas.core.tls.tls13.parser,
  nextpas.core.tls.tls13.wire,
  nextpas.core.tls.base,
  nextpas.core.tls.openssl.backed;

{$IFDEF LINUX}
function ClockGetTimeNs: Int64;
var
  LBuf: array[0..1] of Int64;
  LPtr: Pointer;
begin
  LBuf[0] := 0;
  LBuf[1] := 0;
  LPtr := @LBuf[0];
  asm
    movq $1, %rdi
    movq LPtr, %rsi
    movq $228, %rax
    syscall
  end ['rax', 'rdi', 'rsi', 'rdx', 'rcx', 'r11'];
  Result := LBuf[0] * 1000000000 + LBuf[1];
end;
{$ENDIF}

procedure BenchPurePascalKeyExchange(AIters: Integer);
var
  LPriv, LPub, LServerPub, LShared, LTranscript, LCH: TBytes;
  LSecrets: TTLS13HandshakeSecrets;
  LError: string;
  LStart, LEnd: Int64;
  I: Integer;
  LUsPerIter: Double;
begin
  // Pre-generate a "server" public key
  GenerateX25519KeyPair(LServerPub, LPub);
  LServerPub := LPub;

  LStart := ClockGetTimeNs;
  for I := 1 to AIters do
  begin
    GenerateX25519KeyPair(LPriv, LPub);
    LCH := BuildTLS13ClientHelloRecord('bench.test', '', LPub);
    LShared := X25519ComputeSharedSecret(LPriv, LServerPub);
    SetLength(LTranscript, 64);
    FillChar(LTranscript[0], 64, Byte(I));
    InitTLS13HandshakeSecrets(LSecrets);
    TryDeriveTLS13HandshakeSecrets($1301, LShared, LTranscript, LSecrets, LError);
    ClearTLS13HandshakeSecrets(LSecrets);
  end;
  LEnd := ClockGetTimeNs;

  LUsPerIter := (LEnd - LStart) / 1000.0 / AIters;
  WriteLn(TextFormat('  Pure Pascal key exchange:  %8.1f us/op  (%d iters)', [LUsPerIter, AIters]));
end;

procedure BenchOpenSSLHandshake(AIters: Integer);
var
  LLib: ISSLLibrary;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LSock: TPlatformSocket;
  LAddr: TPlatformSockAddr;
  LStart, LEnd: Int64;
  I, LSuccess: Integer;
  LUsPerIter: Double;
begin
  LLib := CreateOpenSSLLibrary;
  if not LLib.Initialize then begin WriteLn('  OpenSSL init failed'); Exit; end;

  LCtx := LLib.CreateContext(sslCtxClient);
  LCtx.SetVerifyMode([]);
  LCtx.SetServerName('cloudflare.com');

  platform_sockaddr_ipv4(443, platform_ipv4_parse('1.1.1.1'), LAddr);

  LSuccess := 0;
  LStart := ClockGetTimeNs;
  for I := 1 to AIters do
  begin
    if platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
      0, LSock) <> 0 then
      Continue;
    if platform_socket_connect(LSock, @LAddr.Storage[0], LAddr.Len) <> 0 then
    begin
      platform_socket_close(LSock);
      Continue;
    end;

    LConn := LCtx.CreateConnection(THandle(LSock.Value));
    if LConn.Connect then
      Inc(LSuccess);
    LConn.Shutdown;
    LConn.Close;
    LConn := nil;
    platform_socket_close(LSock);
  end;
  LEnd := ClockGetTimeNs;

  LUsPerIter := (LEnd - LStart) / 1000.0 / AIters;
  WriteLn(TextFormat('  OpenSSL TLS 1.3 handshake: %8.1f us/op  (%d/%d success)', [LUsPerIter, LSuccess, AIters]));

  LCtx := nil;
  LLib.Finalize;
end;

begin
  WriteLn('=== TLS Handshake Performance Benchmark ===');
  WriteLn;

  WriteLn('--- Crypto-only (no network) ---');
  BenchPurePascalKeyExchange(100);
  BenchPurePascalKeyExchange(500);
  WriteLn;

  WriteLn('--- Full handshake (network + TLS) ---');
  BenchOpenSSLHandshake(5);
  WriteLn;

  WriteLn('Done.');
end.
