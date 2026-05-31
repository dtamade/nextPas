program test_facade;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.hash.base,
  nextpas.core.hash.intf,
  nextpas.core.hash;

var
  GPass, GFail: Integer;

procedure Check(const AName: string; ACondition: Boolean);
begin
  if ACondition then begin WriteLn('  [PASS] ', AName); Inc(GPass); end
  else begin WriteLn('  [FAIL] ', AName); Inc(GFail); end;
end;

function HexStr(const ABuf; ALen: Integer): string;
var
  I: Integer;
  P: PByte;
begin
  Result := '';
  P := @ABuf;
  for I := 0 to ALen - 1 do
    Result := Result + LowerCase(IntToHex(P[I], 2));
end;

procedure TestNewHasherFactory;
var
  H: IHasher;
  Algo: THashAlgorithm;
begin
  WriteLn('--- NewHasher factory ---');
  for Algo := Low(THashAlgorithm) to High(THashAlgorithm) do
  begin
    H := NewHasher(Algo);
    Check('NewHasher(' + IntToStr(Ord(Algo)) + ') not nil', H <> nil);
  end;

  H := NewHasher(haMD5);
  Check('MD5 DigestSize=16', H.DigestSize = 16);
  Check('MD5 BlockSize=64', H.BlockSize = 64);

  H := NewHasher(haSHA1);
  Check('SHA1 DigestSize=20', H.DigestSize = 20);
  Check('SHA1 BlockSize=64', H.BlockSize = 64);

  H := NewHasher(haSHA256);
  Check('SHA256 DigestSize=32', H.DigestSize = 32);
  Check('SHA256 BlockSize=64', H.BlockSize = 64);

  H := NewHasher(haSHA384);
  Check('SHA384 DigestSize=48', H.DigestSize = 48);
  Check('SHA384 BlockSize=128', H.BlockSize = 128);

  H := NewHasher(haSHA512);
  Check('SHA512 DigestSize=64', H.DigestSize = 64);
  Check('SHA512 BlockSize=128', H.BlockSize = 128);
end;

procedure TestOneShotFunctions;
const
  ABC: array[0..2] of Byte = (Ord('a'), Ord('b'), Ord('c'));
  SHA256_ABC = 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';
  SHA1_ABC = 'a9993e364706816aba3e25717850c26c9cd0d89d';
  MD5_ABC = '900150983cd24fb0d6963f7d28e17f72';
  SHA384_ABC = 'cb00753f45a35e8bb5a03d699ac65007272c32ab0eded1631a8b605a43ff5bed' +
               '8086072ba1e7cc2358baeca134c825a7';
  SHA512_ABC = 'ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a' +
               '2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f';
var
  D256: TSHA256Digest;
  D1: TSHA1Digest;
  D5: TMD5Digest;
  D384: TSHA384Digest;
  D512: TSHA512Digest;
begin
  WriteLn('--- One-shot functions ---');

  D256 := SHA256Of(ABC[0], 3);
  Check('SHA256Of(abc)', HexStr(D256, 32) = SHA256_ABC);

  D1 := SHA1Of(ABC[0], 3);
  Check('SHA1Of(abc)', HexStr(D1, 20) = SHA1_ABC);

  D5 := MD5Of(ABC[0], 3);
  Check('MD5Of(abc)', HexStr(D5, 16) = MD5_ABC);

  D384 := SHA384Of(ABC[0], 3);
  Check('SHA384Of(abc)', HexStr(D384, 48) = SHA384_ABC);

  D512 := SHA512Of(ABC[0], 3);
  Check('SHA512Of(abc)', HexStr(D512, 64) = SHA512_ABC);

  // Empty input
  D256 := SHA256Of(D256, 0);
  Check('SHA256Of(empty) = e3b0c44...',
    Copy(HexStr(D256, 32), 1, 8) = 'e3b0c442');

  D5 := MD5Of(D5, 0);
  Check('MD5Of(empty) = d41d8cd...',
    Copy(HexStr(D5, 16), 1, 8) = 'd41d8cd9');
end;

procedure TestDigestToHex;
const
  DATA: array[0..3] of Byte = ($DE, $AD, $BE, $EF);
begin
  WriteLn('--- DigestToHex ---');
  Check('DigestToHex', DigestToHex(DATA[0], 4) = 'deadbeef');
  Check('DigestToHex empty', DigestToHex(DATA[0], 0) = '');
end;

procedure TestConsistency;
var
  H: IHasher;
  D1, D2: TSHA256Digest;
  ABC: array[0..2] of Byte;
begin
  WriteLn('--- Consistency: one-shot vs streaming ---');
  ABC[0] := Ord('a'); ABC[1] := Ord('b'); ABC[2] := Ord('c');

  D1 := SHA256Of(ABC[0], 3);

  H := NewSHA256;
  H.Write(ABC[0], 3);
  H.Sum(D2, 32);

  Check('SHA256Of == NewSHA256+Write+Sum', CompareMem(@D1, @D2, 32));

  // NewHasher vs direct
  H := NewHasher(haSHA256);
  H.Write(ABC[0], 3);
  H.Sum(D2, 32);
  Check('NewHasher(haSHA256) == SHA256Of', CompareMem(@D1, @D2, 32));
end;

begin
  GPass := 0;
  GFail := 0;
  WriteLn('=== Hash Facade Tests ===');
  WriteLn;

  TestNewHasherFactory;
  TestOneShotFunctions;
  TestDigestToHex;
  TestConsistency;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPass, GFail]));
  if GFail > 0 then Halt(1);
end.
