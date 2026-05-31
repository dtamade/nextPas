program test_tls13_recordcrypto;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.tls13.wire,
  nextpas.core.tls.tls13.recordcrypto;

procedure Fail(const AMessage: string);
begin
  WriteLn('❌ ', AMessage);
  Halt(1);
end;

procedure AssertTrue(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    Fail(AMessage);
end;

procedure AssertEqualsByte(AExpected, AActual: Byte; const AMessage: string);
begin
  if AExpected <> AActual then
    Fail(Format('%s (expected=%d actual=%d)', [AMessage, AExpected, AActual]));
end;

function BytesEqual(const ALeft, ARight: TBytes): Boolean;
var
  I: Integer;
begin
  if Length(ALeft) <> Length(ARight) then
    Exit(False);

  Result := True;
  for I := 0 to High(ALeft) do
    if ALeft[I] <> ARight[I] then
      Exit(False);
end;

procedure AssertBytesEqual(const AExpected, AActual: TBytes; const AMessage: string);
begin
  if not BytesEqual(AExpected, AActual) then
    Fail(AMessage);
end;

procedure TestBuildAAD;
var
  LAAD: TBytes;
begin
  LAAD := BuildTLS13RecordAAD($1234);
  AssertTrue(Length(LAAD) = 5, 'AAD length should be 5');
  AssertEqualsByte(TLS_CONTENT_TYPE_APPLICATION_DATA, LAAD[0], 'AAD content type mismatch');
  AssertEqualsByte($03, LAAD[1], 'AAD legacy_version high mismatch');
  AssertEqualsByte($03, LAAD[2], 'AAD legacy_version low mismatch');
  AssertEqualsByte($12, LAAD[3], 'AAD length high mismatch');
  AssertEqualsByte($34, LAAD[4], 'AAD length low mismatch');
end;

procedure TestBuildNonce;
var
  LStaticIV: TBytes;
  LNonce: TBytes;
  LExpected: TBytes;
begin
  SetLength(LStaticIV, 12);
  LStaticIV[0] := $00;
  LStaticIV[1] := $01;
  LStaticIV[2] := $02;
  LStaticIV[3] := $03;
  LStaticIV[4] := $04;
  LStaticIV[5] := $05;
  LStaticIV[6] := $06;
  LStaticIV[7] := $07;
  LStaticIV[8] := $08;
  LStaticIV[9] := $09;
  LStaticIV[10] := $0A;
  LStaticIV[11] := $0B;

  LExpected := Copy(LStaticIV, 0, Length(LStaticIV));
  LExpected[11] := LExpected[11] xor $01;

  LNonce := BuildTLS13RecordNonce(LStaticIV, 1);
  AssertBytesEqual(LExpected, LNonce, 'Nonce(seq=1) mismatch');

  LNonce := BuildTLS13RecordNonce(LStaticIV, $0102030405060708);
  AssertTrue(Length(LNonce) = 12, 'Nonce length should be 12');
  AssertTrue(not BytesEqual(LNonce, LStaticIV), 'Nonce should differ from static IV when seq != 0');
end;

procedure TestInnerPlaintextBuildParse;
var
  LFragment: TBytes;
  LInner: TBytes;
  LParsedFragment: TBytes;
  LContentType: Byte;
  LPadded: TBytes;
begin
  SetLength(LFragment, 3);
  LFragment[0] := 1;
  LFragment[1] := 2;
  LFragment[2] := 3;

  LInner := BuildTLS13InnerPlaintext(LFragment, TLS_CONTENT_TYPE_HANDSHAKE);
  AssertTrue(Length(LInner) = 4, 'Inner plaintext length mismatch');
  AssertEqualsByte(1, LInner[0], 'Inner payload byte0 mismatch');
  AssertEqualsByte(2, LInner[1], 'Inner payload byte1 mismatch');
  AssertEqualsByte(3, LInner[2], 'Inner payload byte2 mismatch');
  AssertEqualsByte(TLS_CONTENT_TYPE_HANDSHAKE, LInner[3], 'Inner content type mismatch');

  AssertTrue(TryParseTLS13InnerPlaintext(LInner, LParsedFragment, LContentType), 'Inner parse should succeed');
  AssertBytesEqual(LFragment, LParsedFragment, 'Parsed fragment mismatch');
  AssertEqualsByte(TLS_CONTENT_TYPE_HANDSHAKE, LContentType, 'Parsed content type mismatch');

  SetLength(LPadded, Length(LInner) + 2);
  Move(LInner[0], LPadded[0], Length(LInner));
  LPadded[Length(LInner)] := 0;
  LPadded[Length(LInner) + 1] := 0;
  AssertTrue(TryParseTLS13InnerPlaintext(LPadded, LParsedFragment, LContentType), 'Padded inner parse should succeed');
  AssertBytesEqual(LFragment, LParsedFragment, 'Parsed padded fragment mismatch');
  AssertEqualsByte(TLS_CONTENT_TYPE_HANDSHAKE, LContentType, 'Parsed padded content type mismatch');
end;

procedure TestInnerParseInvalid;
var
  LPlain: TBytes;
  LFragment: TBytes;
  LType: Byte;
begin
  SetLength(LPlain, 3);
  LPlain[0] := 0;
  LPlain[1] := 0;
  LPlain[2] := 0;

  AssertTrue(not TryParseTLS13InnerPlaintext(LPlain, LFragment, LType), 'All-zero plaintext should fail parse');
end;

procedure TestSequenceIncrement;
var
  LSeq: QWord;
begin
  LSeq := 0;
  AssertTrue(IncrementTLS13Sequence(LSeq), 'Increment from 0 should succeed');
  AssertTrue(LSeq = 1, 'Sequence should be 1');

  LSeq := High(QWord);
  AssertTrue(not IncrementTLS13Sequence(LSeq), 'Increment at max should fail');
  AssertTrue(LSeq = High(QWord), 'Sequence should stay max on overflow');
end;

begin
  WriteLn('Testing TLS 1.3 record crypto helpers...');

  TestBuildAAD;
  TestBuildNonce;
  TestInnerPlaintextBuildParse;
  TestInnerParseInvalid;
  TestSequenceIncrement;

  WriteLn('✅ TLS 1.3 record crypto checks passed');
end.
