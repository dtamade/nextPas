unit nextpas.core.hash.files;

{$mode objfpc}{$H+}

{ nextpas.core.hash.files — file-level hash convenience helpers

  These helpers keep file IO at the boundary, stream bytes into the existing
  hash implementations, and return lowercase hexadecimal digests.
}

interface

function SHA256FileHex(const APath: string): string;
function SHA512FileHex(const APath: string): string;

implementation

uses
  nextpas.core.errors,
  nextpas.core.base,
  nextpas.core.fs.base,
  nextpas.core.fs.intf,
  nextpas.core.fs.stream,
  nextpas.core.hash.intf,
  nextpas.core.hash.sha256,
  nextpas.core.hash.sha512,
  nextpas.core.hash.util;

function HashFileHex(const APath: string; const AHasher: IHasher): string;
var
  LFile: IFile;
  LBuf: array[0..32767] of Byte;
  LRead: SizeUInt;
  LDigest: TBytes;
begin
  if APath = '' then
    raise EArgumentError.Create('HashFileHex: empty path');
  if Pos(#0, APath) > 0 then
    raise EArgumentError.Create('HashFileHex: path contains embedded NUL');

  LFile := FsOpen(APath, [fmRead]);
  try
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

function SHA256FileHex(const APath: string): string;
begin
  Result := HashFileHex(APath, NewSHA256);
end;

function SHA512FileHex(const APath: string): string;
begin
  Result := HashFileHex(APath, NewSHA512);
end;

end.
