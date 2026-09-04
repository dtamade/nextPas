unit nextpas.core.net.quic.session;

{**
 * @desc QUIC 会话薄封装（Q-pre/L2）：IQuicSession/IQuicStream。
 *       单线程事件循环驱动（TAsyncLoop），薄透传 TQuicClientConnection
 *       + IAsyncUdpSocket + TQuicStreamMux；泵胶水对齐
 *       proxy888/src/pp888/egress/pp888.egress.hysteria2.pas 的
 *       KickQuicStart/DnsCb/SendDgram/RecvCb/ArmRecv/ScheduleTick 模板，
 *       但不吸 H3/Salamander 语义。
 * @note Thread safety: 单线程使用；所有方法仅在 owning TAsyncLoop 线程调用。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.time,
  nextpas.core.base,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.io.base,
  nextpas.core.io.intf,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.async.base,
  nextpas.core.async.loop,
  nextpas.core.async.cancellation,
  nextpas.core.net.async.udp,
  nextpas.core.net.async.resolve,
  nextpas.core.net.resolve,
  nextpas.core.net.async.tcp,
  nextpas.core.net.quic.conn,
  nextpas.core.net.quic.stream;

const
  cQuicSessionDefaultAlpn    = 'h3';
  cQuicSessionDefaultIdleMs  = 30000;
  cQuicSessionDefaultTickMs  = 50;
  cQuicSessionMaxStreamsPerConn = 256;
  cQuicSessionSendBufCap     = 262144;
  cQuicSessionDgramQueueCap  = 32;
  cQuicSessionPacketRoom     = 1100;

type
  TQuicSessionState = (
    qssIdle,
    qssResolving,
    qssConnecting,
    qssConnected,
    qssClosed
  );

  TQuicSessionError = (
    qeOk = 0,
    qeClosed,
    qeResolving,
    qeTimeout,
    qeHandshakeFailed,
    qeDgramUnsupported,
    qeDgramTooLarge,
    qeDgramQueueFull,
    qeStreamLimit,
    qeSendBlocked,
    qeIoFailed
  );

  TOnQuicDatagram = nextpas.core.net.quic.conn.TOnQuicDatagram;
  TOnQuicSessionClosed = procedure(const AReason: string) of object;
  TOnQuicWritable = procedure of object;

  TQuicSessionParams = record
    Loop: TAsyncLoop;
    ServerHost: string;
    ServerPort: UInt16;
    QuicParams: TQuicClientParams;
    BindAddr: string;
    TickIntervalMs: UInt32;
    ObfsPassword: string;
    class function Create(const ALoop: TAsyncLoop; const AHost: string;
      APort: UInt16): TQuicSessionParams; static;
    function Normalized: TQuicSessionParams;
  end;

  IQuicStream = interface(IAsyncTcpStream)
  ['{B7A1C2D3-E4F5-4A6B-8C9D-010000000031}']
    function StreamId: UInt64;
    function IsUnidirectional: Boolean;
    procedure Reset(AErrorCode: UInt64);
    procedure InjectData(const AData: TBytes; AFin: Boolean);
  end;

  IQuicSession = interface
  ['{A7B8C9D0-E1F2-4A3B-9C8D-020000000031}']
    function Connect(const AParams: TQuicSessionParams): TQuicSessionError;
    procedure Close;
    function State: TQuicSessionState;
    function ConnState: TQuicConnPhase;
    function LastError: string;
    function LocalAddr: TNetAddress;
    function PeerAddr: TNetAddress;
    function OpenStream(AUnidirectional: Boolean;
      out AStream: IQuicStream): TQuicSessionError;
    function StreamCount: Integer;
    function SendDatagram(const AData: TBytes): TQuicSessionError;
    procedure HookDatagram(AHandler: TOnQuicDatagram);
    function ExportKeyingMaterial(const ALabel: TBytes; const AContext: TBytes;
      ALength: Integer): TBytes;
    function ExportKeyingMaterialStr(const ALabel: string; const AContext: string;
      ALength: Integer): TBytes;
    function DatagramSupported: Boolean;
    function PeerMaxDatagramSize: Integer;
    function PeerParamsValid: Boolean;
    function CongestionWindow: UInt64;
    function InFlightBytes: Integer;
    function DebugState: string;
    function IdleMs: UInt64;
    procedure HookClosed(AHandler: TOnQuicSessionClosed);
    procedure HookWritable(AHandler: TOnQuicWritable);
    function UnderlyingConn: TQuicClientConnection;
    function UnderlyingUdp: IAsyncUdpSocket;
    function FindStream(AStreamId: UInt64): IQuicStream;
    procedure Pump;
  end;

function CreateQuicSession(const ALoop: TAsyncLoop): IQuicSession;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.net.quic.varint,
  nextpas.core.hash.blake2b,
  nextpas.core.crypto.random;

type
  TQuicSession = class;
  TQuicStreamAdapter = class;

  PDnsCtx = ^TDnsCtx;
  TDnsCtx = record
    Sess: TQuicSession;
  end;

  PSendCtx = ^TSendCtx;
  TSendCtx = record
    Buf: TBytes;
  end;

  TQuicStreamAdapter = class(TInterfacedObject, IReader, IWriter,
    IReadWriteCloser, ITcpStream, ITcpSocketRuntime, ITcpStreamRuntime,
    IAsyncTcpStream, IQuicStream)
  private
    FSession: TQuicSession;
    FStreamId: UInt64;
    FClosed: Boolean;
    FEof: Boolean;
    FRxBuf: TBytes;
    FPendRdBuf: Pointer;
    FPendRdLen: UInt32;
    FPendRdCb: TIoCompletion;
    FPendRdCtx: Pointer;
    procedure DeliverData(const AData: TBytes; AFin: Boolean);
    function TryCompletePendingRead: Boolean;
    procedure FailPendingRead(AErr: Int32);
    function TakeFromRx(ALen: UInt32; ADst: Pointer): Integer;
  public
    constructor Create(ASession: TQuicSession; AStreamId: UInt64);
    destructor Destroy; override;
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
    { ITcpSocketRuntime }
    function NativeSocketHandle: PtrUInt;
    procedure SetBlocking(const ABlocking: Boolean);
    { ITcpStreamRuntime }
    function TryRead(var ABuf; const ACount: SizeUInt;
      out ARead: SizeUInt): TTcpStreamIOResult;
    function TryWrite(const ABuf; const ACount: SizeUInt;
      out AWritten: SizeUInt): TTcpStreamIOResult;
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
    { IQuicStream }
    function StreamId: UInt64;
    function IsUnidirectional: Boolean;
    procedure Reset(AErrorCode: UInt64);
    procedure InjectData(const AData: TBytes; AFin: Boolean);
    procedure NotifyEof;
    procedure NotifyReset;
  end;

  TQuicSession = class(TInterfacedObject, IQuicSession)
  private
    FLoop: TAsyncLoop;
    FUdp: IAsyncUdpSocket;
    FConn: TQuicClientConnection;
    FState: TQuicSessionState;
    FParams: TQuicSessionParams;
    FPeerAddr: TNetAddress;
    FDnsCtx: PDnsCtx;
    FOutTmp: TBytes;
    FRxBuf: array[0..2047] of Byte;
    FRecvArmed: Boolean;
    FTickScheduled: Boolean;
    FLastActiveMs: UInt64;
    FStreams: array of TQuicStreamAdapter;
    FOnClosed: TOnQuicSessionClosed;
    FOnWritable: TOnQuicWritable;
    FLastError: string;
    procedure MarkClosed(const AReason: string);
    procedure KickQuicStart;
    procedure DrainOutbound;
    procedure SendDgram(const ADgram: TBytes);
    procedure ArmRecv;
    procedure ScheduleTick;
    procedure DoTick;
    procedure HandleStreamData(AStreamId: UInt64; const AData: TBytes;
      AFin: Boolean);
    procedure HandleStreamReset(AStreamId, AErrorCode: UInt64);
    procedure HandleDatagram(const AData: TBytes);
    procedure CheckConnPhase;
    function FindAdapter(AStreamId: UInt64): TQuicStreamAdapter;
    procedure UnregisterAdapter(AAdapter: TQuicStreamAdapter);
    class procedure DnsCb(const AResult: TDnsResult; AContext: Pointer); static;
    class procedure TickCb(AContext: Pointer); static;
    class procedure RecvCb(AResult: Int32; ABytes: Int32;
      const AFrom: TNetAddress; AContext: Pointer); static;
    class procedure SentCb(AResult: Int32; ABytes: Int32;
      AContext: Pointer); static;
    class function NowUs: UInt64; static;
  public
    constructor Create(const ALoop: TAsyncLoop);
    destructor Destroy; override;
    function Connect(const AParams: TQuicSessionParams): TQuicSessionError;
    procedure Close;
    function State: TQuicSessionState;
    function ConnState: TQuicConnPhase;
    function LastError: string;
    function LocalAddr: TNetAddress;
    function PeerAddr: TNetAddress;
    function OpenStream(AUnidirectional: Boolean;
      out AStream: IQuicStream): TQuicSessionError;
    function StreamCount: Integer;
    function SendDatagram(const AData: TBytes): TQuicSessionError;
    procedure HookDatagram(AHandler: TOnQuicDatagram);
    function ExportKeyingMaterial(const ALabel: TBytes; const AContext: TBytes;
      ALength: Integer): TBytes;
    function ExportKeyingMaterialStr(const ALabel: string; const AContext: string;
      ALength: Integer): TBytes;
    function DatagramSupported: Boolean;
    function PeerMaxDatagramSize: Integer;
    function PeerParamsValid: Boolean;
    function CongestionWindow: UInt64;
    function InFlightBytes: Integer;
    function DebugState: string;
    function IdleMs: UInt64;
    procedure HookClosed(AHandler: TOnQuicSessionClosed);
    procedure HookWritable(AHandler: TOnQuicWritable);
    function UnderlyingConn: TQuicClientConnection;
    function UnderlyingUdp: IAsyncUdpSocket;
    function FindStream(AStreamId: UInt64): IQuicStream;
    procedure Pump;
  end;

{ TQuicSessionParams }

class function TQuicSessionParams.Create(const ALoop: TAsyncLoop;
  const AHost: string; APort: UInt16): TQuicSessionParams;
begin
  Result := Default(TQuicSessionParams);
  Result.Loop := ALoop;
  Result.ServerHost := AHost;
  Result.ServerPort := APort;
  Result.QuicParams := Default(TQuicClientParams);
  Result.QuicParams.Hostname := StripHostBrackets(AHost);
  Result.QuicParams.ALPN := cQuicSessionDefaultAlpn;
  Result.BindAddr := '';
  Result.TickIntervalMs := cQuicSessionDefaultTickMs;
end;

function TQuicSessionParams.Normalized: TQuicSessionParams;
begin
  Result := Self;
  if Result.QuicParams.ALPN = '' then
    Result.QuicParams.ALPN := cQuicSessionDefaultAlpn;
  if Result.TickIntervalMs = 0 then
    Result.TickIntervalMs := cQuicSessionDefaultTickMs;
end;

{ TQuicStreamAdapter }

constructor TQuicStreamAdapter.Create(ASession: TQuicSession;
  AStreamId: UInt64);
begin
  inherited Create;
  FSession := ASession;
  FStreamId := AStreamId;
  FClosed := False;
  FEof := False;
end;

destructor TQuicStreamAdapter.Destroy;
begin
  inherited Destroy;
end;

function TQuicStreamAdapter.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := 0;
end;

function TQuicStreamAdapter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := 0;
  raise EInvalidOperation.Create('quic stream: sync write unsupported');
end;

procedure TQuicStreamAdapter.Close;
var
  LSess: TQuicSession;
begin
  if FClosed then
    Exit;
  FClosed := True;
  FailPendingRead(-5);
  LSess := FSession;
  FSession := nil;
  if LSess <> nil then
    LSess.UnregisterAdapter(Self);
end;

function TQuicStreamAdapter.LocalAddr: TNetAddress;
begin
  Result := Default(TNetAddress);
end;

function TQuicStreamAdapter.RemoteAddr: TNetAddress;
begin
  Result := Default(TNetAddress);
end;

procedure TQuicStreamAdapter.Shutdown;
begin
  Close;
end;

procedure TQuicStreamAdapter.SetNoDelay(const AValue: Boolean);
begin
end;

procedure TQuicStreamAdapter.SetKeepAlive(const AValue: Boolean);
begin
end;

procedure TQuicStreamAdapter.SetReadDeadline(const ADeadline: TDeadline);
begin
end;

procedure TQuicStreamAdapter.SetWriteDeadline(const ADeadline: TDeadline);
begin
end;

procedure TQuicStreamAdapter.SetCancelToken(const AToken: INetCancelToken);
begin
end;

procedure TQuicStreamAdapter.BindCancelToken(
  const AToken: IAsyncCancellationToken);
begin
end;

function TQuicStreamAdapter.NativeSocketHandle: PtrUInt;
begin
  Result := 0;
end;

procedure TQuicStreamAdapter.SetBlocking(const ABlocking: Boolean);
begin
end;

function TQuicStreamAdapter.TryRead(var ABuf; const ACount: SizeUInt;
  out ARead: SizeUInt): TTcpStreamIOResult;
begin
  ARead := 0;
  Result := tsiorWouldBlock;
end;

function TQuicStreamAdapter.TryWrite(const ABuf; const ACount: SizeUInt;
  out AWritten: SizeUInt): TTcpStreamIOResult;
begin
  AWritten := 0;
  Result := tsiorWouldBlock;
end;

function TQuicStreamAdapter.AsyncRead(ABuf: Pointer; ALen: UInt32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  Result := False;
  if FClosed or (FPendRdCb <> nil) then
    Exit;
  if not Assigned(ACallback) then
    Exit;
  FPendRdBuf := ABuf;
  FPendRdLen := ALen;
  FPendRdCb := ACallback;
  FPendRdCtx := AContext;
  TryCompletePendingRead;
  Result := True;
end;

function TQuicStreamAdapter.AsyncReadRef(ABuf: Pointer; ALen: UInt32;
  ACallback: TIoCompletionRef; AContext: Pointer): Boolean;
begin
  Result := False;
end;

function TQuicStreamAdapter.AsyncWrite(ABuf: Pointer; ALen: UInt32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
var
  LData: TBytes;
  LSess: TQuicSession;
  LOk: Boolean;
begin
  Result := False;
  if FClosed or (ALen = 0) then
    Exit;
  LSess := FSession;
  if (LSess = nil) or (LSess.FState = qssClosed) then
    Exit;
  if LSess.FConn = nil then
    Exit;
  SetLength(LData, ALen);
  Move(PByte(ABuf)^, LData[0], ALen);
  LOk := LSess.FConn.StreamWrite(FStreamId, LData, False);
  if not LOk then
    Exit;
  LSess.FConn.OnTimer(TQuicSession.NowUs);
  LSess.DrainOutbound;
  if Assigned(ACallback) then
    ACallback(UInt64(ALen), Integer(ALen), AContext);
  Result := True;
end;

function TQuicStreamAdapter.AsyncWriteRef(ABuf: Pointer; ALen: UInt32;
  ACallback: TIoCompletionRef; AContext: Pointer): Boolean;
begin
  Result := False;
end;

function TQuicStreamAdapter.AsyncReadTimeout(ABuf: Pointer; ALen: UInt32;
  const ADeadline: TDeadline; ACallback: TIoCompletion;
  AContext: Pointer): Boolean;
begin
  Result := AsyncRead(ABuf, ALen, ACallback, AContext);
end;

function TQuicStreamAdapter.AsyncWriteTimeout(ABuf: Pointer; ALen: UInt32;
  const ADeadline: TDeadline; ACallback: TIoCompletion;
  AContext: Pointer): Boolean;
begin
  Result := AsyncWrite(ABuf, ALen, ACallback, AContext);
end;

function TQuicStreamAdapter.StreamId: UInt64;
begin
  Result := FStreamId;
end;

function TQuicStreamAdapter.IsUnidirectional: Boolean;
begin
  Result := (FStreamId mod 4) = 2;
end;

procedure TQuicStreamAdapter.Reset(AErrorCode: UInt64);
var
  LSess: TQuicSession;
begin
  if FClosed then
    Exit;
  LSess := FSession;
  if (LSess = nil) or (LSess.FConn = nil) then
    Exit;
  if LSess.FConn.StreamReset(FStreamId, AErrorCode) then
  begin
    LSess.DrainOutbound;
  end;
end;

procedure TQuicStreamAdapter.InjectData(const AData: TBytes; AFin: Boolean);
begin
  DeliverData(AData, AFin);
end;

procedure TQuicStreamAdapter.DeliverData(const AData: TBytes; AFin: Boolean);
var
  LOld, LI: Integer;
begin
  if FClosed then
    Exit;
  if AFin then
    FEof := True;
  if Length(AData) > 0 then
  begin
    LOld := Length(FRxBuf);
    SetLength(FRxBuf, LOld + Length(AData));
    for LI := 0 to Length(AData) - 1 do
      FRxBuf[LOld + LI] := AData[LI];
  end;
  TryCompletePendingRead;
end;

procedure TQuicStreamAdapter.NotifyEof;
begin
  if FClosed then
    Exit;
  FEof := True;
  TryCompletePendingRead;
end;

procedure TQuicStreamAdapter.NotifyReset;
begin
  if FClosed then
    Exit;
  FClosed := True;
  FailPendingRead(-5);
end;

function TQuicStreamAdapter.TakeFromRx(ALen: UInt32; ADst: Pointer): Integer;
var
  LN, LI: Integer;
begin
  LN := Length(FRxBuf);
  if LN = 0 then
    Exit(0);
  if UInt32(LN) < ALen then
    ALen := UInt32(LN);
  Move(FRxBuf[0], ADst^, ALen);
  for LI := 0 to LN - Integer(ALen) - 1 do
    FRxBuf[LI] := FRxBuf[LI + Integer(ALen)];
  SetLength(FRxBuf, LN - Integer(ALen));
  Result := Integer(ALen);
end;

function TQuicStreamAdapter.TryCompletePendingRead: Boolean;
var
  LGot: Integer;
  LBuf: Pointer;
  LLn: UInt32;
  LCb: TIoCompletion;
  LCtx: Pointer;
begin
  Result := False;
  if FPendRdCb = nil then
    Exit;
  if (Length(FRxBuf) = 0) and not FEof then
    Exit;
  { zero-byte EOF delivery }
  LBuf := FPendRdBuf;
  LLn := FPendRdLen;
  LCb := FPendRdCb;
  LCtx := FPendRdCtx;
  FPendRdBuf := nil;
  FPendRdLen := 0;
  FPendRdCb := nil;
  FPendRdCtx := nil;
  LGot := TakeFromRx(LLn, LBuf);
  if LGot > 0 then
    LCb(UInt64(LLn), LGot, LCtx)
  else
    LCb(UInt64(LLn), 0, LCtx);
  Result := True;
end;

procedure TQuicStreamAdapter.FailPendingRead(AErr: Int32);
var
  LCb: TIoCompletion;
  LCtx: Pointer;
  LLn: UInt32;
begin
  if FPendRdCb = nil then
    Exit;
  LCb := FPendRdCb;
  LCtx := FPendRdCtx;
  LLn := FPendRdLen;
  FPendRdCb := nil;
  FPendRdBuf := nil;
  FPendRdLen := 0;
  FPendRdCtx := nil;
  LCb(UInt64(LLn), AErr, LCtx);
end;

{ TQuicSession }

constructor TQuicSession.Create(const ALoop: TAsyncLoop);
begin
  inherited Create;
  FLoop := ALoop;
  FState := qssIdle;
  FLastActiveMs := GetTickCount64;
  FRecvArmed := False;
  FTickScheduled := False;
  FDnsCtx := nil;
end;

destructor TQuicSession.Destroy;
begin
  Close;
  inherited Destroy;
end;

class function TQuicSession.NowUs: UInt64;
begin
  Result := GetTickCount64 * 1000;
end;

const
  cQuicSalamanderSaltLen = 8;

procedure QuicSalamanderPasswordBytes(const APassword: string; out AOut: TBytes);
begin
  AOut := nil;
  if Length(APassword) = 0 then Exit;
  SetLength(AOut, Length(APassword));
  Move(APassword[1], AOut[0], Length(APassword));
end;

function QuicSalamanderKey(const APassword: string; const ASalt: TBytes): TBLAKE2b256Digest;
var LCat, LPw: TBytes;
begin
  QuicSalamanderPasswordBytes(APassword, LPw);
  SetLength(LCat, Length(LPw) + Length(ASalt));
  if Length(LPw) > 0 then Move(LPw[0], LCat[0], Length(LPw));
  if Length(ASalt) > 0 then Move(ASalt[0], LCat[Length(LPw)], Length(ASalt));
  if Length(LCat) = 0 then Result := BLAKE2b256Of(LCat, 0)
  else Result := BLAKE2b256Of(LCat[0], Length(LCat));
end;

function QuicSalamanderSeal(const APassword: string; const APlain: TBytes): TBytes;
var LSalt: TBytes; LKey: TBLAKE2b256Digest; LI: Integer;
begin
  Result := nil;
  SetLength(LSalt, cQuicSalamanderSaltLen);
  if not SecureRandomBytes(@LSalt[0], cQuicSalamanderSaltLen) then Exit;
  LKey := QuicSalamanderKey(APassword, LSalt);
  SetLength(Result, cQuicSalamanderSaltLen + Length(APlain));
  Move(LSalt[0], Result[0], cQuicSalamanderSaltLen);
  for LI := 0 to Length(APlain)-1 do Result[cQuicSalamanderSaltLen+LI] := APlain[LI] xor LKey[LI mod BLAKE2B256_DIGEST_SIZE];
end;

function QuicSalamanderOpen(const APassword: string; const AWire: TBytes): TBytes;
var LSalt: TBytes; LKey: TBLAKE2b256Digest; LI, LPay: Integer;
begin
  Result := nil;
  if Length(AWire) <= cQuicSalamanderSaltLen then Exit;
  SetLength(LSalt, cQuicSalamanderSaltLen);
  Move(AWire[0], LSalt[0], cQuicSalamanderSaltLen);
  LKey := QuicSalamanderKey(APassword, LSalt);
  LPay := Length(AWire) - cQuicSalamanderSaltLen;
  SetLength(Result, LPay);
  for LI := 0 to LPay-1 do Result[LI] := AWire[cQuicSalamanderSaltLen+LI] xor LKey[LI mod BLAKE2B256_DIGEST_SIZE];
end;

procedure TQuicSession.MarkClosed(const AReason: string);
var
  LI: Integer;
  LCopy: array of TQuicStreamAdapter;
begin
  if FState = qssClosed then
    Exit;
  FState := qssClosed;
  if AReason <> '' then
    FLastError := AReason
  else if (FConn <> nil) and (FConn.LastError <> '') then
    FLastError := FConn.LastError
  else
    FLastError := AReason;
  if FDnsCtx <> nil then
  begin
    FDnsCtx^.Sess := nil;
    FDnsCtx := nil;
  end;
  { fail pending reads }
  LCopy := Copy(FStreams, 0, Length(FStreams));
  SetLength(FStreams, 0);
  for LI := 0 to High(LCopy) do
  begin
    if LCopy[LI].FSession = Self then
      LCopy[LI].FSession := nil;
    LCopy[LI].FailPendingRead(-5);
  end;
  if FConn <> nil then
  begin
    if FLastError = '' then
      FLastError := FConn.LastError;
    FreeAndNil(FConn);
  end;
  FUdp := nil;
  if Assigned(FOnClosed) then
    FOnClosed(FLastError);
end;

procedure TQuicSession.CheckConnPhase;
begin
  if (FConn <> nil) and (FConn.Phase = qcpClosed) and (FState <> qssClosed) then
    MarkClosed(FConn.LastError);
  if (FConn <> nil) and (FConn.Phase = qcpConnected) and
     (FState = qssConnecting) then
  begin
    FState := qssConnected;
    FLastActiveMs := GetTickCount64;
    if Assigned(FOnWritable) then
      FOnWritable;
  end;
end;

function TQuicSession.FindAdapter(AStreamId: UInt64): TQuicStreamAdapter;
var
  LI: Integer;
begin
  Result := nil;
  for LI := 0 to High(FStreams) do
    if FStreams[LI].StreamId = AStreamId then
      Exit(FStreams[LI]);
end;

procedure TQuicSession.UnregisterAdapter(AAdapter: TQuicStreamAdapter);
var
  LI, LJ: Integer;
begin
  for LI := 0 to High(FStreams) do
    if FStreams[LI] = AAdapter then
    begin
      for LJ := LI to High(FStreams) - 1 do
        FStreams[LJ] := FStreams[LJ + 1];
      SetLength(FStreams, Length(FStreams) - 1);
      Break;
    end;
end;

procedure TQuicSession.HandleStreamData(AStreamId: UInt64;
  const AData: TBytes; AFin: Boolean);
var
  LAd: TQuicStreamAdapter;
begin
  Inc(FLastActiveMs);
  FLastActiveMs := GetTickCount64;
  LAd := FindAdapter(AStreamId);
  if LAd = nil then
  begin
    { peer-initiated: create adapter lazily for delivery }
    if (AStreamId mod 2) <> 1 then
      Exit;
    if Length(FStreams) >= cQuicSessionMaxStreamsPerConn then
    begin
      MarkClosed('stream table beyond bound');
      Exit;
    end;
    LAd := TQuicStreamAdapter.Create(Self, AStreamId);
    SetLength(FStreams, Length(FStreams) + 1);
    FStreams[High(FStreams)] := LAd;
  end;
  LAd.DeliverData(AData, AFin);
  CheckConnPhase;
  if Assigned(FOnWritable) then
    FOnWritable;
end;

procedure TQuicSession.HandleStreamReset(AStreamId, AErrorCode: UInt64);
var
  LAd: TQuicStreamAdapter;
begin
  LAd := FindAdapter(AStreamId);
  if LAd <> nil then
    LAd.NotifyReset;
  if Assigned(FOnWritable) then
    FOnWritable;
end;

procedure TQuicSession.HandleDatagram(const AData: TBytes);
begin
  { user hook is installed on FConn directly; this is placeholder for
    future writable notification }
  if Assigned(FOnWritable) then
    FOnWritable;
end;

procedure TQuicSession.DrainOutbound;
var
  LOut: TBytes;
begin
  if FConn = nil then
    Exit;
  while FConn.TakeOutbound(LOut) do
    SendDgram(LOut);
  CheckConnPhase;
end;

procedure TQuicSession.SendDgram(const ADgram: TBytes);
var
  LCtx: PSendCtx;
  LWire: TBytes;
begin
  if (FUdp = nil) or (Length(ADgram) = 0) then
    Exit;
  New(LCtx);
  if FParams.ObfsPassword <> '' then
  begin
    LWire := QuicSalamanderSeal(FParams.ObfsPassword, ADgram);
    if Length(LWire) = 0 then begin Dispose(LCtx); Exit; end;
    LCtx^.Buf := LWire;
  end
  else
    LCtx^.Buf := Copy(ADgram, 0, Length(ADgram));
  if not FUdp.AsyncSendTo(@LCtx^.Buf[0], UInt32(Length(LCtx^.Buf)),
    FPeerAddr, @TQuicSession.SentCb, LCtx) then
    Dispose(LCtx);
end;

class procedure TQuicSession.SentCb(AResult: Int32; ABytes: Int32;
  AContext: Pointer);
begin
  if AContext <> nil then
    Dispose(PSendCtx(AContext));
end;

procedure TQuicSession.ArmRecv;
var
  LOk: Boolean;
begin
  if FRecvArmed or (FUdp = nil) or (FState = qssClosed) then
    Exit;
  FRecvArmed := True;
  LOk := FUdp.AsyncRecvFrom(@FRxBuf[0], UInt32(Length(FRxBuf)),
    @TQuicSession.RecvCb, Self);
  if not LOk then
    FRecvArmed := False;
end;

class procedure TQuicSession.RecvCb(AResult: Int32; ABytes: Int32;
  const AFrom: TNetAddress; AContext: Pointer);
var
  LSess: TQuicSession;
  LDgram: TBytes;
begin
  LSess := TQuicSession(AContext);
  LSess.FRecvArmed := False;
  if LSess.FState = qssClosed then
    Exit;
  if AResult <= 0 then
  begin
    LSess.ScheduleTick;
    LSess.ArmRecv;
    Exit;
  end;
  SetLength(LDgram, ABytes);
  Move(LSess.FRxBuf[0], LDgram[0], ABytes);
  if LSess.FParams.ObfsPassword <> '' then
  begin
    LDgram := QuicSalamanderOpen(LSess.FParams.ObfsPassword, LDgram);
    if Length(LDgram) = 0 then
    begin
      LSess.ArmRecv;
      LSess.ScheduleTick;
      Exit;
    end;
  end;
  if (LSess.FConn <> nil) and not LSess.FConn.OnDatagram(LDgram) then
  begin
    LSess.MarkClosed(LSess.FConn.LastError);
    Exit;
  end;
  LSess.FLastActiveMs := GetTickCount64;
  LSess.DrainOutbound;
  LSess.CheckConnPhase;
  LSess.ArmRecv;
  LSess.ScheduleTick;
end;

procedure TQuicSession.ScheduleTick;
begin
  if FTickScheduled or (FState = qssClosed) then
    Exit;
  if (FLoop = nil) or (not FLoop.IsValid) then
    Exit;
  FTickScheduled := True;
  FLoop.Schedule(TDuration.FromMilliseconds(Int64(FParams.TickIntervalMs)),
    @TQuicSession.TickCb, Self);
end;

class procedure TQuicSession.TickCb(AContext: Pointer);
var
  LSess: TQuicSession;
begin
  LSess := TQuicSession(AContext);
  LSess.FTickScheduled := False;
  LSess.DoTick;
end;

procedure TQuicSession.DoTick;
begin
  if FState = qssClosed then
    Exit;
  if FConn <> nil then
  begin
    FConn.OnTimer(NowUs);
    DrainOutbound;
    CheckConnPhase;
  end;
  ArmRecv;
  ScheduleTick;
end;

procedure TQuicSession.KickQuicStart;
var
  LBind: string;
begin
  if FPeerAddr.IsIPv6 then
    LBind := '::'
  else
    LBind := '0.0.0.0';
  if FParams.BindAddr <> '' then
    LBind := FParams.BindAddr;
  try
    FUdp := AsyncUdpBind(FLoop, LBind, 0);
  except
    on E: Exception do
    begin
      MarkClosed('udp bind failed: ' + E.Message);
      Exit;
    end;
  end;
  if FUdp = nil then
  begin
    MarkClosed('udp bind failed');
    Exit;
  end;
  FConn := TQuicClientConnection.Create(FParams.QuicParams);
  FConn.HookStreamData(@HandleStreamData);
  FConn.HookStreamReset(@HandleStreamReset);
  FConn.HookDatagram(@HandleDatagram);
  FConn.Start;
  FState := qssConnecting;
  DrainOutbound;
  if (FConn.Phase = qcpClosed) then
  begin
    MarkClosed(FConn.LastError);
    Exit;
  end;
  ArmRecv;
  ScheduleTick;
end;

class procedure TQuicSession.DnsCb(const AResult: TDnsResult;
  AContext: Pointer);
var
  LCtx: PDnsCtx;
  LSess: TQuicSession;
  LAddr: TNetAddress;
begin
  LCtx := PDnsCtx(AContext);
  if LCtx = nil then
    Exit;
  LSess := LCtx^.Sess;
  Dispose(LCtx);
  if (LSess = nil) or (LSess.FState = qssClosed) then
    Exit;
  LSess.FDnsCtx := nil;
  if LSess.FState <> qssResolving then
    Exit;
  if not AResult.Success then
  begin
    LSess.MarkClosed('dns resolve failed');
    Exit;
  end;
  LAddr := AResult.PreferredAddress(True);
  if LAddr.IP = '' then
  begin
    LSess.MarkClosed('dns resolve empty');
    Exit;
  end;
  LSess.FPeerAddr := LAddr.WithPort(LSess.FParams.ServerPort);
  LSess.KickQuicStart;
end;

function TQuicSession.Connect(const AParams: TQuicSessionParams): TQuicSessionError;
var
  LNorm: TQuicSessionParams;
  LBare: string;
  LDns: PDnsCtx;
begin
  if FState <> qssIdle then
  begin
    if FState = qssResolving then
      Exit(qeResolving);
    Exit(qeClosed);
  end;
  if (AParams.Loop = nil) or (not AParams.Loop.IsValid) then
    Exit(qeIoFailed);
  if AParams.ServerHost = '' then
    Exit(qeIoFailed);
  LNorm := AParams.Normalized;
  FParams := LNorm;
  FLoop := LNorm.Loop;
  LBare := StripHostBrackets(LNorm.ServerHost);
  if HostIsIpLiteral(LBare) then
  begin
    if IsIPv6Literal(LBare) then
      FPeerAddr := TNetAddress.IPv6(LBare, LNorm.ServerPort)
    else
      FPeerAddr := TNetAddress.IPv4(LBare, LNorm.ServerPort);
    KickQuicStart;
    if FState = qssClosed then
      Exit(qeIoFailed);
    Result := qeOk;
  end
  else
  begin
    FState := qssResolving;
    New(LDns);
    LDns^.Sess := Self;
    FDnsCtx := LDns;
    if not AsyncResolve(FLoop, LNorm.ServerHost, @TQuicSession.DnsCb, LDns) then
    begin
      Dispose(LDns);
      FDnsCtx := nil;
      MarkClosed('dns resolve submit failed');
      Exit(qeIoFailed);
    end;
    ScheduleTick;
    Result := qeOk;
  end;
end;

procedure TQuicSession.Close;
begin
  MarkClosed('');
end;

function TQuicSession.State: TQuicSessionState;
begin
  CheckConnPhase;
  Result := FState;
end;

function TQuicSession.ConnState: TQuicConnPhase;
begin
  if FConn <> nil then
    Result := FConn.Phase
  else if FState = qssClosed then
    Result := qcpClosed
  else
    Result := qcpIdle;
end;

function TQuicSession.LastError: string;
begin
  if FLastError <> '' then
    Result := FLastError
  else if FConn <> nil then
    Result := FConn.LastError
  else
    Result := '';
end;

function TQuicSession.LocalAddr: TNetAddress;
begin
  if FUdp <> nil then
    Result := FUdp.LocalAddr
  else
    Result := Default(TNetAddress);
end;

function TQuicSession.PeerAddr: TNetAddress;
begin
  Result := FPeerAddr;
end;

function TQuicSession.OpenStream(AUnidirectional: Boolean;
  out AStream: IQuicStream): TQuicSessionError;
var
  LId: UInt64;
  LAd: TQuicStreamAdapter;
begin
  AStream := nil;
  CheckConnPhase;
  if FState <> qssConnected then
    Exit(qeClosed);
  if FConn = nil then
    Exit(qeClosed);
  if not FConn.OpenStream(AUnidirectional, LId) then
    Exit(qeStreamLimit);
  if Length(FStreams) >= cQuicSessionMaxStreamsPerConn then
    Exit(qeStreamLimit);
  LAd := TQuicStreamAdapter.Create(Self, LId);
  SetLength(FStreams, Length(FStreams) + 1);
  FStreams[High(FStreams)] := LAd;
  AStream := LAd;
  Result := qeOk;
end;

function TQuicSession.StreamCount: Integer;
begin
  Result := Length(FStreams);
end;

function TQuicSession.SendDatagram(const AData: TBytes): TQuicSessionError;
var
  LFrameLen, LTail: Integer;
begin
  CheckConnPhase;
  if FState <> qssConnected then
    Exit(qeClosed);
  if FConn = nil then
    Exit(qeClosed);
  if not FConn.DatagramSupported then
    Exit(qeDgramUnsupported);
  LFrameLen := 1 + QuicVarintEncodedLen(UInt64(Length(AData)));
  LTail := LFrameLen + Length(AData);
  if (LTail > FConn.PeerMaxDatagramSize) or (LTail > cQuicSessionPacketRoom) then
    Exit(qeDgramTooLarge);
  if not FConn.SendDatagram(AData) then
  begin
    { distinguish queue full vs other }
    if FConn.DatagramSupported and (FConn.PeerMaxDatagramSize >= LTail) then
      Exit(qeDgramQueueFull);
    Exit(qeDgramTooLarge);
  end;
  Result := qeOk;
end;

procedure TQuicSession.HookDatagram(AHandler: TOnQuicDatagram);
begin
  if FConn <> nil then
    FConn.HookDatagram(AHandler);
end;

function TQuicSession.DatagramSupported: Boolean;
begin
  if FConn <> nil then
    Result := FConn.DatagramSupported
  else
    Result := False;
end;

function TQuicSession.PeerMaxDatagramSize: Integer;
begin
  if FConn <> nil then
    Result := FConn.PeerMaxDatagramSize
  else
    Result := 0;
end;

function TQuicSession.PeerParamsValid: Boolean;
begin
  if FConn <> nil then
    Result := FConn.PeerParamsValid
  else
    Result := False;
end;

function TQuicSession.CongestionWindow: UInt64;
begin
  if FConn <> nil then
    Result := FConn.CongestionWindow
  else
    Result := 0;
end;

function TQuicSession.InFlightBytes: Integer;
begin
  if FConn <> nil then
    Result := FConn.InFlightBytes
  else
    Result := 0;
end;

function TQuicSession.DebugState: string;
begin
  Result := 'state=' + IntToStr(Ord(FState)) +
    ' conn=' + IntToStr(Ord(ConnState)) +
    ' dgram=' + IntToStr(Ord(DatagramSupported)) +
    ' cwnd=' + IntToStr(Int64(CongestionWindow)) +
    ' inflight=' + IntToStr(InFlightBytes) +
    ' streams=' + IntToStr(Length(FStreams)) +
    ' lastError=' + LastError;
  if FConn <> nil then
    Result := Result + ' debugRx=' + FConn.DebugRx;
end;

function TQuicSession.IdleMs: UInt64;
begin
  Result := GetTickCount64 - FLastActiveMs;
end;

procedure TQuicSession.HookClosed(AHandler: TOnQuicSessionClosed);
begin
  FOnClosed := AHandler;
end;

procedure TQuicSession.HookWritable(AHandler: TOnQuicWritable);
begin
  FOnWritable := AHandler;
end;

function TQuicSession.UnderlyingConn: TQuicClientConnection;
begin
  Result := FConn;
end;

function TQuicSession.UnderlyingUdp: IAsyncUdpSocket;
begin
  Result := FUdp;
end;

procedure TQuicSession.Pump;
begin
  if FConn <> nil then
  begin
    FConn.OnTimer(NowUs);
    DrainOutbound;
    CheckConnPhase;
  end;
end;

function TQuicSession.ExportKeyingMaterial(const ALabel: TBytes; const AContext: TBytes;
  ALength: Integer): TBytes;
begin
  Result := nil;
  if FConn <> nil then
    Result := FConn.ExportKeyingMaterial(ALabel, AContext, ALength);
end;

function TQuicSession.ExportKeyingMaterialStr(const ALabel: string; const AContext: string;
  ALength: Integer): TBytes;
var
  LLabelB, LCtxB: TBytes;
begin
  Result := nil;
  SetLength(LLabelB, Length(ALabel));
  if Length(ALabel) > 0 then Move(ALabel[1], LLabelB[0], Length(ALabel));
  SetLength(LCtxB, Length(AContext));
  if Length(AContext) > 0 then Move(AContext[1], LCtxB[0], Length(AContext));
  Result := ExportKeyingMaterial(LLabelB, LCtxB, ALength);
end;

function TQuicSession.FindStream(AStreamId: UInt64): IQuicStream;
var
  LI: Integer;
begin
  Result := nil;
  for LI := 0 to High(FStreams) do
    if FStreams[LI].StreamId = AStreamId then
      Exit(FStreams[LI] as IQuicStream);
end;

function CreateQuicSession(const ALoop: TAsyncLoop): IQuicSession;
begin
  Result := TQuicSession.Create(ALoop);
end;

end.
