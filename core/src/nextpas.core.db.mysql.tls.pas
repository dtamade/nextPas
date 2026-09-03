unit nextpas.core.db.mysql.tls;

{** @desc MySQL TLS 校验桥接（显式例外 Owner=tls，见 design-conventions §范式例外 / CONTRACT §2.1/§2.21）：单元名置于 `db.mysql` 仅承载 DSN `sslmode/sslca` 验证面，校验复用 `nextpas.core.tls` 标准面与 `bytes.ops` 单源零拷贝（BYTES_OPS_SINGLE_SOURCE 门禁，CLIENT_SSL/MYSQL_OPT_SSL_* 单源于 db.mysql.base 仅复用，持续防平行校验器漂移）；Parse/Validate 均 inline 零拷贝视图比对（TByteSpan+SpanEqualIgnoreCase），纯函数无句柄不丢，不自建平行校验器；建连由 db.mysql.adapter 经 my_options 直达，L2→L2 单向。业务以 CONTRACT 为准、缺能力先反哺 tls owner。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.bytes.ops,
  nextpas.core.db.mysql.base,
  nextpas.core.tls.base;



type
  { MySQL sslmode 词汇（对齐 libpq/mysql 5.7+ 约定） }
  TDbMysqlSslMode = (
    mmsmDisabled,       { sslmode=disabled — 明文 }
    mmsmPreferred,      { sslmode=preferred — 有则加密，无则明文（缺省兼容） }
    mmsmRequired,       { sslmode=required — 必须加密，不校验 CA }
    mmsmVerifyCA,       { sslmode=verify-ca — 加密 + CA 校验，不校验主机名 }
    mmsmVerifyIdentity, { sslmode=verify-full/verify-identity — 加密 + CA + 主机名 }
    mmsmUnknown
  );

  { TLS 选项记录化（DSN ssl* 键聚合，纯数据无句柄） }
  TDbMysqlTlsOptions = record
    Mode: TDbMysqlSslMode;
    CaFile: string;
    CaPath: string;
    CertFile: string;
    KeyFile: string;
    Cipher: string;
    CrlFile: string;
    CrlPath: string;
    Enforce: Boolean; { MYSQL_OPT_SSL_ENFORCE 语义：强制加密 }
    function IsTlsEnabled: Boolean; inline;
    function NeedsCa: Boolean; inline;
  end;

{ 零拷贝解析：`AValue` 视图比对（`bytes.ops` 单源 `SpanEqualIgnoreCase`），不分配 LowerCase 拷贝 }
function ParseMysqlSslMode(const AValue: string; out AMode: TDbMysqlSslMode): Boolean; inline;
{ 薄转发映射：MySQL 词汇 → `nextpas.core.tls` 标准 `TSSLVerifyMode`（Owner=tls） }
function MysqlTlsToVerifyMode(AMode: TDbMysqlSslMode): TSSLVerifyModes; inline;
function MysqlTlsToVerifyFlags(AMode: TDbMysqlSslMode): TSSLCertVerifyFlags; inline;
{ 校验：`sslmode` 与 CA/主机名组合的诚实校验（复用 tls 语义），纯函数零分配失败信息 }
function ValidateMysqlTlsOptions(const AOpts: TDbMysqlTlsOptions; out AError: string): Boolean; inline;
{ 快路径判据：是否值得为 TLS 走校验/握手（inline 零成本，阈值复用 Owner） }
function MysqlTlsShouldVerify(const AOpts: TDbMysqlTlsOptions): Boolean; inline;

implementation

uses
  nextpas.core.base,
  nextpas.core.text.conv;

function IsEmptyStr(const S: string): Boolean; inline;
begin
  Result := Length(S) = 0;
end;

function StrEqualsIgnoreCase(const A, B: string): Boolean; inline;
var
  LA, LB: TByteSpan;
begin
  if Length(A) <> Length(B) then
    Exit(False);
  if Length(A) = 0 then
    Exit(True);
  LA.Data := PByte(@A[1]);
  LA.Len := Length(A);
  LB.Data := PByte(@B[1]);
  LB.Len := Length(B);
  Result := SpanEqualIgnoreCase(LA, LB);
end;

function TDbMysqlTlsOptions.IsTlsEnabled: Boolean; inline;
begin
  Result := Mode <> mmsmDisabled;
end;

function TDbMysqlTlsOptions.NeedsCa: Boolean; inline;
begin
  Result := Mode in [mmsmVerifyCA, mmsmVerifyIdentity];
end;

function ParseMysqlSslMode(const AValue: string; out AMode: TDbMysqlSslMode): Boolean; inline;
begin
  { perf: inline 薄转发，零拷贝视图比对（SpanEqualIgnoreCase），bytes.ops 单源，不经 LowerCase 分配 }
  if IsEmptyStr(AValue) then
  begin
    AMode := mmsmPreferred;
    Exit(True);
  end;
  if StrEqualsIgnoreCase(AValue, 'disabled') then
    AMode := mmsmDisabled
  else if StrEqualsIgnoreCase(AValue, 'preferred') or StrEqualsIgnoreCase(AValue, 'prefer') then
    AMode := mmsmPreferred
  else if StrEqualsIgnoreCase(AValue, 'required') or StrEqualsIgnoreCase(AValue, 'require') then
    AMode := mmsmRequired
  else if StrEqualsIgnoreCase(AValue, 'verify-ca') or StrEqualsIgnoreCase(AValue, 'verify_ca') then
    AMode := mmsmVerifyCA
  else if StrEqualsIgnoreCase(AValue, 'verify-full') or StrEqualsIgnoreCase(AValue, 'verify_full') or
          StrEqualsIgnoreCase(AValue, 'verify-identity') or StrEqualsIgnoreCase(AValue, 'verify_identity') then
    AMode := mmsmVerifyIdentity
  else
  begin
    AMode := mmsmUnknown;
    Exit(False);
  end;
  Result := True;
end;

function MysqlTlsToVerifyMode(AMode: TDbMysqlSslMode): TSSLVerifyModes; inline;
begin
  { Owner=tls 标准校验面：按 mysql 语义映射到 tls 校验模式 }
  case AMode of
    mmsmDisabled:   Result := [sslVerifyNone];
    mmsmPreferred:  Result := [sslVerifyNone];
    mmsmRequired:   Result := [sslVerifyNone]; { 加密不校验：verify none + enforce }
    mmsmVerifyCA:   Result := [sslVerifyPeer];
    mmsmVerifyIdentity: Result := [sslVerifyPeer];
  else
    Result := [sslVerifyNone];
  end;
end;

function MysqlTlsToVerifyFlags(AMode: TDbMysqlSslMode): TSSLCertVerifyFlags; inline;
begin
  case AMode of
    mmsmVerifyIdentity: Result := []; { 严格主机名校验：默认不跳过 hostname }
    mmsmVerifyCA:       Result := [sslCertVerifyIgnoreHostname]; { 仅 CA，不校验主机名 }
  else
    Result := [sslCertVerifyIgnoreHostname, sslCertVerifyAllowSelfSigned];
  end;
end;

function ValidateMysqlTlsOptions(const AOpts: TDbMysqlTlsOptions; out AError: string): Boolean; inline;
begin
  AError := '';
  if AOpts.Mode = mmsmUnknown then
  begin
    AError := 'unknown sslmode (expected disabled/preferred/required/verify-ca/verify-identity)';
    Exit(False);
  end;
  if AOpts.NeedsCa and IsEmptyStr(AOpts.CaFile) and IsEmptyStr(AOpts.CaPath) then
  begin
    AError := 'sslmode ' + IntToStr(Ord(AOpts.Mode)) + ' requires sslca or sslcapath (CA bundle)';
    Exit(False);
  end;
  { 其余组合为 advisory 合法：preferred/required 无 CA 亦可，disabled 忽略所有 ssl* 键 }
  Result := True;
end;

function MysqlTlsShouldVerify(const AOpts: TDbMysqlTlsOptions): Boolean; inline;
begin
  Result := AOpts.NeedsCa;
end;

end.
