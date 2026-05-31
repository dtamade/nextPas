program test_tls13_recordcrypto;

{$mode objfpc}{$H+}

uses
  {$IFDEF USE_HEAPTRC}heaptrc,{$ENDIF}
  SysUtils,
  nextpas.core.tls.tls13.recordcrypto;

var
  GPass, GFail: Integer;

procedure Check(const AName: string; ACondition: Boolean);
begin
  if ACondition then
  begin
    WriteLn('  [PASS] ', AName);
    Inc(GPass);
  end
  else
  begin
    WriteLn('  [FAIL] ', AName);
    Inc(GFail);
  end;
end;

function HexToBytes(const AHex: string): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do
    Result[I] := StrToInt('$' + Copy(AHex, I * 2 + 1, 2));
end;

function BytesToHex(const AData: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AData) do
    Result := Result + LowerCase(IntToHex(AData[I], 2));
end;

procedure TestBuildAAD;
var
  LAAD: TBytes;
begin
  // TLS 1.3 record AAD = 17 03 03 <length_hi> <length_lo>
  LAAD := BuildTLS13RecordAAD(256);
  Check('AAD length = 5', Length(LAAD) = 5);
  Check('AAD content type = 0x17', LAAD[0] = $17);
  Check('AAD version = 0x0303', (LAAD[1] = $03) and (LAAD[2] = $03));
  Check('AAD length field = 256', (LAAD[3] = $01) and (LAAD[4] = $00));

  LAAD := BuildTLS13RecordAAD(42);
  Check('AAD length field = 42', (LAAD[3] = $00) and (LAAD[4] = $2A));
end;

procedure TestBuildNonce;
var
  LIV, LNonce: TBytes;
begin
  // nonce = static_iv XOR (0...0 || seq_number_be)
  LIV := HexToBytes('000000000000000000000001');
  LNonce := BuildTLS13RecordNonce(LIV, 0);
  Check('nonce length = 12', Length(LNonce) = 12);
  Check('nonce seq=0: IV unchanged', BytesToHex(LNonce) = '000000000000000000000001');

  LNonce := BuildTLS13RecordNonce(LIV, 1);
  Check('nonce seq=1: XOR with 1', BytesToHex(LNonce) = '000000000000000000000000');

  // More realistic IV
  LIV := HexToBytes('abcdef0123456789abcdef01');
  LNonce := BuildTLS13RecordNonce(LIV, $0102030405060708);
  Check('nonce complex XOR',
    BytesToHex(LNonce) = 'abcdef012247648daecbe809');
end;

procedure TestInnerPlaintext;
var
  LFragment, LInner, LParsedFragment: TBytes;
  LContentType: Byte;
  LOk: Boolean;
begin
  LFragment := HexToBytes('48656c6c6f'); // "Hello"

  // Build: fragment || content_type || zeros (padding)
  LInner := BuildTLS13InnerPlaintext(LFragment, $17); // application_data
  Check('inner plaintext length >= fragment+1', Length(LInner) >= 6);
  Check('inner plaintext starts with fragment',
    (LInner[0] = $48) and (LInner[1] = $65));

  // Parse back
  LOk := TryParseTLS13InnerPlaintext(LInner, LParsedFragment, LContentType);
  Check('parse inner plaintext ok', LOk);
  if LOk then
  begin
    Check('parsed content type = 0x17', LContentType = $17);
    Check('parsed fragment matches', BytesToHex(LParsedFragment) = '48656c6c6f');
  end;
end;

procedure TestInnerPlaintext_Empty;
var
  LFragment, LInner, LParsedFragment: TBytes;
  LContentType: Byte;
  LOk: Boolean;
begin
  SetLength(LFragment, 0);
  LInner := BuildTLS13InnerPlaintext(LFragment, $16); // handshake
  Check('empty fragment inner plaintext', Length(LInner) >= 1);

  LOk := TryParseTLS13InnerPlaintext(LInner, LParsedFragment, LContentType);
  Check('parse empty fragment ok', LOk);
  if LOk then
  begin
    Check('empty fragment content type = 0x16', LContentType = $16);
    Check('empty fragment length = 0', Length(LParsedFragment) = 0);
  end;
end;

procedure TestSequenceIncrement;
var
  LSeq: QWord;
begin
  LSeq := 0;
  Check('seq increment 0→1', IncrementTLS13Sequence(LSeq));
  Check('seq value = 1', LSeq = 1);

  LSeq := $FFFFFFFFFFFFFFFE;
  Check('seq increment near max', IncrementTLS13Sequence(LSeq));
  Check('seq value = max-1', LSeq = $FFFFFFFFFFFFFFFF);

  // At max, should fail (overflow protection)
  Check('seq increment at max fails', not IncrementTLS13Sequence(LSeq));
end;

begin
  GPass := 0;
  GFail := 0;
  WriteLn('=== TLS 1.3 Record Crypto Tests ===');
  WriteLn;

  TestBuildAAD;
  TestBuildNonce;
  TestInnerPlaintext;
  TestInnerPlaintext_Empty;
  TestSequenceIncrement;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPass, GFail]));
  if GFail > 0 then
    Halt(1);
end.
