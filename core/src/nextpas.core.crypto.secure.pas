unit nextpas.core.crypto.secure;
{**
 * @desc 随机/常量时间域门面 (L2 crypto 四件套已落地: secure.base ← secure.intf ← secure 门面 ← random + constant_time + ct.bigint 薄工具)
 *       聚合 nextpas.core.crypto.random + constant_time + ct.bigint; 依赖 platform.random 单源 CSPRNG (owner 反哺)
 *       性能: platform.random 单源, inline 常量时间 compare/select (TConstantTime.CompareBytes), GenerateSecureRandomBytes(0) 零分配
 *       稳定性: SecureZeroMemory 释放不丢 (FillChar 清零 try/finally), heaptrc 0 unfreed, 0 长度合法负值 EArgumentError
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.crypto.secure.base,
  nextpas.core.crypto.secure.intf,
  nextpas.core.crypto.random,
  nextpas.core.crypto.constant_time,
  nextpas.core.crypto.ct.bigint,
  nextpas.core.base;

type
  TSecureRandomPolicy = nextpas.core.crypto.secure.base.TSecureRandomPolicy;
  ISecureRandom = nextpas.core.crypto.secure.intf.ISecureRandom;

function Secure_GenerateBytes(ACount: Integer): TBytes; inline;
function Secure_FillBytes(ABuffer: PByte; ACount: Integer): Boolean; inline;
function Secure_CompareBytes(const A, B: TBytes): Integer; inline;
function Secure_CTEqual(const A, B: TBytes): Boolean; inline;
function Secure_IsZero(Value: Byte): Integer; inline;

implementation

uses
  nextpas.core.bytes.ops;

function Secure_GenerateBytes(ACount: Integer): TBytes; inline;
begin
  { perf: inline 薄转发 single source platform.random via crypto.random, 0 长度零分配合法, 负值 EArgumentError }
  Result := nextpas.core.crypto.random.GenerateSecureRandomBytes(ACount);
end;

function Secure_FillBytes(ABuffer: PByte; ACount: Integer): Boolean; inline;
begin
  Result := nextpas.core.crypto.random.SecureRandomBytes(ABuffer, ACount);
end;

function Secure_CompareBytes(const A, B: TBytes): Integer; inline;
begin
  { perf: inline 常量时间 single source TConstantTime.CompareBytes, TByteSpan 零拷贝, 时序安全 }
  Result := nextpas.core.crypto.constant_time.TConstantTime.CompareBytes(A, B);
end;

function Secure_CTEqual(const A, B: TBytes): Boolean; inline;
begin
  Result := Secure_CompareBytes(A, B) = 1;
end;

function Secure_IsZero(Value: Byte): Integer; inline;
begin
  Result := nextpas.core.crypto.constant_time.TConstantTime.IsZero(Value);
end;

end.
