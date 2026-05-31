program test_corba_interface_issue;

{$mode ObjFPC}{$H+}
{$INTERFACES CORBA}

uses
  SysUtils,
  
  nextpas.core.tls.base;

type
  { 测试实现 }
  TTestLibrary = class(TInterfacedObject, ISSLLibrary)
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

function TTestLibrary.Initialize: Boolean; begin Result := True; end;
procedure TTestLibrary.Finalize; begin end;
function TTestLibrary.IsInitialized: Boolean; begin Result := True; end;
function TTestLibrary.GetLibraryType: TSSLLibraryType; begin Result := sslWinSSL; end;
function TTestLibrary.GetVersionString: string; begin Result := 'Test'; end;
function TTestLibrary.GetVersionNumber: Cardinal; begin Result := 0; end;
function TTestLibrary.GetCompileFlags: string; begin Result := ''; end;
function TTestLibrary.IsProtocolSupported(aProtocol: TSSLProtocolVersion): Boolean; begin Result := False; end;
function TTestLibrary.IsCipherSupported(const aCipherName: string): Boolean; begin Result := False; end;
function TTestLibrary.IsFeatureSupported(aFeature: TSSLFeature): Boolean; begin Result := False; end;
function TTestLibrary.GetCapabilities: TSSLBackendCapabilities; begin FillChar(Result, SizeOf(Result), 0); Result.MinTLSVersion := sslProtocolTLS10; Result.MaxTLSVersion := sslProtocolTLS12; end;
procedure TTestLibrary.SetDefaultConfig(const aConfig: TSSLConfig); begin end;
function TTestLibrary.GetDefaultConfig: TSSLConfig; begin FillChar(Result, SizeOf(Result), 0); end;
function TTestLibrary.GetLastError: Integer; begin Result := 0; end;
function TTestLibrary.GetLastErrorString: string; begin Result := ''; end;
procedure TTestLibrary.ClearError; begin end;
function TTestLibrary.GetStatistics: TSSLStatistics; begin FillChar(Result, SizeOf(Result), 0); end;
procedure TTestLibrary.ResetStatistics; begin end;
procedure TTestLibrary.SetLogCallback(aCallback: TSSLLogCallback); begin end;
procedure TTestLibrary.Log(aLevel: TSSLLogLevel; const aMessage: string); begin end;
function TTestLibrary.CreateContext(aType: TSSLContextType): ISSLContext; begin Result := nil; end;
function TTestLibrary.CreateCertificate: ISSLCertificate; begin Result := nil; end;
function TTestLibrary.CreateCertificateStore: ISSLCertificateStore; begin Result := nil; end;

begin
  WriteLn('Testing CORBA interface...');
  WriteLn('If this compiles, the interface definitions are OK.');
end.
