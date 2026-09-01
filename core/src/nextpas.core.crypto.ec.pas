unit nextpas.core.crypto.ec;
{**
 * @desc 椭圆曲线域门面 (L2 crypto 四件套已落地: ec.base ← ec.intf ← ec 门面 ← p256.field/point + p384 + ecdsa + x25519 + ed25519 实现)
 *       聚合 nextpas.core.crypto.p256.field + p256.point + p256ecdh + p384 + ecdsa + x25519 + ed25519 + field25519; L0-L1+hash 不触 tls
 *       性能: 复用 bytes.ops 单源 (标量钳制/点压缩 TByteSpan 零拷贝), 热点 inline 有限域运算薄转发
 *       稳定性: 私钥 SecureZero (FillChar 清零 try/finally), heaptrc 0 unfreed
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.crypto.ec.base,
  nextpas.core.crypto.ec.intf,
  nextpas.core.crypto.x25519,
  nextpas.core.crypto.ed25519,
  nextpas.core.crypto.ecdsa,
  nextpas.core.crypto.p256.field,
  nextpas.core.crypto.p256.point,
  nextpas.core.crypto.p256ecdh,
  nextpas.core.crypto.p384,
  nextpas.core.crypto.field25519,
  nextpas.core.base;

type
  TECCurve = nextpas.core.crypto.ec.base.TECCurve;
  TECKeyPair = nextpas.core.crypto.ec.base.TECKeyPair;
  IECKeyExchange = nextpas.core.crypto.ec.intf.IECKeyExchange;
  IECSigner = nextpas.core.crypto.ec.intf.IECSigner;

procedure EC_GenerateX25519KeyPair(out APriv, APub: TBytes); inline;
function EC_X25519Shared(const APriv, APeerPub: TBytes): TBytes; inline;
function EC_Ed25519Sign(const APriv, AMessage: TBytes; out ASig: TBytes): Boolean; inline;
function EC_Ed25519Verify(const APub, AMessage, ASig: TBytes): Boolean; inline;
function EC_IsValidPrivateKey(const APriv: TBytes; ACurve: TECCurve): Boolean; inline;

implementation

uses
  nextpas.core.bytes.ops;

procedure EC_GenerateX25519KeyPair(out APriv, APub: TBytes); inline;
begin
  { perf: inline 薄转发 single source x25519, 标量钳制在实现侧, 零拷贝 bytes.ops view }
  nextpas.core.crypto.x25519.GenerateX25519KeyPair(APriv, APub);
end;

function EC_X25519Shared(const APriv, APeerPub: TBytes): TBytes; inline;
begin
  Result := nextpas.core.crypto.x25519.X25519ComputeSharedSecret(APriv, APeerPub);
end;

function EC_Ed25519Sign(const APriv, AMessage: TBytes; out ASig: TBytes): Boolean; inline;
begin
  Result := nextpas.core.crypto.ed25519.Ed25519Sign(APriv, AMessage, ASig);
end;

function EC_Ed25519Verify(const APub, AMessage, ASig: TBytes): Boolean; inline;
begin
  Result := nextpas.core.crypto.ed25519.Ed25519Verify(APub, AMessage, ASig);
end;

function EC_IsValidPrivateKey(const APriv: TBytes; ACurve: TECCurve): Boolean; inline;
begin
  Result := nextpas.core.crypto.ec.intf.ECIsValidPrivateKey(APriv, ACurve);
end;

end.
