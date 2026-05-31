program test_certificate_clone_issuer_link_contract;

{$mode objfpc}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.openssl.backed,
  nextpas.core.tls.wolfssl.lib,
  nextpas.core.tls.mbedtls.lib,
  nextpas.core.tls.freepascal.lib
  {$IFDEF WINDOWS}
  , nextpas.core.tls.winssl.lib
  {$ENDIF}
  ;

var
  GTotal: Integer = 0;
  GPassed: Integer = 0;
  GFailed: Integer = 0;
  GSkipped: Integer = 0;

procedure Pass(const AMessage: string);
begin
  Inc(GTotal);
  Inc(GPassed);
  WriteLn('[PASS] ', AMessage);
end;

procedure Fail(const AMessage: string);
begin
  Inc(GTotal);
  Inc(GFailed);
  WriteLn('[FAIL] ', AMessage);
end;

procedure Skip(const AMessage: string);
begin
  Inc(GTotal);
  Inc(GSkipped);
  WriteLn('[SKIP] ', AMessage);
end;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
    Pass(AMessage)
  else
    Fail(AMessage);
end;

function ReadTextFile(const AFileName: string): string;
var
  LStream: TFileStream;
  LBytes: TBytes;
begin
  Result := '';
  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
  try
    SetLength(LBytes, LStream.Size);
    if LStream.Size > 0 then
      LStream.ReadBuffer(LBytes[0], LStream.Size);
  finally
    LStream.Free;
  end;

  if Length(LBytes) > 0 then
    SetString(Result, PAnsiChar(@LBytes[0]), Length(LBytes));
end;

function CreateLibraryForBackend(ABackend: TSSLLibraryType): ISSLLibrary;
begin
  case ABackend of
    sslOpenSSL:
      Result := CreateOpenSSLLibrary;
    sslWolfSSL:
      Result := CreateWolfSSLLibrary;
    sslMbedTLS:
      Result := CreateMbedTLSLibrary;
    {$IFDEF WINDOWS}
    sslWinSSL:
      Result := CreateWinSSLLibrary;
    {$ENDIF}
    sslFreePascal:
      Result := CreateFreePascalSSLLibrary;
  else
    Result := nil;
  end;
end;

procedure RunCloneIssuerLinkCase(ABackend: TSSLLibraryType; const AName: string);
var
  LLib: ISSLLibrary;
  LLeaf: ISSLCertificate;
  LIssuer: ISSLCertificate;
  LClone: ISSLCertificate;
  LCloneIssuer: ISSLCertificate;
  LPrefix: string;
  LLeafPEM: string;
  LIssuerPEM: string;
begin
  LPrefix := AName + ': ';

  LLib := CreateLibraryForBackend(ABackend);
  if LLib = nil then
  begin
    Skip(LPrefix + 'library creator returned nil');
    Exit;
  end;

  if not LLib.Initialize then
  begin
    Skip(LPrefix + 'library runtime unavailable');
    Exit;
  end;

  try
    LLeaf := LLib.CreateCertificate;
    LIssuer := LLib.CreateCertificate;
    if (LLeaf = nil) or (LIssuer = nil) then
    begin
      Fail(LPrefix + 'failed to create fixture certificates');
      Exit;
    end;

    LLeafPEM := ReadTextFile('tests/certificate/test_certs/signer_cert.pem');
    if not LLeaf.LoadFromPEM(LLeafPEM) then
    begin
      Fail(LPrefix + 'failed to load leaf fixture');
      Exit;
    end;

    LIssuerPEM := ReadTextFile('tests/certificate/test_certs/ca_cert.pem');
    if not LIssuer.LoadFromPEM(LIssuerPEM) then
    begin
      Fail(LPrefix + 'failed to load issuer fixture');
      Exit;
    end;

    LLeaf.SetIssuerCertificate(LIssuer);
    LClone := LLeaf.Clone;

    Check(LClone <> nil, LPrefix + 'clone should succeed');
    if LClone = nil then
      Exit;

    Check(
      SameText(LClone.GetFingerprintSHA256, LLeaf.GetFingerprintSHA256),
      LPrefix + 'clone should preserve leaf fingerprint truth');

    LCloneIssuer := LClone.GetIssuerCertificate;
    Check(LCloneIssuer <> nil, LPrefix + 'clone should preserve issuer link');
    if LCloneIssuer = nil then
      Exit;

    Check(
      SameText(LCloneIssuer.GetFingerprintSHA256, LIssuer.GetFingerprintSHA256),
      LPrefix + 'clone issuer link should match the original issuer fixture');
  finally
    LLib.Finalize;
  end;
end;

begin
  WriteLn('Testing certificate clone issuer-link contract...');
  RunCloneIssuerLinkCase(sslOpenSSL, 'OpenSSL');
  RunCloneIssuerLinkCase(sslWolfSSL, 'WolfSSL');
  RunCloneIssuerLinkCase(sslMbedTLS, 'MbedTLS');
  {$IFDEF WINDOWS}
  RunCloneIssuerLinkCase(sslWinSSL, 'WinSSL');
  {$ENDIF}
  RunCloneIssuerLinkCase(sslFreePascal, 'FreePascal');

  WriteLn('');
  WriteLn('Total: ', GTotal, ' Passed: ', GPassed, ' Failed: ', GFailed,
    ' Skipped: ', GSkipped);
  if GFailed > 0 then
    Halt(1);
end.
