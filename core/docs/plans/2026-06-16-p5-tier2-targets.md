# P5 Tier 2 Targets Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Establish cross-compile and runtime smoke evidence for Tier 2 targets: Windows aarch64, Linux riscv64, Linux arm32.

**Architecture:** Extend the existing Wine CI matrix pattern to additional cross-compile targets. Each target requires:
1. Cross-compile gate (forced-compile evidence)
2. Runtime smoke test (if host available)
3. Source-contract test (contract verification)

**Tech Stack:** FPC cross-compile (`-Twin64`, `-Twin32`, `-Priscv64`, `-Paarch64`, `-Parm`), Wine for Windows smoke, QEMU for Linux smoke.

---

## Phase 1: Windows aarch64 Cross-Compile Gate

### Task 1: Create Windows aarch64 compile test directory

**Files:**
- Create: `core/tests/nextpas.core.platform.test_platform_windows_aarch64_compile/`

**Step 1: Create Makefile**

```bash
mkdir -p core/tests/nextpas.core.platform.test_platform_windows_aarch64_compile
```

Create `Makefile`:
```makefile
FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.platform.test_platform_windows_aarch64_compile
PROGRAM := test_platform_windows_aarch64_compile
SOURCE := $(PROGRAM).lpr
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -Twin64 -Paarch64
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: build test clean
build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

test: build
	@echo "truth=forced-compile: aarch64"

clean:
	rm -rf $(BUILD_DIR)
```

**Step 2: Create minimal test source**

Create `test_platform_windows_aarch64_compile.lpr`:
```pascal
program test_platform_windows_aarch64_compile;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.time,
  nextpas.core.platform.memory,
  nextpas.core.platform.sync,
  nextpas.core.platform.thread,
  nextpas.core.platform.io,
  nextpas.core.platform.process,
  nextpas.core.platform.files,
  nextpas.core.platform.fs,
  nextpas.core.platform.path,
  nextpas.core.platform.env,
  nextpas.core.platform.mmap,
  nextpas.core.platform.random,
  nextpas.core.platform.socket,
  nextpas.core.io.reactor.iocp;

begin
  { Smoke test: all 14 modules compile for Windows aarch64 }
end.
```

**Step 3: Build and verify**

```bash
make -C core/tests/nextpas.core.platform.test_platform_windows_aarch64_compile build
```
Expected: Successful compilation

**Step 4: Commit**

```bash
git add core/tests/nextpas.core.platform.test_platform_windows_aarch64_compile/
git commit -m "feat(platform): add Windows aarch64 compile gate for 14 modules"
```

---

### Task 2: Create Windows aarch64 runtime smoke test

**Files:**
- Create: `core/tests/nextpas.core.platform.test_platform_windows_aarch64_wine/`

**Step 1: Create test directory with Wine aarch64 support**

Note: Wine does not natively support aarch64 Windows binaries. This task establishes the compile gate only. Create a placeholder test that documents this limitation.

Create `Makefile`:
```makefile
FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.platform.test_platform_windows_aarch64_wine
PROGRAM := test_platform_windows_aarch64_wine
SOURCE := $(PROGRAM).lpr
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -Twin64 -Paarch64
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: build run test clean
build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	@echo "SKIP: Wine does not support Windows aarch64 binaries"
	@exit 0

test: run

clean:
	rm -rf $(BUILD_DIR)
```

Create `test_platform_windows_aarch64_wine.lpr`:
```pascal
program test_platform_windows_aarch64_wine;

{$I nextpas.core.settings.inc}

uses SysUtils;

begin
  { Windows aarch64 runtime smoke requires real aarch64 Windows hardware.
    Wine does not support Windows aarch64. This test documents the gap. }
end.
```

**Step 2: Commit**

```bash
git add core/tests/nextpas.core.platform.test_platform_windows_aarch64_wine/
git commit -m "feat(platform): add Windows aarch64 wine test placeholder (Wine gap documented)"
```

---

## Phase 2: Linux riscv64 Cross-Compile + Runtime Smoke

### Task 3: Create Linux riscv64 compile test

**Files:**
- Create: `core/tests/nextpas.core.platform.test_platform_linux_riscv64_compile/`

**Step 1: Create Makefile and source**

```makefile
FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.platform.test_platform_linux_riscv64_compile
PROGRAM := test_platform_linux_riscv64_compile
SOURCE := $(PROGRAM).lpr
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -Priscv64
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: build test clean
build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

test: build
	@echo "truth=forced-compile: riscv64"

clean:
	rm -rf $(BUILD_DIR)
```

```pascal
program test_platform_linux_riscv64_compile;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.time,
  nextpas.core.platform.memory,
  nextpas.core.platform.sync,
  nextpas.core.platform.thread,
  nextpas.core.platform.io,
  nextpas.core.platform.process,
  nextpas.core.platform.files,
  nextpas.core.platform.fs,
  nextpas.core.platform.path,
  nextpas.core.platform.env,
  nextpas.core.platform.mmap,
  nextpas.core.platform.random,
  nextpas.core.platform.socket;

begin
  { Smoke test: all 13 platform modules compile for Linux riscv64 }
end.
```

**Step 2: Build and verify**

```bash
make -C core/tests/nextpas.core.platform.test_platform_linux_riscv64_compile build
```

**Step 3: Commit**

```bash
git add core/tests/nextpas.core.platform.test_platform_linux_riscv64_compile/
git commit -m "feat(platform): add Linux riscv64 compile gate for 13 modules"
```

---

### Task 4: Create Linux riscv64 runtime smoke test (QEMU)

**Files:**
- Create: `core/tests/nextpas.core.platform.test_platform_linux_riscv64_smoke/`

**Step 1: Create test with QEMU execution**

```makefile
FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.platform.test_platform_linux_riscv64_smoke
PROGRAM := test_platform_linux_riscv64_smoke
SOURCE := $(PROGRAM).lpr
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -Priscv64
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: build run test clean
build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	@if command -v qemu-riscv64 >/dev/null 2>&1; then \
		qemu-riscv64 $(BUILD_DIR)/$(PROGRAM); \
	else \
		echo "SKIP: qemu-riscv64 not available"; \
		exit 0; \
	fi

test: run

clean:
	rm -rf $(BUILD_DIR)
```

```pascal
program test_platform_linux_riscv64_smoke;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.platform.time,
  nextpas.core.platform.memory,
  nextpas.core.platform.sync;

var
  T: TTestRunner;

begin
  T := TTestRunner.Create('nextpas.core.platform.linux_riscv64_smoke');
  T.Run('platform.time smoke', @TestTimeSmoke);
  T.Run('platform.memory smoke', @TestMemorySmoke);
  T.Run('platform.sync smoke', @TestSyncSmoke);
  T.Summary;
end.
```

Note: Implement minimal smoke tests for time, memory, sync modules.

**Step 2: Commit**

```bash
git add core/tests/nextpas.core.platform.test_platform_linux_riscv64_smoke/
git commit -m "feat(platform): add Linux riscv64 runtime smoke test (QEMU)"
```

---

## Phase 3: Linux arm32 Cross-Compile + Runtime Smoke

### Task 5: Create Linux arm32 compile test

**Files:**
- Create: `core/tests/nextpas.core.platform.test_platform_linux_arm32_compile/`

**Step 1: Create Makefile and source**

```makefile
FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.platform.test_platform_linux_arm32_compile
PROGRAM := test_platform_linux_arm32_compile
SOURCE := $(PROGRAM).lpr
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -Parm32
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: build test clean
build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

test: build
	@echo "truth=forced-compile: arm32"

clean:
	rm -rf $(BUILD_DIR)
```

```pascal
program test_platform_linux_arm32_compile;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.time,
  nextpas.core.platform.memory,
  nextpas.core.platform.sync,
  nextpas.core.platform.thread,
  nextpas.core.platform.io,
  nextpas.core.platform.process,
  nextpas.core.platform.files,
  nextpas.core.platform.fs,
  nextpas.core.platform.path,
  nextpas.core.platform.env,
  nextpas.core.platform.mmap,
  nextpas.core.platform.random,
  nextpas.core.platform.socket;

begin
  { Smoke test: all 13 platform modules compile for Linux arm32 }
end.
```

**Step 2: Build and verify**

```bash
make -C core/tests/nextpas.core.platform.test_platform_linux_arm32_compile build
```

**Step 3: Commit**

```bash
git add core/tests/nextpas.core.platform.test_platform_linux_arm32_compile/
git commit -m "feat(platform): add Linux arm32 compile gate for 13 modules"
```

---

### Task 6: Create Linux arm32 runtime smoke test (QEMU)

**Files:**
- Create: `core/tests/nextpas.core.platform.test_platform_linux_arm32_smoke/`

**Step 1: Create test with QEMU execution**

```makefile
FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.platform.test_platform_linux_arm32_smoke
PROGRAM := test_platform_linux_arm32_smoke
SOURCE := $(PROGRAM).lpr
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -Parm32
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: build run test clean
build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	@if command -v qemu-arm >/dev/null 2>&1; then \
		qemu-arm $(BUILD_DIR)/$(PROGRAM); \
	else \
		echo "SKIP: qemu-arm not available"; \
		exit 0; \
	fi

test: run

clean:
	rm -rf $(BUILD_DIR)
```

```pascal
program test_platform_linux_arm32_smoke;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.platform.time,
  nextpas.core.platform.memory,
  nextpas.core.platform.sync;

var
  T: TTestRunner;

begin
  T := TTestRunner.Create('nextpas.core.platform.linux_arm32_smoke');
  T.Run('platform.time smoke', @TestTimeSmoke);
  T.Run('platform.memory smoke', @TestMemorySmoke);
  T.Run('platform.sync smoke', @TestSyncSmoke);
  T.Summary;
end.
```

**Step 2: Commit**

```bash
git add core/tests/nextpas.core.platform.test_platform_linux_arm32_smoke/
git commit -m "feat(platform): add Linux arm32 runtime smoke test (QEMU)"
```

---

## Phase 4: Update Documentation

### Task 7: Update goal-tree.md with P5 status

**Files:**
- Modify: `core/docs/platform/goal-tree.md`

**Step 1: Update P5 milestone row**

Change:
```
| P5 Tier 2 targets | Windows aarch64, Linux riscv64/arm32, FreeBSD/Android | source/compile fragments | cross-compile and runtime matrix |
```

To show completed entries with evidence tier.

**Step 2: Commit**

```bash
git add core/docs/platform/goal-tree.md
git commit -m "docs(platform): update P5 completion status"
```

---

### Task 8: Update runtime-truth-matrix.md

**Files:**
- Modify: `core/docs/platform/runtime-truth-matrix.md`

**Step 1: Add Tier 2 entries**

Add new rows for Windows aarch64, Linux riscv64, Linux arm32 with appropriate evidence tiers.

**Step 2: Commit**

```bash
git add core/docs/platform/runtime-truth-matrix.md
git commit -m "docs(platform): update runtime-truth-matrix with Tier 2 targets"
```

---

## Summary

| Phase | Tasks | Deliverable |
|-------|-------|-------------|
| P5-1 | Task 1-2 | Windows aarch64 compile gate + Wine gap documentation |
| P5-2 | Task 3-4 | Linux riscv64 compile gate + QEMU smoke |
| P5-3 | Task 5-6 | Linux arm32 compile gate + QEMU smoke |
| P5-4 | Task 7-8 | Documentation updates |

**Evidence Tiers Achieved:**
- Windows aarch64: `forced-compile`
- Linux riscv64: `forced-compile` + `ci-runtime-matrix` (QEMU available)
- Linux arm32: `forced-compile` + `ci-runtime-matrix` (QEMU available)
