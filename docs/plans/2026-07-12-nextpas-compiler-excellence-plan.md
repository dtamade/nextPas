# nextPas Compiler Excellence Roadmap

> Version: 1.0
> Date: 2026-07-12
> Status: active program roadmap
> Current proven maturity: AL1; historical AL2 claims are under live revalidation
> Promotion target: AL2 convergence, then an AL3 self-hosted production compiler
> Engineering target: Rust-like internal rigor with Go-like build feedback

This roadmap is the active execution plan for compiler correctness, bootstrap,
and performance work. It decides what to do next and what evidence is required
before a capability is promoted. It does not override accepted decisions or
stable ownership rules: conflicts are resolved in favor of `docs/adr/` and
`docs/architecture/`.

`docs/plans/compiler-architecture-plan.md` remains a historical v2.2 snapshot.
Its measurements and commit history are useful, but its completion markers are
not current promotion evidence. `docs/plans/selfhost-roadmap.md` and
`docs/plans/debt-roadmap.md` retain their v3.0-era history; this plan supersedes
their execution order and stale SIMD/full-scan blocker claims.

## Make the product decision explicit

nextPas will follow a hybrid strategy:

- Borrow Rust's typed identities, query dependency model, semantic snapshots,
  structured diagnostics, MIR verification, and explicit compiler/runtime
  contracts.
- Borrow Go's simple build ownership, package-DAG parallelism, content-addressed
  reuse, fast startup, predictable command behavior, and strict latency focus.
- Keep Pascal-specific unit initialization, `System`, managed types, ABI, and
  object-model semantics explicit. Do not hide them behind a generic compiler
  abstraction copied from another language.

The priority order is fixed:

1. Correct compiler behavior and honest gates.
2. A reproducible bootstrap spine.
3. Maintainable ownership and deterministic data flow.
4. Measured cold, warm, incremental, and generated-code performance.
5. Internal language-service reuse.
6. Public LSP, formatter workflow, and IDE integration.

Public tooling work cannot move ahead of the compiler truth it consumes.

## Reset the live baseline

The repository contains several useful components, but a component existing is
not the same as a production capability.

| Surface               | Live state on 2026-07-12                                                                                                                | Promotion gap                                                                                 |
| --------------------- | --------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| Compiler/System cache | Canonical System source-backed bypass committed at `d41bb0259`; focused gate passes                                                     | Cold and immediate-warm full compiler gates, landing replay                                   |
| `compiler-pass`       | Last pre-cache full run was 51/53                                                                                                       | Fresh run; repair `classes_pass`; verify `generic_ctor_propagation_pass` warm recovery        |
| Compiler rebuild      | `scripts/rebuild-compiler.sh` contains only cleanup lines and undefined variables                                                       | Restore one canonical, hermetic build entry                                                   |
| Green tree            | Record-index facade, compact node/child storage, frozen after parse                                                                     | Profile allocation/text-copy costs; finish builder-side data discipline                       |
| Semantic model        | Typed symbols/types/bindings exist; System identity guards improved                                                                     | Remove process-global imported-unit semantic cache authority; freeze snapshot ownership       |
| Query database        | O(n) string/object array with prefix invalidation                                                                                       | Typed keys, revisions, dependency edges, cycles, ownership, concurrency                       |
| Incremental cache     | nextPas compiler cache (NPC) serialization exists, but fingerprint framing is inconsistent and root callers pass empty dependency lists | M0 versioned round-trip/fail-closed repair; M4 dependency fingerprints and invalidation proof |
| Parallel scheduler    | Standalone task-state model; batch selection has no dependency-readiness check or build-path caller                                     | Worker execution, dependency readiness, cancellation, deterministic commit order              |
| MIR                   | Duplicated opt-in side path; session reports MIR ready when disabled and backend rebuilds its own HIR/MIR                               | One verified default MIR input, parity gate, translation validation, pass soundness           |
| Backend               | LLVM and toolchain planning surfaces exist                                                                                              | One default MIR-to-codegen spine, stable artifact truth, code-quality budgets                 |
| Performance benchmark | Tiny programs measured once; failures are swallowed, unsupported targets are timed, and stale IR can be read                            | Reproducible corpus, fail-closed runner, distributions, process-tree RSS, comparisons         |
| Self-hosting          | Frontend/module probe only; no executable B/C evidence                                                                                  | M2 A to B to C viability, then M7 reproducibility and release evidence                        |

Until a row wins its promotion gate, status language must use `skeleton`,
`experimental`, or `integrated`, not `complete` or `production-ready`.

## Map milestones to the stable architecture

The following diagram is an execution projection of
`docs/architecture/compiler-pipeline-specification.md`,
`docs/architecture/runtime-bootstrap-specification.md`, and related stable
specifications. Names marked as proposed are working plan names. They require an
accepted architecture-document or ADR update before production implementation.

```text
Command / Workspace request
  -> proposed WorkspaceBuildCoordinator
      -> CompilationSession (current per-build owner)
          -> SourceDatabase + immutable source snapshots
          -> proposed typed QueryEngine
              -> syntax(file, revision)
              -> unit_graph(root, target, revision)
              -> semantic_snapshot(unit, revision)
              -> typed_hir(unit, revision)
              -> mir(unit, opt_level, revision)
          -> BuildGraph scheduler
          -> MIR verifier + deterministic pass pipeline
          -> CodegenAdapter(MIR, TargetFacts)
          -> ToolchainPlan
          -> Artifact manifest + structured diagnostics

Canonical System source
  -> checked target projection
  -> semantic System snapshot
  -> typed np.system.* contracts
  -> MIR/runtime lowering
```

The dependency direction is one-way:

```text
syntax -> frontend identities -> sema -> HIR -> MIR -> backend -> toolchain
                              \-> diagnostics <- every phase
targets ----------------------------------------------------^
rtl/core/system <---------- typed runtime contracts ----------
```

No lower layer may call back into a higher layer to recover facts that should
already be present in its input.

## Plan owner migrations without redefining stable boundaries

| Owner                           | Owns                                                                        | Must not own                                             |
| ------------------------------- | --------------------------------------------------------------------------- | -------------------------------------------------------- |
| `SourceDatabase`                | canonical paths, `FileId`, revisioned immutable text, line index            | semantic symbols, backend artifacts                      |
| Syntax                          | tokens, lossless green tree, AST facade, syntax diagnostics                 | scope/type facts, target policy                          |
| Resolver                        | normalized `UnitId`, search-root indexes, `UnitGraph`, provenance           | semantic types, compilation of every indexed file        |
| Proposed query engine           | typed query keys, dependency edges, revisions, memo ownership, invalidation | language semantics or protocol projection                |
| Semantic snapshot               | symbols, scopes, canonical types, bindings, constants, runtime contracts    | mutable syntax, LLVM strings, process-global cache state |
| HIR                             | typed language semantics and explicit runtime operations                    | target-specific instruction choices                      |
| MIR                             | control/data flow, temporaries, cleanup points, target-neutral operations   | name resolution, Pascal syntax recovery                  |
| Backend                         | `MIR + TargetFacts` to codegen request/artifact result                      | second type system, second target database               |
| Toolchain                       | executable discovery, invocation, outputs, failure attribution              | semantic fallback or hidden source discovery             |
| Canonical System source         | compiler-root declarations in `rtl/core/system/System.pas`                  | target-specific edits or executable runtime behavior     |
| Installed System projection     | checked target copy consumed by resolution                                  | independent semantic authority or hand edits             |
| Typed System contract inventory | stable `np.system.*` identities and compiler/runtime mapping                | runtime implementation or stringly lowering rules        |
| System runtime implementation   | process/object/managed/unit lifecycle execution                             | source resolution or compiler semantic decisions         |

The existing architecture documents remain authoritative for these roles. M3
must first accept any new workspace/query owner names into the stable
architecture before code depends on them.

## Define completion as four independent proofs

Every promoted capability needs all four columns.

| Proof       | Required evidence                                                                               |
| ----------- | ----------------------------------------------------------------------------------------------- |
| Integration | The normal `nextpas build` or self-host path executes it without a hidden environment switch    |
| Correctness | Focused RED/GREEN regression plus affected compiler pass/fail gates                             |
| Determinism | Cold/warm/repeated/parallel results have equivalent diagnostics, semantic hashes, and artifacts |
| Performance | Reproducible benchmark shows the intended gain without violating correctness or memory budgets  |

Unit tests alone prove implementation behavior. They do not prove production
integration. A status field or projected count alone proves reporting. It does
not prove the reported compiler stage owns the final artifact.

## Make promotion vocabulary executable

Roadmap gates use these definitions until a stable specification replaces them:

- A **canonical semantic snapshot** is a versioned, deterministically sorted
  serialization of unit identities, declarations, symbols, canonical type
  relations, bindings, constants, diagnostics, and `np.system.*` contracts. It
  excludes addresses, timestamps, allocation order, and cache-hit metadata.
- A **semantic hash** is SHA-256 over the canonical semantic snapshot bytes.
- **Artifact equivalence** means byte identity first. If the format has declared
  nondeterministic fields, the gate compares a versioned normalized form and
  lists every ignored field in the report. An ad hoc text filter is not enough.
- The **bootstrap equivalence report** is a versioned machine-readable record of
  the B/C command envelopes, semantic hashes, diagnostics, public symbols,
  artifact comparisons, and runtime results required by M2 and M7. Slice 9 adds
  `tests/tooling/test_compiler_bootstrap_equivalence_contract.sh` to freeze and
  reject incomplete report fields.
- A **self-hosted generation** means the preceding nextPas generation owns
  parsing, semantic analysis, lowering, and code generation for that generation's
  Pascal sources. External assembler/linker tools are allowed and recorded; a
  host Pascal compiler may build A but may not compile any B/C source.
- A **stable compiler kernel** means every M3 exit gate is green on the commit
  being promoted. File presence or unit-test-only evidence is insufficient.
- **Useful four-core speedup** means at least 1.5x p50 wall-time speedup over the
  one-worker run on the 100-unit workspace corpus, with no p95 regression and
  within the PERF-P1 RSS budget.
- The **pinned environment** is the host/tool/corpus/cache profile recorded in
  the accepted benchmark or bootstrap manifest. A machine name without exact
  versions and hashes is not a pinned environment.

## Establish architecture budgets

These budgets are migration gates, not reasons for mechanical rewrites.

| Budget                            | Gate                                                                                         |
| --------------------------------- | -------------------------------------------------------------------------------------------- |
| Dependency cycles                 | Zero cycles between syntax, sema, IR, backend, and toolchain owner families                  |
| Global mutable semantic state     | Zero by M3; caches live under session/workspace owners                                       |
| String identity in core semantics | Names are interned/projection data; stable typed IDs are the internal identity               |
| New coordinator methods           | Prefer <= 80 lines; >150 lines requires extraction or an explicit complexity note            |
| New owner units                   | Prefer <= 1,500 production lines; >2,000 lines requires a split plan                         |
| Include files                     | No new cross-owner include that depends on another owner's private fields                    |
| Diagnostics                       | No compiler phase writes user-facing errors directly to stdout/stderr                        |
| Cache schemas                     | Versioned, bounded, defensive reads; corrupt entries fail closed and can be removed safely   |
| MIR passes                        | Verifier before/after, deterministic ordering, mutation test, and differential runtime proof |
| Resource ownership                | Every model/cache/thread/artifact owner has explicit construction, transfer, and teardown    |

Existing files above a budget are migration inputs, not automatic failures.
New work must not increase the debt without a reviewed reason.

## Build a trustworthy benchmark before optimizing

The benchmark runner must fail when compilation fails. It must never use
`|| true` around the operation being measured.

### Standard corpora

| Corpus               | Purpose                                                                                      |
| -------------------- | -------------------------------------------------------------------------------------------- |
| Startup              | Empty and single-unit programs; driver/session initialization cost                           |
| Frontend 10K/100K/1M | Generated valid Pascal with controlled token, declaration, generic, and control-flow density |
| Workspace DAG        | 10, 100, and 500 units with configurable fan-out and depth                                   |
| Semantic stress      | Overloads, generics, class hierarchies, managed types, and cross-unit bindings               |
| Codegen              | Numeric kernels, strings, allocation, virtual calls, records, exceptions, and collections    |
| Bootstrap            | Compiler modules and canonical compiler executable                                           |

### Measurement modes

- Fresh process cold build with empty cache.
- Fresh process warm build with valid persistent cache.
- Same-process no-op query.
- Leaf-unit edit.
- Public-interface dependency edit.
- Root-only implementation edit.
- Parallel runs at 1, 2, 4, and available host cores.
- Debug, release, and optimized codegen profiles.

Each recorded result includes compiler commit, dirty state, host CPU, core count,
RAM, OS, FPC/Go/Rust/LLVM versions, corpus hash, options, compiler-cache state,
OS page-cache policy, and output artifact hash. Cold means an empty isolated
compiler cache; it does not silently imply a cold OS page cache. Recreate the
declared cache state for every sample.

Use three unmeasured warmups for stable warm modes. Use at least 30 measured
samples for latency and incremental modes, and at least 10 for large cold or
bootstrap modes. Publish p95/p05 only with at least 30 samples. Report p50 and
p95 for lower-is-better metrics, p50 and p05 for higher-is-better metrics,
minimum, maximum, CPU time, wall time, and peak RSS.

FPC is the direct compatibility and performance gate. Go and Rust are reference
envelopes on equivalent native corpora; cross-language results are not treated
as identical-workload proof.

The FPC suite compiles the same Pascal corpus with matched optimization, debug,
range-check, strip, link, target, and worker settings. Go/Rust use separate
algorithmic corpora with matched inputs, outputs, and thread budgets. Their
results are directional and never enter an FPC promotion aggregate.

### Performance budgets

The first accepted benchmark run freezes baseline B0. Until B0 exists, no
absolute speed claim is valid.

Compiler throughput means accepted source bytes and tokens per wall second on
the same generated Pascal corpus. The B0 regression guard applies independently
to every matrix cell. For lower-is-better latency/resource cells, p50 must be
<= 1.05 x B0 and p95 <= 1.10 x B0. For higher-is-better throughput cells, p50
must be >= 0.95 x B0 and p05 >= 0.90 x B0. Baselines are never silently rebased.

#### Build-feedback latency

| Envelope                     | Startup p95 | Cold build             | Fresh-process warm p95 | Same-process no-op p95 | Leaf edit p95 | Public-interface edit p95 | Implementation-only edit p95 |
| ---------------------------- | ----------- | ---------------------- | ---------------------- | ---------------------- | ------------- | ------------------------- | ---------------------------- |
| PERF-P1 parallel-ready       | <= 150 ms   | >= 0.8x FPC throughput | <= 250 ms              | <= 50 ms               | <= 500 ms     | <= 1,500 ms               | <= 500 ms                    |
| PERF-P2 production self-host | <= 100 ms   | >= FPC throughput      | <= 150 ms              | <= 25 ms               | <= 300 ms     | <= 750 ms                 | <= 300 ms                    |
| PERF-L Leadership            | <= 50 ms    | >2.0x FPC throughput   | <= 100 ms              | <= 10 ms               | <= 200 ms     | <= 500 ms                 | <= 200 ms                    |

#### Resource and size budgets

Peak RSS is the maximum for the full compiler/toolchain process tree, including
FPC, assembler, linker, and LLVM children. Prefer a cgroup-v2 `memory.peak`
measurement; a parent-process-only RSS sample is not promotion evidence.
Compiler distribution size is compared only against a baseline with the same
declared feature manifest; a smaller binary that drops required capabilities is
a correctness failure, not an optimization.

| Envelope                     | Process-tree peak RSS | Compiler distribution size           | Generated artifact size |
| ---------------------------- | --------------------- | ------------------------------------ | ----------------------- |
| B0 regression guard          | <= 1.10x B0           | <= 1.10x B0                          | <= 1.10x B0             |
| PERF-P1 parallel-ready       | <= 1.25x FPC          | <= 1.10x same-feature baseline       | <= 1.15x FPC `-O2`      |
| PERF-P2 production self-host | <= 1.10x FPC          | <= 1.10x same-feature baseline       | <= 1.10x FPC `-O2`      |
| PERF-L Leadership            | <= FPC                | <= PERF-P2 complete-feature baseline | <= FPC `-O2`            |

#### Self-owned generated-code quality

The default native path currently delegates source compilation to the host FPC.
Its runtime score measures adapter end-to-end behavior only and cannot promote
nextPas codegen. A generated-program score counts only when the artifact manifest
identifies a nextPas-owned MIR/LLVM path and proves host FPC did not compile the
measured source.

Generated-program runtime is the geometric mean of per-case throughput normalized
to FPC `-O2`; every case and artifact size is also reported.

| Envelope                     | Runtime geometric mean | Worst case         | Artifact size      |
| ---------------------------- | ---------------------- | ------------------ | ------------------ |
| M6 MIR promotion             | >= 0.90x FPC `-O2`     | no case <0.85x FPC | <= 1.20x FPC `-O2` |
| PERF-P2 production self-host | >= 0.95x FPC `-O2`     | no case <0.90x FPC | <= 1.10x FPC `-O2` |
| PERF-L Leadership            | >1.0x FPC `-O2`        | no case <0.90x FPC | <= FPC `-O2`       |

The B0 harness must create a versioned benchmark manifest under
`.sisyphus/evidence/compiler-bench/` containing the host profile, corpus hashes,
commands, metrics, and tool versions. Slice 6 adds
`tests/tooling/test_compiler_benchmark_manifest_contract.sh` to validate its
schema and reject missing/invalid fields. PERF-P1/PERF-P2 become promotion gates
only after that tracked contract test passes; before then they are draft targets. The
accepted manifest hash, schema version, corpus hash, and environment identity are
committed with the promotion dashboard because `.sisyphus/` itself is ignored.
Changing host, compiler/toolchain version, corpus, or schema creates a new named
baseline; it does not rewrite B0. A faster result that changes diagnostics,
semantic hashes, or runtime results is a correctness failure.

## M0: Restore compiler truth

**Effort band:** 2 to 4 weeks

**Goal:** Make the current compiler gate, build entry, and roadmap describe the
same executable reality.

### Deliverables

1. Land canonical System TypeId, parent-graph, and source-backed cache fixes.
2. Repair or version-isolate the NPC header/fingerprint framing mismatch; add
   save-load round-trip, wrong-fingerprint, truncated, corrupt-length, and
   hostile-count fail-closed regressions.
3. Replace the fail-open incremental regression script with a mandatory harness
   group that fails on missing stage0, failed compilation, missing artifacts,
   corrupt cache entries, or clean/incremental semantic drift.
4. Isolate compiler test/build cache roots from other worktrees and from each
   cold/warm sample.
5. Run fresh `compiler-pass`; repair `classes_pass` and any remaining warm-only
   cache regression.
6. Keep `compiler-fail` snapshots stable and add regressions for every fix.
7. Restore `scripts/rebuild-compiler.sh` as the single hermetic stage0 compiler
   build entry.
8. Record exact stage0, self-compile, System source-contract, and hygiene truth.
9. Replace stale SIMD full-scan and `53/53` status claims with fresh gate
   evidence wherever they still appear as current truth.

### Exit gate

M0 slice 2 must create and register the `compiler-incremental` harness group.
The command below does not exist at roadmap authoring time and cannot be counted
as evidence until the group rejects missing stage0, failed compilation, and
missing artifacts.

```text
make test-compiler-system-intrinsics
make test TEST_FILTER=compiler-incremental
make test TEST_FILTER=compiler-pass
make test TEST_FILTER=compiler-fail
make rebuild-compiler
make hygiene
```

Cold and immediate-warm compiler-pass results must match. The gate must report
fixture counts and failures, not only a shell exit code.

### Non-goals

- No query engine rewrite.
- No public language service.
- No performance claim from the current microbenchmark.

## M1: Stabilize the compiler/System bootstrap spine

**Effort band:** 2 to 4 weeks
**Depends on:** M0

**Goal:** Make compiler-root `System` types, semantic ownership, runtime
contracts, and target projection one reproducible handshake across the four
explicit owner layers.

### Deliverables

1. Keep `rtl/core/system/System.pas` canonical and target units generated only
   by the checked projection command.
2. Replace magic runtime strings at semantic/HIR boundaries with typed contract
   identities.
3. Define a canonical System semantic snapshot or an explicit source-only
   policy until the general cache schema can represent it losslessly.
4. Remove remaining duplicate intrinsic seeds and reject non-System direct
   self-alias cycles with stable diagnostics.
5. Freeze object lifecycle, managed strings, arrays, interfaces, unit init/fini,
   process init/fini, allocation, faults, and halt contracts.
6. Prove compiler and System consumer gates together before every landing.

### Exit gate

- Canonical and installed System bytes match.
- Cold/warm canonical semantic hashes match.
- Every `np.system.*` entry has declaration owner, HIR evidence, runtime mapping,
  failure behavior, and focused test evidence.
- No compiler analysis depends on host FPC's implicit System semantics.

## M2: Prove executable two-hop self-host viability

**Effort band:** 2 to 4 weeks
**Depends on:** M0 and M1

**Goal:** Prove the current compiler can produce and execute two successive
compiler generations before large owner, query, parallel, or MIR migrations.

### Deliverables

1. Build generation A through the canonical pinned-FPC stage0 entry.
2. Use A's nextPas-owned frontend and minimum O0 codegen path to compile one
   declared compiler/System/runtime closure and link executable generation B;
   do not hand B sources to the host FPC adapter.
3. Use B's nextPas-owned frontend/codegen path to build the same declared closure
   into executable generation C from a clean artifact root.
4. Use one immutable source manifest for A, B, and C, with isolated cache,
   object, and executable roots for every generation.
5. Record source manifest, target facts, options, toolchain versions, commands,
   codegen owner, process invocation tree, outputs, and artifact hashes for every
   generation.
6. Run the same `query symbols`, build-smoke, compiler-pass, compiler-fail, and
   runtime-smoke acceptance set through B and C.
7. Define an early equivalence report over command envelopes, diagnostics,
   accepted/rejected fixtures, public symbols, and runtime results. Bit identity
   is recorded when available but is not required at this milestone.

### Exit gate

- A to B to C completes without editing generated projections or using a host
  Pascal compiler over B/C sources.
- The B/C invocation manifests contain no host Pascal compiler step over B/C
  source; external assembler/linker steps remain explicit.
- B and C are executable and pass the declared identical acceptance set.
- Repeating M2 from empty compiler-cache and artifact roots yields the same
  equivalence report.
- Query, incremental, parallel, and optimized MIR production paths are not
  prerequisites for this viability proof.

## M3: Turn the compiler skeleton into a kernel

**Effort band:** 4 to 6 weeks
**Depends on:** M2; design work may overlap late M1

**Goal:** Establish small owner APIs, canonical IDs, immutable snapshots, and
session-scoped resource ownership before adding concurrency.

### Deliverables

1. Accept the workspace coordinator, typed query owner, and snapshot ownership
   update in `docs/architecture/` or an ADR before implementation depends on the
   proposed names.
2. Keep `CompilationSession` as the explicit per-build owner of source,
   diagnostics, resolver, semantic, cache, and cancellation state; introduce a
   workspace owner only through that accepted boundary.
3. Remove process-global imported-unit semantic cache authority and keep
   query/memo state under explicit session or workspace owners.
4. Introduce stable `FileId`, `UnitId`, `SymbolId`, `TypeId`, `DefId`, and
   `RevisionId` contracts with checked bounds.
5. Split semantic mutation from immutable consumer snapshots.
6. Build indexes once when snapshots seal; consumers do not repeat O(n)
   `SameText` scans.
7. Replace repeated hot-path string concatenation with interners, builders, or
   buffered emitters after profiling confirms the locations.
8. Add dependency-direction and global-state source-contract gates.

### Exit gate

- Zero process-global mutable semantic caches.
- Cold, warm, and repeated semantic snapshot hashes match.
- Every public mutation API rejects invalid IDs and preserves prior state.
- The normal compiler path consumes sealed semantic truth without reparsing or
  rebinding in lower layers.

## M4: Implement a real typed query and incremental engine

**Effort band:** 6 to 9 weeks
**Depends on:** M1 contract schema and M3 owner/identity boundaries

**Goal:** Replace string-prefix memoization and empty dependency fingerprints
with typed, revisioned, dependency-aware queries.

### Deliverables

1. Define a closed `TQueryKind` and typed key payloads for syntax, unit graph,
   exports, semantic snapshot, HIR, and MIR.
2. Record parent-to-child query dependencies during evaluation.
3. Detect query cycles and emit stable diagnostics with the dependency path.
4. Track workspace revision, file content hash, target facts, compiler options,
   imported public-interface hash, and runtime-contract fingerprint.
5. Invalidate only affected reverse dependencies.
6. Version the persistent cache with bounded readers and atomic writes.
7. Separate memory memo ownership from persistent artifact storage.
8. Prove full/incremental semantic and artifact equivalence.

### Exit gate

- Dependency edits invalidate all consumers and no unrelated units.
- Implementation-only edits do not invalidate unrelated public dependents.
- Corrupt, old-version, truncated, and hostile-size cache entries fail closed.
- Cache-hit metrics come from typed query events, not inferred elapsed time.
- Warm and incremental outputs match clean builds byte-for-byte where the
  artifact is deterministic, otherwise by matching semantic hashes under the
  accepted canonical snapshot schema.

## M5: Add deterministic parallelism and data-oriented performance

**Effort band:** 4 to 7 weeks
**Depends on:** M4

**Goal:** Execute independent unit/query work concurrently without changing
diagnostics, initialization order, artifacts, or cache state.

### Deliverables

1. Build readiness levels from real dependency edges, not topological order
   alone.
2. Implement a bounded worker pool with cancellation and failure propagation.
3. Separate parallel computation from deterministic commit/diagnostic order.
4. Make query memo tables and allocators concurrency-safe by ownership or
   partitioning before adding locks.
5. Add per-session and per-unit arenas with bulk teardown.
6. Intern identifiers, unit names, paths, and common type signatures.
7. Profile and remove repeated array growth, linear ID lookup, and emitter
   string concatenation on measured hot paths.

### Exit gate

- 1-thread and N-thread semantic hashes, diagnostics, artifacts, and init order
  are equivalent across 100 stress repetitions.
- Thread/race failures cancel dependent work and retain complete diagnostics.
- Four-core workspace builds show useful speedup without exceeding RSS budget.
- The PERF-P1 parallel-ready envelope passes through the accepted benchmark
  manifest and contract.

## M6: Make MIR the production optimization boundary

**Effort band:** 7 to 11 weeks
**Depends on:** M3; production promotion depends on M4/M5 determinism

**Goal:** Remove the opt-in status and make verified MIR the single default
input to code generation.

### Deliverables

1. Complete Pascal value, pointer, managed, exception, object, closure, generic,
   unit-lifecycle, and runtime-contract operations in HIR and MIR.
2. Strengthen the MIR verifier for ID ownership, CFG edges, terminators,
   dominance/use-before-def, operand types, cleanup, and target-neutrality.
3. Run the verifier before and after every pass in debug/test profiles.
4. Define O0/O1/O2 pass pipelines with deterministic pass ordering.
5. Add translation validation and differential execution against the current
   trusted path for every promoted operation family.
6. Make the backend consume the session's verified `TMirModule` instead of
   rebuilding a second HIR/MIR path from `TSemanticModel`.
7. Make MIR codegen the default behind a reversible release switch; remove the
   old direct path only after parity evidence.
8. Measure each optimization by generated-code size and runtime, not by pass
   count.

### Exit gate

- Normal `nextpas build` uses MIR without `NEXTPAS_MIR=1`.
- All compiler pass/fail and runtime suites pass through MIR.
- Disabling any promoted lowering or verifier rule makes its focused gate fail.
- The default MIR path satisfies the B0 regression guard and the M6
  self-owned-codegen envelope.

## M7: Promote self-hosting to a reproducible product path

**Effort band:** 4 to 8 weeks
**Depends on:** M2, M4, M5, and production-ready M6

**Goal:** Turn the M2 viability proof into the deterministic, performant,
rollbackable build path used to produce a compiler distribution.

### Deliverables

1. Extend M2 from its declared minimum closure to every required
   compiler/System/runtime module in the release manifest.
2. Build A with the pinned FPC stage0 toolchain, use A's self-owned production
   path to compile/link B, and use B to build C from clean isolated roots.
3. Compare B and C through artifact equivalence, semantic hashes, public
   symbols, diagnostics, and the runtime suite.
4. Record toolchain versions, target facts, cache state, inputs, artifact hashes,
   and exact invocation plans.
5. Add clean-room, immediate-repeat, and parallel-determinism bootstrap gates.
6. Produce a minimal rollbackable compiler distribution.
7. Meet the PERF-P2 production self-host performance envelope.

### Exit gate

- A to B to C completes without undocumented host semantic fallback.
- The production B/C invocation manifests prove no host Pascal compiler read or
  compiled B/C source.
- B and C satisfy the bootstrap equivalence report requirements.
- Repeated clean builds are reproducible under the pinned environment.
- The compiler can rebuild itself through the canonical root Makefile entry.
- The release manifest, equivalence report, and benchmark manifest are complete
  enough to reproduce or reject promotion without reading shell transcripts.

## M8: Build the internal modern tooling core

**Effort band:** 6 to 10 weeks
**Depends on:** M4 and the accepted M3 compiler kernel; public adapters remain
later

**Goal:** Reuse compiler snapshots for interactive analysis without creating a
second parser, resolver, semantic model, or workspace graph.

### Deliverables

1. `LanguageServiceSession` owns revision, overlays, cancellation, and immutable
   compiler snapshots.
2. Definition, references, hover, completion, rename, and diagnostics consume
   typed semantic/query results.
3. Formatter core consumes lossless syntax/trivia and emits deterministic edits.
4. `nextpas test` consumes the canonical workspace/build graph and harness
   evidence contract.
5. Stale revisions cannot publish diagnostics or query results.

### Exit gate

- Interactive queries do not reparse or rebind unchanged files.
- Overlay close returns to disk truth without stale results.
- Formatter is deterministic, idempotent, syntax preserving, and directive safe.
- No public LSP server is required for this milestone.

## M9: Pursue performance leadership

**Effort band:** continuous after M5; leadership promotion depends on M6/M7

**Goal:** Beat the pinned FPC baseline while retaining a simpler and more
predictable compiler than a direct rustc clone.

### Workstreams

- Profile-guided query granularity and cache layout.
- Faster interning, compact IDs, sealed vectors, and arena recycling.
- Buffered LLVM emission or direct LLVM API integration when measured useful.
- Target-aware inlining, devirtualization, escape analysis, bounds-check
  elimination, vectorization, and managed-type optimization.
- PGO/LTO profiles for compiler executable and generated programs.
- Startup and distribution-size reduction.

Each optimization starts with a benchmark and a semantic mutation test. Keep it
only when the measured win exceeds noise and all correctness gates stay green.

## Sequence work without creating a new monolith

```text
M0 truth recovery
  -> M1 System/bootstrap contract
      -> M2 executable two-hop self-host viability
          -> M3 compiler kernel
              -> M4 typed query/incremental
                  -> M5 parallel/data performance
                      -> M6 MIR production
                          -> M7 reproducible product self-hosting
                              -> M9 performance leadership
                  -> M8 internal tooling core
```

Safe parallel work is limited to boundaries with independent files and gates:

- Benchmark harness can progress beside M0 correctness fixes.
- MIR verifier coverage can progress beside M3 owner refactoring, but MIR
  production promotion remains after M5.
- System runtime-contract coverage can progress beside query-engine design.
- Public LSP/formatter adapters cannot progress ahead of M8 internal contracts.

Every implementation slice remains small, test-first, reversible, and landed
through a latest-main candidate. Long-lived compiler-system work is never
raw-merged to `main`.

## Start with these nine landing slices

| Order | Slice                                                                                      | Completion evidence                                                                                                   |
| ----- | ------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------- |
| 1     | Land System intrinsic identity, parent graph, and source-backed cache fixes                | Focused mutation proof plus current-main replay                                                                       |
| 2     | Repair/version the NPC cache framing contract and replace the fail-open incremental script | Save-load round trip plus wrong-fingerprint, truncation, corrupt-length, hostile-count, and missing-artifact failures |
| 3     | Isolate cache roots for compiler tests and builds                                          | Concurrent worktrees and cold/warm gates do not share mutable cache state                                             |
| 4     | Restore compiler-pass truth and repair `classes_pass`                                      | Fresh isolated cold and immediate-warm compiler-pass                                                                  |
| 5     | Restore the canonical compiler rebuild entry                                               | Clean stage0 rebuild, artifact hygiene, failure diagnostics                                                           |
| 6     | Replace the compiler benchmark with a fail-closed B0 harness                               | Versioned manifest, repeat distribution, process-tree RSS, corpus and host fingerprint                                |
| 7     | Complete the four-layer System/runtime contract ledger                                     | Declaration, HIR, runtime, failure, and focused evidence for every active contract                                    |
| 8     | Build and execute generation B from A                                                      | Isolated manifests, executable B, identical declared acceptance set                                                   |
| 9     | Build C from B and emit the M2 equivalence report                                          | Executable C, repeated empty-root proof, versioned B/C report                                                         |

Do not begin the M3 owner migration or M4 typed query engine until slice 9 proves
the current compiler can complete the declared two-hop viability path.

## Maintain one promotion dashboard

The roadmap dashboard records evidence, not optimistic percentages.

| Capability               | State                                   | Current evidence                                                                                         | Next gate                                                                 |
| ------------------------ | --------------------------------------- | -------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| System semantic identity | integrated in lane                      | lane commits `dd9132419`, `feff78730`, `d41bb0259`; focused gate green                                   | latest-main replay and cold/warm compiler-pass                            |
| Compiler correctness     | needs repair                            | last known 51/53 before cache fix                                                                        | fresh full gate, then `classes_pass` root cause                           |
| Rebuild                  | broken                                  | tracked script has no build body                                                                         | hermetic rebuild RED/GREEN slice                                          |
| Query engine             | skeleton                                | O(n) memo table and prefix invalidation                                                                  | typed-key design and dependency tests                                     |
| Incremental compiler     | broken framing / experimental semantics | NPC writer uses length-prefixed fingerprint while readers consume raw bytes; root dependencies are empty | M0 framing round trip and truncation gate, then M4 dependency equivalence |
| Parallel compiler        | standalone skeleton                     | no readiness check, worker, or build-path caller                                                         | real worker execution and determinism stress                              |
| MIR                      | duplicated opt-in side path             | session can report ready without a module; backend rebuilds HIR/MIR and verifier is minimal              | one session-owned verified default input and codegen parity gate          |
| Benchmark truth          | broken                                  | compiler failures and unsupported targets are timed; stale IR and parent-only metrics are possible       | fail-closed B0 manifest and process-tree resource gate                    |
| Self-host                | frontend/module probe only              | historical 22/22 stage2 module probe; no executable B/C evidence                                         | M2 isolated A to B to C viability gate                                    |
| Internal tooling core    | planned                                 | architecture specifications exist                                                                        | starts after typed query snapshots                                        |

Update this table only in the same commit that adds or invalidates evidence.

## Apply stop rules

Stop and revisit architecture when any of these occurs:

- Three fixes in one area reveal different process-global state dependencies.
- Incremental and clean builds disagree and the invalidation edge is unknown.
- Parallel speedup requires nondeterministic diagnostic or artifact order.
- A MIR pass needs syntax-tree access or performs name resolution.
- A benchmark gets faster by skipping work or swallowing failures.
- Self-host requires editing generated target projections by hand.
- Tooling needs a second semantic or workspace model.

The rollback point is always the newest compiler commit with clean focused,
compiler-pass, compiler-fail, rebuild, and hygiene evidence.

## Define success without slogans

The compiler is modern when typed, revisioned truth is reusable by builds and
interactive analysis without duplicated semantics.

The compiler is fast when cold, warm, incremental, parallel, memory, and
generated-code measurements meet published budgets on a reproducible corpus.

The compiler is elegant when owners are small, dependency direction is clear,
resources have explicit lifetimes, and lower layers never reconstruct higher
layer facts.

The compiler is mature when it reproducibly builds itself and its System/runtime
spine, with honest diagnostics and a rollbackable release artifact.
