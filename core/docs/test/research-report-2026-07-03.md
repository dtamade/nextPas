# nextpas.core.test 问题调研报告

**调研日期**: 2026-07-03
**调研范围**: 13 个 findings (F-01 ~ F-13)，其中 F-08 经验证为误报
**方法**: 根因分析 + Go/Rust 对标 + 代码级验证

---

## 问题分类总览

| 编号 | 类型 | 优先级 | 根因 | 修复策略 |
|------|------|--------|------|----------|
| F-01 | 泄漏 | P0→降级 | FPC runtime 内部簿记，非框架泄漏 | 文档标注 + heaptrc suppression |
| F-02 | 缺失 | P1 | 无相对 epsilon 浮点比较 | 新增 CheckNearRel / ToBeNearRel |
| F-03 | 命名 | P1→P2 | FPC 类型系统限制，无法统一重载 | 新增 ExpectStr 别名 |
| F-04 | 注释 | P1 | 注释与实现不一致 | 修正注释 + 明确语义 |
| F-05 | 缺失 | P2 | Pascal 无泛型宏，自动 mock 不可行 | 增强现有 TMock API |
| F-06 | 缺失 | P2 | 无快照测试能力 | 新增 CheckSnapshot |
| F-07 | 缺失 | P3 | 需编译器支持 | 延迟到 LLVM 后端 |
| F-08 | **误报** | — | 并行 runner 已用 mutex 保护输出 | 无需修复 |
| F-09 | 工程 | P3 | FPC 显式 re-export 机制 | include 文件拆分 |
| F-10 | 文档 | P3 | 两种注册方式未明确推荐 | README 补充 |
| F-11 | 缺失 | P3 | 需编译器插桩 | 延迟到 LLVM 后端 |
| F-12 | 随机性 | P3 | PRNG 种子仅基于 tick count | 读 /dev/urandom |
| F-13 | 性能 | P3 | O(K*N) 选择排序 | K>10 时 partial sort |

---

## 详细调研

### F-01 [P0→降级] test_assertions 32 字节 "泄漏"

**根因**: test_assertions.lpr 第 993-995 行已有注释：

```pascal
{ Release closures before heaptrc reports. Note: heaptrc still reports
  32 bytes unfreed — this is FPC runtime bookkeeping inside RunWithResult,
  not a framework leak. All other test suites report 0 unfreed. }
```

**验证**:
- 调用栈为空（heaptrc 无法捕获 FPC 内部分配的栈帧）
- 其他 9 个子套件全部 0 unfreed
- 32 字节 = FPC 内部 exception handling / threadvar 簿记结构

**结论**: 非框架泄漏。降级为 P3（文档标注）。

**修复**: 在 README.md 约定中补充说明此已知 false positive。

---

### F-02 [P1] 浮点比较缺少相对 epsilon

**现状**: 所有浮点比较使用绝对 epsilon `Abs(a-b) <= eps`

**问题场景**:
```
CheckNear(1e15, 1e15 + 1.0, 1e-10)  → FAIL (diff=1.0 > 1e-10)
```
当值量级为 1e15 时，1.0 的差异在浮点精度范围内（ULP ≈ 0.125），但绝对 epsilon 比较会误判。

**Go 对标**:
```go
// Go testing 无内置浮点断言，社区用:
func almostEqual(a, b float64) bool {
    return math.Abs(a-b) <= 1e-9*math.Max(1, math.Max(math.Abs(a), math.Abs(b)))
}
```

**Rust 对标**:
```rust
// approx crate:
relative_eq!(a, b, epsilon = 1e-6, max_relative = 1e-6)
// 算法: abs(a-b) <= max(eps, max_relative * max(abs(a), abs(b)))
```

**修复方案**: 新增 `CheckNearRel` / `ToBeNearRel`，算法：
```pascal
function CheckNearRel(AExpected, AActual: Double;
  AEpsilon: Double = 1e-6): Boolean;
begin
  if IsNan(AExpected) or IsNan(AActual) then Exit(False);
  if IsInfinite(AExpected) or IsInfinite(AActual) then
    Exit(AExpected = AActual); { Inf == Inf, Inf != -Inf }
  if (AExpected = 0) and (AActual = 0) then Exit(True);
  Result := Abs(AActual - AExpected) <=
    AEpsilon * Max(1.0, Max(Abs(AExpected), Abs(AActual)));
end;
```

**向后兼容**: 保留原有 CheckNear / ToBeNear 不变（绝对 epsilon），新增 Rel 变体。

**影响范围**: check.pas + expect.pas + facade + 测试

---

### F-03 [P1→P2] 工厂函数命名不一致

**现状**:
```pascal
function Expect(const AValue: string): IExpectation;      { 裸名 }
function ExpectInt(const AValue: Int64): IExpectation;     { 带后缀 }
function ExpectBool(AValue: Boolean): IExpectation;        { 带后缀 }
function ExpectDouble(const AValue: Double): IExpectation; { 带后缀 }
function ExpectPtr(const AValue: Pointer): IExpectation;   { 带后缀 }
function ExpectProc(AProc: TTestProc): IExpectation;       { 带后缀 }
```

**FPC 限制分析**: FPC 支持函数重载，但 `Expect('hello')` (string) 和 `Expect(42)` (Int64) 在 FPC 中可能产生歧义，因为字面量 `42` 的类型推断不如 Go/Rust 精确。当前设计是安全的——每个类型有明确入口。

**对标**: Go 用 `assert.Equal(t, expected, actual)` 泛型；Rust 用 `assert_eq!` 宏。两者都不需要类型后缀。

**修复方案**: 新增 `ExpectStr` 作为显式别名，保留 `Expect` 向后兼容：
```pascal
function ExpectStr(const AValue: string): IExpectation;
begin Result := TExpectation.CreateStr(AValue); end;
```

**影响范围**: expect.pas + facade + 文档。新增函数，无 breaking change。

---

### F-04 [P1] CheckEqual(Double) 注释与实现矛盾

**现状** (check.pas:22-25):
```pascal
{ CheckEqual for Double — exact bit-wise comparison.
  For floating-point tolerance comparisons, use CheckNear instead. }
procedure CheckEqual(const AExpected, AActual: Double;
  AEpsilon: Double = 1e-10); overload;
```

**实际实现** (check.pas:243-247):
```pascal
procedure CheckEqual(const AExpected, AActual: Double; AEpsilon: Double);
begin
  CheckNear(AExpected, AActual, AEpsilon);  { 不是精确比较！ }
end;
```

**矛盾**: 注释说 "exact bit-wise comparison"，实现是 epsilon 比较。

**分析**: 当前行为（epsilon 比较）实际上更实用——精确比较在浮点场景几乎总会失败。但注释误导用户。

**修复方案**:
1. 修正注释为 "CheckEqual for Double — uses CheckNear with AEpsilon. For strict bit-wise comparison, compare raw bytes directly."
2. 或者：将 CheckEqual(Double) 改为精确比较 + 修正测试

**推荐**: 方案 1（修正注释），因为改变语义是 breaking change，且 epsilon 行为更实用。

**影响范围**: check.pas 注释 + facade 注释

---

### F-05 [P2] Mock 框架为手动字符串录制

**现状**: TMock 是 "配置字典 + 调用记录器"，不是 interface proxy：
```pascal
LMock.Setup('Bar').Returns('hello');     { 配置 }
LMock.RecordCall('Bar', ['arg1']);       { 手动记录 }
CheckEqual('hello', LMock.GetReturn('Bar'));  { 手动取值 }
```

**Pascal 限制**: 无泛型宏、无代码生成器、无运行时代理。自动 mock（如 Go mockgen / Rust mockall）在 Pascal 中不可行。

**增强方案**:
1. **参数验证 mock** — 已有 `CalledWith` / `CalledExactlyWith`，可扩展为 typed 版本
2. **Mock 容器** — `TMock.Create(['Foo', 'Bar'])` 一次性创建多方法 mock
3. **更好的错误消息** — 当 `GetReturn` 找不到配置时，提示 "did you forget Setup()?"
4. **Verify 自动报告** — `TMock.VerifyAll` 在析构时自动检查所有未验证的调用

**对标**: 这是 Pascal 语言的固有限制，与 Go/Rust 的差距无法消除，只能缩小。

**影响范围**: mock.pas + helpers.pas + 测试

---

### F-06 [P2] 无快照测试

**现状**: 无 snapshot 能力。大结构化输出只能手写字符串断言。

**修复方案**: 新增 `CheckSnapshot` 函数：
```pascal
procedure CheckSnapshot(const AName: string; const AActual: string;
  const ASnapshotDir: string = '__snapshots__');
```
- 首次运行：写入 `__snapshots__/AName.snap`
- 后续运行：对比现有快照，不匹配则 fail
- `--update-snapshots` CLI 标志：强制更新快照

**影响范围**: 新增 test.snapshot.pas + CLI 解析 + 测试

---

### F-07 [P3] 无模糊测试

**现状**: 无 fuzzing 能力。
**对标**: Go 1.18+ 内置 fuzzing，Rust cargo-fuzz。
**评估**: 需要编译器支持随机输入生成 + 覆盖率引导。当前 FPC 不支持。
**决策**: 延迟到 LLVM 后端完成后。

---

### F-08 ~~[P2]~~ **误报** — 并行输出交错

**验证结果**: `runner.parallel.pas:461-492` 所有输出都在 `R^.Mtx.Acquire` 保护下：
```pascal
R^.Mtx.Acquire;
try
  IncByStatus(LStatus, R^.Pass^, R^.Fail^, R^.Skip^);
  WriteTestOutput(LStatus, ...);  { 在 mutex 内 }
finally
  SafeRelease(R^.Mtx, LConfig);
end;
```
beforeEach 失败路径 (339-353) 也在 mutex 内。**无需修复。**

---

### F-09 [P3] Facade 门面 712 行 re-export

**现状**: `nextpas.core.test.pas` interface 部分约 250 行类型/常量/函数声明 + ~450 行实现 forward。

**FPC 限制**: 无法用 `public` 或 `reexport` 关键字自动导出。必须显式声明+forward。

**优化方案**: 用 `{$INCLUDE}` 将 re-export 分组到 `.inc` 文件：
```pascal
{ nextpas.core.test.pas }
{$INCLUDE nextpas.core.test.types.inc}     { 类型声明 }
{$INCLUDE nextpas.core.test.checks.inc}    { Check* forward }
{$INCLUDE nextpas.core.test.expects.inc}   { Expect* forward }
```

**收益**: 主文件可读性提升，新增 API 只需改对应 .inc 文件。
**风险**: include 文件调试体验略差（行号不连续）。

---

### F-10 [P3] DiscoverTests 仅支持 published 方法

**现状**: 两种注册方式：
1. `TTestSuite.Test(name, proc)` — 闭包/过程注册
2. `DiscoverTests(fixture)` — RTTI published 方法发现

**问题**: 新用户不知选哪个。

**修复**: README.md 新增 "推荐用法" 段落，明确：
- **首选**: `TTestSuite.Test()` 过程式注册（简单、显式、IDE 友好）
- **高级**: `DiscoverTests` fixture 模式（适合大量相似测试、需要共享 setup/teardown 状态）

---

### F-11 [P3] 无测试覆盖率

**现状**: 无覆盖率报告。
**评估**: 需要编译器插桩支持（Go `-coverprofile`、Rust `cargo-tarpaulin`）。FPC 不支持。
**决策**: 延迟到 LLVM 后端完成后。

---

### F-12 [P3] Shuffle 种子确定性

**现状** (base.pas:380-381):
```pascal
if (ASeed = -1) or (ASeed = 0) then
  LSeed := Integer(GetTickCount64 and $7FFFFFFF)
```
同一毫秒内启动的多进程获得相同序列。

**Go 对标**: Go 1.20+ 使用 `crypto/rand` 或 `-shuffle.seed` 环境变量。

**修复方案**: 优先读 `/dev/urandom`，fallback 到 tick count：
```pascal
function RandomSeed: Integer;
var F: file;
begin
  {$I-}
  Assign(F, '/dev/urandom');
  Reset(F, 1);
  if IOResult = 0 then
  begin
    BlockRead(F, Result, SizeOf(Result));
    Close(F);
    Result := Result and $7FFFFFFF;
  end
  else
    Result := Integer(GetTickCount64 and $7FFFFFFF);
  {$I+}
end;
```

**影响范围**: base.pas ShuffleEntries + 测试

---

### F-13 [P3] GetTopSlowest O(K*N) 性能

**现状** (base.pas:328-367): 对 AResults 做 K 次全扫描找最大值。

**分析**: K=5（默认 SlowTestCount）时，5*N 的开销可忽略。即使 N=10000，也只是 50000 次比较，<1ms。

**修复方案**: 当 K > Length(AResults)/2 时，直接排序后取前 K：
```pascal
if ACount >= Length(AResults) div 2 then
begin
  SortByDuration(AResults);  { introsort }
  Result := Copy(AResults, 0, ACount);
end
else
  { 保持现有选择算法 }
```

**影响范围**: base.pas GetTopSlowest + 测试

---

## 修复策略总结

### 立即修复 (P1, 纯修正)
| 编号 | 改动 | 文件 | 工作量 |
|------|------|------|--------|
| F-01 | 注释标注 | README.md | 5min |
| F-04 | 修正注释 | check.pas | 5min |

### 短期新增 (P1, 新 API)
| 编号 | 改动 | 文件 | 工作量 |
|------|------|------|--------|
| F-02 | CheckNearRel + ToBeNearRel | check.pas + expect.pas + facade | 4h |
| F-03 | ExpectStr 别名 | expect.pas + facade | 30min |

### 中期增强 (P2)
| 编号 | 改动 | 文件 | 工作量 |
|------|------|------|--------|
| F-05 | Mock 增强 (VerifyAll + 错误消息) | mock.pas + helpers.pas | 1d |
| F-06 | CheckSnapshot | 新增 test.snapshot.pas | 2d |

### 长期/延迟 (P3)
| 编号 | 决策 |
|------|------|
| F-07 | 延迟到 LLVM 后端 |
| F-09 | include 文件拆分，可选 |
| F-10 | README 补充，30min |
| F-11 | 延迟到 LLVM 后端 |
| F-12 | 读 /dev/urandom，1h |
| F-13 | K>阈值时 partial sort，1h |

---

## 风险评估

| 风险 | 原评估 | 调研后修正 |
|------|--------|-----------|
| 泄漏可信度 | R-中 | **R-低** — 已确认为 FPC runtime false positive |
| 浮点误判 | R-高 | **R-高** — 确认，需新增 Rel 变体 |
| Mock 不匹配 | R-高 | **R-中** — Pascal 固有限制，增强可行 |
| 并行输出交错 | R-低 | **无风险** — 已有 mutex 保护 |

---

## 依赖关系图

```
F-04 (注释修正) ──→ 无依赖，可立即修
F-01 (文档标注) ──→ 无依赖，可立即修
F-03 (ExpectStr) ──→ 无依赖，可立即修
F-02 (NearRel)  ──→ 无依赖，独立新增
F-05 (Mock增强) ──→ 独立
F-06 (Snapshot) ──→ 独立，但需 CLI 支持 (--update-snapshots)
F-12 (Shuffle)  ──→ 独立
F-13 (TopSlow)  ──→ 独立
F-09 (Include)  ──→ 独立，但建议在 F-02/F-03 完成后做（减少冲突）
F-10 (文档)     ──→ 无依赖
```

**建议实施顺序**: F-01 → F-04 → F-03 → F-02 → F-12 → F-13 → F-10 → F-05 → F-06 → F-09
