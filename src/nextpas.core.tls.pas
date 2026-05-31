unit nextpas.core.tls;

{$mode ObjFPC}{$H+}{$J-}

{ nextpas.core.tls — TLS 模块统一门面

  对齐 Rust rustls API 设计：

  主 API（transport-first，类似 TlsConnector/TlsAcceptor）：
    var Connector: TSSLConnector;
    Connector := TSSLConnector.FromContext(TSSLQuick.SecureClient);
    Stream := Connector.ConnectSocket(Socket, 'example.com');

  便捷 API（含 DNS + TCP，类似 Go tls.Dial）：
    if TryTLSDial('example.com', 443, S, Err) then ...;
}

interface

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.tls,
  nextpas.core.tls.dialer,
  nextpas.core.tls.quick,
  nextpas.core.tls.context.builder,
  nextpas.core.tls.connection.builder;

type
  // Primary API (rustls-aligned)
  TSSLConnector = nextpas.core.tls.tls.TSSLConnector;
  TSSLAcceptor = nextpas.core.tls.tls.TSSLAcceptor;
  TSSLStream = nextpas.core.tls.tls.TSSLStream;

  // Convenience
  TSSLDialer = nextpas.core.tls.dialer.TSSLDialer;
  TSSLDialResult = nextpas.core.tls.dialer.TSSLDialResult;

// Convenience functions (DNS + TCP + TLS in one call)
function TLSDial(const AHost: string; APort: Word): TSSLStream;
function TryTLSDial(const AHost: string; APort: Word;
  out AStream: TSSLStream; out AError: string): Boolean;

implementation

var
  GDefaultDialer: TSSLDialer = nil;

function GetDefaultDialer: TSSLDialer;
begin
  if GDefaultDialer = nil then
    GDefaultDialer := TSSLDialer.CreateDefault;
  Result := GDefaultDialer;
end;

function TLSDial(const AHost: string; APort: Word): TSSLStream;
var
  LResult: TSSLDialResult;
begin
  LResult := GetDefaultDialer.Dial(AHost, APort);
  if LResult.Error.IsErr then
    raise ESSLException.Create('TLS dial failed: ' + LResult.Error.ErrorMessage);
  Result := LResult.Stream;
end;

function TryTLSDial(const AHost: string; APort: Word;
  out AStream: TSSLStream; out AError: string): Boolean;
begin
  Result := GetDefaultDialer.TryDial(AHost, APort, AStream, AError);
end;

finalization
  FreeAndNil(GDefaultDialer);

end.
