#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${FAFAFA_TLS_PORT:-44330}"
HOST="${FAFAFA_TLS_HOST:-localhost}"
WORKDIR="$(mktemp -d -t fafafa_fp_keyupdate_smoke_XXXXXX)"
SERVER_LOG="$WORKDIR/s_server.log"
CLIENT_LOG="$WORKDIR/fp_client.log"

SERVER_PID=""
cleanup() {
  if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" >/dev/null 2>&1; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    sleep 0.2
    if kill -0 "$SERVER_PID" >/dev/null 2>&1; then
      kill -9 "$SERVER_PID" >/dev/null 2>&1 || true
    fi
  fi
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[ERROR] Missing required command: $cmd" >&2
    exit 1
  fi
}

require_cmd openssl
require_cmd fpc

CERT_FILE="$WORKDIR/server.crt"
KEY_FILE="$WORKDIR/server.key"

openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "$KEY_FILE" -out "$CERT_FILE" \
  -days 1 -subj "/CN=$HOST" >/dev/null 2>&1

cat > "$WORKDIR/fp_tls13_keyupdate_client.pas" <<'PAS'
program fp_tls13_keyupdate_client;

{$mode ObjFPC}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

uses
  SysUtils,
  fafafa.ssl,
  nextpas.core.tls.base,
  fafafa.examples.tcp;

var
  Ctx: ISSLContext;
  Conn: ISSLConnection;
  ClientConn: ISSLClientConnection;
  Sock: TSocketHandle;
  NetErr: string;
  Req: RawByteString;
  Resp: array[0..4095] of Byte;
  N: Integer;
  PortStr: string;
  PortNum: Integer;
begin
  PortStr := GetEnvironmentVariable('FAFAFA_TLS_PORT');
  if PortStr = '' then
    PortNum := 44330
  else
    PortNum := StrToIntDef(PortStr, 44330);

  if not InitNetwork(NetErr) then
  begin
    WriteLn('network init failed: ', NetErr);
    Halt(1);
  end;

  Sock := INVALID_SOCKET;
  try
    Ctx := TSSLFactory.CreateContext(sslCtxClient, sslFreePascal);
    Ctx.SetProtocolVersions([sslProtocolTLS13]);
    Ctx.SetPreferredVersion(sslProtocolTLS13);

    Sock := ConnectTCP('localhost', PortNum);
    Conn := Ctx.CreateConnection(THandle(Sock));
    if Conn = nil then
    begin
      WriteLn('connection create failed');
      Halt(1);
    end;

    if Supports(Conn, ISSLClientConnection, ClientConn) then
      ClientConn.SetServerName('localhost');

    if not Conn.Connect then
    begin
      WriteLn('connect failed: ', Conn.GetVerifyResultString);
      Halt(2);
    end;

    if not Conn.Renegotiate then
    begin
      WriteLn('key update failed: ', Conn.GetVerifyResultString);
      Halt(3);
    end;

    Req := 'GET / HTTP/1.1' + #13#10 +
           'Host: localhost' + #13#10 +
           'Connection: close' + #13#10 +
           #13#10;

    if Conn.Write(Req[1], Length(Req)) <> Length(Req) then
    begin
      WriteLn('write failed: ', Conn.GetVerifyResultString);
      Halt(4);
    end;

    N := Conn.Read(Resp[0], SizeOf(Resp));
    if N <= 0 then
    begin
      WriteLn('read failed: ', Conn.GetVerifyResultString);
      Halt(5);
    end;

    WriteLn('SMOKE_OK bytes=', N);
  finally
    if Sock <> INVALID_SOCKET then
      CloseSocket(Sock);
    CleanupNetwork;
  end;
end.
PAS

fpc -B -Mobjfpc -Sh \
  -Fu"$ROOT_DIR/src" \
  -Fi"$ROOT_DIR/src" \
  -Fu"$ROOT_DIR/examples" \
  -FU"$ROOT_DIR/lib" \
  "$WORKDIR/fp_tls13_keyupdate_client.pas" \
  -o"$WORKDIR/fp_tls13_keyupdate_client" >/dev/null 2>&1

openssl s_server -quiet -www \
  -accept "$PORT" \
  -tls1_3 \
  -ciphersuites TLS_CHACHA20_POLY1305_SHA256 \
  -cert "$CERT_FILE" \
  -key "$KEY_FILE" >"$SERVER_LOG" 2>&1 &
SERVER_PID=$!

for _ in {1..20}; do
  if kill -0 "$SERVER_PID" >/dev/null 2>&1; then
    sleep 0.1
    if (echo >"/dev/tcp/127.0.0.1/$PORT") >/dev/null 2>&1; then
      break
    fi
  fi
  sleep 0.1
done

FAFAFA_TLS_PORT="$PORT" "$WORKDIR/fp_tls13_keyupdate_client" >"$CLIENT_LOG" 2>&1 || {
  echo "[ERROR] KeyUpdate smoke client failed" >&2
  echo "--- client log ---" >&2
  cat "$CLIENT_LOG" >&2 || true
  echo "--- s_server log (tail) ---" >&2
  tail -n 120 "$SERVER_LOG" >&2 || true
  exit 1
}

if ! rg -q "SMOKE_OK" "$CLIENT_LOG"; then
  echo "[ERROR] SMOKE_OK marker not found" >&2
  echo "--- client log ---" >&2
  cat "$CLIENT_LOG" >&2 || true
  exit 1
fi

echo "[OK] FreePascal TLS1.3 KeyUpdate smoke passed"
cat "$CLIENT_LOG"
