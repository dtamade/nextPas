unit nextpas.core.tls.sni.callback;

{$mode objfpc}{$H+}{$J-}

interface

uses
  nextpas.core.base,
   nextpas.core.tls.x509;

type
  TSNICertificateEntry = record
    Hostname: string;
    CertificateDER: TBytes;
    PrivateKeyDER: TBytes;
    Certificate: TX509Certificate;
  end;

  TSNICertificateSelector = class
  private
    FEntries: array of TSNICertificateEntry;
    FDefaultIndex: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddCertificate(const AHostname: string; const ACertDER, AKeyDER: TBytes);
    procedure SetDefault(const AHostname: string);
    function SelectForHostname(const AHostname: string): Integer;
    function GetEntry(AIndex: Integer): TSNICertificateEntry;
    function Count: Integer;
  end;

implementation

constructor TSNICertificateSelector.Create;
begin
  inherited Create;
  SetLength(FEntries, 0);
  FDefaultIndex := -1;
end;

destructor TSNICertificateSelector.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(FEntries) do
    FEntries[I].Certificate.Free;
  SetLength(FEntries, 0);
  inherited;
end;

procedure TSNICertificateSelector.AddCertificate(const AHostname: string;
  const ACertDER, AKeyDER: TBytes);
var
  LIdx: Integer;
begin
  LIdx := Length(FEntries);
  SetLength(FEntries, LIdx + 1);
  FEntries[LIdx].Hostname := LowerCase(AHostname);
  FEntries[LIdx].CertificateDER := ACertDER;
  FEntries[LIdx].PrivateKeyDER := AKeyDER;
  FEntries[LIdx].Certificate := TX509Certificate.Create;
  try
    FEntries[LIdx].Certificate.LoadFromDER(ACertDER);
  except
    // DER parsing optional — selector works with raw DER bytes
  end;
  if FDefaultIndex < 0 then
    FDefaultIndex := LIdx;
end;

procedure TSNICertificateSelector.SetDefault(const AHostname: string);
var
  I: Integer;
begin
  for I := 0 to High(FEntries) do
    if FEntries[I].Hostname = LowerCase(AHostname) then
    begin
      FDefaultIndex := I;
      Exit;
    end;
end;

function TSNICertificateSelector.SelectForHostname(const AHostname: string): Integer;
var
  I: Integer;
  LHost: string;
begin
  LHost := LowerCase(AHostname);
  for I := 0 to High(FEntries) do
  begin
    if FEntries[I].Hostname = LHost then
      Exit(I);
    if (Length(FEntries[I].Hostname) > 2) and (FEntries[I].Hostname[1] = '*') and
       (Pos(Copy(FEntries[I].Hostname, 2, MaxInt), LHost) > 0) then
      Exit(I);
  end;
  Result := FDefaultIndex;
end;

function TSNICertificateSelector.GetEntry(AIndex: Integer): TSNICertificateEntry;
begin
  Result := FEntries[AIndex];
end;

function TSNICertificateSelector.Count: Integer;
begin
  Result := Length(FEntries);
end;

end.
