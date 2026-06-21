{
  nextpas.core.tls.base - SSL/TLS 基础定义（类型+接口）
  
  版本: 2.0
  作者: fafafa.ssl 开发团队
  创建: 2025-11-05
  
  描述:
    定义 fafafa.ssl 库的所有基础类型、常量、枚举、异常类和接口。
    按照 fafafa.模块名.base.pas 命名规范，此文件包含：
    - 所有类型定义（从 abstract.types 迁移）
    - 所有接口定义（从 abstract.intf 迁移）
    
    这些定义完全独立于任何特定的 SSL/TLS 后端实现（OpenSSL, WinSSL 等）。
    所有后端实现必须使用这些类型和接口以保证 API 的一致性。
    
  架构位置:
    抽象层 - 不依赖于任何具体后端实现
}

unit nextpas.core.tls.base;

{$mode ObjFPC}{$H+}
{$modeswitch advancedrecords}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

interface

uses
  nextpas.core.base, nextpas.core.system.classes;

type
  // ============================================================================
  // 基础类型定义
  // ============================================================================

  { 通用过程类型 }
  TSSLProc = procedure of object;
  TSSLProcString = procedure(const AValue: string) of object;

  { Result 类型回调函数类型 - 使用 of object 以支持嵌套函数 }
  TProcedureOfConstTBytes = procedure(const AData: TBytes) of object;
  TProcedureOfConstString = procedure(const AValue: string) of object;
  TPredicateTBytes = function(const AData: TBytes): Boolean of object;
  TPredicateString = function(const AValue: string): Boolean of object;

  { TBytesView - 零拷贝字节视图 (Phase 2.3.2)

    类似 Rust 的 &[u8] 借用语义，提供对现有 TBytes 的只读视图，
    避免不必要的内存拷贝。适用于：
    - 加密操作的输入参数（零拷贝读取）
    - 哈希计算（避免输入拷贝）
    - 大数据处理（减少内存分配）

    注意：TBytesView 不拥有数据，只是引用。调用者必须确保
    源数据在视图使用期间保持有效。
  }
  TBytesView = record
    Data: PByte;      // 指向数据的指针
    Length: Integer;  // 数据长度（字节数）

    { 从 TBytes 创建视图（零拷贝）
      注意：使用 var 参数避免复制，确保指针指向调用者的数据 }
    class function FromBytes(var ABytes: TBytes): TBytesView; static;

    { 从指针和长度创建视图 }
    class function FromPtr(AData: PByte; ALength: Integer): TBytesView; static;

    { 创建空视图 }
    class function Empty: TBytesView; static;

    { 转换为 TBytes（需要拷贝） }
    function AsBytes: TBytes;

    { 创建子视图（切片） }
    function Slice(AStart, ALength: Integer): TBytesView;

    { 检查视图是否为空 }
    function IsEmpty: Boolean;

    { 检查视图是否有效（指针非空） }
    function IsValid: Boolean;

    { 获取指定索引的字节（带边界检查，Rust-quality 安全访问） }
    function GetByte(AIndex: Integer): Byte;

    { 获取指定索引的字节（无边界检查，性能关键代码使用） }
    function GetByteUnchecked(AIndex: Integer): Byte; inline;
  end;

  // ============================================================================
  // 枚举类型定义
  // ============================================================================
  
  { SSL/TLS 库后端类型 }
  TSSLLibraryType = (
    sslAutoDetect,   // 自动检测可用库
    sslOpenSSL,      // OpenSSL
    sslWolfSSL,      // WolfSSL
    sslMbedTLS,      // MbedTLS
    sslWinSSL,       // Windows Schannel (仅Windows)
    sslFreePascal    // 纯 FreePascal 实现
  );
  TSSLLibraryTypes = set of TSSLLibraryType;

  { 后端实现类型 (v1.2 新增) }
  TSSLBackendImplType = (
    sslImplNative,      // 纯 FreePascal 实现（无外部依赖）
    sslImplCLibrary,    // C 语言库绑定（OpenSSL, MbedTLS 等）
    sslImplOSNative,    // 操作系统原生 API（WinSSL, SecureTransport 等）
    sslImplHybrid       // 混合实现（部分纯 Pascal + 部分 C 库）
  );

  { 功能支持级别 (v1.2 新增) }
  TSSLFeatureSupportLevel = (
    sslSupportNone,        // 不支持
    sslSupportExperimental,// 实验性（不推荐生产）
    sslSupportStable,      // 稳定（推荐生产）
    sslSupportDeprecated   // 已弃用（计划移除）
  );

  { SSL/TLS 协议版本 }
  TSSLProtocolVersion = (
    sslProtocolUnknown,   // 未知/未指定协议版本
    sslProtocolSSL2,      // SSL 2.0 (已废弃，不推荐)
    sslProtocolSSL3,      // SSL 3.0 (已废弃，不推荐)
    sslProtocolTLS10,     // TLS 1.0
    sslProtocolTLS11,     // TLS 1.1
    sslProtocolTLS12,     // TLS 1.2
    sslProtocolTLS13,     // TLS 1.3
    sslProtocolDTLS10,    // DTLS 1.0 (基于TLS 1.1)
    sslProtocolDTLS12     // DTLS 1.2 (基于TLS 1.2)
  );
  TSSLProtocolVersions = set of TSSLProtocolVersion;

  { SSL 特性枚举（Phase 1.3 - 消除字符串类型状态）

    类型安全的SSL特性标识符，替代stringly-typed模式。
    符合Rust质量标准 - 编译时类型检查，避免拼写错误。
  }
  TSSLFeature = (
    sslFeatSNI,                    // Server Name Indication (服务器名称指示)
    sslFeatALPN,                   // Application-Layer Protocol Negotiation (应用层协议协商)
    sslFeatSessionCache,           // Session Cache (会话缓存)
    sslFeatSessionTickets,         // Session Tickets (会话票据)
    sslFeatRenegotiation,          // Renegotiation (重新协商)
    sslFeatOCSPStapling,          // OCSP Stapling (OCSP装订)
    sslFeatCertificateTransparency // Certificate Transparency (证书透明度)
  );
  TSSLFeatures = set of TSSLFeature;

  { 证书验证模式 }
  TSSLVerifyMode = (
    sslVerifyNone,            // 不验证证书
    sslVerifyPeer,            // 验证对端证书
    sslVerifyFailIfNoPeerCert,// 如果没有对端证书则失败
    sslVerifyClientOnce,      // 仅在初次握手时验证客户端（服务端选项）
    sslVerifyPostHandshake    // 握手后验证（TLS 1.3）
  );
  TSSLVerifyModes = set of TSSLVerifyMode;

  { SSL 上下文类型 }
  TSSLContextType = (
    sslCtxClient,         // 客户端上下文
    sslCtxServer,         // 服务端上下文
    sslCtxBoth            // 同时支持客户端和服务端
  );

  { SSL 选项 }
  TSSLOption = (
    ssoEnableSNI,           // 启用 SNI（服务器名称指示）
    ssoEnableALPN,          // 启用 ALPN（应用层协议协商）
    ssoEnableSessionCache,  // 启用会话缓存
    ssoEnableSessionTickets,// 启用会话票据
    ssoDisableCompression,  // 禁用压缩
    ssoDisableRenegotiation,// 禁用重新协商
    ssoEnableOCSPStapling,  // 启用 OCSP 装订
    ssoSingleDHUse,         // 单次使用 DH 参数
    ssoSingleECDHUse,       // 单次使用 ECDH 参数
    ssoCipherServerPreference,// 服务器密码套件优先
    ssoNoSSLv2,             // 禁用 SSLv2
    ssoNoSSLv3,             // 禁用 SSLv3
    ssoNoTLSv1,             // 禁用 TLSv1.0
    ssoNoTLSv1_1,           // 禁用 TLSv1.1
    ssoNoTLSv1_2,           // 禁用 TLSv1.2
    ssoNoTLSv1_3,             // 禁用 TLSv1.3
    ssoRequireOCSPStapling,   // 强制要求 OCSP 装订
    ssoEnableCertVerifyCache, // 启用证书验证缓存（默认关闭）
    ssoRequireCertificateTransparency // 强制要求 Certificate Transparency（追加到末尾以保持历史序号兼容）
  );
  TSSLOptions = set of TSSLOption;

  { 证书验证标志 }
  TSSLCertVerifyFlag = (
    sslCertVerifyDefault,         // 默认验证
    sslCertVerifyCheckRevocation, // 检查吊销状态（CRL）
    sslCertVerifyCheckOCSP,       // 使用 OCSP 检查吊销
    sslCertVerifyIgnoreExpiry,    // 忽略过期
    sslCertVerifyIgnoreHostname,  // 忽略主机名验证
    sslCertVerifyAllowSelfSigned, // 允许自签名证书
    sslCertVerifyStrictChain,     // 严格证书链验证
    sslCertVerifyCheckCRL         // 检查 CRL 列表
  );
  TSSLCertVerifyFlags = set of TSSLCertVerifyFlag;

  { SSL 握手状态 }
  TSSLHandshakeState = (
    sslHsNotStarted,      // 未开始
    sslHsInProgress,      // 进行中
    sslHsCompleted,       // 已完成
    sslHsFailed,          // 失败
    sslHsRenegotiating    // 重新协商中
  );

  { TLS 1.3 Early Data / 0-RTT 状态 }
  TSSLEarlyDataStatus = (
    sslEarlyDataNone,      // 未启用 / 未排队
    sslEarlyDataQueued,    // 客户端已排队 early data
    sslEarlyDataAccepted,  // 对端接受 early data
    sslEarlyDataRejected   // 对端拒绝 early data
  );

  { TLS 1.3 Early Data 服务端策略 }
  TSSLEarlyDataServerPolicy = (
    sslEarlyDataServerReject,  // 默认拒绝
    sslEarlyDataServerAccept,  // 实验性接受
    sslEarlyDataServerIssueOnly // 仅签发支持 early-data 的 ticket，但不接受 resumed early data
  );

  { SSL 错误代码 }
  TSSLErrorCode = (
    sslErrNone,              // 无错误
    sslErrGeneral,           // 一般错误
    sslErrMemory,            // 内存分配错误
    sslErrInvalidParam,      // 无效参数
    sslErrNotInitialized,    // 未初始化
    sslErrProtocol,          // 协议错误
    sslErrHandshake,         // 握手错误
    sslErrCertificate,       // 证书错误
    sslErrCertificateExpired,// 证书过期
    sslErrCertificateRevoked,// 证书被撤销
    sslErrCertificateUnknown,// 未知证书
    sslErrCertificateUntrusted, // 证书不受信任
    sslErrHostnameMismatch,  // 主机名不匹配
    sslErrConnection,        // 连接错误
    sslErrTimeout,           // 超时
    sslErrIO,                // I/O错误
    sslErrWouldBlock,        // 非阻塞操作会阻塞
    sslErrWantRead,          // SSL需要读取
    sslErrWantWrite,         // SSL需要写入
    sslErrUnsupported,       // 不支持的功能
    sslErrLibraryNotFound,   // 库文件未找到
    sslErrFunctionNotFound,  // 函数未找到
    sslErrVersionMismatch,   // 版本不匹配
    sslErrConfiguration,     // 配置错误
    // 新增错误码 - Phase 4
    sslErrInvalidData,       // 数据格式错误
    sslErrDecryptionFailed,  // 解密失败
    sslErrEncryptionFailed,  // 加密失败
    sslErrParseFailed,       // 解析失败
    sslErrLoadFailed,        // 加载失败
    sslErrVerificationFailed,// 验证失败
    sslErrKeyDerivationFailed,// 密钥派生失败
    sslErrInvalidFormat,     // 格式无效
    sslErrBufferTooSmall,    // 缓冲区太小
    sslErrResourceExhausted, // 资源耗尽
    sslErrOther              // 其他错误
  );

  { SSL 日志级别 }
  TSSLLogLevel = (
    sslLogNone,      // 不记录日志
    sslLogError,     // 仅错误
    sslLogWarning,   // 警告和错误
    sslLogInfo,      // 信息、警告和错误
    sslLogDebug,     // 调试信息
    sslLogTrace      // 详细跟踪
  );

  { 密钥交换算法 }
  TSSLKeyExchange = (
    sslKexRSA,
    sslKexDHE_RSA,
    sslKexECDHE_RSA,
    sslKexDHE_DSS,
    sslKexECDHE_ECDSA,
    sslKexPSK,
    sslKexDHE_PSK,
    sslKexRSA_PSK
  );
  TSSLKeyExchangeSupport = set of TSSLKeyExchange;  // v1.2: 算法支持集合

  { 加密算法 }
  TSSLCipher = (
    sslCipherNone,
    sslCipherAES128,
    sslCipherAES256,
    sslCipherAES128GCM,
    sslCipherAES256GCM,
    sslCipherCHACHA20_POLY1305,
    sslCipher3DES,
    sslCipherDES,
    sslCipherRC4
  );
  TSSLCipherSupport = set of TSSLCipher;  // v1.2: 算法支持集合

  { 哈希算法 }
  TSSLHash = (
    sslHashMD5,
    sslHashSHA1,
    sslHashSHA224,
    sslHashSHA256,
    sslHashSHA384,
    sslHashSHA512,
    sslHashSHA3_256,
    sslHashSHA3_512,
    sslHashBLAKE2b
  );
  TSSLHashSupport = set of TSSLHash;  // v1.2: 算法支持集合

  { 通用字符串数组，用于只读字段传递 }
  TSSLStringArray = array of string;

  // ============================================================================
  // 记录类型定义
  // ============================================================================

  { 证书验证结果 }
  TSSLCertVerifyResult = record
    Success: Boolean;               // 验证是否成功
    ErrorCode: Cardinal;            // 错误代码（平台相关）
    ErrorMessage: string;           // 友好的错误消息
    ChainStatus: Cardinal;          // 证书链状态
    RevocationStatus: Cardinal;     // 吊销状态
    DetailedInfo: string;           // 详细信息（可选）
  end;

  { SSL 证书信息 }
  TSSLCertificateInfo = record
    Subject: string;              // 证书主题
    Issuer: string;               // 证书颁发者
    SerialNumber: string;         // 序列号
    NotBefore: TDateTime;         // 有效期开始
    NotAfter: TDateTime;          // 有效期结束
    FingerprintSHA1: string;      // SHA1指纹
    FingerprintSHA256: string;    // SHA256指纹
    PublicKeyAlgorithm: string;   // 公钥算法
    PublicKeySize: Integer;       // 公钥长度（位）
    SignatureAlgorithm: string;   // 签名算法
    Version: Integer;             // 证书版本
    SubjectAltNames: TSSLStringArray; // 主题备用名称（只读快照）
    IsCA: Boolean;                // 是否为CA证书
    PathLength: Integer;          // 证书路径长度限制
    PathLenConstraint: Integer;   // 路径长度约束 (-1表示无限制)
    KeyUsage: Word;               // 密钥用途位字段
  end;
  PSSLCertificateInfo = ^TSSLCertificateInfo;

  { SSL 连接信息 }
  TSSLConnectionInfo = record
    ProtocolVersion: TSSLProtocolVersion;  // 协议版本
    CipherSuite: string;                   // 密码套件名称
    CipherSuiteId: Word;                   // 密码套件ID
    KeyExchange: TSSLKeyExchange;          // 密钥交换算法
    Cipher: TSSLCipher;                    // 加密算法
    Hash: TSSLHash;                        // 哈希算法
    KeySize: Integer;                      // 密钥长度（位）
    MacSize: Integer;                      // 认证/MAC/tag 长度（字节，best-effort）
    IsResumed: Boolean;                    // 是否为恢复的会话
    SessionId: string;                     // 会话ID
    CompressionMethod: string;             // 压缩方法
    ServerName: string;                    // SNI服务器名称
    ALPNProtocol: string;                  // ALPN协商的协议
    PeerCertificate: TSSLCertificateInfo;  // 对端证书信息
  end;
  PSSLConnectionInfo = ^TSSLConnectionInfo;

  { 日志回调类型 }
  TSSLLogCallback = procedure(ALevel: TSSLLogLevel; const AMessage: string) of object;

  { 显式的 library-scoped defaults helper surface }
  TSSLLibraryDefaults = record
    LogLevel: TSSLLogLevel;
    LogCallback: TSSLLogCallback;
  end;

  { Context-safe configuration surface.
    This is the first additive slice of the TSSLConfig scope-surgery path:
    only build-stage context fields live here. }
  TSSLContextConfig = record
    LibraryType: TSSLLibraryType;
    ContextType: TSSLContextType;
    ProtocolVersions: TSSLProtocolVersions;
    PreferredVersion: TSSLProtocolVersion;
    CertificateFile: string;
    PrivateKeyFile: string;
    PrivateKeyPassword: string;
    CAFile: string;
    CAPath: string;
    UseSystemRoots: Boolean;
    VerifyMode: TSSLVerifyModes;
    VerifyDepth: Integer;
    CipherList: string;
    CipherSuites: string;
    Options: TSSLOptions;
    SessionCacheSize: Integer;
    SessionTimeout: Integer;
    ALPNProtocols: string;
    ClientEarlyDataEnabled: Boolean;
    ServerEarlyDataPolicy: TSSLEarlyDataServerPolicy;
    ServerMaxEarlyDataSize: Cardinal;
    ServerEarlyDataReplayStoreFile: string;
    ServerEarlyDataReplayStoreDirectory: string;
  end;

  { SSL 配置 }
  TSSLConfig = record
    // 基本配置
    LibraryType: TSSLLibraryType;            // 使用的库类型
    ContextType: TSSLContextType;            // 上下文类型
    
    // 协议配置
    ProtocolVersions: TSSLProtocolVersions;  // 允许的协议版本
    PreferredVersion: TSSLProtocolVersion;   // 首选协议版本
    
    // 证书配置
    CertificateFile: string;                 // 证书文件路径
    PrivateKeyFile: string;                  // 私钥文件路径
    PrivateKeyPassword: string;              // 私钥口令（可选）
    CAFile: string;                          // CA证书文件路径
    CAPath: string;                          // CA证书目录路径
    UseSystemRoots: Boolean;                 // Context-scoped system trust-store opt-in; loads platform roots via ISSLCertificateStore
    VerifyMode: TSSLVerifyModes;            // 证书验证模式
    VerifyDepth: Integer;                    // 验证深度
    
    // 密码套件配置
    CipherList: string;                      // 密码套件列表（OpenSSL格式）
    CipherSuites: string;                    // TLS 1.3密码套件
    
    // SSL 选项
    Options: TSSLOptions;                    // SSL 选项集合
    
    // Mixed-scope configuration buckets:
    // ordinary protocol/certificate/cipher fields above stay context-facing unless noted otherwise.
    BufferSize: Integer;                     // Connection-scoped buffering hint; factory paths reject custom values
    HandshakeTimeout: Integer;               // Connection-scoped timeout; use connector/acceptor/connection timeout APIs
    SessionCacheSize: Integer;               // Context-scoped session cache sizing
    SessionTimeout: Integer;                 // Context-scoped session lifetime（秒）
    
    // 高级配置
    ServerName: string;                      // Deprecated compatibility-only context-level SNI; prefer ISSLClientConnection.SetServerName
    ALPNProtocols: string;                   // Context-scoped ALPN defaults（逗号分隔）
    EnableCompression: Boolean;              // Compatibility-only option-bridge flag; prefer Options; normalized into Options
    EnableSessionTickets: Boolean;           // Compatibility-only option-bridge flag; prefer Options; normalized into Options
    EnableOCSPStapling: Boolean;             // Compatibility-only option-bridge flag; prefer Options; normalized into Options
    ClientEarlyDataEnabled: Boolean;         // Context-scoped TLS 1.3 client early-data default
    ServerEarlyDataPolicy: TSSLEarlyDataServerPolicy; // Context-scoped TLS 1.3 server early-data policy
    ServerMaxEarlyDataSize: Cardinal;        // Context-scoped TLS 1.3 server early-data limit
    ServerEarlyDataReplayStoreFile: string;  // Server-context-scoped replay-store file opt-in
    ServerEarlyDataReplayStoreDirectory: string;  // Server-context-scoped replay-store directory opt-in
    
    // 日志配置
    LogLevel: TSSLLogLevel;                  // Library-scoped default log level; factory request paths reject overrides
    LogCallback: TSSLLogCallback;            // Library-scoped callback snapshot; SetLogCallback owns replacements and factory request paths reject callbacks
  end;
  PSSLConfig = ^TSSLConfig;

  { SSL 统计信息 - Phase 3.3: 增强监控和诊断 }
  TSSLStatistics = record
    // 连接统计
    ConnectionsTotal: Int64;        // 总连接数
    ConnectionsActive: Integer;     // 活动连接数
    HandshakesSuccessful: Int64;    // 成功握手次数
    HandshakesFailed: Int64;        // 失败握手次数
    BytesSent: Int64;               // 发送字节数
    BytesReceived: Int64;           // 接收字节数
    SessionCacheHits: Int64;        // 会话缓存命中次数
    SessionCacheMisses: Int64;      // 会话缓存未命中次数
    RenegotiationsCount: Int64;     // 重新协商次数
    AlertsSent: Int64;              // 发送的警报数
    AlertsReceived: Int64;          // 接收的警报数

    // Phase 3.3: 性能统计
    HandshakeTimeTotal: Int64;      // 总握手时间（毫秒）
    HandshakeTimeMin: Integer;      // 最小握手时间（毫秒）
    HandshakeTimeMax: Integer;      // 最大握手时间（毫秒）
    HandshakeTimeAvg: Integer;      // 平均握手时间（毫秒）

    // Phase 3.3: Session 复用统计
    SessionsReused: Int64;          // Session 复用次数
    SessionsCreated: Int64;         // 新 Session 创建次数
    SessionReuseRate: Double;       // Session 复用率（百分比 0-100）
  end;
  PSSLStatistics = ^TSSLStatistics;

  { Phase 3.3: 错误记录 - 用于错误历史追踪 }
  TSSLErrorRecord = record
    ErrorCode: TSSLErrorCode;       // 错误码
    ErrorMessage: string;           // 错误消息
    Timestamp: TDateTime;           // 发生时间
  end;

  { Phase 3.3: 健康状态 - 连接健康检查 }
  TSSLHealthStatus = record
    IsConnected: Boolean;           // 是否已连接
    HandshakeComplete: Boolean;     // 握手是否完成
    LastError: TSSLErrorCode;       // 最后一次错误
    LastErrorTime: TDateTime;       // 最后错误时间
    BytesSent: Int64;               // 已发送字节数
    BytesReceived: Int64;           // 已接收字节数
    ConnectionAge: Integer;         // 连接存活时间（秒）
  end;

  { Phase 3.3: 性能指标 - 连接性能统计 }
  TSSLPerformanceMetrics = record
    HandshakeTime: Integer;         // 握手时间（毫秒）
    FirstByteTime: Integer;         // 首字节时间（毫秒）
    TotalBytesTransferred: Int64;   // 总传输字节数
    AverageLatency: Integer;        // 平均延迟（毫秒）
    SessionReused: Boolean;         // Session 是否复用
  end;

  { Phase 3.3: 诊断信息 - 完整的连接诊断数据 }
  TSSLDiagnosticInfo = record
    ConnectionInfo: TSSLConnectionInfo;      // 连接信息
    HealthStatus: TSSLHealthStatus;          // 健康状态
    PerformanceMetrics: TSSLPerformanceMetrics; // 性能指标
    ErrorHistory: array of TSSLErrorRecord;  // 错误历史
  end;

  // ============================================================================
  // Result 类型定义（借鉴 Rust Result<T, E> 模式）
  // ============================================================================

  { SSL 操作结果 - 类似 Rust Result<(), E> }
  TSSLOperationResult = record
    Success: Boolean;
    ErrorCode: TSSLErrorCode;
    ErrorMessage: string;

    class function Ok: TSSLOperationResult; static;
    class function Err(ACode: TSSLErrorCode; const AMsg: string): TSSLOperationResult; static;

    function IsOk: Boolean;
    function IsErr: Boolean;
    procedure Expect(const AMsg: string);  // 失败时抛出带自定义消息的异常
    function UnwrapErr: TSSLErrorCode;  // 返回错误码（成功时抛异常）
  end;

  { SSL 数据结果 - 类似 Rust Result<TBytes, E> }
  TSSLDataResult = record
    Success: Boolean;
    Data: TBytes;
    ErrorCode: TSSLErrorCode;
    ErrorMessage: string;

    class function Ok(const AData: TBytes): TSSLDataResult; static;
    class function Err(ACode: TSSLErrorCode; const AMsg: string): TSSLDataResult; static;

    function IsOk: Boolean;
    function IsErr: Boolean;
    function Unwrap: TBytes;  // 失败时抛异常
    function UnwrapOr(const ADefault: TBytes): TBytes;  // 失败时返回默认值
    function Expect(const AMsg: string): TBytes;  // 失败时抛出带自定义消息的异常
    function UnwrapErr: TSSLErrorCode;  // 返回错误码（成功时抛异常）
    function IsOkAnd(APredicate: TPredicateTBytes): Boolean;  // 检查是否Ok且满足条件
    function Inspect(ACallback: TProcedureOfConstTBytes): TSSLDataResult;  // 检查但不消耗值
  end;

  { SSL 字符串结果 - 类似 Rust Result<String, E> }
  TSSLStringResult = record
    Success: Boolean;
    Value: string;
    ErrorCode: TSSLErrorCode;
    ErrorMessage: string;

    class function Ok(const AValue: string): TSSLStringResult; static;
    class function Err(ACode: TSSLErrorCode; const AMsg: string): TSSLStringResult; static;

    function IsOk: Boolean;
    function IsErr: Boolean;
    function Unwrap: string;  // 失败时抛异常
    function UnwrapOr(const ADefault: string): string;  // 失败时返回默认值
    function Expect(const AMsg: string): string;  // 失败时抛出带自定义消息的异常
    function UnwrapErr: TSSLErrorCode;  // 返回错误码（成功时抛异常）
    function IsOkAnd(APredicate: TPredicateString): Boolean;  // 检查是否Ok且满足条件
    function Inspect(ACallback: TProcedureOfConstString): TSSLStringResult;  // 检查但不消耗值
  end;

  { Builder 配置验证结果 - Phase 2.1.2 }
  TBuildValidationResult = record
    IsValid: Boolean;          // 是否有效（无错误）
    Warnings: array of string; // 警告消息（不阻止构建）
    Errors: array of string;   // 错误消息（阻止构建）

    class function Ok: TBuildValidationResult; static;
    class function WithWarnings(const AWarn: array of string): TBuildValidationResult; static;
    class function WithErrors(const AErrs: array of string): TBuildValidationResult; static;

    procedure AddWarning(const AMessage: string);
    procedure AddError(const AMessage: string);
    function HasWarnings: Boolean;
    function HasErrors: Boolean;
    function WarningCount: Integer;
    function ErrorCount: Integer;
  end;

  // ============================================================================
  // 异常类定义已移至 nextpas.core.tls.exceptions.pas
  // 所有模块应使用 nextpas.core.tls.exceptions 中定义的异常类
  // ============================================================================

  // ============================================================================
  // 回调类型定义
  // ============================================================================

  { 证书验证回调 }
  TSSLVerifyCallback = function(const ACertificate: TSSLCertificateInfo;
                                const AErrorCode: Integer;
                                const AErrorMessage: string): Boolean of object;

  { 密码回调 }
  TSSLPasswordCallback = function(var APassword: string;
                                const AIsRetry: Boolean): Boolean of object;

  { 信息回调 }
  TSSLInfoCallback = procedure(const AWhere: Integer;
                              const ARet: Integer;
                              const AState: string) of object;

  { 数据传输回调 }
  TSSLDataCallback = procedure(const AData: Pointer;
                              const ASize: Integer;
                              const AIsOutgoing: Boolean) of object;

  { HTTP GET 回调（由上层网络库实现，fafafa.ssl 不实现网络传输） }
  TSSLHTTPGetCallback = function(const AURL: string; ATimeoutMs: Integer): TSSLDataResult of object;

  { HTTP POST 回调（由上层网络库实现，fafafa.ssl 不实现网络传输） }
  TSSLHTTPPostCallback = function(const AURL, AContentType: string;
    const ABody: TBytes; ATimeoutMs: Integer): TSSLDataResult of object;

  // ============================================================================
  // 接口定义
  // ============================================================================

  // 前向声明
  ISSLContext = interface;
  ISSLConnection = interface;
  ISSLConnectionTextIO = interface;
  ISSLConnectionControl = interface;
  ISSLCertificate = interface;
  ISSLCertificateStore = interface;
  ISSLSession = interface;
  ISSLLibrary = interface;
  ISSLNativeHandleAccess = interface;  // 原生句柄访问接口（可选）
  ISSLHttpHooksAccess = interface;     // HTTP hooks 访问接口（可选）

  // 数组类型
  TSSLCertificateArray = array of ISSLCertificate;

  { TSSLBackendCapabilities - 后端能力矩阵 (v1.2 扩展)
    paired capability truth follows the support-level fields; legacy Supports* booleans are compatibility projections normalized via NormalizeLegacyCapabilityBooleans(...)
    SupportsTLS13 remains the primary bool truth until a TLS13Support field exists }
  TSSLBackendCapabilities = record
    // ===== v1.1.0 保留字段（向后兼容）=====
    SupportsTLS13: Boolean;           // TLS 1.3 支持
    SupportsALPN: Boolean;            // 应用层协议协商
    SupportsSNI: Boolean;             // 服务器名称指示
    SupportsOCSPStapling: Boolean;    // OCSP 装订
    SupportsCertificateTransparency: Boolean;  // 证书透明度
    SupportsSessionTickets: Boolean;  // 会话票据
    SupportsECDHE: Boolean;           // ECDHE 密钥交换
    SupportsChaChaPoly: Boolean;      // ChaCha20-Poly1305 加密
    SupportsPEMPrivateKey: Boolean;   // PEM 格式私钥加载支持
    MinTLSVersion: TSSLProtocolVersion;  // 支持的最低 TLS 版本
    MaxTLSVersion: TSSLProtocolVersion;  // 支持的最高 TLS 版本

    // ===== v1.2.0 新增字段 =====

    // ----- 基础信息 -----
    BackendType: TSSLLibraryType;       // 后端类型（OpenSSL, WinSSL 等）
    BackendImplType: TSSLBackendImplType; // 实现类型（原生/C库/OS原生）
    BackendVersion: string;             // 后端版本（如 "OpenSSL 3.0.13"）

    // ----- 协议支持 -----
    SupportsDTLS: Boolean;              // DTLS 支持

    // ----- 高级特性支持（带支持级别）-----
    SNISupport: TSSLFeatureSupportLevel;        // SNI 支持级别
    ALPNSupport: TSSLFeatureSupportLevel;       // ALPN 支持级别
    OCSPStaplingSupport: TSSLFeatureSupportLevel; // OCSP 装订支持级别
    CertTransparencySupport: TSSLFeatureSupportLevel; // 证书透明度支持级别
    SessionTicketsSupport: TSSLFeatureSupportLevel;   // 会话票据支持级别
    SessionCacheSupport: TSSLFeatureSupportLevel;     // 会话缓存支持级别（cache/control surface，不保证已观测到 resumed handshake）
    ZeroRTTSupport: TSSLFeatureSupportLevel;    // 0-RTT 支持级别（TLS 1.3）
    EarlyDataSupport: TSSLFeatureSupportLevel;  // Early Data 支持级别
    RenegotiationSupport: TSSLFeatureSupportLevel; // 重新协商支持级别（TLS 1.2）
    PostHandshakeAuthSupport: TSSLFeatureSupportLevel; // 握手后认证（TLS 1.3）

    // ----- 算法支持（细粒度）-----
    SupportedCiphers: TSSLCipherSupport;        // 支持的对称加密算法
    SupportedHashes: TSSLHashSupport;           // 支持的哈希算法
    SupportedKeyExchanges: TSSLKeyExchangeSupport; // 支持的密钥交换算法

    // ----- 性能特性 -----
    HasHardwareAcceleration: Boolean;    // 是否支持硬件加速（AES-NI 等）
    HasSIMDOptimization: Boolean;        // 是否有 SIMD 优化
    HasAssemblyOptimization: Boolean;    // 是否有汇编优化

    // ----- 平台特性 -----
    RequiresExternalLibrary: Boolean;    // 是否需要外部库文件
    SupportsSystemCertStore: Boolean;    // 是否支持系统证书存储
    SupportsPKCS11: Boolean;             // 是否支持 PKCS#11 硬件令牌
    SupportsTPM: Boolean;                // 是否支持 TPM（可信平台模块）

    // ----- 安全特性 -----
    HasConstantTimeOperations: Boolean;  // 是否有恒定时间操作（防时序攻击）
    SupportsFIPSMode: Boolean;           // 是否支持 FIPS 140-2 模式
    HasSecureMemoryWipe: Boolean;        // 是否有安全内存擦除

    // ----- 证书和密钥支持 -----
    SupportsDERPrivateKey: Boolean;      // DER 格式私钥加载支持
    SupportsPKCS8PrivateKey: Boolean;    // PKCS#8 格式私钥支持
    SupportsPKCS12: Boolean;             // PKCS#12 证书包支持
    SupportsPasswordProtectedKeys: Boolean; // 加密私钥支持

    // ----- 扩展性 -----
    SupportsCustomCipherSuites: Boolean; // 是否支持自定义密码套件
    SupportsCallbacks: Boolean;          // 是否发布上下文回调能力（至少一条 callback 具备真实 runtime wiring）

    // ----- 兼容性和质量 -----
    CompatibilityLevel: Integer;         // 兼容性级别（0-100，100=完全兼容）
    KnownIssues: string;                 // 已知问题描述（简短）
  end;

  {**
   * ISSLNativeHandleAccess - 原生句柄访问接口（可选）
   *
   * 这是一个可选接口，仅由基于 C 库的后端（OpenSSL, WinSSL, MbedTLS）实现。
   * 纯 FreePascal TLS 后端不实现此接口，因为它们没有底层 C 库句柄。
   *
   * 使用方法：
   *   if Supports(Conn, ISSLNativeHandleAccess, NativeAccess) then
   *     Handle := NativeAccess.GetNativeHandle;
   *
   * @since 1.1.0
   * @breaking-change 从核心接口移除 GetNativeHandle，改为可选接口
   *}
  ISSLNativeHandleAccess = interface
    ['{B2C4E6F8-1A2B-3C4D-5E6F-7A8B9C0D1E2F}']

    {** 获取底层 C 库的原生句柄
        @returns 平台相关的原生句柄指针（如 SSL*, HSSL 等）
        @warning 仅适用于 C 库后端，纯 Pascal 后端不实现此接口 *}
    function GetNativeHandle: Pointer;

    {** 获取后端类型，帮助调用者判断句柄的类型
        @returns TSSLLibraryType 枚举值 *}
    function GetBackendType: TSSLLibraryType;

    {** 检查原生句柄是否有效（非空且已初始化）
        @returns True 如果句柄有效 *}
    function IsNativeHandleValid: Boolean;
  end;

  {**
   * ISSLHttpHooksAccess - HTTP 传输 hooks 访问接口（可选）
   *
   * fafafa.ssl 不实现网络通信。任何依赖 HTTP 的功能（例如 OCSP 在线检查、CT log list 下载）
   * 必须通过上层注入的回调完成。
   *
   * 注入优先级由调用方决定；推荐：
   *   1) 为 context/connection 设置专用 hooks（通过 Supports 获取本接口）
   *   2) 未设置时回退到线程局部默认 hooks（见 nextpas.core.tls.net.hooks）
   *
   * @since 1.3.0
   *}
  ISSLHttpHooksAccess = interface
    ['{7F4F4D1D-7E3A-4C10-9F1F-8F61B3D9A5C2}']
    procedure SetHTTPGetCallback(ACallback: TSSLHTTPGetCallback);
    function GetHTTPGetCallback: TSSLHTTPGetCallback;
    procedure SetHTTPPostCallback(ACallback: TSSLHTTPPostCallback);
    function GetHTTPPostCallback: TSSLHTTPPostCallback;
  end;

  {**
   * ISSLServerOCSPStaplingContext - 服务端 stapled OCSP 响应材料访问接口（可选）
   *
   * 通过可选接口暴露“调用方提供的服务端 stapled OCSP response material”，
   * 不改变核心 `ISSLContext` 的跨后端契约。
   *
   * 当前语义有意保持收敛：
   * - 只接受调用方提供的 DER bytes / 文件
   * - 不负责 online fetch / refresh / responder 调度
   *}
  ISSLServerOCSPStaplingContext = interface
    ['{1C55CE81-C4E0-4A1E-A9E7-47A9D44C4BC1}']
    procedure ClearServerStapledOCSPResponse;
    procedure SetServerStapledOCSPResponse(const AResponseDER: TBytes);
    procedure LoadServerStapledOCSPResponseFile(const AFileName: string);
    function HasServerStapledOCSPResponse: Boolean;
    function GetServerStapledOCSPResponse: TBytes;
  end;

  {**
   * ISSLLibrary - SSL库管理接口
   *
   * 提供 SSL/TLS 库的初始化、版本查询、功能检测和工厂方法。
   * 这是使用 fafafa.ssl 的入口点接口。
   *
   * @stable 1.0
   * @locked 2025-12-24
   * @breaking-change-policy Requires major version bump
   *
   * @example
   *   var Lib: ISSLLibrary;
   *   begin
   *     Lib := TOpenSSLLibrary.Create;
   *     if Lib.Initialize then
   *       WriteLn('OpenSSL version: ', Lib.GetVersionString);
   *   end;
   *}
  ISSLLibrary = interface
    ['{A0E8F4B1-7C3A-4D2E-9F5B-8C6D7E9A0B1C}']

    {** 初始化 SSL 库。必须在使用其他功能前调用。
        @returns True 如果初始化成功，False 如果失败 *}
    function Initialize: Boolean;

    {** 清理 SSL 库资源。应在程序退出前调用 *}
    procedure Finalize;

    {** 检查库是否已初始化
        @returns True 如果已初始化 *}
    function IsInitialized: Boolean;

    {** 获取库后端类型（OpenSSL, WinSSL 等）
        @returns TSSLLibraryType 枚举值 *}
    function GetLibraryType: TSSLLibraryType;

    {** 获取库版本字符串（如 "OpenSSL 3.0.13"）
        @returns 版本描述字符串 *}
    function GetVersionString: string;

    {** 获取库版本号（数值格式，便于比较）
        @returns 版本号，格式因后端而异 *}
    function GetVersionNumber: Cardinal;

    {** 获取库编译标志
        @returns 编译配置字符串 *}
    function GetCompileFlags: string;

    {** 检查是否支持指定协议版本
        @param AProtocol 要检查的协议版本
        @returns True 如果支持该协议 *}
    function IsProtocolSupported(AProtocol: TSSLProtocolVersion): Boolean;

    {** 检查是否支持指定密码套件
        @param ACipherName 密码套件名称（如 "AES256-GCM-SHA384"）
        @returns True 如果支持该密码套件 *}
    function IsCipherSupported(const ACipherName: string): Boolean;

    {** 检查是否支持指定特性
        @param AFeature 要检查的特性（SNI, ALPN 等）
        @returns True 如果支持该特性 *}
    function IsFeatureSupported(AFeature: TSSLFeature): Boolean;

    {** 获取后端能力矩阵，一次性查询所有支持的特性
        @returns TSSLBackendCapabilities 记录 *}
    function GetCapabilities: TSSLBackendCapabilities;

    {** 设置默认配置，影响后续创建的上下文
        @param AConfig 配置记录 *}
    procedure SetDefaultConfig(const AConfig: TSSLConfig);

    {** 获取当前默认配置
        @returns 当前配置记录的副本 *}
    function GetDefaultConfig: TSSLConfig;

    {** 获取最后一个错误码
        @returns 平台相关的错误码 *}
    function GetLastError: Integer;

    {** 获取最后一个错误的描述字符串
        @returns 错误描述 *}
    function GetLastErrorString: string;

    {** 清除错误状态 *}
    procedure ClearError;

    {** 获取统计信息（连接数、握手次数等）
        @returns 统计信息记录 *}
    function GetStatistics: TSSLStatistics;

    {** 重置统计计数器 *}
    procedure ResetStatistics;

    {** 设置日志回调函数
        @param ACallback 日志回调，nil 禁用日志 *}
    procedure SetLogCallback(ACallback: TSSLLogCallback);

    {** 记录日志消息
        @param ALevel 日志级别
        @param AMessage 日志内容 *}
    procedure Log(ALevel: TSSLLogLevel; const AMessage: string);

    {** 创建 SSL 上下文
        @param AType 上下文类型（客户端/服务端/双向）
        @returns 新创建的上下文接口 *}
    function CreateContext(AType: TSSLContextType): ISSLContext;

    {** 创建空证书对象
        @returns 新创建的证书接口 *}
    function CreateCertificate: ISSLCertificate;

    {** 创建证书存储
        @returns 新创建的证书存储接口 *}
    function CreateCertificateStore: ISSLCertificateStore;
  end;

  {**
   * ISSLContext - SSL上下文接口
   *
   * 管理 SSL/TLS 连接的配置，包括协议版本、证书、密码套件等。
   * 上下文可以创建多个连接，共享配置。
   *
   * @stable 1.0
   * @locked 2025-12-24
   * @breaking-change-policy Requires major version bump
   *
   * @example
   *   var Ctx: ISSLContext;
   *   begin
   *     Ctx := Lib.CreateContext(sslCtxClient);
   *     Ctx.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);
   *     Ctx.LoadCertificate('client.crt');
   *     Ctx.LoadPrivateKey('client.key', 'password');
   *   end;
   *}
  ISSLContext = interface
    ['{B1F9E5C2-8D4B-5E3F-A06C-9D8E0F1A2B3D}']

    {** 获取上下文类型（客户端/服务端/双向）
        @returns TSSLContextType 枚举值 *}
    function GetContextType: TSSLContextType;

    {** 设置允许的协议版本。废弃协议会触发警告日志
        @param AVersions 协议版本集合 *}
    procedure SetProtocolVersions(AVersions: TSSLProtocolVersions);

    {** 获取当前允许的协议版本
        @returns 协议版本集合 *}
    function GetProtocolVersions: TSSLProtocolVersions;

    {** 设置协议首选版本。
        注意：该设置为跨后端统一的“协商偏好”，并不保证后端可强制命中。
        传入 sslProtocolUnknown 表示不设置偏好（自动协商）。
        @param AVersion 首选协议版本（必须属于当前 ProtocolVersions，或为 sslProtocolUnknown） *}
    procedure SetPreferredVersion(AVersion: TSSLProtocolVersion);

    {** 获取当前协议首选版本
        @returns 首选协议版本；sslProtocolUnknown 表示未设置偏好 *}
    function GetPreferredVersion: TSSLProtocolVersion;

    {** 从文件加载证书
        @param AFileName 证书文件路径（PEM 或 DER 格式）
        @raises ESSLCertificateException 加载失败时 *}
    procedure LoadCertificate(const AFileName: string); overload;

    {** 从流加载证书
        @param AStream 包含证书数据的流
        @raises ESSLCertificateException 加载失败时 *}
    procedure LoadCertificate(AStream: IStream); overload;

    {** 从证书接口加载证书
        @param ACert 证书接口 *}
    procedure LoadCertificate(ACert: ISSLCertificate); overload;

    {** 从文件加载私钥
        @param AFileName 私钥文件路径
        @param APassword 私钥密码（可选）
        @raises ESSLKeyException 加载失败时 *}
    procedure LoadPrivateKey(const AFileName: string; const APassword: string = ''); overload;

    {** 从流加载私钥
        @param AStream 包含私钥数据的流
        @param APassword 私钥密码（可选）
        @raises ESSLKeyException 加载失败时 *}
    procedure LoadPrivateKey(AStream: IStream; const APassword: string = ''); overload;

    {** 从 PEM 字符串直接加载证书（无需临时文件）
        @param APEM PEM 格式的证书字符串
        @raises ESSLCertificateException 加载失败时 *}
    procedure LoadCertificatePEM(const APEM: string);

    {** 从 PEM 字符串直接加载私钥
        @param APEM PEM 格式的私钥字符串
        @param APassword 私钥密码（可选）
        @raises ESSLKeyException 加载失败时 *}
    procedure LoadPrivateKeyPEM(const APEM: string; const APassword: string = '');

    {** 私钥密码可用性说明
        在向 LoadPrivateKey(..., APassword) / LoadPrivateKeyPEM(..., APassword) 传入非空密码前，先检查 ISSLLibrary.GetCapabilities.SupportsPasswordProtectedKeys；对 SupportsPasswordProtectedKeys=False 的 backend，non-empty APassword 应抛出 unsupported，而不是 silent ignore。 *}

    {** 加载 CA 证书文件（用于验证对端证书）
        @param AFileName CA 证书文件路径 *}
    procedure LoadCAFile(const AFileName: string);

    {** 加载 CA 证书目录
        @param APath 包含 CA 证书的目录路径 *}
    procedure LoadCAPath(const APath: string);

    {** 设置证书存储（用于验证）
        @param AStore 证书存储接口 *}
    procedure SetCertificateStore(AStore: ISSLCertificateStore);

    {** 设置证书验证模式
        @param AMode 验证模式集合 *}
    procedure SetVerifyMode(AMode: TSSLVerifyModes);

    {** 获取当前验证模式
        @returns 验证模式集合 *}
    function GetVerifyMode: TSSLVerifyModes;

    {** 设置证书链验证深度
        @param ADepth 最大验证深度（默认 10） *}
    procedure SetVerifyDepth(ADepth: Integer);

    {** 获取当前验证深度
        @returns 验证深度 *}
    function GetVerifyDepth: Integer;

    {** 回调可用性说明
        在安装非 nil 的 verify/password/info callback 前，先检查 ISSLLibrary.GetCapabilities.SupportsCallbacks；对 SupportsCallbacks=False 的 backend，non-nil 赋值应抛出 unsupported，nil 仅用于清除并回到默认行为。 *}
    {** 设置自定义验证回调
        @param ACallback 验证回调函数 *}
    procedure SetVerifyCallback(ACallback: TSSLVerifyCallback);

    {** 自定义密码套件可用性说明
        在调用 SetCipherList(...) / SetCipherSuites(...) 传入 custom non-default cipher override 前，先检查 ISSLLibrary.GetCapabilities.SupportsCustomCipherSuites；对 SupportsCustomCipherSuites=False 的 backend，custom non-default 赋值应抛出 unsupported，empty clear 与 shipped baseline defaults 仅作为 compatibility/default-context path。 *}
    {** 设置密码套件列表（TLS 1.2 及以下）
        @param ACipherList OpenSSL 格式的密码套件字符串 *}
    procedure SetCipherList(const ACipherList: string);

    {** 获取当前密码套件列表
        @returns 密码套件字符串 *}
    function GetCipherList: string;

    {** 设置 TLS 1.3 密码套件
        @param ACipherSuites TLS 1.3 密码套件字符串 *}
    procedure SetCipherSuites(const ACipherSuites: string);

    {** 获取 TLS 1.3 密码套件
        @returns TLS 1.3 密码套件字符串 *}
    function GetCipherSuites: string;

    {** 启用/禁用会话缓存
        @param AEnabled True 启用，False 禁用 *}
    procedure SetSessionCacheMode(AEnabled: Boolean);

    {** 获取会话缓存状态
        @returns True 如果已启用 *}
    function GetSessionCacheMode: Boolean;

    {** 设置会话超时时间
        @param ATimeout 超时秒数 *}
    procedure SetSessionTimeout(ATimeout: Integer);

    {** 获取会话超时时间
        @returns 超时秒数 *}
    function GetSessionTimeout: Integer;

    {** 设置会话缓存大小
        @param ASize 最大缓存会话数 *}
    procedure SetSessionCacheSize(ASize: Integer);

    {** 获取会话缓存大小
        @returns 最大缓存会话数 *}
    function GetSessionCacheSize: Integer;

    {** 设置 SSL 选项
        @param AOptions 选项集合 *}
    procedure SetOptions(const AOptions: TSSLOptions);

    {** 获取当前 SSL 选项
        @returns 选项集合 *}
    function GetOptions: TSSLOptions;

    {** 设置 SNI 服务器名称（客户端使用）
        @param AServerName 服务器主机名
        @deprecated 推荐使用 per-connection SNI：ISSLClientConnection.SetServerName *}
    procedure SetServerName(const AServerName: string);
      deprecated 'Use per-connection SNI via ISSLClientConnection.SetServerName';

    {** 获取 SNI 服务器名称
        @returns 服务器主机名
        @deprecated 推荐使用 per-connection SNI：ISSLClientConnection.GetServerName *}
    function GetServerName: string;
      deprecated 'Use per-connection SNI via ISSLClientConnection.GetServerName';

    {** 设置 ALPN 协议列表
        @param AProtocols 逗号分隔的协议列表（如 "h2,http/1.1"） *}
    procedure SetALPNProtocols(const AProtocols: string);

    {** 获取 ALPN 协议列表
        @returns 协议列表字符串 *}
    function GetALPNProtocols: string;

    {** 设置证书验证标志（OCSP、CRL 等）
        @param AFlags 验证标志集合 *}
    procedure SetCertVerifyFlags(AFlags: TSSLCertVerifyFlags);

    {** 获取证书验证标志
        @returns 验证标志集合 *}
    function GetCertVerifyFlags: TSSLCertVerifyFlags;

    {** 设置密码回调（用于加密私钥）
        @param ACallback 密码回调函数 *}
    procedure SetPasswordCallback(ACallback: TSSLPasswordCallback);

    {** 设置信息回调（用于调试）
        @param ACallback 信息回调函数 *}
    procedure SetInfoCallback(ACallback: TSSLInfoCallback);

    {** 添加证书固定（Certificate Pinning）
        @param AHash SHA-256 哈希值（32字节）
        @param APinType 固定类型（证书或公钥）- 0=证书, 1=公钥
        @param ADescription 描述信息
        @param AIsBackup 是否为备用固定 *}
    procedure AddCertificatePin(const AHash: TBytes; APinType: Integer;
      const ADescription: string; AIsBackup: Boolean = False);

    {** 添加证书固定（Base64编码）
        @param ABase64Hash Base64编码的SHA-256哈希
        @param APinType 固定类型（证书或公钥）- 0=证书, 1=公钥
        @param ADescription 描述信息
        @param AIsBackup 是否为备用固定 *}
    procedure AddCertificatePinBase64(const ABase64Hash: string; APinType: Integer;
      const ADescription: string; AIsBackup: Boolean = False);

    {** 启用/禁用证书固定验证
        @param AEnabled True启用，False禁用 *}
    procedure SetCertificatePinningEnabled(AEnabled: Boolean);

    {** 获取证书固定是否启用
        @returns True如果已启用 *}
    function GetCertificatePinningEnabled: Boolean;

    {** 清除所有证书固定 *}
    procedure ClearCertificatePins;

    {** 从套接字创建 SSL 连接
        @param ASocket 已连接的套接字句柄
        @returns 新创建的连接接口 *}
    function CreateConnection(ASocket: THandle): ISSLConnection; overload;

    {** 从流创建 SSL 连接
        @param AStream 底层传输流
        @returns 新创建的连接接口 *}
    function CreateConnection(AStream: IStream): ISSLConnection; overload;

    {** 检查上下文是否有效
        @returns True 如果上下文已正确初始化 *}
    function IsValid: Boolean;
  end;

  {**
   * ISSLConnection - SSL连接接口
   *
   * 表示一个活动的 SSL/TLS 连接，提供握手、数据传输和状态查询功能。
   * 连接从 ISSLContext.CreateConnection 创建。
   *
   * @stable 1.0
   * @locked 2025-12-24
   * @breaking-change-policy Requires major version bump
   *
   * @example
   *   var Conn: ISSLConnection;
   *   var ClientConn: ISSLClientConnection;
   *   begin
   *     Conn := Ctx.CreateConnection(Socket);
   *     ClientConn := Conn as ISSLClientConnection;
   *     ClientConn.SetServerName('example.com');
   *     if Conn.Connect then
   *       Conn.WriteString('GET / HTTP/1.1'#13#10);
   *   end;
   *}
  ISSLConnection = interface
    ['{C2A9F6D3-9E5C-6F40-B17D-AE9F102B4C5E}']

    {** 执行客户端 SSL 连接（包含握手）
        @returns True 如果连接成功 *}
    function Connect: Boolean;

    {** 接受服务端 SSL 连接（包含握手）
        @returns True 如果接受成功 *}
    function Accept: Boolean;

    {** 优雅关闭 SSL 连接（发送 close_notify）
        @returns True 如果关闭成功 *}
    function Shutdown: Boolean;

    {** 强制关闭连接（不发送 close_notify） *}
    procedure Close;

    {** 执行/继续 SSL 握手
        @returns 握手状态 *}
    function DoHandshake: TSSLHandshakeState;

    {** 检查握手是否完成
        @returns True 如果握手已完成 *}
    function IsHandshakeComplete: Boolean;

    {** 发起重新协商
        @returns True 如果重新协商成功启动 *}
    function Renegotiate: Boolean;

    {** 读取解密数据
        @param ABuffer 接收缓冲区
        @param ACount 要读取的最大字节数
        @returns 实际读取的字节数，-1 表示错误 *}
    function Read(var ABuffer; ACount: Integer): Integer;

    {** 写入数据（将被加密发送）
        @param ABuffer 数据缓冲区
        @param ACount 要写入的字节数
        @returns 实际写入的字节数，-1 表示错误 *}
    function Write(const ABuffer; ACount: Integer): Integer;

    {** 读取字符串
        @param AStr 输出字符串
        @preferred-access 框架/transport 集成优先使用 Read/Write；ReadString/WriteString 继续作为 v1.x convenience-core 文本入口保留
        @owner-note 当前默认 text-helper owner 为 ISSLConnectionTextIO.ReadString；此入口继续作为 v1.x convenience-core mirror 保留
        @returns True 如果读取成功 *}
    function ReadString(out AStr: string): Boolean;

    {** 写入字符串
        @param AStr 要发送的字符串
        @preferred-access 框架/transport 集成优先使用 Read/Write；ReadString/WriteString 继续作为 v1.x convenience-core 文本入口保留
        @owner-note 当前默认 text-helper owner 为 ISSLConnectionTextIO.WriteString；此入口继续作为 v1.x convenience-core mirror 保留
        @returns True 如果写入成功 *}
    function WriteString(const AStr: string): Boolean;

    {** 检查是否需要读取更多数据（非阻塞模式）
        @returns True 如果 SSL 层需要读取 *}
    function WantRead: Boolean;

    {** 检查是否需要写入数据（非阻塞模式）
        @returns True 如果 SSL 层需要写入 *}
    function WantWrite: Boolean;

    {** 获取操作错误码
        @param ARet 操作返回值
        @returns 对应的错误码 *}
    function GetError(ARet: Integer): TSSLErrorCode;

    {** 获取连接详细信息
        @returns 连接信息记录
        @preferred-access 新代码优先通过 ISSLConnectionInfo.GetConnectionInfo 获取
        @owner-note 默认 owner 为 ISSLConnectionInfo.GetConnectionInfo；此入口仅兼容保留
        @compatibility-note v1.x compatibility-core mirror; not recommended as the primary entry for new code; Stage-A demotion target is ISSLConnectionInfo
        @deprecated 推荐使用 ISSLConnectionInfo.GetConnectionInfo *}
    function GetConnectionInfo: TSSLConnectionInfo;
      deprecated 'Use ISSLConnectionInfo.GetConnectionInfo';

    {** 获取协商的协议版本
        @returns 协议版本枚举 *}
    function GetProtocolVersion: TSSLProtocolVersion;

    {** 获取协商的密码套件名称
        @returns 密码套件名称字符串 *}
    function GetCipherName: string;

    {** 获取对端证书
        @returns 对端证书接口，无证书时返回 nil *}
    function GetPeerCertificate: ISSLCertificate;

    {** 获取对端证书链
        @preferred-access 新代码优先通过 ISSLCertificateVerification.GetPeerCertificateChain 获取
        @owner-note 当前默认 owner 为 ISSLCertificateVerification；ISSLConnection.GetPeerCertificateChain 保留为 v1.x compatibility mirror
        @compatibility-note v1.x compatibility-core mirror; not recommended as the primary entry for new code; Stage-A demotion target is ISSLCertificateVerification
        @deprecated 推荐使用 ISSLCertificateVerification.GetPeerCertificateChain
        @returns 证书数组，从叶证书到根证书 *}
    function GetPeerCertificateChain: TSSLCertificateArray;
      deprecated 'Use ISSLCertificateVerification.GetPeerCertificateChain';

    {** 获取证书验证结果码
        @preferred-access 新代码优先通过 ISSLCertificateVerification.GetVerifyResult 获取
        @owner-note 当前默认 owner 为 ISSLCertificateVerification；ISSLConnection.GetVerifyResult 保留为 v1.x compatibility mirror
        @compatibility-note v1.x compatibility-core mirror; not recommended as the primary entry for new code; Stage-A demotion target is ISSLCertificateVerification
        @deprecated 推荐使用 ISSLCertificateVerification.GetVerifyResult
        @returns 平台相关的验证结果码 *}
    function GetVerifyResult: Integer;
      deprecated 'Use ISSLCertificateVerification.GetVerifyResult';

    {** 获取证书验证结果描述
        @preferred-access 新代码优先通过 ISSLCertificateVerification.GetVerifyResultString 获取
        @owner-note 当前默认 owner 为 ISSLCertificateVerification；ISSLConnection.GetVerifyResultString 保留为 v1.x compatibility mirror
        @compatibility-note v1.x compatibility-core mirror; not recommended as the primary entry for new code; Stage-A demotion target is ISSLCertificateVerification
        @deprecated 推荐使用 ISSLCertificateVerification.GetVerifyResultString
        @returns 验证结果的文字描述 *}
    function GetVerifyResultString: string;
      deprecated 'Use ISSLCertificateVerification.GetVerifyResultString';

    {** 获取当前会话（用于会话恢复）
        @preferred-access 新代码优先通过 ISSLSessionResumption.GetSession 获取
        @owner-note 默认 owner 为 ISSLSessionResumption.GetSession；此入口仅兼容保留
        @compatibility-note v1.x compatibility-core mirror; not recommended as the primary entry for new code; Stage-A demotion target is ISSLSessionResumption
        @deprecated 推荐使用 ISSLSessionResumption.GetSession
        @returns 会话接口 *}
    function GetSession: ISSLSession;
      deprecated 'Use ISSLSessionResumption.GetSession';

    {** 设置要恢复的会话
        @preferred-access 新代码优先通过 ISSLSessionResumption.SetSession 配置待恢复会话
        @owner-note 默认 owner 为 ISSLSessionResumption.SetSession；此入口仅兼容保留
        @compatibility-note v1.x compatibility-core mirror; not recommended as the primary entry for new code; Stage-A demotion target is ISSLSessionResumption
        @deprecated 推荐使用 ISSLSessionResumption.SetSession
        @param ASession 之前保存的会话 *}
    procedure SetSession(ASession: ISSLSession);
      deprecated 'Use ISSLSessionResumption.SetSession';

    {** 检查是否使用了会话恢复
        @preferred-access 新代码优先通过 ISSLSessionResumption.IsSessionReused 判断握手是否实际复用
        @owner-note 默认 owner 为 ISSLSessionResumption.IsSessionReused；此入口仅兼容保留
        @compatibility-note v1.x compatibility-core mirror; not recommended as the primary entry for new code; Stage-A demotion target is ISSLSessionResumption
        @deprecated 推荐使用 ISSLSessionResumption.IsSessionReused
        @returns True 如果会话被恢复 *}
    function IsSessionReused: Boolean;
      deprecated 'Use ISSLSessionResumption.IsSessionReused';

    {** 获取 ALPN 协商结果
        @returns 协商的协议名称（如 "h2"），未协商返回空
        @preferred-access 新代码优先通过 ISSLConnectionInfo.GetSelectedALPNProtocol 获取
        @owner-note 当前 ALPN 协商结果的默认 owner；ISSLConnection.GetSelectedALPNProtocol 保留为 v1.x compatibility mirror
        @compatibility-note v1.x compatibility-core mirror; not recommended as the primary entry for new code; Stage-A demotion target is ISSLConnectionInfo
        @deprecated 推荐使用 ISSLConnectionInfo.GetSelectedALPNProtocol *}
    function GetSelectedALPNProtocol: string;
      deprecated 'Use ISSLConnectionInfo.GetSelectedALPNProtocol';

    {** 检查连接是否活动
        @returns True 如果连接已建立且未关闭 *}
    function IsConnected: Boolean;

    {** 获取内部状态（调试用）
        @returns 状态字符串 *}
    function GetState: string;

    {** 获取状态描述字符串
        @returns 人类可读的状态描述
        @preferred-access 新代码优先通过 ISSLConnectionInfo.GetStateString 获取
        @owner-note 默认 owner 为 ISSLConnectionInfo.GetStateString；此入口仅兼容保留
        @compatibility-note v1.x compatibility-core mirror; not recommended as the primary entry for new code; Stage-A demotion target is ISSLConnectionInfo
        @deprecated 推荐使用 ISSLConnectionInfo.GetStateString *}
    function GetStateString: string;
      deprecated 'Use ISSLConnectionInfo.GetStateString';

    {** 设置操作超时
        @param ATimeout 超时毫秒数
        @preferred-access 新代码优先在构建阶段使用 TSSLConnectionBuilder.WithTimeout / TSSLConnector.WithTimeout / TSSLAcceptor.WithTimeout；连接创建后若需要读取或覆盖 runtime control state，优先通过 ISSLConnectionControl.SetTimeout；此入口继续作为 per-connection convenience override 保留
        @owner-note 当前 runtime connection-control state 的默认 owner 为 ISSLConnectionControl；ISSLConnection.SetTimeout 继续作为 v1.x convenience-core mirror 保留 *}
    procedure SetTimeout(ATimeout: Integer);

    {** 获取当前超时设置
        @preferred-access 新代码优先在构建阶段使用 TSSLConnectionBuilder.WithTimeout / TSSLConnector.WithTimeout / TSSLAcceptor.WithTimeout；连接创建后若需要读取或覆盖 runtime control state，优先通过 ISSLConnectionControl.GetTimeout；此入口继续作为 per-connection convenience override 保留
        @owner-note 当前 runtime connection-control state 的默认 owner 为 ISSLConnectionControl；ISSLConnection.GetTimeout 继续作为 v1.x convenience-core mirror 保留
        @returns 超时毫秒数 *}
    function GetTimeout: Integer;

    {** 设置阻塞模式
        @param ABlocking True 为阻塞，False 为非阻塞
        @preferred-access 新代码优先在构建阶段使用 TSSLConnectionBuilder.WithBlocking；连接创建后若需要读取或覆盖 runtime control state，优先通过 ISSLConnectionControl.SetBlocking；此入口继续作为 per-connection convenience override 保留
        @owner-note 当前 runtime connection-control state 的默认 owner 为 ISSLConnectionControl；ISSLConnection.SetBlocking 继续作为 v1.x convenience-core mirror 保留 *}
    procedure SetBlocking(ABlocking: Boolean);

    {** 获取当前阻塞模式
        @preferred-access 新代码优先在构建阶段使用 TSSLConnectionBuilder.WithBlocking；连接创建后若需要读取或覆盖 runtime control state，优先通过 ISSLConnectionControl.GetBlocking；此入口继续作为 per-connection convenience override 保留
        @owner-note 当前 runtime connection-control state 的默认 owner 为 ISSLConnectionControl；ISSLConnection.GetBlocking 继续作为 v1.x convenience-core mirror 保留
        @returns True 如果是阻塞模式 *}
    function GetBlocking: Boolean;

    {** 获取关联的上下文
        @returns 创建此连接的上下文接口
        @preferred-access 新代码优先通过 ISSLConnectionInfo.GetContext 获取
        @owner-note 默认 owner 为 ISSLConnectionInfo.GetContext；此入口仅兼容保留
        @compatibility-note v1.x compatibility-core mirror; not recommended as the primary entry for new code; Stage-A demotion target is ISSLConnectionInfo
        @deprecated 推荐使用 ISSLConnectionInfo.GetContext *}
    function GetContext: ISSLContext;
      deprecated 'Use ISSLConnectionInfo.GetContext';

    // Phase 3.3: 监控和诊断接口

    {** 获取连接健康状态
        @returns 健康状态记录
        @preferred-access 新代码优先通过 ISSLDiagnostics.GetHealthStatus 获取
        @owner-note 默认 owner 为 ISSLDiagnostics.GetHealthStatus；此入口仅兼容保留
        @compatibility-note v1.x compatibility-core mirror; not recommended as the primary entry for new code; Stage-A demotion target is ISSLDiagnostics
        @deprecated 推荐使用 ISSLDiagnostics.GetHealthStatus *}
    function GetHealthStatus: TSSLHealthStatus;
      deprecated 'Use ISSLDiagnostics.GetHealthStatus';

    {** 检查连接是否健康
        @returns True 如果连接健康（已连接且无严重错误）
        @preferred-access 新代码优先通过 ISSLDiagnostics.IsHealthy 获取
        @owner-note 默认 owner 为 ISSLDiagnostics.IsHealthy；此入口仅兼容保留
        @compatibility-note v1.x compatibility-core mirror; not recommended as the primary entry for new code; Stage-A demotion target is ISSLDiagnostics
        @deprecated 推荐使用 ISSLDiagnostics.IsHealthy *}
    function IsHealthy: Boolean;
      deprecated 'Use ISSLDiagnostics.IsHealthy';

    {** 获取完整的诊断信息
        @returns 诊断信息记录，包含连接信息、健康状态、性能指标和错误历史
        @preferred-access 新代码优先通过 ISSLDiagnostics.GetDiagnosticInfo 获取
        @owner-note 默认 owner 为 ISSLDiagnostics.GetDiagnosticInfo；此入口仅兼容保留
        @compatibility-note v1.x compatibility-core mirror; not recommended as the primary entry for new code; Stage-A demotion target is ISSLDiagnostics
        @deprecated 推荐使用 ISSLDiagnostics.GetDiagnosticInfo *}
    function GetDiagnosticInfo: TSSLDiagnosticInfo;
      deprecated 'Use ISSLDiagnostics.GetDiagnosticInfo';

    {** 获取性能指标
        @returns 性能指标记录
        @preferred-access 新代码优先通过 ISSLDiagnostics.GetPerformanceMetrics 获取
        @owner-note 默认 owner 为 ISSLDiagnostics.GetPerformanceMetrics；此入口仅兼容保留
        @compatibility-note v1.x compatibility-core mirror; not recommended as the primary entry for new code; Stage-A demotion target is ISSLDiagnostics
        @deprecated 推荐使用 ISSLDiagnostics.GetPerformanceMetrics *}
    function GetPerformanceMetrics: TSSLPerformanceMetrics;
      deprecated 'Use ISSLDiagnostics.GetPerformanceMetrics';
    
    // OCSP Stapling support
    
    {** 获取 OCSP Stapling 状态
        @returns True 如果启用了 OCSP Stapling
        @preferred-access 新代码优先通过 ISSLOCSPStapling.GetOCSPStaplingEnabled 获取
        @owner-note 默认 owner 为 ISSLOCSPStapling.GetOCSPStaplingEnabled；此入口仅兼容保留
        @compatibility-note v1.x compatibility-core mirror; not recommended as the primary entry for new code; Stage-A demotion target is ISSLOCSPStapling
        @deprecated 推荐使用 ISSLOCSPStapling.GetOCSPStaplingEnabled *}
    function GetOCSPStaplingEnabled: Boolean;
      deprecated 'Use ISSLOCSPStapling.GetOCSPStaplingEnabled';
    
    {** 获取 OCSP Stapling 响应（客户端）
        @returns OCSP 响应的 DER 编码字节，未提供时返回空数组
        @preferred-access 新代码优先通过 ISSLOCSPStapling.GetOCSPResponse 获取
        @owner-note 默认 owner 为 ISSLOCSPStapling.GetOCSPResponse；此入口仅兼容保留
        @compatibility-note v1.x compatibility-core mirror; not recommended as the primary entry for new code; Stage-A demotion target is ISSLOCSPStapling
        @deprecated 推荐使用 ISSLOCSPStapling.GetOCSPResponse *}
    function GetOCSPResponse: TBytes;
      deprecated 'Use ISSLOCSPStapling.GetOCSPResponse';
    
    {** 检查 OCSP Stapling 响应是否已验证
        @returns True 如果响应已验证且证书状态为 Good
        @preferred-access 新代码优先通过 ISSLOCSPStapling.IsOCSPResponseVerified 获取
        @owner-note 默认 owner 为 ISSLOCSPStapling.IsOCSPResponseVerified；此入口仅兼容保留
        @compatibility-note v1.x compatibility-core mirror; not recommended as the primary entry for new code; Stage-A demotion target is ISSLOCSPStapling
        @deprecated 推荐使用 ISSLOCSPStapling.IsOCSPResponseVerified *}
    function IsOCSPResponseVerified: Boolean;
      deprecated 'Use ISSLOCSPStapling.IsOCSPResponseVerified';
    
    {** 获取 OCSP 响应状态描述
        @returns 状态描述字符串（如 "Good", "Revoked", "Unknown", "Not Provided"）
        @preferred-access 新代码优先通过 ISSLOCSPStapling.GetOCSPResponseStatus 获取
        @owner-note 默认 owner 为 ISSLOCSPStapling.GetOCSPResponseStatus；此入口仅兼容保留
        @compatibility-note v1.x compatibility-core mirror; not recommended as the primary entry for new code; Stage-A demotion target is ISSLOCSPStapling
        @deprecated 推荐使用 ISSLOCSPStapling.GetOCSPResponseStatus *}
    function GetOCSPResponseStatus: string;
      deprecated 'Use ISSLOCSPStapling.GetOCSPResponseStatus';
  end;

  {**
   * ISSLConnectionControl - 连接级 timeout / blocking 控制扩展接口
   *
   * 承接 `ISSLConnection` 中这组 v1.x connection-adjacent convenience mirrors：
   * - SetTimeout
   * - GetTimeout
   * - SetBlocking
   * - GetBlocking
   *
   * builder / connector / acceptor 仍然是更高层的 build-stage 推荐入口；
   * 当连接已经创建、调用方需要读取或覆盖 runtime control state 时，
   * 新代码优先通过这个 optional owner path 访问。
   *
   * @stable 1.0
   * @since 2026-05-21
   *}
  ISSLConnectionControl = interface
    ['{4D3AA9AF-6D62-4CE1-9F30-6B5E7E6A9A21}']

    {** 设置操作超时
        @owner-note 当前 runtime connection-control state 的默认 owner；ISSLConnection.SetTimeout 继续作为 v1.x convenience mirror 保留 *}
    procedure SetTimeout(ATimeout: Integer);

    {** 获取当前超时设置
        @owner-note 当前 runtime connection-control state 的默认 owner；ISSLConnection.GetTimeout 继续作为 v1.x convenience mirror 保留 *}
    function GetTimeout: Integer;

    {** 设置阻塞模式
        @owner-note 当前 runtime connection-control state 的默认 owner；ISSLConnection.SetBlocking 继续作为 v1.x convenience mirror 保留 *}
    procedure SetBlocking(ABlocking: Boolean);

    {** 获取当前阻塞模式
        @owner-note 当前 runtime connection-control state 的默认 owner；ISSLConnection.GetBlocking 继续作为 v1.x convenience mirror 保留 *}
    function GetBlocking: Boolean;
  end;

  { Granular timeout control (P1 improvement) }
  TSSLConnectionTimeouts = record
    HandshakeTimeout: Integer;
    ReadTimeout: Integer;
    WriteTimeout: Integer;
    IdleTimeout: Integer;
  end;

  ISSLConnectionTimeoutControl = interface
    ['{E2A641A2-0C36-4D7C-A3F3-6AA6F1D23741}']
    procedure SetHandshakeTimeout(AMs: Integer);
    function GetHandshakeTimeout: Integer;
    procedure SetReadTimeout(AMs: Integer);
    function GetReadTimeout: Integer;
    procedure SetWriteTimeout(AMs: Integer);
    function GetWriteTimeout: Integer;
    procedure SetIdleTimeout(AMs: Integer);
    function GetIdleTimeout: Integer;
    procedure SetTimeouts(const ATimeouts: TSSLConnectionTimeouts);
    function GetTimeouts: TSSLConnectionTimeouts;
  end;

  { Per-connection ALPN override (P1 improvement) }
  ISSLClientALPNConnection = interface
    ['{65A9E7D5-8B9F-4A3C-9C54-4E3F6C0B1D21}']
    procedure SetALPNProtocols(const AProtocols: string);
    function GetALPNProtocols: string;
  end;

  { Server certificate resolver for SNI routing (P2 improvement) }
  TSSLClientHelloInfo = record
    ServerName: string;
    OfferedALPNProtocols: string;
  end;

  ISSLServerCredential = interface
    ['{E7E36F8F-2612-4F30-A516-8A4F0D6D3842}']
    function GetCertificateChainPEM: string;
    function GetPrivateKeyPEM: string;
    function GetPrivateKeyPassword: string;
  end;

  ISSLServerCertificateResolver = interface
    ['{3A2F6C41-B28B-45F1-9B39-4D812A7F0C61}']
    function ResolveServerCredential(
      const AClientHello: TSSLClientHelloInfo;
      out ACredential: ISSLServerCredential
    ): TSSLOperationResult;
  end;

  { Custom server certificate verifier (P2 improvement) }
  TSSLServerCertificateVerifyRequest = record
    ServerName: string;
    LeafCertificateDER: TBytes;
    ChainDER: array of TBytes;
    DefaultErrorCode: Integer;
    DefaultErrorMessage: string;
    OCSPResponse: TBytes;
  end;

  ISSLServerCertificateVerifier = interface
    ['{6B8C841E-6A86-4D0A-9E8F-3BFE0D4E3F72}']
    function VerifyServerCertificate(
      const ARequest: TSSLServerCertificateVerifyRequest
    ): TSSLOperationResult;
  end;

  { Non-blocking handshake state machine (for event-loop integration) }
  TSSLHandshakeProgress = (
    sslHandshakeComplete,
    sslHandshakeWantRead,
    sslHandshakeWantWrite,
    sslHandshakeFailed
  );

  TSSLHandshakeStepResult = record
    Progress: TSSLHandshakeProgress;
    ErrorCode: TSSLErrorCode;
    ErrorMessage: string;
  end;

  {**
   * ISSLClientConnection - 客户端连接扩展接口（per-connection 设置）
   *
   * 目的：将客户端特有且可能随连接变化的参数（如 SNI/hostname）从 Context 中下沉到 Connection。
   * 这样同一个 Context 可以安全地并发创建多个不同目标主机的连接。
   *
   * 使用约定：应在调用 Connect/DoHandshake 之前设置。
   *
   * @stable 1.0
   * @locked 2025-12-31
   * @breaking-change-policy Additive (non-breaking)
   *}
  ISSLClientConnection = interface(ISSLConnection)
    ['{7A8F3F3E-6E4B-4F3A-9B9C-9E3F5C3A2B10}']

    {** 设置服务器名称（SNI）
        @param AServerName 服务器主机名（如 example.com） *}
    procedure SetServerName(const AServerName: string);

    {** 获取当前连接的服务器名称（SNI）
        @returns 服务器主机名，未设置时为空字符串 *}
    function GetServerName: string;
  end;

  {**
   * ISSLEarlyDataContext - TLS 1.3 Early Data 上下文扩展接口
   *
   * 通过可选接口暴露 0-RTT 的上下文级别配置，避免改变核心
   * `ISSLContext` 的既有语义。
   *}
  ISSLEarlyDataContext = interface
    ['{2E4A74D9-C5F4-4BBA-8B94-93A9B828B54F}']

    {** 启用/禁用客户端 early data 能力 *}
    procedure SetClientEarlyDataEnabled(AEnabled: Boolean);

    {** 获取客户端 early data 是否启用 *}
    function GetClientEarlyDataEnabled: Boolean;

    {** 设置服务端 early data accept/reject 策略 *}
    procedure SetServerEarlyDataPolicy(APolicy: TSSLEarlyDataServerPolicy);

    {** 获取服务端 early data accept/reject 策略 *}
    function GetServerEarlyDataPolicy: TSSLEarlyDataServerPolicy;

    {** 设置服务端签发 ticket 时的 max_early_data_size *}
    procedure SetServerMaxEarlyDataSize(ASize: Cardinal);

    {** 获取服务端签发 ticket 时的 max_early_data_size *}
    function GetServerMaxEarlyDataSize: Cardinal;
  end;

  {**
   * ISSLEarlyDataConnection - TLS 1.3 Early Data 连接扩展接口
   *
   * 通过可选接口暴露客户端排队 early data 与连接级状态查询能力，
   * 不改变既有 `ISSLConnection.Write(...)` 的含义。
   *}
  ISSLEarlyDataConnection = interface
    ['{6DAF8835-5B8A-4D6F-97FC-D0ED700B4C72}']

    {** 在握手前排队客户端 early data 负载 *}
    function SetEarlyData(const AData: TBytes): TSSLOperationResult;

    {** 获取当前连接的 early data 状态 *}
    function GetEarlyDataStatus: TSSLEarlyDataStatus;

    {** 获取当前连接可用的 max_early_data_size 限额 *}
    function GetEarlyDataLimit: Cardinal;
  end;

  {**
   * ISSLConnectionTextIO - 文本 helper 扩展接口
   *
   * 承接 `ISSLConnection` 中这组 v1.x convenience-core text helpers：
   * - ReadString
   * - WriteString
   *
   * 框架 / transport / framing 集成
   * 仍优先走 `Read` / `Write`；
   * 但当连接已经创建、调用方仍要沿用文本 helper 这层语义时，
   * 新代码优先通过这个 optional owner path 访问。
   *
   * @stable 1.0
   * @since 2026-05-21
   *}
  ISSLConnectionTextIO = interface
    ['{C548E7E8-1B8B-4C4D-9C6A-54C738746B4A}']

    {** 读取字符串
        @owner-note 当前默认 text-helper owner；ISSLConnection.ReadString 继续作为 v1.x convenience-core mirror 保留 *}
    function ReadString(out AStr: string): Boolean;

    {** 写入字符串
        @owner-note 当前默认 text-helper owner；ISSLConnection.WriteString 继续作为 v1.x convenience-core mirror 保留 *}
    function WriteString(const AStr: string): Boolean;
  end;

  {**
   * ISSLDiagnostics - 连接诊断扩展接口
   *
   * 提供连接健康状态、性能指标等诊断信息。
   * 此接口是可选的，用于监控和调试场景。
   * 当前是 `ISSLConnection` 上这组诊断 mirrors 的默认 owner。
   *
   * @stable 1.0
   * @since 2026-02-05
   *}
  ISSLDiagnostics = interface
    ['{8E4F2A1B-3C5D-6E7F-8A9B-0C1D2E3F4A5B}']

    {** 获取连接健康状态
        @preferred-access 新代码优先通过 ISSLDiagnostics.GetHealthStatus 获取
        @owner-note 当前默认 owner；ISSLConnection.GetHealthStatus 继续作为 v1.x compatibility mirror 保留 *}
    function GetHealthStatus: TSSLHealthStatus;

    {** 检查连接是否健康
        @preferred-access 新代码优先通过 ISSLDiagnostics.IsHealthy 获取
        @owner-note 当前默认 owner；ISSLConnection.IsHealthy 继续作为 v1.x compatibility mirror 保留 *}
    function IsHealthy: Boolean;

    {** 获取性能指标
        @preferred-access 新代码优先通过 ISSLDiagnostics.GetPerformanceMetrics 获取
        @owner-note 当前默认 owner；ISSLConnection.GetPerformanceMetrics 继续作为 v1.x compatibility mirror 保留 *}
    function GetPerformanceMetrics: TSSLPerformanceMetrics;

    {** 获取完整诊断信息
        @preferred-access 新代码优先通过 ISSLDiagnostics.GetDiagnosticInfo 获取
        @owner-note 当前默认 owner；ISSLConnection.GetDiagnosticInfo 继续作为 v1.x compatibility mirror 保留 *}
    function GetDiagnosticInfo: TSSLDiagnosticInfo;
  end;

  {**
   * ISSLSessionResumption - 会话复用扩展接口
   *
   * 提供 TLS 会话保存和恢复功能，用于减少握手开销。
   * 当前是 `ISSLConnection` 上这组会话 mirrors 的默认 owner。
   *
   * @stable 1.0
   * @since 2026-02-05
   *}
  ISSLSessionResumption = interface
    ['{9F5A3B2C-4D6E-7F8A-9B0C-1D2E3F4A5B6C}']

    {** 获取当前会话
        @preferred-access 新代码优先通过 ISSLSessionResumption.GetSession 获取
        @owner-note 当前默认 owner；ISSLConnection.GetSession 继续作为 v1.x compatibility mirror 保留 *}
    function GetSession: ISSLSession;

    {** 设置要恢复的会话
        @preferred-access 新代码优先通过 ISSLSessionResumption.SetSession 配置待恢复会话
        @owner-note 当前默认 owner；ISSLConnection.SetSession 继续作为 v1.x compatibility mirror 保留 *}
    procedure SetSession(ASession: ISSLSession);

    {** 检查是否使用了会话恢复
        @preferred-access 新代码优先通过 ISSLSessionResumption.IsSessionReused 获取
        @owner-note 当前默认 owner；ISSLConnection.IsSessionReused 继续作为 v1.x compatibility mirror 保留 *}
    function IsSessionReused: Boolean;
  end;

  {**
   * ISSLCertificateVerification - 证书验证扩展接口
   *
   * 提供证书链和验证结果的详细信息。
   * 当前是 `ISSLConnection` 上这组证书验证 mirrors 的默认 owner。
   *
   * @stable 1.0
   * @since 2026-02-05
   *}
  ISSLCertificateVerification = interface
    ['{A0B1C2D3-E4F5-6A7B-8C9D-0E1F2A3B4C5D}']

    {** 获取对端证书链
        @preferred-access 新代码优先通过 ISSLCertificateVerification.GetPeerCertificateChain 获取
        @owner-note 当前默认 owner；ISSLConnection.GetPeerCertificateChain 继续作为 v1.x compatibility mirror 保留 *}
    function GetPeerCertificateChain: TSSLCertificateArray;

    {** 获取证书验证结果码
        @preferred-access 新代码优先通过 ISSLCertificateVerification.GetVerifyResult 获取
        @owner-note 当前默认 owner；ISSLConnection.GetVerifyResult 继续作为 v1.x compatibility mirror 保留 *}
    function GetVerifyResult: Integer;

    {** 获取证书验证结果描述
        @preferred-access 新代码优先通过 ISSLCertificateVerification.GetVerifyResultString 获取
        @owner-note 当前默认 owner；ISSLConnection.GetVerifyResultString 继续作为 v1.x compatibility mirror 保留 *}
    function GetVerifyResultString: string;
  end;

  {**
   * ISSLOCSPStapling - OCSP 装订扩展接口
   *
   * 提供 OCSP Stapling 相关功能。
   * 当前是 `ISSLConnection` 上这组 OCSP mirrors 的默认 owner。
   *
   * @stable 1.0
   * @since 2026-02-05
   *}
  ISSLOCSPStapling = interface
    ['{B1C2D3E4-F5A6-7B8C-9D0E-1F2A3B4C5D6E}']

    {** 检查是否启用了 OCSP Stapling
        @preferred-access 新代码优先通过 ISSLOCSPStapling.GetOCSPStaplingEnabled 获取
        @owner-note 当前默认 owner；ISSLConnection.GetOCSPStaplingEnabled 继续作为 v1.x compatibility mirror 保留 *}
    function GetOCSPStaplingEnabled: Boolean;

    {** 获取 OCSP 响应
        @preferred-access 新代码优先通过 ISSLOCSPStapling.GetOCSPResponse 获取
        @owner-note 当前默认 owner；ISSLConnection.GetOCSPResponse 继续作为 v1.x compatibility mirror 保留 *}
    function GetOCSPResponse: TBytes;

    {** 检查 OCSP 响应是否已验证
        @preferred-access 新代码优先通过 ISSLOCSPStapling.IsOCSPResponseVerified 获取
        @owner-note 当前默认 owner；ISSLConnection.IsOCSPResponseVerified 继续作为 v1.x compatibility mirror 保留 *}
    function IsOCSPResponseVerified: Boolean;

    {** 获取 OCSP 响应状态
        @preferred-access 新代码优先通过 ISSLOCSPStapling.GetOCSPResponseStatus 获取
        @owner-note 当前默认 owner；ISSLConnection.GetOCSPResponseStatus 继续作为 v1.x compatibility mirror 保留 *}
    function GetOCSPResponseStatus: string;
  end;

  {**
   * ISSLCertificateTransparency - Certificate Transparency / SCT 扩展接口
   *
   * 提供连接级 SCT list surface。
   * 这只表示 surface / parser 能力，不等于完整 CT policy / cryptographic verification。
   *}
  ISSLCertificateTransparency = interface
    ['{D3A0FA1A-7E5A-4FC5-9A86-0B5C7A7426D1}']

    {** 是否拿到了可用的 SCT list surface *}
    function GetCertificateTransparencyEnabled: Boolean;

    {** 获取原始 SignedCertificateTimestampList 字节 *}
    function GetSignedCertificateTimestampList: TBytes;

    {** 获取解析出的 SCT 数量 *}
    function GetSignedCertificateTimestampCount: Integer;

    {** 获取 CT/SCT surface 状态描述 *}
    function GetCertificateTransparencyStatus: string;
  end;

  {**
   * ISSLCertificateTransparencyValidation - Certificate Transparency validation 扩展接口
   *
   * 提供连接级 CT cryptographic validation / policy surface。
   * 这只表示 validation result/policy 可观测，不等于连接一定会对 validation 失败 fail-closed。
   *}
  ISSLCertificateTransparencyValidation = interface
    ['{8D5D2D62-8C58-4C62-A8D8-59CF5D9110A0}']

    {** 是否拿到了 CT validation 结果 *}
    function HasCertificateTransparencyValidationResult: Boolean;

    {** 默认 CT policy 是否满足 *}
    function IsCertificateTransparencyPolicySatisfied: Boolean;

    {** 获取 CT validation 状态描述 *}
    function GetCertificateTransparencyValidationStatus: string;
  end;

  {**
   * ISSLConnectionInfo - 连接信息扩展接口
   *
   * 承接 `ISSLConnection` 中这组 v1.x compatibility-core mirrors：
   * - GetConnectionInfo
   * - GetContext
   * - GetSelectedALPNProtocol
   * - GetStateString
   *
   * 这是当前 Stage-A demotion target，用来在不立即改动 core signature 的前提下，
   * 为后续 slimming 提供稳定的 owner。
   *
   * @stable 1.0
   * @since 2026-02-05
   *}
  ISSLConnectionInfo = interface
    ['{C2D3E4F5-A6B7-8C9D-0E1F-2A3B4C5D6E7F}']

    {** 获取连接详细信息
        @preferred-access 新代码优先通过 ISSLConnectionInfo.GetConnectionInfo 获取
        @owner-note 当前连接信息记录的默认 owner；ISSLConnection.GetConnectionInfo 保留为 v1.x compatibility mirror *}
    function GetConnectionInfo: TSSLConnectionInfo;

    {** 获取关联的上下文
        @preferred-access 新代码优先通过 ISSLConnectionInfo.GetContext 获取
        @owner-note 当前 context 引用的默认 owner；ISSLConnection.GetContext 保留为 v1.x compatibility mirror *}
    function GetContext: ISSLContext;

    {** 获取 ALPN 协商结果
        @preferred-access 新代码优先通过 ISSLConnectionInfo.GetSelectedALPNProtocol 获取
        @owner-note 当前 ALPN 协商结果的默认 owner；ISSLConnection.GetSelectedALPNProtocol 保留为 v1.x compatibility mirror *}
    function GetSelectedALPNProtocol: string;

    {** 获取状态描述字符串
        @preferred-access 新代码优先通过 ISSLConnectionInfo.GetStateString 获取
        @owner-note 当前状态描述字符串的默认 owner；ISSLConnection.GetStateString 保留为 v1.x compatibility mirror *}
    function GetStateString: string;
  end;

  {**
   * ISSLCertificate - Full-featured certificate interface for SSL operations
   *
   * This interface provides comprehensive certificate management capabilities:
   * - Loading from various sources (file, stream, PEM, DER)
   * - Certificate validation and verification
   * - Certificate chain management
   * - Extension and fingerprint access
   *
   * @note This is DIFFERENT from ICertificate in nextpas.core.tls.cert.builder:
   *   - ISSLCertificate: Full-featured, for SSL operations (load, verify, chains)
   *   - ICertificate: Lightweight, for builder output, read-only
   *
   * @stable 1.0
   * @locked 2025-12-24
   * @breaking-change-policy Requires major version bump
   * @see ICertificate for builder-generated certificates
   *}
  ISSLCertificate = interface
    ['{D3B0A7E4-AF6D-7051-C28E-BF0A213C5D6F}']
    
    // 加载和保存
    function LoadFromFile(const AFileName: string): Boolean;
    function LoadFromStream(AStream: IStream): Boolean;
    function LoadFromMemory(const AData: Pointer; ASize: Integer): Boolean;
    function LoadFromPEM(const APEM: string): Boolean;
    function LoadFromDER(const ADER: TBytes): Boolean;
    
    function SaveToFile(const AFileName: string): Boolean;
    function SaveToStream(AStream: IStream): Boolean;
    function SaveToPEM: string;
    function SaveToDER: TBytes;
    
    // 证书信息
    function GetInfo: TSSLCertificateInfo;
    function GetSubject: string;
    function GetIssuer: string;
    function GetSerialNumber: string;
    function GetNotBefore: TDateTime;
    function GetNotAfter: TDateTime;
    function GetPublicKey: string;
    function GetPublicKeyAlgorithm: string;
    function GetSignatureAlgorithm: string;
    function GetVersion: Integer;
    
    // 证书验证
    function Verify(ACAStore: ISSLCertificateStore): Boolean;
    function VerifyEx(ACAStore: ISSLCertificateStore;
      AFlags: TSSLCertVerifyFlags; out AResult: TSSLCertVerifyResult): Boolean;
    function VerifyHostname(const AHostname: string): Boolean;
    function IsExpired: Boolean;
    function IsSelfSigned: Boolean;
    function IsCA: Boolean;

    // 便利方法 (P2 增强)
    function GetDaysUntilExpiry: Integer;  // 返回证书到期天数，已过期返回负数
    function GetSubjectCN: string;         // 直接获取 Subject 中的 Common Name

    // 证书扩展
    function GetExtension(const AOID: string): string;
    function GetSubjectAltNames: TSSLStringArray;
    function GetKeyUsage: TSSLStringArray;
    function GetExtendedKeyUsage: TSSLStringArray;
    
    // 指纹
    function GetFingerprint(AHashType: TSSLHash): string;
    function GetFingerprintSHA1: string;
    function GetFingerprintSHA256: string;
    
    // 证书链
    procedure SetIssuerCertificate(ACert: ISSLCertificate);
    function GetIssuerCertificate: ISSLCertificate;  // 返回内部引用，不转移所有权

    // 对象管理
    function Clone: ISSLCertificate;    // P3-21: 创建新实例，调用者拥有所有权
  end;

  {**
   * ISSLCertificateStore - 证书存储接口
   * @stable 1.0
   * @locked 2025-12-24
   * @breaking-change-policy Requires major version bump
   *}
  ISSLCertificateStore = interface
    ['{E4C1B8F5-B07E-8162-D39F-C10B324D6E70}']
    
    // 证书管理
    function AddCertificate(ACert: ISSLCertificate): Boolean;
    function RemoveCertificate(ACert: ISSLCertificate): Boolean;
    function Contains(ACert: ISSLCertificate): Boolean;
    procedure Clear;
    function GetCount: Integer;
    function GetCertificate(AIndex: Integer): ISSLCertificate;
    
    // 加载证书
    function LoadFromFile(const AFileName: string): Boolean;
    function LoadFromPath(const APath: string): Boolean;
    function LoadSystemStore: Boolean; // 加载系统证书存储
    
    // 查找证书
    function FindBySubject(const ASubject: string): ISSLCertificate;
    function FindByIssuer(const AIssuer: string): ISSLCertificate;
    function FindBySerialNumber(const ASerialNumber: string): ISSLCertificate;
    function FindByFingerprint(const AFingerprint: string): ISSLCertificate;
    
    // 验证
    function VerifyCertificate(ACert: ISSLCertificate): Boolean;
    function BuildCertificateChain(ACert: ISSLCertificate): TSSLCertificateArray;
  end;

  {**
   * ISSLSession - 会话接口
   * @stable 1.0
   * @locked 2025-12-24
   * @breaking-change-policy Requires major version bump
   *}
  ISSLSession = interface
    ['{F5D2C9F6-C18F-9273-E40A-D21C435E7F81}']
    
    // 会话信息
    function GetID: string;
    function GetCreationTime: TDateTime;
    function GetTimeout: Integer;
    procedure SetTimeout(ATimeout: Integer);
    function IsValid: Boolean;
    function IsResumable: Boolean;
    
    // 会话属性
    function GetProtocolVersion: TSSLProtocolVersion;
    function GetCipherName: string;
    function GetPeerCertificate: ISSLCertificate;
    
    // 序列化
    function Serialize: TBytes;
    function Deserialize(const AData: TBytes): Boolean;

    // 对象管理
    function Clone: ISSLSession;
  end;

const
  // ============================================================================
  // 常量定义
  // ============================================================================

  // ============================================================================
  // 库版本信息 (P2: 接口版本控制)
  // ============================================================================

  {** 库主版本号 - 不兼容的 API 变更时递增 *}
  FAFAFA_SSL_VERSION_MAJOR = 1;

  {** 库次版本号 - 向后兼容的功能添加时递增 *}
  FAFAFA_SSL_VERSION_MINOR = 6;

  {** 库修订版本号 - 向后兼容的 bug 修复时递增 *}
  FAFAFA_SSL_VERSION_PATCH = 0;

  {** 库版本字符串 *}
  FAFAFA_SSL_VERSION_STRING = '1.6.0';

  {** 接口版本号 - 用于检测接口兼容性
      格式: (Major * 10000) + (Minor * 100) + Patch
      例如: 1.0.0 = 10000, 1.5.0 = 10500 *}
  FAFAFA_SSL_INTERFACE_VERSION = 10600;

  {** 接口锁定日期 - 接口稳定后不再修改 *}
  FAFAFA_SSL_INTERFACE_LOCKED_DATE = '2025-12-24';

  // TSSLContextType 别名（兼容性）
  sslContextClient = sslCtxClient;
  sslContextServer = sslCtxServer;
  sslContextBoth = sslCtxBoth;

  // 库名称映射
  SSL_LIBRARY_NAMES: array[TSSLLibraryType] of string = (
    'Auto-Detect',
    'OpenSSL',
    'WolfSSL',
    'MbedTLS',
    'Windows Schannel',
    'FreePascal Native'
  );

  // 协议版本字符串
  SSL_PROTOCOL_NAMES: array[TSSLProtocolVersion] of string = (
    'Unknown',
    'SSL 2.0',
    'SSL 3.0',
    'TLS 1.0',
    'TLS 1.1',
    'TLS 1.2',
    'TLS 1.3',
    'DTLS 1.0',
    'DTLS 1.2'
  );

  // 错误代码描述（中文）
  SSL_ERROR_MESSAGES: array[TSSLErrorCode] of string = (
    '无错误',
    '一般错误',
    '内存分配失败',
    '无效参数',
    '未初始化',
    '协议错误',
    '握手错误',
    '证书错误',
    '证书过期',
    '证书被撤销',
    '未知证书',
    '证书不受信任',
    '主机名不匹配',
    '连接错误',
    '超时',
    'I/O错误',
    '操作将阻塞',
    'SSL需要读取',
    'SSL需要写入',
    '不支持的功能',
    '库文件未找到',
    '函数未找到',
    '版本不匹配',
    '配置错误',
    // 新增错误消息 - Phase 4
    '数据格式错误',
    '解密失败',
    '加密失败',
    '解析失败',
    '加载失败',
    '验证失败',
    '密钥派生失败',
    '格式无效',
    '缓冲区太小',
    '资源耗尽',
    '其他错误'
  );

  // 错误代码描述（英文）
  SSL_ERROR_MESSAGES_EN: array[TSSLErrorCode] of string = (
    'No error',
    'General error',
    'Memory allocation failed',
    'Invalid parameter',
    'Not initialized',
    'Protocol error',
    'Handshake error',
    'Certificate error',
    'Certificate expired',
    'Certificate revoked',
    'Unknown certificate',
    'Certificate untrusted',
    'Hostname mismatch',
    'Connection error',
    'Timeout',
    'I/O error',
    'Operation would block',
    'SSL needs read',
    'SSL needs write',
    'Unsupported feature',
    'Library file not found',
    'Function not found',
    'Version mismatch',
    'Configuration error',
    // New error messages - Phase 4
    'Invalid data format',
    'Decryption failed',
    'Encryption failed',
    'Parse failed',
    'Load failed',
    'Verification failed',
    'Key derivation failed',
    'Invalid format',
    'Buffer too small',
    'Resource exhausted',
    'Other error'
  );

  // 默认配置值
  SSL_DEFAULT_BUFFER_SIZE = 16384;           // 16KB
  SSL_DEFAULT_HANDSHAKE_TIMEOUT = 30000;     // 30秒
  SSL_DEFAULT_SESSION_CACHE_SIZE = 1024;     // 1024个会话
  SSL_DEFAULT_SESSION_TIMEOUT = 300;         // 5分钟
  SSL_DEFAULT_VERIFY_DEPTH = 10;             // 验证深度

  // TLS 1.3 默认密码套件
  SSL_DEFAULT_TLS13_CIPHERSUITES = 'TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_128_GCM_SHA256';
  
  // TLS 1.2 及以下默认密码套件（排除不安全算法）
  SSL_DEFAULT_CIPHER_LIST = 'ECDHE+AESGCM:ECDHE+AES256:DHE+AESGCM:DHE+AES256:' +
                            '!aNULL:!eNULL:!NULL:!MD5:!DSS:!RC4:!3DES:!EXPORT';

  // Phase 3.8 P2-1: 网络端口常量
  SSL_DEFAULT_HTTPS_PORT = 443;
  SSL_DEFAULT_HTTP_PORT = 80;

  // HTTP 配置常量
  SSL_DEFAULT_MAX_REDIRECTS = 5;

  // I/O 缓冲区大小常量
  SSL_IO_STRING_BUFFER_SIZE = 4096;
  SSL_IO_STREAM_BUFFER_SIZE = 8192;

  // 环形缓冲区默认容量幂次 (2^16 = 65536)
  SSL_RINGBUFFER_DEFAULT_CAPACITY_POW2 = 16;

// ============================================================================
// 辅助函数
// ============================================================================

function SSLErrorToString(AError: TSSLErrorCode): string;
function ProtocolVersionToString(AVersion: TSSLProtocolVersion): string;
function LibraryTypeToString(ALibType: TSSLLibraryType): string;
function CreateDefaultLibraryDefaults: TSSLLibraryDefaults;
function GetLibraryDefaults(const ALibrary: ISSLLibrary): TSSLLibraryDefaults;
procedure ApplyLibraryDefaults(const ALibrary: ISSLLibrary; const ADefaults: TSSLLibraryDefaults);
function CreateDefaultContextConfig(AContextType: TSSLContextType = sslCtxClient): TSSLContextConfig;
function ContextConfigFromSSLConfig(const AConfig: TSSLConfig): TSSLContextConfig;
function SSLConfigFromContextConfig(const AConfig: TSSLContextConfig): TSSLConfig;

{** 获取库版本字符串 *}
function GetFafafaSSLVersion: string;

{** 获取接口版本号 *}
function GetFafafaSSLInterfaceVersion: Integer;

{** 检查接口版本兼容性
    @param ARequiredVersion 要求的最低接口版本
    @returns True 如果当前版本 >= 要求版本 *}
function CheckInterfaceVersion(ARequiredVersion: Integer): Boolean;

// ===== v1.2: 能力矩阵辅助函数 =====

{** 检查算法是否被后端支持
    @param ACaps 后端能力矩阵
    @param ACipher 要检查的加密算法
    @returns True 如果支持 *}
function IsCipherSupported(const ACaps: TSSLBackendCapabilities;
                          ACipher: TSSLCipher): Boolean;

{** 检查哈希算法是否被后端支持
    @param ACaps 后端能力矩阵
    @param AHash 要检查的哈希算法
    @returns True 如果支持 *}
function IsHashSupported(const ACaps: TSSLBackendCapabilities;
                        AHash: TSSLHash): Boolean;

{** 检查密钥交换算法是否被后端支持
    @param ACaps 后端能力矩阵
    @param AKex 要检查的密钥交换算法
    @returns True 如果支持 *}
function IsKeyExchangeSupported(const ACaps: TSSLBackendCapabilities;
                                AKex: TSSLKeyExchange): Boolean;

{** 检查功能支持级别是否为稳定
    @param ASupport 支持级别
    @returns True 如果为稳定 *}
function IsFeatureStable(ASupport: TSSLFeatureSupportLevel): Boolean;

{** 检查功能是否可用（稳定或实验性）
    @param ASupport 支持级别
    @returns True 如果可用 *}
function IsFeatureUsable(ASupport: TSSLFeatureSupportLevel): Boolean;

{** 检查功能是否已弃用
    @param ASupport 支持级别
    @returns True 如果已弃用 *}
function IsFeatureDeprecated(ASupport: TSSLFeatureSupportLevel): Boolean;

{** 用 v1.2 support-level 字段回填 legacy boolean 兼容视图
    @param ACaps 后端能力矩阵
    @note runtime truth 以 support-level 字段为准；legacy boolean 仅作兼容派生 *}
procedure NormalizeLegacyCapabilityBooleans(var ACaps: TSSLBackendCapabilities);

{** 检查是否为原生 FreePascal 后端
    @param ACaps 后端能力矩阵
    @returns True 如果为纯 Pascal 实现 *}
function IsNativeBackend(const ACaps: TSSLBackendCapabilities): Boolean;

{** 检查是否为 C 库后端
    @param ACaps 后端能力矩阵
    @returns True 如果为 C 库绑定 *}
function IsCLibraryBackend(const ACaps: TSSLBackendCapabilities): Boolean;

{** 检查后端是否需要外部依赖
    @param ACaps 后端能力矩阵
    @returns True 如果需要外部库文件 *}
function RequiresExternalDependencies(const ACaps: TSSLBackendCapabilities): Boolean;

{** 计算后端安全性评分（0-100）
    @param ACaps 后端能力矩阵
    @returns 安全性评分 *}
function GetSecurityScore(const ACaps: TSSLBackendCapabilities): Integer;

{** 计算后端性能评分（0-100）
    @param ACaps 后端能力矩阵
    @returns 性能评分 *}
function GetPerformanceScore(const ACaps: TSSLBackendCapabilities): Integer;

{** 生成能力矩阵的人类可读描述
    @param ACaps 后端能力矩阵
    @returns 描述字符串 *}
function GetCapabilitiesDescription(const ACaps: TSSLBackendCapabilities): string;

implementation

uses
  nextpas.core.exception,       // EIndexOutOfRangeError (replaces SysUtils.ERangeError)
  nextpas.core.text.conv,       // IntToStr (replaces SysUtils.IntToStr)
  nextpas.core.tls.errors,      // Stage 2.1 P2 - Standardized error handling
  nextpas.core.tls.exceptions;  // Phase 3.3 P0 - 统一异常定义（修复重复定义问题）

{ TBytesView - 零拷贝字节视图实现 (Phase 2.3.2) }

class function TBytesView.FromBytes(var ABytes: TBytes): TBytesView;
begin
  Result.Length := System.Length(ABytes);
  if Result.Length > 0 then
    Result.Data := @ABytes[0]  // 获取第一个元素的地址（指向调用者的数据）
  else
    Result.Data := nil;
end;

class function TBytesView.FromPtr(AData: PByte; ALength: Integer): TBytesView;
begin
  Result.Data := AData;
  Result.Length := ALength;
end;

class function TBytesView.Empty: TBytesView;
begin
  Result.Data := nil;
  Result.Length := 0;
end;

function TBytesView.AsBytes: TBytes;
var
  I: Integer;
begin
  Result := nil;  // Phase 3.3 P0 - 初始化 Result，避免编译器警告
  SetLength(Result, Length);
  if (Length > 0) and (Data <> nil) then
  begin
    for I := 0 to Length - 1 do
      Result[I] := Data[I];
  end;
end;

function TBytesView.Slice(AStart, ALength: Integer): TBytesView;
begin
  // 边界检查
  if (AStart < 0) or (AStart >= Length) then
  begin
    Result := TBytesView.Empty;
    Exit;
  end;

  // 调整长度
  if AStart + ALength > Length then
    ALength := Length - AStart;

  if ALength <= 0 then
  begin
    Result := TBytesView.Empty;
    Exit;
  end;

  // 创建子视图
  Result.Data := Data + AStart;
  Result.Length := ALength;
end;

function TBytesView.IsEmpty: Boolean;
begin
  Result := (Length = 0) or (Data = nil);
end;

function TBytesView.IsValid: Boolean;
begin
  Result := (Data <> nil) and (Length > 0);
end;

function TBytesView.GetByte(AIndex: Integer): Byte;
begin
  // Rust-quality: Bounds checking like Rust's [] operator
  if (AIndex < 0) or (AIndex >= Length) then
    raise EIndexOutOfRangeError.CreateFmt('TBytesView index %d out of bounds [0..%d)', [AIndex, Length]);
  Result := Data[AIndex];
end;

function TBytesView.GetByteUnchecked(AIndex: Integer): Byte;
begin
  // Rust-quality: Unchecked access like Rust's get_unchecked()
  // Use only when bounds are already verified
  Result := Data[AIndex];
end;

{ 异常类实现已移至 nextpas.core.tls.exceptions.pas }

{ 辅助函数实现 }

function SSLErrorToString(AError: TSSLErrorCode): string;
begin
  Result := SSL_ERROR_MESSAGES[AError];
end;

function ProtocolVersionToString(AVersion: TSSLProtocolVersion): string;
begin
  Result := SSL_PROTOCOL_NAMES[AVersion];
end;

function LibraryTypeToString(ALibType: TSSLLibraryType): string;
begin
  Result := SSL_LIBRARY_NAMES[ALibType];
end;

function CreateDefaultLibraryDefaults: TSSLLibraryDefaults;
begin
  Result.LogLevel := sslLogError;
  Result.LogCallback := nil;
end;

function GetLibraryDefaults(const ALibrary: ISSLLibrary): TSSLLibraryDefaults;
var
  LConfig: TSSLConfig;
begin
  Result := CreateDefaultLibraryDefaults;
  if ALibrary = nil then
    Exit;

  LConfig := ALibrary.GetDefaultConfig;
  Result.LogLevel := LConfig.LogLevel;
  Result.LogCallback := LConfig.LogCallback;
end;

procedure ApplyLibraryDefaults(const ALibrary: ISSLLibrary;
  const ADefaults: TSSLLibraryDefaults);
var
  LConfig: TSSLConfig;
begin
  if ALibrary = nil then
    Exit;

  LConfig := ALibrary.GetDefaultConfig;
  LConfig.LogLevel := ADefaults.LogLevel;
  ALibrary.SetDefaultConfig(LConfig);
  ALibrary.SetLogCallback(ADefaults.LogCallback);
end;

function CreateDefaultContextConfig(AContextType: TSSLContextType): TSSLContextConfig;
begin
  Result := Default(TSSLContextConfig);
  Result.LibraryType := sslAutoDetect;
  Result.ContextType := AContextType;
  Result.ProtocolVersions := [sslProtocolTLS12, sslProtocolTLS13];
  Result.PreferredVersion := sslProtocolUnknown;
  if AContextType = sslCtxServer then
    Result.VerifyMode := []
  else
    Result.VerifyMode := [sslVerifyPeer];
  Result.VerifyDepth := SSL_DEFAULT_VERIFY_DEPTH;
  Result.CipherList := SSL_DEFAULT_CIPHER_LIST;
  Result.CipherSuites := SSL_DEFAULT_TLS13_CIPHERSUITES;
  Result.Options := [
    ssoEnableSessionCache,
    ssoEnableSessionTickets,
    ssoDisableCompression,
    ssoDisableRenegotiation,
    ssoNoSSLv2,
    ssoNoSSLv3,
    ssoNoTLSv1,
    ssoNoTLSv1_1
  ];
  Result.SessionCacheSize := SSL_DEFAULT_SESSION_CACHE_SIZE;
  Result.SessionTimeout := SSL_DEFAULT_SESSION_TIMEOUT;
  Result.ClientEarlyDataEnabled := False;
  Result.ServerEarlyDataPolicy := sslEarlyDataServerReject;
  Result.ServerMaxEarlyDataSize := 0;
end;

procedure ProjectOptionBridgeBooleansIntoOptions(var AConfig: TSSLConfig);
begin
  if AConfig.EnableCompression then
    Exclude(AConfig.Options, ssoDisableCompression)
  else
    Include(AConfig.Options, ssoDisableCompression);

  if AConfig.EnableSessionTickets then
    Include(AConfig.Options, ssoEnableSessionTickets)
  else
    Exclude(AConfig.Options, ssoEnableSessionTickets);

  if AConfig.EnableOCSPStapling then
    Include(AConfig.Options, ssoEnableOCSPStapling)
  else
    Exclude(AConfig.Options, ssoEnableOCSPStapling);
end;

function ContextConfigFromSSLConfig(const AConfig: TSSLConfig): TSSLContextConfig;
var
  LConfig: TSSLConfig;
begin
  LConfig := AConfig;
  ProjectOptionBridgeBooleansIntoOptions(LConfig);

  Result := Default(TSSLContextConfig);
  Result.LibraryType := LConfig.LibraryType;
  Result.ContextType := LConfig.ContextType;
  Result.ProtocolVersions := LConfig.ProtocolVersions;
  Result.PreferredVersion := LConfig.PreferredVersion;
  Result.CertificateFile := LConfig.CertificateFile;
  Result.PrivateKeyFile := LConfig.PrivateKeyFile;
  Result.PrivateKeyPassword := LConfig.PrivateKeyPassword;
  Result.CAFile := LConfig.CAFile;
  Result.CAPath := LConfig.CAPath;
  Result.UseSystemRoots := LConfig.UseSystemRoots;
  Result.VerifyMode := LConfig.VerifyMode;
  Result.VerifyDepth := LConfig.VerifyDepth;
  Result.CipherList := LConfig.CipherList;
  Result.CipherSuites := LConfig.CipherSuites;
  Result.Options := LConfig.Options;
  Result.SessionCacheSize := LConfig.SessionCacheSize;
  Result.SessionTimeout := LConfig.SessionTimeout;
  Result.ALPNProtocols := LConfig.ALPNProtocols;
  Result.ClientEarlyDataEnabled := LConfig.ClientEarlyDataEnabled;
  Result.ServerEarlyDataPolicy := LConfig.ServerEarlyDataPolicy;
  Result.ServerMaxEarlyDataSize := LConfig.ServerMaxEarlyDataSize;
  Result.ServerEarlyDataReplayStoreFile := LConfig.ServerEarlyDataReplayStoreFile;
  Result.ServerEarlyDataReplayStoreDirectory := LConfig.ServerEarlyDataReplayStoreDirectory;
end;

function SSLConfigFromContextConfig(const AConfig: TSSLContextConfig): TSSLConfig;
begin
  Result := Default(TSSLConfig);
  Result.LibraryType := AConfig.LibraryType;
  Result.ContextType := AConfig.ContextType;
  Result.ProtocolVersions := AConfig.ProtocolVersions;
  Result.PreferredVersion := AConfig.PreferredVersion;
  Result.CertificateFile := AConfig.CertificateFile;
  Result.PrivateKeyFile := AConfig.PrivateKeyFile;
  Result.PrivateKeyPassword := AConfig.PrivateKeyPassword;
  Result.CAFile := AConfig.CAFile;
  Result.CAPath := AConfig.CAPath;
  Result.UseSystemRoots := AConfig.UseSystemRoots;
  Result.VerifyMode := AConfig.VerifyMode;
  Result.VerifyDepth := AConfig.VerifyDepth;
  Result.CipherList := AConfig.CipherList;
  Result.CipherSuites := AConfig.CipherSuites;
  Result.Options := AConfig.Options;
  Result.SessionCacheSize := AConfig.SessionCacheSize;
  Result.SessionTimeout := AConfig.SessionTimeout;
  Result.ALPNProtocols := AConfig.ALPNProtocols;
  Result.ClientEarlyDataEnabled := AConfig.ClientEarlyDataEnabled;
  Result.ServerEarlyDataPolicy := AConfig.ServerEarlyDataPolicy;
  Result.ServerMaxEarlyDataSize := AConfig.ServerMaxEarlyDataSize;
  Result.ServerEarlyDataReplayStoreFile := AConfig.ServerEarlyDataReplayStoreFile;
  Result.ServerEarlyDataReplayStoreDirectory := AConfig.ServerEarlyDataReplayStoreDirectory;
  Result.EnableCompression := not (ssoDisableCompression in AConfig.Options);
  Result.EnableSessionTickets := ssoEnableSessionTickets in AConfig.Options;
  Result.EnableOCSPStapling := ssoEnableOCSPStapling in AConfig.Options;
  Result.LogLevel := sslLogError;
  Result.LogCallback := nil;
end;

{ TSSLOperationResult }

class function TSSLOperationResult.Ok: TSSLOperationResult;
begin
  Result.Success := True;
  Result.ErrorCode := sslErrNone;
  Result.ErrorMessage := '';
end;

class function TSSLOperationResult.Err(ACode: TSSLErrorCode; const AMsg: string): TSSLOperationResult;
begin
  Result.Success := False;
  Result.ErrorCode := ACode;
  Result.ErrorMessage := AMsg;
end;

function TSSLOperationResult.IsOk: Boolean;
begin
  Result := Success;
end;

function TSSLOperationResult.IsErr: Boolean;
begin
  Result := not Success;
end;

procedure TSSLOperationResult.Expect(const AMsg: string);
begin
  if not Success then
    raise ESSLException.Create(AMsg + ': ' + ErrorMessage, ErrorCode);
end;

function TSSLOperationResult.UnwrapErr: TSSLErrorCode;
begin
  if Success then
    RaiseInvalidData('UnwrapErr on Ok value');
  Result := ErrorCode;
end;

{ TSSLDataResult }

class function TSSLDataResult.Ok(const AData: TBytes): TSSLDataResult;
begin
  Result.Success := True;
  Result.Data := AData;
  Result.ErrorCode := sslErrNone;
  Result.ErrorMessage := '';
end;

class function TSSLDataResult.Err(ACode: TSSLErrorCode; const AMsg: string): TSSLDataResult;
begin
  Result.Success := False;
  Result.Data := nil;
  Result.ErrorCode := ACode;
  Result.ErrorMessage := AMsg;
end;

function TSSLDataResult.IsOk: Boolean;
begin
  Result := Success;
end;

function TSSLDataResult.IsErr: Boolean;
begin
  Result := not Success;
end;

function TSSLDataResult.Unwrap: TBytes;
begin
  if not Success then
    raise ESSLException.Create(ErrorMessage, ErrorCode);
  Result := Data;
end;

function TSSLDataResult.UnwrapOr(const ADefault: TBytes): TBytes;
begin
  if Success then
    Result := Data
  else
    Result := ADefault;
end;

function TSSLDataResult.Expect(const AMsg: string): TBytes;
begin
  if not Success then
    raise ESSLException.Create(AMsg + ': ' + ErrorMessage, ErrorCode);
  Result := Data;
end;

function TSSLDataResult.UnwrapErr: TSSLErrorCode;
begin
  if Success then
    RaiseInvalidData('UnwrapErr on Ok value');
  Result := ErrorCode;
end;

function TSSLDataResult.IsOkAnd(APredicate: TPredicateTBytes): Boolean;
begin
  Result := Success and APredicate(Data);
end;

function TSSLDataResult.Inspect(ACallback: TProcedureOfConstTBytes): TSSLDataResult;
begin
  if Success then
    ACallback(Data);
  Result := Self;
end;

{ TSSLStringResult }

class function TSSLStringResult.Ok(const AValue: string): TSSLStringResult;
begin
  Result.Success := True;
  Result.Value := AValue;
  Result.ErrorCode := sslErrNone;
  Result.ErrorMessage := '';
end;

class function TSSLStringResult.Err(ACode: TSSLErrorCode; const AMsg: string): TSSLStringResult;
begin
  Result.Success := False;
  Result.Value := '';
  Result.ErrorCode := ACode;
  Result.ErrorMessage := AMsg;
end;

function TSSLStringResult.IsOk: Boolean;
begin
  Result := Success;
end;

function TSSLStringResult.IsErr: Boolean;
begin
  Result := not Success;
end;

function TSSLStringResult.Unwrap: string;
begin
  if not Success then
    raise ESSLException.Create(ErrorMessage, ErrorCode);
  Result := Value;
end;

function TSSLStringResult.UnwrapOr(const ADefault: string): string;
begin
  if Success then
    Result := Value
  else
    Result := ADefault;
end;

function TSSLStringResult.Expect(const AMsg: string): string;
begin
  if not Success then
    raise ESSLException.Create(AMsg + ': ' + ErrorMessage, ErrorCode);
  Result := Value;
end;

function TSSLStringResult.UnwrapErr: TSSLErrorCode;
begin
  if Success then
    RaiseInvalidData('UnwrapErr on Ok value');
  Result := ErrorCode;
end;

function TSSLStringResult.IsOkAnd(APredicate: TPredicateString): Boolean;
begin
  Result := Success and APredicate(Value);
end;

function TSSLStringResult.Inspect(ACallback: TProcedureOfConstString): TSSLStringResult;
begin
  if Success then
    ACallback(Value);
  Result := Self;
end;

{ TBuildValidationResult - Phase 2.1.2 }

class function TBuildValidationResult.Ok: TBuildValidationResult;
begin
  Result.IsValid := True;
  SetLength(Result.Warnings, 0);
  SetLength(Result.Errors, 0);
end;

class function TBuildValidationResult.WithWarnings(const AWarn: array of string): TBuildValidationResult;
var
  I: Integer;
begin
  Result.IsValid := True;
  SetLength(Result.Warnings, Length(AWarn));
  for I := 0 to High(AWarn) do
    Result.Warnings[I] := AWarn[I];
  SetLength(Result.Errors, 0);
end;

class function TBuildValidationResult.WithErrors(const AErrs: array of string): TBuildValidationResult;
var
  I: Integer;
begin
  Result.IsValid := False;
  SetLength(Result.Warnings, 0);
  SetLength(Result.Errors, Length(AErrs));
  for I := 0 to High(AErrs) do
    Result.Errors[I] := AErrs[I];
end;

procedure TBuildValidationResult.AddWarning(const AMessage: string);
var
  L: Integer;
begin
  L := Length(Warnings);
  SetLength(Warnings, L + 1);
  Warnings[L] := AMessage;
end;

procedure TBuildValidationResult.AddError(const AMessage: string);
var
  L: Integer;
begin
  IsValid := False;
  L := Length(Errors);
  SetLength(Errors, L + 1);
  Errors[L] := AMessage;
end;

function TBuildValidationResult.HasWarnings: Boolean;
begin
  Result := Length(Warnings) > 0;
end;

function TBuildValidationResult.HasErrors: Boolean;
begin
  Result := Length(Errors) > 0;
end;

function TBuildValidationResult.WarningCount: Integer;
begin
  Result := Length(Warnings);
end;

function TBuildValidationResult.ErrorCount: Integer;
begin
  Result := Length(Errors);
end;

// ============================================================================
// 版本函数实现 (P2: 接口版本控制)
// ============================================================================

function GetFafafaSSLVersion: string;
begin
  Result := FAFAFA_SSL_VERSION_STRING;
end;

function GetFafafaSSLInterfaceVersion: Integer;
begin
  Result := FAFAFA_SSL_INTERFACE_VERSION;
end;

function CheckInterfaceVersion(ARequiredVersion: Integer): Boolean;
begin
  Result := FAFAFA_SSL_INTERFACE_VERSION >= ARequiredVersion;
end;

// ============================================================================
// v1.2: 能力矩阵辅助函数实现
// ============================================================================

function IsCipherSupported(const ACaps: TSSLBackendCapabilities;
                          ACipher: TSSLCipher): Boolean;
begin
  Result := ACipher in ACaps.SupportedCiphers;
end;

function IsHashSupported(const ACaps: TSSLBackendCapabilities;
                        AHash: TSSLHash): Boolean;
begin
  Result := AHash in ACaps.SupportedHashes;
end;

function IsKeyExchangeSupported(const ACaps: TSSLBackendCapabilities;
                                AKex: TSSLKeyExchange): Boolean;
begin
  Result := AKex in ACaps.SupportedKeyExchanges;
end;

function IsFeatureStable(ASupport: TSSLFeatureSupportLevel): Boolean;
begin
  Result := ASupport = sslSupportStable;
end;

function IsFeatureUsable(ASupport: TSSLFeatureSupportLevel): Boolean;
begin
  Result := ASupport in [sslSupportStable, sslSupportExperimental];
end;

function IsFeatureDeprecated(ASupport: TSSLFeatureSupportLevel): Boolean;
begin
  Result := ASupport = sslSupportDeprecated;
end;

procedure NormalizeLegacyCapabilityBooleans(var ACaps: TSSLBackendCapabilities);
begin
  ACaps.SupportsSNI := ACaps.SNISupport <> sslSupportNone;
  ACaps.SupportsALPN := ACaps.ALPNSupport <> sslSupportNone;
  ACaps.SupportsOCSPStapling := ACaps.OCSPStaplingSupport <> sslSupportNone;
  ACaps.SupportsCertificateTransparency := ACaps.CertTransparencySupport <> sslSupportNone;
  ACaps.SupportsSessionTickets := ACaps.SessionTicketsSupport <> sslSupportNone;
end;

function IsNativeBackend(const ACaps: TSSLBackendCapabilities): Boolean;
begin
  Result := ACaps.BackendImplType = sslImplNative;
end;

function IsCLibraryBackend(const ACaps: TSSLBackendCapabilities): Boolean;
begin
  Result := ACaps.BackendImplType = sslImplCLibrary;
end;

function RequiresExternalDependencies(const ACaps: TSSLBackendCapabilities): Boolean;
begin
  Result := ACaps.RequiresExternalLibrary;
end;

function GetSecurityScore(const ACaps: TSSLBackendCapabilities): Integer;
var
  LScore: Integer;
begin
  LScore := 0;

  // 协议支持（20分）
  if ACaps.SupportsTLS13 then
    Inc(LScore, 20);

  // 安全特性（30分）
  if ACaps.HasConstantTimeOperations then
    Inc(LScore, 10);
  if ACaps.SupportsFIPSMode then
    Inc(LScore, 10);
  if ACaps.HasSecureMemoryWipe then
    Inc(LScore, 10);

  // 算法安全性（30分）
  // 支持现代安全算法
  if IsCipherSupported(ACaps, sslCipherAES256GCM) then
    Inc(LScore, 10);
  if IsCipherSupported(ACaps, sslCipherCHACHA20_POLY1305) then
    Inc(LScore, 10);
  // 不支持不安全算法（加分）
  if not IsCipherSupported(ACaps, sslCipherRC4) then
    Inc(LScore, 5);
  if not IsCipherSupported(ACaps, sslCipherDES) then
    Inc(LScore, 5);

  // 高级安全特性（20分）
  if IsFeatureStable(ACaps.OCSPStaplingSupport) then
    Inc(LScore, 10);
  if IsFeatureUsable(ACaps.CertTransparencySupport) then
    Inc(LScore, 10);

  Result := LScore;
  if Result > 100 then
    Result := 100;
end;

function GetPerformanceScore(const ACaps: TSSLBackendCapabilities): Integer;
var
  LScore: Integer;
begin
  LScore := 50;  // 基础分

  // 硬件加速（30分）
  if ACaps.HasHardwareAcceleration then
    Inc(LScore, 30);

  // SIMD 优化（10分）
  if ACaps.HasSIMDOptimization then
    Inc(LScore, 10);

  // 汇编优化（10分）
  if ACaps.HasAssemblyOptimization then
    Inc(LScore, 10);

  Result := LScore;
  if Result > 100 then
    Result := 100;
end;

function GetCapabilitiesDescription(const ACaps: TSSLBackendCapabilities): string;
var
  LLines: array of string;

  procedure AddLine(const ALine: string);
  var L: Integer;
  begin
    L := Length(LLines);
    SetLength(LLines, L + 1);
    LLines[L] := ALine;
  end;

  function Join(const ASep: string): string;
  var
    I: Integer;
  begin
    Result := '';
    for I := 0 to High(LLines) do
    begin
      if I > 0 then
        Result := Result + ASep;
      Result := Result + LLines[I];
    end;
  end;

begin
  SetLength(LLines, 0);

  // 基础信息
  AddLine('Backend: ' + LibraryTypeToString(ACaps.BackendType));
  AddLine('Version: ' + ACaps.BackendVersion);

  case ACaps.BackendImplType of
    sslImplNative:
      AddLine('Implementation: Pure FreePascal');
    sslImplCLibrary:
      AddLine('Implementation: C Library Binding');
    sslImplOSNative:
      AddLine('Implementation: OS Native API');
    sslImplHybrid:
      AddLine('Implementation: Hybrid');
  end;

  // 协议支持
  AddLine('TLS Versions: ' +
          ProtocolVersionToString(ACaps.MinTLSVersion) + ' - ' +
          ProtocolVersionToString(ACaps.MaxTLSVersion));

  // 关键特性
  if ACaps.RequiresExternalLibrary then
    AddLine('Dependencies: External library required')
  else
    AddLine('Dependencies: None (zero dependency)');

  // 评分
  AddLine('Security Score: ' + nextpas.core.text.conv.IntToStr(GetSecurityScore(ACaps)) + '/100');
  AddLine('Performance Score: ' + nextpas.core.text.conv.IntToStr(GetPerformanceScore(ACaps)) + '/100');

  // 已知问题
  if ACaps.KnownIssues <> '' then
    AddLine('Known Issues: ' + ACaps.KnownIssues);

  Result := Join(LineEnding);
end;

end.
