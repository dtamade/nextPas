# nextPas tools/stage0/

`tools/stage0/` 承接 nextPas 第一阶段最小但真实的命令行控制面。这里现在公开
`build`、最小 `test`、`env status/use/sync/clean`、最小 `doctor`、最小 `query symbols` 与只读 `pkg inspect / pkg plan / pkg graph`，
但仍不假装已经是完整工具链前端。

如果你要看冻结后的边界，先读
`docs/architecture/stage0-driver-specification.md`。如果你要看当前主线批次，读
`docs/plans/2026-03-24-nextpas-master-roadmap-plan.md` 与
`docs/plans/2026-03-24-nextpas-mir-backend-toolchain-plan.md`。

## 现在支持什么

当前承诺的命令是：

```text
nextpas build <source> --target linux-x86_64 [--toolchain-binding <id>] [--workspace <root>] [--unit-root <dir>]... [--out-dir <dir>]
nextpas test --list-groups [--workspace <root>]
nextpas test --filter <group> [--workspace <root>]
nextpas env status --target linux-x86_64 [--toolchain-binding <id>] [--workspace <root>]
nextpas env use --target linux-x86_64 --toolchain-binding <id> --workspace <root>
nextpas env sync --target linux-x86_64 [--toolchain-binding <id>] --workspace <root>
nextpas env clean --target linux-x86_64 --workspace <root>
nextpas doctor --target linux-x86_64 [--toolchain-binding <id>] [--workspace <root>]
nextpas query symbols <source> --target linux-x86_64 [--toolchain-binding <id>] [--workspace <root>]
nextpas pkg inspect --workspace <root> --target linux-x86_64 [--toolchain-binding <id>]
nextpas pkg plan --workspace <root> --target linux-x86_64 [--toolchain-binding <id>]
nextpas pkg graph --workspace <root> --target linux-x86_64 [--toolchain-binding <id>]
```

这个入口由 FreePascal 编译成可执行程序，再从
`build/targets/linux-x86_64.toml` 读取目标事实，并按 binding 选择去驱动 smoke 输入的最小
build 路径。当前如果不显式传 `--toolchain-binding`，会继续使用默认
`linux-x86_64-to-linux-x86_64-gnu` binding；如果显式传
`--toolchain-binding linux-x86_64-to-linux-x86_64-llvm`，则会切到同一 host/target pair
下的 LLVM-heavy binding。

Run:

```bash
mkdir -p .sisyphus/tmp/stage0-bootstrap
fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/targets -Fucompiler/syntax -Fucompiler/sema \
  -Fucompiler/ir -Fucompiler/backend -Fucompiler/toolchain -Futools/stage0 \
  -Furtl/core/base -Furtl/core/text \
  -FE.sisyphus/tmp/stage0-bootstrap -FU.sisyphus/tmp/stage0-bootstrap \
  tools/stage0/nextpas.pas
NEXTPAS_REPO_ROOT="$PWD" ./.sisyphus/tmp/stage0-bootstrap/nextpas \
  build examples/smoke/hello.pas --target linux-x86_64 --workspace "$PWD"
```

显式选择 LLVM binding：

```bash
NEXTPAS_REPO_ROOT="$PWD" ./.sisyphus/tmp/stage0-bootstrap/nextpas \
  build examples/smoke/hello.pas --target linux-x86_64 \
  --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --workspace "$PWD"
```

Then:

```bash
NEXTPAS_REPO_ROOT="$PWD" ./.sisyphus/tmp/stage0-bootstrap/nextpas \
  test --filter smoke --workspace "$PWD"
```

Then:

```bash
NEXTPAS_REPO_ROOT="$PWD" ./.sisyphus/tmp/stage0-bootstrap/nextpas \
  env status --target linux-x86_64
```

Then:

```bash
NEXTPAS_REPO_ROOT="$PWD" ./.sisyphus/tmp/stage0-bootstrap/nextpas \
  env use --target linux-x86_64 \
  --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --workspace "$PWD"
NEXTPAS_REPO_ROOT="$PWD" ./.sisyphus/tmp/stage0-bootstrap/nextpas \
  env status --target linux-x86_64 --workspace "$PWD"
NEXTPAS_REPO_ROOT="$PWD" ./.sisyphus/tmp/stage0-bootstrap/nextpas \
  env sync --target linux-x86_64 --workspace "$PWD"
NEXTPAS_REPO_ROOT="$PWD" ./.sisyphus/tmp/stage0-bootstrap/nextpas \
  env clean --target linux-x86_64 --workspace "$PWD"
```

Then:

```bash
NEXTPAS_REPO_ROOT="$PWD" ./.sisyphus/tmp/stage0-bootstrap/nextpas \
  doctor --target linux-x86_64 --workspace "$PWD"
```

Then:

```bash
NEXTPAS_REPO_ROOT="$PWD" ./.sisyphus/tmp/stage0-bootstrap/nextpas \
  query symbols examples/smoke/hello_with_units.pas --target linux-x86_64 --workspace "$PWD"
```

Then:

```bash
NEXTPAS_REPO_ROOT="$PWD" ./.sisyphus/tmp/stage0-bootstrap/nextpas \
  pkg inspect --workspace "$PWD" --target linux-x86_64
NEXTPAS_REPO_ROOT="$PWD" ./.sisyphus/tmp/stage0-bootstrap/nextpas \
  pkg plan --workspace "$PWD" --target linux-x86_64
NEXTPAS_REPO_ROOT="$PWD" ./.sisyphus/tmp/stage0-bootstrap/nextpas \
  pkg graph --workspace "$PWD" --target linux-x86_64
```

Then:

```bash
./tools/stage0/nextpas frobnicate examples/smoke/hello.pas
```

这些命令现在都走统一 `nextpas` 产品壳：`build` 继续由 driver 自己驱动 compiler/toolchain，
`test` 则只做最小参数解析后 thin-wrap 到 `tests/run_all_tests.sh` 与
`tests/harness/runner.pas`，`env status` 则解析 target / binding / distribution /
runtime state，`env use` 只更新 workspace-local selection sidecar，`env sync` 则刷新
workspace-local resolution sidecar，`env clean` 则清理 workspace-local selection /
resolution sidecar，不下载或安装环境，
`doctor` 则复用同一批 environment truth 做只读健康检查，
`query symbols` 则复用 compilation session 的 syntax / resolution / semantic truth 做只读 symbol 查询，
`pkg inspect / pkg plan / pkg graph` 则复用 workspace model 与 package manifest truth 做只读
package workflow 投影；其中 `pkg plan` 是 install plan preflight 的专用只读面，`pkg graph`
还会把 declared dependency truth 投影为 root/dependency nodes 与 `declared-dependency` edges。
其中 `build`、`test --filter <group|smoke>`、`env status/use/sync/clean`、`doctor`、`query symbols` 与 `pkg inspect / pkg plan / pkg graph`
的执行路径都会额外输出一条
`command-envelope=<json>`。这些 key/value 现在至少会对齐这些公共字段：

- `command=build|test|env|doctor|query|pkg`
- `selector=build|test|group|smoke|status|use|sync|clean|doctor|symbols|inspect|plan|graph`
- `status=success|failure`
- `result=success|failure`
- `command-outcome=success|failure`
- `failure-kind=<kind>`（仅失败路径）
- `human-summary=<summary>`

`env status` 当前还会额外投影最小 environment state：

- `env-selection-path=<path>`（传入 `--workspace` 时）
- `env-selection-status=<missing|ready|overridden|invalid|target-mismatch>`（传入 `--workspace` 时）
- `env-selection-target=<target>`（传入 `--workspace` 时）
- `env-selection-toolchain-binding-id=<binding-id>`（selection 可解释时）
- `toolchain-binding-path=<path>`
- `distribution-bin-dir=<path>`
- `distribution-lib-dir=<path>`
- `distribution-share-dir=<path>`
- `runtime-root=<path>`
- `runtime-libc=<path>`
- `runtime-libc-present=<true|false>`
- `environment-readiness=<state>`
- `environment-status=<ready|incomplete>`
- `runtime-sdk-status=<state>`
- `toolchain-binding-status=<ready|missing>`
- `distribution-status=<ready|incomplete>`

`env use` 当前只支持 workspace-local preferred binding selection：

- sidecar 路径固定为 `<workspace>/.nextpas/env/selections/<target>.toml`
- `env use --target <target> --toolchain-binding <id> --workspace <root>` 会先验证 binding
  与 target config，再写入该 sidecar
- 后续 `env status --target <target> --workspace <root>` 在没有显式
  `--toolchain-binding` 时会读取该 selection
- 显式 `--toolchain-binding` 仍高于 workspace selection

`env sync` 当前只支持 workspace-local environment resolution cache：

- sidecar 路径固定为 `<workspace>/.nextpas/env/resolution/<target>.toml`
- `env sync --target <target> --workspace <root>` 会在未显式传
  `--toolchain-binding` 时读取 workspace selection，并复用同一份 target config /
  toolchain binding / distribution / runtime projection
- 输出会额外投影 `env-resolution-path`、`env-resolution-status=ready` 与
  `env-sync-change=materialized|updated|unchanged`
- 它不下载、不解包、不安装 runtime SDK，也不修改 workspace descriptor、package manifest、lockfile
  或 selection sidecar

`env clean` 当前只支持 workspace-local selection / resolution sidecar cleanup：

- 只接受 `--target` 与必须的 `--workspace`
- 只删除 `<workspace>/.nextpas/env/selections/<target>.toml` 与
  `<workspace>/.nextpas/env/resolution/<target>.toml`
- 输出会额外投影 `env-clean-status`、`env-clean-change`、
  `env-clean-selection-path`、`env-clean-resolution-path` 与
  `env-clean-removed-count`
- 它不下载、不解包、不安装 runtime SDK，也不修改 workspace descriptor、package manifest、lockfile
  或公开 install result

这条 surface 当前故意把“状态解析 / selection 切换”和“健康诊断”分开：即使 runtime 仍然缺失，
`env status` 也会保持 `status=success` / `result=success`，并把未就绪事实放进
`environment-readiness`、`environment-status`、`runtime-sdk-status`、
`toolchain-binding-status`、`distribution-status` 与 `runtime-libc-present`，而不是把
“不完整环境”误报成命令执行失败。`environment-readiness` 当前保留为兼容字段，并与
`environment-status` 使用同一 derived readiness vocabulary。

`doctor` 当前还会额外投影最小 health inspection 汇总：

- `doctor-status=healthy|warning`
- `doctor-check-count=<count>`
- `doctor-finding-count=<count>`
- `package-workflow-status`
- `package-manifest-status`
- `package-lock-status`
- `package-install-plan-status`
- `package-source-root-count`
- `package-source-roots`
- `package-dependency-count`
- `package-dependencies`
- `package-dependency-validation-status`
- `package-dependency-issue-count`
- `package-dependency-issues`
- 缺少 package truth 时还会出现 `doctor.package-workspace-missing`
- workspace descriptor root 指向 member package 时还会稳定投影
  `workspace-descriptor-path` 与 member package detail fields

这条 surface 当前仍是只读 inspection：它解释当前 target / binding / runtime / workspace
状态是否健康，但不执行 `env sync`、不安装 runtime SDK，也不替代 `build` 或 `test`。

`query symbols` 当前还会额外投影最小 query 汇总：

- `query-kind=symbols`
- `query-status=success`
- `analysis-source=compilation-session`
- `query-result-count=<count>`
- `query-symbols=<json-array>`
- `query-bindings=<json-array>`
- `query-definitions=<json-array>`
- `query-scopes=<json-array>`
- `query-types=<json-array>`

这条 surface 当前不是完整 language service，也不是 LSP server。它只把
`TCompilationSession` 已经拥有的 syntax / resolution / semantic 结果投影为只读 query
结果。`query-symbols` 是同一份 semantic symbol graph 的结构化 mirror，当前每个条目至少
包含 `symbolId`、`name`、`kind`、`ownerUnitId`、可解析时的 `ownerUnitName`、
`scopeId`、可解析时的 `scopeKind` / `scopeName` / `scopeParentId`、`typeId`、
可解析时的 `typeName` / `typeKind` / `typeParentId` 和 `byteOffset`。`query-scopes`
与 `query-types` 则是同一份 `TSemanticModel` 的 normalized side tables，供调用方用
`scopeId` / `typeId` 回查 scope 与 type truth，而不需要重扫源码或解析 build output。
`query-bindings` 是同一份 semantic binding table 的结构化 mirror，当前每个条目至少包含
`bindingId`、`kind`、`name`、`ownerUnitId`、`byteOffset` 与 `targetSymbolId`。
`query-definitions` 继续把这些 binding 的 target symbol id join 回同一份 semantic
symbol/unit truth，当前每个条目至少包含 binding id/kind/name/offset 与 target
symbol id/name/kind/param count/param signature/owner unit/source path/offset。bare
procedure/function call 已覆盖同名同 arity overload 的最小 typed binding；默认参数语法会把
bare call 的可接受 arity 扩展为必填参数数到总参数数，当前可推断的 argument signature
会按已提供参数前缀选择唯一 `ParamSignature` target，并通过
`queryDefinitions[].targetParamSignature` 暴露 compact target signature；root-owned 单一 target 的
type-mismatch diagnostics 现在还接受 root-owned 零参内建标量/字符串 function result 作为稳定
argument evidence；当 target 来自 imported `project-source` 单一 callable、direct member-call
target 或 inherited direct member-call target 时，同一类 root-owned function-result evidence 也会投影为 `sema.type-mismatch`；
当 imported `project-source` inherited member-call overload set 的所有同 arity target 都不匹配时，
同一类 root-owned function-result evidence 会投影为 `sema.no-matching-overload`；当同一
imported inherited overload set 出现 compact signature collision 且无法唯一选择时，同一类
root-owned function-result evidence 会投影为 `sema.ambiguous-overload`；无法推断、
imported `installed-source` target 或 inherited installed-source overload set、imported/带参/member function result
或 source provenance 不可信的 signature 不唯一时仍保守不绑定。当前 name-only binding pass 会显式排除
`Holder.Help();` 这类 selector/member callee；当前 `member-call` 最小正向边界覆盖 direct
class variable receiver 的 method statement call，包括 argument-count matched
`Worker.SetValue(7);` 这类带参数调用，也覆盖 `Halt(Worker.Add(1, 2));` 这类表达式参数里的
direct member function call、class method body 内的 `Self.SetValue(9)` 与 bare implicit-self
method call（例如 `Touch;` / `Touch(7);`，包括沿 parent class lookup 绑定到 inherited
method），还覆盖 `TWorker.Create(42)` 这类已声明 class type-name receiver 的 constructor-like member call；
same path 的 bare implicit-self method call 若 stable argument signature 与 root-owned
单一 target 不兼容，会失败为 `sema.type-mismatch`（例如 `Touch(True);` 调
`Touch(Integer)`、当前 class 的 `Pick(True);` 调 `Pick(Integer)`，或 `Pick(Flag);`
中 `Flag` 是 root-owned 零参 Boolean function result），且不会注册错误 binding。
若同一路径找到 method name 但 arity 不兼容，会失败为
`sema.wrong-argument-count`（例如当前 class 的 `Pick;` 调 `Pick(Integer)`，或 inherited
`Touch;` 调 `Touch(Integer)`），同样不会注册错误 binding。
若同一路径找到多个 method target 但 stable argument signature 全不匹配，会失败为
`sema.no-matching-overload`（例如当前 class 的 `Pick(True);` 同时面对
`Pick(Integer)` / `Pick(AnsiString)`，或 inherited `Touch(True);` 同时面对
`Touch(Integer)` / `Touch(AnsiString)`），同样不会注册错误 binding。
若同一路径找到多个 method target，且 compact signature collision 后仍无法唯一选择，
会失败为 `sema.ambiguous-overload`（例如当前 class 的 `Pick(1);` 同时面对
`Pick(Integer)` / `Pick(LongInt)`，或 inherited `Touch(1);` 同时面对
`Touch(Integer)` / `Touch(LongInt)`），同样不会注册错误 binding。
root source 中变量的 class type 也可以来自 imported project/source unit 的已 seed type symbol。
当 root 与 imported unit 同时声明同名 class 时，receiver 会沿变量 `TypeId` 回到对应 type
symbol owner，再在该 owner 下选择 method target，避免 query surface 暴露字符串误绑结果。
当 receiver exact class type 没有同名 method 时，当前还会沿 `ParentTypeId` 链查 parent
class method，并把 `Child.Touch` 这类 inherited call 投影到 parent method target；exact type
已有同名 method 但 arity/body 不匹配或不唯一时会保守停止。implicit source-backed `System`
路径下，no-fold typed HIR 会复制继承到的 `TObject.Destroy` VMT slot/function truth，并把
`Obj.Free` lowering 到当前有效 `Destroy` runtime call；同一 lowering 还会产生
`np.system.object_free` contract，记录 nil guard 与 heap release intent，并由 HIR builder
保留为同名 intrinsic marker，匹配的后续 `Destroy` lowering 会被标记为
`np.system.object_free.destroy` owned marker；`heap-release true` 还会成为
`np.system.object_free.release` marker。LLVM HIR emitter 已把这组 marker lowering 成
receiver nil branch，让 `Destroy` call 与 `@np_object_free_release` hook 只在非空分支执行；
class allocation lowering 也已先进入 `@np_object_alloc` helper，再由 helper 委托到底层
`@np_alloc` 申请 16-byte header + payload；allocation helper 会写 payload size 与 magic，
release helper 会从 payload pointer 回退读取 header、校验 magic，并把合法 header 分到
`release:` 占位块、非法 header 分到 `invalid:` 并调用
`@np_object_release_invalid(ptr %raw, i64 %size, i64 %magic)` 后汇合到 `done:`；invalid helper 当前会
调用 `@llvm.trap()` 并发出 `unreachable`；`release:` 当前调用
`@np_object_release_valid(ptr %raw, i64 %size)` 并清零 header magic。当前 object alloc/release
helpers 仍是最小 ownership contract，这仍不是 allocator free、结构化 diagnostics / Pascal
exception path 或动态 virtual dispatch runtime。
完整 member resolver、visibility checking、runtime
constructor lowering、完整 virtual dispatch 与 type-based overload resolution仍属于后续
language-service / semantic model 工作。class method overload 目前只按
argument count 选择同 owner / 同 qualified name / 同 `ParamCount` 的唯一 method symbol，并通过
`queryDefinitions[].targetParamCount` 暴露 target arity；若同 arity 有多个候选，当前可推断的
argument signature 会选择唯一 `ParamSignature` target，并通过
`queryDefinitions[].targetParamSignature` 暴露 compact target signature。
因此成功路径会显示
`mir-status=deferred`、`backend-plan-status=deferred` 与
`toolchain-plan-status=deferred`，不会执行 backend 或 toolchain。

`pkg inspect / pkg plan / pkg graph` 当前还会额外投影最小 package workflow 汇总：

- `package-workflow-status=ready|missing`
- `package-manifest-status=ready|missing`
- `workspace-descriptor-path=<path>`（有值时）
- `package-manifest-path=<path>`（有值时）
- `package-lock-status=missing|ready|invalid`
- `package-lock-format-version=<version>`（有值时）
- `package-lock-entry-count=<count>`
- `package-lock-entries=<json-array>`
- `package-lock-snapshot-count=<count>`
- `package-lock-snapshots=<json-array>`
- `package-lock-issue-count=<count>`
- `package-lock-issues=<json-array>`
- `package-workflow-manifest-path=<path>`
- `package-root-path=<path>`
- `package-name=<name>`
- `package-lockfile-path=<path>`
- `package-source-root-count=<count>`
- `package-source-roots=<json-array>`
- `package-dependency-count=<count>`
- `package-dependencies=<json-array>`
- `package-dependency-validation-status=valid|invalid|missing`
- `package-dependency-issue-count=<count>`
- `package-dependency-issues=<json-array>`
- `package-graph-status=ready|invalid|missing`
- `package-graph-node-count=<count>`
- `package-graph-edge-count=<count>`
- `package-graph-nodes=<json-array>`
- `package-graph-edges=<json-array>`
- `package-install-plan-status=ready|blocked|missing`
- `package-install-plan-blocker-code=<code>`（有 blocker 时）
- `package-install-plan-blocker-message=<message>`（有 blocker 时）
- `package-install-plan-blocker-expected-package=<json-object>`（有 mismatch detail 时）
- `package-install-plan-blocker-lock-entries=<json-array>`（有 mismatch detail 时）

这条 surface 当前不是完整 package manager，也不执行 fetch、install、dependency resolution
或 lockfile write。它只把 `WorkspaceModel`、`PackageManifestInfo` 与最小 `nextpas.lock` v1
read-only parser 已经拥有的 truth 投影为只读 package workflow 结果。当前 lock parser 也会读取
`[[snapshot]]` 的 `target`、`provenance`、`digest` 与 `selection` skeleton；缺字段会让
`package-lock-status=invalid`，selection 不匹配 lock entry、重复 target 或非 `sha256:` digest
shape 也会投影为 lock issues，但不会触发 resolver 或写回 lockfile。valid lockfile 如果已经有
snapshot 集合但没有当前 requested target snapshot，`pkg plan` 会只读 blocked 为
`package-lock-target-snapshot-missing`。`pkg graph` 还会把同一份 truth
展开成 root node、declared-dependency nodes 与 `declared-dependency` edges。
当前 `pkg plan` promotion gate 直接覆盖 package manifest ready path、workspace member
lock-missing blocked path、package-free manifest-missing missing path、dependency-invalid blocked
path、source-roots-missing blocked path、invalid-lock blocked path 与 manifest-lock out-of-sync
blocked path，并在 out-of-sync blocker 上公开 expected package 与 actual lock entries detail；
`pkg inspect / pkg graph` promotion gate 继续覆盖
package manifest root 与 workspace descriptor root 解析到 member
package 的 ready 路径，并冻结 `package-source-roots` / `packageSourceRoots`、
`package-dependencies` / `packageDependencies` 明细、lockfile format/entry/issue detail，以及
dependency requirement validation status / issue detail，避免 `pkg inspect`、`pkg plan`、
`pkg graph` 和 `doctor` 对 workspace membership、source roots、lockfile validity 或
install-plan blocker 形成多套解释。

在 `Batch 3/4/5/6/7` 之后，`stage0 build` 还会额外投影最小 compiler kernel + syntax /
resolution / sema / MIR / backend / toolchain skeleton：

- `session-id=<id>`
- `root-file-id=<id>`
- `source-db-file-count=<count>`
- `source-db-line-index=deferred`
- `unit-state-count=<count>`
- `diagnostics-count=<count>`
- `diagnostics-error-count=<count>`
- `diagnostics-warning-count=<count>`
- `diagnostics-policy=<policy>`
- `workspace-root=<path>`
- `workspace-discovery-kind=explicit-workspace-override|nearest-workspace-descriptor|nearest-package-manifest|source-directory-fallback`
- `workspace-descriptor-path=<path>`（有值时）
- `package-manifest-path=<path>`（有值时）
- `artifact-root=<path>`
- `output-dir=<path>`
- `syntax-status=ready|failure`
- `lexer-token-count=<count>`
- `green-node-count=<count>`
- `ast-root-kind=<kind>`
- `ast-declared-name=<name>`
- `resolution-status=ready|failure|deferred`
- `unit-graph-status=ready|failure|deferred`
- `search-path-count=<count>`
- `search-index-status=deferred|partial|ready|empty`
- `indexed-search-root-count=<count>`
- `search-index-scan-count=<count>`
- `resolved-unit-count=<count>`
- `unit-graph-edge-count=<count>`
- `unit-graph-root-name=<name>`
- `semantic-status=ready|failure|deferred`
- `symbol-graph-status=ready|failure|deferred`
- `type-graph-status=ready|failure|deferred`
- `typed-hir-status=ready|failure|deferred`
- `symbol-count=<count>`
- `type-count=<count>`
- `typed-hir-node-count=<count>`
- `runtime-contract-count=<count>`
- `typed-hir-root-name=<name>`
- `mir-status=ready|failure|deferred`

注意：`workspace-root`、`workspace-discovery-kind`、`workspace-descriptor-path`、
`package-manifest-path`、`artifact-root`、`output-dir` 属于 command-level build context。
当前即使 `invalid-unit-root` 这类在 `TCompilationSession` 创建前就失败的路径，也会继续投影
这批已知字段；`command-envelope=<json>.result` 也会保留对应的 camelCase build-context 字段，
以及已知的 `source` / `target`。但 `stage0` 不会为这类 early failure 伪造
`session-id`、`diagnostics-count`、`syntax-status` 等 session-owned fields。

- `mir-block-count=<count>`
- `mir-operation-count=<count>`
- `mir-entry-block=<label>`
- `mir-root-name=<name>`
- `backend-plan-status=ready|failure|deferred`
- `backend-output-kind=<kind>`
- `backend-primary-artifact-kind=<kind>`
- `backend-primary-artifact-path=<path>`
- `toolchain-binding-id=<binding-id>`
- `backend-family=<family>`
- `assembler-profile-id=<profile-id>`
- `linker-profile-id=<profile-id>`
- `archiver-profile-id=<profile-id>`
- `resource-tool-profile-id=<profile-id>`
- `host-id=<host-id>`
- `target-object-format=<format>`
- `target-assembler-flavor=<flavor>`
- `target-linker-flavor=<flavor>`
- `target-runtime-layout-key=<layout-key>`
- `target-c-symbol-prefix=<prefix-or-empty>`
- `target-c-library-naming=<naming-key>`
- `target-llvm-triple=<triple>`
- `target-llvm-data-layout=<data-layout>`
- `sysroot-mode=<mode>`
- `runtime-sdk-id=<sdk-id>`
- `allow-host-fallback=<true|false>`
- `tool-root-kind=<resolution-kind>`
- `runtime-root-kind=<resolution-kind>`
- `response-file-policy=<policy>`
- `link-script-policy=<policy>`
- `toolchain-plan-status=<status>`
- `toolchain-plan-family=<family>`
- `tool-profile-root=<path>`
- `logical-link-request-status=<status>`
- `logical-link-request-output-kind=<kind>`
- `logical-link-request-library-count=<count>`
- `logical-link-request=<json>`
- `llvm-toolchain-status=<status>`
- `llvm-executable-set-id=<id>`（有值时）
- `llvm-executable-set=<json>`（有值时）
- `tool-invocation-count=<count>`
- `primary-tool-role=<role>`
- `primary-tool-profile-id=<profile-id>`
- `primary-tool-step-id=<step-id>`
- `primary-tool-logical-executable=<logical-executable>`
- `primary-tool-sysroot-ref=<sysroot-ref>`
- `primary-tool-failure-mapping=<failure-kind>`
- `tool-run-status=success|failure`
- `tool-run-step-count=<count>`
- `primary-tool-run-status=success|failed`
- `diagnostics-summary=<summary>`
- `lifecycle-session=<summary>`
- `lifecycle-unit=<summary>`
- `lifecycle-stage=<summary>`

`test` 命令会把 harness 当前已有的 group / smoke 结果直接透传出来；`env status`
会把当前 target/binding/distribution/runtime 解析结果投影成 line-based output 与
`command-envelope=<json>`；`query symbols` 会把 compilation session 的 semantic symbol
detail、scope side table 与 type side table 作为当前最小查询结果投影出来；最后一条未知命令示例应该以非零状态退出，并打印清晰的
`unsupported-command` 消息。

## workspace discovery、unit root 和产物落点

当前 `stage0 build` 已经不是“只拿一个 source path 然后把产物写回原目录”的旧式壳。
现在真实行为固定如下：

- `--workspace <root>` 显式提供时，workspace root 直接取这个目录
- 如果没有 `--workspace`，会从 source 所在目录向上先找最近的 `nextpas.workspace.toml`
- 如果没有 workspace descriptor，再向上找最近的 `nextpas.package.toml`
- 两者都没有时，退回 source 所在目录
- `--unit-root <dir>` 可以重复传入，且 relative path 以 resolved workspace root 为基准
- `--out-dir <dir>` 也按 workspace root 解析 relative path

当前默认 artifact 布局固定是：

```text
<workspace-root>/.nextpas/
  out/<target>/
  cache/backend/<target>/
  cache/host-fpc/<target>/
```

这意味着：

- 默认主产物落在 `<workspace-root>/.nextpas/out/linux-x86_64/<program>`
- 默认 `linux-x86_64-to-linux-x86_64-gnu` binding 会把根程序和 source-backed units 的
  `.s`，以及确定性的 `<program>_link.res` 放进
  `<workspace-root>/.nextpas/cache/backend/linux-x86_64/`，然后继续消费同一批
  backend-owned `.s/.o/.res` truth
- 显式 `linux-x86_64-to-linux-x86_64-llvm` binding 会把 `.ll/.bc/.o` 放进同一个
  backend cache root，并由 LLVM toolchain steps 继续消费这些 backend-owned artifacts
- `cache/host-fpc/<target>/` 仍保留在 shared workspace model 里，但当前
  `bootstrap-native-assemble-link` 与 `llvm-ir-opt-llc-link` 成功路径都不再把根程序的
  中间产物落到这里
- source-adjacent output 不再是默认行为
- 如果 nearest package manifest 或 workspace descriptor 提供了 source roots，它们会先进入
  package source tier
- 当前 unit search precedence 已经是
  `root-source -> package-source-root -> explicit-unit-root -> target-installed`

## 退出码与失败语义

- `0`：命令输入合法，且 `build`、`test`、`env status/use/sync/clean`、`doctor` 或 `query symbols`
  的真实执行路径成功完成
- `1`：参数不合法、命令不受支持、目标不受支持、源文件缺失、syntax / resolution / sema 提前失败，或 `test` / toolchain 底层执行失败

当前 `env status`、`env clean` 与只读 `doctor` 不会因为 environment 仍不完整就退出失败；
这类事实继续通过 `environment-readiness` / `environment-status` / `runtime-sdk-status` /
`toolchain-binding-status` / `distribution-status` / `runtime-libc-present` 以及
`doctor-status` 表达。

当输入命令不是 `build`、`test`、`env`、`doctor`、`query` 或 `pkg` 时，驱动入口必须打印
`unsupported-command: <name>`。
当目标不是 `linux-x86_64` 时，驱动入口必须清晰拒绝，不把问题包装成模糊失败。
当前受支持目标、宿主编译器和发行布局假设都来自外置目标规格，而不是再硬编码在
`nextpas.pas` 里。当前 `stage0 build` 也会在成功路径上显式传入 target-aware
`-Fu<resolved-units-dir>`，并从 binding config 读取 `[profiles]`、`[sysroot]` 与
`[resolution]` policy，让 target-aware installed unit root、LLVM/C interop 相关 target
facts，以及 future assembler/linker/archiver/resource orchestration 需要的
profile / root / sidecar policy 一起进入执行路径。target 选择与 binding 选择是两回事：
`--target` 继续决定目标语义，`--toolchain-binding` 只决定同一 host/target pair 下由谁来
生产这些目标产物。
当前默认 production path 仍是 `bootstrap-native-assemble-link`，而且继续复用同一套
generic runner：`tools/stage0/nextpas.pas` 通过
`TCompilationSession.ExecuteToolchain(GetEnvironmentVariable('PATH'))` 调
`compiler/toolchain/np_toolchain_runner.pas`，先让宿主 FPC 以
`host-fpc-emit-asm` 生成 backend-owned `.s` 与 `<program>_link.res`，再执行
`native-assemble` 与 `native-link`。主 smoke success path 会如实投影
`toolchain-plan-family=bootstrap-native-assemble-link`、`tool-invocation-count=3`、
`primary-tool-step-id=host-fpc-emit-asm` 与 `tool-run-step-count=3`；如果根程序依赖额外的
source-backed units，plan 还会继续长出 `native-assemble-<unit>` 步骤，所以成功路径也可能是
`4+` steps，而不是再假装永远只有一步。
显式 LLVM binding 时，同一条 generic runner 会切到 `llvm-ir-opt-llc-link`：CLI 会投影
`compiler=opt`，backend artifacts 变成
`llvm-ir/llvm-bitcode/object-file/executable` 四类 truth，toolchain runner 会按
`llvm-opt-bitcode -> llvm-llc-object -> llvm-link` 执行，并通过 `ld.lld` 产出最终
executable。默认 native binding 与显式 LLVM binding 共享同一份 target facts，但不再共用
同一条 plan family。
与之并行的 `stage0 test` 当前仍然故意不重写 harness：它只做最小参数解析与 workspace root
选择，然后直接委托 `tests/run_all_tests.sh` / `tests/harness/runner.pas` 继续拥有
fixture grouping、snapshot policy、bootstrap diagnostics 与 `command=test` 结果语义。
当前 direct-link C interop 也开始进入这条 execution path：如果 logical link request 里出现
最小 `{logicalId:"c", linkageKind:"shared", strength:"strong"}`，那么
`native-assemble-link` 与 `llvm-ir-opt-llc-link` 现在会先按当前
`distribution-runtime-root` 解析 `lib/nextpas/runtime/<runtime-sdk>/libc.so`，再把
`-L<runtime-root>` 与 `-lc` 写进真实 linker argv；如果这份 runtime libc 缺失，planner 会直接
给出 `toolchain.c-library-not-found`。这条 contract 当前仍只覆盖 nextPas 自己直接拥有的
direct-link plan；默认 `bootstrap-native-assemble-link` 里的宿主 `*_link.res` 继续保持 host-owned。
当宿主 compiler emit-asm step 真正失败时，失败种类也开始对齐 backend plan 派生的
`toolchain.host-compiler-exec-failed`，不再继续暴露 driver 私有的
`compiler-launch-failed` / `build-failed` 文本。
当前仍要明确标注的残余风险已经收窄：`CompilationSession` 现在会把
`native-assemble` / `native-link` failure 归到真实失败 step，
`diagnostic-step-id`、`diagnostic-profile-id`、`diagnostic-logical-executable`、
`build-trace-ref` 与 `tool-status-events` 的 step metadata 都会跟着失败 step 走；
`build/verify_local.sh` 也已把 `assembler-failure-attribution-check` 与
`linker-failure-attribution-check` 纳入真实 gate。当前这条 surface 已进一步收口：
success path 现在也会暴露完整 multi-step transcript，并统一使用 plan-level
`build-trace-ref=trace-<session-id>-toolchain-plan`。现阶段需要继续注意的不是“有没有
transcript”，而是 success path 的 event/step 数量会跟着真实执行的
`native-assemble-<unit>` 追加步骤增长，调用方不能再把计数冻结成固定字面量。

## 当前 CLI 输出是结果语义的 human projection

`stage0 build` 的长期契约不是“stdout 上刚好出现哪几行文本”，而是它表达的统一
`CommandResultEnvelope` 语义。当前实现继续打印 line-based key/value，主要是为了让 shell、
本地回放和 CI 在第一阶段有一条可读的最小路径；这些行本身不是 canonical truth。

当前成功的 build 路径会把这些结果语义投影出来：

- `mode=build`
- `command=build`
- `selector=build`
- `source=<path>`
- `target=linux-x86_64`
- `target-config=<resolved-config-path>`
- `compiler=fpc`
- `compiler-exit=0`
- `artifact=<path-without-extension>`
- `session-id=<session-id>`
- `root-file-id=<file-id>`
- `source-db-file-count=<count>`
- `source-db-line-index=deferred`
- `unit-state-count=<count>`
- `diagnostics-count=0`
- `diagnostics-policy=default`
- `syntax-status=ready`
- `lexer-token-count=<count>`
- `green-node-count=<count>`
- `ast-root-kind=program`
- `ast-declared-name=Hello`
- `resolution-status=ready`
- `unit-graph-status=ready`
- `search-path-count=<count>`
- `resolved-unit-count=<count>`
- `unit-graph-edge-count=<count>`
- `unit-graph-root-name=Hello`
- `semantic-status=ready`
- `symbol-graph-status=ready`
- `type-graph-status=ready`
- `typed-hir-status=ready`
- `symbol-count=<count>`
- `type-count=3`
- `typed-hir-node-count=<count>`
- `runtime-contract-count=2`
- `typed-hir-root-name=Hello`
- `mir-status=ready`
- `mir-block-count=1`
- `mir-operation-count=6`
- `mir-entry-block=entry`
- `mir-root-name=Hello`
- `backend-plan-status=ready`
- `backend-output-kind=executable`
- `backend-primary-artifact-kind=executable`
- `backend-primary-artifact-path=<workspace-root>/.nextpas/out/linux-x86_64/hello`
- `backend-artifact-count=3`
- `backend-artifacts=<json>`
- `host-id=linux-x86_64`
- `toolchain-binding-id=linux-x86_64-to-linux-x86_64-gnu`
- `backend-family=native`
- `assembler-profile-id=gnu-as`
- `linker-profile-id=gnu-ld`
- `archiver-profile-id=gnu-ar`
- `resource-tool-profile-id=none`
- `target-object-format=elf`
- `target-assembler-flavor=gnu-as`
- `target-linker-flavor=gnu-ld`
- `target-runtime-layout-key=target-sdk-split`
- `target-c-symbol-prefix=`
- `target-c-library-naming=lib-prefix-so-a`
- `target-llvm-triple=x86_64-unknown-linux-gnu`
- `target-llvm-data-layout=e-p:64:64:64-...-S128`
- `sysroot-mode=runtime-sdk`
- `runtime-sdk-id=linux-x86_64`
- `allow-host-fallback=false`
- `tool-root-kind=distribution-helper-root`
- `runtime-root-kind=distribution-runtime-root`
- `response-file-policy=auto`
- `link-script-policy=when-required`
- `toolchain-plan-status=ready`
- `toolchain-plan-family=bootstrap-native-assemble-link`
- `tool-profile-root=<workspace-root>/build/tool_profiles`
- `logical-link-request-status=ready`
- `logical-link-request-output-kind=executable`
- `logical-link-request-library-count=0`
- `logical-link-request=<json>`
- `llvm-toolchain-status=disabled`
- `llvm-executable-set-id=llvm-stable`
- `llvm-executable-set=<json>`
- `tool-invocation-count=3`
- `primary-tool-role=host-compiler`
- `primary-tool-profile-id=fpc-stage0-host`
- `primary-tool-step-id=host-fpc-emit-asm`
- `primary-tool-logical-executable=fpc`
- `primary-tool-sysroot-ref=runtime-sdk:linux-x86_64`
- `primary-tool-failure-mapping=toolchain.host-compiler-exec-failed`
- `tool-run-status=success`
- `tool-run-step-count=3`
- `primary-tool-run-status=success`
- `tool-invocation-plan-ref=plan-<session-id>-primary-tool`
- `tool-invocation-plan=<json>`
- `tool-status-event-count=10`
- `tool-status-events=<json>`
- `diagnostics-summary=none`
- `lifecycle-session=source-db,target-facts,diagnostics-sink,compilation-options`
- `lifecycle-unit=root-input-state`
- `lifecycle-stage=syntax:ready,resolution:ready,sema:ready,ir:ready,backend:ready`
- `build-trace-ref=trace-<session-id>-toolchain-plan`
- `build-trace=<json>`
- `status=success`
- `result=success`
- `command-outcome=success`
- `build-result=success`
- `command-envelope=<json>`
- `human-summary=build succeeded`

这些字段现在对应的是命令级 outcome、输入定位、目标定位、宿主编译器事实，以及当前
compiler session skeleton 的 owned truth 摘要。`command-envelope=<json>` 里的
`result` 当前也会同步带上 camelCase 版本：
`workspaceRoot`、`workspaceDiscoveryKind`、`workspaceDescriptorPath`、
`packageManifestPath`、`artifactRoot`、`outputDir`、
`backendArtifactCount`、`backendArtifacts`、
`assemblerProfileId`、`linkerProfileId`、`archiverProfileId`、
`resourceToolProfileId`、`toolRootKind`、`runtimeRootKind`、
`responseFilePolicy`、`linkScriptPolicy`、`toolchainPlanStatus`、
`toolchainPlanFamily`、`toolProfileRoot`、`logicalLinkRequestStatus`、
`logicalLinkRequestOutputKind`、`logicalLibraryRequestCount`、`logicalLinkRequest`、
`llvmToolchainStatus`、`llvmExecutableSetId`、`llvmExecutableSet`、`toolRunStatus`、
`toolRunStepCount`、`primaryToolRunStatus`、`diagnosticErrorCount`、
`diagnosticWarningCount`、`searchIndexStatus`、`indexedSearchRootCount` 与
`searchIndexScanCount`。
后续即使 CLI 渲染形式调整，调用方也应该继续把它们理解为统一 envelope 的人类可读投影，
而不是另起一套只服务 shell 的私有协议。

上面这组带具体字面量的 success 示例默认描述的是
`linux-x86_64-to-linux-x86_64-gnu` binding。显式传入
`--toolchain-binding linux-x86_64-to-linux-x86_64-llvm` 时，同一组 surface 会改成：

- `compiler=opt`
- `toolchain-binding-id=linux-x86_64-to-linux-x86_64-llvm`
- `backend-family=llvm`
- `linker-profile-id=lld-elf`
- `backend-artifact-count=4`
- `backend-artifacts=<json>`，其中 kinds 按顺序变成
  `llvm-ir`、`llvm-bitcode`、`object-file`、`executable`
- `toolchain-plan-family=llvm-ir-opt-llc-link`
- `llvm-toolchain-status=ready`
- `llvm-executable-set-id=llvm-stable`
- `primary-tool-profile-id=llvm-stable`
- `primary-tool-step-id=llvm-opt-bitcode`
- `primary-tool-logical-executable=opt`

对 `examples/smoke/hello.pas` 这条主 smoke success path，当前真实执行是三步：

- `host-fpc-emit-asm`
- `native-assemble`
- `native-link`

如果 plan 里还包含额外 source-backed units，当前会再插入
`native-assemble-<unit>` 步骤，所以 success path 的 step count 不再被文档冻结成固定 `3`。

`session-id`、`tool-invocation-plan-ref` 和 `build-trace-ref` 当前都已经改成每次 build
唯一的 locator。它们的契约是“同一轮输出内前后一致、可以彼此引用”，而不是“永远等于某个
固定字面量”。

resolver search index 当前仍保持 lazy：

- `examples/smoke/hello.pas` 这类没有触发额外 lookup 的路径，会看到
  `search-index-status=deferred`
- `examples/smoke/hello_with_units.pas` 这类真实解析依赖单元的路径，会看到
  `search-index-status=ready`
- `tests/fixtures/root_source_precedence/root_source_precedence_smoke.pas`、
  `tests/fixtures/explicit_unit_root_smoke.pas` 以及
  `tests/fixtures/package_manifest_source_precedence/...` 这类更高优先级 root 提前命中的路径，
  会看到 `search-index-status=partial`

这不是不一致，而是在把“是否真的消费了 search roots”作为 session-owned truth 如实投影。

这里的 `partial` 不是失败语义，而是 precedence 生效后的正常状态：

- root-source 命中后，不需要再去扫 explicit / installed tiers
- package-source-root 命中后，不需要再去扫更低优先级 tiers
- explicit-unit-root 命中后，也不需要继续把 target-installed tier 再扫一遍

因此 `indexed-search-root-count` 与 `search-index-scan-count` 当前会跟随真实命中层级变化，
而不是总被伪装成“所有 root 都已扫描完”。

其中 `command-envelope=<json>` 是当前第一条 machine-readable bridge。它把
`CommandResultEnvelope` 以单行 JSON 投影到 CLI，当前会在 top-level 继续补出
`buildTraceRef`、`buildTrace`、`toolInvocationPlanRef`、`toolInvocationPlan` 与
`toolStatusEvents`，方便 shell、CI、IDE 适配器和证据采集直接消费，而不需要先从其它
key/value 行反推结果对象。
`result.logicalLinkRequest.objectInputs` 当前也已经不再是假空数组：它会引用 backend-owned
`object-file` artifact，为 future native link selection 提前冻结 object-level input truth。

失败路径当前也会在 stderr 上补出最小失败投影，例如 `status=failure`、`result=failure`、
`failure-kind=...`、`diagnostic-code=parser.syntax-error|resolver.unit-not-found|resolver.ambiguous-unit-source|resolver.unit-cycle-detected|sema.duplicate-declaration|sema.ambiguous-overload|sema.no-matching-overload|sema.wrong-argument-count|sema.invalid-call-shape|sema.unknown-callable|sema.unknown-member|toolchain.host-compiler-exec-failed`、
`diagnostic-phase=syntax|resolution|sema|toolchain`、`command-outcome=failure`、`command-envelope=<json>` 和
`human-summary=<message>`，再附上原始失败消息。

如果失败发生在 session 创建之前，stderr 仍会继续带上当前已知的
`workspace-root`、`workspace-discovery-kind`、`workspace-descriptor-path`、
`package-manifest-path`、`artifact-root`、`output-dir`；但不会伪造 `session-id`、
`diagnostics-count` 或其它 session-owned projection。

对当前 verify 已冻结的 primary-step failure baseline，stderr 还会继续补出：

- `diagnostic-id=diag-0001`
- `diagnostic-binding-id=linux-x86_64-to-linux-x86_64-gnu`
- `diagnostic-profile-id=fpc-stage0-host`
- `diagnostic-step-id=host-fpc-emit-asm`
- `diagnostic-logical-executable=fpc`
- `diagnostic-sysroot-ref=runtime-sdk:linux-x86_64`
- `diagnostic-resolved-path=<resolved-host-fpc-path>`
- `diagnostic-primary-artifact-kind=executable`
- `diagnostic-primary-artifact-path=<workspace-root>/.nextpas/out/linux-x86_64/hello`
- `diagnostic-exit-code=<non-zero>`
- `tool-invocation-plan-ref=plan-<session-id>-primary-tool`
- `tool-invocation-plan=<json>`
- `tool-status-event-count=4`
- `tool-status-events=<json>`
- `build-trace-ref=trace-<session-id>-toolchain-plan`
- `build-trace=<json>`

这条 failure baseline 当前已经不再由 `stage0` 私自维护第二套 diagnostic 对象；
它来自 `CompilationSession` 持有的 `diagnostics sink + build trace`，CLI 这里只做 projection。

当前这条最小 trace payload 现在会把全部 executed steps 按顺序真实暴露出来，而不再只留下
单步摘要。对 `examples/smoke/hello.pas` 这条主 smoke success path：

- `steps[0].stepId=host-fpc-emit-asm`，`primaryOutputs` 至少包含
  `assembly-text` 与 `linker-script`
- `steps[1].stepId=native-assemble`，`primaryOutputs` 至少包含 `object-file`
- `steps[2].stepId=native-link`，`primaryOutputs` 至少包含 `executable`
- `steps[*].sidecars[*]` 现在会携带真实执行 truth，包括
  `materialized=true|false` 与 `cleanupStatus=deleted|retained|not-requested`
- 只有真实失败的 step 会继续带上 `diagnosticRefs=["diag-0001"]`

当前这条最小 `ToolInvocationPlan` 也已经不是文档草图。它会真实暴露：

- `planKind/toolRole/bindingId/profileId/hostId/targetId/sysrootRef/planFamily`
- `steps[0].stepId=host-fpc-emit-asm`
- `steps[0].argv=["-st","-Aas","-FE<backend-cache>","-FU<backend-cache>","-Fu<root-source-dir>","-Fu<unit-root?>","-Fu<units-dir>","<abs-source-path>"]`
- `steps[0].workingDirectory=<workspace-root>/.nextpas/cache/backend/linux-x86_64`
- `steps[0].inputs=[{"kind":"pascal-source","path":"<abs-source-path>"}]`
- `steps[0].outputs` 至少包含根程序 `assembly-text` 与 `linker-script`
- `steps[1].stepId=native-assemble`，把根程序 `.s` 变成 backend-owned `.o`
- `steps[2].stepId=native-link`，通过 `<program>_link.res` 产出最终 executable
- 当存在额外 source-backed units 时，还会附加 `native-assemble-<unit>` steps

显式切到 LLVM binding 时，最小 `ToolInvocationPlan` 会改成
`llvm-ir-opt-llc-link`：

- `steps[0].stepId=llvm-opt-bitcode`，把 backend-owned `.ll` 产出为 `.bc`
- `steps[1].stepId=llvm-llc-object`，把 `.bc` 产出为 backend-owned `.o`
- `steps[2].stepId=llvm-link`，通过 `ld.lld` 产出最终 executable

当前这条最小 status event spine 已经升级成完整 executed-step transcript。
对 `examples/smoke/hello.pas` 这条三步 success path，当前真实 event 序列是：

- `toolchain.tool-selected` / `toolchain.step-started` / `toolchain.step-finished`
  for `host-fpc-emit-asm`
- `toolchain.tool-selected` / `toolchain.step-started` / `toolchain.step-finished`
  for `native-assemble`
- `toolchain.tool-selected` / `toolchain.step-started` / `toolchain.step-finished`
  for `native-link`
- `toolchain.plan-finished`

因此当前 `tool-status-event-count=10`；如果 plan 里还追加了 source-backed unit 的
`native-assemble-<unit>`，每个额外 executed step 会再多出 3 个 event，然后才进入
`plan-finished`。

失败路径里这组 transcript 也会继续按真实执行面收口：宿主 compiler failure 当前会留下
4 个 event，assembler failure 会留下 7 个 event，linker failure 会留下 10 个 event；
`tool-status-events`、`diagnostic-step-id` 与 `build-trace-ref` 全都统一对齐同一条
plan-level trace，而失败 attribution 则落在真实失败 step。

## 状态、诊断与留证边界

- `stage0` 可以把 toolchain progress 友好地投影到 CLI，但这些内容属于 status event
- 真正的失败分类属于 diagnostics，而不是把每条失败都降格成随手拼出来的日志文本
- step、artifact、sidecar 和 failure relation 的执行留证属于 build trace，不属于 `stage0`
  私有回放格式
- 当前 README 里列出的 key/value 字段，只回答命令最终结果；它们不替代 build trace 或 diagnostics

## 这条路径现在如何被验证

`build/verify_local.sh` 会复用这条公开 build 路径：先检查关键架构文档、目标规格与
`compiler/` skeleton 输入，再用
`fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/targets -Fucompiler/syntax -Fucompiler/sema -Fucompiler/ir -Fucompiler/backend -Fucompiler/toolchain -Futools/stage0 -Furtl/core/base -Furtl/core/text -FE.sisyphus/tmp/verify-local.<run>/stage0-bootstrap -FU.sisyphus/tmp/verify-local.<run>/stage0-bootstrap tools/stage0/nextpas.pas`
构建驱动入口。这个 stage0 build dir 是每次 verify 独占的 run-private 目录，避免并发
verify 互相清理同一个 `.sisyphus/tmp/stage0-bootstrap`。随后执行
`.sisyphus/tmp/verify-local.<run>/stage0-bootstrap/nextpas build examples/smoke/hello.pas --target linux-x86_64 --workspace <repo-root>` 并断言
输出里存在 `command-envelope=`、`session-id=`、`source-db-file-count=1`、`syntax-status=ready`、
`resolution-status=ready`、`semantic-status=ready`、`mir-status=ready`、
`backend-plan-status=ready`、`host-id=linux-x86_64`、
`assembler-profile-id=gnu-as`、`linker-profile-id=gnu-ld`、
`archiver-profile-id=gnu-ar`、`resource-tool-profile-id=none`、
`target-runtime-layout-key=target-sdk-split`、`sysroot-mode=runtime-sdk`、
`tool-root-kind=distribution-helper-root`、`runtime-root-kind=distribution-runtime-root`、
`response-file-policy=auto`、`link-script-policy=when-required`、
`toolchain-plan-family=bootstrap-native-assemble-link`、
`logical-link-request.objectInputs=[backend-owned <program>.o]`、
`primary-tool-profile-id=fpc-stage0-host`、`primary-tool-step-id=host-fpc-emit-asm`、
`primary-tool-logical-executable=fpc`、
`primary-tool-sysroot-ref=runtime-sdk:linux-x86_64`、
`primary-tool-failure-mapping=toolchain.host-compiler-exec-failed`、
`tool-run-status=success`、`tool-run-step-count=3`、
`primary-tool-run-status=success`、
`tool-invocation-plan.steps[*].stepId=host-fpc-emit-asm/native-assemble/native-link`、
`tool-status-event-count=10`、
`build-trace-ref=trace-<session-id>-toolchain-plan`、
`ast-root-kind=program` 和 session 相关结果字段；随后再对
`examples/smoke/hello_with_units.pas` 断言 `resolved-unit-count=4` /
`unit-graph-edge-count=4` / `typed-hir-node-count=8` / `mir-operation-count=8` /
`backend-output-kind=executable` / `toolchain-binding-id=linux-x86_64-to-linux-x86_64-gnu` /
`target-c-library-naming=lib-prefix-so-a` / `target-llvm-triple=x86_64-unknown-linux-gnu`，
再对 `examples/smoke/external_cdecl_smoke.pas` 断言
`logical-link-request-library-count=1` 与
`logical-link-request.libraryRequests=[{logicalId:"c", linkageKind:"shared", strength:"strong"}]`，
对 `tests/compiler/fail/missing_semicolon_fail.pas` 断言 `syntax-analysis-failed` /
`parser.syntax-error`，并对 missing unit / ambiguous unit / unit cycle 三类 resolution
failure 断言 `unit-resolution-failed` 基线，再对 duplicate import 语义失败断言
`semantic-analysis-failed` + `sema.duplicate-declaration`，再对
ambiguous imported callable overload 与 ambiguous member overload 断言
`semantic-analysis-failed` + `sema.ambiguous-overload`，再对 imported inherited function-result
ambiguous overload 与 current-class / inherited
implicit-self bare method ambiguous overload 断言同一组 semantic failure / diagnostic projection，再对 root-owned no matching overload 断言
`semantic-analysis-failed` + `sema.no-matching-overload`，再对 imported no matching overload 断言
同一组 semantic failure / diagnostic projection，再对 direct member no matching overload 断言
同一组 semantic failure / diagnostic projection，再对 imported inherited function-result no matching overload 断言
同一组 semantic failure / diagnostic projection，再对 imported project-source bare single-target
type mismatch 断言 `semantic-analysis-failed` + `sema.type-mismatch`，再对 root-owned 与
imported project-source bare wrong argument count 断言
`semantic-analysis-failed` + `sema.wrong-argument-count`，再对 member wrong argument count 断言
同一组 semantic failure / diagnostic projection，再对 bare/member type mismatch 及其内建标量变量/参数/函数结果形态断言
`semantic-analysis-failed` + `sema.type-mismatch`，再对 source-owned unknown bare callable 断言
`semantic-analysis-failed` + `sema.unknown-callable`，再对 known field/property member call 及 inherited known
field/property member call 断言 `semantic-analysis-failed` + `sema.invalid-call-shape`，再对 direct class unknown member
和 class method body 内 bare implicit-self unknown member 断言
`semantic-analysis-failed` + `sema.unknown-member`，再对
`tests/compiler/fail/missing_external_symbol_name_fail.pas` 断言
`semantic-analysis-failed` + `sema.missing-external-symbol-name`，再通过 fake `fpc` 负路径断言
`toolchain.host-compiler-exec-failed`、`diagnostic-binding-id`、`diagnostic-profile-id`、
`diagnostic-step-id`、`diagnostic-logical-executable`、`diagnostic-sysroot-ref`、
`diagnostic-resolved-path`、`diagnostic-primary-artifact-*`、`tool-run-status=failure`、
`tool-run-step-count=1`、`primary-tool-run-status=failed` 与 envelope 里的 structured
toolchain diagnostic；随后再通过 fake `as` / `ld` 负路径断言
`toolchain.assembler-exec-failed` / `toolchain.linker-exec-failed` 必须把
`diagnostic-profile-id`、`diagnostic-step-id`、`diagnostic-logical-executable`、
`build-trace-ref=trace-<session-id>-toolchain-plan`、`tool-run-step-count` 与
`primary-tool-run-status` 对齐到真实 executed-step transcript；同时它也会继续检查
`buildTrace.steps[*]` 必须按顺序留下全部 executed steps，且只有失败 step 才带
`diagnosticRefs`。最后 verify 还会把
`assembler-failure-attribution-check` / `linker-failure-attribution-check`
写进 verify-local success envelope；它还会把 `tests/toolchain/toolchain_contract_smoke.pas`
编译到临时 `mktemp -d` build dir，并在执行后显式断言源码树里不存在
`tests/toolchain/toolchain_contract_smoke` 与 `.o`；再对 explicit unit root /
root-source precedence / out-dir override / invalid unit root 这些路径做真实 gate，
最后通过 fake `fpc` 验证 `./tests/run_all_tests.sh --filter smoke` 的 bootstrap failure
必须带上 `bootstrap-step`、`bootstrap-command`、`bootstrap-stderr-file` 和原始 stderr
evidence，然后再跑真实 smoke。现在这份 verify 还会额外通过 fake
`opt` / `llc` / `ld.lld` 跑一条
`--toolchain-binding linux-x86_64-to-linux-x86_64-llvm` smoke，断言
`compiler=opt`、`backend-artifact-count=4`、
`toolchain-plan-family=llvm-ir-opt-llc-link` 与三步 LLVM transcript。除此之外，它也会再跑
同一个 run-private stage0 binary 的 `nextpas env status --target linux-x86_64`、
临时 workspace 下的 `nextpas env use --target linux-x86_64 --toolchain-binding ... --workspace ...`
和 `nextpas env status --target linux-x86_64 --workspace ...`、同一 workspace 下的
`nextpas env sync --target linux-x86_64 --workspace ...`、
`nextpas env clean --target linux-x86_64 --workspace ...`、裸
`nextpas env`、同一个 run-private stage0 binary 的 `nextpas doctor --target linux-x86_64`
与 package manifest fixture、workspace member fixture 下的 `nextpas doctor --workspace ...`
正向 package workspace 样本、裸 `nextpas doctor`、
同一个 run-private stage0 binary 的 `nextpas query symbols examples/smoke/hello_with_units.pas --target linux-x86_64`
与裸 `nextpas query`、
同一个 run-private stage0 binary 的 `nextpas pkg inspect --workspace "$PACKAGE_MANIFEST_FIXTURE_ROOT" --target linux-x86_64`
与 `nextpas pkg plan --workspace "$PACKAGE_MANIFEST_FIXTURE_ROOT" --target linux-x86_64`
与 `nextpas pkg graph --workspace "$PACKAGE_MANIFEST_FIXTURE_ROOT" --target linux-x86_64`
与 workspace member fixture 下的 `nextpas pkg inspect --workspace ...` 正向 package workflow
样本、workspace member fixture 下的 `nextpas pkg plan --workspace ...` lock-missing blocked
install-plan preflight 样本、package-free 临时 workspace 下的 `nextpas pkg plan --workspace ...`
manifest-missing missing preflight 样本、malformed dependency fixture 下的
`nextpas pkg plan --workspace ...` dependency-invalid blocked preflight 样本、manifest/lock ready
但 source roots 为空的 `nextpas pkg plan --workspace ...` source-roots-missing blocked preflight
样本、invalid lock fixture 下的 `nextpas pkg plan --workspace ...` lock-invalid blocked preflight
样本、out-of-sync lock fixture 下的 `nextpas pkg plan --workspace ...` lock-out-of-sync blocked
preflight 样本、package lock detail fixture 下的 `nextpas pkg inspect --workspace ...` lock detail 样本、workspace member fixture 下的
`nextpas pkg graph --workspace ...` 正向 package graph 样本、裸 `nextpas pkg`，冻结
`environment-readiness=incomplete`、
`environment-status=incomplete`、`runtime-sdk-status=missing`、
`runtime-libc-present=false`、`toolchain-binding-status=ready`、
`distribution-status=incomplete|ready`、`env-selection-status=updated|ready`、
`env-resolution-status=ready`、`env-sync-change=materialized|unchanged`、
`env-clean-status=ready`、`env-clean-change=removed|unchanged`、
`stage0EnvStatusCheck=pass`、`stage0EnvUseCheck=pass`、`stage0EnvSyncCheck=pass`、
`stage0EnvCleanCheck=pass`、`stage0EnvCleanRepeatCheck=pass`
与 `stage0EnvInvalidArgumentsCheck=pass`、`stage0DoctorCheck=pass`、
`stage0DoctorPackageWorkspaceCheck=pass`、`stage0DoctorWorkspaceMemberCheck=pass` 与
`stage0DoctorDeclaredDependenciesCheck=pass`、`stage0DoctorMalformedDependenciesCheck=pass`、
`stage0DoctorInvalidArgumentsCheck=pass`、
`query-kind=symbols`、
`analysis-source=compilation-session`、`query-result-count=<non-zero>`、
`query-bindings=<json-array>`、`query-definitions=<json-array>`、
`query-scopes=<json-array>`、`query-types=<json-array>`、
`stage0QueryCheck=pass`、`stage0QueryBindingsCheck=pass`、`stage0QueryDefinitionsCheck=pass`、
`stage0QueryMemberCallBindingsCheck=pass` 与 `stage0QueryInvalidArgumentsCheck=pass`、
`package-workflow-status=ready`、`package-manifest-status=ready`、
`package-lock-status=missing|ready|invalid`、`package-lock-format-version=<version>`、
`package-lock-entry-count=<count>`、`package-lock-entries=<json-array>`、
`package-lock-snapshot-count=<count>`、`package-lock-snapshots=<json-array>`、
`package-lock-issue-count=<count>`、`package-lock-issues=<json-array>`、
`package-workflow-manifest-path=<path>`、
`package-root-path=<path>`、`package-name=<name>`、`package-lockfile-path=<path>`、
`package-source-root-count=<count>`、`package-source-roots=<json-array>`、
`package-dependency-validation-status=valid|invalid|missing`、
`package-install-plan-status=ready|blocked|missing`、
`package-install-plan-blocker-code` /
`package-install-plan-blocker-message`、
`package-install-plan-blocker-expected-package` /
`package-install-plan-blocker-lock-entries`、
`stage0PkgCheck=pass`、`stage0PkgLockDetailCheck=pass`、`stage0PkgPlanCheck=pass`、`stage0PkgPlanBlockedCheck=pass`、
`stage0PkgPlanMissingCheck=pass`、`stage0PkgPlanDependencyBlockedCheck=pass`、
`stage0PkgPlanSourceRootsBlockedCheck=pass`、`stage0PkgPlanLockInvalidCheck=pass`、
`stage0PkgPlanLockSnapshotInvalidCheck=pass`、
`stage0PkgPlanLockTargetSnapshotMissingCheck=pass`、
`stage0PkgPlanLockOutOfSyncCheck=pass`、
`stage0PkgPlanInvalidArgumentsCheck=pass`、
`stage0PkgWorkspaceMemberCheck=pass` 与
`stage0PkgDeclaredDependenciesCheck=pass`、`stage0PkgGraphCheck=pass`、
`stage0PkgGraphInvalidArgumentsCheck=pass`、
`stage0PkgMalformedDependenciesCheck=pass`、`stage0PkgInvalidArgumentsCheck=pass`，确保当前最小
`env` / `doctor` / `query` / `pkg` surface 也进入正式 gate。

这意味着本地验证与 Linux CI 不应该再各自拼装另一套 `stage0` 成功路径。

## 这里现在不做什么

- 除了 `env status/use/sync/clean` 与只读 `doctor` 之外，不承诺更深的 environment mutation verbs，例如
  `env bootstrap`、download/unpack/install 或 `env gc`。
- `query symbols` 当前只是 compilation-session-backed 的最小 CLI 查询，不承诺完整
  language service、LSP 或 IDE 集成。
- `pkg inspect / pkg plan / pkg graph` 当前只是 workspace-model-backed 的最小只读投影，
  不承诺完整 package manager、fetch/install/update/publish workflow 或 dependency resolution。
- 不在这里塞入格式化、LSP 或 IDE 集成。
- 不把多目标矩阵提前做进 CLI 表面。
- 不绕过 `build/targets/` 目标规格边界，直接把完整平台模型做死在这里。
