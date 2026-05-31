program test_ed25519_final;
{$mode objfpc}{$H+}{$J-}
uses SysUtils, nextpas.core.tls.crypto.ed25519;

function HexToBytes(const AHex: string): TBytes;
var I: Integer;
begin
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do
    Result[I] := StrToInt('$' + Copy(AHex, I * 2 + 1, 2));
end;

var
  LPub, LSig, LMsg: TBytes;
  LPass: Boolean;
begin
  WriteLn('=== Ed25519 Verify Tests ===');

  // Test 1: OpenSSL-generated signature on "hello"
  LPub := HexToBytes('d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a');
  LSig := HexToBytes('511ca497c4d4270b098b1afd5ae4e3b951a5da2c9da6e9c0528f5761883676e7df6e4c0f0e1b5a0a4444f4298b1882dd822fb1133cbd49abfb996c87cd5b8506');
  LMsg := HexToBytes('68656c6c6f');
  LPass := Ed25519Verify(LPub, LMsg, LSig);
  WriteLn('  Test 1 (hello): ', LPass);

  // Test 2: OpenSSL-generated signature on 0x72
  LPub := HexToBytes('3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c');
  LSig := HexToBytes('92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00');
  LMsg := HexToBytes('72');
  LPass := Ed25519Verify(LPub, LMsg, LSig);
  WriteLn('  Test 2 (0x72):  ', LPass);

  // Test 3: Tampered signature (should fail)
  LSig[0] := LSig[0] xor $01;
  LPass := Ed25519Verify(LPub, LMsg, LSig);
  WriteLn('  Test 3 (tamper):', not LPass);

  if Ed25519Verify(
    HexToBytes('d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a'),
    HexToBytes('68656c6c6f'),
    HexToBytes('511ca497c4d4270b098b1afd5ae4e3b951a5da2c9da6e9c0528f5761883676e7df6e4c0f0e1b5a0a4444f4298b1882dd822fb1133cbd49abfb996c87cd5b8506'))
  and Ed25519Verify(
    HexToBytes('3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c'),
    HexToBytes('72'),
    HexToBytes('92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00'))
  then
    WriteLn('ALL PASS')
  else
    WriteLn('SOME FAILED');
end.
