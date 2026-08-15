# nextpas.core.mail

邮件域基础模块（L3）。当前承载：RFC 5322 邮件地址模型与校验、邮件消息/附件载体类型。
SMTP 客户端、IMAP/POP3 客户端、MIME 编码解码按批次扩展（见 `docs/plans/` 与本目录 CONTRACT.md）。

## 使用

```pascal
uses
  nextpas.core.mail;

var
  LAddr: TMailAddress;
begin
  if TMailAddress.TryParse('"Tester" <test@example.com>', LAddr) then
    WriteLn(LAddr.Full);          // test@example.com
  LAddr := TMailAddress.Parse('bad-address');  // 抛 EParseError
end;
```

## 模块结构

- `nextpas.core.mail.base` — 载体类型（TMailAddress / TMailAttachment / TMailMessage）+ record 方法实现
- `nextpas.core.mail` — 门面（re-export）
- `nextpas.core.mail.address` —（规划）地址解析/校验实现子模块（随 SMTP 批次拆出）
- `nextpas.core.mail.smtp` / `mime` —（规划）SMTP 客户端 / MIME 编解码

## 校验规则（务实 RFC 5321/5322 子集）

| 项 | 规则 |
|---|---|
| 总长 | ≤ 254（RFC 5321） |
| 本地部分 | ≤ 64；dot-atom 子集 `[A-Za-z0-9.+-_]`，点不连续/不首尾 |
| 域名 | 逐 label ≤ 63，总长 ≤ 253；字母数字+连字符，连字符不首尾；支持 `[1.2.3.4]` 字面量 |
| 规范化 | trim + 全小写；支持 `"Display" <addr>` 形式 |

> `nextpas.core.validation.TValidator.Email` 仍是最简形式（仅检查 `@` 位置）；
> mail 模块提供严格校验后，后续批次评估让 validator 委托 mail（跨模块改动，另行立项）。

## 测试与基准

- `tests/nextpas.core.mail/test_mail_address` — 地址解析/校验契约测试（focused gate）
- 基准随 SMTP/MIME 批次补充（benchmarks/nextpas.core.mail/）