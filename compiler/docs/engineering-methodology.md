# 编译器工程方法论 — Codex 式开发规范

## 核心原则

### 1. 契约驱动
- 每个模块有明确的输入/输出契约
- 接口先于实现：先定义 `.intf.pas`，再写实现
- 测试即契约：测试用例就是模块行为的可执行规范

### 2. 最小变更
- 一个 commit 只做一件事
- 改动范围不超过 200 行（超过必须拆分 commit）
- 重构和功能变更分开提交

### 3. 验证闭环
- 改代码 → 跑测试 → 通过才提交
- 不通过的测试不能提交
- 回归测试必须覆盖已知 bug

### 4. 文档同步
- 代码改了，文档必须同步更新
- CLAUDE.md 反映当前真实状态
- 不留过期文档

## 开发流程

### Step 1: 分析
```
1. 读相关代码，理解上下文
2. 检查是否有现有测试覆盖
3. 确认影响范围（哪些模块会受影响）
4. 检查是否有相关 issue/计划
```

### Step 2: 计划
```
1. 明确要改什么
2. 明确为什么改
3. 列出需要修改的文件
4. 确定测试策略
5. 评估风险
```

### Step 3: 实现
```
1. 最小改动原则
2. 保持代码风格一致
3. 添加必要的注释（不解释 what，只解释 why）
4. 不引入新的技术债
```

### Step 4: 验证
```
1. 本地测试通过
2. 无编译警告
3. 无内存泄漏（heaptrc）
4. 代码风格检查
```

### Step 5: 提交
```
1. 有意义的 commit message
2. 格式: <type>(<scope>): <description>
3. 类型: feat/fix/refactor/test/docs/chore
4. 范围: sema/ir/parser/lexer/backend/frontend
```

## 质量门禁矩阵

| 门禁 | 命令 | 通过标准 |
|------|------|----------|
| 编译器编译 | `scripts/rebuild-compiler.sh` | 40000+ lines compiled |
| Pass 测试 | `make test TEST_FILTER=compiler-pass` | 30/30 |
| Fail 测试 | `make test TEST_FILTER=compiler-fail` | snapshot 匹配 |
| 产物卫生 | `make hygiene` | 0 violations |
| 自编译 | 19/19 self-compile files | 全部通过 |
| C8 语义 | `bash scripts/c8_scan.sh` | ≥97% semantic pass |

## 技术债管理

### 债务分类
- **P0 (阻塞)**: 阻止编译器正常工作
- **P1 (影响)**: 影响代码质量或可维护性
- **P2 (改善)**: 可以改善但不紧急

### 当前债务清单
| ID | 描述 | 等级 | 状态 |
|----|------|------|------|
| D-001 | sema 17,600 行需拆分 | P1 | 计划中 |
| D-002 | ~~IsBuiltinProcedure 150+ 函数列表~~ | P1 | ✅ 已完成 (157d02355) |
| D-003 | Permissive overload 是临时方案 | P2 | 已知 |
| D-004 | C6-H4 owned string return 限制 | P2 | 已知 |
| D-005 | 接口方法解析缺失 | P1 | 计划中 |
| D-006 | 泛型字段访问不支持 | P2 | 已知 |

### 债务偿还规则
- 每个 sprint 至少偿还 1 个 P1 债务
- P0 债务必须在发现后 24 小时内修复
- 债务修复必须有回归测试

## 文件命名规范

### 模块文件
```
np_<module>.pas              ← 主模块
np_<module>_<sub>.pas        ← 子模块
np_<module>_model.pas        ← 数据模型
np_<module>_intf.pas         ← 接口定义
np_<module>_verifier.pas     ← 验证器
```

### 测试文件
```
test_<module>_<feature>.pas  ← 单元测试
test_<module>_contract.pas   ← 契约测试
test_<module>_smoke.pas      ← 冒烟测试
```

## 分支策略

### 分支命名
```
feat/<scope>-<description>   ← 新功能
fix/<scope>-<description>    ← Bug 修复
refactor/<scope>-<description> ← 重构
test/<scope>-<description>   ← 测试相关
docs/<scope>-<description>   ← 文档更新
```

### Worktree 规则
- 一个 worktree 只负责一个任务
- 完成后必须清理 worktree
- 不要在 worktree 中积累未提交的更改

## 代码审查清单

### 必查项
- [ ] 是否通过所有质量门禁
- [ ] 是否有对应的测试
- [ ] 是否遵循编码规范
- [ ] 是否引入新的技术债
- [ ] 是否更新相关文档
- [ ] commit message 是否清晰

### 可选项
- [ ] 性能影响评估
- [ ] 安全影响评估
- [ ] 向后兼容性检查

## 工具链

### 必备工具
- `build/stage0-bootstrap/nextpas` — 编译器
- `scripts/rebuild-compiler.sh` — 重建编译器
- `scripts/c8_scan.sh` — C8 全量扫描
- `make test` — 测试运行器
- `make hygiene` — 产物卫生检查

### 辅助工具
- `scripts/worktree-add.sh` — 创建 worktree
- `scripts/worktree-audit.sh` — 审计 worktree
- `scripts/build-hygiene-check.sh` — 构建卫生检查
