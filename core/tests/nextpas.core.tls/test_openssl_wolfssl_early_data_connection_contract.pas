program test_openssl_wolfssl_early_data_connection_contract;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  fafafa.ssl,
  nextpas.core.tls.openssl.backed,
  nextpas.core.tls.wolfssl.api,
  nextpas.core.tls.wolfssl.lib;

type
  TMockSession = class(TInterfacedObject, ISSLSession)
  private
    FID: string;
  public
    constructor Create(const AID: string);

    function GetID: string;
    function GetCreationTime: TDateTime;
    function GetTimeout: Integer;
    procedure SetTimeout(ATimeout: Integer);
    function IsValid: Boolean;
    function IsResumable: Boolean;
    function GetProtocolVersion: TSSLProtocolVersion;
    function GetCipherName: string;
    function GetPeerCertificate: ISSLCertificate;
    function Serialize: TBytes;
    function Deserialize(const AData: TBytes): Boolean;
    function Clone: ISSLSession;
  end;

var
  GTotal: Integer = 0;
  GPassed: Integer = 0;
  GFailed: Integer = 0;
  GSkipped: Integer = 0;

procedure Pass(const AName: string);
begin
  Inc(GTotal);
  Inc(GPassed);
  WriteLn('[PASS] ', AName);
end;

procedure Fail(const AName, ADetail: string);
begin
  Inc(GTotal);
  Inc(GFailed);
  WriteLn('[FAIL] ', AName);
  if ADetail <> '' then
    WriteLn('       ', ADetail);
end;

procedure Skip(const AName, AReason: string);
begin
  Inc(GTotal);
  Inc(GSkipped);
  WriteLn('[SKIP] ', AName, ' - ', AReason);
end;

procedure CheckTrue(const AName: string; ACondition: Boolean; const ADetail: string = '');
begin
  if ACondition then
    Pass(AName)
  else
    Fail(AName, ADetail);
end;

function BytesOfText(const AText: string): TBytes;
begin
  SetLength(Result, Length(AText));
  if Length(Result) > 0 then
    Move(AText[1], Result[0], Length(Result));
end;

constructor TMockSession.Create(const AID: string);
begin
  inherited Create;
  FID := AID;
end;

function TMockSession.GetID: string;
begin
  Result := FID;
end;

function TMockSession.GetCreationTime: TDateTime;
begin
  Result := Now;
end;

function TMockSession.GetTimeout: Integer;
begin
  Result := 300;
end;

procedure TMockSession.SetTimeout(ATimeout: Integer);
begin
end;

function TMockSession.IsValid: Boolean;
begin
  Result := True;
end;

function TMockSession.IsResumable: Boolean;
begin
  Result := True;
end;

function TMockSession.GetProtocolVersion: TSSLProtocolVersion;
begin
  Result := sslProtocolTLS13;
end;

function TMockSession.GetCipherName: string;
begin
  Result := 'MOCK-CIPHER';
end;

function TMockSession.GetPeerCertificate: ISSLCertificate;
begin
  Result := nil;
end;

function TMockSession.Serialize: TBytes;
begin
  SetLength(Result, 0);
end;

function TMockSession.Deserialize(const AData: TBytes): Boolean;
begin
  Result := True;
end;

function TMockSession.Clone: ISSLSession;
begin
  Result := TMockSession.Create(FID);
end;

procedure CheckOperationError(const AName: string; const AResult: TSSLOperationResult;
  AExpectedCode: TSSLErrorCode);
begin
  CheckTrue(AName,
    (not AResult.Success) and (AResult.ErrorCode = AExpectedCode),
    Format('expected error=%d, actual success=%s error=%d msg=%s',
      [Ord(AExpectedCode), BoolToStr(AResult.Success, True),
       Ord(AResult.ErrorCode), AResult.ErrorMessage]));
end;

procedure TestBackend(ABackend: TSSLLibraryType;
  AExpectedSupport: TSSLFeatureSupportLevel);
var
  LName: string;
  LLib: ISSLLibrary;
  LCaps: TSSLBackendCapabilities;
  LCtx: ISSLContext;
  LEarlyCtx: ISSLEarlyDataContext;
  LConn: ISSLConnection;
  LResumption: ISSLSessionResumption;
  LEarlyConn: ISSLEarlyDataConnection;
  LStream: TMemoryStream;
  LResult: TSSLOperationResult;
begin
  LName := SSL_LIBRARY_NAMES[ABackend];

  WriteLn;
  WriteLn('=== ', LName, ' early-data connection contract ===');

  if ABackend = sslWolfSSL then
  begin
    LLib := CreateWolfSSLLibrary;
    if (LLib = nil) or (not LLib.Initialize) then
    begin
      Skip(LName, 'backend failed to initialize');
      Exit;
    end;
  end
  else if not TSSLFactory.IsLibraryAvailable(ABackend) then
  begin
    Skip(LName, 'backend not available on this platform');
    Exit;
  end
  else
  begin
    LLib := TSSLFactory.GetLibraryInstance(ABackend);
    if (LLib = nil) or (not LLib.Initialize) then
    begin
      Skip(LName, 'backend failed to initialize');
      Exit;
    end;
  end;

  if LLib = nil then
  begin
    Skip(LName, 'backend failed to initialize');
    Exit;
  end;

  if ABackend = sslWolfSSL then
  begin
    if Assigned(wolfSSL_write_early_data) and
       Assigned(wolfSSL_get_early_data_status) and
       Assigned(wolfSSL_CTX_set_max_early_data) and
       Assigned(wolfSSL_CTX_get_max_early_data) then
      AExpectedSupport := sslSupportExperimental
    else
      AExpectedSupport := sslSupportNone;
  end;

  LCaps := LLib.GetCapabilities;
  CheckTrue(LName + ' capability early-data support',
    LCaps.EarlyDataSupport = AExpectedSupport,
    Format('expected=%d actual=%d', [Ord(AExpectedSupport), Ord(LCaps.EarlyDataSupport)]));

  LCtx := LLib.CreateContext(sslCtxClient);
  if AExpectedSupport = sslSupportNone then
  begin
    CheckTrue(LName + ' context keeps ISSLEarlyDataContext absent when capability is none',
      not Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx),
      'client context should keep ISSLEarlyDataContext absent when capability is none');

    LStream := TMemoryStream.Create;
    try
      LConn := LCtx.CreateConnection(LStream);
      CheckTrue(LName + ' helper keeps early-data connection absent when capability is none',
        not TSSLHelper.SupportsEarlyDataConnection(LConn),
        'TSSLHelper.SupportsEarlyDataConnection should be False when capability is none');
      CheckTrue(LName + ' connection keeps ISSLEarlyDataConnection absent when capability is none',
        not Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
        'client connection should keep ISSLEarlyDataConnection absent when capability is none');
    finally
      LStream.Free;
    end;
    Exit;
  end;

  CheckTrue(LName + ' context exposes ISSLEarlyDataContext',
    Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx),
    'client context should expose ISSLEarlyDataContext');
  if not Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx) then
    Exit;

  CheckTrue(LName + ' client early-data defaults disabled',
    not LEarlyCtx.GetClientEarlyDataEnabled,
    'GetClientEarlyDataEnabled should default to False');

  LStream := TMemoryStream.Create;
  try
    LConn := LCtx.CreateConnection(LStream);

    CheckTrue(LName + ' helper detects ISSLEarlyDataConnection',
      TSSLHelper.SupportsEarlyDataConnection(LConn),
      'TSSLHelper.SupportsEarlyDataConnection should be True');
    CheckTrue(LName + ' connection exposes ISSLEarlyDataConnection',
      Supports(LConn, ISSLEarlyDataConnection, LEarlyConn),
      'client connection should expose ISSLEarlyDataConnection');
    if not Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
      Exit;

    CheckTrue(LName + ' helper status defaults to none',
      TSSLHelper.GetEarlyDataStatus(LConn) = sslEarlyDataNone,
      Format('actual=%d', [Ord(TSSLHelper.GetEarlyDataStatus(LConn))]));
    CheckTrue(LName + ' helper limit defaults to zero',
      TSSLHelper.GetEarlyDataLimit(LConn) = 0,
      Format('actual=%d', [TSSLHelper.GetEarlyDataLimit(LConn)]));

    LResult := LEarlyConn.SetEarlyData(BytesOfText('PING'));
    CheckOperationError(LName + ' SetEarlyData requires enabled client early-data',
      LResult, sslErrConfiguration);

    LEarlyCtx.SetClientEarlyDataEnabled(True);

    LResult := LEarlyConn.SetEarlyData(BytesOfText('PING'));
    CheckOperationError(LName + ' SetEarlyData requires configured resumable session',
      LResult, sslErrInvalidParam);

    CheckTrue(LName + ' connection exposes ISSLSessionResumption',
      Supports(LConn, ISSLSessionResumption, LResumption),
      'client connection should expose ISSLSessionResumption');
    if not Supports(LConn, ISSLSessionResumption, LResumption) then
      Exit;
    LResumption.SetSession(TMockSession.Create('mock-session'));
    LResult := LEarlyConn.SetEarlyData(BytesOfText('PING'));
    CheckOperationError(LName + ' SetEarlyData rejects session without usable native early-data limit',
      LResult, sslErrInvalidParam);

    CheckTrue(LName + ' failed queue keeps status at none',
      LEarlyConn.GetEarlyDataStatus = sslEarlyDataNone,
      Format('actual=%d', [Ord(LEarlyConn.GetEarlyDataStatus)]));
    CheckTrue(LName + ' failed queue keeps limit at zero',
      LEarlyConn.GetEarlyDataLimit = 0,
      Format('actual=%d', [LEarlyConn.GetEarlyDataLimit]));
  finally
    LStream.Free;
  end;
end;

begin
  try
    TestBackend(sslOpenSSL, sslSupportStable);
    TestBackend(sslWolfSSL, sslSupportExperimental);

    WriteLn;
    WriteLn('Summary');
    WriteLn('  Total:   ', GTotal);
    WriteLn('  Passed:  ', GPassed);
    WriteLn('  Failed:  ', GFailed);
    WriteLn('  Skipped: ', GSkipped);

    if GFailed > 0 then
      Halt(1);
  except
    on E: Exception do
    begin
      WriteLn('FATAL: ', E.ClassName, ': ', E.Message);
      Halt(2);
    end;
  end;
end.
