# nextpas.core.test Fix Plan

> 日期: 2026-06-21
> 基于: findings.md (53 findings) + 源码审查
> 状态: 待执行

## 总览

| 级别 | 同意 | 部分同意 | 不同意 | 合计 |
|------|------|----------|--------|------|
| Critical | 1 | 1 | 1 | 3 |
| Major | 14 | 4 | 6 | 24 |
| Minor | 10 | 3 | 6 | 19 |
| Info | 2 | 0 | 5 | 7 |
| **合计** | **27** | **8** | **18** | **53** |

## 修复批次划分 (6 批次)

| 批次 | 名称 | Finding 数 | 依赖 | 优先级 |
|------|------|-----------|------|--------|
| B1 | 正确性修复 | 6 | 无 | P0 |
| B2 | 边界语义修复 | 5 | B1 | P1 |
| B3 | 并行模式修复 | 5 | B1 | P1 |
| B4 | 输出与诊断增强 | 5 | B1 | P2 |
| B5 | 测试覆盖补充 | ~18 | B1-B4 | P2 |
| B6 | 文档补全 | ~8 | B5 | P3 |

---

## C1. 并行模式全局状态竞争 — 同意

**判断**: 同意。这是真实的并发 bug。

**分析**: `ParallelWorkerProc` 故意不调用 `SetTestContext`（见 L1321 注释），但 `InternalFail`/`InternalSkip` 仍直接写全局变量 `GTestFailed`/`GTestSkipped`/`GSkipReason`。当并行测试使用 Check*/Fail/Skip 时，多线程同时写这些变量无同步保护。

**修复方案**:

文件: `core/src/nextpas.core.test.pas`

1. `ParallelWorkerProc` 入口处 save 全局状态，出口处 restore：
```pascal
function ParallelWorkerProc(AArg: Pointer): Pointer; cdecl;
var
  R: PThreadRec;
  LStatus: TTestStatus;
  { Save/restore globals to prevent cross-thread pollution }
  LSavedTestFailed: Boolean;
  LSavedTestSkipped: Boolean;
  LSavedSkipReason: string;
  LSavedTestName: string;
  LSavedSuiteName: string;
begin
  Result := nil;
  R := PThreadRec(AArg);
  LStatus := tsPassed;

  { Save global state }
  LSavedTestFailed := GTestFailed;
  LSavedTestSkipped := GTestSkipped;
  LSavedSkipReason := GSkipReason;
  LSavedTestName := GActiveTestName;
  LSavedSuiteName := GActiveSuiteName;

  { ... existing test execution logic ... }

  { Restore global state before exit }
  GTestFailed := LSavedTestFailed;
  GTestSkipped := LSavedTestSkipped;
  GSkipReason := LSavedSkipReason;
  GActiveTestName := LSavedTestName;
  GActiveSuiteName := LSavedSuiteName;
end;
```

2. 注意：全局状态的 save/restore 本身也需要在 mutex 保护下进行，或者更好的方式是接受这种"每线程独立 save/restore"的模式——因为 join 在 create 之后，所以实际上各线程在自己的栈上保存恢复，但对全局变量的写入仍有瞬态竞争。最佳方案：并行模式下 `InternalFail`/`InternalSkip` 不写全局状态。添加一个 thread-local 或全局 atomic 标志来指示并行模式。

实际更简洁的修复：

```pascal
var
  GParallelMode: Boolean = False;  { Atomic boolean, set before parallel dispatch }

procedure InternalFail(const AMessage: string);
begin
  if not GParallelMode then
    GTestFailed := True;  { Only write global in serial mode }
  raise EAssertionFailed.Create(AMessage);
end;

procedure InternalSkip(const AReason: string);
begin
  if not GParallelMode then
  begin
    GTestSkipped := True;
    GSkipReason := AReason;
  end;
  raise ETestSkipped.Create(AReason);
end;
```

在 `RunParallel` 中设置 `GParallelMode := True`，结束后设回 `False`。因为 `ReportLeakIfAny` 在并行模式下不输出（计数通过 `TThreadRec` 的 Pass/Fail/Skip 指针完成），所以全局变量不需要写入。

**新增测试**: 无独立测试，行为由 B3 的并行失败测试覆盖。

---

## C2. Check* 失败消息内容未验证 — 同意

**判断**: 同意，但仅部分 findings 是正确的问题。

**分析**: 仔细审查 `test_assertions.lpr`，大部分失败测试实际上**已经验证了消息内容**（见 `TestCheckFail` L28, `TestCheckEqualString` L40, `TestCheckEqualInt` L52, `TestCheckContains` 未验证, `TestCheckStartsWith` 未验证 等）。确实有几处只写 `{ expected }` 不验证消息。

**修复方案**:

文件: `core/tests/nextpas.core.test/test_assertions/test_assertions.lpr`

需要在以下 catch 块中添加消息验证：
- `TestCheckEqualBool` L64: 添加 `Check(Pos('True', E.Message) > 0)`
- `TestCheckEqualPtr` L78: 添加 `Check(Pos('pointer', LowerCase(E.Message)) > 0)`
- `TestCheckNotEqual` L90: 添加 `Check(Pos('differ', E.Message) > 0)`
- `TestCheckTrueFalse` L104: 添加 `Check(Pos('True', E.Message) > 0)`
- `TestCheckNilNotNil` L120: 添加 `Check(Pos('non-nil', E.Message) > 0)`
- `TestCheckContains` L132: 添加 `Check(Pos('does not contain', E.Message) > 0)`
- `TestCheckStartsWith` L144: 添加 `Check(Pos('does not start', E.Message) > 0)`
- `TestCheckEndsWith` L159: 添加 `Check(Pos('does not end', E.Message) > 0)`
- `TestCheckSame` L174: 添加 `Check(Pos('same pointer', E.Message) > 0)`

**依赖**: 无
**新增测试**: 修改现有测试

---

## C3. Not_ 失败路径几乎未测试 — 同意

**判断**: 同意。当前仅一个 Not_ 失败测试。

**修复方案**: 归入 **B5 测试覆盖补充** 批次。

---

## M1. 并行 BeforeEach 失败被静默吞掉 — 同意

**判断**: 同意。

**分析**: L1338-1341 中 BeforeEach 失败设 `LStatus := tsError` 但只静默 catch，无 WriteLn 输出，且计数逻辑在后面的 mutex 块中才执行。结果是用户看不到 BeforeEach 失败信息。

**修复方案**:

文件: `core/src/nextpas.core.test.pas`, `ParallelWorkerProc` 函数

```pascal
  if Assigned(R^.Before) then
  begin
    try R^.Before;
    except
      on E: Exception do
      begin
        LStatus := tsError;
        R^.Mtx.Acquire;
        try
          WriteLn('  ', StatusDot(tsError), ' ', R^.Entry.Name,
            ' — beforeEach failed: ', E.Message);
        finally
          R^.Mtx.Release;
        end;
      end;
    end;
  end;
```

**依赖**: C1（并行全局状态修复）
**新增测试**: 归入 B3

---

## M2. BeforeEach 对 skipped test 也执行 — 同意

**判断**: 同意。这是逻辑错误。

**分析**: L1176-1191 中 BeforeEach 在 `ekSkipped` 检查之前执行。如果 BeforeEach 对 skipped test 抛异常，skip 被错误计为 fail。

**修复方案**:

文件: `core/src/nextpas.core.test.pas`, `TTestSuite.Run` 方法，约 L1171-1211

将 ekSkipped 检查提前到 BeforeEach 之前：

```pascal
  for I := 0 to High(Tests) do
  begin
    LEntry := Tests[I];
    LStatus := tsPassed;
    SetTestContext(Name, LEntry.Name);

    { Skip check BEFORE BeforeEach — skipped tests don't need setup }
    if LEntry.Kind = ekSkipped then
    begin
      LStatus := tsSkipped;
      Inc(LSkip);
      if LEntry.SkipReason <> '' then
        WriteLn('  ', StatusDot(tsSkipped), ' ', AnsiDim(LEntry.Name),
          ' — ', LEntry.SkipReason)
      else
        WriteLn('  ', StatusDot(tsSkipped), ' ', AnsiDim(LEntry.Name));
      ReportLeakIfAny(LStatus);
      Continue;
    end;

    { BeforeEach only for non-skipped tests }
    if Assigned(BeforeEach) then
    begin
      try
        BeforeEach;
      except
        on E: Exception do
        begin
          LStatus := tsError;
          WriteLn('  ', StatusDot(tsError), ' ', LEntry.Name,
            ' — beforeEach failed: ', E.Message);
          Inc(LFail);
          { Run AfterEach even if BeforeEach failed }
          if Assigned(AfterEach) then
          begin
            try AfterEach;
            except end;
          end;
          ReportLeakIfAny(LStatus);
          Continue;
        end;
      end;
    end;

    { ... rest of test execution (no ekSkipped check needed here anymore) ... }
```

**依赖**: 无
**新增测试**: 归入 B5

---

## M3. ToBeNotNil 与 Not_ 组合语义错误 — 同意

**判断**: 同意。这是真实的语义 bug。

**分析**: L715-719:
```pascal
function TExpectation.ToBeNotNil: IExpectation;
begin
  FNegated := not FNegated;
  Result := ToBeNil;
end;
```

`ToBeNotNil` 翻转 `FNegated` 后调用 `ToBeNil`。问题场景：
- `ExpectPtr(nil).Not_.ToBeNotNil`: `Not_` 设 `FNegated=True`，`ToBeNotNil` 翻回 `False`，然后 `ToBeNil` 正向检查 `nil`——**通过**。但 `Not_.ToBeNotNil` 应该断言"不是非 nil"即"是 nil"——对于 nil 值应**失败**。
- 更直观的 bug: `ExpectPtr(@x).ToBeNotNil` 翻转 `FNegated` 为 `True`，然后 `ToBeNil` 用 `FNegated=True` 检查——"期望非 nil 而得到非 nil"——通过。正确。
- 但 `ExpectPtr(@x).Not_.ToBeNotNil`: `Not_` 设 `FNegated=True`，`ToBeNotNil` 翻回 `False`，`ToBeNil` 正向检查 `@x`——"期望 nil 但得到指针"——失败。正确。
- 真正的 bug: `ExpectPtr(nil).Not_.ToBeNotNil`: 预期语义是"not (not nil)" = "期望 nil"，对 nil 应通过。实际: `Not_` → True, `ToBeNotNil` → False, `ToBeNil` 正向检查 nil → 通过。**结果正确但是通过错误的逻辑路径**。

等等，让我重新分析。`Not_.ToBeNotNil` 语义应该是"值不是非 nil"即"值是 nil"。

- `ExpectPtr(nil).Not_.ToBeNotNil`: Not_ → FNegated=True, ToBeNotNil → FNegated=False, ToBeNil 正向 → nil 通过。正确。
- `ExpectPtr(@x).Not_.ToBeNotNil`: Not_ → FNegated=True, ToBeNotNil → FNegated=False, ToBeNil 正向 → @x 非 nil 失败。正确。
- `ExpectPtr(nil).ToBeNotNil`: ToBeNotNil → FNegated=True, ToBeNil FNegated=True → "期望非 nil 但得到 nil" → 失败。正确。
- `ExpectPtr(@x).ToBeNotNil`: ToBeNotNil → FNegated=True, ToBeNil FNegated=True → "期望非 nil 而得到非 nil" → 通过。正确。

重新审查：所有四种情况结果都正确。finding 说的 "ExpectPtr(nil).Not_.ToBeNotNil 会双重取反变成正向检查，不报错" 是**错误的**。对于 nil 值，`Not_.ToBeNotNil` 应该通过（因为 nil 确实"不是非 nil"），所以不报错是正确行为。

但问题在于 **代码可维护性** 和 **错误消息**。`ToBeNil` 的错误消息是 "Expected non-nil but got nil"（正向/反向），对 `Not_.ToBeNotNil` 场景会产生误导性消息。

**最终判断**: 代码逻辑正确但实现脆弱且错误消息可能误导。建议重构为独立实现。

**修复方案**:

文件: `core/src/nextpas.core.test.pas`, L715-719

```pascal
function TExpectation.ToBeNotNil: IExpectation;
begin
  if FKind <> ekPointer then
    InternalFail('ToBeNotNil called on non-pointer expectation');
  if FNegated then
  begin
    { Not_.ToBeNotNil = expect nil }
    if FPtrValue <> nil then
      InternalFail('Expected nil but got $' +
        IntToHex(NativeUInt(FPtrValue), 16));
  end
  else
  begin
    { ToBeNotNil = expect non-nil }
    if FPtrValue = nil then
      InternalFail('Expected non-nil but got nil');
  end;
  Result := Self;
end;
```

**依赖**: 无
**新增测试**: 归入 B5

---

## M4. TTestSuite record 浅拷贝陷阱 — 部分同意

**判断**: 部分同意。这是一个 Pascal record 语义的已知陷阱，但文档应该说明。

**分析**: `TTestSuite` 是 record（值类型），`Add` 做浅拷贝。实际上 `specialize TArray<TTestEntry>` 是动态数组（引用计数），拷贝后两个 record 共享同一份数组。但如果 Add 后继续向原 suite 添加 test（触发 `SetLength` 即 COW），runner 里的副本不会看到新测试。

**修复方案**: 不做深拷贝（过度工程化），改为文档说明：

文件: `core/src/nextpas.core.test.pas`, TTestRunner.Add 注释

```pascal
procedure TTestRunner.Add(var ASuite: TTestSuite);
  { Note: ASuite is copied by value. After Add(), further modifications to the
    original ASuite variable will NOT be reflected in the runner due to Pascal
    dynamic-array copy-on-write semantics. Add all tests before calling Add. }
begin
  SetLength(Suites, Length(Suites) + 1);
  Suites[High(Suites)] := ASuite;
end;
```

**依赖**: 无
**新增测试**: 无（文档限制）

---

## M5. AllPassed 隐式执行 Run — 部分同意

**判断**: 部分同意。隐式 Run 是有意设计（懒执行），但确实可能意外触发。

**分析**: `TTestSuite.AllPassed` 在未运行时自动调用 `Run`，`TTestRunner.AllPassed` 在计数为 0 时调用 `RunAll`。这是一个便捷 API，但确实有意外执行副作用的风险。

**修复方案**: 不改变当前行为（懒执行是有用的便捷模式），添加文档注释：

```pascal
function TTestSuite.AllPassed: Boolean;
  { Returns whether all tests passed. If Run/RunParallel has not been called yet,
    this will automatically execute Run (serial mode) first. }
begin
  ...
end;
```

**依赖**: 无
**新增测试**: 归入 B5

---

## M6. CheckNoRaise 未 re-raise ETestSkipped — 同意

**判断**: 同意。这是真实的 bug。

**分析**: L503-516 中 `CheckNoRaise` 的 `on E: Exception` 会捕获 ETestSkipped（因为 ETestSkipped = class(EAbort)，EAbort = class(Exception)）。对比 `CheckRaises` L486-487 已经正确 re-raise ETestSkipped。

**修复方案**:

文件: `core/src/nextpas.core.test.pas`, L503-516

```pascal
procedure CheckNoRaise(AProc: TTestProc; const AMessage: string);
begin
  try
    AProc;
  except
    on E: ETestSkipped do
      raise; { Skip is flow control, not a testable exception }
    on E: Exception do
    begin
      if AMessage <> '' then
        InternalFail(AMessage + ': ' + E.ClassName + ': ' + E.Message)
      else
        InternalFail('Unexpected exception: ' + E.ClassName + ': ' + E.Message);
    end;
  end;
end;
```

**依赖**: 无
**新增测试**: 归入 B5（CheckNoRaise + Skip 测试）

---

## M7. CheckContains/StartsWith/EndsWith 空字符串语义不一致 — 同意

**判断**: 同意。

**分析**:
- `CheckContains('hello', '')`: `Pos('', 'hello')` 在 FPC 中返回 1 → 通过
- `CheckStartsWith('hello', '')`: `StrStartsWith` 有 `Length(APrefix) > 0` 短路 → 返回 False → 失败
- `CheckEndsWith('hello', '')`: `Length(ASuffix) = 0` → `Exit` → 通过

三者不一致。`ToStartWith` 也受 `StrStartsWith` 影响。

**修复方案**:

文件: `core/src/nextpas.core.test.pas`, L197-202

```pascal
function StrStartsWith(const S, APrefix: string): Boolean; inline;
begin
  if Length(APrefix) = 0 then
    Exit(True);  { empty prefix matches everything — consistent with Contains/EndsWith }
  Result := (Length(S) >= Length(APrefix)) and
            (Copy(S, 1, Length(APrefix)) = APrefix);
end;
```

**依赖**: 无
**新增测试**: 归入 B5

---

## M8. 并行 Setup 失败不输出被跳过的测试列表 — 同意

**判断**: 同意。

**分析**: 串行模式 L1158-1166 中 Setup 失败后遍历输出每个被跳过的测试。并行模式 L1427-1431 中只输出 setup 失败消息然后直接 exit。

**修复方案**:

文件: `core/src/nextpas.core.test.pas`, `RunParallel` 方法，L1422-1434

```pascal
  if Assigned(Setup) then
  begin
    try
      Setup;
    except
      on E: Exception do
      begin
        WriteLn('  ', AnsiRed('setup failed: ') + E.Message);
        for I := 0 to High(Tests) do
        begin
          Inc(LSkip);
          WriteLn('    ', StatusDot(tsSkipped), ' ', AnsiDim(Tests[I].Name));
        end;
        FHasRun := True;
        FLastRunPassed := False;
        FLastPass := 0;
        FLastFail := 0;
        FLastSkip := LSkip;
        Result := False;
        WriteLn(AnsiDim('  ') + IntToStr(LSkip) + ' skipped (setup failure)');
        Exit;
      end;
    end;
  end;
```

**依赖**: 无
**新增测试**: 归入 B3

---

## M9. ReportLeakIfAny 检查绝对值而非增量 — 不同意

**判断**: 不同意。

**分析**: `GetFPCHeapStatus.CurrHeapUsed > 0` 确实是绝对值检查。但实际上框架本身在每个测试前后**不应有常驻分配**（所有对象通过接口引用计数管理）。当前 58 测试全绿 0 泄漏，说明框架本身没有常驻分配。改为增量检查需要在每个测试前记录 `CurrHeapUsed` 快照，增加复杂度但无实际收益。

如果未来框架有常驻分配（如 ANSI 缓存），到时再改。当前没有 false positive。

**不修理由**: 无实际 false positive，增量方案增加复杂度，收益不明显。

---

## M10. 子测试失败不传播到 suite 级别 — 同意

**判断**: 同意。这是真实的计数 bug。

**分析**: L996-1055 中 `ExecuteSubtests` 的失败计数只在子 context 的 `FSubFail` 中，不传播到父级。所以 suite 的 `LFail` 不受影响，`FLastRunPassed` 可能错误地为 True。

**修复方案**:

文件: `core/src/nextpas.core.test.pas`, `TTestSuite.Run` 方法中的 subtest 分支（约 L1200-1206）和 `TTestContext.ExecuteSubtests` 方法

需要让 `ExecuteSubtests` 在结束时将失败信息传播出来。最简单的方式：让 `ExecuteSubtests` 在有失败时抛出或通过返回值。

方案 A（最简）：在 `ExecuteSubtests` 结束时检查 `FSubFail > 0` 并 raise：

```pascal
procedure TTestContext.ExecuteSubtests;
var
  ...
begin
  for I := 0 to High(FSubtests) do
  begin
    { ... existing logic ... }
  end;
  { Propagate subtest failures to parent }
  if FSubFail > 0 then
    InternalFail(IntToStr(FSubFail) + ' subtest(s) failed in ' + FTestName);
end;
```

但这样会被 Run 中的 `except on E: EAssertionFailed` 捕获并正确计入 `LFail`。

方案 B（更精确）：添加 `HasFailures` 方法，Run 检查后计入：

方案 A 更简洁，采用 A。

同时在 `TTestSuite.Run` 的 subtest 分支添加 exception handling：

```pascal
      else if LEntry.Kind = ekSubtest then
      begin
        LSubCtx := TTestContext.Create(LEntry.Name);
        LSubCtxI := LSubCtx;
        try
          TSubtestProc(LEntry.Proc)(LSubCtxI);
          LSubCtx.ExecuteSubtests;
        except
          on E: EAssertionFailed do
          begin
            LStatus := tsFailed;
            Inc(LFail);
          end;
          on E: Exception do
          begin
            LStatus := tsError;
            Inc(LFail);
          end;
        end;
      end
```

**依赖**: 无
**新增测试**: 归入 B5

---

## M11. 失败测试不打印错误消息 — 同意

**判断**: 同意。这是用户体验 bug。

**分析**: L1254-1257 中 tsFailed 分支输出 `(assertion failed — see above)`，但"see above"处没有实际消息。EAssertionFailed 在 L218-222 的 catch 块被捕获但消息未保存。

**修复方案**:

文件: `core/src/nextpas.core.test.pas`, `TTestSuite.Run` 方法

需要在 catch 块中捕获异常消息并传递到输出。方案：添加局部变量保存最后的错误消息。

```pascal
var
  ...
  LLastFailMsg: string;
begin
  ...
  LLastFailMsg := '';
  ...
    try
      ...
    except
      on E: ETestSkipped do
      begin
        LStatus := tsSkipped;
        Inc(LSkip);
      end;
      on E: EAssertionFailed do
      begin
        LStatus := tsFailed;
        LLastFailMsg := E.Message;  { Capture failure message }
        Inc(LFail);
      end;
      on E: Exception do
      begin
        LStatus := tsError;
        LLastFailMsg := E.ClassName + ': ' + E.Message;
        Inc(LFail);
      end;
    end;
  ...
    tsFailed:
      begin
        WriteLn('  ', StatusDot(tsFailed), ' ', AnsiRed(LEntry.Name));
        if LLastFailMsg <> '' then
          WriteLn('    ', AnsiDim(LLastFailMsg))
        else
          WriteLn('    ', AnsiDim('(assertion failed)'));
      end;
```

**依赖**: 无
**新增测试**: 无（输出变更，现有测试验证行为不变）

---

## M12. ExecuteSubtests 不聚合嵌套子测试计数 — 同意

**判断**: 同意。

**分析**: L1017-1022 中 ekSubtest 分支创建子 context 并递归调用 `ExecuteSubtests`，但父 context 的 `FSubPass`/`FSubFail`/`FSubSkip` 不更新。

**修复方案**:

文件: `core/src/nextpas.core.test.pas`, `ExecuteSubtests` 方法

在递归调用后聚合子 context 计数：

```pascal
      else if LEntry.Kind = ekSubtest then
      begin
        LSubCtx := TTestContext.Create(LEntry.Name);
        LSubCtxI := LSubCtx;
        TSubtestProc(LEntry.Proc)(LSubCtxI);
        LSubCtx.ExecuteSubtests;
        { Aggregate nested subtest counts into parent }
        Inc(FSubPass, LSubCtx.FSubPass);
        Inc(FSubFail, LSubCtx.FSubFail);
        Inc(FSubSkip, LSubCtx.FSubSkip);
      end
```

**依赖**: M10（一起处理）
**新增测试**: 归入 B5

---

## M13. TestSubtest/RunNested 类型不安全 — 部分同意

**判断**: 部分同意。类型转换确实不安全，但 FPC 没有 variant record 支持 proc 类型，独立字段是唯一选择。

**修复方案**:

文件: `core/src/nextpas.core.test.pas`

1. `TTestEntry` 添加独立字段：
```pascal
  TTestEntry = record
    Name       : string;
    Proc       : TTestProc;
    SubtestProc: TSubtestProc;  { NEW: for ekSubtest }
    Kind       : TTestEntryKind;
    SkipReason : string;
  end;
```

2. 修改 `TestSubtest` 存储到 `SubtestProc`：
```pascal
procedure TTestSuite.TestSubtest(const AName: string; AProc: TSubtestProc);
var
  LEntry: TTestEntry;
begin
  LEntry.Name       := AName;
  LEntry.Proc       := nil;
  LEntry.SubtestProc:= AProc;
  LEntry.Kind       := ekSubtest;
  LEntry.SkipReason := '';
  SetLength(Tests, Length(Tests) + 1);
  Tests[High(Tests)] := LEntry;
end;
```

3. `TTestContext.RunNested` 类似修改：
```pascal
procedure TTestContext.RunNested(const AName: string; AProc: Pointer);
var
  LEntry: TTestEntry;
begin
  LEntry.Name       := FTestName + '/' + AName;
  LEntry.Proc       := nil;
  LEntry.SubtestProc:= TSubtestProc(AProc);
  LEntry.Kind       := ekSubtest;
  LEntry.SkipReason := '';
  SetLength(FSubtests, Length(FSubtests) + 1);
  FSubtests[High(FSubtests)] := LEntry;
end;
```

4. 所有执行点改用 `LEntry.SubtestProc`：
```pascal
// TTestSuite.Run:
TSubtestProc(LEntry.Proc)(LSubCtxI);  →  LEntry.SubtestProc(LSubCtxI);

// TTestContext.ExecuteSubtests:
TSubtestProc(LEntry.Proc)(LSubCtxI);  →  LEntry.SubtestProc(LSubCtxI);

// ParallelWorkerProc — 不需要改动，因为 ekSubtest 不会在并行中运行
```

5. `RunNested` 的 `Pointer` 参数可以在 interface 中改为 `TSubtestProc`，或保留但添加类型注释。建议保留以兼容外部调用。

**依赖**: 无
**新增测试**: 归入 B5

---

## M14. APool 参数完全被忽略 — 部分同意

**判断**: 部分同意。参数确实被忽略，但已有注释说明（L92-94）。文档应更明确。

**修复方案**:

1. 代码注释已存在（L92-94），足够清晰。
2. 归入 B6 文档批次，在 README 中标注 APool 为 reserved。

**依赖**: 无
**新增测试**: 无

---

## M15. 并行模式 failure/skip/lifecycle 未测试 — 同意

**判断**: 同意。并行测试只有 happy path。

**修复方案**: 归入 **B3 并行模式修复** 批次 + **B5 测试覆盖**。

---

## M16. IExpectation 多个方法失败路径未测试 — 同意

**判断**: 同意。

**修复方案**: 归入 **B5 测试覆盖补充**。

---

## M17. Not_ 组合正向通过路径未测试 — 同意

**判断**: 同意。

**修复方案**: 归入 **B5 测试覆盖补充**。

---

## M18. RunNested 从未被测试 — 同意

**判断**: 同意。

**修复方案**: 归入 **B5 测试覆盖补充**。

---

## M19. Setup/Teardown/BeforeEach/AfterEach 失败路径未测试 — 同意

**判断**: 同意。

**修复方案**: 归入 **B5 测试覆盖补充**。

---

## M20. AllPassed 缓存行为未测试 — 同意

**判断**: 同意。

**修复方案**: 归入 **B5 测试覆盖补充**。

---

## M21. 嵌套子测试失败传播未测试 — 同意

**判断**: 同意。

**修复方案**: 归入 **B5 测试覆盖补充**。

---

## M22. 文档 ExpectProc 示例不完整 — 同意

**判断**: 同意。

**修复方案**: 归入 **B6 文档补全**。

---

## M23. 文档 API 签名不完整 — 不同意

**判断**: 不同意。

**理由**: 这是单元测试框架的 README，不需要穷举所有可选参数。Pascal 开发者可以看源码。README 重点是快速上手，不是 API 参考手册。

---

## M24. 文档 APool 说明不清晰 — 同意

**判断**: 同意。

**修复方案**: 归入 **B6 文档补全**。

---

## m1. AfterEach 失败可能使 LPass 变负 — 同意

**判断**: 同意。这是一个真实的计数 bug。

**分析**: L1239-1243 中 AfterEach 失败时 `Dec(LPass)` 在 subtest 成功后（LPass 未递增，因为子 context 计数独立）可能使 LPass 为 -1。

**修复方案**:

文件: `core/src/nextpas.core.test.pas`, L1237-1244

```pascal
        on E: Exception do
        begin
          WriteLn('  ', AnsiYellow('afterEach failed: '), E.Message);
          if LStatus = tsPassed then
          begin
            LStatus := tsError;
            Inc(LFail);
            if LPass > 0 then  { Guard against negative count }
              Dec(LPass);
          end;
        end;
```

**依赖**: 无

---

## m2. TTestEntry.Proc 对 ekSkipped 为 nil — 不同意

**判断**: 不同意。

**理由**: Proc=nil 是 Skip 注册的正常语义——skip 条目没有可执行的 proc。执行路径中 `ekSkipped` 在 proc 调用之前就跳过了（L1195-1198 和 L1010-1015），不会触及 nil proc。添加 `Assigned` 检查是防御性编程但违反 YAGNI。

---

## m3. TTestEntryKind 匿名枚举与 TExpectationKind 前缀冲突 — 不同意

**判断**: 不同意。

**理由**: FPC 中枚举成员在同一 unit 内不会冲突（有作用域）。`ekTest` 和 `ekString` 分属不同枚举类型 `TTestEntryKind` 和 `TExpectationKind`。FPC 编译器可以正确区分。改前缀是纯风格偏好，改动面大但无实际收益。

---

## m4. InitAnsi 并行环境下非线程安全 — 不同意

**判断**: 不同意。

**理由**: finding 自己说了 "已被 initialization 段缓解"。`InitAnsi` 在 `initialization` 段调用（L1587-1588），即程序启动时单线程执行。`Wrap` 中的惰性检查是冗余的——`GAnsiChecked` 已经是 True。实际上没有任何竞争窗口。已注释 "已基本无害，可忽略"。

---

## m5. CheckLength 参数顺序与 CheckEqual 相反 — 部分同意

**判断**: 部分同意。参数顺序确实是 `CheckLength(AValue, AExpected)`，而 `CheckEqual(AExpected, AActual)` 是反的。但 Pascal 社区对参数顺序没有统一标准。

**修复方案**: 不改签名（破坏性变更），添加文档注释：

```pascal
procedure CheckLength(AValue: NativeInt; AExpected: NativeInt);
  { Note: parameter order is (actual, expected), not (expected, actual) like CheckEqual }
```

**依赖**: 无

---

## m6. CheckNotEqual 参数名语义矛盾 — 不同意

**判断**: 不同意。

**理由**: `CheckNotEqual(AExpected, AActual)` 语义是"期望 AExpected 不等于 AActual"。AExpected 是你期望不等于的值，AActual 是实际值。语义完全合理。改为 AValue1/AValue2 反而丢失语义信息。

---

## m7. Not_ 多次调用状态泄漏 — 同意

**判断**: 同意。这是一个真实的 API 设计问题。

**分析**: `Not_` 返回 `Self`，修改 `FNegated` 状态。如果用户缓存了 IExpectation 引用：
```pascal
var E := Expect('hello');
E.Not_.ToEqual('world');  { OK: FNegated toggled twice }
E.ToEqual('hello');       { BUG: FNegated might be wrong if Not_ failed first time }
```

实际上，如果 `Not_.ToEqual` 通过了，`FNegated` 被 `Not_` 设 True，然后 `ToEqual` 执行检查后返回 Self（不重置 FNegated）。下次调用 `E.ToEqual('hello')` 时 FNegated 仍为 True，会错误地检查"不等于"。

但当前所有测试都是链式调用 `Expect(...).Not_.ToXxx()`，不缓存中间结果，所以不会触发。

**修复方案**:

在每个 `To*` 方法结尾重置 `FNegated := False`：

```pascal
function TExpectation.ToEqual(const AExpected: string): IExpectation;
begin
  ...
  FNegated := False;  { Reset after use }
  Result := Self;
end;
```

对所有 16 个 To* 方法都添加此重置。这是最安全的方式。

**依赖**: 无

---

## m8. FLastRunPassed 等字段使用 F 前缀但是公开的 — 不同意

**判断**: 不同意。

**理由**: Pascal record 的字段天然是公开的，没有 private 可言。`F` 前缀在 record 上是常见惯例表示"实现细节"。改名需要改所有使用点，收益为零。

---

## m9. 缺少 CheckNotContains/CheckNotStartsWith/CheckNotEndsWith — 不同意

**判断**: 不同意。

**理由**: YAGNI。IExpectation 的 Not_ 链可以表达否定语义。Check* 系列是过程式 API 的基础子集，不需要穷举组合。如果未来有需求再加。

---

## m10. 缺少 CheckNotEqual(Boolean) / CheckNotEqual(Pointer) — 不同意

**判断**: 不同意。

**理由**: 同 m9。CheckNotEqual(Boolean) 语义不自然（"期望 True 不等于 False" 是无意义的）。Pointer 版本与 CheckSame 的反面语义重叠。

---

## m11. CheckSame 与 CheckEqual(Pointer) 功能重复 — 部分同意

**判断**: 部分同意。

**分析**: 两者确实做相同的事，但 `CheckSame` 有自定义错误消息参数（`AMessage`），`CheckEqual(Pointer)` 没有。它们服务于不同场景：`CheckSame` 是 xUnit 惯例（JUnit assertEquals for objects），`CheckEqual(Pointer)` 是泛化 API。

**修复方案**: 不改 API，让 `CheckSame` 内部委托给 `CheckEqual(Pointer)` 以消除重复逻辑：

```pascal
procedure CheckSame(AExpected, AActual: Pointer; const AMessage: string);
begin
  if AExpected <> AActual then
  begin
    if AMessage <> '' then
      InternalFail(AMessage)
    else
      InternalFail('Expected same pointer $' +
        IntToHex(NativeUInt(AExpected), 16) + ' but got $' +
        IntToHex(NativeUInt(AActual), 16));
  end;
end;
```

实际上当前实现已经是直接比较，没有重复逻辑。不改。

**最终判断**: 不修。两个 API 保持独立，服务于不同用户习惯。

---

## m12. Skip 命名冲突 — 不同意

**判断**: 不同意。

**理由**: 全局 `Skip` 是 `procedure Skip(const AReason: string = '')`，`TTestSuite.Skip` 是 `procedure Skip(const AName: string; const AReason: string = '')`。FPC 可以通过参数数量区分。在用户代码中，全局 `Skip` 在测试过程中使用，`TTestSuite.Skip` 在 suite 配置阶段使用，上下文完全不同。

---

## m13. 并行模式全局计数器竞态注释缺失 — 同意

**判断**: 同意。

**修复方案**: 归入 B3，在 ParallelWorkerProc 和 test_parallel.lpr 中添加 happens-before 注释。

---

## m14. 子测试 Skip 行为未测试 — 同意

**判断**: 同意。

**修复方案**: 归入 B5。

---

## m15. Summary 方法从未被调用 — 同意

**判断**: 同意。

**修复方案**: 归入 B5。

---

## m16. RunAllParallel 从未被测试 — 同意

**判断**: 同意。

**修复方案**: 归入 B5。

---

## m17. 全局计数器隐式依赖 — 不同意

**判断**: 不同意。

**理由**: `test_runner.lpr` 中的全局计数器是有意设计——跨 suite 验证生命周期调用次数。每个 suite 的 lifecycle hook 应该独立触发，计数器累积是测试的需求而不是 bug。如果要隔离，那是测试文件的设计选择，不是框架问题。

---

## m18. Halt(1) 模式可能静默通过 — 部分同意

**判断**: 部分同意。

**分析**: catch 块中如果抛出的不是 `EAssertionFailed` 而是其他异常（比如 `EAccessViolation`），catch 到后什么都不做，测试就通过了。但实际上测试里的 `{ expected }` catch 块之前的代码路径是 `Check*(False)` → `InternalFail` → `EAssertionFailed`，不会抛其他异常。

**修复方案**: 在 catch 块中显式检查异常类型（已在 C2 批次中统一处理）。不需要额外改。

---

## m19. 文档缺失：错误处理策略 — 同意

**判断**: 同意。

**修复方案**: 归入 B6 文档补全。

---

## i1. TotalErr 字段从未被赋值 — 同意

**判断**: 同意。

**分析**: `TotalErr` 在 `TTestRunner.Create` 中初始化为 0，但在 `RunAll`/`RunAllParallel` 中从未递增。tsError 被计为 fail（`R^.Fail^ + 1`），不单独计数。

**修复方案**: 移除 `TotalErr` 字段，因为它与 `TotalFail` 语义重叠（tsError 是一种失败）。

文件: `core/src/nextpas.core.test.pas`
1. 删除 L107 `TotalErr: Integer;`
2. 删除 L1512 `Result.TotalErr := 0;`
3. 删除 L1531 `TotalErr := 0;` 和 L1553 `TotalErr := 0;`

**依赖**: 无

---

## i2. FLastPass 等在 Run 前值为 0 — 部分同意

**判断**: 部分同意。

**分析**: `Summary` 在 Run 之前调用会显示全 0。但 `Summary` 的目的是在 Run 之后调用。`AllPassed` 已有 FHasRun 检查。

**修复方案**: 在 `TTestSuite.Summary` 和 `TTestRunner.Summary` 中添加 FHasRun 检查：

```pascal
procedure TTestSuite.Summary;
begin
  if not FHasRun then
  begin
    WriteLn(AnsiYellow('Warning: ') + Name + ' has not been run yet');
    Exit;
  end;
  WriteLn(AnsiBold('--- ') + AnsiCyan(Name) + AnsiBold(' ---'));
  WriteLn('  Total tests: ', Length(Tests));
  WriteLn('  Passed: ', FLastPass, ', Failed: ', FLastFail, ', Skipped: ', FLastSkip);
end;
```

**依赖**: 无

---

## i3-i7 (文档相关) — 5 个 Info 级别文档 finding

- **i3. Quick Start 缺 modeswitch 说明**: 同意，归入 B6。
- **i4. TTestStatus 四个值语义未解释**: 同意，归入 B6。
- **i5. 子测试示例使用未定义 DB 对象**: 不同意。README 中的示例是示意代码，用户理解意图即可。不需要可编译的示例。
- **i6. 泄漏检测限制未说明**: 同意，归入 B6。
- **i7. ETestSkipped = class(EAbort) 未提及**: 同意，归入 B6。

---

# 批次执行计划

## Batch 1: 正确性修复 (P0)

**目标**: 修复真实 bug，保证框架行为正确。

**涉及 Findings**: C1, M6, M7, M10+M12, m1, m7

### B1.1 CheckNoRaise re-raise ETestSkipped (M6)

文件: `core/src/nextpas.core.test.pas` L503-516

在 `on E: Exception do` 之前添加：
```pascal
    on E: ETestSkipped do
      raise;
```

新增测试 (test_assertions.lpr):
```pascal
procedure TestCheckNoRaiseSkipPassthrough;
begin
  try
    CheckNoRaise(procedure begin Skip('flow control'); end);
    Halt(1);
  except
    on E: ETestSkipped do { expected };
  end;
end;
```

### B1.2 StrStartsWith 空字符串语义统一 (M7)

文件: `core/src/nextpas.core.test.pas` L197-202

修改 `StrStartsWith`：
```pascal
function StrStartsWith(const S, APrefix: string): Boolean; inline;
begin
  if Length(APrefix) = 0 then
    Exit(True);
  Result := (Length(S) >= Length(APrefix)) and
            (Copy(S, 1, Length(APrefix)) = APrefix);
end;
```

新增测试 (test_assertions.lpr):
```pascal
procedure TestCheckStartsWithEmptyPrefix;
begin
  CheckStartsWith('hello', '');  { Should pass — empty matches everything }
  CheckContains('hello', '');    { Verify consistency }
  CheckEndsWith('hello', '');    { Verify consistency }
end;
```

### B1.3 子测试失败传播到 suite 级别 (M10+M12)

文件: `core/src/nextpas.core.test.pas`

1. `ExecuteSubtests` 结尾添加失败传播 (M10):
```pascal
  { Propagate subtest failures to parent }
  if FSubFail > 0 then
    InternalFail(IntToStr(FSubFail) + ' subtest(s) failed in ' + FTestName);
```

2. `ExecuteSubtests` 中 ekSubtest 分支聚合计数 (M12):
```pascal
      else if LEntry.Kind = ekSubtest then
      begin
        LSubCtx := TTestContext.Create(LEntry.Name);
        LSubCtxI := LSubCtx;
        TSubtestProc(LEntry.Proc)(LSubCtxI);
        LSubCtx.ExecuteSubtests;
        Inc(FSubPass, LSubCtx.FSubPass);
        Inc(FSubFail, LSubCtx.FSubFail);
        Inc(FSubSkip, LSubCtx.FSubSkip);
      end
```

3. `TTestSuite.Run` 的 subtest 分支需要能 catch 这个传播的异常——当前已有的 `except on E: EAssertionFailed` 会自动 catch。

**注意**: 由于 `ExecuteSubtests` 中 `InternalFail` 会在子测试失败循环结束后 raise，这会被 `TTestSuite.Run` 中 L1200-1228 的 except 块捕获。但问题是 `ExecuteSubtests` 内部已经处理了每个子测试的异常（L1030-1051），`InternalFail` 在 for 循环结束后才 raise。这意味着 `TTestSuite.Run` 中 subtest 的 proc（`TSubtestProc(LEntry.Proc)(LSubCtxI)`）不会抛异常——`ExecuteSubtests` 是在 proc 调用之后单独执行的。

需要在 `TTestSuite.Run` 中显式调用 `ExecuteSubtests` 并捕获异常：

```pascal
      else if LEntry.Kind = ekSubtest then
      begin
        LSubCtx := TTestContext.Create(LEntry.Name);
        LSubCtxI := LSubCtx;
        TSubtestProc(LEntry.Proc)(LSubCtxI);
        try
          LSubCtx.ExecuteSubtests;
        except
          on E: EAssertionFailed do
          begin
            LStatus := tsFailed;
            Inc(LFail);
          end;
          on E: Exception do
          begin
            LStatus := tsError;
            Inc(LFail);
          end;
        end;
      end
```

新增测试 (test_subtests.lpr):
```pascal
procedure TestNestedFailure3Level(constref Ctx: ITestContext);
begin
  Ctx.Run('level 1',
    procedure
    begin
      Check(True);
    end);
  Ctx.Run('level 1 fail',
    procedure
    begin
      Check(False, 'L1 failure');
    end);
end;
```

### B1.4 ToBeNotNil 独立实现 (M3)

文件: `core/src/nextpas.core.test.pas` L715-719

替换为独立实现（见 M3 修复方案）。

新增测试 (test_expect.lpr):
```pascal
procedure TestExpectNotToBeNotNil;
begin
  { Not_.ToBeNotNil for nil should pass (nil is "not non-nil") }
  ExpectPtr(nil).Not_.ToBeNotNil;
end;
```

### B1.5 AfterEach LPass 负值保护 (m1)

文件: `core/src/nextpas.core.test.pas` L1237-1244

修改 Dec(LPass) 为条件递减：
```pascal
  if LPass > 0 then
    Dec(LPass);
```

### B1.6 Not_ FNegated 重置 (m7)

文件: `core/src/nextpas.core.test.pas`

在每个 To* 方法的 `Result := Self` 之前添加 `FNegated := False`。影响 16 个方法：
- ToEqual (L636)
- ToEqualInt (L658)
- ToEqualBool (L682)
- ToBeTrue (L687) — 委托给 ToEqualBool，已重置
- ToBeFalse (L692) — 同上
- ToBeNil (L712)
- ToBeNotNil (修复后独立实现，L719)
- ToContain (L738)
- ToStartWith (L758)
- ToEndWith (L784)
- ToBeGreaterThan (L804)
- ToBeLessThan (L824)
- ToBeInRange (L846)
- ToHaveLength (L864)
- ToRaise (L902)

注意：`ToBeTrue`/`ToBeFalse` 委托给 `ToEqualBool`，后者已经会重置 `FNegated`。

新增测试 (test_expect.lpr):
```pascal
procedure TestExpectNotStateReset;
var
  E: IExpectation;
begin
  E := Expect('hello');
  E.Not_.ToEqual('world');  { Not_ toggles to True, ToEqual resets to False }
  E.ToEqual('hello');       { Should work: FNegated was reset }
end;
```

**B1 依赖**: 无
**B1 总计修改**: 2 个源文件 (test.pas + 测试文件)

---

## Batch 2: 边界语义修复 (P1)

**目标**: 修复 beforeEach 顺序、类型安全等边界情况。

**涉及 Findings**: M2, M3(已移至B1), M13, i1, i2

### B2.1 BeforeEach 对 skipped test 跳过 (M2)

文件: `core/src/nextpas.core.test.pas`, TTestSuite.Run 方法

重构循环体，将 ekSkipped 检查提到 BeforeEach 之前（见 M2 修复方案）。同时简化 tsSkipped 的输出逻辑（之前在循环体末尾的 case 中重复输出）。

### B2.2 TestSubtest 使用独立字段 (M13)

文件: `core/src/nextpas.core.test.pas`

1. TTestEntry 添加 `SubtestProc: TSubtestProc` 字段
2. TestSubtest 和 RunNested 存储到 SubtestProc
3. 所有执行点使用 LEntry.SubtestProc

### B2.3 移除 TotalErr (i1)

文件: `core/src/nextpas.core.test.pas`

删除 TotalErr 字段及所有赋值。

### B2.4 Summary 添加 FHasRun 检查 (i2)

文件: `core/src/nextpas.core.test.pas`

TTestSuite.Summary 和 TTestRunner.Summary 添加前置检查。

**B2 依赖**: B1
**B2 总计修改**: 1 个源文件

---

## Batch 3: 并行模式修复 (P1)

**目标**: 修复并行模式的竞争、输出和计数问题。

**涉及 Findings**: C1, M1, M8, m13

### B3.1 并行模式全局状态保护 (C1)

文件: `core/src/nextpas.core.test.pas`

添加 `GParallelMode` 标志，`InternalFail`/`InternalSkip` 在并行模式下不写全局变量。

```pascal
var
  GParallelMode: Boolean = False;

procedure InternalFail(const AMessage: string);
begin
  if not GParallelMode then
    GTestFailed := True;
  raise EAssertionFailed.Create(AMessage);
end;

procedure InternalSkip(const AReason: string);
begin
  if not GParallelMode then
  begin
    GTestSkipped := True;
    GSkipReason := AReason;
  end;
  raise ETestSkipped.Create(AReason);
end;
```

在 `RunParallel` 中：
```pascal
  GParallelMode := True;
  try
    { ... spawn/join ... }
  finally
    GParallelMode := False;
  end;
```

### B3.2 并行 BeforeEach 失败输出 (M1)

文件: `core/src/nextpas.core.test.pas`, ParallelWorkerProc L1337-1341

在 mutex 保护下输出错误信息。

### B3.3 并行 Setup 失败输出被跳过测试列表 (M8)

文件: `core/src/nextpas.core.test.pas`, RunParallel L1422-1434

与串行模式保持一致，遍历输出被跳过的测试。

### B3.4 添加 happens-before 注释 (m13)

文件: `test_parallel.lpr`

在 `platform_thread_join` 循环后添加注释说明 happens-before 保证。

**B3 依赖**: B1 (C1 是基础)
**新增测试**: 3 个新并行测试

```pascal
{ test_parallel.lpr 新增 }

procedure TestParallelFail1;
begin
  Check(False, 'intentional parallel failure');
end;

procedure TestParallelSkip1;
begin
  Skip('intentionally skipped in parallel');
end;

{ 新 suite: Parallel Edge Cases }
procedure TestParallelWithFailure;
var
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('Parallel Fail');
  LSuite.Test('pass', @TestParallelSimple1);
  LSuite.Test('fail', @TestParallelFail1);
  { RunParallel should return False because of the failure }
  CheckFalse(LSuite.RunParallel(nil));
end;

procedure TestParallelWithSkip;
var
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('Parallel Skip');
  LSuite.Test('pass', @TestParallelSimple1);
  LSuite.Skip('planned', 'not yet');
  Check(LSuite.RunParallel(nil));  { Skip doesn't make it fail }
end;
```

---

## Batch 4: 输出与诊断增强 (P2)

**目标**: 改善错误输出质量。

**涉及 Findings**: M11, C2, m5

### B4.1 失败测试打印错误消息 (M11)

文件: `core/src/nextpas.core.test.pas`, TTestSuite.Run

添加 `LLastFailMsg` 局部变量，在 catch 块中保存消息，在输出分支中打印。

### B4.2 Check* 失败消息内容验证 (C2)

文件: `core/tests/nextpas.core.test/test_assertions/test_assertions.lpr`

为所有 `{ expected }` catch 块添加消息内容验证。

### B4.3 CheckLength 参数顺序文档注释 (m5)

文件: `core/src/nextpas.core.test.pas`, L166

添加注释说明参数顺序。

**B4 依赖**: B1
**B4 总计修改**: 2 个文件

---

## Batch 5: 测试覆盖补充 (P2)

**目标**: 补齐缺失的测试覆盖。

**涉及 Findings**: C3, M15, M16, M17, M18, M19, M20, M21, m14, m15, m16

### B5.1 Not_ 失败路径测试矩阵 (C3+M17)

文件: `core/tests/nextpas.core.test/test_expect/test_expect.lpr`

新增 ~18 个测试：

```pascal
{ Not_ 正向通过 (should pass when condition is false) }
procedure TestExpectNotToBeNil;
  ExpectPtr(@TestExpectNotToBeNil).Not_.ToBeNil;

procedure TestExpectNotToBeTrue;
  ExpectBool(False).Not_.ToBeTrue;

procedure TestExpectNotToBeFalse;
  ExpectBool(True).Not_.ToBeFalse;

procedure TestExpectNotToBeGreaterThan;
  ExpectInt(5).Not_.ToBeGreaterThan(10);

procedure TestExpectNotToBeLessThan;
  ExpectInt(10).Not_.ToBeLessThan(5);

procedure TestExpectNotToBeInRange;
  ExpectInt(100).Not_.ToBeInRange(1, 10);

procedure TestExpectNotToEqualBool;
  ExpectBool(True).Not_.ToEqualBool(False);

procedure TestExpectNotToHaveLength;
  Expect('hello').Not_.ToHaveLength(3);

{ Not_ 失败路径 (should fail when condition is true) }
procedure TestExpectNotFailToBeNil;
  try ExpectPtr(nil).Not_.ToBeNil; Halt(1);
  except on E: EAssertionFailed do Check(Pos('nil', E.Message) > 0); end;

procedure TestExpectNotFailToBeNotNil;
  try ExpectPtr(@x).Not_.ToBeNotNil; Halt(1);
  except on E: EAssertionFailed do Check(Pos('non-nil', LowerCase(E.Message)) > 0); end;

procedure TestExpectNotFailToContain;
  try Expect('hello').Not_.ToContain('ell'); Halt(1);
  except on E: EAssertionFailed do Check(Pos('should not contain', E.Message) > 0); end;

procedure TestExpectNotFailToStartWith;
  try Expect('hello').Not_.ToStartWith('hel'); Halt(1);
  except on E: EAssertionFailed do Check(Pos('should not start', E.Message) > 0); end;

procedure TestExpectNotFailToEndWith;
  try Expect('hello').Not_.ToEndWith('llo'); Halt(1);
  except on E: EAssertionFailed do Check(Pos('should not end', E.Message) > 0); end;

procedure TestExpectNotFailToBeTrue;
  try ExpectBool(True).Not_.ToBeTrue; Halt(1);
  except on E: EAssertionFailed do { check message }; end;

procedure TestExpectNotFailToBeFalse;
  try ExpectBool(False).Not_.ToBeFalse; Halt(1);
  except on E: EAssertionFailed do { check message }; end;

procedure TestExpectNotFailToBeGreaterThan;
  try ExpectInt(10).Not_.ToBeGreaterThan(5); Halt(1);
  except on E: EAssertionFailed do { check message }; end;

procedure TestExpectNotFailToBeLessThan;
  try ExpectInt(5).Not_.ToBeLessThan(10); Halt(1);
  except on E: EAssertionFailed do { check message }; end;

procedure TestExpectNotFailToBeInRange;
  try ExpectInt(5).Not_.ToBeInRange(1, 10); Halt(1);
  except on E: EAssertionFailed do { check message }; end;

procedure TestExpectNotFailToHaveLength;
  try Expect('hello').Not_.ToHaveLength(5); Halt(1);
  except on E: EAssertionFailed do { check message }; end;
```

### B5.2 IExpectation 失败路径测试 (M16)

文件: `test_expect.lpr`

```pascal
procedure TestExpectFailToStartWith;
  try Expect('hello').ToStartWith('xyz'); Halt(1);
  except on E: EAssertionFailed do Check(Pos('does not start', E.Message) > 0); end;

procedure TestExpectFailToEndWith;
  try Expect('hello').ToEndWith('xyz'); Halt(1);
  except on E: EAssertionFailed do Check(Pos('does not end', E.Message) > 0); end;

procedure TestExpectFailToHaveLength;
  try Expect('hello').ToHaveLength(3); Halt(1);
  except on E: EAssertionFailed do Check(Pos('Expected length', E.Message) > 0); end;

procedure TestExpectFailToBeFalse;
  try ExpectBool(True).ToBeFalse; Halt(1);
  except on E: EAssertionFailed do Check(Pos('False', E.Message) > 0); end;

procedure TestExpectFailToBeNotNil;
  try ExpectPtr(nil).ToBeNotNil; Halt(1);
  except on E: EAssertionFailed do Check(Pos('non-nil', E.Message) > 0); end;

procedure TestExpectFailToBeGreaterThan;
  try ExpectInt(5).ToBeGreaterThan(10); Halt(1);
  except on E: EAssertionFailed do Check(Pos('not >', E.Message) > 0); end;

procedure TestExpectFailToBeLessThan;
  try ExpectInt(10).ToBeLessThan(5); Halt(1);
  except on E: EAssertionFailed do Check(Pos('not <', E.Message) > 0); end;

procedure TestExpectFailToEqualBool;
  try ExpectBool(True).ToEqualBool(False); Halt(1);
  except on E: EAssertionFailed do Check(Pos('False', E.Message) > 0); end;

procedure TestExpectNotFailToRaise;
  try ExpectProc(procedure begin StrToInt('bad'); end).Not_.ToRaise(EConvertError); Halt(1);
  except on E: EAssertionFailed do Check(Pos('no exception', E.Message) > 0); end;
```

### B5.3 生命周期失败路径测试 (M19)

文件: `core/tests/nextpas.core.test/test_runner/test_runner.lpr`

```pascal
procedure TestSetupFailure;
var
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('SetupFail');
  LSuite.SetSetup(procedure begin raise Exception.Create('boom'); end);
  LSuite.Test('should be skipped', @TestAfterEach1);
  CheckFalse(LSuite.Run);  { Should fail because setup failed }
end;

procedure TestBeforeEachFailure;
var
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('BeforeEachFail');
  LSuite.OnBeforeEach(procedure begin raise Exception.Create('boom'); end);
  LSuite.Test('should error', @TestAfterEach1);
  CheckFalse(LSuite.Run);
end;

procedure TestTeardownFailure;
var
  LSuite: TTestSuite;
  LStdOut: Boolean;
begin
  LSuite := TTestSuite.Create('TeardownFail');
  LSuite.SetTeardown(procedure begin raise Exception.Create('boom'); end);
  LSuite.Test('should pass', @TestAfterEach1);
  { Teardown failure is a warning, test still passes }
  CheckTrue(LSuite.Run);
end;
```

### B5.4 并行失败/Skip 测试 (M15)

已包含在 B3 的新增测试中。

### B5.5 RunNested 测试 (M18)

文件: `test_subtests.lpr`

```pascal
procedure TestRunNestedUsage(constref Ctx: ITestContext);
begin
  Ctx.RunNested('nested proc', @TestSimpleSubtest);
end;
```

### B5.6 AllPassed 缓存行为测试 (M20)

文件: `test_runner.lpr`

```pascal
procedure TestAllPassedCaching;
var
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('Cache');
  LSuite.Test('pass', @TestAfterEach1);
  { First call triggers Run }
  CheckTrue(LSuite.AllPassed);
  { Second call uses cached result }
  CheckTrue(LSuite.AllPassed);
  CheckTrue(LSuite.FHasRun);
end;
```

### B5.7 嵌套子测试失败传播测试 (M21)

文件: `test_subtests.lpr`

```pascal
procedure Test3LevelNestedWithFailure(constref Ctx: ITestContext);
begin
  Ctx.Run('level2',
    procedure(constref Ctx2: ITestContext)
    begin
      Ctx2.Run('level3 ok',
        procedure begin Check(True); end);
      Ctx2.Run('level3 fail',
        procedure begin Check(False, 'deep failure'); end);
    end);
end;
```

注意：这需要 `RunNested` 方法支持 `TSubtestProc` 参数，或使用 `Run` 配合 `TTestProc` wrapper。

### B5.8 子测试 Skip 测试 (m14)

文件: `test_subtests.lpr`

```pascal
procedure TestSubtestSkip(constref Ctx: ITestContext);
begin
  Ctx.Run('sub pass',
    procedure begin Check(True); end);
  Ctx.Run('sub skip',
    procedure begin Skip('not ready'); end);
end;
```

### B5.9 Summary 测试 (m15)

文件: `test_runner.lpr`

```pascal
procedure TestSummarySmoke;
var
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('Summary');
  LSuite.Test('pass', @TestAfterEach1);
  LSuite.Run;
  LSuite.Summary;  { Should not crash }
end;
```

### B5.10 RunAllParallel 测试 (m16)

文件: `test_parallel.lpr`

```pascal
procedure TestRunAllParallel;
var
  LRunner: TTestRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('Parallel Suite');
  LSuite.Test('p1', @TestParallelSimple1);
  LSuite.Test('p2', @TestParallelSimple2);
  LRunner := TTestRunner.Create('Runner');
  LRunner.Add(LSuite);
  CheckTrue(LRunner.RunAllParallel(nil));
  CheckTrue(LRunner.TotalPass = 2);
end;
```

**B5 依赖**: B1-B4
**总计新增测试**: ~35-40 个

---

## Batch 6: 文档补全 (P3)

**目标**: 补全 README 文档。

**涉及 Findings**: M4, M5, M14, M22, M24, i3, i4, i6, i7, m19

### B6.1 README 需要新增/更新的章节

1. **APool 说明**: "APool is reserved for future use. Pass nil. Parallel mode currently uses direct platform_thread_create."

2. **modeswitch 说明**: Quick Start 中添加 `{$modeswitch anonymousfunctions}` 和 `{$modeswitch functionreferences}` 说明。

3. **TTestStatus 语义表**:
   | Status | 含义 |
   |--------|------|
   | tsPassed | 断言全部通过 |
   | tsFailed | EAssertionFailed — 断言失败 |
   | tsSkipped | ETestSkipped — 显式跳过 |
   | tsError | 非预期异常（非 EAssertionFailed/ETestSkipped）|

4. **Error Handling 章节**: 说明 ETestSkipped = class(EAbort) 用于流控，不被 CheckRaises/CheckNoRaise 捕获。

5. **泄漏检测限制**: 说明仅串行模式、CurrHeapUsed 绝对值检查、逐测试粒度。

6. **ExpectProc 两种写法**: @Proc 语法 vs 匿名函数语法。

7. **TTestSuite record 语义**: Add 之后不应修改 suite（COW 陷阱）。

8. **AllPassed 语义**: 未运行时自动触发 Run。

**B6 依赖**: B5

---

## 不修改的 Findings 汇总

| Finding | 理由 |
|---------|------|
| M9 (ReportLeakIfAny 绝对值) | 无实际 false positive，增量方案增加复杂度 |
| M23 (API 签名不完整) | README 不需要穷举可选参数 |
| m2 (Proc nil for ekSkipped) | 执行路径已正确处理，Assigned 检查违反 YAGNI |
| m3 (枚举前缀冲突) | FPC 有作用域区分，不冲突 |
| m4 (InitAnsi 线程安全) | initialization 段单线程执行，无竞争窗口 |
| m6 (CheckNotEqual 参数名) | 语义合理 |
| m8 (F 前缀在 record) | Pascal record 天然公开，F 前缀是惯例 |
| m9 (缺少 CheckNotXxx) | YAGNI，Not_ 链可替代 |
| m10 (缺少 CheckNotEqual 重载) | YAGNI |
| m11 (CheckSame vs CheckEqual) | 保持独立，服务不同用户习惯 |
| m12 (Skip 命名冲突) | FPC 可区分，上下文不同 |
| m17 (全局计数器依赖) | 测试设计选择，非框架问题 |
| i5 (DB 示例) | 示意代码不需要可编译 |

---

## 执行顺序与依赖图

```
B1 (正确性修复) ──────────────────────────────────────┐
  ↓                                                    │
B2 (边界语义) ← B1                                     │
  ↓                                                    │
B3 (并行模式) ← B1                                     │
  ↓                                                    │
B4 (输出诊断) ← B1                                     │
  ↓                                                    │
B5 (测试覆盖) ← B1 + B2 + B3 + B4                     │
  ↓                                                    │
B6 (文档补全) ← B5                                     │
```

B2, B3, B4 互相独立，可以并行执行（前提是 B1 完成）。

## 预计工作量

| 批次 | 框架代码修改 | 测试新增/修改 | 预计耗时 |
|------|-------------|--------------|----------|
| B1 | ~6 处 | ~6 个 | 1-2h |
| B2 | ~4 处 | 0 | 1h |
| B3 | ~3 处 | ~5 个 | 1-2h |
| B4 | ~2 处 | ~10 个 | 1h |
| B5 | 0 | ~40 个 | 3-4h |
| B6 | 0 (README) | 0 | 1h |
| **合计** | **~15 处** | **~61 个** | **8-11h** |

## 验证策略

每个批次完成后：
1. `make -C core/tests/nextpas.core.test clean test` 全量通过
2. `make hygiene` 无产物泄漏
3. `git diff --check` 无 whitespace 问题
