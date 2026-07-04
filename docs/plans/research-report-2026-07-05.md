# nextpas.core.test 可用性问题专题调研报告

**调研日期**: 2026-07-05
**调研范围**: 本轮评估发现的 13 个问题 (eval-F-01 ~ eval-F-13)
**前置依赖**: 2026-07-03 调研报告的 13 个 findings 已全部实施完毕
**方法**: 根因分析 + FPC 技术约束验证 + Go/Rust 对标

---

## 问题分类总览

| 编号 | 类型 | 优先级 | 根因 | 可行性 | 修复策略 |
|------|------|--------|------|--------|----------|
| E-01 | API 陷阱 | P1 | record 值语义 + With* 返回值丢弃 | ✅ 可修 | deprecated + 直接修改方法 |
| E-02 | API 膨胀 | P2 | FPC 重载消歧义需要 ADummy | ✅ 可修 | 合并重载 + record 参数 |
| E-03 | 命名不一致 | P2 | FPC 重载歧义导致独立命名 | ✅ 可修 | deprecated CheckEqualMsg |
| E-04 | API 膨胀 | P2 | 22 字段 × 2 函数 = 44 符号 | ✅ 可修 | config builder record |
| E-05 | 内存安全 | P1 | threadvar + New/Dispose 手动管理 | ✅ 可修 | 改用 class 封装 |
| E-06 | 线程安全 | P2 | 裸动态数组无同步 | ✅ 可修 | Assert → 运行时检查 |
| E-07 | 逻辑缺陷 | P3 | RunnerConfig 仅读 Suites[0] | ✅ 可修 | 合并所有 suite config |
| E-08 | 缺失 API | P3 | 60+ 断言无 NaN 专用检查 | ✅ 可修 | 新增 CheckNaN |
| E-09 | 功能缺失 | P3 | Mock 全局返回值不区分参数 | ⚠️ 有限 | 增强 Mock API |
| E-10 | 测试覆盖 | P3 | 无框架核心自测试 | ✅ 可修 | 新增 selftest 套件 |
| E-11 | 工程规范 | P3 | 纯文本错误无 file:line | ⚠️ 有限 | 改进输出格式 |
| E-12 | 功能缺失 | P3 | Benchmark 无基线对比 | ✅ 可修 | 新增 benchstat 支持 |
| E-13 | 架构限制 | P3 | 并行模式不支持子测试 | ❌ 高成本 | 文档标注 + 延迟 |

---

## 详细调研

### E-01 [P1] TTestSuite With* 方法返回值丢弃陷阱

**根因**: `TTestSuite` 是 Pascal record（值类型）。`With*` 方法返回新 record，原值不变。

```pascal
// ❌ 编译通过但 Setup 未生效
Suite.WithSetup(Proc);
Suite.Test('name', TestProc);

// ✅ 正确
Suite := Suite.WithSetup(Proc);
```

**FPC 技术约束验证**:
- ✅ `deprecated` 指令可用于 record 方法，生成编译时警告
- ✅ 警告消息可自定义: `deprecated '必须保存返回值: Suite := Suite.WithSetup(...)'`
- ❌ 无法用类型系统阻止丢弃返回值（Pascal 无 `#[must_use]`）

**对标分析**:
- Go: `testing.T` 是指针，`t.Cleanup()` 是方法调用，无此问题
- Rust: builder pattern 用 `mut self` 消费 self，编译时安全
- C++: `[[nodiscard]]` 属性可标记返回值不可丢弃

**修复策略**:
1. **Phase 1**: 为所有 `With*` 方法添加 `deprecated` 警告
2. **Phase 2**: 确保直接修改方法 (`SetSetup`, `OnBeforeEach` 等) 与 `With*` 完全等价
3. **Phase 3**: 文档推荐直接修改方法为首选

**影响范围**: runner.pas (6 个 With* 方法) + facade + README + 所有使用 With* 的测试

**风险评估**: 低。deprecated 只产生警告，不破坏编译。

---

### E-02 [P2] ShouldFail 6 个重载 + ADummy 参数

**根因**: FPC 类型推断不够精确，导致需要额外参数消歧义：

```pascal
// 两个签名冲突:
ShouldFail(name, proc, msg: string);     { 消息匹配 }
ShouldFail(name, proc, contains: string; ADummy: Integer);  { 子串匹配 }
```

**FPC 技术约束**:
- FPC 不支持 `where` 约束或类型类来区分 `string` 语义
- 用 record 参数可以解决，但增加 API 复杂度

**修复策略**:
1. 保留 4 个核心重载（msg/class+contains/contains-only/closure 变体）
2. 标记 `ADummy` 重载为 `deprecated '使用 ShouldFail(name, proc, TClass, contains)'`
3. 将子串匹配统一到 `ShouldFail(name, proc, TClass=nil, contains)` 签名

**影响范围**: runner.pas + facade + 测试

**风险评估**: 低。deprecated 不破坏编译。

---

### E-03 [P2] CheckEqualMsg 命名不一致

**根因**: FPC 重载决议对 `UInt16/UInt32/UInt64` 有歧义，因此创建了独立函数名 `CheckEqualMsg`。

```pascal
CheckEqual(42, result, 'msg');      { 3-arg overload — 可能歧义 }
CheckEqualMsg(42, result, 'msg');   { 独立函数 — 无歧义 }
```

**分析**: 实际使用中 `Int64` 覆盖了绝大多数场景，`UInt64` 歧义极少触发。

**修复策略**:
1. 标记 `CheckEqualMsg` 为 `deprecated '使用 CheckEqual(expected, actual, message)'`
2. 保留实现以向后兼容
3. 测试逐步迁移到 `CheckEqual` 3-arg

**影响范围**: check.pas + facade + 使用 CheckEqualMsg 的测试

**风险评估**: 极低。

---

### E-04 [P2] 22 个 SetDefault* / Get* 全局函数

**根因**: 每个 `TTestConfig` 字段对应一对 getter/setter，加上 `GExplicit` 跟踪。

**当前状态**:
```
22 字段 × 2 (Set+Get) = 44 公开函数
+ GExplicit: TConfigKeys 跟踪
+ ResolveConfig 合并逻辑
```

**FPC 技术约束**:
- ❌ Pascal 无 `with` 初始化语法（Go struct literal）
- ❌ 无 `Option<T>` 类型
- ✅ record 可直接赋值

**修复策略**:
1. **保留** SetDefault*/Get* 作为向后兼容 API
2. **新增** `TTestConfigBuilder` record:
   ```pascal
   TTestConfigBuilder = record
     Config: TTestConfig;
     Explicit: TConfigKeys;
     function WithTimeoutMs(ms: Integer): TTestConfigBuilder;
     function WithMaxWorkers(n: Integer): TTestConfigBuilder;
     // ... 每个字段一个 With* 方法
     function Build: TTestConfig;
   end;
   ```
3. **新增** `DefaultConfigBuilder: TTestConfigBuilder` 便捷函数

**影响范围**: config.pas + facade + README

**风险评估**: 低。纯新增 API，不破坏现有代码。

---

### E-05 [P1→P3] GExecState 手动内存管理

**根因**: `GExecState: PTestExecState` 是 `threadvar`，使用 `New/Dispose` 手动管理。

```pascal
threadvar
  GExecState: PTestExecState;  { 堆分配，手动 Dispose }
```

**FPC 技术约束验证**:
- ✅ `threadvar` 可存储 class 引用（runner.pas 已用 `GCurrentTestContextObj: TObject`）
- ❌ **FPC 不会在线程退出时自动调用 threadvar class 析构函数**
- 结论：改为 class 不提供额外安全收益

**风险分析**:
- 正常路径: finally 块中 Dispose ✅
- 异常路径: Halt() 跳过 finally → 泄漏 ⚠️ (极低概率)
- parallel worker: 同样模式，同样风险

**修复策略 (降级为 P3)**:
1. **保留** 当前 New/Dispose 模式（已是 FPC 下最优方案）
2. **增强** 添加注释说明为何不改 class
3. **新增** finalization 安全网：检查 GExecState 是否为 nil，非 nil 时 Dispose + 警告

**影响范围**: base.pas finalization

**风险评估**: 极低。仅添加安全网代码。

---

### E-06 [P2] GStubRegistry / GFixtureRegistry 非线程安全

**根因**: 使用裸动态数组，无同步保护。代码用 `Assert` 检查主线程。

**当前防护**:
```pascal
Assert(platform_thread_id = GMainThreadId,
  'RegisterStub must be called from the main thread');
```

**问题**: Assert 在 `{$C-}` (range checking off) 模式下被移除。

**修复策略**:
1. 将 `Assert` 改为 `if not (...) then raise Exception.Create(...)`
2. 或添加专用的 `CheckMainThread` 过程（带清晰错误消息）
3. 文档明确标注 "仅限主线程调用"

**影响范围**: runner.pas (RegisterStub, RegisterFixture)

**风险评估**: 极低。运行时检查替代 Assert。

---

### E-07 [P3] RunnerConfig 仅读 Suites[0]

**根因**:
```pascal
function RunnerConfig(const ARunner: TSuiteRunner): TTestConfig;
begin
  if Length(ARunner.Suites) > 0 then
    Result := ResolveConfig(ARunner.Suites[0].Config)  { 只读第一个 }
```

**影响**: 多 suite runner 中，第一个 suite 以后的独立 config 被忽略。

**分析**: 实际使用中，大多数 runner 的所有 suite 共享同一 config。但如果用户为不同 suite 设置不同 config（如不同 timeout），行为不符合预期。

**修复策略**:
1. 将 `RunnerConfig` 改为读取 runner 级别的 config（新增 `TSuiteRunner.Config` 字段）
2. suite 级别 config 优先于 runner 级别
3. runner 级别 config 优先于 global default

**影响范围**: runner.pas

**风险评估**: 低。需添加新字段，但不破坏现有 API。

---

### E-08 [P3] 缺少 CheckNaN / ExpectNaN

**根因**: 60+ 断言变体中无 NaN 专用检查。

**当前替代方案**:
```pascal
CheckFalse(IsNan(x), 'expected non-NaN');
ExpectDouble(x).Not_.ToBeNear(0, 0);  { 间接 }
```

**修复策略**: 新增简洁 API：
```pascal
procedure CheckNaN(const AValue: Double; const AMessage: string = '');
procedure CheckNotNaN(const AValue: Double; const AMessage: string = '');
// IExpectation:
function ToBeNaN: IExpectation;
function ToBeNotNaN: IExpectation;
```

**影响范围**: check.pas + expect.pas + facade + 测试

**风险评估**: 极低。纯新增。

---

### E-09 [P3] Mock 不支持参数-返回值联动

**根因**: `Setup('Foo').Returns('bar')` 是全局返回值，不区分调用参数。

**Pascal 限制**: 无泛型宏、无闭包捕获类型推断。自动 mock 不可行。

**修复策略**: 增强 `IMockSetup`：
```pascal
function When(const AArgs: array of string): IMockSetup;
function WhenInt(const AArgs: array of Int64): IMockSetup;
```

使用方式：
```pascal
Mock.Setup('Foo').When(['arg1']).Returns('result1');
Mock.Setup('Foo').When(['arg2']).Returns('result2');
```

**影响范围**: mock.pas + 测试

**风险评估**: 中。需修改 GetReturn 查找逻辑。

---

### E-10 [P3] 无框架核心自测试

**根因**: 10 个测试套件测试框架的各个模块，但没有专门测试框架核心逻辑（runner 状态机、config 解析、filter 匹配）的自测试套件。

**分析**: `test_runner` (169 tests) 已经覆盖了大量 runner 行为，但侧重端到端。缺少单元级测试。

**修复策略**: 新增 `test_selftest` 套件，测试：
- `GrowCapacity` 边界
- `ShuffleEntries` 确定性
- `GetTopSlowest` 排序正确性
- `MatchesFilter` glob 模式
- `ResolveConfig` 合并逻辑
- `StringDiff` 差异定位

**影响范围**: 新增测试套件

**风险评估**: 极低。纯新增。

---

### E-11 [P3] 缺少结构化错误输出

**根因**: 错误消息是纯文本，IDE 无法解析 file:line。

**当前格式**:
```
  ✗ TestFoo
    Expected 42 but got 43 [test_foo.pas:25]
```

**Go 对比**:
```
    test_foo_test.go:25: expected 42, got 43
```

**修复策略**:
1. 在 `FormatTestLocation` 中输出 `filename:line:` 格式（Go 兼容）
2. 新增 `--format=github` 选项输出 `::error file=...` 格式
3. JSON 输出已包含结构化信息 ✅

**影响范围**: base.pas (FormatTestLocation) + output.pas

**风险评估**: 低。改变输出格式，可能影响 snapshot 测试。

---

### E-12 [P3] Benchmark 无基线对比

**根因**: Benchmark 只报告当前运行结果。

**Go 对标**: `benchstat` 工具对比两次运行结果。

**修复策略**:
1. 新增 `--benchsave=file` 保存结果到 JSON
2. 新增 `--benchcompare=file` 与基线对比
3. 输出 delta 百分比 + 显著性标记

**影响范围**: runner.pas + cli.pas + output.pas

**风险评估**: 低。纯新增功能。

---

### E-13 [P3] 并行模式不支持子测试

**根因**: 子测试在并行模式下需要嵌套线程或异步调度，架构复杂度高。

**当前行为**: 自动跳过 + 输出 "subtests not supported in parallel mode"

**Go 对比**: Go 的 `t.Run()` 在并行模式下也有限制（goroutine 生命周期管理）。

**修复策略**:
1. **短期**: 文档明确标注此限制
2. **长期**: 实现嵌套并行调度器（复杂度高，延迟到 LLVM 后端后）

**影响范围**: README + runner.parallel.pas

**风险评估**: 不适用（文档改动）。

---

## 修复策略总览

### 依赖关系图

```
E-05 (GExecState) ──→ 无依赖，P1 优先
E-01 (With* 陷阱) ──→ 无依赖，P1 优先
E-06 (Assert→检查) ──→ 无依赖，可立即修
E-02 (ShouldFail) ──→ 无依赖
E-03 (CheckEqualMsg) ──→ 无依赖
E-04 (Config builder) ──→ 独立，中等工作量
E-07 (RunnerConfig) ──→ 独立
E-08 (CheckNaN) ──→ 无依赖，小改动
E-09 (Mock When) ──→ 独立，中等工作量
E-10 (Selftest) ──→ 依赖 E-08 完成后（可选）
E-11 (结构化输出) ──→ 独立
E-12 (Bench baseline) ──→ 独立，中等工作量
E-13 (并行子测试) ──→ 文档标注，无代码改动
```

### 实施批次

**Batch 1 (P1 — 立即修复)**:
- E-05: GExecState 改 class
- E-01: With* deprecated 警告
- E-06: Assert → 运行时检查

**Batch 2 (P2 — API 改进)**:
- E-02: ShouldFail 重载整理
- E-03: CheckEqualMsg deprecated
- E-04: Config builder

**Batch 3 (P3 — 功能增强)**:
- E-07: RunnerConfig 修复
- E-08: CheckNaN/ExpectNaN
- E-09: Mock When API
- E-11: 结构化输出格式
- E-13: 文档标注

**Batch 4 (P3 — 较大功能)**:
- E-10: Selftest 套件
- E-12: Benchmark 基线对比

---

## 风险评估矩阵

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|---------|
| E-05 threadvar class 引用在 FPC 3.3.1 有 bug | 低 | 高 | 先写最小测试验证 |
| E-01 deprecated 警告过多影响 CI | 中 | 低 | 可通过 {$WARN OFF} 控制 |
| E-04 Config builder 增加维护负担 | 中 | 中 | 仅作为补充 API，不替代现有 |
| E-09 Mock When 改变 GetReturn 语义 | 中 | 中 | 新增方法，不改现有 |
| E-11 输出格式改变影响 snapshot | 低 | 中 | 新增格式选项，保留默认 |

---

## 工作量估算

| 批次 | 编码 | 测试 | 文档 | 总计 |
|------|------|------|------|------|
| Batch 1 (P1) | 4h | 2h | 1h | 1d |
| Batch 2 (P2) | 4h | 2h | 1h | 1d |
| Batch 3 (P3) | 6h | 3h | 1h | 1.5d |
| Batch 4 (P3) | 6h | 4h | 1h | 1.5d |
| **总计** | **20h** | **11h** | **4h** | **~5d** |
