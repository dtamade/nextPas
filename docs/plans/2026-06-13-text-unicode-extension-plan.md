# Text 模块 Unicode 扩展——实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.
> **Codex 把关:** 所有代码修改和计划变更必须由 Codex agent 执行，Claude 只分析汇报。

**Goal:** 让 `nextpas.core.text` 从"ASCII + 部分 Unicode"演进为完整的 Unicode 文本引擎，覆盖 Case Mapping、Normalization、Unicode-aware 比较、以及门面收敛。

**Architecture:** 分五个阶段递进——先修债（测试红点 + 门面收口），再建 Unicode 数据基础层（property/property 表），然后逐层叠加 Case Fold、Normalization、最终重写 compare/搜索层。所有 Unicode 数据表由官方 UCD 文件生成 `.inc`，版本固定，测试直接吃官方 conformance 文件。

**Tech Stack:** FreePascal 3.3.1+，core 设计规范（四件套范式），Codex 执行所有代码变更。

**关键约束：**
- 所有代码修改由 Codex 执行，Claude 只分析汇报
- 遵循 `core/docs/design-conventions.md` 的分层与模块范式
- 遵循工作纪律：测试 100% 覆盖、0 泄漏、每轮提交、目标树同步
- Unicode 数据版本固定到 16.0

---

## 阶段总览

| 阶段 | 主题 | 预计时间 | 关键产出 |
|------|------|----------|----------|
| Phase 1 | 修债 + 门面收口 | 1-2 轮 | text.view 全绿、text.pas 瘦身、surface 去重 |
| Phase 2 | Unicode 数据基础层 | 2-3 轮 | 数据生成工具、property 表、General Category |
| Phase 3 | Case Mapping & Folding | 2-3 轮 | Simple/Full case fold、case map API |
| Phase 4 | Normalization (NFC/NFD) | 2-3 轮 | NFC/NFD 核心算法、NFKC/NFKD |
| Phase 5 | Unicode-aware Compare | 1-2 轮 | 基于 fold/normalize 重写 compare 层 |

---

## Phase 1: 修债 + 门面收口

### 背景

Codex 审计发现两个架构债务：
1. `text.view` 测试红点：`TByteSpan.Create(nil, 1)` 应该抛错，测试预期错误
2. `text.pas` 门面过胖：包含 trim/split/join/replace 等真实实现，违反设计规范
3. `text.compare` / `text.utils` / `text.conv` 有重复 surface

### Task 1.1: 修复 text.view 测试红点

**描述:** 修复 `test_text_view.lpr` 中 `reject nil data with non-zero length` 测试——`TByteSpan.Create(nil, 1)` 应该被 `TByteSpan.Create` 直接抛 `EArgumentNil`，而非期望在 `TStringView.FromSpan` 处抛错。

**Codex 执行指令:**
```
修复 test_text_view 测试红点:
1. 阅读 core/src/nextpas.core.base.pas 中 TByteSpan.Create 的 nil 检查逻辑
2. 阅读 core/tests/nextpas.core.text.view/test_text_view/test_text_view.lpr 中"reject nil data with non-zero length"测试
3. 修改测试预期：TByteSpan.Create(nil, 1) 应直接抛 EArgumentNil，因此测试应该验证 Create 抛异常，而非 FromSpan 抛异常
4. 运行测试确认通过: make -C core/tests/nextpas.core.text.view/test_text_view test
5. 确保 0 泄漏
```

**验证:** `make -C core/tests/nextpas.core.text.view/test_text_view test` → 18/18 passed, 0 leak

### Task 1.2: 收敛 text.pas 门面

**描述:** 将 `text.pas` 中的实现逻辑移到合适的子模块，门面只保留 re-export 和 inline 转发。

**当前问题:**
- `Trim/TrimLeft/TrimRight` 实现在 text.pas，但 `text.utils` 和 `text.conv` 也有
- `Split/Join/Replace/ReplaceAll` 实现在 text.pas
- `ToUpper/ToLower` 实现在 text.pas，但 `text.conv` 也有
- `PadLeft/PadRight/Repeat` 实现在 text.pas
- `IndexOf/LastIndexOf` 实现在 text.pas
- `IsEmpty/IsBlank` 实现在 text.pas
- `UTF8Length/UTF8CodePointAt` 实现在 text.pas

**Codex 执行指令:**
```
收敛 text.pas 门面，遵循 core/docs/design-conventions.md 的门面规范:
1. 分析 text.pas 中所有实现，确定各函数应归属的子模块
2. Trim/TrimLeft/TrimRight 应统一到 text.utils（或 text.conv 中已有的 Trim）
3. Split/Join/Replace/ReplaceAll 应移到 text.strings 或独立子模块
4. PadLeft/PadRight/Repeat 应移到 text.utils
5. IndexOf/LastIndexOf/Contains/StartsWith/EndsWith 应移到 text.compare 或 text.view
6. IsEmpty/IsBlank 应移到 text.utils
7. UTF8Length/UTF8CodePointAt 应转发到 text.utf8
8. 门面只保留 type 别名、inline 转发函数
9. 更新所有消费方（测试、其他模块）的 uses
10. 运行所有 text 测试确保全绿
11. 确保 0 泄漏
```

**验证:** 全部 12 个 text 测试套件全绿、0 泄漏

### Task 1.3: 去重 surface

**描述:** 消除 `text.compare`、`text.utils`、`text.conv` 之间的重复 API。

**Codex 执行指令:**
```
去重 text 模块的重复 surface:
1. 识别 text.compare / text.utils / text.conv / text.pas 之间的重复函数
2. 确定每个函数的唯一 owner
3. 其他模块改为 uses 和转发
4. 确保测试全部通过
5. 确保 0 泄漏
```

**验证:** 全部 text 测试全绿、无重复 API

---

## Phase 2: Unicode 数据基础层

### 背景

当前 `text.char` 仅处理 0-255 字节（ASCII），后续所有 Unicode 功能都需要一个稳定的属性/数据层。需要建立数据生成流程，从官方 UCD 文件生成 Pascal `.inc` 表。

### Task 2.1: 建立 Unicode 数据生成工具

**描述:** 创建脚本/工具，从 Unicode 16.0 UCD 文件生成 Pascal 数据表。

**Codex 执行指令:**
```
创建 Unicode 数据生成工具:
1. 在 core/scripts/ 或 core/tools/ 下创建数据生成工具
2. 输入: Unicode 16.0 UCD 文件 (UnicodeData.txt, DerivedCoreProperties.txt, PropList.txt 等)
3. 输出: Pascal .inc 文件，放在 core/src/ 下
4. 生成的数据应包含:
   - General Category (每个码点)
   - 属性表: Alphabetic, Lowercase, Uppercase, White_Space 等
   - 阶段1 先做 2 级表（high-byte + low-byte），保持内存紧凑
5. 生成的 .inc 文件要带版本号注释和生成日期
6. 创建 Makefile 目标方便重新生成
7. 运行测试验证
```

**关键文件:**
- 创建: `core/scripts/gen_unicode_data` (生成工具)
- 创建: `core/src/nextpas.core.text.unicode.data.inc` (生成的数据表)
- 创建: `core/src/nextpas.core.text.unicode.base.pas` (类型定义)

### Task 2.2: 实现 Unicode Property 模块

**描述:** 基于生成的数据表，实现 `nextpas.core.text.unicode.property`。

**Codex 执行指令:**
```
实现 Unicode Property 模块:
1. 创建 core/src/nextpas.core.text.unicode.base.pas
   - 定义 TUnicodeCodepoint = UInt32
   - 定义 TGeneralCategory 枚举
   - 定义 TUnicodeProperty 记录/位掩码
2. 创建 core/src/nextpas.core.text.unicode.property.pas
   - 使用生成的 .inc 数据表
   - 实现 GetGeneralCategory(cp: UInt32): TGeneralCategory
   - 实现 IsUpper/IsLower/IsAlpha/IsDigit/IsWhitespace/IsControl (Unicode 版)
   - 保持热路径性能（ASCII 快路径 + 查表）
3. 创建 core/tests/nextpas.core.text.unicode/test_unicode_property/
   - 测试覆盖: ASCII 范围、BMP 范围、SMP 范围、边界情况
   - 使用官方 Unicode 测试数据
4. 运行测试，确保全绿 + 0 泄漏
```

**验证:** Unicode property 测试全绿、0 泄漏、ASCII 快路径基准不退化

### Task 2.3: 代码点 Case 映射

**描述:** 实现 `CodePointToLower`、`CodePointToUpper`、`CodePointToTitle`。

**Codex 执行指令:**
```
实现 Unicode Case Mapping (Simple):
1. 扩展数据生成工具，从 UnicodeData.txt 提取 Simple_Lowercase_Mapping / Simple_Uppercase_Mapping / Simple_Titlecase_Mapping
2. 创建 core/src/nextpas.core.text.unicode.case.pas
3. 实现:
   - function CodepointToLower(cp: UInt32): UInt32
   - function CodepointToUpper(cp: UInt32): UInt32
   - function CodepointToTitle(cp: UInt32): UInt32
4. 创建测试，使用官方 Unicode 测试数据
5. 确保全绿 + 0 泄漏
```

**验证:** case map 测试全绿、覆盖 BMP 和 SMP 范围

---

## Phase 3: Case Folding

### 背景

Case Folding 是大小写无关比较的基础。Unicode 规范定义了 Simple (C) 和 Full (F) 两种折叠。

### Task 3.1: 实现 Case Folding

**描述:** 基于 `CaseFolding.txt` 实现 Simple 和 Full case fold。

**Codex 执行指令:**
```
实现 Unicode Case Folding:
1. 扩展数据生成工具，从 CaseFolding.txt 提取 C 和 F 折叠
2. 在 core/src/nextpas.core.text.unicode.case.pas 中实现:
   - function CaseFoldSimple(cp: UInt32): UInt32
   - function CaseFoldFull(cp: UInt32): TUnicodeCodepointArray (可能返回多个码点)
3. 提供 UTF-8 字符串级别的包装:
   - function UTF8CaseFold(const s: string): string
   - function UTF8CaseFoldSimple(const s: string): string
4. 创建测试:
   - 单元测试覆盖已知 case fold 对
   - 使用 CaseFolding.txt 衍生测试用例
   - 覆盖 Full fold 返回多码点的情况（如 ß → ss）
5. 确保全绿 + 0 泄漏
```

**验证:** case fold 测试全绿、ß → ss 等经典 case 正确

### Task 3.2: 基于 Case Fold 重写 Compare

**描述:** 用 Case Fold 替换当前的 ASCII ToLower 比较。

**Codex 执行指令:**
```
用 Unicode Case Fold 重写 text.compare 层:
1. 修改 TextCompareI/TextEqualI/TextStartsWithI/TextEndsWithI/TextContainsI
2. 内部使用 CaseFoldSimple 或 UTF8CaseFold 替代 ASCII ToLower
3. 保持 ASCII 快路径（纯 ASCII 输入不需要 full fold）
4. 更新所有相关测试
5. 运行全部 text 测试，确保全绿 + 0 泄漏
6. 运行 benchmark 对比性能
```

**验证:** 全部 text 测试全绿、Unicode 比较正确（如 'İ' 和 'i' 的土耳其语 case）

---

## Phase 4: Normalization

### 背景

Unicode 规范化用于文本等价比较。NFC（组合）和 NFD（分解）是基础，NFKC/NFKD 是兼容性规范化。

### Task 4.1: 实现 NFD 分解

**描述:** 实现 Canonical Decomposition (NFD)。

**Codex 执行指令:**
```
实现 Unicode NFD 规范化:
1. 扩展数据生成工具，从 UnicodeData.txt 提取 Decomposition_Mapping
2. 创建 core/src/nextpas.core.text.unicode.normalize.pas
3. 实现:
   - function NFD(const s: string): string
   - 内部: 递归分解 + 规范排序(CCC)
4. 创建测试:
   - 使用 NormalizationTest.txt 官方 conformance 测试
   - 覆盖 BMP 和 SMP 范围
5. 确保全绿 + 0 泄漏
```

**验证:** NormalizationTest.txt conformance 通过

### Task 4.2: 实现 NFC 组合

**描述:** 实现 Canonical Composition (NFC)。

**Codex 执行指令:**
```
实现 Unicode NFC 规范化:
1. 扩展数据生成工具，从 UnicodeData.txt 提取 Composition Exclusion + Canonical Composition
2. 在 normalize.pas 中实现:
   - function NFC(const s: string): string
   - 内部: NFD + 规范组合
3. 使用 NormalizationTest.txt 验证 NFC
4. 确保全绿 + 0 泄漏
```

**验证:** NFC conformance 通过

### Task 4.3: 实现 NFKC/NFKD

**描述:** 实现兼容性规范化。

**Codex 执行指令:**
```
实现 Unicode NFKC/NFKD 规范化:
1. 扩展数据生成工具，提取 Compatibility Decomposition
2. 在 normalize.pas 中实现:
   - function NFKD(const s: string): string
   - function NFKC(const s: string): string
3. 使用 NormalizationTest.txt 验证
4. 确保全绿 + 0 泄漏
```

**验证:** NFKC/NFKD conformance 通过

---

## Phase 5: Unicode-aware Compare 收口

### 背景

基于 case fold 和 normalization 重写完整的 Unicode 文本比较层。

### Task 5.1: 实现 Canonical Equality

**描述:** 基于 NFC 实现规范等价判断。

**Codex 执行指令:**
```
实现 Unicode 规范等价比较:
1. 在 text.compare 中添加:
   - function TextEqualCanonical(const A, B: string): Boolean (NFC 后比较)
   - function TextEqualCaseFold(const A, B: string): Boolean (NFD + CaseFold 后比较)
2. 创建测试覆盖各种等价场景
3. 确保全绿 + 0 泄漏
```

**验证:** 规范等价测试通过

### Task 5.2: 更新门面和文档

**描述:** 最终收口——更新 text.pas 门面、添加模块文档。

**Codex 执行指令:**
```
收口 text Unicode 扩展:
1. 更新 text.pas 门面，添加 Unicode 模块的 re-export
2. 创建 core/docs/text/ 模块文档目录
3. 编写 Unicode API 使用文档
4. 运行全部 text 测试 + benchmark
5. 确保全绿 + 0 泄漏
6. 运行 make hygiene
```

**验证:** 全部测试全绿、文档完整、hygiene 通过

---

## 回归清单

每个 Phase 完成后必须验证：

```bash
# 全部 text 测试
for d in core/tests/nextpas.core.text*/test_*; do make -C "$d" test || exit 1; done

# 无泄漏（由 heaptrc 自动验证）

# Benchmark 不退化
make -C core/benchmarks/nextpas.core.text/bench_text test

# Hygiene
make -C "$(git rev-parse --show-toplevel)" hygiene
```

## 风险与依赖

| 风险 | 缓解措施 |
|------|----------|
| UCD 数据表过大 | 2 级表 + 范围压缩，控制 .inc 大小 |
| 性能退化 | 每阶段跑 benchmark，ASCII 快路径不能退化 |
| FPC 编译器限制 | 大 .inc 文件可能编译慢，分块生成 |
| 测试数据量大 | NormalizationTest.txt 按需采样，不全量运行 |

## 执行方式

由 Codex agent 负责所有代码修改和测试编写。每完成一个 Task，Claude 汇报结果并确认下一步。

---