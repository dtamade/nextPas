# text.unicode — 性能 SCORECARD v3

**冻结**：2026-07-20 · **P2-2**  
**环境**：Linux x86_64 · Xeon E5-2696 v4 · FPC 3.3.1 -O2 · Go `x/text` + std  
**nextPas**：`make -C core/benchmarks/nextpas.core.text.unicode smoke`  
**Go**：`cd core/benchmarks/nextpas.core.text.unicode/compare_go && go test -bench=. -benchtime=500ms`  
**比率**：`nextPas_ns / Go_ns`（<1 更快）。Segment/Width 为 **库存基线**（非 unfair 对标）。

---

## 通过准则

| ID | 类别 | 准则 |
|----|------|------|
| C1 | ASCII CaseFold / ToUpper 整串 | ≤ **1.0×** |
| C2 | NFC ASCII-200 | ≤ **1.0×** |
| C3 | NFC BMP-Latin | ≤ **1.0×** |
| C4 | NFD BMP-Latin | ≤ **1.0×** |
| C5 | Collate SortKey | ≤ **2.0×** |
| C5b | Collate Compare 跨串 ASCII | ≤ **2.0×** |
| C6 | Segment | 库存基线冻结（非 vs RuneCount） |
| C7 | Width | 库存基线冻结 |

---

## v3 同机数字（P2-2）

### Norm / Case（公平对标）

| 操作 | nextPas ns | Go ns | 比率 | 判定 |
|------|----------:|------:|-----:|------|
| UTF8CaseFoldSimple ASCII-200 | **443** | 2291 ToUpper | **0.19×** | ✅ C1 |
| UTF8CaseFoldSimple BMP-Latin-50 | **1266** | 1526 | **0.83×** | ✅ |
| NFC ASCII-200 | **58** | 251 | **0.23×** | ✅ C2 |
| NFC BMP-Latin-50 | **1175** | 2658 | **0.44×** | ✅ C3 |
| NFD BMP-Latin-50 | **3467** | 19078 | **0.18×** | ✅ C4 |
| NFC BMP-CJK-50 | **16** | 2128 | **0.01×** | ✅ |
| QuickCheckNFC ASCII-200 | **53** | 324 | **0.16×** | ✅ |
| IsAsciiString ASCII-200 | **48** | — | — | ✅ 内部 |

### Collate（公平对标）

| 操作 | nextPas ns | Go ns | 比率 | 判定 |
|------|----------:|------:|-----:|------|
| Compare ASCII-50 vs 200 | **4063** | 3705 | **1.10×** | ✅ C5b |
| GetSortKey ASCII-50 | **1485** | 3903 | **0.38×** | ✅ C5 |
| GetSortKey BMP-Latin-50 | **11051** | 6662 | **1.66×** | ✅ C5 |

### Segment / Width（库存）

| 操作 | nextPas ns | 注 | 判定 |
|------|----------:|----|------|
| NextGrapheme ASCII-200 | **106** | UAX#29 步进 | ✅ C6 |
| NextGrapheme BMP-CJK-50 | **105** | | ✅ C6 |
| NextWord BMP-CJK-50 | **450** | | ✅ C6 |
| NextLine ASCII-200（硬） | **3525** | 非 UAX#14 | ✅ 备注 |
| StringDisplayWidth ASCII-200 | **280** | EAW 列宽 | ✅ C7 |
| StringDisplayWidth BMP-CJK-50 | **74** | | ✅ C7 |

---

## 汇总

- **全绿对标项**：C1–C5b（Compare 1.10× ≤2.0×）
- **库存冻结**：C6 Segment、C7 Width
- **债（非阻塞）**：GetSortKey BMP-Latin 1.66×
- **下一默认**：文档可用性 **P3-3** 后 → **Idle**（可选拉票：P3-4 IDNA Validity 子集；CLDR 仍锁）
- 注：P3-0…P3-3 为文档/错误/IDNA 岛，**不改**本表 perf 数字

---

## 跑法

```bash
make -C core/benchmarks/nextpas.core.text.unicode smoke
cd core/benchmarks/nextpas.core.text.unicode/compare_go && go test -bench=. -benchtime=500ms
./scripts/text-unicode-ensure.sh
```

---

## 变更

| 日期 | 说明 |
|------|------|
| 2026-07-21 | **P3-3**：下一岛导航修正（不再指向已完成的 P2-3） |
| 2026-07-20 | **P2-2 v3**：同机全量重跑 + Width 测项 + C6/C7 库存冻结 |
| 2026-07-20 | v2 / M3b–M3d 历史见 git |
