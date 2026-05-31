program test_backend_callback_setter_fail_closed_contract;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.freepascal.lib
  {$IFDEF UNIX}
  , nextpas.core.tls.openssl.backed
  , nextpas.core.tls.openssl.api.core
  , nextpas.core.tls.openssl.api.ssl
  , nextpas.core.tls.mbedtls.lib
  , nextpas.core.tls.wolfssl.lib
  {$ENDIF}
  {$IFDEF WINDOWS}
  , nextpas.core.tls.openssl.backed
  , nextpas.core.tls.openssl.api.core
  , nextpas.core.tls.openssl.api.ssl
  , nextpas.core.tls.winssl.lib
  , nextpas.core.tls.mbedtls.lib
  , nextpas.core.tls.wolfssl.lib
  {$ENDIF}
  ;

type
  TCallbackKind = (ckVerify, ckPassword, ckInfo);

  TCallbackProbe = class
  public
    function VerifyCallback(const ACertificate: TSSLCertificateInfo;
      const AErrorCode: Integer; const AErrorMessage: string): Boolean;
    function PasswordCallback(var APassword: string; const AIsRetry: Boolean): Boolean;
    procedure InfoCallback(const AWhere: Integer; const ARet: Integer; const AState: string);
  end;

function TCallbackProbe.VerifyCallback(const ACertificate: TSSLCertificateInfo;
  const AErrorCode: Integer; const AErrorMessage: string): Boolean;
begin
  Result := True;
end;

function TCallbackProbe.PasswordCallback(var APassword: string;
  const AIsRetry: Boolean): Boolean;
begin
  APassword := '';
  Result := True;
end;

procedure TCallbackProbe.InfoCallback(const AWhere: Integer;
  const ARet: Integer; const AState: string);
begin
end;

procedure Require(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

function CallbackKindName(AKind: TCallbackKind): string;
begin
  case AKind of
    ckVerify: Result := 'Verify callback';
    ckPassword: Result := 'Password callback';
    ckInfo: Result := 'Info callback';
  end;
end;

procedure AssignNonNilCallback(ACtx: ISSLContext; AKind: TCallbackKind; AProbe: TCallbackProbe);
begin
  case AKind of
    ckVerify: ACtx.SetVerifyCallback(@AProbe.VerifyCallback);
    ckPassword: ACtx.SetPasswordCallback(@AProbe.PasswordCallback);
    ckInfo: ACtx.SetInfoCallback(@AProbe.InfoCallback);
  end;
end;

procedure ClearCallback(ACtx: ISSLContext; AKind: TCallbackKind);
begin
  case AKind of
    ckVerify: ACtx.SetVerifyCallback(nil);
    ckPassword: ACtx.SetPasswordCallback(nil);
    ckInfo: ACtx.SetInfoCallback(nil);
  end;
end;

procedure CheckPublishedBackend(ABackend: TSSLLibraryType);
var
  LLib: ISSLLibrary;
  LCtx: ISSLContext;
  LProbe: TCallbackProbe;
  LKind: TCallbackKind;
begin
  if not TSSLFactory.IsLibraryAvailable(ABackend) then
  begin
    WriteLn('[SKIP] ', SSL_LIBRARY_NAMES[ABackend], ' backend not available on this platform');
    Exit;
  end;

  LLib := TSSLFactory.GetLibrary(ABackend);
  Require(LLib <> nil, SSL_LIBRARY_NAMES[ABackend] + ' library should be creatable when available');
  Require(LLib.GetCapabilities.SupportsCallbacks,
    SSL_LIBRARY_NAMES[ABackend] + ' must publish SupportsCallbacks=True for this contract');

  LCtx := LLib.CreateContext(sslCtxClient);
  Require(LCtx <> nil, SSL_LIBRARY_NAMES[ABackend] + ' context should be creatable');
  LProbe := TCallbackProbe.Create;
  try
    for LKind := Low(TCallbackKind) to High(TCallbackKind) do
    begin
      try
        AssignNonNilCallback(LCtx, LKind, LProbe);
      except
        on E: Exception do
          raise Exception.CreateFmt('%s should accept non-nil %s when SupportsCallbacks=True: %s',
            [SSL_LIBRARY_NAMES[ABackend], CallbackKindName(LKind), E.Message]);
      end;

      try
        ClearCallback(LCtx, LKind);
      except
        on E: Exception do
          raise Exception.CreateFmt('%s should accept nil clear for %s when SupportsCallbacks=True: %s',
            [SSL_LIBRARY_NAMES[ABackend], CallbackKindName(LKind), E.Message]);
      end;
    end;
  finally
    LProbe.Free;
  end;

  WriteLn('[PASS] ', SSL_LIBRARY_NAMES[ABackend],
    ' published callback setters accept non-nil assignments and nil clears');
end;

procedure CheckWinSSLPartialBackend(ABackend: TSSLLibraryType);
var
  LLib: ISSLLibrary;
  LCtx: ISSLContext;
  LProbe: TCallbackProbe;
  LRejected: Boolean;
  LLowerMsg: string;
begin
  if not TSSLFactory.IsLibraryAvailable(ABackend) then
  begin
    WriteLn('[SKIP] ', SSL_LIBRARY_NAMES[ABackend], ' backend not available on this platform');
    Exit;
  end;

  LLib := TSSLFactory.GetLibrary(ABackend);
  Require(LLib <> nil, SSL_LIBRARY_NAMES[ABackend] + ' library should be creatable when available');
  Require(LLib.GetCapabilities.SupportsCallbacks,
    SSL_LIBRARY_NAMES[ABackend] + ' must publish SupportsCallbacks=True for this contract');

  LCtx := LLib.CreateContext(sslCtxClient);
  Require(LCtx <> nil, SSL_LIBRARY_NAMES[ABackend] + ' context should be creatable');
  LProbe := TCallbackProbe.Create;
  try
    AssignNonNilCallback(LCtx, ckVerify, LProbe);
    ClearCallback(LCtx, ckVerify);

    AssignNonNilCallback(LCtx, ckInfo, LProbe);
    ClearCallback(LCtx, ckInfo);

    LRejected := False;
    try
      AssignNonNilCallback(LCtx, ckPassword, LProbe);
    except
      on E: ESSLException do
      begin
        LLowerMsg := LowerCase(E.Message);
        Require((E.ErrorCode = sslErrUnsupported) or (Pos('unsupported', LLowerMsg) > 0) or
          (Pos('不支持', E.Message) > 0),
          Format('%s password callback rejection must report unsupported semantics: %s',
            [SSL_LIBRARY_NAMES[ABackend], E.Message]));
        LRejected := True;
      end;
    end;

    Require(LRejected,
      SSL_LIBRARY_NAMES[ABackend] + ' must reject non-nil password callback while only verify/info are published');

    ClearCallback(LCtx, ckPassword);
  finally
    LProbe.Free;
  end;

  WriteLn('[PASS] ', SSL_LIBRARY_NAMES[ABackend],
    ' verify/info callbacks remain published while password callback fails closed');
end;

procedure CheckUnpublishedBackend(ABackend: TSSLLibraryType);
var
  LLib: ISSLLibrary;
  LCtx: ISSLContext;
  LProbe: TCallbackProbe;
  LKind: TCallbackKind;
  LRejected: Boolean;
  LLowerMsg: string;
begin
  if not TSSLFactory.IsLibraryAvailable(ABackend) then
  begin
    WriteLn('[SKIP] ', SSL_LIBRARY_NAMES[ABackend], ' backend not available on this platform');
    Exit;
  end;

  LLib := TSSLFactory.GetLibrary(ABackend);
  Require(LLib <> nil, SSL_LIBRARY_NAMES[ABackend] + ' library should be creatable when available');
  Require(not LLib.GetCapabilities.SupportsCallbacks,
    SSL_LIBRARY_NAMES[ABackend] + ' must publish SupportsCallbacks=False for this contract');

  LCtx := LLib.CreateContext(sslCtxClient);
  Require(LCtx <> nil, SSL_LIBRARY_NAMES[ABackend] + ' context should be creatable');
  LProbe := TCallbackProbe.Create;
  try
    for LKind := Low(TCallbackKind) to High(TCallbackKind) do
    begin
      LRejected := False;
      try
        AssignNonNilCallback(LCtx, LKind, LProbe);
      except
        on E: ESSLException do
        begin
          LLowerMsg := LowerCase(E.Message);
          Require((E.ErrorCode = sslErrUnsupported) or (Pos('unsupported', LLowerMsg) > 0) or
            (Pos('不支持', E.Message) > 0),
            Format('%s non-nil %s rejection must report unsupported semantics: %s',
              [SSL_LIBRARY_NAMES[ABackend], CallbackKindName(LKind), E.Message]));
          LRejected := True;
        end;
      end;

      Require(LRejected,
        Format('%s must reject non-nil %s while SupportsCallbacks=False',
          [SSL_LIBRARY_NAMES[ABackend], CallbackKindName(LKind)]));

      try
        ClearCallback(LCtx, LKind);
      except
        on E: Exception do
          raise Exception.CreateFmt('%s should accept nil clear for %s while SupportsCallbacks=False: %s',
            [SSL_LIBRARY_NAMES[ABackend], CallbackKindName(LKind), E.Message]);
      end;
    end;
  finally
    LProbe.Free;
  end;

  WriteLn('[PASS] ', SSL_LIBRARY_NAMES[ABackend],
    ' unpublished callback setters fail-closed on non-nil assignments and accept nil clears');
end;

procedure CheckOpenSSLIncompleteSurfaceFailsClosed;
var
  LLib: ISSLLibrary;
  LCtx: ISSLContext;
  LProbe: TCallbackProbe;
  LKind: TCallbackKind;
  LRejected: Boolean;
  LLowerMsg: string;
  LOrigPasswordUserdata: TSSL_CTX_set_default_passwd_cb_userdata;
begin
  if not TSSLFactory.IsLibraryAvailable(sslOpenSSL) then
  begin
    WriteLn('[SKIP] OpenSSL backend not available on this platform');
    Exit;
  end;

  LLib := TOpenSSLLibrary.Create as ISSLLibrary;
  Require(LLib.Initialize,
    'OpenSSL probe library should initialize for incomplete callback-surface contract');

  LOrigPasswordUserdata := SSL_CTX_set_default_passwd_cb_userdata;
  if not Assigned(LOrigPasswordUserdata) then
  begin
    WriteLn('[SKIP] OpenSSL build does not export password callback userdata helper');
    Exit;
  end;

  SSL_CTX_set_default_passwd_cb_userdata := nil;
  try
    Require(not LLib.GetCapabilities.SupportsCallbacks,
      'OpenSSL must stop publishing SupportsCallbacks when callback helper surface is incomplete');

    LCtx := LLib.CreateContext(sslCtxClient);
    Require(LCtx <> nil, 'OpenSSL context should still be creatable while callbacks are unpublished');

    LProbe := TCallbackProbe.Create;
    try
      for LKind := Low(TCallbackKind) to High(TCallbackKind) do
      begin
        LRejected := False;
        try
          AssignNonNilCallback(LCtx, LKind, LProbe);
        except
          on E: ESSLException do
          begin
            LLowerMsg := LowerCase(E.Message);
            Require((E.ErrorCode = sslErrUnsupported) or (Pos('unsupported', LLowerMsg) > 0) or
              (Pos('不支持', E.Message) > 0),
              Format('OpenSSL incomplete callback surface must report unsupported for non-nil %s: %s',
                [CallbackKindName(LKind), E.Message]));
            LRejected := True;
          end;
        end;

        Require(LRejected,
          Format('OpenSSL must reject non-nil %s when callback helper surface is incomplete',
            [CallbackKindName(LKind)]));

        try
          ClearCallback(LCtx, LKind);
        except
          on E: Exception do
            raise Exception.CreateFmt(
              'OpenSSL nil clear should stay available for %s while callback helper surface is incomplete: %s',
              [CallbackKindName(LKind), E.Message]
            );
        end;
      end;
    finally
      LProbe.Free;
    end;
  finally
    LCtx := nil;
    SSL_CTX_set_default_passwd_cb_userdata := LOrigPasswordUserdata;
    LLib := nil;
  end;

  WriteLn('[PASS] OpenSSL incomplete callback surface fails closed across verify/password/info setters');
end;

procedure CheckOpenSSLPublishedStateFromRuntimeGate;
var
  LLib: ISSLLibrary;
begin
  if not TSSLFactory.IsLibraryAvailable(sslOpenSSL) then
  begin
    WriteLn('[SKIP] OpenSSL backend not available on this platform');
    Exit;
  end;

  LLib := TSSLFactory.GetLibrary(sslOpenSSL);
  Require(LLib <> nil, 'OpenSSL library should be creatable when available');

  if OpenSSLPublishedContextCallbackSurfaceReady then
    CheckPublishedBackend(sslOpenSSL)
  else
    CheckUnpublishedBackend(sslOpenSSL);
end;

begin
  WriteLn('Testing backend callback setter fail-closed contract');
  WriteLn('====================================================');

  CheckOpenSSLPublishedStateFromRuntimeGate;
  CheckWinSSLPartialBackend(sslWinSSL);
  CheckUnpublishedBackend(sslFreePascal);
  CheckUnpublishedBackend(sslWolfSSL);
  CheckUnpublishedBackend(sslMbedTLS);
  CheckOpenSSLIncompleteSurfaceFailsClosed;

  WriteLn('====================================================');
  WriteLn('✅ backend callback setter fail-closed contract verified');
end.
