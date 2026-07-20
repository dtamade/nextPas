# nextpas.core.text.unicode — 性能分析

## 复杂度概览

| 操作 | 时间复杂度 | 空间复杂度 | 备注 |
|------|-----------|-----------|------|
| IsAsciiString | O(n/8) | O(1) | 8 字节并行 UInt64 检查 |
| NFD/NFC (ASCII) | O(1) | O(1) | 快速路径：IsAsciiString 检测 |
| NFD/NFC (BMP) | O(n) | O(n) | 表查找 O(1)/码点 |
| NFD/NFC (SMP) | O(n log m) | O(n) | m=183 SMP 范围，二分查找 |
| QuickCheckNFD/NFC | O(n) | O(1) | 无分配，纯检查 |
| GetCanonicalCombiningClass | O(1) / O(log m) | O(1) | BMP 表直接查 / SMP 二分 |
| Compare | O(n) | O(1) | 排序键逐级比较 |
| GetSortKey | O(n) | O(n) | 单遍收集权重 |
| NextGraphemeCluster | O(1) | O(1) | 状态机推进 |
| CountGraphemeClusters | O(n) | O(1) | 单遍扫描 |
| 字素/词/行/句分割 | O(n) | O(1) | 单遍状态机 |

## ASCII 快速路径

所有规范化函数都有 ASCII 快速路径：

```pascal
function NFD(const AText: string): string;
begin
  if AText = '' then Exit('');
  if IsAsciiString(AText) then Exit(AText);  // O(n/8) 检测
  // ... 正常处理
end;
```

IsAsciiString 使用 8 字节并行检查：

```pascal
LWord := PUInt64(LPtr + LIdx)^;
if (LWord and UInt64($8080808080808080)) <> 0 then
  Exit(False);  // 发现非 ASCII 字节
```

一次检查 8 字节，比逐字节检查快 ~8x。

## BMP vs SMP 查找

| 平面 | 查找方式 | 每码点开销 |
|------|---------|-----------|
| BMP (U+0000-U+FFFF) | 256×256 表直接索引 | O(1) |
| SMP (U+10000-U+10FFFF) | 范围数组二分查找 | O(log 183) ≈ 8 次比较 |

SMP 包含 CJK Extension B、emoji、音乐符号等。实际文本中 SMP 码点占比低，
性能影响有限。

## 规范化性能特征

### NFD

1. **快速路径**: IsAsciiString → O(n/8)，纯 ASCII 返回原串
2. **分解阶段**: 遍历每个码点，查找分解表，递归展开
3. **排序阶段**: 按 CCC 重排 combining marks（插入排序，小数组高效）
4. **输出**: 组装 UTF-8 字符串

### NFC

1. **先 NFD**: 完全分解
2. **组合阶段**: 遍历分解结果，尝试组合 starter + combining
3. **Hangul**: 算法化组合（O(1) 每对）

### QuickCheck

- **QuickCheckNFD**: 检查是否有 LKind=1 的字符 + CCC 非递减
- **QuickCheckNFC**: 检查 composition exclusion + 组合可能性 + CCC 顺序
- 无分配，适合"先检查再决定是否规范化"模式

## 排序性能

### Compare vs GetSortKey

| 方式 | 适用场景 | 开销 |
|------|---------|------|
| Compare | 一次性比较 | O(n) NFD + O(n) 权重收集 + O(n) 比较 |
| GetSortKey + memcmp | 多次比较/排序 | O(n) 生成 + O(k) 每次比较（k=键长度） |

排序键缓存后，每次比较只需 memcmp，适合排序大量字符串。

### 排序键格式

```
[primary bytes] 00 [secondary bytes] 00 [tertiary bytes] 00 [quaternary bytes] 00
```

每个级别以 0x00 分隔。级别数取决于 Strength 设置：
- csPrimary: 1 级
- csSecondary: 2 级
- csTertiary: 3 级
- csQuaternary: 4 级
- csIdentical: 4 级

## 实测基准数据 (x86_64 Linux, FPC 3.3.1 -O2)

### 规范化

| 操作 | ns/op | ops/s | 备注 |
|------|-------|-------|------|
| NFC ASCII-50 | 44 | 22.6M | O(n/8) 快速路径 |
| NFC ASCII-200 | 83 | 12.0M | 同上 |
| NFD ASCII-50 | 47 | 21.1M | 同上 |
| NFC BMP-Latin-50 | **4,216** (SCORECARD 2026-07-20b, was ~5.1µs) | 246K | 有重音需规范化 |
| NFD BMP-Latin-50 | 3,067 | 326K | 分解比组合快 |
| NFC BMP-CJK-50 | 47 | 21.5M | CJK 无分解，快速路径 |
| NFD BMP-CJK-50 | 49 | 20.6M | 同上 |
| NFKD BMP-Latin-50 | 3,073 | 325K | 兼容分解 |
| QuickCheckNFC ASCII-200 | 53 | 19.0M | 无分配纯检查 |
| QuickCheckNFC BMP-Latin-50 | 1,858 | 538K | 逐码点检查 |

### 分割

| 操作 | ns/op | ops/s | 备注 |
|------|-------|-------|------|
| NextGrapheme ASCII-200 | 68 | 14.7M | 状态机单遍 |
| NextGrapheme BMP-CJK-50 | 67 | 14.8M | CJK 每字 1 grapheme |
| NextWord BMP-CJK-50 | 831 | 1.2M | CJK 词分割 |
| NextLine ASCII-200 | 3,480 | 288K | 行断点查找 |

### 排序

| 操作 | ns/op | ops/s | 备注 |
|------|-------|-------|------|
| Compare ASCII-50 | ~50 | ~20M | 排序键比较 |
| Compare BMP-Latin-50 | ~200 | ~5M | 有重音权重 |
| Compare BMP-CJK-50 | ~200 | ~5M | CJK 权重 |
| GetSortKey ASCII-50 | ~100 | ~10M | 排序键生成 |

### 大小写 + 工具

| 操作 | ns/op | ops/s | 备注 |
|------|-------|-------|------|
| CaseFoldSimple ASCII-200 | ~4µs | — | 逐码点循环 |
| UTF8CaseFoldSimple ASCII-200 | **447** | — | 整串（2026-07-20 SCORECARD） |
| CaseFoldSimple BMP-Latin-50 | 1,496 | 669K | 同上 |
| IsAsciiString ASCII-200 | 49 | 20.5M | 8 字节并行 |
| IsAsciiString BMP-Latin-50 | 1.5 | 687M | 首字节快速拒绝 |

## 与 FPC RTL 对比

| 操作 | FPC RTL | nextpas.core.text.unicode | 优势 |
|------|---------|--------------------------|------|
| UTF-8 长度 | O(n) 字节扫描 | O(n/8) 并行检查 | ~8x |
| 大小写比较 | SysUtils.UpperCase (临时分配) | CaseFoldSimple (无分配) | 无 GC 压力 |
| Unicode 属性 | 无 | 完整 Unicode 16.0.0 | 功能差距 |
| 排序 | CompareStr (字节序) | DUCET 排序 | 正确性差距 |
| 文本分割 | 无 | UAX#29 完整实现 | 功能差距 |

## 优化建议

### 1. 避免不必要的规范化

```pascal
// 差: 每次都规范化
function Process(const AText: string): string;
begin
  Result := DoSomething(NFC(AText));
end;

// 好: 先快速检查
function Process(const AText: string): string;
var LNorm: string;
begin
  if QuickCheckNFC(AText) then LNorm := AText
  else LNorm := NFC(AText);
  Result := DoSomething(LNorm);
end;
```

### 2. 排序键缓存

```pascal
// 差: 多次比较每次都重新计算
for I := 0 to N-2 do
  for J := I+1 to N-1 do
    if Col.Compare(Strs[I], Strs[J]) > 0 then ...

// 好: 生成排序键后用 memcmp
for I := 0 to N-1 do
  Keys[I] := Col.GetSortKey(Strs[I]);
for I := 0 to N-2 do
  for J := I+1 to N-1 do
    if CompareBytes(Keys[I], Keys[J]) > 0 then ...
```

### 3. IsAsciiString 优先

```pascal
// 对于已知可能含 ASCII 的数据
if IsAsciiString(AText) then
begin
  // 快速路径：直接字节比较/处理
end
else
begin
  // 慢路径：Unicode 感知处理
end;
```

## 内存使用

| 组件 | 静态数据大小 | 备注 |
|------|-------------|------|
| 属性表 (BMP) | ~64 KB | 256×256 字节表 |
| 属性表 (SMP) | ~12 KB | 范围数组 |
| 分解表 (BMP) | ~48 KB | 码点+长度+映射 |
| 分解表 (SMP) | ~80 KB | 更多 SMP 分解 |
| 排序权重表 | ~64 KB | 256×256 UInt32 |
| CCC 表 | ~64 KB | 256×256 字节 |
| Script/Block 表 | ~16 KB | 范围数组 |
| **总计** | **~350 KB** | 静态数据，共享库级别 |

运行时额外开销极小：仅规范化时的 TCodepointBuffer（栈分配，~64 字节）。
