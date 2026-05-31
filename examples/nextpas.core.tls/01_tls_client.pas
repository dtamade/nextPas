program tls_client;

{$mode objfpc}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

{ ============================================================================
  示例 1: TLS 客户端连接（当前公共 API 版本）

  - 传输层：应用自己创建 TCP socket（见 examples/fafafa.examples.tcp）
  - TLS 层：使用 Rust 风格门面：TSSLConnector + TSSLStream
  - SNI/hostname：每连接设置（ConnectSocket(..., serverName)）

  编译（示例）：
    fpc -Mobjfpc -Fu./src -Fu./src/openssl -Fu./examples ./examples/01_tls_client.pas

  运行（示例）：
    ./01_tls_client https://www.example.com/
  ============================================================================ }

uses
  SysUtils, Classes, StrUtils,
  fafafa.ssl,
  nextpas.core.tls.context.builder,
  fafafa.examples.tcp;

const
  DEFAULT_URL = 'https://www.example.com/';
  DEFAULT_TIMEOUT_MS = 15000;
  BUFFER_SIZE = 16384;

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
    Delete(LTemp, 1, 8)
  else if Pos('http://', LowerCase(LTemp)) = 1 then
  begin
    Delete(LTemp, 1, 7);
    APort := 80;
  end;

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

function ReadAll(AStream: TStream): RawByteString;
var
  Buffer: array[0..BUFFER_SIZE - 1] of Byte;
  N: Longint;
  Mem: TMemoryStream;
begin
  Result := '';
  Mem := TMemoryStream.Create;
  try
    repeat
      N := AStream.Read(Buffer[0], SizeOf(Buffer));
      if N > 0 then
        Mem.WriteBuffer(Buffer[0], N);
    until N = 0;

    if Mem.Size > 0 then
    begin
      SetLength(Result, Mem.Size);
      Mem.Position := 0;
      Mem.ReadBuffer(Result[1], Mem.Size);
    end;
  finally
    Mem.Free;
  end;
end;

function FindHeaderEnd(const S: RawByteString; out ADelimLen: Integer): Integer;
begin
  Result := Pos(#13#10#13#10, S);
  if Result > 0 then
  begin
    ADelimLen := 4;
    Exit;
  end;

  Result := Pos(#10#10, S);
  if Result > 0 then
    ADelimLen := 2
  else
    ADelimLen := 0;
end;

procedure PrintHeaderPreview(const ARawResp: RawByteString; AMaxLines: Integer);
var
  HeaderEnd, DelimLen: Integer;
  HeaderBlock: RawByteString;
  Text: string;
  Lines: TStringList;
  I: Integer;
begin
  DelimLen := 0;
  HeaderEnd := FindHeaderEnd(ARawResp, DelimLen);
  if (HeaderEnd > 0) and (DelimLen > 0) then
    HeaderBlock := Copy(ARawResp, 1, HeaderEnd - 1)
  else
    HeaderBlock := ARawResp;

  Text := string(HeaderBlock);
  Text := StringReplace(Text, #13#10, #10, [rfReplaceAll]);
  Text := StringReplace(Text, #13, #10, [rfReplaceAll]);

  Lines := TStringList.Create;
  try
    Lines.Text := Text;
    for I := 0 to Lines.Count - 1 do
    begin
      if I >= AMaxLines then
        Break;
      if Trim(Lines[I]) <> '' then
        WriteLn('  ', Lines[I]);
    end;
  finally
    Lines.Free;
  end;
end;

var
  URL: string;
  Host, Path: string;
  Port: Word;
  NetErr: string;
  Sock: TSocketHandle;
  Ctx: ISSLContext;
  Connector: TSSLConnector;
  TLS: TSSLStream;
  Request: RawByteString;
  RawResp: RawByteString;
  Cert: ISSLCertificate;
  Lib: ISSLLibrary;
  LVerifyResult: Integer;
  LVerifyResultString: string;
  DelimLen, HeaderEnd: Integer;
  BodyLen: Integer;
begin
  URL := DEFAULT_URL;
  if ParamCount >= 1 then
    URL := ParamStr(1);

  if not ParseURL(URL, Host, Path, Port) then
  begin
    WriteLn('URL 解析失败: ', URL);
    Halt(2);
  end;

  WriteLn(StringOfChar('=', 80));
  WriteLn('示例 1: TLS 客户端连接');
  WriteLn('URL: ', URL);
  WriteLn(StringOfChar('=', 80));
  WriteLn;

  if not InitNetwork(NetErr) then
  begin
    WriteLn('网络初始化失败: ', NetErr);
    Halt(2);
  end;

  Sock := INVALID_SOCKET;
  TLS := nil;
  try
    Lib := TSSLFactory.GetLibraryInstance(sslAutoDetect);
    if (Lib <> nil) and Lib.Initialize then
      WriteLn('Backend: ', LibraryTypeToString(Lib.GetLibraryType), ' / ', Lib.GetVersionString);

    WriteLn('连接 TCP: ', Host, ':', Port, ' ...');
    Sock := ConnectTCP(Host, Port);

    Ctx := TSSLContextBuilder.Create
      .WithTLS12And13
      .WithVerifyPeer
      .WithSystemRoots
      .BuildClient;

    Connector := TSSLConnector.FromContext(Ctx)
      .WithTimeout(DEFAULT_TIMEOUT_MS);

    WriteLn('执行 TLS 握手 (SNI=', Host, ') ...');
    TLS := Connector.ConnectSocket(THandle(Sock), Host);

    WriteLn('TLS 版本: ', ProtocolVersionToString(TLS.Connection.GetProtocolVersion));
    WriteLn('密码套件: ', TLS.Connection.GetCipherName);
    GetCertificateVerificationInfo(TLS.Connection, LVerifyResult, LVerifyResultString);
    WriteLn('证书验证: ', LVerifyResultString);

    Cert := TLS.Connection.GetPeerCertificate;
    if Cert <> nil then
    begin
      WriteLn;
      WriteLn('服务器证书:');
      WriteLn('  主题: ', Cert.GetSubject);
      WriteLn('  颁发者: ', Cert.GetIssuer);
      WriteLn('  有效期至: ', DateTimeToStr(Cert.GetNotAfter));
    end;

    WriteLn;
    WriteLn('发送 HTTP/1.1 请求: GET ', Path);
    Request := 'GET ' + Path + ' HTTP/1.1'#13#10 +
               'Host: ' + Host + #13#10 +
               'User-Agent: fafafa.ssl-01_tls_client/1.0'#13#10 +
               'Accept: */*'#13#10 +
               'Connection: close'#13#10 +
               #13#10;

    if Length(Request) > 0 then
      TLS.WriteBuffer(Request[1], Length(Request));

    RawResp := ReadAll(TLS);
    WriteLn('收到响应: ', Length(RawResp), ' bytes');

    DelimLen := 0;
    HeaderEnd := FindHeaderEnd(RawResp, DelimLen);
    if (HeaderEnd > 0) and (DelimLen > 0) then
    begin
      BodyLen := Length(RawResp) - (HeaderEnd + DelimLen) + 1;
      if BodyLen < 0 then
        BodyLen := 0;
      WriteLn('响应体大小(粗略): ', BodyLen, ' bytes');
    end;

    WriteLn;
    WriteLn('响应头预览(前 10 行)：');
    WriteLn(StringOfChar('-', 80));
    PrintHeaderPreview(RawResp, 10);
    WriteLn(StringOfChar('-', 80));

  finally
    if TLS <> nil then
      TLS.Free;
    CloseSocket(Sock);
    CleanupNetwork;
  end;
end.
