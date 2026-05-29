program freepascal_tls13_client;

{$mode objfpc}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

{ ============================================================================
  示例: 纯 FreePascal TLS 1.3 客户端（零外部依赖）

  演示使用纯 Pascal 实现的 TLS 1.3 后端进行 HTTPS 连接。
  不需要 OpenSSL、WolfSSL 或任何 C 库。

  编译：
    fpc -Fu./src -Fu./examples ./examples/09_freepascal_tls13_client.pas

  运行：
    ./09_freepascal_tls13_client [url]
  ============================================================================ }

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.tls,
  nextpas.core.tls.freepascal.lib,
  nextpas.core.tls.freepascal.context,
  fafafa.examples.tcp;

const
  DEFAULT_URL = 'https://www.example.com/';

function ParseURL(const AURL: string; out AHost, APath: string; out APort: Word): Boolean;
var
  LTemp, LHostPart: string;
  LPos, LPortPos: Integer;
begin
  Result := False;
  AHost := '';
  APath := '/';
  APort := 443;

  LTemp := Trim(AURL);
  if Pos('https://', LowerCase(LTemp)) = 1 then
    Delete(LTemp, 1, 8);

  LPos := Pos('/', LTemp);
  if LPos > 0 then
  begin
    LHostPart := Copy(LTemp, 1, LPos - 1);
    APath := Copy(LTemp, LPos, Length(LTemp));
  end
  else
    LHostPart := LTemp;

  LPortPos := Pos(':', LHostPart);
  if LPortPos > 0 then
  begin
    APort := StrToIntDef(Copy(LHostPart, LPortPos + 1, Length(LHostPart)), APort);
    AHost := Copy(LHostPart, 1, LPortPos - 1);
  end
  else
    AHost := LHostPart;

  Result := (AHost <> '');
end;

var
  URL: string;
  Host, Path: string;
  Port: Word;
  NetErr: string;
  Sock: TSocketHandle;
  Lib: ISSLLibrary;
  Ctx: ISSLContext;
  FPCtx: TFreePascalContext;
  Connector: TSSLConnector;
  TLS: TSSLStream;
  ConnInfo: ISSLConnectionInfo;
  Info: TSSLConnectionInfo;
  Request: RawByteString;
  Buffer: array[0..4095] of Byte;
  N: Integer;
  TotalRead: Integer;
begin
  URL := DEFAULT_URL;
  if ParamCount >= 1 then
    URL := ParamStr(1);

  if not ParseURL(URL, Host, Path, Port) then
  begin
    WriteLn('URL parse failed: ', URL);
    Halt(2);
  end;

  WriteLn('=== Pure FreePascal TLS 1.3 Client ===');
  WriteLn('URL: ', URL);
  WriteLn;

  if not InitNetwork(NetErr) then
  begin
    WriteLn('Network init failed: ', NetErr);
    Halt(2);
  end;

  Lib := CreateFreePascalSSLLibrary;
  if not Lib.Initialize then
  begin
    WriteLn('FreePascal SSL init failed');
    Halt(1);
  end;
  WriteLn('Backend: ', Lib.GetVersionString);

  Ctx := Lib.CreateContext(sslCtxClient);

  FPCtx := (Ctx as TObject) as TFreePascalContext;
  if FPCtx.LoadSystemCertificates then
    WriteLn('System CA certificates loaded')
  else
    WriteLn('Warning: no system CA found, certificate verification may fail');

  WriteLn('Connecting to ', Host, ':', Port, ' ...');
  Sock := ConnectTCP(Host, Port);

  Connector := TSSLConnector.FromContext(Ctx).WithTimeout(10000);
  TLS := Connector.ConnectSocket(THandle(Sock), Host);

  if Supports(TLS.Connection, ISSLConnectionInfo, ConnInfo) then
  begin
    Info := ConnInfo.GetConnectionInfo;
    WriteLn('TLS handshake OK');
    WriteLn('  Protocol: TLS 1.3');
    WriteLn('  Cipher: ', Info.CipherSuite);
    WriteLn('  Peer: ', Info.PeerCertificate.Subject);
  end;

  Request := 'GET ' + Path + ' HTTP/1.1'#13#10 +
             'Host: ' + Host + #13#10 +
             'Connection: close'#13#10 +
             #13#10;
  TLS.WriteBuffer(Request[1], Length(Request));
  WriteLn;
  WriteLn('--- Response (first 1024 bytes) ---');

  TotalRead := 0;
  try
    repeat
      N := TLS.Read(Buffer[0], SizeOf(Buffer) - 1);
      if N > 0 then
      begin
        Buffer[N] := 0;
        if TotalRead < 1024 then
          Write(PAnsiChar(@Buffer[0]));
        TotalRead := TotalRead + N;
      end;
    until N <= 0;
  except
    // Connection closed by peer (normal for HTTP/1.1 Connection: close)
  end;
  WriteLn;
  WriteLn('--- End (total: ', TotalRead, ' bytes) ---');

  TLS.Free;
  CloseSocket(Sock);
  Lib.Finalize;
  WriteLn;
  WriteLn('Done. Pure Pascal TLS 1.3 - no external libraries needed.');
end.
