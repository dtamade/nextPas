#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKDIR="$(mktemp -d -t fafafa_fp_srv_probe_XXXXXX)"
PORT="${FAFAFA_TLS_PORT:-19443}"
SERVER_LOG="$WORKDIR/server.log"
CLIENT_ERR="$WORKDIR/client.err"
CLIENT_OUT="$WORKDIR/client.out"

cleanup() {
  if [[ -n "${SPID:-}" ]]; then
    kill "$SPID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

cat > "$WORKDIR/fp_tls13_server_probe.pas" <<'PAS'
program fp_tls13_server_probe;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  BaseUnix,
  Sockets,
  fafafa.ssl,
  nextpas.core.tls.base,
  nextpas.core.tls.factory;

procedure Die(const Msg: string);
begin
  WriteLn('ERR ', Msg);
  Halt(1);
end;

var
  ListenSock: LongInt;
  ClientSock: LongInt;
  Addr: TInetSockAddr;
  AddrLen: TSockLen;
  Ctx: ISSLContext;
  Conn: ISSLConnection;
  Port: Integer;
  Ret: Integer;
  Buf: array[0..4095] of Byte;
  Resp: AnsiString;
  CertPath: string;
  KeyPath: string;
begin
  Port := StrToIntDef(GetEnvironmentVariable('FAFAFA_TLS_PORT'), 19443);
  CertPath := GetEnvironmentVariable('FAFAFA_TLS_CERT');
  KeyPath := GetEnvironmentVariable('FAFAFA_TLS_KEY');
  if CertPath = '' then
    CertPath := 'tests/certificate/test_certs/signer_cert.pem';
  if KeyPath = '' then
    KeyPath := 'tests/certificate/test_certs/signer_key.pem';

  ListenSock := fpSocket(AF_INET, SOCK_STREAM, 0);
  if ListenSock < 0 then Die('socket failed');

  FillChar(Addr, SizeOf(Addr), 0);
  Addr.sin_family := AF_INET;
  Addr.sin_addr := StrToNetAddr('127.0.0.1');
  Addr.sin_port := htons(Port);

  if fpBind(ListenSock, @Addr, SizeOf(Addr)) <> 0 then Die('bind failed');
  if fpListen(ListenSock, 1) <> 0 then Die('listen failed');

  WriteLn('LISTEN ', Port);

  AddrLen := SizeOf(Addr);
  ClientSock := fpAccept(ListenSock, @Addr, @AddrLen);
  if ClientSock < 0 then Die('accept failed');

  Ctx := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  Ctx.SetPreferredVersion(sslProtocolTLS13);
  Ctx.LoadCertificate(CertPath);
  Ctx.LoadPrivateKey(KeyPath);

  Conn := Ctx.CreateConnection(ClientSock);
  if Conn = nil then Die('create connection failed');

  if not Conn.Accept then
  begin
    WriteLn('HS_FAIL code=', Ord(Conn.GetError(-1)), ' detail=', Conn.GetVerifyResultString);
    Halt(2);
  end;

  Ret := Conn.Read(Buf, SizeOf(Buf));
  if Ret > 0 then
  begin
    Resp := 'HTTP/1.1 200 OK'#13#10'Content-Length: 2'#13#10'Connection: close'#13#10#13#10'OK';
    Conn.Write(Resp[1], Length(Resp));
  end;

  WriteLn('HS_OK');
end.
PAS

cd "$ROOT_DIR"
fpc -B -Mobjfpc -Sh -Fu./src -Fi./src -FU./lib "$WORKDIR/fp_tls13_server_probe.pas" -o"$WORKDIR/fp_tls13_server_probe" >/dev/null

FAFAFA_TLS_PORT="$PORT" "$WORKDIR/fp_tls13_server_probe" >"$SERVER_LOG" 2>&1 &
SPID=$!
sleep 0.6

set +e
printf 'GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n' | \
  openssl s_client \
    -connect "127.0.0.1:${PORT}" \
    -tls1_3 \
    -ciphersuites TLS_CHACHA20_POLY1305_SHA256 \
    -servername localhost \
    -quiet >"$CLIENT_OUT" 2>"$CLIENT_ERR"
OPENSSL_RC=$?
set -e

wait "$SPID" || true

echo "[probe] workdir=$WORKDIR"
echo "[probe] openssl_rc=$OPENSSL_RC"
echo "--- server.log ---"
cat "$SERVER_LOG"
echo "--- client.err (tail) ---"
tail -n 20 "$CLIENT_ERR"
echo "--- client.out (tail) ---"
tail -n 20 "$CLIENT_OUT"

if grep -qi "bad signature" "$CLIENT_ERR"; then
  echo "PROBE_RESULT=BAD_SIGNATURE"
  exit 1
fi

if grep -q "HS_OK" "$SERVER_LOG"; then
  echo "PROBE_RESULT=SUCCESS"
  exit 0
fi

if [[ "$OPENSSL_RC" -eq 0 ]]; then
  echo "PROBE_RESULT=SUCCESS"
  exit 0
fi

echo "PROBE_RESULT=UNEXPECTED_FAILURE"
exit 1
