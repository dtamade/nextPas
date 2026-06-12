program test_hash;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.hash.base,
  nextpas.core.hash;

type
  TArgErrorProc = procedure;

var
  T: TTestRunner;
  GNilByte: PByte = nil;

procedure CheckRaisesArgumentError(AProc: TArgErrorProc; const AMessage: string);
begin
  try
    AProc;
  except
    on E: EArgumentError do
      Exit;
    on E: Exception do
      Fail(AMessage + ': expected EArgumentError, got ' + E.ClassName);
  end;

  Fail(AMessage + ': expected EArgumentError');
end;

function SHA256Hex(const ABuf; ASize: SizeUInt): string;
var
  LDigest: TSHA256Digest;
begin
  LDigest := SHA256Of(ABuf, ASize);
  Result := DigestToHex(LDigest[0], SizeOf(LDigest));
end;

function SHA1Hex(const ABuf; ASize: SizeUInt): string;
var
  LDigest: TSHA1Digest;
begin
  LDigest := SHA1Of(ABuf, ASize);
  Result := DigestToHex(LDigest[0], SizeOf(LDigest));
end;

function MD5Hex(const ABuf; ASize: SizeUInt): string;
var
  LDigest: TMD5Digest;
begin
  LDigest := MD5Of(ABuf, ASize);
  Result := DigestToHex(LDigest[0], SizeOf(LDigest));
end;

procedure TestSHA256Vectors;
const
  ABC: array[0..2] of Byte = (Ord('a'), Ord('b'), Ord('c'));
  LONG_MSG = 'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq';
var
  LLongBytes: TBytes;
begin
  CheckEqual(
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    SHA256Hex(GNilByte^, 0),
    'SHA256 nil+0 = empty');
  CheckEqual(
    'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    SHA256Hex(ABC[0], SizeOf(ABC)),
    'SHA256 abc');

  LLongBytes := BytesOf(LONG_MSG);
  CheckEqual(
    '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
    SHA256Hex(LLongBytes[0], Length(LLongBytes)),
    'SHA256 448-bit');
end;

procedure TestMD5AndSHA1Vectors;
const
  ABC: array[0..2] of Byte = (Ord('a'), Ord('b'), Ord('c'));
  MESSAGE: array[0..13] of Byte =
    (Ord('m'), Ord('e'), Ord('s'), Ord('s'), Ord('a'), Ord('g'), Ord('e'),
     Ord(' '), Ord('d'), Ord('i'), Ord('g'), Ord('e'), Ord('s'), Ord('t'));
begin
  CheckEqual('900150983cd24fb0d6963f7d28e17f72',
    MD5Hex(ABC[0], SizeOf(ABC)), 'MD5 abc');
  CheckEqual('f96b697d7cb7938d525a2f31aaf161d0',
    MD5Hex(MESSAGE[0], SizeOf(MESSAGE)), 'MD5 message digest');
  CheckEqual('a9993e364706816aba3e25717850c26c9cd0d89d',
    SHA1Hex(ABC[0], SizeOf(ABC)), 'SHA1 abc');
end;

procedure TestStreamingHasher;
var
  LH: IHasher;
  LDigest: TSHA256Digest;
  LA, LB, LC: Byte;
begin
  LA := Ord('a');
  LB := Ord('b');
  LC := Ord('c');

  LH := NewSHA256;
  CheckEqual(SizeOf(LA), LH.Write(LA, SizeOf(LA)), 'write a size');
  CheckEqual(SizeOf(LB), LH.Write(LB, SizeOf(LB)), 'write b size');
  CheckEqual(SizeOf(LC), LH.Write(LC, SizeOf(LC)), 'write c size');
  LH.Sum(LDigest[0], SizeOf(LDigest));

  CheckEqual(
    'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    DigestToHex(LDigest[0], SizeOf(LDigest)),
    'streaming SHA256 abc');
end;

procedure CallDigestToHexNilPositive;
begin
  DigestToHex(GNilByte^, 1);
end;

procedure CallSHA256OfNilPositive;
begin
  SHA256Of(GNilByte^, 1);
end;

procedure CallMD5WriteNilPositive;
var
  LH: IHasher;
begin
  LH := NewMD5;
  LH.Write(GNilByte^, 1);
end;

procedure CallSHA1WriteNilPositive;
var
  LH: IHasher;
begin
  LH := NewSHA1;
  LH.Write(GNilByte^, 1);
end;

procedure CallSHA256WriteNilPositive;
var
  LH: IHasher;
begin
  LH := NewSHA256;
  LH.Write(GNilByte^, 1);
end;

procedure CallSHA512WriteNilPositive;
var
  LH: IHasher;
begin
  LH := NewSHA512;
  LH.Write(GNilByte^, 1);
end;

procedure CallMD5SumNilPositive;
var
  LH: IHasher;
begin
  LH := NewMD5;
  LH.Sum(GNilByte^, 1);
end;

procedure CallSHA1SumNilPositive;
var
  LH: IHasher;
begin
  LH := NewSHA1;
  LH.Sum(GNilByte^, 1);
end;

procedure CallSHA256SumNilPositive;
var
  LH: IHasher;
begin
  LH := NewSHA256;
  LH.Sum(GNilByte^, 1);
end;

procedure CallSHA512SumNilPositive;
var
  LH: IHasher;
begin
  LH := NewSHA512;
  LH.Sum(GNilByte^, 1);
end;

procedure CallSHA384SumNilPositive;
var
  LH: IHasher;
begin
  LH := NewSHA384;
  LH.Sum(GNilByte^, 1);
end;

procedure TestNilBufferContract;
var
  LH: IHasher;
  LDigest: TSHA256Digest;
begin
  CheckEqual('', DigestToHex(GNilByte^, 0), 'DigestToHex nil+0');

  LH := NewSHA256;
  CheckEqual(0, LH.Write(GNilByte^, 0), 'Write nil+0');
  LH.Sum(GNilByte^, 0);
  LH.Sum(LDigest[0], SizeOf(LDigest));
  CheckEqual(
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    DigestToHex(LDigest[0], SizeOf(LDigest)),
    'nil+0 calls leave empty digest');

  CheckRaisesArgumentError(@CallDigestToHexNilPositive,
    'DigestToHex nil+positive');
  CheckRaisesArgumentError(@CallSHA256OfNilPositive,
    'SHA256Of nil+positive');
  CheckRaisesArgumentError(@CallMD5WriteNilPositive,
    'MD5 Write nil+positive');
  CheckRaisesArgumentError(@CallSHA1WriteNilPositive,
    'SHA1 Write nil+positive');
  CheckRaisesArgumentError(@CallSHA256WriteNilPositive,
    'SHA256 Write nil+positive');
  CheckRaisesArgumentError(@CallSHA512WriteNilPositive,
    'SHA512 Write nil+positive');
  CheckRaisesArgumentError(@CallMD5SumNilPositive,
    'MD5 Sum nil+positive');
  CheckRaisesArgumentError(@CallSHA1SumNilPositive,
    'SHA1 Sum nil+positive');
  CheckRaisesArgumentError(@CallSHA256SumNilPositive,
    'SHA256 Sum nil+positive');
  CheckRaisesArgumentError(@CallSHA512SumNilPositive,
    'SHA512 Sum nil+positive');
  CheckRaisesArgumentError(@CallSHA384SumNilPositive,
    'SHA384 Sum nil+positive');
end;

begin
  T := TTestRunner.Create('nextpas.core.hash');
  T.Run('SHA256 vectors', @TestSHA256Vectors);
  T.Run('MD5 and SHA1 vectors', @TestMD5AndSHA1Vectors);
  T.Run('streaming hasher', @TestStreamingHasher);
  T.Run('nil buffer contract', @TestNilBufferContract);
  T.Summary;
end.
