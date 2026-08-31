# nextpas.core.contracts 代码契约

**模块路径**：`core/src/nextpas.core.contracts.pas`（1 个源文件，35 行）
**层级**：L0（assertion helpers；`base/errors` 单源，`ContractsRequire*` `inline` 零开销）
**Owner**：L0 root
**最后更新**：2026-08-31
**版本**：1.1

---

## 1. 接口契约

### 1.1 公开 API

```pascal
procedure ContractsRequire(aCondition: Boolean; const aMessage: string); inline;
procedure ContractsRequireAssigned(aCondition: Boolean; const aName: string); inline;
```

- `ContractsRequire(False, Msg)` → `raise EInvalidArgument.Create(Msg)` 当且仅当定义 `NEXTPAS_CORE_CONTRACTS`；否则为 `inline` 空操作（`if aCondition and (aMessage='') then;` 消 dead-code 警告）。
- `ContractsRequireAssigned(False, Name)` → `raise EArgumentNil.Create(Name + ' is nil')` 同上；否则空操作。
- 两过程均为 `inline`，调用方 `uses nextpas.core.contracts` 零额外运行时开销；失败路径抛 `nextpas.core.base`/`exception` 既有异常分类，不新增错误类型。

### 1.2 构建开关

`{$IFDEF NEXTPAS_CORE_CONTRACTS}` 时 `uses nextpas.core.base` 并启用抛异常；未定义时不引入 `base` 依赖，保持 L0 零依赖编译（`base` 仅在检查期出现）。

---

## 2. 依赖边界

- 允许：`nextpas.core.base`（仅在 `NEXTPAS_CORE_CONTRACTS` 下）、`nextpas.core.exception` 间接（经 `base` 的 `EInvalidArgument`/`EArgumentNil`）。
- 禁止：`SysUtils`、`platform`、`io`、`text`/`bytes`、`Windows`/`BaseUnix` 等宿主单元。
- Owner 复用：异常分类单源于 `base`/`exception`，不二次定义字符串格式化或比较逻辑。

---

## 3. 不变量

- **[INV-1]** 未定义 `NEXTPAS_CORE_CONTRACTS` 时，两过程必须不抛异常、不分配、不引入 `base` 符号。
- **[INV-2]** 定义时，两过程必须分别抛 `EInvalidArgument` / `EArgumentNil` 且保留传入消息/名称。
- **[INV-3]** 两过程均为 `inline`，热点路径零调用开销。

---

## 4. 错误处理

| 场景 | 行为 |
|------|------|
| `aCondition=True` | 静默返回（无论开关） |
| `aCondition=False` + 开关 off | 静默返回（生产零开销） |
| `aCondition=False` + 开关 on | 抛 `EInvalidArgument` 或 `EArgumentNil` |

---

## 5. 线程安全

纯过程，无状态；✅ 线程安全。

---

## 6. 内存/性能

- `inline` + 空操作分支 → off 时完全消去；on 时仅在失败路径分配异常对象。
- 零堆分配于成功路径；异常路径由调用方 `try/except` 接管，资源释放由异常传播保证。

---

## 7. 测试入口

```bash
make -C core/tests/nextpas.core.contracts clean test
make focused FOCUS=core/tests/nextpas.core.contracts/test_contracts
```

套件：`test_contracts`（`ContractsRequire` 真/假、`ContractsRequireAssigned`、`--contracts-enabled` 双构建）。

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | contracts lane |
| 2026-08-31 | 1.1 | 文档矩阵补齐：新增 `docs/contracts/`（README+CONTRACT），对齐 `module-registry` L0 `contracts`，`inline` 零拷贝证据 | core-docs |
