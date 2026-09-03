unit nextpas.core.crypto.kdf.base;

{$I nextpas.core.settings.inc}

{ nextpas.core.crypto.kdf.base — KDF/口令哈希域公共载体 (L2 crypto)
  Owner: hash/crypto. 纯数据常量/记录, 不依赖 tls. 复用 bytes.ops 单源. }

interface

uses
  nextpas.core.base;

const
  KDF_ARGON2_MIN_MEMORY_KIB = 8;
  KDF_ARGON2_DEFAULT_MEMORY_KIB = 65536;
  KDF_ARGON2_MIN_TIME = 1;
  KDF_ARGON2_MIN_PARALLELISM = 1;
  KDF_ARGON2_MIN_HASHLEN = 4;
  KDF_ARGON2_DEFAULT_SALT_LEN = 16;
  KDF_ARGON2_VERSION = 19;

  KDF_HKDF_MAX_EXPAND = 255; { RFC5869 N<=255 }
  KDF_PBKDF2_DEFAULT_ITERATIONS = 100000;
  KDF_BCRYPT_PBKDF_DEFAULT_ROUNDS = 32;

type
  TKDFAlgo = (kdfHKDF_SHA256, kdfHKDF_SHA384, kdfPBKDF2_SHA256, kdfPBKDF2_SHA1, kdfArgon2id, kdfArgon2i, kdfArgon2d);

  TKDFParams = record
    Algo: TKDFAlgo;
    MemoryKiB: Integer;
    TimeCost: Integer;
    Parallelism: Integer;
    HashLen: Integer;
    Iterations: Integer;
    class function DefaultArgon2id: TKDFParams; static; inline;
    class function DefaultPBKDF2: TKDFParams; static; inline;
  end;

implementation

class function TKDFParams.DefaultArgon2id: TKDFParams; static; inline;
begin
  Result.Algo := kdfArgon2id;
  Result.MemoryKiB := KDF_ARGON2_DEFAULT_MEMORY_KIB;
  Result.TimeCost := 3;
  Result.Parallelism := 1;
  Result.HashLen := 32;
  Result.Iterations := 0;
end;

class function TKDFParams.DefaultPBKDF2: TKDFParams; static; inline;
begin
  Result.Algo := kdfPBKDF2_SHA256;
  Result.MemoryKiB := 0;
  Result.TimeCost := 0;
  Result.Parallelism := 0;
  Result.HashLen := 32;
  Result.Iterations := KDF_PBKDF2_DEFAULT_ITERATIONS;
end;

end.
