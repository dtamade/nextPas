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
  Classes, SysUtils, fpcunit, testregistry,
  test_base,
  openssl_core_interface;

type
  { TTestOpenSSLCoreMock - True unit test with mocks }
  TTestOpenSSLCoreMock = class(TTestBase)
  private
    FCore: IOpenSSLCore;
    FMock: TOpenSSLCoreMock;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
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

procedure TTestOpenSSLCoreMock.SetUp;
begin
  inherited SetUp;
  // Create mock instance
  FMock := TOpenSSLCoreMock.Create;
  FCore := FMock as IOpenSSLCore;
end;

procedure TTestOpenSSLCoreMock.TearDown;
begin
  // Clean up
  FCore := nil;
  FMock := nil;
  inherited TearDown;
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
  AssertTrue('LoadLibrary should return True', Result);
  AssertTrue('IsLoaded should be True after load', FCore.IsLoaded);
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
  AssertFalse('LoadLibrary should return False when configured to fail', Result);
  AssertFalse('IsLoaded should be False after failed load', FCore.IsLoaded);
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
  AssertEquals('Call count should increment by 1', CountBefore + 1, CountAfter);
end;

procedure TTestOpenSSLCoreMock.TestLoad_ShouldBeIdempotent;
var
  FirstResult, SecondResult: Boolean;
begin
  // Given & When
  FirstResult := FCore.LoadLibrary;
  SecondResult := FCore.LoadLibrary;
  
  // Then
  AssertTrue('First load should succeed', FirstResult);
  AssertTrue('Second load should succeed', SecondResult);
  AssertEquals('Should be called twice', 2, FMock.GetLoadCallCount);
end;

procedure TTestOpenSSLCoreMock.TestIsLoaded_ShouldReturnFalse_BeforeLoad;
begin
  // Given
  // (Fresh mock, not loaded)
  
  // When & Then
  AssertFalse('IsLoaded should return False before LoadLibrary', FCore.IsLoaded);
end;

procedure TTestOpenSSLCoreMock.TestIsLoaded_ShouldReturnTrue_AfterLoad;
begin
  // Given
  FCore.LoadLibrary;
  
  // When & Then
  AssertTrue('IsLoaded should return True after LoadLibrary', FCore.IsLoaded);
end;

procedure TTestOpenSSLCoreMock.TestIsLoaded_ShouldReturnFalse_AfterUnload;
begin
  // Given
  FCore.LoadLibrary;
  
  // When
  FCore.UnloadLibrary;
  
  // Then
  AssertFalse('IsLoaded should return False after UnloadLibrary', FCore.IsLoaded);
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
  AssertEquals('Version should be empty when not loaded', '', Version);
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
  AssertTrue('Version should not be empty when loaded', Version <> '');
  AssertTrue('Version should contain "Mock"', Pos('Mock', Version) > 0);
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
  AssertEquals('Should return custom version', Expected, Actual);
end;

procedure TTestOpenSSLCoreMock.TestGetCryptoHandle_ShouldReturnZero_WhenNotLoaded;
var
  Handle: TLibHandle;
begin
  // Given
  // (Not loaded)
  
  // When
  Handle := FCore.GetCryptoLibHandle;
  
  // Then
  AssertEquals('Handle should be NilHandle when not loaded', NilHandle, Handle);
end;

procedure TTestOpenSSLCoreMock.TestGetCryptoHandle_ShouldReturnNonZero_WhenLoaded;
var
  Handle: TLibHandle;
begin
  // Given
  FCore.LoadLibrary;
  
  // When
  Handle := FCore.GetCryptoLibHandle;
  
  // Then
  AssertTrue('Handle should be non-zero when loaded', Handle <> NilHandle);
end;

procedure TTestOpenSSLCoreMock.TestGetSSLHandle_ShouldReturnZero_WhenNotLoaded;
var
  Handle: TLibHandle;
begin
  // Given
  // (Not loaded)
  
  // When
  Handle := FCore.GetSSLLibHandle;
  
  // Then
  AssertEquals('Handle should be NilHandle when not loaded', NilHandle, Handle);
end;

procedure TTestOpenSSLCoreMock.TestGetSSLHandle_ShouldReturnNonZero_WhenLoaded;
var
  Handle: TLibHandle;
begin
  // Given
  FCore.LoadLibrary;
  
  // When
  Handle := FCore.GetSSLLibHandle;
  
  // Then
  AssertTrue('Handle should be non-zero when loaded', Handle <> NilHandle);
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
  AssertFalse('First load should fail', Result1);
  AssertFalse('Second load should also fail', Result2);
  AssertEquals('Should track both attempts', 2, FMock.GetLoadCallCount);
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
  AssertTrue('First load should succeed', LoadResult1);
  AssertTrue('Reload should succeed', LoadResult2);
  AssertTrue('Should be loaded after reload', FCore.IsLoaded);
end;

initialization
  RegisterTest(TTestOpenSSLCoreMock);

end.
