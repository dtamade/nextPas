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
