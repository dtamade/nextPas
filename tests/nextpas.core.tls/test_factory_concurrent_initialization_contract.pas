program test_factory_concurrent_initialization_contract;

{$mode ObjFPC}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  SysUtils, Classes, SyncObjs,
  nextpas.core.tls.base,
  nextpas.core.tls.factory;

type
  IInspectableFactoryMock = interface
    ['{C5058342-5A3A-4A7E-BF0B-16A8E4B4D40C}']
    function GetInstanceId: Integer;
  end;

  TBlockingMockLibraryBase = class(TInterfacedObject, ISSLLibrary, IInspectableFactoryMock)
  private
    FInitialized: Boolean;
    FInstanceId: Integer;
  public
    constructor Create;

    function Initialize: Boolean; virtual;
    procedure Finalize;
    function IsInitialized: Boolean; virtual;
    function GetLibraryType: TSSLLibraryType; virtual;
    function GetVersionString: string; virtual;
    function GetVersionNumber: Cardinal;
    function GetCompileFlags: string;
    function IsProtocolSupported(AProtocol: TSSLProtocolVersion): Boolean;
    function IsCipherSupported(const ACipherName: string): Boolean;
    function IsFeatureSupported(AFeature: TSSLFeature): Boolean;
    function GetCapabilities: TSSLBackendCapabilities;
    procedure SetDefaultConfig(const AConfig: TSSLConfig);
    function GetDefaultConfig: TSSLConfig;
    function GetLastError: Integer;
    function GetLastErrorString: string;
    procedure ClearError;
    function GetStatistics: TSSLStatistics;
    procedure ResetStatistics;
    procedure SetLogCallback(ACallback: TSSLLogCallback);
    procedure Log(ALevel: TSSLLogLevel; const AMessage: string);
    function CreateContext(AType: TSSLContextType): ISSLContext;
    function CreateCertificate: ISSLCertificate;
    function CreateCertificateStore: ISSLCertificateStore;

    function GetInstanceId: Integer;
  end;

  TBlockingMbedTLSLibrary = class(TBlockingMockLibraryBase)
  public
    function GetLibraryType: TSSLLibraryType; override;
    function GetVersionString: string; override;
  end;

  TBlockingWolfSSLLibrary = class(TBlockingMockLibraryBase)
  public
    function GetLibraryType: TSSLLibraryType; override;
    function GetVersionString: string; override;
  end;

  TFactoryCallKind = (fckGetLibrary, fckIsLibraryAvailable);

  TFactoryCallThread = class(TThread)
  private
    FCallKind: TFactoryCallKind;
    FLibType: TSSLLibraryType;
    FSuccess: Boolean;
    FAvailable: Boolean;
    FInstanceId: Integer;
    FErrorMessage: string;
  protected
    procedure Execute; override;
  public
    constructor Create(ACallKind: TFactoryCallKind; ALibType: TSSLLibraryType);

    property Success: Boolean read FSuccess;
    property Available: Boolean read FAvailable;
    property InstanceId: Integer read FInstanceId;
    property ErrorMessage: string read FErrorMessage;
  end;

var
  GTestsPassed: Integer = 0;
  GTestsFailed: Integer = 0;
  GInitializeCalls: Integer = 0;
  GInitializeEnteredEvent: TEvent = nil;
  GAllowInitializeFinishEvent: TEvent = nil;

procedure Fail(const AMessage: string);
begin
  Inc(GTestsFailed);
  WriteLn('[FAIL] ', AMessage);
end;

procedure Pass(const AMessage: string);
begin
  Inc(GTestsPassed);
  WriteLn('[PASS] ', AMessage);
end;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
    Pass(AMessage)
  else
    Fail(AMessage);
end;

procedure CheckEqualsInt(AExpected, AActual: Integer; const AMessage: string);
begin
  Check(AExpected = AActual,
    Format('%s (expected=%d actual=%d)', [AMessage, AExpected, AActual]));
end;

procedure ResetBlockingState;
begin
  GInitializeCalls := 0;
  FreeAndNil(GInitializeEnteredEvent);
  FreeAndNil(GAllowInitializeFinishEvent);
  GInitializeEnteredEvent := TEvent.Create(nil, True, False, '');
  GAllowInitializeFinishEvent := TEvent.Create(nil, True, False, '');
end;

procedure CleanupBackend(ALibType: TSSLLibraryType);
begin
  TSSLFactory.ReleaseLibrary(ALibType);
  TSSLFactory.UnregisterLibrary(ALibType);
end;

procedure WaitForThreadSuccess(AThread: TFactoryCallThread; const AName: string);
begin
  AThread.WaitFor;
  Check(AThread.Success, AName + ' completed without exception: ' + AThread.ErrorMessage);
end;

constructor TBlockingMockLibraryBase.Create;
begin
  inherited Create;
  FInitialized := False;
  FInstanceId := PtrInt(Self);
end;

function TBlockingMockLibraryBase.Initialize: Boolean;
begin
  if FInitialized then
    Exit(True);

  InterlockedIncrement(GInitializeCalls);
  GInitializeEnteredEvent.SetEvent;

  if GAllowInitializeFinishEvent.WaitFor(5000) <> wrSignaled then
    Exit(False);

  FInitialized := True;
  Result := True;
end;

procedure TBlockingMockLibraryBase.Finalize;
begin
  FInitialized := False;
end;

function TBlockingMockLibraryBase.IsInitialized: Boolean;
begin
  Result := FInitialized;
end;

function TBlockingMockLibraryBase.GetLibraryType: TSSLLibraryType;
begin
  Result := sslAutoDetect;
end;

function TBlockingMockLibraryBase.GetVersionString: string;
begin
  Result := 'BlockingMockLibrary';
end;

function TBlockingMockLibraryBase.GetVersionNumber: Cardinal;
begin
  Result := 1;
end;

function TBlockingMockLibraryBase.GetCompileFlags: string;
begin
  Result := 'Mock';
end;

function TBlockingMockLibraryBase.IsProtocolSupported(AProtocol: TSSLProtocolVersion): Boolean;
begin
  Result := True;
end;

function TBlockingMockLibraryBase.IsCipherSupported(const ACipherName: string): Boolean;
begin
  Result := True;
end;

function TBlockingMockLibraryBase.IsFeatureSupported(AFeature: TSSLFeature): Boolean;
begin
  Result := True;
end;

function TBlockingMockLibraryBase.GetCapabilities: TSSLBackendCapabilities;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.BackendType := GetLibraryType;
  Result.MinTLSVersion := sslProtocolTLS12;
  Result.MaxTLSVersion := sslProtocolTLS13;
end;

procedure TBlockingMockLibraryBase.SetDefaultConfig(const AConfig: TSSLConfig);
begin
end;

function TBlockingMockLibraryBase.GetDefaultConfig: TSSLConfig;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.LibraryType := GetLibraryType;
  Result.ContextType := sslCtxClient;
end;

function TBlockingMockLibraryBase.GetLastError: Integer;
begin
  Result := 0;
end;

function TBlockingMockLibraryBase.GetLastErrorString: string;
begin
  Result := '';
end;

procedure TBlockingMockLibraryBase.ClearError;
begin
end;

function TBlockingMockLibraryBase.GetStatistics: TSSLStatistics;
begin
  FillChar(Result, SizeOf(Result), 0);
end;

procedure TBlockingMockLibraryBase.ResetStatistics;
begin
end;

procedure TBlockingMockLibraryBase.SetLogCallback(ACallback: TSSLLogCallback);
begin
end;

procedure TBlockingMockLibraryBase.Log(ALevel: TSSLLogLevel; const AMessage: string);
begin
end;

function TBlockingMockLibraryBase.CreateContext(AType: TSSLContextType): ISSLContext;
begin
  Result := nil;
end;

function TBlockingMockLibraryBase.CreateCertificate: ISSLCertificate;
begin
  Result := nil;
end;

function TBlockingMockLibraryBase.CreateCertificateStore: ISSLCertificateStore;
begin
  Result := nil;
end;

function TBlockingMockLibraryBase.GetInstanceId: Integer;
begin
  Result := FInstanceId;
end;

function TBlockingMbedTLSLibrary.GetLibraryType: TSSLLibraryType;
begin
  Result := sslMbedTLS;
end;

function TBlockingMbedTLSLibrary.GetVersionString: string;
begin
  Result := 'Blocking Mock MbedTLS';
end;

function TBlockingWolfSSLLibrary.GetLibraryType: TSSLLibraryType;
begin
  Result := sslWolfSSL;
end;

function TBlockingWolfSSLLibrary.GetVersionString: string;
begin
  Result := 'Blocking Mock WolfSSL';
end;

constructor TFactoryCallThread.Create(ACallKind: TFactoryCallKind; ALibType: TSSLLibraryType);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FCallKind := ACallKind;
  FLibType := ALibType;
  FSuccess := False;
  FAvailable := False;
  FInstanceId := -1;
  FErrorMessage := '';
end;

procedure TFactoryCallThread.Execute;
var
  LLib: ISSLLibrary;
  LInspectable: IInspectableFactoryMock;
begin
  try
    case FCallKind of
      fckGetLibrary:
      begin
        LLib := TSSLFactory.GetLibrary(FLibType);
        FAvailable := Assigned(LLib);
        if Supports(LLib, IInspectableFactoryMock, LInspectable) then
          FInstanceId := LInspectable.GetInstanceId;
      end;
      fckIsLibraryAvailable:
        FAvailable := TSSLFactory.IsLibraryAvailable(FLibType);
    end;
    FSuccess := True;
  except
    on E: Exception do
      FErrorMessage := E.ClassName + ': ' + E.Message;
  end;
end;

procedure TestConcurrentGetLibraryInitializesOnlyOnce;
var
  LThread1: TFactoryCallThread;
  LThread2: TFactoryCallThread;
begin
  WriteLn('=== Concurrent GetLibrary should initialize only once ===');

  CleanupBackend(sslMbedTLS);
  ResetBlockingState;
  TSSLFactory.RegisterLibrary(sslMbedTLS, TBlockingMbedTLSLibrary, 'Blocking mock mbedtls', 10);

  LThread1 := TFactoryCallThread.Create(fckGetLibrary, sslMbedTLS);
  LThread2 := TFactoryCallThread.Create(fckGetLibrary, sslMbedTLS);
  try
    LThread1.Start;
    Check(GInitializeEnteredEvent.WaitFor(2000) = wrSignaled,
      'First GetLibrary call entered Initialize');

    LThread2.Start;
    Sleep(200);
    GAllowInitializeFinishEvent.SetEvent;

    WaitForThreadSuccess(LThread1, 'First GetLibrary worker');
    WaitForThreadSuccess(LThread2, 'Second GetLibrary worker');

    Check(LThread1.Available, 'First GetLibrary worker returned a library');
    Check(LThread2.Available, 'Second GetLibrary worker returned a library');
    CheckEqualsInt(1, GInitializeCalls,
      'Concurrent GetLibrary should call Initialize exactly once');
    CheckEqualsInt(LThread1.InstanceId, LThread2.InstanceId,
      'Concurrent GetLibrary callers should receive the same initialized instance');
  finally
    LThread1.Free;
    LThread2.Free;
    CleanupBackend(sslMbedTLS);
  end;
end;

procedure TestConcurrentIsLibraryAvailableInitializesOnlyOnce;
var
  LThread1: TFactoryCallThread;
  LThread2: TFactoryCallThread;
begin
  WriteLn('=== Concurrent IsLibraryAvailable should initialize only once ===');

  CleanupBackend(sslWolfSSL);
  ResetBlockingState;
  TSSLFactory.RegisterLibrary(sslWolfSSL, TBlockingWolfSSLLibrary, 'Blocking mock wolfssl', 10);

  LThread1 := TFactoryCallThread.Create(fckIsLibraryAvailable, sslWolfSSL);
  LThread2 := TFactoryCallThread.Create(fckIsLibraryAvailable, sslWolfSSL);
  try
    LThread1.Start;
    Check(GInitializeEnteredEvent.WaitFor(2000) = wrSignaled,
      'First IsLibraryAvailable call entered Initialize');

    LThread2.Start;
    Sleep(200);
    GAllowInitializeFinishEvent.SetEvent;

    WaitForThreadSuccess(LThread1, 'First IsLibraryAvailable worker');
    WaitForThreadSuccess(LThread2, 'Second IsLibraryAvailable worker');

    Check(LThread1.Available, 'First IsLibraryAvailable worker returned True');
    Check(LThread2.Available, 'Second IsLibraryAvailable worker returned True');
    CheckEqualsInt(1, GInitializeCalls,
      'Concurrent IsLibraryAvailable should call Initialize exactly once');
  finally
    LThread1.Free;
    LThread2.Free;
    CleanupBackend(sslWolfSSL);
  end;
end;

begin
  try
    TestConcurrentGetLibraryInitializesOnlyOnce;
    TestConcurrentIsLibraryAvailableInitializesOnlyOnce;

    FreeAndNil(GInitializeEnteredEvent);
    FreeAndNil(GAllowInitializeFinishEvent);

    WriteLn;
    WriteLn('Tests Passed: ', GTestsPassed);
    WriteLn('Tests Failed: ', GTestsFailed);

    if GTestsFailed > 0 then
      Halt(1);
  except
    on E: Exception do
    begin
      WriteLn('FATAL: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
