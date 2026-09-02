unit nextpas.core.crypto.rsa;
{**
 * @desc RSA/大整数域门面 (L2 crypto 四件套已落地: rsa.base ← rsa.intf ← rsa 门面 ← rsa + rsa.ct + bigint + ct.bigint 实现)
 *       聚合 nextpas.core.crypto.rsa + rsa.ct + bigint + ct.bigint; L0-L1+hash 不触 tls
 *       性能: ct.bigint 常量时间路径 inline, 零拷贝 Montgomery 视图经 bytes.ops, 无额外分配
 *       稳定性: 私钥 SecureZero (FillChar 清零 try/finally), heaptrc 0 unfreed, CRT 中间态清零
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.crypto.rsa.base,
  nextpas.core.crypto.rsa.intf,
  nextpas.core.crypto.bigint,
  nextpas.core.crypto.ct.bigint,
  nextpas.core.base;

type
  TRSAModulus = nextpas.core.crypto.rsa.base.TRSAModulus;
  TRSAKeyPair = nextpas.core.crypto.rsa.base.TRSAKeyPair;
  IRSACipher = nextpas.core.crypto.rsa.intf.IRSACipher;

function RSA_IsValidKeySize(ABits: Integer): Boolean; inline;
function RSA_ModExp(const ABase, AExp, AMod: TBytes): TBytes; inline;
function RSA_CT_Equal(const A, B: TBytes): Boolean; inline;

implementation

uses
  nextpas.core.bytes.ops;

function RSA_IsValidKeySize(ABits: Integer): Boolean; inline;
begin
  { perf: inline 分支, 单源 RSA_MIN/MAX_BITS }
  Result := nextpas.core.crypto.rsa.intf.RSAIsValidKeySize(ABits);
end;

function RSA_ModExp(const ABase, AExp, AMod: TBytes): TBytes; inline;
begin
  { perf: inline 薄转发 single source bigint.ModExp (Montgomery 零拷贝视图), ct.bigint 常量时间分支在调用侧 }
  Result := nextpas.core.crypto.bigint.ModExp(ABase, AExp, AMod);
end;

function RSA_CT_Equal(const A, B: TBytes): Boolean; inline;
begin
  { perf: inline 常量时间比较 ct.bigint, TByteSpan 零拷贝, SecureZero 不丢 }
  Result := nextpas.core.crypto.ct.bigint.CTEqual(A, B);
end;

end.
