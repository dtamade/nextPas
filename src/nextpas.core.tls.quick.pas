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
  {$IFDEF UNIX}Sockets, BaseUnix,{$ENDIF}
  {$IFDEF WINDOWS}WinSock2,{$ENDIF}
  nextpas.core.tls.safety,
  nextpas.core.tls.connection.builder;

{$IFDEF UNIX}
function QuickTcpConnect(const AHost: string; APort: Word; out ASocket: THandle; out AError: string): Boolean;
var
  LSock: LongInt;
  LAddr: Sockets.TInetSockAddr;
  LIP: Sockets.in_addr;
begin
  ASocket := THandle(-1);
  AError := '';
  Result := False;

  LIP := Sockets.StrToNetAddr(AHost);
  if LIP.s_addr = 0 then
  begin
    AError := 'Cannot resolve host: ' + AHost;
    Exit;
  end;

  LSock := Sockets.fpSocket(2{AF_INET}, 1{SOCK_STREAM}, 0);
  if LSock < 0 then
  begin
    AError := 'Socket creation failed';
    Exit;
  end;

  FillChar(LAddr, SizeOf(LAddr), 0);
  LAddr.sin_family := 2; // AF_INET
  LAddr.sin_port := Sockets.htons(APort);
  LAddr.sin_addr := LIP;

  if Sockets.fpConnect(LSock, @LAddr, SizeOf(LAddr)) <> 0 then
  begin
    BaseUnix.fpClose(LSock);
    AError := 'TCP connect failed to ' + AHost + ':' + IntToStr(APort);
    Exit;
  end;

  ASocket := THandle(LSock);
  Result := True;
end;
{$ENDIF}

{ TSSLQuick }

class function TSSLQuick.TryConnect(const AHost: string; APort: Word;
  out AConnection: ISSLConnection; out AError: string): Boolean;
var
  LCtx: ISSLContext;
  LBuilder: ISSLConnectionBuilder;
  LSocket: THandle;
begin
  AConnection := nil;
  AError := '';
  Result := False;

  {$IFDEF UNIX}
  if not QuickTcpConnect(AHost, APort, LSocket, AError) then
    Exit;
  {$ELSE}
  AError := 'TryConnect not yet implemented for this platform';
  Exit;
  {$ENDIF}

  try
    LCtx := SecureClient;
    LBuilder := TSSLConnectionBuilder.CreateWithContext(LCtx);
    LBuilder.WithSocket(LSocket);
    LBuilder.WithHostname(AHost);
    AConnection := LBuilder.BuildClient;
    if AConnection = nil then
    begin
      AError := 'TLS handshake failed to ' + AHost + ':' + IntToStr(APort);
      Exit;
    end;
    Result := True;
  except
    on E: Exception do
      AError := E.Message;
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
