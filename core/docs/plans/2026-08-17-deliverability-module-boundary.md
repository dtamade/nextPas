# deliverability 模块边界设计(2026-08-17,批次 5)

## 背景

mailServer888 Phase 2-2b(入站校验链)需要 SPF/DKIM/DMARC 校验;Phase 5
(出站投递)需要 DKIM 签名。BACKPORT §3 批次 5 预定义为 `core.deliverability`
(纯算法,不含业务表和策略执行),前置依赖(批次 4 `nextpas.core.dns` TXT
查询)已于 2026-08-17 landing。本设计确定模块边界与范围取舍。

参考实现:原版 fafafa-mail-server(Rust)`src/smtp/{dkim,spf,dmarc}.rs`(1882 行)。

## 决策

### D1:独立 L2 模块,不并入 mail 家族

SPF/DKIM/DMARC 是协议算法,与具体邮件产品无关(§1 判定标准:换产品仍要);
且 mail 家族已是 L3 桥接(批次 1/2),把算法塞进 L3 违反分层。design-conventions
§15 L2 表本批补 `deliverability` 行,registry 补登记(同批次 4 dns 的先例)。

### D2:纯算法 + 可注入 DNS 查询,不硬绑 dns 模块

三件算法(SPF/DKIM/DMARC)都需要 DNS:TXT(DKIM 密钥/SPF 记录/DMARC 记录)、
A/AAAA(a 机制)、MX(mx 机制)。为可测性与解耦,定义单方法组接口
`IDeliverabilityDns`(QueryTXT/QueryA/QueryMX),由调用方注入:

- 生产路径:`NewDeliverabilityDns(ADns: IDnsResolver)` 适配器桥接批次 4 模块
  (resolver 的 A/AAAA 经 `Query` 的 dqA/dqAAAA 投影)。
- 测试路径:内存 mock(黄金向量注入,不触网)。

### D3:DKIM 验签 rsa-sha256 + ed25519-sha256;签名两者都做,私钥以字节入参

RFC 6376(rsa-sha256)+ RFC 8463(ed25519-sha256)。core 底座:

| 需求 | core 复用 |
|---|---|
| SHA-256 | `nextpas.core.hash` `NewSHA256: IHasher` |
| Base64 | `nextpas.core.encoding.base64` `Base64Decode/Encode` |
| RSA 验签(s^e mod n) | `nextpas.core.crypto.bigint` `TryBigIntModExpFromUnsignedBytes` |
| RSA 签名(EM^d mod n) | `nextpas.core.crypto.bigint` `TryRSAModExpSignPurePascal` |
| Ed25519 验签/签名 | `nextpas.core.crypto.ed25519` `Ed25519Verify/Sign` |
| SPKI DER 解析(公钥) | `nextpas.core.crypto.asn1` `TASN1Node` |

签名 API 以 (modulus, privateExponent) 原始字节入参(上层负责 PEM/PKCS#8 等
私钥容器解析;core pkcs8 仅解加密容器,裸 PKCS#1 私钥解析留反哺候选)。
RFC 8463 §5.4:ed25519-sha256 的签名输入 = 规范化后的 header 哈希输入原文
(不再单独 SHA-256),与 rsa-sha256 的输入相同。

### D4:SPF 机制/宏子集(契约级声明)

- 机制全实现:`all` `ip4` `ip6` `a`(含 `a/` `a:` `a:域/` )`mx`(同形)
  `include` `exists` `redirect`;`ptr` 不支持(permerror 语义?——按 RFC 7208
  ptr 属可选机制,遇 ptr 返回 permerror 会过度拒绝;折中:遇 ptr 视为 no-match,
  契约注明)。qualifier `+`/`-`/`~`/`?` 全支持。
- 宏展开:支持 `%{s} %{l} %{o} %{d} %{i} %{p} %{v} %{h} %{c} %{r} %{t}`
  纯替换(无 deferral、无 `r` 翻转、无分隔符/截断修饰)——覆盖真实世界
  `exists:%{i}.xxx` 黑名单场景;不支持的修饰按字面输出并在契约标注。
- 查询上限:RFC 7208 §4.6.4 的 10 次 DNS 查询硬上限(含 include/redirect 递归)。
- 结果语义:pass/fail/softfail/neutral/none/temperror/permerror。

### D5:组织域 = 末两 label 启发式

DMARC relaxed 对齐需要组织域。本批沿用原版启发式(取最后两个 label),
不引入 Public Suffix List(大依赖,列为反哺候选)。契约标注局限。

### D6:与原版 Rust 的差异(修正/增强)

| 项 | 原版 | 本批 |
|---|---|---|
| h= 含 dkim-signature | 重复追加该头(潜在错误) | 已用则不重复追加 |
| simple body 规范化 | 字符串替换 `\n`→`\r\n` 再清 `\r\r\n`(对 CRLF 输入可能错) | 按字节流处理(CRLF/LF 双输入黄金向量) |
| exists 机制 | 不支持(跳过) | 支持(含宏展开) |
| 宏 | 不支持 | 常用宏纯替换 |
| lookup 上限 | 10(递归处逐点检查) | 集中检查 + 契约 INV |
| DKIM 签名 | 无 | ed25519-sha256 + rsa-sha256(字节私钥入参) |

## 交付形态(四件套 + 门面)

```
src/nextpas.core.deliverability.base.pas   类型/枚举/对齐/组织域/IDeliverabilityDns
src/nextpas.core.deliverability.spf.pas    RFC 7208 子集
src/nextpas.core.deliverability.dkim.pas   RFC 6376/8463 验签+签名
src/nextpas.core.deliverability.dmarc.pas  RFC 7489
src/nextpas.core.deliverability.pas        门面 + 编排(TDeliverabilityVerdict)+ DNS 适配器
tests/nextpas.core.deliverability/test_deliverability_{spf,dkim,dmarc,integration}/
docs/deliverability/CONTRACT.md
```

依赖(registry allowed deps):L0-L1 + `crypto`/`hash`/`encoding`/`dns` owner。
**不反向依赖**上层模块;不触网络(网络由注入的 DNS 接口承担)。

## 测试策略

- SPF:机制黄金向量(全 qualifier/机制/CIDR/域名-CIDR 组合)+ 宏展开 +
  mock DNS(include 递归、redirect、a/mx 解析、10 次上限、NXDOMAIN→none、
  无 v=spf1→none、DNS 错误→temperror、畸形记录→permerror)。
- DKIM:RFC 6376 §A 规范化黄金向量(simple/relaxed 头体)+ RFC 8463 §A
  ed25519 样例密钥验签 + 自洽 rsa-sha256 签名/验签(openssl 生成 1024-bit
  测试密钥嵌入,SPKI DER 公钥)+ 阴性(正文篡改 fail、坏 base64 permerror、
  无签名 neutral、空 p= 吊销 permerror、DNS 错误 temperror)。
- DMARC:记录解析(全部标签)、对齐(relaxed/strict)、pct 边界、组织域、
  精确域→组织域回退、编排(SPF/DKIM 组合 → verdict)。
- 集成:完整消息全链(SPF pass + DKIM pass → DMARC pass;SPF fail + DKIM
  none → DMARC fail policy 应用)。
- 收尾:registry 登记 + source-contract + heaptrc 门禁 0 unfreed。

## 风险与局限(契约级)

1. 组织域非 PSL(见 D5)。
2. 宏无 deferral/翻转/分隔符修饰(见 D4)。
3. `l=`(body 长度限制)不实现,整 body 参与 hash(与原版一致)。
4. 多签名策略:取第一个可解析 DKIM-Signature(与原版一致)。
5. SPF `ptr` 机制按 no-match 处理(非 permerror)。
