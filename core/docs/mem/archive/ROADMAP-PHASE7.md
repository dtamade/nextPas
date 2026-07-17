# mem 模块演化 Phase 7

## 目标

高级分配器策略：固定大小池、内核风格 slab、栈式分配、合并空闲块。

## 项目清单

| ID | 名称 | 文件 | 测试 | 状态 |
|----|------|------|------|------|
| P7-1 | TPoolAllocator | nextpas.core.mem.allocator.pool.pas | test_pool (8 tests) | ✅ 完成 |
| P7-2 | TSlabAllocator | nextpas.core.mem.allocator.slab.pas | test_slab (8 tests) | ✅ 完成 |
| P7-3 | TStackAllocator | nextpas.core.mem.allocator.stack.pas | test_stack (8 tests) | ✅ 完成 |
| P7-4 | TCoalesceAllocator | nextpas.core.mem.allocator.coalesce.pas | test_coalesce (9 tests) | ✅ 完成 |

## 验证

```bash
make -C core/tests/nextpas.core.mem/test_pool clean test
make -C core/tests/nextpas.core.mem/test_slab clean test
make -C core/tests/nextpas.core.mem/test_stack clean test
make -C core/tests/nextpas.core.mem/test_coalesce clean test
```
