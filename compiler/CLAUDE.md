# compiler/CLAUDE.md — 编译器工程治理

## 模块结构

```
compiler/
├── frontend/     ← 编译会话、包管理、单元图、搜索路径
├── syntax/       ← Lexer、Preprocessor、Green Tree、AST Facade
├── sema/         ← 语义分析器、语义模型
├── ir/           ← HIR Builder、HIR Model、LLVM Emitter、Verifier
├── backend/      ← 后端计划、代码生成
├── diagnostics/  ← 诊断基础设施
├── targets/      ← 目标平台配置
└── tests/        ← 编译器单元测试
```

## 模块契约

### 边界规则
- **frontend** 不依赖 sema/ir/backend（只提供编译会话和解析基础设施）
- **syntax** 不依赖 sema/ir/backend（纯语法分析）
- **sema** 依赖 syntax/frontend，不依赖 ir/backend
- **ir** 依赖 sema/frontend，不依赖 backend
- **backend** 依赖 ir/frontend
- **diagnostics** 和 **targets** 被所有模块依赖

### 代码规范
- 所有文件必须有 `{$mode ObjFPC}{$H+}`
- 类型前缀：`T` record/class, `I` interface, `E` exception
- 变量前缀：`L` local, `A` parameter, `F` field
- 2-space 缩进
- 函数不超过 100 行（超过必须拆分）

### np_semantic_analyzer.pas 治理
原 17,735 行，已拆分为 3 文件 (12,175 + 2,217 + 3,345)。
已完成提取:
- `np_sema_string_ops.inc` — 字符串所有权追踪 (2,217 行)
- `np_sema_runtime_expr.inc` — BuildRuntimeScalarHirExpr (3,345 行)
- `np_sema_name_set.pas` — 名称集合查找 (O(log n), 100 行)

进一步拆分计划:
- `np_sema_overload.pas` — 重载解析 (LookupCallBindingDeclaration 等)
- `np_sema_type_check.pas` — 类型检查和推导
- `np_sema_call_binding.pas` — 调用绑定和成员解析
- `np_sema_hir_gen.pas` — HIR 生成

## 质量门禁

### 提交前必须通过
1. `make test TEST_FILTER=compiler-pass` — 34/34 pass
2. `make test TEST_FILTER=compiler-fail` — snapshot 匹配
3. `make hygiene` — 无散落产物
4. `scripts/rebuild-compiler.sh` — 编译器重建成功

### 代码变更流程
1. **分析** — 先读相关代码，理解上下文
2. **计划** — 明确改什么、为什么改、影响范围
3. **实现** — 最小改动原则
4. **验证** — 通过所有质量门禁
5. **提交** — 有意义的 commit message

### 测试要求
- 新增功能必须有对应测试
- bug 修复必须有回归测试
- 测试放在 `compiler/tests/` 或 `tests/compiler/`

## 编译器 CLI

```bash
# 编译单个文件
build/stage0-bootstrap/nextpas build <source> --target linux-x86_64 --workspace .worktrees/compiler

# 重建编译器
scripts/rebuild-compiler.sh

# C8 全量扫描
bash scripts/c8_scan.sh
```

## 当前状态 (2026-07-01)
- compiler-pass: 30/30 ✅
- self-compile: 19/19 ✅
- C8 scan: 856/965 (88.7%), 语义通过率 97.7%
- 主要债务: sema 主文件 12,175 行 (已从 17,735 行拆分), permissive overload 是临时方案

## 已知技术债
- ~~IsBuiltinProcedure 函数列表过长（150+ 函数），需重构为注册表~~ ✅ 已完成
- ~~IsDeferredSystemObjectMember 扩展过多（30+ 方法），需接口方法解析~~ ✅ 已清理并组织
- ~~sema 17,735 行需拆分~~ ✅ 已拆分为 3 文件 (12,175 + 2,217 + 3,345)
- Permissive overload resolution（选第一个候选）是 C8 临时方案
- C6-H4 owned string return 限制需编译器级修复
