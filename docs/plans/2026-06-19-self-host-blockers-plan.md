# P5 Self-Hosting: Default Parameter + Overload Resolution 修复计划

> **上下文**: 自举构建发现 74 个语义错误阻塞 self-hosting。经分析确认：
> - 默认参数在简单场景下已正常工作（单文件 + 跨单元测试均 0 错误）
> - 但在完整的自举构建中，56 个 Fail 调用报 "wrong-argument-count"
> - 另有 18 个 "ambiguous-overload" 错误涉及 3 个函数

## 1. 当前阻塞清单

### 1.1 Fail wrong-argument-count (56 个)

**现象**: `Fail(AState, 'msg')` 被报参数数量错误

**已验证**:
- 默认参数语法解析已实现 (np_green_tree.pas:1948-1966)
- `CountRequiredDeclParams` 已正确处理 `ParamChild.ChildCount <= 1` 判定
- `DeclAcceptsArgCount` 已使用 Min/Max 参数计数
- 简单跨单元默认参数测试通过 (0 错误)

**待诊断**:
- 完整自举构建中为何 Fail 默认参数不生效
- 可能原因：单元加载顺序、导入链中的降级、或特定于大规模构建的 bug

**诊断计划**:
1. 精确重现：构造包含大量 uses 的多单元项目，引入默认参数
2. 添加日志：在 `DeclAcceptsArgCount`/`CountRequiredDeclParams` 中追踪 Fail 的参数计数
3. 检查 `nextpas_command_envelope.pas` 的解析树是否完整保留了默认值子节点

### 1.2 Ambiguous Overload (18 个)

**受影响函数**:
- `BuildToolArtifactArrayJson` (4 个错误)
- `AppendString` (4 个错误)
- `DecodePascalStringLiteral` (10 个错误)

**诊断计划**:
1. 定位这些函数的所有重载声明
2. 分析每个调用点的参数签名
3. 确定 overload resolution 在哪一步失败（名称匹配 vs 签名匹配 vs 类型兼容性）

## 2. 修复策略

### 方案 A: 诊断 + 修复编译器（推荐）

修复编译器中导致默认参数在大规模构建中失效的 bug。这是最正确的方向。

### 方案 B: 修改 stage0 源码（备选）

- 给所有 2-arg Fail 调用补上 `False` 第三参数
- 解决重载歧义：通过类型标注或重命名消除歧义
- 优点：快速绕过；缺点：是 workaround 不是 fix

### 推荐路径

先执行方案 A 的诊断步骤。如果 bug 复杂度超出预期，切换到方案 B 先让自举通过，再回来修编译器。

## 3. 详细执行步骤

### Phase 1: 诊断 (本轮)

1. [ ] 创建精确重现的多单元测试用例
2. [ ] 在 DeclAcceptsArgCount 添加诊断日志
3. [ ] 检查 nextpas_command_envelope.pas 的 AST 中默认值节点
4. [ ] 分析 3 个 ambiguous-overload 函数的重载签名

### Phase 2: 修复 (下轮)

根据 Phase 1 诊断结果确定修复方案。

### Phase 3: 验证

1. [ ] 自举构建 0 错误
2. [ ] 所有 smoke 测试仍然全绿
3. [ ] 新增默认参数 + 重载消歧义的专门测试用例

## 4. 风险评估

| 风险 | 影响 | 对策 |
|------|------|------|
| 默认参数 bug 在更深层次 | 自举延期 | 先用方案 B 绕过 |
| 重载歧义需要大改 overload resolution | 影响面大 | 先消歧义调用方 |
| 修复引入回归 | 破坏现有测试 | Codex 审查 + 完整回归 |
