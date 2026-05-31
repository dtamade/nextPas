#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKDIR="$(mktemp -d -t fafafa_tls13_sign_bench_XXXXXX)"

ITERATIONS="${FAFAFA_TLS13_SIGN_BENCH_ITERATIONS:-10}"
WARMUP="${FAFAFA_TLS13_SIGN_BENCH_WARMUP:-2}"
SCHEME="${FAFAFA_TLS13_SIGN_BENCH_SCHEME:-rsa_pkcs1_sha256}"
KEY_FILE="${FAFAFA_TLS13_SIGN_BENCH_KEY:-tests/certificate/test_certs/signer_key.pem}"
KEEP_WORKDIR="${FAFAFA_TLS13_SIGN_BENCH_KEEP_WORKDIR:-0}"
TIMEOUT_SECONDS="${FAFAFA_TLS13_SIGN_BENCH_TIMEOUT:-120}"
JSON_OUT="${FAFAFA_TLS13_SIGN_BENCH_JSON_OUT:-}"

cleanup() {
  if [[ "$KEEP_WORKDIR" = "1" ]]; then
    echo "[bench] keep workdir: $WORKDIR"
  else
    rm -rf "$WORKDIR"
  fi
}
trap cleanup EXIT

if [[ ! "$ITERATIONS" =~ ^[0-9]+$ ]] || [[ "$ITERATIONS" -le 0 ]]; then
  echo "[bench] invalid FAFAFA_TLS13_SIGN_BENCH_ITERATIONS: $ITERATIONS" >&2
  exit 2
fi

if [[ ! "$WARMUP" =~ ^[0-9]+$ ]] || [[ "$WARMUP" -lt 0 ]]; then
  echo "[bench] invalid FAFAFA_TLS13_SIGN_BENCH_WARMUP: $WARMUP" >&2
  exit 2
fi

if [[ ! -f "$ROOT_DIR/$KEY_FILE" ]]; then
  echo "[bench] key not found: $ROOT_DIR/$KEY_FILE" >&2
  exit 2
fi

if [[ ! "$TIMEOUT_SECONDS" =~ ^[0-9]+$ ]] || [[ "$TIMEOUT_SECONDS" -le 0 ]]; then
  echo "[bench] invalid FAFAFA_TLS13_SIGN_BENCH_TIMEOUT: $TIMEOUT_SECONDS" >&2
  exit 2
fi

if [[ "$SCHEME" != "rsa_pkcs1_sha256" && "$SCHEME" != "rsa_pss_rsae_sha256" && "$SCHEME" != "rsa_pss_pss_sha256" ]]; then
  echo "[bench] invalid FAFAFA_TLS13_SIGN_BENCH_SCHEME: $SCHEME" >&2
  exit 2
fi

cat > "$WORKDIR/bench_tls13_servercertverify.pas" <<'PAS'
program bench_tls13_servercertverify;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  Classes,
  nextpas.core.tls.tls13.wire,
  nextpas.core.tls.tls13.servercertverify,
  nextpas.core.tls.pem;

function LoadFileBytes(const AFileName: string): TBytes;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Result, LStream.Size);
    if LStream.Size > 0 then
      LStream.ReadBuffer(Result[0], LStream.Size);
  finally
    LStream.Free;
  end;
end;

function TryReadDERLength(const AData: TBytes; var AOffset: Integer; out ALength: Integer): Boolean;
var
  LFirst: Byte;
  LCount: Integer;
  I: Integer;
begin
  ALength := 0;
  Result := False;

  if (AOffset < 0) or (AOffset >= Length(AData)) then
    Exit;

  LFirst := AData[AOffset];
  Inc(AOffset);

  if (LFirst and $80) = 0 then
  begin
    ALength := LFirst;
    Exit(True);
  end;

  LCount := LFirst and $7F;
  if (LCount <= 0) or (LCount > 4) or (AOffset + LCount > Length(AData)) then
    Exit;

  ALength := 0;
  for I := 1 to LCount do
  begin
    ALength := (ALength shl 8) or AData[AOffset];
    Inc(AOffset);
  end;

  Result := True;
end;

function TryLocatePKCS1FieldValue(
  const ADER: TBytes;
  AFieldIndex: Integer;
  out AValueOffset: Integer;
  out AValueLength: Integer
): Boolean;
var
  LOffset: Integer;
  LSeqLength: Integer;
  LSeqEnd: Integer;
  LField: Integer;
begin
  AValueOffset := -1;
  AValueLength := 0;
  Result := False;

  if Length(ADER) < 4 then
    Exit;

  LOffset := 0;
  if ADER[LOffset] <> $30 then
    Exit;
  Inc(LOffset);

  if not TryReadDERLength(ADER, LOffset, LSeqLength) then
    Exit;

  LSeqEnd := LOffset + LSeqLength;
  if LSeqEnd > Length(ADER) then
    Exit;

  LField := 0;
  while LOffset < LSeqEnd do
  begin
    if ADER[LOffset] <> $02 then
      Exit;
    Inc(LOffset);

    if not TryReadDERLength(ADER, LOffset, AValueLength) then
      Exit;

    if (AValueLength < 0) or (LOffset + AValueLength > LSeqEnd) then
      Exit;

    if LField = AFieldIndex then
    begin
      AValueOffset := LOffset;
      Exit(True);
    end;

    Inc(LOffset, AValueLength);
    Inc(LField);
  end;
end;

function TryLocatePKCS8PrivateKeyOctetStringValue(
  const ADER: TBytes;
  out AValueOffset: Integer;
  out AValueLength: Integer
): Boolean;
var
  LOffset: Integer;
  LSeqLength: Integer;
  LChildLength: Integer;
begin
  AValueOffset := -1;
  AValueLength := 0;
  Result := False;

  if Length(ADER) < 8 then
    Exit;

  LOffset := 0;
  if ADER[LOffset] <> $30 then
    Exit;
  Inc(LOffset);
  if not TryReadDERLength(ADER, LOffset, LSeqLength) then
    Exit;
  if LOffset + LSeqLength > Length(ADER) then
    Exit;

  if (LOffset >= Length(ADER)) or (ADER[LOffset] <> $02) then
    Exit;
  Inc(LOffset);
  if not TryReadDERLength(ADER, LOffset, LChildLength) then
    Exit;
  Inc(LOffset, LChildLength);

  if (LOffset >= Length(ADER)) or (ADER[LOffset] <> $30) then
    Exit;
  Inc(LOffset);
  if not TryReadDERLength(ADER, LOffset, LChildLength) then
    Exit;
  Inc(LOffset, LChildLength);

  if (LOffset >= Length(ADER)) or (ADER[LOffset] <> $04) then
    Exit;
  Inc(LOffset);
  if not TryReadDERLength(ADER, LOffset, AValueLength) then
    Exit;
  if LOffset + AValueLength > Length(ADER) then
    Exit;

  AValueOffset := LOffset;
  Result := True;
end;

function TryExtractFirstPrivateKeyDER(
  const APEMBlob: TBytes;
  out ADER: TBytes;
  out AType: TPEMType
): Boolean;
var
  LReader: TPEMReader;
  LBlocks: TPEMBlockArray;
  LText: string;
  I: Integer;
begin
  SetLength(ADER, 0);
  AType := pemUnknown;
  Result := False;

  LReader := TPEMReader.Create;
  try
    LText := TEncoding.ANSI.GetString(APEMBlob);
    LReader.LoadFromString(LText);
    LBlocks := LReader.GetPrivateKeys;
    for I := 0 to High(LBlocks) do
    begin
      if LBlocks[I].IsEncrypted then
        Continue;
      if not (LBlocks[I].BlockType in [pemPrivateKey, pemRSAPrivateKey]) then
        Continue;

      ADER := Copy(LBlocks[I].Data, 0, Length(LBlocks[I].Data));
      AType := LBlocks[I].BlockType;
      Exit(Length(ADER) > 0);
    end;
  finally
    LReader.Free;
  end;
end;

function BuildNoCRTPrivateKeyBlob(const APEMBlob: TBytes): TBytes;
var
  LDER: TBytes;
  LInner: TBytes;
  LType: TPEMType;
  LOffset: Integer;
  LLength: Integer;
  LCoefOffset: Integer;
  LCoefLength: Integer;
  I: Integer;
begin
  SetLength(Result, 0);

  if not TryExtractFirstPrivateKeyDER(APEMBlob, LDER, LType) then
    Exit;

  if LType = pemRSAPrivateKey then
  begin
    Result := Copy(LDER, 0, Length(LDER));
    if not TryLocatePKCS1FieldValue(Result, 8, LCoefOffset, LCoefLength) then
      Exit;

    for I := 0 to LCoefLength - 1 do
      Result[LCoefOffset + I] := 0;
    Exit;
  end;

  if LType = pemPrivateKey then
  begin
    if not TryLocatePKCS8PrivateKeyOctetStringValue(LDER, LOffset, LLength) then
      Exit;

    LInner := Copy(LDER, LOffset, LLength);
    if not TryLocatePKCS1FieldValue(LInner, 8, LCoefOffset, LCoefLength) then
      Exit;

    for I := 0 to LCoefLength - 1 do
      LInner[LCoefOffset + I] := 0;

    Result := Copy(LDER, 0, Length(LDER));
    Move(LInner[0], Result[LOffset], LLength);
    Exit;
  end;
end;

function ResolveSignatureScheme(const AName: string; out AScheme: Word): Boolean;
var
  LName: string;
begin
  LName := LowerCase(Trim(AName));

  if (LName = 'rsa_pkcs1_sha256') or (LName = 'pkcs1') then
  begin
    AScheme := TLS13_SIG_RSA_PKCS1_SHA256;
    Exit(True);
  end;

  if (LName = 'rsa_pss_rsae_sha256') or (LName = 'pss_rsae') then
  begin
    AScheme := TLS13_SIG_RSA_PSS_RSAE_SHA256;
    Exit(True);
  end;

  if (LName = 'rsa_pss_pss_sha256') or (LName = 'pss_pss') then
  begin
    AScheme := TLS13_SIG_RSA_PSS_PSS_SHA256;
    Exit(True);
  end;

  AScheme := 0;
  Result := False;
end;

procedure RunBench;
var
  LKeyCRT: TBytes;
  LKeyNoCRT: TBytes;
  LTranscriptHash: TBytes;
  LInput: TBytes;
  LSigCRT: TBytes;
  LSigD: TBytes;
  LErr: string;
  I: Integer;
  LIterations: Integer;
  LWarmup: Integer;
  LSchemeName: string;
  LScheme: Word;
  LKeyPath: string;
  T0, T1: QWord;
  CRTTotal, DTotal: QWord;
  CRTMs, DMs: Double;
begin
  LKeyPath := GetEnvironmentVariable('BENCH_KEY_PATH');
  if LKeyPath = '' then
    LKeyPath := 'tests/certificate/test_certs/signer_key.pem';

  LIterations := StrToIntDef(GetEnvironmentVariable('BENCH_ITERATIONS'), 10);
  LWarmup := StrToIntDef(GetEnvironmentVariable('BENCH_WARMUP'), 2);
  LSchemeName := GetEnvironmentVariable('BENCH_SCHEME');
  if LSchemeName = '' then
    LSchemeName := 'rsa_pkcs1_sha256';

  if (LIterations <= 0) or (LWarmup < 0) then
  begin
    WriteLn('ERROR invalid iteration settings');
    Halt(2);
  end;

  if not ResolveSignatureScheme(LSchemeName, LScheme) then
  begin
    WriteLn('ERROR unsupported scheme: ', LSchemeName);
    Halt(2);
  end;

  LKeyCRT := LoadFileBytes(LKeyPath);
  LKeyNoCRT := BuildNoCRTPrivateKeyBlob(LKeyCRT);

  if Length(LKeyNoCRT) = 0 then
  begin
    WriteLn('ERROR failed to build no-CRT key blob');
    Halt(1);
  end;

  SetLength(LTranscriptHash, 32);
  for I := 0 to 31 do
    LTranscriptHash[I] := Byte($20 + I);
  LInput := BuildTLS13ServerCertificateVerifyInputSHA256(LTranscriptHash);

  for I := 1 to LWarmup do
  begin
    if not TryBuildTLS13CertificateVerifySignature(LScheme, LKeyCRT, LInput, LSigCRT, LErr) then
    begin
      WriteLn('ERROR warmup CRT failed: ', LErr);
      Halt(1);
    end;

    if not TryBuildTLS13CertificateVerifySignature(LScheme, LKeyNoCRT, LInput, LSigD, LErr) then
    begin
      WriteLn('ERROR warmup D failed: ', LErr);
      Halt(1);
    end;
  end;

  T0 := GetTickCount64;
  for I := 1 to LIterations do
  begin
    if not TryBuildTLS13CertificateVerifySignature(LScheme, LKeyCRT, LInput, LSigCRT, LErr) then
    begin
      WriteLn('ERROR CRT bench failed: ', LErr);
      Halt(1);
    end;
  end;
  T1 := GetTickCount64;
  CRTTotal := T1 - T0;

  T0 := GetTickCount64;
  for I := 1 to LIterations do
  begin
    if not TryBuildTLS13CertificateVerifySignature(LScheme, LKeyNoCRT, LInput, LSigD, LErr) then
    begin
      WriteLn('ERROR D bench failed: ', LErr);
      Halt(1);
    end;
  end;
  T1 := GetTickCount64;
  DTotal := T1 - T0;

  CRTMs := CRTTotal / LIterations;
  DMs := DTotal / LIterations;

  WriteLn('BENCH_SCHEME=', LSchemeName);
  WriteLn('BENCH_KEY=', LKeyPath);
  WriteLn('BENCH_ITERATIONS=', LIterations);
  WriteLn('BENCH_WARMUP=', LWarmup);
  WriteLn(Format('CRT_total_ms=%d', [CRTTotal]));
  WriteLn(Format('CRT_avg_ms=%.4f', [CRTMs]));
  WriteLn(Format('D_total_ms=%d', [DTotal]));
  WriteLn(Format('D_avg_ms=%.4f', [DMs]));

  if CRTMs > 0 then
    WriteLn(Format('Speedup_D_over_CRT=%.2fx', [DMs / CRTMs]))
  else
    WriteLn('Speedup_D_over_CRT=INF');
end;

begin
  RunBench;
end.
PAS

cd "$ROOT_DIR"

# Keep the bench on optimized diagnostics without -Criot, which trips compile-time
# range checks in hash constants and hides the real signer runtime path we want to measure.
fpc -MObjFPC -Scghi -O2 -g -gl -vewnhibq \
  -Fu./src -Fu./src/openssl -Fu./src/mbedtls -Fu./src/schannel -Fu./src/wolfssl -Fu./src/freepascal -Fu./src/tls13 \
  -o"$WORKDIR/bench_tls13_servercertverify" "$WORKDIR/bench_tls13_servercertverify.pas"

echo "[bench] compiled: $WORKDIR/bench_tls13_servercertverify"
echo "[bench] scheme=$SCHEME iterations=$ITERATIONS warmup=$WARMUP key=$KEY_FILE"

run_cmd=("$WORKDIR/bench_tls13_servercertverify")
if command -v timeout >/dev/null 2>&1; then
  run_cmd=(timeout "${TIMEOUT_SECONDS}s" "${run_cmd[@]}")
fi

set +e
BENCH_OUTPUT=$(BENCH_KEY_PATH="$KEY_FILE" \
BENCH_SCHEME="$SCHEME" \
BENCH_ITERATIONS="$ITERATIONS" \
BENCH_WARMUP="$WARMUP" \
"${run_cmd[@]}" 2>&1)
BENCH_RC=$?
set -e

echo "$BENCH_OUTPUT"

if [[ "$BENCH_RC" -eq 124 ]]; then
  echo "[bench] timed out after ${TIMEOUT_SECONDS}s" >&2
  exit 124
fi

if [[ "$BENCH_RC" -ne 0 ]]; then
  echo "[bench] failed with exit code: $BENCH_RC" >&2
  exit "$BENCH_RC"
fi

if [[ -n "$JSON_OUT" ]]; then
  mkdir -p "$(dirname "$JSON_OUT")"

  bench_scheme=$(echo "$BENCH_OUTPUT" | grep -E '^BENCH_SCHEME=' | tail -1 | cut -d '=' -f2 || true)
  bench_key=$(echo "$BENCH_OUTPUT" | grep -E '^BENCH_KEY=' | tail -1 | cut -d '=' -f2 || true)
  bench_iterations=$(echo "$BENCH_OUTPUT" | grep -E '^BENCH_ITERATIONS=' | tail -1 | cut -d '=' -f2 || true)
  bench_warmup=$(echo "$BENCH_OUTPUT" | grep -E '^BENCH_WARMUP=' | tail -1 | cut -d '=' -f2 || true)
  crt_total_ms=$(echo "$BENCH_OUTPUT" | grep -E '^CRT_total_ms=' | tail -1 | cut -d '=' -f2 || true)
  crt_avg_ms=$(echo "$BENCH_OUTPUT" | grep -E '^CRT_avg_ms=' | tail -1 | cut -d '=' -f2 || true)
  d_total_ms=$(echo "$BENCH_OUTPUT" | grep -E '^D_total_ms=' | tail -1 | cut -d '=' -f2 || true)
  d_avg_ms=$(echo "$BENCH_OUTPUT" | grep -E '^D_avg_ms=' | tail -1 | cut -d '=' -f2 || true)
  speedup=$(echo "$BENCH_OUTPUT" | grep -E '^Speedup_D_over_CRT=' | tail -1 | cut -d '=' -f2 || true)

  BENCH_SCHEME_VALUE="${bench_scheme}" \
  BENCH_KEY_VALUE="${bench_key}" \
  BENCH_ITERATIONS_VALUE="${bench_iterations}" \
  BENCH_WARMUP_VALUE="${bench_warmup}" \
  CRT_TOTAL_MS_VALUE="${crt_total_ms}" \
  CRT_AVG_MS_VALUE="${crt_avg_ms}" \
  D_TOTAL_MS_VALUE="${d_total_ms}" \
  D_AVG_MS_VALUE="${d_avg_ms}" \
  SPEEDUP_VALUE="${speedup}" \
  python3 - "$JSON_OUT" <<'PY'
import json
import os
import sys

out = sys.argv[1]
data = {
    "bench_scheme": os.environ.get("BENCH_SCHEME_VALUE", ""),
    "bench_key": os.environ.get("BENCH_KEY_VALUE", ""),
    "bench_iterations": os.environ.get("BENCH_ITERATIONS_VALUE", ""),
    "bench_warmup": os.environ.get("BENCH_WARMUP_VALUE", ""),
    "crt_total_ms": os.environ.get("CRT_TOTAL_MS_VALUE", ""),
    "crt_avg_ms": os.environ.get("CRT_AVG_MS_VALUE", ""),
    "d_total_ms": os.environ.get("D_TOTAL_MS_VALUE", ""),
    "d_avg_ms": os.environ.get("D_AVG_MS_VALUE", ""),
    "speedup_d_over_crt": os.environ.get("SPEEDUP_VALUE", ""),
}
with open(out, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
PY

  echo "[bench] json_out=$JSON_OUT"
fi
