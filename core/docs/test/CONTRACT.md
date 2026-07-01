# nextpas.core.test 代码契约

**模块路径**：`core/src/nextpas.core.test*.pas` + `nextpas.core.testing.pas`（15 个源文件）
**层级**：L1（依赖 L0: base, text）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-01
**版本**：1.0

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| test.base | 基础类型和常量 |
| test.runner | TTestRunner 测试运行器 |
| test.check | TTestSuite 测试套件定义 |
| test.config | TTestConfig 配置 |
| test.discovery | 测试发现 |
| test.expect | IExpectation 断言接口 |
| test.helpers | 辅助函数 |
| test.mock | TMockValue Mock 支持 |
| test.output | IOutputSink 输出接口 |
| test.output.json | JSON 输出格式 |
| testing.pas | 门面 re-export |

### 1.2 核心接口

```pascal
IOutputSink = interface
  procedure Write(const AText: string);
  procedure WriteLine(const AText: string);
  procedure Flush;
end;

IExpectation = interface
  function ToEqual(AExpected: Variant): IExpectation;
  function ToBeTrue: IExpectation;
  function ToBeFalse: IExpectation;
  function ToBeNil: IExpectation;
  function ToBeGreaterThan(AValue: Double): IExpectation;
  function ToBeLessThan(AValue: Double): IExpectation;
  function ToContain(const ASubstr: string): IExpectation;
  function ToHaveLength(ALen: Integer): IExpectation;
  function ToRaise(AExcClass: ExceptClass): IExpectation;
end;
```

### 1.3 核心类型

```pascal
TTestConfig = record
  Filter: string;
  Short: Boolean;
  Verbose: Boolean;
  Timeout: TDuration;
  FailuresMax: Integer;
  Shuffle: Boolean;
  FailFast: Boolean;
end;

TTestRunner = record
  Config: TTestConfig;
  Sink: IOutputSink;
end;
```

---

## 2. 不变量

- `--filter` 匹配测试名子串
- `--timeout` 超时后标记失败
- `--failfast` 首次失败立即停止
- `--shuffle` 随机顺序执行

---

## 3. 错误处理

- 测试失败不抛异常，记录结果
- 配置错误抛 `ETestConfigError`

---

## 4. 线程安全

- TTestRunner 在主线程执行
- 并行测试时每个工作线程有独立的 TTestSuite

---

## 5. 内存管理

- IExpectation 通过引用计数自动释放
- Mock 对象生命周期与测试相同

---

## 6. 测试覆盖

- 360 测试覆盖 Runner/Expect/Mock/Config/Discovery/Output
