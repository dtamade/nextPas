# test 模块 v7.0 整体规划

> 目标：消除遗留债务、统一 API 命名、提升编译通过率、夯实测试基础设施

## 当前状态

| 指标 | 值 |
|------|-----|
| 源文件 | 16 模块 + 4 include + 1 deprecated = 21 |
| 迁移后测试文件 | 490 on `test.pas`, 0 on `testing.pas` |
| 3-arg CheckEqual | 2035 调用（已有 string/Int64/Boolean 重载） |
| 编译失败 | ~12% 抽样失败（预存问题） |
| With* 使用 | 4 处 |
| 新 TTestRunner 使用 | 58 文件 |

---

## Phase 1: 清理死代码 [P0]

### 1.1 删除 `nextpas.core.testing.pas`

- 已确认 0 外部调用者
- 删除 `core/src/nextpas.core.testing.pas`
- 删除 `core/tests/nextpas.core.testing/` 测试目录
- 更新 `core/docs/test/CONTRACT.md` 移除 testing 相关描述

**风险**: 低。已验证无调用者。
**验证**: `grep -r 'nextpas\.core\.testing' core/` 返回 0。

### 1.2 清理 `test_testing.lpr`

- 该文件测试 `testing.pas` 的 Check/CheckEqual/Fail
- 迁移到 `test_assertions.lpr` 或删除（功能已被覆盖）

---

## Phase 2: 补齐 CheckEqual 三参数重载 [P0]

### 2.1 添加 `CheckEqualMsg` 函数

FPC 对 `UInt16`/`UInt32`/`UInt64` 的重载解析存在歧义（`Int64` vs `Double` 同等匹配）。解决方案：添加独立函数名 `CheckEqualMsg`，避免重载冲突。

```pascal
// check.pas interface
procedure CheckEqualMsg(const AExpected, AActual: string; const AMessage: string);
procedure CheckEqualMsg(const AExpected, AActual: Int64; const AMessage: string);
procedure CheckEqualMsg(const AExpected, AActual: UInt64; const AMessage: string);
procedure CheckEqualMsg(const AExpected, AActual: Boolean; const AMessage: string);
```

### 2.2 迁移调用者

将2035处 `CheckEqual(x, y, 'msg')` 中涉及 `UInt64` 的部分改为 `CheckEqualMsg`。其余 `string`/`Int64`/`Boolean` 保持现有重载。

**验证**: `test_bytes.lpr` 中 `CheckEqual(UInt64, ...)` 编译通过。

---

## Phase 3: 修复预存编译失败 [P1]

### 3.1 分类

抽样显示 ~12% 失败，主要原因：
- `TTestRunner`（新）方法调用不匹配（`Set_` 缺失等）
- 依赖缺失模块
- 语法错误（预存）

### 3.2 策略

按模块分批修复：
1. **collections** — 约 15 个文件，多数是 `TTestRunner` 用法问题
2. **http** — 约 10 个文件，`Set_` 缺失等
3. **crypto/tls** — 约 10 个文件
4. **其他** — 零散修复

**验证**: 每批修复后 `fpc` 编译通过率提升。

---

## Phase 4: 命名统一 [P1]

### 4.1 `TTestRunner` → `TSuiteRunner`

当前 `TTestRunner` 在两个模块中含义不同：
- `test.runner.pas`: 多套件编排器（Add/RunAll/Summary）
- `testing.pas`（将删除）: 单套件运行器

删除 `testing.pas` 后，`TTestRunner` 只有一个含义。但名字仍易与 `TTestSuite` 混淆。

**方案**: `TTestRunner` → `TSuiteRunner`，语义更清晰。

**影响**: 58 个文件需要重命名。机械替换，sed 可完成。

### 4.2 `TTestSuite.Run` 返回值语义

`TTestSuite.Run` 返回 `Boolean`（True=全部通过）。但 `TTestRunner.AllPassed` 也是 Boolean。统一命名减少混淆。

---

## Phase 5: 测试隔离加固 [P2]

### 5.1 `GExecState` 生命周期

当前 `GExecState` 在 `finally` 中 Dispose（F-02 已修复）。但串行模式下，如果测试中途 crash，`GExecState` 可能泄漏。

**方案**: 每个 test entry 在独立的 try/except/finally 中运行，确保 cleanup。

### 5.2 `GLastTestTrace` 清理

当前 `GLastTestTrace` 在 `SetTestContext` 中设置，但未在所有路径清理。

---

## Phase 6: 测试自动发现 [P3]

### 6.1 RTTI 发现增强

`discovery.pas` 已有 VMT 扫描基础。可扩展为：
- 扫描 `TTestFixture` 子类的 published 方法
- 自动注册为 test case
- 支持 `{$M+}` 或 VMT method table

### 6.2 零注册测试

```pascal
type
  TMyTests = class(TTestFixture)
  published
    procedure TestSomething;  // 自动发现
  end;
```

**依赖**: 编译器对 `{$M+}` 的支持程度。
**风险**: 高。需要验证 FPC VMT 扫描的可靠性。

---

## 里程碑

| 阶段 | 内容 | 预估工作量 | 依赖 |
|------|------|-----------|------|
| Phase 1 | 清理死代码 | 小 | 无 |
| Phase 2 | CheckEqualMsg | 小 | 无 |
| Phase 3 | 编译失败修复 | 中 | Phase 1 |
| Phase 4 | 命名统一 | 中 | Phase 1 |
| Phase 5 | 测试隔离 | 小 | 无 |
| Phase 6 | 自动发现 | 大 | Phase 4 |

**建议执行顺序**: 1 → 2 → 3 → 4 → 5 → 6

---

## 验证标准

每个 Phase 完成后：
- `make -C core/tests/nextpas.core.test clean test` 全绿
- `fpc` 编译通过率 ≥ 当前基线 + 本阶段修复数
- `grep -r 'nextpas\.core\.testing' core/` 返回 0（Phase 1 后）
- heaptrc 0 unfreed（除已知32字节 FPC artifact）
