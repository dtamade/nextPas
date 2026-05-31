# D-1: 编译器系统化测试矩阵设计

> **Goal:** 从 98 个 smoke tests 扩展到 300+ 分层测试，覆盖 Lexer/Parser/Sema/Codegen 各阶段。

## 测试分层架构

```
Layer 4: Smoke Tests (end-to-end, compile+run, verify exit code)
         当前: 98 个 → 目标: 130+
         位置: examples/smoke/llvm_*.pas

Layer 3: Integration Tests (compile, verify diagnostics/IR output)
         当前: verify_local.sh 1953 patterns
         位置: tests/compiler/pass/, tests/compiler/fail/

Layer 2: Sema Tests (negative tests, type errors, scope errors)
         当前: 9 个 fail tests → 目标: 80+
         位置: tests/sema/fail/, tests/sema/pass/

Layer 1: Lexer/Parser Tests (token/AST verification)
         当前: 14 lexer tests → 目标: 40+
         位置: tests/lexer/, tests/parser/
```

## 执行顺序（按 ROI）

### Phase 1: Sema 负面测试（最薄弱，ROI 最高）
- 类型不匹配（assign Integer to String, etc）
- 未声明标识符（各种上下文）
- 重复声明
- 参数数量/类型不匹配
- 不合法的 override/virtual 使用
- interface 实现缺失方法
- 泛型 arity 不匹配
- 循环继承检测
- 目标: +70 tests

### Phase 2: LLVM Codegen 边界条件
- 整数溢出（MaxInt + 1）
- 空数组操作
- nil 对象方法调用（应 segfault 或 trap）
- 深递归（栈溢出边界）
- 大数组（1000+ 元素）
- 多层继承（5+ 层）
- 复杂表达式嵌套
- 目标: +40 tests

### Phase 3: Parser 错误恢复
- 缺少分号后继续解析
- 缺少 end 后恢复
- 不完整的表达式
- 多个错误在同一文件中
- 目标: +30 tests

### Phase 4: Lexer 边界条件
- 超长标识符（1000+ chars）
- 超大数字字面量
- 深嵌套注释
- Unicode 标识符
- 空文件/只有注释的文件
- 目标: +20 tests

## 验证方式

| 层 | 验证方式 | 工具 |
|----|----------|------|
| Smoke | exit code | verify_local.sh |
| Sema fail | diagnostic-message pattern | verify_local.sh |
| Sema pass | status=success + no errors | verify_local.sh |
| Parser | green-node-count / AST structure | lex_snapshot |
| Lexer | token-count / token patterns | lex_snapshot |

## 内存泄漏检测

- 编译器自身：FPC 的 heaptrc 单元（编译时 -gh 开关）
- 生成的代码：freestanding 环境无 malloc/free，用 brk 分配不释放
  → Phase 1 不做（freestanding 无泄漏概念）
  → Phase 2 加 refcount 验证（interface 对象 refcount 归零检查）

## 成功标准

- 总测试数 ≥ 300
- Sema 负面测试 ≥ 70（覆盖所有诊断 code）
- 所有测试在 verify_local.sh 中自动运行
- 零 regression（新测试不破坏现有 pass）
