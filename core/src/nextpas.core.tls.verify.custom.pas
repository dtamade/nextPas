unit nextpas.core.tls.verify.custom;

{$mode ObjFPC}{$H+}{$J-}

interface

uses
  nextpas.core.base,
  nextpas.core.tls.base;

type
  { TSSLPinningVerifier — verify server cert by SHA-256 pin }
  TSSLPinningVerifier = class(TInterfacedObject, ISSLServerCertificateVerifier)
  private
    FPins: array of TBytes;
    FAllowIfNoPins: Boolean;
  public
    constructor Create;
    procedure AddPin(const ASHA256Hash: TBytes);
    procedure AddPinHex(const AHexHash: string);
    property AllowIfNoPins: Boolean read FAllowIfNoPins write FAllowIfNoPins;

    function VerifyServerCertificate(
      const ARequest: TSSLServerCertificateVerifyRequest
    ): TSSLOperationResult;
  end;

  { TSSLAllowAllVerifier — DANGEROUS: accepts any certificate (testing only) }
  TSSLAllowAllVerifier = class(TInterfacedObject, ISSLServerCertificateVerifier)
  public
    function VerifyServerCertificate(
      const ARequest: TSSLServerCertificateVerifyRequest
    ): TSSLOperationResult;
  end;

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.tls.exceptions,
  nextpas.core.crypto.hash;

{ TSSLPinningVerifier }

constructor TSSLPinningVerifier.Create;
begin
  inherited Create;
  SetLength(FPins, 0);
  FAllowIfNoPins := False;
end;

procedure TSSLPinningVerifier.AddPin(const ASHA256Hash: nextpas.core.base.TBytes);
var
  LIdx: Integer;
begin
  if Length(ASHA256Hash) <> 32 then
    raise ESSLException.Create('Certificate pin must be 32 bytes (SHA-256)');
  LIdx := Length(FPins);
  SetLength(FPins, LIdx + 1);
  FPins[LIdx] := Copy(ASHA256Hash);
end;

procedure TSSLPinningVerifier.AddPinHex(const AHexHash: string);
var
  LBytes: TBytes;
  I, LVal: Integer;
begin
  if Length(AHexHash) <> 64 then
    raise ESSLException.Create('Certificate pin hex must be 64 characters');
  SetLength(LBytes, 32);
  for I := 0 to 31 do
  begin
    LVal := StrToIntDef('$' + Copy(AHexHash, I * 2 + 1, 2), -1);
    if LVal < 0 then
      raise ESSLException.Create('Invalid hex at position ' + IntToStr(I * 2 + 1) + ' in pin hash');
    LBytes[I] := Byte(LVal);
  end;
  AddPin(LBytes);
end;

function TSSLPinningVerifier.VerifyServerCertificate(
  const ARequest: TSSLServerCertificateVerifyRequest
): TSSLOperationResult;
var
  LCertHash: TBytes;
  I: Integer;
begin
  if Length(FPins) = 0 then
  begin
    if FAllowIfNoPins then
      Exit(TSSLOperationResult.Ok)
    else
      Exit(TSSLOperationResult.Err(sslErrCertificate, 'No certificate pins configured'));
  end;

  if Length(ARequest.LeafCertificateDER) = 0 then
    Exit(TSSLOperationResult.Err(sslErrCertificate, 'No leaf certificate to verify'));

  LCertHash := SHA256(ARequest.LeafCertificateDER);

  for I := 0 to High(FPins) do
  begin
    if (Length(FPins[I]) = 32) and CompareMem(@FPins[I][0], @LCertHash[0], 32) then
      Exit(TSSLOperationResult.Ok);
  end;

  Result := TSSLOperationResult.Err(sslErrVerificationFailed,
    'Certificate does not match any pinned hash for: ' + ARequest.ServerName);
end;

{ TSSLAllowAllVerifier }

function TSSLAllowAllVerifier.VerifyServerCertificate(
  const ARequest: TSSLServerCertificateVerifyRequest
): TSSLOperationResult;
begin
  Result := TSSLOperationResult.Ok;
end;

end.
