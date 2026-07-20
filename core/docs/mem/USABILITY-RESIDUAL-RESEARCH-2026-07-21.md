# mem 可用性复评残余调研（P2）

**日期**: 2026-07-21
**状态**: Research → Implementing
**输入**: 落地后复评 9.4/10；无 P0/P1
**范围**: P2-1 历史子类 raise；P2-2 坏 stem；P2-3 SAFETY 文档入口

## 量化

| 项 | 数量 |
|----|------|
| 历史子类 bare raise | **40**（fixed 12、fixed.growable 16、slab 2、slab.sharded 4、stack 2、ring 3、arena.local EStackOverflow 1） |
| 坏 stem（`*.Raise` / `allocator_*`） | **~24 处** 跨 8 文件 |
| 主路径 EAllocError/EOutOfMemory | 137/137 已助手（门禁已钉） |

## 根因

1. `check_alloc_error_raises` 只匹配 `EAllocError|EOutOfMemory`，子类字面逃逸。
2. R-* 批量转换对非 Type.Method 字面量用了文件名 + `Raise`。
3. SAFETY 故意不进默认 lane，文档入口已有但可再钉 README/CI 表。

## 策略

- 子类 raise → `FormatAllocErrorMsg`；保留子类类型（不删 API）。
- 扩展门禁扫所有 `raise E*.Create` 于 mem*.pas（白名单 error.pas）。
- 坏 stem 改为真实 Type.Method。
- P2-3：文档钉 `test_heap_safety_profile`；不改 core-ci matrix。

## 风险

LOW。消息全文可能变；测试优先 Pos stem / 错误码。
