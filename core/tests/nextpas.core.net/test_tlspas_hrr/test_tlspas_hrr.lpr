program test_tlspas_hrr;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, Classes,
  nextpas.core.base,
  nextpas.core.test,
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
  nextpas.core.net.async.tcp;

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
    LOpts.EarlyData:=Copy(AEarlyData);
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
  if not GSuite.Run then
    Halt(1);
end.
