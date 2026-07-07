# SIMD 测试迁移计划：fpcunit → nextpas.core.test

## 目标
将 math/simd 模块下所有单元测试从 fpcunit/testregistry 迁移到框架自己的 nextpas.core.test 模块。

## 迁移映射

| fpcunit | nextpas.core.test |
|---------|-------------------|
| `uses fpcunit, testregistry` | `uses nextpas.core.test` |
| `class(TTestCase)` | `class(TTestFixture)` |
| `RegisterTest(TMyClass)` | 删除，改用 runner 中 `DiscoverTests` |
| `AssertEquals(exp, act)` | `CheckEqual(exp, act)` |
| `AssertEquals(msg, exp, act)` | `CheckEqual(exp, act, msg)` |
| `AssertTrue(cond)` | `CheckTrue(cond)` |
| `AssertTrue(msg, cond)` | `CheckTrue(cond, msg)` |
| `AssertFalse(cond)` | `CheckFalse(cond)` |
| `AssertFalse(msg, cond)` | `CheckFalse(cond, msg)` |
| `AssertNotNull(ptr)` | `CheckNotNil(ptr)` |
| `AssertAssigned(ptr)` | `CheckNotNil(ptr)` |
| `AssertSame(a, b)` | `CheckSame(a, b)` |
| `AssertRaises(EClass, proc)` | `CheckRaises(EClass, proc)` |
| `Fail(msg)` | `Fail(msg)` |

## Runner 迁移

当前 runner (`nextpas.core.simd.test.lpr`) 使用 fpcunit 的 `TTestResult`/`TTestSuite`/`HandleSuite(TTestCaseClass)` 模式。

迁移后使用框架的 `TTestSuite` + `DiscoverTests`:
```pascal
uses nextpas.core.test;

var
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('SIMD Tests');
  // 每个 fixture 类:
  LSuite.AddTest(DiscoverTests(TTestCase_SimdArrays.Create));
  // ...
  LSuite.Run;
end.
```

需要解决的问题:
- `HandleSuite` 当前支持 `--suite` 过滤，迁移后需保留此功能
- `TTestSuite.AddTest` 是否存在（需确认框架 API）
- fpcunit 的 `TTestResult.Failures` 错误报告 → 框架的输出机制

## 批次规划

### Batch 0: Runner + 框架 API 确认
- 确认 `TTestSuite.AddTest` / 子 suite 合并 API
- 改写 `nextpas.core.simd.test.lpr`
- 编译验证 runner 能启动

### Batch 1: 已用 Check API 的文件 (8 文件, 仅改 uses/class/registration)
这些文件已用 `CheckTrue`/`CheckEqual`，只需改声明:
1. `nextpas.core.simd.arrays.testcase.pas` (417 行)
2. `nextpas.core.simd.nn.testcase.pas` (723 行)
3. `nextpas.core.simd.signal.testcase.pas` (367 行)
4. `nextpas.core.simd.stats.testcase.pas` (417 行)
5. `nextpas.core.simd.array_f32_correctness.pas` (467 行)
6. `nextpas.core.simd.avx512_verify.pas` (106 行)
7. `nextpas.core.simd.transcendental_f32.pas` (156 行)
8. `nextpas.core.simd.backend.consistency.testcase.pas` (912 行)

### Batch 2: 小文件 Assert→Check (7 文件, <100 断言)
1. `nextpas.core.simd.alignment.testcase.pas` (14 断言)
2. `nextpas.core.simd.algorithms.testcase.pas` (17 断言)
3. `nextpas.core.simd.sse3_correctness.testcase.pas` (18 断言)
4. `nextpas.core.simd.saturating.testcase.pas` (32 断言)
5. `nextpas.core.simd.concurrent.testcase.pas` (41 断言)
6. `nextpas.core.simd.linalg.testcase.pas` (51 断言)
7. `nextpas.core.simd.narrow512.testcase.pas` (59 断言)

### Batch 3: 中等文件 (6 文件, 60-160 断言)
1. `nextpas.core.simd.memutils.aliases.testcase.pas` (69 断言)
2. `nextpas.core.simd.runtime.testcase.pas` (76 断言)
3. `nextpas.core.simd.sse2contracts.testcase.pas` (81 断言)
4. `nextpas.core.simd.vecu32x8.testcase.pas` (87 断言)
5. `nextpas.core.simd.vec512types.testcase.pas` (105 断言)
6. `nextpas.core.simd.rvvparity.testcase.pas` (114 断言)

### Batch 4: 中等文件续 (5 文件, 120-270 断言)
1. `nextpas.core.simd.edgecases.testcase.pas` (120 断言)
2. `nextpas.core.simd.veci32x8.testcase.pas` (127 断言)
3. `nextpas.core.simd.imageproc.testcase.pas` (144 断言)
4. `nextpas.core.simd.dataplane.testcase.pas` (149 断言)
5. `nextpas.core.simd.narrowintegerops.testcase.pas` (266 断言)

### Batch 5: 大文件 (4 文件, 150-460 断言)
1. `nextpas.core.simd.vecf64x4.testcase.pas` (158 断言)
2. `nextpas.core.simd.intrinsics.avx2.testcase.pas` (202 断言)
3. `nextpas.core.simd.vecf32x8.testcase.pas` (202 断言)
4. `nextpas.core.simd.ieee754.testcase.pas` (454 断言)

### Batch 6: 超大文件 (3 文件, 600-740 断言)
1. `nextpas.core.simd.dispatchslots.testcase.pas` (600 断言)
2. `nextpas.core.simd.direct.testcase.pas` (608 断言)
3. `nextpas.core.simd.publicabi.testcase.pas` (737 断言)

### Batch 7: 巨型文件 (2 文件, 2200-2600 断言)
1. `nextpas.core.simd.testcase.pas` (2247 断言, 21 个 RegisterTest)
2. `nextpas.core.simd.dispatchapi.testcase.pas` (2603 断言, 5 个 RegisterTest)

## 验证

每批完成后:
```bash
make -C core/tests/nextpas.core.simd clean test
```

最终确认:
- 0 个 `fpcunit` / `testregistry` 引用
- 0 个 `AssertEquals` / `AssertTrue` / `AssertFalse` 调用
- 所有测试通过
