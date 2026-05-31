{
  nextpas.core.tls.quick - Quick SSL/TLS Convenience API

  Provides simple one-liner methods for common SSL/TLS operations.
  Focused on certificate generation and SSL context creation.

  Note: HTTP operations have been moved to the network framework.

  Usage:
    // Generate self-signed certificate
    KeyPair := TSSLQuick.GenerateSelfSigned('localhost');
}

unit nextpas.core.tls.quick;

{$mode objfpc}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

interface

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.logging,
  nextpas.core.tls.cert.builder,
  nextpas.core.tls.context.builder,
  nextpas.core.tls.factory;

type
  { TSSLQuick - Simple one-liner SSL/TLS operations }
  TSSLQuick = class
  public
    { ==================== Quick Connection ==================== }

    class function TryConnect(const AHost: string; APort: Word;
      out AConnection: ISSLConnection; out AError: string): Boolean; static;

    { ==================== Quick Context Creation ==================== }

    class function SecureClient: ISSLContext; static;
    class function SecureServer(const ACertFile, AKeyFile: string;
      const AKeyPassword: string = ''): ISSLContext; static;

    { ==================== Quick Certificate Generation ==================== }
    
    {**
     * Generate a self-signed certificate for testing.
     * @param ACommonName Certificate common name (e.g., 'localhost')
     * @param AValidDays Validity period in days
     * @return Key pair containing certificate and private key
     *}
    class function GenerateSelfSigned(const ACommonName: string; 
      AValidDays: Integer = 365): IKeyPairWithCertificate; static;
    
    {**
     * Generate a self-signed server certificate with SANs.
     *}
    class function GenerateServerCert(const ACommonName: string;
      ADomains: array of string; AValidDays: Integer = 365): IKeyPairWithCertificate; static;
      
    {**
     * Generate a self-signed CA certificate.
     *}
    class function GenerateCACert(const ACommonName, AOrgName: string;
      AValidDays: Integer = 3650): IKeyPairWithCertificate; static;
    
    {**
     * Generate certificate and private key files at specified paths.
     *}
    class function GenerateCertFiles(const ACommonName, ACertPath, AKeyPath: string;
      AValidDays: Integer = 365): Boolean; static;
  end;

implementation

uses
  nextpas.core.tls.safety,
  nextpas.core.tls.dialer;

{ TSSLQuick }

class function TSSLQuick.TryConnect(const AHost: string; APort: Word;
  out AConnection: ISSLConnection; out AError: string): Boolean;
var
  LDialer: TSSLDialer;
  LResult: TSSLDialResult;
begin
  AConnection := nil;
  AError := '';
  Result := False;

  LDialer := TSSLDialer.CreateDefault;
  try
    LResult := LDialer.Dial(AHost, APort);
    if LResult.Error.IsErr then
    begin
      AError := LResult.Error.ErrorMessage;
      Exit;
    end;
    AConnection := LResult.Connection;
    if LResult.Stream <> nil then
      LResult.Stream.Free;
    Result := True;
  finally
    LDialer.Free;
  end;
end;

class function TSSLQuick.SecureClient: ISSLContext;
var
  LBuilder: ISSLContextBuilder;
begin
  LBuilder := TSSLContextBuilder.Create;
  Result := LBuilder
    .WithTLS12And13
    .WithVerifyPeer
    .WithSystemRoots
    .WithSafeDefaults
    .BuildClient;
end;

class function TSSLQuick.SecureServer(const ACertFile, AKeyFile: string;
  const AKeyPassword: string): ISSLContext;
var
  LBuilder: ISSLContextBuilder;
begin
  LBuilder := TSSLContextBuilder.Create;
  Result := LBuilder
    .WithTLS12And13
    .WithCertificate(ACertFile)
    .WithPrivateKey(AKeyFile, AKeyPassword)
    .WithSafeDefaults
    .BuildServer;
end;

class function TSSLQuick.GenerateSelfSigned(const ACommonName: string;
  AValidDays: Integer): IKeyPairWithCertificate;
begin
  Result := TCertificateBuilder.Create
    .WithCommonName(ACommonName)
    .ValidFor(AValidDays)
    .WithRSAKey(TKeySize.Bits(2048))
    .SelfSigned;
end;

class function TSSLQuick.GenerateServerCert(const ACommonName: string;
  ADomains: array of string; AValidDays: Integer): IKeyPairWithCertificate;
var
  LBuilder: ICertificateBuilder;
  I: Integer;
begin
  LBuilder := TCertificateBuilder.Create
    .WithCommonName(ACommonName)
    .ValidFor(AValidDays)
    .WithRSAKey(TKeySize.Bits(2048))
    .AsServerCert;
  
  for I := Low(ADomains) to High(ADomains) do
    LBuilder := LBuilder.AddSubjectAltName('DNS:' + ADomains[I]);
  
  Result := LBuilder.SelfSigned;
end;

class function TSSLQuick.GenerateCACert(const ACommonName, AOrgName: string;
  AValidDays: Integer): IKeyPairWithCertificate;
begin
  Result := TCertificateBuilder.Create
    .WithCommonName(ACommonName)
    .WithOrganization(AOrgName)
    .ValidFor(AValidDays)
    .WithRSAKey(TKeySize.Bits(4096))
    .AsCA
    .SelfSigned;
end;

class function TSSLQuick.GenerateCertFiles(const ACommonName, ACertPath, AKeyPath: string;
  AValidDays: Integer): Boolean;
var
  LKeyPair: IKeyPairWithCertificate;
  LCertFile, LKeyFile: TFileStream;
  LCertPEM, LKeyPEM: string;
begin
  Result := False;
  try
    LKeyPair := GenerateSelfSigned(ACommonName, AValidDays);
    LCertPEM := LKeyPair.GetCertificate.ToPEM;
    LKeyPEM := LKeyPair.GetPrivateKey.ToPEM;
    
    // Write certificate file
    LCertFile := TFileStream.Create(ACertPath, fmCreate);
    try
      LCertFile.Write(LCertPEM[1], Length(LCertPEM));
    finally
      LCertFile.Free;
    end;
    
    // Write private key file
    LKeyFile := TFileStream.Create(AKeyPath, fmCreate);
    try
      LKeyFile.Write(LKeyPEM[1], Length(LKeyPEM));
    finally
      LKeyFile.Free;
    end;
    
    Result := True;
  except
    on E: Exception do
      TSecurityLog.Warning('Quick', Format('GenerateSelfSignedToFiles failed: %s', [E.Message]));
  end;
end;

end.
