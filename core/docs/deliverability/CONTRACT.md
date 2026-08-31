# CONTRACT: nextpas.core.deliverability(L2)

状态:v1.2(v1.0 冻结 + RFC 精确化 + 签名增量)| 日期:2026-08-25 | 归属:批次 5
边界设计:`docs/plans/2026-08-17-deliverability-module-boundary.md`;
签名增量:`docs/plans/2026-08-25-deliverability-dkim-sign.md`

## 1. 职责与边界

- 提供邮件投递性校验算法:SPF(RFC 7208 子集)、DKIM 验签/签名
  (RFC 6376 rsa-sha256 + RFC 8463 ed25519-sha256)、DMARC(RFC 7489),
  以及三者编排成 `TDeliverabilityVerdict`。
- **纯算法**:不触网络(DNS 经注入的 `IDeliverabilityDns`)、不做策略执行
  (存库/弹窗/退信由调用方决定)。
- 供 mailServer888 Phase 2-2b(入站校验链)与 Phase 5(出站签名)消费。
- **不做**:Public Suffix List(组织域用末两 label 启发式)、SPF 宏的
  deferral/翻转/分隔符/截断修饰、DKIM `l=`(body 长度限制)、多签名策略
  (取第一个可解析签名)、SPF `ptr` 机制(视为 no-match)。

## 2. 类型与接口(冻结)

```pascal
TSpfResult = (srPass, srFail, srSoftFail, srNeutral, srNone,
              srTempError, srPermError);
TDkimResult = (dkPass, dkFail, dkNeutral, dkTempError, dkPermError);
TDmarcPolicy = (dmpNone, dmpQuarantine, dmpReject);
TDmarcResult = (dmPass, dmFail, dmNone, dmTempError);
TAlignMode = (amRelaxed, amStrict);
TDkimAlgo = (daRsaSha256, daEd25519Sha256);
TCanonMode = (cmSimple, cmRelaxed);

TDkimSignature = record
  Algo: TDkimAlgo;
  Domain, Selector: string;
  SignedHeaders: array of string;   { h= 小写, 原序 }
  CanonHeader, CanonBody: TCanonMode;
  Signature: TBytes;                { b= base64 解码 }
  BodyHash: TBytes;                 { bh= base64 解码 }
end;

TDmarcRecord = record
  Policy: TDmarcPolicy;             { p= }
  SubdomainPolicy: TDmarcPolicy;    { sp=; 缺省=p }
  SPFAlign, DKIMAlign: TAlignMode;  { aspf=/adkim=; 缺省 relaxed }
  Pct: Byte;                        { pct=; 缺省 100 }
  RUA, RUF: string;                 { rua=/ruf= 原始值 }
end;

IDeliverabilityDns = interface
  ['{6F1D6F1D-4D7C-4E31-9100-4100000000D5}']
  function QueryTXT(const AName: string; const ATimeoutMs: Int32;
    out ATexts: array of string; out AError: string): Boolean;
  function QueryA(const AName: string; const ATimeoutMs: Int32;
    out AIps: array of string; out AError: string): Boolean;
  function QueryMX(const AName: string; const ATimeoutMs: Int32;
    out AHosts: array of string; out AError: string): Boolean;
end;
```

- `QueryA` 返回 A 与 AAAA 合并的文本 IP 列表(SPF `a` 机制需双栈),
  `QueryTXT` 查询失败但 `AError` 含 `nxdomain`/`no records` 语义时表示
  记录不存在(调用方按「无记录」而非「网络错误」处理;与批次 4 dns 的
  `IDnsResolver.QueryTXT` 错误串语义一致)。

## 3. 函数(冻结)

```pascal
{ SPF: 评估 domain 对 clientIP 的 SPF 记录; 无记录→srNone; DNS 错误→srTempError }
function SpfCheck(const ADns: IDeliverabilityDns; const ADomain: string;
  const AClientIP: string; const ASender: string; const ATimeoutMs: Int32;
  out AError: string): TSpfResult;

{ DKIM 解析: 从 DKIM-Signature 头值解析 tag=value }
function DkimParseSignature(const AValue: string; out ASig: TDkimSignature;
  out AError: string): Boolean;

{ DKIM 规范化 }
function DkimCanonicalizeBody(const ABody: string; const ACanon: TCanonMode): string;
function DkimCanonicalizeHeader(const AName, AValue: string;
  const ACanon: TCanonMode): string;

{ DKIM 验签: 校验 body hash 后取 `<selector>._domainkey.<domain>` TXT 的 p= 验签 }
function DkimVerify(const ADns: IDeliverabilityDns; const ARawMail: string;
  const ATimeoutMs: Int32; out AError: string): TDkimResult;

{ DKIM 签名(底层): 对 header 哈希输入原文签名(rsa: EM^d mod n; ed25519: RFC 8463) }
function DkimSign(const AHdrHashInput: TBytes; const AAlgo: TDkimAlgo;
  const ARsaModulus, ARsaPrivateExponent: TBytes;
  const AEd25519PrivateKey: TBytes; out ASignature: TBytes;
  out AError: string): Boolean;

{ RSA 私钥 PEM 加载(v1.2): 无加密 PKCS#8 "BEGIN PRIVATE KEY" 与传统
  PKCS#1 "BEGIN RSA PRIVATE KEY"; 加密块/非 RSA OID/坏 DER → False }
function DkimLoadRsaPrivateKey(const APemText: string; out AModulus,
  APrivateExponent: TBytes; out AError: string): Boolean;

{ DKIM 签名组装(v1.2, RFC 6376 §3.5/§3.7): bh → 构造 DKIM-Signature
  (物理第一个头, b= 空占位)→ 底层签名 → 填 b= 输出完整邮件;
  h= 须含 from。线格式钉死: 单物理行, tag 序 v,a,c,d,s,h,bh,b, "; "
  分隔, 不加 t=/x=(确定性输出, 黄金向量依赖); Ed25519 私钥为 32 字节
  seed 直传(无 PEM 形态) }
function DkimSignMail(const ARawMail: string; const ADomain,
  ASelector: string; const ASignedHeaders: array of string;
  const ACanonHeader, ACanonBody: TCanonMode; const AAlgo: TDkimAlgo;
  const ARsaModulus, ARsaPrivateExponent: TBytes;
  const AEd25519PrivateKey: TBytes; out ASignedMail: string;
  out AError: string): Boolean;

{ DMARC 记录解析/校验 }
function DmarcParseRecord(const ARecord: string; out ADmarc: TDmarcRecord;
  out AError: string): Boolean;
function DmarcCheck(const ADns: IDeliverabilityDns; const AFromDomain: string;
  const ASpfResult: TSpfResult; const AEnvelopeSenderDomain: string;
  const ADkimResult: TDkimResult; const ADkimSigningDomain: string;
  const ATimeoutMs: Int32; out AError: string): TDmarcResult;

{ 编排 }
TDeliverabilityVerdict = record
  SPF: TSpfResult; SpfError: string;
  DKIM: TDkimResult; DkimError: string;
  DKIMSigningDomain: string;
  DMARC: TDmarcResult; DmarcError: string;
end;
function CheckDeliverability(const ADns: IDeliverabilityDns;
  const ARawMail: string; const AFromDomain, AEnvelopeSenderDomain,
  AClientIP: string; const ATimeoutMs: Int32): TDeliverabilityVerdict;

{ 组织域: 末两 label 启发式(非 PSL); 不足两 label 返回原串 }
function OrganisationalDomain(const ADomain: string): string;

{ DNS 适配器: 桥接批次 4 的 IDnsResolver }
function NewDeliverabilityDns(const ADns: IDnsResolver): IDeliverabilityDns;
```

- `DkimSign` 的 rsa 分支需 `ARsaModulus`/`ARsaPrivateExponent` 均非空;
  ed25519 分支需 `AEd25519PrivateKey`(32 字节);`AAlgo` 决定使用哪个参数。
- `DkimVerify` 失败(非 pass/neutral)时 `AError` 给原因串
  (body-mismatch/bad-b64/key-not-found/revoked/unsupported-algo/…)。
- `DkimLoadRsaPrivateKey`(v1.2)失败时 `AError` 给原因串
  (pem-parse/encrypted/not-supported/invalid-der);加密私钥明确拒绝,
  不做口令解密(口令来源属装配层策略)。
- `DkimSignMail`(v1.2)`h=` 缺 from 或 domain/selector 空 → False;
  组装规则与线格式见 plan 2026-08-25 D1(黄金向量逐字节锁定)。

## 4. 不变量(INV-*)

- **INV-1 SPF 查询上限**:单次评估(含 include/redirect 递归)累计 DNS
  查询 ≤ 10(RFC 7208 §4.6.4),超出 → srPermError。
- **INV-2 SPF 记录判定**:TXT 中首个 `v=spf1` 前缀记录为 SPF 记录(严格
  大小写敏感 `v=spf1`);无 → srNone;**多条 → srPermError**(RFC 7208
  §4.5);TXT 查询网络错误 → srTempError。
- **INV-3 SPF 畸形**:记录**全量语法预校验**(RFC 7208 §4.6,任何机制
  语法错误 → srPermError,即使前面已匹配;`all` 之后的机制忽略不校验);
  `exists` 的宏展开失败 → srPermError(不静默 no-match)。
- **INV-4 SPF include/redirect**:include 目标 pass → match;temperror →
  srTempError;permerror/none → srPermError;其余 → no-match。机制
  domain-spec(a/mx/include/exists/redirect)先宏展开再使用;redirect 仅
  在机制全部不匹配时生效,目标无记录 → srPermError;记录含 `all` 时
  redirect 忽略(RFC 7208 §5.1/§6.1)。
- **INV-5 DKIM body hash**:先算 body 规范化 + SHA-256 与 bh= 比较,
  不匹配 → dkFail 且不再查密钥。
- **INV-6 DKIM 头哈希输入**:h= 依序取头(RFC 6376 §3.7 顺序),名字匹配
  大小写不敏感;**h= 中不存在的头 = null input(不贡献字节,不报错)**;
  正在验证的 DKIM-Signature = 物理第一个,h= 里的 dkim-signature 指其它
  签名(跳过自己);随后若自身未被 h= 使用则追加(b= 值置空,其它 tag 原样);
  各头按 c= 规范化后 CRLF 连接,**末尾无 CRLF**。simple 头规范化 =
  **原封不动**(RFC 6376 §3.4.1,含冒号两侧空白与大小写);relaxed =
  名小写去 WSP + 折叠展开 + WSP 压缩。
- **INV-7 DKIM 验签**:rsa-sha256 = SPKI 解析 → s^e mod n → PKCS#1 v1.5
  (0x00 0x01 0xFF* 0x00 DigestInfo-SHA256)常量时间比较;ed25519-sha256 =
  64 字节签名对输入原文 `Ed25519Verify`。公钥解析失败/算法不支持 →
  dkPermError;DNS 查询错误 → dkTempError。
- **INV-8 DKIM 密钥与头校验**:`v=` 必需且 = 1,缺失/非 1 → dkPermError;
  `h=` 必须含 from(RFC 6376 §6.1.1)→ 否则 dkPermError;查询
  `<selector>._domainkey.<domain>` TXT,按 tag-list 解析:首 tag 为 `v=`
  且 ≠ DKIM1 的记录丢弃,`p=` 可位于任意 tag 位置(非仅记录开头);
  空 p= → dkPermError(吊销);无 DKIM-Signature 头 → dkNeutral。
- **INV-9 DMARC 解析**:`v=DMARC1` 必须;`p=` 缺失/未知或其它语法错误
  → 按 RFC 7489 §6.6.3 视同未发布 → dmNone(原因记入 `AError`)。记录
  查询无 → dmNone;**同层多条 v=DMARC1 记录 → 终止发现 → dmNone**;DNS
  查询网络错误 → dmTempError。
- **INV-10 DMARC 对齐**:relaxed = 组织域相等;strict = 小写精确相等。
  SPF pass 且对齐 或 DKIM pass 且对齐 → dmPass;否则 dmFail(策略)。
- **INV-11 DMARC 回退**:精确域无记录 → 查组织域;组织域也无 → dmNone。
- **INV-12 输入校验**:空 From 域 → dmNone;空客户端 IP → srPermError;
  base64 非法 → 对应 permerror;void 查询(NXDOMAIN/空应答)≤ 2,超出
  → srPermError;单 MX 的地址记录 > 10 → srPermError(RFC 7208 §4.6.4)。
- **INV-13 线程独立**:无共享可变状态,并发调用相互隔离。

## 5. 概要

- SPF:RFC 7208 子集(机制 all/ip4/ip6/a/mx/include/exists/redirect,ptr
  视为 no-match;qualifier +/-/~/?;宏 %{s}%{l}%{o}%{d}%{i}%{p}%{v}%{h}
  %{c}%{r}%{t} 纯替换,不支持修饰符(见 §7 差异表);查询上限 10;void
  上限 2)。
- DKIM:RFC 6376 + 8463;simple/relaxed 头体规范化;`c=` 支持 `relaxed`
  单段(= relaxed/simple);v= 必需;验签 + 签名。
- DMARC:RFC 7489;p/sp/aspf/adkim/pct/rua/ruf;对齐;编排。
- 消费者:mailServer888 Phase 2-2b / Phase 5。

## 6. 变更记录

| 日期 | 版本 | 变更 |
|---|---|---|
| 2026-08-17 | v1.0 | 冻结(批次 5) |
| 2026-08-17 | v1.1 | 实现阶段按 RFC 原文精确化(见 INV 修订与 §7 差异表);测试:
  SPF 32 / DKIM 22 / DMARC 13 / integration 5 全绿 + heaptrc 0 unfreed |
| 2026-08-25 | v1.2 | DKIM 签名增量:`DkimLoadRsaPrivateKey`(PKCS#8/PKCS#1
  双形态)+ `DkimSignMail`(高层组装,线格式钉死,不加 t=/x=);见
  `docs/plans/2026-08-25-deliverability-dkim-sign.md`;测试 dkim 28 用例全绿 +
  heaptrc 0 unfreed(此前头部曾误标 v1.1 与表内冲突,本次定版并补行) |

## 7. 与原版(Rust)及 RFC 的差异表

- SPF 宏修饰符(`%{s1-}` 等)不支持:RFC 7208 §7.1 允许,但主流记录
  极少使用;遇到 → srPermError,不作静默错配(原版 Rust 亦未实现)。
- SPF `ptr` 机制:视为 no-match(RFC 建议 do not use;原版亦如此)。
- SPF `%{p}`/`%{r}`/`%{h}` 宏:无 PTR/HELO 上下文,展开为 `unknown`
  (RFC 7208 §7 允许在无法计算时如此)。
- SPF 机制查询统一走 QueryA(A+AAAA 合并,双栈等价);RFC 按连接族选择
  A/AAAA,合并查询不改变匹配语义。
- DMARC `sp=` 非法值:按未设置处理(跟随 p=);RFC 7489 §6.6.3 要求
  rua 存在时按 p=none 处理,简化后不影响策略结论(差异幅度小)。
- DMARC `pct<100`:采样执行策略由调用方完成,本模块仅返回
  dmPass/dmFail(策略字段携带 pct)。
- DKIM `i=` tag 与 §3.10 SDID/AUID 域约束:未实现(原版 Rust 亦未实现);
  缺省按「无 i=」处理,不影响已验证签名的 d= 输出。
- DKIM 多签名:仅验证首个 DKIM-Signature(RFC §6.1 允许任选顺序)。
