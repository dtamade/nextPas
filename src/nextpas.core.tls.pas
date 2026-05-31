unit nextpas.core.tls;

{$mode ObjFPC}{$H+}{$J-}

{ nextpas.core.tls — TLS 模块统一门面

  一个 uses 搞定 TLS 连接：

    uses nextpas.core.tls;
    var S: TSSLStream; Err: string;
    if TryTLSDial('example.com', 443, S, Err) then
    begin
      S.WriteBuffer(Request[1], Length(Request));
      S.ReadBuffer(Response[0], Len);
      S.Free;
    end;
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
  TSSLStream = nextpas.core.tls.tls.TSSLStream;
  TSSLDialer = nextpas.core.tls.dialer.TSSLDialer;
  TSSLDialResult = nextpas.core.tls.dialer.TSSLDialResult;

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
