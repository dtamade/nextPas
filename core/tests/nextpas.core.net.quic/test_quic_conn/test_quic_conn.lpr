program test_quic_conn;

{ QUIC 客户端连接驱动单元测试（Q4：1-RTT 握手闭环）：
  - 测试内嵌「最小 TLS 1.3 服务器」：用同一批 core 积木（x25519/
    keyschedule/appschedule/finished/servercertverify）在测试侧组装
    SH/EE/Cert/CV/Fin 飞行并按包保护密封，驱动 conn 走完全状态机
    （qcpIdle→InitialSent→Handshake→Connected）；证书夹具复用
    tests/nextpas.core.tls/certs 的 RSA 对（CertificateVerify 恒验
    真实生效：真签名真公钥验证，篡改即拒）；
  - Initial 包结构自环（≥1200 补齐 / 头部字段 / 自解密 / CRYPTO 帧）；
  - CH 线格式经既有 parser 回验（key_share/ALPN/supported_versions）
    + TP 扩展(0x0039) 注入存在性手工扫描；
  - Retry Integrity Tag 按 RFC 9001 §5.8 构造黄金 Retry（常量密钥/
    nonce + Pseudo-Packet AAD）：正向触发换钥重发，tag 篡改静默丢弃；
  - 握手空间 CRYPTO 乱序重组（后段先到暂存、前段到达链式消费）；
  - coalesced 数据报（Initial‖Handshake 单报文）一次投递；
  - OnTimer 固定阈重发 + ACK 结算停发；
  - 负向面全部 fail-closed：严格模式无钩子拒 / 钩子拒绝 / ALPN 不匹配 /
    缺 TP 扩展 / CV 签名篡改 / Finished 篡改。
  仅依赖 nextPas/core（无 system 垫片）。 }
{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.fs.path,
  nextpas.core.fs.util,
  nextpas.core.crypto.hash,
  nextpas.core.crypto.x25519,
  nextpas.core.crypto.aesgcm,
  nextpas.core.crypto.random,
  nextpas.core.tls.pem,
  nextpas.core.tls.tls13.clienthello.parser,
  nextpas.core.tls.tls13.keyschedule,
  nextpas.core.tls.tls13.finished,
  nextpas.core.tls.tls13.servercertverify,
  nextpas.core.net.quic.varint,
  nextpas.core.net.quic.params,
  nextpas.core.net.quic.header,
  nextpas.core.net.quic.tls,
  nextpas.core.net.quic.protect,
  nextpas.core.net.quic.frame,
  nextpas.core.net.quic.conn,
  nextpas.core.test;

{$I ../../fpc_rtl_uses_scan.inc}

const
  cSuiteAes128 = $1301;
  cSchemeRsaPssSha256 = $0804;
  { RFC 9001 §5.8 原文定案 }
  cRetryKeyHex = 'be0c690b9f66575a1d766b54e368c84e';
  cRetryNonceHex = '461599d35d632bf2239825bb';

type
  TSrvFlightMode = (sfOk, sfBadAlpn, sfNoTp, sfBadFin, sfBadCv,
    sfNoDgram, sfSmallDgram);

  TSrvFixture = record
    XPriv: TBytes;
    XPub: TBytes;
    Scid: TBytes;
    CertDer: TBytes;
    KeyBlob: TBytes;
    Transcript: TBytes;    { 终态 = CH..CV（服务器 Fin 不入） }
    HsSecrets: TTLS13HandshakeSecrets;
    EeMsg: TBytes;
  end;

  { 链验证钩子目标（of object 形态要求实例方法） }
  THookTarget = class
  public
    Reject: Boolean;
    function Hook(const ACerts: TQuicDerList;
      out AError: string): Boolean;
  end;

{ Q5 流数据收集器（of object 形态要求实例方法） }
type
  TQ5Collector = class
  public
    Texts: array[0..7] of string;
    Fins: array[0..7] of Boolean;
    Count: Integer;
    procedure OnData(AStreamId: UInt64; const AData: TBytes;
      AFin: Boolean);
    procedure Clear;
  end;

  { RFC 9221 数据报接收收集器 }
  TQ5DgramCollector = class
  public
    Datas: array[0..7] of string;
    Count: Integer;
    procedure OnDgram(const AData: TBytes);
    procedure Clear;
  end;

procedure TQ5Collector.OnData(AStreamId: UInt64; const AData: TBytes;
  AFin: Boolean);
var
  LI: Integer;
begin
  if Count <= High(Texts) then
  begin
    Texts[Count] := '';
    for LI := 0 to Length(AData) - 1 do
      Texts[Count] := Texts[Count] + Chr(AData[LI]);
    Fins[Count] := AFin;
    Inc(Count);
  end;
end;

procedure TQ5Collector.Clear;
var
  LI: Integer;
begin
  for LI := 0 to High(Texts) do
    Texts[LI] := '';
  Count := 0;
end;

procedure TQ5DgramCollector.OnDgram(const AData: TBytes);
var
  LI: Integer;
begin
  if Count <= High(Datas) then
  begin
    Datas[Count] := '';
    for LI := 0 to Length(AData) - 1 do
      Datas[Count] := Datas[Count] + Chr(AData[LI]);
    Inc(Count);
  end;
end;

procedure TQ5DgramCollector.Clear;
var
  LI: Integer;
begin
  for LI := 0 to High(Datas) do
    Datas[LI] := '';
  Count := 0;
end;

function THookTarget.Hook(const ACerts: TQuicDerList;
  out AError: string): Boolean;
begin
  AError := '';
  Result := not Reject;
  if Reject then
    AError := 'rejected by test hook';
end;

var
  GHookTarget: THookTarget;
  GQ5Col: TQ5Collector;
  GQ5Dgm: TQ5DgramCollector;
  { 夹具走单元级全局：规避「捕获含托管字段的记录 + out 参数」组合下的
    堆损坏（测试顺序执行，无共享冲突） }
  GFx: TSrvFixture;

function HexNibbleVal(C: Char): Byte;
begin
  case C of
    '0'..'9': Result := Ord(C) - Ord('0');
    'a'..'f': Result := Ord(C) - Ord('a') + 10;
  else
    Result := 0;
  end;
end;

function HexToBytes(const AHex: string): TBytes;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to Length(Result) - 1 do
    Result[I] := (HexNibbleVal(AHex[I * 2 + 1]) shl 4) or
      HexNibbleVal(AHex[I * 2 + 2]);
end;

function BytesOf(const AVals: array of Byte): TBytes;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AVals));
  for I := 0 to High(AVals) do
    Result[I] := AVals[I];
end;

function BytesEqual(const AA, AB: TBytes): Boolean;
var
  I: Integer;
begin
  Result := False;
  if Length(AA) <> Length(AB) then
    Exit;
  for I := 0 to Length(AA) - 1 do
    if AA[I] <> AB[I] then
      Exit;
  Result := True;
end;

procedure TB(var ABuf: TBytes; const ATail: TBytes);
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

function ConcatBytes(const AA, AB: TBytes): TBytes;
begin
  Result := nil;
  TB(Result, AA);
  TB(Result, AB);
end;

procedure TBByte(var ABuf: TBytes; AVal: Byte);
begin
  QuicBufAppendByte(ABuf, AVal);
end;

procedure TBU24(var ABuf: TBytes; AVal: Integer);
begin
  QuicBufAppendByte(ABuf, Byte(AVal shr 16));
  QuicBufAppendByte(ABuf, Byte(AVal shr 8));
  QuicBufAppendByte(ABuf, Byte(AVal));
end;

procedure TBU16(var ABuf: TBytes; AVal: Word);
begin
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

function CoreRoot: string;
begin
  Result := FsPathAbs(FsPathJoin([FsPathDir(ParamStr(0)),
    '..', '..', '..', '..']));
end;

{ 与被测实现同构的服务端长包组装（独立副本保持测试独立性） }
function SrvLongPacket(AIsInitial: Boolean; const ADcid, AScid, AToken,
  AFrames: TBytes; APn: UInt64; const AKeys: TQuicPacketKeys;
  APad1200: Boolean): TBytes;
var
  LHdr, LPayload, LPkt: TBytes;
  LPad, LBodyLen, LTotal: UInt64;
  LType: TQuicLongType;
  LI: Integer;
begin
  Result := nil;
  if AIsInitial then
    LType := qltInitial
  else
    LType := qltHandshake;
  LHdr := nil;
  QuicBeginLongHeader(LHdr, LType, cQuicVersionV1, ADcid, AScid, AToken);
  LPad := 0;
  for LI := 0 to 2 do
  begin
    LBodyLen := UInt64(4) + UInt64(Length(AFrames)) + LPad + cQuicTagLen;
    LTotal := UInt64(Length(LHdr)) +
      UInt64(QuicVarintEncodedLen(LBodyLen)) + LBodyLen;
    if APad1200 and (LTotal < cQuicMinInitialDgram) then
      LPad := cQuicMinInitialDgram - LTotal
    else if APad1200 and (LTotal > cQuicMinInitialDgram) and
      (LPad >= LTotal - cQuicMinInitialDgram) then
      LPad := LPad - (LTotal - cQuicMinInitialDgram)
    else
      Break;
  end;
  LPayload := nil;
  TB(LPayload, AFrames);
  if LPad > 0 then
    for LI := 1 to Integer(LPad) do
      QuicBufAppendByte(LPayload, 0);
  LBodyLen := UInt64(4) + UInt64(Length(LPayload)) + cQuicTagLen;
  if not QuicVarintAppend(LHdr, LBodyLen) then
    Exit;
  LHdr[0] := QuicLongFirstByte(LType, 0, 3);
  LPkt := QuicProtectPacket(LHdr, APn, 4, LPayload, AKeys);
  Result := LPkt;
end;

{ RFC 9001 §5.8 黄金 Retry：常量密钥/nonce + Pseudo-Packet AAD。
  ACorruptTag=True 时翻转 tag 末字节（负向用例） }
function SrvRetryPacket(const AOdcid, ANewScid, AToken: TBytes;
  ACorruptTag: Boolean): TBytes;
var
  LPkt, LPseudo, LCipher, LTag: TBytes;
begin
  Result := nil;
  LPkt := nil;
  QuicBeginLongHeader(LPkt, qltRetry, cQuicVersionV1, AOdcid, ANewScid,
    nil);
  TB(LPkt, AToken);

  LPseudo := nil;
  QuicBufAppendByte(LPseudo, Byte(Length(AOdcid)));
  TB(LPseudo, AOdcid);
  TB(LPseudo, LPkt);

  if PurePascalAESGCMEncrypt(HexToBytes(cRetryKeyHex),
    HexToBytes(cRetryNonceHex), nil, LPseudo, LCipher, LTag) then
  begin
    if ACorruptTag then
      LTag[High(LTag)] := LTag[High(LTag)] xor $FF;
    TB(LPkt, LTag);
    Result := LPkt;
  end;
end;

function SrvInitFixture(out F: TSrvFixture): Boolean;
var
  LPem: TPEMReader;
  LCertPath, LKeyPath: string;
begin
  Result := False;
  GenerateX25519KeyPair(F.XPriv, F.XPub);
  F.Scid := GenerateSecureRandomBytes(8);
  LCertPath := FsPathJoin([CoreRoot, 'tests', 'nextpas.core.tls', 'certs',
    'server-cert.pem']);
  LKeyPath := FsPathJoin([CoreRoot, 'tests', 'nextpas.core.tls', 'certs',
    'server-key.pem']);
  LPem := TPEMReader.Create;
  try
    try
      LPem.LoadFromFile(LCertPath);
      F.CertDer := LPem.GetFirstBlockOfType(pemCertificate).Data;
    except
      Exit(False);
    end;
  finally
    LPem.Free;
  end;
  { RSA 私钥以整文件 PEM 形态交给签名器（其自带 PEM 分支解析） }
  F.KeyBlob := FsReadFile(LKeyPath);
  Result := (Length(F.CertDer) > 0) and (Length(F.KeyBlob) > 0);
end;

{ 服务端完整飞行。输出：Initial 数据报（含 SH）+ 两段 Handshake 数据报
  （EeMsg | Cert+CV+Fin 拆分），供顺序/乱序/coalesced 用例复用。
  F.Transcript 终态 = CH..SF——恰为客户端 Fin 的 verify_data 基线
  （RFC 8446 §4.4.4：客户端 Finished 覆盖「through the server's Finished」，
  含服务器 Finished 本消息；2026-08-23 aioquic 对拍修正）。
  AHsReadKeys = 服务端握手读钥（= 客户端写方向）。 }
function SrvFlight(var F: TSrvFixture; const ACh: TBytes;
  AMode: TSrvFlightMode; const AClientDcid: TBytes;
  out AInitDgram, AHsFirst, AHsSecond: TBytes;
  out AHsReadKeys: TQuicPacketKeys): Boolean;
var
  LInfo: TTLS13ClientHelloInfo;
  LErr: string;
  LShared, LSHBody, LExtList, LEntries, LEeBody, LM, LCertMsg, LCvm,
  LSig, LVData, LHsPayload, LAck, LFrames, LShMsg: TBytes;
  LTP: TQuicTransportParamArray;
  LInitKeys: TQuicPacketKeys;
  LRng: array[0..0] of TQuicAckRange;
begin
  Result := False;
  AInitDgram := nil;
  AHsFirst := nil;
  AHsSecond := nil;
  if not TryParseTLS13ClientHelloFromHandshake(ACh, LInfo, LErr) or
    (not LInfo.Valid) or (not LInfo.HasKeyShare) then
    Exit;

  LShared := X25519ComputeSharedSecret(F.XPriv, LInfo.PeerKeyShare);
  F.Transcript := nil;
  TB(F.Transcript, ACh);

  { ---- ServerHello（handshake 消息形态）---- }
  LExtList := nil;
  TBU16(LExtList, $002B);          { supported_versions }
  TBU16(LExtList, 2);
  TBU16(LExtList, $0304);
  TBU16(LExtList, $0033);          { key_share }
  TBU16(LExtList, Word(4 + Length(F.XPub)));
  TBU16(LExtList, $001D);          { x25519 }
  TBU16(LExtList, Word(Length(F.XPub)));
  TB(LExtList, F.XPub);

  LSHBody := nil;
  TBU16(LSHBody, $0303);
  TB(LSHBody, GenerateSecureRandomBytes(32));
  TBByte(LSHBody, Byte(Length(LInfo.LegacySessionID)));
  TB(LSHBody, LInfo.LegacySessionID);
  TBU16(LSHBody, cSuiteAes128);
  TBByte(LSHBody, 1);
  TBByte(LSHBody, 0);
  TBU16(LSHBody, Word(Length(LExtList)));
  TB(LSHBody, LExtList);

  LShMsg := nil;
  TBByte(LShMsg, 2);
  TBU24(LShMsg, Length(LSHBody));
  TB(LShMsg, LSHBody);
  TB(F.Transcript, LShMsg);

  { 握手密钥派生点：transcript 必须为 CH..ServerHello（RFC 8446 §7.1） }
  InitTLS13HandshakeSecrets(F.HsSecrets);
  if not TryDeriveTLS13HandshakeSecrets(cSuiteAes128, LShared,
    F.Transcript, F.HsSecrets, LErr) then
    Exit;

  { ---- EncryptedExtensions（ALPN + quic_transport_parameters）---- }
  LEntries := nil;
  TBU16(LEntries, $0010);          { alpn }
  TBU16(LEntries, 5);              { 2(list_len) + 1(name_len) + 2(name) }
  TBU16(LEntries, 3);
  TBByte(LEntries, 2);             { name_len 单字节 }
  if AMode = sfBadAlpn then
    TB(LEntries, BytesOf([$68, $58]))
  else
    TB(LEntries, BytesOf([$68, $33]));
  if AMode <> sfNoTp then
  begin
    LTP := nil;
    QuicParamAddVarint(LTP, cQuicParamMaxIdleTimeout, 60000);
    QuicParamAddEmpty(LTP, cQuicParamDisableActiveMigration);
    { RFC 9221 §3：缺省通告 65535；sfNoDgram 省略参数（不支持语义）；
      sfSmallDgram 收窄为 8（超界违规面） }
    if AMode = sfSmallDgram then
      QuicParamAddVarint(LTP, cQuicParamMaxDatagramFrameSize, 8)
    else if AMode <> sfNoDgram then
      QuicParamAddVarint(LTP, cQuicParamMaxDatagramFrameSize, 65535);
    QuicParamAddBytes(LTP, cQuicParamInitialSourceConnectionId, F.Scid);
    LM := EncodeQuicTransportParams(LTP);
    TBU16(LEntries, cQuicTpExtType);
    TBU16(LEntries, Word(Length(LM)));
    TB(LEntries, LM);
  end;
  LEeBody := nil;
  TBU16(LEeBody, Word(Length(LEntries)));
  TB(LEeBody, LEntries);
  LM := nil;
  TBByte(LM, 8);
  TBU24(LM, Length(LEeBody));
  TB(LM, LEeBody);
  F.EeMsg := LM;
  TB(F.Transcript, LM);

  { ---- Certificate（RFC 8446 §4.4.2：ctx ‖ u24 列表长 ‖ 条目）---- }
  LCertMsg := nil;
  TBByte(LCertMsg, 11);
  TBU24(LCertMsg, 1 + 3 + 3 + Length(F.CertDer) + 2);
  TBByte(LCertMsg, 0);             { 空 request_context }
  TBU24(LCertMsg, 3 + Length(F.CertDer) + 2);
  TBU24(LCertMsg, Length(F.CertDer));
  TB(LCertMsg, F.CertDer);
  TBU16(LCertMsg, 0);              { 空 extensions }
  TB(F.Transcript, LCertMsg);

  { ---- CertificateVerify（RSA-PSS-SHA256，签名至 Cert；server 上下文串）---- }
  LSig := nil;
  if not TryBuildTLS13CertificateVerifySignature(cSchemeRsaPssSha256,
    F.KeyBlob, BuildTLS13ServerCertificateVerifyInputSHA256(
    SHA256(GFx.Transcript)), LSig, LErr) then
    Exit;
  LCvm := nil;
  TBByte(LCvm, 15);
  TBU24(LCvm, 4 + Length(LSig));
  TBU16(LCvm, cSchemeRsaPssSha256);
  TBU16(LCvm, Word(Length(LSig)));
  TB(LCvm, LSig);
  if AMode = sfBadCv then
    LCvm[High(LCvm)] := LCvm[High(LCvm)] xor $01;
  TB(F.Transcript, LCvm);

  { ---- ServerFinished（自身验证覆盖至 CV；消息本体入 F.Transcript
    ——客户端 Fin 基线 = CH..SF，RFC 8446 §4.4.4）---- }
  LVData := TLS13ComputeFinishedVerifyDataFromTrafficSecretForCipherSuite(
    cSuiteAes128, GFx.HsSecrets.ServerHandshakeTrafficSecret,
    SHA256(GFx.Transcript));
  LM := nil;
  TBByte(LM, 20);
  TBU24(LM, Length(LVData));
  TB(LM, LVData);
  TB(F.Transcript, LM);
  if AMode = sfBadFin then
    LM[High(LM)] := LM[High(LM)] xor $01;

  { ---- 打包 ---- }
  LInitKeys := QuicMakePacketKeys(
    DeriveQuicInitialSecrets(AClientDcid).ServerSecret,
    qcsAes128GcmSha256);
  LFrames := nil;
  QuicCryptoAppend(LFrames, 0, LShMsg);
  AInitDgram := SrvLongPacket(True, nil, F.Scid, nil, LFrames, 0,
    LInitKeys, True);

  LHsPayload := nil;
  TB(LHsPayload, F.EeMsg);
  TB(LHsPayload, LCertMsg);
  TB(LHsPayload, LCvm);
  TB(LHsPayload, LM);
  AHsReadKeys := QuicMakePacketKeys(
    GFx.HsSecrets.ServerHandshakeTrafficSecret, qcsAes128GcmSha256);

  { 第一段：ACK(initial, pn0) + CRYPTO(0, EE)；第二段：CRYPTO(rest) }
  LFrames := nil;
  LRng[0].Lo := 0;
  LRng[0].Hi := 0;
  LAck := nil;
  if QuicAckAppend(LAck, 0, 0, LRng) then
    TB(LFrames, LAck);
  QuicCryptoAppend(LFrames, 0, SliceOf(LHsPayload, 0, Length(F.EeMsg)));
  AHsFirst := SrvLongPacket(False, nil, F.Scid, nil, LFrames, 0,
    AHsReadKeys, False);

  LFrames := nil;
  QuicCryptoAppend(LFrames, UInt64(Length(F.EeMsg)),
    SliceOf(LHsPayload, Length(F.EeMsg),
    Length(LHsPayload) - Length(F.EeMsg)));
  AHsSecond := SrvLongPacket(False, nil, F.Scid, nil, LFrames, 1,
    AHsReadKeys, False);
  Result := True;
end;

{ 从客户端首个 Initial 数据报解出 CH（测试侧自环解密）。
  AExpectedPnBase 为去保护时的 PN 解码基线。 }
function ExtractClientHelloFrom(const ADgram, AClientDcid: TBytes;
  out ACh: TBytes; out APn: UInt64): Boolean;
var
  LInfo: TQuicHeaderPeek;
  LKeysS: TQuicPacketKeys;
  LPayload: TBytes;
  LOfs, LEnd: Integer;
  LF: TQuicFrame;
  LRanges: TQuicAckRangeArray;
begin
  Result := False;
  ACh := nil;
  APn := 0;
  { 客户端发出的包用 client 方向密钥密封（RFC 9001 §5.2 "client in"） }
  LKeysS := QuicMakePacketKeys(
    DeriveQuicInitialSecrets(AClientDcid).ClientSecret,
    qcsAes128GcmSha256);
  if not TryPeekQuicHeader(ADgram, 0, LInfo) or
     (not LInfo.IsLong) or (LInfo.PacketType <> qltInitial) then
    Exit;
  if not TryQuicUnprotectPacket(ADgram, 0, LKeysS, 0, APn, LPayload) then
    Exit;
  LOfs := 0;
  LEnd := Length(LPayload);
  while LOfs < LEnd do
  begin
    if not TryQuicFrameParse(LPayload, LOfs, LEnd, LF, LRanges) then
      Exit;
    Inc(LOfs, LF.Consumed);
    if LF.Kind = qfkCrypto then
    begin
      ACh := SliceOf(LPayload, LF.DataOfs, LF.DataLen);
      Exit(True);
    end;
  end;
end;

function ExtractClientHello(const ADgram, AClientDcid: TBytes;
  out ACh: TBytes): Boolean;
var
  LDummy: UInt64;
begin
  Result := ExtractClientHelloFrom(ADgram, AClientDcid, ACh, LDummy);
end;

{ 标准参数的客户端连接 }
function MakeConn(AInsecure: Boolean;
  AHookTarget: THookTarget): TQuicClientConnection;
var
  P: TQuicClientParams;
begin
  P.Hostname := 'localhost';
  P.ALPN := 'h3';
  P.InsecureSkipVerify := AInsecure;
  P.CertVerifyHook := nil;
  if AHookTarget <> nil then
    P.CertVerifyHook := @AHookTarget.Hook;
  Result := TQuicClientConnection.Create(P);
end;

function PhaseName(APhase: TQuicConnPhase): string;
begin
  case APhase of
    qcpIdle: Result := 'idle';
    qcpInitialSent: Result := 'initial-sent';
    qcpHandshake: Result := 'handshake';
    qcpConnected: Result := 'connected';
  else
    Result := 'closed';
  end;
end;

{ 手工扫描 CH 扩展列表是否含指定类型（布局：
  type+len24+ver2+rand32+sidlen1+sid+cslen2+cs+complen1+comp+extlen2+exts）}
function ChHasExtensionType(const ACh: TBytes; AType: Word): Boolean;
var
  LPos, LN, LSidLen, LCsLen, LCompLen, LExtEnd, LEType, LELen: Integer;
begin
  Result := False;
  LN := Length(ACh);
  if LN < 6 then
    Exit;
  LPos := 4 + 2 + 32;
  if LPos >= LN then
    Exit;
  LSidLen := ACh[LPos];
  Inc(LPos, 1 + LSidLen);
  if LPos + 2 > LN then
    Exit;
  LCsLen := (ACh[LPos] shl 8) or ACh[LPos + 1];
  Inc(LPos, 2 + LCsLen);
  if LPos + 1 > LN then
    Exit;
  LCompLen := ACh[LPos];
  Inc(LPos, 1 + LCompLen);
  if LPos + 2 > LN then
    Exit;
  LExtEnd := LPos + 2 + ((ACh[LPos] shl 8) or ACh[LPos + 1]);
  Inc(LPos, 2);
  while LPos + 4 <= LExtEnd do
  begin
    LEType := (ACh[LPos] shl 8) or ACh[LPos + 1];
    LELen := (ACh[LPos + 2] shl 8) or ACh[LPos + 3];
    Inc(LPos, 4 + LELen);
    if LEType = AType then
      Exit(True);
  end;
end;

{ 一站式驱动：建连 → 取 CH → 构造指定模式飞行 → 投递全部三报文。
  返回时连接处于 Connected 或 Closed（负向模式）；失败返回 nil。
  注意：结果形态而非 out 形态——捕获变量作 out 实参在 FPC -O2 下不稳。 }
function DriveFull(AMode: TSrvFlightMode; AInsecure: Boolean;
  AUseRejectHook: Boolean): TQuicClientConnection;
var
  D1, DI, DA, DB: TBytes;
  LKeysR: TQuicPacketKeys;
  LCh: TBytes;
  LConn: TQuicClientConnection;
begin
  Result := nil;
  if not SrvInitFixture(GFx) then
    Exit;
  GHookTarget.Reject := AUseRejectHook;
  try
    if AUseRejectHook then
      LConn := MakeConn(AInsecure, GHookTarget)
    else
      LConn := MakeConn(AInsecure, nil);
    try
      LConn.Start;
      if not LConn.TakeOutbound(D1) then
      begin
        LConn.Free;
        Exit;
      end;
      if not ExtractClientHello(D1, LConn.LocalFirstDcid, LCh) then
      begin
        LConn.Free;
        Exit;
      end;
      if not SrvFlight(GFx, LCh, AMode, LConn.LocalFirstDcid, DI, DA, DB,
        LKeysR) then
      begin
        LConn.Free;
        Exit;
      end;
      LConn.OnDatagram(DI);
      LConn.OnDatagram(DA);
      LConn.OnDatagram(DB);
      Result := LConn;
    except
      LConn.Free;
      raise;
    end;
  finally
    GHookTarget.Reject := False;
  end;
end;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;

begin
  GHookTarget := THookTarget.Create;
  GQ5Col := TQ5Collector.Create;
  GQ5Dgm := TQ5DgramCollector.Create;

  LSuite := TTestSuite.Create('quic_conn');

  { ---------- 全流程正向 ---------- }
  LSuite.Test('happy path: full closure + client finished verified', procedure
  var
    Conn: TQuicClientConnection;
    DOut, DInit, DHsA, DHsB: TBytes;
    LPeek: TQuicHeaderPeek;
    LInfo2: TTLS13ClientHelloInfo;
    LErr: string;
    LCh: TBytes;
    LHsRead: TQuicPacketKeys;
    LPn: UInt64;
    LPayload: TBytes;
    LOfs, LEnd, LAckCount: Integer;
    LF: TQuicFrame;
    LRanges: TQuicAckRangeArray;
    LGotFin, LExpectFin: TBytes;
    LV: UInt64;
    LOk1: Boolean;
  begin
    Check(SrvInitFixture(GFx), 'fixture loaded');
    Conn := MakeConn(True, nil);
    try
      Conn.Start;
      Check(Conn.Phase = qcpInitialSent, 'phase initial-sent');
      Check(Conn.TakeOutbound(DOut), 'outbound #1 exists');
      Check(Length(DOut) >= cQuicMinInitialDgram, 'initial padded >=1200');

      { 头部结构：Initial / V1 / 无 token / SCID 零长 / DCID=8B }
      Check(TryPeekQuicHeader(DOut, 0, LPeek), 'peek ok');
      Check(LPeek.IsLong and (LPeek.PacketType = qltInitial), 'type initial');
      Check(LPeek.Version = cQuicVersionV1, 'version v1');
      Check(Length(LPeek.Token) = 0, 'no token before retry');
      Check(Length(LPeek.SrcCid) = 0, 'zero-len local scid');
      Check((Length(LPeek.DstCid) = 8) and
        BytesEqual(LPeek.DstCid, Conn.LocalFirstDcid), 'dcid = local first');

      { 自解密取 CH 并回验 }
      Check(ExtractClientHello(DOut, Conn.LocalFirstDcid, LCh),
        'self roundtrip decrypt');
      Check((Length(LCh) > 500) and (Length(LCh) < 700),
        'ch size plausible (~567B; 1200 via padding)');
      Check(TryParseTLS13ClientHelloFromHandshake(LCh, LInfo2, LErr) and
        LInfo2.Valid, 'ch parses: ' + LErr);
      Check(LInfo2.HasKeyShare and (LInfo2.KeyShareGroup = $001D) and
        (Length(LInfo2.PeerKeyShare) = 32), 'x25519 key share present');
      Check(TLS13ClientHelloOffersALPNProtocol(LInfo2, 'h3'), 'alpn h3');
      Check(ChHasExtensionType(LCh, cQuicTpExtType), 'tp ext injected');

      { 服务端飞行：SH → 握手相位；EE/Cert/CV/Fin → 连接 }
      Check(SrvFlight(GFx, LCh, sfOk, Conn.LocalFirstDcid, DInit, DHsA,
        DHsB, LHsRead), 'flight built');
      Check(Conn.OnDatagram(DInit), 'feed initial err=' + Conn.LastError);
      Check(Conn.Phase = qcpHandshake, 'phase handshake after SH');
      LOk1 := Conn.OnDatagram(DHsA);
      if not LOk1 then
        Check(False, 'feed hs first: ' + Conn.LastError + ' ph=' +
          PhaseName(Conn.Phase));
      LOk1 := Conn.OnDatagram(DHsB);
      if not LOk1 then
        Check(False, 'feed hs second: ' + Conn.LastError + ' ph=' +
          PhaseName(Conn.Phase));
      Check((LOk1) and (Conn.Phase = qcpConnected), 'phase connected');
      Check(Conn.PeerParamsValid, 'peer params valid');
      LV := 0;
      Check(QuicParamGetVarint(Conn.PeerParams, cQuicParamMaxIdleTimeout,
        LV) and (LV = 60000), 'tp value decoded');
      Check(Length(Conn.ApplicationWriteKeys.Key) = 16, 'app write key');

      { 客户端 Finished 包：Handshake 长头形态（握手密钥保护，RFC 9000
        §17.2；短头属 1-RTT 应用空间）+ 服务端视角解密 + 帧面 }
      Check(Conn.TakeOutbound(DOut), 'client fin outbound');
      Check((DOut[0] and $80) <> 0, 'long header form');
      Check(((DOut[0] shr 4) and $03) = 2, 'handshake packet type');
      LHsRead := QuicMakePacketKeys(
        GFx.HsSecrets.ClientHandshakeTrafficSecret, qcsAes128GcmSha256);
      LPn := 99;
      Check(TryQuicUnprotectPacket(DOut, 0, LHsRead, 0, LPn, LPayload),
        'client fin decrypts with server hs keys');
      Check(LPn = 0, 'fin pn0');
      LAckCount := 0;
      LGotFin := nil;
      LOfs := 0;
      LEnd := Length(LPayload);
      while LOfs < LEnd do
      begin
        Check(TryQuicFrameParse(LPayload, LOfs, LEnd, LF, LRanges),
          'fin frames parse');
        Inc(LOfs, LF.Consumed);
        if LF.Kind = qfkAck then
          Inc(LAckCount);
        if LF.Kind = qfkCrypto then
          LGotFin := SliceOf(LPayload, LF.DataOfs, LF.DataLen);
      end;
      Check(LAckCount = 2, 'ack for both spaces carried');
      Check(Length(LGotFin) > 4, 'crypto fin frame present');
      { 基线 = CH..SF（夹具 F.Transcript 终态已含服务器 Finished，
        RFC 8446 §4.4.4） }
      LExpectFin :=
        TLS13ComputeFinishedVerifyDataFromTrafficSecretForCipherSuite(
        cSuiteAes128, GFx.HsSecrets.ClientHandshakeTrafficSecret,
        SHA256(GFx.Transcript));
      Check(BytesEqual(SliceOf(LGotFin, 4, Length(LGotFin) - 4),
        LExpectFin), 'client fin verify_data matches expectation');
    finally
      Conn.Free;
    end;
  end);

  { ---------- coalesced 数据报一次投递 ---------- }
  LSuite.Test('coalesced datagram: initial+handshake in one feed', procedure
  var
    Conn: TQuicClientConnection;
    D1, DI, DA, DB, DAll: TBytes;
    LKeysR: TQuicPacketKeys;
    LCh: TBytes;
  begin
    Check(SrvInitFixture(GFx), 'fixture loaded');
    Conn := MakeConn(True, nil);
    try
      Conn.Start;
      Check(Conn.TakeOutbound(D1), 'outbound #1');
      Check(ExtractClientHello(D1, Conn.LocalFirstDcid, LCh), 'ch extracted');
      Check(SrvFlight(GFx, LCh, sfOk, Conn.LocalFirstDcid, DI, DA, DB,
        LKeysR), 'flight built');
      DAll := ConcatBytes(ConcatBytes(DI, DA), DB);
      Check(Conn.OnDatagram(DAll), 'coalesced err=' + Conn.LastError);
      Check(Conn.Phase = qcpConnected, 'connected via coalesced dgram');
    finally
      Conn.Free;
    end;
  end);

  { ---------- 握手空间 CRYPTO 乱序重组 ---------- }
  LSuite.Test('handshake crypto reorder: second segment held then chained', procedure
  var
    Conn: TQuicClientConnection;
    D1, DI, DA, DB: TBytes;
    LKeysR: TQuicPacketKeys;
    LCh: TBytes;
  begin
    Check(SrvInitFixture(GFx), 'fixture loaded');
    Conn := MakeConn(True, nil);
    try
      Conn.Start;
      Check(Conn.TakeOutbound(D1), 'outbound #1');
      Check(ExtractClientHello(D1, Conn.LocalFirstDcid, LCh), 'ch extracted');
      Check(SrvFlight(GFx, LCh, sfOk, Conn.LocalFirstDcid, DI, DA, DB,
        LKeysR), 'flight built');
      Check(Conn.OnDatagram(DI), 'feed initial');
      { 后段先到：进暂存，不破坏状态 }
      Check(Conn.OnDatagram(DB), 'second segment first (held)');
      Check(Conn.Phase = qcpHandshake, 'still handshake phase while held');
      { 前段到达：链式消费后段并完成握手 }
      Check(Conn.OnDatagram(DA), 'first segment completes stream');
      Check(Conn.Phase = qcpConnected, 'connected after reorder');
    finally
      Conn.Free;
    end;
  end);

  { ---------- Retry 正向：完整性验证通过 → 换钥重发 ---------- }
  LSuite.Test('retry integrity ok: resync keys and resend CH', procedure
  var
    Conn: TQuicClientConnection;
    D1, D2, LOdcid, LNewScid, LToken, LRetry, LCh1, LCh2: TBytes;
    LPk: TQuicHeaderPeek;
    LPn: UInt64;
  begin
    Check(SrvInitFixture(GFx), 'fixture loaded');
    Conn := MakeConn(True, nil);
    try
      Conn.Start;
      Check(Conn.TakeOutbound(D1), 'outbound #1');
      Check(ExtractClientHello(D1, Conn.LocalFirstDcid, LCh1), 'ch #1');
      LOdcid := SliceOf(Conn.LocalFirstDcid, 0, Length(Conn.LocalFirstDcid));
      LNewScid := GenerateSecureRandomBytes(8);
      LToken := GenerateSecureRandomBytes(16);
      LRetry := SrvRetryPacket(LOdcid, LNewScid, LToken, False);
      Check(Length(LRetry) > 0, 'retry built');
      Check(Conn.OnDatagram(LRetry), 'retry processed');
      Check(Conn.Phase = qcpInitialSent, 'phase still initial-sent');

      Check(Conn.TakeOutbound(D2), 'retransmit queued err=' + Conn.LastError);
      Check(TryPeekQuicHeader(D2, 0, LPk), 'peek retransmit');
      Check(LPk.PacketType = qltInitial, 'retransmit is initial');
      Check(BytesEqual(LPk.Token, LToken), 'token echoed into header');
      Check(BytesEqual(LPk.DstCid, LNewScid), 'dcid switched to retry scid');
      { ODCID 是既成事实，客户端不轮换（RFC 9000 §7.2 只要求换 DCID 目标） }
      Check(BytesEqual(Conn.LocalFirstDcid, LOdcid), 'odcid preserved');

      { 新密钥下可解出同一段 CH（offset 0 重发）；自环解密按线上新 DCID 取钥 }
      Check(ExtractClientHelloFrom(D2, LNewScid, LCh2, LPn) and
        (LPn = 0), 'ch re-decrypts under new keys at pn0');
      Check(Length(LCh2) = Length(LCh1), 'same CH resent');
    finally
      Conn.Free;
    end;
  end);

  { ---------- Retry 负向：tag 篡改静默丢弃 ---------- }
  LSuite.Test('retry integrity bad tag: silently dropped', procedure
  var
    Conn: TQuicClientConnection;
    D1, LOdcid, LNewScid, LToken, LRetry, DNext: TBytes;
  begin
    Check(SrvInitFixture(GFx), 'fixture loaded');
    Conn := MakeConn(True, nil);
    try
      Conn.Start;
      Check(Conn.TakeOutbound(D1), 'outbound #1');
      LOdcid := SliceOf(Conn.LocalFirstDcid, 0, Length(Conn.LocalFirstDcid));
      LNewScid := GenerateSecureRandomBytes(8);
      LToken := GenerateSecureRandomBytes(16);
      LRetry := SrvRetryPacket(LOdcid, LNewScid, LToken, True);
      Check(Length(LRetry) > 0, 'corrupt retry built');
      Check(Conn.OnDatagram(LRetry), 'datagram handled without crash');
      Check(Conn.Phase = qcpInitialSent, 'phase unchanged');
      Check(not Conn.TakeOutbound(DNext), 'no resync outbound');
    finally
      Conn.Free;
    end;
  end);

  { ---------- OnTimer 重发 + ACK 结算停发 ---------- }
  LSuite.Test('timer: retransmit until ack settles', procedure
  var
    Conn: TQuicClientConnection;
    D1, D2, LCh1, LCh2, LScid8, LAckBuf, LPkt, DD: TBytes;
    LKeysS: TQuicPacketKeys;
    LRng: array[0..0] of TQuicAckRange;
    LPn: UInt64;
  begin
    Check(SrvInitFixture(GFx), 'fixture loaded');
    Conn := MakeConn(True, nil);
    try
      Conn.Start;
      Check(Conn.TakeOutbound(D1), 'outbound #1');
      Check(ExtractClientHello(D1, Conn.LocalFirstDcid, LCh1), 'ch #1');

      { 阈值未到：不发 }
      Conn.OnTimer(100000);
      Check(not Conn.TakeOutbound(DD), 'no resend below threshold');

      { 超阈：重发同一 CH（pn1，同钥） }
      Conn.OnTimer(300000);
      Check(Conn.TakeOutbound(D2), 'resend after threshold');
      Check(ExtractClientHelloFrom(D2, Conn.LocalFirstDcid, LCh2, LPn) and
        (LPn = 1), 'retransmit decrypts at pn1');
      Check(Length(LCh2) = Length(LCh1), 'same CH retransmitted');

      { 服务端 ACK([0..1]) 结算后停发 }
      LScid8 := GenerateSecureRandomBytes(8);
      LAckBuf := nil;
      LRng[0].Lo := 0;
      LRng[0].Hi := 1;
      Check(QuicAckAppend(LAckBuf, 1, 0, LRng), 'ack frame built');
      LKeysS := QuicMakePacketKeys(
        DeriveQuicInitialSecrets(Conn.LocalFirstDcid).ServerSecret,
        qcsAes128GcmSha256);
      LPkt := SrvLongPacket(True, nil, LScid8, nil, LAckBuf, 0,
        LKeysS, True);
      Check(Conn.OnDatagram(LPkt), 'ack-only initial processed');
      while Conn.TakeOutbound(DD) do
        ;   { 清空队列 }
      Conn.OnTimer(1000000);
      Check(not Conn.TakeOutbound(DD), 'no resend after settle');
    finally
      Conn.Free;
    end;
  end);

  { ---------- 负向：严格模式无钩子即拒（fail-closed） ---------- }
  LSuite.Test('strict mode without hook: fail closed', procedure
  var
    Conn: TQuicClientConnection;
  begin
    Conn := DriveFull(sfOk, False, False);
    try
      Check(Conn <> nil, 'drive attempted');
      if Conn <> nil then
      begin
        Check(Conn.Phase = qcpClosed, 'closed in strict mode');
        Check(Pos('chain verification', Conn.LastError) > 0,
          'error names chain verification: ' + Conn.LastError);
      end;
    finally
      Conn.Free;
    end;
  end);

  { ---------- 负向：钩子拒绝 ---------- }
  LSuite.Test('cert verify hook rejection: fail closed', procedure
  var
    Conn: TQuicClientConnection;
  begin
    Conn := DriveFull(sfOk, False, True);
    try
      Check(Conn <> nil, 'drive attempted');
      if Conn <> nil then
      begin
        Check(Conn.Phase = qcpClosed, 'closed on hook reject');
        Check(Pos('hook', Conn.LastError) > 0, 'error names hook: ' +
          Conn.LastError);
      end;
    finally
      Conn.Free;
    end;
  end);

  { ---------- 负向四态 ---------- }
  LSuite.Test('negative: alpn mismatch fails closed', procedure
  var
    Conn: TQuicClientConnection;
  begin
    Conn := DriveFull(sfBadAlpn, True, False);
    try
      Check(Conn <> nil, 'drive attempted');
      if Conn <> nil then
      begin
        Check(Conn.Phase = qcpClosed, 'closed');
        Check(Pos('alpn mismatch', Conn.LastError) > 0, 'alpn error: ' +
          Conn.LastError);
      end;
    finally
      Conn.Free;
    end;
  end);

  LSuite.Test('negative: missing transport parameters fails closed', procedure
  var
    Conn: TQuicClientConnection;
  begin
    Conn := DriveFull(sfNoTp, True, False);
    try
      Check(Conn <> nil, 'drive attempted');
      if Conn <> nil then
      begin
        Check(Conn.Phase = qcpClosed, 'closed');
        Check(Pos('transport parameters', Conn.LastError) > 0, 'tp error: ' +
          Conn.LastError);
        Check(not Conn.PeerParamsValid, 'params not marked valid');
      end;
    finally
      Conn.Free;
    end;
  end);

  LSuite.Test('negative: tampered certificate verify fails closed', procedure
  var
    Conn: TQuicClientConnection;
  begin
    Conn := DriveFull(sfBadCv, True, False);
    try
      Check(Conn <> nil, 'drive attempted');
      if Conn <> nil then
      begin
        Check(Conn.Phase = qcpClosed, 'closed');
        Check(Pos('certificate verify', Conn.LastError) > 0, 'cv error: ' +
          Conn.LastError);
      end;
    finally
      Conn.Free;
    end;
  end);

  LSuite.Test('negative: tampered server finished fails closed', procedure
  var
    Conn: TQuicClientConnection;
  begin
    Conn := DriveFull(sfBadFin, True, False);
    try
      Check(Conn <> nil, 'drive attempted');
      if Conn <> nil then
      begin
        Check(Conn.Phase = qcpClosed, 'closed');
        Check(Pos('finished mismatch', Conn.LastError) > 0, 'fin error: ' +
          Conn.LastError);
        Check(Length(Conn.ApplicationWriteKeys.Key) = 0,
          'no app keys leaked into closed conn');
      end;
    finally
      Conn.Free;
    end;
  end);

  { ---------- 源码契约：新单元不得裸 uses FPC RTL ---------- }
  { ---------- Q5 应用平面接线 ---------- }
  LSuite.Test('q5: stream open gate fail-closed then unlocked by peer', procedure
  var
    Conn: TQuicClientConnection;
    LId, LPn: UInt64;
    LFrames, LPkt, LPayload: TBytes;
    LF: TQuicFrame;
  begin
    Conn := DriveFull(sfOk, True, False);
    try
      Check(Conn <> nil, 'drive attempted');
      Check(Conn.Phase = qcpConnected, 'connected');
      if Conn = nil then
        Exit;
      { 夹具服务器参数不含流控授予 ⇒ fail-closed 拒开 }
      CheckFalse(Conn.OpenStream(False, LId), 'no grant fail-closed');
      CheckFalse(Conn.OpenStream(True, LId), 'no uni grant fail-closed');
      { 注入服务器 MAX_STREAMS(bidi=2,uni=1) + MAX_DATA(65536) 包 }
      LFrames := nil;
      QuicMaxStreamsAppend(LFrames, True, 2);
      QuicMaxStreamsAppend(LFrames, False, 1);
      QuicMaxDataAppend(LFrames, 65536);
      LPkt := QuicProtectPacket(BytesOf([$43]), 0, 4, LFrames,
        Conn.ApplicationReadKeys);
      CheckTrue(Conn.OnDatagram(LPkt), 'grant packet accepted');
      CheckTrue(Conn.OpenStream(False, LId), 'bidi unlocked');
      CheckEqual(UInt64(0), LId);
      CheckTrue(Conn.OpenStream(False, LId));
      CheckEqual(UInt64(4), LId);
      CheckFalse(Conn.OpenStream(False, LId), 'grant of 2 exhausted');
      CheckTrue(Conn.OpenStream(True, LId), 'uni unlocked');
      CheckEqual(UInt64(2), LId);
    finally
      Conn.Free;
    end;
  end);

  LSuite.Test('q5: stream write emits protected stream frame', procedure
  var
    Conn: TQuicClientConnection;
    LId, LPn: UInt64;
    LFrames, LPkt, LPayload, LData: TBytes;
    LF: TQuicFrame;
    LPos: Integer;
    LOk: Boolean;
  begin
    Conn := DriveFull(sfOk, True, False);
    try
      Check(Conn <> nil, 'drive attempted');
      if Conn = nil then
        Exit;
      { 第一步：连接级授予解锁开流（MAX_STREAMS + MAX_DATA） }
      LFrames := nil;
      QuicMaxStreamsAppend(LFrames, True, 4);
      QuicMaxDataAppend(LFrames, 65536);
      LPkt := QuicProtectPacket(BytesOf([$43]), 0, 4, LFrames,
        Conn.ApplicationReadKeys);
      CheckTrue(Conn.OnDatagram(LPkt), 'grants accepted');
      Conn.OnTimer(1000000);   { 建立时钟基准 }
      CheckTrue(Conn.OpenStream(False, LId));
      CheckEqual(UInt64(0), LId);
      { 第二步：对已存在的流 0 注入流级授予（先开后授路径） }
      LFrames := nil;
      QuicMaxStreamDataAppend(LFrames, 0, 65536);
      LPkt := QuicProtectPacket(BytesOf([$43]), 1, 4, LFrames,
        Conn.ApplicationReadKeys);
      CheckTrue(Conn.OnDatagram(LPkt), 'stream grant accepted');
      LData := BytesOf([Ord('p'), Ord('i'), Ord('n'), Ord('g')]);
      CheckTrue(Conn.StreamWrite(0, LData, True), 'write accepted');
      { 出站队列：授予包已消费，此处应为应用空间短头包（首帧为随包
        ACK，需遍历载荷定位 STREAM 帧） }
      LOk := False;
      while Conn.TakeOutbound(LPkt) do
      begin
        if (Length(LPkt) > 0) and ((LPkt[0] and $80) = 0) then
        begin
          { 我方出站包 DCID=服务器 SCID（夹具 8 字节） }
          CheckTrue(TryQuicUnprotectPacket(LPkt, 8,
            Conn.ApplicationWriteKeys, 0, LPn, LPayload),
            'unprotect with app write keys');
          LPos := 0;
          while LPos < Length(LPayload) do
          begin
            if not TryQuicFrameParse(LPayload, LPos, Length(LPayload),
              LF) then
              Break;
            Inc(LPos, LF.Consumed);
            if Ord(LF.Kind) = Ord(qfkStream) then
            begin
              LOk := True;
              CheckEqual(UInt64(0), LF.StreamId, 'stream id');
              CheckEqual(UInt64(0), LF.Offset, 'offset');
              CheckEqual(True, LF.Fin, 'fin bit');
              CheckEqual(4, LF.DataLen, 'data len');
              Break;
            end;
          end;
        end;
      end;
      CheckTrue(LOk, 'stream frame found in outbound');
    finally
      Conn.Free;
    end;
  end);

  LSuite.Test('q5: inbound stream data reassembles across packets', procedure
  var
    Conn: TQuicClientConnection;
    LFrames, LPkt: TBytes;
  begin
    GQ5Col.Clear;
    Conn := DriveFull(sfOk, True, False);
    try
      Check(Conn <> nil, 'drive attempted');
      if Conn = nil then
        Exit;
      Conn.HookStreamData(@GQ5Col.OnData);
      { 先发尾部段（ofs=2, fin），再发头部段（ofs=0）——乱序到达 }
      LFrames := nil;
      QuicStreamAppend(LFrames, 1, 2, BytesOf([Ord('C'), Ord('D')]),
        True, True);
      LPkt := QuicProtectPacket(BytesOf([$43]), 0, 4, LFrames,
        Conn.ApplicationReadKeys);
      CheckTrue(Conn.OnDatagram(LPkt), 'tail segment fed');
      CheckEqual(0, GQ5Col.Count, 'gap holds delivery');
      LFrames := nil;
      QuicStreamAppend(LFrames, 1, 0, BytesOf([Ord('A'), Ord('B')]),
        False, True);
      LPkt := QuicProtectPacket(BytesOf([$43]), 1, 4, LFrames,
        Conn.ApplicationReadKeys);
      CheckTrue(Conn.OnDatagram(LPkt), 'head segment fed');
      { 交付设计：数据段不带 fin，final size 达成时补独立零长 FIN 事件 }
      CheckEqual(3, GQ5Col.Count, 'ordered delivery + fin event');
      CheckTrue(GQ5Col.Texts[0] = 'AB', 'first window text');
      CheckFalse(GQ5Col.Fins[0], 'first not fin');
      CheckTrue(GQ5Col.Texts[1] = 'CD', 'second window text');
      CheckFalse(GQ5Col.Fins[1], 'data segment carries no fin');
      CheckTrue(GQ5Col.Texts[2] = '', 'fin event zero length');
      CheckTrue(GQ5Col.Fins[2], 'fin event flagged');
    finally
      Conn.Free;
    end;
  end);

  { ---------- E3 RFC 9221 数据报平面 ---------- }
  LSuite.Test('e3: datagram negotiated via transport parameters', procedure
  var
    Conn: TQuicClientConnection;
  begin
    Conn := DriveFull(sfOk, True, False);
    try
      Check(Conn <> nil, 'drive attempted');
      if Conn = nil then
        Exit;
      CheckTrue(Conn.DatagramSupported, 'peer announced support');
      CheckEqual(65535, Conn.PeerMaxDatagramSize, 'announced limit');
    finally
      Conn.Free;
    end;
  end);

  LSuite.Test('e3: datagram send fail-closed faces', procedure
  var
    Conn, LIdle: TQuicClientConnection;
  begin
    { 未连接直接拒（新实例未 Start） }
    LIdle := MakeConn(True, nil);
    try
      CheckFalse(LIdle.SendDatagram(BytesOf([1])), 'not connected rejects');
      CheckFalse(LIdle.DatagramSupported, 'idle not negotiated');
    finally
      LIdle.Free;
    end;
    { 对端未通告：握手正常完成但数据报面关闭 }
    Conn := DriveFull(sfNoDgram, True, False);
    try
      Check(Conn <> nil, 'drive attempted');
      if Conn = nil then
        Exit;
      CheckTrue(Conn.Phase = qcpConnected, 'handshake completed');
      CheckFalse(Conn.DatagramSupported, 'missing TP means unsupported');
      CheckFalse(Conn.SendDatagram(BytesOf([1])), 'send rejected');
    finally
      Conn.Free;
    end;
  end);

  LSuite.Test('e3: datagram over peer limit rejected', procedure
  var
    Conn: TQuicClientConnection;
    LSix, LSeven: TBytes;
  begin
    Conn := DriveFull(sfSmallDgram, True, False);
    try
      Check(Conn <> nil, 'drive attempted');
      if Conn = nil then
        Exit;
      CheckTrue(Conn.DatagramSupported, 'small window announced');
      CheckEqual(8, Conn.PeerMaxDatagramSize, 'limit is 8');
      LSix := BytesOf([1, 2, 3, 4, 5, 6]);
      LSeven := BytesOf([1, 2, 3, 4, 5, 6, 7]);
      CheckTrue(Conn.SendDatagram(LSix),
        'frame 1+1+6=8 fits exactly');
      CheckFalse(Conn.SendDatagram(LSeven),
        'frame 1+1+7=9 exceeds limit');
    finally
      Conn.Free;
    end;
  end);

  LSuite.Test('e3: datagram send emits protected with-length frame', procedure
  var
    Conn: TQuicClientConnection;
    LPn: UInt64;
    LPkt, LPayload, LD: TBytes;
    LF: TQuicFrame;
    LPos, LI: Integer;
    LOk: Boolean;
  begin
    Conn := DriveFull(sfOk, True, False);
    try
      Check(Conn <> nil, 'drive attempted');
      if Conn = nil then
        Exit;
      Conn.OnTimer(1000000);   { 时钟基准 }
      LD := BytesOf([Ord('h'), Ord('i'), Ord('d'), Ord('g'), Ord('!')]);
      CheckTrue(Conn.SendDatagram(LD), 'send accepted');
      LOk := False;
      while Conn.TakeOutbound(LPkt) do
      begin
        if (Length(LPkt) > 0) and ((LPkt[0] and $80) = 0) then
        begin
          CheckTrue(TryQuicUnprotectPacket(LPkt, 8,
            Conn.ApplicationWriteKeys, 0, LPn, LPayload),
            'unprotect outbound with app write keys');
          LPos := 0;
          while LPos < Length(LPayload) do
          begin
            if not TryQuicFrameParse(LPayload, LPos, Length(LPayload),
              LF) then
              Break;
            Inc(LPos, LF.Consumed);
            if Ord(LF.Kind) = Ord(qfkDatagram) then
            begin
              LOk := True;
              CheckEqual(UInt64(cQfDatagramWithLength), LF.FrameType,
                'with-length form on wire');
              CheckEqual(5, LF.DataLen, 'data len');
              CheckTrue(LF.DataLen = Length(LD), 'payload present');
              for LI := 0 to Length(LD) - 1 do
                CheckEqual(Integer(LD[LI]),
                  Integer(LPayload[LF.DataOfs + LI]), 'byte match');
              Break;
            end;
          end;
        end;
      end;
      CheckTrue(LOk, 'datagram frame found in outbound');
    finally
      Conn.Free;
    end;
  end);

  LSuite.Test('e3: datagram receive delivers coalesced via callback', procedure
  var
    Conn: TQuicClientConnection;
    LFrames, LPkt: TBytes;
  begin
    GQ5Dgm.Clear;
    Conn := DriveFull(sfOk, True, False);
    try
      Check(Conn <> nil, 'drive attempted');
      if Conn = nil then
        Exit;
      Conn.HookDatagram(@GQ5Dgm.OnDgram);
      { 同包两条数据报：WITH_LENGTH 定界语义 }
      LFrames := nil;
      QuicDatagramAppend(LFrames,
        BytesOf([Ord('A'), Ord('B'), Ord('C')]));
      QuicDatagramAppend(LFrames, BytesOf([Ord('D'), Ord('E')]));
      LPkt := QuicProtectPacket(BytesOf([$43]), 0, 4, LFrames,
        Conn.ApplicationReadKeys);
      CheckTrue(Conn.OnDatagram(LPkt), 'datagram packet fed');
      CheckEqual(2, GQ5Dgm.Count, 'both delivered in order');
      CheckTrue(GQ5Dgm.Datas[0] = 'ABC', 'first payload');
      CheckTrue(GQ5Dgm.Datas[1] = 'DE', 'second payload');
    finally
      Conn.Free;
    end;
  end);

  LSuite.Test('e3: datagram receive violations are fatal', procedure
  var
    Conn: TQuicClientConnection;
    LFrames, LPkt: TBytes;
  begin
    { 未通告对端发来 DATAGRAM = PROTOCOL_VIOLATION（RFC 9221 §5） }
    Conn := DriveFull(sfNoDgram, True, False);
    try
      Check(Conn <> nil, 'drive attempted');
      if Conn = nil then
        Exit;
      LFrames := nil;
      QuicDatagramAppend(LFrames, BytesOf([1, 2, 3]));
      LPkt := QuicProtectPacket(BytesOf([$43]), 0, 4, LFrames,
        Conn.ApplicationReadKeys);
      { OnDatagram 返回值 = 连接仍存活；违规即 False }
      CheckFalse(Conn.OnDatagram(LPkt), 'feed reports closed');
      CheckTrue(Conn.Phase = qcpClosed, 'unsupported closes connection');
      CheckTrue(Pos('datagram', Conn.LastError) > 0, 'error names cause');
    finally
      Conn.Free;
    end;
    { 超对端通告上界的帧同罪 }
    GQ5Dgm.Clear;
    Conn := DriveFull(sfSmallDgram, True, False);
    try
      Check(Conn <> nil, 'drive attempted');
      if Conn = nil then
        Exit;
      Conn.HookDatagram(@GQ5Dgm.OnDgram);
      LFrames := nil;
      QuicDatagramAppend(LFrames, BytesOf([1, 2, 3, 4, 5, 6, 7]));
      LPkt := QuicProtectPacket(BytesOf([$43]), 0, 4, LFrames,
        Conn.ApplicationReadKeys);
      CheckFalse(Conn.OnDatagram(LPkt), 'oversize feed reports closed');
      CheckTrue(Conn.Phase = qcpClosed, 'oversize closes connection');
      CheckEqual(0, GQ5Dgm.Count, 'no delivery on violation');
    finally
      Conn.Free;
    end;
  end);

  LSuite.Test('e3: datagram queue bound under blocked congestion window',
    procedure
  var
    Conn: TQuicClientConnection;
    LId: UInt64;
    LFrames, LPkt, LChunk: TBytes;
    LI, LFirstReject: Integer;
  begin
    Conn := DriveFull(sfOk, True, False);
    try
      Check(Conn <> nil, 'drive attempted');
      if Conn = nil then
        Exit;
      Conn.OnTimer(1000000);
      LFrames := nil;
      QuicMaxStreamsAppend(LFrames, True, 4);
      QuicMaxDataAppend(LFrames, 400000);
      LPkt := QuicProtectPacket(BytesOf([$43]), 0, 4, LFrames,
        Conn.ApplicationReadKeys);
      CheckTrue(Conn.OnDatagram(LPkt), 'connection grants');
      CheckTrue(Conn.OpenStream(False, LId), 'stream open');
      LFrames := nil;
      QuicMaxStreamDataAppend(LFrames, 0, 400000);
      LPkt := QuicProtectPacket(BytesOf([$43]), 1, 4, LFrames,
        Conn.ApplicationReadKeys);
      CheckTrue(Conn.OnDatagram(LPkt), 'stream grant');
      { 100KB 流量远超初始拥塞窗：窗口持续堵死，ACK 不至则不泄 }
      SetLength(LChunk, 1000);
      for LI := 0 to 99 do
        CheckTrue(Conn.StreamWrite(LId, LChunk, False), 'fill window');
      { 队列容量 32：允许个别数据报随余量泄出，但必在上界附近拒绝 }
      LFirstReject := -1;
      for LI := 0 to 63 do
      begin
        if not Conn.SendDatagram(LChunk) then
        begin
          LFirstReject := LI;
          Break;
        end;
      end;
      CheckTrue((LFirstReject >= 0) and (LFirstReject <= 34),
        'queue bound hit within cap+slack');
      CheckFalse(Conn.SendDatagram(LChunk),
        'stays full while window blocked');
    finally
      Conn.Free;
    end;
  end);

  LSuite.Test('source contract: no bare FPC RTL in quic.conn', procedure
  var
    LSrcPath, LHit: string;
  begin
    LSrcPath := FsPathAbs(FsPathJoin([FsPathDir(ParamStr(0)),
      '..', '..', '..', '..', 'src', 'nextpas.core.net.quic.conn.pas']));
    Check(not FindBareFpcRtlInUses(FsReadFileText(LSrcPath), LHit),
      'conn — no bare FPC RTL (hit: ' + LHit + ')');
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.net.quic.conn');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  GHookTarget.Free;
  GHookTarget := nil;
  GQ5Col.Free;
  GQ5Col := nil;
  GQ5Dgm.Free;
  GQ5Dgm := nil;
  if not LRunner.AllPassed then Halt(1);
end.
