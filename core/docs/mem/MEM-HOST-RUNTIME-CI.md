# mem 真机 host-runtime CI 证据（G5.x）

**日期**: 2026-07-20
**状态**: 已挂入 core-ci Darwin / Windows matrix
**truth**:
- macOS: `macos-focused-runtime` 子集含 `mem.host_runtime`
- Windows: `ci-matrix` 子集含 `mem.host_runtime`（**真 Win64**，非 Wine）

---

## 1. 跑什么

| Gate | 路径 | make target |
|------|------|-------------|
| mem.host_runtime | `core/tests/nextpas.core.mem/test_mem_cross_os_compile_gate` | **`host-runtime`** |

覆盖：DefaultHeap / DefaultAllocator / GetMem+FreeMem(size) / TryBlockSize / Arena 工厂 / GetMemStats。

**不**在 matrix 里跑完整 `lane-focused`（过重）。

---

## 2. 入口脚本

```bash
# 从 repo root 或 core/
bash core/scripts/platform-macos-ci-matrix.sh
bash core/scripts/platform-windows-ci-matrix.sh
```

core-ci 工作流：
- `test-macos` → `platform-macos-ci-matrix.sh`（fail-closed）
- `test-windows-runtime` → `platform-windows-ci-matrix.sh`（fail-closed）

条目格式：`name relative_dir [make_target]`；缺省 target=`test`。
mem 使用第三字段 `host-runtime`，避免在 Darwin 上强制 FORCE_HOST Windows/FreeBSD 交叉编译。

---

## 3. 源契约

`test_mem_cross_os_compile_gate.lpr` 允许：

`NEXTPAS_WINDOWS | FREEBSD | LINUX | MACOS`

Linux 上完整 `make test` 仍跑 FORCE_HOST 编译门 + host-runtime。

---

## 4. 本地（Linux）自检

```bash
make -C core/tests/nextpas.core.mem/test_mem_cross_os_compile_gate clean test
make -C core/tests/nextpas.core.mem/test_mem_cross_os_compile_gate host-runtime
bash -n core/scripts/platform-macos-ci-matrix.sh
bash -n core/scripts/platform-windows-ci-matrix.sh
```

真机绿以 GHA 日志为准。

---

## 5. 证据快照（GHA · 2026-07-20）

### 5.1 首次挂载（run **29719186114**）

| Job | mem.host_runtime | 备注 |
|-----|------------------|------|
| **test-windows-runtime** | **PASS** | 整 job 绿 |
| **test-macos** | **PASS** | 整 job 曾红于 platform.watch（非 mem） |

### 5.2 平台 watch 修复后（run **29719632518**）

| Job | mem.host_runtime | platform matrix | 备注 |
|-----|------------------|-----------------|------|
| **test-windows-runtime** | **PASS** | **21/21** | 含 mem；整 job 绿 |
| **test-macos** | **PASS** | **10/10** | 含 mem；整 job 红于 **async dial/resolve**（非 mem） |
| test-linux | n/a | 全量 suite | 他模块失败，与 host-runtime 无关 |

结论：**G5.x 真机证据稳固**（Darwin + Windows 连续 PASS）。
macOS job 残余红点在 async，不阻塞 mem Steady。

### 5.3 近次抽样（run **29726581794** · 2026-07-20）

| Job | mem.host_runtime | 备注 |
|-----|------------------|------|
| **test-macos** | **PASS** | platform matrix 10/10；job 红于 kqueue smoke |
| **test-windows-runtime** | **PASS** | matrix 22 pass / 1 fail（非 mem 门） |

### 5.4 近次抽样（run **29727241825** · 2026-07-20）

| Job | mem.host_runtime | 备注 |
|-----|------------------|------|
| **test-macos** | **PASS** | platform matrix 10/10；job 红于 kqueue |
| **test-windows-runtime** | **PASS** | matrix **23/23 全绿** |

### 5.5 H2 FreeMemOf close 后（run **29729148831** · 2026-07-20 · `d080a4b8a`）

| Job | mem.host_runtime | 备注 |
|-----|------------------|------|
| **test-macos** | **PASS** | platform matrix **10/10**（含 mem）；job 红于 **async.kqueue**（`accept4` 未定义，非 mem） |
| **test-windows-runtime** | **PASS** | matrix **24/24 全绿**（含 mem） |
| test-linux | n/a | 红于 **ARCH-SOURCE-CONTRACT**（`docs/platform/master-spec.md` 超 120 行）；非 mem |
| test-freebsd | n/a | job **success** |

结论：H2 land 后 Darwin/Windows 真机 host-runtime 仍稳；整 job 红点仍属 async/platform 治理，不阻塞 mem Maintenance。
