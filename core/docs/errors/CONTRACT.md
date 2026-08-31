# nextpas.core.errors 代码契约

**模块路径**：`core/src/nextpas.core.errors.pas`（1 个源文件，72 行）
**层级**：L0（纯门面，re-export nextpas.core.exception）
**Owner**：Claude（AI 负责）
**最后更新**：2026-08-31
**版本**：1.2

---

## 1. 接口契约

### 1.1 模块定位

纯 re-export 门面。消费者通过 `uses nextpas.core.errors` 访问完整异常分类，无需直接依赖 `nextpas.core.exception` 或 `SysUtils`。

### 1.2 Re-export 类型

| 类型别名 | 来源 | 说明 |
|----------|------|------|
| `Exception` | exception.Exception | 根异常类 |
| `ExceptClass` | exception.ExceptClass | 异常元类 |
| `EConvertError` | exception.EConvertError | 转换错误 |
| `EAssertionFailed` | exception.EAssertionFailed | 断言失败 |
| `TErrorCategory` | exception.TErrorCategory | 错误分类枚举 |
| `ENextPasError` | exception.ENextPasError | nextPas 异常基类 |
| `EArgumentError` | exception.EArgumentError | 参数错误 |
| `ENullReferenceError` | exception.ENullReferenceError | 空引用 |
| `EInvalidOperationError` | exception.EInvalidOperationError | 非法操作 |
| `ENotImplementedError` | exception.ENotImplementedError | 未实现 |
| `ENotSupportedError` | exception.ENotSupportedError | 不支持 |
| `ETimeoutError` | exception.ETimeoutError | 超时 |
| `ECancelledError` | exception.ECancelledError | 已取消 |
| `EInterruptedError` | exception.EInterruptedError | 中断 |
| `EWouldBlockError` | exception.EWouldBlockError | 阻塞 |
| `EPermissionError` | exception.EPermissionError | 权限 |
| `ENotFoundError` | exception.ENotFoundError | 未找到 |
| `EAlreadyExistsError` | exception.EAlreadyExistsError | 已存在 |
| `EResourceExhaustedError` | exception.EResourceExhaustedError | 资源耗尽 |
| `EIOError` | exception.EIOError | IO 错误 |
| `ENetworkError` | exception.ENetworkError | 网络错误 |
| `EParseError` | exception.EParseError | 解析错误 |
| `EIndexOutOfRangeError` | exception.EIndexOutOfRangeError | 索引越界 |
| `EOutOfMemoryError` | exception.EOutOfMemoryError | 内存不足 |
| `EOutOfMemory` | exception.EOutOfMemory | 内存不足（别名） |

### 1.3 Re-export 常量

17 个 `TErrorCategory` 常量：`ecNone`..`ecInternal`。

### 1.4 函数

```pascal
function ErrorCategoryToString(const ACategory: TErrorCategory): string; inline;
// 委托给 nextpas.core.exception.ErrorCategoryToString
```

---

## 2. 不变量

- **[INV-1]** 所有 re-export 符号必须与 `nextpas.core.exception` 一一对应
- **[INV-2]** 本模块不添加任何新类型或新逻辑

---

## 3. 错误处理

纯门面，无自有错误逻辑。所有异常行为由 `nextpas.core.exception` 定义。

---

## 4. 线程安全

✅ 所有符号为类型别名或 inline 函数，完全线程安全。

---

## 5. 内存管理

无自有内存管理。所有类型生命周期由 `nextpas.core.exception` 管理。

---

## 6. 测试覆盖

| 子系统 | 测试文件 | 说明 |
|--------|----------|------|
| 门面完整性 | test_errors | 验证所有 re-export 符号可访问 |
| 源契约边界 | test_errors_source_contracts | shell 脚本验证不引入额外依赖 |
| **合计** | **2 个测试目录** | |

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本：完整六项契约 | Claude |
| 2026-08-30 | 1.1 | 冻结感修复：更新最后更新至 2026-08-30 并 bump 版本 | Claude |
| 2026-08-31 | 1.2 | 时效刷新：批量校正至 2026-08-31，统一 AL1 口径 | core-docs |
