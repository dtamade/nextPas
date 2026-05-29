unit nextpas.core.tls.dane.pure;

{$mode objfpc}{$H+}{$J-}

interface

uses
  SysUtils, nextpas.core.tls.x509;

type
  TDANECertUsage = (cuCAConstraint = 0, cuServiceCert = 1, cuTrustAnchor = 2, cuDomainEE = 3);
  TDANESelector = (selFullCert = 0, selSubjectPublicKeyInfo = 1);
  TDANEMatchingType = (mtExact = 0, mtSHA256 = 1, mtSHA512 = 2);

  TTLSARecord = record
    Usage: TDANECertUsage;
    Selector: TDANESelector;
    MatchingType: TDANEMatchingType;
    CertificateAssociationData: TBytes;
  end;

function VerifyDANE(
  const ATLSARecords: array of TTLSARecord;
  const ACertificateDER: TBytes;
  out AError: string
): Boolean;

function BuildTLSARecord(AUsage, ASelector, AMatchingType: Byte;
  const AData: TBytes): TTLSARecord;

implementation

uses
  nextpas.core.tls.crypto.hash;

function ExtractMatchData(const ACertDER: TBytes; ASelector: TDANESelector): TBytes;
var
  LCert: TX509Certificate;
begin
  if ASelector = selFullCert then
    Exit(Copy(ACertDER));

  // selSubjectPublicKeyInfo: extract raw SPKI from DER
  LCert := TX509Certificate.Create;
  try
    LCert.LoadFromDER(ACertDER);
    Result := LCert.PublicKeyInfo.PublicKey;
  finally
    LCert.Free;
  end;
end;

function HashMatchData(const AData: TBytes; AMatchingType: TDANEMatchingType): TBytes;
begin
  case AMatchingType of
    mtExact: Result := Copy(AData);
    mtSHA256: Result := SHA256(AData);
    mtSHA512: Result := SHA512(AData);
  else
    SetLength(Result, 0);
  end;
end;

function VerifyDANE(
  const ATLSARecords: array of TTLSARecord;
  const ACertificateDER: TBytes;
  out AError: string
): Boolean;
var
  I: Integer;
  LMatchData, LHashed: TBytes;
begin
  AError := '';
  Result := False;

  if Length(ATLSARecords) = 0 then
  begin
    AError := 'No TLSA records provided';
    Exit;
  end;

  for I := 0 to High(ATLSARecords) do
  begin
    if not (ATLSARecords[I].Usage in [cuServiceCert, cuDomainEE]) then
      Continue;

    LMatchData := ExtractMatchData(ACertificateDER, ATLSARecords[I].Selector);
    if Length(LMatchData) = 0 then
      Continue;

    LHashed := HashMatchData(LMatchData, ATLSARecords[I].MatchingType);
    if Length(LHashed) = 0 then
      Continue;

    if (Length(LHashed) = Length(ATLSARecords[I].CertificateAssociationData)) and
       CompareMem(@LHashed[0], @ATLSARecords[I].CertificateAssociationData[0], Length(LHashed)) then
    begin
      Result := True;
      Exit;
    end;
  end;

  AError := 'No TLSA record matched the certificate';
end;

function BuildTLSARecord(AUsage, ASelector, AMatchingType: Byte;
  const AData: TBytes): TTLSARecord;
begin
  Result.Usage := TDANECertUsage(AUsage);
  Result.Selector := TDANESelector(ASelector);
  Result.MatchingType := TDANEMatchingType(AMatchingType);
  Result.CertificateAssociationData := Copy(AData);
end;

end.
