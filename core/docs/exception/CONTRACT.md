# nextpas.core.exception 代码契约

**模块路径**：`core/src/nextpas.core.exception.pas`（1 个源文件，602 行）
**层级**：L0（框架根异常，零外部依赖）
**Owner**：Claude（AI 负责）
**最后更新**：2026-08-30
**版本**：1.1

---

## 1. 接口契约

### 1.1 Exception 根类

```pascal
Exception = class(TObject)
  constructor Create(const msg: string);
  constructor CreateFmt(const msg: string; const args: array of const);
  property HelpContext: longint;
  property Message: string;
end;
```

**设计决策**：nextpas 自有 Exception，字段布局与 FPC 兼容（fmessage/fhelpcontext），但不从 FPC SysUtils re-export。

### 1.2 ENextPasError 框架异常根

```pascal
ENextPasError = class(Exception)
  Category: TErrorCategory;
  Inner: Exception;       // 内部异常链
  // 7 个构造函数重载
  destructor Destroy; override;  // 释放 Inner（若 FOwnsInner）
end;
```

| 构造函数 | 参数 |
|----------|------|
| `Create(AMessage)` | 消息，Category=DefaultCategory |
| `Create(AMessage, ACategory)` | 消息+分类 |
| `CreateFmt(AMessage, AArgs)` | 格式化消息 |
| `CreateFmt(AMessage, ACategory, AArgs)` | 格式化+分类 |
| `CreateFmt(AMessage, ACategory, AArgs, AInner, AOwnsInner)` | 完整参数 |
| `Create(AMessage, AInner, AOwnsInner)` | 消息+内部异常 |
| `Create(AMessage, ACategory, AInner, AOwnsInner)` | 全参数 |

**不变量**：
- `DefaultCategory` 为 virtual 方法，子类 override
- `ResolveCategory(ACategory)`: ACategory=ecNone 时使用 DefaultCategory
- `Destroy` 释放 `FInner`（仅当 FOwnsInner=True）

### 1.3 TErrorCategory 枚举

18 个值：`ecNone`, `ecInvalidArgument`, `ecNullReference`, `ecInvalidOperation`, `ecNotImplemented`, `ecNotSupported`, `ecTimeout`, `ecCancelled`, `ecInterrupted`, `ecWouldBlock`, `ecPermission`, `ecNotFound`, `ecAlreadyExists`, `ecResourceExhausted`, `ecIO`, `ecNetwork`, `ecParse`, `ecInternal`

### 1.4 异常子类（15 个）

| 异常类 | DefaultCategory | 说明 |
|--------|----------------|------|
| EArgumentError | ecInvalidArgument | 参数错误 |
| ENullReferenceError | ecNullReference | 空引用 |
| EInvalidOperationError | ecInvalidOperation | 非法操作 |
| ENotImplementedError | ecNotImplemented | 未实现 |
| ENotSupportedError | ecNotSupported | 不支持 |
| ETimeoutError | ecTimeout | 超时 |
| ECancelledError | ecCancelled | 已取消 |
| EInterruptedError | ecInterrupted | 中断 |
| EWouldBlockError | ecWouldBlock | 阻塞 |
| EPermissionError | ecPermission | 权限 |
| ENotFoundError | ecNotFound | 未找到 |
| EAlreadyExistsError | ecAlreadyExists | 已存在 |
| EResourceExhaustedError | ecResourceExhausted | 资源耗尽 |
| EIOError | ecIO | IO 错误 |
| ENetworkError | ecNetwork | 网络错误 |
| EParseError | ecParse | 解析错误 |
| EIndexOutOfRangeError | ecInvalidArgument | 索引越界 |
| EOutOfMemoryError | ecResourceExhausted | 继承 EResourceExhaustedError |
| EOutOfMemory | ecResourceExhausted | 兼容别名，继承 EOutOfMemoryError |

### 1.5 兼容类型

```pascal
ExceptClass = class of Exception;
EConvertError = class(Exception);
EAssertionFailed = class(Exception);
```

### 1.6 工具函数

```pascal
function ErrorCategoryToString(ACategory: TErrorCategory): string;
// 18 个分类 → 字符串表示
```

### 1.7 内部 FormatStr

自包含格式化函数（%s/%d/%%），不依赖 SysUtils.Format。
- 支持 vtAnsiString, vtUnicodeString, vtString, vtChar, vtPChar, vtWideChar
- 支持 vtInteger, vtInt64, vtBoolean
- 未知类型输出 '???' 或 '0'

---

## 2. 不变量

- **[INV-1]** `Exception` 字段布局与 FPC 兼容（fmessage: string, fhelpcontext: LongInt）
- **[INV-2]** `ENextPasError.Category` 通过 `ResolveCategory` 保证非 ecNone
- **[INV-3]** `ENextPasError.Destroy` 仅释放 `FOwnsInner=True` 的 Inner
- **[INV-4]** 所有子类的 `DefaultCategory` 返回非 ecNone 值
- **[INV-5]** `EOutOfMemoryError` 继承 `EResourceExhaustedError`（OOM 是资源耗尽的特例）
- **[INV-6]** `FormatStr` 零 SysUtils 依赖，自包含实现

---

## 3. 错误处理

本模块是错误处理基础设施本身。无自有错误路径。

| 场景 | 策略 |
|------|------|
| FormatStr 参数不足 | 静默跳过（输出空/0） |
| FormatStr 未知格式符 | 输出 %X 原样 |
| Inner=nil 且 AOwnsInner=True | 安全（Destroy 检查 nil） |

---

## 4. 线程安全

| 类型 | 线程安全 | 说明 |
|------|----------|------|
| Exception 类层次 | ✅ | 每次 raise 创建新实例 |
| TErrorCategory 枚举 | ✅ | 编译时常量 |
| ErrorCategoryToString | ✅ | 纯函数 |
| FormatStr | ✅ | 纯函数，栈上操作 |

---

## 5. 内存管理

- `ENextPasError.Destroy` 释放 `FInner`（FOwnsInner=True 时）
- `Exception.Create` 仅设置字段，无堆分配
- 所有异常对象由 `raise`/`except` 自动管理

---

## 6. 测试覆盖

| 子系统 | 测试文件 | 说明 |
|--------|----------|------|
| 异常根 + 分类 | test_exception_root | Create/Category/Inner/Destroy |
| **合计** | **1 个测试目录** | |

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本：完整六项契约 | Claude |
| 2026-08-30 | 1.1 | 冻结感修复：更新最后更新至 2026-08-30 并 bump 版本 | Claude |
