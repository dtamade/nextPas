# nextpas.core.text 代码契约

**模块路径**：`core/src/nextpas.core.text*.pas`
**层级**：L1（依赖 L0: base, exception 等）
**Owner**：Claude（AI 负责）
**最后更新**：2026-08-31
**版本**：1.5

---

## 1. 接口契约

### 1.1 子模块架构

```
text.base          ← TStringArray, 基础常量
text.char          ← 字符分类/转换
text.utf8          ← UTF-8 编码/解码
text.view          ← TStringView（非拥有字符串视图）
text.builder       ← IStringBuilder（可变字符串构建）
text.strings       ← 字符串操作（Trim/Pad/Split/Join/Contains...）
text.conv          ← 类型↔字符串转换 owner（IntToStr/Format/SameText/Trim 等；sysutils 仅门面）
text.format        ← 格式化引擎
text.compare       ← 字符串比较（Ordinal/Natural/CaseInsensitive）
text.escape        ← C/JSON/HTML 转义/反转义
text.grapheme      ← Grapheme 宽度门面（边界委托 unicode.segment）
text.width         ← 显示宽度计算（EastAsianWidth）
text.number        ← 高性能数字→字符串（Ryu 算法）
text.scan          ← 字符串扫描/解析（新增 ScanPredicateTable 通用谓词+字面量 VecWidth 表驱动单源，零拷贝 via bytes.ops/simd.vec，js.eval/json 共享复用，L1 single source）
text.unicode       ← Unicode 门面（属性/case/normalize/segment/collate…）
  ├── types / base / utils
  ├── props          ← GC / BinaryProperty / GCB / InCB
  ├── casefold
  ├── normalize      ← NFC/NFD/NFKC/NFKD
  ├── segment        ← UAX#29 + GraphemeClusterByteLen 真源
  ├── collate        ← DUCET
  ├── script / block
  └── data
text.pas           ← UTF-8 日常门面（re-export 常用符号）
```

完整 Unicode 契约见 [`unicode/CONTRACT.md`](unicode/CONTRACT.md)。

### 1.2 核心类型

| 类型 | 文件 | 说明 |
|------|------|------|
| `TStringView` | view.pas | 非拥有 UTF-8 视图 (PChar + Len) |
| `IStringBuilder` | builder.pas | 可变字符串构建接口 |
| `TStringArray` | base.pas | `array of string` 别名 |
| `TGraphemeResult` | grapheme.pas | `ByteLen` / `Width` / `CodePoints` |

### 1.3 关键函数

| 领域 | 函数 | 说明 |
|------|------|------|
| 转换 | IntToStr, TryStrToInt, FloatToStr… | 类型↔字符串 |
| 操作 | Trim, Split, Join, Contains… | 日常字符串 |
| 比较 | TextEqual, TextEqualCanonical, TextEqualCaseFold | 语义比较 |
| 宽度 | StringDisplayWidth, CodepointWidth | 终端列宽 |
| Grapheme | GraphemeNext | 边界 + 宽度（边界=UAX#29 真源） |
| Unicode | NFC/NFD, HasBinaryProperty, Segment*… | 见 unicode 门面 |

### 1.4 Grapheme 真源

- **边界**：`unicode.segment.GraphemeClusterByteLen`（门面 re-export）
- **宽度**：`text.grapheme.GraphemeNext` 在边界结果上叠 `CodepointWidth` + VS16/keycap/RI 启发式
- **GB9c**：InCB 已实现；`GraphemeNext` 与 `NextGraphemeCluster` 边界一致

---

## 2. 不变量

- **[INV-1]** `TStringView.Data` 指向有效 UTF-8 内存（调用方保证生命周期）
- **[INV-2]** `IStringBuilder.ToString` 返回完整构建结果的拷贝
- **[INV-3]** 非法 UTF-8 按 U+FFFD 处理（消费 1 字节），不崩溃
- **[INV-4]** `TextWidth` / `StringDisplayWidth` 返回显示列数（全角=2，半角=1）
- **[INV-5]** Unicode 16.0：NormalizationTest + GraphemeBreakTest 官方全量门禁绿
- **[INV-6]** grapheme 边界单一真源（见上）

---

## 3. 错误处理

**真源**：[ERROR_MODEL.md](ERROR_MODEL.md)（P3-2 三层模型 L0/L1/L2）。

| 场景 | 策略 | 层 |
|------|------|-----|
| StrToInt 无效输入 | 抛 `EConvertError` | L1 |
| TryStrToInt 无效输入 | 返回 False | L1 |
| TStringView 非空但 Data=nil | 抛 `EInvalidArgument` | L1 |
| 非法 UTF-8（normalize/case/segment…） | U+FFFD，消费 1 字节，不抛 | L0 |
| JSON unescape 缓冲 API | `out TUnescapeError` | L1 枚举 |
| IDNA（仅 unicode 门面） | `TIDNAErrorKind`，不抛 | L2 |

详见 [ERROR_MODEL.md](ERROR_MODEL.md)。

---

## 4. 线程安全

| 类型 | 线程安全 | 说明 |
|------|----------|------|
| 纯函数 | ✅ | 无共享状态 |
| TStringView | ✅ | 非拥有视图 |
| IStringBuilder | ❌ | 调用方同步 |
| Unicode 属性表 | ✅ | 只读数据 |

---

## 5. 内存管理

- `TStringView`：非拥有，零分配
- `IStringBuilder`：内部 buffer 动态增长
- 纯函数：返回新分配的 string
- Unicode 属性表：编译时内嵌 (`.inc`)

---

## 6. 测试覆盖

| 子系统 | 路径 / 套件 |
|--------|-------------|
| text 子模块 | `core/tests/nextpas.core.text.*/`（view/scan/utf8/width/grapheme…） |
| unicode **一键门禁** | `make -C core/tests/nextpas.core.text.unicode gate`（M1） |
| unicode 手写 | `test_case` `test_data` `test_enhance` `test_grapheme_uax29` `test_normalize` `test_property` `test_collate` |
| unicode 官方 | Norm / Grapheme / Word / Sentence / Line / Bidi×2 / Collate / Case 全套 `test_conformance_*` |

```bash
make -C core/tests/nextpas.core.text.unicode gate
make -C core/tests/nextpas.core.text.grapheme/test_grapheme clean test
make -C core/tests/nextpas.core.text.width/test_text_width clean test
```

导航地图：[unicode/ROADMAP.md](unicode/ROADMAP.md) · 性能：[unicode/SCORECARD.md](unicode/SCORECARD.md)

---

## 7. 已知限制

1. Collation 仅 DUCET（无 CLDR locale tailor）；UCA CollationTest 官方全绿
2. Line 硬 `NextLine` 非 UAX#14；软 `LineBreakByteLen` 已官方 LineBreakTest 全绿
3. UAX#9 Bidi 至 L2 官方 harness 全绿（L3/L4 不在门禁）
4. 无 CLDR tailored grapheme/word
5. East_Asian_Width 真表（UCD 16.0）；LB19a F|W|H；列宽 A→1
6. **locale Case**（tr/az）与完整 segment/bidi/collate 在 **`text.unicode`**；`text` 门面仅 root case 子集（见 ROADMAP 门面表）
7. `UTF8ToTitle` = 逐码点 title；**`UTF8ToTitleWords`** = 词首 title（M2）

---

## 变更记录

| 日期 | 版本 | 变更描述 |
|------|------|----------|
| 2026-07-21 | 1.4 | P3-2：错误策略真源 ERROR_MODEL.md；修正 View 异常类型 |
| 2026-07-20 | 1.3 | M1：gate 入口 + ROADMAP/SCORECARD；门面/限制与 unicode live 对齐 |
| 2026-07-20 | 1.2 | LineBreak UAX#14 官方全绿；硬/软 Line 双语义 |
| 2026-07-19 | 1.1 | Conformance + grapheme 真源 + GB9c；测试表与子模块清单对齐 live |
| 2026-07-01 | 1.0 | 初始版本 |
| 2026-08-31 | 1.5 | 时效刷新：批量校正至 2026-08-31，统一 AL1 口径 | core-docs |
