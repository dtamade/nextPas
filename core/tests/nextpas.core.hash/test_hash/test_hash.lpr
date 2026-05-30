program test_hash;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.hash;

var
  T: TTestRunner;

{ SHA-256 test vectors from NIST }

procedure TestSHA256Empty;
begin
  Check(SHA256StrHex('') =
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    'SHA256 empty');
end;

procedure TestSHA256Abc;
begin
  Check(SHA256StrHex('abc') =
    'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    'SHA256 abc');
end;

procedure TestSHA256Long;
begin
  Check(SHA256StrHex('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq') =
    '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
    'SHA256 448-bit');
end;

procedure TestSHA256Streaming;
var
  LS: TSHA256State;
begin
  LS.Init;
  LS.UpdateStr('a');
  LS.UpdateStr('b');
  LS.UpdateStr('c');
  Check(DigestToHex(LS.Finalize, 32) =
    'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    'SHA256 streaming abc');
end;

procedure TestSHA256LargeBlock;
var
  LS: TSHA256State;
  LBuf: string;
  LI: Int32;
begin
  SetLength(LBuf, 1000);
  for LI := 1 to 1000 do LBuf[LI] := 'a';
  LS.Init;
  LS.UpdateStr(LBuf);
  Check(Length(DigestToHex(LS.Finalize, 32)) = 64, 'SHA256 1000 bytes produces 64 hex chars');
end;

{ MD5 test vectors from RFC 1321 }

procedure TestMD5Empty;
begin
  Check(MD5StrHex('') = 'd41d8cd98f00b204e9800998ecf8427e', 'MD5 empty');
end;

procedure TestMD5Abc;
begin
  Check(MD5StrHex('abc') = '900150983cd24fb0d6963f7d28e17f72', 'MD5 abc');
end;

procedure TestMD5Message;
begin
  Check(MD5StrHex('message digest') = 'f96b697d7cb7938d525a2f31aaf161d0', 'MD5 message digest');
end;

procedure TestMD5Alphabet;
begin
  Check(MD5StrHex('abcdefghijklmnopqrstuvwxyz') = 'c3fcd3d76192e4007dfb496cca67e13b', 'MD5 alphabet');
end;

{ CRC32 }

procedure TestCRC32Empty;
begin
  CheckEqual(Int64(0), Int64(CRC32Str('')), 'CRC32 empty');
end;

procedure TestCRC32Known;
begin
  CheckEqual(Int64($CBF43926), Int64(CRC32Str('123456789')), 'CRC32 123456789');
end;

procedure TestCRC32Streaming;
var
  LS: TCRC32State;
begin
  LS.Init;
  LS.UpdateStr('1234');
  LS.UpdateStr('56789');
  CheckEqual(Int64($CBF43926), Int64(LS.Finalize), 'CRC32 streaming');
end;

{ DigestToHex }

procedure TestDigestToHex;
var
  LD: array[0..3] of Byte;
begin
  LD[0] := $DE; LD[1] := $AD; LD[2] := $BE; LD[3] := $EF;
  Check(DigestToHex(LD, 4) = 'deadbeef', 'hex conversion');
end;

begin
  T := TTestRunner.Create('nextpas.core.hash');
  T.Run('SHA256 empty', @TestSHA256Empty);
  T.Run('SHA256 abc', @TestSHA256Abc);
  T.Run('SHA256 long', @TestSHA256Long);
  T.Run('SHA256 streaming', @TestSHA256Streaming);
  T.Run('SHA256 large block', @TestSHA256LargeBlock);
  T.Run('MD5 empty', @TestMD5Empty);
  T.Run('MD5 abc', @TestMD5Abc);
  T.Run('MD5 message digest', @TestMD5Message);
  T.Run('MD5 alphabet', @TestMD5Alphabet);
  T.Run('CRC32 empty', @TestCRC32Empty);
  T.Run('CRC32 known', @TestCRC32Known);
  T.Run('CRC32 streaming', @TestCRC32Streaming);
  T.Run('DigestToHex', @TestDigestToHex);
  T.Summary;
end.
