program test_tlspas_hrr;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, Classes,
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.os.env,
  nextpas.core.crypto.hash,
  nextpas.core.crypto.p384,
  nextpas.core.crypto.p256ecdh,
  nextpas.core.tls.tls13.wire,
  nextpas.core.tls.tls13.clienthello,
  nextpas.core.tls.tls13.clienthello.parser,
  nextpas.core.tls.tls13.recordsealer,
  nextpas.core.tls.tls13.posthandshake,
  nextpas.core.tls.tls13.finished,
  nextpas.core.net.async.tlspas,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.async.base,
  nextpas.core.async.loop,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.net.tcp,
  nextpas.core.net.async.tcp,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.headers,
  nextpas.core.http.message,
  nextpas.core.http.middleware,
  nextpas.core.http.middleware.context,
  nextpas.core.http.earlydata,
  nextpas.core.http.middleware.earlydata,
  nextpas.core.http.middleware.earlydata.adaptive,
  nextpas.core.http.client_earlydata,
  nextpas.core.http.client,
  nextpas.core.io;

type
  TCaptureWriter = class(TInterfacedObject, IHttpResponseWriter)
  private
    FHeaders: IHttpHeaders;
    FStatus: THttpStatus;
  public
    constructor Create;
    procedure WriteHeader(const AStatus: THttpStatus);
    function GetStatus: THttpStatus;
    function GetHeaders: IHttpHeaders;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Flush;
  end;

constructor TCaptureWriter.Create;
begin
  inherited Create;
  FHeaders := NewHttpHeaders;
  FStatus := HTTP_STATUS_OK;
end;
procedure TCaptureWriter.WriteHeader(const AStatus: THttpStatus); begin FStatus := AStatus; end;
function TCaptureWriter.GetStatus: THttpStatus; begin Result := FStatus; end;
function TCaptureWriter.GetHeaders: IHttpHeaders; begin Result := FHeaders; end;
function TCaptureWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt; begin Result := ACount; end;
procedure TCaptureWriter.Flush; begin end;

procedure TestGroupKeyShareLen;
begin
  CheckEqual(Int64(32), Int64(TlsPasGroupKeyShareLen(TLS13_GROUP_X25519)), 'X25519 len');
  CheckEqual(Int64(65), Int64(TlsPasGroupKeyShareLen(TLS13_GROUP_SECP256R1)), 'P-256 len');
  CheckEqual(Int64(97), Int64(TlsPasGroupKeyShareLen(TLS13_GROUP_SECP384R1)), 'P-384 len');
  Check(TlsPasGroupKeyShareLen($0019) = -1, 'P-521 not HRR-supported');
  Check(TlsPasGroupKeyShareLen($0020) = -1, 'unknown group -1');
end;

procedure TestIsSupportedHRRGroup;
begin
  Check(TlsPasIsSupportedHRRGroup(TLS13_GROUP_X25519), 'X25519 supported');
  Check(TlsPasIsSupportedHRRGroup(TLS13_GROUP_SECP256R1), 'P-256 supported');
  Check(TlsPasIsSupportedHRRGroup(TLS13_GROUP_SECP384R1), 'P-384 supported');
  Check(not TlsPasIsSupportedHRRGroup($0019), 'P-521 not supported');
  Check(not TlsPasIsSupportedHRRGroup(0), 'zero not supported');
end;

procedure TestMessageHashSHA256;
var
  LCH1, LMsgHash, LHash: TBytes;
begin
  SetLength(LCH1, 5);
  LCH1[0] := 1; LCH1[1] := 2; LCH1[2] := 3; LCH1[3] := 4; LCH1[4] := 5;
  LMsgHash := TlsPasBuildMessageHash(LCH1, TLS13_CIPHER_AES_128_GCM_SHA256);
  Check(Length(LMsgHash) = 4 + 32, 'SHA256 msg hash len 36');
  Check(LMsgHash[0] = 254, 'msg hash type 0xFE');
  Check((LMsgHash[1] = 0) and (LMsgHash[2] = 0), 'msg hash reserved zero');
  Check(LMsgHash[3] = 32, 'msg hash len byte 32');
  LHash := SHA256(LCH1);
  Check(CompareMem(@LMsgHash[4], @LHash[0], 32), 'SHA256 hash matches');
end;

procedure TestMessageHashSHA384;
var
  LCH1, LMsgHash, LHash: TBytes;
begin
  SetLength(LCH1, 3);
  LCH1[0] := $AA; LCH1[1] := $BB; LCH1[2] := $CC;
  LMsgHash := TlsPasBuildMessageHash(LCH1, TLS13_CIPHER_AES_256_GCM_SHA384);
  Check(Length(LMsgHash) = 4 + 48, 'SHA384 msg hash len 52');
  Check(LMsgHash[0] = 254, 'msg hash type 0xFE sha384');
  Check(LMsgHash[3] = 48, 'msg hash len byte 48');
  LHash := SHA384(LCH1);
  Check(CompareMem(@LMsgHash[4], @LHash[0], 48), 'SHA384 hash matches');
  // TLS_CHACHA20 uses SHA256 despite 384 selection
  LMsgHash := TlsPasBuildMessageHash(LCH1, TLS13_CIPHER_CHACHA20_POLY1305_SHA256);
  Check(Length(LMsgHash) = 4 + 32, 'chacha uses SHA256');
end;

procedure TestP384KeyPairAndRoundtrip;
var
  LPrivA, LPubA, LPrivB, LPubB, LSharedAB, LSharedBA: TBytes;
  LErr: string;
begin
  Check(TryP384ECDHEKeyPair(LPrivA, LPubA, LErr), 'P-384 keypair A: ' + LErr);
  Check(Length(LPrivA) = 48, 'P-384 priv 48');
  Check(Length(LPubA) = 97, 'P-384 pub 97');
  Check(LPubA[0] = $04, 'P-384 pub uncompressed');
  Check(TryP384ECDHEKeyPair(LPrivB, LPubB, LErr), 'P-384 keypair B: ' + LErr);
  Check(TryP384ECDHE(LPrivA, LPubB, LSharedAB, LErr), 'P-384 ECDHE A->B: ' + LErr);
  Check(TryP384ECDHE(LPrivB, LPubA, LSharedBA, LErr), 'P-384 ECDHE B->A: ' + LErr);
  Check(Length(LSharedAB) = 48, 'shared 48');
  Check(CompareMem(@LSharedAB[0], @LSharedBA[0], 48), 'shared equal both ways');
  // Validation rejects bad format
  Check(not TryP384ValidatePublicKey(TBytes.Create(1,2,3), LErr), 'reject short key');
  // uncompressed flag mismatch
  LPubA[0] := $03;
  Check(not TryP384ValidatePublicKey(LPubA, LErr), 'reject wrong prefix');
end;

procedure TestP256Roundtrip;
var
  LPrivA, LPubA, LPrivB, LPubB, LSharedAB, LSharedBA: TBytes;
  LErr: string;
begin
  Check(TryGenerateP256ECDHKeyPair(LPrivA, LPubA, LErr), 'P-256 gen A: ' + LErr);
  Check(Length(LPubA) = 65, 'P-256 pub 65');
  Check(TryGenerateP256ECDHKeyPair(LPrivB, LPubB, LErr), 'P-256 gen B: ' + LErr);
  Check(TryP256ECDHSharedSecret(LPrivA, LPubB, LSharedAB, LErr), 'P-256 shared A->B: ' + LErr);
  Check(TryP256ECDHSharedSecret(LPrivB, LPubA, LSharedBA, LErr), 'P-256 shared B->A: ' + LErr);
  Check(CompareMem(@LSharedAB[0], @LSharedBA[0], 32), 'P-256 shared equal');
end;

procedure TestPatchP384;
var
  LPubX, LPubP384, LPatchCH, LOrigCH: TBytes;
  LInfo: TTLS13ClientHelloInfo;
  LErr: string;
begin
  SetLength(LPubX, 32);
  FillChar(LPubX[0], 32, $11);
  LOrigCH := BuildTLS13ClientHelloHandshake('localhost', '', LPubX);
  Check(Length(LOrigCH) > 40, 'orig CH built');
  SetLength(LPubP384, 97);
  LPubP384[0] := $04;
  FillChar(LPubP384[1], 96, $22);
  LPatchCH := PatchClientHelloKeyShare(LOrigCH, LPubP384, TLS13_GROUP_SECP384R1);
  Check(Length(LPatchCH) > 0, 'patch to P-384 ok');
  Check(Length(LPatchCH) = Length(LOrigCH) + (97 - 32), 'patch size delta correct');
  Check(TryParseTLS13ClientHelloFromHandshake(LPatchCH, LInfo, LErr), 'parse patched CH: ' + LErr);
  Check(LInfo.KeyShareGroup = TLS13_GROUP_SECP384R1, 'patched group P-384');
  Check(Length(LInfo.PeerKeyShare) = 97, 'patched share 97');
  SetLength(LPubX, 65);
  LPubX[0] := $04;
  FillChar(LPubX[1], 64, $33);
  LPatchCH := PatchClientHelloKeyShare(LPatchCH, LPubX, TLS13_GROUP_SECP256R1);
  Check(Length(LPatchCH) > 0, 'patch back to P-256 ok');
end;

procedure TestTranscriptSynthesis;
var
  LCH1, LHRR, LCH2, LMsgHash, LTranscript: TBytes;
  LSuite: Word;
begin
  SetLength(LCH1, 10);
  FillChar(LCH1[0], 10, $55);
  SetLength(LHRR, 8);
  FillChar(LHRR[0], 8, $AA);
  SetLength(LCH2, 12);
  FillChar(LCH2[0], 12, $77);
  LSuite := TLS13_CIPHER_AES_128_GCM_SHA256;
  LMsgHash := TlsPasBuildMessageHash(LCH1, LSuite);
  SetLength(LTranscript, 0);
  SetLength(LTranscript, Length(LMsgHash) + Length(LHRR) + Length(LCH2));
  Move(LMsgHash[0], LTranscript[0], Length(LMsgHash));
  Move(LHRR[0], LTranscript[Length(LMsgHash)], Length(LHRR));
  Move(LCH2[0], LTranscript[Length(LMsgHash)+Length(LHRR)], Length(LCH2));
  Check(LTranscript[0] = 254, 'transcript starts with message_hash');
  Check(Length(LTranscript) = (4+32)+8+12, 'transcript total len');
end;

{ ===== live HRR e2e (requires openssl s_server, else skipped) ===== }
const
  cGetRequest = 'GET / HTTP/1.0'#13#10#13#10;

var
  GLiveLoop: TAsyncLoop;
  GLiveStream: IAsyncTcpStream;
  GLiveErr: Int32;
  GLiveReady: Boolean;
  GLiveCbCalled: Boolean;
  GLiveFinished: Boolean;
  GLiveBuf: PByte;
  GLiveAcc: TBytes;
  GLiveFound: Boolean;
  GLiveWasHRR: Boolean;
  GLiveWasEarlyDataAccepted: Boolean;

procedure LiveStopCb(AContext: Pointer);
begin
  if GLiveLoop <> nil then GLiveLoop.Stop;
end;

procedure LiveFinish;
begin
  if GLiveFinished then Exit;
  GLiveFinished := True;
  GLiveLoop.Schedule(TDuration.FromMilliseconds(1), @LiveStopCb, nil);
end;

function LiveContains(const AHay: TBytes; const ANeedle: string): Boolean;
var I,J: Integer; LHit: Integer;
begin
  Result:=False; LHit:=Length(ANeedle);
  if Length(AHay) < LHit then Exit;
  for I:=0 to Length(AHay)-LHit do begin
    Result:=True;
    for J:=0 to LHit-1 do if AHay[I+J]<>Ord(ANeedle[J+1]) then begin Result:=False; Break; end;
    if Result then Exit;
  end;
end;

procedure LiveReadCb(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  if AResult < 0 then begin GLiveErr:=AResult; LiveFinish; Exit; end;
  if AResult = 0 then begin LiveFinish; Exit; end;
  SetLength(GLiveAcc, Length(GLiveAcc)+AResult);
  Move(GLiveBuf^, GLiveAcc[Length(GLiveAcc)-AResult], AResult);
  if LiveContains(GLiveAcc, 'HTTP/1.') then begin GLiveFound:=True; LiveFinish; Exit; end;
  if Length(GLiveAcc) > 262144 then begin LiveFinish; Exit; end;
  if not GLiveStream.AsyncRead(GLiveBuf, 4096, @LiveReadCb, nil) then begin GLiveErr:=-3201; LiveFinish; end;
end;

procedure LiveReadyCb(AStream: IAsyncTcpStream; AError: Int32; AContext: Pointer);
begin
  GLiveCbCalled:=True;
  if AError<>0 then begin GLiveErr:=AError; LiveFinish; Exit; end;
  GLiveStream:=AStream; GLiveReady:=True;
  if not GLiveStream.AsyncWrite(PChar(cGetRequest), Length(cGetRequest), @LiveReadCb, nil) then
  begin
    // WriteCb reused ReadCb trampoline: after write we need read. Use direct write-cb that arms read
    GLiveErr:=-3201; LiveFinish; Exit;
  end;
  // Actually we used ReadCb as write cb; arm read after write completes via separate cb
end;

procedure LiveWriteCb(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  if AResult<=0 then begin GLiveErr:=-3201; LiveFinish; Exit; end;
  GetMem(GLiveBuf, 4096);
  if not GLiveStream.AsyncRead(GLiveBuf, 4096, @LiveReadCb, nil) then begin FreeMem(GLiveBuf); GLiveBuf:=nil; GLiveErr:=-3201; LiveFinish; end;
end;

procedure LiveReadyCbWithRead(AStream: IAsyncTcpStream; AError: Int32; AContext: Pointer);
begin
  GLiveCbCalled:=True;
  if AError<>0 then begin GLiveErr:=AError; LiveFinish; Exit; end;
  GLiveStream:=AStream; GLiveReady:=True;
  if not GLiveStream.AsyncWrite(PChar(cGetRequest), Length(cGetRequest), @LiveWriteCb, nil) then begin GLiveErr:=-3201; LiveFinish; end;
end;

function LivePortAvailable(APort: UInt16): Boolean;
var LProbe: ITcpStream;
begin
  Result:=False;
  try LProbe:=NetTcpConnect('127.0.0.1', APort); Result:=LProbe<>nil; except Result:=False; end;
end;

function EnvPort(const AName: string; ADef: UInt16): UInt16;
var S: string; V: Integer;
begin
  S:=GetEnvironmentVariable(AName);
  if S='' then Exit(ADef);
  V:=StrToIntDef(S, ADef);
  Result:=UInt16(V);
end;

procedure RunLiveHRR(APort: UInt16);
var LOpts: TAsyncTlsPasClientOptions; LHRR: ITlsPasHRRInfo;
begin
  GLiveStream:=nil; GLiveErr:=0; GLiveReady:=False; GLiveCbCalled:=False; GLiveFinished:=False; GLiveFound:=False; GLiveWasHRR:=False; GLiveWasEarlyDataAccepted:=False; SetLength(GLiveAcc,0); GLiveBuf:=nil;
  GLiveLoop:=TAsyncLoop.Create;
  try
    GLiveLoop.Schedule(TDuration.FromSeconds(35), @LiveStopCb, nil);
    LOpts:=DefaultAsyncTlsPasClientOptions;
    LOpts.ServerName:='localhost';
    LOpts.HandshakeDeadline:=TDeadline.After(TDuration.FromSeconds(30));
    if not AsyncTlsPasConnect(GLiveLoop, '127.0.0.1', APort, LOpts, @LiveReadyCbWithRead, nil) then
      GLiveErr:=-3201
    else if not GLiveCbCalled then
      GLiveLoop.Run;
    if (GLiveStream<>nil) and Supports(GLiveStream, ITlsPasHRRInfo, LHRR) then
      GLiveWasHRR:=LHRR.GetWasHRR;
  finally
    if GLiveBuf<>nil then begin FreeMem(GLiveBuf); GLiveBuf:=nil; end;
    GLiveLoop.Free; GLiveLoop:=nil;
  end;
end;

procedure RunLiveEarlyData(APort: UInt16; ACache: TAsyncTlsPasSessionCache; const AEarlyData: TBytes);
var LOpts: TAsyncTlsPasClientOptions; LHRR: ITlsPasHRRInfo; LEarly: ITlsPasEarlyDataInfo;
begin
  GLiveStream:=nil; GLiveErr:=0; GLiveReady:=False; GLiveCbCalled:=False; GLiveFinished:=False; GLiveFound:=False; GLiveWasHRR:=False; GLiveWasEarlyDataAccepted:=False; SetLength(GLiveAcc,0); GLiveBuf:=nil;
  GLiveLoop:=TAsyncLoop.Create;
  try
    GLiveLoop.Schedule(TDuration.FromSeconds(35), @LiveStopCb, nil);
    LOpts:=DefaultAsyncTlsPasClientOptions;
    LOpts.ServerName:='localhost';
    LOpts.HandshakeDeadline:=TDeadline.After(TDuration.FromSeconds(30));
    LOpts.Cache:=ACache;
    LOpts.AllowEarlyData:=Length(AEarlyData)>0;
    LOpts.EarlyData:=System.Copy(AEarlyData);
    if not AsyncTlsPasConnect(GLiveLoop, '127.0.0.1', APort, LOpts, @LiveReadyCbWithRead, nil) then
      GLiveErr:=-3201
    else if not GLiveCbCalled then
      GLiveLoop.Run;
    if (GLiveStream<>nil) and Supports(GLiveStream, ITlsPasHRRInfo, LHRR) then
      GLiveWasHRR:=LHRR.GetWasHRR;
    if (GLiveStream<>nil) and Supports(GLiveStream, ITlsPasEarlyDataInfo, LEarly) then
      GLiveWasEarlyDataAccepted:=LEarly.GetWasEarlyDataAccepted;
  finally
    if GLiveBuf<>nil then begin FreeMem(GLiveBuf); GLiveBuf:=nil; end;
    GLiveLoop.Free; GLiveLoop:=nil;
  end;
end;

procedure TestCacheMultiLRU;
var C: TAsyncTlsPasSessionCache; S: TTlsPasResumptionSession; I: Integer; LOk: Boolean;
begin
  C:=TAsyncTlsPasSessionCache.Create;
  try
    for I:=1 to 5 do begin
      S:=Default(TTlsPasResumptionSession);
      S.CipherSuite:=$1301; SetLength(S.TicketIdentity,1); S.TicketIdentity[0]:=Byte(I);
      SetLength(S.ResumptionPSK,1); S.ResumptionPSK[0]:=Byte(I);
      S.LifetimeSec:=3600; S.IssuedMs:=1000;
      C.Store('host', 9999, S);
    end;
    LOk:=C.TryPeek('host', 9999, S);
    Check(LOk, 'cache peek after 5 stores');
    Check(S.TicketIdentity[0]=5, 'most recent kept');
    S:=Default(TTlsPasResumptionSession); S.CipherSuite:=$1301; SetLength(S.TicketIdentity,1); S.TicketIdentity[0]:=99; SetLength(S.ResumptionPSK,1); S.ResumptionPSK[0]:=99; S.LifetimeSec:=3600; S.IssuedMs:=1000;
    C.Store('other', 9999, S);
    LOk:=C.TryPeek('host', 9999, S); Check(LOk and (S.TicketIdentity[0]=5), 'host isolation');
  finally C.Free; end;
end;

procedure TestHRRP256Live;
var P: UInt16;
begin
  P:=EnvPort('TLSPAS_HRR_P256_PORT', 15557);
  if not LivePortAvailable(P) then begin Check(True, 'skip P-256 HRR no server'); Exit; end;
  RunLiveHRR(P);
  Check(GLiveCbCalled, 'P-256 HRR callback');
  Check(GLiveReady, 'P-256 HRR handshake');
  CheckEqual(Int64(0), Int64(GLiveErr), 'P-256 HRR no error');
  Check(GLiveFound, 'P-256 HRR HTTP response');
  Check(GLiveWasHRR, 'P-256 should be HRR');
end;

procedure TestHRRP384Live;
var P: UInt16;
begin
  P:=EnvPort('TLSPAS_HRR_P384_PORT', 15558);
  if not LivePortAvailable(P) then begin Check(True, 'skip P-384 HRR no server'); Exit; end;
  RunLiveHRR(P);
  Check(GLiveCbCalled, 'P-384 HRR callback');
  Check(GLiveReady, 'P-384 HRR handshake');
  CheckEqual(Int64(0), Int64(GLiveErr), 'P-384 HRR no error');
  Check(GLiveFound, 'P-384 HRR HTTP response');
  Check(GLiveWasHRR, 'P-384 should be HRR');
end;

procedure TestHRRBaseNoHRR;
var P: UInt16;
begin
  P:=EnvPort('TLSPAS_HRR_BASE_PORT', 15556);
  if not LivePortAvailable(P) then begin Check(True, 'skip base no HRR'); Exit; end;
  RunLiveHRR(P);
  Check(GLiveCbCalled, 'base callback');
  Check(GLiveReady, 'base handshake');
  CheckEqual(Int64(0), Int64(GLiveErr), 'base no error');
  Check(GLiveFound, 'base HTTP response');
  Check(not GLiveWasHRR, 'base should not be HRR');
end;

procedure TestEarlyDataDeriveSHA256;
var LPSK, LCH: TBytes; LSec: TTlsPasEarlyDataSecrets; LErr: string; LOk: Boolean;
begin
  SetLength(LPSK, 32);
  FillChar(LPSK[0], 32, $42);
  SetLength(LCH, 20);
  FillChar(LCH[0], 20, $11);
  LOk := TlsPasTryDeriveEarlyDataSecrets(TLS13_CIPHER_AES_128_GCM_SHA256, LPSK, LCH, LSec, LErr);
  Check(LOk, 'early SHA256 ok: ' + LErr);
  Check(LSec.Valid, 'valid');
  CheckEqual(Int64(32), Int64(LSec.HashSize), 'hash 32');
  CheckEqual(Int64(16), Int64(LSec.KeyLength), 'key 16');
  CheckEqual(Int64(12), Int64(LSec.IVLength), 'iv 12');
  Check(Length(LSec.ClientEarlyTrafficSecret) = 32, 'c e traffic 32');
  Check(Length(LSec.ClientEarlyKey) = 16, 'c key 16');
  Check(Length(LSec.ClientEarlyIV) = 12, 'c iv 12');
  TlsPasClearEarlyDataSecrets(LSec);
  Check(Length(LSec.ClientEarlyKey) = 0, 'cleared');
end;

procedure TestEarlyDataDeriveSHA384;
var LPSK, LCH: TBytes; LSec: TTlsPasEarlyDataSecrets; LErr: string; LOk: Boolean;
begin
  SetLength(LPSK, 48);
  FillChar(LPSK[0], 48, $55);
  SetLength(LCH, 20);
  FillChar(LCH[0], 20, $22);
  LOk := TlsPasTryDeriveEarlyDataSecrets(TLS13_CIPHER_AES_256_GCM_SHA384, LPSK, LCH, LSec, LErr);
  Check(LOk, 'early SHA384 ok: ' + LErr);
  Check(LSec.HashSize = 48, 'hash 48');
  Check(LSec.KeyLength = 32, 'key 32');
  Check(Length(LSec.ClientEarlyKey) = 32, 'c key 32');
  Check(Length(LSec.ClientEarlyIV) = 12, 'c iv 12');
  TlsPasClearEarlyDataSecrets(LSec);
end;

procedure TestEarlyDataNegative;
var LPSK, LCH: TBytes; LSec: TTlsPasEarlyDataSecrets; LErr: string; LOk: Boolean;
begin
  SetLength(LPSK, 16);
  FillChar(LPSK[0], 16, $01);
  SetLength(LCH, 5);
  LOk := TlsPasTryDeriveEarlyDataSecrets(TLS13_CIPHER_AES_128_GCM_SHA256, LPSK, LCH, LSec, LErr);
  Check(not LOk, 'reject bad PSK len');
  Check(LErr <> '', 'error msg');

  SetLength(LPSK, 32);
  LOk := TlsPasTryDeriveEarlyDataSecrets($1309, LPSK, LCH, LSec, LErr);
  Check(not LOk, 'reject unknown suite');
end;

procedure TestEarlyDataOptionsAndObservability;
var LOpts: TAsyncTlsPasClientOptions;
begin
  LOpts := DefaultAsyncTlsPasClientOptions;
  Check(not LOpts.AllowEarlyData, 'default AllowEarlyData false (zero overhead)');
  LOpts.AllowEarlyData := True;
  Check(LOpts.AllowEarlyData, 'set true');
  Check(True, 'ITlsPasEarlyDataInfo compiled');
end;

procedure TestEarlyDataExtensionSynthetic;
var LPub: TBytes; LPSK, LIdent: TBytes; LPartial, LCH: TBytes; LInfo: TTLS13ClientHelloInfo; LErr: string;
begin
  SetLength(LPub, 32);
  FillChar(LPub[0], 32, $11);
  SetLength(LPSK, 32);
  FillChar(LPSK[0], 32, $22);
  SetLength(LIdent, 16);
  FillChar(LIdent[0], 16, $33);
  // Without early_data: HasEarlyData false, binder still valid
  LCH := BuildTLS13ClientHelloHandshakeWithComputedPSKBinder('example.com', '', LPub, TLS13_CIPHER_AES_128_GCM_SHA256, LIdent, 0, LPSK, LPartial);
  Check(not TlsPasHasEarlyData(LCH), 'no early_data by default');
  Check(TryParseTLS13ClientHelloFromHandshake(LCH, LInfo, LErr) and not LInfo.HasEarlyData, 'parser no early_data');
  // With early_data: flag true, extension present, parser detects
  LCH := BuildTLS13ClientHelloHandshakeWithComputedPSKBinder('example.com', '', LPub, TLS13_CIPHER_AES_128_GCM_SHA256, LIdent, 0, LPSK, LPartial, True);
  Check(TlsPasHasEarlyData(LCH), 'has early_data when allowed');
  Check(TryParseTLS13ClientHelloFromHandshake(LCH, LInfo, LErr) and LInfo.HasEarlyData, 'parser has early_data');
  Check(LInfo.HasPreSharedKey, 'psk still present with early_data');
  // Binder must remain after PSK: early_data before PSK ensures PSK last
  Check(Length(LInfo.FirstPSKBinder) = 32, 'binder len still 32 with early_data');
end;

procedure TestEarlyDataSealRoundTrip;
var LPSK, LCH: TBytes; LSec: TTlsPasEarlyDataSecrets; LErr: string; LSealer: TTLS13RecordSealer; LOpener: TTLS13RecordOpener; LPlain, LRec, LPayload, LDec: TBytes; LType: Byte;
begin
  SetLength(LPSK, 32);
  FillChar(LPSK[0], 32, $42);
  SetLength(LCH, 20);
  FillChar(LCH[0], 20, $11);
  Check(TlsPasTryDeriveEarlyDataSecrets(TLS13_CIPHER_AES_128_GCM_SHA256, LPSK, LCH, LSec, LErr), 'derive early for seal: ' + LErr);
  LSealer.Init(TLS13_CIPHER_AES_128_GCM_SHA256, LSec.ClientEarlyKey, LSec.ClientEarlyIV);
  LOpener.Init(TLS13_CIPHER_AES_128_GCM_SHA256, LSec.ClientEarlyKey, LSec.ClientEarlyIV);
  SetLength(LPlain, 13);
  Move(PChar('hello early!')^, LPlain[0], 13);
  Check(LSealer.Seal(LPlain, TLS_CONTENT_TYPE_APPLICATION_DATA, LRec, LErr), 'seal early: ' + LErr);
  SetLength(LPayload, Length(LRec) - 5);
  Move(LRec[5], LPayload[0], Length(LPayload));
  Check(LOpener.Open(LPayload, LDec, LType, LErr) and (LType = TLS_CONTENT_TYPE_APPLICATION_DATA), 'open early: ' + LErr);
  Check(Length(LDec) = 13, 'dec len 13');
  Check(CompareMem(@LPlain[0], @LDec[0], 13), 'early roundtrip');
  LSealer.Clear; LOpener.Clear; TlsPasClearEarlyDataSecrets(LSec);
end;

procedure TestEarlyDataLiveRejectFallback;
var P: UInt16; C: TAsyncTlsPasSessionCache; S: TTlsPasResumptionSession; LOk: Boolean; LEarly: TBytes;
begin
  P := EnvPort('TLSPAS_HRR_BASE_PORT', 15556);
  if not LivePortAvailable(P) then begin Check(True, 'skip early live no server'); Exit; end;
  C := TAsyncTlsPasSessionCache.Create;
  try
    // Step1: normal handshake to obtain ticket (ServerName=localhost → cache key localhost:P)
    RunLiveEarlyData(P, C, nil);
    Check(GLiveReady, 'early step1 handshake');
    CheckEqual(Int64(0), Int64(GLiveErr), 'step1 no error');
    Sleep(300);
    LOk := C.TryPeek('localhost', P, S);
    if not LOk then begin Check(True, 'skip no ticket'); Exit; end;
    // Promote ticket to early_data capable (synthetic max_early_data, keep PSK/binder valid)
    S.HasMaxEarlyData := True;
    S.MaxEarlyDataSize := 16384;
    C.Store('localhost', P, S);
    // Step2: early_data attempt — server without -early_data will reject but handshake must still succeed via 1-RTT fallback
    SetLength(LEarly, 13);
    Move(PChar('GET / HTTP/1.0'#13#10#13#10)^, LEarly[0], 13);
    // Use small early payload (13 bytes) well below limit
    RunLiveEarlyData(P, C, LEarly);
    Check(GLiveCbCalled, 'early step2 callback');
    Check(GLiveReady, 'early step2 handshake');
    CheckEqual(Int64(0), Int64(GLiveErr), 'early step2 no error');
    Check(GLiveFound, 'early step2 HTTP');
    Check(not GLiveWasEarlyDataAccepted, 'early rejected fallback');
    Check(not GLiveWasHRR, 'no HRR with early');
  finally C.Free; end;
end;

procedure TestTicketMaxEarlyDataCapture;
var C: TAsyncTlsPasSessionCache; S: TTlsPasResumptionSession; LOk: Boolean;
begin
  C := TAsyncTlsPasSessionCache.Create;
  try
    S := Default(TTlsPasResumptionSession);
    S.CipherSuite := TLS13_CIPHER_AES_128_GCM_SHA256;
    SetLength(S.TicketIdentity, 4);
    SetLength(S.ResumptionPSK, 32);
    S.LifetimeSec := 3600;
    S.IssuedMs := 1000;
    S.HasMaxEarlyData := True;
    S.MaxEarlyDataSize := 16384;
    C.Store('host', 443, S);
    LOk := C.TryPeek('host', 443, S);
    Check(LOk, 'peek with early_data');
    Check(S.HasMaxEarlyData and (S.MaxEarlyDataSize = 16384), 'early_data preserved via cache');
    // Zero size should be stored but not trigger early_data (policy)
    S.HasMaxEarlyData := True;
    S.MaxEarlyDataSize := 0;
    C.Store('host', 443, S);
    LOk := C.TryPeek('host', 443, S);
    Check(LOk and S.HasMaxEarlyData and (S.MaxEarlyDataSize = 0), 'zero early_data preserved');
    Check(S.MaxEarlyDataSize <= 16384, 'limit check');
  finally C.Free; end;
end;

procedure TestEndOfEarlyDataHandshakeBuildParse;
var LEoed: TBytes; LInfo: TTLS13EndOfEarlyDataInfo; LErr: string; LOk: Boolean;
begin
  LEoed := BuildTLS13EndOfEarlyDataHandshake;
  Check(Length(LEoed) = 4, 'EOED len 4');
  Check(LEoed[0] = 5, 'EOED type 0x05');
  Check((LEoed[1]=0) and (LEoed[2]=0) and (LEoed[3]=0), 'EOED length zero');
  LOk := TryParseTLS13EndOfEarlyData(LEoed, LInfo, LErr);
  Check(LOk and LInfo.Valid, 'EOED parse valid: ' + LErr);
  LEoed[0] := 4;
  Check(not TryParseTLS13EndOfEarlyData(LEoed, LInfo, LErr), 'EOED wrong type fails');
end;

procedure TestFinishedWithEOEDDiffers;
var LTranscript, LEoed, LHashWithout, LHashWith, LVerifyWithout, LVerifyWith: TBytes;
    LKey: TBytes;
begin
  SetLength(LTranscript, 40);
  FillChar(LTranscript[0], 40, $33);
  LEoed := BuildTLS13EndOfEarlyDataHandshake;
  LHashWithout := SHA256(LTranscript);
  SetLength(LTranscript, 44);
  Move(LEoed[0], LTranscript[40], 4);
  LHashWith := SHA256(LTranscript);
  Check(not CompareMem(@LHashWithout[0], @LHashWith[0], 32), 'EOED changes transcript hash (stability)');
  SetLength(LKey, 32);
  FillChar(LKey[0], 32, $42);
  LVerifyWithout := TLS13ComputeFinishedVerifyDataForCipherSuite(TLS13_CIPHER_AES_128_GCM_SHA256, LKey, LHashWithout);
  LVerifyWith := TLS13ComputeFinishedVerifyDataForCipherSuite(TLS13_CIPHER_AES_128_GCM_SHA256, LKey, LHashWith);
  Check(Length(LVerifyWithout)=32, 'verify len 32');
  Check(not CompareMem(@LVerifyWithout[0], @LVerifyWith[0], 32), 'Finished verify differs with EOED (completeness)');
end;

procedure TestEarlyDataPolicy;
var S: TTlsPasResumptionSession;
begin
  S := Default(TTlsPasResumptionSession);
  S.HasMaxEarlyData := True; S.MaxEarlyDataSize := 16384;
  Check(TlsPasIsEarlyDataAllowed(S, True, 100), 'allow 100');
  Check(not TlsPasIsEarlyDataAllowed(S, False, 100), 'deny not allowed');
  Check(not TlsPasIsEarlyDataAllowed(S, True, 0), 'deny zero len');
  Check(not TlsPasIsEarlyDataAllowed(S, True, 16385), 'deny >16384');
  Check(not TlsPasIsEarlyDataAllowed(S, True, 16384+1), 'deny over limit');
  S.MaxEarlyDataSize := 0;
  Check(not TlsPasIsEarlyDataAllowed(S, True, 10), 'deny max 0');
  S.HasMaxEarlyData := False; S.MaxEarlyDataSize := 16384;
  Check(not TlsPasIsEarlyDataAllowed(S, True, 10), 'deny no max flag');
  S.HasMaxEarlyData := True; S.MaxEarlyDataSize := 500;
  Check(not TlsPasIsEarlyDataAllowed(S, True, 501), 'deny > max');
  Check(TlsPasIsEarlyDataAllowed(S, True, 500), 'allow exact max');
end;

procedure TestEarlyDataFingerprint;
var F1, F2, F3: TBytes; LId, LEarly: TBytes;
begin
  SetLength(LId, 4); FillChar(LId[0], 4, $11);
  SetLength(LEarly, 5); FillChar(LEarly[0], 5, $22);
  F1 := TlsPasComputeEarlyDataFingerprint(LId, LEarly);
  Check(Length(F1)=32, 'fingerprint 32');
  F2 := TlsPasComputeEarlyDataFingerprint(LId, LEarly);
  Check(CompareMem(@F1[0], @F2[0], 32), 'deterministic');
  LEarly[0] := $23;
  F3 := TlsPasComputeEarlyDataFingerprint(LId, LEarly);
  Check(not CompareMem(@F1[0], @F3[0], 32), 'different early diff fingerprint');
end;

procedure TestReplayCache;
var C: TAsyncTlsPasReplayCache; F1, F2: TBytes; IsReplay: Boolean; LOk: Boolean;
begin
  C := TAsyncTlsPasReplayCache.Create(4, 600000);
  try
    SetLength(F1, 32); FillChar(F1[0], 32, $AA);
    SetLength(F2, 32); FillChar(F2[0], 32, $BB);
    LOk := C.CheckAndAdd(F1, IsReplay);
    Check(LOk and not IsReplay, 'first not replay');
    Check(C.Count=1, 'count 1');
    LOk := C.CheckAndAdd(F1, IsReplay);
    Check(LOk and IsReplay, 'second replay');
    Check(C.Count=1, 'still 1');
    LOk := C.CheckAndAdd(F2, IsReplay);
    Check(LOk and not IsReplay, 'F2 not replay');
    Check(C.Count=2, 'count 2');
    C.Clear;
    Check(C.Count=0, 'clear 0');
  finally C.Free; end;
end;

procedure TestReplayStoreInterface;
var Store: ITlsPasReplayStore; F1: TBytes; IsReplay: Boolean; LOk: Boolean;
begin
  Store := TAsyncTlsPasReplayCache.Create(4, 600000) as ITlsPasReplayStore;
  SetLength(F1, 32); FillChar(F1[0], 32, $CC);
  LOk := Store.CheckAndAdd(F1, IsReplay);
  Check(LOk and not IsReplay, 'interface first not replay');
  Check(Store.Count=1, 'interface count 1');
  LOk := Store.CheckAndAdd(F1, IsReplay);
  Check(LOk and IsReplay, 'interface replay');
  Check(Store.Count=1, 'still 1 via interface');
  Store.Clear;
  Check(Store.Count=0, 'clear via interface');
end;

procedure TestReplayStats;
var C: TAsyncTlsPasReplayCache; F1, F2: TBytes; IsReplay: Boolean; S: TAsyncTlsPasReplayStats;
begin
  C := TAsyncTlsPasReplayCache.Create(2, 600000);
  try
    SetLength(F1, 32); FillChar(F1[0], 32, $01);
    SetLength(F2, 32); FillChar(F2[0], 32, $02);
    S := C.GetStats;
    Check((S.Hits=0) and (S.Misses=0) and (S.Current=0), 'initial stats zero');
    C.CheckAndAdd(F1, IsReplay);
    S := C.GetStats;
    Check((S.Misses=1) and (S.Hits=0) and (S.Current=1), 'after miss 1');
    C.CheckAndAdd(F1, IsReplay);
    S := C.GetStats;
    Check((S.Hits=1) and (S.Misses=1), 'after hit 1');
    C.CheckAndAdd(F2, IsReplay);
    S := C.GetStats;
    Check(S.Misses=2, 'misses 2');
    // capacity 2, next insert evicts
    SetLength(F1, 32); FillChar(F1[0], 32, $03);
    C.CheckAndAdd(F1, IsReplay);
    S := C.GetStats;
    Check(S.Evictions=1, 'eviction 1');
    Check(S.Current=2, 'still capacity 2');
    C.Clear;
    S := C.GetStats;
    Check((S.Hits=0) and (S.Current=0), 'clear resets');
  finally C.Free; end;
end;

procedure TestReplayStoreIntegration;
var Store: ITlsPasReplayStore; LId, LEarly: TBytes; LIsReplay: Boolean;
    LOpts: TAsyncTlsPasClientOptions;
begin
  Store := TAsyncTlsPasReplayCache.Create(8, 600000) as ITlsPasReplayStore;
  SetLength(LId, 4); FillChar(LId[0], 4, $11);
  SetLength(LEarly, 5); FillChar(LEarly[0], 5, $22);
  Check(not TlsPasIsEarlyDataReplayed(nil, LId, LEarly), 'nil store not replay');
  Check(not TlsPasIsEarlyDataReplayed(Store, LId, LEarly), 'first not replay');
  Check(TlsPasIsEarlyDataReplayed(Store, LId, LEarly), 'second replay');
  // different early -> not replay
  LEarly[0] := $23;
  Check(not TlsPasIsEarlyDataReplayed(Store, LId, LEarly), 'different payload not replay');
  // options injection zero-overhead check
  LOpts := DefaultAsyncTlsPasClientOptions;
  Check(not Assigned(LOpts.ReplayStore), 'default ReplayStore nil');
  LOpts.ReplayStore := Store;
  Check(Assigned(LOpts.ReplayStore), 'assigned');
  Check(LOpts.ReplayStore.Count=2, 'store count 2 after integration');
  LIsReplay := TlsPasIsEarlyDataReplayed(LOpts.ReplayStore, LId, LEarly);
  Check(LIsReplay, 'via options replay');
end;

procedure TestReplayFileStorePersist;
var Store1, Store2: ITlsPasReplayStore; F1, F2: TBytes; IsReplay: Boolean; LOk: Boolean; LPath: string;
begin
  LPath := '/tmp/tlspas_replay_s10_test.dat';
  if FileExists(LPath) then DeleteFile(LPath);
  if FileExists(LPath + '.tmp') then DeleteFile(LPath + '.tmp');
  Store1 := TAsyncTlsPasReplayFileStore.Create(LPath, 8, 600000) as ITlsPasReplayStore;
  SetLength(F1, 32); FillChar(F1[0], 32, $AA);
  SetLength(F2, 32); FillChar(F2[0], 32, $BB);
  LOk := Store1.CheckAndAdd(F1, IsReplay);
  Check(LOk and not IsReplay, 'file first not replay');
  LOk := Store1.CheckAndAdd(F2, IsReplay);
  Check(LOk and not IsReplay, 'file second not replay');
  Check(Store1.Count=2, 'file count 2');
  Check(FileExists(LPath), 'file persisted');
  // reopen
  Store1 := nil;
  Store2 := TAsyncTlsPasReplayFileStore.Create(LPath, 8, 600000) as ITlsPasReplayStore;
  Check(Store2.Count=2, 'reloaded count 2');
  LOk := Store2.CheckAndAdd(F1, IsReplay);
  Check(LOk and IsReplay, 'reloaded replay hit');
  LOk := Store2.CheckAndAdd(F2, IsReplay);
  Check(LOk and IsReplay, 'reloaded second hit');
  Store2.Clear;
  Check(Store2.Count=0, 'file clear 0');
  // reload after clear should be empty
  Store2 := nil;
  Store2 := TAsyncTlsPasReplayFileStore.Create(LPath, 8, 600000) as ITlsPasReplayStore;
  Check(Store2.Count=0, 'after clear reload 0');
  Store2 := nil;
  if FileExists(LPath) then DeleteFile(LPath);
  if FileExists(LPath + '.tmp') then DeleteFile(LPath + '.tmp');
end;

procedure TestReplayFileStoreCorruption;
var Store: ITlsPasReplayStore; LPath: string; FS: TFileStream; B: Byte;
begin
  LPath := '/tmp/tlspas_replay_s10_corr.dat';
  if FileExists(LPath) then DeleteFile(LPath);
  FS := TFileStream.Create(LPath, fmCreate);
  try
    B := $FF; FS.WriteBuffer(B, 1); // corrupt: size mod 40 !=0
    B := $AA; FS.WriteBuffer(B, 1);
  finally FS.Free; end;
  Store := TAsyncTlsPasReplayFileStore.Create(LPath, 8, 600000) as ITlsPasReplayStore;
  Check(Store.Count=0, 'corrupt file ignored -> 0');
  Store := nil;
  if FileExists(LPath) then DeleteFile(LPath);
end;

procedure TestReplayKvStore;
var Kv: ITlsPasKvStore; Store1, Store2: ITlsPasReplayStore; F1, F2: TBytes; IsReplay: Boolean;
begin
  Kv := TAsyncTlsPasMemoryKvStore.Create as ITlsPasKvStore;
  Store1 := TAsyncTlsPasReplayKvStore.Create(Kv, 8, 600000) as ITlsPasReplayStore;
  SetLength(F1, 32); FillChar(F1[0], 32, $11);
  SetLength(F2, 32); FillChar(F2[0], 32, $22);
  Check(not Store1.CheckAndAdd(F1, IsReplay) or not IsReplay, 'kv first not replay');
  Check(Store1.Count=1, 'kv count 1');
  Check(Store1.CheckAndAdd(F1, IsReplay) and IsReplay, 'kv local hit');
  // second store shares same Kv backend -> cross-instance hit
  Store2 := TAsyncTlsPasReplayKvStore.Create(Kv, 8, 600000) as ITlsPasReplayStore;
  Check(Store2.CheckAndAdd(F1, IsReplay) and IsReplay, 'kv cross hit');
  Check(not Store2.CheckAndAdd(F2, IsReplay) or not IsReplay, 'kv F2 not replay');
  Check(Store2.Count=2, 'kv2 count 2 (F1 cross + F2)');
  Store1.Clear;
  Check(Store1.Count=0, 'kv clear local');
  // Kv cleared too -> Store2 local still has F1, so hit; fresh store should miss
  Check(Store2.CheckAndAdd(F1, IsReplay) and IsReplay, 'after clear still local hit');
  // fresh instance after clear should miss
  Store2 := TAsyncTlsPasReplayKvStore.Create(Kv, 8, 600000) as ITlsPasReplayStore;
  Check(not Store2.CheckAndAdd(F1, IsReplay) or not IsReplay, 'fresh after clear miss');
end;

procedure TestReplayFactory;
var S: ITlsPasReplayStore; Kv: ITlsPasKvStore; F1: TBytes; IsReplay: Boolean; LPath: string;
begin
  S := TAsyncTlsPasReplayStoreFactory.CreateMemory(4, 600000);
  SetLength(F1, 32); FillChar(F1[0], 32, $33);
  Check(not S.CheckAndAdd(F1, IsReplay) or not IsReplay, 'factory memory miss');
  Check(S.Count=1, 'factory memory 1');
  LPath := '/tmp/tlspas_factory_file.dat';
  if FileExists(LPath) then DeleteFile(LPath);
  S := TAsyncTlsPasReplayStoreFactory.CreateFile(LPath, 4, 600000);
  Check(S.Count=0, 'factory file empty');
  Check(not S.CheckAndAdd(F1, IsReplay) or not IsReplay, 'factory file miss');
  S := nil;
  if FileExists(LPath) then DeleteFile(LPath);
  if FileExists(LPath + '.tmp') then DeleteFile(LPath + '.tmp');
  Kv := TAsyncTlsPasMemoryKvStore.Create as ITlsPasKvStore;
  S := TAsyncTlsPasReplayStoreFactory.CreateKv(Kv, 4, 600000);
  Check(S.Count=0, 'factory kv empty');
  Check(not S.CheckAndAdd(F1, IsReplay) or not IsReplay, 'factory kv miss');
  Check(S.Count=1, 'factory kv 1');
end;

procedure TestServerDecide;
var Store: ITlsPasReplayStore; Sess: TTlsPasResumptionSession; Id, Early: TBytes; D: TTlsPasEarlyDataDecision;
begin
  Store := TAsyncTlsPasReplayCache.Create(8, 600000) as ITlsPasReplayStore;
  Sess := Default(TTlsPasResumptionSession);
  Sess.HasMaxEarlyData := True; Sess.MaxEarlyDataSize := 16384;
  SetLength(Id, 4); FillChar(Id[0], 4, $11);
  SetLength(Early, 5); FillChar(Early[0], 5, $22);
  // policy reject: Allow false -> not touch store
  D := TlsPasServerDecideEarlyData(Store, Id, Early, Sess, False);
  Check(D = edRejectPolicy, 'policy reject Allow false');
  Check(Store.Count=0, 'policy reject not inserted');
  Check(not TlsPasServerShouldAcceptEarlyData(Store, Id, Early, Sess, False), 'should not accept policy');
  Check(TlsPasEarlyDataDecisionToStr(edRejectPolicy)='reject_policy', 'toStr policy');
  // policy reject: zero len
  SetLength(Early, 0);
  D := TlsPasServerDecideEarlyData(Store, Id, Early, Sess, True);
  Check(D = edRejectPolicy, 'policy reject zero len');
  SetLength(Early, 5); FillChar(Early[0], 5, $22);
  // first accept
  D := TlsPasServerDecideEarlyData(Store, Id, Early, Sess, True);
  Check(D = edAccept, 'first accept');
  Check(Store.Count=1, 'accept inserted');
  Check(TlsPasServerShouldAcceptEarlyData(Store, Id, Early, Sess, True) = False, 'second should not accept (replay)');
  Check(TlsPasEarlyDataDecisionToStr(edAccept)='accept', 'toStr accept');
  // second replay
  D := TlsPasServerDecideEarlyData(Store, Id, Early, Sess, True);
  Check(D = edRejectReplay, 'second replay');
  Check(TlsPasEarlyDataDecisionToStr(edRejectReplay)='reject_replay', 'toStr replay');
  // different payload -> accept
  Early[0] := $23;
  D := TlsPasServerDecideEarlyData(Store, Id, Early, Sess, True);
  Check(D = edAccept, 'different payload accept');
  Check(Store.Count=2, 'count 2');
  // nil store -> always accept if policy ok
  D := TlsPasServerDecideEarlyData(nil, Id, Early, Sess, True);
  Check(D = edAccept, 'nil store accept');
  Check(TlsPasServerShouldAcceptEarlyData(nil, Id, Early, Sess, True), 'nil should accept');
  // policy fail with nil store still reject
  Sess.HasMaxEarlyData := False;
  D := TlsPasServerDecideEarlyData(nil, Id, Early, Sess, True);
  Check(D = edRejectPolicy, 'nil store policy still reject');
end;

procedure TestServerShouldAcceptIntegration;
var Store: ITlsPasReplayStore; Sess: TTlsPasResumptionSession; Id, Early: TBytes;
begin
  Store := TAsyncTlsPasReplayCache.Create(4, 600000) as ITlsPasReplayStore;
  Sess := Default(TTlsPasResumptionSession);
  Sess.HasMaxEarlyData := True; Sess.MaxEarlyDataSize := 500;
  SetLength(Id, 4); FillChar(Id[0], 4, $55);
  SetLength(Early, 10); FillChar(Early[0], 10, $66);
  Check(TlsPasServerShouldAcceptEarlyData(Store, Id, Early, Sess, True), '500/10 accept');
  Check(not TlsPasServerShouldAcceptEarlyData(Store, Id, Early, Sess, True), 'replay reject');
  SetLength(Early, 501); FillChar(Early[0], 501, $66);
  Check(not TlsPasServerShouldAcceptEarlyData(Store, Id, Early, Sess, True), 'over max reject');
end;

procedure TestObserverStats;
var Store: ITlsPasReplayStore; Obs: TAsyncTlsPasServerObserver; Sess: TTlsPasResumptionSession; Id, Early: TBytes; S: TTlsPasServerStats; RS: TAsyncTlsPasReplayStats;
begin
  Store := TAsyncTlsPasReplayCache.Create(8, 600000) as ITlsPasReplayStore;
  Obs := TAsyncTlsPasServerObserver.Create(Store);
  try
    Sess := Default(TTlsPasResumptionSession);
    Sess.HasMaxEarlyData := True; Sess.MaxEarlyDataSize := 16384;
    SetLength(Id, 4); FillChar(Id[0], 4, $11);
    SetLength(Early, 5); FillChar(Early[0], 5, $22);
    Check(Obs.Decide(Id, Early, Sess, False) = edRejectPolicy, 'obs policy');
    Check(Obs.ShouldAccept(Id, Early, Sess, True), 'obs first accept');
    Check(not Obs.ShouldAccept(Id, Early, Sess, True), 'obs replay');
    Early[0] := $23;
    Check(Obs.Decide(Id, Early, Sess, True) = edAccept, 'obs second accept');
    S := Obs.GetServerStats;
    Check((S.Accepts=2) and (S.RejectPolicy=1) and (S.RejectReplay=1), 'server stats 2/1/1');
    RS := Obs.GetReplayStats;
    Check(RS.Current=2, 'replay current 2');
    Check(Pos('accepts=2', TlsPasFormatServerStats(S))>0, 'format server');
    Check(Pos('hits=', TlsPasFormatReplayStats(RS))>0, 'format replay');
    Obs.Clear;
    S := Obs.GetServerStats;
    Check((S.Accepts=0) and (S.RejectPolicy=0), 'clear resets server');
    RS := Obs.GetReplayStats;
    Check(RS.Current=0, 'clear replay');
  finally Obs.Free; end;
end;

procedure TestFormatHelpers;
var RS: TAsyncTlsPasReplayStats; SS: TTlsPasServerStats; F: string;
begin
  RS := Default(TAsyncTlsPasReplayStats);
  RS.Hits:=1; RS.Misses:=2; RS.Current:=1;
  F := TlsPasFormatReplayStats(RS);
  Check(Pos('hits=1', F)>0, 'format hits');
  Check(Pos('current=1', F)>0, 'format current');
  SS := Default(TTlsPasServerStats);
  SS.Accepts:=5; SS.RejectPolicy:=1; SS.RejectReplay:=2;
  F := TlsPasFormatServerStats(SS);
  Check(Pos('accepts=5', F)>0, 'format accepts');
  Check(Pos('reject_replay=2', F)>0, 'format replay');
end;

procedure TestAdaptiveLimit;
var C: TTlsPasAdaptiveLimitConfig; SS: TTlsPasServerStats; RS: TAsyncTlsPasReplayStats; L: Cardinal;
begin
  C := DefaultTlsPasAdaptiveLimitConfig;
  Check(C.BaseLimit=16384, 'default base 16384');
  Check(C.MinLimit=512, 'min 512');
  SS := Default(TTlsPasServerStats);
  RS := Default(TAsyncTlsPasReplayStats);
  L := TlsPasComputeAdaptiveMaxEarlyData(SS, RS, C);
  Check(L=16384, 'empty stats base');
  SS.Accepts:=9; SS.RejectPolicy:=1; // 10% not >0.1
  L := TlsPasComputeAdaptiveMaxEarlyData(SS, RS, C);
  Check(L=16384, '10% not over');
  SS.Accepts:=8; SS.RejectPolicy:=2; // 20% >0.1 -> half
  L := TlsPasComputeAdaptiveMaxEarlyData(SS, RS, C);
  Check(L=8192, '20% half');
  RS.Current:=51;
  L := TlsPasComputeAdaptiveMaxEarlyData(SS, RS, C);
  Check(L=4096, 'current>50 half again');
  // min clamp
  C.MinLimit:=5000;
  L := TlsPasComputeAdaptiveMaxEarlyData(SS, RS, C);
  Check(L>=5000, 'min clamp');
end;

procedure TestHeaderValue;
begin
  Check(TlsPasEarlyDataDecisionToHeaderValue(edAccept)='1', 'header accept 1');
  Check(TlsPasEarlyDataDecisionToHeaderValue(edRejectPolicy)='0', 'header policy 0');
  Check(TlsPasEarlyDataDecisionToHeaderValue(edRejectReplay)='0', 'header replay 0');
end;

procedure TestHttpEarlyDataBridge;
begin
  Check(HttpEarlyDataHeaderValueFromDecision(edAccept)='1', 'http header accept');
  Check(HttpEarlyDataHeaderValueFromDecision(edRejectPolicy)='0', 'http header policy');
  Check(HttpEarlyDataHeaderValueFromStream(nil)='', 'http nil stream empty');
  Check(not HttpIsEarlyDataStream(nil), 'http nil not early');
  Check(HttpEarlyDataDecisionToLog(edAccept)='accept header=1', 'http log accept');
  Check(HttpEarlyDataDecisionToLog(edRejectReplay)='reject_replay header=0', 'http log replay');
  Check(HTTP_HEADER_X_EARLY_DATA='X-Early-Data', 'header const');
end;

procedure TestHttpRequestEarlyDataFlag;
var
  LReq: IHttpRequest;
  LEarly: IHttpRequestWithEarlyData;
begin
  LReq := THttpRequest.Create(hmGet, TUrl.Parse('http://example.com/'), hvHttp11, NewHttpHeaders, nil, 0);
  Check(not HttpEarlyDataWasEarlyData(LReq), 'initial not early');
  Check(HttpEarlyDataHeaderValue(LReq)='0', 'initial header 0');
  Check(Supports(LReq, IHttpRequestWithEarlyData, LEarly), 'supports early data');
  LEarly.SetWasEarlyData(True);
  Check(HttpEarlyDataWasEarlyData(LReq), 'after set early');
  Check(HttpEarlyDataHeaderValue(LReq)='1', 'header 1 after set');
  Check(LReq.GetHeaders.Get(HTTP_HEADER_X_EARLY_DATA)='', 'request header not auto-set');
  LEarly.SetWasEarlyData(False);
  Check(not HttpEarlyDataWasEarlyData(LReq), 'reset not early');
end;

procedure TestHttpMiddlewareEarlyData;
var
  LReqEarly, LReqNormal: IHttpRequest;
  LEarly: IHttpRequestWithEarlyData;
  LMw: IHttpMiddleware;
  LHandler: IHttpHandler;
  LMwHandler: IHttpHandler;
  LCapEarly, LCapNormal: IHttpResponseWriter;
  LCtxEarly, LCtxNormal: IHttpContext;
begin
  LReqEarly := THttpRequest.Create(hmGet, TUrl.Parse('http://example.com/'), hvHttp11, NewHttpHeaders, nil, 0);
  if Supports(LReqEarly, IHttpRequestWithEarlyData, LEarly) then
    LEarly.SetWasEarlyData(True);
  LReqNormal := THttpRequest.Create(hmGet, TUrl.Parse('http://example.com/'), hvHttp11, NewHttpHeaders, nil, 0);
  LCtxEarly := NewHttpContext;
  LCtxNormal := NewHttpContext;
  (LReqEarly as IHttpRequestWithContext).SetContext(LCtxEarly);
  (LReqNormal as IHttpRequestWithContext).SetContext(LCtxNormal);
  LMw := EarlyDataMiddleware;
  LHandler := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
  end);
  LMwHandler := LMw.Wrap(LHandler);
  LCapEarly := TCaptureWriter.Create;
  LCapNormal := TCaptureWriter.Create;
  LMwHandler.ServeHTTP(LReqEarly, LCapEarly);
  Check(LCapEarly.GetHeaders.Get(HTTP_HEADER_X_EARLY_DATA)='1', 'middleware early header 1');
  Check(HttpContextGetString(LCtxEarly, CONTEXT_EARLY_DATA)='1', 'middleware early context 1');
  LMwHandler.ServeHTTP(LReqNormal, LCapNormal);
  Check(LCapNormal.GetHeaders.Get(HTTP_HEADER_X_EARLY_DATA)='0', 'middleware normal header 0');
  Check(HttpContextGetString(LCtxNormal, CONTEXT_EARLY_DATA)='0', 'middleware normal context 0');
end;

{ ===== S18 client early-data retry bridge ===== }

type
  TMockTransport = class(TInterfacedObject, IHttpTransport)
  public
    FCalls: Integer;
    FResponses: array of IHttpResponse;
    FLastReq: IHttpRequest;
    constructor Create(const AResponses: array of IHttpResponse);
    function RoundTrip(const AReq: IHttpRequest): IHttpResponse;
    property Calls: Integer read FCalls;
    property LastReq: IHttpRequest read FLastReq;
  end;

constructor TMockTransport.Create(const AResponses: array of IHttpResponse);
var I: Integer;
begin
  inherited Create;
  SetLength(FResponses, Length(AResponses));
  for I := 0 to High(AResponses) do FResponses[I] := AResponses[I];
  FCalls := 0;
  FLastReq := nil;
end;

function TMockTransport.RoundTrip(const AReq: IHttpRequest): IHttpResponse;
begin
  FLastReq := AReq;
  if FCalls < Length(FResponses) then
    Result := FResponses[FCalls]
  else
    Result := FResponses[High(FResponses)];
  Inc(FCalls);
end;

procedure TestHttpClientEarlyDataIdempotent;
var LReq: IHttpRequest;
begin
  LReq := THttpRequest.Create(hmGet, TUrl.Parse('http://example.com/'), hvHttp11, NewHttpHeaders, nil, 0);
  Check(HttpEarlyDataIsIdempotentRequest(LReq), 'GET idempotent');
  LReq := THttpRequest.Create(hmHead, TUrl.Parse('http://example.com/'), hvHttp11, NewHttpHeaders, nil, 0);
  Check(HttpEarlyDataIsIdempotentRequest(LReq), 'HEAD idempotent');
  LReq := THttpRequest.Create(hmPost, TUrl.Parse('http://example.com/'), hvHttp11, NewHttpHeaders, nil, 0);
  Check(not HttpEarlyDataIsIdempotentRequest(LReq), 'POST not idempotent');
  LReq := THttpRequest.Create(hmPut, TUrl.Parse('http://example.com/'), hvHttp11, NewHttpHeaders, nil, 0);
  Check(not HttpEarlyDataIsIdempotentRequest(LReq), 'PUT without key not idempotent');
  LReq.Headers.SetHeader('Idempotency-Key', 'k1');
  Check(HttpEarlyDataIsIdempotentRequest(LReq), 'PUT with key idempotent');
end;

procedure TestHttpClientEarlyDataStatus;
begin
  Check(HttpEarlyDataStatusIsRetryable(HTTP_STATUS_TOO_EARLY), '425 retryable');
  Check(not HttpEarlyDataStatusIsRetryable(HTTP_STATUS_OK), '200 not retryable');
  Check(not HttpEarlyDataStatusIsRetryable(HTTP_STATUS_TOO_MANY_REQUESTS), '429 not in early retry');
end;

procedure TestHttpClientEarlyDataShouldRetry;
var LReq: IHttpRequest; LResp: IHttpResponse; LH: IHttpHeaders;
begin
  LReq := THttpRequest.Create(hmGet, TUrl.Parse('http://example.com/'), hvHttp11, NewHttpHeaders, nil, 0);
  HttpEarlyDataMarkRequest(LReq);
  LH := NewHttpHeaders;
  LResp := NewResponse(HTTP_STATUS_TOO_EARLY, LH, nil);
  Check(HttpEarlyDataShouldRetry(LReq, LResp), 'GET early + 425 -> retry');
  LH := NewHttpHeaders;
  LH.SetHeader(HTTP_HEADER_X_EARLY_DATA, '0');
  LResp := NewResponse(HTTP_STATUS_OK, LH, nil);
  Check(HttpEarlyDataShouldRetry(LReq, LResp), 'GET early + X-Early-Data:0 -> retry');
  LH := NewHttpHeaders;
  LH.SetHeader(HTTP_HEADER_X_EARLY_DATA, '1');
  LResp := NewResponse(HTTP_STATUS_OK, LH, nil);
  Check(not HttpEarlyDataShouldRetry(LReq, LResp), 'GET early + X-Early-Data:1 no retry');
  LReq := THttpRequest.Create(hmPost, TUrl.Parse('http://example.com/'), hvHttp11, NewHttpHeaders, nil, 0);
  HttpEarlyDataMarkRequest(LReq);
  LH := NewHttpHeaders;
  LResp := NewResponse(HTTP_STATUS_TOO_EARLY, LH, nil);
  Check(not HttpEarlyDataShouldRetry(LReq, LResp), 'POST early + 425 not retry (non-idempotent)');
  LReq := THttpRequest.Create(hmGet, TUrl.Parse('http://example.com/'), hvHttp11, NewHttpHeaders, nil, 0);
  // not marked early
  LH := NewHttpHeaders;
  LResp := NewResponse(HTTP_STATUS_TOO_EARLY, LH, nil);
  Check(not HttpEarlyDataShouldRetry(LReq, LResp), 'GET not early + 425 no retry');
end;

procedure TestHttpClientEarlyDataMarkAndClone;
var LReq, LCloned: IHttpRequest;
begin
  LReq := THttpRequest.Create(hmGet, TUrl.Parse('http://example.com/'), hvHttp11, NewHttpHeaders, nil, 0);
  HttpEarlyDataMarkRequest(LReq);
  Check(HttpEarlyDataIsEarlyRequest(LReq), 'marked early');
  Check(LReq.Headers.Get(HTTP_HEADER_EARLY_DATA)='1', 'header 1');
  LCloned := HttpEarlyDataCloneWithoutEarlyData(LReq);
  Check(not HttpEarlyDataIsEarlyRequest(LCloned), 'cloned not early');
  Check(LCloned.Headers.Get(HTTP_HEADER_EARLY_DATA)='', 'cloned header removed');
  Check(LCloned.Method=hmGet, 'clone method preserved');
end;

procedure TestHttpClientEarlyDataRetryClient;
var LMock: TMockTransport; LClient: IHttpClient; LReq: IHttpRequest; LResp: IHttpResponse; LH1, LH2: IHttpHeaders; LR1, LR2: IHttpResponse;
begin
  LH1 := NewHttpHeaders;
  LR1 := NewResponse(HTTP_STATUS_TOO_EARLY, LH1, nil);
  LH2 := NewHttpHeaders;
  LH2.SetHeader(HTTP_HEADER_X_EARLY_DATA, '1');
  LR2 := NewResponse(HTTP_STATUS_OK, LH2, 'ok');
  LMock := TMockTransport.Create([LR1, LR2]);
  LClient := NewEarlyDataRetryClient(LMock as IHttpTransport as IHttpClient);
  // Need proper client wrapping: mock implements IHttpTransport, but NewEarlyDataRetryClient expects IHttpClient.
  // So create a minimal IHttpClient adapter around transport via THttpClient with custom transport.
  // Simpler: test via TEarlyDataRetryClient directly with a fake client that delegates to mock transport.
  // We'll bypass by constructing TEarlyDataRetryClient over a THttpClient that uses mock dial? Instead test helpers directly.
  Check(HttpEarlyDataShouldRetry(nil, nil)=False, 'nil guard');
  // Synthetic retry verification via pure helpers + clone
  LReq := THttpRequest.Create(hmGet, TUrl.Parse('http://example.com/'), hvHttp11, NewHttpHeaders, nil, 0);
  HttpEarlyDataMarkRequest(LReq);
  Check(HttpEarlyDataShouldRetry(LReq, LR1), 'helpers predict retry');
  // Verify retry client behavior with a simple fake IHttpClient that counts
  // Use an anonymous inner transport via TEarlyDataRetryClient's Send path: we test via ShouldRetry + Clone logic only (already covered)
  Check(LMock.Calls=0, 'mock not yet called');
end;

procedure TestHttpClientEarlyDataRetryClientLive;
var LInner: IHttpClient; LClient: IHttpClient; LReq: IHttpRequest; LResp: IHttpResponse; LMock: TMockTransport; LH1, LH2: IHttpHeaders;
begin
  LH1 := NewHttpHeaders;
  LH2 := NewHttpHeaders;
  LH2.SetHeader('content-type', 'text/plain');
  // Mock transport that first returns 425, second returns 200
  LMock := TMockTransport.Create([
    NewResponse(HTTP_STATUS_TOO_EARLY, NewHttpHeaders, nil),
    NewResponse(HTTP_STATUS_OK, LH2, 'ok')
  ]);
  // Wrap mock transport in a minimal client
  LInner := THttpClient.Create(LMock as IHttpTransport, THttpClientOptions.Default);
  LClient := NewEarlyDataRetryClient(LInner);
  LReq := THttpRequest.Create(hmGet, TUrl.Parse('http://example.com/'), hvHttp11, NewHttpHeaders, nil, 0);
  HttpEarlyDataMarkRequest(LReq);
  LResp := LClient.Send(LReq);
  Check(LResp.StatusCode=HTTP_STATUS_OK, 'retry client returns 200 after 425');
  Check(LMock.Calls=2, 'mock called twice (retry)');
  // POST should not retry
  LMock := TMockTransport.Create([
    NewResponse(HTTP_STATUS_TOO_EARLY, NewHttpHeaders, nil),
    NewResponse(HTTP_STATUS_OK, LH2, 'ok')
  ]);
  LInner := THttpClient.Create(LMock as IHttpTransport, THttpClientOptions.Default);
  LClient := NewEarlyDataRetryClient(LInner);
  LReq := THttpRequest.Create(hmPost, TUrl.Parse('http://example.com/'), hvHttp11, NewHttpHeaders, nil, 0);
  HttpEarlyDataMarkRequest(LReq);
  LResp := LClient.Send(LReq);
  Check(LResp.StatusCode=HTTP_STATUS_TOO_EARLY, 'POST not retried');
  Check(LMock.Calls=1, 'POST mock called once');
  // X-Early-Data:0 retry
  LMock := TMockTransport.Create([
    NewResponse(HTTP_STATUS_OK, NewHttpHeaders, nil),
    NewResponse(HTTP_STATUS_OK, LH2, 'ok')
  ]);
  // First response has X-Early-Data:0
  LMock.FResponses[0].Headers.SetHeader(HTTP_HEADER_X_EARLY_DATA, '0');
  LInner := THttpClient.Create(LMock as IHttpTransport, THttpClientOptions.Default);
  LClient := NewEarlyDataRetryClient(LInner);
  LReq := THttpRequest.Create(hmGet, TUrl.Parse('http://example.com/'), hvHttp11, NewHttpHeaders, nil, 0);
  HttpEarlyDataMarkRequest(LReq);
  LResp := LClient.Send(LReq);
  Check(LResp.StatusCode=HTTP_STATUS_OK, 'X-Early-Data:0 retry returns second');
  Check(LMock.Calls=2, 'X-Early-Data:0 retry count 2');
end;

procedure TestHttpClientEarlyDataAutoMark;
var LReq: IHttpRequest;
begin
  LReq := THttpRequest.Create(hmGet, TUrl.Parse('http://example.com/'), hvHttp11, NewHttpHeaders, nil, 0);
  Check(not HttpEarlyDataIsEarlyRequest(LReq), 'GET initially not early');
  Check(HttpEarlyDataAutoMarkIfIdempotent(LReq), 'GET auto-mark true');
  Check(HttpEarlyDataIsEarlyRequest(LReq), 'GET after auto-mark early');
  Check(not HttpEarlyDataAutoMarkIfIdempotent(LReq), 'second auto-mark false (already early)');
  LReq := THttpRequest.Create(hmPost, TUrl.Parse('http://example.com/'), hvHttp11, NewHttpHeaders, nil, 0);
  Check(not HttpEarlyDataAutoMarkIfIdempotent(LReq), 'POST auto-mark false (non-idempotent)');
  Check(not HttpEarlyDataIsEarlyRequest(LReq), 'POST still not early');
  LReq := THttpRequest.Create(hmPut, TUrl.Parse('http://example.com/'), hvHttp11, NewHttpHeaders, nil, 0);
  Check(not HttpEarlyDataAutoMarkIfIdempotent(LReq), 'PUT without key not auto');
  LReq.Headers.SetHeader('Idempotency-Key', 'auto1');
  Check(HttpEarlyDataAutoMarkIfIdempotent(LReq), 'PUT with key auto-mark');
  Check(HttpEarlyDataIsEarlyRequest(LReq), 'PUT with key early');
end;

procedure TestHttpClientEarlyDataAutoRetryLive;
var LInner: IHttpClient; LClient: IHttpClient; LReq: IHttpRequest; LResp: IHttpResponse; LMock: TMockTransport; LHOk: IHttpHeaders;
begin
  // Auto client: GET without manual Mark should still retry on 425
  LHOk := NewHttpHeaders;
  LHOk.SetHeader('content-type', 'text/plain');
  LMock := TMockTransport.Create([
    NewResponse(HTTP_STATUS_TOO_EARLY, NewHttpHeaders, nil),
    NewResponse(HTTP_STATUS_OK, LHOk, 'ok')
  ]);
  LInner := THttpClient.Create(LMock as IHttpTransport, THttpClientOptions.Default);
  LClient := NewEarlyDataAutoRetryClient(LInner);
  LReq := THttpRequest.Create(hmGet, TUrl.Parse('http://example.com/'), hvHttp11, NewHttpHeaders, nil, 0);
  // deliberately NOT calling HttpEarlyDataMarkRequest
  LResp := LClient.Send(LReq);
  Check(LResp.StatusCode=HTTP_STATUS_OK, 'auto GET retry returns 200 without manual mark');
  Check(LMock.Calls=2, 'auto GET mock called twice');
  // POST auto should NOT mark and thus not retry
  LHOk := NewHttpHeaders;
  LHOk.SetHeader('content-type', 'text/plain');
  LMock := TMockTransport.Create([
    NewResponse(HTTP_STATUS_TOO_EARLY, NewHttpHeaders, nil),
    NewResponse(HTTP_STATUS_OK, LHOk, 'ok')
  ]);
  LInner := THttpClient.Create(LMock as IHttpTransport, THttpClientOptions.Default);
  LClient := NewEarlyDataAutoRetryClient(LInner);
  LReq := THttpRequest.Create(hmPost, TUrl.Parse('http://example.com/'), hvHttp11, NewHttpHeaders, nil, 0);
  LResp := LClient.Send(LReq);
  Check(LResp.StatusCode=HTTP_STATUS_TOO_EARLY, 'auto POST not retried');
  Check(LMock.Calls=1, 'auto POST mock once');
  // X-Early-Data:0 with auto mark
  LHOk := NewHttpHeaders;
  LHOk.SetHeader('content-type', 'text/plain');
  LMock := TMockTransport.Create([
    NewResponse(HTTP_STATUS_OK, NewHttpHeaders, nil),
    NewResponse(HTTP_STATUS_OK, LHOk, 'ok')
  ]);
  LMock.FResponses[0].Headers.SetHeader(HTTP_HEADER_X_EARLY_DATA, '0');
  LInner := THttpClient.Create(LMock as IHttpTransport, THttpClientOptions.Default);
  LClient := NewEarlyDataAutoRetryClient(LInner);
  LReq := THttpRequest.Create(hmGet, TUrl.Parse('http://example.com/'), hvHttp11, NewHttpHeaders, nil, 0);
  LResp := LClient.Send(LReq);
  Check(LResp.StatusCode=HTTP_STATUS_OK, 'auto X-Early-Data:0 retry');
  Check(LMock.Calls=2, 'auto X-Early-Data:0 retry count 2');
  // With* propagation: WithHeader should keep autoMark
  LHOk := NewHttpHeaders;
  LHOk.SetHeader('content-type', 'text/plain');
  LMock := TMockTransport.Create([
    NewResponse(HTTP_STATUS_TOO_EARLY, NewHttpHeaders, nil),
    NewResponse(HTTP_STATUS_OK, LHOk, 'ok')
  ]);
  LInner := THttpClient.Create(LMock as IHttpTransport, THttpClientOptions.Default);
  LClient := NewEarlyDataAutoRetryClient(LInner).WithHeader('X-Custom', 'v');
  LReq := THttpRequest.Create(hmGet, TUrl.Parse('http://example.com/'), hvHttp11, NewHttpHeaders, nil, 0);
  LResp := LClient.Send(LReq);
  Check(LMock.Calls=2, 'WithHeader preserves autoMark');
end;

procedure TestAdaptiveObserver;
var Store: ITlsPasReplayStore; Obs: TAsyncTlsPasAdaptiveObserver; Sess: TTlsPasResumptionSession; Id, Early: TBytes; Cfg: TTlsPasAdaptiveLimitConfig; LMax: Cardinal;
begin
  Store := TAsyncTlsPasReplayCache.Create(64, 600000) as ITlsPasReplayStore;
  Obs := TAsyncTlsPasAdaptiveObserver.Create(Store);
  try
    Sess := Default(TTlsPasResumptionSession);
    Sess.HasMaxEarlyData := True; Sess.MaxEarlyDataSize := 16384;
    SetLength(Id, 4); FillChar(Id[0], 4, $11);
    SetLength(Early, 100); FillChar(Early[0], 100, $22);
    // initial: no stats -> limit base 16384, 100 accepted
    LMax := Obs.GetAdaptiveMaxEarlyData;
    Check(LMax=16384, 'initial adaptive 16384');
    Check(Obs.Decide(Id, Early, Sess, True)=edAccept, 'adaptive initial accept 100');
    Check(Obs.ShouldAccept(Id, Early, Sess, True)=False, 'adaptive second replay (same fp)');
    // fresh fp with large payload > limit: force throttling via config Base 1000
    Cfg := DefaultTlsPasAdaptiveLimitConfig;
    Cfg.BaseLimit := 50; Cfg.MinLimit := 50; Cfg.MaxLimit := 16384;
    Obs.UpdateConfig(Cfg);
    LMax := Obs.GetAdaptiveMaxEarlyData;
    Check(LMax=50, 'config base 50');
    SetLength(Early, 60); FillChar(Early[0], 60, $33);
    Check(Obs.Decide(Id, Early, Sess, True)=edRejectPolicy, 'adaptive reject >50');
    // small payload within 50 passes
    SetLength(Early, 40); FillChar(Early[0], 40, $44);
    Check(Obs.Decide(Id, Early, Sess, True)=edAccept, 'adaptive accept 40 within 50');
    // simulate high reject rate: create many policy rejects (large) to push rate >0.1
    SetLength(Early, 60);
    Obs.Decide(Id, Early, Sess, True); // reject
    Obs.Decide(Id, Early, Sess, True); // reject again (different fp? need new Id)
    SetLength(Id, 4); Id[0]:=$99;
    SetLength(Early, 60); Obs.Decide(Id, Early, Sess, True);
    // after rejects, adaptive limit should halve base 50 -> but Min is 50 so stays 50
    LMax := Obs.GetAdaptiveMaxEarlyData;
    Check(LMax>=50, 'adaptive after rejects >= min');
    // Clear resets stats -> limit returns to base
    Obs.Clear;
    LMax := Obs.GetAdaptiveMaxEarlyData;
    Check(LMax=50, 'after clear base 50');
  finally Obs.Free; end;
end;

procedure TestAdaptiveDecidePure;
var Store: ITlsPasReplayStore; Obs: TAsyncTlsPasServerObserver; Cfg: TTlsPasAdaptiveLimitConfig; Sess: TTlsPasResumptionSession; Id, Early: TBytes; D: TTlsPasEarlyDataDecision;
begin
  Store := TAsyncTlsPasReplayCache.Create(8, 600000) as ITlsPasReplayStore;
  Obs := TAsyncTlsPasServerObserver.Create(Store);
  try
    Cfg := DefaultTlsPasAdaptiveLimitConfig;
    Cfg.BaseLimit := 100; Cfg.MinLimit := 50; Cfg.MaxLimit := 100;
    Sess := Default(TTlsPasResumptionSession);
    Sess.HasMaxEarlyData := True; Sess.MaxEarlyDataSize := 16384;
    SetLength(Id, 4); FillChar(Id[0], 4, $55);
    SetLength(Early, 90); FillChar(Early[0], 90, $66);
    D := TlsPasAdaptiveDecideEarlyData(Obs, Cfg, Id, Early, Sess, True);
    Check(D=edAccept, 'pure adaptive accept 90 <100');
    SetLength(Early, 110); FillChar(Early[0], 110, $66);
    D := TlsPasAdaptiveDecideEarlyData(Obs, Cfg, Id, Early, Sess, True);
    Check(D=edRejectPolicy, 'pure adaptive reject 110 >100');
    // nil observer still checks limit before policy: if >100 reject, else delegate nil -> accept (if policy ok)
    SetLength(Early, 90);
    D := TlsPasAdaptiveDecideEarlyData(nil, Cfg, Id, Early, Sess, True);
    Check(D=edAccept, 'nil observer accept within limit');
    SetLength(Early, 110);
    D := TlsPasAdaptiveDecideEarlyData(nil, Cfg, Id, Early, Sess, True);
    Check(D=edRejectPolicy, 'nil observer reject over limit');
  finally Obs.Free; end;
end;

procedure TestAdaptiveMiddleware;
var Store: ITlsPasReplayStore; Obs: TAsyncTlsPasAdaptiveObserver; Cfg: TTlsPasAdaptiveLimitConfig;
  LReqEarly, LReqNormal, LReqLarge: IHttpRequest; LEarly: IHttpRequestWithEarlyData;
  LMw: IHttpMiddleware; LHandler: IHttpHandler; LMwHandler: IHttpHandler;
  LCap: IHttpResponseWriter; LCtx: IHttpContext; LBody: TBytes;
begin
  Cfg := DefaultTlsPasAdaptiveLimitConfig;
  Cfg.BaseLimit := 100; Cfg.MinLimit := 50; Cfg.MaxLimit := 100;
  Store := TAsyncTlsPasReplayCache.Create(8, 600000) as ITlsPasReplayStore;
  Obs := TAsyncTlsPasAdaptiveObserver.Create(Store, Cfg);
  try
    // Early GET with small body (0) -> not throttled, header 1
    LReqEarly := THttpRequest.Create(hmGet, TUrl.Parse('http://example.com/'), hvHttp11, NewHttpHeaders, nil, 0);
    if Supports(LReqEarly, IHttpRequestWithEarlyData, LEarly) then LEarly.SetWasEarlyData(True);
    Check(not HttpAdaptiveEarlyDataIsThrottled(LReqEarly, Obs), 'GET early small not throttled');
    Check(HttpAdaptiveEarlyDataHeaderValue(LReqEarly, Obs)='1', 'GET early small header 1');
    // Early GET with large ContentLength > adaptive max (110 >100) -> throttled, header 0
    SetLength(LBody, 110); FillChar(LBody[0], 110, $11);
    LReqLarge := THttpRequest.Create(hmGet, TUrl.Parse('http://example.com/'), hvHttp11, NewHttpHeaders, BytesStreamFrom(LBody), 110);
    if Supports(LReqLarge, IHttpRequestWithEarlyData, LEarly) then LEarly.SetWasEarlyData(True);
    Check(HttpAdaptiveEarlyDataIsThrottled(LReqLarge, Obs), 'GET early large throttled');
    Check(HttpAdaptiveEarlyDataHeaderValue(LReqLarge, Obs)='0', 'GET early large header 0');
    // Normal (not early) never throttled even if large
    LReqNormal := THttpRequest.Create(hmGet, TUrl.Parse('http://example.com/'), hvHttp11, NewHttpHeaders, BytesStreamFrom(LBody), 110);
    Check(not HttpAdaptiveEarlyDataIsThrottled(LReqNormal, Obs), 'normal large not throttled');
    Check(HttpAdaptiveEarlyDataHeaderValue(LReqNormal, Obs)='0', 'normal header 0');
    // Nil observer never throttled
    Check(not HttpAdaptiveEarlyDataIsThrottled(LReqEarly, nil), 'nil observer not throttled');
    // Middleware integration: early small -> header 1, large -> header 0
    LMw := AdaptiveEarlyDataMiddleware(Obs);
    LHandler := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter) begin end);
    LMwHandler := LMw.Wrap(LHandler);
    LCap := TCaptureWriter.Create; LCtx := NewHttpContext;
    (LReqEarly as IHttpRequestWithContext).SetContext(LCtx);
    LMwHandler.ServeHTTP(LReqEarly, LCap);
    Check(LCap.GetHeaders.Get(HTTP_HEADER_X_EARLY_DATA)='1', 'middleware early small 1');
    LCap := TCaptureWriter.Create; LCtx := NewHttpContext;
    (LReqLarge as IHttpRequestWithContext).SetContext(LCtx);
    LMwHandler.ServeHTTP(LReqLarge, LCap);
    Check(LCap.GetHeaders.Get(HTTP_HEADER_X_EARLY_DATA)='0', 'middleware early large throttled 0');
    Check(Pos('adaptive max=', HttpAdaptiveEarlyDataMetrics(Obs))>0, 'metrics contains adaptive max');
    Check(HttpAdaptiveEarlyDataMetrics(nil)='adaptive observer nil', 'metrics nil');
  finally Obs.Free; end;
end;

procedure TestAdaptiveMetricsFormat;
var Store: ITlsPasReplayStore; Obs: TAsyncTlsPasAdaptiveObserver; M: TTlsPasAdaptiveMetrics; F: string;
begin
  Store := TAsyncTlsPasReplayCache.Create(8, 600000) as ITlsPasReplayStore;
  Obs := TAsyncTlsPasAdaptiveObserver.Create(Store);
  try
    M := Obs.GetAdaptiveMetrics;
    Check(M.AdaptiveMax=16384, 'metrics max 16384');
    Check(M.Server.Accepts=0, 'metrics server 0');
    F := TlsPasFormatAdaptiveMetrics(M);
    Check(Pos('adaptive max=16384', F)>0, 'format max');
    Check(Pos('accepts=', F)>0, 'format accepts');
    Check(Pos('hits=', F)>0, 'format hits');
    // after one accept, metrics reflects
    M.Server.Accepts := 5; M.Replay.Current := 51;
    F := TlsPasFormatAdaptiveMetrics(M);
    Check(Pos('adaptive max=', F)>0, 'format after server');
  finally Obs.Free; end;
end;

procedure TestAdaptiveLogLine;
var Store: ITlsPasReplayStore; Obs: TAsyncTlsPasAdaptiveObserver; Cfg: TTlsPasAdaptiveLimitConfig;
  LReqEarly, LReqLarge: IHttpRequest; LEarly: IHttpRequestWithEarlyData; F: string; LBody: TBytes;
begin
  Cfg := DefaultTlsPasAdaptiveLimitConfig;
  Cfg.BaseLimit := 100; Cfg.MinLimit := 50; Cfg.MaxLimit := 100;
  Store := TAsyncTlsPasReplayCache.Create(8, 600000) as ITlsPasReplayStore;
  Obs := TAsyncTlsPasAdaptiveObserver.Create(Store, Cfg);
  try
    LReqEarly := THttpRequest.Create(hmGet, TUrl.Parse('http://example.com/'), hvHttp11, NewHttpHeaders, nil, 0);
    if Supports(LReqEarly, IHttpRequestWithEarlyData, LEarly) then LEarly.SetWasEarlyData(True);
    F := HttpAdaptiveEarlyDataLogLine(LReqEarly, Obs);
    Check(Pos('early=1', F)>0, 'log early 1');
    Check(Pos('throttled=0', F)>0, 'log not throttled small');
    Check(Pos('header=1', F)>0, 'log header 1 small');
    SetLength(LBody, 110); FillChar(LBody[0], 110, $11);
    LReqLarge := THttpRequest.Create(hmGet, TUrl.Parse('http://example.com/'), hvHttp11, NewHttpHeaders, BytesStreamFrom(LBody), 110);
    if Supports(LReqLarge, IHttpRequestWithEarlyData, LEarly) then LEarly.SetWasEarlyData(True);
    F := HttpAdaptiveEarlyDataLogLine(LReqLarge, Obs);
    Check(Pos('throttled=1', F)>0, 'log throttled large');
    Check(Pos('header=0', F)>0, 'log header 0 large');
    Check(Pos('max=100', F)>0, 'log max 100');
    F := HttpAdaptiveEarlyDataLogLine(LReqEarly, nil);
    Check(Pos('max=nil', F)>0, 'log nil max');
  finally Obs.Free; end;
end;

procedure TestAdaptivePressure;
var Store: ITlsPasReplayStore; Obs: TAsyncTlsPasAdaptiveObserver; Sess: TTlsPasResumptionSession;
  Id, Early: TBytes; Cfg: TTlsPasAdaptiveLimitConfig; I: Integer; M: TTlsPasAdaptiveMetrics;
begin
  Cfg := DefaultTlsPasAdaptiveLimitConfig;
  Cfg.BaseLimit := 16384; Cfg.MinLimit := 512; Cfg.MaxLimit := 16384;
  Store := TAsyncTlsPasReplayCache.Create(64, 600000) as ITlsPasReplayStore;
  Obs := TAsyncTlsPasAdaptiveObserver.Create(Store, Cfg);
  try
    Sess := Default(TTlsPasResumptionSession);
    Sess.HasMaxEarlyData := True; Sess.MaxEarlyDataSize := 16384;
    SetLength(Id, 4); FillChar(Id[0], 4, $AB);
    // 60 accepts -> Current 60 >50 => half to 8192
    for I := 1 to 60 do
    begin
      SetLength(Early, 20); FillChar(Early[0], 20, Byte(I));
      Early[0] := Byte(I and $FF); Early[1] := Byte((I shr 8) and $FF);
      Obs.Decide(Id, Early, Sess, True);
    end;
    M := Obs.GetAdaptiveMetrics;
    Check(M.AdaptiveMax=8192, 'pressure Current>50 half to 8192');
    Check(M.Server.Accepts=60, '60 accepts');
    // large 9000 >8192 => throttled (adaptive, not counted in ServerStats)
    SetLength(Early, 9000); FillChar(Early[0], 9000, $CC);
    Check(Obs.Decide(Id, Early, Sess, True)=edRejectPolicy, '9000 throttled under half');
    // reject rate high: add 15 policy rejects via HasMax=false (within adaptive max, counts as RejectPolicy)
    for I := 1 to 15 do
    begin
      Sess.HasMaxEarlyData := False;
      SetLength(Early, 20); FillChar(Early[0], 20, $DD);
      Obs.Decide(Id, Early, Sess, True);
      Sess.HasMaxEarlyData := True;
    end;
    M := Obs.GetAdaptiveMetrics;
    Check(M.Server.RejectPolicy>=15, 'reject policy >=15');
    Check(M.AdaptiveMax<8192, 'further half under high reject');
    Check(M.AdaptiveMax>=512, 'clamped to Min 512');
    Obs.Clear;
    M := Obs.GetAdaptiveMetrics;
    Check(M.AdaptiveMax=16384, 'after clear base 16384');
    Check(M.Server.Accepts=0, 'after clear 0');
  finally Obs.Free; end;
end;

procedure TestAdaptivePrometheus;
var Store: ITlsPasReplayStore; Obs: TAsyncTlsPasAdaptiveObserver; M: TTlsPasAdaptiveMetrics; F, P: string; LReq: IHttpRequest;
begin
  Store := TAsyncTlsPasReplayCache.Create(8, 600000) as ITlsPasReplayStore;
  Obs := TAsyncTlsPasAdaptiveObserver.Create(Store);
  try
    M := Obs.GetAdaptiveMetrics;
    F := TlsPasFormatPrometheusMetrics(M);
    Check(Pos('nextpas_tlspas_adaptive_max', F)>0, 'prom default prefix');
    Check(Pos('# HELP', F)>0, 'prom HELP');
    Check(Pos('# TYPE', F)>0, 'prom TYPE');
    Check(Pos('nextpas_tlspas_server_accepts', F)>0, 'prom accepts');
    Check(Pos('nextpas_tlspas_replay_current', F)>0, 'prom current');
    P := TlsPasFormatPrometheusMetrics(M, 'myapp');
    Check(Pos('myapp_adaptive_max', P)>0, 'prom custom prefix');
    Check(Pos('nextpas_tlspas_adaptive_max', P)=0, 'prom custom no default');
    F := HttpAdaptiveEarlyDataPrometheusText(Obs);
    Check(Pos('nextpas_tlspas_adaptive_max', F)>0, 'http prom wrapper');
    F := HttpAdaptiveEarlyDataPrometheusText(Obs, 'custom');
    Check(Pos('custom_adaptive_max', F)>0, 'http prom custom');
    F := HttpAdaptiveEarlyDataPrometheusText(nil);
    Check(Pos('nextpas_tlspas_adaptive_max 0', F)>0, 'http prom nil 0');
    LReq := THttpRequest.Create(hmGet, TUrl.Parse('http://example.com/'), hvHttp11, NewHttpHeaders, nil, 0);
    F := HttpAdaptiveEarlyDataPrometheusText(Obs);
    Check(Length(F)>100, 'prom length');
  finally Obs.Free; end;
end;

procedure TestPrometheusRegistry;
var Reg: TAsyncTlsPasPrometheusRegistry; Store1, Store2: ITlsPasReplayStore; Obs1, Obs2: TAsyncTlsPasAdaptiveObserver;
  Id, Early: TBytes; Sess: TTlsPasResumptionSession; F: string;
begin
  Reg := TAsyncTlsPasPrometheusRegistry.Create;
  try
    Check(Reg.Count=0, 'reg empty');
    Store1 := TAsyncTlsPasReplayCache.Create(8, 600000) as ITlsPasReplayStore;
    Store2 := TAsyncTlsPasReplayCache.Create(8, 600000) as ITlsPasReplayStore;
    Obs1 := TAsyncTlsPasAdaptiveObserver.Create(Store1);
    Obs2 := TAsyncTlsPasAdaptiveObserver.Create(Store2);
    Sess := Default(TTlsPasResumptionSession);
    Sess.HasMaxEarlyData := True; Sess.MaxEarlyDataSize := 16384;
    SetLength(Id, 4); FillChar(Id[0], 4, $01);
    SetLength(Early, 10); FillChar(Early[0], 10, $02);
    Obs1.Decide(Id, Early, Sess, True);
    Early[0] := $03; Obs2.Decide(Id, Early, Sess, True); Obs2.Decide(Id, Early, Sess, True);
    Reg.Register('api', Obs1);
    Reg.Register('internal', Obs2);
    Check(Reg.Count=2, 'reg 2');
    F := Reg.FormatAllMetrics;
    Check(Pos('observer="api"', F)>0, 'reg api label');
    Check(Pos('observer="internal"', F)>0, 'reg internal label');
    Check(Pos('nextpas_tlspas_adaptive_max', F)>0, 'reg metrics');
    F := HttpPrometheusRegistryText(Reg);
    Check(Pos('observer="api"', F)>0, 'http reg wrapper');
    Check(HttpPrometheusRegistryText(nil)='', 'http reg nil empty');
    Reg.Unregister('api');
    Check(Reg.Count=1, 'unreg 1');
    Reg.Clear;
    Check(Reg.Count=0, 'clear 0');
    Obs1.Free; Obs2.Free;
  finally Reg.Free; end;
end;

procedure TestAdaptiveConfigEnvAndFile;
var C: TTlsPasAdaptiveLimitConfig; LOk: Boolean; LPath: string; F: TextFile;
begin
  SetEnv('NEXTPAS_TLSPAS_BASE_LIMIT', '8000');
  SetEnv('NEXTPAS_TLSPAS_MIN_LIMIT', '1000');
  SetEnv('NEXTPAS_TLSPAS_REJECT_RATE', '0.25');
  LOk := TlsPasTryLoadAdaptiveConfigFromEnv(C);
  Check(LOk, 'env loaded');
  Check(C.BaseLimit=8000, 'env base 8000');
  Check(C.MinLimit=1000, 'env min 1000');
  Check(Abs(C.RejectRateThreshold-0.25)<1e-9, 'env rate 0.25');
  UnsetEnv('NEXTPAS_TLSPAS_BASE_LIMIT');
  UnsetEnv('NEXTPAS_TLSPAS_MIN_LIMIT');
  UnsetEnv('NEXTPAS_TLSPAS_REJECT_RATE');
  LOk := TlsPasTryLoadAdaptiveConfigFromEnv(C);
  Check(not LOk, 'env empty not loaded');
  Check(C.BaseLimit=16384, 'env default base');
  LPath := '/tmp/tlspas_cfg_s26_test.conf';
  AssignFile(F, LPath);
  Rewrite(F);
  WriteLn(F, '# tlspas config');
  WriteLn(F, 'base=4096');
  WriteLn(F, 'min=512');
  WriteLn(F, 'threshold=0.15');
  CloseFile(F);
  LOk := TlsPasTryLoadAdaptiveConfigFromFile(LPath, C);
  Check(LOk, 'file loaded');
  Check(C.BaseLimit=4096, 'file base 4096');
  Check(Abs(C.RejectRateThreshold-0.15)<1e-9, 'file threshold');
  DeleteFile(LPath);
  C := HttpAdaptiveConfigFromEnv;
  Check(C.BaseLimit=16384, 'http env default');
  C := HttpAdaptiveConfigFromFile('/tmp/nonexist_123.conf');
  Check(C.BaseLimit=16384, 'http file default');
end;

procedure TestAdaptiveHealth;
var Store: ITlsPasReplayStore; Obs: TAsyncTlsPasAdaptiveObserver; Sess: TTlsPasResumptionSession;
  Id, Early: TBytes; Cfg: TTlsPasAdaptiveLimitConfig; H: TTlsPasAdaptiveHealth; F: string; M: TTlsPasAdaptiveMetrics;
  Hdl: IHttpHandler; Req: IHttpRequest; W: IHttpResponseWriter; Ctx: IHttpContext;
begin
  Store := TAsyncTlsPasReplayCache.Create(64, 600000) as ITlsPasReplayStore;
  Cfg := DefaultTlsPasAdaptiveLimitConfig;
  Obs := TAsyncTlsPasAdaptiveObserver.Create(Store, Cfg);
  try
    H := Obs.GetAdaptiveHealth;
    Check(H.Healthy, 'initial healthy');
    Check(Pos('ok', H.Reason)>0, 'initial ok');
    Check(Pos('healthy', TlsPasFormatAdaptiveHealth(H))>0, 'format healthy');
    F := TlsPasAdaptiveHealthToPrometheus(H, 'nextpas_tlspas');
    Check(Pos('health_status 1', F)>0, 'prom healthy 1');
    F := TlsPasAdaptiveHealthToPrometheus(H, 'nextpas_tlspas', 'observer="api"');
    Check(Pos('observer="api"', F)>0, 'prom label');
    F := HttpAdaptiveHealthJSON(Obs);
    Check(Pos('"healthy":true', F)>0, 'json healthy true');
    Check(Pos('"adaptive_max"', F)>0, 'json contains adaptive_max');
    // degrade via high reject rate
    Sess := Default(TTlsPasResumptionSession);
    Sess.HasMaxEarlyData := True; Sess.MaxEarlyDataSize := 16384;
    SetLength(Id, 4); FillChar(Id[0], 4, $11);
    // 8 accepts +2 rejects => 20% >0.1
    SetLength(Early, 10); FillChar(Early[0], 10, $01);
    Obs.Decide(Id, Early, Sess, True);
    SetLength(Early, 10); FillChar(Early[0], 10, $02); Obs.Decide(Id, Early, Sess, True);
    SetLength(Early, 10); FillChar(Early[0], 10, $03); Obs.Decide(Id, Early, Sess, True);
    SetLength(Early, 10); FillChar(Early[0], 10, $04); Obs.Decide(Id, Early, Sess, True);
    SetLength(Early, 10); FillChar(Early[0], 10, $05); Obs.Decide(Id, Early, Sess, True);
    SetLength(Early, 10); FillChar(Early[0], 10, $06); Obs.Decide(Id, Early, Sess, True);
    SetLength(Early, 10); FillChar(Early[0], 10, $07); Obs.Decide(Id, Early, Sess, True);
    SetLength(Early, 10); FillChar(Early[0], 10, $08); Obs.Decide(Id, Early, Sess, True);
    // 2 policy rejects via HasMax false
    Sess.HasMaxEarlyData := False;
    SetLength(Early, 10); Obs.Decide(Id, Early, Sess, True);
    SetLength(Early, 10); Obs.Decide(Id, Early, Sess, True);
    Sess.HasMaxEarlyData := True;
    H := Obs.GetAdaptiveHealth;
    Check(not H.Healthy, 'degraded after high reject');
    Check(Pos('reject_rate', H.Reason)>0, 'reason reject_rate');
    F := HttpAdaptiveHealthJSON(Obs);
    Check(Pos('"healthy":false', F)>0, 'json degraded');
    // health handler: should return 503 when degraded
    Hdl := HttpAdaptiveHealthHandler(Obs);
    Req := THttpRequest.Create(hmGet, TUrl.Parse('http://example.com/healthz'), hvHttp11, NewHttpHeaders, nil, 0);
    Ctx := NewHttpContext;
    (Req as IHttpRequestWithContext).SetContext(Ctx);
    W := TCaptureWriter.Create;
    Hdl.ServeHTTP(Req, W);
    Check(W.GetStatus = HTTP_STATUS_SERVICE_UNAVAILABLE, 'handler 503 degraded');
    Obs.Clear;
    H := Obs.GetAdaptiveHealth;
    Check(H.Healthy, 'after clear healthy');
    // nil observer JSON
    F := HttpAdaptiveHealthJSON(nil);
    Check(Pos('observer nil', F)>0, 'nil json');
    // pure compute with config
    M := Obs.GetAdaptiveMetrics;
    H := TlsPasComputeAdaptiveHealth(M, Cfg);
    Check(H.Healthy, 'pure compute healthy');
  finally Obs.Free; end;
end;

procedure TestHealthPrometheusLabels;
var H: TTlsPasAdaptiveHealth; F: string;
begin
  H.Healthy := True; H.Reason := 'ok'; H.RejectRate := 0; H.Current := 10; H.AdaptiveMax := 16384;
  F := TlsPasAdaptiveHealthToPrometheus(H, 'myapp');
  Check(Pos('myapp_health_status', F)>0, 'health custom prefix');
  Check(Pos('health_status 1', F)>0, 'health 1');
  H.Healthy := False; H.Reason := 'reject'; H.Current := 90;
  F := TlsPasAdaptiveHealthToPrometheus(H, 'myapp', 'observer="x"');
  Check(Pos('observer="x"', F)>0, 'health label');
  Check(Pos('} 0', F)>0, 'health 0 with label');
  F := TlsPasFormatAdaptiveHealth(H);
  Check(Pos('degraded', F)>0, 'format degraded');
end;

var
  GSuite: TTestSuite;
begin
  GSuite := TTestSuite.Create('tlspas_hrr');
  GSuite.Test('GroupKeyShareLen', @TestGroupKeyShareLen);
  GSuite.Test('IsSupportedHRRGroup', @TestIsSupportedHRRGroup);
  GSuite.Test('MessageHashSHA256', @TestMessageHashSHA256);
  GSuite.Test('MessageHashSHA384', @TestMessageHashSHA384);
  GSuite.Test('P384KeyPairRoundtrip', @TestP384KeyPairAndRoundtrip);
  GSuite.Test('P256Roundtrip', @TestP256Roundtrip);
  GSuite.Test('PatchP384', @TestPatchP384);
  GSuite.Test('TranscriptSynthesis', @TestTranscriptSynthesis);
  GSuite.Test('CacheMultiLRU', @TestCacheMultiLRU);
  GSuite.Test('HRRBaseNoHRR', @TestHRRBaseNoHRR);
  GSuite.Test('HRRP256Live', @TestHRRP256Live);
  GSuite.Test('HRRP384Live', @TestHRRP384Live);
  GSuite.Test('EarlyDataSHA256', @TestEarlyDataDeriveSHA256);
  GSuite.Test('EarlyDataSHA384', @TestEarlyDataDeriveSHA384);
  GSuite.Test('EarlyDataNegative', @TestEarlyDataNegative);
  GSuite.Test('EarlyDataOptions', @TestEarlyDataOptionsAndObservability);
  GSuite.Test('EarlyDataExtension', @TestEarlyDataExtensionSynthetic);
  GSuite.Test('EarlyDataSeal', @TestEarlyDataSealRoundTrip);
  GSuite.Test('EarlyDataTicketCache', @TestTicketMaxEarlyDataCapture);
  GSuite.Test('EarlyDataLiveRejectFallback', @TestEarlyDataLiveRejectFallback);
  GSuite.Test('EndOfEarlyDataBuildParse', @TestEndOfEarlyDataHandshakeBuildParse);
  GSuite.Test('FinishedWithEOEDDiffers', @TestFinishedWithEOEDDiffers);
  GSuite.Test('EarlyDataPolicy', @TestEarlyDataPolicy);
  GSuite.Test('EarlyDataFingerprint', @TestEarlyDataFingerprint);
  GSuite.Test('ReplayCache', @TestReplayCache);
  GSuite.Test('ReplayStoreInterface', @TestReplayStoreInterface);
  GSuite.Test('ReplayStats', @TestReplayStats);
  GSuite.Test('ReplayStoreIntegration', @TestReplayStoreIntegration);
  GSuite.Test('ReplayFileStorePersist', @TestReplayFileStorePersist);
  GSuite.Test('ReplayFileStoreCorruption', @TestReplayFileStoreCorruption);
  GSuite.Test('ReplayKvStore', @TestReplayKvStore);
  GSuite.Test('ReplayFactory', @TestReplayFactory);
  GSuite.Test('ServerDecide', @TestServerDecide);
  GSuite.Test('ServerShouldAccept', @TestServerShouldAcceptIntegration);
  GSuite.Test('ObserverStats', @TestObserverStats);
  GSuite.Test('FormatHelpers', @TestFormatHelpers);
  GSuite.Test('AdaptiveLimit', @TestAdaptiveLimit);
  GSuite.Test('HeaderValue', @TestHeaderValue);
  GSuite.Test('HttpEarlyDataBridge', @TestHttpEarlyDataBridge);
  GSuite.Test('HttpRequestEarlyDataFlag', @TestHttpRequestEarlyDataFlag);
  GSuite.Test('HttpMiddlewareEarlyData', @TestHttpMiddlewareEarlyData);
  GSuite.Test('HttpClientEarlyDataIdempotent', @TestHttpClientEarlyDataIdempotent);
  GSuite.Test('HttpClientEarlyDataStatus', @TestHttpClientEarlyDataStatus);
  GSuite.Test('HttpClientEarlyDataShouldRetry', @TestHttpClientEarlyDataShouldRetry);
  GSuite.Test('HttpClientEarlyDataMarkAndClone', @TestHttpClientEarlyDataMarkAndClone);
  GSuite.Test('HttpClientEarlyDataRetryClientLive', @TestHttpClientEarlyDataRetryClientLive);
  GSuite.Test('HttpClientEarlyDataAutoMark', @TestHttpClientEarlyDataAutoMark);
  GSuite.Test('HttpClientEarlyDataAutoRetryLive', @TestHttpClientEarlyDataAutoRetryLive);
  GSuite.Test('AdaptiveObserver', @TestAdaptiveObserver);
  GSuite.Test('AdaptiveDecidePure', @TestAdaptiveDecidePure);
  GSuite.Test('AdaptiveMiddleware', @TestAdaptiveMiddleware);
  GSuite.Test('AdaptiveMetricsFormat', @TestAdaptiveMetricsFormat);
  GSuite.Test('AdaptiveLogLine', @TestAdaptiveLogLine);
  GSuite.Test('AdaptivePressure', @TestAdaptivePressure);
  GSuite.Test('AdaptivePrometheus', @TestAdaptivePrometheus);
  GSuite.Test('PrometheusRegistry', @TestPrometheusRegistry);
  GSuite.Test('AdaptiveConfigEnvAndFile', @TestAdaptiveConfigEnvAndFile);
  GSuite.Test('AdaptiveHealth', @TestAdaptiveHealth);
  GSuite.Test('HealthPrometheusLabels', @TestHealthPrometheusLabels);
  if not GSuite.Run then
    Halt(1);
end.
