# 自举障碍路线图 v2.0

> 基于 Codex 战略分析，2026-06-20 更新
> 目标：用 nextPas 编译 nextPas 编译器自身

## 当前状态

- **批量编译**: 55 个 core facade，41 success / 14 toolchain:ready / 0 fail
- **编译器**: Lexer 1652 行基本完整，Sema 15436 行单文件（607 方法），HIR LLVM emitter 1743 行
- **FPC stubs**: 14 个临时 stub 文件在 `units/linux-x86_64/`
- **性能**: 无增量缓存，67 单元 6.4s，158 单元 16s

## 总体策略

**P0 → P1-Math → P2 → P1-SysUtils → P3 → ~~P1-Classes~~ ✅ → P1-平台绑定**

P2（Sema 能力）排在 P1（FPC RTL 清零）前面，因为 P2 修一个方法解锁多个模块，投入产出比更高。

---

## 阶段 1：基础设施（4-6 周）

### P0: 增量编译（2-3 周）

**Phase 1: 符号表热缓存（1-2 周）**

根因：每次编译从 lexer 开始全量走一遍所有传递依赖。

方案：
1. `TSemanticModel` 序列化为二进制缓存（`.nextpas/cache/<unit-id>.npb`）
2. 需序列化：`FSymbols`/`FTypes`/`FBindings`/`FScopeTable`/`FTypeMetadata`（纯 record 数组）
3. 依赖指纹：源文件内容 hash + 所有 uses 依赖 hash 形成复合指纹
4. `TUnitResolver.ResolveDependency` 中检查缓存指纹匹配则直接加载

预期效果：热编译 6.4s → <1s，158 单元 16s → <3s

**Phase 2: 依赖图增量（+1 周）**

- `TUnitGraph.TopologicalInitOrder`（已存在）+ 文件 mtime
- 只重编译变更的子图

**Phase 3: 并行编译（+1-2 周）**

- 按拓扑序分层，同层并行
- Pascal `BeginThread` / `TThread`

**注意**：Phase 1 不要尝试序列化 HIR（`THIRModule`），太复杂。只缓存符号表。

---

### P1-Math: Math 清零（2 天）

影响 8 模块：log, yaml.writer, crypto.*, mem.*

| FPC Math 符号 | nextPas 等价 |
|---------------|-------------|
| `Max`/`Min` | `nextpas.core.math` |
| `Ln`/`Log2` | `nextpas.core.math` |
| `Floor`/`Ceil` | `nextpas.core.math` |

步骤：
1. 确认 `nextpas.core.math` 已有这些符号
2. 替换 8 个模块的 `Math` 引用
3. 删除 `units/linux-x86_64/Math.pas`
4. 验证编译通过

---

### P2-2: 类继承链 Create 解析 — ✅ 已验证通过（2026-06-23）

**解锁模块**: config, compress, props, multipart（4+ 模块）— 已全部 status=success

**状态**: 旧根因描述过时。原假设"`Create` 重载解析没遍历继承链"经核查不成立：当前
`MethodSymbolIdForClassTypeMember`（`compiler/sema/np_semantic_analyzer.pas:4614`）
在 `while (CurrentTypeId > 0) and (Depth < 32)` 循环中遍历 `ParentTypeId` 继承链
（`:4690`），每层调用 `MethodSymbolIdForExactClassTypeMember` 精确匹配成员；
当某层命中 `MethodNameFound`（`:4685`）即停止向上——这正是子类同名成员阴影、
不回退父类的语义所在。6 个曾"被阻塞"的模块（config/config.builder/
compress.deflate/props/multipart）当前全部编译通过，self-compile-modules 19/19 全绿。

**回归测试固化**（commit 5ee32ca75 + 后续）：
- `tests/compiler/pass/inherited_create_pass.pas` — 单文件三层继承 Create + 多态
- `tests/compiler/pass/inherited_create_xunit_pass.pas` (+ `_xunit_parent.pas`) —
  跨单元继承 Create，覆盖"父类来自导入单元"场景
- `tests/compiler/pass/implicit_tobject_create_pass.pas` — 无显式父类时隐式
  `TObject.Create` fallback（与 FPC 3.3.1 行为一致）
- `tests/compiler/fail/inherited_create_shadow_no_fallback_fail.pas` (+ snapshot) —
  子类同名 `Create` 签名不匹配时**禁止回退父类**，须诊断 `sema.wrong-argument-count`
  （保护 wrong-argument-count/type-mismatch 诊断语义，与 FPC 行为一致）

**剩余工作**: 仅维护现有回归测试，无需修改 sema。原"在 LookupOverload 中递归向上查"
方案不再适用——动它会破坏 wrong-argument-count 诊断语义（已被 shadow-no-fallback
测试固化）。

---

### P1-SysUtils: 编译器自身清零 — ✅ 已完成（2026-06-23 复核）

**状态**：编译器生产单元（`compiler/frontend|syntax|sema|toolchain|targets|ir|backend|diagnostics/*.pas`）
已无 `uses ... SysUtils` / `Classes` 导入（grep 核实）。`compiler/sema/np_semantic_analyzer.pas`
中残留的 `SysUtils` 字样仅是注释（行 1168/2148，描述 C6-H4 对外部单元 owned string return 的
处理），非导入。编译器自身已可被 nextPas 编译且不依赖 FPC SysUtils（self-compile-modules 19/19
全绿即为佐证）。`compiler/tests/*.pas` 是宿主 fpc 测试文件，允许使用 SysUtils，不在清零范围。

**C6-H4 task #90 收尾（2026-06-23）**：`gnkExitStatement` handler 由 `faba9ae1b` 落地
（`np_semantic_analyzer.pas` `NodeConsumesOwnedStringReturnDeferred` 内，`Exit(F())` 视为 safe
context）。专项回归测试 `tests/compiler/pass/exit_owned_string_return_pass.pas` 固化该 handler：
采用**顶层 warmup 赋值**（`GWarmup := F()`，走 `ScanTopLevelOwnedStringReturnConsumers` +
`AssignmentOwnsTopLevelStringReturn` 鲁棒注册路由，不依赖局部变量类型解析）登记 MakeGreeting/ExpandFileName
为 owned-string-return 函数，使 `Exit(F())` 真正进入 C6-H4 检查路径。自检确认：删除 handler 块后
fixture 即误报 `sema.c6h4-owned-string-return-deferred-consumer`（build 失败），证明 Pattern 1/2
（local/imported）为 handler 硬保护，删之必回归。task #90 关闭。

**注意**：测试的 registered-producer 路径选择很关键。早期版本用函数内 `LWarmup := F()` warmup，
走 `AssignmentOwnsStringReturn → IsSupportedOwnedStringReturnIdentifierTarget`（依赖局部变量 TypeId
解析为 String），在 pre-register 阶段类型信息未就绪时注册失败 → 测试空跑、删 handler 不回归。
必须用顶层赋值（或 `WriteLn(F())` 走 `WriteArgumentOwnsStringReturn`）才能稳定触发注册。

**历史迁移**：见 commits 0bb352198/abd3e6dc6/b70999215/c41ce7c1b/285d34d76（compiler SysUtils/Classes/Process → 框架内替代）。P1-Classes 清零：commit `aa8645dea`（http.impl.tls.stream TStream→IStream）。
剩余的 SysUtils 残留面在 core 框架（见 FOUNDATION P1）与测试/shim 层，不在本 lane。

---

## 阶段 2：Sema 攻坚（4-6 周）

### P2-1: 泛型构造器传播（2 周）

**解锁模块**: collections, crypto.argon2/hmac/p384/pkcs8（4 模块）

根因：`InstantiateGenericType`（line 436/7810）特化泛型时未正确传播基类构造器。

方案：实例化泛型类时，将模板类的 `Create` 重载集复制到实例类型。

---

### P3-class helper: Class helper 完整支持（2 周）

**解锁模块**: thread.future, text.format, text.conv, process.pipe, http.router 等

涉及 parser 级别改动 + sema 方法调度优先级规则。

---

### P3-forward: forward 声明 + nil 兼容性（1 周）

**解锁模块**: simd 等

- forward 声明：parser 支持后 sema 记录 pending 符号
- nil 兼容性：类型兼容规则扩展

---

### P2-3: 类型兼容性规则补全（1 周）

**解锁模块**: multipart, props

每个 case 是具体的类型对类型匹配，复杂度低。

---

### Sema 拆分重构（阶段 2 开始前，无行为变更）

15436 行单文件是严重技术债务。拆分为：

| 文件 | 职责 | 预估行数 |
|------|------|----------|
| `np_sema_expressions.pas` | 表达式求值 | ~3000 |
| `np_sema_types.pas` | 类型系统 | ~2000 |
| `np_sema_generics.pas` | 泛型实例化 | ~2000 |
| `np_sema_overloads.pas` | 重载解析 | ~1500 |
| `np_sema_string_lifetime.pas` | 字符串所有权跟踪（424 处引用，最大单体） | ~2000 |
| `np_semantic_analyzer.pas` | 协调者 | ~3000 |

---

## 阶段 3：RTL 清零（4-6 周）

### P1-Classes: core/src 清零 — ✅ 已完成（2026-06-23）

**状态**：编译器生产代码 0 引用 Classes（从未有过）。core/src 中唯一的直接 Classes 引用
（`nextpas.core.http.impl.tls.stream.pas`）已消除：`TStream`-based `TTcpStreamTransportStream`
替换为 `IStream`-based `TTlsTransportStream`，移除 `WrapTStream` 中间层（commit `aa8645dea`）。

剩余 Classes 消费者（不在清零范围）：
- `nextpas.core.system.classes.pas` — 桥接层，设计保留
- `units/linux-x86_64/Process.pas` — shim，留 Phase 9 前置
- `rtl/core/` + `core/tests/` — 宿主 FPC 编译，不受影响

### P1-平台绑定: 通过 platform 抽象层（2 周）

- 14 个 FFI 绑定通过 platform 抽象层
- `BaseUnix`/`Windows`/`Winsock2` 等

### P1-零散依赖: 收尾（1 周）

- 其他零散 FPC RTL 依赖

### FFI 绑定保留

以下属于 FFI 绑定，不必清零：
- `zlib` — 压缩算法绑定
- `OpenSSL` — TLS 加密绑定
- `ctypes` — C 类型绑定

---

## 阶段 4：自举冲刺（4-6 周）

1. 编译器源码全面自编译验证
2. 自举测试：用 nextPas 编译 nextPas，产出的编译器再编译自身
3. 回归测试建立
4. 里程碑：自举成功

**关键洞察**：自举不需要 LLVM 后端完美。只要 nextPas 能编译自身源码产出 LLVM IR，然后用系统 LLVM 工具链链接即可。`np_hir_llvm_emitter.pas`（1743 行）已存在且能输出 IR。LLVM 后端的打磨可以推迟到自举之后。

---

## 风险点

1. **Sema 单文件**: 15436 行是技术债务，阶段 2 前必须拆分
2. **class helper 复杂度**: FPC 的 class helper 涉及方法调度优先级规则，可能比预估更复杂
3. **P1 清零工作量**: ~90 个违规点，大部分是体力活但需要逐个验证
4. **并行编译正确性**: Pascal 的单元初始化顺序语义需要小心处理

## 当前工具链限制

- **无增量编译**: 每次重新 lex+parse+sema 全部传递依赖
- **无并行编译**: 顺序处理所有单元
- **Sema 单文件**: 15436 行，607 个方法，改动风险高

## 自举成功标准

1. `nextpas` 编译器能编译自身全部源码
2. 产出的编译器能再次编译自身（bootstrap 验证）
3. 核心运行时 (`nextpas.core.*`) 零 FPC RTL 依赖（FFI 绑定除外）
4. 性能：增量编译 <3s（158 单元），全量编译 <30s（600+ 文件）
