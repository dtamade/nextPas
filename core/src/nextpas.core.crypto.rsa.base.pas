unit nextpas.core.crypto.rsa.base;

{$I nextpas.core.settings.inc}

{ nextpas.core.crypto.rsa.base — RSA/大整数域公共载体 (L2 crypto)
  Owner: crypto. 纯常量/记录, L0-L1+hash, 禁止依赖 tls. }

interface

uses
  nextpas.core.base;

const
  RSA_MIN_BITS = 1024;
  RSA_DEFAULT_BITS = 2048;
  RSA_MAX_BITS = 4096;
  RSA_PKCS1_BLOCK_TYPE_1 = 1;
  RSA_PKCS1_BLOCK_TYPE_2 = 2;
  RSA_CT_WINDOW_BITS = 4;

type
  TRSAKeyBits = 1024..4096;

  TRSAModulus = record
    Bytes: TBytes;
    Bits: Integer;
    class function FromBytes(const AMod: TBytes): TRSAModulus; static; inline;
  end;

  TRSAKeyPair = record
    Modulus: TBytes;
    PublicExp: TBytes;
    PrivateExp: TBytes;
    Prime1: TBytes;
    Prime2: TBytes;
  end;

implementation

class function TRSAModulus.FromBytes(const AMod: TBytes): TRSAModulus; static; inline;
begin
  Result.Bytes := AMod;
  Result.Bits := Length(AMod)*8;
end;

end.
