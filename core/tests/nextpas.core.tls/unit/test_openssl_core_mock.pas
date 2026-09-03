unit test_openssl_core_mock;

{$mode objfpc}{$H+}

{
  True TDD Unit Test with Mocks

  This demonstrates proper unit testing:
  - Fast execution (no real OpenSSL loading)
  - Isolated (no external dependencies)
  - Predictable (controlled mock behavior)
  - Testable error paths (can simulate failures)
}

interface

uses
  nextpas.core.test,
  test_base,
  openssl_core_interface, nextpas.core.platform.dl, nextpas.core.text;

type
  { TTestOpenSSLCoreMock - True unit test with mocks }
  TTestOpenSSLCoreMock = class(TTestBase)
  private
    FCore: IOpenSSLCore;
    FMock: TOpenSSLCoreMock;
  protected
    procedure BeforeEach; override;
    procedure AfterEach; override;
  published
    // Library loading tests
    procedure TestLoad_ShouldReturnTrue_WhenSuccessful;
    procedure TestLoad_ShouldReturnFalse_WhenConfiguredToFail;
    procedure TestLoad_ShouldIncrementCallCount;
    procedure TestLoad_ShouldBeIdempotent;

    // State tests
    procedure TestIsLoaded_ShouldReturnFalse_BeforeLoad;
    procedure TestIsLoaded_ShouldReturnTrue_AfterLoad;
    procedure TestIsLoaded_ShouldReturnFalse_AfterUnload;

    // Version tests
    procedure TestGetVersion_ShouldReturnEmpty_WhenNotLoaded;
    procedure TestGetVersion_ShouldReturnValue_WhenLoaded;
    procedure TestGetVersion_ShouldReturnCustomValue_WhenSet;

    // Handle tests
    procedure TestGetCryptoHandle_ShouldReturnZero_WhenNotLoaded;
    procedure TestGetCryptoHandle_ShouldReturnNonZero_WhenLoaded;
    procedure TestGetSSLHandle_ShouldReturnZero_WhenNotLoaded;
    procedure TestGetSSLHandle_ShouldReturnNonZero_WhenLoaded;

    // Error path tests
    procedure TestLoad_ShouldHandleMultipleFailures;
    procedure TestUnload_ShouldAllowReload;
  end;

implementation

{ TTestOpenSSLCoreMock }

procedure TTestOpenSSLCoreMock.BeforeEach;
begin
  inherited BeforeEach;
  // Create mock instance
  FMock := TOpenSSLCoreMock.Create;
  FCore := FMock as IOpenSSLCore;
end;

procedure TTestOpenSSLCoreMock.AfterEach;
begin
  // Clean up
  FCore := nil;
  FMock := nil;
  inherited AfterEach;
end;

procedure TTestOpenSSLCoreMock.TestLoad_ShouldReturnTrue_WhenSuccessful;
var
  Result: Boolean;
begin
  // Given
  // (Mock configured for success by default)

  // When
  Result := FCore.LoadLibrary;

  // Then
  CheckTrue(Result, 'LoadLibrary should return True');
  CheckTrue(FCore.IsLoaded, 'IsLoaded should be True after load');
end;

procedure TTestOpenSSLCoreMock.TestLoad_ShouldReturnFalse_WhenConfiguredToFail;
var
  Result: Boolean;
begin
  // Given
  FMock.SetShouldFailLoad(True);

  // When
  Result := FCore.LoadLibrary;

  // Then
  CheckFalse(Result, 'LoadLibrary should return False when configured to fail');
  CheckFalse(FCore.IsLoaded, 'IsLoaded should be False after failed load');
end;

procedure TTestOpenSSLCoreMock.TestLoad_ShouldIncrementCallCount;
var
  CountBefore, CountAfter: Integer;
begin
  // Given
  CountBefore := FMock.GetLoadCallCount;

  // When
  FCore.LoadLibrary;

  // Then
  CountAfter := FMock.GetLoadCallCount;
  CheckEqual(CountBefore + 1, CountAfter, 'Call count should increment by 1');
end;

procedure TTestOpenSSLCoreMock.TestLoad_ShouldBeIdempotent;
var
  FirstResult, SecondResult: Boolean;
begin
  // Given & When
  FirstResult := FCore.LoadLibrary;
  SecondResult := FCore.LoadLibrary;

  // Then
  CheckTrue(FirstResult, 'First load should succeed');
  CheckTrue(SecondResult, 'Second load should succeed');
  CheckEqual(2, FMock.GetLoadCallCount, 'Should be called twice');
end;

procedure TTestOpenSSLCoreMock.TestIsLoaded_ShouldReturnFalse_BeforeLoad;
begin
  // Given
  // (Fresh mock, not loaded)

  // When & Then
  CheckFalse(FCore.IsLoaded, 'IsLoaded should return False before LoadLibrary');
end;

procedure TTestOpenSSLCoreMock.TestIsLoaded_ShouldReturnTrue_AfterLoad;
begin
  // Given
  FCore.LoadLibrary;

  // When & Then
  CheckTrue(FCore.IsLoaded, 'IsLoaded should return True after LoadLibrary');
end;

procedure TTestOpenSSLCoreMock.TestIsLoaded_ShouldReturnFalse_AfterUnload;
begin
  // Given
  FCore.LoadLibrary;

  // When
  FCore.UnloadLibrary;

  // Then
  CheckFalse(FCore.IsLoaded, 'IsLoaded should return False after UnloadLibrary');
end;

procedure TTestOpenSSLCoreMock.TestGetVersion_ShouldReturnEmpty_WhenNotLoaded;
var
  Version: string;
begin
  // Given
  // (Not loaded)

  // When
  Version := FCore.GetVersionString;

  // Then
  CheckEqual('', Version, 'Version should be empty when not loaded');
end;

procedure TTestOpenSSLCoreMock.TestGetVersion_ShouldReturnValue_WhenLoaded;
var
  Version: string;
begin
  // Given
  FCore.LoadLibrary;

  // When
  Version := FCore.GetVersionString;

  // Then
  CheckTrue(Version <> '', 'Version should not be empty when loaded');
  CheckTrue(Pos('Mock', Version) > 0, 'Version should contain "Mock"');
end;

procedure TTestOpenSSLCoreMock.TestGetVersion_ShouldReturnCustomValue_WhenSet;
var
  Expected, Actual: string;
begin
  // Given
  Expected := 'Custom Version 1.2.3';
  FMock.SetVersionString(Expected);
  FCore.LoadLibrary;

  // When
  Actual := FCore.GetVersionString;

  // Then
  CheckEqual(Expected, Actual, 'Should return custom version');
end;

procedure TTestOpenSSLCoreMock.TestGetCryptoHandle_ShouldReturnZero_WhenNotLoaded;
var
  Handle: TPlatformLibrary;
begin
  // Given
  // (Not loaded)

  // When
  Handle := FCore.GetCryptoLibHandle;

  // Then
  CheckTrue(Handle.IsInvalid, 'Handle should be NilHandle when not loaded');
end;

procedure TTestOpenSSLCoreMock.TestGetCryptoHandle_ShouldReturnNonZero_WhenLoaded;
var
  Handle: TPlatformLibrary;
begin
  // Given
  FCore.LoadLibrary;

  // When
  Handle := FCore.GetCryptoLibHandle;

  // Then
  CheckTrue(Handle.IsValid, 'Handle should be non-zero when loaded');
end;

procedure TTestOpenSSLCoreMock.TestGetSSLHandle_ShouldReturnZero_WhenNotLoaded;
var
  Handle: TPlatformLibrary;
begin
  // Given
  // (Not loaded)

  // When
  Handle := FCore.GetSSLLibHandle;

  // Then
  CheckTrue(Handle.IsInvalid, 'Handle should be NilHandle when not loaded');
end;

procedure TTestOpenSSLCoreMock.TestGetSSLHandle_ShouldReturnNonZero_WhenLoaded;
var
  Handle: TPlatformLibrary;
begin
  // Given
  FCore.LoadLibrary;

  // When
  Handle := FCore.GetSSLLibHandle;

  // Then
  CheckTrue(Handle.IsValid, 'Handle should be non-zero when loaded');
end;

procedure TTestOpenSSLCoreMock.TestLoad_ShouldHandleMultipleFailures;
var
  Result1, Result2: Boolean;
begin
  // Given
  FMock.SetShouldFailLoad(True);

  // When
  Result1 := FCore.LoadLibrary;
  Result2 := FCore.LoadLibrary;

  // Then
  CheckFalse(Result1, 'First load should fail');
  CheckFalse(Result2, 'Second load should also fail');
  CheckEqual(2, FMock.GetLoadCallCount, 'Should track both attempts');
end;

procedure TTestOpenSSLCoreMock.TestUnload_ShouldAllowReload;
var
  LoadResult1, LoadResult2: Boolean;
begin
  // Given
  LoadResult1 := FCore.LoadLibrary;
  FCore.UnloadLibrary;

  // When
  LoadResult2 := FCore.LoadLibrary;

  // Then
  CheckTrue(LoadResult1, 'First load should succeed');
  CheckTrue(LoadResult2, 'Reload should succeed');
  CheckTrue(FCore.IsLoaded, 'Should be loaded after reload');
end;

end.
