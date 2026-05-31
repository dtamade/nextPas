program test_tls12_fuzzing;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.tls12.io,
  nextpas.core.tls.tls12.wire,
  nextpas.core.tls.tls12.parser,
  nextpas.core.tls.tls12.recordcrypto,
  nextpas.core.tls.tls12.chacha20record,
  nextpas.core.tls.crypto.tls12record;

var
  GPass: Integer = 0;
  GFail: Integer = 0;

procedure Check(ACondition: Boolean; const AMsg: string);
begin
  if ACondition then Inc(GPass)
  else begin Inc(GFail); WriteLn('  FAIL: ', AMsg); end;
end;

procedure TestHandshakeReaderEmptyStream;
var
  LStream: TMemoryStream;
  LReader: TTLS12HandshakeReader;
  LType: Byte;
  LBody, LFull: TBytes;
  LAlert: string;
begin
  WriteLn('Test: HandshakeReader on empty stream');
  LStream := TMemoryStream.Create;
  try
    LReader := TTLS12HandshakeReader.Create(LStream);
    try
      Check(not LReader.ReadMessage(LType, LBody, LFull, LAlert), 'Empty stream returns false');
    finally
      LReader.Free;
    end;
  finally
    LStream.Free;
  end;
end;

procedure TestHandshakeReaderTruncatedRecord;
var
  LStream: TMemoryStream;
  LReader: TTLS12HandshakeReader;
  LType: Byte;
  LBody, LFull: TBytes;
  LAlert: string;
  LData: TBytes;
begin
  WriteLn('Test: HandshakeReader with truncated record header');
  LStream := TMemoryStream.Create;
  try
    SetLength(LData, 3); // Only 3 bytes, need 5 for header
    LData[0] := 22; LData[1] := 3; LData[2] := 3;
    LStream.WriteBuffer(LData[0], 3);
    LStream.Position := 0;

    LReader := TTLS12HandshakeReader.Create(LStream);
    try
      Check(not LReader.ReadMessage(LType, LBody, LFull, LAlert), 'Truncated header returns false');
    finally
      LReader.Free;
    end;
  finally
    LStream.Free;
  end;
end;

procedure TestHandshakeReaderAlertRecord;
var
  LStream: TMemoryStream;
  LReader: TTLS12HandshakeReader;
  LType: Byte;
  LBody, LFull: TBytes;
  LAlert: string;
  LData: TBytes;
begin
  WriteLn('Test: HandshakeReader receives alert');
  LStream := TMemoryStream.Create;
  try
    // Alert record: type=21, version=3.3, length=2, level=2, desc=40
    SetLength(LData, 7);
    LData[0] := 21; LData[1] := 3; LData[2] := 3; LData[3] := 0; LData[4] := 2;
    LData[5] := 2; LData[6] := 40; // fatal handshake_failure
    LStream.WriteBuffer(LData[0], 7);
    LStream.Position := 0;

    LReader := TTLS12HandshakeReader.Create(LStream);
    try
      Check(not LReader.ReadMessage(LType, LBody, LFull, LAlert), 'Alert returns false');
      Check(Pos('alert', LAlert) > 0, 'Alert description present');
    finally
      LReader.Free;
    end;
  finally
    LStream.Free;
  end;
end;

procedure TestHandshakeReaderFragmentedMessage;
var
  LStream: TMemoryStream;
  LReader: TTLS12HandshakeReader;
  LType: Byte;
  LBody, LFull: TBytes;
  LAlert: string;
  LRec1, LRec2: TBytes;
begin
  WriteLn('Test: HandshakeReader reassembles fragmented message');
  LStream := TMemoryStream.Create;
  try
    // Handshake message: type=2 (ServerHello), length=10, body=10 bytes
    // Split across 2 records: first 6 bytes, then 8 bytes

    // Record 1: handshake, 6 bytes (header 4 + 2 body bytes)
    SetLength(LRec1, 5 + 6);
    LRec1[0] := 22; LRec1[1] := 3; LRec1[2] := 3; LRec1[3] := 0; LRec1[4] := 6;
    LRec1[5] := 2; // handshake type = ServerHello
    LRec1[6] := 0; LRec1[7] := 0; LRec1[8] := 10; // body length = 10
    LRec1[9] := $AA; LRec1[10] := $BB; // first 2 bytes of body

    // Record 2: handshake, 8 bytes (remaining body)
    SetLength(LRec2, 5 + 8);
    LRec2[0] := 22; LRec2[1] := 3; LRec2[2] := 3; LRec2[3] := 0; LRec2[4] := 8;
    FillChar(LRec2[5], 8, $CC); // remaining 8 bytes

    LStream.WriteBuffer(LRec1[0], Length(LRec1));
    LStream.WriteBuffer(LRec2[0], Length(LRec2));
    LStream.Position := 0;

    LReader := TTLS12HandshakeReader.Create(LStream);
    try
      Check(LReader.ReadMessage(LType, LBody, LFull, LAlert), 'Fragmented message reassembled');
      Check(LType = 2, 'Type = ServerHello');
      Check(Length(LBody) = 10, 'Body = 10 bytes');
      Check(LBody[0] = $AA, 'First byte correct');
      Check(LBody[1] = $BB, 'Second byte correct');
      Check(LBody[2] = $CC, 'Third byte from second record');
    finally
      LReader.Free;
    end;
  finally
    LStream.Free;
  end;
end;

procedure TestHandshakeReaderCoalescedMessages;
var
  LStream: TMemoryStream;
  LReader: TTLS12HandshakeReader;
  LType: Byte;
  LBody, LFull: TBytes;
  LAlert: string;
  LRec: TBytes;
begin
  WriteLn('Test: HandshakeReader splits coalesced messages');
  LStream := TMemoryStream.Create;
  try
    // One record containing 2 handshake messages:
    // Message 1: type=11 (Certificate), length=2, body=[AA,BB]
    // Message 2: type=14 (ServerHelloDone), length=0
    SetLength(LRec, 5 + 6 + 4);
    LRec[0] := 22; LRec[1] := 3; LRec[2] := 3; LRec[3] := 0; LRec[4] := 10; // record: 10 bytes
    // Message 1
    LRec[5] := 11; LRec[6] := 0; LRec[7] := 0; LRec[8] := 2; LRec[9] := $AA; LRec[10] := $BB;
    // Message 2
    LRec[11] := 14; LRec[12] := 0; LRec[13] := 0; LRec[14] := 0;

    LStream.WriteBuffer(LRec[0], Length(LRec));
    LStream.Position := 0;

    LReader := TTLS12HandshakeReader.Create(LStream);
    try
      Check(LReader.ReadMessage(LType, LBody, LFull, LAlert), 'First message read');
      Check(LType = 11, 'First = Certificate');
      Check(Length(LBody) = 2, 'First body = 2');

      Check(LReader.ReadMessage(LType, LBody, LFull, LAlert), 'Second message read');
      Check(LType = 14, 'Second = ServerHelloDone');
      Check(Length(LBody) = 0, 'Second body = 0');
    finally
      LReader.Free;
    end;
  finally
    LStream.Free;
  end;
end;

procedure TestHandshakeReaderOversizedLength;
var
  LStream: TMemoryStream;
  LReader: TTLS12HandshakeReader;
  LType: Byte;
  LBody, LFull: TBytes;
  LAlert: string;
  LRec: TBytes;
begin
  WriteLn('Test: HandshakeReader with message claiming huge length');
  LStream := TMemoryStream.Create;
  try
    // Record with handshake header claiming 1MB body but only 4 bytes in record
    SetLength(LRec, 5 + 4);
    LRec[0] := 22; LRec[1] := 3; LRec[2] := 3; LRec[3] := 0; LRec[4] := 4;
    LRec[5] := 2; LRec[6] := $0F; LRec[7] := $FF; LRec[8] := $FF; // claims 1048575 bytes

    LStream.WriteBuffer(LRec[0], Length(LRec));
    LStream.Position := 0;

    LReader := TTLS12HandshakeReader.Create(LStream);
    try
      // Should not crash, just return false (can't read enough data)
      Check(not LReader.ReadMessage(LType, LBody, LFull, LAlert), 'Oversized message handled gracefully');
    finally
      LReader.Free;
    end;
  finally
    LStream.Free;
  end;
end;

procedure TestGCMReplayProtection;
var
  LKey, LIV, LPlain, LEnc, LDec: TBytes;
  LOk: Boolean;
  LErr: string;
begin
  WriteLn('Test: GCM replay protection (same ciphertext, different seq)');
  SetLength(LKey, 16); FillChar(LKey[0], 16, $11);
  SetLength(LIV, 4); FillChar(LIV[0], 4, $22);
  LPlain := TEncoding.ASCII.GetBytes('replay test');

  TLS12GCMEncryptRecord(LKey, LIV, 7, 23, LPlain, LEnc, LErr);

  // Decrypt with correct seq
  LOk := TLS12GCMDecryptRecord(LKey, LIV, 7, 23, LEnc, LDec, LErr);
  Check(LOk, 'Correct seq succeeds');

  // Replay with seq+1
  LOk := TLS12GCMDecryptRecord(LKey, LIV, 8, 23, LEnc, LDec, LErr);
  Check(not LOk, 'Replay with wrong seq fails');

  // Replay with different content type
  LOk := TLS12GCMDecryptRecord(LKey, LIV, 7, 22, LEnc, LDec, LErr);
  Check(not LOk, 'Wrong content type fails');
end;

procedure TestChaCha20ReplayProtection;
var
  LKey, LIV, LPlain, LEnc, LDec: TBytes;
  LOk: Boolean;
  LErr: string;
begin
  WriteLn('Test: ChaCha20 replay protection');
  SetLength(LKey, 32); FillChar(LKey[0], 32, $33);
  SetLength(LIV, 12); FillChar(LIV[0], 12, $44);
  LPlain := TEncoding.ASCII.GetBytes('chacha replay');

  TLS12ChaCha20Poly1305EncryptRecord(LKey, LIV, 3, 23, LPlain, LEnc, LErr);

  LOk := TLS12ChaCha20Poly1305DecryptRecord(LKey, LIV, 3, 23, LEnc, LDec, LErr);
  Check(LOk, 'Correct seq succeeds');

  LOk := TLS12ChaCha20Poly1305DecryptRecord(LKey, LIV, 4, 23, LEnc, LDec, LErr);
  Check(not LOk, 'Wrong seq fails');
end;

procedure TestCBCPaddingOracle;
var
  LKey, LMACKey, LPlain, LEnc, LDec: TBytes;
  LOk: Boolean;
  LErr: string;
  I: Integer;
begin
  WriteLn('Test: CBC padding oracle resistance (uniform error)');
  SetLength(LKey, 16); FillChar(LKey[0], 16, $55);
  SetLength(LMACKey, 32); FillChar(LMACKey[0], 32, $66);
  LPlain := TEncoding.ASCII.GetBytes('padding oracle test data here!!');

  TLS12CBCEncrypt_SHA256(LKey, LMACKey, 0, 23, LPlain, LEnc, LErr);

  // Corrupt various positions — all should give same error
  for I := 0 to 4 do
  begin
    LEnc[Length(LEnc) - 1 - I * 3] := LEnc[Length(LEnc) - 1 - I * 3] xor $FF;
    LOk := TLS12CBCDecrypt_SHA256(LKey, LMACKey, 0, 23, LEnc, LDec, LErr);
    Check(not LOk, Format('Corruption at -%d fails', [1 + I * 3]));
    Check(LErr = 'bad_record_mac', Format('Uniform error at -%d', [1 + I * 3]));
    LEnc[Length(LEnc) - 1 - I * 3] := LEnc[Length(LEnc) - 1 - I * 3] xor $FF; // restore
  end;
end;

procedure TestZeroLengthPayloads;
var
  LKey, LIV, LEnc, LDec: TBytes;
  LOk: Boolean;
  LErr: string;
  LEmpty: TBytes;
begin
  WriteLn('Test: Zero-length payload handling');
  SetLength(LKey, 16); FillChar(LKey[0], 16, $77);
  SetLength(LIV, 4); FillChar(LIV[0], 4, $88);
  SetLength(LEmpty, 0);

  LOk := TLS12GCMEncryptRecord(LKey, LIV, 0, 23, LEmpty, LEnc, LErr);
  Check(LOk, 'GCM encrypt empty succeeds');
  Check(Length(LEnc) = 8 + 16, 'GCM empty = nonce + tag only');

  LOk := TLS12GCMDecryptRecord(LKey, LIV, 0, 23, LEnc, LDec, LErr);
  Check(LOk, 'GCM decrypt empty succeeds');
  Check(Length(LDec) = 0, 'Decrypted empty = 0 bytes');
end;

begin
  WriteLn('=== TLS 1.2 Fuzzing-Style Tests ===');
  WriteLn('');

  TestHandshakeReaderEmptyStream;
  TestHandshakeReaderTruncatedRecord;
  TestHandshakeReaderAlertRecord;
  TestHandshakeReaderFragmentedMessage;
  TestHandshakeReaderCoalescedMessages;
  TestHandshakeReaderOversizedLength;
  TestGCMReplayProtection;
  TestChaCha20ReplayProtection;
  TestCBCPaddingOracle;
  TestZeroLengthPayloads;

  WriteLn('');
  WriteLn(Format('Results: %d passed, %d failed', [GPass, GFail]));
  if GFail > 0 then Halt(1);
end.
