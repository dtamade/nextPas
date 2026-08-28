program bench_tlspas_hrr;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.bench.base,
  nextpas.core.thread.init,
  nextpas.core.bench,
  nextpas.core.crypto.hash,
  nextpas.core.crypto.p384,
  nextpas.core.crypto.p256ecdh,
  nextpas.core.tls.tls13.wire,
  nextpas.core.tls.tls13.clienthello,
  nextpas.core.tls.tls13.clienthello.parser,
  nextpas.core.tls.tls13.posthandshake,
  nextpas.core.net.async.tlspas,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.headers,
  nextpas.core.http.message,
  nextpas.core.http.middleware,
  nextpas.core.http.earlydata,
  nextpas.core.http.middleware.earlydata,
  nextpas.core.http.client_earlydata,
  nextpas.core.platform.time,
  nextpas.core.time.base;

var
  GCH1: TBytes;
  GPubX25519: TBytes;
  GPubP384: TBytes;
  GResults: IBenchResults;

// 10 字节 CH1 + 32 字节 X25519 share，贴近真实 ClientHello 规模
procedure BenchMessageHashSHA256(aIters: Int64);
var I: Int64; LOut: TBytes;
begin
  for I := 1 to aIters do
    LOut := TlsPasBuildMessageHash(GCH1, TLS13_CIPHER_AES_128_GCM_SHA256);
end;

procedure BenchMessageHashSHA384(aIters: Int64);
var I: Int64; LOut: TBytes;
begin
  for I := 1 to aIters do
    LOut := TlsPasBuildMessageHash(GCH1, TLS13_CIPHER_AES_256_GCM_SHA384);
end;

procedure BenchPatchX25519ToP384(aIters: Int64);
var I: Int64; LPatched: TBytes; LInfo: TTLS13ClientHelloInfo; LErr: string;
begin
  for I := 1 to aIters do
  begin
    LPatched := PatchClientHelloKeyShare(GCH1, GPubP384, TLS13_GROUP_SECP384R1);
    // 轻量校验避免被优化掉
    if not TryParseTLS13ClientHelloFromHandshake(LPatched, LInfo, LErr) then
      raise Exception.Create(LErr);
  end;
end;

procedure BenchPatchP384ToP256(aIters: Int64);
var I: Int64; LPubP256: TBytes; LPatched: TBytes;
begin
  SetLength(LPubP256, 65);
  LPubP256[0] := $04;
  FillChar(LPubP256[1], 64, $33);
  for I := 1 to aIters do
    LPatched := PatchClientHelloKeyShare(GCH1, LPubP256, TLS13_GROUP_SECP256R1);
end;

procedure BenchP256KeyPair(aIters: Int64);
var I: Int64; LPriv, LPub: TBytes; LErr: string;
begin
  for I := 1 to aIters do
    if not TryGenerateP256ECDHKeyPair(LPriv, LPub, LErr) then
      raise Exception.Create(LErr);
end;

procedure BenchP384KeyPairOnce;
var LPriv, LPub: TBytes; LErr: string; T0, T1: QWord;
begin
  T0 := GetTickCount64;
  if not TryP384ECDHEKeyPair(LPriv, LPub, LErr) then
    raise Exception.Create(LErr);
  T1 := GetTickCount64;
  WriteLn(Format('P384 single keypair: %d ms (experimental big-int, not for hot path)', [T1 - T0]));
end;

procedure BenchTranscriptSynthesis(aIters: Int64);
var I: Int64; LMsgHash, LHRR, LCH2, LTranscript: TBytes;
begin
  SetLength(LHRR, 8);
  FillChar(LHRR[0], 8, $AA);
  SetLength(LCH2, 12);
  FillChar(LCH2[0], 12, $77);
  for I := 1 to aIters do
  begin
    LMsgHash := TlsPasBuildMessageHash(GCH1, TLS13_CIPHER_AES_128_GCM_SHA256);
    SetLength(LTranscript, Length(LMsgHash) + Length(LHRR) + Length(LCH2));
    Move(LMsgHash[0], LTranscript[0], Length(LMsgHash));
    Move(LHRR[0], LTranscript[Length(LMsgHash)], Length(LHRR));
    Move(LCH2[0], LTranscript[Length(LMsgHash) + Length(LHRR)], Length(LCH2));
  end;
end;

var
  GEarlyPSK256: TBytes;
  GEarlyPSK384: TBytes;

procedure BenchEarlyDataSHA256(aIters: Int64);
var I: Int64; LSec: TTlsPasEarlyDataSecrets; LErr: string;
begin
  for I := 1 to aIters do
  begin
    if not TlsPasTryDeriveEarlyDataSecrets(TLS13_CIPHER_AES_128_GCM_SHA256, GEarlyPSK256, GCH1, LSec, LErr) then
      raise Exception.Create(LErr);
    TlsPasClearEarlyDataSecrets(LSec);
  end;
end;

procedure BenchEarlyDataSHA384(aIters: Int64);
var I: Int64; LSec: TTlsPasEarlyDataSecrets; LErr: string;
begin
  for I := 1 to aIters do
  begin
    if not TlsPasTryDeriveEarlyDataSecrets(TLS13_CIPHER_AES_256_GCM_SHA384, GEarlyPSK384, GCH1, LSec, LErr) then
      raise Exception.Create(LErr);
    TlsPasClearEarlyDataSecrets(LSec);
  end;
end;

procedure BenchEOEDBuild(aIters: Int64);
var I: Int64; LMsg: TBytes;
begin
  for I := 1 to aIters do
    LMsg := BuildTLS13EndOfEarlyDataHandshake;
end;

var
  GPolicySess: TTlsPasResumptionSession;
  GReplayCache: TAsyncTlsPasReplayCache;
  GReplayStore: ITlsPasReplayStore;
  GFileStore: ITlsPasReplayStore;
  GKvStore: ITlsPasReplayStore;
  GReplayFp: TBytes;

procedure BenchPolicyAllowed(aIters: Int64);
var I: Int64; LOk: Boolean;
begin
  for I := 1 to aIters do
    LOk := TlsPasIsEarlyDataAllowed(GPolicySess, True, 100);
end;

procedure BenchFingerprint(aIters: Int64);
var I: Int64; LFp: TBytes;
begin
  for I := 1 to aIters do
    LFp := TlsPasComputeEarlyDataFingerprint(GPolicySess.TicketIdentity, GCH1);
end;

procedure BenchReplayCache(aIters: Int64);
var I: Int64; IsReplay: Boolean; LFp: TBytes;
begin
  SetLength(LFp, 32);
  FillChar(LFp[0], 32, $11);
  for I := 1 to aIters do
  begin
    LFp[0] := Byte(I and $FF);
    GReplayCache.CheckAndAdd(LFp, IsReplay);
  end;
end;

procedure BenchReplayStoreInterface(aIters: Int64);
var I: Int64; IsReplay: Boolean; LFp: TBytes;
begin
  SetLength(LFp, 32);
  FillChar(LFp[0], 32, $22);
  for I := 1 to aIters do
  begin
    LFp[0] := Byte(I and $FF);
    GReplayStore.CheckAndAdd(LFp, IsReplay);
  end;
end;

procedure BenchReplayStats(aIters: Int64);
var I: Int64; S: TAsyncTlsPasReplayStats;
begin
  for I := 1 to aIters do
    S := GReplayCache.GetStats;
end;

procedure BenchReplayIsReplayed(aIters: Int64);
var I: Int64; LIsReplay: Boolean;
begin
  for I := 1 to aIters do
    LIsReplay := TlsPasIsEarlyDataReplayed(GReplayStore, GPolicySess.TicketIdentity, GCH1);
end;

procedure BenchReplayFileStore(aIters: Int64);
var I: Int64; IsReplay: Boolean; LFp: TBytes;
begin
  SetLength(LFp, 32);
  FillChar(LFp[0], 32, $33);
  for I := 1 to aIters do
  begin
    LFp[0] := Byte(I and $FF);
    LFp[1] := Byte((I shr 8) and $FF);
    GFileStore.CheckAndAdd(LFp, IsReplay);
  end;
end;

procedure BenchReplayKvStore(aIters: Int64);
var I: Int64; IsReplay: Boolean; LFp: TBytes;
begin
  SetLength(LFp, 32);
  FillChar(LFp[0], 32, $44);
  for I := 1 to aIters do
  begin
    LFp[0] := Byte(I and $FF);
    LFp[1] := Byte((I shr 8) and $FF);
    GKvStore.CheckAndAdd(LFp, IsReplay);
  end;
end;

procedure BenchServerDecide(aIters: Int64);
var I: Int64; D: TTlsPasEarlyDataDecision;
begin
  for I := 1 to aIters do
    D := TlsPasServerDecideEarlyData(GReplayStore, GPolicySess.TicketIdentity, GCH1, GPolicySess, True);
end;

procedure BenchServerShouldAccept(aIters: Int64);
var I: Int64; LOk: Boolean;
begin
  for I := 1 to aIters do
    LOk := TlsPasServerShouldAcceptEarlyData(GReplayStore, GPolicySess.TicketIdentity, GCH1, GPolicySess, True);
end;

var
  GServerObserver: TAsyncTlsPasServerObserver;

procedure BenchObserverDecide(aIters: Int64);
var I: Int64; D: TTlsPasEarlyDataDecision;
begin
  for I := 1 to aIters do
    D := GServerObserver.Decide(GPolicySess.TicketIdentity, GCH1, GPolicySess, True);
end;

procedure BenchFormatReplayStats(aIters: Int64);
var I: Int64; S: TAsyncTlsPasReplayStats; F: string;
begin
  S := GReplayCache.GetStats;
  for I := 1 to aIters do
    F := TlsPasFormatReplayStats(S);
end;

var
  GAdaptiveConfig: TTlsPasAdaptiveLimitConfig;
  GAdaptiveServerStats: TTlsPasServerStats;
  GAdaptiveReplayStats: TAsyncTlsPasReplayStats;

procedure BenchAdaptiveLimit(aIters: Int64);
var I: Int64; L: Cardinal;
begin
  for I := 1 to aIters do
    L := TlsPasComputeAdaptiveMaxEarlyData(GAdaptiveServerStats, GAdaptiveReplayStats, GAdaptiveConfig);
end;

procedure BenchHeaderValue(aIters: Int64);
var I: Int64; H: string;
begin
  for I := 1 to aIters do
    H := TlsPasEarlyDataDecisionToHeaderValue(edAccept);
end;

procedure BenchHttpEarlyDataHeader(aIters: Int64);
var I: Int64; H: string;
begin
  for I := 1 to aIters do
    H := HttpEarlyDataHeaderValueFromDecision(edAccept);
end;

procedure BenchHttpEarlyDataStream(aIters: Int64);
var I: Int64; H: string;
begin
  for I := 1 to aIters do
    H := HttpEarlyDataHeaderValueFromStream(nil);
end;

type
  TCaptureWriterBenchHack = class(TInterfacedObject, IHttpResponseWriter)
  private
    class var FInst: IHttpResponseWriter;
    FHeaders: IHttpHeaders;
  public
    constructor Create;
    procedure WriteHeader(const AStatus: THttpStatus);
    function GetStatus: THttpStatus;
    function GetHeaders: IHttpHeaders;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Flush;
    class function Get: IHttpResponseWriter; static;
  end;

var
  GHttpReqEarly, GHttpReqNormal: IHttpRequest;
  GHttpMw: IHttpMiddleware;
  GHttpMwHandler: IHttpHandler;

constructor TCaptureWriterBenchHack.Create;
begin inherited Create; FHeaders := NewHttpHeaders; end;
procedure TCaptureWriterBenchHack.WriteHeader(const AStatus: THttpStatus); begin end;
function TCaptureWriterBenchHack.GetStatus: THttpStatus; begin Result := HTTP_STATUS_OK; end;
function TCaptureWriterBenchHack.GetHeaders: IHttpHeaders; begin Result := FHeaders; end;
function TCaptureWriterBenchHack.Write(const ABuf; const ACount: SizeUInt): SizeUInt; begin Result := ACount; end;
procedure TCaptureWriterBenchHack.Flush; begin end;
class function TCaptureWriterBenchHack.Get: IHttpResponseWriter;
begin
  if FInst = nil then FInst := TCaptureWriterBenchHack.Create;
  Result := FInst;
  (Result as TCaptureWriterBenchHack).FHeaders.Clear;
end;

procedure BenchHttpRequestFlag(aIters: Int64);
var I: Int64; L: Boolean;
begin
  for I := 1 to aIters do
    L := HttpEarlyDataWasEarlyData(GHttpReqEarly);
end;

procedure BenchHttpMiddlewareEarlyData(aIters: Int64);
var I: Int64;
begin
  for I := 1 to aIters do
    GHttpMwHandler.ServeHTTP(GHttpReqEarly, TCaptureWriterBenchHack.Get);
end;

var
  GClientEarlyReq: IHttpRequest;
  GClientEarlyResp425, GClientEarlyRespOkEarly0: IHttpResponse;

procedure BenchClientEarlyIsIdempotent(aIters: Int64);
var I: Int64; L: Boolean;
begin
  for I := 1 to aIters do L := HttpEarlyDataIsIdempotentRequest(GClientEarlyReq);
end;

procedure BenchClientEarlyIsEarly(aIters: Int64);
var I: Int64; L: Boolean;
begin
  for I := 1 to aIters do L := HttpEarlyDataIsEarlyRequest(GClientEarlyReq);
end;

procedure BenchClientEarlyShouldRetry(aIters: Int64);
var I: Int64; L: Boolean;
begin
  for I := 1 to aIters do L := HttpEarlyDataShouldRetry(GClientEarlyReq, GClientEarlyResp425);
end;

procedure BenchClientEarlyClone(aIters: Int64);
var I: Int64; L: IHttpRequest;
begin
  for I := 1 to aIters do L := HttpEarlyDataCloneWithoutEarlyData(GClientEarlyReq);
end;

procedure InitFixtures;
var LPubX: TBytes;
begin
  SetLength(GCH1, 0);
  SetLength(LPubX, 32);
  FillChar(LPubX[0], 32, $11);
  GCH1 := BuildTLS13ClientHelloHandshake('bench.local', '', LPubX);

  SetLength(GPubX25519, 32);
  FillChar(GPubX25519[0], 32, $11);

  SetLength(GPubP384, 97);
  GPubP384[0] := $04;
  FillChar(GPubP384[1], 96, $22);

  SetLength(GEarlyPSK256, 32);
  FillChar(GEarlyPSK256[0], 32, $42);
  SetLength(GEarlyPSK384, 48);
  FillChar(GEarlyPSK384[0], 48, $55);

  GPolicySess := Default(TTlsPasResumptionSession);
  GPolicySess.HasMaxEarlyData := True;
  GPolicySess.MaxEarlyDataSize := 16384;
  SetLength(GPolicySess.TicketIdentity, 16);
  FillChar(GPolicySess.TicketIdentity[0], 16, $33);

  GReplayCache := TAsyncTlsPasReplayCache.Create(64, 600000);
  GReplayStore := GReplayCache as ITlsPasReplayStore;
  SetLength(GReplayFp, 32);
  FillChar(GReplayFp[0], 32, $99);
  if FileExists('/tmp/bench_replay_file.dat') then DeleteFile('/tmp/bench_replay_file.dat');
  if FileExists('/tmp/bench_replay_file.dat.tmp') then DeleteFile('/tmp/bench_replay_file.dat.tmp');
  GFileStore := TAsyncTlsPasReplayFileStore.Create('/tmp/bench_replay_file.dat', 64, 600000) as ITlsPasReplayStore;
  GKvStore := TAsyncTlsPasReplayStoreFactory.CreateKv(TAsyncTlsPasMemoryKvStore.Create as ITlsPasKvStore, 64, 600000);
  GServerObserver := TAsyncTlsPasServerObserver.Create(GReplayStore);
  GAdaptiveConfig := DefaultTlsPasAdaptiveLimitConfig;
  GAdaptiveServerStats := Default(TTlsPasServerStats);
  GAdaptiveReplayStats := Default(TAsyncTlsPasReplayStats);
  // HTTP middleware fixtures
  GHttpReqEarly := THttpRequest.Create(hmGet, TUrl.Parse('http://bench.local/'), hvHttp11, NewHttpHeaders, nil, 0);
  (GHttpReqEarly as IHttpRequestWithEarlyData).SetWasEarlyData(True);
  GHttpReqNormal := THttpRequest.Create(hmGet, TUrl.Parse('http://bench.local/'), hvHttp11, NewHttpHeaders, nil, 0);
  GHttpMw := EarlyDataMiddleware;
  GHttpMwHandler := GHttpMw.Wrap(HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter) begin end));
  // Client early-data fixtures
  GClientEarlyReq := THttpRequest.Create(hmGet, TUrl.Parse('http://bench.local/'), hvHttp11, NewHttpHeaders, nil, 0);
  HttpEarlyDataMarkRequest(GClientEarlyReq);
  GClientEarlyResp425 := NewResponse(HTTP_STATUS_TOO_EARLY, NewHttpHeaders, nil);
  GClientEarlyRespOkEarly0 := NewResponse(HTTP_STATUS_OK, NewHttpHeaders, nil);
  GClientEarlyRespOkEarly0.Headers.SetHeader(HTTP_HEADER_X_EARLY_DATA, '0');
end;

var
  LCfg: TBenchConfig;
begin
  WriteLn('=== nextpas.core.net tlspas HRR benchmark ===');
  WriteLn('X25519 32B / P-256 65B / P-384 97B | SHA256 vs SHA384 message_hash');
  WriteLn('P-384 keypair is experimental big-int path (expect 5-7s per live HRR, ~ms per keypair)');
  WriteLn;
  InitFixtures;
  LCfg := DefaultBenchConfig;
  LCfg.MinDurationNs := 120 * 1000000; // 120ms per bench, quick gate
  LCfg.MinSamples := 3;
  LCfg.WarmupIterations := 1;
  GResults := TBenchSuite.CreateWithConfig('tlspas HRR', LCfg)
    .AddLoop('MessageHash SHA256 (CH1->0xFE)', @BenchMessageHashSHA256)
    .AddLoop('MessageHash SHA384 (CH1->0xFE)', @BenchMessageHashSHA384)
    .AddLoop('Patch X25519->P384 (key_share rewrite)', @BenchPatchX25519ToP384)
    .AddLoop('Patch P384->P256 (key_share rewrite)', @BenchPatchP384ToP256)
    .AddLoop('P256 ECDHE keypair', @BenchP256KeyPair)
    .AddLoop('Transcript synthesis (msg_hash+HRR+CH2)', @BenchTranscriptSynthesis)
    .AddLoop('EarlyData SHA256 (c e traffic)', @BenchEarlyDataSHA256)
    .AddLoop('EarlyData SHA384 (c e traffic)', @BenchEarlyDataSHA384)
    .AddLoop('EOED build (4B 0x05)', @BenchEOEDBuild)
    .AddLoop('Policy allowed (branch)', @BenchPolicyAllowed)
    .AddLoop('Fingerprint SHA256(id+early)', @BenchFingerprint)
    .AddLoop('ReplayCache check+add', @BenchReplayCache)
    .AddLoop('ReplayStore interface', @BenchReplayStoreInterface)
    .AddLoop('ReplayStats GetStats', @BenchReplayStats)
    .AddLoop('IsEarlyDataReplayed', @BenchReplayIsReplayed)
    .AddLoop('ReplayFileStore persist', @BenchReplayFileStore)
    .AddLoop('ReplayKvStore (local+kv)', @BenchReplayKvStore)
    .AddLoop('ServerDecide (policy+replay)', @BenchServerDecide)
    .AddLoop('ServerShouldAccept', @BenchServerShouldAccept)
    .AddLoop('ObserverDecide (wrap+count)', @BenchObserverDecide)
    .AddLoop('FormatReplayStats', @BenchFormatReplayStats)
    .AddLoop('AdaptiveMaxEarlyData', @BenchAdaptiveLimit)
    .AddLoop('HeaderValue (X-Early-Data)', @BenchHeaderValue)
    .AddLoop('HttpEarlyData header (decision)', @BenchHttpEarlyDataHeader)
    .AddLoop('HttpEarlyData from stream nil', @BenchHttpEarlyDataStream)
    .AddLoop('HttpRequest early flag (Supports)', @BenchHttpRequestFlag)
    .AddLoop('HttpMiddleware early-data', @BenchHttpMiddlewareEarlyData)
    .AddLoop('ClientEarly IsIdempotent', @BenchClientEarlyIsIdempotent)
    .AddLoop('ClientEarly IsEarly', @BenchClientEarlyIsEarly)
    .AddLoop('ClientEarly ShouldRetry', @BenchClientEarlyShouldRetry)
    .AddLoop('ClientEarly CloneWithoutEarly', @BenchClientEarlyClone)
    .Run;
  WriteLn(GResults.PrintToConsole);
  WriteLn;
  WriteLn('--- P-384 experimental (single sample, outside suite) ---');
  BenchP384KeyPairOnce;
end.
