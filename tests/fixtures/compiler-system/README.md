# compiler-system focused fixtures (Batch 22–26)

Small host-free programs for lane evidence. **Not** G0 inventory inflation;
**not** M2-A.

| Fixture | Gate | Expected |
| --- | --- | --- |
| `rec_str_field.pas` | `make test-compiler-rec-str-abi` | exit 42 |
| `rec_const_str_sret.pas` | same | exit 42 |
| `fail_mini_state.pas` | same | exit 1 + greppable status/command/selector |
| `astatestr_fail_mini.pas` | `make test-compiler-astatestr-fail` | exit 1 + multi-arg WriteLn + post-sret field |

## Run

```bash
# Batch 25: record string ABI + mini Fail (intermediate Sel assign)
make test-compiler-rec-str-abi

# Batch 26: multi-arg WriteLn(ErrOutput, 'selector=', Selector(A)) + post-sret field
make test-compiler-astatestr-fail
```

## Claim levels

| Gate | claim-level |
| --- | --- |
| `verify_compiler_rec_str_abi_focused` | `rec-str-const-sret-fail-mini-not-m2a` |
| `verify_compiler_astatestr_fail_focused` | `astatestr-selector-truth` |

## Honest gaps

- Host-free `WriteLn` still writes fd 1 (stdout); `ErrOutput` is skipped as a
  non-integer handle, not yet mapped to fd 2.
- Full `TNextPasState` / `PrintCommandEnvelope` on entry-compiled path and
  entry probe still open; **not** M2-A.
- Batch 26 tightened: record string field `<>`/`=` lowers via strcmp, empty
  `lit ` field-store works, const string params materialize to TString;
  gate requires `selector=build` and `human-summary=invalid-arguments`.