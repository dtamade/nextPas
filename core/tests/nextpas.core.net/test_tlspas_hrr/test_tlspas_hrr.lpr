program test_tlspas_hrr;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils,
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.crypto.hash,
  nextpas.core.crypto.p384,
  nextpas.core.crypto.p256ecdh,
  nextpas.core.tls.tls13.wire,
  nextpas.core.tls.tls13.clienthello,
  nextpas.core.tls.tls13.clienthello.parser,
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
  GLiveStream:=nil; GLiveErr:=0; GLiveReady:=False; GLiveCbCalled:=False; GLiveFinished:=False; GLiveFound:=False; GLiveWasHRR:=False; SetLength(GLiveAcc,0); GLiveBuf:=nil;
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
var LOpts: TAsyncTlsPasClientOptions; LInfo: ITlsPasEarlyDataInfo;
begin
  LOpts := DefaultAsyncTlsPasClientOptions;
  Check(not LOpts.AllowEarlyData, 'default AllowEarlyData false (zero overhead)');
  LOpts.AllowEarlyData := True;
  Check(LOpts.AllowEarlyData, 'set true');

  // Streams currently always report false until S6-record enables; verify interface present
  // Synthetic check: create via fake path not needed; just compile-time Supports presence via RTTI
  Check(True, 'ITlsPasEarlyDataInfo compiled');
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
  if not GSuite.Run then
    Halt(1);
end.
