program test_tssllibrarydefaults_surface;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fafafa.ssl;

type
  TLogRecorder = class
  public
    CallCount: Integer;
    LastLevel: TSSLLogLevel;
    LastMessage: string;

    procedure HandleLog(ALevel: TSSLLogLevel; const AMessage: string);
    procedure Reset;
  end;

procedure AssertTrue(const AName: string; AValue: Boolean);
begin
  if AValue then
    WriteLn('  [PASS] ', AName)
  else
  begin
    WriteLn('  [FAIL] ', AName);
    Halt(1);
  end;
end;

function CallbackEquals(AExpected, AActual: TSSLLogCallback): Boolean;
begin
  Result := (TMethod(AExpected).Code = TMethod(AActual).Code) and
            (TMethod(AExpected).Data = TMethod(AActual).Data);
end;

procedure TLogRecorder.HandleLog(ALevel: TSSLLogLevel; const AMessage: string);
begin
  Inc(CallCount);
  LastLevel := ALevel;
  LastMessage := AMessage;
end;

procedure TLogRecorder.Reset;
begin
  CallCount := 0;
  LastLevel := sslLogNone;
  LastMessage := '';
end;

procedure Test_DefaultBaseline;
var
  LDefaults: TSSLLibraryDefaults;
begin
  LDefaults := CreateDefaultLibraryDefaults;
  AssertTrue('CreateDefaultLibraryDefaults keeps error-level baseline',
    LDefaults.LogLevel = sslLogError);
  AssertTrue('CreateDefaultLibraryDefaults starts without callback',
    not Assigned(LDefaults.LogCallback));
end;

procedure Test_RoundTripAndDispatch;
var
  LLib: ISSLLibrary;
  LOriginal: TSSLLibraryDefaults;
  LUpdated: TSSLLibraryDefaults;
  LSnapshot: TSSLLibraryDefaults;
  LRecorder: TLogRecorder;
begin
  LLib := TSSLFactory.GetLibrary(sslFreePascal);
  LOriginal := GetLibraryDefaults(LLib);
  LRecorder := TLogRecorder.Create;
  try
    LUpdated := LOriginal;
    LUpdated.LogLevel := sslLogInfo;
    LUpdated.LogCallback := @LRecorder.HandleLog;
    ApplyLibraryDefaults(LLib, LUpdated);

    LSnapshot := GetLibraryDefaults(LLib);
    AssertTrue('ApplyLibraryDefaults updates log level',
      LSnapshot.LogLevel = sslLogInfo);
    AssertTrue('ApplyLibraryDefaults installs callback through owner path',
      CallbackEquals(LUpdated.LogCallback, LSnapshot.LogCallback));

    LRecorder.Reset;
    LLib.Log(sslLogInfo, 'library-default helper surface probe');
    AssertTrue('Installed callback receives info-level log',
      LRecorder.CallCount = 1);
    AssertTrue('Dispatched level stays aligned',
      LRecorder.LastLevel = sslLogInfo);
    AssertTrue('Dispatched message stays aligned',
      Pos('helper surface probe', LRecorder.LastMessage) > 0);
  finally
    ApplyLibraryDefaults(LLib, LOriginal);
    LRecorder.Free;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('  fafafa.ssl TSSLLibraryDefaults 测试');
  WriteLn('========================================');

  Test_DefaultBaseline;
  Test_RoundTripAndDispatch;

  WriteLn('所有测试通过！✓');
end.
