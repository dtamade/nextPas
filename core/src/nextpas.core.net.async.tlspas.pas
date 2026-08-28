unit nextpas.core.net.async.tlspas;

{$WARN 5025 off} // deprecated alias unit
{**
 * Async TLS 1.3 client stream over TAsyncLoop — 纯 Pascal 协议栈，
 * 零 OpenSSL、零第三方代理运行时（对齐 proxy888 最高规则 S1 自写协议基线）。
 *
 * 组成：密码学与线材构件全部复用 core 既有单元（tls13.clienthello /
 * parser / wire / recordcrypto / aead / keyschedule / finished /
 * appschedule / recordsealer / servercertificate），本单元只补缺失的
 * 一块：非阻塞记录泵 + 事件循环状态机。
 *
 * CONTRACT（与 nextpas.core.net.async.tls 同构，差异点见下）：
 * - 流面铁律：底层收发一律经 IAsyncTcpStream.AsyncRead/AsyncWrite，
 *   不触碰裸 fd（可用假流做密闭测试；可叠加在变换流之上）。
 * - 握手期绝对期限 Options.HandshakeDeadline（Infinite = 不设超时；
 *   零初始化表示「已过期」——用 DefaultAsyncTlsPasClientOptions 或显式
 *   TDeadline.Infinite）。超时交付 ASYNC_TLSPAS_ERR_IO。
 * - 失败一次性交付：AStream=nil 且 AError<0；半开连接不外漏。
 *   提交返回 False 仅表示同步提交失败且【未】回调；True = 结果经回调。
 * - 数据相：读挂起与写挂起互相独立；同方向重复提交是调用方 bug；
 *   写整段封队冲刷完成后回调一次总长；底层负错误码原样透传（保留
 *   取消/超时域语义），解密失败/协议错交付本单元负码。
 * - 读返回 0 = EOF（close_notify 或对端 TCP EOF）；fatal alert 与解密
 *   失败不可降级为 EOF。
 * - Close 尽力发送 close_notify 后关底层（不等对端，quiet-shutdown）。
 *
 * v2 能力边界（fail-closed，绝不假装支持）：
 * - 仅 TLS 1.3（服务器拒绝 1.3 即失败，无 1.2 回退）；密钥交换
 *   X25519/P-256/P-384（首轮 X25519，遇 HelloRetryRequest 自动重试
 *   P-256/P-384，transcript 按 RFC 8446 §4.4.1 合成 message_hash；
 *   P-384 共享 48B、公钥 97B，走 SHA-384 路径）；
 *   PSK 会话恢复（单身份，NewSessionTicket 捕获，max_early_data 入
 *   缓存，AllowEarlyData+EarlyData 时 0-RTT 数据面已接通，EE 接受
 *   判定与 HRR 互斥均已覆盖，接受时自动发送 EndOfEarlyData（RFC 8446
 *   §4.5，EOED+Finished 同记录），未接受则回退 1-RTT）；HRR+PSK
 *   binder 重算已覆盖；客户端证书（收到 CertificateRequest 即失败）
 *   仍未支持。
 * - VerifyPeer=True：复用 tls.x509verify 全链验证（日期/签名/CA
 *   约束/路径长度/信任锚/主机名 SAN+通配符）+ CertificateVerify
 *   签名校验。信任锚来源 TrustBundlePath 显式指定，或空串时发现
 *   系统 CA bundle 文件（Debian/RHEL/SUSE/FreeBSD 已知路径；目录型
 *   系统库如 Android cacerts 不在 v2 发现范围）。吊销检查（OCSP/
 *   CRL）未做——与 OpenSSL 默认软失败策略的差距已明示。
 * - 后握手消息仅容忍 NewSessionTicket（捕获派生 PSK 入缓存）与
 *   KeyUpdate（update_requested 时按 RFC 8446 §4.6.3 轮换本端写密钥）；
 *   其余类型显式失败。
 *
 * Error codes: 0 = ok，否则负值：
 *   ASYNC_TLSPAS_ERR_IO        底层流/提交失败、握手超时、解密失败
 *   ASYNC_TLSPAS_ERR_HANDSHAKE TLS 协议层失败（alert、非法消息、边界）
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.time.base, nextpas.core.time.deadline,
  nextpas.core.async.base, nextpas.core.async.loop,
  nextpas.core.net.base, nextpas.core.net.intf,
  nextpas.core.net.async.tcp,
  nextpas.core.fs,
  nextpas.core.platform.sync,
  nextpas.core.tls.x509, nextpas.core.tls.x509verify,
  nextpas.core.tls.tls13.keyschedule;

const
  { 底层流读写/提交失败、握手超时、解密失败 }
  ASYNC_TLSPAS_ERR_IO = -3201;
  { TLS 协议层失败：alert、非法消息、不支持的对端选择 }
  ASYNC_TLSPAS_ERR_HANDSHAKE = -3202;
  ASYNC_TLSFP_ERR_IO = ASYNC_TLSPAS_ERR_IO deprecated 'use ASYNC_TLSPAS_ERR_IO';
  ASYNC_TLSFP_ERR_HANDSHAKE = ASYNC_TLSPAS_ERR_HANDSHAKE deprecated 'use ASYNC_TLSPAS_ERR_HANDSHAKE';

type
  { 会话恢复条目：一条 NewSessionTicket 的完整恢复材料 }
  TTlsPasResumptionSession = record
    { 恢复必须沿用原会话的密码套件（PSK 与其绑定） }
    CipherSuite: Word;
    TicketIdentity: TBytes;
    ResumptionPSK: TBytes;
    TicketAgeAdd: Cardinal;
    LifetimeSec: Cardinal;
    { 单调时钟毫秒：算 obfuscated_ticket_age + 本地过期 }
    IssuedMs: Int64;
    { max_early_data 扩展（RFC8446 §4.2.10）：Has=False 表示票据未
      宣告 early_data；True 且 Size>0 时配合 AllowEarlyData 触发
      ClientHello early_data 尾扩展，仍需服务端 EE 确认才算接受。 }
    HasMaxEarlyData: Boolean;
    MaxEarlyDataSize: Cardinal;
  end;

  { 恢复状态查询：判断本次握手是否走了 PSK 恢复（测试与调用方观测
    用）。流对象隐藏实现，经 Supports(IAsyncTcpStream) 获取。 }
  ITlsPasResumeInfo = interface
    ['{8F3A2C61-9B4D-4E75-A1D0-3C6E5B8F2914}']
    function GetWasResumed: Boolean;
  end;

  { HRR 可观测：查询本次握手是否经历 HelloRetryRequest（真实重传）。
    与 WasResumed 正交，可同时为真（HRR+PSK）。 }
  ITlsPasHRRInfo = interface
    ['{A7F1D3E2-4C8B-4F2A-9E0D-1B2C3D4E5F6A}']
    function GetWasHRR: Boolean;
  end;

  { 0-RTT 可观测：查询 early_data 是否被服务端接受（RFC8446 §4.2.10）。
    未启用 early_data 或 1-RTT 回退时为 False；与 WasHRR 互斥。 }
  ITlsPasEarlyDataInfo = interface
    ['{C3E9A1B2-5F4D-4E8A-9B0C-1D2E3F4A5B6C}']
    function GetWasEarlyDataAccepted: Boolean;
  end;

  { 会话缓存：Host:Port → 恢复条目 LRU（每 host 最多 4 票据，mutex
    保护）。Store 追加并在满时淘汰最旧同 host 条目；TryPeek 返回
    最新未过期条目（线性小表，O(N) 可接受）。线程安全。 }
  TAsyncTlsPasSessionCache = class
  private
    FMutex: TPlatformMutex;
    FHosts: array of string;
    FPorts: array of UInt16;
    FSessions: array of TTlsPasResumptionSession;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Store(const AHost: string; APort: UInt16;
      const ASession: TTlsPasResumptionSession);
    function TryPeek(const AHost: string; APort: UInt16;
      out ASession: TTlsPasResumptionSession): Boolean;
  end;

  { 0-RTT 准入策略：纯函数，无堆，零分支透传，供 AllocHsCtx 与上层门面复用 }
function TlsPasIsEarlyDataAllowed(const ASession: TTlsPasResumptionSession;
  AAllowEarlyData: Boolean; AEarlyDataLen: Integer): Boolean;

  { 指纹：SHA256(ticket_identity || early_data)，32B，稳定可比，零密钥 }
function TlsPasComputeEarlyDataFingerprint(const ATicketIdentity,
  AEarlyData: TBytes): TBytes;

type
  TAsyncTlsPasReplayStats = record
    Hits: Int64;
    Misses: Int64;
    Evictions: Int64;
    Expiries: Int64;
    Current: Integer;
  end;

  ITlsPasReplayStore = interface
    ['{E1F2A3B4-C5D6-4E7F-8A9B-0C1D2E3F4A5B}']
    function CheckAndAdd(const AFingerprint: TBytes; out IsReplay: Boolean): Boolean;
    procedure Clear;
    function Count: Integer;
    function GetStats: TAsyncTlsPasReplayStats;
  end;

  { 重放窗口 LRU：64 槽，Mutex 保护，窗口期 10min（可配置），命中即重放。
    职责：服务端去重 / 客户端单票单用检测；不持有密钥材料。
    S9 起实现 ITlsPasReplayStore，支持注入与可观测 Stats。 }
  TAsyncTlsPasReplayCache = class(TInterfacedObject, ITlsPasReplayStore)
  private
    FMutex: TPlatformMutex;
    FHashes: array of TBytes;
    FTimes: array of Int64;
    FCapacity: Integer;
    FWindowMs: Int64;
    FHits: Int64;
    FMisses: Int64;
    FEvictions: Int64;
    FExpiries: Int64;
  public
    constructor Create; overload;
    constructor Create(ACapacity: Integer; AWindowMs: Int64); overload;
    destructor Destroy; override;
    { 指纹已在窗口内存在则 IsReplay=True 否则插入并 IsReplay=False }
    function CheckAndAdd(const AFingerprint: TBytes; out IsReplay: Boolean): Boolean;
    procedure Clear;
    function Count: Integer;
    function GetStats: TAsyncTlsPasReplayStats;
  end;

  { 文件持久化重放存储：ITlsPasReplayStore + 原子落盘（tmp+rename），崩溃安全。
    轻量同步写，适合服务端单机持久化；跨进程需外部 KV 时可用同接口自实现。 }
  TAsyncTlsPasReplayFileStore = class(TInterfacedObject, ITlsPasReplayStore)
  private
    FPath: string;
    FInner: TAsyncTlsPasReplayCache;
    FMutex: TPlatformMutex;
    procedure LoadFromFile;
    procedure SaveToFile;
  public
    constructor Create(const APath: string; ACapacity: Integer = 64; AWindowMs: Int64 = 600000);
    destructor Destroy; override;
    function CheckAndAdd(const AFingerprint: TBytes; out IsReplay: Boolean): Boolean;
    procedure Clear;
    function Count: Integer;
    function GetStats: TAsyncTlsPasReplayStats;
  end;

  { KV 抽象：供 ReplayKvStore 集群共享，内存实现自带，Redis/外部可注入同接口。 }
  ITlsPasKvStore = interface
    ['{A3B4C5D6-E7F8-4A9B-8C0D-1E2F3A4B5C6D}']
    function Get(const AKey: string; out AValue: TBytes): Boolean;
    procedure SetKV(const AKey: string; const AValue: TBytes; ATTLMs: Int64);
    procedure Delete(const AKey: string);
    procedure Clear;
  end;

  TAsyncTlsPasMemoryKvStore = class(TInterfacedObject, ITlsPasKvStore)
  private
    FMutex: TPlatformMutex;
    FKeys: array of string;
    FValues: array of TBytes;
    FExpiries: array of Int64;
  public
    constructor Create;
    destructor Destroy; override;
    function Get(const AKey: string; out AValue: TBytes): Boolean;
    procedure SetKV(const AKey: string; const AValue: TBytes; ATTLMs: Int64);
    procedure Delete(const AKey: string);
    procedure Clear;
  end;

  { KV 重放存储：本地 LRU64 + 远端 KV 二级，集群共享。本地命中即重放；本地未命中查 KV，KV 命中则回填本地并判重放；均未命中则两级写入。 }
  TAsyncTlsPasReplayKvStore = class(TInterfacedObject, ITlsPasReplayStore)
  private
    FLocal: TAsyncTlsPasReplayCache;
    FKv: ITlsPasKvStore;
    FWindowMs: Int64;
    FMutex: TPlatformMutex;
    function FingerprintToKey(const AFingerprint: TBytes): string;
  public
    constructor Create(const AKv: ITlsPasKvStore; ACapacity: Integer = 64; AWindowMs: Int64 = 600000);
    destructor Destroy; override;
    function CheckAndAdd(const AFingerprint: TBytes; out IsReplay: Boolean): Boolean;
    procedure Clear;
    function Count: Integer;
    function GetStats: TAsyncTlsPasReplayStats;
  end;

  { 工厂：统一创建内存/文件/KV 三形态，零分支注入。 }
  TAsyncTlsPasReplayStoreFactory = class
  public
    class function CreateMemory(ACapacity: Integer = 64; AWindowMs: Int64 = 600000): ITlsPasReplayStore; static;
    class function CreateFile(const APath: string; ACapacity: Integer = 64; AWindowMs: Int64 = 600000): ITlsPasReplayStore; static;
    class function CreateKv(const AKv: ITlsPasKvStore; ACapacity: Integer = 64; AWindowMs: Int64 = 600000): ITlsPasReplayStore; static;
  end;

  { 去重判定：指纹入窗口，命中则重放。封装指纹计算与 Store.CheckAndAdd，nil Store 视为不重放。 }
function TlsPasIsEarlyDataReplayed(const AStore: ITlsPasReplayStore;
  const ATicketIdentity, AEarlyData: TBytes): Boolean;

  { 服务端 0-RTT 决策：策略 + 去重一站式。先做零分支策略校验，不通过则
    edRejectPolicy 且不触 Store；通过后再做指纹去重，命中则 edRejectReplay，
    否则 edAccept（已落窗）。nil Store 视为永不重放。供服务端在解析
    ClientHello early_data 后调用，命中即回退 1-RTT。 }
type
  TTlsPasEarlyDataDecision = (edRejectPolicy, edRejectReplay, edAccept);

function TlsPasServerDecideEarlyData(const AStore: ITlsPasReplayStore;
  const ATicketIdentity, AEarlyData: TBytes;
  const ASession: TTlsPasResumptionSession; AAllowEarlyData: Boolean): TTlsPasEarlyDataDecision;
function TlsPasServerShouldAcceptEarlyData(const AStore: ITlsPasReplayStore;
  const ATicketIdentity, AEarlyData: TBytes;
  const ASession: TTlsPasResumptionSession; AAllowEarlyData: Boolean): Boolean;
function TlsPasEarlyDataDecisionToStr(ADecision: TTlsPasEarlyDataDecision): string;

  { S13 可观测：服务端决策统计 + 格式化，零堆纯函数，供日志/HTTP X-Early-Data 埋点 }
type
  TTlsPasServerStats = record
    Accepts: Int64;
    RejectPolicy: Int64;
    RejectReplay: Int64;
  end;

function TlsPasFormatReplayStats(const AStats: TAsyncTlsPasReplayStats): string;
function TlsPasFormatServerStats(const AStats: TTlsPasServerStats): string;

type
  { 服务端观测器：包装任意 ITlsPasReplayStore，委托 TlsPasServerDecideEarlyData 并计数，Mutex 保护 }
  TAsyncTlsPasServerObserver = class
  private
    FStore: ITlsPasReplayStore;
    FMutex: TPlatformMutex;
    FStats: TTlsPasServerStats;
  public
    constructor Create(const AStore: ITlsPasReplayStore);
    destructor Destroy; override;
    function Decide(const ATicketIdentity, AEarlyData: TBytes; const ASession: TTlsPasResumptionSession; AAllowEarlyData: Boolean): TTlsPasEarlyDataDecision;
    function ShouldAccept(const ATicketIdentity, AEarlyData: TBytes; const ASession: TTlsPasResumptionSession; AAllowEarlyData: Boolean): Boolean;
    function GetServerStats: TTlsPasServerStats;
    function GetReplayStats: TAsyncTlsPasReplayStats;
    procedure Clear;
    property Store: ITlsPasReplayStore read FStore;
  end;

type
  { 异步纯 Pas TLS 客户端选项。VerifyPeer=True 走 tls.x509verify
    全链验证 + CV 签名校验；TrustBundlePath 空 = 发现系统 CA bundle }
  TAsyncTlsPasClientOptions = record
    { SNI 主机名；空串 = 不发送（AsyncTlsPasConnect 回退填 Host），
      VerifyPeer=True 且空串时跳过主机名匹配（OpenSSL 同款语义：
      裸 IP 连接无法做身份绑定） }
    ServerName: string;
    { True = 链验证 + 主机名 + CV 签名校验，任一不过即握手失败 }
    VerifyPeer: Boolean;
    { 握手阶段（含底层拨号）绝对期限；Infinite = 不设超时 }
    HandshakeDeadline: TDeadline;
    { 信任锚 PEM bundle 文件路径；空串 = 进程级共享系统默认库
      （已知 bundle 文件惰性发现并缓存，内容确定性故无锁发布安全） }
    TrustBundlePath: string;
    { 会话缓存：非 nil 且缓存命中时尝试 PSK 恢复（1-RTT）；服务器
      拒绝则自动回退全握手。新票据在数据相捕获后回写缓存。nil = 关闭 }
    Cache: TAsyncTlsPasSessionCache;
    { 0-RTT 开关：True 时若缓存命中且票据 max_early_data>0，则在
      ClientHello 中附加 early_data 扩展（RFC8446 §4.2.10），并在
      服务端 EE 接受后自动发送 EndOfEarlyData（RFC 8446 §4.5）；
      默认 False 零开销，行为与 1-RTT 完全一致。 }
    AllowEarlyData: Boolean;
    { 0-RTT 待发送早期数据（幂等请求体，如 GET）。仅当 AllowEarlyData=True
      且票据有效且长度≤MaxEarlyDataSize 时随 CH 之后以 early 密钥发送，
      服务端接受则 EOED+Finished，拒绝则 1-RTT 回退；默认空不发。 }
    EarlyData: TBytes;
    { 可选重放去重存储：非 nil 时在 0-RTT 派生前做指纹去重（SHA256 ticket||early），
      命中则视为重放、本地静默回退为 1-RTT（不发 early_data 记录），避免同进程
      误重放；nil = 不检查（默认零开销，服务端仍需自备去重）。 }
    ReplayStore: ITlsPasReplayStore;
  end;

  { 异步握手完成回调：AError=0 时 AStream 为就绪 TLS 流；失败时
    AStream=nil 且 AError<0。事件循环线程回调，一次。 }
  TAsyncTlsPasConnectCallback = procedure(AStream: IAsyncTcpStream;
    AError: Int32; AContext: Pointer);

function DefaultAsyncTlsPasClientOptions: TAsyncTlsPasClientOptions;

{ 在既有已连接流上做非阻塞纯 Pas TLS1.3 客户端握手（升级）。
  False = 同步提交失败且不回调；True = 结果经回调交付。
  提交成功后 AStream 所有权移交状态机，调用方不得再使用。 }
function AsyncTlsPasUpgrade(const ALoop: TAsyncLoop;
  const AStream: IAsyncTcpStream; const AOptions: TAsyncTlsPasClientOptions;
  ACallback: TAsyncTlsPasConnectCallback; AContext: Pointer = nil): Boolean;

{ 拨号 + 升级一步到位（AsyncTcpDial Happy-Eyeballs + TLS 握手共用
  HandshakeDeadline）。SNI 缺省取 AHost。返回语义同 AsyncTlsPasUpgrade。 }
function AsyncTlsPasConnect(const ALoop: TAsyncLoop; const AHost: string;
  const APort: UInt16; const AOptions: TAsyncTlsPasClientOptions;
  ACallback: TAsyncTlsPasConnectCallback; AContext: Pointer = nil): Boolean;

type
  TFpTlsResumptionSession = TTlsPasResumptionSession deprecated 'use TTlsPasResumptionSession';
  ITlsFpResumeInfo = ITlsPasResumeInfo deprecated 'use ITlsPasResumeInfo';
  TAsyncTlsFpSessionCache = TAsyncTlsPasSessionCache deprecated 'use TAsyncTlsPasSessionCache';
  TAsyncTlsFpClientOptions = TAsyncTlsPasClientOptions deprecated 'use TAsyncTlsPasClientOptions';
  TAsyncTlsFpConnectCallback = TAsyncTlsPasConnectCallback deprecated 'use TAsyncTlsPasConnectCallback';

function DefaultAsyncTlsFpClientOptions: TAsyncTlsPasClientOptions; deprecated 'use DefaultAsyncTlsPasClientOptions';
function AsyncTlsFpUpgrade(const ALoop: TAsyncLoop; const AStream: IAsyncTcpStream;
  const AOptions: TAsyncTlsPasClientOptions; ACallback: TAsyncTlsPasConnectCallback;
  AContext: Pointer = nil): Boolean; deprecated 'use AsyncTlsPasUpgrade';
function AsyncTlsFpConnect(const ALoop: TAsyncLoop; const AHost: string;
  const APort: UInt16; const AOptions: TAsyncTlsPasClientOptions;
  ACallback: TAsyncTlsPasConnectCallback; AContext: Pointer = nil): Boolean; deprecated 'use AsyncTlsPasConnect';

{ HRR helpers exposed for synthetic verification (stable for test, not for app logic) }
function TlsPasIsSupportedHRRGroup(AGroup: Word): Boolean;
function TlsPasGroupKeyShareLen(AGroup: Word): Integer;
function TlsPasBuildMessageHash(const ACH1: TBytes; ACipherSuite: Word): TBytes;
function TlsPasHasEarlyData(const AClientHelloHandshake: TBytes): Boolean;

{ 0-RTT helpers — 薄封装 keyschedule.TryDeriveTLS13ClientEarlyDataSecrets，
  供合成验证与后续 early_data 数据面复用；零堆/零分支透传。 }
type
  TTlsPasEarlyDataSecrets = TTLS13EarlyDataSecrets;

function TlsPasTryDeriveEarlyDataSecrets(
  ACipherSuite: Word; const APSK, AClientHelloHandshake: TBytes;
  out ASecrets: TTlsPasEarlyDataSecrets; out AError: string): Boolean;
procedure TlsPasClearEarlyDataSecrets(var ASecrets: TTlsPasEarlyDataSecrets);

implementation

uses
  SysUtils, Classes,
  nextpas.core.errors,
  nextpas.core.system.sysutils,
  nextpas.core.encoding.base64,
  nextpas.core.atomic,
  nextpas.core.bytes,
  nextpas.core.mem,
  nextpas.core.time.stopwatch,
  nextpas.core.mem.secure,
  nextpas.core.crypto.hash,
  nextpas.core.crypto.hkdf,
  nextpas.core.crypto.ecdsa,
  nextpas.core.crypto.x25519,
  nextpas.core.crypto.p256ecdh,
  nextpas.core.crypto.p384,
  nextpas.core.tls.keyschedule.labels,
  nextpas.core.io.intf,
  nextpas.core.async.cancellation,
  nextpas.core.net.async.dial,
  nextpas.core.tls.tls13.wire,
  nextpas.core.tls.tls13.clienthello,
  nextpas.core.tls.tls13.clienthello.parser,
  nextpas.core.tls.tls13.parser,
  nextpas.core.tls.tls13.recordcrypto,
  nextpas.core.tls.tls13.aead,
  nextpas.core.tls.tls13.finished,
  nextpas.core.tls.tls13.appschedule,
  nextpas.core.tls.tls13.recordsealer,
  nextpas.core.tls.tls13.servercertificate,
  nextpas.core.tls.tls13.servercertverify,
  nextpas.core.tls.tls13.posthandshake;

{ ======== 会话恢复缓存 ======== }

var
  { 单调时钟基准：票据年龄与本地过期的唯一时钟源 }
  GMonoClock: TStopwatch;

function TlsPasMonoMs: Int64;
begin
  Result := GMonoClock.ElapsedMilliseconds;
end;

constructor TAsyncTlsPasSessionCache.Create;
begin
  inherited Create;
  if platform_mutex_init(FMutex) <> 0 then
    raise EInvalidOperationError.Create('tlspas: session cache mutex init');
end;

destructor TAsyncTlsPasSessionCache.Destroy;
var
  I: Integer;
begin
  platform_mutex_destroy(FMutex);
  for I := 0 to High(FSessions) do
  begin
    SecureZeroBytes(FSessions[I].TicketIdentity);
    SecureZeroBytes(FSessions[I].ResumptionPSK);
  end;
  inherited Destroy;
end;

const
  cTlsPasCacheMaxPerHost = 4;

procedure TAsyncTlsPasSessionCache.Store(const AHost: string; APort: UInt16;
  const ASession: TTlsPasResumptionSession);
var
  I, Cnt, Oldest: Integer;
begin
  if AHost = '' then
    Exit;
  platform_mutex_lock(FMutex);
  try
    Cnt := 0; Oldest := -1;
    for I := 0 to High(FHosts) do
      if (FPorts[I] = APort) and (FHosts[I] = AHost) then
      begin
        Inc(Cnt);
        if Oldest < 0 then Oldest := I;
      end;
    if Cnt >= cTlsPasCacheMaxPerHost then
    begin
      SecureZeroBytes(FSessions[Oldest].TicketIdentity);
      SecureZeroBytes(FSessions[Oldest].ResumptionPSK);
      for I := Oldest to High(FHosts) - 1 do
      begin
        FHosts[I] := FHosts[I + 1];
        FPorts[I] := FPorts[I + 1];
        FSessions[I] := FSessions[I + 1];
      end;
      SetLength(FHosts, Length(FHosts) - 1);
      SetLength(FPorts, Length(FPorts) - 1);
      SetLength(FSessions, Length(FSessions) - 1);
    end;
    SetLength(FHosts, Length(FHosts) + 1);
    SetLength(FPorts, Length(FPorts) + 1);
    SetLength(FSessions, Length(FSessions) + 1);
    FHosts[High(FHosts)] := AHost;
    FPorts[High(FPorts)] := APort;
    FSessions[High(FSessions)] := ASession;
  finally
    platform_mutex_unlock(FMutex);
  end;
end;

function TAsyncTlsPasSessionCache.TryPeek(const AHost: string; APort: UInt16;
  out ASession: TTlsPasResumptionSession): Boolean;
var
  I: Integer;
begin
  ASession := Default(TTlsPasResumptionSession);
  Result := False;
  if AHost = '' then
    Exit;
  platform_mutex_lock(FMutex);
  try
    for I := High(FHosts) downto 0 do
      if (FPorts[I] = APort) and (FHosts[I] = AHost) then
      begin
        ASession := FSessions[I];
        Result := ASession.IssuedMs + Int64(ASession.LifetimeSec) * 1000 > TlsPasMonoMs;
        if Result then Exit;
        { 过期则继续向旧条目回退 }
      end;
  finally
    platform_mutex_unlock(FMutex);
  end;
end;

{ ======== 信任锚解析与进程级共享系统库 ======== }

type
  { 加载器创建的证书对象数组：TX509TrustStore 只存引用不拥有，
    调用方验证完毕后必须自行释放 }
  TTlsPasCertObjArray = array of TX509Certificate;

const
  { 已知系统 CA bundle 文件（单文件整读，避免目录扫描开销；
    目录型系统库如 Android cacerts 不在 v2 发现范围——见单元头） }
  CSystemTrustBundleFiles: array[0..3] of string = (
    '/etc/ssl/certs/ca-certificates.crt',        { Debian/Ubuntu }
    '/etc/pki/tls/certs/ca-bundle.crt',          { RHEL/Fedora }
    '/etc/ssl/ca-bundle.pem',                    { SUSE }
    '/usr/local/share/certs/ca-root-nss.crt'     { FreeBSD }
  );

function ExtractPemCertificateBlock(const APem: string;
  var AFrom: Integer; out ADer: TBytes): Boolean;
var
  LBeginTag, LEndTag: string;
  LStart, LFinish, LIdx, LLineStart: Integer;
  LBody: string;
begin
  Result := False;
  SetLength(ADer, 0);
  LBeginTag := '-----BEGIN CERTIFICATE-----';
  LEndTag := '-----END CERTIFICATE-----';
  { Copy(APem, AFrom+1, ·) 中相对位 r 对应绝对位 AFrom+r：
    标签起点 = AFrom+r，标签后首字符 = AFrom+r+len(tag) }
  LStart := Pos(LBeginTag, Copy(APem, AFrom + 1, MaxInt));
  if LStart = 0 then
    Exit;
  LStart := AFrom + LStart + Length(LBeginTag);
  LFinish := Pos(LEndTag, Copy(APem, LStart, MaxInt));
  if LFinish = 0 then
    Exit;
  LFinish := LStart + LFinish - 1;

  { 剥掉 base64 体里的换行空白再解码 }
  LBody := '';
  for LIdx := LStart to LFinish - 1 do
    if not (APem[LIdx] in [#13, #10, #32, #9]) then
      LBody := LBody + APem[LIdx];
  try
    ADer := Base64Decode(LBody);
    Result := Length(ADer) > 0;
  except
    Result := False;
  end;
  { 越过本块 END 标记继续找下一块 }
  AFrom := LFinish + Length(LEndTag);
end;

function LoadTrustStoreFromBundleFile(const APath: string;
  out ALoadedCerts: TTlsPasCertObjArray; out AError: string): TX509TrustStore;
var
  LPem: string;
  LCert: TX509Certificate;
  LCursor: Integer;
  LDer: TBytes;
  LCount: Integer;
begin
  Result := nil;
  AError := '';
  SetLength(ALoadedCerts, 0);
  if not nextpas.core.fs.IsFile(APath) then
  begin
    AError := 'trust bundle not found: ' + APath;
    Exit;
  end;
  LPem := nextpas.core.fs.ReadFileText(APath);
  Result := TX509TrustStore.Create;
  LCursor := 0;
  LCount := 0;
  while ExtractPemCertificateBlock(LPem, LCursor, LDer) do
  begin
    LCert := TX509Certificate.Create;
    try
      LCert.LoadFromDER(LDer);
      Result.AddTrustedCertificate(LCert);
      Inc(LCount);
      SetLength(ALoadedCerts, Length(ALoadedCerts) + 1);
      ALoadedCerts[High(ALoadedCerts)] := LCert;
    except
      LCert.Free; { 单块坏证书跳过，不拖垮整个库 }
    end;
  end;
  if LCount = 0 then
  begin
    Result.Free;
    Result := nil;
    AError := 'no certificate parsed from trust bundle: ' + APath;
  end;
end;

function BuildSystemTrustStore(out ALoadedCerts: TTlsPasCertObjArray;
  out AError: string): TX509TrustStore;
var
  I: Integer;
begin
  Result := nil;
  AError := '';
  SetLength(ALoadedCerts, 0);
  for I := Low(CSystemTrustBundleFiles) to High(CSystemTrustBundleFiles) do
  begin
    if nextpas.core.fs.IsFile(CSystemTrustBundleFiles[I]) then
    begin
      Result := LoadTrustStoreFromBundleFile(
        CSystemTrustBundleFiles[I], ALoadedCerts, AError);
      if Result <> nil then
        Exit;
    end;
  end;
  AError := 'no system CA bundle discovered (tried ' +
    IntToStr(Length(CSystemTrustBundleFiles)) + ' known paths)';
end;

var
  { 进程级共享系统信任库（存 PtrUInt 于 Int64 槽）：构建内容确定性
    （同一 bundle 集合），故 CAS 竞败方释放自有副本即可，胜者等价。
    库内证书对象按设计随进程常驻（一次性 ~150 个小对象），不视为泄漏。 }
  GSharedSystemTrustStoreRef: Int64 = 0;

function SharedSystemTrustStore: TX509TrustStore;
var
  LBuilt: TX509TrustStore;
  LCerts: TTlsPasCertObjArray;
  LErr: string;
  LRef: Int64;
  I: Integer;
begin
  LRef := AtomicLoad64(GSharedSystemTrustStoreRef);
  if LRef <> 0 then
    Exit(TX509TrustStore(Pointer(PtrUInt(LRef))));
  LBuilt := BuildSystemTrustStore(LCerts, LErr);
  if LBuilt = nil then
    Exit(nil); { VerifyPeer 下游报错；LCerts 此时空 }
  if AtomicCompareExchange64(GSharedSystemTrustStoreRef, 0,
    Int64(PtrUInt(Pointer(LBuilt)))) <> 0 then
  begin
    { 别的线程先发布：本副本整体弃置（内容确定性等价） }
    LBuilt.Free;
    for I := 0 to High(LCerts) do
      LCerts[I].Free;
  end;
  Result := TX509TrustStore(Pointer(PtrUInt(
    AtomicLoad64(GSharedSystemTrustStoreRef))));
end;

{ 显式 bundle 路径每次独立加载（测试/嵌入式场景，量小不缓存）；
  空路径 = 进程级共享系统库。AOwned=True 时调用方用完必须 Free store
  并释放 AStoreCerts 内全部证书对象（store 只存引用不拥有）。 }
function ResolveTrustStore(const AExplicitPath: string;
  out AStore: TX509TrustStore; out AStoreCerts: TTlsPasCertObjArray;
  out AOwned: Boolean; out AError: string): Boolean;
begin
  AError := '';
  AOwned := False;
  SetLength(AStoreCerts, 0);
  if AExplicitPath <> '' then
  begin
    AStore := LoadTrustStoreFromBundleFile(AExplicitPath, AStoreCerts,
      AError);
    Result := AStore <> nil;
    AOwned := Result;
    if not Result and (AError = '') then
      AError := 'trust bundle load failed: ' + AExplicitPath;
  end
  else
  begin
    AStore := SharedSystemTrustStore;
    Result := AStore <> nil;
    if not Result then
      AError := 'no system CA bundle discovered; set TrustBundlePath explicitly';
  end;
end;

const
  { 单次网络读块下限（≥ 最大 TLS 密文记录 16KB+256） }
  cNetReadChunk = 16640;
  { 读块自适应上界。臂挂从下限起步，满读翻倍、不足半读回缩——
    批量流自动长大让单次 read 吞掉多记录突发（摊薄 epoll/read），
    低速连接保持下限不占内存。S2：此值即每连接未组帧读缓冲的
    显式最坏值（65536B），与连接总数相乘有界。 }
  cNetReadChunkMax = 65536;
  { 实测扫描（2026-08-26，vless+wss→socks5 端到端）：16K=199.3、
    64K=214.5、128K=206.6 MiB/s——64K 为最优点；再大会放大交付侧
    FPlainOut 压缩搬移与缓存压力 }
  { 单条记录载荷上限（5B 头之外） }
  cMaxRecordPayload = 16384 + 256;
  { 单条握手消息上限（证书链可达数十 KB，1MB 已远超合理面） }
  cMaxHandshakeMessage = 1 shl 20;
  { 应用相单记录明文片上限：TLSInnerPlaintext ≤ 16384 含 ct 尾字节 }
  cMaxAppFragment = 16383;
  { 未组帧网络缓冲协议错界：读块满额（合法实字节峰值）+ 一条最大
    记录余量；超出 = 对端持续给不出可组帧记录，协议错 }
  cMaxNetInBuf = cNetReadChunkMax + 5 + cMaxRecordPayload;
  { 应用相单泵解密预算：一次唤醒内就地解密的明文累计上界——
    读进的全部完整记录一次消化完（而非解 1 条交付 1 次），同时
    给事件循环单次占用设显式顶。S2：FPlainOut 峰值 ≤ 预算 + 单片。 }
  cDecryptBatchBytes = 262144;
  { 握手期记录预算（防对端灌包） }
  cMaxFlightRecords = 96;
  { 后握手缓冲上限 }
  cMaxPostHsBuf = 4 * cMaxHandshakeMessage;

type
  TTlsPasHsState = (hsSendCH, hsRecvSH, hsRecvFlight, hsFlushFin);

  PTlsPasHsCtx = ^TTlsPasHsCtx;
  TTlsPasHsCtx = record
    Loop: TAsyncLoop;
    Stream: IAsyncTcpStream;
    Timer: TAsyncTimerHandle;
    ServerName: string;
    { VerifyPeer=True 时：CERT 相做全链验证，CV 相验签名 }
    VerifyPeer: Boolean;
    TrustBundlePath: string;
    { 会话恢复：缓存里有票据则带 PSK 出手；PsksAccepted 后按恢复
      语义处理飞行（无 CERT/CV） }
    ResumeSession: TTlsPasResumptionSession;
    HasResumeSession: Boolean;
    { 已带 PSK 出手（CH 含 pre_shared_key）；PsksAccepted=服务器接受 }
    Resuming: Boolean;
    PsksAccepted: Boolean;
    { 票据捕获回写目标（经数据相传入流） }
    Cache: TAsyncTlsPasSessionCache;
    CachePort: UInt16;
    { 链验证通过后捕获的叶子证书公钥（CV 签名校验输入） }
    LeafPublicKeyInfo: TX509PublicKeyInfo;
    OnReady: TAsyncTlsPasConnectCallback;
    OnReadyCtx: Pointer;
    Deadline: TDeadline;
    State: TTlsPasHsState;
    { 客户端 X25519 私钥（收尾清零） }
    Priv: TBytes;
    { HRR 扩展：P-256/P-384 私钥与 HRR 状态（收尾清零） }
    PrivP256: TBytes;
    PrivP384: TBytes;
    FirstGroup: Word;
    HRRSeen: Boolean;
    HRRTranscript: TBytes;
    CH1Body: TBytes;
    { ClientHello 握手消息体（transcript 首项，HRR 后更新为 CH2） }
    CHBody: TBytes;
    Transcript: TBytes;
    { 0-RTT 早期数据：CH 含 early_data 时置 SentEarlyData，EE HasEarlyData 决定 Accepted }
    SentEarlyData: Boolean;
    EarlyDataAccepted: Boolean;
    EarlySecrets: TTlsPasEarlyDataSecrets;
    EarlySealer: TTLS13RecordSealer;
    EarlySeq: QWord;
    EarlyData: TBytes;
    Suite: Word;
    Secrets: TTLS13HandshakeSecrets;
    ServerFinKey: TBytes;
    ClientFinKey: TBytes;
    SrvSeq: QWord;
    CliSeq: QWord;
    { 原始网络字节累积（按记录组帧） }
    NetIn: TBytes;
    { ServerHello 相明文握手流 }
    HsBuf: TBytes;
    { 加密飞行相已解密握手消息流 }
    EncBuf: TBytes;
    AppSecrets: TTLS13ApplicationSecrets;
    { server flight 结构断言：FINISHED 时三者必须全真（v1 无 PSK） }
    SeenEncryptedExtensions: Boolean;
    SeenCert: Boolean;
    SeenCertVerify: Boolean;
    CertRequested: Boolean;
    { 待冲刷密文（客户端飞行） }
    TxBytes: TBytes;
    TxOff: Integer;
    SendArmed: Boolean;
    RecvArmed: Boolean;
    Pumping: Boolean;
    Finished: Boolean;
  end;

  { 数据相 TLS 流：对外完整 IAsyncTcpStream 面；内部以
    TTLS13RecordSealer/Opener 承载应用相加解密。fd 仅经
    NativeSocketHandle 透传作观测用途——绕过本层直读写 fd 会破坏
    TLS 分帧。读挂起与写挂起各一槽，互相独立。 }
  TTlsPasStream = class(TInterfacedObject, IReader, IWriter,
    IReadWriteCloser, ITcpStream, ITcpSocketRuntime, ITcpStreamRuntime,
    IAsyncTcpStream, ITlsPasResumeInfo, ITlsPasHRRInfo, ITlsPasEarlyDataInfo)
  private
    FInner: IAsyncTcpStream;
    FLoop: TAsyncLoop;
    FSuite: Word;
    FApp: TTLS13ApplicationSecrets;
    { 票据捕获：非 nil 时 NewSessionTicket → 派生 PSK 入缓存 }
    FCache: TAsyncTlsPasSessionCache;
    FCacheHost: string;
    FCachePort: UInt16;
    FWasResumed: Boolean;
    FWasHRR: Boolean;
    FWasEarlyDataAccepted: Boolean;
    FSealer: TTLS13RecordSealer;
    FOpener: TTLS13RecordOpener;
    FNetIn: TBytes;
    FPlainOut: TBytes;
    FPostHs: TBytes;
    FNetInBuf: TByteStreamBuf;
    FPlainOutBuf: TByteStreamBuf;
    FNetTxBuf: TByteStreamBuf;
    FRecvChunk: Integer;
    FRecvArmed: Boolean;
    FSendArmed: Boolean;
    FPumping: Boolean;
    FEofIn: Boolean;
    FDead: Boolean;
    FCloseNotifySent: Boolean;
    { 读挂起槽 }
    FReadBuf: Pointer;
    FReadLen: UInt32;
    FReadCb: TIoCompletion;
    FReadCbCtx: Pointer;
    FReadPending: Boolean;
    { 写挂起槽 }
    FWriteTotal: Integer;
    FWriteCb: TIoCompletion;
    FWriteCbCtx: Pointer;
    FWritePending: Boolean;
    { 读挂起是否带期限（决定底层臂挂形态） }
    FHasReadDeadlineReq: Boolean;
    FReadDeadlineReq: TDeadline;
    function ArmNetRecv: Boolean;
    function ArmNetSend: Boolean;
    { 组帧并开启记录进 FPlainOut；>0=新增明文字节数，
      0=需更多网络字节，<0=致命（协议/解密） }
    function OpenAvailableRecords: Integer;
    function HandleOpenedRecord(const APayload: TBytes): Integer;
    procedure FeedPostHandshake(const AFragment: TBytes;
      out AFatal: Boolean);
    procedure DeliverRead(AResult: Int32);
    procedure DeliverWrite(AResult: Int32);
    { 明文按 ≤16KB 片封队到 FNetTx }
    procedure SealPlainToQueue(const APlain: TBytes);
    procedure SealPlainToQueueBuf(AData: PByte; ALen: SizeUInt);
    { 已冲尽时压实发送队列（防长连接无限增长） }
    procedure CompactTxIfDrained;
    procedure Pump;
  public
    constructor Create(ASuite: Word; const AApp: TTLS13ApplicationSecrets;
      const AInner: IAsyncTcpStream; ALoop: TAsyncLoop;
      const ANetInSeed, APostHsSeed: TBytes;
      ACache: TAsyncTlsPasSessionCache; const ACacheHost: string;
      ACachePort: UInt16; AWasResumed: Boolean; AWasHRR: Boolean = False;
      AWasEarlyDataAccepted: Boolean = False);
    destructor Destroy; override;
    { ITlsPasResumeInfo }
    function GetWasResumed: Boolean;
    { ITlsPasHRRInfo }
    function GetWasHRR: Boolean;
    { ITlsPasEarlyDataInfo }
    function GetWasEarlyDataAccepted: Boolean;
    { IReader }
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    { IWriter }
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    { IReadWriteCloser }
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
  end;

type
  TFpTlsStream = TTlsPasStream deprecated 'use TTlsPasStream';

{ ======== 静态回调前向声明 ======== }

procedure TlsPasHsStep(ACtx: Pointer); forward;
procedure TlsPasRecvCb(AUserData: UInt64; AResult: Int32;
  AContext: Pointer); forward;
procedure TlsPasSendCb(AUserData: UInt64; AResult: Int32;
  AContext: Pointer); forward;
procedure TlsPasTimerCb(AContext: Pointer); forward;
procedure TlsPasDialDone(AStream: IAsyncTcpStream; AError: Int32;
  AContext: Pointer); forward;
procedure StreamRecvCb(AUserData: UInt64; AResult: Int32;
  AContext: Pointer); forward;
procedure StreamSendCb(AUserData: UInt64; AResult: Int32;
  AContext: Pointer); forward;
procedure TlsPasArmRecv(ACtx: PTlsPasHsCtx); forward;
procedure TlsPasArmSend(ACtx: PTlsPasHsCtx); forward;

{ ======== 通用小件 ======== }

function TlsPasTranscriptHash(ASuite: Word; const AT: TBytes): TBytes;
begin
  if TLS13CipherSuiteIsSHA384(ASuite) then
    Exit(SHA384(AT));
  Result := SHA256(AT);
end;

procedure AppendBytesTo(var ADest: TBytes; const ASrc: TBytes);
var
  LBase: Integer;
begin
  if Length(ASrc) = 0 then
    Exit;
  LBase := Length(ADest);
  SetLength(ADest, LBase + Length(ASrc));
  Move(ASrc[0], ADest[LBase], Length(ASrc));
end;

{ ======== 0-RTT 策略与重放窗口 ======== }

function TlsPasIsEarlyDataAllowed(const ASession: TTlsPasResumptionSession;
  AAllowEarlyData: Boolean; AEarlyDataLen: Integer): Boolean;
begin
  Result := AAllowEarlyData
    and ASession.HasMaxEarlyData
    and (ASession.MaxEarlyDataSize > 0)
    and (ASession.MaxEarlyDataSize <= 16384)
    and (AEarlyDataLen > 0)
    and (AEarlyDataLen <= Integer(ASession.MaxEarlyDataSize))
    and (AEarlyDataLen <= 16384);
end;

function TlsPasComputeEarlyDataFingerprint(const ATicketIdentity,
  AEarlyData: TBytes): TBytes;
var
  LBuf: TBytes;
begin
  SetLength(LBuf, 0);
  AppendBytesTo(LBuf, ATicketIdentity);
  AppendBytesTo(LBuf, AEarlyData);
  Result := SHA256(LBuf);
  SecureZeroBytes(LBuf);
end;

function TlsPasIsEarlyDataReplayed(const AStore: ITlsPasReplayStore;
  const ATicketIdentity, AEarlyData: TBytes): Boolean;
var
  LFP: TBytes;
  LIsReplay: Boolean;
begin
  Result := False;
  if not Assigned(AStore) then Exit;
  LFP := TlsPasComputeEarlyDataFingerprint(ATicketIdentity, AEarlyData);
  try
    if AStore.CheckAndAdd(LFP, LIsReplay) then
      Result := LIsReplay
    else
      Result := False;
  finally
    SecureZeroBytes(LFP);
  end;
end;

function TlsPasServerDecideEarlyData(const AStore: ITlsPasReplayStore;
  const ATicketIdentity, AEarlyData: TBytes;
  const ASession: TTlsPasResumptionSession; AAllowEarlyData: Boolean): TTlsPasEarlyDataDecision;
var LFP: TBytes; LIsReplay: Boolean;
begin
  if not TlsPasIsEarlyDataAllowed(ASession, AAllowEarlyData, Length(AEarlyData)) then
    Exit(edRejectPolicy);
  if not Assigned(AStore) then
    Exit(edAccept);
  LFP := TlsPasComputeEarlyDataFingerprint(ATicketIdentity, AEarlyData);
  try
    if not AStore.CheckAndAdd(LFP, LIsReplay) then
      Exit(edAccept); // Store 异常视为不重放，保持可用性 fail-open，观测靠 Stats
    if LIsReplay then
      Exit(edRejectReplay);
    Result := edAccept;
  finally
    SecureZeroBytes(LFP);
  end;
end;

function TlsPasServerShouldAcceptEarlyData(const AStore: ITlsPasReplayStore;
  const ATicketIdentity, AEarlyData: TBytes;
  const ASession: TTlsPasResumptionSession; AAllowEarlyData: Boolean): Boolean;
begin
  Result := TlsPasServerDecideEarlyData(AStore, ATicketIdentity, AEarlyData, ASession, AAllowEarlyData) = edAccept;
end;

function TlsPasEarlyDataDecisionToStr(ADecision: TTlsPasEarlyDataDecision): string;
begin
  case ADecision of
    edRejectPolicy: Result := 'reject_policy';
    edRejectReplay: Result := 'reject_replay';
    edAccept: Result := 'accept';
  else
    Result := 'unknown';
  end;
end;

function TlsPasFormatReplayStats(const AStats: TAsyncTlsPasReplayStats): string;
begin
  Result := Format('hits=%d misses=%d evictions=%d expiries=%d current=%d',
    [AStats.Hits, AStats.Misses, AStats.Evictions, AStats.Expiries, AStats.Current]);
end;

function TlsPasFormatServerStats(const AStats: TTlsPasServerStats): string;
begin
  Result := Format('accepts=%d reject_policy=%d reject_replay=%d',
    [AStats.Accepts, AStats.RejectPolicy, AStats.RejectReplay]);
end;

constructor TAsyncTlsPasServerObserver.Create(const AStore: ITlsPasReplayStore);
begin
  inherited Create;
  FStore := AStore;
  if platform_mutex_init(FMutex) <> 0 then
    raise EInvalidOperationError.Create('tlspas: server observer mutex init');
end;

destructor TAsyncTlsPasServerObserver.Destroy;
begin
  platform_mutex_destroy(FMutex);
  inherited Destroy;
end;

function TAsyncTlsPasServerObserver.Decide(const ATicketIdentity, AEarlyData: TBytes;
  const ASession: TTlsPasResumptionSession; AAllowEarlyData: Boolean): TTlsPasEarlyDataDecision;
begin
  Result := TlsPasServerDecideEarlyData(FStore, ATicketIdentity, AEarlyData, ASession, AAllowEarlyData);
  platform_mutex_lock(FMutex);
  try
    case Result of
      edAccept: Inc(FStats.Accepts);
      edRejectPolicy: Inc(FStats.RejectPolicy);
      edRejectReplay: Inc(FStats.RejectReplay);
    end;
  finally
    platform_mutex_unlock(FMutex);
  end;
end;

function TAsyncTlsPasServerObserver.ShouldAccept(const ATicketIdentity, AEarlyData: TBytes;
  const ASession: TTlsPasResumptionSession; AAllowEarlyData: Boolean): Boolean;
begin
  Result := Decide(ATicketIdentity, AEarlyData, ASession, AAllowEarlyData) = edAccept;
end;

function TAsyncTlsPasServerObserver.GetServerStats: TTlsPasServerStats;
begin
  platform_mutex_lock(FMutex);
  try
    Result := FStats;
  finally
    platform_mutex_unlock(FMutex);
  end;
end;

function TAsyncTlsPasServerObserver.GetReplayStats: TAsyncTlsPasReplayStats;
begin
  if Assigned(FStore) then
    Result := FStore.GetStats
  else
  begin
    FillChar(Result, SizeOf(Result), 0);
  end;
end;

procedure TAsyncTlsPasServerObserver.Clear;
begin
  if Assigned(FStore) then
    FStore.Clear;
  platform_mutex_lock(FMutex);
  try
    FillChar(FStats, SizeOf(FStats), 0);
  finally
    platform_mutex_unlock(FMutex);
  end;
end;

constructor TAsyncTlsPasReplayCache.Create;
begin
  Create(64, 600000);
end;

constructor TAsyncTlsPasReplayCache.Create(ACapacity: Integer; AWindowMs: Int64);
begin
  inherited Create;
  if ACapacity <= 0 then ACapacity := 64;
  if AWindowMs <= 0 then AWindowMs := 600000;
  FCapacity := ACapacity;
  FWindowMs := AWindowMs;
  if platform_mutex_init(FMutex) <> 0 then
    raise EInvalidOperationError.Create('tlspas: replay cache mutex init');
end;

destructor TAsyncTlsPasReplayCache.Destroy;
var I: Integer;
begin
  platform_mutex_destroy(FMutex);
  for I := 0 to High(FHashes) do
    SecureZeroBytes(FHashes[I]);
  inherited Destroy;
end;

function TAsyncTlsPasReplayCache.CheckAndAdd(const AFingerprint: TBytes;
  out IsReplay: Boolean): Boolean;
var
  I, Oldest: Integer;
  LNow: Int64;
  LOldestTime: Int64;
begin
  Result := False;
  IsReplay := False;
  if Length(AFingerPrint) <> 32 then Exit;
  LNow := TlsPasMonoMs;
  platform_mutex_lock(FMutex);
  try
    // 先清过期
    I := 0;
    while I < Length(FHashes) do
    begin
      if FTimes[I] + FWindowMs <= LNow then
      begin
        SecureZeroBytes(FHashes[I]);
        for Oldest := I to High(FHashes) - 1 do
        begin
          FHashes[Oldest] := FHashes[Oldest + 1];
          FTimes[Oldest] := FTimes[Oldest + 1];
        end;
        SetLength(FHashes, Length(FHashes) - 1);
        SetLength(FTimes, Length(FTimes) - 1);
        Inc(FExpiries);
      end
      else
        Inc(I);
    end;
    for I := 0 to High(FHashes) do
      if (Length(FHashes[I]) = 32) and CompareMem(@FHashes[I][0], @AFingerprint[0], 32) then
      begin
        IsReplay := True;
        Inc(FHits);
        Result := True;
        Exit;
      end;
    // 未命中则插入
    Inc(FMisses);
    if Length(FHashes) >= FCapacity then
    begin
      Oldest := 0;
      LOldestTime := FTimes[0];
      for I := 1 to High(FTimes) do
        if FTimes[I] < LOldestTime then
        begin
          LOldestTime := FTimes[I];
          Oldest := I;
        end;
      SecureZeroBytes(FHashes[Oldest]);
      FHashes[Oldest] := Copy(AFingerPrint);
      FTimes[Oldest] := LNow;
      Inc(FEvictions);
    end
    else
    begin
      SetLength(FHashes, Length(FHashes) + 1);
      SetLength(FTimes, Length(FTimes) + 1);
      FHashes[High(FHashes)] := Copy(AFingerPrint);
      FTimes[High(FTimes)] := LNow;
    end;
    IsReplay := False;
    Result := True;
  finally
    platform_mutex_unlock(FMutex);
  end;
end;

procedure TAsyncTlsPasReplayCache.Clear;
var I: Integer;
begin
  platform_mutex_lock(FMutex);
  try
    for I := 0 to High(FHashes) do
      SecureZeroBytes(FHashes[I]);
    SetLength(FHashes, 0);
    SetLength(FTimes, 0);
    FHits := 0;
    FMisses := 0;
    FEvictions := 0;
    FExpiries := 0;
  finally
    platform_mutex_unlock(FMutex);
  end;
end;

function TAsyncTlsPasReplayCache.Count: Integer;
begin
  platform_mutex_lock(FMutex);
  try
    Result := Length(FHashes);
  finally
    platform_mutex_unlock(FMutex);
  end;
end;

function TAsyncTlsPasReplayCache.GetStats: TAsyncTlsPasReplayStats;
begin
  platform_mutex_lock(FMutex);
  try
    Result.Hits := FHits;
    Result.Misses := FMisses;
    Result.Evictions := FEvictions;
    Result.Expiries := FExpiries;
    Result.Current := Length(FHashes);
  finally
    platform_mutex_unlock(FMutex);
  end;
end;

{ ======== 文件持久化重放存储 ======== }

constructor TAsyncTlsPasReplayFileStore.Create(const APath: string; ACapacity: Integer; AWindowMs: Int64);
begin
  inherited Create;
  FPath := APath;
  FInner := TAsyncTlsPasReplayCache.Create(ACapacity, AWindowMs);
  if platform_mutex_init(FMutex) <> 0 then
  begin
    FInner.Free;
    raise EInvalidOperationError.Create('tlspas: file store mutex init');
  end;
  LoadFromFile;
end;

destructor TAsyncTlsPasReplayFileStore.Destroy;
begin
  // best-effort flush
  try SaveToFile; except end;
  platform_mutex_destroy(FMutex);
  FInner.Free;
  inherited Destroy;
end;

procedure TAsyncTlsPasReplayFileStore.LoadFromFile;
var
  FS: TFileStream;
  LSize: Int64;
  LCount, I: Integer;
  LHash: TBytes;
  LTime: Int64;
  LNow: Int64;
  LBuf: TBytes;
  LIsReplay: Boolean;
begin
  if FPath = '' then Exit;
  if not FileExists(FPath) then Exit;
  try
    FS := TFileStream.Create(FPath, fmOpenRead or fmShareDenyWrite);
    try
      LSize := FS.Size;
      if (LSize = 0) or (LSize mod 40 <> 0) then Exit; // corruption -> ignore
      LCount := Integer(LSize div 40);
      SetLength(LBuf, 40);
      LNow := TlsPasMonoMs;
      for I := 0 to LCount - 1 do
      begin
        FS.ReadBuffer(LBuf[0], 40);
        SetLength(LHash, 32);
        Move(LBuf[0], LHash[0], 32);
        Move(LBuf[32], LTime, 8);
        if LTime + FInner.FWindowMs <= LNow then
        begin
          SecureZeroBytes(LHash);
          Continue;
        end;
        FInner.CheckAndAdd(LHash, LIsReplay);
        SecureZeroBytes(LHash);
      end;
    finally
      FS.Free;
    end;
  except
    // 腐败或 IO 错：忽略，视为空存储
  end;
end;

procedure TAsyncTlsPasReplayFileStore.SaveToFile;
var
  FS: TFileStream;
  I: Integer;
  LTmp: string;
  LHash: TBytes;
  LTime: Int64;
begin
  if FPath = '' then Exit;
  LTmp := FPath + '.tmp';
  try
    FS := TFileStream.Create(LTmp, fmCreate);
    try
      platform_mutex_lock(FInner.FMutex);
      try
        for I := 0 to High(FInner.FHashes) do
        begin
          LHash := FInner.FHashes[I];
          LTime := FInner.FTimes[I];
          if Length(LHash) <> 32 then Continue;
          FS.WriteBuffer(LHash[0], 32);
          FS.WriteBuffer(LTime, 8);
        end;
      finally
        platform_mutex_unlock(FInner.FMutex);
      end;
    finally
      FS.Free;
    end;
    if FileExists(FPath) then DeleteFile(FPath);
    RenameFile(LTmp, FPath);
  except
    // 落盘失败不影响内存去重
    try if FileExists(LTmp) then DeleteFile(LTmp); except end;
  end;
end;

function TAsyncTlsPasReplayFileStore.CheckAndAdd(const AFingerprint: TBytes; out IsReplay: Boolean): Boolean;
begin
  platform_mutex_lock(FMutex);
  try
    Result := FInner.CheckAndAdd(AFingerprint, IsReplay);
    if Result then
      SaveToFile;
  finally
    platform_mutex_unlock(FMutex);
  end;
end;

procedure TAsyncTlsPasReplayFileStore.Clear;
begin
  platform_mutex_lock(FMutex);
  try
    FInner.Clear;
    SaveToFile;
  finally
    platform_mutex_unlock(FMutex);
  end;
end;

function TAsyncTlsPasReplayFileStore.Count: Integer;
begin
  Result := FInner.Count;
end;

function TAsyncTlsPasReplayFileStore.GetStats: TAsyncTlsPasReplayStats;
begin
  Result := FInner.GetStats;
end;

{ ======== 内存 KV 存储 ======== }

constructor TAsyncTlsPasMemoryKvStore.Create;
begin
  inherited Create;
  if platform_mutex_init(FMutex) <> 0 then
    raise EInvalidOperationError.Create('tlspas: memory kv mutex init');
end;

destructor TAsyncTlsPasMemoryKvStore.Destroy;
var I: Integer;
begin
  platform_mutex_destroy(FMutex);
  for I := 0 to High(FValues) do
    SecureZeroBytes(FValues[I]);
  inherited Destroy;
end;

function TAsyncTlsPasMemoryKvStore.Get(const AKey: string; out AValue: TBytes): Boolean;
var I: Integer; LNow: Int64;
begin
  Result := False;
  SetLength(AValue, 0);
  LNow := TlsPasMonoMs;
  platform_mutex_lock(FMutex);
  try
    I := 0;
    while I < Length(FKeys) do
    begin
      if FExpiries[I] <= LNow then
      begin
        SecureZeroBytes(FValues[I]);
        FKeys[I] := FKeys[High(FKeys)];
        FValues[I] := FValues[High(FValues)];
        FExpiries[I] := FExpiries[High(FExpiries)];
        SetLength(FKeys, Length(FKeys) - 1);
        SetLength(FValues, Length(FValues) - 1);
        SetLength(FExpiries, Length(FExpiries) - 1);
      end else Inc(I);
    end;
    for I := 0 to High(FKeys) do
      if FKeys[I] = AKey then
      begin
        AValue := Copy(FValues[I]);
        Result := True;
        Exit;
      end;
  finally
    platform_mutex_unlock(FMutex);
  end;
end;

procedure TAsyncTlsPasMemoryKvStore.SetKV(const AKey: string; const AValue: TBytes; ATTLMs: Int64);
var I: Integer; LExp: Int64;
begin
  if ATTLMs <= 0 then ATTLMs := 600000;
  LExp := TlsPasMonoMs + ATTLMs;
  platform_mutex_lock(FMutex);
  try
    for I := 0 to High(FKeys) do
      if FKeys[I] = AKey then
      begin
        SecureZeroBytes(FValues[I]);
        FValues[I] := Copy(AValue);
        FExpiries[I] := LExp;
        Exit;
      end;
    SetLength(FKeys, Length(FKeys) + 1);
    SetLength(FValues, Length(FValues) + 1);
    SetLength(FExpiries, Length(FExpiries) + 1);
    FKeys[High(FKeys)] := AKey;
    FValues[High(FValues)] := Copy(AValue);
    FExpiries[High(FExpiries)] := LExp;
  finally
    platform_mutex_unlock(FMutex);
  end;
end;

procedure TAsyncTlsPasMemoryKvStore.Delete(const AKey: string);
var I, J: Integer;
begin
  platform_mutex_lock(FMutex);
  try
    for I := 0 to High(FKeys) do
      if FKeys[I] = AKey then
      begin
        SecureZeroBytes(FValues[I]);
        for J := I to High(FKeys) - 1 do
        begin
          FKeys[J] := FKeys[J+1];
          FValues[J] := FValues[J+1];
          FExpiries[J] := FExpiries[J+1];
        end;
        SetLength(FKeys, Length(FKeys)-1);
        SetLength(FValues, Length(FValues)-1);
        SetLength(FExpiries, Length(FExpiries)-1);
        Exit;
      end;
  finally
    platform_mutex_unlock(FMutex);
  end;
end;

procedure TAsyncTlsPasMemoryKvStore.Clear;
var I: Integer;
begin
  platform_mutex_lock(FMutex);
  try
    for I := 0 to High(FValues) do
      SecureZeroBytes(FValues[I]);
    SetLength(FKeys, 0);
    SetLength(FValues, 0);
    SetLength(FExpiries, 0);
  finally
    platform_mutex_unlock(FMutex);
  end;
end;

{ ======== KV 重放存储（本地 LRU + 远端 KV） ======== }

constructor TAsyncTlsPasReplayKvStore.Create(const AKv: ITlsPasKvStore; ACapacity: Integer; AWindowMs: Int64);
begin
  inherited Create;
  if not Assigned(AKv) then
    raise EInvalidOperationError.Create('tlspas: kv store nil');
  FKv := AKv;
  FWindowMs := AWindowMs;
  if FWindowMs <= 0 then FWindowMs := 600000;
  FLocal := TAsyncTlsPasReplayCache.Create(ACapacity, FWindowMs);
  if platform_mutex_init(FMutex) <> 0 then
  begin
    FLocal.Free;
    raise EInvalidOperationError.Create('tlspas: kv replay mutex init');
  end;
end;

destructor TAsyncTlsPasReplayKvStore.Destroy;
begin
  platform_mutex_destroy(FMutex);
  FLocal.Free;
  inherited Destroy;
end;

function TAsyncTlsPasReplayKvStore.FingerprintToKey(const AFingerprint: TBytes): string;
const HexChars: array[0..15] of Char = '0123456789abcdef';
var I: Integer;
begin
  Result := 'replay:';
  SetLength(Result, 7 + Length(AFingerprint)*2);
  for I := 0 to High(AFingerprint) do
  begin
    Result[8 + I*2] := HexChars[(AFingerprint[I] shr 4) and $F];
    Result[8 + I*2 + 1] := HexChars[AFingerprint[I] and $F];
  end;
end;

function TAsyncTlsPasReplayKvStore.CheckAndAdd(const AFingerprint: TBytes; out IsReplay: Boolean): Boolean;
var LKey: string; LVal: TBytes; LLocalReplay: Boolean;
begin
  Result := False;
  IsReplay := False;
  if Length(AFingerprint) <> 32 then Exit;
  LKey := FingerprintToKey(AFingerprint);
  platform_mutex_lock(FMutex);
  try
    // 先查本地
    if FLocal.CheckAndAdd(AFingerprint, LLocalReplay) then
    begin
      if LLocalReplay then
      begin
        IsReplay := True;
        Result := True;
        Exit;
      end;
      // 本地未命中已插入，查远端是否已有（跨进程/重启重放）
      if FKv.Get(LKey, LVal) then
      begin
        // 远端已有 -> 视为重放（本地已插入但应判重放）
        IsReplay := True;
        Result := True;
        Exit;
      end;
      // 均未命中 -> 写入远端
      SetLength(LVal, 1);
      LVal[0] := 1;
      FKv.SetKV(LKey, LVal, FWindowMs);
      IsReplay := False;
      Result := True;
    end else
      Result := False;
  finally
    platform_mutex_unlock(FMutex);
  end;
end;

procedure TAsyncTlsPasReplayKvStore.Clear;
begin
  platform_mutex_lock(FMutex);
  try
    FLocal.Clear;
    FKv.Clear;
  finally
    platform_mutex_unlock(FMutex);
  end;
end;

function TAsyncTlsPasReplayKvStore.Count: Integer;
begin
  Result := FLocal.Count;
end;

function TAsyncTlsPasReplayKvStore.GetStats: TAsyncTlsPasReplayStats;
begin
  Result := FLocal.GetStats;
end;

{ ======== 工厂 ======== }

class function TAsyncTlsPasReplayStoreFactory.CreateMemory(ACapacity: Integer; AWindowMs: Int64): ITlsPasReplayStore;
begin
  Result := TAsyncTlsPasReplayCache.Create(ACapacity, AWindowMs) as ITlsPasReplayStore;
end;

class function TAsyncTlsPasReplayStoreFactory.CreateFile(const APath: string; ACapacity: Integer; AWindowMs: Int64): ITlsPasReplayStore;
begin
  Result := TAsyncTlsPasReplayFileStore.Create(APath, ACapacity, AWindowMs) as ITlsPasReplayStore;
end;

class function TAsyncTlsPasReplayStoreFactory.CreateKv(const AKv: ITlsPasKvStore; ACapacity: Integer; AWindowMs: Int64): ITlsPasReplayStore;
begin
  Result := TAsyncTlsPasReplayKvStore.Create(AKv, ACapacity, AWindowMs) as ITlsPasReplayStore;
end;

{ 从 ABuf 组一条完整记录：1=取出（从缓冲移除），0=需要更多字节，
  <0=协议错（类型非法或超限） }
function TlsPasTryFrameRecord(var ABuf: TBytes; out ACt: Byte;
  out APayload: TBytes): Integer;
var
  LHeader: TTLSRecordHeader;
  LHeaderBytes: TBytes;
  LTotal: Integer;
begin
  Result := 0;
  ACt := 0;
  SetLength(APayload, 0);
  if Length(ABuf) < 5 then
    Exit;
  SetLength(LHeaderBytes, 5);
  Move(ABuf[0], LHeaderBytes[0], 5);
  if not ParseTLSRecordHeader(LHeaderBytes, LHeader) then
    Exit(-1);
  case LHeader.ContentType of
    TLS_CONTENT_TYPE_CHANGE_CIPHER_SPEC,
    TLS_CONTENT_TYPE_ALERT,
    TLS_CONTENT_TYPE_HANDSHAKE,
    TLS_CONTENT_TYPE_APPLICATION_DATA: ;
  else
    Exit(-1);
  end;
  if LHeader.Length > cMaxRecordPayload then
    Exit(-1);
  LTotal := 5 + Integer(LHeader.Length);
  if Length(ABuf) < LTotal then
    Exit;
  ACt := LHeader.ContentType;
  SetLength(APayload, Integer(LHeader.Length));
  if LHeader.Length > 0 then
    Move(ABuf[5], APayload[0], LHeader.Length);
  Move(ABuf[LTotal], ABuf[0], Length(ABuf) - LTotal);
  SetLength(ABuf, Length(ABuf) - LTotal);
  Result := 1;
end;

{ 零拷贝视图版：从连续缓冲 (AData, AAvailable) 试组一条记录
  返回 1=可组帧（填充 ACt/APayloadOff/APayloadLen/ATotalLen）
        0=需要更多字节  <0=协议错；不移动/不拷贝缓冲 }
function TlsPasTryFrameRecordView(AData: PByte; AAvailable: SizeUInt;
  out ACt: Byte; out APayloadOff, APayloadLen, ATotalLen: SizeUInt): Integer;
begin
  Result := 0;
  ACt := 0; APayloadOff := 0; APayloadLen := 0; ATotalLen := 0;
  if (AData = nil) and (AAvailable > 0) then Exit(-1);
  if AAvailable < 5 then Exit(0);
  ACt := AData[0];
  case ACt of
    TLS_CONTENT_TYPE_CHANGE_CIPHER_SPEC,
    TLS_CONTENT_TYPE_ALERT,
    TLS_CONTENT_TYPE_HANDSHAKE,
    TLS_CONTENT_TYPE_APPLICATION_DATA: ;
  else
    Exit(-1);
  end;
  APayloadLen := (SizeUInt(AData[3]) shl 8) or SizeUInt(AData[4]);
  if APayloadLen > SizeUInt(cMaxRecordPayload) then Exit(-1);
  ATotalLen := 5 + APayloadLen;
  if AAvailable < ATotalLen then Exit(0);
  APayloadOff := 5;
  Result := 1;
end;

{ 从握手消息流弹出一条完整消息：1=弹出，0=需要更多，<0=超限 }
function TlsPasTryPopHandshake(var ABuf: TBytes; out AMessage: TBytes): Integer;
var
  LLen: Cardinal;
begin
  Result := 0;
  SetLength(AMessage, 0);
  if Length(ABuf) < 4 then
    Exit;
  LLen := ReadUInt24(ABuf, 1);
  if LLen > cMaxHandshakeMessage then
    Exit(-1);
  if Length(ABuf) < 4 + Integer(LLen) then
    Exit;
  SetLength(AMessage, 4 + Integer(LLen));
  Move(ABuf[0], AMessage[0], 4 + Integer(LLen));
  Move(ABuf[4 + Integer(LLen)], ABuf[0],
    Length(ABuf) - (4 + Integer(LLen)));
  SetLength(ABuf, Length(ABuf) - (4 + Integer(LLen)));
  Result := 1;
end;

{ 用客户端握手密钥封一条记录（Certificate/Finished 飞行）。
  失败抛错（仅内存/AEAD 内部错，调用点统一转握手失败）。 }
function TlsPasSealClientHandshakeRecord(ACtx: PTlsPasHsCtx; const ABody: TBytes;
  ACT: Byte): TBytes;
var
  LInner, LNonce, LAAD, LEncrypted: TBytes;
  LError: string;
begin
  LInner := BuildTLS13InnerPlaintext(ABody, ACT);
  LNonce := BuildTLS13RecordNonce(ACtx^.Secrets.ClientHandshakeIV,
    ACtx^.CliSeq);
  LAAD := BuildTLS13RecordAAD(
    Word(Length(LInner) + TLS13AEADTagLength(ACtx^.Suite)));
  if not TryTLS13AEADEncrypt(ACtx^.Suite,
    ACtx^.Secrets.ClientHandshakeKey, LNonce, LAAD, LInner, LEncrypted,
    LError) then
    raise EInvalidOperationError.Create('tlspas: seal client flight: ' +
      LError);
  if not IncrementTLS13Sequence(ACtx^.CliSeq) then
    raise EInvalidOperationError.Create('tlspas: client sequence overflow');
  Result := BuildTLSPlaintext(TLS_CONTENT_TYPE_APPLICATION_DATA,
    LEncrypted);
end;

procedure BuildClientFlight(ACtx: PTlsPasHsCtx);
var
  LTranscript: TBytes;
  LTranscriptForFin: TBytes;
  LHash: TBytes;
  LVerify: TBytes;
  LFinished: TBytes;
  LEoed: TBytes;
  LFlight: TBytes;
  LRecord: TBytes;
begin
  { RFC 8446 §4.5：接受 early_data 时客户端在 Finished 之前发送
    EndOfEarlyData，且 Finished 的 transcript Hash 需覆盖 EOED。 }
  LTranscript := Copy(ACtx^.Transcript, 0, Length(ACtx^.Transcript));
  LTranscriptForFin := Copy(LTranscript, 0, Length(LTranscript));
  if ACtx^.EarlyDataAccepted then
  begin
    LEoed := BuildTLS13EndOfEarlyDataHandshake;
    AppendBytesTo(LTranscriptForFin, LEoed);
  end
  else
    SetLength(LEoed, 0);
  LHash := TlsPasTranscriptHash(ACtx^.Suite, LTranscriptForFin);
  LVerify := TLS13ComputeFinishedVerifyDataForCipherSuite(ACtx^.Suite,
    ACtx^.ClientFinKey, LHash);

  SetLength(LFinished, 4 + Length(LVerify));
  LFinished[0] := TLS_HANDSHAKE_TYPE_FINISHED;
  LFinished[1] := Byte((Length(LVerify) shr 16) and $FF);
  LFinished[2] := Byte((Length(LVerify) shr 8) and $FF);
  LFinished[3] := Byte(Length(LVerify) and $FF);
  if Length(LVerify) > 0 then
    Move(LVerify[0], LFinished[4], Length(LVerify));

  { 飞行按 RFC 顺序拼装：EOED (+ 空 Certificate 若被请求) + Finished，
    同一 handshake IV 下一同加密为单记录，降低往返与分片。 }
  SetLength(LFlight, 0);
  if Length(LEoed) > 0 then
    AppendBytesTo(LFlight, LEoed);
  if ACtx^.CertRequested then
    AppendBytesTo(LFlight, TBytes.Create(TLS_HANDSHAKE_TYPE_CERTIFICATE, 0, 0, 4,
      0, 0, 0, 0));
  AppendBytesTo(LFlight, LFinished);

  SetLength(ACtx^.TxBytes, 0);
  LRecord := TlsPasSealClientHandshakeRecord(ACtx, LFlight,
    TLS_CONTENT_TYPE_HANDSHAKE);
  AppendBytesTo(ACtx^.TxBytes, LRecord);
  ACtx^.TxOff := 0;

  { resumption_master_secret 输入 = Hash(CH..EOED..CF)；v1 不恢复会话，
    保留正确派生供后续批次扩展 }
  if Length(LEoed) > 0 then
    AppendBytesTo(LTranscript, LEoed);
  if ACtx^.CertRequested then
    AppendBytesTo(LTranscript, TBytes.Create(TLS_HANDSHAKE_TYPE_CERTIFICATE, 0, 0, 4,
      0, 0, 0, 0));
  AppendBytesTo(LTranscript, LFinished);
  ACtx^.AppSecrets.ResumptionTranscriptHash :=
    TlsPasTranscriptHash(ACtx^.Suite, LTranscript);
end;

{ ======== HRR 辅助：资料勘察结论 ========
  BuildTLS13ClientHelloHandshakeWithComputedPSKBinder(无 Ciphers 版)与
  BuildTLS13ClientHelloHandshake 均未内置 message_hash 扩展的自动插入；
  HRR+PSK 组合的 binder 重算在 RFC 8446 中要求覆盖 CH1||HRR，外加
  message_hash 仅为 transcript 内部合成（0xFE 类型），并不在 CH2
  线材中出现。实测 Freepascal 后端亦采用 PatchClientHelloKeyShare
  仅替换 key_share、随后手工重算 binder 的路径，且保持其余扩展
  （supported_groups 等）与 CH1 一致。为保持跨模块最小改动，本
  单元沿用 patch 思路：HRR 时用 PatchClientHelloKeyShare 生成 CH2，
  再以手工 binder 覆盖；不扩展 clienthello 构建器，避免为单一
  状态机引入额外 builder 分支。跨模块 touched files 仅本单元与
  p256ecdh/p384（P-384 新增）。HRR 重试同时支持 P-256(65B)/P-384(97B)。 }

function TlsPasIsHRR(const ARandom: TBytes): Boolean;
begin
  Result := (Length(ARandom) = 32) and CompareMem(@ARandom[0], @TLS13_HRR_RANDOM[0], 32);
end;

function TlsPasBuildMessageHash(const ACH1: TBytes; ACipherSuite: Word): TBytes;
var
  LHash: TBytes;
begin
  Result := nil;
  if TLS13CipherSuiteIsSHA384(ACipherSuite) then
    LHash := SHA384(ACH1)
  else
    LHash := SHA256(ACH1);
  SetLength(Result, 4 + Length(LHash));
  Result[0] := 254;
  Result[1] := 0;
  Result[2] := 0;
  Result[3] := Byte(Length(LHash));
  if Length(LHash) > 0 then
    Move(LHash[0], Result[4], Length(LHash));
end;

function TlsPasHasEarlyData(const AClientHelloHandshake: TBytes): Boolean;
var LInfo: TTLS13ClientHelloInfo; LErr: string;
begin
  Result := False;
  if TryParseTLS13ClientHelloFromHandshake(AClientHelloHandshake, LInfo, LErr) then
    Result := LInfo.HasEarlyData;
end;

function TlsPasPatchBinder(const AOriginalCH: TBytes; const ANewBinder: TBytes): TBytes;
var
  LPos, LExtStart, LExtLen, LExtType, LExtListLen: Integer;
  LSessionIdLen, LCipherLen, LCompLen: Integer;
  LPskeExtPos, LPskeExtLen: Integer;
  LIdentitiesLen, LIdLen, LBinderLenPos, LOldBinderLen: Integer;
  LBeforeBinder, LAfterBinder: TBytes;
  LNewExtLen: Integer;
begin
  Result := Copy(AOriginalCH);
  if Length(AOriginalCH) < 44 then Exit;
  LPos := 38;
  if LPos >= Length(AOriginalCH) then Exit;
  LSessionIdLen := AOriginalCH[LPos];
  Inc(LPos, 1 + LSessionIdLen);
  if LPos + 2 > Length(AOriginalCH) then Exit;
  LCipherLen := (Integer(AOriginalCH[LPos]) shl 8) or Integer(AOriginalCH[LPos+1]);
  Inc(LPos, 2 + LCipherLen);
  if LPos >= Length(AOriginalCH) then Exit;
  LCompLen := AOriginalCH[LPos];
  Inc(LPos, 1 + LCompLen);
  if LPos + 2 > Length(AOriginalCH) then Exit;
  LExtListLen := (Integer(AOriginalCH[LPos]) shl 8) or Integer(AOriginalCH[LPos+1]);
  LExtStart := LPos + 2;
  LPos := LExtStart;
  LPskeExtPos := -1;
  LPskeExtLen := 0;
  while LPos + 4 <= LExtStart + LExtListLen do
  begin
    LExtType := (Integer(AOriginalCH[LPos]) shl 8) or Integer(AOriginalCH[LPos+1]);
    LExtLen := (Integer(AOriginalCH[LPos+2]) shl 8) or Integer(AOriginalCH[LPos+3]);
    if LExtType = TLS_EXTENSION_PRE_SHARED_KEY then
    begin
      LPskeExtPos := LPos;
      LPskeExtLen := LExtLen;
      Break;
    end;
    Inc(LPos, 4 + LExtLen);
  end;
  if LPskeExtPos < 0 then Exit;
  // Inside PSK extension data: identities_len(2) + identities + binders_len(2) + binders
  LPos := LPskeExtPos + 4;
  if LPos + 2 > Length(AOriginalCH) then Exit;
  LIdentitiesLen := (Integer(AOriginalCH[LPos]) shl 8) or Integer(AOriginalCH[LPos+1]);
  Inc(LPos, 2 + LIdentitiesLen);
  if LPos + 2 > Length(AOriginalCH) then Exit;
  // binders_len
  LBinderLenPos := LPos;
  // old binder len byte at LPos+2
  if LPos + 2 + 1 > Length(AOriginalCH) then Exit;
  LOldBinderLen := AOriginalCH[LPos+2];
  // binder bytes at LPos+3 .. LPos+2+LOldBinderLen
  if LPos + 3 + LOldBinderLen > LPskeExtPos + 4 + LPskeExtLen then Exit;
  // Build patch: replace single binder entry (len byte + binder)
  // Keep binders_len field (2 bytes) same length if binder size unchanged (binder size = hash size, same suite)
  if Length(ANewBinder) <> LOldBinderLen then Exit;
  // Copy before binder bytes
  LBeforeBinder := Copy(AOriginalCH, 0, LPos+3);
  LAfterBinder := Copy(AOriginalCH, LPos+3+LOldBinderLen, Length(AOriginalCH) - (LPos+3+LOldBinderLen));
  SetLength(Result, Length(LBeforeBinder) + Length(ANewBinder) + Length(LAfterBinder));
  Move(LBeforeBinder[0], Result[0], Length(LBeforeBinder));
  Move(ANewBinder[0], Result[Length(LBeforeBinder)], Length(ANewBinder));
  Move(LAfterBinder[0], Result[Length(LBeforeBinder)+Length(ANewBinder)], Length(LAfterBinder));
end;

function TlsPasComputeHRRBinder(ACipherSuite: Word; const APSK, ACH1, AHRR, ATruncatedCH2: TBytes): TBytes;
var
  LTranscript: TBytes;
  LHash: TBytes;
  LZero: TBytes;
  LEarlySecret, LBinderKey: TBytes;
  LMsgHash: TBytes;
begin
  LMsgHash := TlsPasBuildMessageHash(ACH1, ACipherSuite);
  SetLength(LTranscript, 0);
  AppendBytesTo(LTranscript, LMsgHash);
  AppendBytesTo(LTranscript, AHRR);
  AppendBytesTo(LTranscript, ATruncatedCH2);
  if TLS13CipherSuiteIsSHA384(ACipherSuite) then
    LHash := SHA384(LTranscript)
  else
    LHash := SHA256(LTranscript);
  SetLength(LZero, 0);
  if TLS13CipherSuiteIsSHA384(ACipherSuite) then
    LEarlySecret := HKDF_Extract_SHA384(LZero, APSK)
  else
    LEarlySecret := HKDF_Extract_SHA256(LZero, APSK);
  if TLS13CipherSuiteIsSHA384(ACipherSuite) then
    LBinderKey := TLS13_HKDF_Expand_Label_SHA384(LEarlySecret, 'res binder', SHA384(LZero), 48)
  else
    LBinderKey := TLS13_HKDF_Expand_Label_SHA256(LEarlySecret, 'res binder', SHA256(LZero), 32);
  Result := TLS13ComputeFinishedVerifyDataFromTrafficSecretForCipherSuite(ACipherSuite, LBinderKey, LHash);
end;

function TlsPasIsSupportedHRRGroup(AGroup: Word): Boolean;
begin
  Result := (AGroup = TLS13_GROUP_X25519) or (AGroup = TLS13_GROUP_SECP256R1) or (AGroup = TLS13_GROUP_SECP384R1);
end;

function TlsPasGroupKeyShareLen(AGroup: Word): Integer;
begin
  case AGroup of
    TLS13_GROUP_X25519: Result := 32;
    TLS13_GROUP_SECP256R1: Result := 65;
    TLS13_GROUP_SECP384R1: Result := 97;
  else
    Result := -1;
  end;
end;

function TlsPasGenerateHRRKeyPair(AGroup: Word; ACtx: PTlsPasHsCtx; out APub: TBytes; out AError: string): Boolean;
var
  LPrivP256: TBytes;
  LPrivP384: TBytes;
begin
  Result := False;
  AError := '';
  SetLength(APub, 0);
  case AGroup of
    TLS13_GROUP_SECP256R1:
      begin
        if not TryGenerateP256ECDHKeyPair(LPrivP256, APub, AError) then Exit;
        SecureZeroBytes(ACtx^.Priv);
        SecureZeroBytes(ACtx^.PrivP384);
        ACtx^.PrivP256 := LPrivP256;
      end;
    TLS13_GROUP_SECP384R1:
      begin
        if not TryP384ECDHEKeyPair(LPrivP384, APub, AError) then Exit;
        SecureZeroBytes(ACtx^.Priv);
        SecureZeroBytes(ACtx^.PrivP256);
        ACtx^.PrivP384 := LPrivP384;
      end;
    TLS13_GROUP_X25519:
      begin
        GenerateX25519KeyPair(LPrivP256, APub);
        SecureZeroBytes(ACtx^.PrivP256);
        SecureZeroBytes(ACtx^.PrivP384);
        SecureZeroBytes(ACtx^.Priv);
        ACtx^.Priv := LPrivP256;
      end;
  else
    AError := 'unsupported HRR group';
    Exit;
  end;
  Result := True;
end;

function TlsPasDeriveSharedSecret(ACtx: PTlsPasHsCtx; AGroup: Word; const APeerShare: TBytes; out AShared: TBytes; out AError: string): Boolean;
var
  LPeerPoint: TECPoint;
  LSharedPoint: TECPoint;
  LSharedX: TBytes;
begin
  Result := False;
  AError := '';
  SetLength(AShared, 0);
  case AGroup of
    TLS13_GROUP_X25519:
      begin
        try
          AShared := X25519ComputeSharedSecret(ACtx^.Priv, APeerShare);
          Result := True;
        except
          on E: Exception do AError := E.Message;
        end;
      end;
    TLS13_GROUP_SECP256R1:
      begin
        if Length(ACtx^.PrivP256) = 0 then begin AError := 'P-256 private missing'; Exit; end;
        if not TryParseP256PublicPoint(APeerShare, LPeerPoint, AError) then Exit;
        if not TryP256ScalarMult(ACtx^.PrivP256, LPeerPoint, LSharedPoint, AError) then Exit;
        if LSharedPoint.IsInfinity then begin AError := 'P-256 ECDHE infinity'; Exit; end;
        if not TryToFixedLength32(LSharedPoint.X, LSharedX, AError) then Exit;
        if Length(LSharedX) <> 32 then begin AError := 'P-256 shared len'; Exit; end;
        AShared := LSharedX;
        Result := True;
      end;
    TLS13_GROUP_SECP384R1:
      begin
        if Length(ACtx^.PrivP384) = 0 then begin AError := 'P-384 private missing'; Exit; end;
        if not TryP384ECDHE(ACtx^.PrivP384, APeerShare, AShared, AError) then Exit;
        Result := True;
      end;
  else
    AError := 'unsupported group';
  end;
end;

{ ======== 握手上下文生命周期 ======== }

procedure CancelHsTimer(ACtx: PTlsPasHsCtx);
begin
  if (ACtx <> nil) and (ACtx^.Loop <> nil) and ACtx^.Timer.IsValid then
  begin
    ACtx^.Loop.CancelTimer(ACtx^.Timer);
    ACtx^.Timer := TAsyncTimerHandle.None;
  end;
end;

procedure FreeHsCtx(ACtx: PTlsPasHsCtx);
begin
  if ACtx = nil then
    Exit;
  CancelHsTimer(ACtx);
  ClearTLS13HandshakeSecrets(ACtx^.Secrets);
  ClearTLS13ApplicationSecrets(ACtx^.AppSecrets);
  TlsPasClearEarlyDataSecrets(ACtx^.EarlySecrets);
  ACtx^.EarlySealer.Clear;
  SecureZeroBytes(ACtx^.EarlyData);
  SecureZeroBytes(ACtx^.Priv);
  SecureZeroBytes(ACtx^.PrivP256);
  SecureZeroBytes(ACtx^.PrivP384);
  SecureZeroBytes(ACtx^.ServerFinKey);
  SecureZeroBytes(ACtx^.ClientFinKey);
  SecureZeroBytes(ACtx^.HRRTranscript);
  ACtx^.Stream := nil;
  ACtx^.Loop := nil;
  Dispose(ACtx);
end;

{ 同步提交失败路径：静默释放，不回调（契约：False = 未回调） }
procedure FreeHsCtxSilent(ACtx: PTlsPasHsCtx);
begin
  if ACtx <> nil then
    ACtx^.Finished := True;
  FreeHsCtx(ACtx);
end;

procedure TlsPasFail(ACtx: PTlsPasHsCtx; AErr: Int32);
var
  LCb: TAsyncTlsPasConnectCallback;
  LCbCtx: Pointer;
begin
  if (ACtx = nil) or ACtx^.Finished then
    Exit;
  ACtx^.Finished := True;
  LCb := ACtx^.OnReady;
  LCbCtx := ACtx^.OnReadyCtx;
  FreeHsCtx(ACtx);
  if Assigned(LCb) then
    LCb(nil, AErr, LCbCtx);
end;

procedure TlsPasDone(ACtx: PTlsPasHsCtx);
var
  LStream: TTlsPasStream;
  LCb: TAsyncTlsPasConnectCallback;
  LCbCtx: Pointer;
  LNetInSeed: TBytes;
  LPostHsSeed: TBytes;
begin
  if (ACtx = nil) or ACtx^.Finished then
    Exit;
  ACtx^.Finished := True;
  CancelHsTimer(ACtx);
  { 未组帧残余与已解密未消费握手片段移交数据相 }
  LNetInSeed := ACtx^.NetIn;
  LPostHsSeed := ACtx^.EncBuf;
  LStream := TTlsPasStream.Create(ACtx^.Suite, ACtx^.AppSecrets,
    ACtx^.Stream, ACtx^.Loop, LNetInSeed, LPostHsSeed,
    ACtx^.Cache, ACtx^.ServerName, ACtx^.CachePort, ACtx^.PsksAccepted, ACtx^.HRRSeen, ACtx^.EarlyDataAccepted);
  ACtx^.Stream := nil;
  LCb := ACtx^.OnReady;
  LCbCtx := ACtx^.OnReadyCtx;
  FreeHsCtx(ACtx);
  if Assigned(LCb) then
    LCb(LStream as IAsyncTcpStream, 0, LCbCtx);
end;

{ ======== 接收处理 ======== }

procedure HandleServerHelloMessage(ACtx: PTlsPasHsCtx; const AMsg: TBytes);
var
  LShared: TBytes;
  LInfo: TTLS13ServerHelloInfo;
  LError: string;
  LNewPub: TBytes;
  LCH2: TBytes;
  LTruncatedCH2: TBytes;
  LMsgHash: TBytes;
  LNewBinder: TBytes;
  LCookieExt: TBytes;
  LExtListLen: Integer;
  LPos: Integer;
  LScan: Integer;
  LExtType: Integer;
  LExtLen: Integer;
  LPskePos: Integer;
  LBefore: TBytes;
  LAfter: TBytes;
begin
  if not TryParseServerHelloFromHandshake(AMsg, LInfo) then
  begin
    TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
    Exit;
  end;
  if LInfo.SelectedVersion <> $0304 then
  begin
    TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
    Exit;
  end;
  if TlsPasIsHRR(LInfo.ServerRandom) then
  begin
    if ACtx^.HRRSeen then
    begin
      TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
      Exit;
    end;
    // S6-record：HRR 与 early_data 互斥，已发 early_data 遇到 HRR 直接 fail-closed
    if ACtx^.SentEarlyData then
    begin
      TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
      Exit;
    end;
    if (not LInfo.HasKeyShare) or (Length(LInfo.PeerKeyShare) <> 0) then
    begin
      TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
      Exit;
    end;
    if not TlsPasIsSupportedHRRGroup(LInfo.KeyShareGroup) then
    begin
      TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
      Exit;
    end;
    if LInfo.KeyShareGroup = ACtx^.FirstGroup then
    begin
      TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
      Exit;
    end;
    if not TLS13AEADIsSupported(LInfo.SelectedCipherSuite) then
    begin
      TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
      Exit;
    end;
    if Length(ACtx^.CH1Body) = 0 then
      ACtx^.CH1Body := Copy(ACtx^.CHBody);
    if not TlsPasGenerateHRRKeyPair(LInfo.KeyShareGroup, ACtx, LNewPub, LError) then
    begin
      TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
      Exit;
    end;
    ACtx^.FirstGroup := LInfo.KeyShareGroup;
    LCH2 := PatchClientHelloKeyShare(ACtx^.CHBody, LNewPub, LInfo.KeyShareGroup);
    if Length(LCH2) = 0 then
    begin
      TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
      Exit;
    end;
    if LInfo.HasCookie and (Length(LInfo.Cookie) > 0) then
    begin
      SetLength(LCookieExt, 4 + Length(LInfo.Cookie));
      LCookieExt[0] := Byte($00); LCookieExt[1] := Byte($2C);
      LCookieExt[2] := Byte(Length(LInfo.Cookie) shr 8);
      LCookieExt[3] := Byte(Length(LInfo.Cookie));
      Move(LInfo.Cookie[0], LCookieExt[4], Length(LInfo.Cookie));
      // 计算扩展列表起点
      LPos := 38;
      if LPos < Length(LCH2) then
      begin
        LPos := LPos + 1 + LCH2[38];
        if LPos + 2 <= Length(LCH2) then
        begin
          LPos := LPos + 2 + ((Integer(LCH2[LPos]) shl 8) or Integer(LCH2[LPos+1]));
          if LPos < Length(LCH2) then
          begin
            LPos := LPos + 1 + LCH2[LPos];
            if LPos + 2 <= Length(LCH2) then
            begin
              // LPos 此时指向 extensions_length(2B)
              if ACtx^.Resuming then
              begin
                // PSK 必须最后：cookie 插到 PSK 前，PS K 后移
                // 扫描扩展找到 PSK 位置
                LExtListLen := (Integer(LCH2[LPos]) shl 8) or Integer(LCH2[LPos+1]);
                // 扩展列表起始 LPos+2
                // 寻找 type 0x0029
                LPskePos := -1;
                LScan := LPos + 2;
                while LScan + 4 <= LPos + 2 + LExtListLen do
                begin
                  LExtType := (Integer(LCH2[LScan]) shl 8) or Integer(LCH2[LScan+1]);
                  LExtLen := (Integer(LCH2[LScan+2]) shl 8) or Integer(LCH2[LScan+3]);
                  if LExtType = TLS_EXTENSION_PRE_SHARED_KEY then begin LPskePos := LScan; Break; end;
                  Inc(LScan, 4 + LExtLen);
                end;
                if LPskePos >= 0 then
                begin
                  // 插入 cookie 到 PSK 前
                  LBefore := Copy(LCH2, 0, LPskePos);
                  LAfter := Copy(LCH2, LPskePos, Length(LCH2)-LPskePos);
                  LExtListLen := LExtListLen + Length(LCookieExt);
                  SetLength(LCH2, Length(LBefore) + Length(LCookieExt) + Length(LAfter));
                  if Length(LBefore) > 0 then Move(LBefore[0], LCH2[0], Length(LBefore));
                  Move(LCookieExt[0], LCH2[Length(LBefore)], Length(LCookieExt));
                  Move(LAfter[0], LCH2[Length(LBefore)+Length(LCookieExt)], Length(LAfter));
                  LCH2[LPos] := Byte(LExtListLen shr 8);
                  LCH2[LPos+1] := Byte(LExtListLen);
                  LPos := Length(LCH2) - 4;
                  LCH2[1] := Byte(LPos shr 16);
                  LCH2[2] := Byte(LPos shr 8);
                  LCH2[3] := Byte(LPos);
                end
                else
                begin
                  // 未找到 PSK，按追加处理
                  LExtListLen := LExtListLen + Length(LCookieExt);
                  LCH2[LPos] := Byte(LExtListLen shr 8);
                  LCH2[LPos+1] := Byte(LExtListLen);
                  SetLength(LCH2, Length(LCH2) + Length(LCookieExt));
                  Move(LCookieExt[0], LCH2[Length(LCH2)-Length(LCookieExt)], Length(LCookieExt));
                  LPos := Length(LCH2) - 4;
                  LCH2[1] := Byte(LPos shr 16);
                  LCH2[2] := Byte(LPos shr 8);
                  LCH2[3] := Byte(LPos);
                end;
              end
              else
              begin
                LExtListLen := ((Integer(LCH2[LPos]) shl 8) or Integer(LCH2[LPos+1])) + Length(LCookieExt);
                LCH2[LPos] := Byte(LExtListLen shr 8);
                LCH2[LPos+1] := Byte(LExtListLen);
                SetLength(LCH2, Length(LCH2) + Length(LCookieExt));
                Move(LCookieExt[0], LCH2[Length(LCH2)-Length(LCookieExt)], Length(LCookieExt));
                LPos := Length(LCH2) - 4;
                LCH2[1] := Byte(LPos shr 16);
                LCH2[2] := Byte(LPos shr 8);
                LCH2[3] := Byte(LPos);
              end;
            end;
          end;
        end;
      end;
    end;
    if ACtx^.Resuming then
    begin
      if Length(ACtx^.ResumeSession.ResumptionPSK) = 0 then
      begin
        TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
        Exit;
      end;
      LTruncatedCH2 := Copy(LCH2, 0, Length(LCH2) - (2 + 1 + Length(ACtx^.ResumeSession.ResumptionPSK)));
      LNewBinder := TlsPasComputeHRRBinder(LInfo.SelectedCipherSuite, ACtx^.ResumeSession.ResumptionPSK, ACtx^.CH1Body, AMsg, LTruncatedCH2);
      if Length(LNewBinder) = 0 then
      begin
        TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
        Exit;
      end;
      LCH2 := TlsPasPatchBinder(LCH2, LNewBinder);
      if Length(LCH2) = 0 then
      begin
        TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
        Exit;
      end;
    end;
    LMsgHash := TlsPasBuildMessageHash(ACtx^.CH1Body, LInfo.SelectedCipherSuite);
    SetLength(ACtx^.HRRTranscript, 0);
    AppendBytesTo(ACtx^.HRRTranscript, LMsgHash);
    AppendBytesTo(ACtx^.HRRTranscript, AMsg);
    AppendBytesTo(ACtx^.HRRTranscript, LCH2);
    ACtx^.CHBody := LCH2;
    ACtx^.HRRSeen := True;
    ACtx^.HsBuf := nil;
    ACtx^.TxBytes := BuildTLSPlaintext(TLS_CONTENT_TYPE_HANDSHAKE, LCH2);
    ACtx^.TxOff := 0;
    if not ACtx^.SendArmed then
      TlsPasArmSend(ACtx);
    Exit;
  end;
  if LInfo.HasPreSharedKey then
  begin
    if (not ACtx^.Resuming) or (LInfo.SelectedPSKIdentity <> 0) or
       (LInfo.SelectedCipherSuite <> ACtx^.ResumeSession.CipherSuite) then
    begin
      TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
      Exit;
    end;
  end;
  if not LInfo.HasKeyShare then
  begin
    TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
    Exit;
  end;
  if TlsPasGroupKeyShareLen(LInfo.KeyShareGroup) < 0 then
  begin
    TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
    Exit;
  end;
  if Length(LInfo.PeerKeyShare) <> TlsPasGroupKeyShareLen(LInfo.KeyShareGroup) then
  begin
    TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
    Exit;
  end;
  if ACtx^.HRRSeen and (LInfo.KeyShareGroup <> ACtx^.FirstGroup) then
  begin
    TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
    Exit;
  end;
  if not ACtx^.HRRSeen and (LInfo.KeyShareGroup <> TLS13_GROUP_X25519) then
  begin
    TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
    Exit;
  end;
  if not TLS13AEADIsSupported(LInfo.SelectedCipherSuite) then
  begin
    TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
    Exit;
  end;
  if not TlsPasDeriveSharedSecret(ACtx, LInfo.KeyShareGroup, LInfo.PeerKeyShare, LShared, LError) then
  begin
    TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
    Exit;
  end;
  ACtx^.Suite := LInfo.SelectedCipherSuite;
  SetLength(ACtx^.Transcript, 0);
  if ACtx^.HRRSeen then
  begin
    AppendBytesTo(ACtx^.Transcript, ACtx^.HRRTranscript);
    AppendBytesTo(ACtx^.Transcript, AMsg);
  end
  else
  begin
    AppendBytesTo(ACtx^.Transcript, ACtx^.CHBody);
    AppendBytesTo(ACtx^.Transcript, AMsg);
  end;
  if LInfo.HasPreSharedKey then
  begin
    if not TryDeriveTLS13HandshakeSecretsWithPSK(ACtx^.Suite, LShared,
      ACtx^.Transcript, ACtx^.ResumeSession.ResumptionPSK,
      ACtx^.Secrets, LError) then
    begin
      TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
      Exit;
    end;
    ACtx^.PsksAccepted := True;
  end
  else if not TryDeriveTLS13HandshakeSecrets(ACtx^.Suite, LShared,
    ACtx^.Transcript, ACtx^.Secrets, LError) then
  begin
    TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
    Exit;
  end;
  ACtx^.ServerFinKey := TLS13FinishedKeyForCipherSuite(ACtx^.Suite,
    ACtx^.Secrets.ServerHandshakeTrafficSecret);
  ACtx^.ClientFinKey := TLS13FinishedKeyForCipherSuite(ACtx^.Suite,
    ACtx^.Secrets.ClientHandshakeTrafficSecret);
  ACtx^.SrvSeq := 0;
  ACtx^.CliSeq := 0;
  ACtx^.State := hsRecvFlight;
end;

{ VerifyPeer 相一：证书链 DER → TX509 对象 → 全链验证（日期/签名/
  CA 约束/信任锚/主机名）。返回 False = 已 TlsPasFail。 }
function TlsPasVerifyServerChain(ACtx: PTlsPasHsCtx;
  const ACerts: TTLS13CertificateArray): Boolean;
var
  LChain: array of TX509Certificate;
  LStore: TX509TrustStore;
  LStoreCerts: TTlsPasCertObjArray;
  LOwned: Boolean;
  LErr: string;
  LV: TX509VerifyResult;
  I: Integer;
begin
  Result := False;
  try
    if Length(ACerts) = 0 then
    begin
      TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
      Exit;
    end;
    SetLength(LChain, Length(ACerts));
    try
      for I := 0 to High(ACerts) do
      begin
        LChain[I] := TX509Certificate.Create;
        LChain[I].LoadFromDER(ACerts[I]);
      end;
    except
      TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
      { finally 统一释放：未初始化槽位为 nil，Free 安全 }
      for I := 0 to High(LChain) do
        LChain[I].Free;
      Exit;
    end;
    try
      if not ResolveTrustStore(ACtx^.TrustBundlePath, LStore, LStoreCerts,
        LOwned, LErr) then
      begin
        WriteLn(ErrOutput, '[tlspas] verify failed: ', LErr);
        TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
        Exit;
      end;
      try
        LV := VerifyX509Chain(LChain, LStore, ACtx^.ServerName);
        if not LV.IsValid then
        begin
          { 仅失败路径的一行现场：链验证拒绝原因（日期/签名/主机名等） }
          WriteLn(ErrOutput, '[tlspas] verify failed: ', LV.ErrorMessage);
          TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
          Exit;
        end;
        ACtx^.LeafPublicKeyInfo := LChain[0].PublicKeyInfo;
        Result := True;
      finally
        { 先 store 后证书：store 析构只清指针数组，不拥有对象 }
        if LOwned then
          LStore.Free;
        for I := 0 to High(LStoreCerts) do
          LStoreCerts[I].Free;
      end;
    finally
      for I := 0 to High(LChain) do
        LChain[I].Free;
    end;
  except
    TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
  end;
end;

{ VerifyPeer 相二：CV 签名校验。输入 = Hash(CH..CERT)——调用点必须
  在把 CV 消息追加进 transcript 之前。 }
function TlsPasVerifyCertVerifySignature(ACtx: PTlsPasHsCtx; AScheme: Word;
  const ASig: TBytes): Boolean;
var
  LHash, LInput: TBytes;
  LErr: string;
begin
  Result := False;
  try
    LHash := TlsPasTranscriptHash(ACtx^.Suite, ACtx^.Transcript);
    LInput := BuildTLS13ServerCertificateVerifyInputSHA256(LHash);
    if not TryVerifyTLS13CertificateVerifySignature(AScheme,
      ACtx^.LeafPublicKeyInfo, LInput, ASig, LErr) then
    begin
      { 仅失败路径的一行现场：CV 方案与失败原因 }
      WriteLn(ErrOutput, '[tlspas] verify failed: scheme=', AScheme, ' ',
        LErr);
      TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
      Exit;
    end;
    Result := True;
  except
    TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
  end;
end;

procedure HandleEncryptedFlightRecord(ACtx: PTlsPasHsCtx;
  const APayload: TBytes);
var
  LAAD, LNonce, LPlaintext: TBytes;
  LFrag: TBytes;
  LInnerCt: Byte;
  LMsg: TBytes;
  LMsgType: Byte;
  LMsgLen: Cardinal;
  LVerify: TBytes;
  LHash: TBytes;
  LEEInfo: TTLS13EncryptedExtensionsInfo;
  LCerts: TTLS13CertificateArray;
  LScheme: Word;
  LSig: TBytes;
  LError: string;
begin
  LAAD := BuildTLS13RecordAAD(Word(Length(APayload)));
  LNonce := BuildTLS13RecordNonce(ACtx^.Secrets.ServerHandshakeIV,
    ACtx^.SrvSeq);
  if not IncrementTLS13Sequence(ACtx^.SrvSeq) then
  begin
    TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
    Exit;
  end;
  if not TryTLS13AEADDecrypt(ACtx^.Suite,
    ACtx^.Secrets.ServerHandshakeKey, LNonce, LAAD, APayload, LPlaintext,
    LError) then
  begin
    { 解密失败 = 密钥不符或遭篡改：协议层失败，不可降级 }
    TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
    Exit;
  end;
  if not TryParseTLS13InnerPlaintext(LPlaintext, LFrag, LInnerCt) then
  begin
    TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
    Exit;
  end;
  case LInnerCt of
    TLS_CONTENT_TYPE_HANDSHAKE:
      begin
        AppendBytesTo(ACtx^.EncBuf, LFrag);
        while TlsPasTryPopHandshake(ACtx^.EncBuf, LMsg) = 1 do
        begin
          LMsgType := LMsg[0];
          if LMsgType = TLS_HANDSHAKE_TYPE_ENCRYPTED_EXTENSIONS then
          begin
            if not TryParseTLS13EncryptedExtensions(LMsg, LEEInfo,
              LError) then
            begin
              TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
              Exit;
            end;
            { S6-record：early_data 接受判定。未发 early_data 却收到 EE early_data 视为协议错；
              已发 early_data 时记录接受/拒绝，HRR 与 early_data 互斥（RFC 8446 §4.1.3）。 }
            if LEEInfo.HasEarlyData then
            begin
              if not ACtx^.SentEarlyData then
              begin
                TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
                Exit;
              end;
              if ACtx^.HRRSeen then
              begin
                TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
                Exit;
              end;
              ACtx^.EarlyDataAccepted := True;
            end
            else if ACtx^.SentEarlyData then
              ACtx^.EarlyDataAccepted := False;
            ACtx^.SeenEncryptedExtensions := True;
            AppendBytesTo(ACtx^.Transcript, LMsg);
          end
          else if LMsgType = TLS_HANDSHAKE_TYPE_CERTIFICATE then
          begin
            { 恢复握手无服务器证书（RFC 8446 §2.2）；出现即协议错 }
            if ACtx^.PsksAccepted then
            begin
              TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
              Exit;
            end;
            if not TryParseTLS13ServerCertificateHandshake(LMsg, LCerts,
              LError) then
            begin
              TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
              Exit;
            end;
            ACtx^.SeenCert := True;
            AppendBytesTo(ACtx^.Transcript, LMsg);
            { VerifyPeer：全链验证（日期/签名/CA 约束/信任锚/主机名）。
              失败即握手终止——绝不降级为不校验继续。 }
            if ACtx^.VerifyPeer then
              if not TlsPasVerifyServerChain(ACtx, LCerts) then
                Exit;
          end
          else if LMsgType = TLS_HANDSHAKE_TYPE_CERTIFICATE_REQUEST then
          begin
            { v1 无客户端证书材料：fail-closed（见单元头能力边界） }
            TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
            Exit;
          end
          else if LMsgType = TLS_HANDSHAKE_TYPE_CERTIFICATE_VERIFY then
          begin
            { 恢复握手无 CV；出现即协议错 }
            if ACtx^.PsksAccepted then
            begin
              TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
              Exit;
            end;
            { 结构合法性必查（transcript 完整性依赖其长度域可信）；
              VerifyPeer=True 时签名必须验过才入 transcript——CV 签的
              是 Hash(CH..CERT)，先验后追加，顺序不可倒置 }
            if not TryParseTLS13CertificateVerifyHandshake(LMsg, LScheme,
              LSig, LError) then
            begin
              TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
              Exit;
            end;
            if ACtx^.VerifyPeer then
              if not TlsPasVerifyCertVerifySignature(ACtx, LScheme, LSig) then
                Exit;
            ACtx^.SeenCertVerify := True;
            AppendBytesTo(ACtx^.Transcript, LMsg);
          end
          else if LMsgType = TLS_HANDSHAKE_TYPE_FINISHED then
          begin
            { RFC 8446 §4.4.1-4.4.3：全握手的 server flight 必含
              EE+CERT+CV；恢复握手只需 EE。乱序/重复消息由 FINISHED 的
              transcript HMAC 自动判负，无需顺序机。 }
            if ACtx^.PsksAccepted then
            begin
              if not ACtx^.SeenEncryptedExtensions then
              begin
                TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
                Exit;
              end;
            end
            else if not (ACtx^.SeenEncryptedExtensions and
                         ACtx^.SeenCert and ACtx^.SeenCertVerify) then
            begin
              TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
              Exit;
            end;
            LMsgLen := ReadUInt24(LMsg, 1);
            if LMsgLen <> Cardinal(ACtx^.Secrets.HashSize) then
            begin
              TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
              Exit;
            end;
            SetLength(LVerify, Integer(LMsgLen));
            if Integer(LMsgLen) > 0 then
              Move(LMsg[4], LVerify[0], Integer(LMsgLen));
            LHash := TlsPasTranscriptHash(ACtx^.Suite, ACtx^.Transcript);
            if not TLS13VerifyFinishedForCipherSuite(ACtx^.Suite,
              ACtx^.Secrets.ServerHandshakeTrafficSecret, LHash,
              LVerify) then
            begin
              TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
              Exit;
            end;
            AppendBytesTo(ACtx^.Transcript, LMsg);

            { 应用密钥派生输入 = Hash(CH..SF)，不含客户端 Finished }
            if not TryDeriveTLS13ApplicationSecrets(ACtx^.Suite,
              ACtx^.Secrets.HandshakeSecret, ACtx^.Transcript,
              ACtx^.AppSecrets, LError) then
            begin
              TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
              Exit;
            end;
            try
              BuildClientFlight(ACtx);
            except
              TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
              Exit;
            end;
            ACtx^.State := hsFlushFin;
            { 返回让泵转去冲刷客户端飞行；NetIn 余量随 TlsPasDone 移交 }
            Exit;
          end
          else
          begin
            { 未知握手消息：fail-closed }
            TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
            Exit;
          end;
        end;
        if Length(ACtx^.EncBuf) > cMaxPostHsBuf then
        begin
          TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
          Exit;
        end;
      end;
    TLS_CONTENT_TYPE_ALERT:
      TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
    TLS_CONTENT_TYPE_CHANGE_CIPHER_SPEC:
      ; { middlebox 兼容记录：忽略 }
  else
    TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
  end;
end;

{ 泵尽 NetIn 可组帧记录；False = 已失败/已完成（终止泵） }
function TlsPasPumpRecords(ACtx: PTlsPasHsCtx): Boolean;
var
  LCt: Byte;
  LPayload: TBytes;
  LFrameRes, LPumped: Integer;
  LMsg: TBytes;
begin
  Result := True;
  if ACtx^.Pumping then
    Exit(True);
  ACtx^.Pumping := True;
  try
    LPumped := 0;
    while (ACtx^.State <> hsFlushFin) and not ACtx^.Finished do
    begin
      LFrameRes := TlsPasTryFrameRecord(ACtx^.NetIn, LCt, LPayload);
      if LFrameRes < 0 then
      begin
        TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
        Exit(False);
      end;
      if LFrameRes = 0 then
        Break;
      Inc(LPumped);
      if (LPumped > cMaxFlightRecords) or
         (Length(ACtx^.NetIn) > cMaxNetInBuf) then
      begin
        TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
        Exit(False);
      end;
      if ACtx^.State = hsRecvSH then
      begin
        case LCt of
          TLS_CONTENT_TYPE_CHANGE_CIPHER_SPEC: ; { 忽略 }
          TLS_CONTENT_TYPE_ALERT:
            begin
              TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
              Exit(False);
            end;
          TLS_CONTENT_TYPE_HANDSHAKE:
            begin
              AppendBytesTo(ACtx^.HsBuf, LPayload);
              while TlsPasTryPopHandshake(ACtx^.HsBuf, LMsg) = 1 do
              begin
                if LMsg[0] <> TLS_HANDSHAKE_TYPE_SERVER_HELLO then
                begin
                  TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
                  Exit(False);
                end;
                HandleServerHelloMessage(ACtx, LMsg);
                if ACtx^.Finished or (ACtx^.State = hsRecvFlight) then
                  Break;
              end;
              if Length(ACtx^.HsBuf) > cMaxHandshakeMessage then
              begin
                TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
                Exit(False);
              end;
            end;
          TLS_CONTENT_TYPE_APPLICATION_DATA:
            begin
              TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
              Exit(False);
            end;
        end;
      end
      else if ACtx^.State = hsRecvFlight then
      begin
        case LCt of
          TLS_CONTENT_TYPE_CHANGE_CIPHER_SPEC: ; { 忽略 }
          TLS_CONTENT_TYPE_ALERT:
            begin
              TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
              Exit(False);
            end;
          TLS_CONTENT_TYPE_APPLICATION_DATA:
            HandleEncryptedFlightRecord(ACtx, LPayload);
        else
          begin
            { 握手密钥相不允许明文 handshake 记录 }
            TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_HANDSHAKE);
            Exit(False);
          end;
        end;
      end;
    end;
  finally
    ACtx^.Pumping := False;
  end;
end;

{ ======== 握手 IO 臂挂 ======== }

procedure TlsPasArmRecv(ACtx: PTlsPasHsCtx);
var
  LRx: PByte;
begin
  if (ACtx = nil) or ACtx^.Finished or ACtx^.RecvArmed then
    Exit;
  SetLength(ACtx^.NetIn, Length(ACtx^.NetIn) + cNetReadChunk);
  LRx := @ACtx^.NetIn[Length(ACtx^.NetIn) - cNetReadChunk];
  ACtx^.RecvArmed := True;
  if ACtx^.Stream.AsyncRead(LRx, cNetReadChunk, @TlsPasRecvCb, ACtx) then
    Exit;
  ACtx^.RecvArmed := False;
  SetLength(ACtx^.NetIn, Length(ACtx^.NetIn) - cNetReadChunk);
  TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_IO);
end;

procedure TlsPasArmSend(ACtx: PTlsPasHsCtx);
var
  LLeft: Integer;
begin
  if (ACtx = nil) or ACtx^.Finished or ACtx^.SendArmed then
    Exit;
  LLeft := Length(ACtx^.TxBytes) - ACtx^.TxOff;
  if LLeft <= 0 then
  begin
    if ACtx^.State = hsFlushFin then
      TlsPasDone(ACtx);
    Exit;
  end;
  ACtx^.SendArmed := True;
  if ACtx^.Stream.AsyncWrite(@ACtx^.TxBytes[ACtx^.TxOff], UInt32(LLeft),
    @TlsPasSendCb, ACtx) then
    Exit;
  ACtx^.SendArmed := False;
  TlsPasFail(ACtx, ASYNC_TLSPAS_ERR_IO);
end;

{ ======== 握手回调 ======== }

procedure TlsPasRecvCb(AUserData: UInt64; AResult: Int32; AContext: Pointer);
var
  LCtx: PTlsPasHsCtx;
begin
  LCtx := PTlsPasHsCtx(AContext);
  if (LCtx = nil) or LCtx^.Finished then
    Exit;
  LCtx^.RecvArmed := False;
  if AResult <= 0 then
  begin
    { 握手期对端 EOF/传输错误都是失败 }
    if AResult = 0 then
      TlsPasFail(LCtx, ASYNC_TLSPAS_ERR_IO)
    else
      TlsPasFail(LCtx, AResult); { 底层域负码透传（取消/超时语义保留） }
    Exit;
  end;
  { 有效字节已在 NetIn 尾部（臂挂时预扩容），收缩到实际长度 }
  SetLength(LCtx^.NetIn,
    Length(LCtx^.NetIn) - cNetReadChunk + AResult);
  if not TlsPasPumpRecords(LCtx) then
    Exit;
  if LCtx^.Finished then
    Exit;
  if LCtx^.State = hsFlushFin then
  begin
    TlsPasArmSend(LCtx);
    Exit;
  end;
  TlsPasArmRecv(LCtx);
end;

procedure TlsPasSendCb(AUserData: UInt64; AResult: Int32; AContext: Pointer);
var
  LCtx: PTlsPasHsCtx;
begin
  LCtx := PTlsPasHsCtx(AContext);
  if (LCtx = nil) or LCtx^.Finished then
    Exit;
  LCtx^.SendArmed := False;
  if AResult <= 0 then
  begin
    if AResult = 0 then
      TlsPasFail(LCtx, ASYNC_TLSPAS_ERR_IO)
    else
      TlsPasFail(LCtx, AResult);
    Exit;
  end;
  Inc(LCtx^.TxOff, AResult);
  if LCtx^.State = hsFlushFin then
  begin
    if LCtx^.TxOff >= Length(LCtx^.TxBytes) then
      TlsPasDone(LCtx)
    else
      TlsPasArmSend(LCtx);
    Exit;
  end;
  { ClientHello 冲完 → 收 ServerHello }
  TlsPasArmRecv(LCtx);
end;

procedure TlsPasTimerCb(AContext: Pointer);
var
  LCtx: PTlsPasHsCtx;
begin
  LCtx := PTlsPasHsCtx(AContext);
  if (LCtx = nil) or LCtx^.Finished then
    Exit;
  LCtx^.Timer := TAsyncTimerHandle.None;
  TlsPasFail(LCtx, ASYNC_TLSPAS_ERR_IO);
end;

procedure TlsPasHsStep(ACtx: Pointer);
var
  LCtx: PTlsPasHsCtx;
  LCHRecord, LEarlyRecord: TBytes;
  LErr: string;
begin
  LCtx := PTlsPasHsCtx(ACtx);
  if (LCtx = nil) or LCtx^.Finished then
    Exit;
  if LCtx^.State <> hsSendCH then
    Exit;
  LCHRecord := BuildTLSPlaintext(TLS_CONTENT_TYPE_HANDSHAKE,
    LCtx^.CHBody);
  LCtx^.TxBytes := LCHRecord;
  // S6-record：若已派生 early 密钥且携带 EarlyData，则紧跟 CH 之后以 early 密钥封装发送（仍走同一 Tx 冲刷）。
  if LCtx^.SentEarlyData and (Length(LCtx^.EarlyData) > 0) and LCtx^.EarlySecrets.Valid then
  begin
    if LCtx^.EarlySealer.Seal(LCtx^.EarlyData, TLS_CONTENT_TYPE_APPLICATION_DATA, LEarlyRecord, LErr) then
      AppendBytes(LCtx^.TxBytes, LEarlyRecord)
    else
    begin
      // 封装失败：丢弃 EarlyData，保持 CH 仍可 1-RTT 握手，fail-open 仅丢早期数据
      SecureZeroBytes(LCtx^.EarlyData);
      SetLength(LCtx^.EarlyData, 0);
    end;
    // EarlyData 已封队即清原文（防残留）
    SecureZeroBytes(LCtx^.EarlyData);
    SetLength(LCtx^.EarlyData, 0);
  end;
  LCtx^.TxOff := 0;
  LCtx^.State := hsRecvSH;
  TlsPasArmSend(LCtx);
end;

procedure TlsPasDialDone(AStream: IAsyncTcpStream; AError: Int32;
  AContext: Pointer);
var
  LCtx: PTlsPasHsCtx;
begin
  LCtx := PTlsPasHsCtx(AContext);
  if LCtx = nil then
    Exit;
  if AError <> 0 then
  begin
    { 拨号失败原样透传 dial 域负错误码（超时/拒绝等语义保留） }
    TlsPasFail(LCtx, AError);
    Exit;
  end;
  LCtx^.Stream := AStream;
  TlsPasHsStep(LCtx);
end;

{ ======== 工厂入口 ======== }

function DefaultAsyncTlsPasClientOptions: TAsyncTlsPasClientOptions;
begin
  Result.ServerName := '';
  Result.VerifyPeer := False;
  Result.HandshakeDeadline := TDeadline.Infinite;
  Result.TrustBundlePath := '';
  Result.Cache := nil;
  Result.AllowEarlyData := False;
  SetLength(Result.EarlyData, 0);
  Result.ReplayStore := nil;
end;

{ 0-RTT 薄封装：零分支透传至 keyschedule，不引入新密钥派生实现 }
function TlsPasTryDeriveEarlyDataSecrets(
  ACipherSuite: Word; const APSK, AClientHelloHandshake: TBytes;
  out ASecrets: TTlsPasEarlyDataSecrets; out AError: string): Boolean;
begin
  Result := TryDeriveTLS13ClientEarlyDataSecrets(ACipherSuite, APSK, AClientHelloHandshake, ASecrets, AError);
end;

procedure TlsPasClearEarlyDataSecrets(var ASecrets: TTlsPasEarlyDataSecrets);
begin
  ClearTLS13EarlyDataSecrets(ASecrets);
end;

{ 公共初始化：X25519 keypair + ClientHello（失败静默释放并 re-raise）}
function AllocHsCtx(const ALoop: TAsyncLoop;
  const AServerName: string; ACachePort: UInt16;
  const AOptions: TAsyncTlsPasClientOptions;
  const AResumeSession: TTlsPasResumptionSession; AHasResume: Boolean;
  AOnReady: TAsyncTlsPasConnectCallback; AOnReadyCtx: Pointer
  ): PTlsPasHsCtx;
var
  LPub: TBytes;
  LPartialCH: TBytes;
  LAllowEarly: Boolean;
  LErr: string;
begin
  New(Result);
  FillChar(Result^, SizeOf(Result^), 0);
  Result^.Loop := ALoop;
  Result^.ServerName := AServerName;
  Result^.VerifyPeer := AOptions.VerifyPeer;
  Result^.TrustBundlePath := AOptions.TrustBundlePath;
  Result^.Cache := AOptions.Cache;
  Result^.CachePort := ACachePort;
  Result^.ResumeSession := AResumeSession;
  Result^.HasResumeSession := AHasResume;
  Result^.Deadline := AOptions.HandshakeDeadline;
  Result^.OnReady := AOnReady;
  Result^.OnReadyCtx := AOnReadyCtx;
  Result^.Timer := TAsyncTimerHandle.None;
  Result^.State := hsSendCH;
  InitTLS13HandshakeSecrets(Result^.Secrets);
  InitTLS13ApplicationSecrets(Result^.AppSecrets);
  try
    GenerateX25519KeyPair(Result^.Priv, LPub);
    Result^.FirstGroup := TLS13_GROUP_X25519;
    Result^.CH1Body := nil;
    if AHasResume then
    begin
      { PSK 恢复（psk_dhe_ke）：仍带 X25519 key_share；binder 覆盖
        去 binders 的部分 CH，由构建器内部完成。S6-ext：AllowEarlyData
        且票据携带 max_early_data 时附加 early_data 扩展（仍走 1-RTT，
        需服务端 EE 确认）。 }
      Result^.Resuming := True;
      LAllowEarly := AOptions.AllowEarlyData and AResumeSession.HasMaxEarlyData
        and (AResumeSession.MaxEarlyDataSize > 0)
        and (AResumeSession.MaxEarlyDataSize <= 16384);
      Result^.CHBody :=
        BuildTLS13ClientHelloHandshakeWithComputedPSKBinder(
          AServerName, '', LPub, AResumeSession.CipherSuite,
          AResumeSession.TicketIdentity,
          Cardinal(Int64(AResumeSession.TicketAgeAdd) +
            (TlsPasMonoMs - AResumeSession.IssuedMs)),
          AResumeSession.ResumptionPSK, LPartialCH, LAllowEarly);
    end
    else
      Result^.CHBody := BuildTLS13ClientHelloHandshake(AServerName, '',
        LPub);
  except
    FreeHsCtxSilent(Result);
    raise;
  end;
  { 0-RTT 早期数据本地准备：仅当 CH 已带 early_data 且调用方提供了 EarlyData 时派生 early 密钥。
    轻量一次性 HKDF，失败则静默回退 1-RTT（不中断握手，EarlyData 丢弃）。
    S9：若注入 ReplayStore 则先做指纹去重，命中则本地回退为 1-RTT（零重放）。 }
  Result^.SentEarlyData := LAllowEarly and AHasResume;
  if Result^.SentEarlyData and (Length(AOptions.EarlyData) > 0) then
  begin
    if TlsPasIsEarlyDataAllowed(AResumeSession, True, Length(AOptions.EarlyData)) then
    begin
      // S9 可选本地去重：避免同进程误重放相同 early_data
      if Assigned(AOptions.ReplayStore) then
      begin
        // 指纹计算与检查为 O(N) 小表，默认 nil 时零开销
        if TlsPasIsEarlyDataReplayed(AOptions.ReplayStore, AResumeSession.TicketIdentity, AOptions.EarlyData) then
        begin
          Result^.SentEarlyData := False;
          SetLength(Result^.EarlyData, 0);
        end
        else
        begin
          Result^.EarlyData := Copy(AOptions.EarlyData);
          if TlsPasTryDeriveEarlyDataSecrets(AResumeSession.CipherSuite,
            AResumeSession.ResumptionPSK, Result^.CHBody, Result^.EarlySecrets, LErr) then
          begin
            Result^.EarlySealer.Init(AResumeSession.CipherSuite,
              Result^.EarlySecrets.ClientEarlyKey, Result^.EarlySecrets.ClientEarlyIV);
            Result^.EarlySeq := 0;
          end
          else
          begin
            SecureZeroBytes(Result^.EarlyData);
            SetLength(Result^.EarlyData, 0);
          end;
        end;
      end
      else
      begin
        Result^.EarlyData := Copy(AOptions.EarlyData);
        if TlsPasTryDeriveEarlyDataSecrets(AResumeSession.CipherSuite,
          AResumeSession.ResumptionPSK, Result^.CHBody, Result^.EarlySecrets, LErr) then
        begin
          Result^.EarlySealer.Init(AResumeSession.CipherSuite,
            Result^.EarlySecrets.ClientEarlyKey, Result^.EarlySecrets.ClientEarlyIV);
          Result^.EarlySeq := 0;
        end
        else
        begin
          SecureZeroBytes(Result^.EarlyData);
          SetLength(Result^.EarlyData, 0);
        end;
      end;
    end
    else
    begin
      // 超限：不发 EarlyData，保留 CH early_data 扩展但无负载（服务端将拒绝）
      SetLength(Result^.EarlyData, 0);
    end;
  end;
  Result^.CH1Body := Copy(Result^.CHBody);
  if Length(Result^.CHBody) = 0 then
  begin
    FreeHsCtxSilent(Result);
    Result := nil;
  end;
end;

function AsyncTlsPasUpgrade(const ALoop: TAsyncLoop;
  const AStream: IAsyncTcpStream; const AOptions: TAsyncTlsPasClientOptions;
  ACallback: TAsyncTlsPasConnectCallback; AContext: Pointer): Boolean;
var
  LCtx: PTlsPasHsCtx;
  LDummySess: TTlsPasResumptionSession;
begin
  Result := False;
  if (AStream = nil) or not Assigned(ACallback) then
    Exit;

  FillChar(LDummySess, SizeOf(LDummySess), 0);
  { 升级路径无拨号端口语境：票据缓存仅经 Connect 路径启用 }
  LCtx := AllocHsCtx(ALoop, AOptions.ServerName, 0, AOptions,
    LDummySess, False, ACallback, AContext);
  if LCtx = nil then
    Exit;
  LCtx^.Stream := AStream;
  if not LCtx^.Deadline.IsInfinite then
    LCtx^.Timer := ALoop.Schedule(LCtx^.Deadline.Remaining, @TlsPasTimerCb,
      LCtx);
  TlsPasHsStep(LCtx);
  { 同步失败已在 TlsPasFail 回调；此后结果一律经回调交付 }
  Result := True;
end;

function AsyncTlsPasConnect(const ALoop: TAsyncLoop; const AHost: string;
  const APort: UInt16; const AOptions: TAsyncTlsPasClientOptions;
  ACallback: TAsyncTlsPasConnectCallback; AContext: Pointer): Boolean;
var
  LCtx: PTlsPasHsCtx;
  LOpts: TAsyncTcpDialOptions;
  LServerName: string;
  LSess: TTlsPasResumptionSession;
  LHasResume: Boolean;
begin
  Result := False;
  if (AHost = '') or not Assigned(ACallback) then
    Exit;
  if AOptions.ServerName <> '' then
    LServerName := AOptions.ServerName
  else
    LServerName := AHost;

  { 会话恢复尝试：缓存命中即带 PSK 出手；服务器拒绝时 SH 不含
    pre_shared_key，自然回退全握手 }
  LHasResume := False;
  FillChar(LSess, SizeOf(LSess), 0);
  if AOptions.Cache <> nil then
    LHasResume := AOptions.Cache.TryPeek(LServerName, APort, LSess);

  LCtx := AllocHsCtx(ALoop, LServerName, APort, AOptions, LSess,
    LHasResume, ACallback, AContext);
  if LCtx = nil then
    Exit;
  if not LCtx^.Deadline.IsInfinite then
    LCtx^.Timer := ALoop.Schedule(LCtx^.Deadline.Remaining, @TlsPasTimerCb,
      LCtx);

  LOpts := DefaultAsyncTcpDialOptions;
  LOpts.NoDelay := True;
  LOpts.OverallDeadline := AOptions.HandshakeDeadline;
  if not AsyncTcpDial(ALoop, AHost, APort, LOpts, @TlsPasDialDone, LCtx) then
    FreeHsCtxSilent(LCtx)
  else
    Result := True;
end;

{ ======== TTlsPasStream：数据相 ======== }

constructor TTlsPasStream.Create(ASuite: Word;
  const AApp: TTLS13ApplicationSecrets; const AInner: IAsyncTcpStream;
  ALoop: TAsyncLoop; const ANetInSeed, APostHsSeed: TBytes;
  ACache: TAsyncTlsPasSessionCache; const ACacheHost: string;
  ACachePort: UInt16; AWasResumed: Boolean; AWasHRR: Boolean = False;
  AWasEarlyDataAccepted: Boolean = False);
begin
  inherited Create;
  FSuite := ASuite;
  FApp := AApp;
  { 密钥材料必须深拷贝：TlsPasDone 创建本对象后立即经 FreeHsCtx 安全
    擦除握手上下文，record 赋值的 TBytes 引用与上下文共享底层缓冲，
    会被连带清零——NST 派生 PSK 将拿到全零 master secret }
  FApp.TranscriptHash := Copy(AApp.TranscriptHash);
  FApp.ResumptionTranscriptHash := Copy(AApp.ResumptionTranscriptHash);
  FApp.DerivedSecret := Copy(AApp.DerivedSecret);
  FApp.MasterSecret := Copy(AApp.MasterSecret);
  FApp.ClientApplicationTrafficSecret :=
    Copy(AApp.ClientApplicationTrafficSecret);
  FApp.ServerApplicationTrafficSecret :=
    Copy(AApp.ServerApplicationTrafficSecret);
  FApp.ClientApplicationKey := Copy(AApp.ClientApplicationKey);
  FApp.ServerApplicationKey := Copy(AApp.ServerApplicationKey);
  FApp.ClientApplicationIV := Copy(AApp.ClientApplicationIV);
  FApp.ServerApplicationIV := Copy(AApp.ServerApplicationIV);
  FCache := ACache;
  FCacheHost := ACacheHost;
  FCachePort := ACachePort;
  FWasResumed := AWasResumed;
  FWasHRR := AWasHRR;
  FWasEarlyDataAccepted := AWasEarlyDataAccepted;
  FInner := AInner;
  FLoop := ALoop;
  FNetIn := ANetInSeed;
  FPostHs := APostHsSeed;
  FNetInBuf := TByteStreamBuf.Create(DefaultAllocator, 4096);
  FPlainOutBuf := TByteStreamBuf.Create(DefaultAllocator, 4096);
  FNetTxBuf := TByteStreamBuf.Create(DefaultAllocator, 4096);
  if Length(ANetInSeed) > 0 then
    FNetInBuf.Append(@ANetInSeed[0], Length(ANetInSeed));
  FRecvChunk := cNetReadChunk;
  FOpener.Init(FSuite, FApp.ServerApplicationKey,
    FApp.ServerApplicationIV);
  FSealer.Init(FSuite, FApp.ClientApplicationKey,
    FApp.ClientApplicationIV);
end;

function TTlsPasStream.GetWasResumed: Boolean;
begin
  Result := FWasResumed;
end;

function TTlsPasStream.GetWasHRR: Boolean;
begin
  Result := FWasHRR;
end;

function TTlsPasStream.GetWasEarlyDataAccepted: Boolean;
begin
  Result := FWasEarlyDataAccepted;
end;

destructor TTlsPasStream.Destroy;
begin
  { quiet-shutdown：不阻塞等对端；密钥即刻清零 }
  FSealer.Clear;
  FOpener.Clear;
  ClearTLS13ApplicationSecrets(FApp);
  if Assigned(FNetInBuf) then FNetInBuf.Free;
  FNetInBuf := nil;
  if Assigned(FPlainOutBuf) then FPlainOutBuf.Free;
  FPlainOutBuf := nil;
  if Assigned(FNetTxBuf) then FNetTxBuf.Free;
  FNetTxBuf := nil;
  FInner := nil;
  FLoop := nil;
  inherited Destroy;
end;

{ ---- 后握手消息 ---- }

procedure TTlsPasStream.FeedPostHandshake(const AFragment: TBytes;
  out AFatal: Boolean);
var
  LMsg: TBytes;
  LMsgType: Byte;
  LErr: string;
  LTicket: TTLS13NewSessionTicket;
  LSess: TTlsPasResumptionSession;
begin
  AFatal := False;
  AppendBytesTo(FPostHs, AFragment);
  while TlsPasTryPopHandshake(FPostHs, LMsg) = 1 do
  begin
    LMsgType := LMsg[0];
    if LMsgType = TLS_HANDSHAKE_TYPE_NEW_SESSION_TICKET then
    begin
      { v2：捕获票据派生 PSK 入缓存。恢复材料绑定本会话 master
        secret（全握手才有意义）；含 max_early_data 的票据亦纳入
        缓存但仍走 1-RTT（0-RTT 数据面未启用，按 RFC 8446 §2.3
        回退语义安全）}
      if TryParseTLS13NewSessionTicket(LMsg, LTicket, LErr) and
         (FCache <> nil) and (LTicket.TicketLifetime > 0) and
         (Length(LTicket.Ticket) > 0) then
      begin
        FillChar(LSess, SizeOf(LSess), 0);
        LSess.CipherSuite := FSuite;
        LSess.TicketIdentity :=
          Copy(LTicket.Ticket, 0, Length(LTicket.Ticket));
        LSess.ResumptionPSK := TLS13DeriveResumptionPSKFromTranscriptHash(
          FSuite, FApp.MasterSecret, FApp.ResumptionTranscriptHash,
          LTicket.TicketNonce);
        LSess.TicketAgeAdd := LTicket.TicketAgeAdd;
        LSess.LifetimeSec := LTicket.TicketLifetime;
        LSess.IssuedMs := TlsPasMonoMs;
        LSess.HasMaxEarlyData := LTicket.HasMaxEarlyDataSize;
        LSess.MaxEarlyDataSize := LTicket.MaxEarlyDataSize;
        FCache.Store(FCacheHost, FCachePort, LSess);
      end;
      Continue;
    end;
    if LMsgType = TLS_HANDSHAKE_TYPE_KEY_UPDATE then
    begin
      if (Length(LMsg) >= 5) and (LMsg[4] = 1) then
      begin
        { update_requested：必须轮换本端写密钥（RFC 8446 §4.6.3） }
        if not TryUpdateTLS13ClientApplicationWriteKeys(FApp, LErr) then
        begin
          AFatal := True;
          Exit;
        end;
        FSealer.Init(FSuite, FApp.ClientApplicationKey,
          FApp.ClientApplicationIV);
      end;
      Continue;
    end;
    { 其余后握手消息类型 fail-closed }
    AFatal := True;
    Exit;
  end;
  if Length(FPostHs) > cMaxPostHsBuf then
    AFatal := True;
end;

function TTlsPasStream.HandleOpenedRecord(const APayload: TBytes): Integer;
var
  LFrag: TBytes;
  LInnerCt: Byte;
  LFatal: Boolean;
  LError: string;
begin
  Result := 0;
  if not FOpener.Open(APayload, LFrag, LInnerCt, LError) then
    Exit(-1);
  case LInnerCt of
    TLS_CONTENT_TYPE_APPLICATION_DATA:
      begin
        AppendBytesTo(FPlainOut, LFrag);
        Result := Length(LFrag);
      end;
    TLS_CONTENT_TYPE_HANDSHAKE:
      begin
        FeedPostHandshake(LFrag, LFatal);
        if LFatal then
          Exit(-1);
      end;
    TLS_CONTENT_TYPE_ALERT:
      begin
        { fatal → 致命；close_notify/warning → 读侧 EOF }
        if (Length(LFrag) >= 2) and (LFrag[0] = 2) then
          Exit(-1);
        FEofIn := True;
      end;
    TLS_CONTENT_TYPE_CHANGE_CIPHER_SPEC:
      ; { 兼容：忽略 }
  else
    Exit(-1);
  end;
end;

function TTlsPasStream.OpenAvailableRecords: Integer;
var
  LCt: Byte;
  LPayloadOff, LPayloadLen, LTotalLen: SizeUInt;
  LFrameRes: Integer;
  LFragLen: Integer;
  LInnerCt: Byte;
  LErr: string;
  LDest: PByte;
  LPayloadPtr: PByte;
  LFatal: Boolean;
  LFragBytes: TBytes;
begin
  Result := 0;
  while not FEofIn and not FDead do
  begin
    if FNetInBuf.Available > SizeUInt(cMaxNetInBuf) then
    begin
      FDead := True;
      Exit(-1);
    end;
    LFrameRes := TlsPasTryFrameRecordView(FNetInBuf.Data, FNetInBuf.Available,
      LCt, LPayloadOff, LPayloadLen, LTotalLen);
    if LFrameRes < 0 then
    begin
      FDead := True;
      Exit(-1);
    end;
    if LFrameRes = 0 then
      Exit;
    if LCt = TLS_CONTENT_TYPE_APPLICATION_DATA then
    begin
      // Payload位于 Data+Off 区间，零拷贝视图不分配
      LPayloadPtr := FNetInBuf.Data + LPayloadOff;
      // 预留明文目标区（最坏 payloadLen，实际 fragLen ≤ payloadLen）
      if LPayloadLen > 0 then
        LDest := FPlainOutBuf.ReserveAppend(LPayloadLen)
      else
        LDest := nil;
      if not FOpener.OpenToBuf(LPayloadPtr, Integer(LPayloadLen),
        LDest, Integer(LPayloadLen), LFragLen, LInnerCt, LErr) then
      begin
        FNetInBuf.Consume(LTotalLen);
        FDead := True;
        Exit(-1);
      end;
      FNetInBuf.Consume(LTotalLen);
      case LInnerCt of
        TLS_CONTENT_TYPE_APPLICATION_DATA:
          begin
            // 提交真实片段长度（丢弃零填充尾）
            if LFragLen > 0 then
              FPlainOutBuf.CommitAppend(SizeUInt(LFragLen))
            else
            begin
              // 零长度片段：仅预留未提交即回退（Reserve 未 commit 自动空洞回收）
              // 无需额外操作，下一 Reserve 会复用同一尾区
            end;
            Inc(Result, LFragLen);
            if Result >= cDecryptBatchBytes then
              Exit;
          end;
        TLS_CONTENT_TYPE_HANDSHAKE:
          begin
            // 握手内嵌（NewSessionTicket/KeyUpdate）：不入明文流，转后握手处理
            // Reserve 區已写入但不提交；拷贝片段走既有 TBytes 路径（罕见、低频）
            SetLength(LFragBytes, LFragLen);
            if LFragLen > 0 then
              Move(LDest^, LFragBytes[0], LFragLen);
            // 回退 Reserve（不 Commit，尾区自动复用）
            FeedPostHandshake(LFragBytes, LFatal);
            if LFatal then
            begin
              FDead := True;
              Exit(-1);
            end;
          end;
        TLS_CONTENT_TYPE_ALERT:
          begin
            SetLength(LFragBytes, LFragLen);
            if LFragLen > 0 then
              Move(LDest^, LFragBytes[0], LFragLen);
            if (Length(LFragBytes) >= 2) and (LFragBytes[0] = 2) then
            begin
              FDead := True;
              Exit(-1);
            end;
            FEofIn := True;
          end;
        TLS_CONTENT_TYPE_CHANGE_CIPHER_SPEC:
          ; // 忽略
      else
        begin
          FDead := True;
          Exit(-1);
        end;
      end;
    end
    else if LCt = TLS_CONTENT_TYPE_ALERT then
    begin
      FNetInBuf.Consume(LTotalLen);
      FDead := True;
      Exit(-1);
    end
    else
    begin
      // CCS 等明文记录：直接丢弃
      FNetInBuf.Consume(LTotalLen);
    end;
  end;
end;

{ ---- 挂起交付与泵 ---- }

procedure TTlsPasStream.DeliverRead(AResult: Int32);
var
  LCB: TIoCompletion;
  LCtx: Pointer;
  LBuf: Pointer;
begin
  LBuf := FReadBuf;
  LCB := FReadCb;
  LCtx := FReadCbCtx;
  FReadPending := False;
  FReadBuf := nil;
  FReadLen := 0;
  FReadCb := nil;
  FReadCbCtx := nil;
  FHasReadDeadlineReq := False;
  if Assigned(LCB) then
    LCB(UInt64(PtrUInt(LBuf)), AResult, LCtx);
end;

procedure TTlsPasStream.DeliverWrite(AResult: Int32);
var
  LCB: TIoCompletion;
  LCtx: Pointer;
begin
  LCB := FWriteCb;
  LCtx := FWriteCbCtx;
  FWritePending := False;
  FWriteTotal := 0;
  FWriteCb := nil;
  FWriteCbCtx := nil;
  if Assigned(LCB) then
    LCB(0, AResult, LCtx);
end;

procedure TTlsPasStream.Pump;
const
  { 单次泵内迭代上限：合法路径每迭代必有进展（明文递减/记录消耗/
    臂挂后返回等待回调）。若未来出现未知病态零进展交错，在此
    毫秒级掐断转干净失败——绝不无限自旋阻塞事件循环（自旋会连
    定时器回调一起饿死，看门狗失效）。合法大数据单次泵封顶
    ~400MB（10 万次 x 4KB 读块），绰绰有余。 }
  cMaxPumpIterations = 100000;
var
  LCopy: SizeUInt;
  LRes: Integer;
  LIters: Integer;
begin
  if FPumping then
    Exit;
  FPumping := True;
  try
    LIters := 0;
    while True do
    begin
      Inc(LIters);
      if LIters > cMaxPumpIterations then
      begin
        WriteLn(ErrOutput, '[tlspas] pump iteration cap exceeded: plain=',
          FPlainOutBuf.Available, ' netin=', FNetInBuf.Available, ' eof=', FEofIn,
          ' readpending=', FReadPending);
        FDead := True;
        if FReadPending then
          DeliverRead(ASYNC_TLSPAS_ERR_IO);
        if FWritePending then
          DeliverWrite(ASYNC_TLSPAS_ERR_IO);
        Exit;
      end;
      { 每迭代先冲已封密文：同步回调（读交付/写完成）内可能刚封装了新
        记录，而该回调里的重入 Pump 被本函数入口护栏拒绝——若只在泵
        入口冲一次，回调期间封装的密文将永远发不出去（实测 sing-box
        wss：WS 升级响应交付后 vless 命令帧滞留发送队列，双向静默
        死锁）。 }
      if not FDead then
        ArmNetSend;
      if FDead then
      begin
        if FReadPending then
          DeliverRead(ASYNC_TLSPAS_ERR_IO);
        Exit;
      end;
      if FPlainOutBuf.Available > 0 then
      begin
        if not FReadPending then
        begin
          Exit;
        end;
        LCopy := FReadLen;
        if LCopy > FPlainOutBuf.Available then
          LCopy := FPlainOutBuf.Available;
        Move(FPlainOutBuf.Data^, FReadBuf^, LCopy);
        FPlainOutBuf.Consume(LCopy);
        DeliverRead(Int32(LCopy));
        Continue;
      end;
      if FEofIn then
      begin
        if not FReadPending then
        begin
          Exit;
        end;
        DeliverRead(0);
        Continue;
      end;
      if FRecvArmed then
        Exit; { 臂挂接收未完成：FNetIn 尾部是未初始化暂存区，不可解析；
                新字节只会经回调收缩后进入，届时再泵 }
      LRes := OpenAvailableRecords;
      if LRes < 0 then
      begin
        if FReadPending then
          DeliverRead(ASYNC_TLSPAS_ERR_IO);
        Exit;
      end;
      if LRes > 0 then
        Continue;
      if not FRecvArmed then
      begin
        if not ArmNetRecv then
        begin
          if FReadPending then
            DeliverRead(ASYNC_TLSPAS_ERR_IO);
          Exit;
        end;
      end;
      Exit;
    end;
  finally
    FPumping := False;
  end;
end;

procedure StreamRecvCb(AUserData: UInt64; AResult: Int32;
  AContext: Pointer);
var
  LSelf: TTlsPasStream;
begin
  LSelf := TTlsPasStream(AContext);
  if LSelf = nil then
    Exit;
  LSelf.FRecvArmed := False;
  if AResult < 0 then
  begin
    { 底层负码透传（含取消/超时域语义） }
    LSelf.FDead := True;
    if LSelf.FReadPending then
      LSelf.DeliverRead(AResult);
    if LSelf.FWritePending then
      LSelf.DeliverWrite(ASYNC_TLSPAS_ERR_IO);
    Exit;
  end;
  if AResult = 0 then
  begin
    { 对端 TCP EOF：半关闭，读侧置 EOF；存量整记录仍可在 Pump 中消化 }
    // 零拷贝：FNetInBuf 上次 Reserve 的尾区未提交，保持原状（AResult=0 不 commit）
    LSelf.FEofIn := True;
  end
  else
  begin
    LSelf.FNetInBuf.CommitAppend(SizeUInt(AResult));
    { 读块自时钟：满读翻倍至多记录粒度（对端突发被单次 read 吞下），
      不足半读说明内核暂无余量，回缩下限；其间保持不变防抖动 }
    if (AResult >= LSelf.FRecvChunk) and
       (LSelf.FRecvChunk < cNetReadChunkMax) then
    begin
      LSelf.FRecvChunk := LSelf.FRecvChunk * 2;
      if LSelf.FRecvChunk > cNetReadChunkMax then
        LSelf.FRecvChunk := cNetReadChunkMax;
    end
    else if AResult * 2 < LSelf.FRecvChunk then
      LSelf.FRecvChunk := cNetReadChunk;
  end;
  LSelf.Pump;
end;

procedure StreamSendCb(AUserData: UInt64; AResult: Int32;
  AContext: Pointer);
var
  LSelf: TTlsPasStream;
begin
  LSelf := TTlsPasStream(AContext);
  if LSelf = nil then
    Exit;
  LSelf.FSendArmed := False;
  if AResult <= 0 then
  begin
    LSelf.FDead := True;
    if LSelf.FWritePending then
      LSelf.DeliverWrite(ASYNC_TLSPAS_ERR_IO);
    Exit;
  end;
  LSelf.FNetTxBuf.Consume(SizeUInt(AResult));
  LSelf.CompactTxIfDrained;
  if (LSelf.FNetTxBuf.Available = 0) and
     LSelf.FWritePending then
    LSelf.DeliverWrite(Int32(LSelf.FWriteTotal))
  else
    LSelf.Pump;
end;

function TTlsPasStream.ArmNetRecv: Boolean;
var
  LRx: PByte;
begin
  Result := False;
  if FRecvArmed or FDead then
    Exit;
  LRx := FNetInBuf.ReserveAppend(SizeUInt(FRecvChunk));
  FRecvArmed := True;
  { 读挂起带期限时走底层超时形态（到期由底层交付其域内负码） }
  if FHasReadDeadlineReq then
  begin
    if FInner.AsyncReadTimeout(LRx, FRecvChunk, FReadDeadlineReq,
      @StreamRecvCb, Self) then
      Exit(True);
  end
  else if FInner.AsyncRead(LRx, FRecvChunk, @StreamRecvCb, Self) then
    Exit(True);
  FRecvArmed := False;
  // Reserve 未提交，不移动 FLen，尾区自动复用，无需回缩 SetLength
end;

function TTlsPasStream.ArmNetSend: Boolean;
begin
  Result := False;
  if FSendArmed or FDead then
    Exit;
  if FNetTxBuf.Available = 0 then
    Exit(True);
  FSendArmed := True;
  if FInner.AsyncWrite(FNetTxBuf.Data, UInt32(FNetTxBuf.Available), @StreamSendCb,
    Self) then
    Exit(True);
  FSendArmed := False;
end;

{ ---- 明文封队（写方向） ---- }

procedure TTlsPasStream.SealPlainToQueue(const APlain: TBytes);
var
  LOffset, LTake, LRecLen, LNeed: Integer;
  LErr: string;
  LDest: PByte;
begin
  LOffset := 0;
  while LOffset < Length(APlain) do
  begin
    LTake := Length(APlain) - LOffset;
    if LTake > cMaxAppFragment then
      LTake := cMaxAppFragment;
    // 5B header + (LTake+1) inner +16 tag
    LNeed := 5 + (LTake + 1) + 16;
    LDest := FNetTxBuf.ReserveAppend(SizeUInt(LNeed));
    if not FSealer.SealToBuf(@APlain[LOffset], LTake, TLS_CONTENT_TYPE_APPLICATION_DATA,
      LDest, LNeed, LRecLen, LErr) then
      raise EInvalidOperationError.Create('tlspas: seal app data: ' + LErr);
    FNetTxBuf.CommitAppend(SizeUInt(LRecLen));
    Inc(LOffset, LTake);
  end;
end;

procedure TTlsPasStream.SealPlainToQueueBuf(AData: PByte; ALen: SizeUInt);
var
  LOffset, LTake, LRecLen, LNeed: Integer;
  LErr: string;
  LDest: PByte;
begin
  LOffset := 0;
  while SizeUInt(LOffset) < ALen do
  begin
    LTake := Integer(ALen) - LOffset;
    if LTake > cMaxAppFragment then
      LTake := cMaxAppFragment;
    LNeed := 5 + (LTake + 1) + 16;
    LDest := FNetTxBuf.ReserveAppend(SizeUInt(LNeed));
    if not FSealer.SealToBuf(AData + LOffset, LTake, TLS_CONTENT_TYPE_APPLICATION_DATA,
      LDest, LNeed, LRecLen, LErr) then
      raise EInvalidOperationError.Create('tlspas: seal app data: ' + LErr);
    FNetTxBuf.CommitAppend(SizeUInt(LRecLen));
    Inc(LOffset, LTake);
  end;
end;

procedure TTlsPasStream.CompactTxIfDrained;
begin
  if (FNetTxBuf.Available = 0) and not FWritePending then
    FNetTxBuf.Clear;
end;

{ ---- IReader/IWriter（同步便捷面） ---- }

function TTlsPasStream.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
begin
  if TryRead(ABuf, ACount, Result) <> tsiorOk then
    Result := 0;
end;

function TTlsPasStream.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  { 同步面不支持记录化写入（异步栈契约）：请走 AsyncWrite }
  Result := 0;
end;

{ ---- IReadWriteCloser ---- }

procedure TTlsPasStream.Close;
var
  LAlert: TBytes;
  LRecord: TBytes;
  LErr: string;
  LDest: PByte;
  LRecLen: Integer;
  LAlertBytes: array[0..1] of Byte;
begin
  if not FCloseNotifySent and not FDead then
  begin
    FCloseNotifySent := True;
    LAlertBytes[0] := 1; LAlertBytes[1] := 0; { warning + close_notify }
    LDest := FNetTxBuf.ReserveAppend(5 + 3 + 16);
    if FSealer.SealToBuf(@LAlertBytes[0], 2, TLS_CONTENT_TYPE_ALERT, LDest, 5 + 3 + 16, LRecLen, LErr) then
    begin
      FNetTxBuf.CommitAppend(SizeUInt(LRecLen));
      ArmNetSend; { 尽力冲刷；不等对端 }
    end;
  end;
  FDead := True;
  if FInner <> nil then
  begin
    FInner.Close;
    FInner := nil;
  end;
  if FReadPending then
    DeliverRead(ASYNC_TLSPAS_ERR_IO);
  if FWritePending then
    DeliverWrite(ASYNC_TLSPAS_ERR_IO);
end;

{ ---- ITcpStream 委托底层流 ---- }

function TTlsPasStream.LocalAddr: TNetAddress;
begin
  if FInner <> nil then
    Result := FInner.LocalAddr
  else
    FillChar(Result, SizeOf(Result), 0);
end;

function TTlsPasStream.RemoteAddr: TNetAddress;
begin
  if FInner <> nil then
    Result := FInner.RemoteAddr
  else
    FillChar(Result, SizeOf(Result), 0);
end;

procedure TTlsPasStream.Shutdown;
begin
  if FInner <> nil then
    FInner.Shutdown;
end;

procedure TTlsPasStream.SetNoDelay(const AValue: Boolean);
begin
  if FInner <> nil then
    FInner.SetNoDelay(AValue);
end;

procedure TTlsPasStream.SetKeepAlive(const AValue: Boolean);
begin
  if FInner <> nil then
    FInner.SetKeepAlive(AValue);
end;

procedure TTlsPasStream.SetReadDeadline(const ADeadline: TDeadline);
begin
  if FInner <> nil then
    FInner.SetReadDeadline(ADeadline);
end;

procedure TTlsPasStream.SetWriteDeadline(const ADeadline: TDeadline);
begin
  if FInner <> nil then
    FInner.SetWriteDeadline(ADeadline);
end;

procedure TTlsPasStream.SetCancelToken(const AToken: INetCancelToken);
begin
  if FInner <> nil then
    FInner.SetCancelToken(AToken);
end;

procedure TTlsPasStream.BindCancelToken(
  const AToken: IAsyncCancellationToken);
begin
  if FInner <> nil then
    FInner.BindCancelToken(AToken);
end;

{ ---- ITcpSocketRuntime ---- }

function TTlsPasStream.NativeSocketHandle: PtrUInt;
begin
  Result := 0;
  if FInner <> nil then
    Result := (FInner as ITcpSocketRuntime).NativeSocketHandle;
end;

procedure TTlsPasStream.SetBlocking(const ABlocking: Boolean);
begin
  if FInner <> nil then
    (FInner as ITcpSocketRuntime).SetBlocking(ABlocking);
end;

{ ---- ITcpStreamRuntime ---- }

function TTlsPasStream.TryRead(var ABuf; const ACount: SizeUInt;
  out ARead: SizeUInt): TTcpStreamIOResult;
var
  LN: SizeUInt;
begin
  ARead := 0;
  if FDead then
    Exit(tsiorClosed);
  if FPlainOutBuf.Available = 0 then
  begin
    if OpenAvailableRecords < 0 then
      Exit(tsiorClosed);
  end;
  if FPlainOutBuf.Available > 0 then
  begin
    LN := ACount;
    if LN > FPlainOutBuf.Available then
      LN := FPlainOutBuf.Available;
    Move(FPlainOutBuf.Data^, ABuf, LN);
    FPlainOutBuf.Consume(LN);
    ARead := LN;
    Exit(tsiorOk);
  end;
  if FEofIn then
    Exit(tsiorClosed);
  Exit(tsiorWouldBlock);
end;

function TTlsPasStream.TryWrite(const ABuf; const ACount: SizeUInt;
  out AWritten: SizeUInt): TTcpStreamIOResult;
begin
  AWritten := 0;
  if FDead then
    Exit(tsiorClosed);
  if ACount = 0 then
    Exit(tsiorOk);
  { 有未冲尽残留时不再追加（避免跨调用字节序歧义）：先冲完再来 }
  if FNetTxBuf.Available > 0 then
    Exit(tsiorWouldBlock);
  try
    SealPlainToQueueBuf(PByte(@ABuf), ACount);
  except
    FDead := True;
    Exit(tsiorClosed);
  end;
  ArmNetSend;
  if FNetTxBuf.Available > 0 then
    Exit(tsiorWouldBlock);
  CompactTxIfDrained;
  AWritten := ACount;
  Exit(tsiorOk);
end;

{ ---- IAsyncTcpStream ---- }

function TTlsPasStream.AsyncRead(ABuf: Pointer; ALen: UInt32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  Result := False;
  if (ABuf = nil) or (ALen = 0) or not Assigned(ACallback) then
    Exit;
  if FReadPending then
    Exit; { 单挂起契约：重复提交是调用方 bug }
  if FDead then
  begin
    ACallback(UInt64(PtrUInt(ABuf)), ASYNC_TLSPAS_ERR_IO, AContext);
    Exit(True);
  end;
  FReadBuf := ABuf;
  FReadLen := ALen;
  FReadCb := ACallback;
  FReadCbCtx := AContext;
  FReadPending := True;
  FHasReadDeadlineReq := False;
  Pump;
  Result := True;
end;

function TTlsPasStream.AsyncReadRef(ABuf: Pointer; ALen: UInt32;
  ACallback: TIoCompletionRef; AContext: Pointer): Boolean;
var
  LWrap: Pointer;
begin
  LWrap := WrapIoCompletionRef(ACallback, AContext);
  Result := AsyncRead(ABuf, ALen, @IoCompletionRefWrapper, LWrap);
  if not Result then
    Dispose(PIoCompletionRefCtx(LWrap));
end;

function TTlsPasStream.AsyncWrite(ABuf: Pointer; ALen: UInt32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  Result := False;
  if (ABuf = nil) or (ALen = 0) or not Assigned(ACallback) then
    Exit;
  if FWritePending then
    Exit; { 单挂起契约 }
  if FDead then
  begin
    ACallback(UInt64(PtrUInt(ABuf)), ASYNC_TLSPAS_ERR_IO, AContext);
    Exit(True);
  end;
  { 整段先封队（dataplane 缓冲有界，瞬态 ~1.06× 可接受）；
    冲刷完成后一次回调总长。缓冲所有权：调用方持有至回调，
    本层立即拷贝成记录队列，不引用调用方内存跨重试。 }
  if FNetTxBuf.Available > 0 then
  begin
    { 前序写未冲尽（close_notify 残留等）：拒绝重复提交 }
    Exit;
  end;
  try
    SealPlainToQueueBuf(PByte(ABuf), ALen);
  except
    FDead := True;
    ACallback(UInt64(PtrUInt(ABuf)), ASYNC_TLSPAS_ERR_IO, AContext);
    Exit(True);
  end;
  FWriteTotal := Integer(ALen);
  FWriteCb := ACallback;
  FWriteCbCtx := AContext;
  FWritePending := True;
  Pump;
  Result := True;
end;

function TTlsPasStream.AsyncWriteRef(ABuf: Pointer; ALen: UInt32;
  ACallback: TIoCompletionRef; AContext: Pointer): Boolean;
var
  LWrap: Pointer;
begin
  LWrap := WrapIoCompletionRef(ACallback, AContext);
  Result := AsyncWrite(ABuf, ALen, @IoCompletionRefWrapper, LWrap);
  if not Result then
    Dispose(PIoCompletionRefCtx(LWrap));
end;

function TTlsPasStream.AsyncReadTimeout(ABuf: Pointer; ALen: UInt32;
  const ADeadline: TDeadline; ACallback: TIoCompletion;
  AContext: Pointer): Boolean;
begin
  Result := False;
  if (ABuf = nil) or (ALen = 0) or not Assigned(ACallback) then
    Exit;
  if FReadPending then
    Exit;
  if FDead then
  begin
    ACallback(UInt64(PtrUInt(ABuf)), ASYNC_TLSPAS_ERR_IO, AContext);
    Exit(True);
  end;
  FReadBuf := ABuf;
  FReadLen := ALen;
  FReadCb := ACallback;
  FReadCbCtx := AContext;
  FReadPending := True;
  { 先吃存量；不足则带期限挂底层读（到期由底层交付其域内负码） }
  FHasReadDeadlineReq := True;
  FReadDeadlineReq := ADeadline;
  Pump;
  if FReadPending and (FPlainOutBuf.Available = 0) and not FEofIn and
     not FDead and not FRecvArmed then
    DeliverRead(ASYNC_TLSPAS_ERR_IO); { 臂挂失败 }
  Result := True;
end;

function TTlsPasStream.AsyncWriteTimeout(ABuf: Pointer; ALen: UInt32;
  const ADeadline: TDeadline; ACallback: TIoCompletion;
  AContext: Pointer): Boolean;
begin
  { 与 net.async.tls 一致：接受但不在冲刷中途强断（握手期才全强制） }
  Result := AsyncWrite(ABuf, ALen, ACallback, AContext);
end;

function DefaultAsyncTlsFpClientOptions: TAsyncTlsPasClientOptions;
begin
  Result := DefaultAsyncTlsPasClientOptions;
end;

function AsyncTlsFpUpgrade(const ALoop: TAsyncLoop; const AStream: IAsyncTcpStream;
  const AOptions: TAsyncTlsPasClientOptions; ACallback: TAsyncTlsPasConnectCallback;
  AContext: Pointer): Boolean;
begin
  Result := AsyncTlsPasUpgrade(ALoop, AStream, AOptions, ACallback, AContext);
end;

function AsyncTlsFpConnect(const ALoop: TAsyncLoop; const AHost: string;
  const APort: UInt16; const AOptions: TAsyncTlsPasClientOptions;
  ACallback: TAsyncTlsPasConnectCallback; AContext: Pointer): Boolean;
begin
  Result := AsyncTlsPasConnect(ALoop, AHost, APort, AOptions, ACallback, AContext);
end;

initialization
  GMonoClock.Start;

end.
