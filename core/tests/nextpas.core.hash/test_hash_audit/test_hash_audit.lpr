program test_hash_audit;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.hash.base,
  nextpas.core.hash,
  nextpas.core.hash.wyhash;

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

procedure CheckRaisesArgumentErrorContaining(AProc: TArgErrorProc;
  const AExpectedText, AMessage: string);
begin
  try
    AProc;
  except
    on E: EArgumentError do
    begin
      Check(Pos(AExpectedText, E.Message) > 0,
        AMessage + ': expected message containing "' + AExpectedText +
        '", got "' + E.Message + '"');
      Exit;
    end;
    on E: Exception do
      Fail(AMessage + ': expected EArgumentError, got ' + E.ClassName);
  end;

  Fail(AMessage + ': expected EArgumentError');
end;

function InvalidHashAlgorithm: THashAlgorithm;
var
  LValue: Integer;
begin
  LValue := Ord(High(THashAlgorithm));
  Inc(LValue);
  Result := THashAlgorithm(LValue);
end;

function HexStrOf(const ABuf; ASize: SizeUInt): string;
begin
  Result := DigestToHex(ABuf, ASize);
end;

function SHA256HexOfString(const AText: AnsiString): string;
var
  LDigest: TSHA256Digest;
begin
  if Length(AText) = 0 then
    LDigest := SHA256Of(GNilByte^, 0)
  else
    LDigest := SHA256Of(AText[1], SizeUInt(Length(AText)));
  Result := HexStrOf(LDigest[0], SizeOf(LDigest));
end;

function MD5HexOfString(const AText: AnsiString): string;
var
  LDigest: TMD5Digest;
begin
  if Length(AText) = 0 then
    LDigest := MD5Of(GNilByte^, 0)
  else
    LDigest := MD5Of(AText[1], SizeUInt(Length(AText)));
  Result := HexStrOf(LDigest[0], SizeOf(LDigest));
end;

function StreamingHashHex(AAlgo: THashAlgorithm; const AData: AnsiString): string;
var
  LHasher: IHasher;
  LDigest: TBytes;
  LSplit: SizeUInt;
begin
  LHasher := NewHasher(AAlgo);
  LSplit := SizeUInt(Length(AData) div 2);
  if LSplit > 0 then
    LHasher.Write(AData[1], LSplit);
  if SizeUInt(Length(AData)) > LSplit then
    LHasher.Write(AData[LSplit + 1], SizeUInt(Length(AData)) - LSplit);
  LDigest := LHasher.SumBytes;
  if Length(LDigest) = 0 then
    Exit('');
  Result := DigestToHex(LDigest[0], SizeUInt(Length(LDigest)));
end;

procedure TestKnownVectors;
begin
  CheckEqual(
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    SHA256HexOfString(''), 'SHA256 empty vector');
  CheckEqual(
    'ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb',
    SHA256HexOfString('a'), 'SHA256 single byte vector');
  CheckEqual(
    '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824',
    SHA256HexOfString('hello'), 'SHA256 hello vector');
  CheckEqual('d41d8cd98f00b204e9800998ecf8427e',
    MD5HexOfString(''), 'MD5 empty vector');
  CheckEqual('5d41402abc4b2a76b9719d911017c592',
    MD5HexOfString('hello'), 'MD5 hello vector');
end;

procedure TestStreamingBoundaries;
var
  LData55, LData56, LData64: AnsiString;
begin
  LData55 := StringOfChar('a', 55);
  LData56 := StringOfChar('b', 56);
  LData64 := StringOfChar('c', 64);

  CheckEqual(SHA256HexOfString(LData55), StreamingHashHex(haSHA256, LData55),
    'SHA256 streaming boundary 55 bytes');
  CheckEqual(SHA256HexOfString(LData56), StreamingHashHex(haSHA256, LData56),
    'SHA256 streaming boundary 56 bytes');
  CheckEqual(SHA256HexOfString(LData64), StreamingHashHex(haSHA256, LData64),
    'SHA256 streaming boundary 64 bytes');
  CheckEqual(MD5HexOfString(LData55), StreamingHashHex(haMD5, LData55),
    'MD5 streaming boundary 55 bytes');
  CheckEqual(MD5HexOfString(LData56), StreamingHashHex(haMD5, LData56),
    'MD5 streaming boundary 56 bytes');
  CheckEqual(MD5HexOfString(LData64), StreamingHashHex(haMD5, LData64),
    'MD5 streaming boundary 64 bytes');
end;

procedure TestSumDestinationBounds;
const
  SENTINEL = $A5;
var
  LHasher: IHasher;
  LFull: TBytes;
  LBuf: array[0..127] of Byte;
  I: Integer;
  LOk: Boolean;
begin
  LHasher := NewSHA256;
  LHasher.Write('abc'[1], 3);
  LFull := LHasher.SumBytes;

  FillChar(LBuf[0], SizeOf(LBuf), SENTINEL);
  LHasher.Sum(LBuf[0], 0);
  LOk := True;
  for I := 0 to High(LBuf) do
    LOk := LOk and (LBuf[I] = SENTINEL);
  Check(LOk, 'Sum size 0 leaves destination untouched');

  FillChar(LBuf[0], SizeOf(LBuf), SENTINEL);
  LHasher.Sum(LBuf[0], 3);
  LOk := True;
  for I := 0 to 2 do
    LOk := LOk and (LBuf[I] = LFull[I]);
  for I := 3 to High(LBuf) do
    LOk := LOk and (LBuf[I] = SENTINEL);
  Check(LOk, 'Sum short buffer writes prefix only');

  FillChar(LBuf[0], SizeOf(LBuf), SENTINEL);
  LHasher.Sum(LBuf[0], LHasher.DigestSize + 5);
  LOk := True;
  for I := 0 to LHasher.DigestSize - 1 do
    LOk := LOk and (LBuf[I] = LFull[I]);
  for I := LHasher.DigestSize to High(LBuf) do
    LOk := LOk and (LBuf[I] = SENTINEL);
  Check(LOk, 'Sum oversized buffer stops at digest size');
end;

procedure CallDigestToHexNilPositive;
begin
  DigestToHex(GNilByte^, 1);
end;

procedure CallDigestToHexLengthOverflow;
var
  LByte: Byte;
begin
  LByte := 0;
  DigestToHex(LByte, SizeUInt(High(SizeInt)) div 2 + 1);
end;

procedure CallSHA256OfNilPositive;
begin
  SHA256Of(GNilByte^, 1);
end;

procedure CallMD5OfNilPositive;
begin
  MD5Of(GNilByte^, 1);
end;

procedure CallSHA1OfNilPositive;
begin
  SHA1Of(GNilByte^, 1);
end;

procedure CallSHA384OfNilPositive;
begin
  SHA384Of(GNilByte^, 1);
end;

procedure CallSHA512OfNilPositive;
begin
  SHA512Of(GNilByte^, 1);
end;

procedure CallSHA384WriteNilPositive;
var
  LHasher: IHasher;
begin
  LHasher := NewSHA384;
  LHasher.Write(GNilByte^, 1);
end;

procedure CallSHA384SumNilPositive;
var
  LHasher: IHasher;
begin
  LHasher := NewSHA384;
  LHasher.Sum(GNilByte^, 1);
end;

{$IFDEF CPU64}
procedure CallMD5WriteTotalLengthOverflow;
var
  LHasher: IHasher;
begin
  LHasher := NewMD5;
  LHasher.Write(GNilByte^, SizeUInt(High(UInt64) div 8) + 1);
end;

procedure CallSHA1WriteTotalLengthOverflow;
var
  LHasher: IHasher;
begin
  LHasher := NewSHA1;
  LHasher.Write(GNilByte^, SizeUInt(High(UInt64) div 8) + 1);
end;

procedure CallSHA256WriteTotalLengthOverflow;
var
  LHasher: IHasher;
begin
  LHasher := NewSHA256;
  LHasher.Write(GNilByte^, SizeUInt(High(UInt64) div 8) + 1);
end;

procedure CallSHA384WriteTotalLengthOverflow;
var
  LHasher: IHasher;
begin
  LHasher := NewSHA384;
  LHasher.Write(GNilByte^, SizeUInt(High(UInt64) div 8) + 1);
end;

procedure CallSHA512WriteTotalLengthOverflow;
var
  LHasher: IHasher;
begin
  LHasher := NewSHA512;
  LHasher.Write(GNilByte^, SizeUInt(High(UInt64) div 8) + 1);
end;
{$ENDIF}

procedure CallWyHashNilPositive;
begin
  WyHash(nil, 1, 0);
end;

procedure CallNewHasherInvalidAlgorithm;
begin
  NewHasher(InvalidHashAlgorithm);
end;

procedure CallSHA256FileHexEmptyPath;
begin
  SHA256FileHex('');
end;

procedure CallSHA512FileHexEmptyPath;
begin
  SHA512FileHex('');
end;

procedure CallSHA256FileHexEmbeddedNulPath;
begin
  SHA256FileHex('/tmp/nextpas-hash-real.bin' + #0 + '.shadow');
end;

procedure CallSHA512FileHexEmbeddedNulPath;
begin
  SHA512FileHex('/tmp/nextpas-hash-real.bin' + #0 + '.shadow');
end;

procedure TestMalformedInputs;
begin
  CheckRaisesArgumentError(@CallDigestToHexNilPositive,
    'DigestToHex nil+positive');
  CheckRaisesArgumentError(@CallDigestToHexLengthOverflow,
    'DigestToHex length overflow');
  CheckRaisesArgumentError(@CallSHA256OfNilPositive,
    'SHA256Of nil+positive');
  CheckRaisesArgumentError(@CallMD5OfNilPositive,
    'MD5Of nil+positive');
  CheckRaisesArgumentError(@CallSHA1OfNilPositive,
    'SHA1Of nil+positive');
  CheckRaisesArgumentError(@CallSHA384OfNilPositive,
    'SHA384Of nil+positive');
  CheckRaisesArgumentError(@CallSHA512OfNilPositive,
    'SHA512Of nil+positive');
  CheckRaisesArgumentErrorContaining(@CallSHA384WriteNilPositive,
    'SHA384.Write', 'SHA384 Write nil+positive context');
  CheckRaisesArgumentErrorContaining(@CallSHA384SumNilPositive,
    'SHA384.Sum', 'SHA384 Sum nil+positive context');
  {$IFDEF CPU64}
  CheckRaisesArgumentErrorContaining(@CallMD5WriteTotalLengthOverflow,
    'total length', 'MD5 Write total length overflow');
  CheckRaisesArgumentErrorContaining(@CallSHA1WriteTotalLengthOverflow,
    'total length', 'SHA1 Write total length overflow');
  CheckRaisesArgumentErrorContaining(@CallSHA256WriteTotalLengthOverflow,
    'total length', 'SHA256 Write total length overflow');
  CheckRaisesArgumentErrorContaining(@CallSHA384WriteTotalLengthOverflow,
    'SHA384.Write', 'SHA384 Write total length overflow context');
  CheckRaisesArgumentErrorContaining(@CallSHA512WriteTotalLengthOverflow,
    'total length', 'SHA512 Write total length overflow');
  {$ENDIF}
  CheckRaisesArgumentError(@CallWyHashNilPositive,
    'WyHash nil+positive');
  CheckRaisesArgumentError(@CallNewHasherInvalidAlgorithm,
    'NewHasher invalid algorithm');
  CheckRaisesArgumentError(@CallSHA256FileHexEmptyPath,
    'SHA256FileHex empty path');
  CheckRaisesArgumentError(@CallSHA512FileHexEmptyPath,
    'SHA512FileHex empty path');
  CheckRaisesArgumentError(@CallSHA256FileHexEmbeddedNulPath,
    'SHA256FileHex embedded NUL path');
  CheckRaisesArgumentError(@CallSHA512FileHexEmbeddedNulPath,
    'SHA512FileHex embedded NUL path');
end;

begin
  T := TTestRunner.Create('nextpas.core.hash.audit');
  T.Run('known vectors', @TestKnownVectors);
  T.Run('streaming boundary sizes', @TestStreamingBoundaries);
  T.Run('sum destination bounds', @TestSumDestinationBounds);
  T.Run('malformed input contracts', @TestMalformedInputs);
  T.Summary;
end.
