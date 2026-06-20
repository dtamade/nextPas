# 自举障碍路线图

> 最后更新: 2026-06-21
> 状态: 活跃规划
> 目标: 用 nextPas 编译 nextPas（自举）

## 当前状态

**55 个 facade 模块编译结果**:
- ✅ success: 30 (55%)
- 🟡 toolchain:ready (host FPC 链接失败): 15 (27%)
- ❌ 未通过: 10 (18%)

---

## P0: 编译器性能 — 增量编译（阻塞批量验证）

### 问题

编译器**无增量缓存**：每次编译都重新分析全部传递依赖。

| 模块 | 解析单元数 | 耗时 | 每单元耗时 |
|------|-----------|------|-----------|
| base | 3 | 0.22s | 73ms |
| yaml | 67 | 6.4s | 96ms |
| collections | 158 | 16s | 101ms |
| **全量 55 模块** | **~2000 次重复解析** | **~10 分钟** | — |

### 根因

`np_unit_resolver.pas` 每次编译从头解析所有 `.pas` 文件：
1. 读取源文件 → lexer → parser → sema
2. 67 个单元 = 67 次完整 lex+parse+sema
3. 无 PPU/缓存机制，无增量依赖图

### 解决方案

**Phase 1: Unit PPU 缓存**（最高优先级）
- 编译成功后将解析结果（AST + symbol table）序列化为 `.ppu` 文件
- 下次编译同一单元时直接加载 `.ppu`，跳过 lex+parse+sema
- 预期提速：67 单元从 6.4s → <1s（只需解析根文件 1 个）

**Phase 2: 依赖图增量更新**
- 只重新编译源文件有变更的单元
- 使用文件 hash 或 mtime 判断变更
- 预期：修改 1 个文件后重编译 <0.5s

**Phase 3: 并行编译**
- 无依赖关系的单元并行编译
- 利用多核 CPU
- 预期：全量编译从 10 分钟 → <1 分钟

### 验收标准

```bash
# 冷编译（无缓存）
time nextpas build core/src/nextpas.core.yaml.pas  # <1s

# 热编译（有缓存，无变更）
time nextpas build core/src/nextpas.core.yaml.pas  # <0.2s

# 增量编译（修改 1 个依赖文件后）
touch core/src/nextpas.core.base.pas
time nextpas build core/src/nextpas.core.yaml.pas  # <0.5s
```

---

## P1: FPC RTL 依赖清零（违反架构约束）

### 约束

> nextpas.core 框架内 system 模块以外不得依赖 FPC RTL 单元。
> system 模块仅为兼容 FPC 编译时路由到相关包装（包装内联性能）。

### 当前违规统计

| FPC 单元 | 违规模块数 | 涉及模块 |
|----------|-----------|---------|
| **SysUtils** | 23 | errors, exception, platform.*, io.*, mem.*, tls.*, log 等 |
| **Classes** | 22 | crypto.hash, http.impl.*, tls.* (大量), io.stream_adapter |
| **Math** | 8 | log, yaml.writer, crypto.*, mem.arena/blockpool/pool |
| **BaseUnix/Unix** | 7 | io.uring, simd.cpuinfo, tls.*, tui.clipboard |
| **Windows/Winsock2** | 12 | tls.winssl.*, simd.cpuinfo, tls.openssl.api |
| **ctypes** | 5 | git.libgit2.*, tls.openssl.connection, simd.cpuinfo |
| **DateUtils** | 4 | git.libgit2.backend, tls.crl, tls.mbedtls |
| **zlib** | 4 | compress.base/deflate/gzip/zlib.ffi |
| **Base64** | 2 | tls.freepascal.context, tls.mbedtls.context |
| **Sockets** | 3 | tls.freepascal.connection, tls.nonblocking, tls.mbedtls |
| **Variants** | 1 | collections.base |
| **Registry** | 1 | tls.winssl.enterprise |
| **总计** | **~90 个违规点** | |

### 清理路线

#### Phase 1a: Math 清零（8 模块，难度低）

`Math` 只用了几个函数：`Max`, `Min`, `Ln`, `Floor`, `Ceil`。

**方案**: 在 `nextpas.core.math` 中提供这些函数，模块改用 `nextpas.core.math.Max` 等。

涉及模块:
- [ ] `nextpas.core.log` — `Math` → `nextpas.core.math`
- [ ] `nextpas.core.yaml.writer` — `Math` → `nextpas.core.math`
- [ ] `nextpas.core.crypto.aesni` — `Math` → `nextpas.core.math`
- [ ] `nextpas.core.crypto.argon2` — `Math` → `nextpas.core.math`
- [ ] `nextpas.core.crypto.pbkdf2` — `Math` → `nextpas.core.math`
- [ ] `nextpas.core.crypto.pkcs8` — `Math` → `nextpas.core.math`
- [ ] `nextpas.core.mem.arena.growable` — `Math` → `nextpas.core.math`
- [ ] `nextpas.core.mem.blockpool.growable` — `Math` → `nextpas.core.math`
- [ ] `nextpas.core.mem.pool.fixed.growable` — `Math` → `nextpas.core.math`
- [ ] `nextpas.core.tls.debug.utils` — `Math` → `nextpas.core.math`
- [ ] `nextpas.core.math.quat.base` — `Math` → `nextpas.core.math` (自引用)
- [ ] `nextpas.core.math.vec.base` — `Math` → `nextpas.core.math` (自引用)

#### Phase 1b: SysUtils 清零（23 模块，难度中）

`SysUtils` 提供: 字符串操作、文件操作、类型转换、异常类。

**方案**:
- 字符串/类型转换 → `nextpas.core.text.conv` (已有)
- 文件操作 → `nextpas.core.fs` (已有)
- 异常类 → `nextpas.core.exception` (已有)
- `Format` → `nextpas.core.text.format` (已有)

涉及模块（按优先级）:
- [ ] `nextpas.core.errors` — 最底层，影响面最大
- [ ] `nextpas.core.exception` — 异常类定义
- [ ] `nextpas.core.platform.error` / `platform.mmap`
- [ ] `nextpas.core.io.*` (slab_pool, stream_adapter, reactor.iocp)
- [ ] `nextpas.core.mem.*` (mimalloc, pool.fixed)
- [ ] `nextpas.core.log` (间接依赖)
- [ ] `nextpas.core.tls.*` (20+ 模块)

#### Phase 1c: Classes 清零（22 模块，难度中高）

`Classes` 提供: `TStream`, `TStringList`, `TFileStream`。

**方案**: 使用 `nextpas.core.io.intf.IStream` 替代 `TStream`，`TStringList` 用 `nextpas.core.text.builder` 或 `TArray<string>` 替代。

涉及模块:
- [ ] `nextpas.core.crypto.hash` — `Classes` → `nextpas.core.io.intf`
- [ ] `nextpas.core.http.impl.tls.stream` — `Classes` → `nextpas.core.io.intf`
- [ ] `nextpas.core.io.stream_adapter` — `Classes` → `nextpas.core.io.intf`
- [ ] `nextpas.core.tls.*` (18+ 模块) — 最大工作量

#### Phase 1d: 平台绑定清零（BaseUnix/Unix/Windows/Sockets，难度高）

平台绑定是 TLS 模块的底层依赖，需要通过 `nextpas.core.platform` 抽象层替代。

**方案**:
- `BaseUnix.fpSocket/fpConnect` → `nextpas.core.platform.socket`
- `BaseUnix.fpEpollCreate` → `nextpas.core.platform.io`
- `Sockets.TSockAddr` → `nextpas.core.platform.socket.TSockAddr`
- `Windows.*` → `nextpas.core.platform.windows.*`

涉及模块:
- [ ] `nextpas.core.io.uring` — `BaseUnix` → `nextpas.core.platform.io`
- [ ] `nextpas.core.simd.cpuinfo.*` — `Unix/Windows` → `nextpas.core.platform`
- [ ] `nextpas.core.tui.clipboard` — `BaseUnix/Unix` → `nextpas.core.platform`
- [ ] `nextpas.core.tls.freepascal.connection` — 6 个 FPC 单元
- [ ] `nextpas.core.tls.nonblocking` — 4 个 FPC 单元
- [ ] `nextpas.core.tls.winssl.*` — 6 个 FPC 单元

#### Phase 1e: 其他零散依赖

- [ ] `nextpas.core.collections.base` — `Variants` → 移除或用 `nextpas.core.base` 替代
- [ ] `nextpas.core.git.libgit2.*` — `ctypes/DateUtils/SysUtils` → `nextpas.core.base`/`nextpas.core.time`
- [ ] `nextpas.core.compress.*` — `zlib` → 保留为 FFI 绑定（允许，但需标记为 FFI 层）
- [ ] `nextpas.core.tls.*` — `Base64/Registry/OpenSSL` → 保留为 FFI 绑定

### 清理优先级

```
P1-1: Math 清零        → 8 模块，1-2 天
P1-2: SysUtils 清零    → 23 模块，3-5 天
P1-3: Classes 清零     → 22 模块，5-7 天
P1-4: 平台绑定清零     → 12 模块，5-10 天
P1-5: 零散依赖清零     → 10 模块，2-3 天
```

### FFI 层例外

以下依赖**允许保留**（它们是 FFI 绑定，不是 RTL 依赖）：
- `zlib` → `nextpas.core.compress.zlib.ffi` (FFI 绑定)
- `OpenSSL` → `nextpas.core.tls.openssl.backed` (FFI 绑定)
- `Base64` → 可选保留，或用 `nextpas.core.encoding` 替代
- `ctypes` → 可选保留，或用 `nextpas.core.base` 的 C 类型别名

---

## P2: Sema 能力缺失（阻塞 10 个模块）

### P2-1: 泛型构造器解析（collections, crypto.argon2/hmac/p384/pkcs8）

**问题**: `specialize TConcurrentHashMap<K,V>.Create(...)` 的 `Create` 方法在泛型特化后无法解析。

**根因**: sema 的 overload resolution 不支持从泛型基类继承的构造器。

**方案**: 在泛型特化时正确传播基类的构造器声明。

### P2-2: 类继承链 Create 解析（config）

**问题**: `EConfigError.Create(...)` — `EConfigError = class(EParseError)` 的 `Create` 无法找到。

**根因**: sema 在解析 `Create` 时未正确遍历类继承链到 `Exception.Create`。

**方案**: 在 member resolution 中添加类继承链遍历。

### P2-3: 类型兼容性（multipart, props）

**问题**: `sema.type-mismatch` — 赋值或参数传递时类型不兼容。

**方案**: 需要具体分析每个 case，可能是隐式类型转换缺失。

### P2-4: unknown-member / unknown-callable（regex, config 子模块）

**问题**: 某些成员或可调用对象无法解析。

**方案**: 需要具体分析每个 case。

---

## P3: Parser 语法支持缺失（阻塞多个子模块）

### P3-1: `class helper for` 完整支持

涉及: `thread.future`, `text.format`, `text.conv`, `process.pipe`, `http.router` 等。

### P3-2: `generic` / `specialize` 高级语法

涉及: `mem.pool.object_pool`, `config.*`, `collections.*`。

### P3-3: 其他 parser syntax-error

每个需要具体分析。当前有 ~20 个子模块因 parser syntax-error 失败。

---

## P4: Lexer 能力缺失

### P4-1: 更多数字字面量格式

当前已有: 十六进制 `$FF`, 八进制 `&77`, 二进制 `%01`, 小数 `1.5`。
可能缺失: 科学计数法 `1.5e10`, 下划线分隔 `1_000_000`。

---

## P5: toolchain 链接失败（15 个模块）

### 问题

这些模块**编译器处理完全成功**（syntax → resolution → sema → IR → backend → toolchain 全部 ready），但 FPC host 编译器链接阶段失败。

### 根因

nextpas 编译器生成的中间表示（HIR/MIR）与 FPC 的代码生成不完全兼容。编译器本身处理了所有前端阶段，但在最后一步调用 FPC 生成目标代码时失败。

### 方案

这是 LLVM 后端的目标。当 LLVM 后端完成后，这些模块将直接通过 LLVM 编译，不再依赖 FPC host 编译器。

**短期**: 保持现状，这些模块在语义上是正确的。
**中期**: LLVM 后端完成后自动解决。

---

## 执行顺序

```
P0: 增量编译     ← 最高优先级，解锁批量验证
P1-1: Math 清零  ← 最简单的 FPC 依赖清理
P2-2: 类继承链   ← 解锁 config 模块
P1-2: SysUtils   ← 最广泛的依赖清理
P2-1: 泛型构造器 ← 解锁 collections + crypto
P1-3: Classes    ← TLS 模块清理
P1-4: 平台绑定   ← TLS/IO 模块清理
P3: Parser 语法  ← 解锁子模块
P1-5: 零散依赖   ← 收尾
P5: LLVM 后端    ← 长期目标
```

---

## 关联文档

- `compiler/docs/compiler-goal-tree.md` — 编译器目标树
- `docs/adr/` — 架构决策记录
- `core/AGENTS.md` — core 模块 AI 协作入口
- `memory/compiler-arch-debt-roadmap.md` — 编译器架构债务
- `memory/fpc-sysroot-mechanism.md` — FPC sysroot 机制
- `memory/fpc-shadow-set-inventory.md` — shadow set 符号清单
