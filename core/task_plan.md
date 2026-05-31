# Task Plan: Regex Teddy SIMD Multi-Pattern Matcher

## Goal
实现 Teddy 算法用于 literal alternation 的 SIMD 多模式匹配，将 `cat|dog|bird|fish` 类模式的 IsMatch 从 24μs 降到 ~5μs（目标 vs Rust 差距从 13x 缩小到 3x）。

## Current Phase
Phase 2: 核心实现

## 设计决策

### 算法选择：SSE2 Multi-Byte Scan + Verify
对于 N 个 pattern（N ≤ 8），每个 pattern 取第一个字节：
1. 构建 "first byte set" — 去重后最多 8 个不同字节
2. 用 SSE2 pcmpeqb 并行扫描 16 字节输入，生成候选位掩码
3. 对每个候选位，用 first byte 确定是哪个 pattern，然后验证完整匹配

### 为什么不用完整 Teddy
- 完整 Teddy 需要 SSSE3 pshufb（nibble lookup），兼容性差
- 对于 ≤8 个 pattern，SSE2 multi-scan 已经足够快
- 实现复杂度低（~150 行 vs ~500 行）

### API
```pascal
function MultiPatternScanIsMatch(
  const APatterns: array of string; APatternCount: Integer;
  const AInput: PAnsiChar; ALen: SizeUInt): Boolean;
```

## Phases

### Phase 1: 架构设计 ✅
### Phase 2: 核心实现 ← 当前
- [ ] 实现 MultiPatternScanIsMatch
- [ ] 集成到 regex facade（替换顺序 ScanFindSubstring）
- [ ] 编译验证
- **Status:** in_progress

### Phase 3: 测试 + Benchmark
- [ ] 111 regex tests pass
- [ ] Benchmark 对照
- [ ] 提交
- **Status:** not_started
