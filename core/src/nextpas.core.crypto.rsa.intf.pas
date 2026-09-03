unit nextpas.core.crypto.rsa.intf;

{$I nextpas.core.settings.inc}

{ nextpas.core.crypto.rsa.intf — RSA/大整数域接口契约
  base ← intf. ct.bigint 常量时间路径 inline, 零拷贝 Montgomery 视图, SecureZero 私钥. }

interface

uses
  nextpas.core.base,
  nextpas.core.crypto.rsa.base;

type
  IRSACipher = interface
    ['{F4A5B6C7-D8E9-0006-ABCD-1234567890AF}']
    function Encrypt(const APublicKey, APlaintext: TBytes; out ACiphertext: TBytes): Boolean;
    function Decrypt(const APrivateKey, ACiphertext: TBytes; out APlaintext: TBytes): Boolean;
  end;

  IBigIntOps = interface
    ['{F4A5B6C7-D8E9-0007-ABCD-1234567890B0}']
    function ModExp(const ABase, AExp, AMod: TBytes; out AResult: TBytes): Boolean;
  end;

function RSAIsValidKeySize(ABits: Integer): Boolean; inline;
function RSAModulusLen(ABits: Integer): Integer; inline;

implementation

function RSAIsValidKeySize(ABits: Integer): Boolean; inline;
begin
  Result := (ABits >= RSA_MIN_BITS) and (ABits <= RSA_MAX_BITS) and (ABits mod 8 = 0);
end;

function RSAModulusLen(ABits: Integer): Integer; inline;
begin
  Result := ABits div 8;
end;

end.
