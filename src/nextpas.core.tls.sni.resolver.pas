unit nextpas.core.tls.sni.resolver;

{$mode ObjFPC}{$H+}{$J-}

interface

uses
  SysUtils,
  nextpas.core.tls.base;

type
  { TSSLSNIEntry — one hostname → cert+key mapping }
  TSSLSNIEntry = record
    Hostname: string;
    CertPEM: string;
    KeyPEM: string;
    KeyPassword: string;
  end;

  { TSSLSimpleServerCredential — implements ISSLServerCredential }
  TSSLSimpleServerCredential = class(TInterfacedObject, ISSLServerCredential)
  private
    FCertPEM: string;
    FKeyPEM: string;
    FKeyPassword: string;
  public
    constructor Create(const ACertPEM, AKeyPEM: string; const AKeyPassword: string = '');
    function GetCertificateChainPEM: string;
    function GetPrivateKeyPEM: string;
    function GetPrivateKeyPassword: string;
  end;

  { TSSLSNICertificateResolver — map-based SNI resolver }
  TSSLSNICertificateResolver = class(TInterfacedObject, ISSLServerCertificateResolver)
  private
    FEntries: array of TSSLSNIEntry;
    FDefaultEntry: TSSLSNIEntry;
    FHasDefault: Boolean;
  public
    constructor Create;

    procedure AddHost(const AHostname, ACertPEM, AKeyPEM: string;
      const AKeyPassword: string = '');
    procedure SetDefault(const ACertPEM, AKeyPEM: string;
      const AKeyPassword: string = '');

    function ResolveServerCredential(
      const AClientHello: TSSLClientHelloInfo;
      out ACredential: ISSLServerCredential
    ): TSSLOperationResult;
  end;

implementation

{ TSSLSimpleServerCredential }

constructor TSSLSimpleServerCredential.Create(const ACertPEM, AKeyPEM: string;
  const AKeyPassword: string);
begin
  inherited Create;
  FCertPEM := ACertPEM;
  FKeyPEM := AKeyPEM;
  FKeyPassword := AKeyPassword;
end;

function TSSLSimpleServerCredential.GetCertificateChainPEM: string;
begin
  Result := FCertPEM;
end;

function TSSLSimpleServerCredential.GetPrivateKeyPEM: string;
begin
  Result := FKeyPEM;
end;

function TSSLSimpleServerCredential.GetPrivateKeyPassword: string;
begin
  Result := FKeyPassword;
end;

{ TSSLSNICertificateResolver }

constructor TSSLSNICertificateResolver.Create;
begin
  inherited Create;
  SetLength(FEntries, 0);
  FHasDefault := False;
end;

procedure TSSLSNICertificateResolver.AddHost(const AHostname, ACertPEM, AKeyPEM: string;
  const AKeyPassword: string);
var
  LIdx: Integer;
begin
  LIdx := Length(FEntries);
  SetLength(FEntries, LIdx + 1);
  FEntries[LIdx].Hostname := LowerCase(AHostname);
  FEntries[LIdx].CertPEM := ACertPEM;
  FEntries[LIdx].KeyPEM := AKeyPEM;
  FEntries[LIdx].KeyPassword := AKeyPassword;
end;

procedure TSSLSNICertificateResolver.SetDefault(const ACertPEM, AKeyPEM: string;
  const AKeyPassword: string);
begin
  FDefaultEntry.Hostname := '*';
  FDefaultEntry.CertPEM := ACertPEM;
  FDefaultEntry.KeyPEM := AKeyPEM;
  FDefaultEntry.KeyPassword := AKeyPassword;
  FHasDefault := True;
end;

function TSSLSNICertificateResolver.ResolveServerCredential(
  const AClientHello: TSSLClientHelloInfo;
  out ACredential: ISSLServerCredential
): TSSLOperationResult;
var
  I: Integer;
  LName: string;
begin
  ACredential := nil;
  LName := LowerCase(AClientHello.ServerName);

  // Exact match
  for I := 0 to High(FEntries) do
  begin
    if FEntries[I].Hostname = LName then
    begin
      ACredential := TSSLSimpleServerCredential.Create(
        FEntries[I].CertPEM, FEntries[I].KeyPEM, FEntries[I].KeyPassword);
      Exit(TSSLOperationResult.Ok);
    end;
  end;

  // Wildcard match (*.example.com) — RFC 6125 style
  // Only matches exactly one label before the suffix
  for I := 0 to High(FEntries) do
  begin
    if (Length(FEntries[I].Hostname) > 2) and
       (FEntries[I].Hostname[1] = '*') and
       (FEntries[I].Hostname[2] = '.') then
    begin
      // Suffix = ".example.com" (from position 2 onwards)
      // Name must end with suffix AND have exactly one dot before it
      if (Length(LName) > Length(FEntries[I].Hostname) - 1) and
         (Copy(LName, Length(LName) - Length(FEntries[I].Hostname) + 2 + 1,
               Length(FEntries[I].Hostname) - 1) =
          Copy(FEntries[I].Hostname, 2, Length(FEntries[I].Hostname) - 1)) and
         (Pos('.', Copy(LName, 1, Length(LName) - Length(FEntries[I].Hostname) + 2)) = 0) then
      begin
        ACredential := TSSLSimpleServerCredential.Create(
          FEntries[I].CertPEM, FEntries[I].KeyPEM, FEntries[I].KeyPassword);
        Exit(TSSLOperationResult.Ok);
      end;
    end;
  end;

  // Default fallback
  if FHasDefault then
  begin
    ACredential := TSSLSimpleServerCredential.Create(
      FDefaultEntry.CertPEM, FDefaultEntry.KeyPEM, FDefaultEntry.KeyPassword);
    Exit(TSSLOperationResult.Ok);
  end;

  Result := TSSLOperationResult.Err(sslErrCertificate,
    'No certificate found for SNI: ' + AClientHello.ServerName);
end;

end.
