# Wave0 台账 — findings × residual（S0）

> **状态：历史台账（nofold33–35 时代）。** residual 数字已过期（305/1338 →
> 2026-07-26 实测 80/251）。当前唯一执行入口和实时数字：`docs/plans/m2/ROADMAP.md`；
> 探针：`scripts/m2-l3-residual.sh`。本文件保留策略冻结（F-002/F-003/F-009/F-012）
> 与分桶方法论，仍然有效。

- **Date**: 2026-07-25
- **Worktree**: `.worktrees/compiler-system` · `codex/compiler-system`
- **权威方案**: findings 整改总案（F-001–F-022）
- **审计源**: 仓库根 `findings.md`（临时，不进主线）
- **L3 基线**: `nofold33` / `nextpas.ll` mtime 2026-07-24 23:43
- **opt 首错**: `use of undefined value '@AOp'` @ `nextpas.ll:33911`
  `call i64 @AOp(i64 0, ptr, ptr)` — 参数/局部当 call，非真函数

## 策略冻结（Wave0 出口）

| 策略 | 冻结选择 | 对应 |
|------|----------|------|
| MIR 与 gen-B | **不参与** gen-B 正确性；生产路径 = Typed HIR → LLVM；MIR = experimental skeleton | F-012 |
| Allowlist | 基线 hash 只减不增；新增条目 = 债 | F-009 |
| Overload | 唯一最优否则 diagnostic；禁止 silent last-wins 作生产默认 | F-002 |
| 并发 stub | 禁止静默成功；先 fail-loud，真原子/mutex 后置 | F-003 |
| SameText 类 | 库调用 → `text.conv` owner；非 language intrinsic | F-001/P3 + 文档边界 |
| SizeOf/High/Length | language intrinsic / 合法 lower；禁止 residual `@SizeOf` | F-001/P2 |

### Allowlist 基线（F-009）

```
path: core/tests/nextpas.core.system/test_system_source_contracts/fpc_rtl_file_allowlist.txt
lines: 93
sha256: ab2d672baa4a0c145131bcd92f06c92f5495afbb4240102afe5e69af91bbda0a
```

验证：`sha256sum` 与本文件比对；Wave3 起 CI 只允许行数/条目减少。

### MIR 声明（F-012）

见 `compiler/README.md`：MIR/backend-plan skeleton **不**作为 M2 L3 / gen-B 正确性证据。
gen-B 证据链：`nextpas.ll` → `opt -O2` → `llc` → `ld` + `libnprt.a`。

### Overload 策略草案（F-002）

现状：`compiler/sema/np_sema_overload_lookup.inc` ~L215 / ~L290
注释明确 `C8/M2 permissive` → multi-unit same-signature **last index / last direct-import**。

目标评分（Wave1 实施）：

1. arity + 类型 exact > compatible
2. 本单元 root body
3. 直接 import
4. 传递 import
5. **唯一最优** → 绑定；`count>1` 同分 → diagnostic（可先 warn 计数，再生产 error）

首个验证：构造 ParamStr / SameText 双候选最小用例；期望绑定可解释或报歧义。

### 并发 stub 策略（F-003）

现状：`core/src/nextpas.core.system.thread.inc`
- `EnterCriticalSection` 空体
- `TryEnterCriticalSection` → `True`
- `Interlocked*` 非原子 RMW

Wave1-1a：fail-loud（raise / 文档+否定测试），禁止伪成功。
Wave1-1b：L3 residual `atomic_*` → LLVM atomic 或真 runtime define。
Wave2+：platform/sync owner 真 mutex。

## Residual 基线（nofold33）

| 指标 | 值 |
|------|-----|
| defined | 2109 |
| declared | 46 |
| unique calls | 1943 |
| **undefined unique** | **313** |
| **undefined total** | **1330** |
| 失败映射 | `toolchain.llvm-opt-exec-failed` |
| 产物 | `/tmp/m2-l3-out33` 空（未 link B） |
| log | `/tmp/m2-l3-nofold33.log` |
| opt err | `/tmp/m2-opt33.err` |

### 分桶 → Finding / Wave1 Phase

| Bucket | unique | total | 代表符号 | Finding | 修法相位 |
|--------|--------|-------|----------|---------|----------|
| project-helper | 104 | 323 | `RequireField$is`, `NormalizeUnitIdentity` | F-001 | Phase3 binding/mangling |
| sysutils-string | 9 | 303 | `SameText$is`, `Trim`, `ParamStr`, `ExpandFileName` | F-001 + owner | Phase3；SameText→text.conv |
| builtin-rtl | 2+ | ~250* | `SizeOf`, `High`, `Length`, `Low` | F-001 | Phase2 intrinsic |
| method-object | 76 | 187 | `TObject.Create`, `TGreenNode.Text` | F-001 | Phase4 |
| var-param-global | ~45 | ~150 | **`AOp`**, `Result`, `GThreadCache`, `$len` | F-001 | **Phase1（当前阻塞）** |
| atomic-concurrent | 15 | 67 | `atomic_store$iii`, `Interlocked*` | F-001 + F-003 | Phase2 / F-003-1b |
| const-type | 19 | 52 | `MaxInt`, `MAX_SIZE_INT`, `PLATFORM_PATH_SEP` | F-001 | Phase2 const fold |
| other | 43 | 52 | `platform_mutex_*`, simd globals | F-001 / F-005 | declare 或 wire |

\* `Length`/`Low` 在启发式里可能落入 var 桶；语义上仍归 **builtin-rtl**。

### 首错函数上下文

- 符号：`@AOp`（参数名 `AOp`，HIR 侧见大量 `strvar AOp` / `ProcessCondBr`）
- 形态：`call i64 @AOp(i64 0, ptr, ptr)` → **TString/参数未 seed 成 alloca+load，误走 residual call**
- 优先文件：`compiler/ir/np_hir_builder_emit.inc`（`EmitExprVar` / strvar）、param seed、TString `$ts`/`$len` 对称路径
- 相关 finding：F-001 Phase1；护栏 F-022（若再出现 parse 吞 body）

## Finding → Wave → 首个验证命令

| ID | Wave | 首个验证 |
|----|------|----------|
| F-001 | W1 | `opt -O2` on `nextpas.ll`；最终 `m2-two-hop.sh --phase build-b` |
| F-002 | W1 | overload 双候选 pass/fail + residual `ParamStr`/`SameText` 绑定可解释 |
| F-003 | W1 | thread stub 否定测试；atomic residual 有 define/declare |
| F-004 | W2 | lifecycle 最小 init/fini 可观察 |
| F-005 | W2 | compilerproc 对照表；L3 link 无缺符号 |
| F-006 | W2 | sysutils 无时间/env 直调 SysUtils 实现 |
| F-007 | W2 | RemoveDir 删目录测例绿 |
| F-008 | W3 | `compiler/**` uses SysUtils 计数下降 |
| F-009 | W3 | allowlist hash/行数 ≤ 基线 |
| F-010 | W2 | FindAlloca 热路径索引；L3 wall-time |
| F-011 | W4 | sema 按数据流可导航 |
| F-012 | W0/W4 | README experimental（本文件 + README） |
| F-013 | W4 | ZeroMem 签名 source-contract |
| F-014 | W3 | classes 文档=代码 |
| F-015 | W3 | kernel stub / FS 否定与语义测 |
| F-016 | W3 | residual 桶最小 compiler-pass |
| F-017 | W4 | 缓存进 session |
| F-018 | W3 | sysutils 表面文档=interface |
| F-019 | W4 | FreeAndNil 单实现 |
| F-020 | W4 | 仅机检 KPI |
| F-021 | W4 | backend 边界文档或迁移 |
| F-022 | W1 | soft-keyword 表 + parse 回归 |

## 下一刀（Wave1 立即）

1. ~~修 `@AOp` 类 strvar/param residual~~ **DONE nofold34**：过程参数 → `hikIndirectCall`；`@func` → `funcref`/`func_ref`
2. ~~`@AppendImportedUnitCacheEntry` 等 method→free-helper 未 seed~~ **DONE nofold35**：
   - `EnqueueBody` 允许 method 入队；method 用 `WalkGreenForCallTargets`（仅 gnkFunctionCall）
   - `MarkBodiesFromTypedHirCalls` 扫描 operand blob 中 `call Name`
   - 证据：`AppendImportedUnitCacheEntry`/`NormalizeUnitIdentity`/`FindCachedUnit` 已 `define`；needed 643→903→1981；defined 2109→2506
3. **当前 opt 首错（nofold35）**：`np_tstring_from_int` i32 vs i64 — 已补 `EmitCastValueToLlvmType`（待 nofold36 验证）
4. 下一桶：SizeOf/Length/High intrinsic；SameText→text.conv；atomic；method Create/Destroy
5. 不并行：sema 大拆、compiler 去 SysUtils、MIR 生产化

### nofold34 增量（2026-07-25）

| 项 | 值 |
|----|-----|
| 首错 | `@AppendImportedUnitCacheEntry`（非 `@AOp`） |
| log | `/tmp/m2-l3-nofold34.log` |
| opt | `/tmp/m2-opt34.err` |
| 修法 | `EmitExprCall` + `EmitIndirectCallInstr` + encode `funcref` |

### nofold35 增量（2026-07-25）

| 项 | 值 |
|----|-----|
| 首错 | `i32` vs `i64` `@np_tstring_from_int`（非 undefined symbol） |
| needed/encoded | 1981 / 1977（was 1541/1538） |
| defined | 2506（was ~2109） |
| undefined unique/total | 305 / 1338 |
| log | `/tmp/m2-l3-nofold35.log` |
| 修法 | method call-target reachability + blob call scan |

## 探针命令（固定）

```bash
./scripts/rebuild-compiler.sh
/bin/cp -f build/stage0-bootstrap/nextpas nextpas-m2-l3-probe
rm -f .nextpas/cache/backend/linux-x86_64/nextpas.ll
./nextpas-m2-l3-probe build tools/stage0/nextpas.pas \
  --target linux-x86_64 \
  --toolchain-binding linux-x86_64-to-linux-x86_64-llvm \
  --workspace "$PWD" --out-dir /tmp/m2-l3-outN
opt -O2 -o /dev/null .nextpas/cache/backend/linux-x86_64/nextpas.ll
```

## S0 出口检查

- [x] residual 分桶 + 首错 `@AOp`
- [x] bucket → finding/phase 映射
- [x] allowlist 基线 hash
- [x] MIR experimental 策略写清（+ README 补丁）
- [x] F-002 / F-003 策略写清
- [x] Finding → Wave → 验证命令表