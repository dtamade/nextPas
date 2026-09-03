unit nextpas.core.crypto.kdf.intf;

{$I nextpas.core.settings.inc}

{ nextpas.core.crypto.kdf.intf — KDF 域接口契约
  base ← intf 方向. 复用 bytes.ops 零拷贝视图, SecureZero 释放不丢. }

interface

uses
  nextpas.core.base,
  nextpas.core.crypto.kdf.base;

type
  IKDFDeriver = interface
    ['{C1A2B3C4-D5E6-0002-ABCD-1234567890AB}']
    function Derive(const APassword, ASalt: TBytes; out AOut: TBytes): Boolean;
    function NeedsRehash(const AEncoded: string): Boolean;
  end;

function KDFIsValidArgon2Params(AMemKiB, ATime, APar, AHashLen: Integer): Boolean; inline;
function KDFIsValidPBKDF2Params(AIterations, AKeyLen: Integer): Boolean; inline;

implementation

uses
  nextpas.core.bytes.ops;

function KDFIsValidArgon2Params(AMemKiB, ATime, APar, AHashLen: Integer): Boolean; inline;
begin
  { perf: inline 分支, 零拷贝, 单源 constants }
  Result := (AMemKiB >= KDF_ARGON2_MIN_MEMORY_KIB) and (ATime >= KDF_ARGON2_MIN_TIME)
    and (APar >= KDF_ARGON2_MIN_PARALLELISM) and (AHashLen >= KDF_ARGON2_MIN_HASHLEN);
end;

function KDFIsValidPBKDF2Params(AIterations, AKeyLen: Integer): Boolean; inline;
begin
  Result := (AIterations >= 1) and (AKeyLen >= 1) and (AKeyLen <= 1024*1024);
end;

end.
