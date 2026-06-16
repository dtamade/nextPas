unit nextpas.core.tls.engine;

{$mode objfpc}{$H+}

interface

uses nextpas.core.base, nextpas.core.tls.base; type TSSLEngineAction = ( eaNone, eaNeedMoreInput, eaHasCiphertext, eaHasPlaintext, eaHandshakeComplete, eaClosed, eaError );

  TSSLEngineRole = (
    erClient,
    erServer
  );

  ISSLEngine = interface
    ['{F1A2B3C4-D5E6-7F80-9A1B-2C3D4E5F6A7B}']

    procedure SetServerName(const AName: string);
    procedure SetALPNProtocols(const AProtocols: string);

    procedure InjectCiphertext(const AData: TBytes; AOffset, ALength: Integer); overload;
    procedure InjectCiphertext(const AData: TBytes); overload;

    function ProcessHandshake: TSSLEngineAction;

    function Encrypt(const APlaintext: TBytes; AOffset, ALength: Integer): TSSLEngineAction; overload;
    function Encrypt(const APlaintext: TBytes): TSSLEngineAction; overload;

    function Decrypt: TSSLEngineAction;

    function ExtractCiphertext: TBytes;
    function ExtractPlaintext: TBytes;

    function HasPendingCiphertext: Boolean;
    function HasPendingPlaintext: Boolean;
    function IsHandshakeComplete: Boolean;

    function GetProtocolVersion: TSSLProtocolVersion;
    function GetCipherName: string;
    function GetPeerCertificate: ISSLCertificate;
    function GetSelectedALPNProtocol: string;
    function GetLastError: string;
    function GetLastErrorCode: TSSLErrorCode;
  end;

implementation

end.
