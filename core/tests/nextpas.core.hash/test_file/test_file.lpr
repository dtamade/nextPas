program test_file;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.errors,
  nextpas.core.fs,
  nextpas.core.hash;

type
  TArgErrorProc = procedure;

var
  T: TTestRunner;
  GTmpDir: string;

function InvalidHashAlgorithm: THashAlgorithm;
var
  LValue: Integer;
begin
  LValue := Ord(High(THashAlgorithm));
  Inc(LValue);
  Result := THashAlgorithm(LValue);
end;

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

procedure CheckRaisesInvalidOperationWithMessage(AProc: TArgErrorProc;
  const AExpectedText, AForbiddenText, AMessage: string);
begin
  try
    AProc;
  except
    on E: EInvalidOperationError do
    begin
      Check(Pos(AExpectedText, E.Message) > 0,
        AMessage + ': expected message containing "' + AExpectedText +
        '", got "' + E.Message + '"');
      if AForbiddenText <> '' then
        Check(Pos(AForbiddenText, E.Message) = 0,
          AMessage + ': message must not contain raw input path');
      Exit;
    end;
    on E: Exception do
      Fail(AMessage + ': expected EInvalidOperationError, got ' + E.ClassName);
  end;

  Fail(AMessage + ': expected EInvalidOperationError');
end;

procedure SetupTmpDir;
begin
  GTmpDir := nextpas.core.fs.PathJoin([
    nextpas.core.fs.GetTempDir,
    'nextpas_hash_file_test_' + IntToStr(GetProcessID)
  ]);
  nextpas.core.fs.RemoveAll(GTmpDir);
  nextpas.core.fs.MkdirAll(GTmpDir);
end;

procedure CleanupTmpDir;
begin
  nextpas.core.fs.RemoveAll(GTmpDir);
end;

function BytesOfString(const AText: string): TBytes;
begin
  SetLength(Result, Length(AText));
  if Length(AText) > 0 then
    Move(AText[1], Result[0], Length(AText));
end;

function SHA512BytesHex(const AData: TBytes): string;
var
  LHasher: IHasher;
  LDigest: TSHA512Digest;
begin
  LHasher := NewSHA512;
  if Length(AData) > 0 then
    LHasher.Write(AData[0], Length(AData));
  LHasher.Sum(LDigest, SizeOf(LDigest));
  Result := DigestToHex(LDigest, SizeOf(LDigest));
end;

procedure TestSHA256FileHexKnownVector;
const
  EXPECTED = 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';
var
  LPath: string;
begin
  LPath := GTmpDir + '/abc.txt';
  nextpas.core.fs.WriteFile(LPath, BytesOfString('abc'));

  CheckEqual(EXPECTED, SHA256FileHex(LPath), 'SHA256FileHex abc vector');
end;

procedure TestSHA512FileHexKnownVector;
const
  EXPECTED =
    'ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a' +
    '2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f';
var
  LPath: string;
begin
  LPath := GTmpDir + '/abc-sha512.txt';
  nextpas.core.fs.WriteFile(LPath, BytesOfString('abc'));

  CheckEqual(EXPECTED, SHA512FileHex(LPath), 'SHA512FileHex abc vector');
end;

procedure TestHashFileHexFacadeByAlgorithm;
const
  MD5_EXPECTED = '900150983cd24fb0d6963f7d28e17f72';
  SHA1_EXPECTED = 'a9993e364706816aba3e25717850c26c9cd0d89d';
  SHA256_EXPECTED = 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';
  SHA384_EXPECTED =
    'cb00753f45a35e8bb5a03d699ac65007272c32ab0eded163' +
    '1a8b605a43ff5bed8086072ba1e7cc2358baeca134c825a7';
  SHA512_EXPECTED =
    'ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a' +
    '2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f';
var
  LPath: string;
begin
  LPath := GTmpDir + '/facade-algo-abc.txt';
  nextpas.core.fs.WriteFile(LPath, BytesOfString('abc'));

  CheckEqual(MD5_EXPECTED, HashFileHex(haMD5, LPath), 'HashFileHex MD5 abc vector');
  CheckEqual(SHA1_EXPECTED, HashFileHex(haSHA1, LPath), 'HashFileHex SHA1 abc vector');
  CheckEqual(SHA256_EXPECTED, HashFileHex(haSHA256, LPath), 'HashFileHex SHA256 abc vector');
  CheckEqual(SHA384_EXPECTED, HashFileHex(haSHA384, LPath), 'HashFileHex SHA384 abc vector');
  CheckEqual(SHA512_EXPECTED, HashFileHex(haSHA512, LPath), 'HashFileHex SHA512 abc vector');
end;

procedure TestHashFileHexEmptyFileByAlgorithm;
const
  MD5_EXPECTED = 'd41d8cd98f00b204e9800998ecf8427e';
  SHA1_EXPECTED = 'da39a3ee5e6b4b0d3255bfef95601890afd80709';
  SHA256_EXPECTED = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
  SHA384_EXPECTED =
    '38b060a751ac96384cd9327eb1b1e36a21fdb71114be07434c0cc7bf63f6e1da' +
    '274edebfe76f65fbd51ad2f14898b95b';
  SHA512_EXPECTED =
    'cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce' +
    '47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e';
var
  LPath: string;
begin
  LPath := GTmpDir + '/facade-empty.bin';
  nextpas.core.fs.WriteFile(LPath, nil);

  CheckEqual(MD5_EXPECTED, HashFileHex(haMD5, LPath), 'HashFileHex MD5 empty vector');
  CheckEqual(SHA1_EXPECTED, HashFileHex(haSHA1, LPath), 'HashFileHex SHA1 empty vector');
  CheckEqual(SHA256_EXPECTED, HashFileHex(haSHA256, LPath), 'HashFileHex SHA256 empty vector');
  CheckEqual(SHA384_EXPECTED, HashFileHex(haSHA384, LPath), 'HashFileHex SHA384 empty vector');
  CheckEqual(SHA512_EXPECTED, HashFileHex(haSHA512, LPath), 'HashFileHex SHA512 empty vector');
end;

procedure CallHashFileHexInvalidAlgorithm;
begin
  HashFileHex(InvalidHashAlgorithm, GTmpDir + '/invalid-algorithm.txt');
end;

procedure TestHashFileHexInvalidAlgorithm;
begin
  nextpas.core.fs.WriteFile(GTmpDir + '/invalid-algorithm.txt', BytesOfString('abc'));
  CheckRaisesArgumentError(@CallHashFileHexInvalidAlgorithm,
    'HashFileHex invalid algorithm');
end;

procedure TestSHA256FileHexEmptyFile;
const
  EXPECTED = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
var
  LPath: string;
begin
  LPath := GTmpDir + '/empty.bin';
  nextpas.core.fs.WriteFile(LPath, nil);

  CheckEqual(EXPECTED, SHA256FileHex(LPath), 'SHA256FileHex empty file');
end;

procedure TestFileHexStreamsPastSingleBuffer;
const
  EXPECTED = 'cd2df694e424bc7968cc37f47751019e5ca0cd1bdf2e479ea537c3a1c32ee1aa';
var
  LPath: string;
  LData: TBytes;
  LI: Integer;
begin
  LPath := GTmpDir + '/large.bin';
  SetLength(LData, 100000);
  for LI := 0 to High(LData) do
    LData[LI] := Byte(LI mod 251);
  nextpas.core.fs.WriteFile(LPath, LData);

  CheckEqual(EXPECTED, SHA256FileHex(LPath), 'SHA256FileHex streaming file');
end;

procedure TestSHA512FileHexPreservesBinaryBytes;
var
  LPath: string;
  LData: TBytes;
begin
  LPath := GTmpDir + '/binary.bin';
  LData := TBytes.Create(0, 1, 2, 3, 0, 255, 254, 10);
  nextpas.core.fs.WriteFile(LPath, LData);

  CheckEqual(SHA512BytesHex(LData), SHA512FileHex(LPath),
    'SHA512FileHex preserves binary zero bytes');
end;

procedure TestMissingFileRaisesNotFound;
var
  LGot: Boolean;
begin
  LGot := False;
  try
    SHA256FileHex(GTmpDir + '/missing.bin');
  except
    on E: ENotFoundError do
      LGot := True;
  end;

  Check(LGot, 'SHA256FileHex missing file raises ENotFoundError');
end;

procedure CallSHA256FileHexEmptyPath;
begin
  SHA256FileHex('');
end;

procedure CallSHA512FileHexEmptyPath;
begin
  SHA512FileHex('');
end;

procedure CallHashFileHexEmptyPath;
begin
  HashFileHex(haMD5, '');
end;

procedure CallSHA256FileHexEmbeddedNulPath;
begin
  SHA256FileHex(GTmpDir + '/nul-real.bin' + #0 + '.shadow');
end;

procedure CallSHA512FileHexEmbeddedNulPath;
begin
  SHA512FileHex(GTmpDir + '/nul-real.bin' + #0 + '.shadow');
end;

procedure CallHashFileHexEmbeddedNulPath;
begin
  HashFileHex(haSHA1, GTmpDir + '/nul-real.bin' + #0 + '.shadow');
end;

procedure CallSHA256FileHexDirectoryPath;
begin
  SHA256FileHex(GTmpDir);
end;

procedure CallSHA512FileHexDirectoryPath;
begin
  SHA512FileHex(GTmpDir);
end;

procedure CallHashFileHexDirectoryPath;
begin
  HashFileHex(haSHA384, GTmpDir);
end;

procedure TestEmptyPathRaisesArgumentError;
begin
  CheckRaisesArgumentError(@CallSHA256FileHexEmptyPath,
    'SHA256FileHex empty path');
  CheckRaisesArgumentError(@CallSHA512FileHexEmptyPath,
    'SHA512FileHex empty path');
  CheckRaisesArgumentError(@CallHashFileHexEmptyPath,
    'HashFileHex empty path');
end;

procedure TestEmbeddedNulPathRaisesArgumentError;
begin
  nextpas.core.fs.WriteFile(GTmpDir + '/nul-real.bin', BytesOfString('real'));

  CheckRaisesArgumentError(@CallSHA256FileHexEmbeddedNulPath,
    'SHA256FileHex embedded NUL path');
  CheckRaisesArgumentError(@CallSHA512FileHexEmbeddedNulPath,
    'SHA512FileHex embedded NUL path');
  CheckRaisesArgumentError(@CallHashFileHexEmbeddedNulPath,
    'HashFileHex embedded NUL path');
end;

procedure TestDirectoryPathRaisesInvalidOperation;
begin
  CheckRaisesInvalidOperationWithMessage(@CallSHA256FileHexDirectoryPath,
    'regular file', GTmpDir, 'SHA256FileHex directory path');
  CheckRaisesInvalidOperationWithMessage(@CallSHA512FileHexDirectoryPath,
    'regular file', GTmpDir, 'SHA512FileHex directory path');
  CheckRaisesInvalidOperationWithMessage(@CallHashFileHexDirectoryPath,
    'regular file', GTmpDir, 'HashFileHex directory path');
end;

begin
  SetupTmpDir;
  try
    T := TTestRunner.Create('nextpas.core.hash.files');
    T.Run('SHA256FileHex known vector', @TestSHA256FileHexKnownVector);
    T.Run('SHA512FileHex known vector', @TestSHA512FileHexKnownVector);
    T.Run('HashFileHex facade by algorithm', @TestHashFileHexFacadeByAlgorithm);
    T.Run('HashFileHex empty file by algorithm', @TestHashFileHexEmptyFileByAlgorithm);
    T.Run('HashFileHex invalid algorithm', @TestHashFileHexInvalidAlgorithm);
    T.Run('SHA256FileHex empty file', @TestSHA256FileHexEmptyFile);
    T.Run('SHA256FileHex streaming file', @TestFileHexStreamsPastSingleBuffer);
    T.Run('SHA512FileHex binary bytes', @TestSHA512FileHexPreservesBinaryBytes);
    T.Run('SHA256FileHex missing file error', @TestMissingFileRaisesNotFound);
    T.Run('file hash empty path error', @TestEmptyPathRaisesArgumentError);
    T.Run('file hash embedded NUL path error', @TestEmbeddedNulPathRaisesArgumentError);
    T.Run('file hash directory path error', @TestDirectoryPathRaisesInvalidOperation);
    T.Summary;
  finally
    CleanupTmpDir;
  end;
end.
