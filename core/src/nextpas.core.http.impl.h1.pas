unit nextpas.core.http.impl.h1;
{**
 * @desc Default HTTP/1.x transport implementations for client and server.
 *       Owns single-request round trips, connection reuse, and per-connection
 *       request/response handling for the shared HTTP facade layer.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf,
  nextpas.core.net.intf,
  nextpas.core.net.server.intf,
  nextpas.core.net.server.base,
  nextpas.core.platform.io.base,
  nextpas.core.http.base,
  nextpas.core.http.intf;

type
  TH1ClientTransportOptions = record
    Timeout: Int64;
  end;

  TH1ServerTransportOptions = record
    ReadTimeout: Int64;
    WriteTimeout: Int64;
    IdleTimeout: Int64;
    MaxHeaderSize: Int32;
    MaxBodySize: Int64;
  end;

function NewH1ClientTransport(const AOptions: TH1ClientTransportOptions): IHttpTransport;
function NewH1ServerTransport(const AOptions: TH1ServerTransportOptions): IHttpServerTransport;

implementation

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.errors,
  nextpas.core.io.base,
  nextpas.core.io.buffer,
  nextpas.core.net,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.text.conv,
  nextpas.core.http.headers,
  nextpas.core.http.message,
  nextpas.core.http.impl.h1.outbound,
  nextpas.core.http.impl.h1.parser,
  nextpas.core.http.impl.h1.writer;

type
  TPoolEntry = record
    Host: string;
    Port: UInt16;
    Conn: ITcpStream;
  end;

  TPrefixedTcpStream = class(TInterfacedObject, IReader, IWriter, IStream, ITcpStream)
  private
    FInner: ITcpStream;
    FPrefix: string;
    FPrefixPos: SizeInt;
  public
    constructor Create(const AInner: ITcpStream; const APrefix: string);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
    procedure Close;
    function GetSize: Int64;
    function GetPosition: Int64;
    procedure SetPosition(const AValue: Int64);
    function LocalAddr: TNetAddress;
    function RemoteAddr: TNetAddress;
    procedure Shutdown;
    procedure SetNoDelay(const AValue: Boolean);
    procedure SetKeepAlive(const AValue: Boolean);
    procedure SetReadDeadline(const ADeadline: TDeadline);
    procedure SetWriteDeadline(const ADeadline: TDeadline);
  end;

  TH1ClientTransport = class(TInterfacedObject, IHttpTransport)
  private
    FOptions: TH1ClientTransportOptions;
    FPool: array of TPoolEntry;
    FPoolCount: Int32;
    function PoolGet(const AHost: string; const APort: UInt16): ITcpStream;
    procedure PoolPut(const AHost: string; const APort: UInt16; const AConn: ITcpStream);
    function WriteRequest(const AWriter: IWriter; const AReq: IHttpRequest): Boolean;
    function ReadResponse(const AReader: IReader;
      const ARequestMethod: THttpMethod; out AKeepAlive: Boolean): IHttpResponse;
  public
    constructor Create(const AOptions: TH1ClientTransportOptions);
    function RoundTrip(const AReq: IHttpRequest): IHttpResponse;
  end;

  TH1ServerTransport = class(TInterfacedObject, IHttpServerTransport,
    IHttpServerSessionFactory, IHttpServerSessionFactoryWithContext)
  private
    FOptions: TH1ServerTransportOptions;
    function HandleConnection(const AConn: ITcpStream; const AHandler: IHttpHandler): Boolean;
  public
    constructor Create(const AOptions: TH1ServerTransportOptions);
    function ServeConn(const AConn: ITcpStream;
      const AHandler: IHttpHandler): TTcpServerConnOwnership;
    function NewSession(const AConn: ITcpStream;
      const AHandler: IHttpHandler): ITcpServerSession; overload;
    function NewSession(const AConn: ITcpStream; const AHandler: IHttpHandler;
      const AContext: ITcpServerSessionContext): ITcpServerSession; overload;
  end;

  TH1ServerConnectionState = class;

  TH1PollRunWork = class(TInterfacedObject, ITcpServerWork)
  private
    FState: TH1ServerConnectionState;
  public
    constructor Create(const AState: TH1ServerConnectionState);
    function Execute: TTcpServerConnOwnership;
  end;

  TH1PollRequestWork = class(TInterfacedObject, ITcpServerWork)
  private
    FState: TH1ServerConnectionState;
    FOutbound: IH1OutboundBuffer;
    FCloseAfterDrain: Boolean;
  public
    constructor Create(const AState: TH1ServerConnectionState);
    function Execute: TTcpServerConnOwnership;
    property Outbound: IH1OutboundBuffer read FOutbound;
    property CloseAfterDrain: Boolean read FCloseAfterDrain;
  end;

  TH1PollRunCompletion = class(TInterfacedObject, ITcpServerWorkCompletion)
  private
    FState: TH1ServerConnectionState;
  public
    constructor Create(const AState: TH1ServerConnectionState);
    procedure Complete(const AOutcome: TTcpServerWorkOutcome;
      const AOwnership: TTcpServerConnOwnership);
  end;

  TH1PollRequestCompletion = class(TInterfacedObject, ITcpServerWorkCompletion)
  private
    FState: TH1ServerConnectionState;
    FWorkRef: ITcpServerWork;
    FWork: TH1PollRequestWork;
  public
    constructor Create(const AState: TH1ServerConnectionState;
      const AWork: TH1PollRequestWork);
    procedure Complete(const AOutcome: TTcpServerWorkOutcome;
      const AOwnership: TTcpServerConnOwnership);
  end;

  // Connection state stays protocol-owned so future runtimes can drive
  // the same H1 logic without keeping it welded to a thread entrypoint.
  TH1ServerConnectionState = class(TInterfacedObject, ITcpServerSession,
    ITcpServerPollDrivenSession, ITcpServerPollDrivenSessionWithDeadline)
  private
    FOptions: TH1ServerTransportOptions;
    FConn: ITcpStream;
    FHandler: IHttpHandler;
    FSessionContext: ITcpServerSessionContext;
    FSocketRuntime: ITcpSocketRuntime;
    FStreamRuntime: ITcpStreamRuntime;
    FWorkerHandoff: ITcpServerWorkerHandoff;
    FParser: IH1Parser;
    FPending: string;
    FKeepAlive: Boolean;
    FIdleMs: Int64;
    FBuf: array[0..4095] of Byte;
    FPollSubmitted: Boolean;
    FPollWorkerPending: Boolean;
    FPollCompletionReady: Boolean;
    FPollCompletionOwnership: TTcpServerConnOwnership;
    FPollNeedRequestReset: Boolean;
    FParseTotalRead: SizeUInt;
    FParseHeadersDone: Boolean;
    FPollOutbound: IH1OutboundBuffer;
    FPollResponsePending: Boolean;
    FPollCloseAfterDrain: Boolean;
    FPollQueuedOutbound: IH1OutboundBuffer;
    FPollQueuedResponsePending: Boolean;
    FPollQueuedCloseAfterDrain: Boolean;
    FPollWriteDeadline: TDeadline;
    procedure ResetPollRequestState;
    procedure PreparePollRequestParse;
    procedure ResetPollResponseState;
    procedure PromoteQueuedPollResponse;
    function EnqueuePollResponse(const AOutbound: IH1OutboundBuffer;
      const ACloseAfterDrain: Boolean): Boolean;
    function CanParseBufferedPollRequestWhileDraining: Boolean;
    function ShouldWaitForWritableInsteadOfEagerDrain(
      const AEvents: TPlatformPollEvents): Boolean;
    function QueuePollErrorResponse(const AStatus: THttpStatus): Boolean;
    procedure ApplyPollRequestResult(const AWork: TH1PollRequestWork);
    procedure ArmPollWriteDeadline;
    procedure ArmDirectWriteDeadline;
    function UsePollOwnedResponseDrain: Boolean;
    function ExecuteCurrentRequest: TTcpServerConnOwnership;
    function ExecuteCurrentPollRequest(out AOutbound: IH1OutboundBuffer;
      out ACloseAfterDrain: Boolean): TTcpServerConnOwnership;
    function AdvanceWholeRunBridge(const AEvents: TPlatformPollEvents;
      out ANextEvents: TPlatformPollEvents;
      out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
    function SubmitCurrentPollRequest(out ANextEvents: TPlatformPollEvents;
      out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
    function ContinueAfterPollCompletion(const AEvents: TPlatformPollEvents;
      out ANextEvents: TPlatformPollEvents;
      out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
    function AdvancePollResponseDrain(const AEvents: TPlatformPollEvents;
      out ANextEvents: TPlatformPollEvents;
      out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
    function AdvancePollRequestParse(const AEvents: TPlatformPollEvents;
      out ANextEvents: TPlatformPollEvents;
      out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
  public
    constructor Create(const AConn: ITcpStream; const AHandler: IHttpHandler;
      const AOptions: TH1ServerTransportOptions); overload;
    constructor Create(const AConn: ITcpStream; const AHandler: IHttpHandler;
      const AOptions: TH1ServerTransportOptions;
      const AContext: ITcpServerSessionContext); overload;
    function Run: TTcpServerConnOwnership;
    function PollEvents: TPlatformPollEvents;
    function Advance(const AEvents: TPlatformPollEvents;
      out ANextEvents: TPlatformPollEvents;
      out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
    function WakeDeadline: TDeadline;
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

function ParserErrorStatus(const AParser: IH1Parser): THttpStatus;
begin
  case AParser.ErrorKind of
    pekUnsupportedTransferCoding:
      Result := HTTP_STATUS_NOT_IMPLEMENTED;
  else
    Result := HTTP_STATUS_BAD_REQUEST;
  end;
end;

{ TPrefixedTcpStream }

constructor TPrefixedTcpStream.Create(const AInner: ITcpStream; const APrefix: string);
begin
  inherited Create;
  FInner := AInner;
  FPrefix := APrefix;
  FPrefixPos := 1;
end;

function TPrefixedTcpStream.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LPtr: PByte;
  LCopy: SizeUInt;
begin
  Result := 0;
  if ACount = 0 then
    Exit(0);

  LPtr := @ABuf;
  if (FPrefixPos > 0) and (FPrefixPos <= Length(FPrefix)) then
  begin
    LCopy := SizeUInt(Length(FPrefix) - FPrefixPos + 1);
    if LCopy > ACount then
      LCopy := ACount;
    Move(FPrefix[FPrefixPos], LPtr^, LCopy);
    Inc(FPrefixPos, SizeInt(LCopy));
    Inc(Result, LCopy);
    Inc(LPtr, LCopy);
    if FPrefixPos > Length(FPrefix) then
      FPrefix := '';
  end;

  if Result < ACount then
    Inc(Result, FInner.Read(LPtr^, ACount - Result));
end;

function TPrefixedTcpStream.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := FInner.Write(ABuf, ACount);
end;

function TPrefixedTcpStream.Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
begin
  Result := FInner.Seek(AOffset, AOrigin);
end;

procedure TPrefixedTcpStream.Close;
begin
  FInner.Close;
end;

function TPrefixedTcpStream.GetSize: Int64;
begin
  Result := FInner.Size;
end;

function TPrefixedTcpStream.GetPosition: Int64;
begin
  Result := FInner.Position;
end;

procedure TPrefixedTcpStream.SetPosition(const AValue: Int64);
begin
  FInner.Position := AValue;
end;

function TPrefixedTcpStream.LocalAddr: TNetAddress;
begin
  Result := FInner.LocalAddr;
end;

function TPrefixedTcpStream.RemoteAddr: TNetAddress;
begin
  Result := FInner.RemoteAddr;
end;

procedure TPrefixedTcpStream.Shutdown;
begin
  FInner.Shutdown;
end;

procedure TPrefixedTcpStream.SetNoDelay(const AValue: Boolean);
begin
  FInner.SetNoDelay(AValue);
end;

procedure TPrefixedTcpStream.SetKeepAlive(const AValue: Boolean);
begin
  FInner.SetKeepAlive(AValue);
end;

procedure TPrefixedTcpStream.SetReadDeadline(const ADeadline: TDeadline);
begin
  FInner.SetReadDeadline(ADeadline);
end;

procedure TPrefixedTcpStream.SetWriteDeadline(const ADeadline: TDeadline);
begin
  FInner.SetWriteDeadline(ADeadline);
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
    { Ignore secondary write failures while sending an error response. }
  end;
end;

procedure WriteErrorResponseToWriter(const AWriter: IWriter;
  const AStatus: THttpStatus);
var
  LW: IHttpResponseWriter;
  LBody: string;
begin
  LW := TH1ResponseWriter.Create(AWriter);
  LBody := HttpStatusText(AStatus);
  LW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LBody))));
  LW.GetHeaders.Set_('connection', 'close');
  LW.WriteHeader(AStatus);
  if Length(LBody) > 0 then
    LW.Write(LBody[1], SizeUInt(Length(LBody)));
end;

{ TH1PollRunWork }

constructor TH1PollRunWork.Create(const AState: TH1ServerConnectionState);
begin
  inherited Create;
  FState := AState;
end;

function TH1PollRunWork.Execute: TTcpServerConnOwnership;
begin
  Result := FState.Run;
end;

{ TH1PollRequestWork }

constructor TH1PollRequestWork.Create(const AState: TH1ServerConnectionState);
begin
  inherited Create;
  FState := AState;
end;

function TH1PollRequestWork.Execute: TTcpServerConnOwnership;
begin
  if FState.UsePollOwnedResponseDrain then
    Result := FState.ExecuteCurrentPollRequest(FOutbound, FCloseAfterDrain)
  else
    Result := FState.ExecuteCurrentRequest;
end;

{ TH1PollRunCompletion }

constructor TH1PollRunCompletion.Create(const AState: TH1ServerConnectionState);
begin
  inherited Create;
  FState := AState;
end;

procedure TH1PollRunCompletion.Complete(const AOutcome: TTcpServerWorkOutcome;
  const AOwnership: TTcpServerConnOwnership);
begin
  if FState <> nil then
  begin
    if AOutcome = tswoCompleted then
      FState.FPollCompletionOwnership := AOwnership
    else
    begin
      FState.FPollCompletionOwnership := tscoServer;
      FState.FKeepAlive := False;
    end;
    FState.FPollCompletionReady := True;
  end;
  FState := nil;
end;

{ TH1PollRequestCompletion }

constructor TH1PollRequestCompletion.Create(const AState: TH1ServerConnectionState;
  const AWork: TH1PollRequestWork);
begin
  inherited Create;
  FState := AState;
  FWorkRef := AWork as ITcpServerWork;
  FWork := AWork;
end;

procedure TH1PollRequestCompletion.Complete(
  const AOutcome: TTcpServerWorkOutcome;
  const AOwnership: TTcpServerConnOwnership);
begin
  if FState <> nil then
  begin
    if AOutcome = tswoCompleted then
    begin
      if AOwnership = tscoServer then
        FState.ApplyPollRequestResult(FWork);
      FState.FPollCompletionOwnership := AOwnership;
    end
    else
    begin
      FState.FPollCompletionOwnership := tscoServer;
      FState.FKeepAlive := False;
    end;
    FState.FPollCompletionReady := True;
  end;
  FWorkRef := nil;
  FWork := nil;
  FState := nil;
end;

{ TH1ServerConnectionState }

constructor TH1ServerConnectionState.Create(const AConn: ITcpStream;
  const AHandler: IHttpHandler; const AOptions: TH1ServerTransportOptions);
begin
  Create(AConn, AHandler, AOptions, nil);
end;

constructor TH1ServerConnectionState.Create(const AConn: ITcpStream;
  const AHandler: IHttpHandler; const AOptions: TH1ServerTransportOptions;
  const AContext: ITcpServerSessionContext);
begin
  inherited Create;
  FOptions := AOptions;
  FConn := AConn;
  FHandler := AHandler;
  FSessionContext := AContext;
  Supports(AConn, ITcpSocketRuntime, FSocketRuntime);
  Supports(AConn, ITcpStreamRuntime, FStreamRuntime);
  if AContext <> nil then
    FWorkerHandoff := AContext.WorkerHandoff
  else
    FWorkerHandoff := nil;
  FParser := NewH1RequestParser;
  FPending := '';
  FKeepAlive := True;
  if FOptions.IdleTimeout > 0 then
    FIdleMs := FOptions.IdleTimeout
  else
    FIdleMs := 30000;
  FPollSubmitted := False;
  FPollWorkerPending := False;
  FPollCompletionReady := False;
  FPollCompletionOwnership := tscoServer;
  FPollNeedRequestReset := False;
  FParseTotalRead := 0;
  FParseHeadersDone := False;
  FPollOutbound := nil;
  FPollResponsePending := False;
  FPollCloseAfterDrain := False;
  FPollQueuedOutbound := nil;
  FPollQueuedResponsePending := False;
  FPollQueuedCloseAfterDrain := False;
  FPollWriteDeadline := TDeadline.Infinite;
end;

procedure TH1ServerConnectionState.ResetPollRequestState;
begin
  FParser.Reset;
  FParseTotalRead := 0;
  FParseHeadersDone := False;
  FPollNeedRequestReset := False;
end;

procedure TH1ServerConnectionState.PreparePollRequestParse;
begin
  if FPollNeedRequestReset then
    ResetPollRequestState;
end;

procedure TH1ServerConnectionState.ResetPollResponseState;
begin
  FPollOutbound := nil;
  FPollResponsePending := False;
  FPollCloseAfterDrain := False;
  FPollQueuedOutbound := nil;
  FPollQueuedResponsePending := False;
  FPollQueuedCloseAfterDrain := False;
  FPollWriteDeadline := TDeadline.Infinite;
end;

procedure TH1ServerConnectionState.PromoteQueuedPollResponse;
begin
  if not FPollQueuedResponsePending then
    Exit;

  FPollOutbound := FPollQueuedOutbound;
  FPollResponsePending := (FPollOutbound <> nil) and (not FPollOutbound.IsEmpty);
  FPollCloseAfterDrain := FPollQueuedCloseAfterDrain;
  FPollQueuedOutbound := nil;
  FPollQueuedResponsePending := False;
  FPollQueuedCloseAfterDrain := False;
  FPollWriteDeadline := TDeadline.Infinite;
end;

function TH1ServerConnectionState.EnqueuePollResponse(
  const AOutbound: IH1OutboundBuffer; const ACloseAfterDrain: Boolean): Boolean;
begin
  if (AOutbound = nil) or AOutbound.IsEmpty then
    Exit(True);

  if not FPollResponsePending then
  begin
    FPollOutbound := AOutbound;
    FPollResponsePending := True;
    FPollCloseAfterDrain := ACloseAfterDrain;
    Exit(True);
  end;

  if not FPollQueuedResponsePending then
  begin
    FPollQueuedOutbound := AOutbound;
    FPollQueuedResponsePending := True;
    FPollQueuedCloseAfterDrain := ACloseAfterDrain;
    Exit(True);
  end;

  Result := False;
end;

function TH1ServerConnectionState.CanParseBufferedPollRequestWhileDraining: Boolean;
begin
  Result := (FOptions.WriteTimeout <= 0) and FKeepAlive and (FPending <> '') and
    FPollResponsePending and
    (not FPollCloseAfterDrain) and (not FPollQueuedResponsePending);
end;

function TH1ServerConnectionState.ShouldWaitForWritableInsteadOfEagerDrain(
  const AEvents: TPlatformPollEvents): Boolean;
begin
  Result := (FPending <> '') and FPollResponsePending and
    FPollQueuedResponsePending and (not (peWritable in AEvents));
end;

function TH1ServerConnectionState.QueuePollErrorResponse(
  const AStatus: THttpStatus): Boolean;
var
  LOutbound: IH1OutboundBuffer;
begin
  LOutbound := NewH1OutboundBuffer;
  WriteErrorResponseToWriter(LOutbound as IWriter, AStatus);
  Result := EnqueuePollResponse(LOutbound, True);
end;

procedure TH1ServerConnectionState.ApplyPollRequestResult(
  const AWork: TH1PollRequestWork);
begin
  if (AWork = nil) then
    Exit;

  if not EnqueuePollResponse(AWork.Outbound, AWork.CloseAfterDrain) then
    FKeepAlive := False;
end;

procedure TH1ServerConnectionState.ArmPollWriteDeadline;
begin
  if FOptions.WriteTimeout > 0 then
  begin
    FPollWriteDeadline := TDeadline.After(
      TDuration.FromMilliseconds(FOptions.WriteTimeout));
    FConn.SetWriteDeadline(FPollWriteDeadline);
  end
  else
    FPollWriteDeadline := TDeadline.Infinite;
end;

procedure TH1ServerConnectionState.ArmDirectWriteDeadline;
begin
  if FOptions.WriteTimeout > 0 then
    FConn.SetWriteDeadline(TDeadline.After(
      TDuration.FromMilliseconds(FOptions.WriteTimeout)));
end;

function TH1ServerConnectionState.UsePollOwnedResponseDrain: Boolean;
begin
  Result := FStreamRuntime <> nil;
end;

function TH1ServerConnectionState.ExecuteCurrentRequest: TTcpServerConnOwnership;
var
  LUrl: TUrl;
  LReq: IHttpRequest;
  LW: IHttpResponseWriter;
  LBodyReader: IReader;
  LContentLen: Int64;
  LHijackConn: ITcpStream;
  LOutbound: IH1OutboundBuffer;
  LResponseWriter: IWriter;
  LFlusher: IFlusher;
  LDrainStarted: Boolean;
begin
  Result := tscoServer;
  LW := nil;
  LOutbound := nil;
  LResponseWriter := nil;
  LDrainStarted := False;
  try
    FKeepAlive := ShouldKeepAlive(FParser);

    if (FParser.GetHttpVersion = hvHttp11) and
       (FParser.GetHeaders.Get('host') = '') then
    begin
      WriteErrorResponse(FConn, HTTP_STATUS_BAD_REQUEST);
      FKeepAlive := False;
      Exit(tscoServer);
    end;

    LUrl := TUrl.Parse(FParser.GetUrl);
    LContentLen := FParser.GetBodySize;
    LBodyReader := FParser.NewBodyReader;
    if LBodyReader <> nil then
    begin
      LReq := THttpRequest.Create(FParser.GetMethod, LUrl,
        FParser.GetHttpVersion, FParser.GetHeaders, LBodyReader, LContentLen);
    end
    else
    begin
      LContentLen := 0;
      LReq := THttpRequest.Create(FParser.GetMethod, LUrl,
        FParser.GetHttpVersion, FParser.GetHeaders, nil, LContentLen);
    end;

    (LReq as THttpRequest).SetRemoteAddr(FConn.RemoteAddr.ToString);

    if FPending <> '' then
      LHijackConn := TPrefixedTcpStream.Create(FConn, FPending)
    else
      LHijackConn := FConn;
    LOutbound := NewH1OutboundBuffer;
    LResponseWriter := CreateBufferedWriter(LOutbound as IWriter, 4096);
    LW := TH1ResponseWriter.Create(LResponseWriter, LHijackConn,
      LReq.Method = hmHead);
    if FKeepAlive and (FParser.GetHttpVersion = hvHttp10) then
      LW.GetHeaders.Set_('connection', 'keep-alive');
    if not FKeepAlive then
      LW.GetHeaders.Set_('connection', 'close');

    FHandler.ServeHTTP(LReq, LW);

    if (LW as TH1ResponseWriter).IsHijacked then
    begin
      Result := tscoHandler;
      FKeepAlive := False;
      Exit;
    end;

    LW.Flush;
    if Supports(LResponseWriter, IFlusher, LFlusher) then
      LFlusher.Flush;
    LDrainStarted := True;
    ArmDirectWriteDeadline;
    LOutbound.DrainAllTo(FConn as IWriter);

    if LW.GetHeaders.Get('connection') = 'close' then
      FKeepAlive := False;
  except
    on E: Exception do
    begin
      if (LW <> nil) and (LW as TH1ResponseWriter).IsHijacked then
        Result := tscoHandler
      else if (LW = nil) or (not (LW as TH1ResponseWriter).HasCommitted) then
        WriteErrorResponse(FConn, HTTP_STATUS_INTERNAL_SERVER_ERROR);
      if (LW <> nil) and (not (LW as TH1ResponseWriter).IsHijacked) and
         (LW as TH1ResponseWriter).HasCommitted and (not LDrainStarted) then
      begin
        try
          if Supports(LResponseWriter, IFlusher, LFlusher) then
            LFlusher.Flush;
          if (LOutbound <> nil) and (not LOutbound.IsEmpty) then
          begin
            ArmDirectWriteDeadline;
            LOutbound.DrainAllTo(FConn as IWriter);
          end;
        except
        end;
      end;
      FKeepAlive := False;
    end;
  end;
end;

function TH1ServerConnectionState.ExecuteCurrentPollRequest(
  out AOutbound: IH1OutboundBuffer; out ACloseAfterDrain: Boolean): TTcpServerConnOwnership;
var
  LUrl: TUrl;
  LReq: IHttpRequest;
  LW: IHttpResponseWriter;
  LBodyReader: IReader;
  LContentLen: Int64;
  LHijackConn: ITcpStream;
  LOutbound: IH1OutboundBuffer;
  LResponseWriter: IWriter;
  LFlusher: IFlusher;
  LKeepAlive: Boolean;
begin
  Result := tscoServer;
  AOutbound := nil;
  ACloseAfterDrain := False;
  LW := nil;
  LOutbound := nil;
  LResponseWriter := nil;
  try
    LKeepAlive := ShouldKeepAlive(FParser);

    if (FParser.GetHttpVersion = hvHttp11) and
       (FParser.GetHeaders.Get('host') = '') then
    begin
      LOutbound := NewH1OutboundBuffer;
      WriteErrorResponseToWriter(LOutbound as IWriter, HTTP_STATUS_BAD_REQUEST);
      AOutbound := LOutbound;
      ACloseAfterDrain := True;
      Exit(tscoServer);
    end;

    LUrl := TUrl.Parse(FParser.GetUrl);
    LContentLen := FParser.GetBodySize;
    LBodyReader := FParser.NewBodyReader;
    if LBodyReader <> nil then
    begin
      LReq := THttpRequest.Create(FParser.GetMethod, LUrl,
        FParser.GetHttpVersion, FParser.GetHeaders, LBodyReader, LContentLen);
    end
    else
    begin
      LContentLen := 0;
      LReq := THttpRequest.Create(FParser.GetMethod, LUrl,
        FParser.GetHttpVersion, FParser.GetHeaders, nil, LContentLen);
    end;

    (LReq as THttpRequest).SetRemoteAddr(FConn.RemoteAddr.ToString);

    if FPending <> '' then
      LHijackConn := TPrefixedTcpStream.Create(FConn, FPending)
    else
      LHijackConn := FConn;
    LOutbound := NewH1OutboundBuffer;
    LResponseWriter := CreateBufferedWriter(LOutbound as IWriter, 4096);
    LW := TH1ResponseWriter.Create(LResponseWriter, LHijackConn,
      LReq.Method = hmHead);
    if LKeepAlive and (FParser.GetHttpVersion = hvHttp10) then
      LW.GetHeaders.Set_('connection', 'keep-alive');
    if not LKeepAlive then
      LW.GetHeaders.Set_('connection', 'close');

    FHandler.ServeHTTP(LReq, LW);

    if (LW as TH1ResponseWriter).IsHijacked then
    begin
      Result := tscoHandler;
      FKeepAlive := False;
      Exit;
    end;

    LW.Flush;
    if Supports(LResponseWriter, IFlusher, LFlusher) then
      LFlusher.Flush;

    if LW.GetHeaders.Get('connection') = 'close' then
      LKeepAlive := False;
    AOutbound := LOutbound;
    ACloseAfterDrain := not LKeepAlive;
  except
    on E: Exception do
    begin
      if (LW <> nil) and (LW as TH1ResponseWriter).IsHijacked then
        Result := tscoHandler
      else if (LW = nil) or (not (LW as TH1ResponseWriter).HasCommitted) then
      begin
        if LOutbound = nil then
        begin
          LOutbound := NewH1OutboundBuffer;
          LResponseWriter := CreateBufferedWriter(LOutbound as IWriter, 4096);
        end;
        try
          WriteErrorResponseToWriter(LOutbound as IWriter,
            HTTP_STATUS_INTERNAL_SERVER_ERROR);
          AOutbound := LOutbound;
          ACloseAfterDrain := True;
        except
          AOutbound := nil;
          ACloseAfterDrain := False;
        end;
      end
      else
      begin
        try
          if Supports(LResponseWriter, IFlusher, LFlusher) then
            LFlusher.Flush;
        except
        end;
        if (LOutbound <> nil) and (not LOutbound.IsEmpty) then
        begin
          AOutbound := LOutbound;
          ACloseAfterDrain := True;
        end
      end;
    end;
  end;
end;

function TH1ServerConnectionState.Run: TTcpServerConnOwnership;
var
  LN: SizeUInt;
  LConsumed: SizeUInt;
  LTotalRead: SizeUInt;
  LHeadersDone: Boolean;
  LRejected: Boolean;
begin
  Result := tscoServer;
  while FKeepAlive do
  begin
    try
      FConn.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(FIdleMs)));

      FParser.Reset;
      LTotalRead := 0;
      LHeadersDone := False;
      LRejected := False;
      repeat
        if FPending <> '' then
        begin
          LN := SizeUInt(Length(FPending));
          LConsumed := FParser.Execute(PAnsiChar(FPending), LN);
          if LConsumed < LN then
            FPending := Copy(FPending, Int32(LConsumed) + 1, Int32(LN - LConsumed))
          else
            FPending := '';
        end
        else
        begin
          LN := FConn.Read(FBuf[0], 4096);
          if LN = 0 then
          begin
            FKeepAlive := False;
            if (LTotalRead > 0) and (not FParser.IsComplete) and
               (not FParser.HasError) then
              FParser.Finish;
            Break;
          end;
          LConsumed := FParser.Execute(@FBuf[0], LN);
          if LConsumed < LN then
          begin
            SetLength(FPending, Int32(LN - LConsumed));
            Move(FBuf[LConsumed], FPending[1], LN - LConsumed);
          end;
        end;
        Inc(LTotalRead, LConsumed);
        if (not LHeadersDone) and ((FParser.GetUrl <> '') or FParser.IsComplete) then
        begin
          LHeadersDone := True;
          if (FOptions.MaxHeaderSize > 0) and
             (Int64(LTotalRead) - FParser.GetBodySize >
              Int64(FOptions.MaxHeaderSize)) then
          begin
            WriteErrorResponse(FConn, HTTP_STATUS_HEADER_TOO_LARGE);
            LRejected := True;
            FKeepAlive := False;
            Break;
          end;
        end;
        if LHeadersDone and (FOptions.MaxHeaderSize > 0) and
           (FParser.GetTrailerBytes > Int64(FOptions.MaxHeaderSize)) then
        begin
          WriteErrorResponse(FConn, HTTP_STATUS_HEADER_TOO_LARGE);
          LRejected := True;
          FKeepAlive := False;
          Break;
        end;
        if (FOptions.MaxBodySize > 0) and
           (FParser.GetBodySize > FOptions.MaxBodySize) then
        begin
          WriteErrorResponse(FConn, HTTP_STATUS_PAYLOAD_TOO_LARGE);
          LRejected := True;
          FKeepAlive := False;
          Break;
        end;
      until FParser.IsComplete or FParser.HasError;

      if LRejected then
        Break;

      if FParser.HasError then
      begin
        WriteErrorResponse(FConn, ParserErrorStatus(FParser));
        Break;
      end;

      if not FParser.IsComplete then
        Break;

      if FOptions.MaxBodySize > 0 then
      begin
        if FParser.GetBodySize > FOptions.MaxBodySize then
        begin
          WriteErrorResponse(FConn, HTTP_STATUS_PAYLOAD_TOO_LARGE);
          FKeepAlive := False;
          Continue;
        end;
      end;

      Result := ExecuteCurrentRequest;
      if Result <> tscoServer then
        Continue;
      if not FKeepAlive then
        FKeepAlive := False;
    except
      on E: Exception do
      begin
        WriteErrorResponse(FConn, HTTP_STATUS_INTERNAL_SERVER_ERROR);
        FKeepAlive := False;
      end;
    end;
  end;
end;

function TH1ServerConnectionState.AdvanceWholeRunBridge(
  const AEvents: TPlatformPollEvents; out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
var
  LWork: ITcpServerWork;
  LCompletion: ITcpServerWorkCompletion;
  LHandoffResult: TTcpServerHandoffResult;
begin
  AOwnership := tscoServer;

  if not FPollSubmitted then
  begin
    if not (peReadable in AEvents) then
    begin
      ANextEvents := [peReadable];
      Exit(tsprWait);
    end;

    if FWorkerHandoff = nil then
    begin
      ANextEvents := [];
      AOwnership := Run;
      Exit(tsprDone);
    end;

    if FSocketRuntime <> nil then
      FSocketRuntime.SetBlocking(True);

    LWork := TH1PollRunWork.Create(Self);
    LCompletion := TH1PollRunCompletion.Create(Self);
    LHandoffResult := FWorkerHandoff.Submit(LWork, LCompletion);
    if LHandoffResult <> tshrAccepted then
    begin
      ANextEvents := [];
      Exit(tsprDone);
    end;

    FPollSubmitted := True;
    ANextEvents := [];
    Exit(tsprWait);
  end;

  if not FPollCompletionReady then
  begin
    ANextEvents := [];
    Exit(tsprWait);
  end;

  ANextEvents := [];
  AOwnership := FPollCompletionOwnership;
  Result := tsprDone;
end;

function TH1ServerConnectionState.SubmitCurrentPollRequest(
  out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
var
  LWorkRef: TH1PollRequestWork;
  LWork: ITcpServerWork;
  LCompletion: ITcpServerWorkCompletion;
  LHandoffResult: TTcpServerHandoffResult;
  LOutbound: IH1OutboundBuffer;
  LCloseAfterDrain: Boolean;
begin
  AOwnership := tscoServer;

  if FWorkerHandoff = nil then
  begin
    if FSocketRuntime <> nil then
      FSocketRuntime.SetBlocking(True);
    FPollNeedRequestReset := True;
    if UsePollOwnedResponseDrain then
      AOwnership := ExecuteCurrentPollRequest(LOutbound, LCloseAfterDrain)
    else
      AOwnership := ExecuteCurrentRequest;
    if AOwnership <> tscoServer then
    begin
      ANextEvents := [];
      Exit(tsprDone);
    end;
    if UsePollOwnedResponseDrain then
      EnqueuePollResponse(LOutbound, LCloseAfterDrain);
    if FSocketRuntime <> nil then
      FSocketRuntime.SetBlocking(False);
    if CanParseBufferedPollRequestWhileDraining then
    begin
      PreparePollRequestParse;
      Exit(AdvancePollRequestParse([], ANextEvents, AOwnership));
    end;
    if FPollResponsePending then
    begin
      if ShouldWaitForWritableInsteadOfEagerDrain([]) then
      begin
        ANextEvents := [peWritable];
        Exit(tsprWait);
      end;
      Exit(AdvancePollResponseDrain([], ANextEvents, AOwnership));
    end;
    if not FKeepAlive then
    begin
      ANextEvents := [];
      Exit(tsprDone);
    end;
    PreparePollRequestParse;
    Exit(AdvancePollRequestParse([], ANextEvents, AOwnership));
  end;

  if FSocketRuntime <> nil then
    FSocketRuntime.SetBlocking(True);

  FPollNeedRequestReset := True;
  FPollWorkerPending := True;
  FPollCompletionReady := False;
  LWorkRef := TH1PollRequestWork.Create(Self);
  LWork := LWorkRef;
  LCompletion := TH1PollRequestCompletion.Create(Self, LWorkRef);
  LHandoffResult := FWorkerHandoff.Submit(LWork, LCompletion);
  if LHandoffResult <> tshrAccepted then
  begin
    FPollWorkerPending := False;
    ANextEvents := [];
    Exit(tsprDone);
  end;

  ANextEvents := [];
  Result := tsprWait;
end;

function TH1ServerConnectionState.ContinueAfterPollCompletion(
  const AEvents: TPlatformPollEvents;
  out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
begin
  FPollWorkerPending := False;
  FPollCompletionReady := False;
  AOwnership := FPollCompletionOwnership;

  if AOwnership <> tscoServer then
  begin
    ANextEvents := [];
    Exit(tsprDone);
  end;

  if FSocketRuntime <> nil then
    FSocketRuntime.SetBlocking(False);
  if CanParseBufferedPollRequestWhileDraining then
  begin
    PreparePollRequestParse;
    Exit(AdvancePollRequestParse([], ANextEvents, AOwnership));
  end;
  if FPollResponsePending then
  begin
    if ShouldWaitForWritableInsteadOfEagerDrain(AEvents) then
    begin
      ANextEvents := [peWritable];
      Exit(tsprWait);
    end;
    Exit(AdvancePollResponseDrain(AEvents, ANextEvents, AOwnership));
  end;
  if not FKeepAlive then
  begin
    ANextEvents := [];
    Exit(tsprDone);
  end;
  PreparePollRequestParse;
  Result := AdvancePollRequestParse([], ANextEvents, AOwnership);
end;

function TH1ServerConnectionState.AdvancePollResponseDrain(
  const AEvents: TPlatformPollEvents; out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
var
  LWritten: SizeUInt;
  LWriteResult: TTcpStreamIOResult;
  LCloseAfterDrain: Boolean;
begin
  AOwnership := tscoServer;

  if (not FPollResponsePending) or (FPollOutbound = nil) or FPollOutbound.IsEmpty then
  begin
    PromoteQueuedPollResponse;
    if (not FPollResponsePending) or (FPollOutbound = nil) or FPollOutbound.IsEmpty then
      ResetPollResponseState;
    if not FKeepAlive then
    begin
      ANextEvents := [];
      Exit(tsprDone);
    end;
    PreparePollRequestParse;
    Exit(AdvancePollRequestParse(AEvents, ANextEvents, AOwnership));
  end;

  if (not FPollWriteDeadline.IsInfinite) and FPollWriteDeadline.IsExpired then
  begin
    ResetPollResponseState;
    FKeepAlive := False;
    ANextEvents := [];
    Exit(tsprDone);
  end;

  if FPollWriteDeadline.IsInfinite then
    ArmPollWriteDeadline;

  LWriteResult := FPollOutbound.TryDrainTo(FStreamRuntime, LWritten);
  case LWriteResult of
    tsiorOk:
      begin
        if FPollOutbound.IsEmpty then
        begin
          LCloseAfterDrain := FPollCloseAfterDrain;
          FPollOutbound := nil;
          FPollResponsePending := False;
          FPollCloseAfterDrain := False;
          FPollWriteDeadline := TDeadline.Infinite;
          if LCloseAfterDrain then
          begin
            ANextEvents := [];
            Exit(tsprDone);
          end;
          if FPollQueuedResponsePending then
          begin
            PromoteQueuedPollResponse;
            if (FPending <> '') and (not FPollCloseAfterDrain) then
            begin
              ANextEvents := [peWritable];
              Exit(tsprWait);
            end;
            Exit(AdvancePollResponseDrain(AEvents, ANextEvents, AOwnership));
          end;
          if not FKeepAlive then
          begin
            ANextEvents := [];
            Exit(tsprDone);
          end;
          PreparePollRequestParse;
          Exit(AdvancePollRequestParse([], ANextEvents, AOwnership));
        end;
        if LWritten > 0 then
          ArmPollWriteDeadline;
        ANextEvents := [peWritable];
        Exit(tsprWait);
      end;
    tsiorWouldBlock:
      begin
        ANextEvents := [peWritable];
        Exit(tsprWait);
      end;
  else
    begin
      ResetPollResponseState;
      FKeepAlive := False;
      ANextEvents := [];
      Exit(tsprDone);
    end;
  end;
end;

function TH1ServerConnectionState.AdvancePollRequestParse(
  const AEvents: TPlatformPollEvents; out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
var
  LN: SizeUInt;
  LConsumed: SizeUInt;
  LReadResult: TTcpStreamIOResult;
begin
  AOwnership := tscoServer;

  while True do
  begin
    if FPending <> '' then
    begin
      LN := SizeUInt(Length(FPending));
      LConsumed := FParser.Execute(PAnsiChar(FPending), LN);
      if LConsumed < LN then
        FPending := Copy(FPending, Int32(LConsumed) + 1, Int32(LN - LConsumed))
      else
        FPending := '';
    end
    else
    begin
      if FStreamRuntime = nil then
        Exit(AdvanceWholeRunBridge(AEvents, ANextEvents, AOwnership));
      if not (peReadable in AEvents) then
      begin
        if FPollResponsePending then
          Exit(AdvancePollResponseDrain(AEvents, ANextEvents, AOwnership));
        ANextEvents := [peReadable];
        Exit(tsprWait);
      end;

      LReadResult := FStreamRuntime.TryRead(FBuf[0], SizeUInt(SizeOf(FBuf)), LN);
      case LReadResult of
        tsiorWouldBlock:
          begin
            ANextEvents := [peReadable];
            Exit(tsprWait);
          end;
        tsiorClosed:
          begin
            FKeepAlive := False;
            if (FParseTotalRead > 0) and (not FParser.IsComplete) and
               (not FParser.HasError) then
              FParser.Finish;
            if FParser.HasError then
            begin
              if FPollResponsePending and
                 QueuePollErrorResponse(ParserErrorStatus(FParser)) then
              begin
                FKeepAlive := False;
                Exit(AdvancePollResponseDrain(AEvents, ANextEvents, AOwnership));
              end;
              WriteErrorResponse(FConn, ParserErrorStatus(FParser));
              ANextEvents := [];
              Exit(tsprDone);
            end;
            ANextEvents := [];
            Exit(tsprDone);
          end;
      else
        begin
          LConsumed := FParser.Execute(@FBuf[0], LN);
          if LConsumed < LN then
          begin
            SetLength(FPending, Int32(LN - LConsumed));
            Move(FBuf[LConsumed], FPending[1], LN - LConsumed);
          end;
        end;
      end;
    end;

    Inc(FParseTotalRead, LConsumed);
    if (not FParseHeadersDone) and ((FParser.GetUrl <> '') or FParser.IsComplete) then
    begin
      FParseHeadersDone := True;
      if (FOptions.MaxHeaderSize > 0) and
         (Int64(FParseTotalRead) - FParser.GetBodySize >
          Int64(FOptions.MaxHeaderSize)) then
      begin
        if FPollResponsePending and
           QueuePollErrorResponse(HTTP_STATUS_HEADER_TOO_LARGE) then
        begin
          FKeepAlive := False;
          Exit(AdvancePollResponseDrain(AEvents, ANextEvents, AOwnership));
        end;
        WriteErrorResponse(FConn, HTTP_STATUS_HEADER_TOO_LARGE);
        FKeepAlive := False;
        ANextEvents := [];
        Exit(tsprDone);
      end;
    end;

    if FParseHeadersDone and (FOptions.MaxHeaderSize > 0) and
       (FParser.GetTrailerBytes > Int64(FOptions.MaxHeaderSize)) then
    begin
      if FPollResponsePending and
         QueuePollErrorResponse(HTTP_STATUS_HEADER_TOO_LARGE) then
      begin
        FKeepAlive := False;
        Exit(AdvancePollResponseDrain(AEvents, ANextEvents, AOwnership));
      end;
      WriteErrorResponse(FConn, HTTP_STATUS_HEADER_TOO_LARGE);
      FKeepAlive := False;
      ANextEvents := [];
      Exit(tsprDone);
    end;

    if (FOptions.MaxBodySize > 0) and
       (FParser.GetBodySize > FOptions.MaxBodySize) then
    begin
      if FPollResponsePending and
         QueuePollErrorResponse(HTTP_STATUS_PAYLOAD_TOO_LARGE) then
      begin
        FKeepAlive := False;
        Exit(AdvancePollResponseDrain(AEvents, ANextEvents, AOwnership));
      end;
      WriteErrorResponse(FConn, HTTP_STATUS_PAYLOAD_TOO_LARGE);
      FKeepAlive := False;
      ANextEvents := [];
      Exit(tsprDone);
    end;

    if FParser.HasError then
    begin
      if FPollResponsePending and
         QueuePollErrorResponse(ParserErrorStatus(FParser)) then
      begin
        FKeepAlive := False;
        Exit(AdvancePollResponseDrain(AEvents, ANextEvents, AOwnership));
      end;
      WriteErrorResponse(FConn, ParserErrorStatus(FParser));
      FKeepAlive := False;
      ANextEvents := [];
      Exit(tsprDone);
    end;

    if FParser.IsComplete then
      Exit(SubmitCurrentPollRequest(ANextEvents, AOwnership));
  end;
end;

function TH1ServerConnectionState.PollEvents: TPlatformPollEvents;
begin
  Result := [peReadable];
end;

function TH1ServerConnectionState.Advance(const AEvents: TPlatformPollEvents;
  out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
begin
  AOwnership := tscoServer;

  if FStreamRuntime = nil then
    Exit(AdvanceWholeRunBridge(AEvents, ANextEvents, AOwnership));

  if FPollWorkerPending then
  begin
    if not FPollCompletionReady then
    begin
      ANextEvents := [];
      Exit(tsprWait);
    end;
    Exit(ContinueAfterPollCompletion(AEvents, ANextEvents, AOwnership));
  end;

  if CanParseBufferedPollRequestWhileDraining then
  begin
    PreparePollRequestParse;
    Exit(AdvancePollRequestParse([], ANextEvents, AOwnership));
  end;
  if FPollResponsePending then
  begin
    if ShouldWaitForWritableInsteadOfEagerDrain(AEvents) then
    begin
      ANextEvents := [peWritable];
      Exit(tsprWait);
    end;
    Exit(AdvancePollResponseDrain(AEvents, ANextEvents, AOwnership));
  end;

  Result := AdvancePollRequestParse(AEvents, ANextEvents, AOwnership);
end;

function TH1ServerConnectionState.WakeDeadline: TDeadline;
begin
  Result := FPollWriteDeadline;
end;

{ TH1ClientTransport }

constructor TH1ClientTransport.Create(const AOptions: TH1ClientTransportOptions);
begin
  inherited Create;
  FOptions := AOptions;
  FPoolCount := 0;
end;

function TH1ClientTransport.PoolGet(const AHost: string; const APort: UInt16): ITcpStream;
var
  LI: Int32;
begin
  Result := nil;
  for LI := 0 to FPoolCount - 1 do
    if (FPool[LI].Host = AHost) and (FPool[LI].Port = APort) then
    begin
      Result := FPool[LI].Conn;
      FPool[LI] := FPool[FPoolCount - 1];
      Dec(FPoolCount);
      Exit;
    end;
end;

procedure TH1ClientTransport.PoolPut(const AHost: string; const APort: UInt16;
  const AConn: ITcpStream);
begin
  if FPoolCount >= Length(FPool) then
    SetLength(FPool, FPoolCount + 4);
  FPool[FPoolCount].Host := AHost;
  FPool[FPoolCount].Port := APort;
  FPool[FPoolCount].Conn := AConn;
  Inc(FPoolCount);
end;

function TH1ClientTransport.WriteRequest(const AWriter: IWriter;
  const AReq: IHttpRequest): Boolean;
const
  CRLF: array[0..1] of Byte = (13, 10);
var
  LPath: string;
  LBuf: IWriter;
  LFlusher: IFlusher;
  LN: SizeUInt;
  LTmp: array[0..4095] of Byte;
  LStr: string;
begin
  Result := True;
  if not (AReq.Version in [hvHttp10, hvHttp11]) then
    raise EHttpError.Create('h1 transport only supports HTTP/1.x requests');

  LBuf := CreateBufferedWriter(AWriter, 4096);

  LStr := HttpMethodToStr(AReq.Method);
  LBuf.Write(LStr[1], SizeUInt(Length(LStr)));
  LBuf.Write(PAnsiChar(' ')^, 1);

  LPath := AReq.Url.Path;
  if LPath = '' then
    LPath := '/';
  if AReq.Url.RawQuery <> '' then
    LPath := LPath + '?' + AReq.Url.RawQuery;
  LBuf.Write(LPath[1], SizeUInt(Length(LPath)));

  LStr := ' ' + HttpVersionToStr(AReq.Version);
  LBuf.Write(LStr[1], SizeUInt(Length(LStr)));
  LBuf.Write(CRLF[0], 2);

  AReq.Headers.ForEach(procedure(const AName, AValue: string)
  var
    LHeader: string;
  begin
    LHeader := AName + ': ' + AValue;
    LBuf.Write(LHeader[1], SizeUInt(Length(LHeader)));
    LBuf.Write(CRLF[0], 2);
  end);

  LBuf.Write(CRLF[0], 2);

  if AReq.Body <> nil then
  begin
    repeat
      LN := AReq.Body.Read(LTmp[0], 4096);
      if LN > 0 then
        LBuf.Write(LTmp[0], LN);
    until LN = 0;
  end;

  if Supports(LBuf, IFlusher, LFlusher) then
    LFlusher.Flush;
end;

function TH1ClientTransport.ReadResponse(const AReader: IReader;
  const ARequestMethod: THttpMethod; out AKeepAlive: Boolean): IHttpResponse;
var
  LParser: IH1Parser;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LBodyReader: IReader;
begin
  LParser := NewH1ResponseParser(ARequestMethod = hmHead);
  repeat
    LN := AReader.Read(LBuf[0], 4096);
    if LN = 0 then
      Break;
    LParser.Execute(@LBuf[0], LN);
  until LParser.IsComplete or LParser.HasError;

  if (not LParser.IsComplete) and (not LParser.HasError) then
    LParser.Finish;

  if LParser.HasError then
    raise EHttpError.Create('HTTP parse error: ' + LParser.ErrorMessage);
  if not LParser.IsComplete then
    raise EHttpError.Create('HTTP response incomplete: connection closed');

  AKeepAlive := LParser.ShouldKeepAlive;

  LBodyReader := LParser.NewBodyReader;
  if LBodyReader <> nil then
  begin
    Result := THttpResponse.Create(LParser.GetStatusCode, LParser.GetHeaders,
      LBodyReader);
  end
  else
    Result := THttpResponse.Create(LParser.GetStatusCode, LParser.GetHeaders, nil);
end;

function TH1ClientTransport.RoundTrip(const AReq: IHttpRequest): IHttpResponse;
var
  LUrl: TUrl;
  LHost: string;
  LPort: UInt16;
  LConn: ITcpStream;
  LResp: IHttpResponse;
  LPooled: Boolean;
  LKeepAlive: Boolean;
begin
  LUrl := AReq.Url;
  LHost := LUrl.Host;
  LPort := LUrl.Port;
  if LPort = 0 then
  begin
    if LUrl.Scheme = 'https' then
      LPort := 443
    else
      LPort := 80;
  end;

  LConn := PoolGet(LHost, LPort);
  LPooled := LConn <> nil;
  if not LPooled then
    LConn := TcpConnect(LHost, LPort);

  if FOptions.Timeout > 0 then
  begin
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(FOptions.Timeout)));
    LConn.SetWriteDeadline(TDeadline.After(TDuration.FromMilliseconds(FOptions.Timeout)));
  end;

  if not AReq.Headers.Has('host') then
    AReq.Headers.Set_('host', LUrl.HostPort);

  try
    WriteRequest(LConn as IWriter, AReq);
    LResp := ReadResponse(LConn as IReader, AReq.Method, LKeepAlive);
  except
    if LPooled then
    begin
      LConn.Close;
      LConn := TcpConnect(LHost, LPort);
      if FOptions.Timeout > 0 then
      begin
        LConn.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(FOptions.Timeout)));
        LConn.SetWriteDeadline(TDeadline.After(TDuration.FromMilliseconds(FOptions.Timeout)));
      end;
      WriteRequest(LConn as IWriter, AReq);
      LResp := ReadResponse(LConn as IReader, AReq.Method, LKeepAlive);
    end
    else
    begin
      LConn.Close;
      raise;
    end;
  end;

  if LKeepAlive then
    PoolPut(LHost, LPort, LConn)
  else
    LConn.Close;

  Result := LResp;
end;

{ TH1ServerTransport }

constructor TH1ServerTransport.Create(const AOptions: TH1ServerTransportOptions);
begin
  inherited Create;
  FOptions := AOptions;
end;

function TH1ServerTransport.HandleConnection(const AConn: ITcpStream;
  const AHandler: IHttpHandler): Boolean;
var
  LState: TH1ServerConnectionState;
begin
  LState := TH1ServerConnectionState.Create(AConn, AHandler, FOptions);
  try
    Result := LState.Run = tscoServer;
  finally
    LState.Free;
  end;
end;

function TH1ServerTransport.ServeConn(const AConn: ITcpStream;
  const AHandler: IHttpHandler): TTcpServerConnOwnership;
begin
  if HandleConnection(AConn, AHandler) then
    Result := tscoServer
  else
    Result := tscoHandler;
end;

function TH1ServerTransport.NewSession(const AConn: ITcpStream;
  const AHandler: IHttpHandler): ITcpServerSession;
begin
  Result := TH1ServerConnectionState.Create(AConn, AHandler, FOptions);
end;

function TH1ServerTransport.NewSession(const AConn: ITcpStream;
  const AHandler: IHttpHandler;
  const AContext: ITcpServerSessionContext): ITcpServerSession;
begin
  Result := TH1ServerConnectionState.Create(AConn, AHandler, FOptions, AContext);
end;

function NewH1ClientTransport(const AOptions: TH1ClientTransportOptions): IHttpTransport;
begin
  Result := TH1ClientTransport.Create(AOptions);
end;

function NewH1ServerTransport(const AOptions: TH1ServerTransportOptions): IHttpServerTransport;
begin
  Result := TH1ServerTransport.Create(AOptions);
end;

end.
