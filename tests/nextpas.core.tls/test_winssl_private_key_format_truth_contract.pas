program test_winssl_private_key_format_truth_contract;

{$mode objfpc}{$H+}

uses
  SysUtils,
  Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.exceptions
  {$IFDEF WINDOWS}
  , nextpas.core.tls.winssl.lib
  {$ENDIF}
  ;

const
  TEST_PASSWORD = 'contract-password';
  DUMMY_PRIVATE_KEY_PEM =
    '-----BEGIN PRIVATE KEY-----' + #10 +
    'contract-sentinel' + #10 +
    '-----END PRIVATE KEY-----' + #10;

procedure Require(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

function IsUnsupportedMessage(const AMessage: string): Boolean;
var
  LLower: string;
begin
  LLower := LowerCase(AMessage);
  Result := (Pos('unsupported', LLower) > 0) or
    (Pos('pfx/p12', LLower) > 0) or
    (Pos('不支持', AMessage) > 0);
end;

procedure CheckCapabilityTruth;
var
  LLib: ISSLLibrary;
  LCaps: TSSLBackendCapabilities;
begin
  if not TSSLFactory.IsLibraryAvailable(sslWinSSL) then
  begin
    WriteLn('[SKIP] Windows Schannel backend not available on this platform');
    Exit;
  end;

  LLib := TSSLFactory.GetLibrary(sslWinSSL);
  Require(LLib <> nil, 'WinSSL library should be creatable when available');

  LCaps := LLib.GetCapabilities;
  Require(not LCaps.SupportsDERPrivateKey,
    'WinSSL must publish SupportsDERPrivateKey=False while no bare DER private-key load path exists');
  Require(not LCaps.SupportsPKCS8PrivateKey,
    'WinSSL must publish SupportsPKCS8PrivateKey=False while no bare PKCS#8 private-key load path exists');
  Require(LCaps.SupportsPKCS12,
    'WinSSL must keep SupportsPKCS12=True for PFX/P12 private-key import');

  WriteLn('[PASS] WinSSL capability truth reports DER=False, PKCS8=False, PKCS12=True');
end;

procedure CheckNonPFXFailsClosed;
var
  LLib: ISSLLibrary;
  LCtx: ISSLContext;
  LStream: TStringStream;
  LTempDir: string;
  LTempFile: string;
  LRejected: Boolean;
begin
  if not TSSLFactory.IsLibraryAvailable(sslWinSSL) then
  begin
    WriteLn('[SKIP] Windows Schannel backend not available on this platform');
    Exit;
  end;

  LLib := TSSLFactory.GetLibrary(sslWinSSL);
  Require(LLib <> nil, 'WinSSL library should be creatable when available');
  Require(LLib.Initialize, 'WinSSL library must initialize for runtime contract');

  LCtx := LLib.CreateContext(sslCtxServer);
  Require(LCtx <> nil, 'WinSSL context should be creatable');

  LStream := TStringStream.Create(DUMMY_PRIVATE_KEY_PEM);
  try
    LRejected := False;
    try
      LCtx.LoadPrivateKey(LStream, TEST_PASSWORD);
    except
      on E: ESSLException do
      begin
        Require(IsUnsupportedMessage(E.Message),
          'WinSSL stream non-PFX rejection must report unsupported semantics: ' + E.Message);
        LRejected := True;
      end;
    end;
    Require(LRejected, 'WinSSL stream private-key loader must reject non-PFX input');

    LTempDir := IncludeTrailingPathDelimiter('tmp') + 'test_winssl_private_key_format_truth';
    ForceDirectories(LTempDir);
    LTempFile := IncludeTrailingPathDelimiter(LTempDir) + 'winssl_non_pfx_private_key.pem';
    with TStringList.Create do
    try
      Text := DUMMY_PRIVATE_KEY_PEM;
      SaveToFile(LTempFile);
    finally
      Free;
    end;

    LRejected := False;
    try
      LCtx.LoadPrivateKey(LTempFile, TEST_PASSWORD);
    except
      on E: ESSLException do
      begin
        Require(IsUnsupportedMessage(E.Message),
          'WinSSL file non-PFX rejection must report unsupported semantics: ' + E.Message);
        LRejected := True;
      end;
    end;
    Require(LRejected, 'WinSSL file private-key loader must reject non-PFX input');

    if FileExists(LTempFile) then
      DeleteFile(LTempFile);
  finally
    LStream.Free;
  end;

  WriteLn('[PASS] WinSSL non-PFX private-key inputs fail-closed as unsupported');
end;

begin
  WriteLn('Testing WinSSL private-key format truth contract');
  WriteLn('===============================================');

  CheckCapabilityTruth;
  CheckNonPFXFailsClosed;

  WriteLn('===============================================');
  WriteLn('✅ WinSSL private-key format truth contract verified');
end.
