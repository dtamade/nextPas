# ADR 0002：达梦 DM8 适配器路径 — ODBC 网关优先，专用 DPI 按需

- 状态：已提议（待总控确认后转已接受）
- 日期：2026-08-28
- 决策人：core-db lane / 总控
- 范围：`nextpas.core.db` D4、`core/docs/db/national-db-guide.md`、`core/src/nextpas.core.db.*`

## 背景

D4 要求补齐国产数据库中达梦 DM8 的工业级覆盖。DM8 同时提供两套 C 侧接口：

- **DPI**（Dameng Program Interface，`libdmdpi.so` / `dmdpi.dll`，头文件 `DPI.h`）：OCI 风格句柄层级 `DPIENV→DPICONN→DPISTMT`，函数 `dpi_alloc_env/conn/stmt`、`dpi_prepare/exec/fetch/bind_param/get_data`，原生类型 `DM_BLOB/CLOB`、`DM_DATETIME` 等，支持数组绑定与 LOB 流式，错误码体系独立（如 `-1007` 约束、`-11011` 鉴权、`-2003` 连接）。
- **ODBC**（`libdodbc.so` / `dodbc.dll`）：基于 DPI 的薄封装，通过 `odbcinst.ini` 注册（`[DM8 ODBC DRIVER] Driver=/opt/dmdbms/bin/libdodbc.so`），经 `SQLDriverConnect("Driver=DM8 ODBC DRIVER;Server=...")` 消费，符合 ISO CLI。

A3/A4 ODBC 网关（`libodbc.so.2` 顺序探测 + 22 符号 ANSI 绑定 + `ClassifyOdbc/Ex`）已落地，12 门禁全绿，`IM002` 诊断链真库验证通过。MySQL 专用适配器模式（`mysql.loader` 多候选 + `mariadb_connection` flavor 探测 + 双 `MYSQL_BIND` 72/112 镜像）亦已验证。需在两者间做出选择。

## 驱动因素

- 国产库覆盖（政企存量）且不破坏 `only-downward-deps` / `no parallel universe` / `honest semantics`
- 零新增代码的杠杆 vs 原生精度的收益
- CI 可用性：SDK 许可、QEMU ARM 开销、`make hygiene` 纪律

## 考虑的选项

### 选项 1：仅专用 DPI

新建 `nextpas.core.db.dm.{base,ffi,loader,adapter}` 四单元，候选 `libdmdpi.so` / `libdmdpi.so.8` / `dmdpi.dll`，`dpi_*` FFI、`ClassifyDm` 归一表、`TDbKind.dbkDm` 尾部追加、`test_db_dm`（loader 离线 + env 门控 live）。获得完整 DM 错误码细分与原生类型、数组绑定等。

代价：新增 ABI 分叉、SDK 许可下载、CI 需额外 `libdmdpi`、ARM 版 DM8 镜像需 `--platform linux/arm64` QEMU 5-10× 慢，维护成本翻倍。

### 选项 2：仅 ODBC 网关

复用 A3/A4 零新增代码。`core/src/nextpas.core.db.odbc.*` 已 5.3k 行，`SQL_C_SBIGINT/CHAR/BINARY` 分派已覆盖 DM 类型（整数/浮点精确、其余文本/二进制无损），`?` 占位符经 `nextpas.core.db.sqlscan` 同构支持。

代价：错误归一有损（DM ODBC 统一报 `HY000/23000/08001` 泛化，`ClassifyOdbc` 默认不消费 `NativeError`，多数 `decUnknown`）、`SupportsSavepoints/LargeObjects/NativeBool=false` 诚实降级、Manager 一跳约 10-15% 开销（仍在 `≤1.15×` 判据内）。

### 选项 3：分阶段混合（推荐）

**P1 立即 ODBC 网关，P2 按需 DPI**。P1 声明 `ConnectOdbc` 为 DM8 Tier-1 路径，消费者以 DM 方言编写 SQL（`?` 占位符、`WithTransaction` 事务、超时 advisory），经 `NEXTPAS_ODBC_TEST_CONN='Driver=DM8 ODBC DRIVER;Server=127.0.0.1;Port=5236;...'` 复用 openGauss 的 env 门控 conformance 模式。P2 仅当触发条件满足时再实现专用适配器。

## 决策

选择 **选项 3**。本切片 **不新增** `nextpas.core.db.dm.*`。P2 触发条件与设计草图如下：

- **触发**：(a) ≥2 消费方反馈 `ClassifyOdbc` 欠归一阻塞线上排障，或 (b) 需 LOB/interval/数组绑定的性能/语义，或 (c) 需 Savepoint 嵌套。
- **P2 设计**：候选 `libdmdpi.so` / `libdmdpi.so.8`，`dpi_*` 25 符号 FFI，`ClassifyDm` 入 `db.err`，`dbkDm` 尾部追加（序号钉死），`test_db_dm` 复刻 `test_db_mysql` 门禁（loader 离线 + env 门控 live）。

此决策符合路线图工业原则：*优先复用既有驱动 + 兼容性探测，不为协议兼容库重写适配器*，以及 D5 flavor 细化先例（仅当缺口导致可度量的欠归一时才加代码）。

## 后果

**正向**：立即获得 DM8 覆盖，共享基准/观测/池/重试能力，单一 ABI 维护。

**负向**：Savepoints/LO/ArrayBinding 保持 `false`，错误多数 `decUnknown`（已文档化）。

**缓解**：`national-db-guide.md §2.4` 诚实能力矩阵 + `§4.5` DM Docker/QEMU 配方；P2 的 `ClassifyDmEx` 设计已预留；方言保持消费者 SQL 原样（不做解析器）。

## 验证

- `NEXTPAS_ODBC_TEST_CONN` 指向 DM8（`5236`，`SYSDBA`）时，`make focused FOCUS=core/tests/nextpas.core.db/test_db_conformance`（含 `trace`）应通过，离线门禁保持 `test_db_odbc_base/adapter` 绿。
- DM 特有失败按 §2.6 风格记录，不吸收进能力矩阵。

## 需更新项

- `core/docs/db/national-db-guide.md`：扩展 §2.4 DM DSN 与能力行，新增 §4.5 DM Docker/QEMU 行（`arm64 --platform linux/arm64`）。
- `core/docs/plans/2026-08-23-db-v3-industrial-roadmap.md` D4：标记 `ODBC gateway P1 ✅` / `DPI P2 ⏳`。
- `core/docs/db/CONTRACT.md` §2.11：补充 DM ODBC flavor 说明（仅 SqlState，NativeError 透传）。

## 参考

- DM8 手册：DPI Programming Guide、ODBC Driver Guide
- `core/src/nextpas.core.db.odbc.loader.pas:100-140`、`odbc.adapter.pas:1-45`、`mysql.loader.pas:170-216`
- 路线图 D4、`national-db-guide.md` D1、ADR 0001
