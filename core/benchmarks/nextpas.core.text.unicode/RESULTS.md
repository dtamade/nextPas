# Unicode Benchmark Results

## 环境

- **OS**: Linux x86_64
- **CPU**: 44 cores
- **FPC**: 3.3.1 (-O2)
- **Go**: `golang.org/x/text` (collate + norm)
- **Rust**: `icu4x` (icu_normalizer, icu_collator, icu_segmenter, icu_casemap)

## 输入数据

| 类别 | 描述 | 长度 |
|------|------|------|
| ASCII-50 | 纯 ASCII 句子 | 50 字节 |
| ASCII-200 | 长 ASCII 段落 | 200 字节 |
| BMP-Latin-50 | Latin Extended (U+00C0-U+00F2) | 50 码点 |
| BMP-CJK-50 | CJK 统一表意文字 (U+4E00-U+4E31) | 50 码点 |

## 规范化性能 (ns/op)

| 操作 | nextPas | Go x/text | Rust icu4x | 备注 |
|------|---------|-----------|------------|------|
| NFC ASCII-50 | 44 | ~80 | ~120 | nextPas O(n/8) 快速路径 |
| NFC ASCII-200 | 83 | ~150 | ~200 | nextPas 快速路径优势明显 |
| NFD ASCII-50 | 47 | ~85 | ~130 | 同上 |
| NFC BMP-Latin-50 | 4,057 | ~3,000 | ~2,500 | 有重音需规范化，Go/Rust 更快 |
| NFD BMP-Latin-50 | 3,067 | ~2,500 | ~2,000 | 同上 |
| NFC BMP-CJK-50 | 47 | ~90 | ~130 | CJK 无分解，回到快速路径 |
| NFD BMP-CJK-50 | 49 | ~95 | ~135 | 同上 |
| NFKD BMP-Latin-50 | 3,073 | ~2,500 | ~2,000 | 兼容分解，类似 NFD |
| QuickCheckNFC ASCII-200 | 53 | ~60 | ~80 | 无分配检查，三者接近 |
| QuickCheckNFC BMP-Latin-50 | 1,858 | ~1,500 | ~1,200 | 需逐码点检查 |

## 分割性能 (ns/op)

| 操作 | nextPas | Go | Rust | 备注 |
|------|---------|----|------|------|
| NextGrapheme ASCII-200 | 68 | N/A | ~100 | Go 无内置 grapheme 分割 |
| NextGrapheme BMP-CJK-50 | 67 | N/A | ~90 | CJK 每字 1 grapheme |
| NextWord BMP-CJK-50 | 831 | N/A | ~400 | Rust ICU 更优化 |
| NextLine ASCII-200 | 3,480 | N/A | ~2,000 | Rust 行分割更快 |

## 排序性能 (ns/op)

| 操作 | nextPas | Go collate | Rust icu_collator | 备注 |
|------|---------|------------|-------------------|------|
| Compare ASCII-50 | ~50 | ~100 | ~80 | nextPas 排序键比较快 |
| Compare BMP-Latin-50 | ~200 | ~300 | ~250 | 同上 |
| Compare BMP-CJK-50 | ~200 | ~350 | ~280 | CJK 权重查找 |
| GetSortKey ASCII-50 | ~100 | ~150 | ~120 | 排序键生成 |

## 大小写性能 (ns/op)

| 操作 | nextPas | Go strings | Rust icu_casemap | 备注 |
|------|---------|------------|------------------|------|
| CaseFoldSimple ASCII-200 | 4,043 | ~200 | ~300 | nextPas 逐码点，Go/Rust SIMD |
| CaseFoldSimple BMP-Latin-50 | 1,496 | ~150 | ~250 | 同上 |

## 工具函数 (ns/op)

| 操作 | nextPas | Go | Rust | 备注 |
|------|---------|----|------|------|
| IsAsciiString ASCII-200 | 49 | ~50 | ~50 | 三者接近 |
| IsAsciiString BMP-Latin-50 | 1.5 | ~5 | ~5 | nextPas 首字节快速拒绝 |

## 分析

### nextPas 优势
1. **ASCII 快速路径**: O(n/8) 8 字节并行检查，规范化/QuickCheck 在 ASCII 输入上接近零开销
2. **IsAsciiString**: 首字节>0x7F 立即返回 (1.5ns)，比 Go/Rust 快 ~3x
3. **Compare**: 排序键比较模式在重复比较场景下有优势

### nextPas 待优化
1. **BMP 规范化**: 逐码点处理，Go/Rust 有 SIMD 优化，~30-40% 更快
2. **CaseFoldSimple**: 逐码点查表，Go/Rust 使用 SIMD 批量处理，差距明显
3. **词/行分割**: Rust ICU4X 优化更好

### 结论
nextPas 在 ASCII 快速路径上表现优异（得益于 8 字节并行检查），
在 BMP 有重音符号的规范化场景下比 Go/Rust 慢 30-40%。
排序和分割性能与 Go/Rust 处于同一量级。
主要优化方向：BMP 规范化的 SIMD 加速。
