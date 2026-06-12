unit nextpas.core.hash.base;

{$mode objfpc}{$H+}

{ nextpas.core.hash.base — 哈希模块基础类型定义

  固定大小 digest 使用静态数组（零堆分配）。公开 size helper
  只依赖本单元类型，implementation 负责拒绝非法算法值。
}

interface

type
  THashAlgorithm = (
    haMD5,
    haSHA1,
    haSHA256,
    haSHA384,
    haSHA512
  );

  TMD5Digest    = array[0..15] of Byte;
  TSHA1Digest   = array[0..19] of Byte;
  TSHA256Digest = array[0..31] of Byte;
  TSHA384Digest = array[0..47] of Byte;
  TSHA512Digest = array[0..63] of Byte;

const
  MD5_DIGEST_SIZE    = 16;
  SHA1_DIGEST_SIZE   = 20;
  SHA256_DIGEST_SIZE = 32;
  SHA384_DIGEST_SIZE = 48;
  SHA512_DIGEST_SIZE = 64;

  MD5_BLOCK_SIZE    = 64;
  SHA1_BLOCK_SIZE   = 64;
  SHA256_BLOCK_SIZE = 64;
  SHA384_BLOCK_SIZE = 128;
  SHA512_BLOCK_SIZE = 128;

function GetDigestSize(AAlgo: THashAlgorithm): SizeUInt;
function GetBlockSize(AAlgo: THashAlgorithm): SizeUInt;

implementation

uses
  nextpas.core.errors;

function GetDigestSize(AAlgo: THashAlgorithm): SizeUInt;
begin
  case Ord(AAlgo) of
    Ord(haMD5):    Result := MD5_DIGEST_SIZE;
    Ord(haSHA1):   Result := SHA1_DIGEST_SIZE;
    Ord(haSHA256): Result := SHA256_DIGEST_SIZE;
    Ord(haSHA384): Result := SHA384_DIGEST_SIZE;
    Ord(haSHA512): Result := SHA512_DIGEST_SIZE;
  else
    raise EArgumentError.Create('GetDigestSize: invalid hash algorithm');
  end;
end;

function GetBlockSize(AAlgo: THashAlgorithm): SizeUInt;
begin
  case Ord(AAlgo) of
    Ord(haMD5):    Result := MD5_BLOCK_SIZE;
    Ord(haSHA1):   Result := SHA1_BLOCK_SIZE;
    Ord(haSHA256): Result := SHA256_BLOCK_SIZE;
    Ord(haSHA384): Result := SHA384_BLOCK_SIZE;
    Ord(haSHA512): Result := SHA512_BLOCK_SIZE;
  else
    raise EArgumentError.Create('GetBlockSize: invalid hash algorithm');
  end;
end;

end.
