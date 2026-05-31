unit nextpas.core.http.server;
{**
 * @desc Thread-per-connection HTTP/1.1 server with keep-alive support.
 *       Loops on each connection handling multiple requests until close.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf;

type
  THttpServerOptions = record
    ReadTimeout: Int64;   // milliseconds, 0 = no timeout
    WriteTimeout: Int64;  // milliseconds, 0 = no timeout
    IdleTimeout: Int64;   // milliseconds between requests, default 30000
    MaxHeaderSize: Int32; // bytes, default 8192
    MaxBodySize: Int64;   // bytes, default 4194304 (4MB), 0 = unlimited
    class function Default: THttpServerOptions; static;
  end;

  THttpServer = class(TInterfacedObject, IHttpServer)
  private
    FHandler: IHttpHandler;
    FOptions: THttpServerOptions;
    FRunning: Boolean;
    FListener: ITcpListener;
  public
    constructor Create(const AHandler: IHttpHandler; const AOptions: THttpServerOptions);
    destructor Destroy; override;
    procedure ListenAndServe(const AAddr: string; const APort: UInt16);
    procedure Shutdown;
    function LocalAddr: TNetAddress;
    function IsRunning: Boolean;
  end;

function NewHttpServer(const AHandler: IHttpHandler): IHttpServer; overload;
function NewHttpServer(const AHandler: IHttpHandler; const AOptions: THttpServerOptions): IHttpServer; overload;

implementation

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.io.intf,
  nextpas.core.io.buffer,
  nextpas.core.io.memory,
  nextpas.core.net.tcp,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.text.conv,
  nextpas.core.http.headers,
  nextpas.core.http.message,
  nextpas.core.http.impl.h1.parser,
  nextpas.core.http.impl.h1.writer,
  nextpas.core.platform.thread;

type
  PConnContext = ^TConnContext;
  TConnContext = record
    Conn: ITcpStream;
    Handler: IHttpHandler;
    Options: THttpServerOptions;
  end;

function ShouldKeepAlive(const AParser: IH1Parser): Boolean;
var
  LConn: string;
begin
  LConn := AParser.GetHeaders.Get('connection');
  if AParser.GetHttpVersion = hvHttp10 then
    Result := (LConn = 'keep-alive')
  else
    Result := (LConn <> 'close');
end;

procedure WriteErrorResponse(const AConn: ITcpStream; const AStatus: THttpStatus);
var
  LW: IHttpResponseWriter;
  LBody: string;
begin
  try
    LW := TH1ResponseWriter.Create(AConn as IWriter);
    LBody := HttpStatusText(AStatus);
    LW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LBody))));
    LW.GetHeaders.Set_('connection', 'close');
    LW.WriteHeader(AStatus);
    if Length(LBody) > 0 then
      LW.Write(LBody[1], SizeUInt(Length(LBody)));
  except
    { Swallow write errors during error response }
  end;
end;

function StrToBytes(const S: string): TBytes;
begin
  SetLength(Result, Length(S));
  if Length(S) > 0 then
    Move(S[1], Result[0], Length(S));
end;

procedure HandleConnection(const AConn: ITcpStream; const AHandler: IHttpHandler;
  const AOptions: THttpServerOptions);
var
  LParser: IH1Parser;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LUrl: TUrl;
  LReq: IHttpRequest;
  LW: IHttpResponseWriter;
  LKeepAlive: Boolean;
  LIdleMs: Int64;
  LBufWriter: IWriter;
  LBodyStr: string;
  LBodyReader: IReader;
  LContentLen: Int64;
  LTotalRead: SizeUInt;
  LHeadersDone: Boolean;
begin
  LParser := NewH1RequestParser;
  LBufWriter := CreateBufferedWriter(AConn as IWriter, 4096);
  LKeepAlive := True;
  if AOptions.IdleTimeout > 0 then
    LIdleMs := AOptions.IdleTimeout
  else
    LIdleMs := 30000;

  while LKeepAlive do
  begin
    try
      { Set idle timeout for reading next request }
      AConn.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(LIdleMs)));
      if AOptions.WriteTimeout > 0 then
        AConn.SetWriteDeadline(TDeadline.After(TDuration.FromMilliseconds(AOptions.WriteTimeout)));

      { Parse request }
      LParser.Reset;
      LTotalRead := 0;
      LHeadersDone := False;
      repeat
        LN := AConn.Read(LBuf[0], 4096);
        if LN = 0 then begin LKeepAlive := False; Break; end;
        Inc(LTotalRead, LN);
        LParser.Execute(@LBuf[0], LN);
        { Detect when headers become available }
        if (not LHeadersDone) and ((LParser.GetUrl <> '') or LParser.IsComplete) then
        begin
          LHeadersDone := True;
          { Check header size limit: total bytes read when headers parsed
            minus body length gives approximate header size }
          if (AOptions.MaxHeaderSize > 0) and
             (Int64(LTotalRead) - Int64(Length(LParser.GetBody)) > Int64(AOptions.MaxHeaderSize)) then
          begin
            WriteErrorResponse(AConn, HTTP_STATUS_HEADER_TOO_LARGE);
            LKeepAlive := False;
            Break;
          end;
        end;
      until LParser.IsComplete or LParser.HasError;

      if not LParser.IsComplete then
      begin
        if LParser.HasError then
          WriteErrorResponse(AConn, HTTP_STATUS_BAD_REQUEST);
        Break;
      end;

      { Check body size limit }
      if AOptions.MaxBodySize > 0 then
      begin
        LBodyStr := LParser.GetBody;
        if Int64(Length(LBodyStr)) > AOptions.MaxBodySize then
        begin
          WriteErrorResponse(AConn, HTTP_STATUS_PAYLOAD_TOO_LARGE);
          LKeepAlive := False;
          Continue;
        end;
      end;

      { Determine keep-alive before dispatching }
      LKeepAlive := ShouldKeepAlive(LParser);

      { Build request }
      LUrl := TUrl.Parse(LParser.GetUrl);
      LBodyStr := LParser.GetBody;
      if LBodyStr <> '' then
      begin
        LBodyReader := CreateBytesStreamFrom(StrToBytes(LBodyStr)) as IReader;
        LContentLen := Int64(Length(LBodyStr));
      end
      else
      begin
        LBodyReader := nil;
        LContentLen := 0;
      end;
      LReq := THttpRequest.Create(LParser.GetMethod, LUrl, LParser.GetHttpVersion,
        LParser.GetHeaders, LBodyReader, LContentLen);

      { Set remote address }
      (LReq as THttpRequest).SetRemoteAddr(AConn.RemoteAddr.ToString);

      { Dispatch to handler }
      LW := TH1ResponseWriter.Create(LBufWriter);
      { For HTTP/1.0 keep-alive, add the header explicitly }
      if LKeepAlive and (LParser.GetHttpVersion = hvHttp10) then
        LW.GetHeaders.Set_('connection', 'keep-alive');
      { If we plan to close, signal it }
      if not LKeepAlive then
        LW.GetHeaders.Set_('connection', 'close');

      AHandler.ServeHTTP(LReq, LW);
      LW.Flush;
      (LBufWriter as IFlusher).Flush;

      { If response writer forced connection close (no content-length),
        the writer already set Connection: close — we must stop }
      if LW.GetHeaders.Get('connection') = 'close' then
        LKeepAlive := False;
    except
      on E: Exception do
      begin
        WriteErrorResponse(AConn, HTTP_STATUS_INTERNAL_SERVER_ERROR);
        LKeepAlive := False;
      end;
    end;
  end;
end;

function ConnThreadFunc(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PConnContext;
  LConn: ITcpStream;
  LHandler: IHttpHandler;
  LOptions: THttpServerOptions;
begin
  Result := nil;
  LCtx := PConnContext(AArg);
  LConn := LCtx^.Conn;
  LHandler := LCtx^.Handler;
  LOptions := LCtx^.Options;
  Dispose(LCtx);
  try
    HandleConnection(LConn, LHandler, LOptions);
  finally
    LConn.Shutdown;
    LConn.Close;
    LConn := nil;
    LHandler := nil;
  end;
end;

{ THttpServerOptions }

class function THttpServerOptions.Default: THttpServerOptions;
begin
  Result.ReadTimeout := 0;
  Result.WriteTimeout := 0;
  Result.IdleTimeout := 30000; { 30 seconds between requests }
  Result.MaxHeaderSize := 8192;
  Result.MaxBodySize := 4194304; { 4 MB }
end;

{ THttpServer }

constructor THttpServer.Create(const AHandler: IHttpHandler; const AOptions: THttpServerOptions);
begin
  inherited Create;
  FHandler := AHandler;
  FOptions := AOptions;
  FRunning := False;
  FListener := nil;
end;

destructor THttpServer.Destroy;
begin
  if FRunning then
    Shutdown;
  FHandler := nil;
  FListener := nil;
  inherited;
end;

procedure THttpServer.ListenAndServe(const AAddr: string; const APort: UInt16);
var
  LConn: ITcpStream;
  LCtx: PConnContext;
  LHandle: TPlatformThreadHandle;
begin
  FListener := NetTcpListen(AAddr, APort);
  FRunning := True;
  while FRunning do
  begin
    try
      LConn := FListener.Accept;
    except
      { Accept fails when listener is closed during Shutdown }
      Break;
    end;
    if (LConn = nil) or (not FRunning) then
      Break;
    New(LCtx);
    LCtx^.Conn := LConn;
    LCtx^.Handler := FHandler;
    LCtx^.Options := FOptions;
    if platform_thread_create(LHandle, @ConnThreadFunc, LCtx) = 0 then
      platform_thread_detach(LHandle)
    else
    begin
      { Thread creation failed — handle inline }
      HandleConnection(LConn, FHandler, FOptions);
      LConn.Close;
      Dispose(LCtx);
    end;
  end;
end;

procedure THttpServer.Shutdown;
var
  LAddr: TNetAddress;
  LWake: ITcpStream;
begin
  FRunning := False;
  if FListener <> nil then
  begin
    { Connect to self to unblock Accept() — closing the listener socket
      does not reliably unblock accept() on Linux }
    LAddr := FListener.LocalAddr;
    try
      LWake := NetTcpConnect(LAddr.IP, LAddr.Port);
      LWake.Close;
    except
      { Ignore — listener may already be closed }
    end;
    FListener.Close;
  end;
end;

function THttpServer.LocalAddr: TNetAddress;
begin
  if FListener <> nil then
    Result := FListener.LocalAddr
  else
    Result := TNetAddress.Any(0);
end;

function THttpServer.IsRunning: Boolean;
begin
  Result := FRunning;
end;

{ Factory functions }

function NewHttpServer(const AHandler: IHttpHandler): IHttpServer;
begin
  Result := THttpServer.Create(AHandler, THttpServerOptions.Default);
end;

function NewHttpServer(const AHandler: IHttpHandler; const AOptions: THttpServerOptions): IHttpServer;
begin
  Result := THttpServer.Create(AHandler, AOptions);
end;

end.
