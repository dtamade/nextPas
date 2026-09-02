unit nextpas.core.net.quic.h3.session;

{**
 * nextpas.core.net.quic.h3.session — H3 控制流/SETTINGS 助手（thin wrapper）
 *
 * 背景：net.quic.h3 已有 wire/QPACK 编解码，但缺会话级控制流生命周期；
 * hysteria2 PumpAuthFlow 已示范：开 uni 控制流发 SETTINGS+0x00，随后每条
 * bidi 请求流发 HEADERS-FIN。本单元将该逻辑 thin wrapper 化，供 hy2/tuic
 * 复用（不处理 DATAGRAM/Salamander/认证头组装，不管理会话池/复用策略）。
 *
 * 依赖：TQuicClientConnection 的 Loop 驱动（单线程）；错误一律 AErr: string
 * 返回，false fail-closed。幂等控制流、bidi 请求流编码后经 StreamWrite
 * (FIN) 由 conn 泵出，不直接操作 UDP。
 *}

{$mode objfpc}{$H+}

interface

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.io.base,
  nextpas.core.async.base,
  nextpas.core.net.quic.conn,
  nextpas.core.net.quic.h3,
  nextpas.core.net.quic.varint,
  nextpas.core.net.async.tcp,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.io.intf,
  nextpas.core.async.loop,
  nextpas.core.async.cancellation,
  nextpas.core.time.deadline,
  nextpas.core.bytes.ops;

type
  { 复用 net.quic.h3 已有类型 }
  THeader = TQuicH3Header;
  TH3HeaderArray = array of THeader;

  { 为与任务描述的 IQuicSession/IQuicStream 术语对齐：当前 core 以
    TQuicClientConnection 为会话实体；此处以别名暴露，qp1 的
    nextpas.core.net.quic.session 落地后可无缝替换为接口类型。 }
  IQuicSession = TQuicClientConnection;
  IQuicStream = IAsyncTcpStream;

  TH3Session = class
  private
    FConn: TQuicClientConnection;
    FControlId: UInt64;
    FHasControl: Boolean;
    FAdapters: array of TObject; { of TH3Stream }
    procedure HandleStreamData(AStreamId: UInt64; const AData: TBytes;
      AFin: Boolean);
    procedure HandleStreamReset(AStreamId, AErrorCode: UInt64);
    function FindAdapter(AStreamId: UInt64): TObject;
    procedure RemoveAdapter(AObj: TObject);
  public
    constructor Create(ASession: IQuicSession; AHook: Boolean = True);
    destructor Destroy; override;

    {** 幂等，开 uni 控制流发 stream-type 0x00 + SETTINGS(0x04) 帧；
     *  已存在直接返回 True；失败 Reset(0x102) 并返回 False。 *}
    function EnsureControlStream(out AErr: string): Boolean;

    {** 开 bidi  请求流，编码 HEADERS 帧并以 FIN 发送；
     *  流即 IAsyncTcpStream（后续可 AsyncRead/AsyncWrite）。 *}
    function OpenRequestStream(const AHeaders: array of THeader;
      out AStream: IQuicStream; out AErr: string): Boolean; overload;
    function OpenRequestStream(const AHeaders: array of THeader;
      out AStreamId: UInt64; out AErr: string): Boolean; overload;

    property HasControl: Boolean read FHasControl;
    property ControlId: UInt64 read FControlId;
  end;

implementation

type
  TH3Stream = class(TInterfacedObject, IAsyncTcpStream)
  private
    FSession: TH3Session;
    FConn: TQuicClientConnection;
    FId: UInt64;
    FClosed: Boolean;
    FEof: Boolean;
    FRxBuf: TBytes;
    FPendBuf: Pointer;
    FPendLen: UInt32;
    FPendCb: TIoCompletion;
    FPendCtx: Pointer;
    procedure DeliverData(const AData: TBytes); inline;
    procedure MarkEof;
    function TryCompletePendingRead: Boolean;
    procedure FailPendingRead(AError: Int32);
    function TakeFromRxBuf(ABuf: Pointer; ALen: UInt32): Integer; inline;
  public
    constructor Create(ASession: TH3Session;
      AConn: TQuicClientConnection; AId: UInt64);
    { IReader/IWriter/IReadWriteCloser }
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Close;
    { ITcpStream }
    function LocalAddr: TNetAddress;
    function RemoteAddr: TNetAddress;
    procedure Shutdown;
    procedure SetNoDelay(const AValue: Boolean);
    procedure SetKeepAlive(const AValue: Boolean);
    procedure SetReadDeadline(const ADeadline: TDeadline);
    procedure SetWriteDeadline(const ADeadline: TDeadline);
    procedure SetCancelToken(const AToken: INetCancelToken);
    procedure BindCancelToken(const AToken: IAsyncCancellationToken);
    { IAsyncTcpStream }
    function AsyncRead(ABuf: Pointer; ALen: UInt32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncReadRef(ABuf: Pointer; ALen: UInt32;
      ACallback: TIoCompletionRef; AContext: Pointer = nil): Boolean;
    function AsyncWrite(ABuf: Pointer; ALen: UInt32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncWriteRef(ABuf: Pointer; ALen: UInt32;
      ACallback: TIoCompletionRef; AContext: Pointer = nil): Boolean;
    function AsyncReadTimeout(ABuf: Pointer; ALen: UInt32;
      const ADeadline: TDeadline; ACallback: TIoCompletion;
      AContext: Pointer = nil): Boolean;
    function AsyncWriteTimeout(ABuf: Pointer; ALen: UInt32;
      const ADeadline: TDeadline; ACallback: TIoCompletion;
      AContext: Pointer = nil): Boolean;
    property StreamId: UInt64 read FId;
  end;

{ TH3Session }

constructor TH3Session.Create(ASession: IQuicSession; AHook: Boolean);
begin
  inherited Create;
  FConn := TQuicClientConnection(ASession);
  FHasControl := False;
  FControlId := 0;
  SetLength(FAdapters, 0);
  if (FConn <> nil) and AHook then
  begin
    FConn.HookStreamData(@HandleStreamData);
    FConn.HookStreamReset(@HandleStreamReset);
  end;
end;

destructor TH3Session.Destroy;
var
  LI: Integer;
  LObj: TH3Stream;
begin
  for LI := 0 to High(FAdapters) do
  begin
    LObj := TH3Stream(FAdapters[LI]);
    if LObj <> nil then
      LObj.FSession := nil;
  end;
  SetLength(FAdapters, 0);
  inherited Destroy;
end;

function TH3Session.FindAdapter(AStreamId: UInt64): TObject;
var
  LI: Integer;
begin
  Result := nil;
  for LI := 0 to High(FAdapters) do
    if TH3Stream(FAdapters[LI]).FId = AStreamId then
      Exit(FAdapters[LI]);
end;

procedure TH3Session.RemoveAdapter(AObj: TObject);
var
  LI, LIdx: Integer;
begin
  LIdx := -1;
  for LI := 0 to High(FAdapters) do
    if FAdapters[LI] = AObj then
    begin
      LIdx := LI;
      Break;
    end;
  if LIdx < 0 then
    Exit;
  for LI := LIdx to High(FAdapters) - 1 do
    FAdapters[LI] := FAdapters[LI + 1];
  SetLength(FAdapters, Length(FAdapters) - 1);
end;

procedure TH3Session.HandleStreamData(AStreamId: UInt64; const AData: TBytes;
  AFin: Boolean);
var
  LAd: TH3Stream;
begin
  if (FHasControl) and (AStreamId = FControlId) then
    Exit; { 控制流下行忽略（SERVER SETTINGS 等观测面） }
  LAd := TH3Stream(FindAdapter(AStreamId));
  if LAd = nil then
    Exit;
  if Length(AData) > 0 then
    LAd.DeliverData(AData);
  if AFin then
    LAd.MarkEof;
end;

procedure TH3Session.HandleStreamReset(AStreamId, AErrorCode: UInt64);
var
  LAd: TH3Stream;
begin
  LAd := TH3Stream(FindAdapter(AStreamId));
  if LAd = nil then
    Exit;
  LAd.FClosed := True;
  LAd.FailPendingRead(-1);
end;

function TH3Session.EnsureControlStream(out AErr: string): Boolean;
var
  LSettings, LCtl: TBytes;
begin
  Result := False;
  AErr := '';
  if FHasControl then
    Exit(True);
  if FConn = nil then
  begin
    AErr := 'h3 session: nil conn';
    Exit;
  end;
  if FConn.Phase <> qcpConnected then
  begin
    AErr := 'h3 control: not connected';
    Exit;
  end;
  if not FConn.OpenStream(True, FControlId) then
  begin
    AErr := 'open control stream failed: ' + FConn.LastError;
    Exit;
  end;
  LSettings := nil;
  QuicH3SettingAppend(LSettings, cH3SettingQpackMaxTableCapacity, 0);
  QuicH3SettingAppend(LSettings, cH3SettingQpackBlockedStreams, 0);
  LCtl := nil;
  if not QuicVarintAppend(LCtl, cH3StreamControl) then
  begin
    AErr := 'varint append failed';
    FConn.StreamReset(FControlId, $102);
    Exit;
  end;
  QuicH3FrameAppend(LCtl, cH3FrameSettings, LSettings);
  if not FConn.StreamWrite(FControlId, LCtl, False) then
  begin
    AErr := 'control stream write failed: ' + FConn.LastError;
    FConn.StreamReset(FControlId, $102);
    Exit;
  end;
  FHasControl := True;
  Result := True;
end;

function TH3Session.OpenRequestStream(const AHeaders: array of THeader;
  out AStreamId: UInt64; out AErr: string): Boolean;
var
  LArr: TQuicH3HeaderArray;
  LBlock, LPayload: TBytes;
  LI: Integer;
begin
  Result := False;
  AErr := '';
  AStreamId := 0;
  if FConn = nil then
  begin
    AErr := 'h3 session: nil conn';
    Exit;
  end;
  if FConn.Phase <> qcpConnected then
  begin
    AErr := 'h3 request: not connected';
    Exit;
  end;
  if not FConn.OpenStream(False, AStreamId) then
  begin
    AErr := 'open bidi failed: ' + FConn.LastError;
    Exit;
  end;
  SetLength(LArr, Length(AHeaders));
  for LI := 0 to High(AHeaders) do
  begin
    LArr[LI].Name := AHeaders[LI].Name;
    LArr[LI].Value := AHeaders[LI].Value;
  end;
  LBlock := QuicH3EncodeHeaders(LArr);
  LPayload := nil;
  QuicH3FrameAppend(LPayload, cH3FrameHeaders, LBlock);
  if not FConn.StreamWrite(AStreamId, LPayload, True) then
  begin
    AErr := 'request stream write failed: ' + FConn.LastError;
    FConn.StreamReset(AStreamId, $102);
    Exit;
  end;
  Result := True;
end;

function TH3Session.OpenRequestStream(const AHeaders: array of THeader;
  out AStream: IQuicStream; out AErr: string): Boolean;
var
  LId: UInt64;
  LObj: TH3Stream;
begin
  Result := False;
  AStream := nil;
  AErr := '';
  if not OpenRequestStream(AHeaders, LId, AErr) then
    Exit;
  LObj := TH3Stream.Create(Self, FConn, LId);
  SetLength(FAdapters, Length(FAdapters) + 1);
  FAdapters[High(FAdapters)] := LObj;
  AStream := LObj as IQuicStream;
  Result := True;
end;

{ TH3Stream }

constructor TH3Stream.Create(ASession: TH3Session;
  AConn: TQuicClientConnection; AId: UInt64);
begin
  inherited Create;
  FSession := ASession;
  FConn := AConn;
  FId := AId;
  FClosed := False;
  FEof := False;
  FRxBuf := nil;
  FPendBuf := nil;
  FPendLen := 0;
  FPendCb := nil;
  FPendCtx := nil;
end;

function TH3Stream.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := 0;
end;

function TH3Stream.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := 0;
  raise ENextPasError.Create('h3 stream: sync write unsupported');
end;

procedure TH3Stream.Close;
var
  LSess: TH3Session;
begin
  if FClosed then
    Exit;
  FClosed := True;
  FailPendingRead(-1);
  LSess := FSession;
  FSession := nil;
  if LSess <> nil then
    LSess.RemoveAdapter(Self);
end;

function TH3Stream.LocalAddr: TNetAddress;
begin
  Result := Default(TNetAddress);
end;

function TH3Stream.RemoteAddr: TNetAddress;
begin
  Result := Default(TNetAddress);
end;

procedure TH3Stream.Shutdown;
begin
  Close;
end;

procedure TH3Stream.SetNoDelay(const AValue: Boolean);
begin
end;

procedure TH3Stream.SetKeepAlive(const AValue: Boolean);
begin
end;

procedure TH3Stream.SetReadDeadline(const ADeadline: TDeadline);
begin
end;

procedure TH3Stream.SetWriteDeadline(const ADeadline: TDeadline);
begin
end;

procedure TH3Stream.SetCancelToken(const AToken: INetCancelToken);
begin
end;

procedure TH3Stream.BindCancelToken(const AToken: IAsyncCancellationToken);
begin
end;

function TH3Stream.TakeFromRxBuf(ABuf: Pointer; ALen: UInt32): Integer; inline;
var
  LN: Integer;
  LRemain: Integer;
begin
  LN := Length(FRxBuf);
  if (LN = 0) or (ALen = 0) or (ABuf = nil) then
    Exit(0);
  if UInt32(LN) < ALen then
    ALen := UInt32(LN);
  nextpas.core.bytes.ops.BytesCopy(ABuf, @FRxBuf[0], SizeUInt(ALen)); // perf: zero-copy single source via bytes.ops.BytesCopy inline (INV-5)
  LRemain := LN - Integer(ALen);
  if LRemain > 0 then
    nextpas.core.bytes.ops.BytesCopy(@FRxBuf[0], @FRxBuf[ALen], SizeUInt(LRemain)); // perf: zero-copy single source via bytes.ops.BytesCopy inline (INV-5)
  SetLength(FRxBuf, LRemain);
  Result := Integer(ALen);
end;

procedure TH3Stream.DeliverData(const AData: TBytes); inline;
var
  LOld, LLen: Integer;
begin
  LLen := Length(AData);
  if FClosed or (LLen = 0) then
    Exit;
  LOld := Length(FRxBuf);
  if LOld + LLen > 262144 then
  begin
    FClosed := True;
    FailPendingRead(-1);
    Exit;
  end;
  nextpas.core.bytes.ops.BytesAppend(FRxBuf, AData);
  TryCompletePendingRead;
end;

procedure TH3Stream.MarkEof;
begin
  if FClosed then
    Exit;
  FEof := True;
  TryCompletePendingRead;
end;

function TH3Stream.TryCompletePendingRead: Boolean;
var
  LGot: Integer;
  LBuf: Pointer;
  LLn: UInt32;
  LCb: TIoCompletion;
  LCtx: Pointer;
begin
  Result := False;
  if FPendCb = nil then
    Exit;
  if (Length(FRxBuf) = 0) and not (FEof or FClosed) then
    Exit;
  LBuf := FPendBuf;
  LLn := FPendLen;
  LCb := FPendCb;
  LCtx := FPendCtx;
  FPendBuf := nil;
  FPendLen := 0;
  FPendCb := nil;
  FPendCtx := nil;
  LGot := TakeFromRxBuf(LBuf, LLn);
  if LGot > 0 then
    LCb(UInt64(LLn), LGot, LCtx)
  else
    LCb(UInt64(LLn), 0, LCtx);
  Result := True;
end;

procedure TH3Stream.FailPendingRead(AError: Int32);
var
  LCb: TIoCompletion;
  LCtx: Pointer;
  LLn: UInt32;
begin
  if FPendCb = nil then
    Exit;
  LCb := FPendCb;
  LCtx := FPendCtx;
  LLn := FPendLen;
  FPendCb := nil;
  FPendBuf := nil;
  FPendLen := 0;
  FPendCtx := nil;
  LCb(UInt64(LLn), AError, LCtx);
end;

function TH3Stream.AsyncRead(ABuf: Pointer; ALen: UInt32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  Result := False;
  if FClosed or (FPendCb <> nil) then
    Exit;
  FPendBuf := ABuf;
  FPendLen := ALen;
  FPendCb := ACallback;
  FPendCtx := AContext;
  TryCompletePendingRead;
  Result := True;
end;

function TH3Stream.AsyncReadRef(ABuf: Pointer; ALen: UInt32;
  ACallback: TIoCompletionRef; AContext: Pointer): Boolean;
begin
  Result := False;
end;

function TH3Stream.AsyncWrite(ABuf: Pointer; ALen: UInt32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
var
  LData: TBytes;
begin
  Result := False;
  if FClosed or (ALen = 0) then
    Exit;
  if (FConn = nil) or (FConn.Phase = qcpClosed) then
    Exit;
  SetLength(LData, ALen);
  nextpas.core.bytes.ops.BytesCopy(@LData[0], ABuf, SizeUInt(ALen)); // perf: zero-copy single source via bytes.ops.BytesCopy inline (INV-5)
  if not FConn.StreamWrite(FId, LData, False) then
    Exit;
  ACallback(UInt64(ALen), Integer(ALen), AContext);
  Result := True;
end;

function TH3Stream.AsyncWriteRef(ABuf: Pointer; ALen: UInt32;
  ACallback: TIoCompletionRef; AContext: Pointer): Boolean;
begin
  Result := False;
end;

function TH3Stream.AsyncReadTimeout(ABuf: Pointer; ALen: UInt32;
  const ADeadline: TDeadline; ACallback: TIoCompletion;
  AContext: Pointer): Boolean;
begin
  Result := AsyncRead(ABuf, ALen, ACallback, AContext);
end;

function TH3Stream.AsyncWriteTimeout(ABuf: Pointer; ALen: UInt32;
  const ADeadline: TDeadline; ACallback: TIoCompletion;
  AContext: Pointer): Boolean;
begin
  Result := AsyncWrite(ABuf, ALen, ACallback, AContext);
end;

end.
