unit nextpas.core.http.impl.h2.types;
{**
 * @desc Shared HTTP/2 transport types: negotiated settings, transport options,
 *       stream state, and transport-owned flow-control bookkeeping.
 *       This unit re-exports key RFC 9113 constants so H2 transport code can
 *       depend on one type surface instead of reaching into frame codecs.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.base,
  nextpas.core.http.impl.h2.frame;

const
  H2_CONNECTION_STREAM_ID = UInt32(0);
  H2_MIN_STREAM_ID = UInt32(1);
  H2_MAX_STREAM_ID = UInt32($7FFFFFFF);
  H2_MAX_WINDOW_SIZE = UInt32($7FFFFFFF);

  { RFC 9113 defaults. A zero MaxConcurrentStreams or MaxHeaderListSize means
    the peer did not advertise an explicit limit and the RFC default applies. }
  H2_DEFAULT_ENABLE_PUSH = True;
  H2_DEFAULT_MAX_CONCURRENT_STREAMS = UInt32(0);
  H2_DEFAULT_MAX_HEADER_LIST_SIZE = UInt32(0);

  H2_FRAME_HEADER_SIZE = nextpas.core.http.impl.h2.frame.H2_FRAME_HEADER_SIZE;

  H2_DEFAULT_MAX_FRAME_SIZE =
    nextpas.core.http.impl.h2.frame.H2_DEFAULT_MAX_FRAME_SIZE;
  H2_MIN_MAX_FRAME_SIZE =
    nextpas.core.http.impl.h2.frame.H2_MIN_MAX_FRAME_SIZE;
  H2_ABSOLUTE_MAX_FRAME_SIZE =
    nextpas.core.http.impl.h2.frame.H2_ABSOLUTE_MAX_FRAME_SIZE;

  H2_DEFAULT_INITIAL_WINDOW_SIZE =
    nextpas.core.http.impl.h2.frame.H2_DEFAULT_INITIAL_WINDOW_SIZE;
  H2_DEFAULT_HEADER_TABLE_SIZE =
    nextpas.core.http.impl.h2.frame.H2_DEFAULT_HEADER_TABLE_SIZE;

  H2_SETTINGS_HEADER_TABLE_SIZE =
    nextpas.core.http.impl.h2.frame.H2_SETTINGS_HEADER_TABLE_SIZE;
  H2_SETTINGS_ENABLE_PUSH =
    nextpas.core.http.impl.h2.frame.H2_SETTINGS_ENABLE_PUSH;
  H2_SETTINGS_MAX_CONCURRENT_STREAMS =
    nextpas.core.http.impl.h2.frame.H2_SETTINGS_MAX_CONCURRENT_STREAMS;
  H2_SETTINGS_INITIAL_WINDOW_SIZE =
    nextpas.core.http.impl.h2.frame.H2_SETTINGS_INITIAL_WINDOW_SIZE;
  H2_SETTINGS_MAX_FRAME_SIZE =
    nextpas.core.http.impl.h2.frame.H2_SETTINGS_MAX_FRAME_SIZE;
  H2_SETTINGS_MAX_HEADER_LIST_SIZE =
    nextpas.core.http.impl.h2.frame.H2_SETTINGS_MAX_HEADER_LIST_SIZE;

  H2_FRAME_DATA =
    nextpas.core.http.impl.h2.frame.H2_FRAME_DATA;
  H2_FRAME_HEADERS =
    nextpas.core.http.impl.h2.frame.H2_FRAME_HEADERS;
  H2_FRAME_PRIORITY =
    nextpas.core.http.impl.h2.frame.H2_FRAME_PRIORITY;
  H2_FRAME_RST_STREAM =
    nextpas.core.http.impl.h2.frame.H2_FRAME_RST_STREAM;
  H2_FRAME_SETTINGS =
    nextpas.core.http.impl.h2.frame.H2_FRAME_SETTINGS;
  H2_FRAME_PUSH_PROMISE =
    nextpas.core.http.impl.h2.frame.H2_FRAME_PUSH_PROMISE;
  H2_FRAME_PING =
    nextpas.core.http.impl.h2.frame.H2_FRAME_PING;
  H2_FRAME_GOAWAY =
    nextpas.core.http.impl.h2.frame.H2_FRAME_GOAWAY;
  H2_FRAME_WINDOW_UPDATE =
    nextpas.core.http.impl.h2.frame.H2_FRAME_WINDOW_UPDATE;
  H2_FRAME_CONTINUATION =
    nextpas.core.http.impl.h2.frame.H2_FRAME_CONTINUATION;

  H2_FLAG_DATA_END_STREAM =
    nextpas.core.http.impl.h2.frame.H2_FLAG_DATA_END_STREAM;
  H2_FLAG_DATA_PADDED =
    nextpas.core.http.impl.h2.frame.H2_FLAG_DATA_PADDED;

  H2_FLAG_HEADERS_END_STREAM =
    nextpas.core.http.impl.h2.frame.H2_FLAG_HEADERS_END_STREAM;
  H2_FLAG_HEADERS_END_HEADERS =
    nextpas.core.http.impl.h2.frame.H2_FLAG_HEADERS_END_HEADERS;
  H2_FLAG_HEADERS_PADDED =
    nextpas.core.http.impl.h2.frame.H2_FLAG_HEADERS_PADDED;
  H2_FLAG_HEADERS_PRIORITY =
    nextpas.core.http.impl.h2.frame.H2_FLAG_HEADERS_PRIORITY;

  H2_FLAG_SETTINGS_ACK =
    nextpas.core.http.impl.h2.frame.H2_FLAG_SETTINGS_ACK;
  H2_FLAG_PING_ACK =
    nextpas.core.http.impl.h2.frame.H2_FLAG_PING_ACK;

  H2_FLAG_PUSH_PROMISE_END_HEADERS =
    nextpas.core.http.impl.h2.frame.H2_FLAG_PUSH_PROMISE_END_HEADERS;
  H2_FLAG_PUSH_PROMISE_PADDED =
    nextpas.core.http.impl.h2.frame.H2_FLAG_PUSH_PROMISE_PADDED;

  H2_FLAG_CONTINUATION_END_HEADERS =
    nextpas.core.http.impl.h2.frame.H2_FLAG_CONTINUATION_END_HEADERS;

  H2_ERR_NO_ERROR =
    nextpas.core.http.impl.h2.frame.H2_ERR_NO_ERROR;
  H2_ERR_PROTOCOL_ERROR =
    nextpas.core.http.impl.h2.frame.H2_ERR_PROTOCOL_ERROR;
  H2_ERR_INTERNAL_ERROR =
    nextpas.core.http.impl.h2.frame.H2_ERR_INTERNAL_ERROR;
  H2_ERR_FLOW_CONTROL_ERROR =
    nextpas.core.http.impl.h2.frame.H2_ERR_FLOW_CONTROL_ERROR;
  H2_ERR_SETTINGS_TIMEOUT =
    nextpas.core.http.impl.h2.frame.H2_ERR_SETTINGS_TIMEOUT;
  H2_ERR_STREAM_CLOSED =
    nextpas.core.http.impl.h2.frame.H2_ERR_STREAM_CLOSED;
  H2_ERR_FRAME_SIZE_ERROR =
    nextpas.core.http.impl.h2.frame.H2_ERR_FRAME_SIZE_ERROR;
  H2_ERR_REFUSED_STREAM =
    nextpas.core.http.impl.h2.frame.H2_ERR_REFUSED_STREAM;
  H2_ERR_CANCEL =
    nextpas.core.http.impl.h2.frame.H2_ERR_CANCEL;
  H2_ERR_COMPRESSION_ERROR =
    nextpas.core.http.impl.h2.frame.H2_ERR_COMPRESSION_ERROR;
  H2_ERR_CONNECT_ERROR =
    nextpas.core.http.impl.h2.frame.H2_ERR_CONNECT_ERROR;
  H2_ERR_ENHANCE_YOUR_CALM =
    nextpas.core.http.impl.h2.frame.H2_ERR_ENHANCE_YOUR_CALM;
  H2_ERR_INADEQUATE_SECURITY =
    nextpas.core.http.impl.h2.frame.H2_ERR_INADEQUATE_SECURITY;
  H2_ERR_HTTP_1_1_REQUIRED =
    nextpas.core.http.impl.h2.frame.H2_ERR_HTTP_1_1_REQUIRED;

  H2_CLIENT_PREFACE =
    nextpas.core.http.impl.h2.frame.H2_CLIENT_PREFACE;

type
  TH2StreamState = (
    h2ssIdle,
    h2ssReservedLocal,
    h2ssReservedRemote,
    h2ssOpen,
    h2ssHalfClosedLocal,
    h2ssHalfClosedRemote,
    h2ssClosed
  );

  { Effective negotiated SETTINGS values. MaxConcurrentStreams and
    MaxHeaderListSize use 0 to represent the RFC default "no explicit limit". }
  TH2Settings = record
    HeaderTableSize: UInt32;
    EnablePush: Boolean;
    MaxConcurrentStreams: UInt32;
    InitialWindowSize: UInt32;
    MaxFrameSize: UInt32;
    MaxHeaderListSize: UInt32;
    class function Default: TH2Settings; static;
    procedure Validate;
    procedure ApplyPeerSettings(const ASettings: TH2Settings);
  end;

  TH2ServerTransportOptions = record
    MaxConcurrentStreams: UInt32;
    InitialStreamWindowSize: UInt32;
    InitialConnectionWindowSize: UInt32;
    HeaderTableSize: UInt32;
    MaxFrameSize: UInt32;
    MaxHeaderListSize: UInt32;
    MaxBodySize: UInt32;
    ReadTimeout: Int64;
    WriteTimeout: Int64;
    IdleTimeout: Int64;
    ReadIdleTimeout: Int64;
    PingTimeout: Int64;
    class function Default: TH2ServerTransportOptions; static;
    procedure Validate;
    function ToSettings: TH2Settings;
  end;

  TH2ClientTransportOptions = record
    Timeout: Int64;
    MaxPoolSize: Int32;
    HeaderTableSize: UInt32;
    EnablePush: Boolean;
    InitialStreamWindowSize: UInt32;
    InitialConnectionWindowSize: UInt32;
    MaxFrameSize: UInt32;
    MaxHeaderListSize: UInt32;
    PingTimeout: Int64;
    class function Default: TH2ClientTransportOptions; static;
    procedure Validate;
    function ToSettings: TH2Settings;
  end;

  { Generic flow-control bookkeeping shared by send and receive windows.
    AvailableWindow can become negative when SETTINGS_INITIAL_WINDOW_SIZE is
    reduced below bytes already in flight on an active stream. }
  TH2FlowState = record
    InitialWindowSize: UInt32;
    AvailableWindow: Int64;
    ReservedBytes: UInt32;
    InFlightBytes: UInt32;
    procedure Init(const AInitialWindowSize: UInt32);
    procedure Reset(const AInitialWindowSize: UInt32);
    function AvailableCapacity: Int64; inline;
    function UsedCapacity: UInt32; inline;
    function HasSendCapacity: Boolean; inline;
    function HasReceiveCapacity: Boolean; inline;
    function CanReserve(const ABytes: UInt32): Boolean; inline;
    function CanReceive(const ABytes: UInt32): Boolean; inline;
    function TryReserve(const ABytes: UInt32): Boolean;
    procedure ReleaseReserved(const ABytes: UInt32);
    procedure CommitSend(const ABytes: UInt32);
    procedure OnWindowUpdate(const AIncrement: UInt32);
    procedure OnDataReceived(const ABytes: UInt32);
    procedure OnDataConsumed(const ABytes: UInt32);
    procedure OnPeerInitialWindowSizeChanged(
      const ANewInitialWindowSize: UInt32);
  end;

  TH2ConnectionFlowControl = record
    SendWindow: TH2FlowState;
    RecvWindow: TH2FlowState;
    procedure Init(const ASendInitialWindowSize: UInt32;
      const ARecvInitialWindowSize: UInt32); overload;
    procedure Init(const AInitialWindowSize: UInt32); overload;
  end;

  TH2StreamFlowControl = record
    StreamID: UInt32;
    SendWindow: TH2FlowState;
    RecvWindow: TH2FlowState;
    procedure Init(const AStreamID: UInt32;
      const ASendInitialWindowSize: UInt32;
      const ARecvInitialWindowSize: UInt32); overload;
    procedure Init(const AStreamID: UInt32;
      const AInitialWindowSize: UInt32); overload;
    procedure ApplyPeerInitialWindowSize(const ANewInitialWindowSize: UInt32);
    procedure ApplyLocalInitialWindowSize(const ANewInitialWindowSize: UInt32);
  end;

implementation

procedure RaiseH2ConfigError(const AMessage: string);
begin
  raise EHttpError.Create(AMessage);
end;

procedure EnsureNonNegativeTimeout(const AValue: Int64; const AName: string);
begin
  if AValue < 0 then
    RaiseH2ConfigError('HTTP/2 ' + AName + ' must be >= 0');
end;

procedure EnsurePositivePoolSize(const AValue: Int32);
begin
  if AValue <= 0 then
    RaiseH2ConfigError('HTTP/2 client MaxPoolSize must be > 0');
end;

procedure EnsureValidInitialWindowSize(const AWindowSize: UInt32);
begin
  if AWindowSize > H2_MAX_WINDOW_SIZE then
    RaiseH2ConfigError(
      'HTTP/2 initial window size must be <= 2147483647');
end;

procedure EnsureValidConnectionWindowSize(const AWindowSize: UInt32);
begin
  if AWindowSize > H2_MAX_WINDOW_SIZE then
    RaiseH2ConfigError(
      'HTTP/2 connection window size must be <= 2147483647');
end;

procedure EnsureValidMaxFrameSize(const AMaxFrameSize: UInt32);
begin
  if (AMaxFrameSize < H2_MIN_MAX_FRAME_SIZE) or
     (AMaxFrameSize > H2_ABSOLUTE_MAX_FRAME_SIZE) then
    RaiseH2ConfigError(
      'HTTP/2 max frame size must be in [16384, 16777215]');
end;

procedure EnsureValidWindowIncrement(const AIncrement: UInt32);
begin
  if (AIncrement = 0) or (AIncrement > H2_MAX_WINDOW_SIZE) then
    RaiseH2ConfigError(
      'HTTP/2 window increment must be in [1, 2147483647]');
end;

procedure EnsureWindowNotOverflowed(const AWindowSize: Int64);
begin
  if AWindowSize > Int64(H2_MAX_WINDOW_SIZE) then
    RaiseH2ConfigError('HTTP/2 flow-control window overflow');
end;

{ TH2Settings }

class function TH2Settings.Default: TH2Settings;
begin
  Result.HeaderTableSize := H2_DEFAULT_HEADER_TABLE_SIZE;
  Result.EnablePush := H2_DEFAULT_ENABLE_PUSH;
  Result.MaxConcurrentStreams := H2_DEFAULT_MAX_CONCURRENT_STREAMS;
  Result.InitialWindowSize := H2_DEFAULT_INITIAL_WINDOW_SIZE;
  Result.MaxFrameSize := H2_DEFAULT_MAX_FRAME_SIZE;
  Result.MaxHeaderListSize := H2_DEFAULT_MAX_HEADER_LIST_SIZE;
end;

procedure TH2Settings.Validate;
begin
  EnsureValidInitialWindowSize(InitialWindowSize);
  EnsureValidMaxFrameSize(MaxFrameSize);
end;

procedure TH2Settings.ApplyPeerSettings(const ASettings: TH2Settings);
begin
  HeaderTableSize := ASettings.HeaderTableSize;
  EnablePush := ASettings.EnablePush;
  MaxConcurrentStreams := ASettings.MaxConcurrentStreams;
  InitialWindowSize := ASettings.InitialWindowSize;
  MaxFrameSize := ASettings.MaxFrameSize;
  MaxHeaderListSize := ASettings.MaxHeaderListSize;
end;

{ TH2ServerTransportOptions }

class function TH2ServerTransportOptions.Default: TH2ServerTransportOptions;
begin
  Result.MaxConcurrentStreams := 100;
  Result.InitialStreamWindowSize := H2_DEFAULT_INITIAL_WINDOW_SIZE;
  Result.InitialConnectionWindowSize := H2_DEFAULT_INITIAL_WINDOW_SIZE;
  Result.HeaderTableSize := H2_DEFAULT_HEADER_TABLE_SIZE;
  Result.MaxFrameSize := H2_DEFAULT_MAX_FRAME_SIZE;
  Result.MaxHeaderListSize := H2_DEFAULT_MAX_HEADER_LIST_SIZE;
  Result.MaxBodySize := 4194304;
  Result.ReadTimeout := 0;
  Result.WriteTimeout := 0;
  Result.IdleTimeout := 30000;
  Result.ReadIdleTimeout := 0;
  Result.PingTimeout := 5000;
end;

procedure TH2ServerTransportOptions.Validate;
begin
  EnsureValidInitialWindowSize(InitialStreamWindowSize);
  EnsureValidConnectionWindowSize(InitialConnectionWindowSize);
  EnsureValidMaxFrameSize(MaxFrameSize);
  if MaxBodySize > High(Int32) then
    RaiseH2ConfigError('HTTP/2 MaxBodySize must be <= 2147483647');
  EnsureNonNegativeTimeout(ReadTimeout, 'ReadTimeout');
  EnsureNonNegativeTimeout(WriteTimeout, 'WriteTimeout');
  EnsureNonNegativeTimeout(IdleTimeout, 'IdleTimeout');
  EnsureNonNegativeTimeout(ReadIdleTimeout, 'ReadIdleTimeout');
  EnsureNonNegativeTimeout(PingTimeout, 'PingTimeout');
end;

function TH2ServerTransportOptions.ToSettings: TH2Settings;
begin
  Validate;
  Result := TH2Settings.Default;
  Result.HeaderTableSize := HeaderTableSize;
  Result.EnablePush := False;
  Result.MaxConcurrentStreams := MaxConcurrentStreams;
  Result.InitialWindowSize := InitialStreamWindowSize;
  Result.MaxFrameSize := MaxFrameSize;
  Result.MaxHeaderListSize := MaxHeaderListSize;
  Result.Validate;
end;

{ TH2ClientTransportOptions }

class function TH2ClientTransportOptions.Default: TH2ClientTransportOptions;
begin
  Result.Timeout := 30000;
  Result.MaxPoolSize := 64;
  Result.HeaderTableSize := H2_DEFAULT_HEADER_TABLE_SIZE;
  Result.EnablePush := False;
  Result.InitialStreamWindowSize := H2_DEFAULT_INITIAL_WINDOW_SIZE;
  Result.InitialConnectionWindowSize := H2_DEFAULT_INITIAL_WINDOW_SIZE;
  Result.MaxFrameSize := H2_DEFAULT_MAX_FRAME_SIZE;
  Result.MaxHeaderListSize := H2_DEFAULT_MAX_HEADER_LIST_SIZE;
  Result.PingTimeout := 5000;
end;

procedure TH2ClientTransportOptions.Validate;
begin
  EnsurePositivePoolSize(MaxPoolSize);
  EnsureValidInitialWindowSize(InitialStreamWindowSize);
  EnsureValidConnectionWindowSize(InitialConnectionWindowSize);
  EnsureValidMaxFrameSize(MaxFrameSize);
  EnsureNonNegativeTimeout(Timeout, 'Timeout');
  EnsureNonNegativeTimeout(PingTimeout, 'PingTimeout');
end;

function TH2ClientTransportOptions.ToSettings: TH2Settings;
begin
  Validate;
  Result := TH2Settings.Default;
  Result.HeaderTableSize := HeaderTableSize;
  Result.EnablePush := EnablePush;
  Result.InitialWindowSize := InitialStreamWindowSize;
  Result.MaxFrameSize := MaxFrameSize;
  Result.MaxHeaderListSize := MaxHeaderListSize;
  Result.Validate;
end;

{ TH2FlowState }

procedure TH2FlowState.Init(const AInitialWindowSize: UInt32);
begin
  Reset(AInitialWindowSize);
end;

procedure TH2FlowState.Reset(const AInitialWindowSize: UInt32);
begin
  EnsureValidInitialWindowSize(AInitialWindowSize);
  InitialWindowSize := AInitialWindowSize;
  AvailableWindow := AInitialWindowSize;
  ReservedBytes := 0;
  InFlightBytes := 0;
end;

function TH2FlowState.AvailableCapacity: Int64;
begin
  Result := AvailableWindow;
end;

function TH2FlowState.UsedCapacity: UInt32;
begin
  Result := InFlightBytes;
end;

function TH2FlowState.HasSendCapacity: Boolean;
begin
  Result := AvailableWindow > 0;
end;

function TH2FlowState.HasReceiveCapacity: Boolean;
begin
  Result := AvailableWindow > 0;
end;

function TH2FlowState.CanReserve(const ABytes: UInt32): Boolean;
begin
  Result := (Int64(ABytes) <= AvailableWindow) and
    (ReservedBytes <= UInt32(H2_MAX_WINDOW_SIZE - ABytes));
end;

function TH2FlowState.CanReceive(const ABytes: UInt32): Boolean;
begin
  Result := Int64(ABytes) <= AvailableWindow;
end;

function TH2FlowState.TryReserve(const ABytes: UInt32): Boolean;
begin
  if ABytes = 0 then
    Exit(True);
  if not CanReserve(ABytes) then
    Exit(False);
  Dec(AvailableWindow, Int64(ABytes));
  Inc(ReservedBytes, ABytes);
  Result := True;
end;

procedure TH2FlowState.ReleaseReserved(const ABytes: UInt32);
begin
  if ABytes = 0 then
    Exit;
  if ABytes > ReservedBytes then
    RaiseH2ConfigError(
      'HTTP/2 cannot release more reserved send capacity than assigned');
  Dec(ReservedBytes, ABytes);
  Inc(AvailableWindow, Int64(ABytes));
  EnsureWindowNotOverflowed(AvailableWindow);
end;

procedure TH2FlowState.CommitSend(const ABytes: UInt32);
begin
  if ABytes = 0 then
    Exit;
  if ABytes > ReservedBytes then
    RaiseH2ConfigError(
      'HTTP/2 cannot commit more send bytes than reserved capacity');
  Dec(ReservedBytes, ABytes);
  Inc(InFlightBytes, ABytes);
end;

procedure TH2FlowState.OnWindowUpdate(const AIncrement: UInt32);
begin
  EnsureValidWindowIncrement(AIncrement);
  Inc(AvailableWindow, Int64(AIncrement));
  EnsureWindowNotOverflowed(AvailableWindow);
  if AIncrement >= InFlightBytes then
    InFlightBytes := 0
  else
    Dec(InFlightBytes, AIncrement);
end;

procedure TH2FlowState.OnDataReceived(const ABytes: UInt32);
begin
  if ABytes = 0 then
    Exit;
  if not CanReceive(ABytes) then
    RaiseH2ConfigError('HTTP/2 receive window exceeded');
  Dec(AvailableWindow, Int64(ABytes));
  Inc(InFlightBytes, ABytes);
end;

procedure TH2FlowState.OnDataConsumed(const ABytes: UInt32);
begin
  if ABytes = 0 then
    Exit;
  if ABytes > InFlightBytes then
    RaiseH2ConfigError(
      'HTTP/2 cannot release more receive capacity than pending data');
  if AvailableWindow + Int64(ABytes) > Int64(InitialWindowSize) then
    RaiseH2ConfigError('HTTP/2 receive window exceeds target window');
  Dec(InFlightBytes, ABytes);
  Inc(AvailableWindow, Int64(ABytes));
end;

procedure TH2FlowState.OnPeerInitialWindowSizeChanged(
  const ANewInitialWindowSize: UInt32);
var
  LDelta: Int64;
begin
  EnsureValidInitialWindowSize(ANewInitialWindowSize);
  LDelta := Int64(ANewInitialWindowSize) - Int64(InitialWindowSize);
  InitialWindowSize := ANewInitialWindowSize;
  Inc(AvailableWindow, LDelta);
  EnsureWindowNotOverflowed(AvailableWindow);
end;

{ TH2ConnectionFlowControl }

procedure TH2ConnectionFlowControl.Init(
  const ASendInitialWindowSize: UInt32;
  const ARecvInitialWindowSize: UInt32);
begin
  SendWindow.Init(ASendInitialWindowSize);
  RecvWindow.Init(ARecvInitialWindowSize);
end;

procedure TH2ConnectionFlowControl.Init(const AInitialWindowSize: UInt32);
begin
  Init(AInitialWindowSize, AInitialWindowSize);
end;

{ TH2StreamFlowControl }

procedure TH2StreamFlowControl.Init(const AStreamID: UInt32;
  const ASendInitialWindowSize: UInt32;
  const ARecvInitialWindowSize: UInt32);
begin
  if (AStreamID = H2_CONNECTION_STREAM_ID) or (AStreamID > H2_MAX_STREAM_ID) then
    RaiseH2ConfigError('HTTP/2 stream flow control requires a valid stream ID');
  StreamID := AStreamID;
  SendWindow.Init(ASendInitialWindowSize);
  RecvWindow.Init(ARecvInitialWindowSize);
end;

procedure TH2StreamFlowControl.Init(const AStreamID: UInt32;
  const AInitialWindowSize: UInt32);
begin
  Init(AStreamID, AInitialWindowSize, AInitialWindowSize);
end;

procedure TH2StreamFlowControl.ApplyPeerInitialWindowSize(
  const ANewInitialWindowSize: UInt32);
begin
  SendWindow.OnPeerInitialWindowSizeChanged(ANewInitialWindowSize);
end;

procedure TH2StreamFlowControl.ApplyLocalInitialWindowSize(
  const ANewInitialWindowSize: UInt32);
begin
  RecvWindow.OnPeerInitialWindowSizeChanged(ANewInitialWindowSize);
end;

end.
