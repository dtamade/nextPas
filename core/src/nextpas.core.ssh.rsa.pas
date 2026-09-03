unit nextpas.core.ssh.rsa;

{** nextpas.core.ssh.rsa - RSA PKCS#1 v1.5 门面（L2 crypto.rsa 单源）.
 *
 *  Facade 薄转发至 nextpas.core.crypto.rsa，保留对外 API 与
 *  DIGEST_INFO_* 常量以兼容 hostkey/session.auth 等历史调用方；
 *  单一来源为 crypto.rsa，禁止在此单元重复实现编解码逻辑。*}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.ssh.errors;

const
  SSH_RSA_SIG_SHA256 = 'rsa-sha2-256';
  SSH_RSA_SIG_SHA512 = 'rsa-sha2-512';

  { 单源转发：常量值与 nextpas.core.crypto.rsa 保持一致 }
  DIGEST_INFO_SHA256: array[0..18] of Byte = (
    $30, $31, $30, $0d, $06, $09, $60, $86, $48, $01,
    $65, $03, $04, $02, $01, $05, $00, $04, $20);
  DIGEST_INFO_SHA384: array[0..18] of Byte = (
    $30, $41, $30, $0d, $06, $09, $60, $86, $48, $01,
    $65, $03, $04, $02, $02, $05, $00, $04, $30);
  DIGEST_INFO_SHA512: array[0..18] of Byte = (
    $30, $51, $30, $0d, $06, $09, $60, $86, $48, $01,
    $65, $03, $04, $02, $03, $05, $00, $04, $40);

function RsaSignPkcs1v15(const AN, AD, AMsgHash: TBytes;
  const ADigestInfo: array of Byte; out ASig: TBytes): Boolean; inline;

function RsaSignPkcs1v15Crt(const AN, AD, AP, AQ, AIqmp: TBytes;
  const AMsgHash: TBytes; const ADigestInfo: array of Byte;
  out ASig: TBytes): Boolean; inline;

function RsaVerifyPkcs1v15(const AE, AN, AMsgHash: TBytes;
  const ADigestInfo: array of Byte; ASig: TBytes): Boolean; inline;

implementation

uses
  nextpas.core.crypto.rsa;

function RsaSignPkcs1v15(const AN, AD, AMsgHash: TBytes;
  const ADigestInfo: array of Byte; out ASig: TBytes): Boolean; inline;
begin
  Result := nextpas.core.crypto.rsa.RsaSignPkcs1v15(AN, AD, AMsgHash, ADigestInfo, ASig);
end;

function RsaSignPkcs1v15Crt(const AN, AD, AP, AQ, AIqmp: TBytes;
  const AMsgHash: TBytes; const ADigestInfo: array of Byte;
  out ASig: TBytes): Boolean; inline;
begin
  Result := nextpas.core.crypto.rsa.RsaSignPkcs1v15Crt(AN, AD, AP, AQ, AIqmp, AMsgHash, ADigestInfo, ASig);
end;

function RsaVerifyPkcs1v15(const AE, AN, AMsgHash: TBytes;
  const ADigestInfo: array of Byte; ASig: TBytes): Boolean; inline;
begin
  Result := nextpas.core.crypto.rsa.RsaVerifyPkcs1v15(AE, AN, AMsgHash, ADigestInfo, ASig);
end;

end.
