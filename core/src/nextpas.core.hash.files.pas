unit nextpas.core.hash.files;

{$mode objfpc}{$H+}

{ nextpas.core.hash.files — file-level hash convenience helpers

  These helpers keep file IO at the boundary, stream bytes into the existing
  hash implementations, and return lowercase hexadecimal digests.
}

interface

uses
  nextpas.core.hash.base;

function HashFileHex(AAlgo: THashAlgorithm; const APath: string): string;
function SHA256FileHex(const APath: string): string;
function SHA512FileHex(const APath: string): string;

implementation

uses
  nextpas.core.errors,
  nextpas.core.base,
  nextpas.core.fs.base,
  nextpas.core.fs.intf,
  nextpas.core.fs.stream,
  nextpas.core.fs.util,
  nextpas.core.hash.intf,
  nextpas.core.hash.md5,
  nextpas.core.hash.sha1,
  nextpas.core.hash.sha256,
  nextpas.core.hash.sha512,
  nextpas.core.hash.util;

function HashFileWithHasherHex(const APath: string; const AHasher: IHasher): string;
var
  LFile: IFile;
  LInfo: TFileInfo;
  LBuf: array[0..32767] of Byte;
  LRead: SizeUInt;
  LDigest: TBytes;
begin
  if APath = '' then
    raise EArgumentError.Create('HashFileHex: empty path');
  if Pos(#0, APath) > 0 then
    raise EArgumentError.Create('HashFileHex: path contains embedded NUL');

  LInfo := FsStat(APath);
  if LInfo.FileType <> ftRegular then
    raise EInvalidOperationError.Create('HashFileHex: path is not a regular file');

  LFile := FsOpen(APath, [fmRead]);
  try
    LInfo := LFile.Stat;
    if LInfo.FileType <> ftRegular then
      raise EInvalidOperationError.Create('HashFileHex: opened handle is not a regular file');

    repeat
      LRead := LFile.Read(LBuf[0], SizeOf(LBuf));
      if LRead = 0 then
        Break;
      AHasher.Write(LBuf[0], LRead);
    until False;
  finally
    LFile.Close;
  end;

  SetLength(LDigest, AHasher.DigestSize);
  if Length(LDigest) = 0 then
  begin
    Result := '';
    Exit;
  end;
  AHasher.Sum(LDigest[0], SizeUInt(Length(LDigest)));
  Result := DigestToHex(LDigest[0], SizeUInt(Length(LDigest)));
end;

function HashFileHex(AAlgo: THashAlgorithm; const APath: string): string;
begin
  case Ord(AAlgo) of
    Ord(haMD5):    Result := HashFileWithHasherHex(APath, NewMD5);
    Ord(haSHA1):   Result := HashFileWithHasherHex(APath, NewSHA1);
    Ord(haSHA256): Result := HashFileWithHasherHex(APath, NewSHA256);
    Ord(haSHA384): Result := HashFileWithHasherHex(APath, NewSHA384);
    Ord(haSHA512): Result := HashFileWithHasherHex(APath, NewSHA512);
  else
    raise EArgumentError.Create('HashFileHex: invalid hash algorithm');
  end;
end;

function SHA256FileHex(const APath: string): string;
begin
  Result := HashFileWithHasherHex(APath, NewSHA256);
end;

function SHA512FileHex(const APath: string): string;
begin
  Result := HashFileWithHasherHex(APath, NewSHA512);
end;

end.
