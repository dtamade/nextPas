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
  nextpas.core.mem.arena.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.impl.h2.frame,
  nextpas.core.http.impl.h2.wire,
  nextpas.core.http.impl.h2.hpack,
  nextpas.core.http.impl.h2.stream,
  nextpas.core.http.impl.h2.streammap,
  nextpas.core.http.impl.h2.session.helpers,
  nextpas.core.http.impl.h2.session.request,
  nextpas.core.http.impl.h2.session.preface,
  nextpas.core.http.impl.h2.session.writer,
  nextpas.core.http.impl.h2.types;

type
  { Mechanical extracts re-exported for existing tests/source contracts. }
  TH2PrefaceStatus =
    nextpas.core.http.impl.h2.session.preface.TH2PrefaceStatus;
  TH2StreamMap =
    nextpas.core.http.impl.h2.streammap.TH2StreamMap;
  TH2ResponseWriter =
    nextpas.core.http.impl.h2.session.writer.TH2ResponseWriter;

const
  { CVE-2023-44487 rapid-reset budget: max consecutive peer RST_STREAMs that
    cancel a not-yet-handled request before the server treats the peer as
    abusive and closes with ENHANCE_YOUR_CALM. Any request that runs to
    completion resets the budget, so legitimate cancellation never trips it. }
  H2_MAX_RAPID_RESETS = 100;

  { CVE-2019-9512 (Ping Flood) / CVE-2019-9515 (Settings Flood) budget: max
    ack-demanding control frames (non-ACK PING/SETTINGS) the peer may send
    without any request making progress before the server treats the peer as
    abusive and closes with ENHANCE_YOUR_CALM. Any request that runs to
    completion resets the budget, so a client's occasional keep-alive PING or
    SETTINGS update never trips it. }
  H2_MAX_CONTROL_FRAME_FLOOD = 100;

  h2psNeedMore =
    nextpas.core.http.impl.h2.session.preface.h2psNeedMore;
  h2psOk =
    nextpas.core.http.impl.h2.session.preface.h2psOk;
  h2psConnectionError =
    nextpas.core.http.impl.h2.session.preface.h2psConnectionError;

type
  TH2SessionState = (
    h2sesExpectPreface,
    h2sesActive,
    h2sesShuttingDown,
    h2sesClosed
  );

  TH2ServerSession = class(TInterfacedObject, ITcpServerSession,
    ITcpServerPollDrivenSession, ITcpServerPollDrivenSessionWithDeadline)
  private
    FConn: ITcpStream;
    FHandler: IHttpHandler;
    FOptions: TH2ServerTransportOptions;
    FState: TH2SessionState;
    FWire: TH2WireBuffers;
    FStreams: TH2StreamMap;
    FRemoteSettings: TH2Settings;
    FLocalSettings: TH2Settings;
    FConnectionFlow: TH2ConnectionFlowControl;
    FDecoder: THPackDecoder;
    FEncoder: THPackEncoder;
    FPrefaceValidated: Boolean;
    FServerSettingsSent: Boolean;
    FPeerSettingsReceived: Boolean;
    FGoawayReceived: Boolean;
    FGoawaySent: Boolean;
    FLastSeenPeerStreamID: UInt32;
    FLastLocalStreamID: UInt32;
    FPeerGoawayLastLocalStreamID: UInt32;
    FPendingContinuationStreamID: UInt32;
    FRapidResetCount: UInt32;
    FControlFrameFloodCount: UInt32;
    FShutdownErrorCode: UInt32;
    FReadDeadline: TDeadline;
    FWriteDeadline: TDeadline;
    FRequestArena: IArena;
    procedure InvokeHandler(const AReq: IHttpRequest;
      const AW: IHttpResponseWriter);
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
    { Poll path: partial write + would-block (non-blocking socket). }
    function DrainWriteBufferPoll(out AWouldBlock: Boolean): Boolean;
    function FillReadBufferBlocking: Boolean;
    function FillReadBufferPoll(const AEvents: TPlatformPollEvents;
      out ANextEvents: TPlatformPollEvents;
      out AClosed: Boolean): Boolean;
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
    { Charges one ack-demanding control frame against the flood budget.
      Returns False (and queues GOAWAY(ENHANCE_YOUR_CALM), closing the
      session) once the budget is exceeded; the caller must Exit(False). }
    function RegisterControlFrameFlood: Boolean;
    { Escalates a stream-level header-block flood reset (ENHANCE_YOUR_CALM is
      the only reset code produced by the HEADERS/CONTINUATION fragment bounds)
      to a connection error: GOAWAY(ENHANCE_YOUR_CALM), close, and clear any
      pending CONTINUATION state. Returns False; the caller must Exit(False). }
    function EscalateHeaderBlockFlood: Boolean;
    function HandleGoaway(const AFrame: TH2Frame): Boolean;
    function ClosedStreamDataLength(const AFrame: TH2Frame;
      out ADataLen: UInt32): Boolean;
    function ConsumeClosedStreamDataConnectionWindow(
      const AFrame: TH2Frame): Boolean;
    function RejectFrame(const AStreamID: UInt32; const AErrorCode: UInt32;
      const AConnectionLevel: Boolean): Boolean;
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
  out AConsumed: SizeUInt; out AErrorCode: UInt32): TH2PrefaceStatus; inline;

implementation

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.errors,
  nextpas.core.exception,
  nextpas.core.io.memory,
  nextpas.core.time.base,
  nextpas.core.http.headers,
  nextpas.core.http.message,
  nextpas.core.http.mem,
  nextpas.core.http.middleware.requestarena;

function H2ValidateServerPreface(const ABuf: PAnsiChar; const ALen: SizeUInt;
  out AConsumed: SizeUInt; out AErrorCode: UInt32): TH2PrefaceStatus;
begin
  Result := nextpas.core.http.impl.h2.session.preface.H2ValidateServerPreface(
    ABuf, ALen, AConsumed, AErrorCode);
end;

{ TH2ServerSession }

constructor TH2ServerSession.Create(const AConn: ITcpStream;
  const AHandler: IHttpHandler; const AOptions: TH2ServerTransportOptions);
begin
  inherited Create;
  if AConn = nil then
    raise EHttpError.Create(hekArgument, 'h2 server session requires connection');
  if AHandler = nil then
    raise EHttpError.Create(hekArgument, 'h2 server session requires handler');
  AOptions.Validate;
  FConn := AConn;
  FHandler := AHandler;
  FOptions := AOptions;
  { Connection-scoped request arena: Reset per stream request (session is serial). }
  if AOptions.RequestArena then
    FRequestArena := HttpCreateRequestArena(AOptions.RequestArenaCapacity)
  else
    FRequestArena := nil;
  FState := h2sesExpectPreface;
  FStreams := TH2StreamMap.Create;
  FRemoteSettings := TH2Settings.Default;
  FLocalSettings := FOptions.ToSettings;
  FConnectionFlow.Init(FRemoteSettings.InitialWindowSize,
    FOptions.InitialConnectionWindowSize);
  FDecoder.Init(FLocalSettings.HeaderTableSize);
  FEncoder.Init(FLocalSettings.HeaderTableSize);
  H2WireInit(FWire);
  FPrefaceValidated := False;
  FServerSettingsSent := False;
  FPeerSettingsReceived := False;
  FGoawayReceived := False;
  FGoawaySent := False;
  FLastSeenPeerStreamID := 0;
  FLastLocalStreamID := 0;
  FPeerGoawayLastLocalStreamID := 0;
  FPendingContinuationStreamID := 0;
  FRapidResetCount := 0;
  FControlFrameFloodCount := 0;
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
var
  LTimeoutMs: Int64;
begin
  { Prefer explicit read timeout; fall back to idle timeout for keep-alive waits
    so blocking Run() does not hang forever after a response is flushed. }
  LTimeoutMs := ATimeoutMs;
  if (LTimeoutMs <= 0) and (FOptions.IdleTimeout > 0) then
    LTimeoutMs := FOptions.IdleTimeout;
  if LTimeoutMs > 0 then
    FReadDeadline := TDeadline.After(TDuration.FromMilliseconds(LTimeoutMs))
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
begin
  H2WireAppendWrite(FWire, ABytes);
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
begin
  Result := True;
  while H2WireHasWriteData(FWire) do
  begin
    ArmWriteDeadline(FOptions.WriteTimeout);
    LWritten := FConn.Write(FWire.WriteBuf[1], SizeUInt(Length(FWire.WriteBuf)));
    if LWritten = 0 then
      Exit(False);
    if LWritten > SizeUInt(Length(FWire.WriteBuf)) then
      raise EIOError.Create('h2 session write over-reported progress');
    H2WireConsumeWriteFront(FWire, LWritten);
  end;
  ClearWriteDeadline;
end;

function TH2ServerSession.DrainWriteBufferPoll(out AWouldBlock: Boolean): Boolean;
var
  LRuntime: ITcpStreamRuntime;
  LWritten: SizeUInt;
  LRes: TTcpStreamIOResult;
begin
  Result := True;
  AWouldBlock := False;
  if not H2WireHasWriteData(FWire) then
    Exit(True);
  if not Supports(FConn, ITcpStreamRuntime, LRuntime) then
  begin
    Result := DrainWriteBuffer;
    Exit;
  end;
  while H2WireHasWriteData(FWire) do
  begin
    ArmWriteDeadline(FOptions.WriteTimeout);
    LRes := LRuntime.TryWrite(FWire.WriteBuf[1], SizeUInt(Length(FWire.WriteBuf)),
      LWritten);
    ClearWriteDeadline;
    case LRes of
      tsiorOk:
        begin
          if LWritten = 0 then
          begin
            AWouldBlock := True;
            Exit(True);
          end;
          if LWritten > SizeUInt(Length(FWire.WriteBuf)) then
            raise EIOError.Create('h2 session write over-reported progress');
          H2WireConsumeWriteFront(FWire, LWritten);
        end;
      tsiorWouldBlock:
        begin
          AWouldBlock := True;
          Exit(True);
        end;
      tsiorTimeout, tsiorClosed:
        Exit(False);
    end;
  end;
end;

function TH2ServerSession.FillReadBufferBlocking: Boolean;
var
  LBuf: array[0..16383] of AnsiChar;
  LRead: SizeUInt;
begin
  { Reject if read buffer has grown beyond hard limit — prevents memory
    exhaustion from an attacker sending tiny fragments that never form
    a complete frame. }
  H2WirePrepareAppendRead(FWire);
  if H2WireReadStored(FWire) >= H2_WIRE_READ_HARD_LIMIT then
  begin
    QueueGoaway(FLastSeenPeerStreamID, H2_ERR_ENHANCE_YOUR_CALM);
    FShutdownErrorCode := H2_ERR_ENHANCE_YOUR_CALM;
    FState := h2sesClosed;
    Exit(False);
  end;
  ArmReadDeadline(FOptions.ReadTimeout);
  LRead := FConn.Read(LBuf[0], SizeOf(LBuf));
  if LRead = 0 then
    Exit(False);
  H2WireAppendReadBytes(FWire, LBuf[0], SizeInt(LRead));
  ClearReadDeadline;
  Result := True;
end;

function TH2ServerSession.FillReadBufferPoll(const AEvents: TPlatformPollEvents;
  out ANextEvents: TPlatformPollEvents; out AClosed: Boolean): Boolean;
var
  LRuntime: ITcpStreamRuntime;
  LBuf: array[0..16383] of AnsiChar;
  LRead: SizeUInt;
  LRes: TTcpStreamIOResult;
begin
  Result := False;
  AClosed := False;
  ANextEvents := [peReadable];
  if not (peReadable in AEvents) then
    Exit(False);

  H2WirePrepareAppendRead(FWire);
  if H2WireReadStored(FWire) >= H2_WIRE_READ_HARD_LIMIT then
  begin
    QueueGoaway(FLastSeenPeerStreamID, H2_ERR_ENHANCE_YOUR_CALM);
    FShutdownErrorCode := H2_ERR_ENHANCE_YOUR_CALM;
    FState := h2sesClosed;
    AClosed := True;
    ANextEvents := [];
    Exit(False);
  end;

  { S3-3: epoll sockets are non-blocking. Blocking Read() treating EAGAIN as
    EOF left the session waiting forever (empty ANextEvents hang). }
  if Supports(FConn, ITcpStreamRuntime, LRuntime) then
  begin
    ArmReadDeadline(FOptions.ReadTimeout);
    LRes := LRuntime.TryRead(LBuf[0], SizeOf(LBuf), LRead);
    ClearReadDeadline;
    case LRes of
      tsiorOk:
        begin
          if LRead = 0 then
          begin
            AClosed := True;
            ANextEvents := [];
            Exit(False);
          end;
          H2WireAppendReadBytes(FWire, LBuf[0], SizeInt(LRead));
          Exit(True);
        end;
      tsiorWouldBlock:
        begin
          ANextEvents := [peReadable];
          Exit(False);
        end;
      tsiorTimeout, tsiorClosed:
        begin
          AClosed := True;
          ANextEvents := [];
          Exit(False);
        end;
    end;
  end;

  { Fallback: blocking Read (threaded path should not use FillReadBufferPoll). }
  Result := FillReadBufferBlocking;
  if not Result then
  begin
    AClosed := True;
    ANextEvents := [];
  end;
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
  if not H2WireHasReadData(FWire) then
    Exit(False);
  LStatus := H2ValidateServerPreface(H2WireReadPtr(FWire),
    SizeUInt(H2WireReadAvailable(FWire)), LConsumed, LErrorCode);
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

  H2WireDiscardConsumed(FWire, LConsumed);
  FPrefaceValidated := True;
  FPeerSettingsReceived := True;
  FState := h2sesActive;
  EnsureServerHandshakeFramesQueued;
  QueueSettingsAck;
  Result := True;
end;

function TH2ServerSession.DecodeNextFrame(out AFrame: TH2Frame;
  out AConsumed: SizeUInt): Boolean;
var
  LHeader: TH2FrameHeader;
  LDeclaredPayloadLen: SizeUInt;
begin
  Result := False;
  AFrame := Default(TH2Frame);
  AConsumed := 0;
  if not H2WirePeekFrameHeader(FWire, LHeader) then
    Exit(False);
  { Early reject: parse 9-byte header and check declared payload length
    against negotiated MAX_FRAME_SIZE BEFORE allocating payload memory.
    This prevents a client from declaring a 16 MB frame that would be
    copied into memory before validation. }
  LDeclaredPayloadLen := SizeUInt(LHeader.Len);
  if LDeclaredPayloadLen > H2_ABSOLUTE_MAX_FRAME_SIZE then
  begin
    QueueGoaway(FLastSeenPeerStreamID, H2_ERR_FRAME_SIZE_ERROR);
    FShutdownErrorCode := H2_ERR_FRAME_SIZE_ERROR;
    FState := h2sesClosed;
    Exit(False);
  end;
  if LDeclaredPayloadLen > SizeUInt(FRemoteSettings.MaxFrameSize) then
  begin
    QueueGoaway(FLastSeenPeerStreamID, H2_ERR_FRAME_SIZE_ERROR);
    FShutdownErrorCode := H2_ERR_FRAME_SIZE_ERROR;
    FState := h2sesClosed;
    Exit(False);
  end;
  { Not enough data yet for the full frame — wait for more }
  if not H2WireHasFullFrame(FWire, LHeader) then
    Exit(False);
  Result := H2WireTryDecodeFrame(FWire, AFrame, AConsumed);
end;

function TH2ServerSession.ProcessFrames: Boolean;
var
  LFrame: TH2Frame;
  LConsumed: SizeUInt;
  LErrorCode: UInt32;
begin
  LFrame := Default(TH2Frame);
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
    H2WireDiscardConsumed(FWire, LConsumed);
    if not HandleFrame(LFrame) then
      Exit(False);
  end;
end;

function TH2ServerSession.HandleFrame(const AFrame: TH2Frame): Boolean;
begin
  Result := True;
  { RFC 9113 §3.4: Before receiving a valid SETTINGS frame from the peer,
    only SETTINGS frames are allowed.  Any other frame type is a
    connection error (PROTOCOL_ERROR). }
  if not FPeerSettingsReceived then
  begin
    if AFrame.Header.FrameType <> H2_FRAME_SETTINGS then
    begin
      QueueGoaway(FLastSeenPeerStreamID, H2_ERR_PROTOCOL_ERROR);
      FShutdownErrorCode := H2_ERR_PROTOCOL_ERROR;
      FState := h2sesClosed;
      Exit(False);
    end;
  end;
  { RFC 9113 §6.10: During a pending CONTINUATION sequence, only
    CONTINUATION frames for the same stream are allowed.  Any other
    frame type is a connection error (PROTOCOL_ERROR). }
  if (FPendingContinuationStreamID <> 0) and
     ((AFrame.Header.FrameType <> H2_FRAME_CONTINUATION) or
      (AFrame.Header.StreamID <> FPendingContinuationStreamID)) then
  begin
    QueueGoaway(FLastSeenPeerStreamID, H2_ERR_PROTOCOL_ERROR);
    FShutdownErrorCode := H2_ERR_PROTOCOL_ERROR;
    FState := h2sesClosed;
    Exit(False);
  end;
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

function TH2ServerSession.HandleSettings(const AFrame: TH2Frame): Boolean;
var
  LSettings: TH2Settings;
begin
  if (AFrame.Header.Flags and H2_FLAG_SETTINGS_ACK) <> 0 then
    Exit(True);
  if not H2ParseSettingsPayload(FRemoteSettings, AFrame.Payload, LSettings) then
    Exit(RejectFrame(0, H2_ERR_PROTOCOL_ERROR, True));
  FRemoteSettings := LSettings;
  FEncoder.SetDynamicTableSize(FRemoteSettings.HeaderTableSize);
  FStreams.ApplyPeerInitialWindowSize(FRemoteSettings.InitialWindowSize);
  if not RegisterControlFrameFlood then
    Exit(False);
  QueueSettingsAck;
  Result := True;
end;

function TH2ServerSession.HandleHeaders(const AFrame: TH2Frame): Boolean;
var
  LStream: TH2Stream;
begin
  if FGoawayReceived or (FState = h2sesShuttingDown) then
    Exit(RejectFrame(AFrame.Header.StreamID, H2_ERR_REFUSED_STREAM, False));
  if (AFrame.Header.StreamID and 1) = 0 then
    Exit(RejectFrame(AFrame.Header.StreamID, H2_ERR_PROTOCOL_ERROR, True));
  LStream := FStreams.Find(AFrame.Header.StreamID);
  if LStream = nil then
  begin
    if AFrame.Header.StreamID <= FLastSeenPeerStreamID then
      Exit(RejectFrame(AFrame.Header.StreamID, H2_ERR_STREAM_CLOSED, False));
    if FStreams.ActiveCount >= EffectiveMaxConcurrentStreams(FLocalSettings) then
    begin
      QueueRstStream(AFrame.Header.StreamID, H2_ERR_REFUSED_STREAM);
      Exit(True);
    end;
    LStream := FStreams.FindOrCreate(AFrame.Header.StreamID,
      FRemoteSettings.InitialWindowSize, FOptions.InitialStreamWindowSize,
      FConnectionFlow, FDecoder, FLocalSettings.MaxHeaderListSize);
    FLastSeenPeerStreamID := AFrame.Header.StreamID;
  end;
  LStream.OnHeaders(AFrame.Header.Flags, AFrame.Payload);
  if LStream.ResetReceived then
  begin
    if LStream.ResetCode = H2_ERR_ENHANCE_YOUR_CALM then
      Exit(EscalateHeaderBlockFlood);
    QueueRstStream(LStream.StreamID, LStream.ResetCode);
    FStreams.Remove(LStream.StreamID);
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
begin
  if (FPendingContinuationStreamID = 0) or
     (FPendingContinuationStreamID <> AFrame.Header.StreamID) then
    Exit(RejectFrame(AFrame.Header.StreamID, H2_ERR_PROTOCOL_ERROR, True));
  LStream := FStreams.Find(AFrame.Header.StreamID);
  if LStream = nil then
    Exit(RejectFrame(AFrame.Header.StreamID, H2_ERR_STREAM_CLOSED, False));
  LStream.OnContinuation(AFrame.Header.Flags, AFrame.Payload);
  if LStream.ResetReceived then
  begin
    if LStream.ResetCode = H2_ERR_ENHANCE_YOUR_CALM then
      Exit(EscalateHeaderBlockFlood);
    QueueRstStream(LStream.StreamID, LStream.ResetCode);
    FStreams.Remove(LStream.StreamID);
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
begin
  if FPendingContinuationStreamID <> 0 then
    Exit(RejectFrame(AFrame.Header.StreamID, H2_ERR_PROTOCOL_ERROR, True));
  if AFrame.Header.StreamID = 0 then
    Exit(RejectFrame(0, H2_ERR_PROTOCOL_ERROR, True));
  LStream := FStreams.Find(AFrame.Header.StreamID);
  if LStream = nil then
  begin
    QueueRstStream(AFrame.Header.StreamID, H2_ERR_STREAM_CLOSED);
    if not ConsumeClosedStreamDataConnectionWindow(AFrame) then
      Exit(False);
    { Stream-level RST sent; continue processing other frames. }
    Exit(True);
  end;
  LStream.OnData(AFrame.Header.Flags, AFrame.Payload);
  if LStream.ResetReceived then
  begin
    QueueRstStream(LStream.StreamID, LStream.ResetCode);
    FStreams.Remove(LStream.StreamID);
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
  LStream := FStreams.Find(AFrame.Header.StreamID);
  if LStream = nil then
    Exit(True);
  LStream.OnWindowUpdate(LIncrement);
  if LStream.ResetReceived then
  begin
    QueueRstStream(LStream.StreamID, LStream.ResetCode);
    FStreams.Remove(LStream.StreamID);
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
  { RFC 9113 §6.10: If the stream is reset while a CONTINUATION sequence
    is pending, clear the pending state to avoid stale expectations. }
  if FPendingContinuationStreamID = AFrame.Header.StreamID then
    FPendingContinuationStreamID := 0;
  LStream := FStreams.Find(AFrame.Header.StreamID);
  if LStream <> nil then
  begin
    { CVE-2023-44487: cancelling a stream whose request never ran is the
      rapid-reset signature. Count it against the budget; a completed request
      clears the counter (see ExecuteStreamRequest), so this only fires under
      a sustained open-then-reset flood. }
    if not LStream.RequestHandled then
    begin
      Inc(FRapidResetCount);
      if FRapidResetCount > H2_MAX_RAPID_RESETS then
      begin
        LStream.OnRstStream(LErrorCode);
        FStreams.Remove(AFrame.Header.StreamID);
        QueueGoaway(FLastSeenPeerStreamID, H2_ERR_ENHANCE_YOUR_CALM);
        FShutdownErrorCode := H2_ERR_ENHANCE_YOUR_CALM;
        FState := h2sesClosed;
        Exit(True);
      end;
    end;
    LStream.OnRstStream(LErrorCode);
    FStreams.Remove(AFrame.Header.StreamID);
  end;
  Result := True;
end;

function TH2ServerSession.RegisterControlFrameFlood: Boolean;
begin
  Inc(FControlFrameFloodCount);
  if FControlFrameFloodCount > H2_MAX_CONTROL_FRAME_FLOOD then
  begin
    QueueGoaway(FLastSeenPeerStreamID, H2_ERR_ENHANCE_YOUR_CALM);
    FShutdownErrorCode := H2_ERR_ENHANCE_YOUR_CALM;
    FState := h2sesClosed;
    Exit(False);
  end;
  Result := True;
end;

function TH2ServerSession.EscalateHeaderBlockFlood: Boolean;
begin
  QueueGoaway(FLastSeenPeerStreamID, H2_ERR_ENHANCE_YOUR_CALM);
  FShutdownErrorCode := H2_ERR_ENHANCE_YOUR_CALM;
  FState := h2sesClosed;
  FPendingContinuationStreamID := 0;
  Result := False;
end;

function TH2ServerSession.HandlePing(const AFrame: TH2Frame): Boolean;
var
  LData: UInt64;
begin
  if not H2DecodePing(AFrame.Payload, LData) then
    Exit(RejectFrame(0, H2_ERR_FRAME_SIZE_ERROR, True));
  if (AFrame.Header.Flags and H2_FLAG_PING_ACK) = 0 then
  begin
    if not RegisterControlFrameFlood then
      Exit(False);
    QueuePingAck(LData);
  end;
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
    Result := False;
  end
  else
  begin
    { Stream-level rejection: send RST_STREAM but keep the connection alive.
      Returning True signals the Run loop to continue processing frames. }
    QueueRstStream(AStreamID, AErrorCode);
    Result := True;
  end;
end;

function TH2ServerSession.ExtractPseudoHeader(const AHeaders: IHttpHeaders;
  const AName: string): string;
begin
  Result := H2ExtractPseudoHeader(AHeaders, AName);
end;

function TH2ServerSession.BuildRequestFromStream(const AStream: TH2Stream): IHttpRequest;
begin
  Result := H2BuildRequestFromStream(AStream, FConn.RemoteAddr);
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

procedure TH2ServerSession.InvokeHandler(const AReq: IHttpRequest;
  const AW: IHttpResponseWriter);
begin
  if FRequestArena = nil then
  begin
    FHandler.ServeHTTP(AReq, AW);
    Exit;
  end;
  { Session-serial: one LocalArena, Reset per stream request. }
  FRequestArena.Reset;
  HttpAttachRequestArena(AReq, FRequestArena);
  try
    FHandler.ServeHTTP(AReq, AW);
  finally
    HttpDetachRequestArena(AReq);
    FRequestArena.Reset;
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
    FRapidResetCount := 0;
    FControlFrameFloodCount := 0;
    SendResponseHeaders(AStream, HTTP_STATUS_PAYLOAD_TOO_LARGE, nil, True);
    AStream.DiscardUnreadBody;
    ApplyPendingWindowUpdates(AStream);
    CloseStreamIfTerminal(AStream);
    Exit;
  end;
  LReq := BuildRequestFromStream(AStream);
  LWriterObj := TH2ResponseWriter.Create;
  try
    InvokeHandler(LReq, LWriterObj as IHttpResponseWriter);
    AStream.MarkRequestHandled;
    FRapidResetCount := 0;
    FControlFrameFloodCount := 0;
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
      var
        LLowerName: string;
        LJ: Integer;
      begin
        if (AName = '') or (AName[1] = ':') then
          Exit;
        { RFC 9113 §8.2: field names MUST be lowercase }
        LLowerName := LowerCase(AName);
        { Reject connection-specific headers that are forbidden in HTTP/2 }
        if (LLowerName = 'connection') or (LLowerName = 'upgrade') or
           (LLowerName = 'keep-alive') or (LLowerName = 'proxy-connection') or
           (LLowerName = 'transfer-encoding') then
          Exit;
        { TE header is only allowed with value "trailers" }
        if (LLowerName = 'te') and (LowerCase(AValue) <> 'trailers') then
          Exit;
        LHeaderList[LHeaderCount].Name := StringToAnsi(LLowerName);
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
    LChunkSize := H2MinUInt32(LMaxChunk, LCapacity);
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
    { Flush responses (and SETTINGS ACK / RST / WINDOW_UPDATE) before blocking
      on the next read. Otherwise a keep-alive client waiting for headers will
      deadlock with a server blocked in FillReadBufferBlocking. }
    if not DrainWriteBuffer then
      Break;
    if (FState = h2sesShuttingDown) and (FStreams.ActiveCount = 0) then
    begin
      if not FGoawaySent then
        StartGracefulShutdown(FLastSeenPeerStreamID, FShutdownErrorCode);
      if not DrainWriteBuffer then
        Break;
      Break;
    end;
    if not H2WireHasReadData(FWire) then
      if not FillReadBufferBlocking then
        Break;
  end;
  DrainWriteBuffer;
  CloseSession;
end;

function TH2ServerSession.PollEvents: TPlatformPollEvents;
begin
  if H2WireHasWriteData(FWire) then
    Result := [peWritable]
  else
    Result := [peReadable];
end;

function TH2ServerSession.Advance(const AEvents: TPlatformPollEvents;
  out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
var
  LWouldBlock: Boolean;
  LClosed: Boolean;
begin
  AOwnership := TCP_SERVER_CONN_OWNERSHIP_SERVER;
  if FState = h2sesClosed then
  begin
    ANextEvents := [];
    Exit(tsprDone);
  end;

  { 1. Drain pending writes (non-blocking). }
  if H2WireHasWriteData(FWire) then
  begin
    if not (peWritable in AEvents) then
    begin
      ANextEvents := [peWritable];
      Exit(tsprWait);
    end;
    if not DrainWriteBufferPoll(LWouldBlock) then
    begin
      CloseSession;
      ANextEvents := [];
      Exit(tsprDone);
    end;
    if LWouldBlock and H2WireHasWriteData(FWire) then
    begin
      ANextEvents := [peWritable];
      Exit(tsprWait);
    end;
  end;

  { 2. Preface + inbound frames. }
  if not ProcessPreface then
  begin
    if not FillReadBufferPoll(AEvents, ANextEvents, LClosed) then
    begin
      if LClosed or (FState = h2sesClosed) then
      begin
        CloseSession;
        ANextEvents := [];
        Exit(tsprDone);
      end;
      Exit(tsprWait);
    end;
    if not ProcessPreface then
    begin
      ANextEvents := [peReadable];
      Exit(tsprWait);
    end;
  end;

  { Read available data when readable so ProcessFrames can make progress. }
  if peReadable in AEvents then
  begin
    if not FillReadBufferPoll(AEvents, ANextEvents, LClosed) then
    begin
      if LClosed then
      begin
        if H2WireHasWriteData(FWire) then
        begin
          ANextEvents := [peWritable];
          Exit(tsprWait);
        end;
        CloseSession;
        ANextEvents := [];
        Exit(tsprDone);
      end;
      { would-block with empty buffer is fine; may still process buffered. }
    end;
  end;

  if not ProcessFrames then
  begin
    if FState = h2sesClosed then
    begin
      if H2WireHasWriteData(FWire) then
      begin
        ANextEvents := [peWritable];
        Exit(tsprWait);
      end;
      CloseSession;
      ANextEvents := [];
      Exit(tsprDone);
    end;
  end;

  ApplyAllPendingWindowUpdates;
  ExecuteReadyStreams;

  { 3. Flush responses produced by handlers. }
  if H2WireHasWriteData(FWire) then
  begin
    if not DrainWriteBufferPoll(LWouldBlock) then
    begin
      CloseSession;
      ANextEvents := [];
      Exit(tsprDone);
    end;
    if LWouldBlock and H2WireHasWriteData(FWire) then
    begin
      ANextEvents := [peWritable];
      Exit(tsprWait);
    end;
  end;

  if (FState = h2sesShuttingDown) and (FStreams.ActiveCount = 0) then
  begin
    if not FGoawaySent then
      StartGracefulShutdown(FLastSeenPeerStreamID, FShutdownErrorCode);
    if H2WireHasWriteData(FWire) then
    begin
      ANextEvents := [peWritable];
      Exit(tsprWait);
    end;
    CloseSession;
    ANextEvents := [];
    Exit(tsprDone);
  end;

  if H2WireHasWriteData(FWire) then
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
