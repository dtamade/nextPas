# text.unicode — 性能 SCORECARD

**状态**：v1 固化（M1）· **v2 冻结数字** 在 **M3** 重跑后更新。  
**bench 路径**：`core/benchmarks/nextpas.core.text.unicode/`  
**原始流水**：[`RESULTS.md`](../../../benchmarks/nextpas.core.text.unicode/RESULTS.md)（若相对 docs 路径以仓库根为准：`core/benchmarks/.../RESULTS.md`）

---

## 测项纪律

1. **整串 API** 与 Go/Rust 对比；禁止「逐码点循环」对「整串 ToUpper」  
2. 输入必须是 **真实 UTF-8**（禁止 Pascal `#$00C0` 单字节假 Latin-1）  
3. 已规范化串与 denorm 串 **分开报**（QC 短路 vs 全路径）  
4. 每次优化 land：更新 tip + 本表数字 + RESULTS  

---

## 通过准则（M3 冻结目标）

| 类别 | 准则 | 未达标 |
|------|------|--------|
| ASCII 热路径（CaseFold / NFC / IsAscii） | nextPas / Go **≤ 1.0×**（越小越快） | 🔴 |
| 已 NFC 的 BMP 拉丁 | NFC **≤ 1.0×** Go | 🔴 |
| denorm NFC 全路径 | 目标 **≤ 1.2×** Go | 🟡 可 land，记债 |
| Segment / Collate / Width | M3 建基线；暂无硬阈值 | ⬜ M3 |

判定：`比率 = nextPas_ns / Go_ns`。

---

## v1 水位快照（2026-07-20，历史，M3 须重跑）

环境：Linux x86_64 · FPC 3.3.1 -O2 · Go `x/text`  

| 操作 | nextPas | Go | 比率 | 注 |
|------|--------:|---:|-----:|----|
| UTF8CaseFoldSimple ASCII-200 | ~447 ns | ~2899 ns ToUpper | **0.15×** | 整串 |
| NFC ASCII-200 | ~83 ns | ~268 ns | **0.31×** | |
| NFC BMP-Latin 已 NFC（真 UTF-8） | ~1031 ns | ~2819 ns | **0.36×** | QC 短路 |
| NFD BMP-Latin | 领先（见 RESULTS） | | **≪1** | |
| denorm NFC 全路径 | 历史 ~1.5× 级 | | 🟡 | M3 重测 |

**v1 结论**：ASCII 与已规范化 BMP 已可对标/领先；denorm 全路径与 Collate/Segment 基线留给 **M3**。

---

## 优化只跟表

- 仅 🔴 或明确 🟡 债项开优化  
- 正确性门禁优先：`make -C core/tests/nextpas.core.text.unicode gate`  
- 不接受无 SCORECARD 行的「感觉慢」重构  

---

## 跑法

```bash
make -C core/benchmarks/nextpas.core.text.unicode
# Go 对照
cd core/benchmarks/nextpas.core.text.unicode/compare_go && go test -bench=. -benchtime=1s
```

---

## 变更

| 日期 | 说明 |
|------|------|
| 2026-07-20 | M1：准则入仓；数字引用 RESULTS 历史快照 |
