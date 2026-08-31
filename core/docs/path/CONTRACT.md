# nextpas.core.path 代码契约

**模块路径**：`core/src/nextpas.core.path.pas`（1 个源文件）
**层级**：L2（依赖 L0-L1: platform.path; 委托 fs.path）
**Owner**：Claude（AI 负责）
**最后更新**：2026-08-31
**版本**：2.10

---

## 1. 接口契约

### 1.1 模块定位

SysUtils 路径函数的替代品。委托给 `nextpas.core.fs.path`（后者调用 platform_path_*）。
适用于只需路径操作、不需要完整 fs 模块的场景。

### 1.2 核心函数

| 函数 | 说明 | SysUtils 等价 |
|------|------|---------------|
| `PathJoin(ABase, AChild): string` | 连接两段路径 | — |
| `PathJoin3(A, B, C): string` | 连接三段路径 | — |
| `PathDir(APath): string` | 目录部分 | ExtractFilePath |
| `PathBase(APath): string` | 文件名（含扩展名） | ExtractFileName |
| `PathSplit(APath, ADir, ABase)` | 分离目录和文件名 | — |
| `PathExt(APath): string` | 扩展名（含点） | ExtractFileExt |
| `PathChangeExt(APath, AExt): string` | 更改扩展名 | ChangeFileExt |
| `PathIsAbsolute(APath): Boolean` | 是否绝对路径 | — |
| `PathNormalize(APath): string` | 规范化（消除 `.`/`..`） | — |
| `PathRelative(ABase, ATarget): string` | 计算相对路径 | — |
| `PathHasExt(APath): Boolean` | 是否有扩展名 | — |
| `PathWithoutExt(APath): string` | 去除扩展名 | — |
| `ExtractFilePath(AFileName): string` | 目录部分（末尾含分隔符） | ✓ |
| `ExtractFileName(AFileName): string` | 文件名 | ✓ |
| `ExtractFileExt(AFileName): string` | 扩展名 | ✓ |
| `ChangeFileExt(AFileName, AExt): string` | 更改扩展名 | ✓ |

---

## 2. 不变量

- **[INV-1]** 同时处理 `/` 和 `\` 分隔符
- **[INV-2]** UTF-8 字符串安全
- **[INV-3]** 空路径返回空字符串
- **[INV-4]** 本单元与 path 测试不 `uses` 裸 FPC RTL；「SysUtils 兼容」仅指 API 形状，实现委托 `fs.path` / `platform.path`。门禁：`test_path` 真 uses 扫描。
- **[INV-5]** **PathDir 语义**：门面仅对**无路径分隔符**的裸文件名把 `'.'`→`''`（SysUtils）；`./x` 保留 `'.'`。底层 `FsPathDir` 始终 Go 语义。`PathIsAbs` ≡ `PathIsAbsolute`。
- **[INV-6]** `ExpandFileName` 委托 `FsPathAbs`，依赖 cwd。
- **[INV-7]** R16：`PathToSlash`/`PathFromSlash`/`PathSplitList`/`PathVolume`/`PathFileStem`/`PathStripPrefix` 对齐 Go filepath / Rust Path 常用子集。

---

## 3. 错误处理

不抛异常。所有函数对空/无效输入返回空字符串或原样。

---

## 4. 线程安全

✅ 纯函数，线程安全。

---

## 5. 内存管理

返回新 string，调用方负责释放。无全局缓存。

---

## 6. 测试覆盖

**最后校准：2026-07-19**（以 `make -C core/tests/nextpas.core.path/test_path test` 输出为准）。

| 测试文件 | 参考通过数 | 说明 |
|----------|-----------|------|
| test_path | **70** | R31 边界表 |
| test_path_wine | **4** | wine 最小生产集 |
| **合计** | **2 个测试目录** | heaptrc 0 leak |

---

## Windows / Unix 支持矩阵（M2-W4）

完整一眼表：[`../process/WIN.md`](../process/WIN.md)。

| 能力 | Linux/Unix | Windows | 备注 |
|------|------------|---------|------|
| Join / Clean / Rel / Match | Done | Done | 分隔符 `/` 与 `\` |
| IsAbsolute / Volume | Done | Done（盘符） | wine：IsAbs-Volume |
| ToSlash / FromSlash | Done | Done | 可移植归一 |
| StripPrefix / FileStem | Done | Done | wine：StripPrefix |

**原则**：纯字符串层无 stub；语义差异写在 INV-5/7。

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | Claude |
| 2026-07-11 | 2.0 | 更新为实际 API 和测试数据 | Claude |
| 2026-07-19 | 2.1 | 测试数口径校准 + 命名规范见 README | Claude |
| 2026-07-19 | 2.2 | INV-4 FPC RTL 隔离 / 编译器无关 | Claude |
| 2026-07-19 | 2.3 | 真 uses 门禁（test_path） | Claude |
| 2026-07-19 | 2.4 | PathDir 双轨钉死；PathIsAbs；ExpandFileName cwd | Claude |
| 2026-07-19 | 2.5 | PathDir 仅裸名压空；`./x` 保留 `.` | Claude |
| 2026-07-19 | 2.6 | R16 ToSlash/SplitList/Volume/Stem/StripPrefix | Claude |
| 2026-07-19 | 2.7 | R17 质量表；测试 56 | Claude |
| 2026-07-20 | 2.8 | R22 Clean/Rel/Dir 边界用例；测试 69 | Claude |
| 2026-07-20 | 2.9 | R31 边界表 70；M2-W4 Win 矩阵 + wine 4 | Claude |
| 2026-07-21 | 2.10 | U4 mix-use audit script + MIXUSE-AUDIT；C6 锚点门禁 | Claude |
| 2026-08-31 | 2.10 | 时效刷新：批量校正至 2026-08-31，统一 AL1 口径 | core-docs |
