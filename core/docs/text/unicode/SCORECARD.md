# text.unicode — 性能 SCORECARD v2

**冻结**：2026-07-20 · **M3**  
**环境**：Linux x86_64 · Xeon E5-2696 v4 · FPC 3.3.1 -O2 · Go `x/text`  
**nextPas**：`make -C core/benchmarks/nextpas.core.text.unicode smoke`  
**Go**：`cd core/benchmarks/nextpas.core.text.unicode/compare_go && go test -bench=. -benchtime=500ms`  
**比率**：`nextPas_ns / Go_ns`（&lt;1 更快）

---

## 通过准则（冻结）

| ID | 类别 | 准则 |
|----|------|------|
| C1 | ASCII CaseFold / ToUpper 整串 | ≤ **1.0×** |
| C2 | NFC ASCII-200 | ≤ **1.0×** |
| C3 | NFC BMP-Latin（已 NFC / QC 短路） | ≤ **1.0×** |
| C4 | NFD BMP-Latin | ≤ **1.0×** |
| C5 | Collate SortKey | ≤ **2.0×** |
| C5b | Collate Compare 跨串 | ≤ **2.0×**（未达标 = 🔴 债） |
| C6 | Segment NextGrapheme | 仅基线 |

**纪律**：只对 🔴 开优化；`make gate` 正确性优先。

---

## v2 冻结数字（2026-07-20 smoke）

| 操作 | nextPas | Go | 比率 | 判定 |
|------|--------:|---:|-----:|------|
| UTF8CaseFoldSimple ASCII-200 | 424 | 2514 ToUpper | **0.17×** | ✅ C1 |
| UTF8CaseFoldSimple BMP-Latin-50 | 1255 | 1924 | **0.65×** | ✅ |
| NFC ASCII-200 | 60 | 273 | **0.22×** | ✅ C2 |
| NFC BMP-Latin-50 | 1140 | 2716 | **0.42×** | ✅ C3 |
| NFD BMP-Latin-50 | 3449 | 20316 | **0.17×** | ✅ C4 |
| NFC BMP-CJK-50 | 17 | 2229 | **0.01×** | ✅ |
| QuickCheckNFC ASCII-200 | 51 | 361 | **0.14×** | ✅ |
| IsAsciiString ASCII-200 | 48 | — | — | ✅ 内部 |
| NextGrapheme ASCII-200 | 106 | (RuneCount 264) | 不同测项 | ⬜ C6 |
| GetSortKey ASCII-50 | **2275** | 4931 | **0.46×** | ✅ C5 (M3b) |
| GetSortKey BMP-Latin-50 | 14898 | 7943 | **1.88×** | ✅ C5 |
| Collate Compare ASCII-50 vs 200 | **4000** | 3579 | **1.12×** | ✅ C5b (M3b) |

### 汇总

- ✅ C1–C4、SortKey、**C5b Compare ≤2×**（M3b ≈1.12×）  
- 维护：优化后必须更新本表 tip + 数字  

---

## 测项纪律

1. 整串 API；禁止逐码点 vs 整串混比  
2. 真实 UTF-8  
3. 已 NFC vs denorm 分开报  

---

## 变更

| 日期 | 说明 |
|------|------|
| 2026-07-20 | **M3b** Collate ASCII 表 + 缓冲复用：Compare **1.12×** Go |
| 2026-07-20 | **M3 v2 冻结** 同机数字 + Collate Compare 债 |
| 2026-07-20 | M1 准则入仓 |
