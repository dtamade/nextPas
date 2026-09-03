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
  nextpas.core.http.impl.h2.frame,
  nextpas.core.http.impl.h2.hpack,
  nextpas.core.http.impl.h2.types;

type
  TH2HeaderFinalizeResult = (
    h2hfrNone,
    h2hfrOk,
    h2hfrCompressionError,
    h2hfrProtocolError,
    h2hfrHeaderListTooLarge
  );

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
    FHeaderBlockTotalBytes: SizeInt;
    FFragmentCount: SizeInt;
    FEmptyFragmentCount: SizeInt;
    FHeaderStore: TObject;
    FHeadersDecoded: IHttpHeaders;
    FTrailerStore: TObject;
    FTrailersDecoded: IHttpHeaders;
    FBodyBuffer: TBytes;
    FBodyReadPos: SizeInt;
    FEndStreamReceived: Boolean;
    FEndStreamSent: Boolean;
    FEndHeadersReceived: Boolean;
    FTrailerSectionReceived: Boolean;
    FResetCode: UInt32;
    FResetReceived: Boolean;
    FRequestHandled: Boolean;
    FPendingStreamWindowUpdate: UInt32;
    FPendingConnectionWindowUpdate: UInt32;
    FPendingResponseBody: IStream;
    FConnectionFlow: ^TH2ConnectionFlowControl;
    FDecoder: ^THPackDecoder;
    FMaxHeaderListSize: UInt32;
    FLastHeaderFinalizeResult: TH2HeaderFinalizeResult;
    function AppendHeaderFragment(const AFragment: AnsiString): Boolean;
    procedure ClearPendingHeaderBlock;
    function FinalizeHeaders: TH2HeaderFinalizeResult;
    procedure AppendBodyData(const APayload: AnsiString);
    procedure ConsumeBodyBytes(const ABytes: UInt32);
    procedure ApplyRemoteOpenState;
    procedure ApplyRemoteEndStream;
    procedure ApplyLocalEndStream;
    procedure InternalReset(const AErrorCode: UInt32);
    function IsWritableState: Boolean; inline;
    function CanReceiveRemoteData: Boolean; inline;
    function UnreadBodyBytes: UInt32; inline;
  public
    constructor Create(const AStreamID: UInt32;
      const ASendWindowSize: UInt32; const ARecvWindowSize: UInt32;
      var AConnectionFlow: TH2ConnectionFlowControl;
      var ADecoder: THPackDecoder;
      const AMaxHeaderListSize: UInt32 = H2_DEFAULT_MAX_HEADER_LIST_SIZE);
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
    property Trailers: IHttpHeaders read FTrailersDecoded;
    property BodyBuffer: TBytes read FBodyBuffer;
    property EndStreamReceived: Boolean read FEndStreamReceived;
    property EndStreamSent: Boolean read FEndStreamSent;
    property ResetReceived: Boolean read FResetReceived;
    property ResetCode: UInt32 read FResetCode;
    property LastHeaderFinalizeResult: TH2HeaderFinalizeResult
      read FLastHeaderFinalizeResult;
  end;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.http.headers;

const
  { Maximum total bytes for HEADERS + CONTINUATION fragments before
    rejecting.  64 KB is generous for legitimate header blocks; an
    attacker sending unlimited CONTINUATION frames would hit this. }
  H2_MAX_HEADER_BLOCK_BYTES: SizeInt = 64 * 1024;
  { Maximum number of CONTINUATION fragments per header block.
    Prevents DoS via many tiny fragments that waste memory allocation calls. }
  H2_MAX_HEADER_FRAGMENTS: SizeInt = 512;
  { Maximum number of empty CONTINUATION fragments.
    Prevents DoS via many empty frames that don't contribute to the header block. }
  H2_MAX_EMPTY_FRAGMENTS: SizeInt = 64;
  { Absolute ceiling on the *decoded* header-list size (RFC 7541 §4.1 units),
    enforced regardless of the advertised SETTINGS_MAX_HEADER_LIST_SIZE (which
    defaults to 0 = "no explicit limit").  A compact HPACK block can decompress
    far past its wire size via repeated indexed references to a large dynamic-
    table entry (RFC 7541 §10.5 amplification); this hard backstop caps the
    materialized cost.  1 MB is generous for legitimate traffic, which the
    64 KB compressed-block limit already bounds to ~64 KB decoded. }
  H2_HEADER_LIST_HARD_LIMIT: UInt64 = 1024 * 1024;

  H2_FORBIDDEN_CONNECTION_HEADERS: array[0..4] of AnsiString = (
    'connection',
    'upgrade',
    'keep-alive',
    'proxy-connection',
    'transfer-encoding'
  );

  H2_FORBIDDEN_TRAILER_HEADERS: array[0..4] of AnsiString = (
    'content-length',
    'transfer-encoding',
    'host',
    'te',
    'trailer'
  );

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

function ByteSpanEquals(const ASpan: TH2ByteSpan; const AValue: AnsiString): Boolean;
var
  LI: SizeInt;
begin
  if ASpan.Len <> Length(AValue) then
    Exit(False);
  if ASpan.Len = 0 then
    Exit(True);
  if ASpan.Ptr = nil then
    Exit(False);
  for LI := 0 to ASpan.Len - 1 do
    if ASpan.Ptr[LI] <> AValue[LI + 1] then
      Exit(False);
  Result := True;
end;

{ RFC 9113 §8.2: field names MUST be lowercase. Returns False if any byte is A-Z. }
function H2HeaderNameIsLowercase(const AName: TH2ByteSpan): Boolean;
var
  LI: SizeInt;
begin
  if AName.Ptr = nil then
    Exit(True);
  for LI := 0 to AName.Len - 1 do
    if (AName.Ptr[LI] >= 'A') and (AName.Ptr[LI] <= 'Z') then
      Exit(False);
  Result := True;
end;

function ByteSpanToAnsiString(const ASpan: TH2ByteSpan): AnsiString;
begin
  if (ASpan.Ptr = nil) or (ASpan.Len <= 0) then
    Exit('');
  SetString(Result, ASpan.Ptr, ASpan.Len);
end;

function IsForbiddenConnectionHeader(const AName: TH2ByteSpan): Boolean;
var
  LI: SizeInt;
begin
  for LI := Low(H2_FORBIDDEN_CONNECTION_HEADERS) to
    High(H2_FORBIDDEN_CONNECTION_HEADERS) do
    if ByteSpanEquals(AName, H2_FORBIDDEN_CONNECTION_HEADERS[LI]) then
      Exit(True);
  Result := False;
end;

function IsValidTeHeaderValue(const AValue: TH2ByteSpan): Boolean;
begin
  Result := ByteSpanEquals(AValue, 'trailers');
end;

function IsForbiddenTrailerHeader(const AName: TH2ByteSpan): Boolean;
var
  LI: SizeInt;
begin
  if IsForbiddenConnectionHeader(AName) then
    Exit(True);
  for LI := Low(H2_FORBIDDEN_TRAILER_HEADERS) to
    High(H2_FORBIDDEN_TRAILER_HEADERS) do
    if ByteSpanEquals(AName, H2_FORBIDDEN_TRAILER_HEADERS[LI]) then
      Exit(True);
  Result := False;
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

  // perf: zero-copy single source via bytes.ops.BytesCopy inline (BodyBuffer -> ABuf, INV-5)
  BytesCopy(@ABuf, @FStream.FBodyBuffer[FStream.FBodyReadPos], Result);
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
  var ADecoder: THPackDecoder; const AMaxHeaderListSize: UInt32);
begin
  inherited Create;
  FStreamID := AStreamID;
  FState := h2ssIdle;
  FSendFlow.Init(ASendWindowSize);
  FRecvFlow.Init(ARecvWindowSize);
  FConnectionFlow := @AConnectionFlow;
  FDecoder := @ADecoder;
  FMaxHeaderListSize := AMaxHeaderListSize;
  FHeaderStore := nil;
  FHeadersDecoded := nil;
  FTrailerStore := nil;
  FTrailersDecoded := nil;
  FHeaderFragments := nil;
  FHeaderBlock := '';
  FHeaderBlockTotalBytes := 0;
  FBodyBuffer := nil;
  FBodyReadPos := 0;
  FEndStreamReceived := False;
  FEndStreamSent := False;
  FEndHeadersReceived := False;
  FTrailerSectionReceived := False;
  FResetCode := H2_ERR_NO_ERROR;
  FResetReceived := False;
  FRequestHandled := False;
  FPendingStreamWindowUpdate := 0;
  FPendingConnectionWindowUpdate := 0;
  FPendingResponseBody := nil;
  FMaxHeaderListSize := AMaxHeaderListSize;
  FLastHeaderFinalizeResult := h2hfrNone;
end;

destructor TH2Stream.Destroy;
begin
  ClearPendingHeaderBlock;
  FHeadersDecoded := nil;
  FHeaderStore := nil;
  FTrailersDecoded := nil;
  FTrailerStore := nil;
  FBodyBuffer := nil;
  FPendingResponseBody := nil;
  inherited Destroy;
end;

function TH2Stream.AppendHeaderFragment(const AFragment: AnsiString): Boolean;
var
  LLen: SizeInt;
begin
  LLen := Length(FHeaderFragments);
  { Track total bytes across HEADERS + all CONTINUATION fragments.
    Reject if accumulated bytes exceed limit to prevent memory exhaustion
    from unlimited CONTINUATION frames. }
  Inc(FHeaderBlockTotalBytes, Length(AFragment));
  if FHeaderBlockTotalBytes > H2_MAX_HEADER_BLOCK_BYTES then
    Exit(False);
  { Track fragment count to prevent DoS via many tiny fragments. }
  Inc(FFragmentCount);
  if FFragmentCount >= H2_MAX_HEADER_FRAGMENTS then
    Exit(False);
  { Track empty fragments separately - many empty CONTINUATION frames
    are pointless and waste processing time. }
  if Length(AFragment) = 0 then
  begin
    Inc(FEmptyFragmentCount);
    if FEmptyFragmentCount >= H2_MAX_EMPTY_FRAGMENTS then
      Exit(False);
  end;
  SetLength(FHeaderFragments, LLen + 1);
  FHeaderFragments[LLen] := AFragment;
  Result := True;
end;

procedure TH2Stream.ClearPendingHeaderBlock;
begin
  FHeaderFragments := nil;
  FHeaderBlock := '';
  FHeaderBlockTotalBytes := 0;
  FFragmentCount := 0;
  FEmptyFragmentCount := 0;
  FEndHeadersReceived := False;
end;

function TH2Stream.FinalizeHeaders: TH2HeaderFinalizeResult;
var
  LHeaders: array of THPackHeaderView;
  LIndex: SizeInt;
  LMethodSeen: Boolean;
  LSchemeSeen: Boolean;
  LPathSeen: Boolean;
  LAuthoritySeen: Boolean;
  LHostSeen: Boolean;
  LPseudoSectionClosed: Boolean;
  LIsPseudo: Boolean;
  LNameStr: AnsiString;
  LTotalLen: SizeInt;
  LValueStr: AnsiString;
  LWritePos: SizeInt;
  LTargetStore: TObject;
  LIsTrailerSection: Boolean;
  LHeaderListSize: UInt64;
begin
  Result := h2hfrNone;
  LIsTrailerSection := FHeadersDecoded <> nil;
  LTotalLen := 0;
  for LIndex := 0 to High(FHeaderFragments) do
    Inc(LTotalLen, Length(FHeaderFragments[LIndex]));

  SetLength(FHeaderBlock, LTotalLen);
  LWritePos := 1;
  for LIndex := 0 to High(FHeaderFragments) do
  begin
    if FHeaderFragments[LIndex] = '' then
      Continue;
    // perf: zero-copy single source via bytes.ops.BytesCopy inline (fragment single source INV-5)
    BytesCopy(@FHeaderBlock[LWritePos], @FHeaderFragments[LIndex][1],
      SizeUInt(Length(FHeaderFragments[LIndex])));
    Inc(LWritePos, Length(FHeaderFragments[LIndex]));
  end;

  SetLength(LHeaders, Length(FHeaderBlock));
  if (FDecoder = nil) or not FDecoder^.DecodeView(FHeaderBlock, LHeaders) then
  begin
    InternalReset(H2_ERR_COMPRESSION_ERROR);
    Exit(h2hfrCompressionError);
  end;

  if not LIsTrailerSection then
  begin
    FHeaderStore := THttpHeaders.Create;
    FHeadersDecoded := HeaderStoreAsConcrete(FHeaderStore);
    LTargetStore := FHeaderStore;
  end
  else
  begin
    if FTrailerStore = nil then
    begin
      FTrailerStore := THttpHeaders.Create;
      FTrailersDecoded := HeaderStoreAsConcrete(FTrailerStore);
    end;
    LTargetStore := FTrailerStore;
  end;

  LMethodSeen := False;
  LSchemeSeen := False;
  LPathSeen := False;
  LAuthoritySeen := False;
  LHostSeen := False;
  LPseudoSectionClosed := False;
  LHeaderListSize := 0;
  for LIndex := 0 to High(LHeaders) do
  begin
    if LHeaders[LIndex].Name.Ptr = nil then
      Break;
    LIsPseudo := (LHeaders[LIndex].Name.Len > 0) and
      (LHeaders[LIndex].Name.Ptr[0] = ':');
    if not LIsTrailerSection then
    begin
      if LIsPseudo then
      begin
        if LPseudoSectionClosed then
        begin
          InternalReset(H2_ERR_PROTOCOL_ERROR);
          Exit(h2hfrProtocolError);
        end;
        if ByteSpanEquals(LHeaders[LIndex].Name, ':method') then
        begin
          if LMethodSeen then
          begin
            InternalReset(H2_ERR_PROTOCOL_ERROR);
            Exit(h2hfrProtocolError);
          end;
          LMethodSeen := True;
        end
        else if ByteSpanEquals(LHeaders[LIndex].Name, ':scheme') then
        begin
          if LSchemeSeen then
          begin
            InternalReset(H2_ERR_PROTOCOL_ERROR);
            Exit(h2hfrProtocolError);
          end;
          LSchemeSeen := True;
        end
        else if ByteSpanEquals(LHeaders[LIndex].Name, ':path') then
        begin
          if LPathSeen then
          begin
            InternalReset(H2_ERR_PROTOCOL_ERROR);
            Exit(h2hfrProtocolError);
          end;
          LPathSeen := True;
        end
        else if ByteSpanEquals(LHeaders[LIndex].Name, ':authority') then
        begin
          if LAuthoritySeen then
          begin
            InternalReset(H2_ERR_PROTOCOL_ERROR);
            Exit(h2hfrProtocolError);
          end;
          LAuthoritySeen := True;
        end
        else
        begin
          InternalReset(H2_ERR_PROTOCOL_ERROR);
          Exit(h2hfrProtocolError);
        end;
      end
      else
      begin
        LPseudoSectionClosed := True;
        { RFC 9113 §8.2: field names MUST be lowercase }
        if not H2HeaderNameIsLowercase(LHeaders[LIndex].Name) then
        begin
          InternalReset(H2_ERR_PROTOCOL_ERROR);
          Exit(h2hfrProtocolError);
        end;
        if ByteSpanEquals(LHeaders[LIndex].Name, 'host') then
          LHostSeen := True
        else if IsForbiddenConnectionHeader(LHeaders[LIndex].Name) then
        begin
          InternalReset(H2_ERR_PROTOCOL_ERROR);
          Exit(h2hfrProtocolError);
        end
        else if ByteSpanEquals(LHeaders[LIndex].Name, 'te') and
          (not IsValidTeHeaderValue(LHeaders[LIndex].Value)) then
        begin
          InternalReset(H2_ERR_PROTOCOL_ERROR);
          Exit(h2hfrProtocolError);
        end;
      end;
    end
    else if LIsPseudo then
    begin
      InternalReset(H2_ERR_PROTOCOL_ERROR);
      Exit(h2hfrProtocolError);
    end
    else
    begin
      { RFC 9113 §8.2: field names MUST be lowercase }
      if not H2HeaderNameIsLowercase(LHeaders[LIndex].Name) then
      begin
        InternalReset(H2_ERR_PROTOCOL_ERROR);
        Exit(h2hfrProtocolError);
      end;
      if IsForbiddenTrailerHeader(LHeaders[LIndex].Name) then
      begin
        InternalReset(H2_ERR_PROTOCOL_ERROR);
        Exit(h2hfrProtocolError);
      end;
    end;

    { Accumulate the decoded header-list size unconditionally (RFC 7541 §4.1:
      name + value + 32 per field), saturating to avoid UInt64 overflow. }
    if LHeaderListSize > High(UInt64) - (UInt64(LHeaders[LIndex].Name.Len) +
       UInt64(LHeaders[LIndex].Value.Len) + 32) then
      LHeaderListSize := High(UInt64)
    else
      LHeaderListSize := LHeaderListSize + UInt64(LHeaders[LIndex].Name.Len) +
        UInt64(LHeaders[LIndex].Value.Len) + 32;
    { Reject past the absolute hard backstop (fires only on amplification, since
      the 64 KB compressed-block bound keeps legit lists far below it), or past
      the advertised soft SETTINGS_MAX_HEADER_LIST_SIZE when one is set. }
    if (LHeaderListSize > H2_HEADER_LIST_HARD_LIMIT) or
       ((FMaxHeaderListSize > 0) and (LHeaderListSize > UInt64(FMaxHeaderListSize))) then
    begin
      if not LIsTrailerSection then
      begin
        FHeaderStore := nil;
        FHeadersDecoded := nil;
      end
      else
      begin
        FTrailerStore := nil;
        FTrailersDecoded := nil;
      end;
      FHeaderFragments := nil;
      FHeaderBlock := '';
      Exit(h2hfrHeaderListTooLarge);
    end;

    SetString(LNameStr, LHeaders[LIndex].Name.Ptr, LHeaders[LIndex].Name.Len);
    SetString(LValueStr, LHeaders[LIndex].Value.Ptr, LHeaders[LIndex].Value.Len);
    HeaderStoreAsConcrete(LTargetStore).AddParsed(string(LNameStr),
      string(LValueStr));
  end;

  if (not LIsTrailerSection) and
     ((not LMethodSeen) or (not LSchemeSeen) or (not LPathSeen) or
      ((not LAuthoritySeen) and (not LHostSeen))) then
  begin
    InternalReset(H2_ERR_PROTOCOL_ERROR);
    Exit(h2hfrProtocolError);
  end;

  FEndHeadersReceived := True;
  if LIsTrailerSection then
    FTrailerSectionReceived := True;
  FHeaderFragments := nil;
  FHeaderBlock := '';
  Result := h2hfrOk;
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
  // perf: zero-copy single source via bytes.ops.BytesCopy inline (APayload -> BodyBuffer single source INV-5)
  BytesCopy(@FBodyBuffer[LOldLen], @APayload[1], SizeUInt(LPayloadLen));
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
  FTrailerSectionReceived := False;
  FState := h2ssClosed;
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
  if FEndStreamReceived then
  begin
    InternalReset(H2_ERR_PROTOCOL_ERROR);
    Exit;
  end;
  if FTrailerSectionReceived then
  begin
    InternalReset(H2_ERR_PROTOCOL_ERROR);
    Exit;
  end;
  if not FEndHeadersReceived and (Length(FHeaderFragments) > 0) then
  begin
    InternalReset(H2_ERR_PROTOCOL_ERROR);
    Exit;
  end;
  if not H2ExtractHeadersFragment(AFlags, APayload, LFragment) then
  begin
    InternalReset(H2_ERR_PROTOCOL_ERROR);
    Exit;
  end;

  FHeaderBlock := '';
  FHeaderFragments := nil;
  FHeaderBlockTotalBytes := 0;
  FLastHeaderFinalizeResult := h2hfrNone;
  if not AppendHeaderFragment(LFragment) then
  begin
    InternalReset(H2_ERR_ENHANCE_YOUR_CALM);
    Exit;
  end;
  FEndHeadersReceived := False;
  ApplyRemoteOpenState;

  if (AFlags and H2_FLAG_HEADERS_END_HEADERS) <> 0 then
    FLastHeaderFinalizeResult := FinalizeHeaders;

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

  if not AppendHeaderFragment(APayload) then
  begin
    InternalReset(H2_ERR_ENHANCE_YOUR_CALM);
    Exit;
  end;
  if (AFlags and H2_FLAG_CONTINUATION_END_HEADERS) <> 0 then
    FLastHeaderFinalizeResult := FinalizeHeaders;
end;

procedure TH2Stream.OnData(const AFlags: Byte; const APayload: AnsiString);
var
  LData: AnsiString;
  LDataLen: UInt32;
  LFrameLen: UInt32;
begin
  if FResetReceived or (FState = h2ssClosed) then
    Exit;
  if not CanReceiveRemoteData then
    Exit;
  if not H2ExtractDataPayload(AFlags, APayload, LData) then
  begin
    InternalReset(H2_ERR_PROTOCOL_ERROR);
    Exit;
  end;

  { Flow control accounts for entire frame payload including padding }
  LFrameLen := UInt32(Length(APayload));
  if LFrameLen > 0 then
  begin
    if not FRecvFlow.CanReceive(LFrameLen) then
    begin
      InternalReset(H2_ERR_FLOW_CONTROL_ERROR);
      Exit;
    end;
    if (FConnectionFlow <> nil) and
       (not FConnectionFlow^.RecvWindow.CanReceive(LFrameLen)) then
    begin
      InternalReset(H2_ERR_FLOW_CONTROL_ERROR);
      Exit;
    end;
    try
      FRecvFlow.OnDataReceived(LFrameLen);
      if FConnectionFlow <> nil then
        FConnectionFlow^.RecvWindow.OnDataReceived(LFrameLen);
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
