unit nextpas.core.crypto.rsa;

{** nextpas.core.crypto.rsa - RSA PKCS#1 v1.5 单一来源（L2）。
 *
 *  Owner: nextpas.core.crypto。整合 ssh.rsa 签名/验签核与
 *  RSAES-PKCS1-v1_5 加密；DigestInfo 前缀在此单一来源
 *  （历史上 SHA-512 前缀曾带错长度且无向量覆盖，现由 openssl
 *  黄金向量双向锁定）。依赖仅 L0 base/text + L1/L2 crypto
 *  bigint/random/constant_time；零拷贝 via bytes.ops/Move，
 *  热路径 inline。
 *}

{$mode objfpc}{$H+}{$J-}
{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.text.format;

const
  SSH_RSA_SIG_SHA256 = 'rsa-sha2-256';
  SSH_RSA_SIG_SHA512 = 'rsa-sha2-512';

  { DigestInfo DER 前缀（RFC 8017 附录）：SEQUENCE 头 ‖ AlgorithmIdentifier
    ‖ NULL 参数 ‖ OCTET STRING 头。末字节是摘要长度 ($20/$30/$40)。 }
  DIGEST_INFO_SHA256: array[0..18] of Byte = (
    $30, $31, $30, $0d, $06, $09, $60, $86, $48, $01,
    $65, $03, $04, $02, $01, $05, $00, $04, $20);
  DIGEST_INFO_SHA384: array[0..18] of Byte = (
    $30, $41, $30, $0d, $06, $09, $60, $86, $48, $01,
    $65, $03, $04, $02, $02, $05, $00, $04, $30);
  DIGEST_INFO_SHA512: array[0..18] of Byte = (
    $30, $51, $30, $0d, $06, $09, $60, $86, $48, $01,
    $65, $03, $04, $02, $03, $05, $00, $04, $40);

  { 兼容别名：供 tls.x509verify / tls.tls13.servercertverify 复用 }
  SHA256_DIGESTINFO_PREFIX: array[0..18] of Byte = (
    $30, $31, $30, $0d, $06, $09, $60, $86, $48, $01,
    $65, $03, $04, $02, $01, $05, $00, $04, $20);
  SHA384_DIGESTINFO_PREFIX: array[0..18] of Byte = (
    $30, $41, $30, $0d, $06, $09, $60, $86, $48, $01,
    $65, $03, $04, $02, $02, $05, $00, $04, $30);
  SHA512_DIGESTINFO_PREFIX: array[0..18] of Byte = (
    $30, $51, $30, $0d, $06, $09, $60, $86, $48, $01,
    $65, $03, $04, $02, $03, $05, $00, $04, $40);
  SHA256_DIGEST_INFO: array[0..18] of Byte = (
    $30, $31, $30, $0d, $06, $09, $60, $86, $48, $01,
    $65, $03, $04, $02, $01, $05, $00, $04, $20);

function TryRSAES_PKCS1v15_Encode(
  const AMessage: TBytes;
  AKeyOctetLength: Integer;
  out AEncodedMessage: TBytes;
  out AError: string
): Boolean;

function TryRSAES_PKCS1v15_Encrypt(
  const AMessage: TBytes;
  const AModulus: TBytes;
  const APublicExponent: TBytes;
  out ACiphertext: TBytes;
  out AError: string
): Boolean;

{** PKCS#1 v1.5 签名：EM = 00 01 FF..FF 00 ‖ DigestInfo ‖ Hash，
  * 计算 EM^d mod n 并右对齐到模长。AMsgHash 必须与 ADigestInfo 配套。
  * 输入非法或模幂失败返回 False（不抛异常）。*}
function RsaSignPkcs1v15(const AN, AD, AMsgHash: TBytes;
  const ADigestInfo: array of Byte; out ASig: TBytes): Boolean;

{** PKCS#1 v1.5 CRT 签名：利用 p/q/iqmp 与中国剩余定理加速。*}
function RsaSignPkcs1v15Crt(const AN, AD, AP, AQ, AIqmp: TBytes;
  const AMsgHash: TBytes; const ADigestInfo: array of Byte;
  out ASig: TBytes): Boolean;

{** PKCS#1 v1.5 验签：sig^e mod n 重构 EM 与期望值常数时间比较。*}
function RsaVerifyPkcs1v15(const AE, AN, AMsgHash: TBytes;
  const ADigestInfo: array of Byte; ASig: TBytes): Boolean;

implementation

uses
  nextpas.core.crypto.random,
  nextpas.core.crypto.bigint,
  nextpas.core.crypto.constant_time,
  nextpas.core.crypto.errors;

function TryRSAES_PKCS1v15_Encode(
  const AMessage: TBytes;
  AKeyOctetLength: Integer;
  out AEncodedMessage: TBytes;
  out AError: string
): Boolean;
var
  LMLen, LPSLen, I: Integer;
  LRandomByte: Byte;
begin
  SetLength(AEncodedMessage, 0);
  AError := '';
  Result := False;
  LMLen := Length(AMessage);
  if LMLen > AKeyOctetLength - 11 then
  begin
    AError := TextFormat('Message too long for RSAES-PKCS1-v1_5 (mLen=%d, k=%d, max=%d)',
      [LMLen, AKeyOctetLength, AKeyOctetLength - 11]);
    Exit;
  end;
  LPSLen := AKeyOctetLength - LMLen - 3;
  SetLength(AEncodedMessage, AKeyOctetLength);
  AEncodedMessage[0] := $00;
  AEncodedMessage[1] := $02;
  for I := 0 to LPSLen - 1 do
  begin
    repeat
      SecureRandomBytes(@LRandomByte, 1);
    until LRandomByte <> 0;
    AEncodedMessage[2 + I] := LRandomByte;
  end;
  AEncodedMessage[2 + LPSLen] := $00;
  if LMLen > 0 then
    Move(AMessage[0], AEncodedMessage[3 + LPSLen], LMLen);
  Result := True;
end;

function TryRSAES_PKCS1v15_Encrypt(
  const AMessage: TBytes;
  const AModulus: TBytes;
  const APublicExponent: TBytes;
  out ACiphertext: TBytes;
  out AError: string
): Boolean;
var
  LEncoded: TBytes;
  LKeyLen: Integer;
  LResult: TBytes;
begin
  SetLength(ACiphertext, 0);
  AError := '';
  Result := False;
  LKeyLen := Length(AModulus);
  if (LKeyLen < 64) then
  begin
    AError := 'RSA modulus too short';
    Exit;
  end;
  if not TryRSAES_PKCS1v15_Encode(AMessage, LKeyLen, LEncoded, AError) then
    Exit;
  if not TryBigIntModExpFromUnsignedBytes(LEncoded, APublicExponent, AModulus, LResult, AError) then
  begin
    AError := 'RSA modular exponentiation failed: ' + AError;
    Exit;
  end;
  if not TryBigIntToFixedLengthFromUnsignedBytes(LResult, LKeyLen, ACiphertext, AError) then
  begin
    AError := 'RSA ciphertext sizing failed: ' + AError;
    Exit;
  end;
  Result := True;
end;

{ --- PKCS#1 v1.5 EMSA helpers (inline/zero-copy, single source) --- }

function LeftPadTo(const AValue: TBytes; ALen: Integer): TBytes; inline;
var
  LOff: SizeUInt;
begin
  Result := nil;
  SetLength(Result, ALen);
  if ALen > 0 then
    FillChar(Result[0], SizeUInt(ALen), 0);
  if SizeUInt(Length(AValue)) > SizeUInt(ALen) then
    Exit;
  LOff := SizeUInt(ALen) - SizeUInt(Length(AValue));
  if Length(AValue) > 0 then
    Move(AValue[0], Result[LOff], SizeUInt(Length(AValue)));
end;

function RsaBuildEm(AModLen: Integer; const ADigestInfo: array of Byte;
  const AMsgHash: TBytes): TBytes; inline;
var
  LTLen, LPsLen, LPos: Integer;
begin
  LTLen := Length(ADigestInfo) + Length(AMsgHash);
  LPsLen := AModLen - 3 - LTLen;
  if LPsLen < 8 then
    RaiseCryptoError(cecInvalidArgument, 'rsa: modulus too small for pkcs1 v1.5 encoding');
  SetLength(Result, AModLen);
  if AModLen > 0 then
    FillChar(Result[0], SizeUInt(AModLen), 0);
  Result[1] := $01;
  for LPos := 2 to LPsLen + 1 do
    Result[LPos] := $FF;
  LPos := LPsLen + 2;
  Result[LPos] := $00;
  Inc(LPos);
  if Length(ADigestInfo) > 0 then
    Move(ADigestInfo[0], Result[LPos], SizeUInt(Length(ADigestInfo)));
  Inc(LPos, Length(ADigestInfo));
  if Length(AMsgHash) > 0 then
    Move(AMsgHash[0], Result[LPos], SizeUInt(Length(AMsgHash)));
end;

function EmFits(AModLen: Integer; const ADigestInfo: array of Byte;
  const AMsgHash: TBytes): Boolean; inline;
begin
  Result := (AModLen >= 11) and
    (AModLen - 3 - Length(ADigestInfo) - Length(AMsgHash) >= 8);
end;

function BytesSubOne(const AValue: TBytes): TBytes; inline;
var
  I, LFirstNonZero: Integer;
begin
  if Length(AValue) = 0 then
    Exit(nil);
  Result := Copy(AValue, 0, Length(AValue));
  I := High(Result);
  while (I >= 0) and (Result[I] = 0) do
  begin
    Result[I] := $FF;
    Dec(I);
  end;
  if I >= 0 then
    Dec(Result[I])
  else
  begin
    SetLength(Result, 0);
    Exit;
  end;
  LFirstNonZero := 0;
  while (LFirstNonZero < High(Result)) and (Result[LFirstNonZero] = 0) do
    Inc(LFirstNonZero);
  if LFirstNonZero > 0 then
    Result := Copy(Result, LFirstNonZero, Length(Result) - LFirstNonZero);
  if Length(Result) = 0 then
  begin
    SetLength(Result, 1);
    Result[0] := 0;
  end;
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
  if not TryRSAModExpSignPurePascal(RsaBuildEm(Length(AN), ADigestInfo, AMsgHash), AN, AD, LRaw, LErr) then
    Exit;
  ASig := LeftPadTo(LRaw, Length(AN));
  Result := True;
end;

function RsaSignPkcs1v15Crt(const AN, AD, AP, AQ, AIqmp: TBytes;
  const AMsgHash: TBytes; const ADigestInfo: array of Byte;
  out ASig: TBytes): Boolean;
var
  LEm, LPMinus1, LQMinus1, LDp, LDq, LM1, LM2, LDiff, LH, LHq, LSigRaw: TBytes;
  LErr: string;
begin
  Result := False;
  ASig := nil;
  if (Length(AN) = 0) or (Length(AD) = 0) or (Length(AP) = 0) or
     (Length(AQ) = 0) or (Length(AIqmp) = 0) or (Length(AMsgHash) = 0) then
    Exit;
  if not EmFits(Length(AN), ADigestInfo, AMsgHash) then
    Exit;
  LEm := RsaBuildEm(Length(AN), ADigestInfo, AMsgHash);
  LPMinus1 := BytesSubOne(AP);
  LQMinus1 := BytesSubOne(AQ);
  if (Length(LPMinus1) = 0) or (Length(LQMinus1) = 0) then
    Exit;
  if not TryBigIntModFromUnsignedBytes(AD, LPMinus1, LDp, LErr) then
    Exit;
  if not TryBigIntModFromUnsignedBytes(AD, LQMinus1, LDq, LErr) then
    Exit;
  if (Length(LDp) = 0) or (Length(LDq) = 0) then
    Exit;
  if not TryBigIntModExpFromUnsignedBytes(LEm, LDp, AP, LM1, LErr) then
    Exit;
  if not TryBigIntModExpFromUnsignedBytes(LEm, LDq, AQ, LM2, LErr) then
    Exit;
  if not TryBigIntSubtractModuloFromUnsignedBytes(LM1, LM2, AP, LDiff, LErr) then
    Exit;
  if not TryBigIntModMulFromUnsignedBytes(AIqmp, LDiff, AP, LH, LErr) then
    Exit;
  if not TryBigIntMulFromUnsignedBytes(LH, AQ, LHq, LErr) then
    Exit;
  if not TryBigIntAddFromUnsignedBytes(LM2, LHq, LSigRaw, LErr) then
    Exit;
  ASig := LeftPadTo(LSigRaw, Length(AN));
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
