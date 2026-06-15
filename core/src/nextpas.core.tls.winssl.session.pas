{**
 * Unit: nextpas.core.tls.winssl.session
 * Purpose: WinSSL session compatibility shim
 *
 * 真实的 WinSSL session 实现已经收敛到
 * `nextpas.core.tls.winssl.connection.TWinSSLSession`。
 * 本单元只保留兼容入口，避免外部代码直接引用
 * `nextpas.core.tls.winssl.session` 时断裂。
 *}

unit nextpas.core.tls.winssl.session;

{$mode objfpc}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

interface

uses
  {$IFDEF WINDOWS}
  Windows,
  {$ENDIF}
  nextpas.core.text.conv,
  nextpas.core.tls.base,
  nextpas.core.tls.winssl.base,
  nextpas.core.tls.winssl.connection;

type
  { Compatibility shim: canonical implementation lives in winssl.connection. }
  TWinSSLSession = class(nextpas.core.tls.winssl.connection.TWinSSLSession)
  public
    constructor CreateFromData(const AData: TBytes);
    constructor CreateFromConnection(AContext: PCtxtHandle;
      AProtocol: TSSLProtocolVersion; const ACipher: string);
  end;

implementation

constructor TWinSSLSession.CreateFromData(const AData: TBytes);
begin
  inherited Create;
  Deserialize(AData);
end;

constructor TWinSSLSession.CreateFromConnection(AContext: PCtxtHandle;
  AProtocol: TSSLProtocolVersion; const ACipher: string);
var
  LSessionID: string;
begin
  inherited Create;

  if AContext = nil then
    Exit;

  // Keep the compatibility shim aligned with the current canonical conservative truth:
  // no direct risky Schannel session-info probe here; callers only get a fallback session id.
  LSessionID := Format('winssl-session-%p', [Pointer(AContext)]);
  SetSessionMetadata(LSessionID, AProtocol, ACipher, False);
end;

end.
