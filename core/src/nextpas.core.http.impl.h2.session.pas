unit nextpas.core.http.impl.h2.session;

{**
 * @desc HTTP/2 server-side session state machine:
 *       client preface validation, SETTINGS handshake, frame dispatch,
 *       per-stream request execution, response encoding, flow-control,
 *       and synchronous poll-driven execution.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf,
  nextpas.core.net.intf,
  nextpas.core.net.server.intf,
  nextpas.core.platform.io.base,
  nextpas.core.time.deadline,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.impl.h2.frame,
  nextpas.core.http.impl.h2.hpack,
  nextpas.core.http.impl.h2.stream,
  nextpas.core.http.impl.h2.types;

type
  TH2PrefaceStatus = (
    h2psNeedMore,
    h2psOk,
    h2psConnectionError
  );

  TH2SessionState = (
    h2sesExpectPreface,
    h2sesActive,
    h2sesShuttingDown,
    h2sesClosed
  );

  TH2StreamMap = class
  private
    FStreams: array of TH2Stream;
    FCount: SizeInt;
    function FindIndex(const AStreamID: UInt32): SizeInt;
    function ExtractByIndex(const AIndex: SizeInt): TH2Stream;
  public
    destructor Destroy; override;
    function Find(const AStreamID: UInt32): TH2Stream;
    function FindOrCreate(const AStreamID: UInt32;
      const ASendWindowSize: UInt32; const ARecvWindowSize: UInt32;
      var AConnectionFlow: TH2ConnectionFlowControl;
      var ADecoder: THPackDecoder;
      const AMaxHeaderListSize: UInt32 = H2_DEFAULT_MAX_HEADER_LIST_SIZE): TH2Stream;
    procedure RemoveByIndex(const AIndex: SizeInt);
    function FindAndRemove(const AStreamID: UInt32): TH2Stream;
    procedure Remove(const AStreamID: UInt32);
    function ActiveCount: SizeInt;
    function AnyPending: Boolean;
    procedure CloseAll(const AErrorCode: UInt32);
    procedure ApplyPeerInitialWindowSize(const ANewInitialWindowSize: UInt32);
    function ItemAt(const AIndex: SizeInt): TH2Stream;
  end;

  TH2ResponseWriter = class(TInterfacedObject, IHttpResponseWriter)
  private
    FStatus: THttpStatus;
    FHeaders: IHttpHeaders;
    FBody: IStream;
    FCommitted: Boolean;
  public
    constructor Create;
    procedure WriteHeader(const AStatus: THttpStatus);
    function GetStatus: THttpStatus;
    function GetHeaders: IHttpHeaders;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Flush;
    function BodyStream: IStream;
  end;

  TH2ServerSession = class(TInterfacedObject, ITcpServerSession,
    ITcpServerPollDrivenSession, ITcpServerPollDrivenSessionWithDeadline)
  private
    FConn: ITcpStream;
    FHandler: IHttpHandler;
    FOptions: TH2ServerTransportOptions;
    FState: TH2SessionState;
    FReadBuffer: AnsiString;
    FWriteBuffer: AnsiString;
    FStreams: TH2StreamMap;
    FRemoteSettings: TH2Settings;
    FLocalSettings: TH2Settings;
    FConnectionFlow: TH2ConnectionFlowControl;
    FDecoder: THPackDecoder;
    FEncoder: THPackEncoder;
    FPrefaceValidated: Boolean;
    FServerSettingsSent: Boolean;
    FPeerSettingsAcked: Boolean;
    FGoawayReceived: Boolean;
    FGoawaySent: Boolean;
    FLastSeenPeerStreamID: UInt32;
    FLastLocalStreamID: UInt32;
    FPeerGoawayLastLocalStreamID: UInt32;
    FPendingContinuationStreamID: UInt32;
    FShutdownErrorCode: UInt32;
    FReadDeadline: TDeadline;
    FWriteDeadline: TDeadline;
    function StreamBodyTooLarge(const AStream: TH2Stream): Boolean;
    procedure ArmReadDeadline(const ATimeoutMs: Int64);
    procedure ArmWriteDeadline(const ATimeoutMs: Int64);
    procedure ClearReadDeadline;
    procedure ClearWriteDeadline;
    procedure AppendWrite(const ABytes: AnsiString);
    procedure QueueFrame(const AFrameType: Byte; const AFlags: Byte;
      const AStreamID: UInt32; const APayload: AnsiString);
    procedure QueueSettingsFrame(const ASettings: TH2Settings);
    procedure QueueSettingsAck;
    procedure QueuePingAck(const AData: UInt64);
    procedure QueueWindowUpdate(const AStreamID: UInt32;
      const AIncrement: UInt32);
    procedure QueueRstStream(const AStreamID: UInt32;
      const AErrorCode: UInt32);
    procedure QueueGoaway(const ALastStreamID: UInt32;
      const AErrorCode: UInt32; const ADebugData: AnsiString = '');
    procedure EnsureServerHandshakeFramesQueued;
    procedure ApplyPendingWindowUpdates(const AStream: TH2Stream);
    procedure ApplyAllPendingWindowUpdates;
    function DrainWriteBuffer: Boolean;
    function FillReadBufferBlocking: Boolean;
    function FillReadBufferPoll(const AEvents: TPlatformPollEvents;
      out ANextEvents: TPlatformPollEvents): Boolean;
    function ProcessPreface: Boolean;
    function ProcessFrames: Boolean;
    function DecodeNextFrame(out AFrame: TH2Frame; out AConsumed: SizeUInt): Boolean;
    function HandleFrame(const AFrame: TH2Frame): Boolean;
    function HandleSettings(const AFrame: TH2Frame): Boolean;
    function HandleHeaders(const AFrame: TH2Frame): Boolean;
    function HandleContinuation(const AFrame: TH2Frame): Boolean;
    function HandleData(const AFrame: TH2Frame): Boolean;
    function HandleWindowUpdate(const AFrame: TH2Frame): Boolean;
    function HandleRstStream(const AFrame: TH2Frame): Boolean;
    function HandlePing(const AFrame: TH2Frame): Boolean;
    function HandleGoaway(const AFrame: TH2Frame): Boolean;
    function ClosedStreamDataLength(const AFrame: TH2Frame;
      out ADataLen: UInt32): Boolean;
    function ConsumeClosedStreamDataConnectionWindow(
      const AFrame: TH2Frame): Boolean;
    function RejectFrame(const AStreamID: UInt32; const AErrorCode: UInt32;
      const AConnectionLevel: Boolean): Boolean;
    function ParseSettingsPayload(const APayload: AnsiString;
      out ASettings: TH2Settings): Boolean;
    function ExtractPseudoHeader(const AHeaders: IHttpHeaders;
      const AName: string): string;
    function BuildRequestFromStream(const AStream: TH2Stream): IHttpRequest;
    procedure ExecuteReadyStreams;
    procedure ExecuteStreamRequest(const AStream: TH2Stream);
    procedure FlushPendingResponseBody(const AStream: TH2Stream);
    procedure EncodeResponse(const AStream: TH2Stream;
      const AWriter: TH2ResponseWriter);
    procedure SendResponseHeaders(const AStream: TH2Stream;
      const AStatus: THttpStatus; const AHeaders: IHttpHeaders;
      const AEndStream: Boolean);
    procedure SendResponseBody(const AStream: TH2Stream; const ABody: IStream;
      const AStatus: THttpStatus);
    procedure CloseStreamIfTerminal(const AStream: TH2Stream);
    procedure StartGracefulShutdown(const ALastStreamID: UInt32;
      const AErrorCode: UInt32);
    procedure CloseSession;
    procedure HandleRequestHeaderListTooLarge(const AStream: TH2Stream);
  public
    constructor Create(const AConn: ITcpStream; const AHandler: IHttpHandler;
      const AOptions: TH2ServerTransportOptions);
    destructor Destroy; override;
    function Run: TTcpServerConnOwnership;
    function PollEvents: TPlatformPollEvents;
    function Advance(const AEvents: TPlatformPollEvents;
      out ANextEvents: TPlatformPollEvents;
      out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
    function WakeDeadline: TDeadline;

    property State: TH2SessionState read FState;
  end;

function H2ValidateServerPreface(const ABuf: PAnsiChar; const ALen: SizeUInt;
  out AConsumed: SizeUInt; out AErrorCode: UInt32): TH2PrefaceStatus;

implementation

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.io.memory,
  nextpas.core.time.base,
  nextpas.core.http.headers,
  nextpas.core.http.message;

function H2PrefaceResult(const AStatus: TH2PrefaceStatus;
  const AConsumed: SizeUInt; const AErrorCode: UInt32; out AOutConsumed: SizeUInt;
  out AOutErrorCode: UInt32): TH2PrefaceStatus;
begin
  AOutConsumed := AConsumed;
  AOutErrorCode := AErrorCode;
  Result := AStatus;
end;

function H2PrefacePrefixMatches(const ABuf: PAnsiChar;
  const ALen: SizeUInt): Boolean;
var
  LI: SizeUInt;
begin
  if ALen = 0 then
    Exit(True);

  if ABuf = nil then
    Exit(False);

  for LI := 0 to ALen - 1 do
  begin
    if ABuf[LI] <> H2_CLIENT_PREFACE[LI + 1] then
      Exit(False);
  end;

  Result := True;
end;

function H2ValidateServerPreface(const ABuf: PAnsiChar; const ALen: SizeUInt;
  out AConsumed: SizeUInt; out AErrorCode: UInt32): TH2PrefaceStatus;
var
  LFrame: TH2Frame;
  LFrameBytes: SizeUInt;
  LFrameBuf: PAnsiChar;
  LFrameError: UInt32;
  LFrameLen: SizeUInt;
begin
  if ALen < SizeUInt(Length(H2_CLIENT_PREFACE)) then
  begin
    if H2PrefacePrefixMatches(ABuf, ALen) then
      Exit(H2PrefaceResult(h2psNeedMore, 0, H2_ERR_NO_ERROR, AConsumed,
        AErrorCode));

    Exit(H2PrefaceResult(h2psConnectionError, 0, H2_ERR_PROTOCOL_ERROR,
      AConsumed, AErrorCode));
  end;

  if not H2PrefacePrefixMatches(ABuf, Length(H2_CLIENT_PREFACE)) then
    Exit(H2PrefaceResult(h2psConnectionError, 0, H2_ERR_PROTOCOL_ERROR,
      AConsumed, AErrorCode));

  LFrameLen := ALen - Length(H2_CLIENT_PREFACE);
  if LFrameLen < H2_FRAME_HEADER_SIZE then
    Exit(H2PrefaceResult(h2psNeedMore, 0, H2_ERR_NO_ERROR, AConsumed,
      AErrorCode));

  LFrameBuf := @ABuf[Length(H2_CLIENT_PREFACE)];
  if not H2DecodeFrame(LFrameBuf, LFrameLen, LFrame, LFrameBytes) then
    Exit(H2PrefaceResult(h2psNeedMore, 0, H2_ERR_NO_ERROR, AConsumed,
      AErrorCode));

  if not H2ValidateFrame(LFrame, H2_DEFAULT_MAX_FRAME_SIZE, LFrameError) then
    Exit(H2PrefaceResult(h2psConnectionError, 0, LFrameError, AConsumed,
      AErrorCode));

  if LFrame.Header.FrameType <> H2_FRAME_SETTINGS then
    Exit(H2PrefaceResult(h2psConnectionError, 0, H2_ERR_PROTOCOL_ERROR,
      AConsumed, AErrorCode));

  if (LFrame.Header.Flags and H2_FLAG_SETTINGS_ACK) <> 0 then
    Exit(H2PrefaceResult(h2psConnectionError, 0, H2_ERR_PROTOCOL_ERROR,
      AConsumed, AErrorCode));

  Result := H2PrefaceResult(h2psOk,
    Length(H2_CLIENT_PREFACE) + LFrameBytes, H2_ERR_NO_ERROR, AConsumed,
    AErrorCode);
end;

function MinUInt32(const ALeft, ARight: UInt32): UInt32; inline;
begin
  if ALeft < ARight then
    Result := ALeft
  else
    Result := ARight;
end;

function AnsiToString(const AValue: AnsiString): string; inline;
begin
  Result := string(AValue);
end;

function StringToAnsi(const AValue: string): AnsiString; inline;
begin
  Result := AnsiString(AValue);
end;

function StatusHeaderValue(const AStatus: THttpStatus): string; inline;
begin
  Result := IntToStr(Int64(AStatus));
end;

function HttpMethodFromPseudo(const AValue: string): THttpMethod;
begin
  Result := HttpStrToMethod(AValue);
end;

function ResponseStatusMustNotHaveBody(const AStatus: THttpStatus): Boolean;
begin
  Result := HttpStatusIsInformational(AStatus) or
    (AStatus = HTTP_STATUS_NO_CONTENT) or
    (AStatus = HTTP_STATUS_NOT_MODIFIED);
end;

{ TH2ResponseWriter }

constructor TH2ResponseWriter.Create;
begin
  inherited Create;
  FStatus := HTTP_STATUS_OK;
  FHeaders := NewHttpHeaders;
  FBody := CreateBytesStream;
  FCommitted := False;
end;

procedure TH2ResponseWriter.WriteHeader(const AStatus: THttpStatus);
begin
  FStatus := AStatus;
  FCommitted := True;
end;

function TH2ResponseWriter.GetStatus: THttpStatus;
begin
  Result := FStatus;
end;

function TH2ResponseWriter.GetHeaders: IHttpHeaders;
begin
  Result := FHeaders;
end;

function TH2ResponseWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  if not FCommitted then
    WriteHeader(HTTP_STATUS_OK);
  Result := FBody.Write(ABuf, ACount);
end;

procedure TH2ResponseWriter.Flush;
begin
end;

function TH2ResponseWriter.BodyStream: IStream;
begin
  Result := FBody;
end;

{ TH2StreamMap }

destructor TH2StreamMap.Destroy;
begin
  CloseAll(H2_ERR_CANCEL);
  inherited Destroy;
end;

function TH2StreamMap.FindIndex(const AStreamID: UInt32): SizeInt;
var
  LI: SizeInt;
begin
  for LI := 0 to FCount - 1 do
    if FStreams[LI].StreamID = AStreamID then
      Exit(LI);
  Result := -1;
end;

function TH2StreamMap.ExtractByIndex(const AIndex: SizeInt): TH2Stream;
var
  LI: SizeInt;
begin
  if (AIndex < 0) or (AIndex >= FCount) then
    Exit(nil);
  Result := FStreams[AIndex];
  for LI := AIndex to FCount - 2 do
    FStreams[LI] := FStreams[LI + 1];
  Dec(FCount);
  FStreams[FCount] := nil;
end;

function TH2StreamMap.Find(const AStreamID: UInt32): TH2Stream;
var
  LIndex: SizeInt;
begin
  LIndex := FindIndex(AStreamID);
  if LIndex < 0 then
    Exit(nil);
  Result := FStreams[LIndex];
end;

function TH2StreamMap.FindOrCreate(const AStreamID: UInt32;
  const ASendWindowSize: UInt32; const ARecvWindowSize: UInt32;
  var AConnectionFlow: TH2ConnectionFlowControl;
  var ADecoder: THPackDecoder; const AMaxHeaderListSize: UInt32): TH2Stream;
var
  LIndex: SizeInt;
begin
  LIndex := FindIndex(AStreamID);
  if LIndex >= 0 then
    Exit(FStreams[LIndex]);
  if FCount >= Length(FStreams) then
    SetLength(FStreams, FCount + 8);
  FStreams[FCount] := TH2Stream.Create(AStreamID, ASendWindowSize,
    ARecvWindowSize, AConnectionFlow, ADecoder, AMaxHeaderListSize);
  Result := FStreams[FCount];
  Inc(FCount);
end;

procedure TH2StreamMap.RemoveByIndex(const AIndex: SizeInt);
var
  LStream: TH2Stream;
begin
  LStream := ExtractByIndex(AIndex);
  if LStream <> nil then
    LStream.Free;
end;

function TH2StreamMap.FindAndRemove(const AStreamID: UInt32): TH2Stream;
var
  LIndex: SizeInt;
begin
  LIndex := FindIndex(AStreamID);
  if LIndex < 0 then
    Exit(nil);
  Result := ExtractByIndex(LIndex);
end;

procedure TH2StreamMap.Remove(const AStreamID: UInt32);
var
  LIndex: SizeInt;
begin
  LIndex := FindIndex(AStreamID);
  RemoveByIndex(LIndex);
end;

function TH2StreamMap.ActiveCount: SizeInt;
begin
  Result := FCount;
end;

function TH2StreamMap.AnyPending: Boolean;
begin
  Result := FCount > 0;
end;

procedure TH2StreamMap.CloseAll(const AErrorCode: UInt32);
begin
  while FCount > 0 do
  begin
    FStreams[FCount - 1].Reset(AErrorCode);
    RemoveByIndex(FCount - 1);
  end;
end;

procedure TH2StreamMap.ApplyPeerInitialWindowSize(
  const ANewInitialWindowSize: UInt32);
var
  LI: SizeInt;
begin
  for LI := 0 to FCount - 1 do
    FStreams[LI].ApplyPeerInitialWindowSize(ANewInitialWindowSize);
end;

function TH2StreamMap.ItemAt(const AIndex: SizeInt): TH2Stream;
begin
  if (AIndex < 0) or (AIndex >= FCount) then
    Exit(nil);
  Result := FStreams[AIndex];
end;

{ TH2ServerSession }

constructor TH2ServerSession.Create(const AConn: ITcpStream;
  const AHandler: IHttpHandler; const AOptions: TH2ServerTransportOptions);
begin
  inherited Create;
  if AConn = nil then
    raise EArgumentError.Create('h2 server session requires connection');
  if AHandler = nil then
    raise EArgumentError.Create('h2 server session requires handler');
  AOptions.Validate;
  FConn := AConn;
  FHandler := AHandler;
  FOptions := AOptions;
  FState := h2sesExpectPreface;
  FStreams := TH2StreamMap.Create;
  FRemoteSettings := TH2Settings.Default;
  FLocalSettings := FOptions.ToSettings;
  FConnectionFlow.Init(FRemoteSettings.InitialWindowSize,
    FOptions.InitialConnectionWindowSize);
  FDecoder.Init(FLocalSettings.HeaderTableSize);
  FEncoder.Init(FLocalSettings.HeaderTableSize);
  FReadBuffer := '';
  FWriteBuffer := '';
  FPrefaceValidated := False;
  FServerSettingsSent := False;
  FPeerSettingsAcked := False;
  FGoawayReceived := False;
  FGoawaySent := False;
  FLastSeenPeerStreamID := 0;
  FLastLocalStreamID := 0;
  FPeerGoawayLastLocalStreamID := 0;
  FPendingContinuationStreamID := 0;
  FShutdownErrorCode := H2_ERR_NO_ERROR;
  FReadDeadline := TDeadline.Infinite;
  FWriteDeadline := TDeadline.Infinite;
end;

destructor TH2ServerSession.Destroy;
begin
  FStreams.Free;
  inherited Destroy;
end;

procedure TH2ServerSession.ArmReadDeadline(const ATimeoutMs: Int64);
begin
  if ATimeoutMs > 0 then
    FReadDeadline := TDeadline.After(TDuration.FromMilliseconds(ATimeoutMs))
  else
    FReadDeadline := TDeadline.Infinite;
  FConn.SetReadDeadline(FReadDeadline);
end;

procedure TH2ServerSession.ArmWriteDeadline(const ATimeoutMs: Int64);
begin
  if ATimeoutMs > 0 then
    FWriteDeadline := TDeadline.After(TDuration.FromMilliseconds(ATimeoutMs))
  else
    FWriteDeadline := TDeadline.Infinite;
  FConn.SetWriteDeadline(FWriteDeadline);
end;

procedure TH2ServerSession.ClearReadDeadline;
begin
  FReadDeadline := TDeadline.Infinite;
  FConn.SetReadDeadline(FReadDeadline);
end;

procedure TH2ServerSession.ClearWriteDeadline;
begin
  FWriteDeadline := TDeadline.Infinite;
  FConn.SetWriteDeadline(FWriteDeadline);
end;

procedure TH2ServerSession.AppendWrite(const ABytes: AnsiString);
var
  LOldLen: SizeInt;
begin
  if ABytes = '' then
    Exit;
  LOldLen := Length(FWriteBuffer);
  SetLength(FWriteBuffer, LOldLen + Length(ABytes));
  Move(ABytes[1], FWriteBuffer[LOldLen + 1], Length(ABytes));
end;

procedure TH2ServerSession.QueueFrame(const AFrameType: Byte; const AFlags: Byte;
  const AStreamID: UInt32; const APayload: AnsiString);
begin
  AppendWrite(H2EncodeFrame(AFrameType, AFlags, AStreamID, APayload));
end;

procedure TH2ServerSession.QueueSettingsFrame(const ASettings: TH2Settings);
var
  LEntries: TH2SettingEntries;
  LEntryCount: SizeInt;
begin
  LEntryCount := 5;
  if ASettings.MaxHeaderListSize > 0 then
    Inc(LEntryCount);
  SetLength(LEntries, LEntryCount);
  LEntries[0].Identifier := H2_SETTINGS_HEADER_TABLE_SIZE;
  LEntries[0].Value := ASettings.HeaderTableSize;
  LEntries[1].Identifier := H2_SETTINGS_ENABLE_PUSH;
  if ASettings.EnablePush then
    LEntries[1].Value := 1
  else
    LEntries[1].Value := 0;
  LEntries[2].Identifier := H2_SETTINGS_MAX_CONCURRENT_STREAMS;
  LEntries[2].Value := ASettings.MaxConcurrentStreams;
  LEntries[3].Identifier := H2_SETTINGS_INITIAL_WINDOW_SIZE;
  LEntries[3].Value := ASettings.InitialWindowSize;
  LEntries[4].Identifier := H2_SETTINGS_MAX_FRAME_SIZE;
  LEntries[4].Value := ASettings.MaxFrameSize;
  if ASettings.MaxHeaderListSize > 0 then
  begin
    LEntries[5].Identifier := H2_SETTINGS_MAX_HEADER_LIST_SIZE;
    LEntries[5].Value := ASettings.MaxHeaderListSize;
  end;
  QueueFrame(H2_FRAME_SETTINGS, 0, 0, H2EncodeSettingsPayload(LEntries));
end;

procedure TH2ServerSession.QueueSettingsAck;
begin
  QueueFrame(H2_FRAME_SETTINGS, H2_FLAG_SETTINGS_ACK, 0, '');
end;

procedure TH2ServerSession.QueuePingAck(const AData: UInt64);
begin
  QueueFrame(H2_FRAME_PING, H2_FLAG_PING_ACK, 0, H2EncodePing(AData));
end;

procedure TH2ServerSession.QueueWindowUpdate(const AStreamID: UInt32;
  const AIncrement: UInt32);
begin
  if AIncrement = 0 then
    Exit;
  QueueFrame(H2_FRAME_WINDOW_UPDATE, 0, AStreamID,
    H2EncodeWindowUpdate(AIncrement));
end;

procedure TH2ServerSession.QueueRstStream(const AStreamID: UInt32;
  const AErrorCode: UInt32);
begin
  if AStreamID = 0 then
    Exit;
  QueueFrame(H2_FRAME_RST_STREAM, 0, AStreamID, H2EncodeRstStream(AErrorCode));
end;

procedure TH2ServerSession.QueueGoaway(const ALastStreamID: UInt32;
  const AErrorCode: UInt32; const ADebugData: AnsiString);
begin
  if FGoawaySent then
    Exit;
  QueueFrame(H2_FRAME_GOAWAY, 0, 0,
    H2EncodeGoaway(ALastStreamID, AErrorCode, ADebugData));
  FGoawaySent := True;
  FState := h2sesShuttingDown;
end;

procedure TH2ServerSession.EnsureServerHandshakeFramesQueued;
begin
  if FServerSettingsSent then
    Exit;
  QueueSettingsFrame(FLocalSettings);
  FServerSettingsSent := True;
end;

procedure TH2ServerSession.ApplyPendingWindowUpdates(const AStream: TH2Stream);
var
  LIncrement: UInt32;
begin
  if AStream = nil then
    Exit;
  LIncrement := AStream.TakePendingStreamWindowUpdate;
  if LIncrement > 0 then
    QueueWindowUpdate(AStream.StreamID, LIncrement);
  LIncrement := AStream.TakePendingConnectionWindowUpdate;
  if LIncrement > 0 then
    QueueWindowUpdate(0, LIncrement);
end;

procedure TH2ServerSession.ApplyAllPendingWindowUpdates;
var
  LI: SizeInt;
begin
  for LI := 0 to FStreams.ActiveCount - 1 do
    ApplyPendingWindowUpdates(FStreams.ItemAt(LI));
end;

function TH2ServerSession.StreamBodyTooLarge(const AStream: TH2Stream): Boolean;
begin
  if (AStream = nil) or (FOptions.MaxBodySize = 0) then
    Exit(False);
  Result := UInt32(Length(AStream.BodyBuffer)) > FOptions.MaxBodySize;
end;

function TH2ServerSession.DrainWriteBuffer: Boolean;
var
  LWritten: SizeUInt;
  LRemaining: SizeInt;
begin
  Result := True;
  while FWriteBuffer <> '' do
  begin
    ArmWriteDeadline(FOptions.WriteTimeout);
    LWritten := FConn.Write(FWriteBuffer[1], SizeUInt(Length(FWriteBuffer)));
    if LWritten = 0 then
      Exit(False);
    if LWritten > SizeUInt(Length(FWriteBuffer)) then
      raise EIOError.Create('h2 session write over-reported progress');
    LRemaining := Length(FWriteBuffer) - SizeInt(LWritten);
    if LRemaining > 0 then
    begin
      Move(FWriteBuffer[LWritten + 1], FWriteBuffer[1], LRemaining);
      SetLength(FWriteBuffer, LRemaining);
    end
    else
      FWriteBuffer := '';
  end;
  ClearWriteDeadline;
end;

function TH2ServerSession.FillReadBufferBlocking: Boolean;
var
  LBuf: array[0..16383] of AnsiChar;
  LRead: SizeUInt;
  LOldLen: SizeInt;
begin
  ArmReadDeadline(FOptions.ReadTimeout);
  LRead := FConn.Read(LBuf[0], SizeOf(LBuf));
  if LRead = 0 then
    Exit(False);
  LOldLen := Length(FReadBuffer);
  SetLength(FReadBuffer, LOldLen + SizeInt(LRead));
  Move(LBuf[0], FReadBuffer[LOldLen + 1], LRead);
  ClearReadDeadline;
  Result := True;
end;

function TH2ServerSession.FillReadBufferPoll(const AEvents: TPlatformPollEvents;
  out ANextEvents: TPlatformPollEvents): Boolean;
begin
  if not (peReadable in AEvents) then
  begin
    ANextEvents := [peReadable];
    Exit(False);
  end;
  Result := FillReadBufferBlocking;
  if not Result then
    ANextEvents := [];
end;

function TH2ServerSession.ProcessPreface: Boolean;
var
  LConsumed: SizeUInt;
  LErrorCode: UInt32;
  LStatus: TH2PrefaceStatus;
begin
  Result := True;
  if FPrefaceValidated then
    Exit(True);
  if FReadBuffer = '' then
    Exit(False);
  LStatus := H2ValidateServerPreface(@FReadBuffer[1], Length(FReadBuffer),
    LConsumed, LErrorCode);
  case LStatus of
    h2psNeedMore:
      Exit(False);
    h2psConnectionError:
      begin
        QueueGoaway(0, LErrorCode);
        FShutdownErrorCode := LErrorCode;
        FState := h2sesClosed;
        Exit(False);
      end;
    h2psOk:
      ;
  end;

  Delete(FReadBuffer, 1, LConsumed);
  FPrefaceValidated := True;
  FPeerSettingsAcked := True;
  FState := h2sesActive;
  EnsureServerHandshakeFramesQueued;
  QueueSettingsAck;
  Result := True;
end;

function TH2ServerSession.DecodeNextFrame(out AFrame: TH2Frame;
  out AConsumed: SizeUInt): Boolean;
begin
  Result := False;
  AFrame := Default(TH2Frame);
  AConsumed := 0;
  if Length(FReadBuffer) < H2_FRAME_HEADER_SIZE then
    Exit(False);
  Result := H2DecodeFrame(@FReadBuffer[1], Length(FReadBuffer), AFrame,
    AConsumed);
end;

function TH2ServerSession.ProcessFrames: Boolean;
var
  LFrame: TH2Frame;
  LConsumed: SizeUInt;
  LErrorCode: UInt32;
begin
  Result := True;
  while DecodeNextFrame(LFrame, LConsumed) do
  begin
    if not H2ValidateFrame(LFrame, FRemoteSettings.MaxFrameSize, LErrorCode) then
    begin
      QueueGoaway(FLastSeenPeerStreamID, LErrorCode);
      FShutdownErrorCode := LErrorCode;
      FState := h2sesClosed;
      Exit(False);
    end;
    Delete(FReadBuffer, 1, LConsumed);
    if not HandleFrame(LFrame) then
      Exit(False);
  end;
end;

function TH2ServerSession.HandleFrame(const AFrame: TH2Frame): Boolean;
begin
  Result := True;
  case AFrame.Header.FrameType of
    H2_FRAME_SETTINGS:
      Result := HandleSettings(AFrame);
    H2_FRAME_HEADERS:
      Result := HandleHeaders(AFrame);
    H2_FRAME_CONTINUATION:
      Result := HandleContinuation(AFrame);
    H2_FRAME_DATA:
      Result := HandleData(AFrame);
    H2_FRAME_PUSH_PROMISE:
      Result := RejectFrame(0, H2_ERR_PROTOCOL_ERROR, True);
    H2_FRAME_WINDOW_UPDATE:
      Result := HandleWindowUpdate(AFrame);
    H2_FRAME_RST_STREAM:
      Result := HandleRstStream(AFrame);
    H2_FRAME_PING:
      Result := HandlePing(AFrame);
    H2_FRAME_GOAWAY:
      Result := HandleGoaway(AFrame);
    H2_FRAME_PRIORITY:
      Result := True;
  else
    Result := True;
  end;
end;

function TH2ServerSession.ParseSettingsPayload(const APayload: AnsiString;
  out ASettings: TH2Settings): Boolean;
var
  LEntries: TH2SettingEntries;
  LI: SizeInt;
begin
  ASettings := FRemoteSettings;
  if not H2DecodeSettingsPayload(APayload, LEntries) then
    Exit(False);
  for LI := 0 to High(LEntries) do
  begin
    case LEntries[LI].Identifier of
      H2_SETTINGS_HEADER_TABLE_SIZE:
        ASettings.HeaderTableSize := LEntries[LI].Value;
      H2_SETTINGS_ENABLE_PUSH:
        begin
          if LEntries[LI].Value > 1 then
            Exit(False);
          ASettings.EnablePush := LEntries[LI].Value <> 0;
        end;
      H2_SETTINGS_MAX_CONCURRENT_STREAMS:
        ASettings.MaxConcurrentStreams := LEntries[LI].Value;
      H2_SETTINGS_INITIAL_WINDOW_SIZE:
        ASettings.InitialWindowSize := LEntries[LI].Value;
      H2_SETTINGS_MAX_FRAME_SIZE:
        ASettings.MaxFrameSize := LEntries[LI].Value;
      H2_SETTINGS_MAX_HEADER_LIST_SIZE:
        ASettings.MaxHeaderListSize := LEntries[LI].Value;
      else
        { unknown setting ignored }
    end;
  end;
  try
    ASettings.Validate;
  except
    Exit(False);
  end;
  Result := True;
end;

function TH2ServerSession.HandleSettings(const AFrame: TH2Frame): Boolean;
var
  LSettings: TH2Settings;
begin
  if (AFrame.Header.Flags and H2_FLAG_SETTINGS_ACK) <> 0 then
    Exit(True);
  if not ParseSettingsPayload(AFrame.Payload, LSettings) then
    Exit(RejectFrame(0, H2_ERR_PROTOCOL_ERROR, True));
  FRemoteSettings := LSettings;
  FEncoder.SetDynamicTableSize(FRemoteSettings.HeaderTableSize);
  FStreams.ApplyPeerInitialWindowSize(FRemoteSettings.InitialWindowSize);
  QueueSettingsAck;
  Result := True;
end;

function TH2ServerSession.HandleHeaders(const AFrame: TH2Frame): Boolean;
var
  LStream: TH2Stream;
  LStreamIndex: SizeInt;
begin
  if FGoawayReceived or (FState = h2sesShuttingDown) then
    Exit(RejectFrame(AFrame.Header.StreamID, H2_ERR_REFUSED_STREAM, False));
  if (AFrame.Header.StreamID and 1) = 0 then
    Exit(RejectFrame(AFrame.Header.StreamID, H2_ERR_PROTOCOL_ERROR, True));
  LStreamIndex := FStreams.FindIndex(AFrame.Header.StreamID);
  if LStreamIndex < 0 then
  begin
    if AFrame.Header.StreamID <= FLastSeenPeerStreamID then
      Exit(RejectFrame(AFrame.Header.StreamID, H2_ERR_STREAM_CLOSED, False));
    LStream := FStreams.FindOrCreate(AFrame.Header.StreamID,
      FRemoteSettings.InitialWindowSize, FOptions.InitialStreamWindowSize,
      FConnectionFlow, FDecoder, FLocalSettings.MaxHeaderListSize);
    FLastSeenPeerStreamID := AFrame.Header.StreamID;
    if (FLocalSettings.MaxConcurrentStreams > 0) and
       (FStreams.ActiveCount >= FLocalSettings.MaxConcurrentStreams) then
    begin
      QueueRstStream(LStream.StreamID, H2_ERR_REFUSED_STREAM);
      FStreams.RemoveByIndex(FStreams.ActiveCount - 1);
      Exit(True);
    end;
  end;
  if LStreamIndex >= 0 then
    LStream := FStreams.ItemAt(LStreamIndex)
  else
    LStreamIndex := FStreams.ActiveCount - 1;
  LStream.OnHeaders(AFrame.Header.Flags, AFrame.Payload);
  if LStream.ResetReceived then
  begin
    QueueRstStream(LStream.StreamID, LStream.ResetCode);
    FStreams.RemoveByIndex(LStreamIndex);
    Exit(True);
  end;
  if LStream.LastHeaderFinalizeResult = h2hfrHeaderListTooLarge then
  begin
    HandleRequestHeaderListTooLarge(LStream);
    Exit(True);
  end;
  if (AFrame.Header.Flags and H2_FLAG_HEADERS_END_HEADERS) = 0 then
    FPendingContinuationStreamID := AFrame.Header.StreamID
  else
    FPendingContinuationStreamID := 0;
  ApplyPendingWindowUpdates(LStream);
  if LStream.IsRequestReady and (not LStream.RequestHandled) then
    ExecuteStreamRequest(LStream);
  Result := True;
end;

function TH2ServerSession.HandleContinuation(const AFrame: TH2Frame): Boolean;
var
  LStream: TH2Stream;
  LStreamIndex: SizeInt;
begin
  if (FPendingContinuationStreamID = 0) or
     (FPendingContinuationStreamID <> AFrame.Header.StreamID) then
    Exit(RejectFrame(AFrame.Header.StreamID, H2_ERR_PROTOCOL_ERROR, True));
  LStreamIndex := FStreams.FindIndex(AFrame.Header.StreamID);
  if LStreamIndex < 0 then
    Exit(RejectFrame(AFrame.Header.StreamID, H2_ERR_STREAM_CLOSED, False));
  LStream := FStreams.ItemAt(LStreamIndex);
  LStream.OnContinuation(AFrame.Header.Flags, AFrame.Payload);
  if LStream.ResetReceived then
  begin
    QueueRstStream(LStream.StreamID, LStream.ResetCode);
    FStreams.RemoveByIndex(LStreamIndex);
    Exit(True);
  end;
  if LStream.LastHeaderFinalizeResult = h2hfrHeaderListTooLarge then
  begin
    HandleRequestHeaderListTooLarge(LStream);
    Exit(True);
  end;
  if (AFrame.Header.Flags and H2_FLAG_CONTINUATION_END_HEADERS) <> 0 then
    FPendingContinuationStreamID := 0;
  if LStream.IsRequestReady and (not LStream.RequestHandled) then
    ExecuteStreamRequest(LStream);
  Result := True;
end;

function TH2ServerSession.ClosedStreamDataLength(const AFrame: TH2Frame;
  out ADataLen: UInt32): Boolean;
var
  LPayloadLen: UInt32;
  LPadLen: UInt32;
begin
  ADataLen := 0;
  LPayloadLen := UInt32(Length(AFrame.Payload));
  if (AFrame.Header.Flags and H2_FLAG_DATA_PADDED) = 0 then
  begin
    ADataLen := LPayloadLen;
    Exit(True);
  end;

  if LPayloadLen < 1 then
    Exit(False);
  LPadLen := UInt32(Byte(AFrame.Payload[1]));
  if LPayloadLen < 1 + LPadLen then
    Exit(False);
  ADataLen := LPayloadLen - 1 - LPadLen;
  Result := True;
end;

function TH2ServerSession.ConsumeClosedStreamDataConnectionWindow(
  const AFrame: TH2Frame): Boolean;
var
  LDataLen: UInt32;
begin
  Result := True;
  if not ClosedStreamDataLength(AFrame, LDataLen) then
    Exit(True);
  if LDataLen = 0 then
    Exit(True);
  try
    FConnectionFlow.RecvWindow.OnDataReceived(LDataLen);
    FConnectionFlow.RecvWindow.OnDataConsumed(LDataLen);
  except
    Exit(RejectFrame(0, H2_ERR_FLOW_CONTROL_ERROR, True));
  end;
  QueueWindowUpdate(0, LDataLen);
end;

function TH2ServerSession.HandleData(const AFrame: TH2Frame): Boolean;
var
  LStream: TH2Stream;
  LStreamIndex: SizeInt;
begin
  if FPendingContinuationStreamID <> 0 then
    Exit(RejectFrame(AFrame.Header.StreamID, H2_ERR_PROTOCOL_ERROR, True));
  if AFrame.Header.StreamID = 0 then
    Exit(RejectFrame(0, H2_ERR_PROTOCOL_ERROR, True));
  LStreamIndex := FStreams.FindIndex(AFrame.Header.StreamID);
  if LStreamIndex < 0 then
  begin
    QueueRstStream(AFrame.Header.StreamID, H2_ERR_STREAM_CLOSED);
    if not ConsumeClosedStreamDataConnectionWindow(AFrame) then
      Exit(False);
    Exit(False);
  end;
  LStream := FStreams.ItemAt(LStreamIndex);
  LStream.OnData(AFrame.Header.Flags, AFrame.Payload);
  if LStream.ResetReceived then
  begin
    QueueRstStream(LStream.StreamID, LStream.ResetCode);
    FStreams.RemoveByIndex(LStreamIndex);
    Exit(True);
  end;
  if LStream.RequestHandled then
  begin
    LStream.DiscardUnreadBody;
    ApplyPendingWindowUpdates(LStream);
    CloseStreamIfTerminal(LStream);
    Exit(True);
  end;
  ApplyPendingWindowUpdates(LStream);
  if LStream.IsRequestReady and (not LStream.RequestHandled) then
    ExecuteStreamRequest(LStream);
  Result := True;
end;

function TH2ServerSession.HandleWindowUpdate(const AFrame: TH2Frame): Boolean;
var
  LIncrement: UInt32;
  LStream: TH2Stream;
  LStreamIndex: SizeInt;
begin
  if not H2DecodeWindowUpdate(AFrame.Payload, LIncrement) then
    Exit(RejectFrame(AFrame.Header.StreamID, H2_ERR_FRAME_SIZE_ERROR, True));
  if AFrame.Header.StreamID = 0 then
  begin
    try
      FConnectionFlow.SendWindow.OnWindowUpdate(LIncrement);
    except
      Exit(RejectFrame(0, H2_ERR_FLOW_CONTROL_ERROR, True));
    end;
    ExecuteReadyStreams;
    Exit(True);
  end;
  LStreamIndex := FStreams.FindIndex(AFrame.Header.StreamID);
  if LStreamIndex < 0 then
    Exit(True);
  LStream := FStreams.ItemAt(LStreamIndex);
  LStream.OnWindowUpdate(LIncrement);
  if LStream.ResetReceived then
  begin
    QueueRstStream(LStream.StreamID, LStream.ResetCode);
    FStreams.RemoveByIndex(LStreamIndex);
    Exit(True);
  end;
  if LStream.RequestHandled then
    FlushPendingResponseBody(LStream)
  else if LStream.IsRequestReady then
    ExecuteStreamRequest(LStream);
  Result := True;
end;

function TH2ServerSession.HandleRstStream(const AFrame: TH2Frame): Boolean;
var
  LErrorCode: UInt32;
  LStream: TH2Stream;
begin
  if not H2DecodeRstStream(AFrame.Payload, LErrorCode) then
    Exit(RejectFrame(AFrame.Header.StreamID, H2_ERR_FRAME_SIZE_ERROR, True));
  LStream := FStreams.FindAndRemove(AFrame.Header.StreamID);
  if LStream <> nil then
    try
      LStream.OnRstStream(LErrorCode);
    finally
      LStream.Free;
    end;
  Result := True;
end;

function TH2ServerSession.HandlePing(const AFrame: TH2Frame): Boolean;
var
  LData: UInt64;
begin
  if not H2DecodePing(AFrame.Payload, LData) then
    Exit(RejectFrame(0, H2_ERR_FRAME_SIZE_ERROR, True));
  if (AFrame.Header.Flags and H2_FLAG_PING_ACK) = 0 then
    QueuePingAck(LData);
  Result := True;
end;

function TH2ServerSession.HandleGoaway(const AFrame: TH2Frame): Boolean;
var
  LErrorCode: UInt32;
  LLastStreamID: UInt32;
  LDebugData: AnsiString;
begin
  if not H2DecodeGoaway(AFrame.Payload, LLastStreamID, LErrorCode, LDebugData) then
    Exit(RejectFrame(0, H2_ERR_FRAME_SIZE_ERROR, True));
  if LLastStreamID > FLastLocalStreamID then
    Exit(RejectFrame(0, H2_ERR_PROTOCOL_ERROR, True));
  if FGoawayReceived and (LLastStreamID > FPeerGoawayLastLocalStreamID) then
    Exit(RejectFrame(0, H2_ERR_PROTOCOL_ERROR, True));
  FGoawayReceived := True;
  FPeerGoawayLastLocalStreamID := LLastStreamID;
  FShutdownErrorCode := LErrorCode;
  FState := h2sesShuttingDown;
  Result := True;
end;

function TH2ServerSession.RejectFrame(const AStreamID: UInt32;
  const AErrorCode: UInt32; const AConnectionLevel: Boolean): Boolean;
begin
  if AConnectionLevel then
  begin
    QueueGoaway(FLastSeenPeerStreamID, AErrorCode);
    FShutdownErrorCode := AErrorCode;
    FState := h2sesClosed;
  end
  else
    QueueRstStream(AStreamID, AErrorCode);
  Result := False;
end;

function TH2ServerSession.ExtractPseudoHeader(const AHeaders: IHttpHeaders;
  const AName: string): string;
var
  LFound: string;
begin
  if AHeaders = nil then
    Exit('');
  LFound := '';
  AHeaders.ForEach(
    procedure(const AHeaderName, AHeaderValue: string)
    begin
      if AHeaderName = AName then
        LFound := AHeaderValue;
    end);
  Result := LFound;
end;

function TH2ServerSession.BuildRequestFromStream(const AStream: TH2Stream): IHttpRequest;
var
  LOriginalHeaders: IHttpHeaders;
  LHeaders: IHttpHeaders;
  LMethod: THttpMethod;
  LPath: string;
  LScheme: string;
  LAuthority: string;
  LRequest: THttpRequest;
  LBody: IH2BodyReader;
begin
  LOriginalHeaders := AStream.Headers;
  if LOriginalHeaders = nil then
    raise EHttpError.Create('h2 stream missing headers');
  LMethod := HttpMethodFromPseudo(ExtractPseudoHeader(LOriginalHeaders, ':method'));
  LPath := ExtractPseudoHeader(LOriginalHeaders, ':path');
  LScheme := ExtractPseudoHeader(LOriginalHeaders, ':scheme');
  LAuthority := ExtractPseudoHeader(LOriginalHeaders, ':authority');
  if LPath = '' then
    LPath := '/';
  LBody := AStream.CreateBodyReader;
  LHeaders := NewHttpHeaders;
  LOriginalHeaders.ForEach(
    procedure(const AName, AValue: string)
    begin
      if (AName <> '') and (AName[1] = ':') then
        Exit;
      LHeaders.Add(AName, AValue);
    end);
  if LAuthority <> '' then
    LHeaders.SetHeader('host', LAuthority);
  if LScheme <> '' then
    LHeaders.SetHeader('x-forwarded-proto', LScheme);
  LRequest := THttpRequest.CreateFromRequestTarget(LMethod, LPath, hvHttp2,
    LHeaders, LBody, Int64(Length(AStream.BodyBuffer)));
  if AStream.Trailers <> nil then
    LRequest.SetTrailers(AStream.Trailers.Clone);
  LRequest.SetRemoteNetAddr(FConn.RemoteAddr);
  Result := LRequest;
end;

procedure TH2ServerSession.HandleRequestHeaderListTooLarge(
  const AStream: TH2Stream);
begin
  if AStream = nil then
    Exit;
  AStream.MarkRequestHandled;
  SendResponseHeaders(AStream, HTTP_STATUS_HEADER_TOO_LARGE, nil, True);
  ApplyPendingWindowUpdates(AStream);
  CloseStreamIfTerminal(AStream);
end;

procedure TH2ServerSession.ExecuteReadyStreams;
var
  LI: SizeInt;
  LStream: TH2Stream;
begin
  LI := 0;
  while LI < FStreams.ActiveCount do
  begin
    LStream := FStreams.ItemAt(LI);
    if (LStream <> nil) and (not LStream.ResetReceived) and
       (not LStream.EndStreamSent) then
    begin
      if LStream.RequestHandled then
        FlushPendingResponseBody(LStream)
      else if LStream.IsRequestReady then
        ExecuteStreamRequest(LStream);
    end;
    if (LI < FStreams.ActiveCount) and (FStreams.ItemAt(LI) = LStream) then
      Inc(LI);
  end;
end;

procedure TH2ServerSession.ExecuteStreamRequest(const AStream: TH2Stream);
var
  LReq: IHttpRequest;
  LWriterObj: TH2ResponseWriter;
begin
  if (AStream = nil) or AStream.ResetReceived or AStream.EndStreamSent then
    Exit;
  if AStream.RequestHandled then
  begin
    FlushPendingResponseBody(AStream);
    Exit;
  end;
  if StreamBodyTooLarge(AStream) then
  begin
    AStream.MarkRequestHandled;
    SendResponseHeaders(AStream, HTTP_STATUS_PAYLOAD_TOO_LARGE, nil, True);
    AStream.DiscardUnreadBody;
    ApplyPendingWindowUpdates(AStream);
    CloseStreamIfTerminal(AStream);
    Exit;
  end;
  LReq := BuildRequestFromStream(AStream);
  LWriterObj := TH2ResponseWriter.Create;
  try
    FHandler.ServeHTTP(LReq, LWriterObj as IHttpResponseWriter);
    AStream.MarkRequestHandled;
    EncodeResponse(AStream, LWriterObj);
  except
    on E: Exception do
    begin
      QueueRstStream(AStream.StreamID, H2_ERR_INTERNAL_ERROR);
      FStreams.Remove(AStream.StreamID);
      Exit;
    end;
  end;
  AStream.DiscardUnreadBody;
  ApplyPendingWindowUpdates(AStream);
  CloseStreamIfTerminal(AStream);
end;

procedure TH2ServerSession.FlushPendingResponseBody(const AStream: TH2Stream);
var
  LBody: IStream;
begin
  if (AStream = nil) or AStream.ResetReceived or AStream.EndStreamSent then
    Exit;
  if not AStream.HasPendingResponseBody then
    Exit;
  LBody := AStream.GetPendingResponseBody;
  if LBody = nil then
    Exit;
  SendResponseBody(AStream, LBody, HTTP_STATUS_OK);
  if AStream.EndStreamSent then
    AStream.ClearPendingResponseBody;
  CloseStreamIfTerminal(AStream);
end;

procedure TH2ServerSession.EncodeResponse(const AStream: TH2Stream;
  const AWriter: TH2ResponseWriter);
begin
  SendResponseHeaders(AStream, AWriter.GetStatus, AWriter.GetHeaders,
    (AWriter.BodyStream = nil) or (AWriter.BodyStream.Size = 0) or
    ResponseStatusMustNotHaveBody(AWriter.GetStatus));
  if not ResponseStatusMustNotHaveBody(AWriter.GetStatus) then
  begin
    AWriter.BodyStream.Position := 0;
    AStream.SetPendingResponseBody(AWriter.BodyStream);
    SendResponseBody(AStream, AWriter.BodyStream, AWriter.GetStatus);
    if AStream.EndStreamSent then
      AStream.ClearPendingResponseBody;
  end;
end;

procedure TH2ServerSession.SendResponseHeaders(const AStream: TH2Stream;
  const AStatus: THttpStatus; const AHeaders: IHttpHeaders;
  const AEndStream: Boolean);
var
  LHeaderList: array of THPackHeader;
  LHeaderCount: SizeInt;
  LPayload: AnsiString;
  LFlags: Byte;
begin
  LHeaderCount := 1;
  if AHeaders <> nil then
    LHeaderCount := LHeaderCount + AHeaders.Count;
  SetLength(LHeaderList, LHeaderCount);
  LHeaderList[0].Name := ':status';
  LHeaderList[0].Value := StringToAnsi(StatusHeaderValue(AStatus));
  LHeaderCount := 1;
  if AHeaders <> nil then
    AHeaders.ForEach(
      procedure(const AName, AValue: string)
      begin
        if (AName = '') or (AName[1] = ':') then
          Exit;
        LHeaderList[LHeaderCount].Name := StringToAnsi(AName);
        LHeaderList[LHeaderCount].Value := StringToAnsi(AValue);
        Inc(LHeaderCount);
      end);
  SetLength(LHeaderList, LHeaderCount);
  LPayload := FEncoder.Encode(LHeaderList);
  LFlags := H2_FLAG_HEADERS_END_HEADERS;
  if AEndStream then
    LFlags := LFlags or H2_FLAG_HEADERS_END_STREAM;
  QueueFrame(H2_FRAME_HEADERS, LFlags, AStream.StreamID, LPayload);
  if AEndStream then
    AStream.MarkEndStreamSent;
end;

procedure TH2ServerSession.SendResponseBody(const AStream: TH2Stream;
  const ABody: IStream; const AStatus: THttpStatus);
var
  LChunkSize: UInt32;
  LMaxChunk: UInt32;
  LCapacity: UInt32;
  LRead: SizeUInt;
  LPayload: AnsiString;
  LFlags: Byte;
begin
  if (ABody = nil) or ResponseStatusMustNotHaveBody(AStatus) then
    Exit;
  LMaxChunk := FLocalSettings.MaxFrameSize;
  if LMaxChunk = 0 then
    LMaxChunk := H2_DEFAULT_MAX_FRAME_SIZE;
  repeat
    LCapacity := AStream.AvailableSendCapacity;
    if LCapacity = 0 then
      Break;
    LChunkSize := MinUInt32(LMaxChunk, LCapacity);
    SetLength(LPayload, LChunkSize);
    LRead := ABody.Read(LPayload[1], LChunkSize);
    if LRead = 0 then
      Break;
    if LRead < Length(LPayload) then
      SetLength(LPayload, LRead);
    AStream.ReserveSendCapacity(UInt32(LRead));
    if Length(LPayload) = 0 then
      Break;
    AStream.CommitSend(UInt32(LRead));
    LFlags := 0;
    if ABody.Position >= ABody.Size then
      LFlags := H2_FLAG_DATA_END_STREAM;
    QueueFrame(H2_FRAME_DATA, LFlags, AStream.StreamID, LPayload);
    if (LFlags and H2_FLAG_DATA_END_STREAM) <> 0 then
    begin
      AStream.MarkEndStreamSent;
      Exit;
    end;
  until False;
  if (ABody.Position >= ABody.Size) and (not AStream.EndStreamSent) then
  begin
    QueueFrame(H2_FRAME_DATA, H2_FLAG_DATA_END_STREAM, AStream.StreamID, '');
    AStream.MarkEndStreamSent;
  end;
end;

procedure TH2ServerSession.CloseStreamIfTerminal(const AStream: TH2Stream);
begin
  if (AStream = nil) or AStream.ResetReceived then
    Exit;
  if AStream.State = h2ssClosed then
    FStreams.Remove(AStream.StreamID);
end;

procedure TH2ServerSession.StartGracefulShutdown(const ALastStreamID: UInt32;
  const AErrorCode: UInt32);
begin
  if FGoawaySent then
    Exit;
  QueueGoaway(ALastStreamID, AErrorCode);
  FShutdownErrorCode := AErrorCode;
  FState := h2sesShuttingDown;
end;

procedure TH2ServerSession.CloseSession;
begin
  if FState = h2sesClosed then
    Exit;
  FStreams.CloseAll(H2_ERR_CANCEL);
  FState := h2sesClosed;
end;

function TH2ServerSession.Run: TTcpServerConnOwnership;
begin
  Result := TCP_SERVER_CONN_OWNERSHIP_SERVER;
  EnsureServerHandshakeFramesQueued;
  while FState <> h2sesClosed do
  begin
    if not DrainWriteBuffer then
      Break;
    if not ProcessPreface then
    begin
      if not FillReadBufferBlocking then
        Break;
      Continue;
    end;
    if not ProcessFrames then
      Break;
    ApplyAllPendingWindowUpdates;
    ExecuteReadyStreams;
    if (FState = h2sesShuttingDown) and (FStreams.ActiveCount = 0) then
    begin
      if not FGoawaySent then
        StartGracefulShutdown(FLastSeenPeerStreamID, FShutdownErrorCode);
      if not DrainWriteBuffer then
        Break;
      Break;
    end;
    if FReadBuffer = '' then
      if not FillReadBufferBlocking then
        Break;
  end;
  DrainWriteBuffer;
  CloseSession;
end;

function TH2ServerSession.PollEvents: TPlatformPollEvents;
begin
  if FWriteBuffer <> '' then
    Result := [peWritable]
  else
    Result := [peReadable];
end;

function TH2ServerSession.Advance(const AEvents: TPlatformPollEvents;
  out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
begin
  AOwnership := TCP_SERVER_CONN_OWNERSHIP_SERVER;
  if FState = h2sesClosed then
  begin
    ANextEvents := [];
    Exit(tsprDone);
  end;

  if FWriteBuffer <> '' then
  begin
    if not (peWritable in AEvents) then
    begin
      ANextEvents := [peWritable];
      Exit(tsprWait);
    end;
    if not DrainWriteBuffer then
    begin
      CloseSession;
      ANextEvents := [];
      Exit(tsprDone);
    end;
  end;

  if not ProcessPreface then
  begin
    if not FillReadBufferPoll(AEvents, ANextEvents) then
      Exit(tsprWait);
    if not ProcessPreface then
    begin
      ANextEvents := [peReadable];
      Exit(tsprWait);
    end;
  end;

  if not ProcessFrames then
  begin
    if FWriteBuffer <> '' then
      ANextEvents := [peWritable]
    else
      ANextEvents := [];
    if FState = h2sesClosed then
      Exit(tsprDone);
    Exit(tsprWait);
  end;

  ApplyAllPendingWindowUpdates;
  ExecuteReadyStreams;

  if (FState = h2sesShuttingDown) and (FStreams.ActiveCount = 0) then
  begin
    if not FGoawaySent then
      StartGracefulShutdown(FLastSeenPeerStreamID, FShutdownErrorCode);
    if FWriteBuffer <> '' then
    begin
      ANextEvents := [peWritable];
      Exit(tsprWait);
    end;
    CloseSession;
    ANextEvents := [];
    Exit(tsprDone);
  end;

  if FWriteBuffer <> '' then
    ANextEvents := [peWritable]
  else
    ANextEvents := [peReadable];
  Result := tsprWait;
end;

function TH2ServerSession.WakeDeadline: TDeadline;
begin
  Result := TDeadline.Min(FReadDeadline, FWriteDeadline);
end;

end.
