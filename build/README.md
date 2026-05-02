# nextPas build/

`build/` 是 nextPas 第一阶段的现代编排层。这里负责承接目标平台规格、本地验证入口、
CI 粘合层，以及与公开发行布局相关的控制面语义。

如果你要看冻结后的边界，先读
`docs/architecture/target-platform-specification.md` 和
`docs/architecture/distribution-layout-specification.md`。

## 第一阶段这里会承接什么

- `targets/`：外置的目标平台事实来源；当前已落位 `targets/linux-x86_64.toml`
- `toolchains/`：host-to-target binding spec 的正式落点；当前已落位
  `toolchains/linux-x86_64-to-linux-x86_64-gnu.toml`，其中当前显式固定
  `host_compiler=fpc` 与 `host_compiler_profile=fpc-stage0-host`
- `verify_local.sh`：与 CI 尽量对齐的本地验证入口
- 后续 Linux CI 所需的最小编排与检查胶水

Run:

```bash
./build/verify_local.sh
```

Then:

```bash
./tests/run_all_tests.sh --filter smoke
```

第一条命令会先检查关键架构文档、目标规格、`compiler/` skeleton 输入和驱动入口，再用 `fpc`
构建 `stage0` 驱动，随后执行 `stage0 build` 的真实 smoke 路径并断言输出里存在
`command-envelope=`、`session-id=`、`source-db-file-count=1`、`syntax-status=ready`、
`resolution-status=ready`、`semantic-status=ready`、`mir-status=ready`、
`backend-plan-status=ready`、`toolchain-binding-id=linux-x86_64-to-linux-x86_64-gnu`、
`host-id=linux-x86_64`、`target-runtime-layout-key=target-sdk-split`、
`sysroot-mode=runtime-sdk`、`runtime-sdk-id=linux-x86_64`、`allow-host-fallback=false`、
`primary-tool-profile-id=fpc-stage0-host`、`primary-tool-step-id=host-fpc-compile`、
`primary-tool-logical-executable=fpc`、
`primary-tool-sysroot-ref=runtime-sdk:linux-x86_64`、
`primary-tool-failure-mapping=toolchain.host-compiler-exec-failed`、
`ast-root-kind=program` 与 session 相关结果字段，再对
`examples/smoke/hello_with_units.pas` 断言 `resolved-unit-count=4`、`unit-graph-edge-count=4`、
`symbol-count=4`、`type-count=3`、`typed-hir-node-count=7`、`runtime-contract-count=2`、
`mir-block-count=1`、`mir-operation-count=8`、`backend-output-kind=executable`、
`target-object-format=elf`、`target-assembler-flavor=gnu-as`、
`target-linker-flavor=gnu-ld`、`target-c-library-naming=lib-prefix-so-a`、
`target-llvm-triple=x86_64-unknown-linux-gnu`、`tool-invocation-count=1` 与同一批
`primaryToolProfileId` / `primaryToolStepId` / `primaryToolLogicalExecutable` /
`primaryToolSysrootRef` / `primaryToolFailureMapping` envelope fields，对
`tests/compiler/fail/missing_semicolon_fail.pas` 断言 `syntax-analysis-failed` /
`parser.syntax-error` 路径，并对 missing unit / ambiguous unit / unit cycle 三类
resolution failure 断言 `unit-resolution-failed` + resolver diagnostics，再对
duplicate import 语义失败断言 `semantic-analysis-failed` +
`sema.duplicate-declaration`，再通过 fake `fpc` 负路径断言
`toolchain.host-compiler-exec-failed`、`diagnostic-binding-id`、`diagnostic-profile-id`、
`diagnostic-step-id`、`diagnostic-logical-executable`、`diagnostic-sysroot-ref`、
`diagnostic-resolved-path`、`diagnostic-primary-artifact-*` 与同一条 envelope diagnostics
payload；它还会把 `tests/toolchain/toolchain_contract_smoke.pas` 编译到临时 `-FE/-FU`
build dir，并在执行后显式断言源码树里不存在
`tests/toolchain/toolchain_contract_smoke` 与 `tests/toolchain/toolchain_contract_smoke.o`；
最后再用 fake `fpc` 驱动 `./tests/run_all_tests.sh --filter smoke` 的 stage0 bootstrap
failure，断言输出里存在 `bootstrap-step`、`bootstrap-command`、
`bootstrap-stderr-file`，并且原始 stderr evidence 会被回显，然后跑通 smoke `harness`
并断言 `tests/run_all_tests.sh --filter smoke` 的输出里同样存在
`command-envelope=`。
第二条命令保留为手工回放时可单独执行的最小验证入口，但 CI 与本地默认都应该优先复用
`verify_local.sh`。

## `verify_local.sh` 是编排入口，不是新的结果协议

`build/verify_local.sh` 当前会打印 line-based 字段，例如 `mode=verify-local`、
`command=verify-local`、`selector=verify-local`、`target=linux-x86_64`、`docs-check=pass`、
`stage0-build=pass`、`stage0-smoke=pass`、`semantic-smoke-check=pass`、
`toolchain-contract-check=pass`、`toolchain-failure-check=pass`、
`syntax-failure-check=pass`、`missing-unit-check=pass`、`ambiguous-unit-check=pass`、
`unit-cycle-check=pass`、`duplicate-import-check=pass`、
`harness-bootstrap-diagnostics-check=pass`、`smoke-check=pass`、
`status=ready`、`result=pass`、`command-outcome=success` 和
`human-summary=local verification passed`。
这些字段的作用，是让本地终端、CI log 和 `.sisyphus/evidence/` 有一条确定性的编排回放线，
但它们不是下一套独立的 canonical truth。

这里要继续对齐的对象边界是：

- `stage0 build`
  - 结果语义继续朝统一 `CommandResultEnvelope` 收敛；当前 key/value 只是 human projection
- `tests/run_all_tests.sh --filter smoke`
  - 默认继续消费命令级 outcome、diagnostics snapshot 与 build trace 的分工，而不是 scrape 任意 progress 文本
- `build/verify_local.sh`
  - 只负责把 docs check、目标输入检查、stage0 构建、stage0 smoke envelope 断言，以及 harness smoke envelope 断言编排成一条公开路径
  - 它自己现在也会输出 `command-envelope=<json>`，把 `verify-local` 的最终结果投影成同一类 command result truth
  - `Batch 3/4/5/6/7` 起，它还负责断言最小 `CompilationSession` / `SourceDatabase` /
    `syntax` / `UnitGraph` / `SemanticModel` / `MIR` / `BackendPlan` / toolchain binding skeleton
    已真实进入 `stage0 build`
  - `Batch 11` 起，它还会显式 gate primary tool profile / step / logical executable /
    sysroot ref / failure mapping，避免宿主 compiler execute step 又退回 driver 私有语义
  - `Batch 12` 起，它还会显式 gate host-compiler failure 的 structured toolchain diagnostic，
    确保 `bindingId/profileId/stepId/logicalExecutable/sysrootRef/resolvedPath/primaryArtifact/exitCode`
    已真实进入 failure envelope
  - `Batch 13` 起，这条 toolchain diagnostic 的 ownership 已下沉到 `diagnostics sink + compilation session`，
    `stage0` 只继续做结果投影，不再长期持有私有 diagnostic 组装逻辑
  - 当前它还会显式保护两条 hygiene / 留证 contract：
    `tests/toolchain/toolchain_contract_smoke.pas` 的编译产物必须停留在临时 build dir，
    不能污染源码树；`tests/run_all_tests.sh` 的 bootstrap failure 必须保留
    `bootstrap-step` / `bootstrap-command` / `bootstrap-stderr-file` 和原始 stderr evidence

换句话说，`verify_local.sh` 负责 orchestration visibility，不替代 `stage0` 的命令结果契约，
也不替代 `harness` 的 snapshot / trace 留证模型。

## 这一层当前必须坚持的规则

- 第一阶段只允许一个目标：`linux-x86_64`
- 目标规则要从配置中读取，而不是散落在 Pascal 代码或临时 shell 参数里
- toolchain binding 也必须有正式文件归属，而不是继续由脚本临时拼出 `CROSSBINDIR` / `LDPROG` /
  `ARPROG` 一类推导链
- 构建与验证路径必须能解释到公开发行语义：`bin/`、`lib/`、`units/<target>/`、
  `share/`

这也是为什么 `build/` 不能只是一些零散脚本的收纳位置。它是 nextPas 把目标、验证和
发行布局绑在一起的控制层。

## 这里现在不做什么

- 不私自维护第二套平台矩阵。
- 不引入 Windows 或 macOS 的预留配置分支。
- 不把安装器、包管理器或 IDE 集成写成当前前提。
- 不把构建逻辑重新藏回与其无关的目录里。
