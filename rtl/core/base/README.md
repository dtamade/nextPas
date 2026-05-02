# nextPas rtl/core/base/

`rtl/core/base/` 是 nextPas `toolchain-first RTL` 的第一层公共基础。这里先承接那些会被
compiler、build tooling、package tooling 和 future public RTL 一起复用，但又不应该继续
塞进 `System` 杂项里的最小 truth object。

如果你要看为什么 nextPas 现在先从这里动手，读
`docs/architecture/rtl-specification.md` 和
`docs/architecture/runtime-bootstrap-specification.md`。

## 当前目录分工

- `np_base_types.pas`
  - 提供最小 `status/result` vocabulary、stable id 与 span support types

## 第一阶段这里先做什么

- 先把 compiler/toolchain 能共享的最小 support types 固定下来。
- 先服务 diagnostics、source identity、runtime contract 与后续 artifact/tool spans。
- 保持 Linux x86_64 `stage0` 可直接由宿主 FPC 编译。

## 这里现在不做什么

- 不在这里提前塞入完整 text/path/interning 体系。
- 不把 app-facing string helpers、formatting helpers 或 I/O facade 混进来。
- 不把异常当成热路径默认 contract。
