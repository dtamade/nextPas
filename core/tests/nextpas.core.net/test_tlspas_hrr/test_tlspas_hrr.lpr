program test_tlspas_hrr;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.crypto.hash,
  nextpas.core.crypto.p384,
  nextpas.core.crypto.p256ecdh,
  nextpas.core.tls.tls13.wire,
  nextpas.core.tls.tls13.clienthello,
  nextpas.core.tls.tls13.clienthello.parser,
  nextpas.core.net.async.tlspas;

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
  // Simulate tlspas HRRTranscript = message_hash || HRR || CH2
  SetLength(LTranscript, 0);
  SetLength(LTranscript, Length(LMsgHash) + Length(LHRR) + Length(LCH2));
  Move(LMsgHash[0], LTranscript[0], Length(LMsgHash));
  Move(LHRR[0], LTranscript[Length(LMsgHash)], Length(LHRR));
  Move(LCH2[0], LTranscript[Length(LMsgHash)+Length(LHRR)], Length(LCH2));
  Check(LTranscript[0] = 254, 'transcript starts with message_hash');
  Check(Length(LTranscript) = (4+32)+8+12, 'transcript total len');
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
  if not GSuite.Run then
    Halt(1);
end.
