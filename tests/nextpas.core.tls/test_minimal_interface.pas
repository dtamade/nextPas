program test_minimal_interface;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  
  nextpas.core.tls.base;

type
  TMinimalLib = class(TInterfacedObject, ISSLLibrary)
  public
    function Initialize: Boolean;
    procedure Finalize;
    function IsInitialized: Boolean;
    function GetLibraryType: TSSLLibraryType;
    function GetVersionString: string;
    function GetVersionNumber: Cardinal;
    function GetCompileFlags: string;
    function IsProtocolSupported(aProtocol: TSSLProtocolVersion): Boolean;
    function IsCipherSupported(const aCipherName: string): Boolean;
    function IsFeatureSupported(aFeature: TSSLFeature): Boolean;
    function GetCapabilities: TSSLBackendCapabilities;
    procedure SetDefaultConfig(const aConfig: TSSLConfig);
    function GetDefaultConfig: TSSLConfig;
    function GetLastError: Integer;
    function GetLastErrorString: string;
    procedure ClearError;
    function GetStatistics: TSSLStatistics;
    procedure ResetStatistics;
    procedure SetLogCallback(aCallback: TSSLLogCallback);
    procedure Log(aLevel: TSSLLogLevel; const aMessage: string);
    function CreateContext(aType: TSSLContextType): ISSLContext;
    function CreateCertificate: ISSLCertificate;
    function CreateCertificateStore: ISSLCertificateStore;
  end;

function TMinimalLib.Initialize: Boolean; begin Result := True; end;
procedure TMinimalLib.Finalize; begin end;
function TMinimalLib.IsInitialized: Boolean; begin Result := True; end;
function TMinimalLib.GetLibraryType: TSSLLibraryType; begin Result := sslWinSSL; end;
function TMinimalLib.GetVersionString: string; begin Result := 'Test'; end;
function TMinimalLib.GetVersionNumber: Cardinal; begin Result := 0; end;
function TMinimalLib.GetCompileFlags: string; begin Result := ''; end;
function TMinimalLib.IsProtocolSupported(aProtocol: TSSLProtocolVersion): Boolean; begin Result := False; end;
function TMinimalLib.IsCipherSupported(const aCipherName: string): Boolean; begin Result := False; end;
function TMinimalLib.IsFeatureSupported(aFeature: TSSLFeature): Boolean; begin Result := False; end;
function TMinimalLib.GetCapabilities: TSSLBackendCapabilities; begin FillChar(Result, SizeOf(Result), 0); Result.MinTLSVersion := sslProtocolTLS10; Result.MaxTLSVersion := sslProtocolTLS12; end;
procedure TMinimalLib.SetDefaultConfig(const aConfig: TSSLConfig); begin end;
function TMinimalLib.GetDefaultConfig: TSSLConfig; begin FillChar(Result, SizeOf(Result), 0); end;
function TMinimalLib.GetLastError: Integer; begin Result := 0; end;
function TMinimalLib.GetLastErrorString: string; begin Result := ''; end;
procedure TMinimalLib.ClearError; begin end;
function TMinimalLib.GetStatistics: TSSLStatistics; begin FillChar(Result, SizeOf(Result), 0); end;
procedure TMinimalLib.ResetStatistics; begin end;
procedure TMinimalLib.SetLogCallback(aCallback: TSSLLogCallback); begin end;
procedure TMinimalLib.Log(aLevel: TSSLLogLevel; const aMessage: string); begin end;
function TMinimalLib.CreateContext(aType: TSSLContextType): ISSLContext; begin Result := nil; end;
function TMinimalLib.CreateCertificate: ISSLCertificate; begin Result := nil; end;
function TMinimalLib.CreateCertificateStore: ISSLCertificateStore; begin Result := nil; end;

begin
  WriteLn('Testing minimal interface implementation...');
  WriteLn('Compiled successfully!');
end.
