# Stage2 Self-Hosting Feasibility Assessment

**Date:** 2026-05-02  
**Status:** 评估进行中  
**Conclusion:** Stage2 当前**不可行**，需要先完成 RTL 基础设施

## 执行摘要

通过实际尝试用 nextPas 编译自己的 compiler modules，我们发现了 Stage2 的关键阻塞因素：
**RTL 不完整**。当前 RTL 只包含 compiler-facing 的基础类型，缺少 compiler modules 
自身依赖的标准库单元（如 `SysUtils`、`Classes` 等）。

## 实验：用 nextPas 编译 compiler module

### 测试用例

尝试编译最简单的 compiler module：`compiler/diagnostics/np_diagnostics_sink.pas`

```bash
./.sisyphus/tmp/stage0-bootstrap-debug/nextpas build \
  compiler/diagnostics/np_diagnostics_sink.pas \
  --target linux-x86_64 \
  --workspace .
```

### 结果

```
resolution-status=failure
unit-graph-status=failure
diagnostic-code=resolver.unit-not-found
diagnostic-message=unit "SysUtils" not found
```

### 分析

`np_diagnostics_sink.pas` 的依赖链：

```
np_diagnostics_sink.pas
  ├─ uses SysUtils          ❌ 缺失
  └─ uses np_base_types     ✅ 存在 (rtl/core/base/)
```

**问题**：nextPas 的 runtime SDK (`units/linux-x86_64/`) 中没有 `SysUtils`。

## RTL 当前状态

### 已有的 RTL 模块

```
rtl/core/base/np_base_types.pas          ✅ Compiler-facing 基础类型
rtl/core/text/np_text_primitives.pas     ✅ Text/path primitives
rtl/core/mem/np_allocator.pas            ✅ Memory allocator
rtl/core/system/system_placeholder.pas   ✅ System unit placeholder
```

### 缺失的标准库单元

Compiler modules 依赖但 RTL 中缺失的单元：

1. **SysUtils** - 字符串操作、文件 I/O、异常处理
2. **Classes** - TStringList, TList 等容器类
3. **StrUtils** - 字符串工具函数
4. **Math** - 数学函数（如果需要）

### RTL 设计哲学

根据 `rtl/README.md`：

> `rtl/` 不只是 future user program 的运行时位置，它也会成为 nextPas 自家 
> compiler / toolchain 的共享基础设施来源。

**当前优先级**：
- ✅ Compiler-facing primitives (base types, text, mem)
- ❌ Application-facing standard library (SysUtils, Classes)

**长期方向**：
- RTL 会长成 compiler/toolchain 可复用的 nextPas-native core runtime
- 不承诺完整 FPC RTL 树覆盖面
- 优先服务 compiler 代码，而不是应用生态

## Stage2 的依赖分析

### Compiler Modules 的外部依赖

让我分析所有 compiler modules 的 `uses` 子句：

**Frontend modules:**
```pascal
// np_compilation_session.pas
uses SysUtils, Classes, np_source_database, np_unit_resolver, ...

// np_unit_resolver.pas
uses SysUtils, np_unit_graph, np_source_database, ...

// np_workspace_model.pas
uses SysUtils, np_package_manifest

// np_package_manifest.pas
uses SysUtils
```

**Syntax modules:**
```pascal
// np_lexer.pas
uses SysUtils, np_base_types

// np_green_tree.pas
uses SysUtils, np_base_types
```

**Sema modules:**
```pascal
// np_semantic_analyzer.pas
uses SysUtils, np_semantic_model, np_ast_facade

// np_semantic_model.pas
uses SysUtils, np_base_types
```

**Diagnostics:**
```pascal
// np_diagnostics_sink.pas
uses SysUtils, np_base_types
```

**共同依赖**：
- ✅ `np_base_types` - 已有
- ❌ `SysUtils` - 缺失（几乎所有模块都依赖）
- ❌ `Classes` - 缺失（部分模块依赖）

### 依赖复杂度估算

**SysUtils 的核心功能**（compiler modules 实际使用的）：
1. 字符串操作：`Trim`, `Copy`, `Pos`, `LowerCase`, `UpperCase`
2. 文件操作：`FileExists`, `DirectoryExists`, `ExpandFileName`, `ExtractFileDir`
3. 路径操作：`IncludeTrailingPathDelimiter`, `ExtractFileName`
4. 异常：`Exception` 基类
5. 类型转换：`IntToStr`, `StrToInt`

**Classes 的核心功能**：
1. `TStringList` - 字符串列表
2. `TList` - 泛型列表（可能不需要，可以用 dynamic arrays）

**估算工作量**：
- 实现 SysUtils 子集：~500-1000 行代码
- 实现 Classes 子集：~300-500 行代码
- 测试和验证：~200-300 行测试代码
- **总计**：~1000-1800 行代码

## Stage2 的其他潜在问题

### 1. 后端成熟度

**问题**：nextPas 后端能否处理 compiler modules 的复杂性？

**Compiler modules 的特点**：
- 大量使用 classes 和 objects
- 复杂的数据结构（dynamic arrays, records, classes）
- 字符串操作密集
- 递归调用（如 AST 遍历）

**当前后端状态**：
- ✅ 可以编译简单程序（`hello_pass.pas`）
- ✅ 支持 FPC backend（委托给 FPC）
- ✅ 支持 LLVM backend（实验性）
- ❓ 未验证能否处理 compiler modules 的复杂性

**风险**：中等。FPC backend 应该能处理，因为它就是 FPC。

### 2. Bootstrap 循环设计

**问题**：如何设计 stage1 → stage2 的过渡路径？

**可能的方案**：

**方案 A：渐进式 self-hosting**
1. 先用 nextPas 编译单个最简单的 module（如 `np_base_types.pas`）
2. 逐步扩大到更多 modules
3. 最终编译整个 compiler
4. 用 nextPas 编译的 compiler 再编译自己（验证一致性）

**方案 B：一次性 self-hosting**
1. 补齐所有缺失的 RTL 单元
2. 直接用 nextPas 编译整个 compiler
3. 验证生成的 binary 与 FPC 构建的行为一致

**推荐**：方案 A（渐进式），风险更低。

### 3. 验证一致性

**问题**：如何证明 self-hosted nextPas 与 FPC-hosted 行为一致？

**策略**：
1. **Differential testing**：
   - 用两个版本编译相同的测试用例
   - 比较输出（diagnostics, generated code, binary behavior）
   
2. **Regression testing**：
   - 所有现有测试必须通过
   - `verify-local=pass` 是最低要求

3. **Bootstrap 循环验证**：
   - nextPas₁ (FPC-hosted) 编译 nextPas₂
   - nextPas₂ 编译 nextPas₃
   - 验证 nextPas₂ 和 nextPas₃ 的 binary 完全相同（bit-identical）

**风险**：高。需要仔细设计验证策略。

## 阻塞因素总结

| 阻塞因素 | 严重程度 | 工作量估算 | 优先级 |
|---------|---------|-----------|--------|
| RTL 不完整（SysUtils, Classes） | 🔴 Critical | ~1000-1800 LOC | P0 |
| 后端未验证复杂代码 | 🟡 Medium | ~测试验证 | P1 |
| Bootstrap 循环设计 | 🟡 Medium | ~设计+实现 | P1 |
| 一致性验证策略 | 🟡 Medium | ~测试框架 | P1 |

## 结论

**Stage2 当前不可行**，主要阻塞因素是 **RTL 不完整**。

### 推荐路径

**Phase 1: RTL 基础设施（必需）**
1. 实现 `SysUtils` 子集（compiler modules 实际使用的功能）
2. 实现 `Classes` 子集（如果需要，或用 dynamic arrays 替代）
3. 添加 RTL 单元测试
4. 将 RTL 单元安装到 `units/linux-x86_64/`

**Phase 2: 渐进式验证（推荐）**
1. 用 nextPas 编译最简单的 module（`np_base_types.pas`）
2. 逐步扩大到更复杂的 modules
3. 识别并修复后端问题
4. 验证生成的代码正确性

**Phase 3: 完整 Self-Hosting（最终目标）**
1. 用 nextPas 编译整个 compiler
2. 实现 bootstrap 循环
3. 验证一致性（differential testing, bit-identical builds）
4. 正式宣布 Stage2 完成

### 工作量估算

- **Phase 1 (RTL)**: ~2-3 周（1000-1800 LOC + 测试）
- **Phase 2 (验证)**: ~1-2 周（测试+修复）
- **Phase 3 (Self-hosting)**: ~1-2 周（集成+验证）
- **总计**: ~4-7 周

### 风险评估

**高风险**：
- RTL 实现可能遇到意外的依赖链
- 后端可能无法处理某些复杂的 Pascal 特性
- Bootstrap 循环可能暴露微妙的语义差异

**缓解策略**：
- 渐进式推进，每步都验证
- 保持 FPC-hosted 构建作为参考基准
- 充分的测试覆盖

## 下一步行动

### 选项 A：开始 RTL 实现（推荐）

立即开始实现 `SysUtils` 子集，为 Stage2 铺路。

**优点**：
- 直接解决阻塞因素
- RTL 本身也是有价值的资产
- 为 future user programs 奠定基础

**缺点**：
- 需要较大工作量
- 可能遇到意外的复杂性

### 选项 B：继续加固 Stage1

暂时不进入 Stage2，继续改进 Stage1 的功能和质量。

**优点**：
- 降低风险
- 让 Stage1 更加稳定
- 为 Stage2 积累更多信心

**缺点**：
- 延迟 self-hosting 里程碑
- 可能错过发现后端问题的机会

### 选项 C：探索替代方案

考虑是否真的需要 full self-hosting，或者可以采用混合方案。

**优点**：
- 可能找到更简单的路径
- 降低复杂度

**缺点**：
- 偏离传统的 compiler bootstrap 路径
- 可能不符合长期愿景

## 我的推荐

**选择 选项 A：开始 RTL 实现**

理由：
1. RTL 是 Stage2 的必需基础设施
2. RTL 本身也是有价值的资产，不仅服务 self-hosting
3. 渐进式推进可以控制风险
4. 符合 `rtl/README.md` 的长期方向

**具体行动**：
1. 创建 `rtl/core/sysutils/` 目录
2. 实现 `SysUtils` 子集（从 compiler modules 实际使用的功能开始）
3. 添加单元测试
4. 安装到 `units/linux-x86_64/`
5. 重新尝试编译 `np_diagnostics_sink.pas`
6. 迭代直到成功

**预期时间线**：
- Week 1: 实现 SysUtils 核心功能（字符串、文件、路径）
- Week 2: 实现 Classes 子集（如果需要）+ 测试
- Week 3: 验证 compiler modules 可以编译
- Week 4+: 渐进式扩大到更多 modules

这样，我们可以在 ~1 个月内为 Stage2 铺平道路。
