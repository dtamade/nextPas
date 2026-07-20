# text + text.unicode 开发地图

**导航真源**（防止无编号「继续下一轮」）。  
**Owner**：Claude · **UCD**：16.0.0 · **顺序**：M1 → M2 → M3 串行；M4/M5 默认关闭。

相关：[CONTRACT](CONTRACT.md) · [SCORECARD](SCORECARD.md) · [README](README.md) · [../CONTRACT.md](../CONTRACT.md)

---

## 北极星

| 维度 | 标准 |
|------|------|
| 正确性 | 官方 UCD/UCA **离线 harness 0-fail** |
| 对标 | Go `unicode`/`x/text` + Rust `unicode-*` 质量条 |
| 架构 | 双门面：`text`（日常 UTF-8）+ `text.unicode`（真源）；**硬 NextLine ≠ UAX#14** |
| 工程 | worktree-only；0-fail 合 main；generators 可复现 |

**岸线**：M0 算法绿 + **M1 产品化** → 核心层就绪；之后只整岛推进，禁止碎片漂流。

---

## 里程碑状态

| 里程碑 | 状态 | 完成定义（摘要） |
|--------|------|------------------|
| **M0** 官方算法绿 | ✅ | Norm/Grapheme/Word/Sentence/Line软/BidiL2/Collation/Case+tr·az/EAW 全绿 |
| **M1** 产品化与导航 | ✅ | ROADMAP + SCORECARD + `make gate` + CONTRACT 对齐 + 门面差异表；QC 对非法 UTF-8 不误短路 |
| **M2** 日常 API | ✅ | Word-boundary Title；`clLithuanian`；COOKBOOK |
| **M3** SCORECARD v2→v3 | ✅ | v2 冻结 + M3b–e 优化 + **P2-2 v3** 全量 |
| **M3b** Collate Compare 热路径 | ✅ | ASCII CE 表 + 实例缓冲；Compare ≈1.12× Go |
| **M3c** Collate 通用加速 | ✅ | contraction 快拒 + 已 NFD 跳过二次分解；ensure 脚本 |
| **M3d** GetSortKey 热路径 | ✅ | count 版 ElementsToSortKey；无 CE 切片拷贝；BMP-Latin 1.20× |
| **M3e** 门面+Segment 基线 | ✅ | text.UTF8ToTitle(Words)；SCORECARD C6 冻结 |
| **M4 / Phase 2** | 🔄 | **重新开放**：对标 Go/Rust 的下一阶段整岛（非「收工」） |
| **M5** CLDR / L3+ | 🔒 | 仍默认关闭；书面需求再开 |

## Phase 2 地图（2026-07-20 重规划）

目标：在 **UCD 官方门禁已绿** 之上，把「能写应用 / 对标 Go unicode + x/text」缺口按整岛推进。

| 岛 | 状态 | 完成定义 |
|----|------|----------|
| **P2-0** 岸线加固 | ✅ | 重放 M3d/M3e；ensure 含 TitleWords+ACount |
| **P2-1** BinaryProperty 扩展 | ✅ | PropList 高价值属性 + gen 表 + test_property；对标 Go `unicode.Is*` |
| **P2-2** SCORECARD v3 | ✅ | 全量重跑 + Width 测项 + C6/C7 库存 |
| **P2-3** Bidi 视觉序 | ✅ | ReorderBidiVisually / ApplyBidiVisualOrder / InvertBidiIndexMap |
| **P2-4** Script_Extensions | ✅ | GetScriptExtensions / HasScript + gen |
| **P2-5** UTS#46 IDNA | ✅ | 大 epic：Punycode + ToASCII/ToUnicode（net 拉票可优先） |
| **P2-6** CLDR Collation | 🔒 | 仍深水 |


## Phase 3 地图（可用性 / 对标加深）

| 岛 | 状态 | 完成定义 |
|----|------|----------|
| **P3-0** 岸线 + 错误模型 + 门面矩阵 | ✅ | re-land P2-3/4 + P0；`TIDNAErrorKind`；门面矩阵 v2；ROADMAP 与 tip 对齐 |
| **P3-1** IDNA MappingTable | ✅ | UTS#46 IdnaMappingTable 全表 + Nontransitional Map 步 |
| **P3-2** 统一 text 错误策略 | ✅ | [ERROR_MODEL.md](../ERROR_MODEL.md) L0/L1/L2 真源 |
| **P3-3** 可用性 P1 文档 | ✅ | API-REF 对齐 tip；SCORECARD 导航；IDNA kind 样板；RTL 边界 |
| **P2-6** CLDR Collation | 🔒 | 仍深水 |


**纪律不变**：worktree；gate 0-fail；一 land 一岛；禁止无编号碎片。


---

## M0 已交付（岸在身后）

| 域 | harness / 契约 |
|----|----------------|
| UAX#15 | `test_conformance_normalize` |
| UAX#29 G/W/S | `test_conformance_{grapheme,word,sentence}` |
| UAX#14 软 | `test_conformance_line`；`LineBreakByteLen` / `NextLineBreak` |
| 硬行 | `NextLine` / `SegmentLines`（仅硬分隔符） |
| UAX#9 ≤L2 | `test_conformance_bidi*` |
| UCA DUCET | `test_conformance_collate` NON_IGNORABLE+SHIFTED |
| Case | `test_conformance_case` C/F/S + Special 无条件 + Final_Sigma + **tr/az** |
| EAW | 真表；LB19a F\|W\|H；列宽 A→1 |

---

## 明确不做（岸外）

- CLDR collation / tailored segment  
- Bidi L3/L4（除非 TUI 书面 epic）  
- 扫表式「UCD 属性全集」  
- 硬 `NextLine` 改成 UAX#14  
- 无地图编号的碎片 land  

---

## 双门面差异（v2 · P3-0）

| 能力 | `text.pas` | `text.unicode.pas` |
|------|------------|---------------------|
| Trim/Split/Join/Format/conv | ✅ 日常 | — |
| UTF8ToUpper/Lower/CaseFold（root） | ✅ | ✅ |
| **TCaseLocale / locale 重载** | ❌ 仅 unicode | ✅ tr/az/lt |
| UTF8ToTitle / TitleWords | ✅ root | ✅ + locale |
| NFC/NFD / IsNormalized* / QC | ✅ 子集 | ✅ 全套 |
| Segment G/W/S + 硬/软 Line | — | ✅ |
| Bidi resolve L2 + **visual 序** | — | ✅ |
| Collate DUCET | — | ✅ |
| BinaryProperty / Script / **SCX** / Block / EAW | — | ✅ |
| IDNA / Punycode + **TIDNAErrorKind** | — | ✅ |
| GraphemeNext / DisplayWidth | ✅（委托 unicode） | 底层 |

**约定**：locale Case、segment/bidi/collate/IDNA/属性全集 → **`nextpas.core.text.unicode`**。  
`text` 保持轻量日常 UTF-8；不透传 locale / IDNA。

---

## M1 交付清单

- [x] 本文件 `ROADMAP.md`
- [x] `SCORECARD.md`（准则 + 链到 bench RESULTS）
- [x] `make -C core/tests/nextpas.core.text.unicode gate`
- [x] `text/CONTRACT` 与 `unicode/CONTRACT` 测试清单对齐
- [x] README 索引 + generators 一条龙
- [x] QC 非法 UTF-8 不误短路（gate 露出 test_normalize 红已修）
- [x] land main + worktree 清理

---

## M2 交付（已完成）

1. ✅ `UTF8ToTitleWords`：UAX#29 Word_Break 词首 title + 词内 lower  
2. ✅ `clLithuanian`：More_Above / After_Soft_Dotted / 00CC·00CD·0128  
3. ✅ COOKBOOK + CONTRACT 更新；locale 仍 **仅 unicode 门面**（`text` 不透传）  

---

## M3 范围

- 整串级 vs Go 对齐；Norm/Case/Segment/Collate/Width/IsAscii 各类 ≥1 行  
- 准则示例：ASCII ≤1.0× Go；已 NFC BMP ≤1.0×；denorm NFC 目标 ≤1.2×  
- 仅 🔴 项开优化 PR  

---

## M4 backlog（拉票）

| 项 | 触发 |
|----|------|
| 更多 BinaryProperty / Emoji | regex 等 |
| Script_Extensions | 多脚本检测 |
| UTS#46 IDNA + Punycode | net 国际化域名 |
| UTF-16/32 | 互操作 |
| Bidi 布局辅助（非 L3） | TUI RTL |

---

## 一键验证

```bash
make -C core/tests/nextpas.core.text.unicode gate
```

UCD 升版（generators 一条龙）见 [README.md](README.md#ucd-升版一条龙)。

---

## 纪律

1. 会话声明 `正在执行 Mx`  
2. 无完成定义不开工  
3. 一 land ≈ 一里程碑  
4. 新想法进本文件 backlog，不直接变代码  

---

## 变更

| 日期 | 说明 |
|------|------|
| 2026-07-21 | **P3-3**：可用性 P1 — API-REFERENCE / SCORECARD tip / IDNA kind / RTL |
| 2026-07-21 | **P3-2**：ERROR_MODEL L0/L1/L2 统一错误策略 |
| 2026-07-21 | **P3-1**：IdnaMappingTable 全表 + ApplyIdnaMap / GetIdnaMapStatus |
| 2026-07-21 | **P3-0**：re-land P2-3/4+P0；TIDNAErrorKind；门面矩阵 v2 |
| 2026-07-20 | P2-5：Punycode + IDNA ToASCII/ToUnicode |
| 2026-07-20 | Phase2 重规划 + P2-1 BinaryProperty 扩展 |
| 2026-07-20 | M3e：text 门面 TitleWords + C6 基线 |
| 2026-07-20 | M3d：GetSortKey 去拷贝；Compare≈0.99× / SortKey BMP 1.20× |
| 2026-07-20 | M3c：contraction 快拒 + QuickCheckNFD 短路；text-unicode-ensure.sh |
| 2026-07-20 | M3b：Collate Compare ≈1.12× Go |
| 2026-07-20 | M2：TitleWords + clLithuanian |
| 2026-07-20 | M1：地图入仓 + gate + 门面差异表 |
