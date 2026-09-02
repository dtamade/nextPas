unit nextpas.core.crypto.ec.intf;

{$I nextpas.core.settings.inc}

{ nextpas.core.crypto.ec.intf — 椭圆曲线域接口契约
  base ← intf. 复用 bytes.ops 单源标量钳制/点压缩视图, SecureZero 私钥. }

interface

uses
  nextpas.core.base,
  nextpas.core.crypto.ec.base;

type
  IECKeyExchange = interface
    ['{E3F4A5B6-C7D8-0004-ABCD-1234567890AD}']
    function GenerateKeyPair(out APriv, APub: TBytes): Boolean;
    function ComputeShared(const APriv, APeerPub: TBytes; out AShared: TBytes): Boolean;
  end;

  IECSigner = interface
    ['{E3F4A5B6-C7D8-0005-ABCD-1234567890AE}']
    function Sign(const APriv, AMessage: TBytes; out ASig: TBytes): Boolean;
    function Verify(const APub, AMessage, ASig: TBytes): Boolean;
  end;

function ECIsValidPrivateKey(const APriv: TBytes; ACurve: TECCurve): Boolean; inline;
function ECIsValidPublicKey(const APub: TBytes; ACurve: TECCurve): Boolean; inline;

implementation

uses
  nextpas.core.bytes.ops;

function ECIsValidPrivateKey(const APriv: TBytes; ACurve: TECCurve): Boolean; inline;
begin
  case ACurve of
    ecX25519, ecEd25519: Result := Length(APriv)=EC_X25519_KEY_SIZE;
    ecP256: Result := Length(APriv)=EC_P256_FIELD_SIZE;
    ecP384: Result := Length(APriv)=EC_P384_FIELD_SIZE;
    else Result := Length(APriv) in [EC_X25519_KEY_SIZE, EC_P256_FIELD_SIZE, EC_P384_FIELD_SIZE];
  end;
end;

function ECIsValidPublicKey(const APub: TBytes; ACurve: TECCurve): Boolean; inline;
begin
  case ACurve of
    ecX25519, ecEd25519: Result := Length(APub)=EC_X25519_KEY_SIZE;
    ecP256: Result := Length(APub) in [EC_P256_POINT_COMPRESSED, EC_P256_POINT_UNCOMPRESSED];
    ecP384: Result := Length(APub)=EC_P384_POINT_SIZE;
    else Result := Length(APub) >= EC_X25519_KEY_SIZE;
  end;
end;

end.
