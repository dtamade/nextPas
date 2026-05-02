# nextPas rtl/core/mem/

`rtl/core/mem/` 承接 nextPas compiler / toolchain 优先需要的内存纪律。这里的重点不是把
通用容器或完整 GC 先写一遍，而是先把 allocator contract 和 arena 这类会直接影响 parser、
semantic model、MIR lowering 与 future IDE 后台服务吞吐的基础设施落下来。

如果你要看为什么这里不应该继续塞进 `System`，读
`docs/architecture/rtl-specification.md`。如果你要看 runtime bootstrap 为什么要尽早拥有
共享 allocator discipline，读 `docs/architecture/runtime-bootstrap-specification.md`。

## 当前目录分工

- `np_allocator.pas`
  - 提供最小 `TCoreAllocator` contract 与 `TBumpArena` implementation

## 第一阶段这里先做什么

- 先固定 allocator/result contract，而不是继续依赖宿主 RTL 习惯。
- 先提供 compiler-friendly bump arena，服务 lexer、syntax、HIR、MIR 与 diagnostics 热路径。
- 保持 block reuse 和 `Reset` 语义显式，方便后续 session / phase 生命周期接入。

## 这里现在不做什么

- 不在这里提前承诺 region graph、GC 或完整 ownership system。
- 不把 app-facing container API 混进 allocator layer。
- 不把跨阶段缓存策略写死在当前最小 arena skeleton 里。
