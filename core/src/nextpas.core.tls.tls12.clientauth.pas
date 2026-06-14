unit nextpas.core.tls.tls12.clientauth;

{$mode objfpc}{$H+}{$J-}

interface

uses Classes, nextpas.core.tls.x509;

type
  TTLS12ClientCertConfig = record
    CertificateDER: TBytes;
    PrivateKeyDER: TBytes;
    Certificate: TX509Certificate;
  end;

function TLS12BuildClientCertificate(const AConfig: TTLS12ClientCertConfig): TBytes;
function TLS12BuildCertificateVerify(const AConfig: TTLS12ClientCertConfig;
  const ATranscriptHash: TBytes; AUseSHA384: Boolean; out AError: string): TBytes;

implementation

uses nextpas.core.tls.tls12.wire, nextpas.core.tls.tls13.servercertverify, nextpas.core.crypto.hash;

function TLS12BuildClientCertificate(const AConfig: TTLS12ClientCertConfig): TBytes;
var
  LCertLen, LTotalLen: Integer;
begin
  LCertLen := Length(AConfig.CertificateDER);
  LTotalLen := 3 + 3 + LCertLen;

  SetLength(Result, 4 + LTotalLen);
  Result[0] := TLS12_HANDSHAKE_CERTIFICATE;
  Result[1] := Byte(LTotalLen shr 16);
  Result[2] := Byte(LTotalLen shr 8);
  Result[3] := Byte(LTotalLen);
  // certificates_length
  Result[4] := Byte((LCertLen + 3) shr 16);
  Result[5] := Byte((LCertLen + 3) shr 8);
  Result[6] := Byte(LCertLen + 3);
  // single cert length
  Result[7] := Byte(LCertLen shr 16);
  Result[8] := Byte(LCertLen shr 8);
  Result[9] := Byte(LCertLen);
  if LCertLen > 0 then
    Move(AConfig.CertificateDER[0], Result[10], LCertLen);
end;

function TLS12BuildCertificateVerify(const AConfig: TTLS12ClientCertConfig;
  const ATranscriptHash: TBytes; AUseSHA384: Boolean; out AError: string): TBytes;
var
  LSignature: TBytes;
  LScheme: Word;
  LSigLen: Integer;
begin
  AError := '';
  SetLength(Result, 0);

  if AConfig.Certificate.PublicKeyInfo.KeyType = 'ECDSA' then
    LScheme := $0403
  else if AUseSHA384 then
    LScheme := $0501
  else
    LScheme := $0401;

  if not TryBuildTLS13CertificateVerifySignature(LScheme, AConfig.PrivateKeyDER,
    ATranscriptHash, LSignature, AError) then
    Exit;

  LSigLen := Length(LSignature);
  SetLength(Result, 4 + 2 + 2 + LSigLen);
  Result[0] := TLS12_HANDSHAKE_CERTIFICATE_VERIFY;
  Result[1] := 0;
  Result[2] := Byte((4 + LSigLen) shr 8);
  Result[3] := Byte(4 + LSigLen);
  Result[4] := Byte(LScheme shr 8);
  Result[5] := Byte(LScheme);
  Result[6] := Byte(LSigLen shr 8);
  Result[7] := Byte(LSigLen);
  Move(LSignature[0], Result[8], LSigLen);
end;

end.
