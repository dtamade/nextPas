unit openssl_core_interface;

{$mode objfpc}{$H+}

{
  OpenSSL Core Interface Abstraction
  
  Purpose: Provide interface for dependency injection
  Allows: Real implementation OR Mock implementation
  Benefits: True unit testing, fast execution, isolated tests
}

interface

uses
  Classes, SysUtils, DynLibs;

type
  { IOpenSSLCore - Interface for OpenSSL Core functionality }
  IOpenSSLCore = interface
    ['{E8F9A1B2-C3D4-4E5F-6A7B-8C9D0E1F2A3B}']
    
    // Library loading
    function LoadLibrary: Boolean;
    function IsLoaded: Boolean;
    function GetCryptoLibHandle: TLibHandle;
    function GetSSLLibHandle: TLibHandle;
    
    // Version information
    function GetVersionString: string;
    function GetVersionNumber: Cardinal;
    
    // Library management
    procedure UnloadLibrary;  // For testing purposes
  end;

  { TOpenSSLCoreReal - Real implementation using actual OpenSSL }
  TOpenSSLCoreReal = class(TInterfacedObject, IOpenSSLCore)
  private
    FLoaded: Boolean;
    FCryptoHandle: TLibHandle;
    FSSLHandle: TLibHandle;
    FVersionString: string;
  public
    constructor Create;
    destructor Destroy; override;
    
    // IOpenSSLCore implementation
    function LoadLibrary: Boolean;
    function IsLoaded: Boolean;
    function GetCryptoLibHandle: TLibHandle;
    function GetSSLLibHandle: TLibHandle;
    function GetVersionString: string;
    function GetVersionNumber: Cardinal;
    procedure UnloadLibrary;
  end;

  { TOpenSSLCoreMock - Mock implementation for testing }
  TOpenSSLCoreMock = class(TInterfacedObject, IOpenSSLCore)
  private
    FLoaded: Boolean;
    FVersionString: string;
    FVersionNumber: Cardinal;
    FShouldFailLoad: Boolean;
    FLoadCallCount: Integer;
  public
    constructor Create;
    
    // IOpenSSLCore implementation
    function LoadLibrary: Boolean;
    function IsLoaded: Boolean;
    function GetCryptoLibHandle: TLibHandle;
    function GetSSLLibHandle: TLibHandle;
    function GetVersionString: string;
    function GetVersionNumber: Cardinal;
    procedure UnloadLibrary;
    
    // Mock control methods
    procedure SetShouldFailLoad(AValue: Boolean);
    procedure SetVersionString(const AValue: string);
    procedure SetVersionNumber(AValue: Cardinal);
    function GetLoadCallCount: Integer;
    procedure Reset;
  end;

  { TOpenSSLCoreFactory - Factory for creating instances }
  TOpenSSLCoreFactory = class
  private
    class var FInstance: IOpenSSLCore;
    class var FUseMock: Boolean;
  public
    class function GetInstance: IOpenSSLCore;
    class procedure SetUseMock(AValue: Boolean);
    class procedure ResetInstance;
  end;

implementation

uses
  nextpas.core.tls.openssl.loader, nextpas.core.tls.openssl.api.core;

{ TOpenSSLCoreReal }

constructor TOpenSSLCoreReal.Create;
begin
  inherited Create;
  FLoaded := False;
  FCryptoHandle := NilHandle;
  FSSLHandle := NilHandle;
  FVersionString := '';
end;

destructor TOpenSSLCoreReal.Destroy;
begin
  // Don't actually unload - OpenSSL doesn't support it well
  inherited Destroy;
end;

function TOpenSSLCoreReal.LoadLibrary: Boolean;
begin
  if not FLoaded then
  begin
    LoadOpenSSLCore;
    FLoaded := TOpenSSLLoader.IsModuleLoaded(osmCore);
    if FLoaded then
    begin
      FCryptoHandle := GetCryptoLibHandle;
      FSSLHandle := GetSSLLibHandle;
      FVersionString := GetOpenSSLVersionString;
    end;
  end;
  Result := FLoaded;
end;

function TOpenSSLCoreReal.IsLoaded: Boolean;
begin
  Result := FLoaded or TOpenSSLLoader.IsModuleLoaded(osmCore);
end;

function TOpenSSLCoreReal.GetCryptoLibHandle: TLibHandle;
begin
  if not FLoaded then
    LoadLibrary;
  Result := FCryptoHandle;
end;

function TOpenSSLCoreReal.GetSSLLibHandle: TLibHandle;
begin
  if not FLoaded then
    LoadLibrary;
  Result := FSSLHandle;
end;

function TOpenSSLCoreReal.GetVersionString: string;
begin
  if not FLoaded then
    LoadLibrary;
  Result := FVersionString;
end;

function TOpenSSLCoreReal.GetVersionNumber: Cardinal;
begin
  // Simplified - would need actual OpenSSL version number function
  Result := $30000000; // 3.0.0
end;

procedure TOpenSSLCoreReal.UnloadLibrary;
begin
  // Can't truly unload OpenSSL
  // Just reset our state
  FLoaded := False;
end;

{ TOpenSSLCoreMock }

constructor TOpenSSLCoreMock.Create;
begin
  inherited Create;
  Reset;
end;

function TOpenSSLCoreMock.LoadLibrary: Boolean;
begin
  Inc(FLoadCallCount);
  if not FShouldFailLoad then
    FLoaded := True;
  Result := FLoaded;
end;

function TOpenSSLCoreMock.IsLoaded: Boolean;
begin
  Result := FLoaded;
end;

function TOpenSSLCoreMock.GetCryptoLibHandle: TLibHandle;
begin
  if FLoaded then
    Result := TLibHandle(12345) // Mock handle
  else
    Result := NilHandle;
end;

function TOpenSSLCoreMock.GetSSLLibHandle: TLibHandle;
begin
  if FLoaded then
    Result := TLibHandle(67890) // Mock handle
  else
    Result := NilHandle;
end;

function TOpenSSLCoreMock.GetVersionString: string;
begin
  if FLoaded then
    Result := FVersionString
  else
    Result := '';
end;

function TOpenSSLCoreMock.GetVersionNumber: Cardinal;
begin
  if FLoaded then
    Result := FVersionNumber
  else
    Result := 0;
end;

procedure TOpenSSLCoreMock.UnloadLibrary;
begin
  FLoaded := False;
end;

procedure TOpenSSLCoreMock.SetShouldFailLoad(AValue: Boolean);
begin
  FShouldFailLoad := AValue;
end;

procedure TOpenSSLCoreMock.SetVersionString(const AValue: string);
begin
  FVersionString := AValue;
end;

procedure TOpenSSLCoreMock.SetVersionNumber(AValue: Cardinal);
begin
  FVersionNumber := AValue;
end;

function TOpenSSLCoreMock.GetLoadCallCount: Integer;
begin
  Result := FLoadCallCount;
end;

procedure TOpenSSLCoreMock.Reset;
begin
  FLoaded := False;
  FVersionString := 'Mock OpenSSL 3.0.0';
  FVersionNumber := $30000000;
  FShouldFailLoad := False;
  FLoadCallCount := 0;
end;

{ TOpenSSLCoreFactory }

class function TOpenSSLCoreFactory.GetInstance: IOpenSSLCore;
begin
  if FInstance = nil then
  begin
    if FUseMock then
      FInstance := TOpenSSLCoreMock.Create
    else
      FInstance := TOpenSSLCoreReal.Create;
  end;
  Result := FInstance;
end;

class procedure TOpenSSLCoreFactory.SetUseMock(AValue: Boolean);
begin
  FUseMock := AValue;
  ResetInstance;
end;

class procedure TOpenSSLCoreFactory.ResetInstance;
begin
  FInstance := nil;
end;

initialization
  TOpenSSLCoreFactory.FUseMock := False;
  TOpenSSLCoreFactory.FInstance := nil;

end.
