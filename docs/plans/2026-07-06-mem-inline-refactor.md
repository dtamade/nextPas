# mem 模块内联重构实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 消除 TAllocator 虚方法基类，所有 59 个 allocator 改为 `TInterfacedObject + IAllocator + inline`，热路径零开销。

**Architecture:** 每个 allocator 直接实现 IAllocator 接口，方法标记 inline。共享逻辑（DEBUG poison/double-free/null check）提取为工具函数。中间件通过 `FInner: IAllocator` 委托内层。调用方可选择具体类型（内联展开）或接口（多态）。

**Tech Stack:** Free Pascal 3.3.1+, `{$mode objfpc}{$H+}`, nextpas.core.mem 子系统

---

## 关键约束

- `{$I nextpas.core.settings.inc}` 包含 `{$mode objfpc}{$H+}`，不要再加
- 测试用 `nextpas.core.test` 框架：`T.Test('name', @Proc)` / `Check(condition, msg)` / `CheckEqual`
- 测试文件扩展名 `.lpr`，Makefile 用 `PROGRAM := xxx` + `include ../../common.mk`
- 已有 2 个 allocator 不继承 TAllocator：`TPoolAllocator`(pool.allocator.pas)、`TFallbackAllocator`(fallback.pas)
- 55 个 allocator 继承 TAllocator，需迁移

## 每个 allocator 的迁移模式

**之前（虚方法）：**
```pascal
TMyAllocator = class(TAllocator)
protected
  function DoGetMem(ASize: SizeUInt): Pointer; override;
  procedure DoFreeMem(APtr: Pointer); override;
public
  function Traits: TAllocatorTraits; override;
end;

function TMyAllocator.DoGetMem(ASize: SizeUInt): Pointer;
begin
  Result := ...;
end;
```

**之后（内联）：**
```pascal
TMyAllocator = class(TInterfacedObject, IAllocator)
public
  function GetMem(ASize: SizeUInt): Pointer; inline;
  function AllocMem(ASize: SizeUInt): Pointer; inline;
  function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
  procedure FreeMem(APtr: Pointer); inline;
  function Traits: TAllocatorTraits; inline;
end;

function TMyAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
begin
  {$IFDEF DEBUG}
  if ASize = 0 then Exit(nil);
  {$ENDIF}
  Result := ...;  // 具体分配逻辑
  {$IFDEF DEBUG}
  if Result <> nil then
    DebugPoisonAlloc(Result, ASize);
  {$ENDIF}
end;
```

---

## Phase 0: 基础设施准备

### Task 0.1: 创建 worktree

**Step 1: 创建分支和 worktree**

```bash
cd /home/dtamade/projects/nextPas
scripts/worktree-add.sh mem-inline main
cd .worktrees/mem-inline
```

**Step 2: 验证初始状态**

```bash
make -C core/tests/nextpas.core.mem test 2>&1 | tail -5
```

Expected: 测试通过

**Step 3: Commit**

```bash
git commit --allow-empty -m "chore: mem-inline worktree 初始化"
```

### Task 0.2: 提取共享工具函数

**Files:**
- Modify: `core/src/nextpas.core.mem.utils.pas`

**Step 1: 在 mem.utils 中添加 DEBUG 工具函数**

在 `implementation` 部分添加：

```pascal
const
  MEM_POISON_ALLOC = $AB;
  MEM_POISON_FREED = $DE;
  FREED_PTR_RING_SIZE = 256;

var
  GFreedRing: array[0..FREED_PTR_RING_SIZE - 1] of Pointer;
  GFreedRingPos: Integer;

procedure DebugPoisonAlloc(APtr: Pointer; ASize: SizeUInt);
begin
  FillChar(APtr^, ASize, MEM_POISON_ALLOC);
end;

procedure DebugPoisonFree(APtr: Pointer; ASize: SizeUInt);
begin
  FillChar(APtr^, ASize, MEM_POISON_FREED);
end;

procedure DebugRecordFree(APtr: Pointer);
begin
  GFreedRing[GFreedRingPos] := APtr;
  GFreedRingPos := (GFreedRingPos + 1) mod FREED_PTR_RING_SIZE;
end;

function DebugIsDoubleFree(APtr: Pointer): Boolean;
var
  I: Integer;
begin
  for I := 0 to FREED_PTR_RING_SIZE - 1 do
    if GFreedRing[I] = APtr then
      Exit(True);
  Result := False;
end;
```

在 `interface` 部分添加声明：

```pascal
procedure DebugPoisonAlloc(APtr: Pointer; ASize: SizeUInt);
procedure DebugPoisonFree(APtr: Pointer; ASize: SizeUInt);
procedure DebugRecordFree(APtr: Pointer);
function DebugIsDoubleFree(APtr: Pointer): Boolean;
```

**Step 2: 编译验证**

```bash
fpc -MObjFPC -Sh -O2 -Fi core/src core/src/nextpas.core.mem.utils.pas 2>&1 | tail -5
```

Expected: 编译通过

**Step 3: Commit**

```bash
git add core/src/nextpas.core.mem.utils.pas
git commit -m "refactor(mem): 提取 DEBUG 工具函数到 mem.utils"
```

### Task 0.3: 删除 TAllocator 基类

**Files:**
- Modify: `core/src/nextpas.core.mem.allocator.base.pas`

**Step 1: 清空 TAllocator 定义**

保留文件中的常量和类型定义，删除 `TAllocator` 类定义和实现。

将 `nextpas.core.mem.allocator.base.pas` 改为仅导出工具函数和类型：

```pascal
unit nextpas.core.mem.allocator.base;
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.mem.base,
  nextpas.core.mem.utils,
  nextpas.core.mem.intf;

type
  TAllocatorTraits = nextpas.core.mem.intf.TAllocatorTraits;
  IAllocator = nextpas.core.mem.intf.IAllocator;
  TMemAllocator = nextpas.core.mem.intf.IAllocator;

implementation
end.
```

**Step 2: 编译验证（预期大量错误）**

```bash
fpc -MObjFPC -Sh -O2 -Fi core/src -Fu core/src core/src/nextpas.core.mem.pas 2>&1 | grep "Error:" | head -10
```

Expected: 很多 "TAllocator not found" 错误。这是正常的，后续 task 逐个修复。

**Step 3: Commit**

```bash
git add core/src/nextpas.core.mem.allocator.base.pas
git commit -m "refactor(mem): 删除 TAllocator 基类（编译暂不通过）"
```

---

## Phase 1: P0 高频分配器迁移（5 个）

每个 allocator 的迁移步骤相同：

1. 改继承：`TAllocator` → `TInterfacedObject, IAllocator`
2. 改方法：`DoGetMem` override → `GetMem` inline
3. 改方法：`DoFreeMem` override → `FreeMem` inline
4. 改方法：`DoAllocMem` override → `AllocMem` inline（如有）
5. 改方法：`DoReallocMem` override → `ReallocMem` inline（如有）
6. Traits 保持 inline
7. 调用 `DebugPoisonAlloc`/`DebugRecordFree`（按需）
8. 编译 + 测试 + commit

### Task 1.1: TPoolAllocator（pool.allocator.pas）

**注意：已经是 `TInterfacedObject, IAllocator`，只需加 inline 标记。**

**Files:**
- Modify: `core/src/nextpas.core.mem.pool.allocator.pas`

**Step 1: 添加 inline 标记**

```bash
# 当前 GetMem/FreeMem/Traits 没有 inline
grep -n "function TPoolAllocator.GetMem\|procedure TPoolAllocator.FreeMem\|function TPoolAllocator.Traits" core/src/nextpas.core.mem.pool.allocator.pas
```

在声明处和实现处都加 `inline`：

```pascal
// 类声明中
function GetMem(ASize: SizeUInt): Pointer; inline;
procedure FreeMem(APtr: Pointer); inline;
function Traits: TAllocatorTraits; inline;

// 实现处
function TPoolAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
procedure TPoolAllocator.FreeMem(APtr: Pointer); inline;
function TPoolAllocator.Traits: TAllocatorTraits; inline;
```

**Step 2: 运行测试**

```bash
make -C core/tests/nextpas.core.mem/test_pool clean test 2>&1 | tail -5
```

Expected: PASS

**Step 3: Commit**

```bash
git add core/src/nextpas.core.mem.pool.allocator.pas
git commit -m "refactor(mem): TPoolAllocator 方法标记 inline"
```

### Task 1.2: TPool2Allocator（pool2.pas）

**Files:**
- Modify: `core/src/nextpas.core.mem.allocator.pool2.pas`

**Step 1: 改继承和方法**

```pascal
// 之前
TPool2Allocator = class(TAllocator)
protected
  function DoGetMem(ASize: SizeUInt): Pointer; override;
  procedure DoFreeMem(APtr: Pointer); override;
public
  function Traits: TAllocatorTraits; override;
end;

// 之后
TPool2Allocator = class(TInterfacedObject, IAllocator)
public
  function GetMem(ASize: SizeUInt): Pointer; inline;
  function AllocMem(ASize: SizeUInt): Pointer; inline;
  function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
  procedure FreeMem(APtr: Pointer); inline;
  function Traits: TAllocatorTraits; inline;
end;
```

**Step 2: 改实现**

将 `DoGetMem` 改为 `GetMem`，`DoFreeMem` 改为 `FreeMem`。添加 `AllocMem`/`ReallocMem` 默认实现。

**Step 3: 编译 + 测试 + commit**

### Task 1.3: TCoalesceAllocator（coalesce.pas）

同 Task 1.2 模式。

### Task 1.4: TBitmapAllocator（bitmap.pas）

同 Task 1.2 模式。

### Task 1.5: TGrowingAllocator（growing.pas）

**注意：growing.pas 已有 inline GetMem/FreeMem，但它们不是 IAllocator 的实现。需确认是否需要适配。**

检查当前 growing.pas 是否已有自己的 GetMem（非 override）：

```bash
grep -n "function.*GetMem.*inline" core/src/nextpas.core.mem.allocator.growing.pas
```

如果已有 inline GetMem 且不继承 TAllocator，则无需改动。

---

## Phase 2: P1 次高频分配器迁移（10 个）

按优先级排序，每个 allocator 同 Task 1.2 模式：

### Task 2.1: TBumpAllocator（bump.pas）
### Task 2.2: TStackAllocator（stack.pas）
### Task 2.3: TVirtualArenaAllocator（arena.pas）
### Task 2.4: TArena2Allocator（arena2.pas）
### Task 2.5: TFreelistAllocator（freelist.pas）
### Task 2.6: TSizeClassAllocator（size_class.pas）
### Task 2.7: TPageAllocator（page.pas）
### Task 2.8: TWatermarkAllocator（watermark.pas）
### Task 2.9: TSlidingAllocator（sliding.pas）
### Task 2.10: TSlabAllocator（slab.pas）

每个 task：
1. 改继承：`TAllocator` → `TInterfacedObject, IAllocator`
2. 改方法：`DoGetMem` → `GetMem` inline
3. 改方法：`DoFreeMem` → `FreeMem` inline
4. 添加 `AllocMem`/`ReallocMem` 默认实现（如无）
5. 编译 + 测试 + commit

---

## Phase 3: P2 中间件迁移（15 个）

中间件特点：有 `FInner: IAllocator` 字段，内部调 `FInner.GetMem`。

### Task 3.1: TGuardAllocator（guard.pas）

**Step 1: 改继承和方法**

```pascal
TGuardAllocator = class(TInterfacedObject, IAllocator)
private
  FInner: IAllocator;
public
  constructor Create(AInner: IAllocator);
  destructor Destroy; override;
  function GetMem(ASize: SizeUInt): Pointer; inline;
  function AllocMem(ASize: SizeUInt): Pointer; inline;
  function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
  procedure FreeMem(APtr: Pointer); inline;
  function Traits: TAllocatorTraits; inline;
end;
```

**Step 2: GetMem 实现**

```pascal
function TGuardAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
var
  LTotalSize: SizeUInt;
  LHdr: PGuardHeader;
begin
  LTotalSize := HeaderSize + ASize + GUARD_PAGE_SIZE;
  Result := FInner.GetMem(LTotalSize);  // 接口调用
  // ... guard page 设置逻辑
end;
```

**Step 3: 编译 + 测试 + commit**

### Task 3.2: TSentinelAllocator（sentinel.pas）
### Task 3.3: TTrackingAllocator（tracking.pas）
### Task 3.4: TAlignedAllocator（aligned.pas）
### Task 3.5: TBoundedAllocator（bounded.pas）
### Task 3.6: TPrefixAllocator（prefix.pas）
### Task 3.7: TLoggingAllocator（logging.pas）
### Task 3.8: TDebugAllocator（debug_alloc.pas）
### Task 3.9: TStatsAllocator（stats.pas）
### Task 3.10: TCompactAllocator（compact.pas）
### Task 3.11: TSamplingAllocator（sampling.pas）
### Task 3.12: TReplayAllocator（replay.pas）
### Task 3.13: TZeroedAllocator（zeroed.pas）
### Task 3.14: TCowAllocator（cow.pas）
### Task 3.15: TCountingAllocator（counting.pas）

---

## Phase 4: P3 其余分配器迁移（29 个）

低频/特殊分配器，同模式迁移：

### Task 4.1-4.29:

callback, cascade, dual, fail, mimalloc, mimalloc.loader, crt, hotswap,
mapped_file, prediction, group, mmap, rtl, profile, sized, pool_auto,
recycling, recycling_pool, recycling_group, scoped, huge_page, numa,
thread_safe, thread_cache, validation, pool_grow, leak_report, leak_check,
arena_group

---

## Phase 5: 验证与清理

### Task 5.1: 全量编译

```bash
make -C core/src clean
make -C core/tests/nextpas.core.mem clean test 2>&1 | tail -20
```

Expected: 所有测试通过

### Task 5.2: Benchmark 对比

```bash
# 对比 pool 分配性能（inline vs 虚方法）
make -C core/tests/nextpas.core.mem/test_pool test 2>&1 | grep -i "time\|perf\|ns/op"
```

### Task 5.3: 清理 TAllocator 残留引用

```bash
grep -rn "TAllocator" core/src/nextpas.core.mem.*.pas | grep -v "allocator.base.pas\|test_\|\.md"
```

Expected: 0 结果

### Task 5.4: 更新文档

- `core/docs/mem/ROADMAP.md` — 添加内联重构里程碑
- `core/docs/mem/README.md` — 更新架构说明

### Task 5.5: 最终 Commit

```bash
git add -A
git commit -m "refactor(mem): 内联架构重构完成 — 59 个 allocator 全部 TInterfacedObject + IAllocator + inline"
```

---

## 风险与回退

| 风险 | 缓解 |
|------|------|
| FPC 无法 inline 虚方法 | 已确认：不走虚方法，直接 inline 实现 |
| 接口引用计数管理 | TInterfacedObject 自动管理，与当前 TAllocator 相同 |
| 中间件链 inline 收益有限 | 省掉的是中间件自身的虚方法跳转，内层仍是接口调用 |
| 全量改动编译不过 | 分批推进，每批编译验证 |
| 测试覆盖不足 | 每批运行完整测试套件 |

## 成功标准

- [ ] 59 个 allocator 全部继承 `TInterfacedObject, IAllocator`
- [ ] 所有 GetMem/FreeMem/Traits 标记 `inline`
- [ ] TAllocator 基类已删除
- [ ] 全部测试通过
- [ ] `grep -rn "TAllocator" core/src/` 返回 0（除 base.pas 的类型别名）
