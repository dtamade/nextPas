program test_tls13_recordsealer;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tls.tls13.recordsealer,
  nextpas.core.tls.tls13.wire,
  nextpas.core.test, nextpas.core.base, nextpas.core.base.utils, nextpas.core.text;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('tls13.recordsealer');

  LSuite.Test('AES-128-GCM seal/open roundtrip', procedure
  var LSealer: TTLS13RecordSealer; LOpener: TTLS13RecordOpener;
    LKey, LIV, LFragment, LRecord, LOutFragment, LPayload: TBytes;
    LOutContentType: Byte; LError: string;
  begin
    SetLength(LKey, 16); FillChar(LKey[0], 16, $AB);
    SetLength(LIV, 12); FillChar(LIV[0], 12, $CD);
    LSealer.Init(TLS13_CIPHER_AES_128_GCM_SHA256, LKey, LIV);
    LOpener.Init(TLS13_CIPHER_AES_128_GCM_SHA256, LKey, LIV);
    LFragment := TBytes.Create($48, $65, $6C, $6C, $6F);
    CheckTrue(LSealer.Seal(LFragment, TLS_CONTENT_TYPE_APPLICATION_DATA, LRecord, LError));
    CheckTrue(LError = '');
    CheckTrue(Length(LRecord) > 5);
    CheckTrue(LRecord[0] = TLS_CONTENT_TYPE_APPLICATION_DATA);
    CheckTrue((LRecord[1] = $03) and (LRecord[2] = $03));
    SetLength(LPayload, Length(LRecord) - 5);
    Move(LRecord[5], LPayload[0], Length(LPayload));
    CheckTrue(LOpener.Open(LPayload, LOutFragment, LOutContentType, LError));
    CheckTrue(LOutContentType = TLS_CONTENT_TYPE_APPLICATION_DATA);
    CheckEqual(5, Length(LOutFragment));
    CheckTrue(CompareMem(@LOutFragment[0], @LFragment[0], 5));
    LSealer.Clear; LOpener.Clear;
  end);

  LSuite.Test('ChaCha20-Poly1305 seal/open roundtrip', procedure
  var LSealer: TTLS13RecordSealer; LOpener: TTLS13RecordOpener;
    LKey, LIV, LFragment, LRecord, LOutFragment, LPayload: TBytes;
    LOutContentType: Byte; LError: string;
  begin
    SetLength(LKey, 32); FillChar(LKey[0], 32, $11);
    SetLength(LIV, 12); FillChar(LIV[0], 12, $22);
    LSealer.Init(TLS13_CIPHER_CHACHA20_POLY1305_SHA256, LKey, LIV);
    LOpener.Init(TLS13_CIPHER_CHACHA20_POLY1305_SHA256, LKey, LIV);
    LFragment := TBytes.Create($57, $6F, $72, $6C, $64);
    CheckTrue(LSealer.Seal(LFragment, TLS_CONTENT_TYPE_HANDSHAKE, LRecord, LError));
    SetLength(LPayload, Length(LRecord) - 5);
    Move(LRecord[5], LPayload[0], Length(LPayload));
    CheckTrue(LOpener.Open(LPayload, LOutFragment, LOutContentType, LError));
    CheckTrue(LOutContentType = TLS_CONTENT_TYPE_HANDSHAKE);
    CheckTrue(CompareMem(@LOutFragment[0], @LFragment[0], 5));
    LSealer.Clear; LOpener.Clear;
  end);

  LSuite.Test('sequence increment', procedure
  var LSealer: TTLS13RecordSealer; LKey, LIV, LFragment, LRecord: TBytes; LError: string;
  begin
    SetLength(LKey, 16); FillChar(LKey[0], 16, $01);
    SetLength(LIV, 12); FillChar(LIV[0], 12, $02);
    LSealer.Init(TLS13_CIPHER_AES_128_GCM_SHA256, LKey, LIV);
    LFragment := TBytes.Create($AA);
    CheckTrue(LSealer.GetSequence = 0);
    LSealer.Seal(LFragment, TLS_CONTENT_TYPE_APPLICATION_DATA, LRecord, LError);
    CheckTrue(LSealer.GetSequence = 1);
    LSealer.Seal(LFragment, TLS_CONTENT_TYPE_APPLICATION_DATA, LRecord, LError);
    CheckTrue(LSealer.GetSequence = 2);
    LSealer.Clear;
  end);

  LSuite.Test('sequence exhaustion', procedure
  var LSealer: TTLS13RecordSealer; LKey, LIV, LFragment, LRecord: TBytes; LError: string;
  begin
    SetLength(LKey, 16); FillChar(LKey[0], 16, $FF);
    SetLength(LIV, 12); FillChar(LIV[0], 12, $EE);
    LSealer.Init(TLS13_CIPHER_AES_128_GCM_SHA256, LKey, LIV);
    LSealer.FSequence := High(QWord) - 1;
    LFragment := TBytes.Create($BB);
    CheckTrue(not LSealer.IsExhausted);
    CheckTrue(LSealer.Seal(LFragment, TLS_CONTENT_TYPE_APPLICATION_DATA, LRecord, LError));
    CheckTrue(LSealer.Seal(LFragment, TLS_CONTENT_TYPE_APPLICATION_DATA, LRecord, LError));
    CheckTrue(LSealer.IsExhausted);
    CheckTrue(not LSealer.Seal(LFragment, TLS_CONTENT_TYPE_APPLICATION_DATA, LRecord, LError));
    CheckTrue(Pos('exhausted', LError) > 0);
    LSealer.Clear;
  end);

  LSuite.Test('tampered ciphertext rejected', procedure
  var LSealer: TTLS13RecordSealer; LOpener: TTLS13RecordOpener;
    LKey, LIV, LFragment, LRecord, LOutFragment, LPayload: TBytes;
    LOutContentType: Byte; LError: string;
  begin
    SetLength(LKey, 32); FillChar(LKey[0], 32, $33);
    SetLength(LIV, 12); FillChar(LIV[0], 12, $44);
    LSealer.Init(TLS13_CIPHER_CHACHA20_POLY1305_SHA256, LKey, LIV);
    LOpener.Init(TLS13_CIPHER_CHACHA20_POLY1305_SHA256, LKey, LIV);
    LFragment := TBytes.Create($DE, $AD, $BE, $EF);
    LSealer.Seal(LFragment, TLS_CONTENT_TYPE_APPLICATION_DATA, LRecord, LError);
    SetLength(LPayload, Length(LRecord) - 5);
    Move(LRecord[5], LPayload[0], Length(LPayload));
    LPayload[0] := LPayload[0] xor $FF;
    CheckTrue(not LOpener.Open(LPayload, LOutFragment, LOutContentType, LError));
    CheckTrue(LError <> '');
    LSealer.Clear; LOpener.Clear;
  end);

  LSuite.Test('update key resets sequence', procedure
  var LSealer: TTLS13RecordSealer;
    LKey1, LKey2, LIV1, LIV2, LFragment, LRecord: TBytes; LError: string;
  begin
    SetLength(LKey1, 16); FillChar(LKey1[0], 16, $A1);
    SetLength(LIV1, 12); FillChar(LIV1[0], 12, $B1);
    SetLength(LKey2, 16); FillChar(LKey2[0], 16, $A2);
    SetLength(LIV2, 12); FillChar(LIV2[0], 12, $B2);
    LSealer.Init(TLS13_CIPHER_AES_128_GCM_SHA256, LKey1, LIV1);
    LFragment := TBytes.Create($CC);
    LSealer.Seal(LFragment, TLS_CONTENT_TYPE_APPLICATION_DATA, LRecord, LError);
    LSealer.Seal(LFragment, TLS_CONTENT_TYPE_APPLICATION_DATA, LRecord, LError);
    CheckTrue(LSealer.GetSequence = 2);
    LSealer.UpdateKey(LKey2, LIV2);
    CheckTrue(LSealer.GetSequence = 0);
    CheckTrue(not LSealer.IsExhausted);
    LSealer.Clear;
  end);

  LSuite.Test('empty fragment', procedure
  var LSealer: TTLS13RecordSealer; LOpener: TTLS13RecordOpener;
    LKey, LIV, LFragment, LRecord, LOutFragment, LPayload: TBytes;
    LOutContentType: Byte; LError: string;
  begin
    SetLength(LKey, 32); FillChar(LKey[0], 32, $55);
    SetLength(LIV, 12); FillChar(LIV[0], 12, $66);
    LSealer.Init(TLS13_CIPHER_CHACHA20_POLY1305_SHA256, LKey, LIV);
    LOpener.Init(TLS13_CIPHER_CHACHA20_POLY1305_SHA256, LKey, LIV);
    SetLength(LFragment, 0);
    CheckTrue(LSealer.Seal(LFragment, TLS_CONTENT_TYPE_APPLICATION_DATA, LRecord, LError));
    SetLength(LPayload, Length(LRecord) - 5);
    Move(LRecord[5], LPayload[0], Length(LPayload));
    CheckTrue(LOpener.Open(LPayload, LOutFragment, LOutContentType, LError));
    CheckEqual(0, Length(LOutFragment));
    CheckTrue(LOutContentType = TLS_CONTENT_TYPE_APPLICATION_DATA);
    LSealer.Clear; LOpener.Clear;
  end);

  LSuite.Test('AES-256-GCM roundtrip', procedure
  var LSealer: TTLS13RecordSealer; LOpener: TTLS13RecordOpener;
    LKey, LIV, LFragment, LRecord, LOutFragment, LPayload: TBytes;
    LOutContentType: Byte; LError: string;
  begin
    SetLength(LKey, 32); FillChar(LKey[0], 32, $77);
    SetLength(LIV, 12); FillChar(LIV[0], 12, $88);
    LSealer.Init(TLS13_CIPHER_AES_256_GCM_SHA384, LKey, LIV);
    LOpener.Init(TLS13_CIPHER_AES_256_GCM_SHA384, LKey, LIV);
    LFragment := TBytes.Create($01, $02, $03, $04, $05, $06, $07, $08);
    CheckTrue(LSealer.Seal(LFragment, TLS_CONTENT_TYPE_APPLICATION_DATA, LRecord, LError));
    SetLength(LPayload, Length(LRecord) - 5);
    Move(LRecord[5], LPayload[0], Length(LPayload));
    CheckTrue(LOpener.Open(LPayload, LOutFragment, LOutContentType, LError));
    CheckTrue(CompareMem(@LOutFragment[0], @LFragment[0], 8));
    LSealer.Clear; LOpener.Clear;
  end);

  LSuite.Test('invalid IV rejected', procedure
  var LSealer: TTLS13RecordSealer; LKey, LIV, LFragment, LRecord: TBytes; LError: string;
  begin
    SetLength(LKey, 16); FillChar(LKey[0], 16, $AA);
    SetLength(LIV, 11); FillChar(LIV[0], 11, $BB);
    LSealer.Init(TLS13_CIPHER_AES_128_GCM_SHA256, LKey, LIV);
    LFragment := TBytes.Create($01, $02, $03);
    CheckTrue(not LSealer.Seal(LFragment, TLS_CONTENT_TYPE_APPLICATION_DATA, LRecord, LError));
    CheckTrue(Pos('IV', LError) > 0);
    SetLength(LIV, 0);
    LSealer.Init(TLS13_CIPHER_AES_128_GCM_SHA256, LKey, LIV);
    CheckTrue(not LSealer.Seal(LFragment, TLS_CONTENT_TYPE_APPLICATION_DATA, LRecord, LError));
    LSealer.Clear;
  end);

  LSuite.Test('oversize fragment rejected', procedure
  var LSealer: TTLS13RecordSealer; LKey, LIV, LFragment, LRecord: TBytes; LError: string;
  begin
    SetLength(LKey, 16); FillChar(LKey[0], 16, $CC);
    SetLength(LIV, 12); FillChar(LIV[0], 12, $DD);
    LSealer.Init(TLS13_CIPHER_AES_128_GCM_SHA256, LKey, LIV);
    SetLength(LFragment, 16385); FillChar(LFragment[0], 16385, $EE);
    CheckTrue(not LSealer.Seal(LFragment, TLS_CONTENT_TYPE_APPLICATION_DATA, LRecord, LError));
    CheckTrue(Pos('max', LError) > 0);
    SetLength(LFragment, 16384); FillChar(LFragment[0], 16384, $FF);
    CheckTrue(LSealer.Seal(LFragment, TLS_CONTENT_TYPE_APPLICATION_DATA, LRecord, LError));
    LSealer.Clear;
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.tls.tls13.recordsealer');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
