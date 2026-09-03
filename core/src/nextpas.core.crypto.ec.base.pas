unit nextpas.core.crypto.ec.base;

{$I nextpas.core.settings.inc}

{ nextpas.core.crypto.ec.base — 椭圆曲线域公共载体 (L2 crypto)
  Owner: crypto. 纯常量/记录, L0-L1+hash, 禁止依赖 tls. 复用 bytes.ops 单源. }

interface

uses
  nextpas.core.base;

const
  EC_X25519_KEY_SIZE = 32;
  EC_X25519_SCALAR_SIZE = 32;
  EC_ED25519_KEY_SIZE = 32;
  EC_ED25519_SIG_SIZE = 64;
  EC_P256_FIELD_SIZE = 32;
  EC_P256_POINT_COMPRESSED = 33;
  EC_P256_POINT_UNCOMPRESSED = 65;
  EC_P384_FIELD_SIZE = 48;
  EC_P384_POINT_SIZE = 97;

type
  TECCurve = (ecX25519, ecEd25519, ecP256, ecP384);

  TECKeyPair = record
    PrivateKey: TBytes;
    PublicKey: TBytes;
    Curve: TECCurve;
    class function Create(const APriv, APub: TBytes; ACurve: TECCurve): TECKeyPair; static; inline;
  end;

  TECPointAffine = record
    X: TBytes;
    Y: TBytes;
    IsInfinity: Boolean;
  end;

implementation

class function TECKeyPair.Create(const APriv, APub: TBytes; ACurve: TECCurve): TECKeyPair; static; inline;
begin
  Result.PrivateKey := APriv;
  Result.PublicKey := APub;
  Result.Curve := ACurve;
end;

end.
