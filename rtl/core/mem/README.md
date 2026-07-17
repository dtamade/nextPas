# nextPas rtl/core/mem/

`rtl/core/mem/` 承接 nextPas compiler / toolchain 早期需要的最小 allocator 骨架。

## 状态

| 项 | 说明 |
|----|------|
| `np_allocator.pas` | 最小 `TCoreAllocator` + `TBumpArena` 实现 |
| **消费者** | 当前仓库 **无** 生产/测试引用（`TBumpArena` 零 uses） |
| **继任产品面** | `nextpas.core.compiler.mem`（VirtualArena / unit allocator） |
| **通用 stdlib** | `nextpas.core.mem`（DefaultHeap Growing + Arena 工厂） |

新编译器模块请优先：

```pascal
uses nextpas.core.compiler.mem;

var LScope: TCompilerUnitScope;
FillChar(LScope, SizeOf(LScope), 0);
LScope.BeginScope;
try
  // ... unit compile (LScope.Alloc) ...
  LScope.Reset;
finally
  LScope.EndScope;
end;
```

示例：`core/examples/nextpas.core.compiler/unit_arena_demo/`

HTTP 请求 scratch 走 `nextpas.core.http` 的 `RequestArenaMiddleware` / `HttpCreateRequestArena`，不要在本目录扩展业务 API。

## 这里现在不做什么

- 不在这里提前承诺 region graph、GC 或完整 ownership system。
- 不把 app-facing container API 混进 allocator layer。
- 不把跨阶段缓存策略写死在当前最小 arena skeleton 里。
- **不**继续扩展 `TBumpArena` 作为长期 compiler 路径；继任见 `core/src/nextpas.core.compiler.mem.pas`。

## 相关文档

- 通用 mem 入口：`core/docs/mem/README.md`
- 可用性评分：`core/docs/mem/USABILITY-SCORE.md`
- RTL 边界：`docs/architecture/rtl-specification.md`
