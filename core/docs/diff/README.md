# nextpas.core.diff

Text diff algorithms and unified patch codec. Pure L1: no fs/net/process deps.

## Units

| Unit | Responsibility |
|------|----------------|
| `nextpas.core.diff.base` | `TDiffLineAction`, `TDiffEdit`, `TDiffHunk` types; line split/join helpers |
| `nextpas.core.diff.myers` | Myers O(ND) diff over line arrays, edit-script output |
| `nextpas.core.diff.unified` | unified hunk emit + tolerant patch parse |
| `nextpas.core.diff` | facade (pure re-export) |

## API Sketch

```pascal
uses nextpas.core.diff;

var OldLines, NewLines: TStringDynArray;
    Edits: TDiffEditArray;
    Hunks: TDiffHunkArray;

Edits := DiffLines(OldLines, NewLines);          // Myers edit script
Hunks := BuildHunks(Edits, 3);                   // group with context
WriteLn(EmitUnifiedHunks(Hunks));                // "@@ -1,3 +1,3 @@" blocks

Hunks := ParseUnified(PatchText);                // tolerant reader:
                                                 // skips file headers,
                                                 // "\ No newline" markers,
                                                 // funcname suffixes
```

## Semantics

- Lines are compared with native string equality; no normalization.
- `TDiffEdit.OldIndex` / `NewIndex` are 0-based into the input arrays;
  `daEqual/daDelete` carry `OldIndex`, `daEqual/daInsert` carry `NewIndex`.
- Hunk header numbers are 1-based; an empty side is emitted as `0,0`.
- `EmitUnifiedHunks` emits only the hunk sections. File headers (`---`,
  `+++`) belong to the caller; the parser accepts patches with or without
  them.

## Known Limits (D1)

- Memory for the trace is O(D^2) in the edit distance D — fine for source
  files, not for multi-MB single-line blobs.
- No patience/histogram variants yet (D2).
- The end-of-file newline marker is tolerated on parse but not reproduced on
  emit (emit input lines carry no EOL information).

## Consumers

- `nextpas.core.tui.widget.diffview` consumes this module since D3:
  `TDiffView.UnifiedToLines` delegates to `ParseUnified`, which fixed the
  inline parser's per-hunk line-number reset, `---`-content misdetection
  and `\ No newline` handling. The header section (`---`/`+++`) still
  renders as `dlHeader`; git transport lines are skipped.

## Testing

```bash
make -C core/tests/nextpas.core.diff/test_diff_myers clean test
make -C core/tests/nextpas.core.diff/test_diff_unified clean test
```

The unified gate uses system `git diff --no-index` output as golden input:
parse must reconstruct both sides byte-for-byte, and our emit must match
git's hunk sections.
