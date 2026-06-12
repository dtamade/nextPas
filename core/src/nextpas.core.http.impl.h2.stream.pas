unit nextpas.core.http.impl.h2.stream;
{**
 * @desc HTTP/2 per-stream state machine and flow-control bookkeeping.
 *       Handles RFC 9113 stream state transitions, HEADERS/CONTINUATION
 *       assembly, HPACK decode, buffered DATA intake, and body-reader
 *       consumption that releases stream and connection receive credits.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.http.intf,
  nextpas.core.http.impl.h2.hpack,
  nextpas.core.http.impl.h2.types;

type
  IH2BodyReader = interface(IReader)
    ['{A1B2C3D4-E5F6-7890-ABCD-500000020001}']
    function GetStreamID: UInt32;
    property StreamID: UInt32 read GetStreamID;
  end;

  TH2Stream = class(TInterfacedObject, IH2StreamControl)
  private
    FStreamID: UInt32;
    FState: TH2StreamState;
    FSendFlow: TH2FlowState;
    FRecvFlow: TH2FlowState;
    FHeaderFragments: array of AnsiString;
    FHeaderBlock: AnsiString;
    FHeaderStore: TObject;
    FHeadersDecoded: IHttpHeaders;
    FBodyBuffer: TBytes;
    FBodyReadPos: SizeInt;
    FEndStreamReceived: Boolean;
    FEndStreamSent: Boolean;
    FEndHeadersReceived: Boolean;
    FResetCode: UInt32;
    FResetReceived: Boolean;
    FRequestHandled: Boolean;
    FPendingStreamWindowUpdate: UInt32;
    FPendingConnectionWindowUpdate: UInt32;
    FPendingResponseBody: IStream;
    FConnectionFlow: ^TH2ConnectionFlowControl;
    FDecoder: ^THPackDecoder;
    procedure AppendHeaderFragment(const AFragment: AnsiString);
    procedure ClearPendingHeaderBlock;
    procedure FinalizeHeaders;
    procedure AppendBodyData(const APayload: AnsiString);
    procedure ConsumeBodyBytes(const ABytes: UInt32);
    procedure ApplyRemoteOpenState;
    procedure ApplyRemoteEndStream;
    procedure ApplyLocalEndStream;
    procedure InternalReset(const AErrorCode: UInt32);
    function ExtractHeadersFragment(const AFlags: Byte;
      const APayload: AnsiString; out AFragment: AnsiString): Boolean;
    function ExtractDataPayload(const AFlags: Byte;
      const APayload: AnsiString; out AData: AnsiString): Boolean;
    function IsWritableState: Boolean; inline;
    function CanReceiveRemoteData: Boolean; inline;
    function UnreadBodyBytes: UInt32; inline;
  public
    constructor Create(const AStreamID: UInt32;
      const ASendWindowSize: UInt32; const ARecvWindowSize: UInt32;
      var AConnectionFlow: TH2ConnectionFlowControl;
      var ADecoder: THPackDecoder);
    destructor Destroy; override;

    procedure Reset(const AErrorCode: UInt32);
    function GetStreamID: UInt32;

    procedure OnHeaders(const AFlags: Byte; const APayload: AnsiString);
    procedure OnContinuation(const AFlags: Byte; const APayload: AnsiString);
    procedure OnData(const AFlags: Byte; const APayload: AnsiString);
    procedure OnRstStream(const AErrorCode: UInt32);
    procedure OnWindowUpdate(const AIncrement: UInt32);
    procedure ApplyPeerInitialWindowSize(const ANewInitialWindowSize: UInt32);

    function IsRequestReady: Boolean;
    function RequestHandled: Boolean;
    procedure MarkRequestHandled;
    function CanWriteData: Boolean;
    function HasCapacity: Boolean;
    function AvailableSendCapacity: UInt32;

    procedure ReserveSendCapacity(const ABytes: UInt32);
    procedure CommitSend(const ABytes: UInt32);
    procedure MarkEndStreamSent;
    function CreateBodyReader: IH2BodyReader;
    procedure DiscardUnreadBody;
    procedure SetPendingResponseBody(const ABody: IStream);
    function GetPendingResponseBody: IStream;
    function HasPendingResponseBody: Boolean;
    procedure ClearPendingResponseBody;
    function TakePendingStreamWindowUpdate: UInt32;
    function TakePendingConnectionWindowUpdate: UInt32;

    property StreamID: UInt32 read FStreamID;
    property State: TH2StreamState read FState;
    property Headers: IHttpHeaders read FHeadersDecoded;
    property BodyBuffer: TBytes read FBodyBuffer;
    property EndStreamReceived: Boolean read FEndStreamReceived;
    property EndStreamSent: Boolean read FEndStreamSent;
    property ResetReceived: Boolean read FResetReceived;
    property ResetCode: UInt32 read FResetCode;
  end;

implementation

uses
  SysUtils,
  nextpas.core.http.headers;

type
  TH2BodyReader = class(TInterfacedObject, IH2BodyReader)
  private
    FStream: TH2Stream;
  public
    constructor Create(const AStream: TH2Stream);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    function GetStreamID: UInt32;
  end;

function MinSizeUInt(const ALeft, ARight: SizeUInt): SizeUInt; inline;
begin
  if ALeft < ARight then
    Result := ALeft
  else
    Result := ARight;
end;

function HeaderStoreAsConcrete(const AStore: TObject): THttpHeaders; inline;
begin
  Result := THttpHeaders(AStore);
end;

{ TH2BodyReader }

constructor TH2BodyReader.Create(const AStream: TH2Stream);
begin
  inherited Create;
  FStream := AStream;
end;

function TH2BodyReader.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LAvailable: SizeUInt;
begin
  Result := 0;
  if (FStream = nil) or (ACount = 0) then
    Exit;
  if FStream.FBodyReadPos >= Length(FStream.FBodyBuffer) then
    Exit;

  LAvailable := SizeUInt(Length(FStream.FBodyBuffer) - FStream.FBodyReadPos);
  Result := MinSizeUInt(ACount, LAvailable);
  if Result = 0 then
    Exit;

  Move(FStream.FBodyBuffer[FStream.FBodyReadPos], ABuf, Result);
  Inc(FStream.FBodyReadPos, SizeInt(Result));
  FStream.ConsumeBodyBytes(UInt32(Result));
end;

function TH2BodyReader.GetStreamID: UInt32;
begin
  if FStream = nil then
    Exit(0);
  Result := FStream.StreamID;
end;

{ TH2Stream }

constructor TH2Stream.Create(const AStreamID: UInt32;
  const ASendWindowSize: UInt32; const ARecvWindowSize: UInt32;
  var AConnectionFlow: TH2ConnectionFlowControl;
  var ADecoder: THPackDecoder);
begin
  inherited Create;
  FStreamID := AStreamID;
  FState := h2ssIdle;
  FSendFlow.Init(ASendWindowSize);
  FRecvFlow.Init(ARecvWindowSize);
  FConnectionFlow := @AConnectionFlow;
  FDecoder := @ADecoder;
  FHeaderStore := nil;
  FHeadersDecoded := nil;
  FHeaderFragments := nil;
  FHeaderBlock := '';
  FBodyBuffer := nil;
  FBodyReadPos := 0;
  FEndStreamReceived := False;
  FEndStreamSent := False;
  FEndHeadersReceived := False;
  FResetCode := H2_ERR_NO_ERROR;
  FResetReceived := False;
  FRequestHandled := False;
  FPendingStreamWindowUpdate := 0;
  FPendingConnectionWindowUpdate := 0;
  FPendingResponseBody := nil;
end;

destructor TH2Stream.Destroy;
begin
  ClearPendingHeaderBlock;
  FHeadersDecoded := nil;
  FHeaderStore := nil;
  FBodyBuffer := nil;
  FPendingResponseBody := nil;
  inherited Destroy;
end;

procedure TH2Stream.AppendHeaderFragment(const AFragment: AnsiString);
var
  LLen: SizeInt;
begin
  LLen := Length(FHeaderFragments);
  SetLength(FHeaderFragments, LLen + 1);
  FHeaderFragments[LLen] := AFragment;
end;

procedure TH2Stream.ClearPendingHeaderBlock;
begin
  FHeaderFragments := nil;
  FHeaderBlock := '';
  FEndHeadersReceived := False;
end;

procedure TH2Stream.FinalizeHeaders;
var
  LHeaders: array of THPackHeader;
  LIndex: SizeInt;
  LTotalLen: SizeInt;
  LWritePos: SizeInt;
begin
  LTotalLen := 0;
  for LIndex := 0 to High(FHeaderFragments) do
    Inc(LTotalLen, Length(FHeaderFragments[LIndex]));

  SetLength(FHeaderBlock, LTotalLen);
  LWritePos := 1;
  for LIndex := 0 to High(FHeaderFragments) do
  begin
    if FHeaderFragments[LIndex] = '' then
      Continue;
    Move(FHeaderFragments[LIndex][1], FHeaderBlock[LWritePos],
      Length(FHeaderFragments[LIndex]));
    Inc(LWritePos, Length(FHeaderFragments[LIndex]));
  end;

  SetLength(LHeaders, Length(FHeaderBlock));
  if (FDecoder = nil) or not FDecoder^.Decode(FHeaderBlock, LHeaders) then
  begin
    InternalReset(H2_ERR_COMPRESSION_ERROR);
    Exit;
  end;

  if FHeaderStore = nil then
  begin
    FHeaderStore := THttpHeaders.Create;
    FHeadersDecoded := HeaderStoreAsConcrete(FHeaderStore);
  end;

  for LIndex := 0 to High(LHeaders) do
  begin
    if LHeaders[LIndex].Name = '' then
      Break;
    HeaderStoreAsConcrete(FHeaderStore).AddParsed(string(LHeaders[LIndex].Name),
      string(LHeaders[LIndex].Value));
  end;

  FEndHeadersReceived := True;
  FHeaderFragments := nil;
end;

procedure TH2Stream.AppendBodyData(const APayload: AnsiString);
var
  LOldLen: SizeInt;
  LPayloadLen: SizeInt;
begin
  LPayloadLen := Length(APayload);
  if LPayloadLen = 0 then
    Exit;
  LOldLen := Length(FBodyBuffer);
  SetLength(FBodyBuffer, LOldLen + LPayloadLen);
  Move(APayload[1], FBodyBuffer[LOldLen], LPayloadLen);
end;

procedure TH2Stream.ConsumeBodyBytes(const ABytes: UInt32);
begin
  if ABytes = 0 then
    Exit;
  try
    FRecvFlow.OnDataConsumed(ABytes);
    if FPendingStreamWindowUpdate <= High(UInt32) - ABytes then
      Inc(FPendingStreamWindowUpdate, ABytes)
    else
      FPendingStreamWindowUpdate := High(UInt32);
    if FConnectionFlow <> nil then
    begin
      FConnectionFlow^.RecvWindow.OnDataConsumed(ABytes);
      if FPendingConnectionWindowUpdate <= High(UInt32) - ABytes then
        Inc(FPendingConnectionWindowUpdate, ABytes)
      else
        FPendingConnectionWindowUpdate := High(UInt32);
    end;
  except
    InternalReset(H2_ERR_FLOW_CONTROL_ERROR);
  end;
end;

procedure TH2Stream.ApplyRemoteOpenState;
begin
  case FState of
    h2ssIdle:
      FState := h2ssOpen;
    h2ssReservedLocal:
      FState := h2ssHalfClosedRemote;
  else
    { keep current state }
  end;
end;

procedure TH2Stream.ApplyRemoteEndStream;
begin
  FEndStreamReceived := True;
  case FState of
    h2ssIdle:
      FState := h2ssHalfClosedRemote;
    h2ssReservedLocal:
      FState := h2ssHalfClosedRemote;
    h2ssOpen:
      FState := h2ssHalfClosedRemote;
    h2ssHalfClosedLocal:
      FState := h2ssClosed;
  else
    { keep current state }
  end;
end;

procedure TH2Stream.ApplyLocalEndStream;
begin
  FEndStreamSent := True;
  case FState of
    h2ssIdle:
      FState := h2ssHalfClosedLocal;
    h2ssReservedRemote:
      FState := h2ssHalfClosedLocal;
    h2ssOpen:
      FState := h2ssHalfClosedLocal;
    h2ssHalfClosedRemote:
      FState := h2ssClosed;
  else
    { keep current state }
  end;
end;

procedure TH2Stream.InternalReset(const AErrorCode: UInt32);
var
  LUnread: UInt32;
  LReserved: UInt32;
begin
  LReserved := FSendFlow.ReservedBytes;
  if LReserved > 0 then
  begin
    try
      FSendFlow.ReleaseReserved(LReserved);
      if FConnectionFlow <> nil then
        FConnectionFlow^.SendWindow.ReleaseReserved(LReserved);
    except
      { swallow bookkeeping errors: stream reset should not raise outward }
    end;
  end;

  LUnread := UnreadBodyBytes;
  if LUnread > 0 then
    ConsumeBodyBytes(LUnread);

  FRecvFlow.Reset(FRecvFlow.InitialWindowSize);
  FSendFlow.Reset(FSendFlow.InitialWindowSize);
  FBodyBuffer := nil;
  FBodyReadPos := 0;
  ClearPendingHeaderBlock;
  FResetCode := AErrorCode;
  FResetReceived := True;
  FRequestHandled := True;
  FPendingStreamWindowUpdate := 0;
  FPendingConnectionWindowUpdate := 0;
  FPendingResponseBody := nil;
  FState := h2ssClosed;
end;

function TH2Stream.ExtractHeadersFragment(const AFlags: Byte;
  const APayload: AnsiString; out AFragment: AnsiString): Boolean;
var
  LPadLength: SizeInt;
  LStart: SizeInt;
  LFragmentLen: SizeInt;
begin
  Result := False;
  AFragment := '';
  LStart := 1;
  LPadLength := 0;

  if (AFlags and H2_FLAG_HEADERS_PADDED) <> 0 then
  begin
    if Length(APayload) < 1 then
      Exit;
    LPadLength := Byte(APayload[1]);
    Inc(LStart);
  end;

  if (AFlags and H2_FLAG_HEADERS_PRIORITY) <> 0 then
  begin
    if Length(APayload) < LStart + 4 then
      Exit;
    Inc(LStart, 5);
  end;

  LFragmentLen := Length(APayload) - LStart + 1 - LPadLength;
  if LFragmentLen < 0 then
    Exit;
  if LFragmentLen > 0 then
    AFragment := Copy(APayload, LStart, LFragmentLen);
  Result := True;
end;

function TH2Stream.ExtractDataPayload(const AFlags: Byte;
  const APayload: AnsiString; out AData: AnsiString): Boolean;
var
  LPadLength: SizeInt;
begin
  Result := False;
  AData := '';
  if (AFlags and H2_FLAG_DATA_PADDED) = 0 then
  begin
    AData := APayload;
    Exit(True);
  end;

  if Length(APayload) < 1 then
    Exit;
  LPadLength := Byte(APayload[1]);
  if Length(APayload) < 1 + LPadLength then
    Exit;
  if Length(APayload) > 1 + LPadLength then
    AData := Copy(APayload, 2, Length(APayload) - 1 - LPadLength);
  Result := True;
end;

function TH2Stream.IsWritableState: Boolean; inline;
begin
  Result := FState in [h2ssOpen, h2ssHalfClosedRemote];
end;

function TH2Stream.CanReceiveRemoteData: Boolean; inline;
begin
  Result := FState in [h2ssOpen, h2ssHalfClosedLocal];
end;

function TH2Stream.UnreadBodyBytes: UInt32; inline;
begin
  if FBodyReadPos >= Length(FBodyBuffer) then
    Exit(0);
  Result := UInt32(Length(FBodyBuffer) - FBodyReadPos);
end;

procedure TH2Stream.Reset(const AErrorCode: UInt32);
begin
  InternalReset(AErrorCode);
end;

function TH2Stream.GetStreamID: UInt32;
begin
  Result := FStreamID;
end;

procedure TH2Stream.OnHeaders(const AFlags: Byte; const APayload: AnsiString);
var
  LFragment: AnsiString;
begin
  if FResetReceived or (FState = h2ssClosed) then
    Exit;
  if not FEndHeadersReceived and (Length(FHeaderFragments) > 0) then
  begin
    InternalReset(H2_ERR_PROTOCOL_ERROR);
    Exit;
  end;
  if not ExtractHeadersFragment(AFlags, APayload, LFragment) then
  begin
    InternalReset(H2_ERR_PROTOCOL_ERROR);
    Exit;
  end;

  FHeaderBlock := '';
  FHeaderFragments := nil;
  AppendHeaderFragment(LFragment);
  FEndHeadersReceived := False;
  ApplyRemoteOpenState;

  if (AFlags and H2_FLAG_HEADERS_END_HEADERS) <> 0 then
    FinalizeHeaders;

  if (AFlags and H2_FLAG_HEADERS_END_STREAM) <> 0 then
    ApplyRemoteEndStream;
end;

procedure TH2Stream.OnContinuation(const AFlags: Byte; const APayload: AnsiString);
begin
  if FResetReceived or (FState = h2ssClosed) then
    Exit;
  if FEndHeadersReceived or (Length(FHeaderFragments) = 0) then
  begin
    InternalReset(H2_ERR_PROTOCOL_ERROR);
    Exit;
  end;

  AppendHeaderFragment(APayload);
  if (AFlags and H2_FLAG_CONTINUATION_END_HEADERS) <> 0 then
    FinalizeHeaders;
end;

procedure TH2Stream.OnData(const AFlags: Byte; const APayload: AnsiString);
var
  LData: AnsiString;
  LDataLen: UInt32;
begin
  if FResetReceived or (FState = h2ssClosed) then
    Exit;
  if not CanReceiveRemoteData then
    Exit;
  if not ExtractDataPayload(AFlags, APayload, LData) then
  begin
    InternalReset(H2_ERR_PROTOCOL_ERROR);
    Exit;
  end;

  LDataLen := UInt32(Length(LData));
  if LDataLen > 0 then
  begin
    if not FRecvFlow.CanReceive(LDataLen) then
    begin
      InternalReset(H2_ERR_FLOW_CONTROL_ERROR);
      Exit;
    end;
    if (FConnectionFlow <> nil) and
       (not FConnectionFlow^.RecvWindow.CanReceive(LDataLen)) then
    begin
      InternalReset(H2_ERR_FLOW_CONTROL_ERROR);
      Exit;
    end;
    try
      FRecvFlow.OnDataReceived(LDataLen);
      if FConnectionFlow <> nil then
        FConnectionFlow^.RecvWindow.OnDataReceived(LDataLen);
      AppendBodyData(LData);
    except
      InternalReset(H2_ERR_FLOW_CONTROL_ERROR);
      Exit;
    end;
  end;

  if (AFlags and H2_FLAG_DATA_END_STREAM) <> 0 then
    ApplyRemoteEndStream;
end;

procedure TH2Stream.OnRstStream(const AErrorCode: UInt32);
begin
  InternalReset(AErrorCode);
end;

procedure TH2Stream.OnWindowUpdate(const AIncrement: UInt32);
begin
  if FResetReceived or (FState = h2ssClosed) then
    Exit;
  try
    FSendFlow.OnWindowUpdate(AIncrement);
  except
    InternalReset(H2_ERR_FLOW_CONTROL_ERROR);
  end;
end;

procedure TH2Stream.ApplyPeerInitialWindowSize(const ANewInitialWindowSize: UInt32);
begin
  if FResetReceived or (FState = h2ssClosed) then
    Exit;
  try
    FSendFlow.OnPeerInitialWindowSizeChanged(ANewInitialWindowSize);
  except
    InternalReset(H2_ERR_FLOW_CONTROL_ERROR);
  end;
end;

function TH2Stream.IsRequestReady: Boolean;
begin
  Result := FEndHeadersReceived and (FHeadersDecoded <> nil) and
    FEndStreamReceived;
end;

function TH2Stream.RequestHandled: Boolean;
begin
  Result := FRequestHandled;
end;

procedure TH2Stream.MarkRequestHandled;
begin
  FRequestHandled := True;
end;

function TH2Stream.CanWriteData: Boolean;
begin
  Result := IsWritableState and (not FEndStreamSent) and HasCapacity;
end;

function TH2Stream.HasCapacity: Boolean;
begin
  Result := FSendFlow.HasSendCapacity and
    ((FConnectionFlow = nil) or FConnectionFlow^.SendWindow.HasSendCapacity);
end;

function TH2Stream.AvailableSendCapacity: UInt32;
var
  LStreamCapacity: Int64;
  LConnCapacity: Int64;
begin
  LStreamCapacity := FSendFlow.AvailableCapacity;
  if FConnectionFlow <> nil then
    LConnCapacity := FConnectionFlow^.SendWindow.AvailableCapacity
  else
    LConnCapacity := LStreamCapacity;
  if LStreamCapacity < LConnCapacity then
    LConnCapacity := LStreamCapacity;
  if LConnCapacity <= 0 then
    Exit(0);
  if LConnCapacity > High(UInt32) then
    Exit(High(UInt32));
  Result := UInt32(LConnCapacity);
end;

procedure TH2Stream.ReserveSendCapacity(const ABytes: UInt32);
begin
  if (ABytes = 0) or not IsWritableState or FEndStreamSent then
    Exit;
  if not FSendFlow.TryReserve(ABytes) then
    Exit;
  if (FConnectionFlow <> nil) and
     (not FConnectionFlow^.SendWindow.TryReserve(ABytes)) then
  begin
    try
      FSendFlow.ReleaseReserved(ABytes);
    except
      InternalReset(H2_ERR_INTERNAL_ERROR);
    end;
  end;
end;

procedure TH2Stream.CommitSend(const ABytes: UInt32);
begin
  if (ABytes = 0) or FResetReceived or (FState = h2ssClosed) then
    Exit;
  try
    FSendFlow.CommitSend(ABytes);
    if FConnectionFlow <> nil then
      FConnectionFlow^.SendWindow.CommitSend(ABytes);
  except
    InternalReset(H2_ERR_INTERNAL_ERROR);
  end;
end;

procedure TH2Stream.MarkEndStreamSent;
begin
  if FResetReceived or (FState = h2ssClosed) then
    Exit;
  ApplyLocalEndStream;
end;

function TH2Stream.CreateBodyReader: IH2BodyReader;
begin
  Result := TH2BodyReader.Create(Self);
end;

procedure TH2Stream.DiscardUnreadBody;
var
  LUnread: UInt32;
begin
  LUnread := UnreadBodyBytes;
  if LUnread = 0 then
    Exit;
  FBodyReadPos := Length(FBodyBuffer);
  ConsumeBodyBytes(LUnread);
end;

procedure TH2Stream.SetPendingResponseBody(const ABody: IStream);
begin
  FPendingResponseBody := ABody;
end;

function TH2Stream.GetPendingResponseBody: IStream;
begin
  Result := FPendingResponseBody;
end;

function TH2Stream.HasPendingResponseBody: Boolean;
begin
  Result := FPendingResponseBody <> nil;
end;

procedure TH2Stream.ClearPendingResponseBody;
begin
  FPendingResponseBody := nil;
end;

function TH2Stream.TakePendingStreamWindowUpdate: UInt32;
begin
  Result := FPendingStreamWindowUpdate;
  FPendingStreamWindowUpdate := 0;
end;

function TH2Stream.TakePendingConnectionWindowUpdate: UInt32;
begin
  Result := FPendingConnectionWindowUpdate;
  FPendingConnectionWindowUpdate := 0;
end;

end.
