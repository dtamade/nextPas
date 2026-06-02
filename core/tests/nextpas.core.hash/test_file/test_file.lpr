program test_file;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.errors,
  nextpas.core.fs,
  nextpas.core.hash;

var
  T: TTestRunner;
  GTmpDir: string;

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

begin
  SetupTmpDir;
  try
    T := TTestRunner.Create('nextpas.core.hash.files');
    T.Run('SHA256FileHex known vector', @TestSHA256FileHexKnownVector);
    T.Run('SHA512FileHex known vector', @TestSHA512FileHexKnownVector);
    T.Run('SHA256FileHex empty file', @TestSHA256FileHexEmptyFile);
    T.Run('SHA256FileHex streaming file', @TestFileHexStreamsPastSingleBuffer);
    T.Run('SHA512FileHex binary bytes', @TestSHA512FileHexPreservesBinaryBytes);
    T.Run('SHA256FileHex missing file error', @TestMissingFileRaisesNotFound);
    T.Summary;
  finally
    CleanupTmpDir;
  end;
end.
