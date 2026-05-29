unit nextpas.core.tls.crypto.x509verify;

{$mode objfpc}{$H+}{$J-}

interface

uses
  SysUtils, Classes, nextpas.core.tls.x509;

type
  TX509TrustStore = class
  private
    FCertificates: array of TX509Certificate;
    FCount: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddTrustedCertificate(ACert: TX509Certificate);
    function FindIssuer(ACert: TX509Certificate): TX509Certificate;
    function IsTrusted(ACert: TX509Certificate): Boolean;
  end;

  TX509VerifyResult = record
    IsValid: Boolean;
    ErrorCode: Integer;
    ErrorMessage: string;
    ChainDepth: Integer;
  end;

function VerifyX509Chain(
  const AChain: array of TX509Certificate;
  ATrustStore: TX509TrustStore;
  const AHostname: string
): TX509VerifyResult;

function VerifyChainSignature(ASubject, AIssuer: TX509Certificate): Boolean;

function VerifyChainSignatureEx(ASubject, AIssuer: TX509Certificate; out AError: string): Boolean;

function VerifySignedX509Blob(
  const ATBSData, ASignature: TBytes;
  const ASignatureAlgOID, ASignatureAlgName: string;
  AIssuer: TX509Certificate;
  out AError: string
): Boolean;

function MatchHostname(const AHostname: string; ACert: TX509Certificate): Boolean;

implementation

uses
  nextpas.core.crypto.bigint,
  nextpas.core.crypto.primitives,
  nextpas.core.tls.tls13.servercertverify,
  nextpas.core.crypto.hash,
  nextpas.core.crypto.ecdsa,
  nextpas.core.crypto.ed25519,
  nextpas.core.crypto.p384;

const
  X509_V_OK = 0;
  X509_V_ERR_CERT_NOT_YET_VALID = 1;
  X509_V_ERR_CERT_HAS_EXPIRED = 2;
  X509_V_ERR_UNABLE_TO_GET_ISSUER = 3;
  X509_V_ERR_CERT_SIGNATURE_FAILURE = 4;
  X509_V_ERR_INVALID_CA = 5;
  X509_V_ERR_PATH_LENGTH_EXCEEDED = 6;
  X509_V_ERR_HOSTNAME_MISMATCH = 7;
  X509_V_ERR_KEY_USAGE = 8;
  X509_V_ERR_UNTRUSTED_ROOT = 9;

constructor TX509TrustStore.Create;
begin
  inherited Create;
  FCount := 0;
  SetLength(FCertificates, 0);
end;

destructor TX509TrustStore.Destroy;
begin
  SetLength(FCertificates, 0);
  inherited Destroy;
end;

procedure TX509TrustStore.AddTrustedCertificate(ACert: TX509Certificate);
begin
  SetLength(FCertificates, FCount + 1);
  FCertificates[FCount] := ACert;
  Inc(FCount);
end;

function TX509TrustStore.FindIssuer(ACert: TX509Certificate): TX509Certificate;
var
  I: Integer;
  LIssuerName: string;
begin
  Result := nil;
  LIssuerName := ACert.Issuer.ToString;
  for I := 0 to FCount - 1 do
    if FCertificates[I].Subject.ToString = LIssuerName then
      Exit(FCertificates[I]);
end;

function TX509TrustStore.IsTrusted(ACert: TX509Certificate): Boolean;
var
  I: Integer;
  LFP: TBytes;
  LStoreFP: TBytes;
begin
  Result := False;
  LFP := SHA256(ACert.RawCertificate);
  for I := 0 to FCount - 1 do
  begin
    LStoreFP := SHA256(FCertificates[I].RawCertificate);
    if (Length(LFP) = Length(LStoreFP)) and CompareMem(@LFP[0], @LStoreFP[0], Length(LFP)) then
      Exit(True);
  end;
end;

const
  SHA256_DIGEST_INFO_PREFIX: array[0..18] of Byte = (
    $30, $31, $30, $0d, $06, $09, $60, $86, $48, $01,
    $65, $03, $04, $02, $01, $05, $00, $04, $20
  );
  SHA384_DIGEST_INFO_PREFIX: array[0..18] of Byte = (
    $30, $41, $30, $0d, $06, $09, $60, $86, $48, $01,
    $65, $03, $04, $02, $02, $05, $00, $04, $30
  );

function VerifySignedX509Blob(
  const ATBSData, ASignature: TBytes;
  const ASignatureAlgOID, ASignatureAlgName: string;
  AIssuer: TX509Certificate;
  out AError: string
): Boolean;
var
  LModulus, LExponent, LHash: TBytes;
  LP384PublicKey: TP384Point;
  LAlgName: string;
begin
  Result := False;
  AError := '';
  LAlgName := LowerCase(ASignatureAlgName);

  if Length(ASignature) = 0 then
  begin
    AError := 'Empty signature';
    Exit;
  end;

  if ASignatureAlgOID = '1.3.101.112' then
  begin
    if Length(AIssuer.PublicKeyInfo.PublicKey) = 32 then
      Result := Ed25519Verify(AIssuer.PublicKeyInfo.PublicKey, ATBSData, ASignature);
    if not Result then AError := 'Ed25519 signature verification failed';
    Exit;
  end;

  if (ASignatureAlgOID = '1.2.840.10045.4.3.2') or
     ((Pos('ecdsa', LAlgName) > 0) and (Pos('sha256', LAlgName) > 0)) then
  begin
    if Length(AIssuer.PublicKeyInfo.ECPoint) > 0 then
    begin
      LHash := SHA256(ATBSData);
      Result := TryECDSAVerifyP256SHA256(LHash, AIssuer.PublicKeyInfo.ECPoint, ASignature, AError);
    end
    else
      AError := 'Issuer has no EC public key for ECDSA-SHA256';
    Exit;
  end;

  if (ASignatureAlgOID = '1.2.840.10045.4.3.3') or
     ((Pos('ecdsa', LAlgName) > 0) and (Pos('sha384', LAlgName) > 0)) then
  begin
    if (Length(AIssuer.PublicKeyInfo.ECPoint) = 97) and
       (AIssuer.PublicKeyInfo.ECPoint[0] = $04) then
    begin
      LP384PublicKey.X := Copy(AIssuer.PublicKeyInfo.ECPoint, 1, 48);
      LP384PublicKey.Y := Copy(AIssuer.PublicKeyInfo.ECPoint, 49, 48);
      LHash := SHA384(ATBSData);
      Result := TryP384ECDSAVerifyDER(LHash, ASignature, LP384PublicKey, AError);
    end
    else
      AError := 'Issuer has no P-384 public key for ECDSA-SHA384';
    Exit;
  end;

  LModulus := AIssuer.PublicKeyInfo.RSAModulus;
  LExponent := AIssuer.PublicKeyInfo.RSAExponent;
  if (Length(LModulus) = 0) or (Length(LExponent) = 0) then
  begin
    AError := 'Unsupported signature algorithm: ' + ASignatureAlgOID;
    Exit;
  end;

  if (Pos('sha256', LAlgName) > 0) or (Pos('sha-256', LAlgName) > 0) then
    Result := TryVerifyRSAPKCS1v15SignatureSHA256(ATBSData, ASignature, LModulus, LExponent, AError)
  else if (Pos('sha384', LAlgName) > 0) or (Pos('sha-384', LAlgName) > 0) then
    Result := TryVerifyRSAPKCS1v15SignatureSHA384(ATBSData, ASignature, LModulus, LExponent, AError)
  else
    AError := 'Unsupported RSA hash algorithm: ' + ASignatureAlgName;
end;

function VerifyChainSignatureEx(ASubject, AIssuer: TX509Certificate; out AError: string): Boolean;
begin
  Result := VerifySignedX509Blob(
    ASubject.RawTBSCertificate,
    ASubject.Signature,
    ASubject.SignatureAlgorithm.OID,
    ASubject.SignatureAlgorithm.Name,
    AIssuer,
    AError
  );
end;

function VerifyChainSignature(ASubject, AIssuer: TX509Certificate): Boolean;
var
  LError: string;
begin
  Result := VerifyChainSignatureEx(ASubject, AIssuer, LError);
end;

function MatchHostname(const AHostname: string; ACert: TX509Certificate): Boolean;
var
  I: Integer;
  LSAN: TX509SubjectAltName;
  LPattern, LHost, LSuffix: string;
  LDotPos: Integer;
begin
  Result := False;
  if AHostname = '' then
    Exit(True);

  LHost := LowerCase(AHostname);

  for I := 0 to High(ACert.SubjectAltNames) do
  begin
    LSAN := ACert.SubjectAltNames[I];
    if LSAN.SANType = sanDNSName then
    begin
      LPattern := LowerCase(LSAN.Value);
      if LPattern = LHost then
        Exit(True);
      if (Pos('*.', LPattern) = 1) and (Length(LPattern) > 2) then
      begin
        LSuffix := Copy(LPattern, 2, Length(LPattern));
        LDotPos := Pos('.', LHost);
        if (LDotPos > 0) and
           (Copy(LHost, LDotPos, Length(LHost)) = LSuffix) then
          Exit(True);
      end;
    end;
  end;

  if Length(ACert.SubjectAltNames) = 0 then
  begin
    LPattern := LowerCase(ACert.Subject.CommonName);
    if LPattern = LHost then
      Exit(True);
  end;
end;

function VerifyX509Chain(
  const AChain: array of TX509Certificate;
  ATrustStore: TX509TrustStore;
  const AHostname: string
): TX509VerifyResult;
var
  I: Integer;
  LCurrent, LIssuer: TX509Certificate;
  LChainLen: Integer;
begin
  Result.IsValid := False;
  Result.ErrorCode := 0;
  Result.ErrorMessage := '';
  Result.ChainDepth := 0;

  LChainLen := Length(AChain);
  if LChainLen = 0 then
  begin
    Result.ErrorCode := X509_V_ERR_UNABLE_TO_GET_ISSUER;
    Result.ErrorMessage := 'Empty certificate chain';
    Exit;
  end;

  for I := 0 to LChainLen - 1 do
  begin
    LCurrent := AChain[I];

    if LCurrent.Validity.IsValid = False then
    begin
      if Now > LCurrent.Validity.NotAfter then
      begin
        Result.ErrorCode := X509_V_ERR_CERT_HAS_EXPIRED;
        Result.ErrorMessage := Format('Certificate expired: %s', [LCurrent.Subject.CommonName]);
      end
      else
      begin
        Result.ErrorCode := X509_V_ERR_CERT_NOT_YET_VALID;
        Result.ErrorMessage := Format('Certificate not yet valid: %s', [LCurrent.Subject.CommonName]);
      end;
      Exit;
    end;

    if (I > 0) then
    begin
      if not (kuKeyCertSign in AChain[I].KeyUsage) then
        if AChain[I].KeyUsage <> [] then
        begin
          Result.ErrorCode := X509_V_ERR_KEY_USAGE;
          Result.ErrorMessage := Format('Intermediate lacks keyCertSign: %s', [AChain[I].Subject.CommonName]);
          Exit;
        end;

      if not AChain[I].BasicConstraints.IsCA then
      begin
        Result.ErrorCode := X509_V_ERR_INVALID_CA;
        Result.ErrorMessage := Format('BasicConstraints CA=FALSE on intermediate: %s', [AChain[I].Subject.CommonName]);
        Exit;
      end;

      if AChain[I].BasicConstraints.HasPathLen then
        if I - 1 > AChain[I].BasicConstraints.PathLenConstraint then
        begin
          Result.ErrorCode := X509_V_ERR_PATH_LENGTH_EXCEEDED;
          Result.ErrorMessage := 'Path length constraint exceeded';
          Exit;
        end;
    end;
  end;

  LCurrent := AChain[LChainLen - 1];
  if ATrustStore.IsTrusted(LCurrent) then
  begin
    Result.ChainDepth := LChainLen;
  end
  else
  begin
    LIssuer := ATrustStore.FindIssuer(LCurrent);
    if LIssuer = nil then
    begin
      Result.ErrorCode := X509_V_ERR_UNTRUSTED_ROOT;
      Result.ErrorMessage := 'Unable to find trusted issuer for: ' + LCurrent.Subject.CommonName;
      Exit;
    end;

    if not VerifyChainSignature(LCurrent, LIssuer) then
    begin
      Result.ErrorCode := X509_V_ERR_CERT_SIGNATURE_FAILURE;
      Result.ErrorMessage := 'Signature verification failed for: ' + LCurrent.Subject.CommonName;
      Exit;
    end;

    Result.ChainDepth := LChainLen + 1;
  end;

  for I := 0 to LChainLen - 2 do
  begin
    if not VerifyChainSignature(AChain[I], AChain[I + 1]) then
    begin
      Result.ErrorCode := X509_V_ERR_CERT_SIGNATURE_FAILURE;
      Result.ErrorMessage := 'Signature verification failed for: ' + AChain[I].Subject.CommonName;
      Exit;
    end;
  end;

  if (AHostname <> '') and (LChainLen > 0) then
  begin
    if not MatchHostname(AHostname, AChain[0]) then
    begin
      Result.ErrorCode := X509_V_ERR_HOSTNAME_MISMATCH;
      Result.ErrorMessage := Format('Hostname mismatch: expected %s', [AHostname]);
      Exit;
    end;
  end;

  Result.IsValid := True;
  Result.ErrorCode := X509_V_OK;
end;

end.
