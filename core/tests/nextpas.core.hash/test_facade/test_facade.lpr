program test_facade;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.system.sysutils,
  nextpas.core.errors,
  nextpas.core.hash,
  nextpas.core.test;

function InvalidHashAlgorithm: THashAlgorithm;
var LValue: Integer;
begin
  LValue := Ord(High(THashAlgorithm)); Inc(LValue);
  Result := THashAlgorithm(LValue);
end;

function HexStr(const ABuf; ALen: Integer): string;
var I: Integer; P: PByte;
begin Result := ''; P := @ABuf;
  for I := 0 to ALen - 1 do Result := Result + LowerCase(IntToHex(P[I], 2));
end;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('hash.facade');

  LSuite.Test('NewHasher factory', procedure
  var H: IHasher; Algo: THashAlgorithm;
  begin
    for Algo := Low(THashAlgorithm) to High(THashAlgorithm) do begin
      H := NewHasher(Algo);
      CheckTrue(H <> nil);
    end;
    H := NewHasher(haMD5); CheckEqual(16, H.DigestSize); CheckEqual(64, H.BlockSize);
    H := NewHasher(haSHA1); CheckEqual(20, H.DigestSize); CheckEqual(64, H.BlockSize);
    H := NewHasher(haSHA256); CheckEqual(32, H.DigestSize); CheckEqual(64, H.BlockSize);
    H := NewHasher(haSHA384); CheckEqual(48, H.DigestSize); CheckEqual(128, H.BlockSize);
    H := NewHasher(haSHA512); CheckEqual(64, H.DigestSize); CheckEqual(128, H.BlockSize);
    H := NewBLAKE2b256; CheckEqual(32, H.DigestSize); CheckEqual(128, H.BlockSize);
  end);

  LSuite.Test('invalid algorithm rejected', procedure
  var LRaised: Boolean;
  begin
    LRaised := False;
    try NewHasher(InvalidHashAlgorithm); except on E: EArgumentError do LRaised := True; end;
    CheckTrue(LRaised);
    LRaised := False;
    try GetDigestSize(InvalidHashAlgorithm); except on E: EArgumentError do LRaised := True; end;
    CheckTrue(LRaised);
    LRaised := False;
    try GetBlockSize(InvalidHashAlgorithm); except on E: EArgumentError do LRaised := True; end;
    CheckTrue(LRaised);
  end);

  LSuite.Test('one-shot functions', procedure
  const ABC: array[0..2] of Byte = (Ord('a'), Ord('b'), Ord('c'));
  var D256: TSHA256Digest; D1: TSHA1Digest; D5: TMD5Digest; D384: TSHA384Digest; D512: TSHA512Digest;
      DB2: TBLAKE2b256Digest;
  begin
    D256 := SHA256Of(ABC[0], 3);
    CheckEqual('ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad', HexStr(D256, 32));
    D1 := SHA1Of(ABC[0], 3);
    CheckEqual('a9993e364706816aba3e25717850c26c9cd0d89d', HexStr(D1, 20));
    D5 := MD5Of(ABC[0], 3);
    CheckEqual('900150983cd24fb0d6963f7d28e17f72', HexStr(D5, 16));
    D384 := SHA384Of(ABC[0], 3);
    CheckEqual('cb00753f45a35e8bb5a03d699ac65007272c32ab0eded1631a8b605a43ff5bed8086072ba1e7cc2358baeca134c825a7', HexStr(D384, 48));
    D512 := SHA512Of(ABC[0], 3);
    CheckEqual('ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f', HexStr(D512, 64));
    D256 := SHA256Of(D256, 0);
    CheckEqual('e3b0c442', Copy(HexStr(D256, 32), 1, 8));
    D5 := MD5Of(D5, 0);
    CheckEqual('d41d8cd9', Copy(HexStr(D5, 16), 1, 8));
    DB2 := BLAKE2b256Of(ABC[0], 3);
    CheckEqual('bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319',
      HexStr(DB2, 32));
  end);

  LSuite.Test('DigestToHex', procedure
  const DATA: array[0..3] of Byte = ($DE, $AD, $BE, $EF);
  begin
    CheckEqual('deadbeef', DigestToHex(DATA[0], 4));
    CheckEqual('', DigestToHex(DATA[0], 0));
  end);

  LSuite.Test('WyHash facade', procedure
  var H64: UInt64; H32: UInt32; LRaised: Boolean;
  begin
    H64 := WyHash(PAnsiChar('abc'), 3, 0);
    CheckTrue(H64 = UInt64($B4808DF22D44FFCF));
    H64 := WyHashStr('abc', 0);
    CheckTrue(H64 = UInt64($B4808DF22D44FFCF));
    H32 := WyHash32(PAnsiChar('test'), 4, 0);
    H64 := WyHash(PAnsiChar('test'), 4, 0);
    CheckTrue(H32 = UInt32(H64 xor (H64 shr 32)));
    LRaised := False;
    try WyHash(nil, 1, 0); except on E: EArgumentError do LRaised := True; end;
    CheckTrue(LRaised);
  end);

  LSuite.Test('Sum output-size contract', procedure
  const SENTINEL = $A5;
  var H: IHasher; Full: TBytes; Buf: array[0..127] of Byte; J: Integer; Ok: Boolean;
    LData: array[0..2] of Byte;
  begin
    LData[0] := Ord('a'); LData[1] := Ord('b'); LData[2] := Ord('c');
    H := NewHasher(haMD5);
    H.Write(LData[0], 3);
    Full := H.SumBytes;
    FillChar(Buf[0], SizeOf(Buf), SENTINEL);
    H.Sum(Buf[0], 0);
    Ok := True; for J := 0 to High(Buf) do Ok := Ok and (Buf[J] = SENTINEL);
    CheckTrue(Ok);
    H := NewHasher(haSHA256);
    H.Write(LData[0], 3);
    Full := H.SumBytes;
    FillChar(Buf[0], SizeOf(Buf), SENTINEL);
    H.Sum(Buf[0], 0);
    Ok := True; for J := 0 to High(Buf) do Ok := Ok and (Buf[J] = SENTINEL);
    CheckTrue(Ok);
  end);

  LSuite.Test('consistency one-shot vs streaming', procedure
  var H: IHasher; D1, D2: TSHA256Digest; ABC: array[0..2] of Byte;
  begin
    ABC[0] := Ord('a'); ABC[1] := Ord('b'); ABC[2] := Ord('c');
    D1 := SHA256Of(ABC[0], 3);
    H := NewSHA256; H.Write(ABC[0], 3); H.Sum(D2, 32);
    CheckTrue(CompareMem(@D1, @D2, 32));
    H := NewHasher(haSHA256); H.Write(ABC[0], 3); H.Sum(D2, 32);
    CheckTrue(CompareMem(@D1, @D2, 32));
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.hash.facade');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
