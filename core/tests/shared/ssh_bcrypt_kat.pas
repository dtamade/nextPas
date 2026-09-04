unit ssh_bcrypt_kat;

{** nextpas.core.ssh 测试共享：bcrypt_pbkdf 黄金向量。
 *
 * 五组向量经 python-bcrypt 5.0.0 交叉验证（与 OpenBSD bcrypt_pbkdf 一致）：
 *   1: password/salt1234/48/16
 *   2: password/salt1234/48/64
 *   3: hunter2!/0123456789abcdef/32/100
 *   4: pw/saltsalt/72/5
 *   5: topsecret/abcdefgh/16/1
 * 常量为小写 hex，测试内与 TryBcryptPbkdf 输出逐字节比对。*}

interface

uses
  nextpas.core.base;

type
  TBcryptVector = record
    Pass: string;
    Salt: string;
    KeyLen: Integer;
    Rounds: Cardinal;
    WantHex: string;
  end;

const
  BCRYPT_VECTORS: array[0..4] of TBcryptVector = (
    (Pass: 'password'; Salt: 'salt1234'; KeyLen: 48; Rounds: 16;
     WantHex: '9d684452bc3975bce9d256d068a093beaa9c6e501f70244a791877bc6ad631da6ef31623ffda8d75a1e80b5bc489e829'),
    (Pass: 'password'; Salt: 'salt1234'; KeyLen: 48; Rounds: 64;
     WantHex: 'e645c92faf759e56c93586f77e2039833288d9aad2a3962152944af5edadfa74bd897660aafd7df65f410e5dbc2031f9'),
    (Pass: 'hunter2!'; Salt: '0123456789abcdef'; KeyLen: 32; Rounds: 100;
     WantHex: 'b41ee6e096bd131c573b439b2c50ba948cdcae4625be11cd90693fe5d6e3d091'),
    (Pass: 'pw'; Salt: 'saltsalt'; KeyLen: 72; Rounds: 5;
     WantHex: 'd144ced52435823b21a0753be17550def2959177042c67314085b4abc9b8219bfc3e996618e5d508380f55f33414c2e84ed7b55d78e513ae61212acad51eae4f519d315598377634'),
    (Pass: 'topsecret'; Salt: 'abcdefgh'; KeyLen: 16; Rounds: 1;
     WantHex: '992bf161f37d6508d0d7a02beb361b8b')
  );

function HexToBytes(const AHex: string): TBytes;
function StringToBytesAscii(const AText: string): TBytes;
function BytesToHexLower(const AData: TBytes): string;

implementation

uses
  nextpas.core.exception, nextpas.core.text.conv;

function HexVal(C: Char): Byte;
begin
  case C of
    '0'..'9': Result := Ord(C) - Ord('0');
    'a'..'f': Result := Ord(C) - Ord('a') + 10;
    'A'..'F': Result := Ord(C) - Ord('A') + 10;
  else
    raise Exception.Create('ssh_bcrypt_kat: bad hex char');
  end;
end;

function HexToBytes(const AHex: string): TBytes;
var
  I: Integer;
begin
  if (Length(AHex) mod 2) <> 0 then
    raise Exception.Create('ssh_bcrypt_kat: odd hex length');
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do
    Result[I] := (HexVal(AHex[2 * I + 1]) shl 4) or HexVal(AHex[2 * I + 2]);
end;

function StringToBytesAscii(const AText: string): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(AText));
  if Length(AText) > 0 then
    Move(PByte(PChar(AText))^, Result[0], SizeUInt(Length(AText)));
end;

function BytesToHexLower(const AData: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AData) do
    Result := Result + LowerCase(IntToHex(AData[I], 2));
end;

end.
