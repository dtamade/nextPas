# Mem Test Platform API Swap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `SysUtils`, `Classes`, and `TThread` dependencies in five `nextpas.core.mem` test projects with `nextpas.core` platform abstractions while preserving all existing test behavior and assertions.

**Architecture:** Keep the refactor strictly inside the five requested `.lpr` files. `test_mem_secure` swaps file-existence checks to `nextpas.core.platform.mmap`, and the four threaded tests replace each `TThread` subclass with a data record plus a `TPlatformThreadProc` entry function using `TPlatformThreadRecord` lifecycle helpers.

**Tech Stack:** FreePascal `.lpr` tests, `nextpas.core.platform.mmap`, `nextpas.core.platform.thread`, per-test `Makefile` focused gates.

---

### Task 1: Convert `test_mem_secure` path checks

**Files:**
- Modify: `core/tests/nextpas.core.mem/test_mem_secure/test_mem_secure.lpr`
- Test: `core/tests/nextpas.core.mem/test_mem_secure/Makefile`

- [ ] **Step 1: Replace `FileExists` with `FileExistsByStat` and add the required unit**
- [ ] **Step 2: Run `make -C core/tests/nextpas.core.mem/test_mem_secure clean test`**

### Task 2: Convert `test_default_allocator` worker threads

**Files:**
- Modify: `core/tests/nextpas.core.mem/test_default_allocator/test_default_allocator.lpr`
- Test: `core/tests/nextpas.core.mem/test_default_allocator/Makefile`

- [ ] **Step 1: Remove `Classes`/`SysUtils`, add `nextpas.core.platform.thread`, and replace `TDefaultAllocatorThread` with a worker-data record plus thread proc**
- [ ] **Step 2: Preserve the concurrent-start assertions by collecting allocator identity and failure state from the worker records**
- [ ] **Step 3: Run `make -C core/tests/nextpas.core.mem/test_default_allocator clean test`**

### Task 3: Convert `test_sharded_pools` worker threads

**Files:**
- Modify: `core/tests/nextpas.core.mem/test_sharded_pools/test_sharded_pools.lpr`
- Test: `core/tests/nextpas.core.mem/test_sharded_pools/Makefile`

- [ ] **Step 1: Remove `Classes`/`SysUtils` and replace all five `TThread` subclasses with worker-data records plus `TPlatformThreadProc` entry points**
- [ ] **Step 2: Preserve per-worker state (`Ptr`, `Shard`, duplicate-release diagnostics, failure text) so the existing assertions remain unchanged**
- [ ] **Step 3: Run `make -C core/tests/nextpas.core.mem/test_sharded_pools clean test`**

### Task 4: Convert `test_thread_arena` worker threads

**Files:**
- Modify: `core/tests/nextpas.core.mem/test_thread_arena/test_thread_arena.lpr`
- Test: `core/tests/nextpas.core.mem/test_thread_arena/Makefile`

- [ ] **Step 1: Remove `Classes`, add `nextpas.core.platform.thread`, and replace `TThreadArenaWorker` with a worker-data record plus thread proc**
- [ ] **Step 2: Preserve logging/failure aggregation, start-barrier behavior, and all arena assertions**
- [ ] **Step 3: Run `make -C core/tests/nextpas.core.mem/test_thread_arena clean test`**

### Task 5: Convert `test_concurrent_wrappers` worker threads

**Files:**
- Modify: `core/tests/nextpas.core.mem/test_concurrent_wrappers/test_concurrent_wrappers.lpr`
- Test: `core/tests/nextpas.core.mem/test_concurrent_wrappers/Makefile`

- [ ] **Step 1: Remove `Classes`, add `nextpas.core.platform.thread`, and replace all thread subclasses with worker-data records plus thread procs**
- [ ] **Step 2: Replace every `Sleep(0)` with `platform_thread_yield` and keep the one delayed-start pause behavior using platform-thread sleep or equivalent existing platform API**
- [ ] **Step 3: Run `make -C core/tests/nextpas.core.mem/test_concurrent_wrappers clean test`**

### Task 6: Final verification and diff review

**Files:**
- Verify: `core/tests/nextpas.core.mem/test_mem_secure/test_mem_secure.lpr`
- Verify: `core/tests/nextpas.core.mem/test_default_allocator/test_default_allocator.lpr`
- Verify: `core/tests/nextpas.core.mem/test_sharded_pools/test_sharded_pools.lpr`
- Verify: `core/tests/nextpas.core.mem/test_thread_arena/test_thread_arena.lpr`
- Verify: `core/tests/nextpas.core.mem/test_concurrent_wrappers/test_concurrent_wrappers.lpr`

- [ ] **Step 1: Run `git diff --check -- <five target files>`**
- [ ] **Step 2: Inspect `git diff -- <five target files>` to confirm the refactor stayed path-limited and preserved the requested behavior surface**
