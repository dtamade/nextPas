# Generics Implementation Findings

## 当前状态（2026-05-28）

### Parser
- FPC `generic TBox<T> = class` 语法已能解析（`tests/parser/generics_pass.pas` 通过）
- `<T>` type params 被 parser 跳过（不保留到 AST）
- `specialize TBox<Integer>` 被解析为普通 type reference

### Semantic Analyzer
- `specialize TBox<Integer>` 被当作普通 type alias
- 不产生 instantiated member truth
- `B.SetValue(42)` 不报错但也不绑定（binding count = 0）
- 没有 constraint checking

### 需要实现的核心能力

1. **Parser 保留 type params**：`<T>` 不再跳过，产出 type param nodes
2. **Generic type registration**：`TBox<T>` 注册为 generic type，记录 type params
3. **Instantiation**：`specialize TBox<Integer>` 触发 monomorphization，生成 `TIntBox` 的完整 member truth
4. **Member substitution**：`SetValue(V: T)` 在 `TIntBox` 中变为 `SetValue(V: Integer)`
5. **Call binding**：`B.SetValue(42)` 能正确绑定到 instantiated method

### 实现计划

| 步骤 | 内容 | 复杂度 |
|------|------|--------|
| 1 | Parser 保留 type params 到 AST | 中 |
| 2 | Semantic model 加 generic type metadata | 低 |
| 3 | ProcessTypeSection 识别 generic type 并注册 | 中 |
| 4 | 遇到 specialize 时触发 instantiation | 高 |
| 5 | Instantiation 产生 member truth（替换 T → Integer） | 高 |
| 6 | Instantiated type 参与 member call resolution | 低（已有基础设施） |

步骤 4-5 是核心难点。需要：
- 找到 generic type 的 AST（class body）
- 遍历所有 member declarations
- 用具体类型替换 type param
- 注册 instantiated members 到 semantic model
