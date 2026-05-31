program test_crypto_vectors;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.crypto.x25519,
  nextpas.core.tls.crypto.aesgcm,
  nextpas.core.tls.crypto.hash;

var
  GPass: Integer = 0;
  GFail: Integer = 0;

procedure Check(ACondition: Boolean; const AMsg: string);
begin
  if ACondition then Inc(GPass)
  else begin Inc(GFail); WriteLn('  FAIL: ', AMsg); end;
end;

function HexToBytes(const AHex: string): TBytes;
var I: Integer;
begin
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to Length(Result) - 1 do
    Result[I] := StrToInt('$' + Copy(AHex, I * 2 + 1, 2));
end;

function BytesToHex(const AData: TBytes): string;
var I: Integer;
begin
  Result := '';
  for I := 0 to Length(AData) - 1 do
    Result := Result + LowerCase(IntToHex(AData[I], 2));
end;

procedure TestX25519RFC7748;
var
  LAlicePriv, LAlicePub, LBobPriv, LBobPub, LAliceShared, LBobShared: TBytes;
begin
  WriteLn('Test: X25519 RFC 7748 §6.1');
  LAlicePriv := HexToBytes('77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a');
  LBobPriv := HexToBytes('5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb');
  LAlicePub := X25519PublicKeyFromPrivate(LAlicePriv);
  LBobPub := X25519PublicKeyFromPrivate(LBobPriv);
  Check(BytesToHex(LAlicePub) = '8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a', 'Alice pub');
  Check(BytesToHex(LBobPub) = 'de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f', 'Bob pub');
  LAliceShared := X25519ComputeSharedSecret(LAlicePriv, LBobPub);
  LBobShared := X25519ComputeSharedSecret(LBobPriv, LAlicePub);
  Check(BytesToHex(LAliceShared) = '4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742', 'Shared secret');
  Check(CompareMem(@LAliceShared[0], @LBobShared[0], 32), 'Both sides agree');
end;

procedure TestX25519Iteration;
var LPriv, LPub: TBytes;
begin
  WriteLn('Test: X25519 RFC 7748 §5.2');
  LPriv := HexToBytes('a546e36bf0527c9d3b16154b82465edd62144c0ac1fc5a18506a2244ba449ac4');
  LPub := X25519PublicKeyFromPrivate(LPriv);
  Check(Length(LPub) = 32, 'Public key is 32 bytes');
end;

procedure TestAESGCMNIST;
var
  LKey, LIV, LPlain, LAAD, LCipher, LTag: TBytes;
begin
  WriteLn('Test: AES-128-GCM NIST SP 800-38D Test Case 3');
  LKey := HexToBytes('feffe9928665731c6d6a8f9467308308');
  LIV := HexToBytes('cafebabefacedbaddecaf888');
  LPlain := HexToBytes('d9313225f88406e5a55909c5aff5269a86a7a9531534f7da2e4c303d8a318a721c3c0c95956809532fcf0e2449a6b525b16aedf5aa0de657ba637b391aafd255');
  SetLength(LAAD, 0);
  PurePascalAESGCMEncrypt(LKey, LIV, LPlain, LAAD, LCipher, LTag);
  Check(BytesToHex(LCipher) = '42831ec2217774244b7221b784d0d49ce3aa212f2c02a4e035c17e2329aca12e21d514b25466931c7d8f6a5aac84aa051ba30b396a0aac973d58e091473f5985', 'Ciphertext');
  Check(BytesToHex(LTag) = '4d5c2af327cd64a62cf35abd2ba6fab4', 'Tag');
end;

procedure TestAESGCMEmpty;
var
  LKey, LIV, LAAD, LEmpty, LCipher, LTag: TBytes;
begin
  WriteLn('Test: AES-128-GCM NIST Test Case 1 (empty)');
  LKey := HexToBytes('00000000000000000000000000000000');
  LIV := HexToBytes('000000000000000000000000');
  SetLength(LAAD, 0);
  SetLength(LEmpty, 0);
  PurePascalAESGCMEncrypt(LKey, LIV, LEmpty, LAAD, LCipher, LTag);
  Check(Length(LCipher) = 0, 'Empty ciphertext');
  Check(BytesToHex(LTag) = '58e2fccefa7e3061367f1d57a4e7455a', 'Tag');
end;

procedure TestSHA256;
var LHash: TBytes;
begin
  WriteLn('Test: SHA-256 FIPS 180-4');
  LHash := SHA256(TEncoding.ASCII.GetBytes('abc'));
  Check(BytesToHex(LHash) = 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad', 'SHA-256(abc)');
end;

procedure TestSHA384;
var LHash: TBytes;
begin
  WriteLn('Test: SHA-384 FIPS 180-4');
  LHash := SHA384(TEncoding.ASCII.GetBytes('abc'));
  Check(BytesToHex(LHash) = 'cb00753f45a35e8bb5a03d699ac65007272c32ab0eded1631a8b605a43ff5bed8086072ba1e7cc2358baeca134c825a7', 'SHA-384(abc)');
end;

begin
  WriteLn('=== Crypto Standard Vector Tests ===');
  WriteLn('');
  TestX25519RFC7748;
  TestX25519Iteration;
  TestAESGCMNIST;
  TestAESGCMEmpty;
  TestSHA256;
  TestSHA384;
  WriteLn('');
  WriteLn(Format('Results: %d passed, %d failed', [GPass, GFail]));
  if GFail > 0 then Halt(1);
end.
