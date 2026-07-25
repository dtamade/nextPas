# compiler-system focused fixtures (Batch 22–29)

Small host-free programs for lane evidence. **Not** G0 inventory inflation;
**not** M2-A.

| Fixture | Gate | Expected |
| --- | --- | --- |
| `rec_str_field.pas` | `make test-compiler-rec-str-abi` | exit 42 |
| `rec_const_str_sret.pas` | same | exit 42 |
| `fail_mini_state.pas` | same | exit 1 + Fail lines **on stderr only** |
| `astatestr_fail_mini.pas` | `make test-compiler-astatestr-fail` | exit 1 + multi-arg WriteLn + post-sret field **on stderr only** |
| `erroutput_fd_mini.pas` | `make test-compiler-erroutput-fd` | stdout vs stderr split (fd 1 vs fd 2) |
| `write_i64_fd_mini.pas` | `make test-compiler-write-i64-fd` | integer 42 on stdout, 7 on stderr |

## Run

```bash
# Batch 25: record string ABI + mini Fail (intermediate Sel assign)
make test-compiler-rec-str-abi

# Batch 26: multi-arg WriteLn(ErrOutput, 'selector=', Selector(A)) + post-sret field
make test-compiler-astatestr-fail

# Batch 27: ErrOutput/StdErr → write(fd=2); Output → write(fd=1)
make test-compiler-erroutput-fd

# Batch 29: write_i64_decimal(value, fd) integer routing
make test-compiler-write-i64-fd
```

## Claim levels

| Gate | claim-level |
| --- | --- |
| `verify_compiler_rec_str_abi_focused` | `rec-str-const-sret-fail-mini-not-m2a` |
| `verify_compiler_astatestr_fail_focused` | `astatestr-selector-truth-fd2` |
| `verify_compiler_erroutput_fd_focused` | `erroutput-fd2-routing` |
| `verify_compiler_write_i64_fd_focused` | `write-i64-decimal-fd` |

## Honest gaps

- Full `TNextPasState` / `PrintCommandEnvelope` on entry-compiled path and
  entry probe still open; **not** M2-A (large block).
- Batch 26 tightened: record string field `<>`/`=` lowers via strcmp, empty
  `lit ` field-store works, const string params materialize to TString;
  gate requires `selector=build` and `human-summary=invalid-arguments`.
- Batch 27 maps host-free `Write`/`WriteLn` string payloads for
  `ErrOutput`/`StdErr` to fd 2 and `Output`/`StdOut` to fd 1.
- Batch 28: `astatestr-fail` and `fail_mini_state` gates **require** Fail
  diagnostic lines on stderr (fd 2) and reject stdout leakage (no combined
  stdout|stderr lucky-green).
- Batch 29: `write_i64_decimal(i64 %v, i64 %fd)` — integer writes honor the
  same Write/WriteErr DisplayName → fd routing as strings. Fixture proves
  `WriteLn(Output, 42)` vs `WriteLn(ErrOutput, 7)`.

## Landing (path-limited; do **not** raw-merge this lane)

Lane: `codex/compiler-system` @ `.worktrees/compiler-system`

### Commits on main..HEAD (expected after B25–B29 land)

- B25/B26: rec_str ABI + AState multi-arg Fail
- B27: ErrOutput/StdErr host-free write → fd 2
- B28: Fail/AState 诊断强制 stderr(fd2)
- B29 (+ docs): write_i64_decimal fd + fixture/gate + this Landing note

Use `git log --oneline main..HEAD` for exact hashes at land time.

### Path inventory (keep)

- `compiler/ir/np_hir_builder_write_string.inc`
- `compiler/ir/np_hir_llvm_emitter_instr.inc`
- `compiler/ir/np_hir_llvm_emitter_helpers.inc`
- `compiler/sema/np_sema_walk_halt_calls.inc`
- `rtl/runtime/src/nextpas.runtime.strings.ll`
- `Makefile` (focused targets only)
- `tests/fixtures/compiler-system/*`
- `tests/regression/verify_compiler_{rec_str_abi,astatestr_fail,erroutput_fd,write_i64_fd}_focused.sh`

### Focused verification

```bash
make test-compiler-rec-str-abi
make test-compiler-astatestr-fail
make test-compiler-erroutput-fd
make test-compiler-write-i64-fd
make system-projection-check
make hygiene
git diff --check
```

Rebuild prerequisites when emitter/runtime change:

```bash
make rebuild-compiler
make -C rtl/runtime all
```

### Do **not** bring into main

- `build/`, `.nextpas/`, temporary bisect/body-seed trees
- Unrelated http/mem/platform lane dirt
- M2-A / full `TNextPasState` / process_init typed migration
- A→B→C bootstrap campaign docs or task_plan.md
- Raw whole-lane history without path-limited replay

### Merge recommendation

Create a **path-limited landing candidate** (cherry-pick / filtered replay of
the B25–B29 commits onto fresh main). Do **not** raw-merge
`codex/compiler-system`. After land, re-base the lane and drop absorbed
temporary worktrees.