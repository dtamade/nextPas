program test_sha512;
{$mode objfpc}{$H+}
uses
  SysUtils, nextpas.core.hash.base, nextpas.core.hash.intf, nextpas.core.hash.sha512;
var
  GPass: Integer = 0;
procedure Check(const AName: string; ACond: Boolean);
begin
  if ACond then begin Inc(GPass); WriteLn('  [PASS] ', AName); end
  else begin WriteLn('  [FAIL] ', AName); Halt(1); end;
end;
function ToHex(const ABuf; ALen: Integer): string;
var I: Integer; P: PByte;
begin
  Result := ''; P := @ABuf;
  for I := 0 to ALen-1 do Result := Result + LowerCase(IntToHex(P[I], 2));
end;
var
  LH: IHasher;
  LD512: TSHA512Digest;
  LD384: TSHA384Digest;
  LData: AnsiString;
begin
  WriteLn('=== nextpas.core.hash.sha512 unit tests ===');

  // SHA-512("")
  LH := NewSHA512;
  LH.Sum(LD512, SHA512_DIGEST_SIZE);
  Check('SHA-512("") prefix',
    Copy(ToHex(LD512, 64), 1, 16) = 'cf83e1357eefb8bd');

  // SHA-512("abc")
  LH := NewSHA512;
  LData := 'abc';
  LH.Write(LData[1], 3);
  LH.Sum(LD512, SHA512_DIGEST_SIZE);
  Check('SHA-512("abc") prefix',
    Copy(ToHex(LD512, 64), 1, 16) = 'ddaf35a193617aba');

  // SHA-384("")
  LH := NewSHA384;
  LH.Sum(LD384, SHA384_DIGEST_SIZE);
  Check('SHA-384("") prefix',
    Copy(ToHex(LD384, 48), 1, 16) = '38b060a751ac9638');

  // SHA-384("abc")
  LH := NewSHA384;
  LH.Write(LData[1], 3);
  LH.Sum(LD384, SHA384_DIGEST_SIZE);
  Check('SHA-384("abc") prefix',
    Copy(ToHex(LD384, 48), 1, 16) = 'cb00753f45a35e8b');

  // Metadata
  LH := NewSHA512;
  Check('SHA-512 DigestSize=64', LH.DigestSize = 64);
  Check('SHA-512 BlockSize=128', LH.BlockSize = 128);
  LH := NewSHA384;
  Check('SHA-384 DigestSize=48', LH.DigestSize = 48);
  Check('SHA-384 BlockSize=128', LH.BlockSize = 128);

  WriteLn;
  WriteLn('Results: ', GPass, ' passed');
end.
