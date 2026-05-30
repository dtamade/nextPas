# Findings & Decisions

## Requirements
- Review `src/nextpas.core.regex.nfa.pas`, `src/nextpas.core.regex.pas`, `src/nextpas.core.regex.compiler.pas`, and `src/nextpas.core.regex.parser.pas`.
- Focus on memory leaks, crash edge cases, performance regressions, and correctness bugs.
- Pay special attention to the slot pool in `NfaSearch`, malformed expand templates, `FindAt` bounds, `Split` with `AMaxSplits=0`, very large NFA programs, and sparse-set behavior when code length is zero.
- Report each finding with severity, approximate location, failure mode, and suggested fix.

## Research Findings
- Memory file quick pass confirms `nextPas` review work should stay architecture- and correctness-first, with explicit attention to memory-leak proof for public surfaces.
- `TRegex.FindAt` forwards `AStartPos` directly to `NfaSearch` with no wrapper-level bounds check.
- `TRegex.ReplaceAllExpand` treats malformed `$` templates as literals or silently drops unterminated `${name` fragments instead of raising an error.
- `TRegex.Split` maps `AMaxSplits <= 0` to "unlimited", which is surprising for `AMaxSplits = 0`.
- `NfaSearch` uses a grow-only slot pool with no explicit teardown path and deduplicates epsilon closure only by program counter, not by `(pc, slot-state)`.
- `RegexParse` accepts `{m,n}` without validating numeric size/order, and `RegexCompile` materializes bounded repeats by full unrolling.
- The shipped `tests/nextpas.core.regex/test_regex_basic/test_regex_basic.lpr` passes cleanly, but it does not cover malformed expand templates, `Split(..., 0)`, `FindAt` with start beyond input, or very large repetition counts.
- Checked the user-highlighted `LCodeLen = 0` sparse-set path: both `NfaIsMatch` and `NfaSearch` return before sparse-set initialization/use, so this specific edge looks safe.

## Technical Decisions
| Decision | Rationale |
|----------|-----------|
| Review by execution pipeline: parser -> compiler -> NFA -> wrapper API | Makes it easier to connect user-visible bugs to root causes |
| Record both confirmed issues and disproved suspicions | Prevents noisy final review and captures what was validated |

## Issues Encountered
| Issue | Resolution |
|-------|------------|
| Broad `rg --files` query returned too much noise | Switched to targeted file opens and narrower searches |
| Test folder has no local `Makefile` | Compiled the regex test directly with `fpc -Fu./src -Fi./src` |

## Resources
- `task_plan.md`
- `src/nextpas.core.regex.nfa.pas`
- `src/nextpas.core.regex.pas`
- `src/nextpas.core.regex.compiler.pas`
- `src/nextpas.core.regex.parser.pas`

## Visual/Browser Findings
- None; local source review only.
