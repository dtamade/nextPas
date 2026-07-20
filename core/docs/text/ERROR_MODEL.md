# text / text.unicode — 统一错误策略（P3-2）

**真源**：本文件。`CONTRACT.md` 与 `unicode/CONTRACT.md` 仅摘要并链接至此。  
**范围**：`nextpas.core.text*` + `nextpas.core.text.unicode*`（不含 CLDR / Transitional IDNA）。

---

## 1. 三层模型（选层不混用）

| 层 | 适用 | 失败形态 | 调用方约定 |
|----|------|----------|------------|
| **L0 流式 / 文本处理** | UTF-8 解码、normalize、case、segment、bidi、collate 输入串 | **不抛**；非法序列 → **U+FFFD**（消费 1 字节）或空结果 | 假定「尽力处理」；需要严格合法性时先 `UTF8IsValid` |
| **L1 转换 / 参数** | `text.conv` StrTo*、Format、View/Builder 非法参数 | **抛异常**；Try* 返回 Boolean | 直线代码用 Str*；分支用 Try* |
| **L2 协议 / 域名** | IDNA / Punycode | **不抛**；`TIDNAErrorKind`（+ 可选 string 兼容） | 检查 kind / error 串；成功才使用 Result |

**原则**

1. **同一调用路径只用一种失败形态**（FFFD *或* 异常 *或* kind 码），不混「有时抛有时 FFFD」。
2. **默认不抛**的路径（L0/L2）永不静默返回「看起来合法」的错误数据：L2 失败时 `Result=''` 且 kind≠`idnaOk`。
3. **Try\*** 仅在调用方需区分成功/失败分支时提供（与 core 全局错误策略一致）。
4. **locale / CLDR / Transitional IDNA** 不在本模型扩展范围内（仍锁定）。

---

## 2. L0 — 流式 Unicode（U+FFFD）

| API 族 | 非法 UTF-8 | 空输入 | 备注 |
|--------|------------|--------|------|
| `UTF8Decode` / 迭代器 | ByteLen=0 或替换策略依调用点 | 无数据 | 底层原语 |
| `NFC/NFD/NFKC/NFKD`、`UTF8ToUpper/Lower/...` | 非法字节 → U+FFFD 路径，**不短路误判 QC Yes** | 空串 → 空串 | QuickCheck 前须有效 UTF-8 才 Yes |
| `Segment*` / `Next*` / Bidi resolve | 同 FFFD 消费 | 空 → 空段/空 levels | 硬 `NextLine` ≠ UAX#14 |
| `UnicodeCollator.Compare` / SortKey | 按码点流（含 FFFD） | 空 vs 空 = 0 | 仅 DUCET |
| 属性 `Get*` / `HasBinaryProperty` | 对码点本身；越界码点按表默认 | — | 不解析 UTF-8 |

**代理码点**（U+D800..DFFF）：不作为合法 Unicode 标量；出现在解码层时按无效序列处理（与 harness skip 代理一致）。

**不变量（与 text CONTRACT INV-3 对齐）**：L0 路径 **不崩溃、不抛**；不因坏 UTF-8 进入未定义行为。

---

## 3. L1 — 转换与参数（异常 / Try）

| API | 失败 | 类型 / 码 |
|-----|------|-----------|
| `StrToInt` / `StrToFloat` | raise | `EConvertError` |
| `TryStrToInt*` / `TryStrToFloat*` / `StrToIntDef` | False / 默认值 | 无异常 |
| `TextFormat` 参数不足/非法 | raise | `EInvalidArgument` / `EOverflow` |
| `TStringView.Create` 非空但 Data=nil | raise | `EInvalidArgument` |
| `IStringBuilder` 溢出 / nil 源 | raise | `EOverflow` / `EOutOfMemory` / `EInvalidArgument` |
| JSON unescape buffer API | `out AError: TUnescapeError` | `ueNone` 成功；其它为错误类（**不抛**） |

**选用规则**

- 解析用户/配置输入且可恢复 → **Try\*** 或 `*Def`。
- 内部不变量被破坏（nil 视图、format 参数错）→ **raise**。
- Escape 热路径需要错误分类且无堆异常 → **out enum**（`TUnescapeError`）。

---

## 4. L2 — IDNA（结构化 kind）

| API | 成功 | 失败 |
|-----|------|------|
| `IDNAToASCII/ToUnicode(..., out AKind)` | Result=域名；`AKind=idnaOk` | Result=''；`AKind≠idnaOk` |
| `IDNAToASCII/ToUnicode(..., out AError: string)` | `AError=''` | `AError=IDNAErrorKindName(kind)` |
| 无 out 重载 | 同成功路径；失败 Result=''（**丢失 kind**，仅便利） | 生产代码优先 kind 重载 |
| `ApplyIdnaMap` | 映射后 UTF-8 | kind=`idnaDisallowed` / `idnaInvalidUtf8` 等 |
| `PunycodeEncode/Decode` | 非空串或合法空策略 | 失败 Result=''（**无 kind**；由 IDNA 层包装） |

### `TIDNAErrorKind` 一览

| Kind | 含义 |
|------|------|
| `idnaOk` | 成功 |
| `idnaEmptyDomain` / `idnaEmptyLabel` | 空域/空标签 |
| `idnaInvalidDomain` | 分割失败（如连续点） |
| `idnaInvalidAsciiLabel` | 非 LDH / 首尾 `-` |
| `idnaNfcFailed` | NFC 后不可用 |
| `idnaPunycodeEncodeFailed` / `DecodeFailed` | Punycode 失败 |
| `idnaEmptyAceBody` | `xn--` 无 body |
| `idnaAceLabelTooLong` / `idnaDomainTooLong` | 长度 >63 / >253 |
| `idnaDisallowed` | MappingTable disallowed（含 STD3 规则下的 STD3_*） |
| `idnaInvalidUtf8` | Map 步遇到非法 UTF-8 |

**策略钉死（P3-1）**：Nontransitional + UseSTD3ASCIIRules=True；**无** Transitional、**无** 完整 Validity Criteria 扩展报告。

---

## 5. 门面路由

| 能力 | 错误层 | 入口 |
|------|--------|------|
| Trim/Split/Format/conv | L1 | `nextpas.core.text` |
| root case / NFC 子集 / width | L0 | `text` → 委托 unicode |
| locale case / segment / bidi / collate | L0 | `text.unicode` |
| IDNA / Punycode / Map | L2 | `text.unicode` only |

`text` **不** re-export IDNA；避免日常门面混入 L2 协议语义。

---

## 6. 与 Go / Rust 对照（预期）

| 场景 | nextPas | Go（参考） | Rust（参考） |
|------|---------|------------|--------------|
| 坏 UTF-8 在 strings | FFFD（L0） | 常 error 或 `utf8.Valid` 先检 | `from_utf8` → Result |
| 数字解析 | Str 抛 / Try 布尔 | `strconv` error | `parse` → Result |
| IDNA | kind 码，不抛 | `idna` Profile error | `idna` Result/Error |

差异是刻意的：Pascal 热路径 L0 对齐「Unicode 处理不因坏输入中断」；L2 给 net 清晰枚举。

---

## 7. 反模式（禁止）

- 在 L0 normalize/segment 内 `raise` 因坏 UTF-8  
- IDNA 失败返回「部分 ACE」且 kind=ok  
- 用 SysUtils 异常消息字符串做稳定协议（应用 `TIDNAErrorKind` / `TUnescapeError`）  
- 在 `text` 门面静默吞掉 convert 错误  

---

## 8. 验证入口

```bash
# L0 非法 UTF-8 / QC
make -C core/tests/nextpas.core.text.unicode/test_normalize test
# L1 convert
make -C core/tests/nextpas.core.text/test_text_conv test
# L2 IDNA kinds + mapping
make -C core/tests/nextpas.core.text.unicode/test_idna test
```

---

## 9. RTL / 编译器无关（P3-3）

**原则**：仅 `nextpas.core.system` 可直接 `uses` FPC RTL 单元；其余模块（含 text/unicode **生产与测试**）走 `nextpas.core.*`。

| 允许 | 禁止 |
|------|------|
| `System.Move` / `System.Copy` / `System.Length` / `SetLength` / `ReallocMem` 等 **语言内建** | `uses SysUtils, Classes, Windows, BaseUnix, Unix, …` |
| `nextpas.core.sync`（`IMutex`）、`nextpas.core.fs`、`nextpas.core.exception` 等 | 业务代码包装 FPC `TStream`/`TStringList` 作长期 API |
| 门面 re-export 的框架类型 | 测试里「图省事」拉 SysUtils |

审计：`rg '\b(SysUtils|Classes)\b'` 于 `core/src/nextpas.core.text*` 与对应 tests 应为 **零 unit 引用**（变量名 `Classes` 等假阳性除外）。

---

## 变更

| 日期 | 说明 |
|------|------|
| 2026-07-21 | **P3-3**：§9 RTL 边界（uses 禁止 / System 内建允许） |
| 2026-07-21 | **P3-2** 初版：L0/L1/L2 统一策略真源 |
