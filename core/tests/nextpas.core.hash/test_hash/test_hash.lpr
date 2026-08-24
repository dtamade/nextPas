program test_hash;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.system.sysutils,
  nextpas.core.errors,
  nextpas.core.test,
  nextpas.core.hash.base,
  nextpas.core.hash;

type
  TArgErrorProc = procedure;

var
  T: TTestSuite;
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

function SHA224Hex(const ABuf; ASize: SizeUInt): string;
var
  LDigest: TSHA224Digest;
begin
  LDigest := SHA224Of(ABuf, ASize);
  Result := DigestToHex(LDigest[0], SizeOf(LDigest));
end;

procedure TestSHA224Vectors;
const
  ABC: array[0..2] of Byte = (Ord('a'), Ord('b'), Ord('c'));
begin
  CheckEqual(
    'd14a028c2a3a2bc9476102bb288234c415a2b01f828ea62ac5b3e42f',
    SHA224Hex(GNilByte^, 0),
    'SHA224 empty');
  CheckEqual(
    '23097d223405d8228642a477bda255b32aadbce4bda0b3f7e36c9da7',
    SHA224Hex(ABC[0], SizeOf(ABC)),
    'SHA224 abc');
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

function BLAKE2b256Hex(const ABuf; ASize: SizeUInt): string;
var
  LDigest: TBLAKE2b256Digest;
begin
  LDigest := BLAKE2b256Of(ABuf, ASize);
  Result := DigestToHex(LDigest[0], SizeOf(LDigest));
end;

procedure TestBLAKE2b256Vectors;
const
  ABC: array[0..2] of Byte = (Ord('a'), Ord('b'), Ord('c'));
  LONG_MSG = 'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq';
var
  LLong: TBytes;
  LH: IHasher;
  LDigest: TBLAKE2b256Digest;
begin
  CheckEqual(
    '0e5751c026e543b2e8ab2eb06099daa1d1e5df47778f7787faab45cdf12fe3a8',
    BLAKE2b256Hex(GNilByte^, 0),
    'BLAKE2b-256 empty');
  CheckEqual(
    'bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319',
    BLAKE2b256Hex(ABC[0], SizeOf(ABC)),
    'BLAKE2b-256 abc');
  LLong := BytesOf(LONG_MSG);
  CheckEqual(
    '5f7a93da9c5621583f22e49e8e91a40cbba37536622235a380f434b9f68e49c4',
    BLAKE2b256Hex(LLong[0], Length(LLong)),
    'BLAKE2b-256 448-bit');
  LH := NewBLAKE2b256;
  LH.Write(ABC[0], 1);
  LH.Write(ABC[1], 1);
  LH.Write(ABC[2], 1);
  LH.Sum(LDigest[0], SizeOf(LDigest));
  CheckEqual(
    'bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319',
    DigestToHex(LDigest[0], SizeOf(LDigest)),
    'BLAKE2b-256 streaming abc');
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

procedure CallBLAKE2b256OfNilPositive;
begin
  BLAKE2b256Of(GNilByte^, 1);
end;

procedure CallBLAKE2b256WriteNilPositive;
var
  LH: IHasher;
begin
  LH := NewBLAKE2b256;
  LH.Write(GNilByte^, 1);
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
  CheckRaisesArgumentError(@CallBLAKE2b256OfNilPositive,
    'BLAKE2b256Of nil+positive');
  CheckRaisesArgumentError(@CallBLAKE2b256WriteNilPositive,
    'BLAKE2b256 Write nil+positive');
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

procedure TestSHAKE128Vectors;
var
  LOut: TBytes;
  LS: TSHAKE128;
  ABC: array[0..2] of Byte;
begin
  ABC[0] := Ord('a'); ABC[1] := Ord('b'); ABC[2] := Ord('c');
  LOut := SHAKE128Of(GNilByte^, 0, 32);
  CheckEqual(
    '7f9c2ba4e88f827d616045507605853ed73b8093f6efbc88eb1a6eacfa66ef26',
    DigestToHex(LOut[0], 32),
    'SHAKE128 empty 32');
  LOut := SHAKE128Of(ABC[0], 3, 32);
  CheckEqual(
    '5881092dd818bf5cf8a3ddb793fbcba74097d5c526a6d35f97b83351940f2cc8',
    DigestToHex(LOut[0], 32),
    'SHAKE128 abc 32');
  LS := TSHAKE128.Create;
  try
    LS.Write(ABC[0], 3);
    SetLength(LOut, 32);
    LS.Read(LOut[0], 16);
    LS.Read(LOut[16], 16);
    CheckEqual(
      '5881092dd818bf5cf8a3ddb793fbcba74097d5c526a6d35f97b83351940f2cc8',
      DigestToHex(LOut[0], 32),
      'SHAKE128 streaming two reads');
  finally
    LS.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.hash');
  T.Test('SHA256 vectors', @TestSHA256Vectors);
  T.Test('SHA224 vectors', @TestSHA224Vectors);
  T.Test('BLAKE2b-256 vectors', @TestBLAKE2b256Vectors);
  T.Test('MD5 and SHA1 vectors', @TestMD5AndSHA1Vectors);
  T.Test('streaming hasher', @TestStreamingHasher);
  T.Test('nil buffer contract', @TestNilBufferContract);
  T.Test('SHAKE128 vectors', @TestSHAKE128Vectors);
  if not T.Run then Halt(1);
end.
