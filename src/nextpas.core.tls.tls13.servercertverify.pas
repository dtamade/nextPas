{**
 * Unit: nextpas.core.tls.tls13.servercertverify
 * Purpose: TLS 1.3 Server CertificateVerify 消息辅助构建（纯 Pascal）
 *
 * 说明：
 * - 本单元只负责 CertificateVerify 相关的线协议编码与签名算法选择
 * - 不依赖外部 TLS 库
 * - 提供 RSA-PSS / RSA-PKCS1(SHA-256) 的真实私钥签名实现
 *}

unit nextpas.core.tls.tls13.servercertverify;

{$mode ObjFPC}{$H+}
{$WARN 5093 off} // Suppress false-positive "Function result not initialized" for managed types

interface

uses
  SysUtils,
  nextpas.core.tls.tls13.wire,
  nextpas.core.tls.tls13.clienthello.parser,
  nextpas.core.tls.x509;

function TrySelectTLS13ServerCertificateVerifyScheme(
  const AClientHello: TTLS13ClientHelloInfo;
  out ASignatureScheme: Word;
  out AError: string
): Boolean;

function TrySelectTLS13ServerCertificateVerifySchemeForKeyType(
  const AClientHello: TTLS13ClientHelloInfo;
  const ALeafKeyType: string;
  out ASignatureScheme: Word;
  out AError: string
): Boolean;

function TrySelectTLS13ServerCertificateVerifySchemeForKeyTypeAndCipherSuite(
  const AClientHello: TTLS13ClientHelloInfo;
  const ALeafKeyType: string;
  ACipherSuite: Word;
  out ASignatureScheme: Word;
  out AError: string
): Boolean;

function BuildTLS13ServerCertificateVerifyInputSHA256(
  const ATranscriptHash: TBytes
): TBytes;

function BuildTLS13ClientCertificateVerifyInput(
  const ATranscriptHash: TBytes
): TBytes;

function BuildTLS13CertificateVerifyHandshake(
  ASignatureScheme: Word;
  const ASignature: TBytes
): TBytes;

function BuildTLS13PlaceholderSignatureFromTranscriptHash(
  const ATranscriptHash: TBytes;
  ATargetLength: Integer
): TBytes;

function TryParseTLS13CertificateVerifyHandshake(
  const AHandshakeMessage: TBytes;
  out ASignatureScheme: Word;
  out ASignature: TBytes;
  out AError: string
): Boolean;

function TryVerifyTLS13CertificateVerifySignature(
  ASignatureScheme: Word;
  const APublicKeyInfo: TX509PublicKeyInfo;
  const ACertificateVerifyInput: TBytes;
  const ASignature: TBytes;
  out AError: string
): Boolean;

function TryBuildTLS13CertificateVerifySignature(
  ASignatureScheme: Word;
  const APrivateKeyBlob: TBytes;
  const ACertificateVerifyInput: TBytes;
  out ASignature: TBytes;
  out AError: string
): Boolean;

function TryVerifyRSAPKCS1v15SignatureSHA256(
  const AMessage, ASignature, AModulus, APublicExponent: TBytes;
  out AError: string
): Boolean;

function TryVerifyRSAPKCS1v15SignatureSHA384(
  const AMessage, ASignature, AModulus, APublicExponent: TBytes;
  out AError: string
): Boolean;

function TryVerifyRSAPSSSignatureSHA256(
  const AMessage, ASignature, AModulus, APublicExponent: TBytes;
  out AError: string
): Boolean;

function TryVerifyRSAPSSSignatureSHA384(
  const AMessage, ASignature, AModulus, APublicExponent: TBytes;
  out AError: string
): Boolean;

function IsECDSAPrivateKey(const APrivateKeyBlob: TBytes): Boolean;

implementation

uses
  nextpas.core.tls.errors,
  nextpas.core.tls.asn1,
  nextpas.core.tls.pem,
  nextpas.core.crypto.hash,
  nextpas.core.tls.random,
  nextpas.core.tls.tls13.keyschedule,
  nextpas.core.crypto.bigint,
  nextpas.core.crypto.ecdsa,
  nextpas.core.crypto.p384,
  nextpas.core.crypto.ed25519,
  nextpas.core.crypto.rsa.ct;

const
  TLS13_SERVER_CERTVERIFY_CONTEXT = 'TLS 1.3, server CertificateVerify';
  TLS13_CLIENT_CERTVERIFY_CONTEXT = 'TLS 1.3, client CertificateVerify';
  OID_RSA_ENCRYPTION = '1.2.840.113549.1.1.1';
  OID_RSASSA_PSS = '1.2.840.113549.1.1.10';
  OID_EC_PUBLIC_KEY = '1.2.840.10045.2.1';
  OID_EC_SECP256R1 = '1.2.840.10045.3.1.7';

  SHA256_DIGESTINFO_PREFIX: array[0..18] of Byte = (
    $30, $31, $30, $0D,
    $06, $09, $60, $86, $48, $01, $65, $03, $04, $02, $01,
    $05, $00,
    $04, $20
  );

  SHA384_DIGESTINFO_PREFIX: array[0..18] of Byte = (
    $30, $41, $30, $0D,
    $06, $09, $60, $86, $48, $01, $65, $03, $04, $02, $02,
    $05, $00,
    $04, $30
  );

function BytesToAnsiString(const AData: TBytes): AnsiString;
begin
  SetLength(Result, Length(AData));
  if Length(AData) > 0 then
    Move(AData[0], Result[1], Length(AData));
end;

function BlobLooksLikePEM(const ABlob: TBytes): Boolean;
var
  LText: AnsiString;
begin
  LText := BytesToAnsiString(ABlob);
  Result := Pos('-----BEGIN', string(LText)) > 0;
end;

function StripLeadingZeroBytes(const AData: TBytes): TBytes;
var
  I: Integer;
begin
  I := 0;
  while (I < Length(AData)) and (AData[I] = 0) do
    Inc(I);

  if I >= Length(AData) then
  begin
    SetLength(Result, 1);
    Result[0] := 0;
    Exit;
  end;

  Result := Copy(AData, I, Length(AData) - I);
end;

function UnsignedBitLength(const AData: TBytes): Integer;
var
  LTrimmed: TBytes;
  LFirst: Byte;
begin
  LTrimmed := StripLeadingZeroBytes(AData);
  if Length(LTrimmed) = 0 then
    Exit(0);

  if (Length(LTrimmed) = 1) and (LTrimmed[0] = 0) then
    Exit(0);

  LFirst := LTrimmed[0];
  Result := (Length(LTrimmed) - 1) * 8;
  while LFirst > 0 do
  begin
    Inc(Result);
    LFirst := LFirst shr 1;
  end;
end;

function CompareUnsignedBytes(const ALeft, ARight: TBytes): Integer;
var
  LLeft: TBytes;
  LRight: TBytes;
  I: Integer;
begin
  LLeft := StripLeadingZeroBytes(ALeft);
  LRight := StripLeadingZeroBytes(ARight);

  if Length(LLeft) < Length(LRight) then
    Exit(-1);
  if Length(LLeft) > Length(LRight) then
    Exit(1);

  for I := 0 to Length(LLeft) - 1 do
  begin
    if LLeft[I] < LRight[I] then
      Exit(-1);
    if LLeft[I] > LRight[I] then
      Exit(1);
  end;

  Result := 0;
end;

function UnsignedBytesEqual(const ALeft, ARight: TBytes): Boolean;
var
  LLeft: TBytes;
  LRight: TBytes;
  I: Integer;
begin
  LLeft := StripLeadingZeroBytes(ALeft);
  LRight := StripLeadingZeroBytes(ARight);

  if Length(LLeft) <> Length(LRight) then
    Exit(False);

  for I := 0 to Length(LLeft) - 1 do
  begin
    if LLeft[I] <> LRight[I] then
      Exit(False);
  end;

  Result := True;
end;

function UnsignedIsZero(const AData: TBytes): Boolean;
var
  LTrimmed: TBytes;
begin
  LTrimmed := StripLeadingZeroBytes(AData);
  Result := (Length(LTrimmed) = 1) and (LTrimmed[0] = 0);
end;

function UnsignedIsOne(const AData: TBytes): Boolean;
var
  LTrimmed: TBytes;
begin
  LTrimmed := StripLeadingZeroBytes(AData);
  Result := (Length(LTrimmed) = 1) and (LTrimmed[0] = 1);
end;

function TryUnsignedSubtractOne(const AData: TBytes; out AResult: TBytes): Boolean;
var
  LValue: TBytes;
  I: Integer;
begin
  SetLength(AResult, 0);
  Result := False;

  LValue := StripLeadingZeroBytes(AData);
  if UnsignedIsZero(LValue) then
    Exit;

  AResult := Copy(LValue, 0, Length(LValue));
  I := High(AResult);
  while I >= 0 do
  begin
    if AResult[I] > 0 then
    begin
      Dec(AResult[I]);
      AResult := StripLeadingZeroBytes(AResult);
      Exit(True);
    end;

    AResult[I] := $FF;
    Dec(I);
  end;
end;

function TryValidateRSACRTComponents(
  const AModulus: TBytes;
  const APrivateExponent: TBytes;
  const AP, AQ, ADP, ADQ, AQInv: TBytes;
  out AError: string
): Boolean;
var
  LProduct: TBytes;
  LProductFixed: TBytes;
  LQInvCheck: TBytes;
  LPMinusOne: TBytes;
  LQMinusOne: TBytes;
  LDModPMinusOne: TBytes;
  LDModQMinusOne: TBytes;
  LOne: TBytes;
begin
  AError := '';
  Result := False;

  if (Length(AModulus) = 0) or ((Length(AModulus) = 1) and (AModulus[0] = 0)) then
  begin
    AError := 'RSA CRT validation failed: modulus is empty';
    Exit;
  end;

  if (Length(AP) = 0) or (Length(AQ) = 0) or (Length(AQInv) = 0) then
  begin
    AError := 'RSA CRT validation failed: missing CRT fields';
    Exit;
  end;

  if UnsignedIsZero(APrivateExponent) then
  begin
    AError := 'RSA CRT validation failed: private exponent is zero';
    Exit;
  end;

  if UnsignedBytesEqual(AP, AQ) then
  begin
    AError := 'RSA CRT validation failed: p and q must be distinct';
    Exit;
  end;

  if UnsignedIsZero(AP) or UnsignedIsZero(AQ) or UnsignedIsOne(AP) or UnsignedIsOne(AQ) then
  begin
    AError := 'RSA CRT validation failed: p/q must be > 1';
    Exit;
  end;

  if UnsignedIsZero(ADP) or UnsignedIsZero(ADQ) then
  begin
    AError := 'RSA CRT validation failed: dp/dq must be non-zero';
    Exit;
  end;

  if ((AP[High(AP)] and 1) = 0) or ((AQ[High(AQ)] and 1) = 0) then
  begin
    AError := 'RSA CRT validation failed: p/q must be odd';
    Exit;
  end;

  if not TryBigIntMulFromUnsignedBytes(AP, AQ, LProduct, AError) then
  begin
    AError := 'RSA CRT validation failed (p*q): ' + AError;
    Exit;
  end;

  if not TryBigIntToFixedLengthFromUnsignedBytes(LProduct, Length(AModulus), LProductFixed, AError) then
  begin
    AError := 'RSA CRT validation failed (p*q sizing): ' + AError;
    Exit;
  end;

  if not UnsignedBytesEqual(LProductFixed, AModulus) then
  begin
    AError := 'RSA CRT validation failed: p*q does not match modulus';
    Exit;
  end;

  if not TryBigIntModMulFromUnsignedBytes(AQ, AQInv, AP, LQInvCheck, AError) then
  begin
    AError := 'RSA CRT validation failed (qInv): ' + AError;
    Exit;
  end;

  SetLength(LOne, 1);
  LOne[0] := 1;
  if not UnsignedBytesEqual(LQInvCheck, LOne) then
  begin
    AError := 'RSA CRT validation failed: qInv is inconsistent with q mod p';
    Exit;
  end;

  if not TryBigIntModFromUnsignedBytes(ADP, AP, LQInvCheck, AError) then
  begin
    AError := 'RSA CRT validation failed (dp range): ' + AError;
    Exit;
  end;
  if not UnsignedBytesEqual(LQInvCheck, ADP) then
  begin
    AError := 'RSA CRT validation failed: dp is out of range for modulus p';
    Exit;
  end;

  if not TryBigIntModFromUnsignedBytes(ADQ, AQ, LQInvCheck, AError) then
  begin
    AError := 'RSA CRT validation failed (dq range): ' + AError;
    Exit;
  end;
  if not UnsignedBytesEqual(LQInvCheck, ADQ) then
  begin
    AError := 'RSA CRT validation failed: dq is out of range for modulus q';
    Exit;
  end;

  if not TryUnsignedSubtractOne(AP, LPMinusOne) then
  begin
    AError := 'RSA CRT validation failed: invalid p for exponent congruence';
    Exit;
  end;

  if not TryUnsignedSubtractOne(AQ, LQMinusOne) then
  begin
    AError := 'RSA CRT validation failed: invalid q for exponent congruence';
    Exit;
  end;

  if not TryBigIntModFromUnsignedBytes(APrivateExponent, LPMinusOne, LDModPMinusOne, AError) then
  begin
    AError := 'RSA CRT validation failed (dp congruence): ' + AError;
    Exit;
  end;
  if not UnsignedBytesEqual(LDModPMinusOne, ADP) then
  begin
    AError := 'RSA CRT validation failed: dp is inconsistent with private exponent';
    Exit;
  end;

  if not TryBigIntModFromUnsignedBytes(APrivateExponent, LQMinusOne, LDModQMinusOne, AError) then
  begin
    AError := 'RSA CRT validation failed (dq congruence): ' + AError;
    Exit;
  end;
  if not UnsignedBytesEqual(LDModQMinusOne, ADQ) then
  begin
    AError := 'RSA CRT validation failed: dq is inconsistent with private exponent';
    Exit;
  end;

  Result := True;
end;

function TryParseRSAPrivateKeyPKCS1(
  const ADER: TBytes;
  out AModulus: TBytes;
  out APrivateExponent: TBytes;
  out AError: string
): Boolean;
var
  LReader: TASN1Reader;
  LRoot: TASN1Node;
begin
  SetLength(AModulus, 0);
  SetLength(APrivateExponent, 0);
  AError := '';
  Result := False;

  if Length(ADER) = 0 then
  begin
    AError := 'PKCS#1 DER is empty';
    Exit;
  end;

  LReader := TASN1Reader.Create(ADER);
  try
    try
      LRoot := LReader.Parse;
    except
      on E: Exception do
      begin
        AError := 'PKCS#1 parse failed: ' + E.Message;
        Exit;
      end;
    end;

    try
      if (LRoot = nil) or (not LRoot.IsSequence) then
      begin
        AError := 'PKCS#1 root is not ASN.1 SEQUENCE';
        Exit;
      end;

      if LRoot.ChildCount < 4 then
      begin
        AError := 'PKCS#1 RSA private key must contain at least 4 fields';
        Exit;
      end;

      if (not LRoot.GetChild(1).IsInteger) or (not LRoot.GetChild(3).IsInteger) then
      begin
        AError := 'PKCS#1 RSA key fields (modulus/privateExponent) are invalid';
        Exit;
      end;

      AModulus := StripLeadingZeroBytes(LRoot.GetChild(1).AsBigInteger);
      APrivateExponent := StripLeadingZeroBytes(LRoot.GetChild(3).AsBigInteger);

      if (Length(AModulus) = 0) or ((Length(AModulus) = 1) and (AModulus[0] = 0)) then
      begin
        AError := 'PKCS#1 modulus is empty';
        Exit;
      end;

      if (Length(APrivateExponent) = 0) or ((Length(APrivateExponent) = 1) and (APrivateExponent[0] = 0)) then
      begin
        AError := 'PKCS#1 private exponent is empty';
        Exit;
      end;

      Result := True;
    finally
      LRoot.Free;
    end;
  finally
    LReader.Free;
  end;
end;

function TryParseRSAPrivateKeyPKCS1CRT(
  const ADER: TBytes;
  out AP, AQ, ADP, ADQ, AQInv: TBytes;
  out AError: string
): Boolean;
var
  LReader: TASN1Reader;
  LRoot: TASN1Node;
begin
  SetLength(AP, 0);
  SetLength(AQ, 0);
  SetLength(ADP, 0);
  SetLength(ADQ, 0);
  SetLength(AQInv, 0);
  AError := '';
  Result := False;

  if Length(ADER) = 0 then
  begin
    AError := 'PKCS#1 DER is empty';
    Exit;
  end;

  LReader := TASN1Reader.Create(ADER);
  try
    try
      LRoot := LReader.Parse;
    except
      on E: Exception do
      begin
        AError := 'PKCS#1 parse failed: ' + E.Message;
        Exit;
      end;
    end;

    try
      if (LRoot = nil) or (not LRoot.IsSequence) then
      begin
        AError := 'PKCS#1 root is not ASN.1 SEQUENCE';
        Exit;
      end;

      if LRoot.ChildCount < 9 then
      begin
        AError := 'PKCS#1 RSA CRT fields are incomplete';
        Exit;
      end;

      if (not LRoot.GetChild(4).IsInteger) or
        (not LRoot.GetChild(5).IsInteger) or
        (not LRoot.GetChild(6).IsInteger) or
        (not LRoot.GetChild(7).IsInteger) or
        (not LRoot.GetChild(8).IsInteger) then
      begin
        AError := 'PKCS#1 RSA CRT fields are invalid';
        Exit;
      end;

      AP := StripLeadingZeroBytes(LRoot.GetChild(4).AsBigInteger);
      AQ := StripLeadingZeroBytes(LRoot.GetChild(5).AsBigInteger);
      ADP := StripLeadingZeroBytes(LRoot.GetChild(6).AsBigInteger);
      ADQ := StripLeadingZeroBytes(LRoot.GetChild(7).AsBigInteger);
      AQInv := StripLeadingZeroBytes(LRoot.GetChild(8).AsBigInteger);

      if (Length(AP) = 0) or ((Length(AP) = 1) and (AP[0] = 0)) or
        (Length(AQ) = 0) or ((Length(AQ) = 1) and (AQ[0] = 0)) or
        (Length(ADP) = 0) or ((Length(ADP) = 1) and (ADP[0] = 0)) or
        (Length(ADQ) = 0) or ((Length(ADQ) = 1) and (ADQ[0] = 0)) or
        (Length(AQInv) = 0) or ((Length(AQInv) = 1) and (AQInv[0] = 0)) then
      begin
        AError := 'PKCS#1 RSA CRT components contain empty values';
        Exit;
      end;

      Result := True;
    finally
      LRoot.Free;
    end;
  finally
    LReader.Free;
  end;
end;

function TryParseRSAPrivateKeyPKCS8(
  const ADER: TBytes;
  out AModulus: TBytes;
  out APrivateExponent: TBytes;
  out AError: string
): Boolean;
var
  LReader: TASN1Reader;
  LRoot: TASN1Node;
  LAlgNode: TASN1Node;
  LOID: string;
  LPrivateKeyOctets: TBytes;
begin
  SetLength(AModulus, 0);
  SetLength(APrivateExponent, 0);
  AError := '';
  Result := False;

  if Length(ADER) = 0 then
  begin
    AError := 'PKCS#8 DER is empty';
    Exit;
  end;

  LReader := TASN1Reader.Create(ADER);
  try
    try
      LRoot := LReader.Parse;
    except
      on E: Exception do
      begin
        AError := 'PKCS#8 parse failed: ' + E.Message;
        Exit;
      end;
    end;

    try
      if (LRoot = nil) or (not LRoot.IsSequence) then
      begin
        AError := 'PKCS#8 root is not ASN.1 SEQUENCE';
        Exit;
      end;

      if LRoot.ChildCount < 3 then
      begin
        AError := 'PKCS#8 PrivateKeyInfo fields are incomplete';
        Exit;
      end;

      LAlgNode := LRoot.GetChild(1);
      if (not LAlgNode.IsSequence) or (LAlgNode.ChildCount < 1) or (not LAlgNode.GetChild(0).IsOID) then
      begin
        AError := 'PKCS#8 AlgorithmIdentifier is invalid';
        Exit;
      end;

      LOID := LAlgNode.GetChild(0).AsOID;
      if (LOID <> OID_RSA_ENCRYPTION) and (LOID <> OID_RSASSA_PSS) then
      begin
        AError := 'PKCS#8 key algorithm is not RSA';
        Exit;
      end;

      if not LRoot.GetChild(2).IsOctetString then
      begin
        AError := 'PKCS#8 privateKey field is not OCTET STRING';
        Exit;
      end;

      LPrivateKeyOctets := LRoot.GetChild(2).AsOctetString;
      if not TryParseRSAPrivateKeyPKCS1(LPrivateKeyOctets, AModulus, APrivateExponent, AError) then
      begin
        AError := 'PKCS#8 inner PKCS#1 parse failed: ' + AError;
        Exit;
      end;

      Result := True;
    finally
      LRoot.Free;
    end;
  finally
    LReader.Free;
  end;
end;

function TryParseRSAPrivateKeyPKCS8CRT(
  const ADER: TBytes;
  out AP, AQ, ADP, ADQ, AQInv: TBytes;
  out AError: string
): Boolean;
var
  LReader: TASN1Reader;
  LRoot: TASN1Node;
  LAlgNode: TASN1Node;
  LOID: string;
  LPrivateKeyOctets: TBytes;
begin
  SetLength(AP, 0);
  SetLength(AQ, 0);
  SetLength(ADP, 0);
  SetLength(ADQ, 0);
  SetLength(AQInv, 0);
  AError := '';
  Result := False;

  if Length(ADER) = 0 then
  begin
    AError := 'PKCS#8 DER is empty';
    Exit;
  end;

  LReader := TASN1Reader.Create(ADER);
  try
    try
      LRoot := LReader.Parse;
    except
      on E: Exception do
      begin
        AError := 'PKCS#8 parse failed: ' + E.Message;
        Exit;
      end;
    end;

    try
      if (LRoot = nil) or (not LRoot.IsSequence) then
      begin
        AError := 'PKCS#8 root is not ASN.1 SEQUENCE';
        Exit;
      end;

      if LRoot.ChildCount < 3 then
      begin
        AError := 'PKCS#8 PrivateKeyInfo fields are incomplete';
        Exit;
      end;

      LAlgNode := LRoot.GetChild(1);
      if (not LAlgNode.IsSequence) or (LAlgNode.ChildCount < 1) or (not LAlgNode.GetChild(0).IsOID) then
      begin
        AError := 'PKCS#8 AlgorithmIdentifier is invalid';
        Exit;
      end;

      LOID := LAlgNode.GetChild(0).AsOID;
      if (LOID <> OID_RSA_ENCRYPTION) and (LOID <> OID_RSASSA_PSS) then
      begin
        AError := 'PKCS#8 key algorithm is not RSA';
        Exit;
      end;

      if not LRoot.GetChild(2).IsOctetString then
      begin
        AError := 'PKCS#8 privateKey field is not OCTET STRING';
        Exit;
      end;

      LPrivateKeyOctets := LRoot.GetChild(2).AsOctetString;
      if not TryParseRSAPrivateKeyPKCS1CRT(LPrivateKeyOctets, AP, AQ, ADP, ADQ, AQInv, AError) then
      begin
        AError := 'PKCS#8 inner PKCS#1 parse failed: ' + AError;
        Exit;
      end;

      Result := True;
    finally
      LRoot.Free;
    end;
  finally
    LReader.Free;
  end;
end;

function TryExtractRSAPrivateKeyComponents(
  const APrivateKeyBlob: TBytes;
  out AModulus: TBytes;
  out APrivateExponent: TBytes;
  out AError: string
): Boolean;
var
  LReader: TPEMReader;
  LBlocks: TPEMBlockArray;
  LKeyDER: TBytes;
  LText: AnsiString;
  I: Integer;
  LLastError: string;
begin
  SetLength(AModulus, 0);
  SetLength(APrivateExponent, 0);
  AError := '';
  Result := False;

  if Length(APrivateKeyBlob) = 0 then
  begin
    AError := 'Private key material is empty';
    Exit;
  end;

  if BlobLooksLikePEM(APrivateKeyBlob) then
  begin
    LReader := TPEMReader.Create;
    try
      LText := BytesToAnsiString(APrivateKeyBlob);
      try
        LReader.LoadFromString(string(LText));
      except
        on E: Exception do
        begin
          AError := 'Failed to parse PEM private key blob: ' + E.Message;
          Exit;
        end;
      end;

      LBlocks := LReader.GetPrivateKeys;
      if Length(LBlocks) = 0 then
      begin
        AError := 'No private key block found in PEM blob';
        Exit;
      end;

      LLastError := '';
      for I := 0 to High(LBlocks) do
      begin
        if LBlocks[I].IsEncrypted then
        begin
          LLastError := 'Encrypted PEM private keys are not supported in pure FreePascal TLS13 signer';
          Continue;
        end;

        case LBlocks[I].BlockType of
          pemPrivateKey:
            begin
              if TryParseRSAPrivateKeyPKCS8(LBlocks[I].Data, AModulus, APrivateExponent, LLastError) then
                Exit(True);
            end;

          pemRSAPrivateKey:
            begin
              if TryParseRSAPrivateKeyPKCS1(LBlocks[I].Data, AModulus, APrivateExponent, LLastError) then
                Exit(True);
            end;

          pemEncryptedPrivateKey:
            begin
              LLastError := 'Encrypted PKCS#8 private keys are not supported in pure FreePascal TLS13 signer';
            end;

        else
          LLastError := 'PEM private key is not RSA';
        end;
      end;

      if LLastError = '' then
        LLastError := 'No usable RSA private key found in PEM material';
      AError := LLastError;
      Exit(False);
    finally
      LReader.Free;
    end;
  end;

  LKeyDER := Copy(APrivateKeyBlob, 0, Length(APrivateKeyBlob));

  if TryParseRSAPrivateKeyPKCS8(LKeyDER, AModulus, APrivateExponent, AError) then
    Exit(True);

  if TryParseRSAPrivateKeyPKCS1(LKeyDER, AModulus, APrivateExponent, AError) then
    Exit(True);

  AError := 'Unsupported DER private key format (expected RSA PKCS#8 or PKCS#1)';
end;

function TryExtractRSAPrivateKeyCRTComponents(
  const APrivateKeyBlob: TBytes;
  out AP, AQ, ADP, ADQ, AQInv: TBytes;
  out AError: string
): Boolean;
var
  LReader: TPEMReader;
  LBlocks: TPEMBlockArray;
  LKeyDER: TBytes;
  LText: AnsiString;
  I: Integer;
  LLastError: string;
begin
  SetLength(AP, 0);
  SetLength(AQ, 0);
  SetLength(ADP, 0);
  SetLength(ADQ, 0);
  SetLength(AQInv, 0);
  AError := '';
  Result := False;

  if Length(APrivateKeyBlob) = 0 then
  begin
    AError := 'Private key material is empty';
    Exit;
  end;

  if BlobLooksLikePEM(APrivateKeyBlob) then
  begin
    LReader := TPEMReader.Create;
    try
      LText := BytesToAnsiString(APrivateKeyBlob);
      try
        LReader.LoadFromString(string(LText));
      except
        on E: Exception do
        begin
          AError := 'Failed to parse PEM private key blob: ' + E.Message;
          Exit;
        end;
      end;

      LBlocks := LReader.GetPrivateKeys;
      if Length(LBlocks) = 0 then
      begin
        AError := 'No private key block found in PEM blob';
        Exit;
      end;

      LLastError := '';
      for I := 0 to High(LBlocks) do
      begin
        if LBlocks[I].IsEncrypted then
        begin
          LLastError := 'Encrypted PEM private keys are not supported in pure FreePascal TLS13 signer';
          Continue;
        end;

        case LBlocks[I].BlockType of
          pemPrivateKey:
            begin
              if TryParseRSAPrivateKeyPKCS8CRT(LBlocks[I].Data, AP, AQ, ADP, ADQ, AQInv, LLastError) then
                Exit(True);
            end;

          pemRSAPrivateKey:
            begin
              if TryParseRSAPrivateKeyPKCS1CRT(LBlocks[I].Data, AP, AQ, ADP, ADQ, AQInv, LLastError) then
                Exit(True);
            end;

          pemEncryptedPrivateKey:
            begin
              LLastError := 'Encrypted PKCS#8 private keys are not supported in pure FreePascal TLS13 signer';
            end;

        else
          LLastError := 'PEM private key is not RSA';
        end;
      end;

      if LLastError = '' then
        LLastError := 'No usable RSA private key found in PEM material';
      AError := LLastError;
      Exit(False);
    finally
      LReader.Free;
    end;
  end;

  LKeyDER := Copy(APrivateKeyBlob, 0, Length(APrivateKeyBlob));

  if TryParseRSAPrivateKeyPKCS8CRT(LKeyDER, AP, AQ, ADP, ADQ, AQInv, AError) then
    Exit(True);

  if TryParseRSAPrivateKeyPKCS1CRT(LKeyDER, AP, AQ, ADP, ADQ, AQInv, AError) then
    Exit(True);

  AError := 'Unsupported DER private key format (expected RSA PKCS#8 or PKCS#1)';
end;


function TryParseECPrivateKeySEC1(
  const ADER: TBytes;
  out APrivateScalar: TBytes;
  out ACurveOID: string;
  out AError: string
): Boolean;
var
  LReader: TASN1Reader;
  LRoot: TASN1Node;
  I: Integer;
  LCtxNode: TASN1Node;
begin
  SetLength(APrivateScalar, 0);
  ACurveOID := '';
  AError := '';
  Result := False;

  if Length(ADER) = 0 then
  begin
    AError := 'EC SEC1 DER is empty';
    Exit;
  end;

  LReader := TASN1Reader.Create(ADER);
  try
    try
      LRoot := LReader.Parse;
    except
      on E: Exception do
      begin
        AError := 'EC SEC1 parse failed: ' + E.Message;
        Exit;
      end;
    end;

    try
      if (LRoot = nil) or (not LRoot.IsSequence) then
      begin
        AError := 'EC SEC1 root is not ASN.1 SEQUENCE';
        Exit;
      end;

      if LRoot.ChildCount < 2 then
      begin
        AError := 'EC SEC1 private key fields are incomplete';
        Exit;
      end;

      if (not LRoot.GetChild(0).IsInteger) or (not LRoot.GetChild(1).IsOctetString) then
      begin
        AError := 'EC SEC1 version/privateKey fields are invalid';
        Exit;
      end;

      APrivateScalar := StripLeadingZeroBytes(LRoot.GetChild(1).AsOctetString);
      if (Length(APrivateScalar) = 0) or ((Length(APrivateScalar) = 1) and (APrivateScalar[0] = 0)) then
      begin
        AError := 'EC SEC1 private scalar is empty';
        Exit;
      end;

      for I := 2 to LRoot.ChildCount - 1 do
      begin
        LCtxNode := LRoot.GetChild(I);
        if LCtxNode.IsContextTag(0) and (LCtxNode.ChildCount > 0) and LCtxNode.GetChild(0).IsOID then
        begin
          ACurveOID := LCtxNode.GetChild(0).AsOID;
          Break;
        end;
      end;

      Result := True;
    finally
      LRoot.Free;
    end;
  finally
    LReader.Free;
  end;
end;

function TryParseECPrivateKeyPKCS8(
  const ADER: TBytes;
  out APrivateScalar: TBytes;
  out ACurveOID: string;
  out AError: string
): Boolean;
var
  LReader: TASN1Reader;
  LRoot: TASN1Node;
  LAlgNode: TASN1Node;
  LAlgOID: string;
  LInnerDER: TBytes;
  LInnerCurveOID: string;
begin
  SetLength(APrivateScalar, 0);
  ACurveOID := '';
  AError := '';
  Result := False;

  if Length(ADER) = 0 then
  begin
    AError := 'EC PKCS#8 DER is empty';
    Exit;
  end;

  LReader := TASN1Reader.Create(ADER);
  try
    try
      LRoot := LReader.Parse;
    except
      on E: Exception do
      begin
        AError := 'EC PKCS#8 parse failed: ' + E.Message;
        Exit;
      end;
    end;

    try
      if (LRoot = nil) or (not LRoot.IsSequence) then
      begin
        AError := 'EC PKCS#8 root is not ASN.1 SEQUENCE';
        Exit;
      end;

      if LRoot.ChildCount < 3 then
      begin
        AError := 'EC PKCS#8 PrivateKeyInfo fields are incomplete';
        Exit;
      end;

      LAlgNode := LRoot.GetChild(1);
      if (not LAlgNode.IsSequence) or (LAlgNode.ChildCount < 2) then
      begin
        AError := 'EC PKCS#8 AlgorithmIdentifier is invalid';
        Exit;
      end;

      if (not LAlgNode.GetChild(0).IsOID) or (not LAlgNode.GetChild(1).IsOID) then
      begin
        AError := 'EC PKCS#8 algorithm/curve fields are invalid';
        Exit;
      end;

      LAlgOID := LAlgNode.GetChild(0).AsOID;
      if LAlgOID <> OID_EC_PUBLIC_KEY then
      begin
        AError := 'PKCS#8 key algorithm is not EC';
        Exit;
      end;

      ACurveOID := LAlgNode.GetChild(1).AsOID;

      if not LRoot.GetChild(2).IsOctetString then
      begin
        AError := 'EC PKCS#8 privateKey field is not OCTET STRING';
        Exit;
      end;

      LInnerDER := LRoot.GetChild(2).AsOctetString;
      if not TryParseECPrivateKeySEC1(LInnerDER, APrivateScalar, LInnerCurveOID, AError) then
      begin
        AError := 'EC PKCS#8 inner SEC1 parse failed: ' + AError;
        Exit;
      end;

      if LInnerCurveOID <> '' then
        ACurveOID := LInnerCurveOID;

      Result := True;
    finally
      LRoot.Free;
    end;
  finally
    LReader.Free;
  end;
end;

function TryExtractECDSAPrivateKeyP256Scalar(
  const APrivateKeyBlob: TBytes;
  out APrivateScalar: TBytes;
  out AError: string
): Boolean;
var
  LReader: TPEMReader;
  LBlocks: TPEMBlockArray;
  LKeyDER: TBytes;
  LText: AnsiString;
  I: Integer;
  LCurveOID: string;
  LLastError: string;
begin
  SetLength(APrivateScalar, 0);
  AError := '';
  Result := False;

  if Length(APrivateKeyBlob) = 0 then
  begin
    AError := 'Private key material is empty';
    Exit;
  end;

  if BlobLooksLikePEM(APrivateKeyBlob) then
  begin
    LReader := TPEMReader.Create;
    try
      LText := BytesToAnsiString(APrivateKeyBlob);
      try
        LReader.LoadFromString(string(LText));
      except
        on E: Exception do
        begin
          AError := 'Failed to parse PEM private key blob: ' + E.Message;
          Exit;
        end;
      end;

      LBlocks := LReader.GetPrivateKeys;
      if Length(LBlocks) = 0 then
      begin
        AError := 'No private key block found in PEM blob';
        Exit;
      end;

      LLastError := '';
      for I := 0 to High(LBlocks) do
      begin
        if LBlocks[I].IsEncrypted then
        begin
          LLastError := 'Encrypted PEM private keys are not supported in pure FreePascal TLS13 signer';
          Continue;
        end;

        case LBlocks[I].BlockType of
          pemPrivateKey:
            begin
              if TryParseECPrivateKeyPKCS8(LBlocks[I].Data, APrivateScalar, LCurveOID, LLastError) and
                (LCurveOID = OID_EC_SECP256R1) then
                Exit(True);
              if LLastError = '' then
                LLastError := 'PKCS#8 EC key curve is not prime256v1';
            end;

          pemECPrivateKey:
            begin
              if TryParseECPrivateKeySEC1(LBlocks[I].Data, APrivateScalar, LCurveOID, LLastError) and
                (LCurveOID = OID_EC_SECP256R1) then
                Exit(True);
              if LLastError = '' then
                LLastError := 'SEC1 EC key curve is not prime256v1';
            end;

          pemRSAPrivateKey:
            LLastError := 'PEM private key is not EC';

          pemEncryptedPrivateKey:
            LLastError := 'Encrypted PKCS#8 private keys are not supported in pure FreePascal TLS13 signer';

        else
          LLastError := 'PEM private key is not EC';
        end;
      end;

      if LLastError = '' then
        LLastError := 'No usable EC P-256 private key found in PEM material';
      AError := LLastError;
      Exit(False);
    finally
      LReader.Free;
    end;
  end;

  LKeyDER := Copy(APrivateKeyBlob, 0, Length(APrivateKeyBlob));

  if TryParseECPrivateKeyPKCS8(LKeyDER, APrivateScalar, LCurveOID, AError) and
    (LCurveOID = OID_EC_SECP256R1) then
    Exit(True);

  if TryParseECPrivateKeySEC1(LKeyDER, APrivateScalar, LCurveOID, AError) and
    (LCurveOID = OID_EC_SECP256R1) then
    Exit(True);

  AError := 'Unsupported DER private key format (expected EC prime256v1 PKCS#8 or SEC1)';
end;

function IsECDSAPrivateKey(const APrivateKeyBlob: TBytes): Boolean;
var
  LScalar: TBytes;
  LError: string;
begin
  Result := TryExtractECDSAPrivateKeyP256Scalar(APrivateKeyBlob, LScalar, LError);
end;

function MGF1_SHA256(const ASeed: TBytes; AMaskLength: Integer): TBytes;
var
  LCounter: Cardinal;
  LOffset: Integer;
  LInput: TBytes;
  LHash: TBytes;
  LCopyLen: Integer;
begin
  if AMaskLength < 0 then
    RaiseInvalidParameter('MGF1MaskLength');

  SetLength(Result, AMaskLength);
  if AMaskLength = 0 then
    Exit;

  SetLength(LInput, Length(ASeed) + 4);
  if Length(ASeed) > 0 then
    Move(ASeed[0], LInput[0], Length(ASeed));

  LCounter := 0;
  LOffset := 0;
  while LOffset < AMaskLength do
  begin
    LInput[Length(ASeed)] := Byte((LCounter shr 24) and $FF);
    LInput[Length(ASeed) + 1] := Byte((LCounter shr 16) and $FF);
    LInput[Length(ASeed) + 2] := Byte((LCounter shr 8) and $FF);
    LInput[Length(ASeed) + 3] := Byte(LCounter and $FF);

    LHash := SHA256(LInput);
    LCopyLen := Length(LHash);
    if LCopyLen > AMaskLength - LOffset then
      LCopyLen := AMaskLength - LOffset;

    if LCopyLen > 0 then
      Move(LHash[0], Result[LOffset], LCopyLen);

    Inc(LOffset, LCopyLen);
    Inc(LCounter);
  end;
end;

function MGF1_SHA384(const ASeed: TBytes; AMaskLength: Integer): TBytes;
var
  LCounter: Cardinal;
  LOffset: Integer;
  LInput: TBytes;
  LHash: TBytes;
  LCopyLen: Integer;
begin
  if AMaskLength < 0 then
    RaiseInvalidParameter('MGF1MaskLength');

  SetLength(Result, AMaskLength);
  if AMaskLength = 0 then
    Exit;

  SetLength(LInput, Length(ASeed) + 4);
  if Length(ASeed) > 0 then
    Move(ASeed[0], LInput[0], Length(ASeed));

  LCounter := 0;
  LOffset := 0;
  while LOffset < AMaskLength do
  begin
    LInput[Length(ASeed)] := Byte((LCounter shr 24) and $FF);
    LInput[Length(ASeed) + 1] := Byte((LCounter shr 16) and $FF);
    LInput[Length(ASeed) + 2] := Byte((LCounter shr 8) and $FF);
    LInput[Length(ASeed) + 3] := Byte(LCounter and $FF);

    LHash := SHA384(LInput);
    LCopyLen := Length(LHash);
    if LCopyLen > AMaskLength - LOffset then
      LCopyLen := AMaskLength - LOffset;

    if LCopyLen > 0 then
      Move(LHash[0], Result[LOffset], LCopyLen);

    Inc(LOffset, LCopyLen);
    Inc(LCounter);
  end;
end;

function TryBuildRSAPSSEncodedMessageSHA256(
  const AMessage: TBytes;
  AModulusBitLength: Integer;
  out AEncoded: TBytes;
  out AError: string
): Boolean;
const
  HASH_SIZE = 32;
  SALT_SIZE = 32;
var
  LEMBits: Integer;
  LEMLen: Integer;
  LMHash: TBytes;
  LSalt: TBytes;
  LMPrime: TBytes;
  LH: TBytes;
  LDB: TBytes;
  LDBMask: TBytes;
  LMaskedDB: TBytes;
  LPSLen: Integer;
  I: Integer;
  LUnusedBits: Integer;
begin
  SetLength(AEncoded, 0);
  AError := '';
  Result := False;

  if AModulusBitLength <= 1 then
  begin
    AError := 'RSA modulus bit length is invalid for PSS';
    Exit;
  end;

  LEMBits := AModulusBitLength - 1;
  LEMLen := (LEMBits + 7) div 8;
  if LEMLen < HASH_SIZE + SALT_SIZE + 2 then
  begin
    AError := 'RSA modulus too short for SHA-256 PSS encoding';
    Exit;
  end;

  LMHash := SHA256(AMessage);

  try
    LSalt := GenerateSecureRandomBytes(SALT_SIZE);
  except
    on E: Exception do
    begin
      AError := 'Failed to generate RSA-PSS salt: ' + E.Message;
      Exit;
    end;
  end;

  SetLength(LMPrime, 8 + HASH_SIZE + SALT_SIZE);
  FillChar(LMPrime[0], 8, 0);
  Move(LMHash[0], LMPrime[8], HASH_SIZE);
  Move(LSalt[0], LMPrime[8 + HASH_SIZE], SALT_SIZE);

  LH := SHA256(LMPrime);

  LPSLen := LEMLen - SALT_SIZE - HASH_SIZE - 2;
  SetLength(LDB, LEMLen - HASH_SIZE - 1);
  if Length(LDB) > 0 then
    FillChar(LDB[0], Length(LDB), 0);
  LDB[LPSLen] := 1;
  Move(LSalt[0], LDB[LPSLen + 1], SALT_SIZE);

  LDBMask := MGF1_SHA256(LH, Length(LDB));
  SetLength(LMaskedDB, Length(LDB));
  for I := 0 to Length(LDB) - 1 do
    LMaskedDB[I] := LDB[I] xor LDBMask[I];

  LUnusedBits := 8 * LEMLen - LEMBits;
  if LUnusedBits > 0 then
    LMaskedDB[0] := LMaskedDB[0] and ($FF shr LUnusedBits);

  SetLength(AEncoded, LEMLen);
  Move(LMaskedDB[0], AEncoded[0], Length(LMaskedDB));
  Move(LH[0], AEncoded[Length(LMaskedDB)], HASH_SIZE);
  AEncoded[LEMLen - 1] := $BC;

  Result := True;
end;

function TryBuildRSAPSSEncodedMessageSHA384(
  const AMessage: TBytes;
  AModulusBitLength: Integer;
  out AEncoded: TBytes;
  out AError: string
): Boolean;
const
  HASH_SIZE = 48;
  SALT_SIZE = 48;
var
  LEMBits: Integer;
  LEMLen: Integer;
  LMHash: TBytes;
  LSalt: TBytes;
  LMPrime: TBytes;
  LH: TBytes;
  LDB: TBytes;
  LDBMask: TBytes;
  LMaskedDB: TBytes;
  LPSLen: Integer;
  I: Integer;
  LUnusedBits: Integer;
begin
  SetLength(AEncoded, 0);
  AError := '';
  Result := False;

  if AModulusBitLength <= 1 then
  begin
    AError := 'RSA modulus bit length is invalid for PSS';
    Exit;
  end;

  LEMBits := AModulusBitLength - 1;
  LEMLen := (LEMBits + 7) div 8;
  if LEMLen < HASH_SIZE + SALT_SIZE + 2 then
  begin
    AError := 'RSA modulus too short for SHA-384 PSS encoding';
    Exit;
  end;

  LMHash := SHA384(AMessage);

  try
    LSalt := GenerateSecureRandomBytes(SALT_SIZE);
  except
    on E: Exception do
    begin
      AError := 'Failed to generate RSA-PSS salt: ' + E.Message;
      Exit;
    end;
  end;

  SetLength(LMPrime, 8 + HASH_SIZE + SALT_SIZE);
  FillChar(LMPrime[0], 8, 0);
  Move(LMHash[0], LMPrime[8], HASH_SIZE);
  Move(LSalt[0], LMPrime[8 + HASH_SIZE], SALT_SIZE);

  LH := SHA384(LMPrime);

  LPSLen := LEMLen - SALT_SIZE - HASH_SIZE - 2;
  SetLength(LDB, LEMLen - HASH_SIZE - 1);
  if Length(LDB) > 0 then
    FillChar(LDB[0], Length(LDB), 0);
  LDB[LPSLen] := 1;
  Move(LSalt[0], LDB[LPSLen + 1], SALT_SIZE);

  LDBMask := MGF1_SHA384(LH, Length(LDB));
  SetLength(LMaskedDB, Length(LDB));
  for I := 0 to Length(LDB) - 1 do
    LMaskedDB[I] := LDB[I] xor LDBMask[I];

  LUnusedBits := 8 * LEMLen - LEMBits;
  if LUnusedBits > 0 then
    LMaskedDB[0] := LMaskedDB[0] and ($FF shr LUnusedBits);

  SetLength(AEncoded, LEMLen);
  Move(LMaskedDB[0], AEncoded[0], Length(LMaskedDB));
  Move(LH[0], AEncoded[Length(LMaskedDB)], HASH_SIZE);
  AEncoded[LEMLen - 1] := $BC;

  Result := True;
end;

function TryBuildRSAPKCS1v15EncodedMessageSHA256(
  const AMessage: TBytes;
  AModulusLength: Integer;
  out AEncoded: TBytes;
  out AError: string
): Boolean;
var
  LHash: TBytes;
  LTLen: Integer;
  LPSLen: Integer;
  LOffset: Integer;
  I: Integer;
begin
  SetLength(AEncoded, 0);
  AError := '';
  Result := False;

  if AModulusLength <= 0 then
  begin
    AError := 'RSA modulus length is invalid';
    Exit;
  end;

  LHash := SHA256(AMessage);
  LTLen := Length(SHA256_DIGESTINFO_PREFIX) + Length(LHash);
  if AModulusLength < LTLen + 11 then
  begin
    AError := 'RSA modulus is too short for PKCS#1 v1.5 SHA-256 encoding';
    Exit;
  end;

  LPSLen := AModulusLength - LTLen - 3;
  SetLength(AEncoded, AModulusLength);

  AEncoded[0] := 0;
  AEncoded[1] := 1;
  for I := 0 to LPSLen - 1 do
    AEncoded[2 + I] := $FF;

  LOffset := 2 + LPSLen;
  AEncoded[LOffset] := 0;
  Inc(LOffset);

  Move(SHA256_DIGESTINFO_PREFIX[0], AEncoded[LOffset], Length(SHA256_DIGESTINFO_PREFIX));
  Inc(LOffset, Length(SHA256_DIGESTINFO_PREFIX));
  Move(LHash[0], AEncoded[LOffset], Length(LHash));

  Result := True;
end;

function TryBuildRSAPKCS1v15EncodedMessageSHA384(
  const AMessage: TBytes;
  AModulusLength: Integer;
  out AEncoded: TBytes;
  out AError: string
): Boolean;
var
  LHash: TBytes;
  LTLen: Integer;
  LPSLen: Integer;
  LOffset: Integer;
  I: Integer;
begin
  SetLength(AEncoded, 0);
  AError := '';
  Result := False;

  if AModulusLength <= 0 then
  begin
    AError := 'RSA modulus length is invalid';
    Exit;
  end;

  LHash := SHA384(AMessage);
  LTLen := Length(SHA384_DIGESTINFO_PREFIX) + Length(LHash);
  if AModulusLength < LTLen + 11 then
  begin
    AError := 'RSA modulus is too short for PKCS#1 v1.5 SHA-384 encoding';
    Exit;
  end;

  LPSLen := AModulusLength - LTLen - 3;
  SetLength(AEncoded, AModulusLength);

  AEncoded[0] := 0;
  AEncoded[1] := 1;
  for I := 0 to LPSLen - 1 do
    AEncoded[2 + I] := $FF;

  LOffset := 2 + LPSLen;
  AEncoded[LOffset] := 0;
  Inc(LOffset);

  Move(SHA384_DIGESTINFO_PREFIX[0], AEncoded[LOffset], Length(SHA384_DIGESTINFO_PREFIX));
  Inc(LOffset, Length(SHA384_DIGESTINFO_PREFIX));
  Move(LHash[0], AEncoded[LOffset], Length(LHash));

  Result := True;
end;

function BytesEqual(const ALeft, ARight: TBytes): Boolean;
var
  I: Integer;
begin
  if Length(ALeft) <> Length(ARight) then
    Exit(False);

  for I := 0 to Length(ALeft) - 1 do
  begin
    if ALeft[I] <> ARight[I] then
      Exit(False);
  end;

  Result := True;
end;

function RSAKeyOctetLength(const AModulus: TBytes): Integer;
var
  LBitLength: Integer;
begin
  LBitLength := UnsignedBitLength(AModulus);
  if LBitLength <= 0 then
    Exit(0);
  Result := (LBitLength + 7) div 8;
end;

function TryRecoverRSAEncodedMessage(
  const ASignature: TBytes;
  const AModulus: TBytes;
  const APublicExponent: TBytes;
  out AEncodedMessage: TBytes;
  out AError: string
): Boolean;
var
  LRecovered: TBytes;
  LModulusLength: Integer;
begin
  SetLength(AEncodedMessage, 0);
  AError := '';
  Result := False;

  LModulusLength := RSAKeyOctetLength(AModulus);
  if LModulusLength <= 0 then
  begin
    AError := 'RSA public modulus is empty';
    Exit;
  end;

  if Length(ASignature) <> LModulusLength then
  begin
    AError := Format('RSA signature length mismatch (expected=%d actual=%d)',
      [LModulusLength, Length(ASignature)]);
    Exit;
  end;

  if UnsignedIsZero(APublicExponent) then
  begin
    AError := 'RSA public exponent is empty';
    Exit;
  end;

  if CompareUnsignedBytes(ASignature, AModulus) >= 0 then
  begin
    AError := 'RSA signature representative is out of range';
    Exit;
  end;

  if not TryBigIntModExpFromUnsignedBytes(
    ASignature,
    APublicExponent,
    AModulus,
    LRecovered,
    AError
  ) then
  begin
    AError := 'RSA signature modular exponentiation failed: ' + AError;
    Exit;
  end;

  if not TryBigIntToFixedLengthFromUnsignedBytes(
    LRecovered,
    LModulusLength,
    AEncodedMessage,
    AError
  ) then
  begin
    AError := 'RSA encoded message sizing failed: ' + AError;
    Exit;
  end;

  Result := True;
end;

function TryVerifyRSAPKCS1v15SignatureSHA256(
  const AMessage: TBytes;
  const ASignature: TBytes;
  const AModulus: TBytes;
  const APublicExponent: TBytes;
  out AError: string
): Boolean;
var
  LRecovered: TBytes;
  LExpected: TBytes;
begin
  AError := '';
  Result := False;

  if not TryRecoverRSAEncodedMessage(ASignature, AModulus, APublicExponent, LRecovered, AError) then
    Exit;

  if not TryBuildRSAPKCS1v15EncodedMessageSHA256(AMessage, Length(LRecovered), LExpected, AError) then
  begin
    AError := 'RSA PKCS#1 v1.5 encoding failed: ' + AError;
    Exit;
  end;

  if not BytesEqual(LRecovered, LExpected) then
  begin
    AError := 'RSA PKCS#1 v1.5 signature does not match transcript';
    Exit;
  end;

  Result := True;
end;

function TryVerifyRSAPKCS1v15SignatureSHA384(
  const AMessage: TBytes;
  const ASignature: TBytes;
  const AModulus: TBytes;
  const APublicExponent: TBytes;
  out AError: string
): Boolean;
var
  LRecovered: TBytes;
  LExpected: TBytes;
begin
  AError := '';
  Result := False;

  if not TryRecoverRSAEncodedMessage(ASignature, AModulus, APublicExponent, LRecovered, AError) then
    Exit;

  if not TryBuildRSAPKCS1v15EncodedMessageSHA384(AMessage, Length(LRecovered), LExpected, AError) then
  begin
    AError := 'RSA PKCS#1 v1.5 encoding failed: ' + AError;
    Exit;
  end;

  if not BytesEqual(LRecovered, LExpected) then
  begin
    AError := 'RSA PKCS#1 v1.5 signature does not match transcript';
    Exit;
  end;

  Result := True;
end;

function TryVerifyRSAPSSEncodedMessageSHA256(
  const AMessage: TBytes;
  const AEncodedMessage: TBytes;
  AModulusBitLength: Integer;
  out AError: string
): Boolean;
const
  HASH_SIZE = 32;
  SALT_SIZE = 32;
var
  LEMBits: Integer;
  LEMLen: Integer;
  LMaskedDB: TBytes;
  LH: TBytes;
  LDBMask: TBytes;
  LDB: TBytes;
  LMHash: TBytes;
  LMPrime: TBytes;
  LExpectedH: TBytes;
  LSalt: TBytes;
  LPSLen: Integer;
  LUnusedBits: Integer;
  LUnusedMask: Byte;
  I: Integer;
begin
  AError := '';
  Result := False;

  if AModulusBitLength <= 1 then
  begin
    AError := 'RSA modulus bit length is invalid for PSS verification';
    Exit;
  end;

  LEMBits := AModulusBitLength - 1;
  LEMLen := (LEMBits + 7) div 8;
  if Length(AEncodedMessage) <> LEMLen then
  begin
    AError := 'RSA-PSS encoded message length does not match modulus';
    Exit;
  end;

  if LEMLen < HASH_SIZE + SALT_SIZE + 2 then
  begin
    AError := 'RSA modulus too short for SHA-256 PSS verification';
    Exit;
  end;

  if AEncodedMessage[LEMLen - 1] <> $BC then
  begin
    AError := 'RSA-PSS trailer byte is invalid';
    Exit;
  end;

  SetLength(LMaskedDB, LEMLen - HASH_SIZE - 1);
  if Length(LMaskedDB) > 0 then
    Move(AEncodedMessage[0], LMaskedDB[0], Length(LMaskedDB));
  LH := Copy(AEncodedMessage, Length(LMaskedDB), HASH_SIZE);

  LUnusedBits := 8 * LEMLen - LEMBits;
  if LUnusedBits > 0 then
  begin
    LUnusedMask := Byte($FF shl (8 - LUnusedBits));
    if (LMaskedDB[0] and LUnusedMask) <> 0 then
    begin
      AError := 'RSA-PSS leftmost masked bits are non-zero';
      Exit;
    end;
  end;

  LDBMask := MGF1_SHA256(LH, Length(LMaskedDB));
  SetLength(LDB, Length(LMaskedDB));
  for I := 0 to Length(LMaskedDB) - 1 do
    LDB[I] := LMaskedDB[I] xor LDBMask[I];

  if LUnusedBits > 0 then
    LDB[0] := LDB[0] and ($FF shr LUnusedBits);

  LPSLen := LEMLen - HASH_SIZE - SALT_SIZE - 2;
  for I := 0 to LPSLen - 1 do
  begin
    if LDB[I] <> 0 then
    begin
      AError := 'RSA-PSS padding prefix is invalid';
      Exit;
    end;
  end;

  if LDB[LPSLen] <> 1 then
  begin
    AError := 'RSA-PSS salt delimiter is missing';
    Exit;
  end;

  LSalt := Copy(LDB, LPSLen + 1, SALT_SIZE);
  LMHash := SHA256(AMessage);

  SetLength(LMPrime, 8 + HASH_SIZE + SALT_SIZE);
  FillChar(LMPrime[0], 8, 0);
  Move(LMHash[0], LMPrime[8], HASH_SIZE);
  Move(LSalt[0], LMPrime[8 + HASH_SIZE], SALT_SIZE);
  LExpectedH := SHA256(LMPrime);

  if not BytesEqual(LH, LExpectedH) then
  begin
    AError := 'RSA-PSS signature hash does not match transcript';
    Exit;
  end;

  Result := True;
end;

function TryVerifyRSAPSSEncodedMessageSHA384(
  const AMessage: TBytes;
  const AEncodedMessage: TBytes;
  AModulusBitLength: Integer;
  out AError: string
): Boolean;
const
  HASH_SIZE = 48;
  SALT_SIZE = 48;
var
  LEMBits: Integer;
  LEMLen: Integer;
  LMaskedDB: TBytes;
  LH: TBytes;
  LDBMask: TBytes;
  LDB: TBytes;
  LMHash: TBytes;
  LMPrime: TBytes;
  LExpectedH: TBytes;
  LSalt: TBytes;
  LPSLen: Integer;
  LUnusedBits: Integer;
  LUnusedMask: Byte;
  I: Integer;
begin
  AError := '';
  Result := False;

  if AModulusBitLength <= 1 then
  begin
    AError := 'RSA modulus bit length is invalid for PSS verification';
    Exit;
  end;

  LEMBits := AModulusBitLength - 1;
  LEMLen := (LEMBits + 7) div 8;
  if Length(AEncodedMessage) <> LEMLen then
  begin
    AError := 'RSA-PSS encoded message length does not match modulus';
    Exit;
  end;

  if LEMLen < HASH_SIZE + SALT_SIZE + 2 then
  begin
    AError := 'RSA modulus too short for SHA-384 PSS verification';
    Exit;
  end;

  if AEncodedMessage[LEMLen - 1] <> $BC then
  begin
    AError := 'RSA-PSS trailer byte is invalid';
    Exit;
  end;

  SetLength(LMaskedDB, LEMLen - HASH_SIZE - 1);
  if Length(LMaskedDB) > 0 then
    Move(AEncodedMessage[0], LMaskedDB[0], Length(LMaskedDB));
  LH := Copy(AEncodedMessage, Length(LMaskedDB), HASH_SIZE);

  LUnusedBits := 8 * LEMLen - LEMBits;
  if LUnusedBits > 0 then
  begin
    LUnusedMask := Byte($FF shl (8 - LUnusedBits));
    if (LMaskedDB[0] and LUnusedMask) <> 0 then
    begin
      AError := 'RSA-PSS leftmost masked bits are non-zero';
      Exit;
    end;
  end;

  LDBMask := MGF1_SHA384(LH, Length(LMaskedDB));
  SetLength(LDB, Length(LMaskedDB));
  for I := 0 to Length(LMaskedDB) - 1 do
    LDB[I] := LMaskedDB[I] xor LDBMask[I];

  if LUnusedBits > 0 then
    LDB[0] := LDB[0] and ($FF shr LUnusedBits);

  LPSLen := LEMLen - HASH_SIZE - SALT_SIZE - 2;
  for I := 0 to LPSLen - 1 do
  begin
    if LDB[I] <> 0 then
    begin
      AError := 'RSA-PSS padding prefix is invalid';
      Exit;
    end;
  end;

  if LDB[LPSLen] <> 1 then
  begin
    AError := 'RSA-PSS salt delimiter is missing';
    Exit;
  end;

  LSalt := Copy(LDB, LPSLen + 1, SALT_SIZE);
  LMHash := SHA384(AMessage);

  SetLength(LMPrime, 8 + HASH_SIZE + SALT_SIZE);
  FillChar(LMPrime[0], 8, 0);
  Move(LMHash[0], LMPrime[8], HASH_SIZE);
  Move(LSalt[0], LMPrime[8 + HASH_SIZE], SALT_SIZE);
  LExpectedH := SHA384(LMPrime);

  if not BytesEqual(LH, LExpectedH) then
  begin
    AError := 'RSA-PSS signature hash does not match transcript';
    Exit;
  end;

  Result := True;
end;

function TryVerifyRSAPSSSignatureSHA256(
  const AMessage: TBytes;
  const ASignature: TBytes;
  const AModulus: TBytes;
  const APublicExponent: TBytes;
  out AError: string
): Boolean;
var
  LRecovered: TBytes;
begin
  AError := '';
  Result := False;

  if not TryRecoverRSAEncodedMessage(ASignature, AModulus, APublicExponent, LRecovered, AError) then
    Exit;

  Result := TryVerifyRSAPSSEncodedMessageSHA256(
    AMessage,
    LRecovered,
    UnsignedBitLength(AModulus),
    AError
  );
end;

function TryVerifyRSAPSSSignatureSHA384(
  const AMessage: TBytes;
  const ASignature: TBytes;
  const AModulus: TBytes;
  const APublicExponent: TBytes;
  out AError: string
): Boolean;
var
  LRecovered: TBytes;
begin
  AError := '';
  Result := False;

  if not TryRecoverRSAEncodedMessage(ASignature, AModulus, APublicExponent, LRecovered, AError) then
    Exit;

  Result := TryVerifyRSAPSSEncodedMessageSHA384(
    AMessage,
    LRecovered,
    UnsignedBitLength(AModulus),
    AError
  );
end;

function TryVerifyTLS13CertificateVerifySignature(
  ASignatureScheme: Word;
  const APublicKeyInfo: TX509PublicKeyInfo;
  const ACertificateVerifyInput: TBytes;
  const ASignature: TBytes;
  out AError: string
): Boolean;
var
  LMessageHash: TBytes;
  LP384Pub: TP384Point;
begin
  AError := '';
  Result := False;

  if Length(ACertificateVerifyInput) = 0 then
  begin
    AError := 'CertificateVerify input is empty';
    Exit;
  end;

  if Length(ASignature) = 0 then
  begin
    AError := 'CertificateVerify signature is empty';
    Exit;
  end;

  case ASignatureScheme of
    TLS13_SIG_RSA_PSS_RSAE_SHA256,
    TLS13_SIG_RSA_PSS_PSS_SHA256,
    TLS13_SIG_RSA_PKCS1_SHA256,
    TLS13_SIG_RSA_PSS_RSAE_SHA384,
    TLS13_SIG_RSA_PSS_PSS_SHA384,
    TLS13_SIG_RSA_PKCS1_SHA384:
      begin
        if not SameText(APublicKeyInfo.KeyType, 'RSA') then
        begin
          AError := 'Unsupported CertificateVerify key type for RSA signature scheme';
          Exit;
        end;

        case ASignatureScheme of
          TLS13_SIG_RSA_PSS_RSAE_SHA256,
          TLS13_SIG_RSA_PSS_PSS_SHA256:
            Result := TryVerifyRSAPSSSignatureSHA256(
              ACertificateVerifyInput,
              ASignature,
              APublicKeyInfo.RSAModulus,
              APublicKeyInfo.RSAExponent,
              AError
            );

          TLS13_SIG_RSA_PSS_RSAE_SHA384,
          TLS13_SIG_RSA_PSS_PSS_SHA384:
            Result := TryVerifyRSAPSSSignatureSHA384(
              ACertificateVerifyInput,
              ASignature,
              APublicKeyInfo.RSAModulus,
              APublicKeyInfo.RSAExponent,
              AError
            );

          TLS13_SIG_RSA_PKCS1_SHA256:
            Result := TryVerifyRSAPKCS1v15SignatureSHA256(
              ACertificateVerifyInput,
              ASignature,
              APublicKeyInfo.RSAModulus,
              APublicKeyInfo.RSAExponent,
              AError
            );

          TLS13_SIG_RSA_PKCS1_SHA384:
            Result := TryVerifyRSAPKCS1v15SignatureSHA384(
              ACertificateVerifyInput,
              ASignature,
              APublicKeyInfo.RSAModulus,
              APublicKeyInfo.RSAExponent,
              AError
            );
        end;

        Exit;
      end;

    TLS13_SIG_ECDSA_SECP256R1_SHA256:
      begin
        if not SameText(APublicKeyInfo.KeyType, 'ECDSA') then
        begin
          AError := 'Unsupported CertificateVerify key type for ECDSA signature scheme';
          Exit;
        end;

        if (not SameText(APublicKeyInfo.ECCurve, 'prime256v1')) and
          (not SameText(APublicKeyInfo.ECCurve, 'secp256r1')) then
        begin
          AError := 'Unsupported ECDSA curve for CertificateVerify';
          Exit;
        end;

        LMessageHash := SHA256(ACertificateVerifyInput);
        Result := TryECDSAVerifyP256SHA256(
          LMessageHash,
          APublicKeyInfo.ECPoint,
          ASignature,
          AError
        );
        Exit;
      end;

    TLS13_SIG_ECDSA_SECP384R1_SHA384:
      begin
        if not SameText(APublicKeyInfo.KeyType, 'ECDSA') then
        begin
          AError := 'Unsupported CertificateVerify key type for ECDSA-P384 signature scheme';
          Exit;
        end;

        if (not SameText(APublicKeyInfo.ECCurve, 'secp384r1')) and
          (not SameText(APublicKeyInfo.ECCurve, 'prime384v1')) then
        begin
          AError := 'Unsupported ECDSA curve for P-384 CertificateVerify';
          Exit;
        end;

        if (Length(APublicKeyInfo.ECPoint) <> 97) or (APublicKeyInfo.ECPoint[0] <> $04) then
        begin
          AError := 'Invalid P-384 public key format for CertificateVerify';
          Exit;
        end;

        LMessageHash := SHA384(ACertificateVerifyInput);
        LP384Pub.X := Copy(APublicKeyInfo.ECPoint, 1, 48);
        LP384Pub.Y := Copy(APublicKeyInfo.ECPoint, 49, 48);
        Result := TryP384ECDSAVerifyDER(LMessageHash, ASignature, LP384Pub, AError);
        Exit;
      end;

    TLS13_SIG_ED25519:
      begin
        if not SameText(APublicKeyInfo.KeyType, 'Ed25519') then
        begin
          AError := 'Unsupported CertificateVerify key type for Ed25519 signature scheme';
          Exit;
        end;

        if Length(APublicKeyInfo.PublicKey) <> 32 then
        begin
          AError := 'Invalid Ed25519 public key length';
          Exit;
        end;

        Result := Ed25519Verify(APublicKeyInfo.PublicKey, ACertificateVerifyInput, ASignature);
        if not Result then
          AError := 'Ed25519 CertificateVerify signature verification failed';
        Exit;
      end;
  end;

  AError := 'Unsupported CertificateVerify signature scheme: ' +
    TLS13SignatureSchemeToString(ASignatureScheme);
end;

function TryRSASignWithPrivateExponent(
  const AEncodedMessage: TBytes;
  const AModulus: TBytes;
  const APrivateExponent: TBytes;
  out ASignature: TBytes;
  out AError: string
): Boolean;
begin
  Result := TryRSACTModExpSign(
    AEncodedMessage,
    AModulus,
    APrivateExponent,
    ASignature,
    AError
  );
end;

function TryRSASignWithCRT(
  const AEncodedMessage: TBytes;
  const AModulus: TBytes;
  const AP, AQ, ADP, ADQ, AQInv: TBytes;
  out ASignature: TBytes;
  out AError: string
): Boolean;
begin
  Result := TryRSACTSignWithCRT(
    AEncodedMessage, AModulus,
    TBytes.Create($00, $01, $00, $01), // e=65537 for verify-after-sign
    AP, AQ, ADP, ADQ, AQInv,
    ASignature, AError
  );
end;

function TrySelectTLS13ServerCertificateVerifyScheme(
  const AClientHello: TTLS13ClientHelloInfo;
  out ASignatureScheme: Word;
  out AError: string
): Boolean;
begin
  ASignatureScheme := 0;
  AError := '';
  Result := False;

  if not AClientHello.HasSignatureAlgorithms then
  begin
    AError := 'ClientHello missing signature_algorithms extension';
    Exit;
  end;

  if TLS13ClientHelloOffersSignatureScheme(AClientHello, TLS13_SIG_RSA_PSS_RSAE_SHA256) then
  begin
    ASignatureScheme := TLS13_SIG_RSA_PSS_RSAE_SHA256;
    Exit(True);
  end;

  if TLS13ClientHelloOffersSignatureScheme(AClientHello, TLS13_SIG_RSA_PSS_RSAE_SHA384) then
  begin
    ASignatureScheme := TLS13_SIG_RSA_PSS_RSAE_SHA384;
    Exit(True);
  end;

  if TLS13ClientHelloOffersSignatureScheme(AClientHello, TLS13_SIG_ECDSA_SECP256R1_SHA256) then
  begin
    ASignatureScheme := TLS13_SIG_ECDSA_SECP256R1_SHA256;
    Exit(True);
  end;

  if TLS13ClientHelloOffersSignatureScheme(AClientHello, TLS13_SIG_RSA_PKCS1_SHA256) then
  begin
    ASignatureScheme := TLS13_SIG_RSA_PKCS1_SHA256;
    Exit(True);
  end;

  if TLS13ClientHelloOffersSignatureScheme(AClientHello, TLS13_SIG_RSA_PKCS1_SHA384) then
  begin
    ASignatureScheme := TLS13_SIG_RSA_PKCS1_SHA384;
    Exit(True);
  end;

  if TLS13ClientHelloOffersSignatureScheme(AClientHello, TLS13_SIG_RSA_PSS_PSS_SHA256) then
  begin
    ASignatureScheme := TLS13_SIG_RSA_PSS_PSS_SHA256;
    Exit(True);
  end;

  if TLS13ClientHelloOffersSignatureScheme(AClientHello, TLS13_SIG_RSA_PSS_PSS_SHA384) then
  begin
    ASignatureScheme := TLS13_SIG_RSA_PSS_PSS_SHA384;
    Exit(True);
  end;

  AError := 'No supported TLS 1.3 CertificateVerify signature scheme from client';
end;

function TrySelectTLS13ServerCertificateVerifySchemeForKeyType(
  const AClientHello: TTLS13ClientHelloInfo;
  const ALeafKeyType: string;
  out ASignatureScheme: Word;
  out AError: string
): Boolean;
var
  LKeyType: string;
begin
  ASignatureScheme := 0;
  AError := '';
  Result := False;

  LKeyType := UpperCase(Trim(ALeafKeyType));

  if not AClientHello.HasSignatureAlgorithms then
  begin
    AError := 'ClientHello missing signature_algorithms extension';
    Exit;
  end;

  if LKeyType = 'RSA' then
  begin
    if TLS13ClientHelloOffersSignatureScheme(AClientHello, TLS13_SIG_RSA_PSS_RSAE_SHA256) then
    begin
      ASignatureScheme := TLS13_SIG_RSA_PSS_RSAE_SHA256;
      Exit(True);
    end;

    if TLS13ClientHelloOffersSignatureScheme(AClientHello, TLS13_SIG_RSA_PSS_RSAE_SHA384) then
    begin
      ASignatureScheme := TLS13_SIG_RSA_PSS_RSAE_SHA384;
      Exit(True);
    end;

    if TLS13ClientHelloOffersSignatureScheme(AClientHello, TLS13_SIG_RSA_PKCS1_SHA256) then
    begin
      ASignatureScheme := TLS13_SIG_RSA_PKCS1_SHA256;
      Exit(True);
    end;

    if TLS13ClientHelloOffersSignatureScheme(AClientHello, TLS13_SIG_RSA_PKCS1_SHA384) then
    begin
      ASignatureScheme := TLS13_SIG_RSA_PKCS1_SHA384;
      Exit(True);
    end;

    if TLS13ClientHelloOffersSignatureScheme(AClientHello, TLS13_SIG_RSA_PSS_PSS_SHA256) then
    begin
      ASignatureScheme := TLS13_SIG_RSA_PSS_PSS_SHA256;
      Exit(True);
    end;

    if TLS13ClientHelloOffersSignatureScheme(AClientHello, TLS13_SIG_RSA_PSS_PSS_SHA384) then
    begin
      ASignatureScheme := TLS13_SIG_RSA_PSS_PSS_SHA384;
      Exit(True);
    end;

    AError := 'No supported TLS 1.3 CertificateVerify signature scheme from client for RSA key';
    Exit;
  end;

  if LKeyType = 'ECDSA' then
  begin
    if TLS13ClientHelloOffersSignatureScheme(AClientHello, TLS13_SIG_ECDSA_SECP256R1_SHA256) then
    begin
      ASignatureScheme := TLS13_SIG_ECDSA_SECP256R1_SHA256;
      Exit(True);
    end;

    AError := 'No supported TLS 1.3 CertificateVerify signature scheme from client for ECDSA key';
    Exit;
  end;

  AError := 'Unsupported leaf certificate key type for TLS 1.3 CertificateVerify';
end;

function TrySelectTLS13ServerCertificateVerifySchemeForKeyTypeAndCipherSuite(
  const AClientHello: TTLS13ClientHelloInfo;
  const ALeafKeyType: string;
  ACipherSuite: Word;
  out ASignatureScheme: Word;
  out AError: string
): Boolean;
  function TrySelectFirstOfferedScheme(
    const ACandidateSchemes: array of Word;
    out ASelectedScheme: Word
  ): Boolean;
  var
    I: Integer;
  begin
    ASelectedScheme := 0;
    for I := Low(ACandidateSchemes) to High(ACandidateSchemes) do
    begin
      if TLS13ClientHelloOffersSignatureScheme(AClientHello, ACandidateSchemes[I]) then
      begin
        ASelectedScheme := ACandidateSchemes[I];
        Exit(True);
      end;
    end;

    Result := False;
  end;
var
  LKeyType: string;
begin
  ASignatureScheme := 0;
  AError := '';
  Result := False;

  LKeyType := UpperCase(Trim(ALeafKeyType));

  if not AClientHello.HasSignatureAlgorithms then
  begin
    AError := 'ClientHello missing signature_algorithms extension';
    Exit;
  end;

  if LKeyType = 'RSA' then
  begin
    if TLS13CipherSuiteIsSHA384(ACipherSuite) then
    begin
      if TrySelectFirstOfferedScheme([
        TLS13_SIG_RSA_PSS_RSAE_SHA384,
        TLS13_SIG_RSA_PKCS1_SHA384,
        TLS13_SIG_RSA_PSS_PSS_SHA384
      ], ASignatureScheme) then
        Exit(True);

      if TrySelectFirstOfferedScheme([
        TLS13_SIG_RSA_PSS_RSAE_SHA256,
        TLS13_SIG_RSA_PKCS1_SHA256,
        TLS13_SIG_RSA_PSS_PSS_SHA256
      ], ASignatureScheme) then
        Exit(True);
    end
    else if TLS13CipherSuiteIsSHA256(ACipherSuite) then
    begin
      if TrySelectFirstOfferedScheme([
        TLS13_SIG_RSA_PSS_RSAE_SHA256,
        TLS13_SIG_RSA_PKCS1_SHA256,
        TLS13_SIG_RSA_PSS_PSS_SHA256
      ], ASignatureScheme) then
        Exit(True);

      if TrySelectFirstOfferedScheme([
        TLS13_SIG_RSA_PSS_RSAE_SHA384,
        TLS13_SIG_RSA_PKCS1_SHA384,
        TLS13_SIG_RSA_PSS_PSS_SHA384
      ], ASignatureScheme) then
        Exit(True);
    end
    else
      Exit(TrySelectTLS13ServerCertificateVerifySchemeForKeyType(
        AClientHello,
        ALeafKeyType,
        ASignatureScheme,
        AError
      ));

    AError := 'No supported TLS 1.3 CertificateVerify signature scheme from client for RSA key';
    Exit;
  end;

  if LKeyType = 'ECDSA' then
    Exit(TrySelectTLS13ServerCertificateVerifySchemeForKeyType(
      AClientHello,
      ALeafKeyType,
      ASignatureScheme,
      AError
    ));

  AError := 'Unsupported leaf certificate key type for TLS 1.3 CertificateVerify';
end;

function BuildTLS13ServerCertificateVerifyInputSHA256(
  const ATranscriptHash: TBytes
): TBytes;
var
  LContextBytes: TBytes;
  I: Integer;
begin
  if (Length(ATranscriptHash) <> 32) and (Length(ATranscriptHash) <> 48) then
    RaiseInvalidParameter('TLS13TranscriptHashSHA256');

  LContextBytes := TEncoding.ASCII.GetBytes(TLS13_SERVER_CERTVERIFY_CONTEXT);

  SetLength(Result, 64 + Length(LContextBytes) + 1 + Length(ATranscriptHash));

  for I := 0 to 63 do
    Result[I] := $20;

  if Length(LContextBytes) > 0 then
    Move(LContextBytes[0], Result[64], Length(LContextBytes));

  Result[64 + Length(LContextBytes)] := 0;

  Move(
    ATranscriptHash[0],
    Result[64 + Length(LContextBytes) + 1],
    Length(ATranscriptHash)
  );
end;

function BuildTLS13ClientCertificateVerifyInput(
  const ATranscriptHash: TBytes
): TBytes;
var
  LContextBytes: TBytes;
  I: Integer;
begin
  if (Length(ATranscriptHash) <> 32) and (Length(ATranscriptHash) <> 48) then
    RaiseInvalidParameter('TLS13TranscriptHash');

  LContextBytes := TEncoding.ASCII.GetBytes(TLS13_CLIENT_CERTVERIFY_CONTEXT);

  SetLength(Result, 64 + Length(LContextBytes) + 1 + Length(ATranscriptHash));

  for I := 0 to 63 do
    Result[I] := $20;

  if Length(LContextBytes) > 0 then
    Move(LContextBytes[0], Result[64], Length(LContextBytes));

  Result[64 + Length(LContextBytes)] := 0;

  Move(
    ATranscriptHash[0],
    Result[64 + Length(LContextBytes) + 1],
    Length(ATranscriptHash)
  );
end;

function BuildTLS13CertificateVerifyHandshake(
  ASignatureScheme: Word;
  const ASignature: TBytes
): TBytes;
var
  LBody: TBytes;
begin
  if Length(ASignature) > High(Word) then
    RaiseInvalidParameter('TLS13CertificateVerifySignatureLength');

  SetLength(LBody, 0);
  AppendUInt16(LBody, ASignatureScheme);
  AppendUInt16(LBody, Length(ASignature));
  AppendBytes(LBody, ASignature);

  SetLength(Result, 0);
  AppendByte(Result, TLS_HANDSHAKE_TYPE_CERTIFICATE_VERIFY);
  AppendUInt24(Result, Length(LBody));
  AppendBytes(Result, LBody);
end;

function BuildTLS13PlaceholderSignatureFromTranscriptHash(
  const ATranscriptHash: TBytes;
  ATargetLength: Integer
): TBytes;
var
  I: Integer;
  LHashLen: Integer;
begin
  if Length(ATranscriptHash) = 0 then
    RaiseInvalidParameter('TLS13TranscriptHash');

  if ATargetLength <= 0 then
    RaiseInvalidParameter('TLS13PlaceholderSignatureLength');

  SetLength(Result, ATargetLength);
  LHashLen := Length(ATranscriptHash);

  for I := 0 to ATargetLength - 1 do
    Result[I] := Byte(ATranscriptHash[I mod LHashLen] xor Byte((I * 131) and $FF));
end;

function IsSupportedTLS13CertificateVerifyScheme(ASignatureScheme: Word): Boolean;
begin
  case ASignatureScheme of
    TLS13_SIG_RSA_PSS_RSAE_SHA256,
    TLS13_SIG_RSA_PSS_PSS_SHA256,
    TLS13_SIG_RSA_PKCS1_SHA256,
    TLS13_SIG_RSA_PSS_RSAE_SHA384,
    TLS13_SIG_RSA_PSS_PSS_SHA384,
    TLS13_SIG_RSA_PKCS1_SHA384,
    TLS13_SIG_ECDSA_SECP256R1_SHA256,
    TLS13_SIG_ECDSA_SECP384R1_SHA384,
    TLS13_SIG_ED25519:
      Result := True;
  else
    Result := False;
  end;
end;

function TryParseTLS13CertificateVerifyHandshake(
  const AHandshakeMessage: TBytes;
  out ASignatureScheme: Word;
  out ASignature: TBytes;
  out AError: string
): Boolean;
var
  LBodyLength: Cardinal;
  LSignatureLength: Word;
begin
  ASignatureScheme := 0;
  SetLength(ASignature, 0);
  AError := '';
  Result := False;

  if Length(AHandshakeMessage) < 9 then
  begin
    AError := 'CertificateVerify handshake is too short';
    Exit;
  end;

  if AHandshakeMessage[0] <> TLS_HANDSHAKE_TYPE_CERTIFICATE_VERIFY then
  begin
    AError := 'Handshake type is not CertificateVerify';
    Exit;
  end;

  LBodyLength := ReadUInt24(AHandshakeMessage, 1);
  if LBodyLength <> Cardinal(Length(AHandshakeMessage) - 4) then
  begin
    AError := 'CertificateVerify body length does not match handshake framing';
    Exit;
  end;

  if LBodyLength < 5 then
  begin
    AError := 'CertificateVerify body is too short';
    Exit;
  end;

  ASignatureScheme := ReadUInt16(AHandshakeMessage, 4);
  if not IsSupportedTLS13CertificateVerifyScheme(ASignatureScheme) then
  begin
    AError := 'Unsupported CertificateVerify signature scheme: ' +
      TLS13SignatureSchemeToString(ASignatureScheme);
    Exit;
  end;

  LSignatureLength := ReadUInt16(AHandshakeMessage, 6);
  if Integer(LSignatureLength) = 0 then
  begin
    AError := 'CertificateVerify signature is empty';
    Exit;
  end;

  if Integer(LSignatureLength) <> Length(AHandshakeMessage) - 8 then
  begin
    AError := 'CertificateVerify signature length does not match body framing';
    Exit;
  end;

  ASignature := Copy(AHandshakeMessage, 8, Integer(LSignatureLength));
  Result := True;
end;

function TryBuildTLS13CertificateVerifySignature(
  ASignatureScheme: Word;
  const APrivateKeyBlob: TBytes;
  const ACertificateVerifyInput: TBytes;
  out ASignature: TBytes;
  out AError: string
): Boolean;
var
  LModulus: TBytes;
  LPrivateExponent: TBytes;
  LP, LQ, LDP, LDQ, LQInv: TBytes;
  LEM: TBytes;
  LModBits: Integer;
  LCRTErr: string;
  LExpErr: string;
  LECPrivateScalar: TBytes;
  LDigest: TBytes;
begin
  SetLength(ASignature, 0);
  AError := '';
  Result := False;

  if Length(ACertificateVerifyInput) = 0 then
  begin
    AError := 'CertificateVerify input is empty';
    Exit;
  end;

  case ASignatureScheme of
    TLS13_SIG_RSA_PSS_RSAE_SHA256,
    TLS13_SIG_RSA_PSS_PSS_SHA256,
    TLS13_SIG_RSA_PKCS1_SHA256,
    TLS13_SIG_RSA_PSS_RSAE_SHA384,
    TLS13_SIG_RSA_PSS_PSS_SHA384,
    TLS13_SIG_RSA_PKCS1_SHA384,
    TLS13_SIG_ECDSA_SECP256R1_SHA256:
      ;
  else
    begin
      AError := 'Unsupported signature scheme for pure FreePascal signer: ' +
        TLS13SignatureSchemeToString(ASignatureScheme);
      Exit;
    end;
  end;

  if ASignatureScheme = TLS13_SIG_ECDSA_SECP256R1_SHA256 then
  begin
    if not TryExtractECDSAPrivateKeyP256Scalar(APrivateKeyBlob, LECPrivateScalar, AError) then
      Exit;

    LDigest := SHA256(ACertificateVerifyInput);
    Result := TryECDSASignP256SHA256(LDigest, LECPrivateScalar, ASignature, AError);
    Exit;
  end;

  if not TryExtractRSAPrivateKeyComponents(APrivateKeyBlob, LModulus, LPrivateExponent, AError) then
    Exit;

  if not TryExtractRSAPrivateKeyCRTComponents(APrivateKeyBlob, LP, LQ, LDP, LDQ, LQInv, AError) then
  begin
    SetLength(LP, 0);
    SetLength(LQ, 0);
    SetLength(LDP, 0);
    SetLength(LDQ, 0);
    SetLength(LQInv, 0);
    AError := '';
  end;

  case ASignatureScheme of
    TLS13_SIG_RSA_PSS_RSAE_SHA256,
    TLS13_SIG_RSA_PSS_PSS_SHA256:
      begin
        LModBits := UnsignedBitLength(LModulus);
        if not TryBuildRSAPSSEncodedMessageSHA256(ACertificateVerifyInput, LModBits, LEM, AError) then
          Exit;
      end;

    TLS13_SIG_RSA_PSS_RSAE_SHA384,
    TLS13_SIG_RSA_PSS_PSS_SHA384:
      begin
        LModBits := UnsignedBitLength(LModulus);
        if not TryBuildRSAPSSEncodedMessageSHA384(ACertificateVerifyInput, LModBits, LEM, AError) then
          Exit;
      end;

    TLS13_SIG_RSA_PKCS1_SHA256:
      begin
        if not TryBuildRSAPKCS1v15EncodedMessageSHA256(ACertificateVerifyInput, Length(LModulus), LEM, AError) then
          Exit;
      end;

    TLS13_SIG_RSA_PKCS1_SHA384:
      begin
        if not TryBuildRSAPKCS1v15EncodedMessageSHA384(ACertificateVerifyInput, Length(LModulus), LEM, AError) then
          Exit;
      end;
  end;

  if (Length(LP) > 0) and (Length(LQ) > 0) and (Length(LDP) > 0) and
    (Length(LDQ) > 0) and (Length(LQInv) > 0) then
  begin
    LCRTErr := '';
    if TryValidateRSACRTComponents(LModulus, LPrivateExponent, LP, LQ, LDP, LDQ, LQInv, LCRTErr) then
    begin
      if TryRSASignWithCRT(LEM, LModulus, LP, LQ, LDP, LDQ, LQInv, ASignature, AError) then
        Exit(True);
      LCRTErr := AError;
    end;

    if TryRSASignWithPrivateExponent(LEM, LModulus, LPrivateExponent, ASignature, LExpErr) then
    begin
      AError := '';
      Exit(True);
    end;

    if LCRTErr <> '' then
      AError := 'E_TLS13_SIGNER_FALLBACK_FAILED: crt_reason=' + LCRTErr + '; exp_reason=' + LExpErr
    else
      AError := 'E_TLS13_SIGNER_FALLBACK_FAILED: crt_reason=unknown; exp_reason=' + LExpErr;
    Exit(False);
  end;

  Result := TryRSASignWithPrivateExponent(LEM, LModulus, LPrivateExponent, ASignature, AError);
end;

end.
