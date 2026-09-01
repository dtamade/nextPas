# ZIP 完美迭代 S60 — 六维收敛计划

> 基于 2026-09-01 六维并行审计（modularity 9.1 / performance 7.5 / elegance 8.9 / reuse 8.5 / stability 7.8 / completeness 8.0）与 P0 编译阻断现场修复的后续收敛。

## 审计基线
- Worktree: `.worktrees/zip` @ `e73722e9` + 2 处 P0 热修（`common.DosMaxUnixSec` inline 转发丢失、`compress.RawDeflateWriter` 别名缺失）
- 门：`test_zip 27` `reader 27` `sequential 22` `fs 7` `contract 6` 均 `HEAPTRC OK`，`hygiene pass`
- 结论：领头羊水位已达 1.0.0 Final，剩余为巡检债与微瑕，无结构性缺陷。

## P0 — 已落地（本迭代前置热修，需单独 commit）
| # | 文件 | 修复 | 验证 |
|---|------|------|------|
| P0-1 | `core/src/nextpas.core.zip.common.pas:81-85` | 补 `DosMaxUnixSec inline` 透传 `zip.base.DosMaxUnixSec`，解决 Forward declaration not solved | `make focused test_zip` 27/27 |
| P0-2 | `core/src/nextpas.core.compress.pas:62-67,195-213` | 恢复 `RawDeflateWriter/Reader/ReaderWithMaxOutputSize` 薄包装（inline 委托 `CreateRaw*`），修复 `zip.writer` 与 `test_compress` 编译 | `test_zip 27` + `test_compress` 编译 |

> 执行：单独 commit `fix(zip): P0 编译阻断还原`，不与其他改动混排。

## S60 — 文档一致性收敛（P1, 零风险）
**动机**：`SECURITY 5 模型` vs `ROADMAP/CHANGELOG 4 模型` 及 `CONTRACT §6` 覆盖不全，导致 truth drift。
- `core/docs/zip/SECURITY.md` 已 5 模型（新增 Symlink Traversal）
- `core/docs/zip/ROADMAP.md:S50 表` 与 `core/CHANGELOG.md:17` 仍称 4 模型
- `core/docs/zip/CONTRACT.md §6` 未提 `Symlink 非原子/MaxDescriptorBuffer 正交` 已知局限
- `core/docs/core-module-registry.md:110` `zip` 允许依赖未列 `crypto/hash`（实现已依赖 `pbkdf2/hmac/random`）

**改动**：
- `ROADMAP.md:25 S50 行 4→5`，`CHANGELOG` 同步
- `CONTRACT.md §6` 增 2 行已知局限说明（与 SECURITY 互引）
- `core-module-registry.md` `zip` 行 `Allowed` 增 `crypto/hash` 显式
- `README.md:292` 性能段拆为表 + 外链，降密度（elegance P1）

**验证**：`test_zip_contract:EnumerationConsistency` + `docs contract` 门，`grep -n "模型"` 三文档一致。

## S61 — 稳定性：未知方法错误分类归一（P1, 行为修正）
**动机**：`reader.pas:399-405` 与 `sequential.pas:370-377` 将未知 `MethodCode≠8/99` 映射 `zmStore`，后续才 `ENotSupportedError`，导致 parse 阶段错误消息降级为 `EIOError size/crc mismatch`，利于指纹混淆。
**改动**：
- `ParseCentralEntry` 中：若 `LMethod<>8` 且非 99/AES，则直接 `raise ENotSupportedError('zip: unsupported compression method...')` 而非映射，`Method/MedCode` 保持原值供诊断。
- `sequential.ParseCurrentLocal` 同步。
- 更新 `CONTRACT.md INV-5` 错误示例，增 `test_zip_reader:TestUnsupportedMethodIsNotStore` 用例（defer 至 S61 测试增量）。

**风险**：极小，语义更严格，现有 `DecompressEntryVerified` 抛 `ENotSupported` 路径不变，仅提前失败点。

## S62 — 复用/性能微抛光（P2, 可选本迭代或下期）
- `common.GuardRange` 抽取：合并 `reader.NeedRange*` + `sequential.ReadExact*` 的截断守卫
- `extra.WriteLE*` 重载收敛：`TBytes` 版委托 `PByte` 版
- `IsSafeZipEntryName` / `TBytesBuilder.Grow` 去 `inline`（防代码膨胀）

> 本迭代先以 S60+S61 为必做，S62 视 review 余量决定是否同批；S62 若入本批则与 S60/S61 分 commit，保持 path-limited replay 可回滚。

## 验证纪律
- 每 S 单独 focused 门 + `make hygiene` + `git diff --check`
- S60 后 `test_zip_contract` 必须绿；S61 后 `test_zip_reader 27` + `test_zip_sequential 22` + 新增用例
- 终态 `12门+bench regression` 全绿再提 Ready，不跑全量 `make verify`

## 合并策略
- Worktree: `.worktrees/zip`，分支 `zip`
- Commit 粒度：`fix(zip): P0 编译阻断还原` → `docs(zip): S60 一致性收敛` → `fix(zip): S61 未知方法归一`（各带 hygiene+门证据）
- 需总控 landing：`landing/zip-S60` path-limited replay 到 `main`，`zip` lane 随后 rebase
