unit nextpas.core.net.quic.conn;

{**
 * nextpas.core.net.quic.conn — QUIC v1 客户端连接驱动（Q4：1-RTT 握手闭环）
 *
 * 组装点：tls13 消息级积木（clienthello/parser/keyschedule/appschedule/
 * finished/servercertverify + x25519）× Q1 派生 × Q2 包保护 × Q3 帧层。
 * 不经 TLS record 层——握手消息走 CRYPTO 帧，记录密封由包保护替代
 * （RFC 9001 §4.4/§5）。
 *
 * 状态机：qcpIdle → Start() → qcpInitialSent →(收 ServerInitial)→
 * qcpHandshake →(验证服务器 Finished 并发出客户端 Finished)→ qcpConnected。
 *
 * 已覆盖：
 * - Retry 处理：Retry Integrity Tag 按 RFC 9001 §5.8 完整验证
 *   （常量密钥/nonce AES-GCM 空载荷 + Pseudo-Packet AAD），验证失败丢弃；
 * - Initial 数据报按 §14.1 补齐 ≥1200 字节（PADDING 帧）；
 * - 传输参数：CH 注入 quic_transport_parameters(0x0039)（§8.2 MUST），
 *   EE 缺该扩展即 fail-closed；initial_source_connection_id 与服务器
 *   SCID 一致性校验（RFC 9000 §7.3）；
 * - CertificateVerify 恒验（transcript 绑定的服务器持钥证明）；链与主机名
 *   验证按 InsecureSkipVerify/CertVerifyHook 配置——无配置时 fail-closed
 *   （hysteria2 的 insecure/pin 开关在 egress 面接同一钩子）；
 * - 收包 ACK 范围簿记（每空间降序互斥、有界 ≤32）+ CRYPTO 未确认段
 *   OnTimer 重发（固定阈骨架，PTO 属 Q5）；
 * - CRYPTO 流重组容忍乱序（有界暂存槽），重复/重叠段去重或拒收。
 *
 * 明确不做（后续批次）：0-RTT、Key Update、连接迁移、流族帧、VN。
 *
 * @note Thread safety: 单线程使用；UDP 底座由调用方驱动（OnDatagram/
 *       TakeOutbound/OnTimer 全显式注入）。
 *}
{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.crypto.hash,
  nextpas.core.crypto.x25519,
  nextpas.core.crypto.aesgcm,
  nextpas.core.crypto.random,
  nextpas.core.exception,
  nextpas.core.tls.x509,
  nextpas.core.tls.tls13.clienthello,
  nextpas.core.tls.tls13.parser,
  nextpas.core.tls.tls13.keyschedule,
  nextpas.core.tls.tls13.appschedule,
  nextpas.core.tls.tls13.finished,
  nextpas.core.tls.tls13.servercertverify,
  nextpas.core.net.quic.varint,
  nextpas.core.net.quic.params,
  nextpas.core.net.quic.pn,
  nextpas.core.net.quic.header,
  nextpas.core.net.quic.tls,
  nextpas.core.net.quic.protect,
  nextpas.core.net.quic.frame,
  nextpas.core.net.quic.reliable,
  nextpas.core.net.quic.flow,
  nextpas.core.net.quic.congestion,
  nextpas.core.net.quic.stream;

const
  { QUIC transport parameters 扩展类型（RFC 9001 §8.2 原文定案） }
  cQuicTpExtType = $0039;
  cQuicMinInitialDgram = 1200;      { §14.1 }
  cQuicMaxRecvRangesPerSpace = 32;  { ACK 簿记有界上界 }
  cQuicMaxCryptoHolds = 16;         { 乱序暂存槽上界（fail-closed） }
  cQuicResendThresholdUs = 200000;  { 重发固定阈（骨架期，PTO 属 Q5） }
  cQuicDgramQueueCap = 32;          { 未封包数据报滞留上界（fail-closed） }
  { RFC 9221 §3 RECOMMENDED 通告值 }
  cQuicMaxDgramSizeOffer = 65535;

type
  TQuicConnPhase = (
    qcpIdle,         { 未启动 }
    qcpInitialSent,  { 首个 Client Initial 已出队 }
    qcpHandshake,    { 已见 ServerHello，Handshake 密钥可用 }
    qcpConnected,    { 1-RTT 写密钥可用，客户端 Finished 已排队 }
    qcpClosed);      { 失败/对端关闭 }

  TQuicSpace = (qspInitial, qspHandshake, qspApplication);

  { CRYPTO 流乱序暂存单槽 }
  TQuicCryptoHold = record
    Ofs: Int64;
    Data: TBytes;
  end;

  TQuicDerList = array of TBytes;

  { 自定义链验证钩子：ACerts 为 DER 列表（叶在前）。返回 False 即失败 }
  TQuicCertVerifyHook = function(const ACerts: TQuicDerList;
    out AError: string): Boolean of object;

  { RFC 9221 应用层数据报到达回调（与网络层 OnDatagram 不同层） }
  TOnQuicDatagram = procedure(const AData: TBytes) of object;

  TQuicClientParams = record
    Hostname: string;
    ALPN: string;              { 缺省 'h3'（QUIC MUST ALPN，§8.1） }
    InsecureSkipVerify: Boolean;   { 跳过链/主机名验证；CV 签名恒验 }
    CertVerifyHook: TQuicCertVerifyHook;
  end;

  { 单空间发送的 crypto 区间登记（重发判定用；按 CryptoLo 升序维护） }
  TQuicSentCryptoSpan = record
    Pn: UInt64;
    CryptoLo: UInt64;          { 本包承载的 crypto 流区间 [lo..hi) }
    CryptoHi: UInt64;
  end;

  TQuicClientConnection = class
  private
    FParams: TQuicClientParams;
    FPhase: TQuicConnPhase;
    FLastError: string;

    FLocalDcid: TBytes;        { 我方首个 Initial 的 DCID（Retry 后换新） }
    FPeerScid: TBytes;         { 服务器 SCID → 后续我方包的 DCID }
    FPeerCidSet: Boolean;
    FRetryToken: TBytes;

    FX25519Priv: TBytes;
    FX25519Pub: TBytes;

    FSuite: TQuicCipherSuite;
    FTlsSuite: Word;
    FInitialAlive: Boolean;
    FHasAppKeys: Boolean;
    FLastDropReason: string;   { 最近一次收包静默丢弃原因（诊断面） }
    FRxShortOk, FRxPeekFail, FRxOtherVer: Integer;  { 接收分类计数（诊断面） }
    FInitialKeysC, FInitialKeysS: TQuicPacketKeys;
    FHsKeysC, FHsKeysS: TQuicPacketKeys;
    FAppKeysW: TQuicPacketKeys;     { 我方 1-RTT 写 }
    FAppKeysR: TQuicPacketKeys;     { 对方 1-RTT 读 }

    FLastTimerUs: UInt64;
    FSendPn: array[TQuicSpace] of UInt64;
    FLargestRecvPn: array[TQuicSpace] of UInt64;
    FRecvRanges: array[TQuicSpace] of TQuicAckRangeArray;
    FRecvRangeCount: array[TQuicSpace] of Integer;

    FCryptoNext: array[TQuicSpace] of UInt64;   { 已重组到的偏移 }
    FCryptoHolds: array[TQuicSpace] of array of TQuicCryptoHold;
    FMsgBuf: array[TQuicSpace] of TBytes;        { 半条 TLS 消息缓存 }
    FCryptoAcked: array[TQuicSpace] of UInt64;   { 连续确认到 offset }
    FCryptoEnd: array[TQuicSpace] of UInt64;     { 我方已写到的 offset }
    FSentCryptoData: array[TQuicSpace] of TBytes; { 我方 crypto 流全文（重发源） }
    FSentSpans: array[TQuicSpace] of array of TQuicSentCryptoSpan;
    FSentSpanLastUs: array[TQuicSpace] of UInt64;

    { ---- Q5 应用平面：流复用 + 拥塞 + 应用空间可靠性 ---- }
    FMux: TQuicStreamMux;
    FReno: TQuicNewReno;
    FAppTracker: TQuicSentTracker;   { 应用空间在途簿记（STREAM 载荷包） }
    FAppRtt: TQuicRttEstimator;
    FAckDelayExponent: UInt64;       { 对端 ack_delay_exponent（钳制 ≤30） }
    FMaxAckDelayUs: UInt64;          { 对端 max_ack_delay（ms→µs） }
    FPeerParamsApplied: Boolean;     { 传输参数授予值只消费一次 }

    FTranscript: TBytes;
    FHsSecrets: TTLS13HandshakeSecrets;
    FAppSecrets: TTLS13ApplicationSecrets;
    FLeafCert: TX509Certificate;
    FPeerCerts: TQuicDerList;
    FPeerParams: TQuicTransportParamArray;
    FPeerParamsValid: Boolean;
    FDgramOut: array of TBytes;

    { ---- RFC 9221 数据报平面（应用层帧，非网络层 FDgramOut） ---- }
    FDgramEnabled: Boolean;          { 对端 TP 通告 max_datagram_frame_size>0 }
    FPeerMaxDgramSize: Integer;      { 对端允许的单帧总字节数上界 }
    FDgramQ: array[0..cQuicDgramQueueCap - 1] of TBytes;
    FDgramQCount: Integer;
    FDgramQHead: Integer;
    FOnDgram: TOnQuicDatagram;

    function GetDebugRx: string;
    function TakeError(const AMsg: string): Boolean;
    procedure HandleMuxFatal(const AReason: string);
    function GetCongestionWindow: UInt64;
    function GetInFlightBytes: Integer;
    procedure RandomBytes(out ADst: TBytes; ACount: Integer);
    procedure DeriveInitialKeys(const ADCID: TBytes);
    procedure ResetForRetry;
    function SuiteFromTls(ATlsSuite: Word;
      out ASuite: TQuicCipherSuite): Boolean;
    function BuildTransportParamsExt: TBytes;
    procedure AppendTail(var ABuf: TBytes; const ATail: TBytes);
    function PatchChExtraExtension(const ACh, AExtra: TBytes): TBytes;
    function AppendClientHello: Boolean;
    function SendSpacePacket(ASpace: TQuicSpace; const AFrames: TBytes;
      APadTo1200: Boolean): Boolean;
    function BuildLongPacket(ASpaceIsInitial: Boolean; APnLen: Integer;
      const AFrames: TBytes; APadTo1200: Boolean): TBytes;
    function BuildShortPacket(APnLen: Integer;
      const AFrames: TBytes): TBytes;
    function QueueCryptoFrames(ASpace: TQuicSpace;
      const APayload: TBytes): Boolean;
    procedure RequeueUnackedCrypto(ASpace: TQuicSpace; APadTo1200: Boolean);
    procedure RegisterSpan(ASpace: TQuicSpace; ACryptoLo,
      ACryptoHi: UInt64);
    procedure RecordRecvPn(ASpace: TQuicSpace; APn: UInt64);
    function BuildAckFrameFor(ASpace: TQuicSpace;
      out AHas: Boolean): TBytes;
    procedure SettleAckFrame(ASpace: TQuicSpace;
      const ARanges: TQuicAckRangeArray; ADelayRaw: UInt64);
    function PnInRanges(APn: UInt64;
      const ARanges: TQuicAckRangeArray): Boolean;
    procedure FeedCrypto(ASpace: TQuicSpace; AOffset: UInt64;
      const AData: TBytes);
    procedure ConsumeHolds(ASpace: TQuicSpace);
    procedure PumpMessages(ASpace: TQuicSpace);
    function PreTranscriptHash(ALastMsgLen: Integer): TBytes;
    procedure HandleMessage(AType: Byte; const AFullMsg,
      ABody: TBytes);
    procedure HandleServerHello(const AFullMsg, ABody: TBytes);
    procedure HandleEncryptedExtensions(const AFullMsg, ABody: TBytes);
    procedure HandleCertificate(const AFullMsg, ABody: TBytes);
    procedure HandleCertificateVerify(const AFullMsg, ABody: TBytes);
    procedure HandleServerFinished(const AFullMsg, ABody: TBytes);
    procedure HandleShortPacket(const APacket: TBytes);
    function HandleRetryPacket(const APacket: TBytes): Boolean;
    procedure ProcessFrames(ASpace: TQuicSpace; const APayload: TBytes);
    procedure DiscardInitialKeys;
    { Q5 应用平面 }
    procedure ApplyPeerGrantsOnce;
    procedure SettleApplicationAck(
      const ARanges: TQuicAckRangeArray; ADelayRaw: UInt64);
    procedure DetectApplicationLoss(ANowUs: UInt64);
  public
    constructor Create(const AParams: TQuicClientParams);
    destructor Destroy; override;

    procedure Start;
    function OnDatagram(const ADgram: TBytes): Boolean;
    function TakeOutbound(out ADgram: TBytes): Boolean;
    procedure OnTimer(ANowUs: UInt64);

    { ---- Q5 流应用平面 ---- }
    {** 打开本地流（受对端 MAX_STREAMS 授予门禁）；须握手完成后使用 *}
    function OpenStream(AUnidirectional: Boolean;
      out AStreamId: UInt64): Boolean;

    {** 入队流数据并立即尝试封包发出（拥塞窗/流控钳制下可能部分
      *  滞留，滞留部分由 OnTimer 驱动续发） *}
    function StreamWrite(AStreamId: UInt64; const AData: TBytes;
      AFin: Boolean): Boolean;

    {** 复位发送侧（排队 RESET_STREAM 并清空待发） *}
    function StreamReset(AStreamId, AErrorCode: UInt64): Boolean;

    {** 应用空间封包泵：控制帧+重发+新数据在拥塞窗内尽量出包。
      *  时钟基准 = 最近一次 OnTimer 的 ANowUs *}
    procedure FlushApplication;

    property Phase: TQuicConnPhase read FPhase;
    property LastError: string read FLastError;
    { 最近一次收包静默丢弃原因（诊断/取证用；成功收包时清空） }
    property LastDropReason: string read FLastDropReason;
    { 接收分类计数 short-ok/peek-fail/异版本（诊断面） }
    property DebugRx: string read GetDebugRx;
    property PeerParamsValid: Boolean read FPeerParamsValid;
    property PeerParams: TQuicTransportParamArray read FPeerParams;
    property ApplicationWriteKeys: TQuicPacketKeys read FAppKeysW;
    property ApplicationReadKeys: TQuicPacketKeys read FAppKeysR;
    { Q5 观测面：应用空间拥塞窗与复用器 }
    property CongestionWindow: UInt64 read GetCongestionWindow;
    property InFlightBytes: Integer read GetInFlightBytes;
    property Mux: TQuicStreamMux read FMux;
    { 对端 STREAM 数据回调透传（等价 Mux.OnStreamData 赋值） }
    procedure HookStreamData(AHandler: TOnStreamData);
    procedure HookStreamReset(AHandler: TOnStreamReset);

    { ---- RFC 9221 数据报平面（hysteria2 UDP 中继承载） ---- }
    {** 发送一个不可靠数据报（WITH_LENGTH 形态入队，FlushApplication
      *  出包；受拥塞控制不保证送达）。未协商/超对端上限/滞留队列满
      *  返回 False（丢弃责任在调用方重试）。 *}
    function SendDatagram(const AData: TBytes): Boolean;
    {** 对端数据报到达回调 *}
    procedure HookDatagram(AHandler: TOnQuicDatagram);
    { 对端是否通告支持数据报（EE 后生效）与单帧总字节上界 }
    property DatagramSupported: Boolean read FDgramEnabled;
    property PeerMaxDatagramSize: Integer read FPeerMaxDgramSize;
    function ExportKeyingMaterial(const ALabel: TBytes; const AContext: TBytes;
      ALength: Integer): TBytes;
    function ExportKeyingMaterialStr(const ALabel: string; const AContext: string;
      ALength: Integer): TBytes;
    property TlsSuite: Word read FTlsSuite;
    property HasAppKeys: Boolean read FHasAppKeys;
    property AppSecrets: TTLS13ApplicationSecrets read FAppSecrets;
    { 观测面：首个 Initial 的 DCID（Retry 完整性验证的 ODCID 即它） }
    property LocalFirstDcid: TBytes read FLocalDcid;
  end;

implementation

const
  cTlsSuiteAes128GcmSha256 = $1301;
  cTlsSuiteChaCha20Poly1305Sha256 = $1303;
  cTlsVersion13 = $0304;
  cMsgNewSessionTicket = 4;
  cMsgClientHello = 1;
  cMsgServerHello = 2;
  cMsgEncryptedExtensions = 8;
  cMsgCertificate = 11;
  cMsgCertificateVerify = 15;
  cMsgFinished = 20;
  cMsgKeyUpdate = 24;

  { Q5：应用空间单包帧区预算（短头≈1+SCID+PN4+tag16，留 ACK 余量） }
  cQuicAppPacketRoom = 1100;

  { RFC 9001 §5.8 原文定案的 Retry Integrity 常量（AES-128-GCM 空载荷） }
  cRetryIntegrityKey: array[0..15] of Byte = (
    $BE, $0C, $69, $0B, $9F, $66, $57, $5A,
    $1D, $76, $6B, $54, $E3, $68, $C8, $4E);
  cRetryIntegrityNonce: array[0..11] of Byte = (
    $46, $15, $99, $D3, $5D, $63, $2B, $F2, $23, $98, $25, $BB);

function ReadU24(const ABuf: TBytes; AOfs: Integer): UInt64;
begin
  Result := (UInt64(ABuf[AOfs]) shl 16) or (UInt64(ABuf[AOfs + 1]) shl 8) or
    UInt64(ABuf[AOfs + 2]);
end;

procedure AppendU24(var ABuf: TBytes; AVal: UInt64);
begin
  QuicBufAppendByte(ABuf, Byte(AVal shr 16));
  QuicBufAppendByte(ABuf, Byte(AVal shr 8));
  QuicBufAppendByte(ABuf, Byte(AVal));
end;

function SliceOf(const ABuf: TBytes; AStart, ACount: Integer): TBytes;
begin
  Result := nil;
  if (ACount <= 0) or (AStart < 0) or (AStart + ACount > Length(ABuf)) then
    Exit;
  SetLength(Result, ACount);
  Move(ABuf[AStart], Result[0], ACount);
end;

function ConstTimeEqual(const AA, AB: TBytes): Boolean;
var
  LV: Byte;
  LI: Integer;
begin
  Result := False;
  if Length(AA) <> Length(AB) then
    Exit;
  LV := 0;
  for LI := 0 to Length(AA) - 1 do
    LV := LV or (AA[LI] xor AB[LI]);
  Result := LV = 0;
end;

function WordsAt(const ABuf: TBytes; AOfs: Integer): Word;
begin
  Result := (Word(ABuf[AOfs]) shl 8) or Word(ABuf[AOfs + 1]);
end;

function BytesOfConst(const AArr: array of Byte): TBytes;
var
  LI: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AArr));
  for LI := 0 to High(AArr) do
    Result[LI] := AArr[LI];
end;

{ TQuicClientConnection }

constructor TQuicClientConnection.Create(const AParams: TQuicClientParams);
var
  LI: TQuicSpace;
begin
  inherited Create;
  FParams := AParams;
  if FParams.ALPN = '' then
    FParams.ALPN := 'h3';
  FPhase := qcpIdle;
  FInitialAlive := False;
  FHasAppKeys := False;
  FPeerParamsApplied := False;
  FMux := TQuicStreamMux.Create(cQuicDefaultFlowWindow,
    cQuicDefaultFlowWindow);
  FMux.OnFatal := @HandleMuxFatal;
  FReno := TQuicNewReno.Create(1200);
  FAppTracker := TQuicSentTracker.Create(1024);
  QuicRttInit(FAppRtt);
  for LI := Low(TQuicSpace) to High(TQuicSpace) do
  begin
    FSendPn[LI] := 0;
    FLargestRecvPn[LI] := 0;
    FRecvRangeCount[LI] := 0;
    FCryptoNext[LI] := 0;
    FCryptoAcked[LI] := 0;
    FCryptoEnd[LI] := 0;
    FSentSpanLastUs[LI] := 0;
  end;
end;

destructor TQuicClientConnection.Destroy;
begin
  FMux.Free;
  FReno.Free;
  FAppTracker.Free;
  FLeafCert.Free;
  inherited Destroy;
end;

procedure TQuicClientConnection.HandleMuxFatal(const AReason: string);
begin
  TakeError('stream fatal: ' + AReason);
end;

function TQuicClientConnection.GetCongestionWindow: UInt64;
begin
  Result := FReno.Cwnd;
end;

function TQuicClientConnection.GetInFlightBytes: Integer;
begin
  Result := FAppTracker.InFlightBytes;
end;

function TQuicClientConnection.GetDebugRx: string;
begin
  Result := 'shortOk=' + IntToStr(FRxShortOk) +
    ' peekFail=' + IntToStr(FRxPeekFail) +
    ' otherVer=' + IntToStr(FRxOtherVer) +
    ' drop="' + FLastDropReason + '"';
end;

function TQuicClientConnection.TakeError(const AMsg: string): Boolean;
begin
  if FLastError = '' then
    FLastError := AMsg;
  FPhase := qcpClosed;
  Result := False;
end;

procedure TQuicClientConnection.RandomBytes(out ADst: TBytes; ACount: Integer);
begin
  ADst := GenerateSecureRandomBytes(ACount);
end;

procedure TQuicClientConnection.DeriveInitialKeys(const ADCID: TBytes);
var
  LSec: TQuicInitialSecrets;
begin
  LSec := DeriveQuicInitialSecrets(ADCID);
  FInitialKeysC := QuicMakePacketKeys(LSec.ClientSecret, qcsAes128GcmSha256);
  FInitialKeysS := QuicMakePacketKeys(LSec.ServerSecret, qcsAes128GcmSha256);
end;

procedure TQuicClientConnection.ResetForRetry;
begin
  { RFC 9000 §7.2：Retry 后我方 Initial 包 DCID 换为 Retry 的 SCID
    （BuildLongPacket 取 FPeerScid）；RFC 9001 §5.2：Initial 密钥按新
    DCID 重派。PN/去重/在途登记作废，CH 数据本体（Acked..End）保留待重发 }
  DeriveInitialKeys(FPeerScid);
  FSendPn[qspInitial] := 0;
  FLargestRecvPn[qspInitial] := 0;
  FRecvRanges[qspInitial] := nil;
  FRecvRangeCount[qspInitial] := 0;
  { 旧密钥下的在途登记全部作废 }
  FSentSpans[qspInitial] := nil;
  FSentSpanLastUs[qspInitial] := 0;
end;

function TQuicClientConnection.SuiteFromTls(ATlsSuite: Word;
  out ASuite: TQuicCipherSuite): Boolean;
begin
  Result := True;
  case ATlsSuite of
    cTlsSuiteAes128GcmSha256:
      ASuite := qcsAes128GcmSha256;
    cTlsSuiteChaCha20Poly1305Sha256:
      ASuite := qcsChaCha20Poly1305Sha256;
  else
    Result := False;
  end;
end;

function TQuicClientConnection.BuildTransportParamsExt: TBytes;
var
  LEntries: TQuicTransportParamArray;
  LRaw: TBytes;
begin
  LEntries := nil;
  QuicParamAddVarint(LEntries, cQuicParamMaxIdleTimeout, 30000);
  QuicParamAddVarint(LEntries, cQuicParamMaxUdpPayloadSize, 1350);
  { RFC 9000 §7.3：initial_source_connection_id = 本端首个 Initial 包
    SCID 字段的值。我方客户端 SCID 恒零长 ⇒ 必须携带空值（缺省≠空，
    合规服务器按「存在且等于线头 SCID」校验——aioquic 实测拒绝缺省） }
  QuicParamAddBytes(LEntries, cQuicParamInitialSourceConnectionId,
    nil);
  QuicParamAddVarint(LEntries, cQuicParamInitialMaxData, 65536);
  QuicParamAddVarint(LEntries, cQuicParamInitialMaxStreamDataBidiLocal, 65536);
  QuicParamAddVarint(LEntries, cQuicParamInitialMaxStreamDataBidiRemote, 65536);
  QuicParamAddVarint(LEntries, cQuicParamInitialMaxStreamDataUni, 65536);
  QuicParamAddVarint(LEntries, cQuicParamInitialMaxStreamsBidi, 16);
  QuicParamAddVarint(LEntries, cQuicParamInitialMaxStreamsUni, 16);
  QuicParamAddVarint(LEntries, cQuicParamAckDelayExponent, 3);
  QuicParamAddVarint(LEntries, cQuicParamMaxAckDelay, 25);
  QuicParamAddVarint(LEntries, cQuicParamActiveConnectionIdLimit, 8);
  QuicParamAddEmpty(LEntries, cQuicParamDisableActiveMigration);
  { RFC 9221 §3：数据报支持通告（RECOMMENDED 65535） }
  QuicParamAddVarint(LEntries, cQuicParamMaxDatagramFrameSize,
    cQuicMaxDgramSizeOffer);
  LRaw := EncodeQuicTransportParams(LEntries);

  { TLS 扩展线格式：type(u16)+len(u16)+data }
  Result := nil;
  QuicBufAppendByte(Result, Byte(cQuicTpExtType shr 8));
  QuicBufAppendByte(Result, Byte(cQuicTpExtType));
  QuicBufAppendByte(Result, Byte(Length(LRaw) shr 8));
  QuicBufAppendByte(Result, Byte(Length(LRaw)));
  AppendTail(Result, LRaw);
end;

procedure TQuicClientConnection.AppendTail(var ABuf: TBytes;
  const ATail: TBytes);
var
  LN, LI: Integer;
begin
  if Length(ATail) = 0 then
    Exit;
  LN := Length(ABuf);
  SetLength(ABuf, LN + Length(ATail));
  for LI := 0 to Length(ATail) - 1 do
    ABuf[LN + LI] := ATail[LI];
end;

{ 在已构建的 CH handshake 上追加一个扩展：改 extensions_length(u16)、
  handshake length(u24)。布局：type+len24+ver2+rand32+sidlen1+sid+
  cslen2+cs+complen1+comp+extlen2+exts }
function TQuicClientConnection.PatchChExtraExtension(const ACh,
  AExtra: TBytes): TBytes;
var
  LPos, LSidLen, LCsLen, LCompLen, LExtLenPos: Integer;
  LOldLen, LNewLen: Integer;
begin
  LPos := 4;             { 过 handshake header }
  Inc(LPos, 2 + 32);     { legacy_version + random }
  LSidLen := ACh[LPos];
  Inc(LPos, 1 + LSidLen);
  LCsLen := (ACh[LPos] shl 8) or ACh[LPos + 1];
  Inc(LPos, 2 + LCsLen);
  LCompLen := ACh[LPos];
  Inc(LPos, 1 + LCompLen);
  LExtLenPos := LPos;
  LOldLen := (ACh[LExtLenPos] shl 8) or ACh[LExtLenPos + 1];

  Result := nil;
  AppendTail(Result, ACh);
  if Length(AExtra) > 0 then
  begin
    SetLength(Result, Length(Result) + Length(AExtra));
    Move(AExtra[0], Result[Length(Result) - Length(AExtra)], Length(AExtra));
  end;
  LNewLen := LOldLen + Length(AExtra);
  Result[LExtLenPos] := Byte(LNewLen shr 8);
  Result[LExtLenPos + 1] := Byte(LNewLen);

  { 重写 handshake 长度 u24（位于 1..3） }
  LNewLen := Length(Result) - 4;
  Result[1] := Byte(LNewLen shr 16);
  Result[2] := Byte(LNewLen shr 8);
  Result[3] := Byte(LNewLen);
end;

function TQuicClientConnection.AppendClientHello: Boolean;
var
  LCh: TBytes;
  LSuites: TTLS13CipherSuiteList;
begin
  GenerateX25519KeyPair(FX25519Priv, FX25519Pub);
  SetLength(LSuites, 2);
  LSuites[0] := cTlsSuiteAes128GcmSha256;
  LSuites[1] := cTlsSuiteChaCha20Poly1305Sha256;
  LCh := BuildTLS13ClientHelloHandshakeWithCiphers(FParams.Hostname,
    FParams.ALPN, FX25519Pub, LSuites, False, False, True);
  LCh := PatchChExtraExtension(LCh, BuildTransportParamsExt);
  AppendTail(FTranscript, LCh);
  Result := QueueCryptoFrames(qspInitial, LCh);
end;

function TQuicClientConnection.SendSpacePacket(ASpace: TQuicSpace;
  const AFrames: TBytes; APadTo1200: Boolean): Boolean;
var
  LDgram: TBytes;
  LN: Integer;
begin
  Result := False;
  case ASpace of
    qspInitial:
      if not FInitialAlive then
        Exit;
    qspHandshake:
      if (FPhase <> qcpHandshake) and (FPhase <> qcpConnected) then
        Exit;
    qspApplication:
      if not FHasAppKeys then
        Exit;
  end;
  if ASpace = qspApplication then
    LDgram := BuildShortPacket(4, AFrames)
  else
    LDgram := BuildLongPacket(ASpace = qspInitial, 4, AFrames, APadTo1200);
  if LDgram = nil then
    Exit;
  LN := Length(FDgramOut);
  SetLength(FDgramOut, LN + 1);
  FDgramOut[LN] := LDgram;
  FSendPn[ASpace] := FSendPn[ASpace] + 1;
  FSentSpanLastUs[ASpace] := FLastTimerUs;
  Result := True;
end;

function TQuicClientConnection.BuildLongPacket(ASpaceIsInitial: Boolean;
  APnLen: Integer; const AFrames: TBytes; APadTo1200: Boolean): TBytes;
var
  LClearHdr, LPayload, LPkt: TBytes;
  LPacketType: TQuicLongType;
  LKeys: TQuicPacketKeys;
  LPn: UInt64;
  LDcid: TBytes;
  LPad, LBodyLen, LTotal: UInt64;
  LI: Integer;
begin
  Result := nil;
  if ASpaceIsInitial then
  begin
    LPacketType := qltInitial;
    LKeys := FInitialKeysC;
    LPn := FSendPn[qspInitial];
    if FPeerCidSet then
      LDcid := FPeerScid
    else
      LDcid := FLocalDcid;
  end
  else
  begin
    LPacketType := qltHandshake;
    LKeys := FHsKeysC;
    LPn := FSendPn[qspHandshake];
    if not FPeerCidSet then
      Exit;
    LDcid := FPeerScid;
  end;

  { 明文头前缀（首字节 $FF 占位、版本、DCID、SCID、token）；
    我方 SCID 恒空（零长 CID 寻址），token 仅 Retry 后存在 }
  LClearHdr := nil;
  QuicBeginLongHeader(LClearHdr, LPacketType, cQuicVersionV1,
    LDcid, nil, FRetryToken);

  { PADDING 预算（§14.1 整包 ≥1200）。Length varint 宽度随 body 变化，
    两轮收敛迭代消除循环依赖。Length 语义 = PN+payload+tag 总长（§17.2） }
  LPad := 0;
  for LI := 0 to 2 do
  begin
    LBodyLen := UInt64(APnLen) + UInt64(Length(AFrames)) + LPad + cQuicTagLen;
    LTotal := UInt64(Length(LClearHdr)) +
      UInt64(QuicVarintEncodedLen(LBodyLen)) + LBodyLen;
    if APadTo1200 and (LTotal < cQuicMinInitialDgram) then
      LPad := cQuicMinInitialDgram - LTotal
    else if APadTo1200 and (LTotal > cQuicMinInitialDgram) and
      (LPad >= LTotal - cQuicMinInitialDgram) then
      LPad := LPad - (LTotal - cQuicMinInitialDgram)
    else
      Break;
  end;

  LPayload := nil;
  AppendTail(LPayload, AFrames);
  if LPad > 0 then
    for LI := 1 to Integer(LPad) do
      QuicBufAppendByte(LPayload, 0);   { PADDING 帧 = 单字节 0x00 }

  LBodyLen := UInt64(APnLen) + UInt64(Length(LPayload)) + cQuicTagLen;
  if LBodyLen > $3FFF then
    Exit;   { varint 宽度预算上界保护（正常远小于此值） }
  if not QuicVarintAppend(LClearHdr, LBodyLen) then
    Exit;
  LClearHdr[0] := QuicLongFirstByte(LPacketType, 0, Byte(APnLen - 1));

  LPkt := QuicProtectPacket(LClearHdr, LPn, APnLen, LPayload, LKeys);
  Result := LPkt;
end;

function TQuicClientConnection.BuildShortPacket(APnLen: Integer;
  const AFrames: TBytes): TBytes;
var
  LClearHdr, LPkt: TBytes;
  LI: Integer;
begin
  Result := nil;
  if not FPeerCidSet then
    Exit;
  { 短头首字节：固定位 1，pnlen 低 2 位；DCID = 服务器 SCID。
    KeyPhase 位恒 0（Q4 无 Key Update） }
  LClearHdr := nil;
  QuicBufAppendByte(LClearHdr, $40 or Byte(APnLen - 1));
  for LI := 0 to Length(FPeerScid) - 1 do
    QuicBufAppendByte(LClearHdr, FPeerScid[LI]);
  LPkt := QuicProtectPacket(LClearHdr, FSendPn[qspApplication], APnLen,
    AFrames, FAppKeysW);
  Result := LPkt;
end;

function TQuicClientConnection.QueueCryptoFrames(ASpace: TQuicSpace;
  const APayload: TBytes): Boolean;
var
  LFrames: TBytes;
begin
  AppendTail(FSentCryptoData[ASpace], APayload);
  RegisterSpan(ASpace, FCryptoEnd[ASpace],
    FCryptoEnd[ASpace] + UInt64(Length(APayload)));
  LFrames := nil;
  QuicCryptoAppend(LFrames, FCryptoEnd[ASpace], APayload);
  FCryptoEnd[ASpace] := FCryptoEnd[ASpace] + UInt64(Length(APayload));
  Result := SendSpacePacket(ASpace, LFrames, ASpace = qspInitial);
end;

procedure TQuicClientConnection.RegisterSpan(ASpace: TQuicSpace;
  ACryptoLo, ACryptoHi: UInt64);
var
  LN: Integer;
begin
  if ACryptoHi <= ACryptoLo then
    Exit;
  LN := Length(FSentSpans[ASpace]);
  SetLength(FSentSpans[ASpace], LN + 1);
  FSentSpans[ASpace][LN].Pn := FSendPn[ASpace];
  FSentSpans[ASpace][LN].CryptoLo := ACryptoLo;
  FSentSpans[ASpace][LN].CryptoHi := ACryptoHi;
end;

procedure TQuicClientConnection.RequeueUnackedCrypto(ASpace: TQuicSpace;
  APadTo1200: Boolean);
var
  LAck, LUnacked, LFrames: TBytes;
  LHas: Boolean;
begin
  { 重发条件 = 存在未确认 crypto 数据（Retry 重置后 spans 已清但数据仍在） }
  if FCryptoEnd[ASpace] <= FCryptoAcked[ASpace] then
    Exit;
  LFrames := nil;
  LAck := BuildAckFrameFor(ASpace, LHas);
  if LHas then
    AppendTail(LFrames, LAck);
  LUnacked := SliceOf(FSentCryptoData[ASpace], Integer(FCryptoAcked[ASpace]),
    Integer(FCryptoEnd[ASpace] - FCryptoAcked[ASpace]));
  if Length(LUnacked) > 0 then
  begin
    RegisterSpan(ASpace, FCryptoAcked[ASpace], FCryptoEnd[ASpace]);
    QuicCryptoAppend(LFrames, FCryptoAcked[ASpace], LUnacked);
  end;
  if Length(LFrames) > 0 then
    SendSpacePacket(ASpace, LFrames, APadTo1200);
end;

procedure TQuicClientConnection.RecordRecvPn(ASpace: TQuicSpace; APn: UInt64);
var
  LRanges: TQuicAckRangeArray;
  LN, LPos, LI, LM: Integer;
begin
  if APn > FLargestRecvPn[ASpace] then
    FLargestRecvPn[ASpace] := APn;
  LRanges := FRecvRanges[ASpace];
  LN := FRecvRangeCount[ASpace];
  for LI := 0 to LN - 1 do
    if (APn >= LRanges[LI].Lo) and (APn <= LRanges[LI].Hi) then
      Exit;   { 重复包 }

  { 按 Hi 降序找插入点并插入单点区间 }
  LPos := 0;
  while (LPos < LN) and (LRanges[LPos].Hi >= APn) do
    Inc(LPos);
  SetLength(LRanges, LN + 1);
  if LN > LPos then
    Move(LRanges[LPos], LRanges[LPos + 1], (LN - LPos) * SizeOf(TQuicAckRange));
  LRanges[LPos].Lo := APn;
  LRanges[LPos].Hi := APn;

  { 单遍合并：降序下相邻/重叠即并入前段（以 Hi+1 与 Lo 判邻接，避免把带洞的离散区间误并） }
  LM := 0;
  for LI := 0 to LN do
  begin
    if (LM > 0) and (LRanges[LI].Hi + 1 >= LRanges[LM - 1].Lo) and
       (LRanges[LI].Lo <= LRanges[LM - 1].Hi + 1) then
    begin
      if LRanges[LI].Lo < LRanges[LM - 1].Lo then
        LRanges[LM - 1].Lo := LRanges[LI].Lo;
      if LRanges[LI].Hi > LRanges[LM - 1].Hi then
        LRanges[LM - 1].Hi := LRanges[LI].Hi;
    end
    else
    begin
      if LM <> LI then
        LRanges[LM] := LRanges[LI];
      Inc(LM);
    end;
  end;

  { 有界纪律：超上界丢最旧（最小）段——滑动窗口语义 }
  if LM > cQuicMaxRecvRangesPerSpace then
    LM := cQuicMaxRecvRangesPerSpace;
  SetLength(LRanges, LM);
  FRecvRanges[ASpace] := LRanges;
  FRecvRangeCount[ASpace] := LM;
end;

function TQuicClientConnection.BuildAckFrameFor(ASpace: TQuicSpace;
  out AHas: Boolean): TBytes;
var
  LSingle: TQuicAckRangeArray;
begin
  Result := nil;
  AHas := FRecvRangeCount[ASpace] > 0;
  if not AHas then
    Exit;
  // 规避对端 packet number skip 导致的 ACK 误并（TQuic 1-RTT 场景下 skip 属于
  // 合法行为，合并式 ACK 若把未收的 skip 区间并入会触发对端 transport 关闭）。
  // 保守策略：仅确认最大已收包号单点区间，避免把未确认的洞区间一并确认。
  SetLength(LSingle, 1);
  LSingle[0].Hi := FRecvRanges[ASpace][0].Hi;
  LSingle[0].Lo := FRecvRanges[ASpace][0].Hi;
  if not QuicAckAppend(Result, LSingle[0].Hi, 0, LSingle) then
  begin
    AHas := False;
    Result := nil;
  end;
end;

function TQuicClientConnection.PnInRanges(APn: UInt64;
  const ARanges: TQuicAckRangeArray): Boolean;
var
  LI: Integer;
begin
  Result := False;
  for LI := 0 to High(ARanges) do
    if (APn >= ARanges[LI].Lo) and (APn <= ARanges[LI].Hi) then
      Exit(True);
end;

procedure TQuicClientConnection.SettleAckFrame(ASpace: TQuicSpace;
  const ARanges: TQuicAckRangeArray; ADelayRaw: UInt64);
var
  LKept: array of TQuicSentCryptoSpan;
  LI, LK: Integer;
begin
  LKept := nil;
  LK := 0;
  for LI := 0 to High(FSentSpans[ASpace]) do
  begin
    if PnInRanges(FSentSpans[ASpace][LI].Pn, ARanges) then
      Continue;
    SetLength(LKept, LK + 1);
    LKept[LK] := FSentSpans[ASpace][LI];
    Inc(LK);
  end;
  FSentSpans[ASpace] := LKept;
  if LK > 0 then
    { 区间按 CryptoLo 升序登记，最早未确认段的下沿 = 连续确认点 }
    FCryptoAcked[ASpace] := FSentSpans[ASpace][0].CryptoLo
  else
    FCryptoAcked[ASpace] := FCryptoEnd[ASpace];
  if ASpace = qspApplication then
    SettleApplicationAck(ARanges, ADelayRaw);
end;

procedure TQuicClientConnection.FeedCrypto(ASpace: TQuicSpace;
  AOffset: UInt64; const AData: TBytes);
var
  LHold: TQuicCryptoHold;
  LIns, LI: Integer;
  LHolds: array of TQuicCryptoHold;
begin
  if Length(AData) = 0 then
    Exit;
  if AOffset + UInt64(Length(AData)) <= FCryptoNext[ASpace] then
    Exit;   { 全部重复 }
  if AOffset < FCryptoNext[ASpace] then
  begin
    TakeError('crypto stream overlap');
    Exit;
  end;
  if AOffset = FCryptoNext[ASpace] then
  begin
    AppendTail(FMsgBuf[ASpace], AData);
    FCryptoNext[ASpace] := FCryptoNext[ASpace] + UInt64(Length(AData));
    ConsumeHolds(ASpace);
    Exit;
  end;
  { 未来段：入有界暂存（按偏移有序插入） }
  if Length(FCryptoHolds[ASpace]) >= cQuicMaxCryptoHolds then
  begin
    TakeError('crypto reorder beyond bound');
    Exit;
  end;
  LHolds := FCryptoHolds[ASpace];
  LIns := Length(LHolds);
  for LI := 0 to Length(LHolds) - 1 do
    if UInt64(LHolds[LI].Ofs) > AOffset then
    begin
      LIns := LI;
      Break;
    end;
  SetLength(LHolds, Length(LHolds) + 1);
  { 含 TBytes 的记录禁用裸 Move（引用计数）：逐位赋值搬移 }
  for LI := Length(LHolds) - 1 downto LIns + 1 do
    LHolds[LI] := LHolds[LI - 1];
  LHold.Ofs := Int64(AOffset);
  LHold.Data := AData;
  LHolds[LIns] := LHold;
  FCryptoHolds[ASpace] := LHolds;
end;

procedure TQuicClientConnection.ConsumeHolds(ASpace: TQuicSpace);
var
  LI, LFound: Integer;
  LHolds: array of TQuicCryptoHold;
begin
  repeat
    if FPhase = qcpClosed then
      Exit;
    LHolds := FCryptoHolds[ASpace];
    LFound := -1;
    for LI := 0 to Length(LHolds) - 1 do
      if UInt64(LHolds[LI].Ofs) = FCryptoNext[ASpace] then
      begin
        LFound := LI;
        Break;
      end;
    if LFound < 0 then
      Break;
    AppendTail(FMsgBuf[ASpace], LHolds[LFound].Data);
    FCryptoNext[ASpace] := FCryptoNext[ASpace] +
      UInt64(Length(LHolds[LFound].Data));
    for LI := LFound to Length(LHolds) - 2 do
      LHolds[LI] := LHolds[LI + 1];
    SetLength(LHolds, Length(LHolds) - 1);
    FCryptoHolds[ASpace] := LHolds;
  until False;
  PumpMessages(ASpace);
end;

procedure TQuicClientConnection.PumpMessages(ASpace: TQuicSpace);
var
  LBuf, LFull, LBody: TBytes;
  LLen: UInt64;
  LType: Byte;
  LRest: Integer;
begin
  { 握手空间的 TLS 消息必须等 ServerHello 就位后才进 transcript——
    否则 EE 先于 SH 入流会破坏全局消息顺序 }
  if (ASpace = qspHandshake) and (FPhase <> qcpHandshake) then
    Exit;
  while FPhase <> qcpClosed do
  begin
    LBuf := FMsgBuf[ASpace];
    if Length(LBuf) < 4 then
      Break;
    LLen := ReadU24(LBuf, 1);
    if LLen > UInt64(Length(LBuf)) - 4 then
      Break;
    LType := LBuf[0];
    LFull := SliceOf(LBuf, 0, 4 + Integer(LLen));
    LBody := SliceOf(LBuf, 4, Integer(LLen));

    { 原地左移消费已解析消息（动态数组别名共享内存，Move 后收缩安全） }
    LRest := Length(LBuf) - (4 + Integer(LLen));
    if LRest > 0 then
      Move(LBuf[4 + Integer(LLen)], LBuf[0], LRest);
    SetLength(FMsgBuf[ASpace], LRest);

    AppendTail(FTranscript, LFull);
    HandleMessage(LType, LFull, LBody);
  end;
end;

function TQuicClientConnection.PreTranscriptHash(ALastMsgLen: Integer): TBytes;
begin
  { 排除末尾 ALastMsgLen 字节后的 transcript 哈希——verify_data 覆盖
    「不含本消息」的前缀 }
  Result := SHA256(SliceOf(FTranscript, 0, Length(FTranscript) - ALastMsgLen));
end;

procedure TQuicClientConnection.HandleMessage(AType: Byte;
  const AFullMsg, ABody: TBytes);
begin
  case AType of
    cMsgServerHello:
      HandleServerHello(AFullMsg, ABody);
    cMsgEncryptedExtensions:
      HandleEncryptedExtensions(AFullMsg, ABody);
    cMsgCertificate:
      HandleCertificate(AFullMsg, ABody);
    cMsgCertificateVerify:
      HandleCertificateVerify(AFullMsg, ABody);
    cMsgFinished:
      HandleServerFinished(AFullMsg, ABody);
    cMsgNewSessionTicket, cMsgKeyUpdate:
      ;  { 握手后良性消息（NST/KeyUpdate）：Q4 不消费，忽略 }
  else
    TakeError('unexpected tls handshake message');
  end;
end;

procedure TQuicClientConnection.HandleServerHello(const AFullMsg,
  ABody: TBytes);
var
  LInfo: TTLS13ServerHelloInfo;
  LShared: TBytes;
  LErrMsg: string;
begin
  if FPhase <> qcpInitialSent then
  begin
    TakeError('unexpected server hello');
    Exit;
  end;
  if not TryParseServerHelloFromHandshake(AFullMsg, LInfo) or
    (not LInfo.Valid) then
  begin
    TakeError('server hello parse failed');
    Exit;
  end;
  if LInfo.SelectedVersion <> cTlsVersion13 then
  begin
    TakeError('negotiated version is not tls 1.3');
    Exit;
  end;
  if not SuiteFromTls(LInfo.SelectedCipherSuite, FSuite) then
  begin
    TakeError('cipher suite unsupported');
    Exit;
  end;
  FTlsSuite := LInfo.SelectedCipherSuite;
  if Length(LInfo.PeerKeyShare) = 0 then
  begin
    TakeError('server key share missing');
    Exit;
  end;
  LShared := nil;
  LErrMsg := '';
  if not TryX25519ComputeSharedSecret(FX25519Priv, LInfo.PeerKeyShare,
    LShared, LErrMsg) then
  begin
    TakeError('x25519 shared secret failed');
    Exit;
  end;
  { transcript 追加由 PumpMessages 统一负责（含本消息），此处不得重复 }
  InitTLS13HandshakeSecrets(FHsSecrets);
  if not TryDeriveTLS13HandshakeSecrets(FTlsSuite, LShared, FTranscript,
    FHsSecrets, LErrMsg) then
  begin
    TakeError('handshake secrets derive failed');
    Exit;
  end;
  FHsKeysC := QuicMakePacketKeys(FHsSecrets.ClientHandshakeTrafficSecret,
    FSuite);
  FHsKeysS := QuicMakePacketKeys(FHsSecrets.ServerHandshakeTrafficSecret,
    FSuite);
  FPhase := qcpHandshake;
end;

procedure TQuicClientConnection.HandleEncryptedExtensions(const AFullMsg,
  ABody: TBytes);
var
  LInfo: TTLS13EncryptedExtensionsInfo;
  LErr: string;
  LRaw: TBytes;
  LTotal, LPos, LEType, LELen, LIdx, LI: Integer;
  LOk, LMismatch: Boolean;
  LDgramVal: UInt64;
begin
  if FPhase <> qcpHandshake then
  begin
    TakeError('encrypted extensions before server hello');
    Exit;
  end;
  if not TryParseTLS13EncryptedExtensions(AFullMsg, LInfo, LErr) then
  begin
    TakeError('encrypted extensions parse failed: ' + LErr);
    Exit;
  end;
  { QUIC MUST ALPN（RFC 9001 §8.1）：缺失或不匹配均 fail-closed }
  if not LInfo.HasALPN then
  begin
    TakeError('alpn missing in encrypted extensions');
    Exit;
  end;
  if string(LInfo.SelectedALPNProtocol) <> FParams.ALPN then
  begin
    TakeError('alpn mismatch');
    Exit;
  end;

  { EE 体：u16 扩展总长 + 条目(type u16+len u16+data)。
    parser 单元不透出原始扩展，TP 扩展在此自析 }
  if Length(ABody) < 2 then
  begin
    TakeError('encrypted extensions truncated');
    Exit;
  end;
  LTotal := WordsAt(ABody, 0);
  LPos := 2;
  LOk := False;
  while LPos + 4 <= Length(ABody) do
  begin
    LEType := WordsAt(ABody, LPos);
    LELen := WordsAt(ABody, LPos + 2);
    Inc(LPos, 4);
    if LPos + LELen > Length(ABody) then
    begin
      TakeError('extension entry truncated');
      Exit;
    end;
    if (LEType = cQuicTpExtType) and (not LOk) then
    begin
      LRaw := SliceOf(ABody, LPos, LELen);
      if not TryDecodeQuicTransportParams(LRaw, FPeerParams) then
      begin
        TakeError('transport parameters malformed');
        Exit;
      end;
      LOk := True;
      { 不提前退出：继续走完剩余条目的边界校验 }
    end;
    Inc(LPos, LELen);
  end;
  if (not LOk) or (LPos <> 2 + LTotal) then
  begin
    TakeError('quic transport parameters missing');
    Exit;
  end;

  { RFC 9000 §7.3：initial_source_connection_id 必须等于服务器包 SCID }
  LIdx := QuicParamFind(FPeerParams, cQuicParamInitialSourceConnectionId);
  if LIdx < 0 then
  begin
    TakeError('initial_source_connection_id missing');
    Exit;
  end;
  LMismatch := Length(FPeerParams[LIdx].Value) <> Length(FPeerScid);
  if not LMismatch then
    for LI := 0 to Length(FPeerScid) - 1 do
      if FPeerParams[LIdx].Value[LI] <> FPeerScid[LI] then
      begin
        LMismatch := True;
        Break;
      end;
  if LMismatch then
  begin
    TakeError('initial_source_connection_id mismatch');
    Exit;
  end;

  { RFC 9221 §3：max_datagram_frame_size 缺省 = 不支持；值 >0 = 支持，
    语义为对端允许接收的单个 DATAGRAM 帧总字节数上界（帧类型+
    长度前缀+载荷全含）；0 与缺省同义（不支持，非错误） }
  FDgramEnabled := False;
  FPeerMaxDgramSize := 0;
  if QuicParamGetVarint(FPeerParams, cQuicParamMaxDatagramFrameSize,
    LDgramVal) and (LDgramVal > 0) then
  begin
    FDgramEnabled := True;
    FPeerMaxDgramSize := Integer(LDgramVal);
  end;

  FPeerParamsValid := True;
end;

procedure TQuicClientConnection.HandleCertificate(const AFullMsg,
  ABody: TBytes);
var
  LPos, LCtxLen, LListEnd, LCertLen, LExtLen: Integer;
begin
  if FPhase <> qcpHandshake then
  begin
    TakeError('certificate before handshake');
    Exit;
  end;
  if Length(ABody) < 1 then
  begin
    TakeError('certificate message truncated');
    Exit;
  end;
  { RFC 8446 §4.4.2：request_context(u8 前缀) ‖ certificate_list
    （u24 列表总长前缀，条目 = u24 证书长 + DER + u16 扩展） }
  LCtxLen := ABody[0];
  if LCtxLen <> 0 then
  begin
    TakeError('certificate request context unsupported');
    Exit;
  end;
  LPos := 1;
  if LPos + 3 > Length(ABody) then
  begin
    TakeError('certificate list truncated');
    Exit;
  end;
  LListEnd := LPos + 3 + Integer(ReadU24(ABody, LPos));
  Inc(LPos, 3);
  if LListEnd > Length(ABody) then
  begin
    TakeError('certificate list overrun');
    Exit;
  end;
  FPeerCerts := nil;
  FLeafCert.Free;
  FLeafCert := nil;
  while LPos < LListEnd do
  begin
    if LPos + 3 > LListEnd then
    begin
      TakeError('certificate list truncated');
      Exit;
    end;
    LCertLen := Integer(ReadU24(ABody, LPos));
    Inc(LPos, 3);
    if (LCertLen <= 0) or (LPos + LCertLen > LListEnd) then
    begin
      TakeError('certificate entry truncated');
      Exit;
    end;
    SetLength(FPeerCerts, Length(FPeerCerts) + 1);
    FPeerCerts[High(FPeerCerts)] := SliceOf(ABody, LPos, LCertLen);
    Inc(LPos, LCertLen);
    if LPos + 2 > LListEnd then
    begin
      TakeError('certificate extensions truncated');
      Exit;
    end;
    LExtLen := WordsAt(ABody, LPos);
    Inc(LPos, 2 + LExtLen);
    if LPos > LListEnd then
    begin
      TakeError('certificate entry overrun');
      Exit;
    end;
  end;
  if Length(FPeerCerts) = 0 then
  begin
    TakeError('empty certificate list');
    Exit;
  end;
  FLeafCert := TX509Certificate.Create;
  try
    FLeafCert.LoadFromDER(FPeerCerts[0]);
  except
    on E: Exception do
    begin
      FLeafCert.Free;
      FLeafCert := nil;
      TakeError('leaf certificate parse failed');
      Exit;
    end;
  end;
end;

procedure TQuicClientConnection.HandleCertificateVerify(const AFullMsg,
  ABody: TBytes);
var
  LScheme: Word;
  LSig: TBytes;
  LErr, LHookErr: string;
  LHash, LInput: TBytes;
begin
  if FPhase <> qcpHandshake then
  begin
    TakeError('certificate verify before handshake');
    Exit;
  end;
  if FLeafCert = nil then
  begin
    TakeError('certificate verify without leaf certificate');
    Exit;
  end;
  if not TryParseTLS13CertificateVerifyHandshake(AFullMsg, LScheme, LSig,
    LErr) then
  begin
    TakeError('certificate verify parse failed');
    Exit;
  end;
  { CV 恒验：签名覆盖 transcript 至 Certificate（不含本消息）；
    客户端验「服务器」CV 用 server 上下文串（RFC 8446 §4.4.3） }
  LHash := PreTranscriptHash(Length(AFullMsg));
  LInput := BuildTLS13ServerCertificateVerifyInputSHA256(LHash);
  if not TryVerifyTLS13CertificateVerifySignature(LScheme,
    FLeafCert.PublicKeyInfo, LInput, LSig, LErr) then
  begin
    { 反哺纪律：透出底层原因，不做黑箱吞错 }
    TakeError('certificate verify signature failed: ' + LErr);
    Exit;
  end;
  { 第二层策略：链/主机名验证交钩子；无钩子且未显式 insecure 即拒绝 }
  LHookErr := '';
  if Assigned(FParams.CertVerifyHook) then
  begin
    if not FParams.CertVerifyHook(FPeerCerts, LHookErr) then
    begin
      TakeError('certificate hook rejected');
      Exit;
    end;
  end
  else if not FParams.InsecureSkipVerify then
  begin
    TakeError('chain verification unavailable (hook or insecure required)');
    Exit;
  end;
end;

procedure TQuicClientConnection.HandleServerFinished(const AFullMsg,
  ABody: TBytes);
var
  LErr: string;
  LHash, LExpect, LClientFin, LMsg, LAck, LFrames: TBytes;
  LHas: Boolean;
begin
  if FPhase <> qcpHandshake then
  begin
    TakeError('unexpected server finished');
    Exit;
  end;
  { verify_data 覆盖 transcript 至 CertificateVerify（不含本消息），
    常量时间比较防侧信道 }
  LHash := PreTranscriptHash(Length(AFullMsg));
  LExpect := TLS13ComputeFinishedVerifyDataFromTrafficSecretForCipherSuite(
    FTlsSuite, FHsSecrets.ServerHandshakeTrafficSecret, LHash);
  if (Length(ABody) <> Length(LExpect)) or
     (not ConstTimeEqual(ABody, LExpect)) then
  begin
    TakeError('server finished mismatch');
    Exit;
  end;

  { 应用密钥派生：transcript 至服务器 Finished（当前 FTranscript 恰为该前缀） }
  InitTLS13ApplicationSecrets(FAppSecrets);
  if not TryDeriveTLS13ApplicationSecrets(FTlsSuite,
    FHsSecrets.HandshakeSecret, FTranscript, FAppSecrets, LErr) then
  begin
    TakeError('application secrets derive failed');
    Exit;
  end;
  FAppKeysW := QuicMakePacketKeys(
    FAppSecrets.ClientApplicationTrafficSecret, FSuite);
  FAppKeysR := QuicMakePacketKeys(
    FAppSecrets.ServerApplicationTrafficSecret, FSuite);
  FHasAppKeys := True;

  { 客户端 Finished（RFC 8446 §4.4.4 原文：verify_data 覆盖「through the
    server's Finished」）——transcript 必须含服务器 Finished 本消息，
    与上方验证服务器 Finished 所用的 CH..CV 前缀哈希是两个不同基线。
    互操作缺陷（2026-08-23 aioquic 对拍揭穿）：此前误复用前缀哈希，
    自写双向单测因对称实现互相印证而不可见 }
  LClientFin := TLS13ComputeFinishedVerifyDataFromTrafficSecretForCipherSuite(
    FTlsSuite, FHsSecrets.ClientHandshakeTrafficSecret,
    SHA256(FTranscript));
  LMsg := nil;
  QuicBufAppendByte(LMsg, cMsgFinished);
  AppendU24(LMsg, Length(LClientFin));
  AppendTail(LMsg, LClientFin);

  AppendTail(FSentCryptoData[qspHandshake], LMsg);
  RegisterSpan(qspHandshake, FCryptoEnd[qspHandshake],
    FCryptoEnd[qspHandshake] + UInt64(Length(LMsg)));

  { Handshake 包：ACK(initial)+ACK(handshake)+CRYPTO(fin)——
    Initial 空间确认随包携带后即可弃钥（RFC 9001 §4.9.1） }
  LFrames := nil;
  LAck := BuildAckFrameFor(qspInitial, LHas);
  if LHas then
    AppendTail(LFrames, LAck);
  LAck := BuildAckFrameFor(qspHandshake, LHas);
  if LHas then
    AppendTail(LFrames, LAck);
  QuicCryptoAppend(LFrames, FCryptoEnd[qspHandshake], LMsg);
  FCryptoEnd[qspHandshake] := FCryptoEnd[qspHandshake] +
    UInt64(Length(LMsg));
  SendSpacePacket(qspHandshake, LFrames, False);
  DiscardInitialKeys;
  FPhase := qcpConnected;
end;

procedure TQuicClientConnection.HandleShortPacket(const APacket: TBytes);
var
  LPn: UInt64;
  LPayload: TBytes;
begin
  if not FHasAppKeys then
  begin
    FLastDropReason := 'short packet before app keys';
    Exit;   { 密钥未就绪（乱序到达）：静默丢弃，等对端重传 }
  end;
  if not TryQuicUnprotectPacket(APacket, 0, FAppKeysR,
    FLargestRecvPn[qspApplication], LPn, LPayload) then
  begin
    FLastDropReason := 'short packet unprotect failed';
    Exit;
  end;
  FLastDropReason := '';
  Inc(FRxShortOk);
  RecordRecvPn(qspApplication, LPn);
  { 授予参数必须先于任何应用空间帧落地：MAX_STREAMS/MAX_DATA 帧
    相对 initial_* 参数是增量语义，顺序颠倒会被零值覆盖 }
  ApplyPeerGrantsOnce;
  ProcessFrames(qspApplication, LPayload);
end;

function TQuicClientConnection.HandleRetryPacket(
  const APacket: TBytes): Boolean;
var
  LPseudo, LWireTag, LTag, LCipher, LKeyB, LNonceB: TBytes;
  LDcidLen, LScidLen, LTokLen: Integer;
  LPos, LScidOfs, LTokOfs, LI: Integer;
  LOk: Boolean;
begin
  Result := True;   { 无论验证成败都不中断连接处理：无效 Retry 仅丢弃 }
  if FPhase <> qcpInitialSent then
    Exit;   { 握手已推进后的 Retry 无意义 }

  if Length(APacket) < 6 then
    Exit;
  LPos := 5;
  LDcidLen := APacket[LPos];
  Inc(LPos);
  if (LDcidLen > 160) or (Length(APacket) < LPos + LDcidLen + 1) then
    Exit;
  { Retry 包 DCID 字段必须是我方原 ODCID——否则非发给我们的 Retry }
  if LDcidLen <> Length(FLocalDcid) then
    Exit;
  for LI := 0 to LDcidLen - 1 do
    if APacket[LPos + LI] <> FLocalDcid[LI] then
      Exit;
  Inc(LPos, LDcidLen);

  if Length(APacket) < LPos + 1 + cQuicTagLen then
    Exit;
  LScidLen := APacket[LPos];
  LScidOfs := LPos + 1;
  Inc(LPos, 1 + LScidLen);
  if (LScidLen > cQuicMaxCidLen) or
     (Length(APacket) < LPos + cQuicTagLen) then
    Exit;
  LTokOfs := LPos;
  LTokLen := Length(APacket) - LPos - cQuicTagLen;
  if LTokLen < 0 then
    Exit;

  { RFC 9001 §5.8 Figure 8：伪包 = ODCID(len8+值) ‖ 去 tag 的 Retry 包；
    AES-128-GCM 空载荷，tag 与线上末 16 字节比对 }
  LPseudo := nil;
  QuicBufAppendByte(LPseudo, Byte(Length(FLocalDcid)));
  AppendTail(LPseudo, FLocalDcid);
  AppendTail(LPseudo, SliceOf(APacket, 0, Length(APacket) - cQuicTagLen));
  LWireTag := SliceOf(APacket, Length(APacket) - cQuicTagLen, cQuicTagLen);
  LKeyB := BytesOfConst(cRetryIntegrityKey);
  LNonceB := BytesOfConst(cRetryIntegrityNonce);
  LOk := PurePascalAESGCMEncrypt(LKeyB, LNonceB, nil, LPseudo, LCipher, LTag);
  if (not LOk) or (not ConstTimeEqual(LTag, LWireTag)) then
    Exit;

  { 验证通过：换新服务器 CID 与 token，重置密钥态后重发 CH。
    token 进包头（Retry Token 字段）而非 TLS 层 }
  FPeerScid := SliceOf(APacket, LScidOfs, LScidLen);
  FPeerCidSet := True;
  FRetryToken := SliceOf(APacket, LTokOfs, LTokLen);
  ResetForRetry;
  RequeueUnackedCrypto(qspInitial, True);
end;

procedure TQuicClientConnection.ProcessFrames(ASpace: TQuicSpace;
  const APayload: TBytes);
var
  LOfs, LEnd: Integer;
  LF: TQuicFrame;
  LRanges: TQuicAckRangeArray;
  LCloseReason: string;
  LHexDigits: string;
begin
  LOfs := 0;
  LEnd := Length(APayload);
  while LOfs < LEnd do
  begin
    if not TryQuicFrameParse(APayload, LOfs, LEnd, LF, LRanges) then
    begin
      { 诊断面：空间+偏移+失败处首字节（对端发了什么可取证） }
      LHexDigits := '0123456789abcdef';
      if LOfs < LEnd then
        TakeError('frame parse failed space=' + IntToStr(Ord(ASpace)) +
          ' ofs=' + IntToStr(LOfs) + '/' + IntToStr(LEnd) +
          ' byte=0x' + LHexDigits[1 + (APayload[LOfs] shr 4)] +
          LHexDigits[1 + (APayload[LOfs] and $F)])
      else
        TakeError('frame parse failed space=' + IntToStr(Ord(ASpace)) +
          ' ofs=' + IntToStr(LOfs) + '/' + IntToStr(LEnd));
      Exit;
    end;
    Inc(LOfs, LF.Consumed);
    case LF.Kind of
      qfkPadding, qfkPing, qfkNewToken:
        ;   { NEW_TOKEN（§19.7）：客户端不重连场景无 token 复用，忽略 }
      qfkAck:
        SettleAckFrame(ASpace, LRanges, LF.AckDelayRaw);
      qfkCrypto:
        if LF.DataLen > 0 then
          FeedCrypto(ASpace, LF.Offset,
            SliceOf(APayload, LF.DataOfs, LF.DataLen));
      qfkConnectionClose:
        begin
          { 诊断面：码/触发帧/原因短语并入错误文本（对端为何关连可取证） }
          if LF.ReasonLen > 0 then
          begin
            SetLength(LCloseReason, LF.ReasonLen);
            Move(APayload[LF.ReasonOfs], LCloseReason[1], LF.ReasonLen);
          end
          else
            LCloseReason := '';
          if LF.CloseSpace = qcsTransport then
            TakeError('connection closed by peer (transport) code=' +
              IntToStr(Int64(LF.ErrorCode)) + ' frame_type=' +
              IntToStr(Int64(LF.CloseFrameType)) + LCloseReason)
          else
            TakeError('connection closed by peer (application) code=' +
              IntToStr(Int64(LF.ErrorCode)) + LCloseReason);
          Exit;
        end;
      qfkHandshakeDone:
        ;   { 仅观测面 }
      qfkStream:
        if FPhase = qcpConnected then
        begin
          ApplyPeerGrantsOnce;
          FMux.HandleStreamData(LF.StreamId, LF.Offset,
            SliceOf(APayload, LF.DataOfs, LF.DataLen), LF.Fin);
        end;
      qfkResetStream:
        FMux.HandleResetStream(LF.StreamId, LF.ErrorCode, LF.FinalSize);
      qfkStopSending:
        FMux.HandleStopSending(LF.StreamId, LF.ErrorCode);
      qfkMaxData:
        FMux.HandleMaxData(LF.MaxValue);
      qfkMaxStreamData:
        FMux.HandleMaxStreamData(LF.StreamId, LF.MaxValue);
      qfkMaxStreams:
        FMux.HandleMaxStreams(LF.FrameType = cQfMaxStreamsBidi,
          LF.MaxValue);
      qfkDatagram:
        begin
          { RFC 9221 §5：仅 0-RTT/1-RTT 合法（客户端收不到 0-RTT）；
            未通告或超对端上界 = PROTOCOL_VIOLATION }
          if ASpace <> qspApplication then
          begin
            TakeError('datagram frame outside application space');
            Exit;
          end;
          if (not FDgramEnabled) or (LF.Consumed > FPeerMaxDgramSize) then
          begin
            TakeError('datagram frame violates negotiated limit');
            Exit;
          end;
          if Assigned(FOnDgram) then
            FOnDgram(SliceOf(APayload, LF.DataOfs, LF.DataLen));
        end;
      qfkNewConnectionId, qfkRetireConnectionId, qfkPathChallenge,
      qfkPathResponse, qfkDataBlocked, qfkStreamDataBlocked,
      qfkStreamsBlocked:
        ;  { CID/迁移族：单 CID 不迁移故忽略；阻塞通告为对端观测面 }
    end;
    if FPhase = qcpClosed then
      Exit;
  end;
end;

function TQuicClientConnection.OnDatagram(const ADgram: TBytes): Boolean;
var
  LPos, LAdv: Integer;
  LCur: TBytes;
  LInfo: TQuicHeaderPeek;
  LPn: UInt64;
  LPayload: TBytes;
begin
  Result := True;
  if (FPhase = qcpIdle) or (FPhase = qcpClosed) then
    Exit;
  LPos := 0;
  while (FPhase <> qcpClosed) and (LPos < Length(ADgram)) do
  begin
    if ADgram[LPos] = 0 then
    begin
      Inc(FRxPeekFail);   { 裸零分支计数并入 peek-fail（诊断面） }
      Break;   { 裸零非包头；coalesced 尾随 PADDING 归前包 }
    end;
    LCur := SliceOf(ADgram, LPos, Length(ADgram) - LPos);
    if not TryPeekQuicHeader(LCur, 0, LInfo) then
    begin
      Inc(FRxPeekFail);
      Break;   { 我方 SCID 为空 ⇒ 短头 DCID 长度恒 0 }
    end;

    if not LInfo.IsLong then
    begin
      HandleShortPacket(LCur);
      Break;   { 短头吞掉余下数据报（无法再切分） }
    end;
    if LInfo.Version <> cQuicVersionV1 then
    begin
      Inc(FRxOtherVer);
      if LInfo.Version = cQuicVersionVersionNegotiation then
        TakeError('version negotiation unsupported');
      Break;
    end;

    LAdv := 0;
    case LInfo.PacketType of
      qltRetry:
        begin
          HandleRetryPacket(LCur);
          Break;   { Retry 独占数据报 }
        end;
      qltZeroRtt:
        Break;   { 客户端角色不会收到 0-RTT 保护包 }
      qltInitial:
        begin
          if FInitialAlive and TryQuicUnprotectPacket(LCur, 0,
            FInitialKeysS, FLargestRecvPn[qspInitial], LPn, LPayload) then
          begin
            { 认证通过才登记 SCID——垃圾包不得污染对端 CID }
            if not FPeerCidSet then
            begin
              FPeerScid := LInfo.SrcCid;
              FPeerCidSet := True;
            end;
            RecordRecvPn(qspInitial, LPn);
            ProcessFrames(qspInitial, LPayload);
          end;
          LAdv := LInfo.PnOffset + Integer(LInfo.Length);
        end;
      qltHandshake:
        begin
          if ((FPhase = qcpHandshake) or (FPhase = qcpConnected)) and
            TryQuicUnprotectPacket(LCur, 0, FHsKeysS,
              FLargestRecvPn[qspHandshake], LPn, LPayload) then
          begin
            if not FPeerCidSet then
            begin
              FPeerScid := LInfo.SrcCid;
              FPeerCidSet := True;
            end;
            RecordRecvPn(qspHandshake, LPn);
            ProcessFrames(qspHandshake, LPayload);
          end;
          LAdv := LInfo.PnOffset + Integer(LInfo.Length);
        end;
    end;
    if LAdv <= 0 then
      Break;
    Inc(LPos, LAdv);
  end;
  Result := FPhase <> qcpClosed;
end;

function TQuicClientConnection.TakeOutbound(out ADgram: TBytes): Boolean;
var
  LN, LI: Integer;
begin
  ADgram := nil;
  LN := Length(FDgramOut);
  if LN = 0 then
    Exit(False);
  ADgram := FDgramOut[0];
  for LI := 0 to LN - 2 do   { 含 TBytes 的数组禁裸 Move：逐位赋值 }
    FDgramOut[LI] := FDgramOut[LI + 1];
  SetLength(FDgramOut, LN - 1);
  Result := True;
end;

procedure TQuicClientConnection.OnTimer(ANowUs: UInt64);
begin
  FLastTimerUs := ANowUs;
  if (FPhase = qcpIdle) or (FPhase = qcpClosed) then
    Exit;
  { Initial 空间：首个 CH 发出时尚无时钟基准（戳为 0）——按「时刻 0
    发出」计阈，即绝对时间过阈即可重发；重复 Initial 服务端按 PN 去重 }
  if FInitialAlive and (Length(FSentSpans[qspInitial]) > 0) and
     (((FSentSpanLastUs[qspInitial] = 0) and
       (ANowUs >= cQuicResendThresholdUs)) or
      ((FSentSpanLastUs[qspInitial] > 0) and
       (ANowUs >= FSentSpanLastUs[qspInitial]) and
       (ANowUs - FSentSpanLastUs[qspInitial] >= cQuicResendThresholdUs))) then
    RequeueUnackedCrypto(qspInitial, True);
  if ((FPhase = qcpHandshake) or (FPhase = qcpConnected)) and
     (FSentSpanLastUs[qspHandshake] > 0) and
     (ANowUs >= FSentSpanLastUs[qspHandshake]) and
     (ANowUs - FSentSpanLastUs[qspHandshake] >= cQuicResendThresholdUs) and
     (Length(FSentSpans[qspHandshake]) > 0) then
    RequeueUnackedCrypto(qspHandshake, False);
  { Q5 应用空间：丢失检测 → 拥塞联动 + STREAM 重发入队，随后封包泵 }
  if FPhase = qcpConnected then
  begin
    DetectApplicationLoss(ANowUs);
    FlushApplication;
  end;
end;

procedure TQuicClientConnection.Start;
begin
  if FPhase <> qcpIdle then
    Exit;
  RandomBytes(FLocalDcid, 8);
  DeriveInitialKeys(FLocalDcid);
  FInitialAlive := True;
  if AppendClientHello then
    FPhase := qcpInitialSent
  else if FLastError = '' then
    TakeError('initial packet build failed');
end;

procedure TQuicClientConnection.DiscardInitialKeys;
begin
  FInitialAlive := False;
  FInitialKeysC := Default(TQuicPacketKeys);
  FInitialKeysS := Default(TQuicPacketKeys);
  FRecvRanges[qspInitial] := nil;
  FRecvRangeCount[qspInitial] := 0;
  FSentSpans[qspInitial] := nil;
  FCryptoHolds[qspInitial] := nil;
  FMsgBuf[qspInitial] := nil;
  FSentCryptoData[qspInitial] := nil;
  FRetryToken := nil;   { 地址验证 token 单次有效 }
end;

{ ---- Q5 应用平面 ---- }

procedure TQuicClientConnection.ApplyPeerGrantsOnce;
var
  LMaxAckDelayMs: UInt64;

  function GrantOrZero(AId: UInt64): UInt64;
  var
    LV: UInt64;
  begin
    if not QuicParamGetVarint(FPeerParams, AId, LV) then
      LV := 0;
    Result := LV;
  end;

begin
  if FPeerParamsApplied or (not FPeerParamsValid) then
    Exit;
  FPeerParamsApplied := True;
  { 授予缺失按 0 处理：对端不给预算即不可发（fail-closed） }
  FMux.ApplyPeerGrants(
    GrantOrZero(cQuicParamInitialMaxData),
    GrantOrZero(cQuicParamInitialMaxStreamDataBidiLocal),
    GrantOrZero(cQuicParamInitialMaxStreamDataBidiRemote),
    GrantOrZero(cQuicParamInitialMaxStreamDataUni),
    GrantOrZero(cQuicParamInitialMaxStreamsBidi),
    GrantOrZero(cQuicParamInitialMaxStreamsUni));
  { ACK 延迟缩放参数（缺省 = §18.2 RECOMMENDED：指数 3 / 延迟 25ms） }
  if not QuicParamGetVarint(FPeerParams, cQuicParamAckDelayExponent,
    FAckDelayExponent) then
    FAckDelayExponent := 3;
  if FAckDelayExponent > 30 then
    FAckDelayExponent := 30;   { 防 shl 移位越界 }
  if not QuicParamGetVarint(FPeerParams, cQuicParamMaxAckDelay,
    LMaxAckDelayMs) then
    LMaxAckDelayMs := 25;
  FMaxAckDelayUs := LMaxAckDelayMs * 1000;
end;

function TQuicClientConnection.OpenStream(AUnidirectional: Boolean;
  out AStreamId: UInt64): Boolean;
begin
  Result := False;
  AStreamId := 0;
  if FPhase <> qcpConnected then
    Exit;   { 握手完成后才可开流 }
  ApplyPeerGrantsOnce;
  if AUnidirectional then
    Result := FMux.OpenUni(AStreamId)
  else
    Result := FMux.OpenBidi(AStreamId);
end;

function TQuicClientConnection.StreamWrite(AStreamId: UInt64;
  const AData: TBytes; AFin: Boolean): Boolean;
begin
  Result := False;
  if FPhase <> qcpConnected then
    Exit;
  ApplyPeerGrantsOnce;
  if not FMux.StreamWrite(AStreamId, AData, AFin) then
    Exit;
  FlushApplication;
  Result := True;
end;

function TQuicClientConnection.StreamReset(AStreamId,
  AErrorCode: UInt64): Boolean;
begin
  Result := False;
  if FPhase <> qcpConnected then
    Exit;
  Result := FMux.ResetLocal(AStreamId, AErrorCode);
  if Result then
    FlushApplication;
end;

procedure TQuicClientConnection.FlushApplication;
var
  LAck, LFrames, LPkt, LDgram: TBytes;
  LHasAck: Boolean;
  LRoom, LDgramLen: Integer;
  LDgramSent: Boolean;
begin
  if FPhase <> qcpConnected then
    Exit;
  ApplyPeerGrantsOnce;
  while FReno.CanSend(UInt64(FAppTracker.InFlightBytes)) do
  begin
    LFrames := nil;
    LAck := BuildAckFrameFor(qspApplication, LHasAck);
    if LHasAck then
      AppendTail(LFrames, LAck);
    LRoom := cQuicAppPacketRoom - Length(LFrames);
    if LRoom < 32 then
      Break;   { ACK 已占满预算：下轮再发数据 }

    { RFC 9221 §5.4：数据报受拥塞控制，与流帧同包竞争预算；
      统一 WITH_LENGTH 形态（0x31）支持共包多条定界。
      LDgramSent 让「仅 ACK+数据报、无流帧」也能出包（低延迟优先），
      纯 ACK 无产出仍按原样滞留下轮随行 }
    LDgramSent := False;
    while FDgramQCount > 0 do
    begin
      LDgram := FDgramQ[FDgramQHead];
      LDgramLen := 1 + QuicVarintEncodedLen(UInt64(Length(LDgram)))
        + Length(LDgram);
      if LDgramLen > LRoom then
        Break;   { 本包余量不足：留待下轮（不拆分数据报） }
      QuicDatagramAppend(LFrames, LDgram);
      FDgramQ[FDgramQHead] := nil;
      FDgramQHead := (FDgramQHead + 1) mod cQuicDgramQueueCap;
      Dec(FDgramQCount);
      Dec(LRoom, LDgramLen);
      LDgramSent := True;
    end;

    if not FMux.CollectFrames(LFrames, LRoom) and (not LDgramSent) then
      Break;   { 复用器无产出且无数据报：无事可做 }
    { 保底：protect 样本区需 APnLen+tag=20 字节，不足即补 PADDING，
      否则小数据报包被拒后队列已排空无法归还 }
    if (Length(LFrames) > 0) and (Length(LFrames) < 24) then
      QuicPaddingAppend(LFrames, 24 - Length(LFrames));
    LPkt := BuildShortPacket(4, LFrames);
    if LPkt = nil then
    begin
      FMux.RollbackStaged;
      Break;
    end;
    FAppTracker.Track(FSendPn[qspApplication], FLastTimerUs,
      Length(LPkt), True);
    FMux.CommitSent(FSendPn[qspApplication]);
    SendSpacePacket(qspApplication, LFrames, False);
  end;
end;

procedure TQuicClientConnection.SettleApplicationAck(
  const ARanges: TQuicAckRangeArray; ADelayRaw: UInt64);
var
  LStats: TQuicAckStats;
  LLatest, LDelayScaled: UInt64;
begin
  if Length(ARanges) = 0 then
    Exit;
  if not FAppTracker.OnAckFrame(ARanges[0].Hi, ARanges, LStats) then
    Exit;
  if LStats.HasSampleCandidate and
     (FLastTimerUs >= LStats.SampleTimeSentUs) then
  begin
    LLatest := FLastTimerUs - LStats.SampleTimeSentUs;
    LDelayScaled := ADelayRaw shl FAckDelayExponent;
    QuicRttOnSample(FAppRtt, LLatest, LDelayScaled, True,
      FMaxAckDelayUs);
    FReno.OnAcked(LStats.SamplePn, UInt64(FAppTracker.HighestTracked),
      UInt64(LStats.AckedBytes));
  end;
  FMux.OnAckRanges(ARanges);
  FlushApplication;   { 确认释放窗口后立即续发滞留数据 }
end;

procedure TQuicClientConnection.DetectApplicationLoss(ANowUs: UInt64);
var
  LLostPns: TQuicPnArray;
  LLostBytes, LI: Integer;
  LEarliest: UInt64;
  LT: Int64;
begin
  FAppTracker.DetectLost(FAppRtt, ANowUs, LLostPns, LLostBytes);
  if Length(LLostPns) = 0 then
    Exit;
  FReno.OnLost(UInt64(FAppTracker.HighestTracked));
  LEarliest := High(UInt64);
  for LI := 0 to High(LLostPns) do
  begin
    LT := FAppTracker.TimeSentOf(LLostPns[LI]);
    if (LT >= 0) and (UInt64(LT) < LEarliest) then
      LEarliest := UInt64(LT);
  end;
  if (FAppTracker.InFlightCount = 0) and
     (LEarliest < High(UInt64)) and (ANowUs >= LEarliest) then
  begin
    if QuicIsPersistentCongestion(ANowUs - LEarliest,
       QuicComputePtoUs(FAppRtt, FMaxAckDelayUs)) then
      FReno.OnPersistentCongestion(UInt64(FAppTracker.HighestTracked));
  end;
  FMux.OnLostPns(LLostPns);
end;

procedure TQuicClientConnection.HookStreamData(AHandler: TOnStreamData);
begin
  FMux.OnStreamData := AHandler;
end;

procedure TQuicClientConnection.HookStreamReset(AHandler: TOnStreamReset);
begin
  FMux.OnStreamReset := AHandler;
end;

function TQuicClientConnection.SendDatagram(const AData: TBytes): Boolean;
var
  LFrameLen, LTail: Integer;
begin
  Result := False;
  if FPhase <> qcpConnected then
    Exit;
  if not FDgramEnabled then
    Exit;   { 对端未通告支持：fail-closed }
  { RFC 9221 §3：上界含帧类型+长度前缀+载荷全长 }
  LFrameLen := 1 + QuicVarintEncodedLen(UInt64(Length(AData)));
  LTail := LFrameLen + Length(AData);
  if (LTail > FPeerMaxDgramSize) or (LTail > cQuicAppPacketRoom) then
    Exit;   { 超对端上界或单包预算：调用方分片或改走流 }
  if FDgramQCount >= cQuicDgramQueueCap then
    Exit;   { 滞留上界：拥塞窗满时拒绝而非无限积压 }
  LTail := (FDgramQHead + FDgramQCount) mod cQuicDgramQueueCap;
  FDgramQ[LTail] := AData;
  Inc(FDgramQCount);
  FlushApplication;
  Result := True;
end;

procedure TQuicClientConnection.HookDatagram(AHandler: TOnQuicDatagram);
begin
  FOnDgram := AHandler;
end;

function TQuicClientConnection.ExportKeyingMaterial(const ALabel: TBytes;
  const AContext: TBytes; ALength: Integer): TBytes;
begin
  Result := nil;
  if not FHasAppKeys then Exit;
  if (FTlsSuite <> $1301) and (FTlsSuite <> $1302) and (FTlsSuite <> $1303) then Exit;
  if (FAppSecrets.MasterSecret = nil) or (FAppSecrets.TranscriptHash = nil) then Exit;
  Result := TLS13ExportKeyingMaterial(FTlsSuite, FAppSecrets.MasterSecret,
    FAppSecrets.TranscriptHash, ALabel, AContext, ALength);
end;

function TQuicClientConnection.ExportKeyingMaterialStr(const ALabel: string;
  const AContext: string; ALength: Integer): TBytes;
var
  LLabelB, LCtxB: TBytes;
begin
  Result := nil;
  if ALabel <> '' then
  begin
    SetLength(LLabelB, Length(ALabel));
    if Length(LLabelB) > 0 then Move(ALabel[1], LLabelB[0], Length(LLabelB));
  end;
  if AContext <> '' then
  begin
    SetLength(LCtxB, Length(AContext));
    if Length(LCtxB) > 0 then Move(AContext[1], LCtxB[0], Length(LCtxB));
  end;
  Result := ExportKeyingMaterial(LLabelB, LCtxB, ALength);
end;

end.
