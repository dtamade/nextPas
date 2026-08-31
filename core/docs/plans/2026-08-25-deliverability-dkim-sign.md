# deliverability.dkim 签名增量:私钥加载 + 高层组装(2026-08-25,批次 5 增量)

## 背景

mailServer888 Phase 5b(出站 MX 直投)需要在发送前对邮件做 DKIM 签名。
现有 `nextpas.core.deliverability.dkim` 已具备验签(DkimVerify)、规范化、
hash input 构建与底层签名(DkimSign:对 header hash input 直接出签),
缺两块:

1. **PEM 私钥文件 → RSA n/d 加载**(调用方只有 PEM 文本;ASN.1 解析属
   core 能力,应用侧不得自研);
2. **完整邮件 → 带 DKIM-Signature 头邮件的高层组装**(RFC 6376 §3.5
   tag 组装 + §3.7 两段哈希流程的编排)。

本增量在**同单元**内补两个接口区函数,不新建单元(registry 无需新行)。
原版行为基线:fafafa-mail-server `sign_message_dkim`(dkim crate:
PKCS#8/PKCS#1 双形态私钥加载 + relaxed/simple 组装),只取行为契约,
实现按 core 既有资产重新组合(tls.pem 的 TPEMReader + crypto.asn1 的
TASN1Reader),不复刻 dkim crate 结构。

## 决策

### D1:DkimSignMail 高层组装;线格式钉死

职责边界:调用方给「原始邮件 + 域/选择器/h= 列表/规范化模式/算法/私钥
材料」,函数输出「DKIM-Signature 为物理第一个头的完整邮件」。组装流程:

1. h= 列表小写化;缺 `from` → False(RFC 6376 §3.5 必签 From);
   domain/selector 空 → False;
2. bh = Base64(SHA-256(DkimCanonicalizeBody(body)))(复用既有规范化);
3. 构造头值 `v=1; a=<algo>; c=<ch>/<cb>; d=<domain>; s=<selector>;
   h=<h 逗号…实为冒号列表>; bh=<b64>; b=`(**单物理行不折叠**,b= 留空
   占位);以 `DKIM-Signature: <值>` + CRLF 插入为物理第一个头,原邮件
   逐字节不动;
4. DkimBuildHeaderHashInput(b= 置空语义已有,正在签名的头物理第一)
   → 底层 DkimSign → b= 追加 base64 签名得到最终邮件。

线格式决策(黄金向量字节级依赖,改动须升版契约):

- tag 顺序固定 `v, a, c, d, s, h, bh, b`;分隔符 `; `(分号+空格);
- **不加 t=/x=**:时间戳破坏输出确定性,无法做字节级黄金向量与
  openssl 对拍;RFC 6376 中均为可选,需要时由上层自行追加后走
  DkimVerify 验证(披露项);
- h= 为冒号分隔小写名列表(RFC 6376 §3.5);h= 中列出的头不存在时
  null input 跳过(既有 DkimBuildHeaderHashInput 语义,无需特判);
- Ed25519 分支:`a=ed25519-sha256`,私钥为 32 字节 seed(RFC 8463),
  无 PEM 形态,不经 DkimLoadRsaPrivateKey。

### D2:DkimLoadRsaPrivateKey 私钥加载;组合 tls.pem + crypto.asn1

`DkimLoadRsaPrivateKey(const APemText: string; out AModulus,
APrivateExponent: TBytes; out AError: string): Boolean`

- 输入任意 PEM 文本;`nextpas.core.tls.pem.TPEMReader` 取块:
  - `pemPrivateKey`(PKCS#8 "BEGIN PRIVATE KEY"):解析
    `SEQUENCE{INTEGER 0, SEQUENCE{OID rsaEncryption(1.2.840.113549.1.1.1),
    NULL}, OCTETSTRING}`,内层 OCTETSTRING 内容按 RSAPrivateKey 再解析;
    OID 非 rsaEncryption → False(非 RSA 私钥明确拒绝);
  - `pemRSAPrivateKey`(PKCS#1 "BEGIN RSA PRIVATE KEY"):直接按
    RSAPrivateKey 解析;
  - 其余类型/无可用块 → False + 错误串;
  - `pemEncryptedPrivateKey` 或块带 Proc-Type 加密头 → False
    (口令来源属装配层策略,core 不预判解密)。
- RSAPrivateKey = `SEQUENCE{version=0, n, e, d, p, q, …}`:校验
  version=0,取 n(child 1)与 d(child 3);DER INTEGER 前导 00 剥离
  手法与 TryParseRsaSpki 一致。
- 异常即失败:EPEMException/EASN1Exception 捕获转 AError,不外泄。

### D3:测试证据链

- gen_vectors.py 扩展(密钥文件 /tmp/dkim_tv/rsa.pem 由 n/e/d 因子恢复
  引导重建,openssl 校验通过且黄金签名逐字节复现):
  - 输出 PKCS#8 与 PKCS#1 PEM 常量(CRLF 规范化);
  - 输出「DkimSignMail 黄金向量」:输入邮件 + 按 D1 线格式独立实现的
    期望签名邮件(python 侧组装规则与 D1 逐条对应,openssl dgst 对拍
    自检沿用);
- FPC 测试新增:PKCS#8/PKCS#1 双形态加载正例(n/d == 向量 n/d)、
  坏 PEM/仅证书块负例、DkimSignMail 黄金向量字节比对、
  DkimSignMail→DkimVerify 回环 dkPass(RSA + Ed25519)、h= 缺 from
  与空 domain 负例;
- HEAPTRC_GATE=1 全绿 0 unfreed。

## 披露

- Ed25519 私钥无标准 PEM 形态(seed 即私钥,DNS 发布 raw base64),
  本批仅做 RSA 私钥加载;Ed25519 继续由调用方直供 32 字节 seed 走
  DkimSignMail。
- t=/x=/i=/l= 不支持(理由见 D1);多签名叠加:上层可把上一轮输出作为
  下轮输入再次调用(新签名头插最前,旧头成为普通头,h= 可显式纳入),
  本层不做一次多条编排。
- 不做密钥文件监控/热重载(装配层职责)。
