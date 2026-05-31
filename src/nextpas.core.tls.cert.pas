{
  nextpas.core.tls.cert - High-Level Certificate Facade
  
  Provides scenario-based, user-friendly API for common certificate operations.
  This is the main entry point users should use.
}

unit nextpas.core.tls.cert;

{$mode objfpc}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

interface

uses
  SysUtils, Classes,
  nextpas.core.tls.cert.builder;

type
  { High-level certificate facade - scenario-based API }
  TCertificate = class
  public
    { Creation }
    class function CreateBuilder: ICertificateBuilder; static;
    class function CreateSelfSigned(const ACommonName: string): IKeyPairWithCertificate; static;
    class function CreateServerCert(const ACommonName: string; const ASANs: array of string): IKeyPairWithCertificate; static;
    class function CreateClientCert(const ACommonName: string): IKeyPairWithCertificate; static;
    
    { Loading }
    class function LoadFromFile(const AFile: string): ICertificate; static;
    class function ParsePEM(const APEM: string): ICertificate; static;
    class function ParseDER(const ADER: TBytes): ICertificate; static;
    
    { Conversion }
    class function ConvertPEMToDER(const APEM: string): TBytes; static;
    class function ConvertDERToPEM(const ADER: TBytes): string; static;
  end;

implementation

uses
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.cert.builder.impl,
  nextpas.core.tls.safety;

{ TCertificate }

class function TCertificate.CreateBuilder: ICertificateBuilder;
begin
  Result := TCertificateBuilder.Create;
end;

class function TCertificate.CreateSelfSigned(const ACommonName: string): IKeyPairWithCertificate;
begin
  Result := CreateBuilder
    .WithCommonName(ACommonName)
    .ValidFor(365)
    .WithRSAKey(TKeySize.Bits(2048))
    .SelfSigned;
end;

class function TCertificate.CreateServerCert(const ACommonName: string; 
  const ASANs: array of string): IKeyPairWithCertificate;
var
  LBuilder: ICertificateBuilder;
  I: Integer;
begin
  LBuilder := CreateBuilder
    .WithCommonName(ACommonName)
    .ValidFor(90);
    
  // Add SANs
  for I := Low(ASANs) to High(ASANs) do
    LBuilder := LBuilder.AddSubjectAltName(ASANs[I]);
    
  Result := LBuilder
    .WithECDSAKey(ec_P256)  // Fast & modern
    .SelfSigned;
end;

class function TCertificate.CreateClientCert(const ACommonName: string): IKeyPairWithCertificate;
begin
  Result := CreateBuilder
    .WithCommonName(ACommonName)
    .ValidFor(365)
    .WithRSAKey(TKeySize.Bits(2048))
    .SelfSigned;
end;

class function TCertificate.LoadFromFile(const AFile: string): ICertificate;
var
  LPEM: string;
begin
  LPEM := TCertificateUtils.LoadFromFile(AFile);
  Result := ParsePEM(LPEM);
end;

class function TCertificate.ParsePEM(const APEM: string): ICertificate;
begin
  Result := TCertificateImpl.Create(APEM);
end;

class function TCertificate.ParseDER(const ADER: TBytes): ICertificate;
var
  LPEM: string;
begin
  LPEM := TCertificateUtils.DERToPEM(ADER);
  Result := ParsePEM(LPEM);
end;

class function TCertificate.ConvertPEMToDER(const APEM: string): TBytes;
begin
  Result := TCertificateUtils.PEMToDER(APEM);
end;

class function TCertificate.ConvertDERToPEM(const ADER: TBytes): string;
begin
  Result := TCertificateUtils.DERToPEM(ADER);
end;

end.
