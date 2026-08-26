unit nextpas.core.ssh.rsa;

{** nextpas.core.ssh - RSA PKCS#1 v1.5 签名/验签核（RFC 8332、RFC 8017 §9.2）。
 *
 * hostkey 验签与客户端 publickey 签名共用本单元；DigestInfo 前缀在此
 * 单一来源（历史上 SHA-512 前缀曾带错摘要长度字节且无外部向量覆盖，
 * 真实签名恒验败——现由 openssl 产出黄金向量双向锁定）。
 * 签名 = EM^d mod n（Montgomery 模幂），验签为常数时间比较。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.system.sysutils,
  nextpas.core.base,
  nextpas.core.ssh.errors;

const
  { RFC 8332 签名算法名（裸 ssh-rsa 即 SHA-1 不在现代集合内）}
  SSH_RSA_SIG_SHA256 = 'rsa-sha2-256';
  SSH_RSA_SIG_SHA512 = 'rsa-sha2-512';

  { DigestInfo DER 前缀（RFC 8017 附录）：SEQUENCE 头 ‖ AlgorithmIdentifier
    ‖ NULL 参数 ‖ OCTET STRING 头。末字节是摘要长度（$20/$40）。}
  DIGEST_INFO_SHA256: array[0..18] of Byte = (
    $30, $31, $30, $0d, $06, $09, $60, $86, $48, $01,
    $65, $03, $04, $02, $01, $05, $00, $04, $20);
  DIGEST_INFO_SHA512: array[0..18] of Byte = (
    $30, $51, $30, $0d, $06, $09, $60, $86, $48, $01,
    $65, $03, $04, $02, $03, $05, $00, $04, $40);

{** PKCS#1 v1.5 签名：EM = 00 01 FF..FF 00 ‖ DigestInfo ‖ Hash，
  * 计算 EM^d mod n 并右对齐到模长。AMsgHash 必须与 ADigestInfo 配套。
  * 输入非法或模幂失败返回 False（不抛异常，调用方决定语义）。*}
function RsaSignPkcs1v15(const AN, AD, AMsgHash: TBytes;
  const ADigestInfo: array of Byte; out ASig: TBytes): Boolean;

{** PKCS#1 v1.5 验签：sig^e mod n 重构 EM 与期望值常数时间比较。
  * 自 hostkey 移入（原实现与签名共享同一套编码逻辑）。*}
function RsaVerifyPkcs1v15(const AE, AN, AMsgHash: TBytes;
  const ADigestInfo: array of Byte; ASig: TBytes): Boolean;

implementation

uses
  nextpas.core.crypto.bigint,
  nextpas.core.crypto.constant_time;

{ modexp 结果右对齐到模长（bigint 输出可能剥离前导零）}
function LeftPadTo(const AValue: TBytes; ALen: Integer): TBytes;
var
  LOff: SizeUInt;
begin
  Result := nil;
  SetLength(Result, ALen);
  FillChar(Result[0], SizeUInt(ALen), 0);
  if SizeUInt(Length(AValue)) > SizeUInt(ALen) then
    Exit;
  LOff := SizeUInt(ALen) - SizeUInt(Length(AValue));
  if Length(AValue) > 0 then
    Move(AValue[0], Result[LOff], SizeUInt(Length(AValue)));
end;

{ 构造定长模长的 EMSA-PKCS1-v1_5 编码块；模长过小抛 sekCrypto }
function RsaBuildEm(AModLen: Integer; const ADigestInfo: array of Byte;
  const AMsgHash: TBytes): TBytes;
var
  LTLen, LPsLen, LPos: Integer;
begin
  LTLen := Length(ADigestInfo) + Length(AMsgHash);
  LPsLen := AModLen - 3 - LTLen;
  if LPsLen < 8 then
    raise ESSHError.Create(sekCrypto,
      'ssh rsa: modulus too small for pkcs1 v1.5 encoding');
  SetLength(Result, AModLen);
  FillChar(Result[0], SizeUInt(AModLen), 0);
  Result[1] := $01;
  for LPos := 2 to LPsLen + 1 do
    Result[LPos] := $FF;
  LPos := LPsLen + 2;
  Result[LPos] := $00;
  Inc(LPos);
  Move(ADigestInfo[0], Result[LPos], SizeUInt(Length(ADigestInfo)));
  Inc(LPos, Length(ADigestInfo));
  Move(AMsgHash[0], Result[LPos], SizeUInt(Length(AMsgHash)));
end;

{ 模长能否容纳该 DigestInfo+摘要 的 PKCS#1 v1.5 编码（PS 至少 8 字节）}
function EmFits(AModLen: Integer; const ADigestInfo: array of Byte;
  const AMsgHash: TBytes): Boolean;
begin
  Result := (AModLen >= 11) and
    (AModLen - 3 - Length(ADigestInfo) - Length(AMsgHash) >= 8);
end;

function RsaSignPkcs1v15(const AN, AD, AMsgHash: TBytes;
  const ADigestInfo: array of Byte; out ASig: TBytes): Boolean;
var
  LRaw: TBytes;
  LErr: string;
begin
  Result := False;
  ASig := nil;
  if (Length(AN) = 0) or (Length(AD) = 0) or (Length(AMsgHash) = 0) then
    Exit;
  if not EmFits(Length(AN), ADigestInfo, AMsgHash) then
    Exit;
  if not TryRSAModExpSignPurePascal(
    RsaBuildEm(Length(AN), ADigestInfo, AMsgHash), AN, AD, LRaw, LErr) then
    Exit;
  ASig := LeftPadTo(LRaw, Length(AN));
  Result := True;
end;

function RsaVerifyPkcs1v15(const AE, AN, AMsgHash: TBytes;
  const ADigestInfo: array of Byte; ASig: TBytes): Boolean;
var
  LEmRaw, LEm, LExpected: TBytes;
  LErr: string;
begin
  Result := False;
  if (Length(ASig) = 0) or (SizeUInt(Length(ASig)) > SizeUInt(Length(AN))) then
    Exit;
  if not EmFits(Length(AN), ADigestInfo, AMsgHash) then
    Exit;
  if not TryBigIntModExpFromUnsignedBytes(ASig, AE, AN, LEmRaw, LErr) then
    Exit;

  LExpected := RsaBuildEm(Length(AN), ADigestInfo, AMsgHash);
  LEm := LeftPadTo(LEmRaw, Length(AN));
  Result := TConstantTime.CompareBytes(LEm, LExpected) = 1;
end;

end.
