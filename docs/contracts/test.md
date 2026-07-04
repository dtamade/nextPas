# nextpas.core.test 代码契约

> 模块路径: `core/src/nextpas.core.test.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

高级 Pascal 单元测试框架门面。提供 Check* API、fluent IExpectation 链、
并行执行、子测试、ANSI 输出、泄漏检测、RTTI 发现、重试、TAP/JSON/JUnit 输出和 mock 框架。

---

## 关键接口

### Check* API

```pascal
procedure Check(ACondition: Boolean; AMessage: string = '');
procedure CheckEqual(AExpected, AActual: string); overload;
procedure CheckEqual(AExpected, AActual: Int64); overload;
procedure CheckEqual(AExpected, AActual: Double; AEpsilon: Double = 1e-10); overload;
procedure CheckTrue(AValue: Boolean; AMessage: string = '');
procedure CheckNil(APtr: Pointer; AMessage: string = '');
procedure CheckContains(AHaystack, ANeedle: string);
procedure CheckNear(AExpected, AActual, AEpsilon: Double);
procedure CheckRaises(AExceptClass: ExceptClass; AProc: TTestProc);
procedure Fail(AMessage: string);
procedure Skip(AReason: string);
```

### Fluent API

```pascal
Expect(AValue).ToEqual(AExpected);
Expect(AValue).ToBeTrue;
ExpectProc(AProc).ToRaise(Exception);
Expect(1.0).ToBeNear(1.001, 0.01);
```

### Runner

```pascal
type
  TTestSuite = record
    procedure Test(AName: string; AProc: TTestProc);
    function Run: Boolean;
  end;
```

---

## 错误语义

| 场景 | 行为 |
|------|------|
| 断言失败 | raise EAssertionFailed |
| 测试跳过 | raise ETestSkipped |
| CheckEqual(Double) | IEEE 754 精确比较（epsilon 参数废弃） |

---

## 线程安全

- 并行测试由 runner 管理，每个测试在独立线程
- Check* API 线程安全（per-test context）

---

## 依赖关系

- 依赖: system, base, text, sync, io
- 被依赖: 所有测试套件

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
