# nextpas.core.system Error Handling

本规范定义 system kernel 的错误处理策略、异常分类、错误传播和诊断机制。

## 1. 错误处理原则

### 1.1 默认用异常

- 所有可恢复错误使用异常
- 调用方写直线代码，不需要检查返回值
- 边界处统一捕获（HTTP handler、TUI 事件循环、main）

### 1.2 TryXxx 仅在必要时

- 仅当调用方需区分成功/失败分支时提供 TryXxx 函数
- 返回 `Boolean` 表示成功/失败
- 输出参数返回结果

```pascal
// ✅ 正常情况用异常
function StrToInt(const S: string): LongInt;  // 失败抛 EConvertError

// ✅ 需要区分分支时用 TryXxx
function TryStrToInt(const S: string; out AValue: LongInt): Boolean;
```

### 1.3 "无值"用 nil

- 不引入 Result/Optional 类型
- "无值"用 `nil` 表达
- 返回指针或接口的函数，`nil` 表示失败

```pascal
function FindComponent(const AName: string): TComponent;  // 找不到返回 nil
function GetInterface(const IID: TGUID; out Obj): Boolean; // 找不到返回 False
```

## 2. 异常层次

### 2.1 根异常类

```pascal
Exception = class
  FMessage: AnsiString;
  // ...
end;
```

所有自定义异常必须继承自 `Exception`。

### 2.2 标准异常类

| 异常类 | 用途 | 抛出场景 |
|--------|------|---------|
| `EAbort` | 静默中止 | 不显示错误对话框 |
| `EConvertError` | 类型转换失败 | `StrToInt('abc')` |
| `EAssertionFailed` | 断言失败 | `Assert(False)` |
| `ENextPasError` | nextPas 运行时错误 | 内部错误 |

### 2.3 扩展异常类（来自 nextpas.core.errors）

| 异常类 | 错误类别 | 用途 |
|--------|---------|------|
| `EArgumentError` | `ecArgument` | 参数错误 |
| `EInvalidArgument` | `ecArgument` | 无效参数 |
| `EArgumentNil` | `ecArgument` | 参数为 nil |
| `EArgumentOutOfRange` | `ecArgument` | 参数超出范围 |
| `ETimeoutError` | `ecTimeout` | 操作超时 |
| `EIOError` | `ecIO` | I/O 错误 |
| `EFileNotFound` | `ecIO` | 文件不存在 |
| `EDirectoryNotFound` | `ecIO` | 目录不存在 |
| `EOutOfMemoryError` | `ecMemory` | 内存不足 |
| `EStackOverflow` | `ecStack` | 栈溢出 |
| `EAccessViolation` | `ecAccess` | 访问违规 |
| `EBusError` | `ecAccess` | 总线错误 |
| `ESignalError` | `ecSignal` | 信号错误 |
| `EInvalidCast` | `ecInvalidCast` | 无效类型转换 |
| `EInvalidOp` | `ecFloatOp` | 无效浮点操作 |
| `EZeroDivide` | `ecFloatOp` | 除零错误 |
| `EOverflow` | `ecFloatOp` | 浮点溢出 |
| `EUnderflow` | `ecFloatOp` | 浮点下溢 |
| `EExternalException` | `ecExternal` | 外部异常 |
| `EControlC` | `ecExternal` | Ctrl+C 中断 |
| `EPrivilege` | `ecPrivilege` | 权限不足 |
| `EResNotFound` | `ecResource` | 资源未找到 |
| `EPropReadOnly` | `ecPropAccess` | 属性只读 |
| `EPropWriteOnly` | `ecPropAccess` | 属性只写 |
| `EAbstractError` | `ecAbstract` | 调用抽象方法 |
| `EIntfCastError` | `ecInterface` | 接口转换失败 |
| `EIntOverflow` | `ecMisc` | 整数溢出 |
| `ESafecallException` | `ecMisc` | safecall 异常 |
| `EVariantError` | `ecMisc` | Variant 错误 |
| `ENotImplemented` | `ecMisc` | 功能未实现 |
| `ENetworkError` | `ecMisc` | 网络错误 |
| `EEncryptionError` | `ecMisc` | 加密错误 |
| `ECompressionError` | `ecMisc` | 压缩错误 |
| `EThreadError` | `ecMisc` | 线程错误 |
| `EResourceNotFound` | `ecResource` | 资源未找到 |

### 2.4 错误类别常量

```pascal
ecArgument    = 0;   // 参数错误
ecTimeout     = 1;   // 超时
ecIO          = 2;   // I/O 错误
ecMemory      = 3;   // 内存错误
ecStack       = 4;   // 栈错误
ecAccess      = 5;   // 访问错误
ecSignal      = 6;   // 信号错误
ecAssertion   = 7;   // 断言错误
ecConvert     = 8;   // 转换错误
ecInvalidCast = 9;   // 无效转换
ecFloatOp     = 10;  // 浮点操作错误
ecExternal    = 11;  // 外部异常
ecPrivilege   = 12;  // 权限错误
ecResource    = 13;  // 资源错误
ecPropAccess  = 14;  // 属性访问错误
ecAbstract    = 15;  // 抽象错误
ecInterface   = 16;  // 接口错误
ecMisc        = 17;  // 其他错误
```

## 3. 异常传播

### 3.1 异常抛出

```pascal
// 抛出异常
raise EConvertError.Create('Invalid integer: ' + S);

// 抛出带消息的异常
raise EArgumentError.CreateFmt('Argument %d out of range', [AIndex]);
```

### 3.2 异常捕获

```pascal
try
  // 可能抛出异常的代码
except
  on E: EConvertError do
    WriteLn('Convert error: ', E.Message);
  on E: EArgumentError do
    WriteLn('Argument error: ', E.Message);
  on E: Exception do
    WriteLn('Other error: ', E.Message);
end;
```

### 3.3 异常清理

```pascal
var
  LResource: TMyResource;
begin
  LResource := TMyResource.Create;
  try
    // 使用 LResource
  finally
    LResource.Free;  // 无论是否异常都释放
  end;
end;
```

### 3.4 异常重新抛出

```pascal
try
  // 可能抛出异常的代码
except
  on E: Exception do
  begin
    // 记录日志
    LogError(E);
    raise;  // 重新抛出当前异常
  end;
end;
```

## 4. 运行时错误分类

### 4.1 致命错误（不可恢复）

| 错误类型 | 异常类 | 处理方式 |
|---------|--------|---------|
| 栈溢出 | `EStackOverflow` | 程序终止 |
| 内存不足 | `EOutOfMemoryError` | 程序终止 |
| 访问违规 | `EAccessViolation` | 程序终止 |
| 总线错误 | `EBusError` | 程序终止 |

### 4.2 可恢复错误

| 错误类型 | 异常类 | 处理方式 |
|---------|--------|---------|
| 类型转换 | `EConvertError` | 捕获并处理 |
| 参数错误 | `EArgumentError` | 捕获并处理 |
| I/O 错误 | `EIOError` | 捕获并处理 |
| 文件不存在 | `EFileNotFound` | 捕获并处理 |

### 4.3 静默错误

| 错误类型 | 异常类 | 处理方式 |
|---------|--------|---------|
| 用户中止 | `EAbort` | 静默捕获，不显示错误 |

## 5. 错误上下文

### 5.1 异常消息

异常消息应包含：
- 错误描述
- 相关参数值
- 操作上下文

```pascal
// ✅ 好的错误消息
raise EConvertError.CreateFmt('Invalid integer: "%s"', [S]);

// ❌ 差的错误消息
raise EConvertError.Create('Invalid input');
```

### 5.2 异常链

异常可以包含原因链：

```pascal
try
  // 底层操作
except
  on E: Exception do
    raise EIOError.Create('Failed to read config') from E;
end;
```

## 6. 编译器错误处理

### 6.1 fpc_* 异常函数

```pascal
function fpc_setjmp(var S: jmp_buf): LongInt;      // 保存栈上下文
procedure fpc_longjmp(var S: jmp_buf; Value: LongInt); // 恢复栈上下文
function fpc_get_exception_address: Pointer;        // 获取异常地址
function fpc_get_exception_object: Pointer;         // 获取异常对象
function fpc_get_exception_class: TClass;           // 获取异常类
function fpc_try_push(var S: ExceptionRecord): LongInt; // try 入栈
procedure fpc_try_pop(S: ExceptionRecord);          // try 出栈
procedure fpc_raise_exception(S: Exception);        // 抛出异常
procedure fpc_finally_end;                          // finally 结束
procedure fpc_except_end;                           // except 结束
```

### 6.2 np.system.* 异常契约

| 契约名称 | 语义 |
|----------|------|
| `np.system.exception_try_push` | 异常 try 入栈 |
| `np.system.exception_try_pop` | 异常 try 出栈 |
| `np.system.exception_raise` | 异常抛出 |
| `np.system.exception_finally_end` | finally 结束 |
| `np.system.exception_except_end` | except 结束 |

## 7. 异常与资源管理

### 7.1 RAII 模式

使用 `try...finally` 确保资源释放：

```pascal
var
  LFile: TFileStream;
begin
  LFile := TFileStream.Create('data.txt', fmOpenRead);
  try
    // 使用 LFile
  finally
    LFile.Free;
  end;
end;
```

### 7.2 接口自动管理

使用接口自动管理资源生命周期：

```pascal
type
  IMyResource = interface(IUnknown)
    procedure DoSomething;
  end;

var
  LRes: IMyResource;
begin
  LRes := TMyResource.Create;
  LRes.DoSomething;
  // LRes 离开作用域时自动释放
end;
```

### 7.3 FreeAndNil vs SafeFree

```pascal
var
  LObj: TMyClass;
begin
  LObj := TMyClass.Create;

  // FreeAndNil: 如果 Destroy 抛出异常，LObj 不为 nil
  FreeAndNil(LObj);

  // SafeFree: 即使 Destroy 抛出异常，LObj 也为 nil
  SafeFree(LObj);
end;
```

## 8. 错误处理最佳实践

### 8.1 异常选择

1. 使用标准异常类，不要创建不必要的自定义异常
2. 异常消息要包含足够上下文
3. 使用错误类别常量（`ecArgument` 等）进行分类

### 8.2 捕获策略

1. 只捕获能处理的异常
2. 不要捕获所有异常然后忽略
3. 在边界处统一捕获

```pascal
// ✅ 正确：捕获特定异常
try
  LValue := StrToInt(S);
except
  on E: EConvertError do
    LValue := 0;
end;

// ❌ 错误：捕获所有异常然后忽略
try
  LValue := StrToInt(S);
except
  // 忽略错误
end;
```

### 8.3 资源清理

1. 始终使用 `try...finally` 清理资源
2. 在 `finally` 块中释放资源
3. 使用接口自动管理生命周期

### 8.4 性能考虑

1. 异常有性能开销，不要用于正常控制流
2. 使用 TryXxx 函数避免异常开销
3. 预检查条件避免不必要的异常

```pascal
// ❌ 差：用异常做控制流
try
  LValue := StrToInt(S);
except
  LValue := 0;
end;

// ✅ 好：预检查
if TryStrToInt(S, LValue) then
  // 使用 LValue
else
  LValue := 0;
```

## 9. 调试与诊断

### 9.1 异常堆栈跟踪

异常对象可以包含堆栈跟踪信息，用于调试：

```pascal
try
  // 可能抛出异常的代码
except
  on E: Exception do
  begin
    WriteLn('Error: ', E.Message);
    WriteLn('Stack trace: ');
    WriteLn(E.StackTrace);  // 如果支持
  end;
end;
```

### 9.2 错误日志

在边界处记录错误日志：

```pascal
procedure HandleRequest(ARequest: TRequest; AResponse: TResponse);
begin
  try
    // 处理请求
  except
    on E: Exception do
    begin
      LogError(E);
      AResponse.StatusCode := 500;
      AResponse.Body := 'Internal Server Error';
    end;
  end;
end;
```

### 9.3 断言

使用断言检查前置条件和后置条件：

```pascal
procedure DoSomething(AValue: LongInt);
begin
  Assert(AValue > 0, 'AValue must be positive');
  // ... 实现
  Assert(Result <> nil, 'Result must not be nil');
end;
```

## 10. 与 FPC 兼容性

### 10.1 兼容的异常类

- `Exception`, `EAbort`, `EConvertError`, `EAssertionFailed` 与 FPC 兼容
- 异常消息格式与 FPC 兼容

### 10.2 兼容的错误处理

- `try...except...finally` 语法与 FPC 兼容
- `raise` 语法与 FPC 兼容
- `on E: Exception do` 语法与 FPC 兼容

### 10.3 不兼容之处

- nextPas 可能使用不同的异常实现机制（table-based vs setjmp/longjmp）
- 异常堆栈跟踪格式可能不同
- 某些 FPC 特有的异常类可能不存在

## 11. 迁移指南

### 11.1 从 FPC 迁移

1. 保持异常类层次不变
2. 保持错误处理语法不变
3. 更新自定义异常类的基类（如果需要）

### 11.2 常见问题

**Q: 为什么我的异常没有被捕获？**
A: 检查异常类是否正确继承自 `Exception`。

**Q: 为什么异常消息为空？**
A: 确保在创建异常时传递消息参数。

**Q: 如何获取异常的调用栈？**
A: 使用 `E.StackTrace`（如果支持）或手动记录调用栈。

## 12. 参考资料

| 文档 | 用途 |
|------|------|
| `abi-specification.md` | 异常模型 ABI 细节 |
| `api-reference.md` | 异常类和错误类别清单 |
| `design-decisions.md` | DD-9 异常模型选择 |
| `runtime-contracts.md` | np.system.exception_* 契约 |
| `lifecycle-contracts.md` | 异常边界契约 |
| `contract-coverage-table.md` | 异常契约覆盖证据 |
