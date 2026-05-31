program test_tls13_recordsealer;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.tls13.recordsealer,
  nextpas.core.tls.tls13.wire;

var
  GPassCount: Integer = 0;
  GFailCount: Integer = 0;

procedure Check(ACondition: Boolean; const AName: string);
begin
  if ACondition then
  begin
    WriteLn('  [PASS] ', AName);
    Inc(GPassCount);
  end
  else
  begin
    WriteLn('  [FAIL] ', AName);
    Inc(GFailCount);
  end;
end;

procedure TestSealOpenRoundTrip_AES128GCM;
var
  LSealer: TTLS13RecordSealer;
  LOpener: TTLS13RecordOpener;
  LKey, LIV, LFragment, LRecord: TBytes;
  LOutFragment: TBytes;
  LOutContentType: Byte;
  LError: string;
  LPayload: TBytes;
begin
  WriteLn('--- Seal/Open round-trip AES-128-GCM ---');
  SetLength(LKey, 16);
  FillChar(LKey[0], 16, $AB);
  SetLength(LIV, 12);
  FillChar(LIV[0], 12, $CD);

  LSealer.Init(TLS13_CIPHER_AES_128_GCM_SHA256, LKey, LIV);
  LOpener.Init(TLS13_CIPHER_AES_128_GCM_SHA256, LKey, LIV);

  LFragment := TBytes.Create($48, $65, $6C, $6C, $6F);

  Check(LSealer.Seal(LFragment, TLS_CONTENT_TYPE_APPLICATION_DATA, LRecord, LError),
    'seal succeeds');
  Check(LError = '', 'no error on seal');
  Check(Length(LRecord) > 5, 'record has header + payload');
  Check(LRecord[0] = TLS_CONTENT_TYPE_APPLICATION_DATA, 'record content type');
  Check(LRecord[1] = $03, 'legacy version hi');
  Check(LRecord[2] = $03, 'legacy version lo');

  SetLength(LPayload, Length(LRecord) - 5);
  Move(LRecord[5], LPayload[0], Length(LPayload));

  Check(LOpener.Open(LPayload, LOutFragment, LOutContentType, LError),
    'open succeeds');
  Check(LOutContentType = TLS_CONTENT_TYPE_APPLICATION_DATA, 'content type recovered');
  Check(Length(LOutFragment) = 5, 'fragment length matches');
  Check(CompareMem(@LOutFragment[0], @LFragment[0], 5), 'fragment content matches');

  LSealer.Clear;
  LOpener.Clear;
end;

procedure TestSealOpenRoundTrip_ChaCha20;
var
  LSealer: TTLS13RecordSealer;
  LOpener: TTLS13RecordOpener;
  LKey, LIV, LFragment, LRecord: TBytes;
  LOutFragment: TBytes;
  LOutContentType: Byte;
  LError: string;
  LPayload: TBytes;
begin
  WriteLn('--- Seal/Open round-trip ChaCha20-Poly1305 ---');
  SetLength(LKey, 32);
  FillChar(LKey[0], 32, $11);
  SetLength(LIV, 12);
  FillChar(LIV[0], 12, $22);

  LSealer.Init(TLS13_CIPHER_CHACHA20_POLY1305_SHA256, LKey, LIV);
  LOpener.Init(TLS13_CIPHER_CHACHA20_POLY1305_SHA256, LKey, LIV);

  LFragment := TBytes.Create($57, $6F, $72, $6C, $64);

  Check(LSealer.Seal(LFragment, TLS_CONTENT_TYPE_HANDSHAKE, LRecord, LError),
    'chacha seal succeeds');

  SetLength(LPayload, Length(LRecord) - 5);
  Move(LRecord[5], LPayload[0], Length(LPayload));

  Check(LOpener.Open(LPayload, LOutFragment, LOutContentType, LError),
    'chacha open succeeds');
  Check(LOutContentType = TLS_CONTENT_TYPE_HANDSHAKE, 'handshake type recovered');
  Check(CompareMem(@LOutFragment[0], @LFragment[0], 5), 'chacha fragment matches');

  LSealer.Clear;
  LOpener.Clear;
end;

procedure TestSequenceIncrement;
var
  LSealer: TTLS13RecordSealer;
  LKey, LIV, LFragment, LRecord: TBytes;
  LError: string;
begin
  WriteLn('--- Sequence increment ---');
  SetLength(LKey, 16);
  FillChar(LKey[0], 16, $01);
  SetLength(LIV, 12);
  FillChar(LIV[0], 12, $02);

  LSealer.Init(TLS13_CIPHER_AES_128_GCM_SHA256, LKey, LIV);
  LFragment := TBytes.Create($AA);

  Check(LSealer.GetSequence = 0, 'initial seq = 0');
  LSealer.Seal(LFragment, TLS_CONTENT_TYPE_APPLICATION_DATA, LRecord, LError);
  Check(LSealer.GetSequence = 1, 'seq after first seal = 1');
  LSealer.Seal(LFragment, TLS_CONTENT_TYPE_APPLICATION_DATA, LRecord, LError);
  Check(LSealer.GetSequence = 2, 'seq after second seal = 2');

  LSealer.Clear;
end;

procedure TestSequenceExhaustion;
var
  LSealer: TTLS13RecordSealer;
  LKey, LIV, LFragment, LRecord: TBytes;
  LError: string;
begin
  WriteLn('--- Sequence exhaustion ---');
  SetLength(LKey, 16);
  FillChar(LKey[0], 16, $FF);
  SetLength(LIV, 12);
  FillChar(LIV[0], 12, $EE);

  LSealer.Init(TLS13_CIPHER_AES_128_GCM_SHA256, LKey, LIV);
  LSealer.FSequence := High(QWord) - 1;
  LFragment := TBytes.Create($BB);

  Check(not LSealer.IsExhausted, 'not exhausted before last seal');
  Check(LSealer.Seal(LFragment, TLS_CONTENT_TYPE_APPLICATION_DATA, LRecord, LError),
    'second-to-last seal succeeds');
  Check(LSealer.Seal(LFragment, TLS_CONTENT_TYPE_APPLICATION_DATA, LRecord, LError),
    'last seal succeeds');
  Check(LSealer.IsExhausted, 'exhausted after last seal');
  Check(not LSealer.Seal(LFragment, TLS_CONTENT_TYPE_APPLICATION_DATA, LRecord, LError),
    'seal after exhaustion fails');
  Check(Pos('exhausted', LError) > 0, 'error mentions exhausted');

  LSealer.Clear;
end;

procedure TestTamperedCiphertext;
var
  LSealer: TTLS13RecordSealer;
  LOpener: TTLS13RecordOpener;
  LKey, LIV, LFragment, LRecord: TBytes;
  LOutFragment: TBytes;
  LOutContentType: Byte;
  LError: string;
  LPayload: TBytes;
begin
  WriteLn('--- Tampered ciphertext rejected ---');
  SetLength(LKey, 32);
  FillChar(LKey[0], 32, $33);
  SetLength(LIV, 12);
  FillChar(LIV[0], 12, $44);

  LSealer.Init(TLS13_CIPHER_CHACHA20_POLY1305_SHA256, LKey, LIV);
  LOpener.Init(TLS13_CIPHER_CHACHA20_POLY1305_SHA256, LKey, LIV);

  LFragment := TBytes.Create($DE, $AD, $BE, $EF);
  LSealer.Seal(LFragment, TLS_CONTENT_TYPE_APPLICATION_DATA, LRecord, LError);

  SetLength(LPayload, Length(LRecord) - 5);
  Move(LRecord[5], LPayload[0], Length(LPayload));
  LPayload[0] := LPayload[0] xor $FF;

  Check(not LOpener.Open(LPayload, LOutFragment, LOutContentType, LError),
    'tampered payload rejected');
  Check(LError <> '', 'error message present');

  LSealer.Clear;
  LOpener.Clear;
end;

procedure TestUpdateKey;
var
  LSealer: TTLS13RecordSealer;
  LKey1, LKey2, LIV1, LIV2, LFragment, LRecord: TBytes;
  LError: string;
begin
  WriteLn('--- UpdateKey resets sequence ---');
  SetLength(LKey1, 16);
  FillChar(LKey1[0], 16, $A1);
  SetLength(LIV1, 12);
  FillChar(LIV1[0], 12, $B1);
  SetLength(LKey2, 16);
  FillChar(LKey2[0], 16, $A2);
  SetLength(LIV2, 12);
  FillChar(LIV2[0], 12, $B2);

  LSealer.Init(TLS13_CIPHER_AES_128_GCM_SHA256, LKey1, LIV1);
  LFragment := TBytes.Create($CC);
  LSealer.Seal(LFragment, TLS_CONTENT_TYPE_APPLICATION_DATA, LRecord, LError);
  LSealer.Seal(LFragment, TLS_CONTENT_TYPE_APPLICATION_DATA, LRecord, LError);
  Check(LSealer.GetSequence = 2, 'seq = 2 before update');

  LSealer.UpdateKey(LKey2, LIV2);
  Check(LSealer.GetSequence = 0, 'seq reset to 0 after update');
  Check(not LSealer.IsExhausted, 'not exhausted after update');

  LSealer.Clear;
end;

procedure TestEmptyFragment;
var
  LSealer: TTLS13RecordSealer;
  LOpener: TTLS13RecordOpener;
  LKey, LIV, LFragment, LRecord: TBytes;
  LOutFragment: TBytes;
  LOutContentType: Byte;
  LError: string;
  LPayload: TBytes;
begin
  WriteLn('--- Empty fragment ---');
  SetLength(LKey, 32);
  FillChar(LKey[0], 32, $55);
  SetLength(LIV, 12);
  FillChar(LIV[0], 12, $66);

  LSealer.Init(TLS13_CIPHER_CHACHA20_POLY1305_SHA256, LKey, LIV);
  LOpener.Init(TLS13_CIPHER_CHACHA20_POLY1305_SHA256, LKey, LIV);

  SetLength(LFragment, 0);
  Check(LSealer.Seal(LFragment, TLS_CONTENT_TYPE_APPLICATION_DATA, LRecord, LError),
    'empty fragment seal ok');

  SetLength(LPayload, Length(LRecord) - 5);
  Move(LRecord[5], LPayload[0], Length(LPayload));

  Check(LOpener.Open(LPayload, LOutFragment, LOutContentType, LError),
    'empty fragment open ok');
  Check(Length(LOutFragment) = 0, 'recovered fragment is empty');
  Check(LOutContentType = TLS_CONTENT_TYPE_APPLICATION_DATA, 'content type correct');

  LSealer.Clear;
  LOpener.Clear;
end;

procedure TestAES256GCM;
var
  LSealer: TTLS13RecordSealer;
  LOpener: TTLS13RecordOpener;
  LKey, LIV, LFragment, LRecord: TBytes;
  LOutFragment: TBytes;
  LOutContentType: Byte;
  LError: string;
  LPayload: TBytes;
begin
  WriteLn('--- AES-256-GCM round-trip ---');
  SetLength(LKey, 32);
  FillChar(LKey[0], 32, $77);
  SetLength(LIV, 12);
  FillChar(LIV[0], 12, $88);

  LSealer.Init(TLS13_CIPHER_AES_256_GCM_SHA384, LKey, LIV);
  LOpener.Init(TLS13_CIPHER_AES_256_GCM_SHA384, LKey, LIV);

  LFragment := TBytes.Create($01, $02, $03, $04, $05, $06, $07, $08);
  Check(LSealer.Seal(LFragment, TLS_CONTENT_TYPE_APPLICATION_DATA, LRecord, LError),
    'aes256 seal ok');

  SetLength(LPayload, Length(LRecord) - 5);
  Move(LRecord[5], LPayload[0], Length(LPayload));

  Check(LOpener.Open(LPayload, LOutFragment, LOutContentType, LError),
    'aes256 open ok');
  Check(CompareMem(@LOutFragment[0], @LFragment[0], 8), 'aes256 content matches');

  LSealer.Clear;
  LOpener.Clear;
end;

procedure TestInvalidIV;
var
  LSealer: TTLS13RecordSealer;
  LKey, LIV, LFragment, LRecord: TBytes;
  LError: string;
begin
  WriteLn('--- Invalid IV rejected ---');
  SetLength(LKey, 16);
  FillChar(LKey[0], 16, $AA);
  SetLength(LIV, 11); // Wrong! Should be 12
  FillChar(LIV[0], 11, $BB);

  LSealer.Init(TLS13_CIPHER_AES_128_GCM_SHA256, LKey, LIV);
  LFragment := TBytes.Create($01, $02, $03);

  Check(not LSealer.Seal(LFragment, TLS_CONTENT_TYPE_APPLICATION_DATA, LRecord, LError),
    'seal with 11-byte IV fails');
  Check(Pos('IV', LError) > 0, 'error mentions IV');

  // Zero-length IV
  SetLength(LIV, 0);
  LSealer.Init(TLS13_CIPHER_AES_128_GCM_SHA256, LKey, LIV);
  Check(not LSealer.Seal(LFragment, TLS_CONTENT_TYPE_APPLICATION_DATA, LRecord, LError),
    'seal with empty IV fails');

  LSealer.Clear;
end;

procedure TestOversizeFragment;
var
  LSealer: TTLS13RecordSealer;
  LKey, LIV, LFragment, LRecord: TBytes;
  LError: string;
begin
  WriteLn('--- Oversize fragment rejected ---');
  SetLength(LKey, 16);
  FillChar(LKey[0], 16, $CC);
  SetLength(LIV, 12);
  FillChar(LIV[0], 12, $DD);

  LSealer.Init(TLS13_CIPHER_AES_128_GCM_SHA256, LKey, LIV);

  // 16385 bytes = over TLS 1.3 max
  SetLength(LFragment, 16385);
  FillChar(LFragment[0], 16385, $EE);

  Check(not LSealer.Seal(LFragment, TLS_CONTENT_TYPE_APPLICATION_DATA, LRecord, LError),
    'seal with 16385-byte fragment fails');
  Check(Pos('max', LError) > 0, 'error mentions max size');

  // 16384 bytes = exactly at limit (should succeed)
  SetLength(LFragment, 16384);
  FillChar(LFragment[0], 16384, $FF);
  Check(LSealer.Seal(LFragment, TLS_CONTENT_TYPE_APPLICATION_DATA, LRecord, LError),
    'seal with 16384-byte fragment succeeds');

  LSealer.Clear;
end;

begin
  WriteLn('=== TLS 1.3 RecordSealer/Opener Tests ===');
  WriteLn;

  TestSealOpenRoundTrip_AES128GCM;
  TestSealOpenRoundTrip_ChaCha20;
  TestSequenceIncrement;
  TestSequenceExhaustion;
  TestTamperedCiphertext;
  TestUpdateKey;
  TestEmptyFragment;
  TestAES256GCM;
  TestInvalidIV;
  TestOversizeFragment;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPassCount, GFailCount]));
  if GFailCount > 0 then
    Halt(1);
end.
