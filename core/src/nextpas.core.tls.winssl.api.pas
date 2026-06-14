{
  nextpas.core.tls.winssl.api - Windows Schannel API 函数绑定
  
  版本: 1.0
  作者: fafafa.ssl 开发团队
  创建: 2025-10-04
  
  描述:
    绑定 Windows Schannel (SSPI) 的所有核心函数。
    这些函数来自 secur32.dll 和 crypt32.dll。
}

unit nextpas.core.tls.winssl.api;

{$mode ObjFPC}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

interface

uses Windows, nextpas.core.tls.winssl.base;

// ============================================================================
// Secur32.dll - Security Support Provider Interface (SSPI)
// ============================================================================

const
  SECUR32_DLL = 'secur32.dll';

// ----------------------------------------------------------------------------
// 凭据管理函数
// ----------------------------------------------------------------------------

// 获取凭据句柄
function AcquireCredentialsHandleW(
  pszPrincipal: PWideChar;           // 主体名称（通常为 nil）
  pszPackage: PWideChar;             // 包名称（UNISP_NAME_W）
  fCredentialUse: ULONG;             // 凭据用途（SECPKG_CRED_OUTBOUND/INBOUND）
  pvLogonId: Pointer;                // 登录 ID（通常为 nil）
  pAuthData: Pointer;                // 认证数据（PSCHANNEL_CRED）
  pGetKeyFn: Pointer;                // 获取密钥函数（通常为 nil）
  pvGetKeyArgument: Pointer;         // 获取密钥参数（通常为 nil）
  phCredential: PCredHandle;         // [out] 凭据句柄
  ptsExpiry: PTimeStamp              // [out] 过期时间
): SECURITY_STATUS; stdcall; external SECUR32_DLL name 'AcquireCredentialsHandleW';

// 释放凭据句柄
function FreeCredentialsHandle(
  phCredential: PCredHandle          // 凭据句柄
): SECURITY_STATUS; stdcall; external SECUR32_DLL;

// ----------------------------------------------------------------------------
// 安全上下文管理函数（客户端）
// ----------------------------------------------------------------------------

// 初始化安全上下文（客户端握手）
function InitializeSecurityContextW(
  phCredential: PCredHandle;         // 凭据句柄
  phContext: PCtxtHandle;            // [in/out] 上下文句柄（首次调用为 nil）
  pszTargetName: PWideChar;          // 目标服务器名称（用于 SNI）
  fContextReq: ULONG;                // 上下文请求标志
  Reserved1: ULONG;                  // 保留，必须为 0
  TargetDataRep: ULONG;              // 数据表示（SECURITY_NATIVE_DREP）
  pInput: PSecBufferDesc;            // [in] 输入缓冲区（服务器响应）
  Reserved2: ULONG;                  // 保留，必须为 0
  phNewContext: PCtxtHandle;         // [out] 新上下文句柄
  pOutput: PSecBufferDesc;           // [out] 输出缓冲区（发送给服务器）
  pfContextAttr: PULONG;             // [out] 上下文属性
  ptsExpiry: PTimeStamp              // [out] 过期时间
): SECURITY_STATUS; stdcall; external SECUR32_DLL name 'InitializeSecurityContextW';

// ----------------------------------------------------------------------------
// 安全上下文管理函数（服务器端）
// ----------------------------------------------------------------------------

// 接受安全上下文（服务器端握手）
// SSPI 这里没有 A/W 后缀导出名，必须绑定未后缀的 AcceptSecurityContext。
function AcceptSecurityContext(
  phCredential: PCredHandle;         // 凭据句柄
  phContext: PCtxtHandle;            // [in/out] 上下文句柄（首次调用为 nil）
  pInput: PSecBufferDesc;            // [in] 输入缓冲区（客户端请求）
  fContextReq: ULONG;                // 上下文请求标志
  TargetDataRep: ULONG;              // 数据表示（SECURITY_NATIVE_DREP）
  phNewContext: PCtxtHandle;         // [out] 新上下文句柄
  pOutput: PSecBufferDesc;           // [out] 输出缓冲区（发送给客户端）
  pfContextAttr: PULONG;             // [out] 上下文属性
  ptsExpiry: PTimeStamp              // [out] 过期时间
): SECURITY_STATUS; stdcall; external SECUR32_DLL name 'AcceptSecurityContext';

// ----------------------------------------------------------------------------
// 上下文操作函数
// ----------------------------------------------------------------------------

// 删除安全上下文
function DeleteSecurityContext(
  phContext: PCtxtHandle             // 上下文句柄
): SECURITY_STATUS; stdcall; external SECUR32_DLL;

// 查询上下文属性
function QueryContextAttributesW(
  phContext: PCtxtHandle;            // 上下文句柄
  ulAttribute: ULONG;                // 属性类型（SECPKG_ATTR_*）
  pBuffer: Pointer                   // [out] 属性数据缓冲区
): SECURITY_STATUS; stdcall; external SECUR32_DLL name 'QueryContextAttributesW';

// 查询凭据属性
function QueryCredentialsAttributesW(
  phCredential: PCredHandle;         // 凭据句柄
  ulAttribute: ULONG;                // 属性类型
  pBuffer: Pointer                   // [out] 属性数据缓冲区
): SECURITY_STATUS; stdcall; external SECUR32_DLL name 'QueryCredentialsAttributesW';

// ----------------------------------------------------------------------------
// 数据加密/解密函数
// ----------------------------------------------------------------------------

// 加密消息
function EncryptMessage(
  phContext: PCtxtHandle;            // 上下文句柄
  fQOP: ULONG;                       // 服务质量（通常为 0）
  pMessage: PSecBufferDesc;          // [in/out] 消息缓冲区
  MessageSeqNo: ULONG                // 消息序列号（通常为 0）
): SECURITY_STATUS; stdcall; external SECUR32_DLL;

// 解密消息
function DecryptMessage(
  phContext: PCtxtHandle;            // 上下文句柄
  pMessage: PSecBufferDesc;          // [in/out] 消息缓冲区
  MessageSeqNo: ULONG;               // 消息序列号（通常为 0）
  pfQOP: PULONG                      // [out] 服务质量
): SECURITY_STATUS; stdcall; external SECUR32_DLL;

// ----------------------------------------------------------------------------
// 其他实用函数
// ----------------------------------------------------------------------------

// 应用控制令牌到上下文
function ApplyControlToken(
  phContext: PCtxtHandle;            // 上下文句柄
  pInput: PSecBufferDesc             // 控制令牌缓冲区
): SECURITY_STATUS; stdcall; external SECUR32_DLL;

// 完成认证令牌（某些协议需要）
function CompleteAuthToken(
  phContext: PCtxtHandle;            // 上下文句柄
  pToken: PSecBufferDesc             // 令牌缓冲区
): SECURITY_STATUS; stdcall; external SECUR32_DLL;

// 释放 SSPI 分配的缓冲区
function FreeContextBuffer(
  pvContextBuffer: Pointer           // 由 SSPI 分配的缓冲区指针
): SECURITY_STATUS; stdcall; external SECUR32_DLL;

// ============================================================================
// Crypt32.dll - Windows 证书 API
// ============================================================================

const
  CRYPT32_DLL = 'crypt32.dll';

// ----------------------------------------------------------------------------
// 证书存储管理
// ----------------------------------------------------------------------------

// 打开证书存储
function CertOpenStore(
  lpszStoreProvider: LPCSTR;         // 存储提供者类型
  dwEncodingType: DWORD;             // 编码类型
  hCryptProv: HCRYPTPROV;            // 加密提供者句柄（可为 0）
  dwFlags: DWORD;                    // 标志
  pvPara: Pointer                    // 参数（取决于提供者类型）
): HCERTSTORE; stdcall; external CRYPT32_DLL;

// 打开系统证书存储
function CertOpenSystemStoreW(
  hProv: HCRYPTPROV;                 // 加密提供者句柄（可为 0）
  szSubsystemProtocol: PWideChar     // 子系统协议名称（如 'MY', 'ROOT'）
): HCERTSTORE; stdcall; external CRYPT32_DLL name 'CertOpenSystemStoreW';

// 关闭证书存储
function CertCloseStore(
  hCertStore: HCERTSTORE;            // 证书存储句柄
  dwFlags: DWORD                     // 标志（通常为 0）
): BOOL; stdcall; external CRYPT32_DLL;

// ----------------------------------------------------------------------------
// 证书操作
// ----------------------------------------------------------------------------

// 在存储中查找证书
function CertFindCertificateInStore(
  hCertStore: HCERTSTORE;            // 证书存储句柄
  dwCertEncodingType: DWORD;         // 编码类型
  dwFindFlags: DWORD;                // 查找标志
  dwFindType: DWORD;                 // 查找类型（CERT_FIND_*）
  pvFindPara: Pointer;               // 查找参数
  pPrevCertContext: PCCERT_CONTEXT   // 上一个证书上下文（首次为 nil）
): PCCERT_CONTEXT; stdcall; external CRYPT32_DLL;

// 枚举存储中的证书
function CertEnumCertificatesInStore(
  hCertStore: HCERTSTORE;            // 证书存储句柄
  pPrevCertContext: PCCERT_CONTEXT   // 上一个证书上下文（首次为 nil）
): PCCERT_CONTEXT; stdcall; external CRYPT32_DLL;

// 复制证书上下文
function CertDuplicateCertificateContext(
  pCertContext: PCCERT_CONTEXT       // 证书上下文
): PCCERT_CONTEXT; stdcall; external CRYPT32_DLL;

// 添加证书到存储
function CertAddCertificateContextToStore(
  hCertStore: HCERTSTORE;            // 证书存储句柄
  pCertContext: PCCERT_CONTEXT;      // 证书上下文
  dwAddDisposition: DWORD;           // 添加方式（CERT_STORE_ADD_*）
  ppStoreContext: PPCCERT_CONTEXT    // [out] 存储中的证书上下文（可为 nil）
): BOOL; stdcall; external CRYPT32_DLL;

// 从存储中删除证书
function CertDeleteCertificateFromStore(
  pCertContext: PCCERT_CONTEXT       // 证书上下文
): BOOL; stdcall; external CRYPT32_DLL;

// 添加编码证书到存储
function CertAddEncodedCertificateToStore(
  hCertStore: HCERTSTORE;            // 证书存储句柄
  dwCertEncodingType: DWORD;         // 编码类型
  pbCertEncoded: PByte;              // 编码的证书数据
  cbCertEncoded: DWORD;              // 数据大小
  dwAddDisposition: DWORD;           // 添加方式
  ppCertContext: PPCCERT_CONTEXT     // [out] 证书上下文（可为 nil）
): BOOL; stdcall; external CRYPT32_DLL;

// 释放证书上下文
function CertFreeCertificateContext(
  pCertContext: PCCERT_CONTEXT       // 证书上下文
): BOOL; stdcall; external CRYPT32_DLL;

// ----------------------------------------------------------------------------
// 证书验证
// ----------------------------------------------------------------------------

// 获取证书链
function CertGetCertificateChain(
  hChainEngine: HCERTCHAINENGINE;    // 链引擎句柄（可为 nil）
  pCertContext: PCCERT_CONTEXT;      // 证书上下文
  pTime: PFileTime;                  // 验证时间（nil 表示当前时间）
  hAdditionalStore: HCERTSTORE;      // 附加证书存储（可为 nil）
  pChainPara: PCERT_CHAIN_PARA;      // 链参数
  dwFlags: DWORD;                    // 标志
  pvReserved: Pointer;               // 保留，必须为 nil
  ppChainContext: PPCCERT_CHAIN_CONTEXT  // [out] 链上下文
): BOOL; stdcall; external CRYPT32_DLL;

// 释放证书链
procedure CertFreeCertificateChain(
  pChainContext: PCCERT_CHAIN_CONTEXT  // 链上下文
); stdcall; external CRYPT32_DLL;

// 创建证书链引擎
function CertCreateCertificateChainEngine(
  pConfig: PCERT_CHAIN_ENGINE_CONFIG;
  phChainEngine: PHCERTCHAINENGINE
): BOOL; stdcall; external CRYPT32_DLL;

// 释放证书链引擎
procedure CertFreeCertificateChainEngine(
  hChainEngine: HCERTCHAINENGINE
); stdcall; external CRYPT32_DLL;

// 验证证书链策略
function CertVerifyCertificateChainPolicy(
  pszPolicyOID: LPCSTR;              // 策略 OID
  pChainContext: PCCERT_CHAIN_CONTEXT;  // 链上下文
  pPolicyPara: Pointer;              // 策略参数
  pPolicyStatus: Pointer             // [out] 策略状态
): BOOL; stdcall; external CRYPT32_DLL;

// ----------------------------------------------------------------------------
// 证书名称操作
// ----------------------------------------------------------------------------

// 获取证书名称字符串
function CertGetNameStringW(
  pCertContext: PCCERT_CONTEXT;      // 证书上下文
  dwType: DWORD;                     // 名称类型
  dwFlags: DWORD;                    // 标志
  pvTypePara: Pointer;               // 类型参数
  pszNameString: PWideChar;          // [out] 名称字符串缓冲区
  cchNameString: DWORD               // 缓冲区大小（字符数）
): DWORD; stdcall; external CRYPT32_DLL name 'CertGetNameStringW';

// 将证书名称转换为字符串
function CertNameToStrW(
  dwCertEncodingType: DWORD;         // 编码类型
  pName: Pointer;                    // 证书名称结构
  dwStrType: DWORD;                  // 字符串类型
  psz: PWideChar;                    // [out] 字符串缓冲区
  csz: DWORD                         // 缓冲区大小
): DWORD; stdcall; external CRYPT32_DLL name 'CertNameToStrW';

// ----------------------------------------------------------------------------
// 证书导入/导出
// ----------------------------------------------------------------------------

// 从文件创建证书上下文
function CertCreateCertificateContext(
  dwCertEncodingType: DWORD;         // 编码类型
  pbCertEncoded: PByte;              // 证书编码数据
  cbCertEncoded: DWORD               // 数据大小
): PCCERT_CONTEXT; stdcall; external CRYPT32_DLL;

// ----------------------------------------------------------------------------
// 证书扩展操作
// ----------------------------------------------------------------------------

// 查找证书扩展
function CertFindExtension(
  pszObjId: LPCSTR;                  // 扩展 OID
  cExtensions: DWORD;                // 扩展数量
  rgExtensions: PCERT_EXTENSION      // 扩展数组
): PCERT_EXTENSION; stdcall; external CRYPT32_DLL;

// 解码对象
function CryptDecodeObject(
  dwCertEncodingType: DWORD;         // 编码类型
  lpszStructType: LPCSTR;            // 结构类型
  pbEncoded: PByte;                  // 编码数据
  cbEncoded: DWORD;                  // 数据大小
  dwFlags: DWORD;                    // 标志
  pvStructInfo: Pointer;             // [out] 解码结构
  pcbStructInfo: PDWORD              // [in/out] 结构大小
): BOOL; stdcall; external CRYPT32_DLL;

// 计算证书哈希
function CryptHashCertificate(
  hCryptProv: HCRYPTPROV;            // 加密提供者句柄（可为 0）
  Algid: ALG_ID;                     // 哈希算法 ID
  dwFlags: DWORD;                    // 标志（通常为 0）
  pbEncoded: PByte;                  // 证书编码数据
  cbEncoded: DWORD;                  // 数据大小
  pbComputedHash: PByte;             // [out] 哈希值缓冲区
  pcbComputedHash: PDWORD            // [in/out] 哈希值大小
): BOOL; stdcall; external CRYPT32_DLL;

// PFX 导入
function PFXImportCertStore(
  pPFX: PCRYPT_DATA_BLOB;            // PFX 数据 Blob
  szPassword: LPCWSTR;               // 密码
  dwFlags: DWORD                     // 标志
): HCERTSTORE; stdcall; external CRYPT32_DLL;

// ----------------------------------------------------------------------------
// 字符串编码/解码函数（用于 PEM 格式）
// ----------------------------------------------------------------------------

// 将字符串转换为二进制（例如：Base64 解码）
function CryptStringToBinaryA(
  pszString: PAnsiChar;              // 输入字符串
  cchString: DWORD;                  // 字符串长度（0 表示自动计算）
  dwFlags: DWORD;                    // 编码类型标志（CRYPT_STRING_*）
  pbBinary: PByte;                   // [out] 二进制数据缓冲区
  pcbBinary: PDWORD;                 // [in/out] 缓冲区大小
  pdwSkip: PDWORD;                   // [out] 跳过的字符数（可为 nil）
  pdwFlags: PDWORD                   // [out] 标志（可为 nil）
): BOOL; stdcall; external CRYPT32_DLL name 'CryptStringToBinaryA';

// 将二进制转换为字符串（例如：Base64 编码）
function CryptBinaryToStringA(
  pbBinary: PByte;                   // 二进制数据
  cbBinary: DWORD;                   // 数据大小
  dwFlags: DWORD;                    // 编码类型标志（CRYPT_STRING_*）
  pszString: PAnsiChar;              // [out] 字符串缓冲区
  pcchString: PDWORD                 // [in/out] 缓冲区大小（字符数）
): BOOL; stdcall; external CRYPT32_DLL name 'CryptBinaryToStringA';

// 编码对象
function CryptEncodeObject(
  dwCertEncodingType: DWORD;         // 编码类型
  lpszStructType: LPCSTR;            // 结构类型（如 X509_PUBLIC_KEY_INFO）
  pvStructInfo: Pointer;             // 要编码的结构
  pbEncoded: PByte;                  // [out] 编码后的数据缓冲区
  pcbEncoded: PDWORD                 // [in/out] 缓冲区大小
): BOOL; stdcall; external CRYPT32_DLL;

// ============================================================================
// 常量定义（补充）
// ============================================================================

// 字符串编码类型标志（用于 CryptStringToBinaryA/CryptBinaryToStringA）
const
  CRYPT_STRING_BASE64HEADER       = $00000000;  // Base64 with "-----BEGIN..." header
  CRYPT_STRING_BASE64             = $00000001;  // Base64 without header
  CRYPT_STRING_BINARY             = $00000002;  // Pure binary
  CRYPT_STRING_BASE64REQUESTHEADER = $00000003; // Base64 with request header
  CRYPT_STRING_HEX                = $00000004;  // Hex string
  CRYPT_STRING_HEXASCII           = $00000005;  // Hex ASCII
  CRYPT_STRING_BASE64_ANY         = $00000006;  // Base64 (any format)
  CRYPT_STRING_ANY                = $00000007;  // Auto-detect format
  CRYPT_STRING_HEX_ANY            = $00000008;  // Hex (any format)
  CRYPT_STRING_BASE64X509CRLHEADER = $00000009; // Base64 with X.509 CRL header
  CRYPT_STRING_HEXADDR            = $0000000A;  // Hex with address
  CRYPT_STRING_HEXASCIIADDR       = $0000000B;  // Hex ASCII with address
  CRYPT_STRING_HEXRAW             = $0000000C;  // Hex raw

  CRYPT_STRING_NOCRLF             = $40000000;  // Don't include CR/LF in output
  CRYPT_STRING_NOCR               = $80000000;  // Don't include CR in output

  // PFX 导入标志
  CRYPT_EXPORTABLE                = $00000001;
  CRYPT_USER_PROTECTED            = $00000002;
  CRYPT_MACHINE_KEYSET            = $00000020;
  CRYPT_USER_KEYSET               = $00001000;
  PKCS12_IMPORT_RESERVED_MASK     = $FFFF0000;
  PKCS12_PREFER_CN_KSP            = $00000100;
  PKCS12_ALWAYS_CN_KSP            = $00000200;
  PKCS12_ALLOW_OVERWRITE_KEY      = $00004000;
  PKCS12_NO_PERSIST_KEY           = $00008000;
  PKCS12_INCLUDE_EXTENDED_PROPERTIES = $00000010;

// 结构类型常量（用于 CryptEncodeObject/CryptDecodeObject）
const
  X509_PUBLIC_KEY_INFO            = LPCSTR(8);   // 公钥信息结构类型
  X509_CERT                       = LPCSTR(1);   // 证书结构类型
  X509_CERT_TO_BE_SIGNED          = LPCSTR(2);   // 待签名证书结构

implementation

// 实现部分为空，所有函数都是外部导入

end.
