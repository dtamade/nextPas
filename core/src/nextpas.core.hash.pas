unit nextpas.core.hash;

{$mode objfpc}{$H+}

{ nextpas.core.hash — 哈希模块门面

  L2 系统能力模块。提供 SHA-256/384/512 和 MD5 哈希原语。
  IHasher 继承 IWriter，可直接与 io 层集成。

  用法：
    uses nextpas.core.hash;
    var H: IHasher;
    H := NewSHA256;
    if Length(Data) > 0 then
      H.Write(Data[0], Length(Data));
    H.Sum(Digest, SHA256_DIGEST_SIZE);
}

interface

uses
  nextpas.core.hash.base,
  nextpas.core.hash.intf,
  nextpas.core.hash.md5,
  nextpas.core.hash.sha1,
  nextpas.core.hash.sha256,
  nextpas.core.hash.sha512,
  nextpas.core.hash.util,
  nextpas.core.hash.files,
  nextpas.core.hash.wyhash;

type
  THashAlgorithm = nextpas.core.hash.base.THashAlgorithm;
  IHasher = nextpas.core.hash.intf.IHasher;
  TMD5Digest = nextpas.core.hash.base.TMD5Digest;
  TSHA1Digest = nextpas.core.hash.base.TSHA1Digest;
  TSHA256Digest = nextpas.core.hash.base.TSHA256Digest;
  TSHA384Digest = nextpas.core.hash.base.TSHA384Digest;
  TSHA512Digest = nextpas.core.hash.base.TSHA512Digest;

const
  haMD5 = nextpas.core.hash.base.haMD5;
  haSHA1 = nextpas.core.hash.base.haSHA1;
  haSHA256 = nextpas.core.hash.base.haSHA256;
  haSHA384 = nextpas.core.hash.base.haSHA384;
  haSHA512 = nextpas.core.hash.base.haSHA512;

  MD5_DIGEST_SIZE = nextpas.core.hash.base.MD5_DIGEST_SIZE;
  SHA1_DIGEST_SIZE = nextpas.core.hash.base.SHA1_DIGEST_SIZE;
  SHA256_DIGEST_SIZE = nextpas.core.hash.base.SHA256_DIGEST_SIZE;
  SHA384_DIGEST_SIZE = nextpas.core.hash.base.SHA384_DIGEST_SIZE;
  SHA512_DIGEST_SIZE = nextpas.core.hash.base.SHA512_DIGEST_SIZE;

  MD5_BLOCK_SIZE = nextpas.core.hash.base.MD5_BLOCK_SIZE;
  SHA1_BLOCK_SIZE = nextpas.core.hash.base.SHA1_BLOCK_SIZE;
  SHA256_BLOCK_SIZE = nextpas.core.hash.base.SHA256_BLOCK_SIZE;
  SHA384_BLOCK_SIZE = nextpas.core.hash.base.SHA384_BLOCK_SIZE;
  SHA512_BLOCK_SIZE = nextpas.core.hash.base.SHA512_BLOCK_SIZE;

function NewMD5: IHasher; inline;
function NewSHA1: IHasher; inline;
function NewSHA256: IHasher; inline;
function NewSHA384: IHasher; inline;
function NewSHA512: IHasher; inline;
function NewHasher(AAlgo: THashAlgorithm): IHasher;
function GetDigestSize(AAlgo: THashAlgorithm): SizeUInt; inline;
function GetBlockSize(AAlgo: THashAlgorithm): SizeUInt; inline;

function SHA256Of(const ABuf; ALen: SizeUInt): TSHA256Digest;
function SHA1Of(const ABuf; ALen: SizeUInt): TSHA1Digest;
function SHA384Of(const ABuf; ALen: SizeUInt): TSHA384Digest;
function SHA512Of(const ABuf; ALen: SizeUInt): TSHA512Digest;
function MD5Of(const ABuf; ALen: SizeUInt): TMD5Digest;

function DigestToHex(const ABuf; ALen: SizeUInt): string; inline;
function WyHash(const AData: Pointer; ALen: SizeUInt; ASeed: UInt64 = 0): UInt64; inline;
function WyHashStr(const S: AnsiString; ASeed: UInt64 = 0): UInt64; inline;
function WyHash32(const AData: Pointer; ALen: SizeUInt; ASeed: UInt64 = 0): UInt32; inline;
function WyHashStr32(const S: AnsiString; ASeed: UInt64 = 0): UInt32; inline;
function HashFileHex(AAlgo: THashAlgorithm; const APath: string): string; inline;
function SHA256FileHex(const APath: string): string; inline;
function SHA512FileHex(const APath: string): string; inline;

implementation

uses
  nextpas.core.errors;

function NewMD5: IHasher;
begin
  Result := nextpas.core.hash.md5.NewMD5;
end;

function NewSHA1: IHasher;
begin
  Result := nextpas.core.hash.sha1.NewSHA1;
end;

function NewSHA256: IHasher;
begin
  Result := nextpas.core.hash.sha256.NewSHA256;
end;

function NewSHA384: IHasher;
begin
  Result := nextpas.core.hash.sha512.NewSHA384;
end;

function NewSHA512: IHasher;
begin
  Result := nextpas.core.hash.sha512.NewSHA512;
end;

function GetDigestSize(AAlgo: THashAlgorithm): SizeUInt;
begin
  Result := nextpas.core.hash.base.GetDigestSize(AAlgo);
end;

function GetBlockSize(AAlgo: THashAlgorithm): SizeUInt;
begin
  Result := nextpas.core.hash.base.GetBlockSize(AAlgo);
end;

function SHA256Of(const ABuf; ALen: SizeUInt): TSHA256Digest;
var LH: IHasher;
begin
  LH := nextpas.core.hash.sha256.NewSHA256;
  if ALen > 0 then LH.Write(ABuf, ALen);
  LH.Sum(Result, SHA256_DIGEST_SIZE);
end;

function SHA1Of(const ABuf; ALen: SizeUInt): TSHA1Digest;
var LH: IHasher;
begin
  LH := nextpas.core.hash.sha1.NewSHA1;
  if ALen > 0 then LH.Write(ABuf, ALen);
  LH.Sum(Result, SHA1_DIGEST_SIZE);
end;

function SHA384Of(const ABuf; ALen: SizeUInt): TSHA384Digest;
var LH: IHasher;
begin
  LH := nextpas.core.hash.sha512.NewSHA384;
  if ALen > 0 then LH.Write(ABuf, ALen);
  LH.Sum(Result, SHA384_DIGEST_SIZE);
end;

function SHA512Of(const ABuf; ALen: SizeUInt): TSHA512Digest;
var LH: IHasher;
begin
  LH := nextpas.core.hash.sha512.NewSHA512;
  if ALen > 0 then LH.Write(ABuf, ALen);
  LH.Sum(Result, SHA512_DIGEST_SIZE);
end;

function MD5Of(const ABuf; ALen: SizeUInt): TMD5Digest;
var LH: IHasher;
begin
  LH := nextpas.core.hash.md5.NewMD5;
  if ALen > 0 then LH.Write(ABuf, ALen);
  LH.Sum(Result, MD5_DIGEST_SIZE);
end;

function DigestToHex(const ABuf; ALen: SizeUInt): string;
begin
  Result := nextpas.core.hash.util.DigestToHex(ABuf, ALen);
end;

function WyHash(const AData: Pointer; ALen: SizeUInt; ASeed: UInt64): UInt64;
begin
  Result := nextpas.core.hash.wyhash.WyHash(AData, ALen, ASeed);
end;

function WyHashStr(const S: AnsiString; ASeed: UInt64): UInt64;
begin
  Result := nextpas.core.hash.wyhash.WyHashStr(S, ASeed);
end;

function WyHash32(const AData: Pointer; ALen: SizeUInt; ASeed: UInt64): UInt32;
begin
  Result := nextpas.core.hash.wyhash.WyHash32(AData, ALen, ASeed);
end;

function WyHashStr32(const S: AnsiString; ASeed: UInt64): UInt32;
begin
  Result := nextpas.core.hash.wyhash.WyHashStr32(S, ASeed);
end;

function HashFileHex(AAlgo: THashAlgorithm; const APath: string): string;
begin
  Result := nextpas.core.hash.files.HashFileHex(AAlgo, APath);
end;

function SHA256FileHex(const APath: string): string;
begin
  Result := nextpas.core.hash.files.SHA256FileHex(APath);
end;

function SHA512FileHex(const APath: string): string;
begin
  Result := nextpas.core.hash.files.SHA512FileHex(APath);
end;

function NewHasher(AAlgo: THashAlgorithm): IHasher;
begin
  case Ord(AAlgo) of
    Ord(haMD5):    Result := nextpas.core.hash.md5.NewMD5;
    Ord(haSHA1):   Result := nextpas.core.hash.sha1.NewSHA1;
    Ord(haSHA256): Result := nextpas.core.hash.sha256.NewSHA256;
    Ord(haSHA384): Result := nextpas.core.hash.sha512.NewSHA384;
    Ord(haSHA512): Result := nextpas.core.hash.sha512.NewSHA512;
  else
    raise EArgumentError.Create('NewHasher: invalid hash algorithm');
  end;
end;

end.
