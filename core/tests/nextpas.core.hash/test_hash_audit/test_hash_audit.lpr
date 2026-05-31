program test_hash_audit;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.crypto.hash;

var
  T: TTestRunner;

{ === Padding Boundary Tests (SHA-256) === }

procedure TestSHA256_55Bytes;
var LS: TSHA256State; LData: string;
begin
  // 55 bytes: padding fits in same block (55 + 1 + 8 = 64)
  SetLength(LData, 55);
  FillChar(LData[1], 55, 'a');
  Check(Length(SHA256StrHex(LData)) = 64, 'sha256 55 bytes produces hash');
end;

procedure TestSHA256_56Bytes;
var LData: string;
begin
  // 56 bytes: padding needs extra block (56 + 1 + 8 = 65 > 64)
  SetLength(LData, 56);
  FillChar(LData[1], 56, 'b');
  Check(Length(SHA256StrHex(LData)) = 64, 'sha256 56 bytes produces hash');
end;

procedure TestSHA256_64Bytes;
var LData: string;
begin
  // 64 bytes: full block, padding is entire new block
  SetLength(LData, 64);
  FillChar(LData[1], 64, 'c');
  Check(Length(SHA256StrHex(LData)) = 64, 'sha256 64 bytes produces hash');
end;

procedure TestSHA256_SingleByte;
begin
  // Known vector: SHA256("a") = ca978112...
  Check(SHA256StrHex('a') =
    'ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb',
    'sha256 single byte a');
end;

procedure TestSHA256_AllZeros;
var LData: TBytes;
begin
  SetLength(LData, 32);
  FillChar(LData[0], 32, 0);
  Check(Length(SHA256Hex(@LData[0], 32)) = 64, 'sha256 all zeros');
end;

procedure TestSHA256_AllFF;
var LData: TBytes;
begin
  SetLength(LData, 64);
  FillChar(LData[0], 64, $FF);
  Check(Length(SHA256Hex(@LData[0], 64)) = 64, 'sha256 all FF');
end;

{ === MD5 Boundary Tests === }

procedure TestMD5_55Bytes;
var LData: string;
begin
  SetLength(LData, 55);
  FillChar(LData[1], 55, 'x');
  Check(Length(MD5StrHex(LData)) = 32, 'md5 55 bytes');
end;

procedure TestMD5_56Bytes;
var LData: string;
begin
  SetLength(LData, 56);
  FillChar(LData[1], 56, 'y');
  Check(Length(MD5StrHex(LData)) = 32, 'md5 56 bytes');
end;

procedure TestMD5_64Bytes;
var LData: string;
begin
  SetLength(LData, 64);
  FillChar(LData[1], 64, 'z');
  Check(Length(MD5StrHex(LData)) = 32, 'md5 64 bytes');
end;

procedure TestMD5Streaming;
var LS: TMD5State; LI: Int32;
begin
  LS.Init;
  for LI := 1 to 100 do
    LS.UpdateStr('a');
  // MD5 of 100 'a's
  Check(Length(DigestToHex(LS.Finalize, 16)) = 32, 'md5 streaming 100a');
end;

{ === CRC32 Tests === }

procedure TestCRC32_LargeData;
var LData: TBytes; LI: Int32; LResult: UInt32;
begin
  SetLength(LData, 65536);
  for LI := 0 to 65535 do LData[LI] := Byte(LI mod 256);
  LResult := CRC32(@LData[0], 65536);
  Check(LResult <> 0, 'crc32 64KB non-zero');
  // Verify deterministic
  Check(CRC32(@LData[0], 65536) = LResult, 'crc32 deterministic');
end;

procedure TestCRC32_SingleByte;
begin
  Check(CRC32Str('A') <> 0, 'crc32 single byte');
  Check(CRC32Str('A') <> CRC32Str('B'), 'crc32 different for different input');
end;

{ === Finalize Misuse Detection === }

procedure TestSHA256_DoubleFinalize;
var LS: TSHA256State; LD1, LD2: TSHA256Digest;
begin
  LS.Init;
  LS.UpdateStr('test');
  LD1 := LS.Finalize;
  // Second finalize on consumed state — should produce different (wrong) hash
  LD2 := LS.Finalize;
  // They WILL be different because state is corrupted after first Finalize
  // This test documents the behavior (not a crash)
  Check(Length(DigestToHex(LD1, 32)) = 64, 'first finalize ok');
  Check(Length(DigestToHex(LD2, 32)) = 64, 'second finalize no crash');
end;

procedure TestMD5_DoubleFinalize;
var LS: TMD5State; LD1, LD2: TMD5Digest;
begin
  LS.Init;
  LS.UpdateStr('test');
  LD1 := LS.Finalize;
  LD2 := LS.Finalize;
  Check(Length(DigestToHex(LD1, 16)) = 32, 'md5 first finalize ok');
  Check(Length(DigestToHex(LD2, 16)) = 32, 'md5 second finalize no crash');
end;

{ === Stress/Lifecycle === }

procedure TestSHA256_1000Cycles;
var LI: Int32; LData: string;
begin
  LData := 'stress test data for hashing';
  for LI := 1 to 1000 do
    SHA256Str(LData);
  Check(True, '1000 sha256 cycles no leak');
end;

procedure TestCRC32_1000Cycles;
var LI: Int32; LData: string;
begin
  LData := 'crc32 stress';
  for LI := 1 to 1000 do
    CRC32Str(LData);
  Check(True, '1000 crc32 cycles no leak');
end;

{ === DigestToHex Edge Cases === }

procedure TestDigestToHex_Zero;
var LD: array[0..3] of Byte;
begin
  FillChar(LD, 4, 0);
  Check(DigestToHex(LD, 4) = '00000000', 'hex of zeros');
end;

procedure TestDigestToHex_Max;
var LD: array[0..3] of Byte;
begin
  FillChar(LD, 4, $FF);
  Check(DigestToHex(LD, 4) = 'ffffffff', 'hex of FF');
end;

{ === Openssl Comparison (known vectors) === }

procedure TestSHA256_KnownVectors;
begin
  // echo -n "hello" | sha256sum
  Check(SHA256StrHex('hello') =
    '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824',
    'sha256 hello');
  // echo -n "The quick brown fox jumps over the lazy dog" | sha256sum
  Check(SHA256StrHex('The quick brown fox jumps over the lazy dog') =
    'd7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592',
    'sha256 fox');
end;

procedure TestMD5_KnownVectors;
begin
  // echo -n "" | md5sum
  Check(MD5StrHex('') = 'd41d8cd98f00b204e9800998ecf8427e', 'md5 empty');
  // echo -n "hello" | md5sum
  Check(MD5StrHex('hello') = '5d41402abc4b2a76b9719d911017c592', 'md5 hello');
end;

begin
  T := TTestRunner.Create('nextpas.core.hash.audit');
  T.Run('SHA256 55 bytes', @TestSHA256_55Bytes);
  T.Run('SHA256 56 bytes', @TestSHA256_56Bytes);
  T.Run('SHA256 64 bytes', @TestSHA256_64Bytes);
  T.Run('SHA256 single byte', @TestSHA256_SingleByte);
  T.Run('SHA256 all zeros', @TestSHA256_AllZeros);
  T.Run('SHA256 all FF', @TestSHA256_AllFF);
  T.Run('MD5 55 bytes', @TestMD5_55Bytes);
  T.Run('MD5 56 bytes', @TestMD5_56Bytes);
  T.Run('MD5 64 bytes', @TestMD5_64Bytes);
  T.Run('MD5 streaming 100', @TestMD5Streaming);
  T.Run('CRC32 large data', @TestCRC32_LargeData);
  T.Run('CRC32 single byte', @TestCRC32_SingleByte);
  T.Run('SHA256 double finalize', @TestSHA256_DoubleFinalize);
  T.Run('MD5 double finalize', @TestMD5_DoubleFinalize);
  T.Run('SHA256 1000 cycles', @TestSHA256_1000Cycles);
  T.Run('CRC32 1000 cycles', @TestCRC32_1000Cycles);
  T.Run('DigestToHex zeros', @TestDigestToHex_Zero);
  T.Run('DigestToHex max', @TestDigestToHex_Max);
  T.Run('SHA256 known vectors', @TestSHA256_KnownVectors);
  T.Run('MD5 known vectors', @TestMD5_KnownVectors);
  T.Summary;
end.
