# nextPas rtl/core/text/

`rtl/core/text/` 承接 nextPas compiler / toolchain 会高频复用的 text、identity 和 path
primitive。这里的重点不是先做一套宽而全的 string library，而是先把 source path
normalization、unit identity normalization 和 text file ingestion 这类会直接影响
`SourceDatabase`、resolver、diagnostics 和 future package/toolchain control plane 的基础能力
沉成共享资产。

如果你要看为什么 `text/path` 不该继续散落在 compiler 私有 helper 里，读
`docs/architecture/rtl-specification.md` 和
`docs/architecture/compiler-pipeline-specification.md`。

## 当前目录分工

- `np_text_primitives.pas`
  - 提供最小 path/identity normalization、path-prefix 检查与 text file ingestion contract

## 第一阶段这里先做什么

- 先固定 `SourceDatabase`、resolver 和 diagnostics 能共享的最小 text/path helper。
- 先把 path canonicalization 和 unit identity normalization 收成单点 truth。
- 保持 Linux x86_64 `stage0` 可直接由宿主 FPC 编译和验证。

## 这里现在不做什么

- 不在这里提前塞完整 interner、rope 或 rich Unicode text engine。
- 不把 formatting helper、locale helper 或 app-facing string API 混进来。
- 不把 editor-facing text model 和 compiler-facing text primitive 提前混成一层。
