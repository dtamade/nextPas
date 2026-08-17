# 消除 Classes/SysUtils/Process 双实现：收敛计划

> 日期：2026-08-17
> 分支：`codex/compiler-system`（worktree `.worktrees/compiler-system`）
> 状态：草案，待总控确认后按批执行

## 1. 目标与判据

**目标**：编译链内同一 FPC 单元名只保留一个实现（消除双实现漂移），并把编译链对
FPC 兼容 stub 的真实消费面收敛到最小。方向与 CLAUDE.md「逐步让 nextpas.core 模块用
自己的类型替代 FPC 类型，最终 stub 自然废弃」一致，但**不做无差别迁移**——每批必须
回答：消除的是 stub 分叉，还是制造新的自举负担。

**完成判据**：
- 每对双实现（Classes / SysUtils / Process）在编译链内只剩一个被引用实现，另一份
  归档或删除，不再漂移。
- `units/<target>/` 下的 stub 面只保留仍有编译器单元图消费的单元，其余移入
  `units/<target>/_frozen/` 或标注 `not-in-compile-graph`（不直接删除，避免破坏其他
  AI 的进行中工作）。
- M2-L3 探针 `undefined uniq/total` 不升；compiler-pass 回归全绿；hygiene 通过。

## 2. 现状盘点（2026-08-17 实测）

### 2.1 编译链真实使用的 FPC 兼容 stub 只有 6 个

`.nextpas/cache/backend/linux-x86_64/nextpas.ll`（340 个单元 init）∩
`units/linux-x86_64/*.pas`：

| stub | 编译链消费者 | 证据 |
|---|---|---|
| `Classes` | `rtl/core/text/np_text_primitives.pas`（TryReadCoreTextFile） | .ll:301202 调用、379795-380468 定义 |
| `SysUtils` | `rtl/core/text/np_text_primitives.pas` + `core/src` 5 处（exception、thread.base、net.async.udp、system.sysutils、numa） | `^\s*SysUtils[,;]` 命中 |
| `Process` | `tools/stage0/nextpas_command_test.pas`（RunTest） | .ll:13439 RunTest → 13264/13533 TProcess |
| `System` | FPC magic unit，编译器语义 live | — |
| `TypInfo` | `core/src/nextpas.core.system.typinfo.pas`（S4 门面） | |
| `Variants` | `core/src/nextpas.core.collections.base.pas` | |

其余 40+ stub（Base64、BaseUnix、ctypes、DateUtils、Math、OpenSSL、Registry、
Sockets、Unix、Windows、Winsock2、zlib、AmbiguousHelper、CycleA/B、Mu*/BsFlood*、
Stage0Greeter* 等）**全部未进编译链**，是死面或测试夹具。

### 2.2 双实现清单（同一单元名两份实现 = 漂移源）

| 单元名 | A：编译链实际使用（stub） | B：未接线的自研版 | 漂移证据 |
|---|---|---|---|
| `Classes` | `units/linux-x86_64/Classes.pas`（TStream 家族全量，826 行） | `rtl/core/classes/np_classes.pas`（TFileStream 无 TStream 继承，248 行） | 自研版 `TFileStream.Seek(Offset: LongInt; Origin: Word)` 与 stub 的 `Int64/TSeekOrigin` 签名不同 |
| `SysUtils` | `units/linux-x86_64/SysUtils.pas`（961 行） | `rtl/core/sysutils/np_sysutils.pas`（666 行） | `TSearchRec`：stub 用 `Pattern` 字段，自研版用 `FilterPattern`+`SearchDir` —— **字段名已漂移** |
| `Process` | `units/linux-x86_64/Process.pas` | `rtl/core/process/np_process.pas` | 同形不同源 |

另有第三份 `core/src/nextpas.core.system.classes.pas`（Sysroot Classes 兼容门面，
re-export `Classes.THandleStream`/`TMemoryStream`）——**stub 里没有这两个类型**，
该门面只在 FPC 宿主编译环境成立，nextPas 编译链不含它（.ll 无此单元）。一旦有模块
被 nextPas 编译且 uses 该门面，立即编译失败。这是定时炸弹，不是当前阻塞。

### 2.3 已有收敛成就（文档已过时）

- `compiler/toolchain/np_toolchain_runner.pas`、`np_toolchain_profiles.pas` 已全走
  `nextpas.core.process/fs`——`core/docs/system/compatibility-facades.md` 里点的
  TFileStream/Classes consumer 已不存在。
- `tools/stage0/nextpas_command_*.pas` 已全走 `nextpas.core.*`（除 `nextpas_command_test.pas`
  仍 uses `process`）。
- `core/src` 多数模块已完成 FPC RTL 隔离（git log：`fix(test): replace SysUtils/Classes
  with framework abstractions (FPC RTL isolation)`）。

### 2.4 顺带发现的 B6.5 家族签名不一致（挂账，本计划不修）

- `TFileStream.Create`：.ll:380277 define `(ptr,ptr,i32,ptr)` 4 参 vs :301202 call 3 实参。
- `TProcess.Create`：.ll:13264 define `(ptr,ptr)` 2 参 vs :13533 call 1 实参。

两者都是「class 构造/方法被 direct call，参数签名编错」的 method-object 家族症状，
归 B6.5 桶。本计划批次执行后相关符号若从 .ll 消失，这两条自动减压。

## 3. 关键机制事实

- **nextPas 编译器不处理 `{$UNITPATH}` 指令**：该指令只出现在编译器源码自身头部
  （供 FPC 宿主编译用）。因此 `rtl/core/text/np_text_primitives.pas` 与
  `rtl/core/process/np_process.pas` 头部的 `{$UNITPATH ../classes|../sysutils|../process}`
  对 nextPas 编译无效——`uses Classes/SysUtils` 一律解析到 `units/<target>/` 全局路径的
  stub。B 份自研版永远不会被 nextPas 编译链选中。**唯一源归属无需取舍，现实已是
  stub 胜出，缺的只是删除/归档 B 份的动作。**
- `#include` 例外：`np_text_primitives.pas` 是 FPC 宿主编译（core 测试）与 nextPas
  编译（编译链）双路径源，改动它必须两条路径都验证。

## 4. 批次规划（每批一口，探针数字写进 commit）

### P1：TryReadCoreTextFile 去 Classes 化（最高价值，先做）

- 改动：`rtl/core/text/np_text_primitives.pas` 的 `TryReadCoreTextFile` 改用
  `nextpas.core.fs.util.FsReadFileText`，外层保留现有 TCoreResult 错误码契约
  （空路径→`crcInvalidArgument`；文件缺失→`crcNotFound`；IO 失败→`crcIoError`，
  catch 异常映射）。`uses Classes, SysUtils` 收缩为 `uses nextpas.core.fs...`。
- 语义对齐点：FsReadFileText 有 BOM/编码处理且不抛非 UTF-8（Latin-1 降级），现实现
  是裸字节转 string。**行为差异要显式记录进 commit**，编译器读源码的正确性不变（
  源码文件本就 UTF-8，BOM 处理是净改进）。
- 验证：
  1. 探针 `--analyze-only`（rebuild 后 `/bin/cp -f` 到 probe，见 ROADMAP note 6）；
     `.ll` 中 `@TStream.*`/`@TFileStream.*` define 预计全部消失，undefined uniq/total 不升。
  2. `make test TEST_FILTER=compiler-pass` 58/58。
  3. core 侧 host-fpc 编译路径 `make -C rtl/core/text` 对应门（若存在）green。
  4. `make hygiene`。
- 风险：TryReadCoreTextFile 是编译器源码读取心脏，改动后编译器编译自己必须自洽
  （自举咬合）。失败即回滚，探针数字升=停。

### P2：RunTest 去 Process 化

- 改动：`tools/stage0/nextpas_command_test.pas` 的 RunTest 中 TProcess 用法迁到
  `nextpas.core.process`（toolchain_runner 已有同款先例可抄）。
- 验证：TProcess 符号从 .ll 消失；compiler-pass；探针不升。
- 风险：低——先例已存在，语义对齐点只有 TProcess.FCurrentDirectory 属性读写。

### P3：SysUtils 消费梳理（逐 consumer 决定去留）

- 消费者：`rtl/core/text/np_text_primitives.pas`、`core/src/nextpas.core.exception.pas`、
  `nextpas.core.thread.base.pas`、`nextpas.core.net.async.udp.pas`、
  `nextpas.core.system.sysutils.pas`、`nextpas.core.numa.pas`。
- 逐个审计用到的符号（Exception？TBytes？Format？），能换 nextpas.core 等价物的换，
  换不动的（多为 `on Exception do` 兼容 catch 语义）显式记录原因。
- ⚠️ **深水区**：stub `Exception` 是「无依赖自包含」类型；`nextpas.core.exception`
  有自己的 Exception 体系。catch 匹配语义、编译器 ivcall 编码都依赖类型身份，这口
  必须在 system 模块线 S5 集成准备里协同，不单干。
- 验证：每 consumer 迁移后 single-module gate + 探针不升。

### P4：物理归并双实现（决策 B 份去留）

- S4 官方立场（compatibility-matrix.md）：Classes 只认「极窄兼容子集，不做容器
  所有权」；Risk 1 警告不要冻结 bootstrap shortcut 为永久 public API。
- 动作：`rtl/core/classes/np_classes.pas`、`rtl/core/sysutils/np_sysutils.pas`、
  `rtl/core/process/np_process.pas` 三份 B 实现：内容已基本被子集化的 stub 覆盖 →
  移入 `rtl/core/classes/_retired/` 等归档目录（不 git rm，保留 git 历史与审计痕迹），
  在各自 README 标注「编译链唯一源 = units/<target>/<name>.pas」。
- 若归档后发现 core 测试仍 host-fpc 编译它们，则先修测试指向 stub path 再归档。
- 验证：core 全量测试 gate + hygiene。

### P5：stub 面冻结与文档修正

- `units/<target>/` 死面（40+ 未进链 stub）标注 `not-in-compile-graph` 或移
  `_frozen/`；不删除。
- 修正过时文档：`core/docs/system/compatibility-facades.md` 的 consumer 名单
  （toolchain 已迁移）；记录 `.system.classes` 门面的 THandleStream/TMemoryStream
  缺口（stub 无此类型）为已知定时炸弹，决定门面去留（建议：门面删掉两个不存在类型
  的 re-export，或 stub 补最小定义——交给 system 模块线 S5 决策）。
- 更新 `docs/plans/m2/ROADMAP.md` 战况表。

## 5. 不做的事（防屎山边界）

- 不实现 `nextpas.core.system.classes` 活门面（CLAUDE.md：已推迟）。
- 不把 core 变成 FPC 杂货箱第二份：每个迁移只对准「编译链真实消费的符号」。
- 不顺手重构无关模块；每批只动一个消费者。
- 不删除其他 AI 可能依赖的 stub 文件本身（保留为冻结标记），除非总控授权。

## 6. 汇报口径

每批结束按 ROADMAP 会话协议：探针数字 → 战况更新 → compiler-pass 回归 → 小步提交
（数字与批号写进 commit message）。P1 是可独立开口的第一桶。