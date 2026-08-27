# V3-C8 RTL 收敛 sweep 提案（已完成 2026-08-28）

> **状态**：Done（审计 → 四切片 landing 完成，12→0 `SysUtils`，见 §8）
> **范围**：`nextpas.core.db` 家族从 FPC RTL（`SysUtils`）向 `nextpas.core` 词汇表收敛
> **红线**：不新建 FPC 兼容层；缺失能力只反哺既有 `nextpas.core` 模块
> **触发条件**：路线图 §7.1 登记的 C8 占位 —— 家族 39 单元中 12 单元仍 `uses SysUtils`，`text.conv` 已有全量对应物，具备收敛条件
> **关联**：C6 已验证 `db.sqlscan` 抽取路径；C8 为同类“词汇表收口”最后一扫

---

## 1. 审计快照（2026-08-28，`main@64e41f2db` + `codex/core-db@50621b87f`）

### 1.1 规模

- 家族单元总数：**39**（`core/src/nextpas.core.db*.pas`）
- 仍 `uses SysUtils`：**12**（`grep -l "^\s*SysUtils" | wc -l = 12`），占比 30.7%
- 已干净：27 单元（含 `db.sqlscan` 新单元、`db.sqlite.conn` 已主动避免 `SysUtils`、`db.async` 零直引等正面先例）
- 按 `implementation uses` 统计更精确：`db.async` 与 `db.sqlite.conn` 的 `SysUtils` 命中为**注释误报**，真实 `uses` 为 12

### 1.2 12 单元清单（按风险分层）

| # | 单元 | `SysUtils` 位置 | 实际符号占用 | 风险 |
|---|---|---|---|---|
| 1 | `db.factory` | interface | `LowerCase`, `Trim` 各 1 处 | **低** — 纯文本归一 |
| 2 | `db.tx` | implementation | `IntToStr` 1 处（`'np_db_sp_' + IntToStr(ADepth)`） | **低** |
| 3 | `db.pas`（L3 门面） | implementation | **零** — `uses SysUtils` 悬空，仅为 `Supports` 历史残留 | **极低** — 去 import + 补 `base.utils` |
| 4 | `db.redis.transport` | interface | **零** — 悬空 | **极低** |
| 5 | `db.migrate` | implementation | `LowerCase`, `IntToHex(LCrc,8)`, `IntToStr` ×7, `FormatISO8601UTC(DateTimeToUnix(DateTimeUtcNow()))`（时间非 SysUtils） | **低** |
| 6 | `db.pool` | interface | `Format` ×2, `GetTickCount64`, `IntToStr` ×2, `QWord` 时间算术 | **中** — `Format` 需覆盖 `%s/%d/%m`，`GetTickCount64` 需换源 |
| 7 | `db.redis.resp` | interface | `IntToStr` ×3, `IntToHex` 1, `Move/SetString/TBytes` 手工, `Format` 类错误串 | **中** — interface 段不可轻移（`TBytes` 遮蔽坑已成文） |
| 8 | `db.redis.adapter` | interface | `IntToStr` 2, `StrToInt64Def`, `Trim`, `FreeAndNil`, `Exception` catch-all ×2 | **中** |
| 9 | `db.redis.subscribe` | interface | `IntToStr` 1, `Exception` catch-all ×3, `QWord/Int64` 计时 | **中** |
|10 | `db.odbc.loader` | implementation | `Format` ×2, `AnsiString(PAnsiChar)` | **中** — C ABI 边界 |
|11 | `db.mysql.adapter` | implementation | `IntToStr` ×6, `StrToIntDef`, `LowerCase`, `FreeAndNil`, `AnsiString` | **高** — 二进制协议+文本协议双路径 |
|12 | `db.odbc.adapter` | implementation | `Format` ×4, `IntToStr` ×9, `Trim`, `FreeAndNil`, `AnsiString` | **高** — `Format` 最重，参数绑定/诊断全族 |

> 注：`db.mysql.adapter` 头部统计仅算 interface 段；implementation 段另含 `AnsiPtrToStr` 候选 6 处 `string(AnsiString(...))` 强转。

### 1.3 符号级占用全景（`grep -n` 实证）

```
Text      : IntToStr×~27, IntToHex×2, Trim×3, LowerCase×3, Format×8, StringReplace 0
Lifecycle : FreeAndNil×3
Time      : GetTickCount64×1(pool), DateTimeUtcNow×1(migrate, via time.* 非 SysUtils)
Error     : Exception catch-all ×~7 (redis.adapter/subscribe/pool/mysql), EConvertError 0
C ABI     : string(AnsiString(PAnsiChar)) ×~12 (mysql×6, odbc.loader×1, odbc.adapter×2, redis.resp×2)
Other     : StrToIntDef, StrToInt64Def 各 1, Val 0 (已在 conv 内消化)
```

**结论**：92% 为 `text.conv` / `base.utils` / `text.format` 已有能力；剩余 8% 为时间与 C ABI 边界，`core` 已有解。

---

## 2. 替换词表（`nextpas.core` 侧已就绪能力）

| FPC `SysUtils` | `nextpas.core` 对应 | 备注 |
|---|---|---|
| `IntToStr(Int64/UInt64)` | `nextpas.core.text.conv.IntToStr` | `Str()` 路径，无 locale 副作用，perf 同源 |
| `IntToHex(Value, Digits)` | `text.conv.IntToHex` | 内部 `text.number.IntToHexBuffer`，已补大写归一 |
| `Trim / TrimLeft/Right` | `text.conv.Trim*` → `text.utils.Trim*` | ASCII 语义一致 |
| `LowerCase / UpperCase` | `text.conv.LowerCase/UpperCase` → `text.utils.*` | ASCII-only，与 `text.unicode` 分工明确 |
| `StrToIntDef / StrToInt64Def` | `text.conv.StrToInt*Def` | `Val` 路径，已含范围 guard |
| `Format('%s %d ...')` | `text.format.TextFormat` + `text.conv.Format` 薄封装 | 见 §2.1 覆盖度说明 |
| `FreeAndNil(var Obj)` | `nextpas.core.base.utils.FreeAndNil` | 语义逐字节一致，已在 `db.redis.adapter` 等处实证可用 |
| `GetTickCount64` | `nextpas.core.time.GetTickCount64` → `platform_monotonic_ns` | 单调源，pool 计时已验证 |
| `Exception` / `EConvertError` | `nextpas.core.errors.Exception`（re-export `core.exception`） | 见 §3 异常策略 |
| `string(AnsiString(PAnsiChar))` | `nextpas.core.text.conv.AnsiPtrToStr` | **必换** — 仓库硬边界：返回托管记录数组的函数内强转会损坏临时管理（`odbc.loader` 已成文坑） |

### 2.1 `Format` 覆盖度实证

| 单元 | 实际 format 串 | 覆盖 |
|---|---|---|
| `odbc.adapter` | `'odbc: %s failed [%s/%d]'`, `'odbc: %s failed [retcode %d, no diagnostics]'`, `'SQLBindParameter(%d)'` 等 | 仅 `%s %d`，无 `%f %x %n` |
| `odbc.loader` | `'odbc: %s [%s/%d] %s'` | 同上 |
| `pool` | `'acquire timeout %dms'`, `'pool ... %s'` | `%s %d` |
| `migrate` | 无 `Format`，仅字符串拼接 | — |

`text.format.TextFormat` 已支持 `%s %d %%`，`text.conv.Format` 为兼容入口（标记 deprecated 但可用）。**C8 仅使用 `%s %d %%` 三键，无风险**。若未来需 `%x/%f`，走 `text.format` 扩展而非回退 `SysUtils`。

### 2.2 时间源

- `pool.NowTick: QWord = GetTickCount64` → 换 `nextpas.core.time.GetTickCount64`（内联 `platform_monotonic_ns div 1000000` 等价，单调性更强）。
- `migrate` 的 `DateTimeUtcNow()` / `DateTimeToUnix` 非 `SysUtils` 而是 `nextpas.core.time`（`performance` 命名空间下已用），无需动。
- 若追求极致单调统一，可二阶段改为 `platform_monotonic_ns` 直用；本次保持 `GetTickCount64` 别名零行为差。

### 2.3 C ABI 边界（`AnsiString` 强转）

现状 `string(AnsiString(mysql_error(...)))` 等在 `mysql.adapter` 6 处、`odbc.loader` 1 处。替换为 `AnsiPtrToStr(PAnsiChar(...))`：

- **正确性**：`AnsiPtrToStr(nil)= ''` 安全；`Move` + `SetString` 零临时，规避“返回托管记录数组函数内强转破坏”硬边界。
- **性能**：原路径 `AnsiString` 临时分配 + 拷贝；新路径单次 `SetLength+Move`，**更快**且无隐式 `SetCodePage`。
- **迁移点**：`text.conv` 已有实现，`core.exception` 头注亦推荐此入口；`db` 家族已在 `sqlite.conn` 实证 ASCII 大写无 `SysUtils` 路径。

---

## 3. 异常语义专项（`Exception` 唯一难点）

### 3.1 现状

- `EDbError` 已继承自 `ENextPasError` → `Exception`（`core.exception` 金字塔），**非 `SysUtils` 直接派生**。
- 7 处 `on E: Exception do` catch-all（`redis.adapter` 2、`redis.subscribe` 3、`pool` / `mysql.adapter` / `odbc.adapter` 各散落）—— 语义为“网/协议任意失败桥接为 `EDbError`”，**必须保持 catch-all 宽度**，不可收窄为 `EDbError`。
- `db.async` 公开面 `ErrorObj: Exception`（`nextpas.core.db.async` Line 72）返回句柄持有的异常对象所有权（句柄析构 `FErrorObj.Free`）。调用方 `ErrorObj = nil` 即成功，非 nil 时**不得手动 Free**。

### 3.2 策略

1. **类型别名不变更语义**：所有 `Exception` 引用改为 `nextpas.core.errors.Exception`（或 `core.exception.Exception`），二者在 FPC 下 `type Exception = SysUtils.Exception` 为同一类型别名，**ABI 与 `AcquireExceptionObject` 行为零变化**。`nextpas.core.errors` 已 re-export `Exception/ExceptClass/EConvertError`，消费方无需直引 `SysUtils`。
2. **不引入 `try/except` 窄化**：保持 `on E: Exception`，不改为 `on E: ENextPasError`，避免漏捕 `ENetworkError/TlsException` 等 `ENextPasError` 同辈（`redis.adapter BridgeNetError` 依赖）。
3. **`AcquireExceptionObject` 保留**：该例程属 `System` 非 `SysUtils`，不受收敛影响（`db.async` 已正确使用）。
4. **文档补位**：`CONTRACT §2.17` 已述 `ErrorObj` 所有权；C8 在 `db.async` 头注补一行“`Exception` 指 `core.errors.Exception`（FPC 别名），非直引 `SysUtils`”。

### 3.3 反哺点

- 无需新建异常类；`core.exception` 已覆盖 `EConvertError/EAssertionFailed/EAbort` 全量。
- 若未来需 `EArgumentException` 等细分，直接用 `core.exception` 既有项，不新增包装。

---

## 4. 反哺清单（缺口 = 0，均为既有模块）

| 需求 | 现状 | 动作 |
|---|---|---|
| `Trim/LowerCase/IntToStr` | `text.conv` 已全量 | **无** |
| `IntToHex` | `text.conv.IntToHex` 已有 | **无** |
| `Format` | `text.format.TextFormat` 已有 | **无**，C8 仅用 `%s/%d` |
| `FreeAndNil` | `base.utils.FreeAndNil` 已有 | **无** |
| `Supports`（`db.pas` 门面） | `base.utils.Supports` 已有双重载 | C8 为 `db.pas/pool` 补 `uses base.utils` |
| `GetTickCount64` | `core.time.GetTickCount64` 已有 | **无** |
| `AnsiPtrToStr` | `text.conv.AnsiPtrToStr` 已有 | **无** |
| `DateTimeUtcNow` 等 | `core.time` 已有 | **无** |

**结论**：C8 **零反哺新增**，纯消费侧替换。符合“只反哺既有 core 模块”红线，且本次无需改 `core`。

---

## 5. 分治实施计划（4 个 landing 切片，串行）

每个切片独立 `landing/core-db-c8-*` 分支、`make focused` + `heaptrc 0` + `make hygiene` + `git diff --check` 四门禁；合入后回填本提案状态。

| 切片 | 内容 | 单元 | 验证 | 备注 |
|---|---|---|---|---|
| **C8-1** | 文本归一（低风险） | `db.factory` (`Trim/LowerCase`), `db.tx` (`IntToStr`), `db.migrate` (`IntToStr/IntToHex/LowerCase`), `db.pas`/`db.redis.transport` 悬空清理 | `test_db_migrate_v2` 7 组 + `test_db_tx_v2` 7 组 + `test_db_factory` 15 组 | 建立 `text.conv` 基线，无 `Format` 干扰 |
| **C8-2** | 池与时间 | `db.pool` (`Format`→`text.format`, `GetTickCount64`→`core.time`, `IntToStr`) | `test_db_pool_v2` 15 组 + `test_db_tx` 7 组 + `bench_db_pool_stress` 定性（opens==Max 不变式） | 观测 `LeakDetectionThreshold` 路径 `Format` 覆盖 |
| **C8-3** | 协议与诊断（`Format` 重灾区） | `db.odbc.adapter` 4 串 + `db.odbc.loader` 2 串 + `db.redis.resp`（`IntToStr/IntToHex`） | `test_db_odbc_adapter` 6+1skip + `test_db_odbc_base` 7 组 + `test_db_redis_base` 11 组 + `test_db_redis_adapter` 15 组 | `Format` 逐串对照 `text.format` 输出；`redis.resp` 注意 interface 段不可移 |
| **C8-4** | C ABI 与生命周期收口 | `db.mysql.adapter` (`AnsiString`→`AnsiPtrToStr` 6 处 + `FreeAndNil`), `db.redis.adapter/subscribe` (`FreeAndNil` + `Exception` 别名), `db.odbc.adapter` `FreeAndNil` | `test_db_mysql_adapter` 6+1skip + `test_db_redis_subscribe` 11 组 + `test_db_pg` 13 组（`AnsiPtrToStr` 回归）+ `test_db_conformance` 2 组 | 最终 `grep -R "SysUtils" core/src/nextpas.core.db*.pas` 应 **0 行**（仅注释豁免） |

> **异常面**不单独切片：各片顺手将 `on E: Exception` 的 `Exception` 归属改为 `nextpas.core.errors.Exception`（import 侧），不改变 catch 宽度；`db.async` 头注补位在 C8-4。

### 5.1 切片内纪律

- `uses` 调整：`SysUtils` 移除时同步增补 `nextpas.core.text.conv` / `nextpas.core.text.format` / `nextpas.core.base.utils` / `nextpas.core.time` / `nextpas.core.errors` 中**实际使用项**，不批量预引。
- `Format` 迁移：逐调用点单测对照（`SysUtils.Format` vs `TextFormat` 对 `%s %d` 输出逐字节一致性已在 `text.format` 既有用例覆盖，C8 仅验证无新增动词）。
- `AnsiPtrToStr` 迁移：保持 `PAnsiChar(nil)` 语义不变；`mysql.adapter` 的 `my_error/my_sqlstate` 返回 `PAnsiChar` 直喂，不经 `AnsiString` 中转。
- 悬空单元（`db.pas`/`redis.transport`）直接删 `SysUtils`，补 `base.utils`（若需 `Supports`）。

---

## 6. 验证矩阵（每片必跑，合入前全量）

### 6.1 Focused Gates（`make focused FOCUS=core/tests/nextpas.core.db/<gate>`）

| Gate | 覆盖切片 | 期望 |
|---|---|---|
| `test_db_factory` | C8-1 | 15 passed heaptrc 0 |
| `test_db_migrate_v2` | C8-1 | 7 passed |
| `test_db_tx_v2` | C8-1/2 | 7 passed |
| `test_db_pool_v2` | C8-2 | 15 passed |
| `test_db_redis_base` | C8-3 | 11 passed |
| `test_db_redis_adapter` | C8-3/4 | 15 passed heaptrc 0 |
| `test_db_redis_subscribe` | C8-4 | 11 passed |
| `test_db_odbc_base` | C8-3 | 7 passed |
| `test_db_odbc_adapter` | C8-3 | 6 +1 skip（env 门控） |
| `test_db_mysql_adapter` | C8-4 | 6 +1 skip |
| `test_db_pg` | C8-4 | 13 passed（`bytea` 装饰路径回归 `AnsiPtrToStr`） |
| `test_db_sqlscan` | 全片 | 12 passed（零漂移护栏） |
| `test_db_conformance` | 全片 | 2 passed（能力互证） |
| `test_db_unified` | 全片 | 18 passed |

### 6.2 Hygiene 与静态门禁

```
./scripts/build-hygiene-check.sh      # = pass（无 .o/.ppu 落盘）
git diff --check                      # = 空（无尾空/制表）
grep -rn "SysUtils" core/src/nextpas.core.db*.pas  # 终态 0 行（注释行豁免需单批核）
grep -rn "string(AnsiString" core/src/nextpas.core.db*.pas  # 终态 0 行
```

### 6.3 性能基线（±15% 噪声带内视为等价，§C4 纪律）

- `IntToStr` 热路径：`text.conv` 与 `SysUtils` 同为 `Str()`，**零差异**；`Format` 仅低频诊断路径（`odbc` 异常串、`pool` 泄漏报告），不入 `J1 adapter_overhead` 热点。
- `AnsiPtrToStr` 较 `string(AnsiString(...))` 少一次 `AnsiString` 临时堆分配，**微优**。
- `GetTickCount64` 换源为 `platform_monotonic_ns`，精度/单调性更优，开销同级（`RDTSC` / `clock_gettime`）。

---

## 7. 风险与回退

| 风险 | 概率 | 缓解 | 回退 |
|---|---|---|---|
| `TextFormat` 对 `%s/%d` 外动词静默差异 | 低 | 本次仅 `%s/%d/%%`，已逐串审计 | 单片 `git revert`，不影响他片 |
| `AnsiPtrToStr(nil)` 与 `string(AnsiString(nil))` 语义差异 | 极低 | 前者显式 `nil → ''`，后者同值；已在 `text.conv` 单测覆盖 | 同上 |
| `FreeAndNil` 换源后 double-free | 极低 | `base.utils.FreeAndNil` 与 `SysUtils` 同实现（`Pointer(AObj):=nil; LTemp.Free`） | 同上 |
| `Exception` 别名导致 `is` 判断漂移 | 无 | FPC 下 `type Exception = SysUtils.Exception` 同一类型，重载解析一致 | 无需 |
| `TBytes` 遮蔽（`redis.resp` interface 段） | 已知 | **禁止**将 `SysUtils` 移 implementation 段；保持 interface 段 `nextpas.core.base` 在前 | 静态检查：编译失败即拦截 |

---

## 8. 文档与契约同步（已回填 2026-08-28）

- 本提案落 `core/docs/plans/2026-08-28-db-v3-c8-rtl-convergence-proposal.md`（状态 Done）
- 已回填：
  - `core/docs/db/CONTRACT.md` §6 末尾增 C8 节（家族 0 `SysUtils` 终态，词汇表 `text.conv/text.format/base.utils/core.time/core.errors`）
  - `core/docs/db/README.md` 特性矩阵下方增"词汇表"行 + 门禁速查补 `test_db_factory` 等
  - 路线图 `2026-08-23-db-v3-industrial-roadmap.md` §7.1 增 C8 完成行 + C 线表 C8 行 + §5 清单勾选

---

## 9. 判定标准（Done 2026-08-28 实证）

- [x] `grep -l "^\s*SysUtils" core/src/nextpas.core.db*.pas` = 0（注释 3 行豁免；`uses` 终态 0）
- [x] 12 单元 `uses` 均指向 `nextpas.core.*`（无 `SysUtils/Classes/BaseUnix/Windows`）
- [x] §6.1 全量 gates **全绿 + heaptrc 0 unfreed**（env 门控 skip 如实登记：C8-1 factory 15/migrate_v2 10/tx_v2 9；C8-2 pool_v2 19；C8-3 redis_base 11/redis_adapter 15/odbc_base 7+1skip/odbc_adapter 6+1skip；C8-4 mysql_adapter 6+1skip/redis_subscribe 10/pg 13/sqlscan 12/conformance 2/unified 18）
- [x] `make hygiene` + `git diff --check` 双 pass（每片独立验证）
- [x] 四切片独立 landing（`landing/core-db-c8-1-text-20260828` --no-ff e77398f40 + `landing/core-db-c8-234-20260828` cherry-picks 925806581），lane 收敛后 `core-db`@`main` 零 diff
- [ ] `grep -l "string(AnsiString" = 0` 未达成——残留 8 处在 `db.pg.*` LO 路径（非 C8 12 单元 scope），记入下一 sweep，不阻 C8 Done

---

## 附录 A. 原始审计证据（可复算）

```bash
# 规模
ls core/src/nextpas.core.db*.pas | wc -l          # 39
grep -l "^\s*SysUtils" core/src/nextpas.core.db*.pas | wc -l  # 12

# 符号占用抽样
grep -n "SysUtils\|Format\|IntToStr\|Trim\|LowerCase\|GetTickCount64\|FreeAndNil\|AnsiString" \
  core/src/nextpas.core.db.{factory,migrate,mysql.adapter,odbc.adapter,odbc.loader,pool,redis.resp,redis.adapter}.pas

# 時間源
grep -rn "GetTickCount64" core/src/nextpas.core.time*.pas  # core.time 已有

# 异常别名
grep -n "on E: Exception\|ErrorObj: Exception" core/src/nextpas.core.db.async.pas core/src/nextpas.core.db.redis.adapter.pas
```

## 附录 B. 对照：已干净单元的最佳实践（供 C8 复制）

- `db.sqlite.conn`：ASCII 大写自实现，不引 `SysUtils`（Line 306 注释即纪律）
- `db.async`：全程 `core.errors / core.time / core.sync / core.thread.*`，零 `SysUtils`，`AcquireExceptionObject` 走 `System`
- `db.sqlscan`：纯函数 + `text.conv`，零 `SysUtils`，方言表记录化

## 附录 C. 不做项（重申）

- 不为 `Format` 扩展 `%f/%x`（本次无需求）
- 不为 `SysUtils` 建 `nextpas.core.compat.sysutils` 兼容层（基线禁令）
- 不改 `db.intf` 公开面（`ErrorObj: Exception` 类型名保留，仅换 `uses` 来源）
