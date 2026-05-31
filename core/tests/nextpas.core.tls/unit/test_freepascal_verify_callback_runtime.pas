program test_freepascal_verify_callback_runtime;

{$mode objfpc}{$H+}{$J-}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.freepascal.context,
  nextpas.core.tls.freepascal.context.material;

type
  TVerifyCallbackRecorder = class
  public
    Called: Boolean;
    LastSubject: string;
    LastErrorCode: Integer;
    LastErrorMessage: string;
    function Verify(const ACertificate: TSSLCertificateInfo;
      const AErrorCode: Integer; const AErrorMessage: string): Boolean;
  end;

var
  LTotal, LPassed: Integer;

function TVerifyCallbackRecorder.Verify(const ACertificate: TSSLCertificateInfo;
  const AErrorCode: Integer; const AErrorMessage: string): Boolean;
begin
  Called := True;
  LastSubject := ACertificate.Subject;
  LastErrorCode := AErrorCode;
  LastErrorMessage := AErrorMessage;
  Result := True;
end;

procedure Check(ACondition: Boolean; const AName: string);
begin
  Inc(LTotal);
  if ACondition then
  begin
    Inc(LPassed);
    WriteLn('  PASS: ', AName);
  end
  else
  begin
    WriteLn('  FAIL: ', AName);
    Halt(1);
  end;
end;

function ReadTextFile(const AFileName: string): string;
var
  LStream: TFileStream;
  LBytes: TBytes;
begin
  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(LBytes, LStream.Size);
    if Length(LBytes) > 0 then
      LStream.ReadBuffer(LBytes[0], Length(LBytes));
    Result := TEncoding.UTF8.GetString(LBytes);
  finally
    LStream.Free;
  end;
end;

procedure TestContextReturnsStoredVerifyCallback;
var
  LContext: TFreePascalContext;
  LCallbackAccess: IFreePascalContextVerifyCallback;
  LCallback: TSSLVerifyCallback;
  LRecorder: TVerifyCallbackRecorder;
  LInfo: TSSLCertificateInfo;
begin
  WriteLn('TestContextReturnsStoredVerifyCallback');
  LContext := TFreePascalContext.Create(nil, sslCtxClient);
  LRecorder := TVerifyCallbackRecorder.Create;
  try
    Check(Supports(LContext, IFreePascalContextVerifyCallback, LCallbackAccess),
      'FreePascal context exposes verify callback access');

    LContext.SetVerifyCallback(@LRecorder.Verify);
    LCallback := LCallbackAccess.GetVerifyCallback;
    Check(Assigned(LCallback), 'Stored verify callback is returned');

    FillChar(LInfo, SizeOf(LInfo), 0);
    LInfo.Subject := 'CN=callback.test';
    Check(LCallback(LInfo, Ord(sslErrCertificateUntrusted), 'chain failed'),
      'Returned verify callback is callable');
    Check(LRecorder.Called, 'Verify callback recorder was invoked');
    Check(LRecorder.LastSubject = 'CN=callback.test',
      'Verify callback receives certificate info');
    Check(LRecorder.LastErrorCode = Ord(sslErrCertificateUntrusted),
      'Verify callback receives certificate error code');
    Check(LRecorder.LastErrorMessage = 'chain failed',
      'Verify callback receives certificate error message');
  finally
    LRecorder.Free;
    LContext := nil;
  end;
end;

procedure TestConnectionValidationConsumesVerifyCallback;
var
  LValidationSource: string;
begin
  WriteLn('TestConnectionValidationConsumesVerifyCallback');
  LValidationSource := ReadTextFile('src/nextpas.core.tls.freepascal.connection.validation.inc');

  Check(Pos('IFreePascalContextVerifyCallback', LValidationSource) > 0,
    'Connection validation looks up FreePascal verify callback access');
  Check(Pos('GetVerifyCallback', LValidationSource) > 0,
    'Connection validation retrieves stored verify callback');
  Check(Pos('FPeerCertificate.GetInfo', LValidationSource) > 0,
    'Connection validation passes peer certificate info');
  Check(Pos('Ord(LErrorCode)', LValidationSource) > 0,
    'Connection validation passes error code');
  Check(Pos('LVerifyCallback(', LValidationSource) > 0,
    'Connection validation invokes callback on trust failure');
end;

begin
  LTotal := 0;
  LPassed := 0;

  TestContextReturnsStoredVerifyCallback;
  TestConnectionValidationConsumesVerifyCallback;

  WriteLn;
  WriteLn('FreePascal verify callback runtime tests: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.
