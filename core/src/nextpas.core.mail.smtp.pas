unit nextpas.core.mail.smtp;

{$I nextpas.core.settings.inc}

{**
 * nextpas.core.mail SMTP 客户端（L3）。
 * 同步阻塞，基于 nextpas.core.net。EHLO/HELO、MAIL FROM、RCPT TO、
 * DATA（点转义）、QUIT、AUTH PLAIN/LOGIN、STARTTLS 能力探测。
 * 连接/读写超时经 deadline，取消经 INetCancelController。
 * 错误契约：方法抛异常（ESmtpError 族 / ETimeoutError / ECancelledError /
 * ENetworkError），Try* 对偶方法捕获后返回 False，细节见 LastReply/LastError。
 * 本批次不含 TLS 升级（STARTTLS 只探测不握手）。
 *}

interface

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.net,
  nextpas.core.mail.base;

type
  ESmtpError = class(ENextPasError);
  ESmtpProtocolError = class(ESmtpError);    { 响应无法解析 }
  ESmtpRejectedError = class(ESmtpError);    { 服务器 4xx/5xx 拒绝命令 }
  ESmtpAuthError = class(ESmtpRejectedError); { 认证失败 }

  TSmtpReply = record
    Code: Integer;          { 3 位响应码 }
    Category: Integer;      { Code div 100 }
    Text: string;           { 各行文本以空格拼接（不含码） }
    Lines: array of string; { 各行文本（不含码与分隔符） }
    function IsPositive: Boolean;   { 2xx/3xx }
    function IsSuccess: Boolean;    { 2xx }
    function IsPermanent: Boolean;  { 5xx }
  end;

  TSmtpCapabilities = record
  public
    Extensions: array of string;      { 小写扩展名，如 'starttls'、'8bitmime' }
    AuthMechanisms: array of string;  { 大写机制名，如 'PLAIN'、'LOGIN' }
    MaxSize: Int64;                   { SIZE= 值；0 表示未知 }
    function Supports(const AExtension: string): Boolean;
    function SupportsAuth(const AMechanism: string): Boolean;
  end;

  TSmtpClientConfig = record
    Host: string;
    Port: UInt16;
    HeloDomain: string;      { EHLO/HELO 域；'' → 'localhost' }
    ConnectTimeoutMs: Int64; { 拨号超时；<=0 不限 }
    IoTimeoutMs: Int64;      { 单次读写 deadline；<=0 不限 }
  end;

  TSmtpClient = class
  private
    FConfig: TSmtpClientConfig;
    FStream: ITcpStream;
    FCancel: INetCancelController;
    FConnected: Boolean;
    FGreeting: string;
    FCapabilities: TSmtpCapabilities;
    FLastReply: TSmtpReply;
    FLastError: string;
    function ReadLine: string;
    function ReadReply: TSmtpReply;
    function SendCommand(const ALine: string): TSmtpReply;
    procedure SendRaw(const AData: string);
    function ParseCapabilities(const AReply: TSmtpReply): TSmtpCapabilities;
    procedure EnsureConnected;
    procedure SetReadDeadline;
    procedure SetWriteDeadline;
  public
    constructor Create(const AConfig: TSmtpClientConfig);
    destructor Destroy; override;

    { 连接 + 问候语 + EHLO（失败回退 HELO）；失败抛异常 }
    procedure Connect;
    function TryConnect: Boolean;
    { QUIT + 关闭。尽力而为：不抛异常（RFC 5321 客户端正常终止）；TryQuit 恒 true }
    procedure Quit;
    function TryQuit: Boolean;

    procedure SendMail(const AFrom: TMailAddress; const ATo: TMailAddressArray;
      const AData: string);
    function TrySendMail(const AFrom: TMailAddress; const ATo: TMailAddressArray;
      const AData: string): Boolean;
    { AUTH PLAIN（首选）/ AUTH LOGIN；失败抛 ESmtpAuthError }
    procedure Auth(const AUsername, APassword: string);
    function TryAuth(const AUsername, APassword: string): Boolean;
    { 唤醒阻塞中的读写（ECancelledError） }
    procedure Cancel;

    property Connected: Boolean read FConnected;
    property Capabilities: TSmtpCapabilities read FCapabilities;
    property Greeting: string read FGreeting;
    property LastReply: TSmtpReply read FLastReply;
    property LastError: string read FLastError;
  end;

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.text.builder,
  nextpas.core.encoding.base64,
  nextpas.core.time;

const
  MAX_SMTP_LINE = 65536;  { 防失控行长（RFC 5321 建议 512，容忍 >=1KB 常见实现） }

{ 按空白拆 token }
function SplitWhitespace(const AValue: string): TStringArray;
var
  LCount, I: Integer;
  LStart: Integer;
begin
  Result := nil;
  LCount := 0;
  LStart := 0;
  for I := 1 to Length(AValue) + 1 do
  begin
    if (I > Length(AValue)) or (AValue[I] = ' ') or (AValue[I] = #9) then
    begin
      if LStart > 0 then
      begin
        SetLength(Result, LCount + 1);
        Result[LCount] := Copy(AValue, LStart, I - LStart);
        Inc(LCount);
        LStart := 0;
      end;
    end
    else if LStart = 0 then
      LStart := I;
  end;
end;

{ TSmtpReply }

function TSmtpReply.IsPositive: Boolean;
begin
  Result := (Category >= 2) and (Category <= 3);
end;

function TSmtpReply.IsSuccess: Boolean;
begin
  Result := Category = 2;
end;

function TSmtpReply.IsPermanent: Boolean;
begin
  Result := Category = 5;
end;

{ TSmtpCapabilities }

function TSmtpCapabilities.Supports(const AExtension: string): Boolean;
var
  I: Integer;
begin
  for I := 0 to Length(Extensions) - 1 do
    if Extensions[I] = LowerCase(AExtension) then
      Exit(True);
  Result := False;
end;

function TSmtpCapabilities.SupportsAuth(const AMechanism: string): Boolean;
var
  I: Integer;
begin
  for I := 0 to Length(AuthMechanisms) - 1 do
    if AuthMechanisms[I] = UpperCase(AMechanism) then
      Exit(True);
  Result := False;
end;

{ TSmtpClient }

constructor TSmtpClient.Create(const AConfig: TSmtpClientConfig);
begin
  inherited Create;
  FConfig := AConfig;
  if FConfig.HeloDomain = '' then
    FConfig.HeloDomain := 'localhost';
  FCancel := NewNetCancelToken;
end;

destructor TSmtpClient.Destroy;
begin
  try
    Quit;
  except
    on E: Exception do
    begin
      { 析构不抛；清理现场 }
    end;
  end;
  inherited Destroy;
end;

procedure TSmtpClient.SetReadDeadline;
begin
  if FConfig.IoTimeoutMs > 0 then
    FStream.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(FConfig.IoTimeoutMs)))
  else
    FStream.SetReadDeadline(TDeadline.Infinite);
end;

procedure TSmtpClient.SetWriteDeadline;
begin
  if FConfig.IoTimeoutMs > 0 then
    FStream.SetWriteDeadline(TDeadline.After(TDuration.FromMilliseconds(FConfig.IoTimeoutMs)))
  else
    FStream.SetWriteDeadline(TDeadline.Infinite);
end;

{ 读一行（去 CRLF）；EOF 抛 ENetworkError，超长抛 ESmtpProtocolError。
  deadline 按整行设置一次（慢滴流不算超时）。 }
function TSmtpClient.ReadLine: string;
var
  LBytes: TBytes;
  LCap: Integer;
  LByte: Byte;
  LRaw: Byte;
begin
  SetLength(LBytes, 512);
  LCap := 0;
  SetReadDeadline;
  while True do
  begin
    LRaw := 0;
    if FStream.Read(LRaw, 1) = 0 then
      raise ENetworkError.Create('smtp connection closed by server');
    LByte := LRaw;
    if LByte = 10 then
      Break;
    if LByte <> 13 then
    begin
      if LCap >= Length(LBytes) then
        SetLength(LBytes, LCap * 2);
      LBytes[LCap] := LByte;
      Inc(LCap);
      if LCap > MAX_SMTP_LINE then
        raise ESmtpProtocolError.Create('smtp line too long');
    end;
  end;
  SetLength(LBytes, LCap);
  Result := ASCIIBytesToString(LBytes);
end;

{ 读完整响应（多行 250-…/250 … 结构）；拆码失败抛 ESmtpProtocolError }
function TSmtpClient.ReadReply: TSmtpReply;
var
  LLine: string;
  LCode: Integer;
  LBuilder: TBufStringBuilder;
  I: Integer;
  LSep: Integer;
begin
  Result := Default(TSmtpReply);
  LBuilder.Init(128);
  LLine := ReadLine;
  if Length(LLine) < 3 then
    raise ESmtpProtocolError.Create('bad smtp reply: ' + LLine);
  for I := 1 to 3 do
    if (LLine[I] < '0') or (LLine[I] > '9') then
      raise ESmtpProtocolError.Create('bad smtp reply code: ' + LLine);
  LCode := (Ord(LLine[1]) - Ord('0')) * 100 +
           (Ord(LLine[2]) - Ord('0')) * 10 +
           (Ord(LLine[3]) - Ord('0'));
  Result.Code := LCode;
  Result.Category := LCode div 100;

  { 首行的码后文本 }
  LSep := Pos('-', LLine);
  if LSep = 4 then
  begin
    { 多行：首行也算一条 Lines（如 EHLO 特性列表），继续读到同码 ' ' 结尾行 }
    SetLength(Result.Lines, 1);
    Result.Lines[0] := Copy(LLine, 5, Length(LLine) - 4);
    if LBuilder.Len > 0 then
      LBuilder.AppendChar(' ');
    LBuilder.AppendStr(Result.Lines[0]);
    while True do
    begin
      LLine := ReadLine;
      if Copy(LLine, 1, 4) = IntToStr(LCode) + ' ' then
      begin
        { 结束行（可带正文） }
        if Length(LLine) > 4 then
        begin
          SetLength(Result.Lines, Length(Result.Lines) + 1);
          Result.Lines[High(Result.Lines)] := Copy(LLine, 5, Length(LLine) - 4);
          if LBuilder.Len > 0 then
            LBuilder.AppendChar(' ');
          LBuilder.AppendStr(Copy(LLine, 5, Length(LLine) - 4));
        end;
        Break;
      end
      else if Copy(LLine, 1, 3) = IntToStr(LCode) then
      begin
        { 中间行 '250-…' }
        SetLength(Result.Lines, Length(Result.Lines) + 1);
        Result.Lines[High(Result.Lines)] := Copy(LLine, 5, Length(LLine) - 4);
        if LBuilder.Len > 0 then
          LBuilder.AppendChar(' ');
        LBuilder.AppendStr(Copy(LLine, 5, Length(LLine) - 4));
      end
      else
        raise ESmtpProtocolError.Create('smtp multiline code mismatch: ' + LLine);
    end;
  end
  else
  begin
    { 单行 '250 …' 或裸 '250' }
    SetLength(Result.Lines, 1);
    if Length(LLine) > 4 then
      Result.Lines[0] := Copy(LLine, 5, Length(LLine) - 4)
    else
      Result.Lines[0] := '';
    LBuilder.AppendStr(Result.Lines[0]);
  end;
  Result.Text := LBuilder.ToString;
  LBuilder.Done;
end;

procedure TSmtpClient.SendRaw(const AData: string);
var
  LBytes: TBytes;
begin
  SetWriteDeadline;
  LBytes := StringToUTF8Bytes(AData);
  if Length(LBytes) > 0 then
    FStream.Write(LBytes[0], Length(LBytes));
end;

{ 发命令并读响应 }
function TSmtpClient.SendCommand(const ALine: string): TSmtpReply;
begin
  SendRaw(ALine + #13#10);
  Result := ReadReply;
  FLastReply := Result;
end;

{ EHLO 响应解析能力：跳过首行（服务器域名），逐行登记扩展/AUTH/SIZE }
function TSmtpClient.ParseCapabilities(const AReply: TSmtpReply): TSmtpCapabilities;
var
  LTokens: TStringArray;
  I, J: Integer;
  LLine: string;
begin
  Result := Default(TSmtpCapabilities);
  for I := 1 to Length(AReply.Lines) - 1 do
  begin
    LLine := AReply.Lines[I];
    if LLine = '' then
      Continue;
    LTokens := SplitWhitespace(LLine);
    if Length(LTokens) = 0 then
      Continue;
    if LowerCase(LTokens[0]) = 'auth' then
    begin
      SetLength(Result.AuthMechanisms, Length(LTokens) - 1);
      for J := 1 to Length(LTokens) - 1 do
        Result.AuthMechanisms[J - 1] := UpperCase(LTokens[J]);
    end
    else if LowerCase(LTokens[0]) = 'size' then
    begin
      if Length(LTokens) > 1 then
        Result.MaxSize := StrToInt64Def(LTokens[1], 0);
    end
    else
    begin
      SetLength(Result.Extensions, Length(Result.Extensions) + 1);
      Result.Extensions[High(Result.Extensions)] := LowerCase(LTokens[0]);
    end;
  end;
end;

procedure TSmtpClient.EnsureConnected;
begin
  if not FConnected then
    raise EInvalidOperationError.Create('smtp client not connected');
end;

procedure TSmtpClient.Connect;
var
  LReply: TSmtpReply;
begin
  if FConnected then
    raise EInvalidOperationError.Create('smtp client already connected');
  try
    if FConfig.ConnectTimeoutMs > 0 then
      FStream := TcpConnect(FConfig.Host, FConfig.Port, FConfig.ConnectTimeoutMs)
    else
      FStream := TcpConnect(FConfig.Host, FConfig.Port);
    FStream.SetCancelToken(FCancel);
    LReply := ReadReply;
    if LReply.Category <> 2 then
      raise ESmtpRejectedError.Create('smtp greeting rejected (' +
        IntToStr(LReply.Code) + '): ' + LReply.Text);
    FGreeting := LReply.Text;
    FLastReply := LReply;

    LReply := SendCommand('EHLO ' + FConfig.HeloDomain);
    if LReply.Category <> 2 then
    begin
      { RFC 5321：EHLO 失败回退 HELO }
      LReply := SendCommand('HELO ' + FConfig.HeloDomain);
      if LReply.Category <> 2 then
        raise ESmtpRejectedError.Create('ehlo/helo rejected (' +
          IntToStr(LReply.Code) + '): ' + LReply.Text);
      FCapabilities := Default(TSmtpCapabilities);
    end
    else
      FCapabilities := ParseCapabilities(LReply);
    FConnected := True;
  except
    on E: Exception do
    begin
      if FStream <> nil then
      begin
        try
          FStream.Close;
        except
          on E2: Exception do
            { 忽略关闭错误 }
          end;
      end;
      FStream := nil;
      FLastError := E.Message;
      raise;
    end;
  end;
end;

function TSmtpClient.TryConnect: Boolean;
begin
  try
    Connect;
    Result := True;
  except
    on E: Exception do
    begin
      Result := False;
      FLastError := E.Message;
    end;
  end;
end;

procedure TSmtpClient.Quit;
begin
  if not FConnected then
    Exit;
  try
    FLastReply := SendCommand('QUIT');
  except
    on E: Exception do
    begin
      { 4xx/5xx 或传输错误都视为会话结束；传输错误记入 LastError }
      if not (E is ESmtpRejectedError) then
        FLastError := E.Message;
    end;
  end;
  if FStream <> nil then
    try
      FStream.Close;
    except
      on E: Exception do
      begin
      end;
    end;
  FConnected := False;
end;

function TSmtpClient.TryQuit: Boolean;
begin
  try
    Quit;
    Result := True;
  except
    on E: Exception do
    begin
      Result := False;
      FLastError := E.Message;
    end;
  end;
end;

{ DATA 正文：CRLF 归一化 + 点转义 + 结束点 }
procedure SendDataBody(const AStream: ITcpStream; const AData: string);
var
  LBuilder: TBufStringBuilder;
  I: Integer;
  LAtLineStart: Boolean;
  LCRPending: Boolean;
  LBytes: TBytes;
begin
  LBuilder.Init(Length(AData) + 32);
  LAtLineStart := True;
  LCRPending := False;
  for I := 1 to Length(AData) do
  begin
    if LCRPending then
    begin
      { 上一字符是 CR：本字符必为 LF，即 CRLF 行界 }
      LBuilder.AppendStr(#13#10);
      LCRPending := False;
      LAtLineStart := True;
      if (I <= Length(AData)) and (AData[I] = #10) then
        Continue;
    end;
    if AData[I] = #10 then
    begin
      LBuilder.AppendStr(#13#10);
      LAtLineStart := True;
    end
    else if AData[I] = #13 then
    begin
      { CR 后跟 LF？需要前瞻：本循环下次迭代处理；若末尾 CR 视为行界 }
      if I = Length(AData) then
      begin
        LBuilder.AppendStr(#13#10);
        LAtLineStart := True;
      end
      else
        LCRPending := True;
    end
    else
    begin
      if LAtLineStart and (AData[I] = '.') then
        LBuilder.AppendChar('.');   { 点转义 }
      LBuilder.AppendChar(AData[I]);
      LAtLineStart := False;
    end;
  end;
  if LCRPending then
    LBuilder.AppendStr(#13#10);
  { 结束点必须自带行界（CRLF . CRLF），否则会与前/后字节粘连成一行 }
  LBuilder.AppendStr(#13#10 + '.' + #13#10);
  { 发送 }
  if LBuilder.Len > 0 then
  begin
    LBytes := StringToUTF8Bytes(LBuilder.ToString);
    AStream.Write(LBytes[0], Length(LBytes));
  end;
  LBuilder.Done;
end;

procedure TSmtpClient.SendMail(const AFrom: TMailAddress; const ATo: TMailAddressArray;
  const AData: string);
var
  LReply: TSmtpReply;
  LOk: Integer;
  LRejected: string;
  I: Integer;
begin
  EnsureConnected;
  if Length(ATo) = 0 then
    raise EArgumentError.Create('smtp send: no recipients');

  LReply := SendCommand('MAIL FROM:<' + AFrom.Full + '>');
  if not LReply.IsSuccess then
    raise ESmtpRejectedError.Create('MAIL FROM rejected (' +
      IntToStr(LReply.Code) + '): ' + LReply.Text);

  LOk := 0;
  LRejected := '';
  for I := 0 to Length(ATo) - 1 do
  begin
    LReply := SendCommand('RCPT TO:<' + ATo[I].Full + '>');
    if LReply.IsSuccess then
      Inc(LOk)
    else
      LRejected := LRejected + ATo[I].Full + ' ' +
        IntToStr(LReply.Code) + '; ';
  end;
  if LOk = 0 then
    raise ESmtpRejectedError.Create('all recipients rejected: ' + LRejected);

  LReply := SendCommand('DATA');
  if LReply.Category <> 3 then
    raise ESmtpRejectedError.Create('DATA rejected (' +
      IntToStr(LReply.Code) + '): ' + LReply.Text);

  SendDataBody(FStream, AData);
  LReply := ReadReply;
  FLastReply := LReply;
  if not LReply.IsSuccess then
    raise ESmtpRejectedError.Create('message rejected (' +
      IntToStr(LReply.Code) + '): ' + LReply.Text);
end;

function TSmtpClient.TrySendMail(const AFrom: TMailAddress; const ATo: TMailAddressArray;
  const AData: string): Boolean;
begin
  try
    SendMail(AFrom, ATo, AData);
    Result := True;
  except
    on E: Exception do
    begin
      Result := False;
      FLastError := E.Message;
    end;
  end;
end;

{ AUTH PLAIN：单命令 base64(#0user#0pass) }
procedure TSmtpClient.Auth(const AUsername, APassword: string);
var
  LReply: TSmtpReply;
  LCred: string;
begin
  EnsureConnected;
  if FCapabilities.SupportsAuth('LOGIN') and (not FCapabilities.SupportsAuth('PLAIN')) then
  begin
    { AUTH LOGIN：334 挑战式三步 }
    LReply := SendCommand('AUTH LOGIN');
    if LReply.Category <> 3 then
      raise ESmtpAuthError.Create('AUTH LOGIN rejected (' +
        IntToStr(LReply.Code) + '): ' + LReply.Text);
    LReply := SendCommand(Base64Encode(StringToUTF8Bytes(AUsername)));
    if LReply.Category <> 3 then
      raise ESmtpAuthError.Create('AUTH LOGIN user rejected (' +
        IntToStr(LReply.Code) + '): ' + LReply.Text);
    LReply := SendCommand(Base64Encode(StringToUTF8Bytes(APassword)));
    if not LReply.IsSuccess then
      raise ESmtpAuthError.Create('AUTH LOGIN failed (' +
        IntToStr(LReply.Code) + '): ' + LReply.Text);
  end
  else
  begin
    { AUTH PLAIN：默认首选；未广播时仍尝试（服务器定夺） }
    LCred := #0 + AUsername + #0 + APassword;
    LReply := SendCommand('AUTH PLAIN ' + Base64Encode(StringToUTF8Bytes(LCred)));
    if not LReply.IsSuccess then
      raise ESmtpAuthError.Create('AUTH PLAIN failed (' +
        IntToStr(LReply.Code) + '): ' + LReply.Text);
  end;
  FLastReply := LReply;
end;

function TSmtpClient.TryAuth(const AUsername, APassword: string): Boolean;
begin
  try
    Auth(AUsername, APassword);
    Result := True;
  except
    on E: Exception do
    begin
      Result := False;
      FLastError := E.Message;
    end;
  end;
end;

procedure TSmtpClient.Cancel;
begin
  if FCancel <> nil then
    FCancel.Cancel;
end;

end.