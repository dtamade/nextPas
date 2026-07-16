# mem 可用性实施规划（F1–F7 + R1–R5 + S1–S3）

**状态**: S1–S3 implemented
**前置**: [USABILITY-EVAL-2026-07-17.md](USABILITY-EVAL-2026-07-17.md) · [USABILITY-FINDINGS-RESEARCH.md](USABILITY-FINDINGS-RESEARCH.md)
**日期**: 2026-07-17
**确认门**: 评估 + 调研 + 本计划落盘后 **统一实施**（禁止边调边改设计）

### 实施检查清单

- [x] M0–M7 F1–F7（已落地）
- [x] M8–M11 R1–R5（已落地）
- [x] M12 S1 TryReallocMemOf 与 ReallocMemOf 成功语义对称
- [x] M13 S3 guardrails + check_usability_docs
- [x] M14 S2 error.pas 对齐 raise 用 FormatAllocErrorMsg
- [x] M15 文档复评 USABILITY-SCORE **9.3**

---

## 1. 里程碑（三轮 S1–S3）

| M | 名称 | 交付 | 依赖 | 优先级 |
|---|------|------|------|--------|
| **M12** | Try 对称 | S1：删 `TryReallocMemOf` 错误早退 | 无 | **P1** |
| **M13** | 门禁 | S3：`TestTryReallocMemOfNilAllocatorGetMem` + docs 锁 | M12 | **P0** |
| **M14** | 错误助手 | S2：`SanitizeRuntimeAlignment` / `SanitizeConfigAlignment` | 无 | **P2** |
| **M15** | 复评 | SCORE/EVAL/RESEARCH/FIX-PLAN | M12–M14 | **P2** |

### 依赖图

```text
M12 TryReallocMemOf ──► M13 guardrails
M14 error.pas ─────────► M15 docs
M12 / M13 ─────────────► M15 docs
```

---

## 2. 实现要点（冻结设计）

1. **删除** `TryReallocMemOf` 中 `(AAllocator=nil) and (APtr=nil) and (ANewSize>0)` 早退。
2. 保留：`Result := (ANewPtr <> nil) or (ANewSize = 0)`；权威语义在 `ReallocMemOf`。
3. S2 **仅** `error.pas` 对齐校验；不扫 pool/blockpool 历史 raise。
4. **不**默认开 HEAP_SAFETY / ARENA_STRICT / DEBUG。

---

## 3. 验证（M15）

```bash
make focused FOCUS=core/tests/nextpas.core.mem/test_usability_guardrails
make focused FOCUS=core/tests/nextpas.core.mem/test_contract_matrix
make focused FOCUS=core/tests/nextpas.core.mem/test_error
make focused FOCUS=core/tests/nextpas.core.mem/test_debug_wrap
make hygiene
```

| 发现 | 验收 |
|------|------|
| S1 | `TryReallocMemOf(nil,nil,0,N,P)` → True + non-nil；可 FreeMem |
| S2 | 非法对齐 raise 消息含 `Type.Method:` stem |
| S3 | guardrails + check_usability_docs 锁 S1/S2 |

---

## 4. 回滚

恢复 `TryReallocMemOf` 早退；对齐消息回裸字符串；删对应测试。

## 5. 非目标

双轨合并、默认安全税、EOutOfMemory 继承树大迁移、门面大规模删 Tier-2、全库 pool raise 格式扫改。
